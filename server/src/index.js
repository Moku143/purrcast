// Purrcast forecast server — Cloudflare Worker.
//   GET /v1/forecast?lat=&lon=&region=kr|jp|other&tz=&plan=free|plus&lang=ko[&prev=0..9][&name=서울 마포구]
//   GET /health
// Korea: 기상청 단기예보 (+ Plus: 초단기실황 · 초단기예보 · 특보), days 4–10 and UV from MET Norway.
// Elsewhere: Apple WeatherKit (current, hourly, daily, next-hour minutes, alerts) when its key is set.
// MET Norway is the fallback everywhere: no key, or a source failing, falls back to it.
//
// Bindings (wrangler.toml / secrets): KMA_SERVICE_KEY (secret), WEATHERKIT_KEY_ID · WEATHERKIT_KEY_P8 · APPLE_TEAM_ID
// (secrets), WEATHERKIT_SERVICE_ID (var), CONTACT (var, for MET's User-Agent),
// HISTORY (optional KV namespace: yesterday-at-this-hour temperatures for "전일 대비").

import { metUrl, parseMet } from './providers/met.js';
import { toGrid, vilageBase, eveBase, ultraBase, ncstBase, kmaUrl, parseForecast, parseNow, parseWarnings, kmaOK, kmaXmlError } from './providers/kma.js';
import { hasWeatherKit, weatherKitUrl, weatherKitToken, parseWeatherKit } from './providers/weatherkit.js';
import { buildScene, validateScene } from './scene.js';
import { local, pad2, dayKey } from './time.js';
import { normLang } from './i18n.js';

const JSON_HEADERS = { 'content-type': 'application/json; charset=utf-8', 'access-control-allow-origin': '*' };

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (url.pathname === '/health') {
      const out = { ok: true, kma: !!env.KMA_SERVICE_KEY, weatherkit: hasWeatherKit(env), time: new Date().toISOString() };
      if (url.searchParams.get('deep') === '1') out.check = await deepCheck(env);   // first-deploy check: can we reach both sources?
      return json(out);
    }
    if (url.pathname !== '/v1/forecast') return json({ error: 'not found' }, 404);
    try {
      const q = readQuery(url.searchParams);
      const scene = await forecast(q, env, ctx);
      validateScene(scene);
      // Plus: refresh every 10 min; free: the day's stored forecast, so cache longer
      return json(scene, 200, { 'cache-control': q.plan === 'plus' ? 'public, max-age=600' : 'public, max-age=3600' });
    } catch (e) {
      const status = e.status || 502;
      return json({ error: String(e.message || e) }, status);
    }
  },
};

export function readQuery(sp) {
  // ~1 km is plenty for a forecast and is what the privacy policy promises
  const lat = Math.round(parseFloat(sp.get('lat')) * 100) / 100, lon = Math.round(parseFloat(sp.get('lon')) * 100) / 100;
  if (!(lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180)) throw Object.assign(new Error('lat / lon missing or out of range'), { status: 400 });
  const tz = sp.get('tz') || 'Asia/Seoul';
  try { new Intl.DateTimeFormat('en-US', { timeZone: tz }); } catch { throw Object.assign(new Error('bad tz'), { status: 400 }); }
  const prev = sp.get('prev') == null ? null : parseInt(sp.get('prev'), 10);
  return {
    lat, lon, tz,
    region: ['kr', 'jp', 'other'].includes(sp.get('region')) ? sp.get('region') : 'other',
    plan: sp.get('plan') === 'plus' ? 'plus' : 'free',
    prev: Number.isInteger(prev) && prev >= 0 && prev <= 9 ? prev : null,
    name: sp.get('name') || '',
    lang: normLang(sp.get('lang')),   // ko (default) | en | ja; anything else → en
  };
}

function json(body, status = 200, extra = {}) {
  return new Response(JSON.stringify(body), { status, headers: { ...JSON_HEADERS, ...extra } });
}

// Two cache layers: this isolate's memory (works everywhere, including workers.dev) and the Workers cache
// (shared per data centre, only on a custom domain). Only usable answers are stored.
const MEM = new Map();
const MEM_MAX = 400;
export function resetCache() { MEM.clear(); }

/** fetch → JSON. `ok(data)` decides whether it may be cached; `ttl` seconds (MET: from its Expires header). */
async function getJSON(url, { ttl, headers = {}, fetcher = fetch, ok = () => true, ctx = null, kma = false }) {
  const now = Date.now();
  const m = MEM.get(url);
  if (m && m.until > now) return m.data;
  const cache = typeof caches !== 'undefined' ? caches.default : null;
  const key = new Request(url, { headers: { 'x-purrcast-cache': '1' } });
  if (cache) {
    const hit = await cache.match(key).catch(() => null);
    if (hit) { const data = await hit.json(); MEM.set(url, { data, until: now + ttl * 1000 }); return data; }
  }
  const res = await fetcher(url, { headers });
  const text = await res.text();
  if (kma && text.trimStart().startsWith('<')) throw kmaXmlError(text);
  if (!res.ok) throw new Error(`${new URL(url).host} ${res.status}`);
  const data = JSON.parse(text);
  let life = ttl;
  const exp = res.headers?.get?.('expires');
  if (exp) { const left = Math.round((Date.parse(exp) - now) / 1000); if (left > 60) life = Math.min(left, 3 * 3600); }
  if (ok(data) && life > 0) {
    if (MEM.size >= MEM_MAX) MEM.delete(MEM.keys().next().value);
    MEM.set(url, { data, until: now + life * 1000 });
    if (cache) {
      const put = cache.put(key, new Response(text, { headers: { 'content-type': 'application/json', 'cache-control': `public, max-age=${life}` } })).catch(() => {});
      if (ctx?.waitUntil) ctx.waitUntil(put); else await put;
    }
  }
  return data;
}

export async function forecast(q, env, ctx, { now = new Date(), fetcher = fetch } = {}) {
  const ua = `Purrcast/1.0 ${env.CONTACT || 'github.com/Moku143/purrcast'}`;
  const metP = getJSON(metUrl(q.lat, q.lon), { ttl: 1800, headers: { 'user-agent': ua }, fetcher, ctx })
    .then(parseMet).catch((e) => ({ error: e }));

  let f = null;
  if (q.region === 'kr' && env.KMA_SERVICE_KEY) {
    try { f = await korea(q, env, now, fetcher, ctx); } catch (e) { console.log('KMA failed, using MET:', e.message); f = null; }
  }
  if (!f && hasWeatherKit(env)) {   // everywhere else (and Korea when KMA is down): Apple WeatherKit
    try { f = await apple(q, env, now, fetcher, ctx); } catch (e) { console.log('WeatherKit failed, using MET:', e.message); f = null; }
  }
  const met = await metP;
  if (!f) {
    if (met.error) throw met.error;
    f = { points: met.points, updated: met.updated, nextSource: 'met', src: 'met' };
    if (q.plan === 'plus') f.next6 = met.points.filter((p) => p.t > now).slice(0, 6);
  } else if (f.src === 'kma' && !met.error) {
    // KMA hourly for the first ~4 days (day 5 is 3-hourly and in words), MET after; MET's UV / gusts / fog where KMA has none
    const cut = now.getTime() + 4 * 86400000;
    f.points = f.points.filter((p) => p.t.getTime() < cut);
    const lastKma = f.points[f.points.length - 1]?.t ?? now;
    let j = 0;
    const mp = met.points;
    f.points = f.points.map((p) => {
      while (j + 1 < mp.length && Math.abs(mp[j + 1].t - p.t) <= Math.abs(mp[j].t - p.t)) j++;   // both lists are sorted
      const m = mp.length && Math.abs(mp[j].t - p.t) <= 3 * 3600000 ? mp[j] : null;
      return m ? { ...p, uvClear: m.uvClear, gust: p.gust ?? m.gust, fog: m.fog, dew: p.dew ?? m.dew } : p;
    }).concat(mp.filter((p) => p.t > lastKma));
  }

  // 예보 비교: the other sources' next 24 h go to the comparison card only (the main source drives everything else)
  const compare = [{ key: f.src, points: f.points, main: true }];
  if (f.src !== 'apple' && hasWeatherKit(env)) {
    try { const a = await apple(q, env, now, fetcher, ctx); compare.push({ key: 'apple', points: a.points }); }
    catch (e) { console.log('WeatherKit (compare) failed:', e.message); }
  }
  if (f.src !== 'met' && !met.error) compare.push({ key: 'met', points: met.points });
  if (compare.length > 1) f.compare = compare;

  const yday = await history(env, q, now, f, ctx);
  return buildScene(f, { lat: q.lat, lon: q.lon, tz: q.tz, plan: q.plan, prev: q.prev, yday, now, lang: q.lang });
}

async function korea(q, env, now, fetcher, ctx) {
  const key = env.KMA_SERVICE_KEY;
  const { nx, ny } = toGrid(q.lat, q.lon);
  const plus = q.plan === 'plus';
  const get = (op, params, ttl) => getJSON(kmaUrl(op, key, { ...params, nx, ny }), { ttl, fetcher, ok: kmaOK, ctx, kma: true });
  const vb = vilageBase(now, plus ? null : 5);       // free: the 05 h run ("06:00 기준")
  // earlier runs for today's morning: the run in use starts an hour after it was made, and runs after 06 h leave out
  // today's low (TMN), after 15 h today's high (TMX) — so the 05 h run and yesterday's 23 h run fill in the hours since
  // midnight (the day sheet) and today's low / high. They never change, so they are cached for hours (and shared).
  const same = (a, b) => a.date === b.date && a.time === b.time;
  const earlier = [vilageBase(now, 5), eveBase(now)].filter((b, i, all) => !same(b, vb) && all.findIndex((x) => same(x, b)) === i);
  const [vilRaw, ...early] = await Promise.allSettled([
    get('getVilageFcst', { base_date: vb.date, base_time: vb.time }, plus ? 1800 : 6 * 3600),
    ...earlier.map((b) => get('getVilageFcst', { base_date: b.date, base_time: b.time }, 12 * 3600)),
  ]);
  if (vilRaw.status === 'rejected') throw vilRaw.reason;
  const vil = parseForecast(vilRaw.value, 'kma');
  if (vil.total != null && vil.total > vil.got) console.log(`KMA 단기예보 cut: ${vil.got} of ${vil.total} rows`);
  const f = { points: vil.points, daily: { ...vil.daily }, updated: vb.at, nextSource: 'kma', src: 'kma' };
  const today = dayKey(now, 'Asia/Seoul');
  for (const r of early) {   // newest first
    if (r.status !== 'fulfilled') continue;
    let e;
    try { e = parseForecast(r.value, 'kma'); } catch { continue; }
    const first = f.points[0]?.t ?? Infinity;
    f.points = e.points.filter((p) => p.t < first && dayKey(p.t, 'Asia/Seoul') >= today).concat(f.points);
    for (const [k, d] of Object.entries(e.daily)) if (k >= today) f.daily[k] = { lo: f.daily[k]?.lo ?? d.lo, hi: f.daily[k]?.hi ?? d.hi };
  }
  if (plus) {
    const [ultra, ncst, warn] = await Promise.allSettled([
      (async () => { const b = ultraBase(now); return { b, d: parseForecast(await get('getUltraSrtFcst', { base_date: b.date, base_time: b.time }, 600), 'kma-ultra') }; })(),
      (async () => {
        const b = ncstBase(now);
        try { return parseNow(await get('getUltraSrtNcst', { base_date: b.date, base_time: b.time }, 600)); }
        catch (e) {   // at the edge of the hour the newest run may not be out yet: the hour before
          const p = ncstBase(new Date(now.getTime() - 3600000));
          return parseNow(await get('getUltraSrtNcst', { base_date: p.date, base_time: p.time }, 600));
        }
      })(),
      (async () => parseWarnings(await getJSON(kmaUrl('getPwnStatus', key, {}), { ttl: 600, fetcher, ok: kmaOK, ctx, kma: true }), q.name))(),
    ]);
    for (const [name, r] of [['초단기예보', ultra], ['초단기실황', ncst], ['특보', warn]]) {
      if (r.status === 'rejected') console.log(`KMA ${name} failed:`, r.reason?.message);
    }
    if (ultra.status === 'fulfilled' && ultra.value.d.points.length) {
      // the next six hours from 초단기예보 replace the 단기예보 hours they cover
      const up = ultra.value.d.points;
      const covered = new Set(up.map((p) => p.t.getTime()));
      f.points = f.points.filter((p) => !covered.has(p.t.getTime())).concat(up.map((u) => {
        const v = f.points.find((p) => p.t.getTime() === u.t.getTime());
        return { ...u, pop: v?.pop ?? (u.mm > 0 ? 80 : 0) };
      })).sort((a, b) => a.t - b.t);
      f.next6 = up.slice(0, 6);
      f.updated = ultra.value.b.at;
    }
    if (ncst.status === 'fulfilled' && ncst.value) f.now = ncst.value;
    if (warn.status === 'fulfilled') f.warnings = warn.value;
  }
  return f;
}

const COUNTRY = { kr: 'KR', jp: 'JP' };   // WeatherKit wants a country code for weatherAlerts; 'other' has none

/** Apple WeatherKit: one call gives everything. Plus refreshes every 10 min, free every 30. */
async function apple(q, env, now, fetcher, ctx) {
  const plus = q.plan === 'plus';
  const jwt = await weatherKitToken(env, { now });
  const url = weatherKitUrl(q.lat, q.lon, { lang: q.lang, tz: q.tz, country: COUNTRY[q.region] ?? null });
  const w = parseWeatherKit(await getJSON(url, { ttl: plus ? 600 : 1800, headers: { authorization: `Bearer ${jwt}` }, fetcher, ok: (d) => !!d?.forecastHourly?.hours?.length, ctx }), q.tz);
  if (!w.points.length) throw new Error('WeatherKit: no hourly forecast');
  const f = { points: w.points, updated: w.updated, daily: w.daily, warnings: w.warnings, nextSource: 'apple', src: 'apple' };
  if (plus) {
    // where Apple has minute-by-minute rain (Japan, the US, the UK, …) the app shows the next hour by the minute;
    // elsewhere the next 6 hours from Apple's hourly forecast
    if (w.minutes?.length) f.minutes = w.minutes;
    else f.next6 = w.points.filter((p) => p.t > now).slice(0, 6);
    if (w.now) f.now = w.now;
  }
  return f;
}

/** /health?deep=1: one real call to each source, so a first deploy shows at once whether keys and network work. */
async function deepCheck(env) {
  const out = {};
  if (hasWeatherKit(env)) {
    try {
      const jwt = await weatherKitToken(env);
      const r = await fetch(weatherKitUrl(35.69, 139.7, { lang: 'en', tz: 'Asia/Tokyo', country: 'JP' }), { headers: { authorization: `Bearer ${jwt}` } });
      out.weatherkit = r.ok ? r.status : `${r.status} ${(await r.text().catch(() => '')).slice(0, 160)}`.trim();   // Apple's reason, e.g. NOT_ENABLED
    } catch (e) { out.weatherkit = String(e.message || e); }
  } else out.weatherkit = 'no key';
  try { const r = await fetch(metUrl(37.57, 126.98), { headers: { 'user-agent': `Purrcast/1.0 ${env.CONTACT || ''}` } }); out.met = r.status; }
  catch (e) { out.met = String(e.message || e); }
  if (env.KMA_SERVICE_KEY) {
    try {
      const b = vilageBase(new Date());
      const r = await fetch(kmaUrl('getVilageFcst', env.KMA_SERVICE_KEY, { base_date: b.date, base_time: b.time, nx: 60, ny: 127 }));
      const t = await r.text();
      out.kma = t.trimStart().startsWith('<') ? kmaXmlError(t).message : (JSON.parse(t)?.response?.header?.resultMsg ?? r.status);
    } catch (e) { out.kma = String(e.message || e); }
  }
  return out;
}

/** "전일 대비": remember this hour's temperature per ~1 km cell for 2 days (KV), read yesterday's. */
async function history(env, q, now, f, ctx) {
  if (!env.HISTORY) return null;
  const p = local(now, q.tz);
  const cell = `${q.lat.toFixed(2)},${q.lon.toFixed(2)}`;
  const k = (d) => `t:${cell}:${d.y}${pad2(d.m)}${pad2(d.d)}${pad2(d.h)}`;
  const y = local(new Date(now.getTime() - 86400000), q.tz);
  const cur = f.now?.temp ?? f.points.find((x) => x.t <= now && now - x.t < 3600000)?.temp;
  try {
    // free KV allows 1,000 writes a day: write each cell-hour once
    if (cur != null && (await env.HISTORY.get(k(p))) == null) {
      const put = env.HISTORY.put(k(p), String(cur), { expirationTtl: 2 * 86400 + 3600 });
      if (ctx?.waitUntil) ctx.waitUntil(put); else await put;
    }
    const v = await env.HISTORY.get(k(y));
    return v == null ? null : parseFloat(v);
  } catch { return null; }
}
