// Purrcast forecast server — Cloudflare Worker.
//   GET /v1/forecast?lat=&lon=&region=kr|jp|other&tz=&plan=free|plus&lang=ko[&outfitPrev=0..14][&prev=0..9][&name=서울 마포구][&v=2]
//   v: what the app knows. 2 = the 'sleet' icon (진눈깨비); older apps (no v) get 'snowflake' in its place.
//   GET /health
// Korea: 기상청 단기예보 (+ Plus: 초단기실황 · 초단기예보 · 특보) and 중기예보 for days 4–10; Apple WeatherKit fills the hours
// after the 단기예보 and the UV / gusts KMA has none of.
// Elsewhere: Apple WeatherKit (current, hourly, daily, next-hour minutes, alerts) when its key is set.
// MET Norway is the comparison card's second opinion and the last-resort fallback: no key, or every source failing, falls back to it.
//
// Bindings (wrangler.toml / secrets): KMA_SERVICE_KEY (secret), AIRKOREA_SERVICE_KEY (secret, 미세먼지 in Korea; the same
// data.go.kr key works once 에어코리아 is approved for it), OPENWEATHER_KEY (secret, air quality elsewhere),
// WEATHERKIT_KEY_ID · WEATHERKIT_KEY_P8 · APPLE_TEAM_ID
// (secrets), WEATHERKIT_SERVICE_ID (var), CONTACT (var, for MET's User-Agent),
// HISTORY (optional KV namespace: yesterday-at-this-hour temperatures for "전일 대비"),
// FREE_DAY (KV namespace: the free plan's one Apple forecast a day per ~1 km cell; the Server workflow creates it).

import { metUrl, parseMet } from './providers/met.js';
import { toGrid, vilageBase, eveBase, ultraBase, ncstBase, kmaUrl, parseForecast, parseNow, parseWarnings, kmaOK, kmaXmlError, midUrl, midBase, midRegions, parseMidTa, parseMidLand } from './providers/kma.js';
import { hasWeatherKit, weatherKitUrl, weatherKitToken, parseWeatherKit, packWeatherKit, unpackWeatherKit, WK_HOST } from './providers/weatherkit.js';
import { stationsUrl, realtimeUrl, forecastUrl, alarmUrl, nationUrl, airkoreaOK, nearestStation, parseRealtime, parseHistory, todayHours, forecastRegion, parseForecast as parseDustForecast, parseAlarms, stationIndex, airMap, pmLevel, airDetail, owDetail } from './providers/airkorea.js';
import { owNowUrl, owForecastUrl, owHistoryUrl, owOK, parseOwNow, parseOwTomorrow, parseOwHours } from './providers/openweather.js';
import { buildScene, validateScene } from './scene.js';
import { nearestAsos, asosUrl, parseAsos, weatherKitHistoryUrl, parseWeatherKitHistory } from './providers/history.js';
import { local, pad2, dayKey } from './time.js';
import { normLang } from './i18n.js';
import { hasAPNs, readDevice, saveDevice, runActivities } from './push.js';
import { radarFrames, obsUrl, qpfUrl, imagePath } from './providers/radar.js';

const JSON_HEADERS = { 'content-type': 'application/json; charset=utf-8', 'access-control-allow-origin': '*' };

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    // bulk callers only: a generous limit per address (a carrier NAT puts many phones behind one), when bound
    if (env.IP_LIMIT && url.pathname !== '/health') {
      const ip = request.headers.get('cf-connecting-ip') || 'unknown';
      if (!(await env.IP_LIMIT.limit({ key: `ip:${ip}` })).success) return json({ error: 'slow down' }, 429, { 'retry-after': '60' });
    }
    if (url.pathname === '/health') {
      const out = { ok: true, kma: !!env.KMA_SERVICE_KEY, radar: !!env.KMA_APIHUB_KEY, airkorea: !!env.AIRKOREA_SERVICE_KEY, openweather: !!env.OPENWEATHER_KEY, weatherkit: hasWeatherKit(env), freeDay: !!env.FREE_DAY, apns: hasAPNs(env), devices: !!env.DEVICES, holidays: !!env.HOLIDAYS, time: new Date().toISOString() };
      // first-deploy check (can we reach every source?): only while DEEP_CHECK is "on" — each call spends upstream quota
      if (url.searchParams.get('deep') === '1' && env.DEEP_CHECK === 'on') out.check = await deepCheck(env);
      return json(out);
    }
    if (url.pathname === '/v1/devices') return devices(request, env);
    if (url.pathname === '/v1/airmap') {
      try {
        const out = await airMapAnswer(url.searchParams, env, ctx);
        return json(out, 200, { 'cache-control': 'public, max-age=900' });
      } catch (e) { return json({ error: String(e.message || e) }, e.status || 502); }
    }
    // 비 지도 (Plus, Korea): the frame list, and each frame's picture fetched from 기상청 API허브 (the key stays here)
    if (url.pathname === '/v1/radar') {
      if ((url.searchParams.get('region') || 'kr') !== 'kr') return json({ error: 'Korea only' }, 404);
      if (!env.KMA_APIHUB_KEY) return json({ error: 'no radar key' }, 503);
      return json(radarFrames(new Date()), 200, { 'cache-control': 'public, max-age=120' });
    }
    if (url.pathname === '/v1/radar/img') return radarImage(url.searchParams, env);
    if (url.pathname === '/v1/holidays') {
      const out = await holidaysAnswer(url.searchParams, env);
      return new Response(out.body, { status: out.status, headers: { ...JSON_HEADERS, 'cache-control': out.status === 200 ? 'public, max-age=86400' : 'no-store' } });
    }
    if (url.pathname === '/v1/history') {
      try {
        const out = await historyAnswer(url.searchParams, env, ctx);
        return json(out, 200, { 'cache-control': 'public, max-age=3600' });
      } catch (e) { return json({ error: String(e.message || e) }, e.status || 502); }
    }
    if (url.pathname !== '/v1/forecast') return json({ error: 'not found' }, 404);
    try {
      const q = readQuery(url.searchParams);
      const scene = await forecast(q, env, ctx);
      validateScene(scene);
      if (q.v < 2) legacyIcons(scene);
      // Plus: refresh every 10 min; free: the day's stored forecast, so cache longer
      return json(scene, 200, { 'cache-control': q.plan === 'plus' ? 'public, max-age=600' : 'public, max-age=3600' });
    } catch (e) {
      const status = e.status || 502;
      return json({ error: String(e.message || e) }, status);
    }
  },

  /** Every half hour (wrangler.toml `crons`): the rain Live Activities of registered Plus devices. */
  async scheduled(event, env, ctx) {
    const now = new Date();
    const forecastRaw = (q) => forecast(q, env, ctx, { now, raw: true });
    const out = await runActivities(env, { forecastRaw, now });
    console.log('activities:', JSON.stringify(out));
  },
};

// the pictures of the last frames, in this isolate (workers.dev has no shared cache); a frame's picture never changes
const RADAR_IMG = new Map();
const RADAR_IMG_MAX = 60;

/** GET /v1/radar/img?k=obs&tm=YYYYMMDDHHMM | k=qpf&tm=…&ef=10…60 — one radar picture. `debug=1`: the API's own
 *  answer instead (the key blanked), for checking its format. */
export async function radarImage(sp, env, { fetcher = fetch, timeout = 8000 } = {}) {
  const k = sp.get('k'), tm = sp.get('tm') || '', ef = sp.get('ef') || '';
  if (!/^\d{12}$/.test(tm) || !['obs', 'qpf'].includes(k) || (k === 'qpf' && !/^(10|20|30|40|50|60)$/.test(ef))) return json({ error: 'bad frame' }, 400);
  const key = env.KMA_APIHUB_KEY;
  if (!key) return json({ error: 'no radar key' }, 503);
  const id = `${k}|${tm}|${ef}`;
  const debug = sp.get('debug') === '1';
  const hit = !debug && RADAR_IMG.get(id);
  if (hit) return picture(hit.bytes, hit.type);
  const blank = (s) => s.split(key).join('***');
  const get = async (u) => {
    const ac = new AbortController();
    const timer = setTimeout(() => ac.abort(), timeout);
    try { return await fetcher(u, { signal: ac.signal }); } finally { clearTimeout(timer); }
  };
  try {
    const r = await get(k === 'obs' ? obsUrl(key, tm) : qpfUrl(key, tm, +ef));
    const type = r.headers.get('content-type') || '';
    let bytes, imgType;
    if (type.startsWith('image/')) {
      // the API answered with the picture itself
      bytes = new Uint8Array(await r.arrayBuffer()); imgType = type;
      if (debug) return json({ status: r.status, type, bytes: bytes.length });
    } else {
      const text = await r.text();
      let data; try { data = JSON.parse(text); } catch { data = [text]; }
      const src = r.ok ? imagePath(data) : null;
      if (debug) return json({ status: r.status, type, answer: blank(text).slice(0, 4000), picture: src && blank(src) });
      if (!src) return json({ error: 'no picture for this frame yet' }, 404, { 'cache-control': 'public, max-age=60' });
      const ir = await get(src);
      if (!ir.ok) return json({ error: `picture ${ir.status}` }, 404, { 'cache-control': 'public, max-age=60' });
      bytes = new Uint8Array(await ir.arrayBuffer()); imgType = ir.headers.get('content-type') || 'image/png';
    }
    if (bytes.length < 100) return json({ error: 'empty picture' }, 404, { 'cache-control': 'public, max-age=60' });
    if (RADAR_IMG.size >= RADAR_IMG_MAX) RADAR_IMG.delete(RADAR_IMG.keys().next().value);
    RADAR_IMG.set(id, { bytes, type: imgType });
    return picture(bytes, imgType);
  } catch (e) {
    return json({ error: blank(String(e.message || e)) }, 502);
  }
}

function picture(bytes, type) {
  return new Response(bytes, { headers: { 'content-type': type, 'cache-control': 'public, max-age=86400, immutable', 'access-control-allow-origin': '*' } });
}

/** GET /v1/holidays?cc=KR — one country's public holidays for the 날씨 달력 (substitute days included), as
 *  { cc, lang, made, days: { "2026-10-05": { "": "개천절 대체공휴일", en: "…" } } }. HOLIDAYS (KV, bound by the Server
 *  workflow) holds `cc:KR` … written by tools/holidays/upload.mjs from the open-source `holidays` package (weekly and
 *  at every deploy). A country with none known answers with no days. */
export async function holidaysAnswer(sp, env) {
  const cc = (sp.get('cc') || '').toUpperCase();
  if (!/^[A-Z]{2}$/.test(cc)) return { status: 400, body: JSON.stringify({ error: 'cc: a two-letter country code' }) };
  const body = env.HOLIDAYS ? await env.HOLIDAYS.get('cc:' + cc) : null;
  return { status: 200, body: body || JSON.stringify({ cc, days: {} }) };
}

/** GET /v1/history?lat=&lon=&region=&tz=&from=YYYY-MM-DD&to=YYYY-MM-DD — 날씨 기록's missing days (the calendar, Plus):
 *  what each past day's weather was. Korea: the nearest 기상청 ASOS station's daily record; elsewhere (or when that
 *  fails): Apple WeatherKit's daily history. At most 62 days, up to yesterday. → { days: [...], src: 'kma' | 'apple' } */
export async function historyAnswer(sp, env, ctx, { now = new Date(), fetcher = fetch } = {}) {
  const q = readQuery(sp);
  const iso = (k) => `${k.slice(0, 4)}-${k.slice(4, 6)}-${k.slice(6, 8)}`;
  const yesterday = iso(dayKey(new Date(now.getTime() - 86400000), q.tz));
  const okDate = (v) => /^\d{4}-\d{2}-\d{2}$/.test(v || '');
  let to = okDate(sp.get('to')) ? sp.get('to') : yesterday;
  if (to > yesterday) to = yesterday;
  let from = okDate(sp.get('from')) ? sp.get('from') : to;
  const earliest = new Date(Date.parse(`${to}T00:00:00Z`) - 61 * 86400000).toISOString().slice(0, 10);
  if (from < earliest) from = earliest;
  if (from < '2021-08-01') from = '2021-08-01';   // Apple's history starts there
  if (from > to) return { days: [], src: null };
  // past days do not change; yesterday's record can still arrive late in the morning
  const ttl = to >= yesterday ? 3 * 3600 : 7 * 86400;
  const errors = [];
  if (q.region === 'kr' && env.KMA_SERVICE_KEY) {
    const st = nearestAsos(q.lat, q.lon);
    if (st) {
      try {
        const data = await getJSON(asosUrl(env.KMA_SERVICE_KEY, st.id, from, to), { ttl, fetcher, ctx, kma: true, ok: (d) => d?.response?.header?.resultCode === '00' });
        const days = parseAsos(data, st);
        if (days.length) return { days, src: 'kma', station: st.name };
      } catch (e) { errors.push(String(e.message || e)); }
    }
  }
  if (hasWeatherKit(env)) {
    const jwt = await weatherKitToken(env, { now });
    const data = await getJSON(weatherKitHistoryUrl(WK_HOST, q.lat, q.lon, from, to, q.tz), { ttl, fetcher, ctx, headers: { authorization: `Bearer ${jwt}` }, ok: (d) => !!d?.forecastDaily?.days?.length });
    return { days: parseWeatherKitHistory(data, from, to, (d) => iso(dayKey(d, q.tz))), src: 'apple' };
  }
  throw Object.assign(new Error(errors[0] || 'no history source'), { status: 502 });
}

/** GET /v1/airmap?lat=&lon=&region= — the 대기질 지도 (Plus).
 *  Korea (region=kr): 에어코리아's latest hour for every station near the place, with 통합대기환경지수 — the whole country
 *  is fetched once and kept for half an hour. Elsewhere: OpenWeather's air at a 4 × 4 grid over the same box (plus the
 *  place itself), each grid point snapped to 0.1° so nearby places share them, kept an hour; PM2.5 and PM10 on WHO's
 *  steps. Either way: { kind, at, me: { value?, level, grade }, points: [[lat, lon, level 0–4, value|null]] }. */
export async function airMapAnswer(sp, env, ctx, fetcher = fetch) {
  const lat = Math.round(parseFloat(sp.get('lat')) * 100) / 100, lon = Math.round(parseFloat(sp.get('lon')) * 100) / 100;
  if (!(lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180)) throw Object.assign(new Error('lat / lon missing or out of range'), { status: 400 });
  const kr = sp.get('region') === 'kr' && lat >= 32 && lat <= 39.5 && lon >= 123.5 && lon <= 132;
  if (kr && env.AIRKOREA_SERVICE_KEY) {
    const key = env.AIRKOREA_SERVICE_KEY;
    const [st, nation] = await Promise.all([
      getJSON(stationsUrl(key), { ttl: 86400, fetcher, ok: airkoreaOK, ctx, kma: true }),
      getJSON(nationUrl(key), { ttl: 1800, fetcher, ok: airkoreaOK, ctx, kma: true }),
    ]);
    const m = airMap(nation, stationIndex(st), lat, lon);
    // the sheet: the same station the 미세먼지 card reads (its last day of readings, the URL the card already caches)
    const near = nearestStation(st, lat, lon);
    if (near) {
      try { m.detail = airDetail(await getJSON(realtimeUrl(key, near.name), { ttl: 3600, fetcher, ok: airkoreaOK, ctx, kma: true }), near.name); }
      catch (e) { console.log('airmap detail failed:', e.message); }
    }
    return m;
  }
  if (!env.OPENWEATHER_KEY) throw Object.assign(new Error('no air quality source'), { status: 503 });
  const key = env.OPENWEATHER_KEY, r1 = (v) => Math.round(v * 10) / 10;
  const spots = [[lat, lon]];
  for (const dy of [-0.4, -0.13, 0.13, 0.4]) for (const dx of [-0.5, -0.17, 0.17, 0.5]) spots.push([r1(lat + dy), r1(lon + dx)]);
  const got = await Promise.allSettled(spots.map(([y, x]) => getJSON(owNowUrl(key, y, x), { ttl: 3600, fetcher, ok: owOK, ctx })));
  const points = [];
  let me = null, at = null;
  got.forEach((g, i) => {
    if (g.status !== 'fulfilled') return;
    const c = parseOwNow(g.value);
    const level = c ? pmLevel(c.pm25, c.pm10) : null;
    if (level == null) return;
    const lv = Math.min(level, 3.99), grade = Math.floor(lv);
    if (!at || c.at > at) at = c.at;
    if (i === 0) me = { value: null, level: lv, grade };
    else points.push([spots[i][0], spots[i][1], lv, null]);
  });
  if (!me && !points.length) throw Object.assign(new Error('no air quality data'), { status: 502 });
  // the sheet: every pollutant at the place, and the same hour yesterday
  let detail = null;
  if (got[0].status === 'fulfilled') {
    const t = Math.floor(Date.now() / 1000) - 86400;
    // the hour nearest this time yesterday (the history is hourly and can lag: a wider window, the closest one kept)
    const hist = await getJSON(owHistoryUrl(key, lat, lon, t - 3 * 3600, t + 3600), { ttl: 3600, fetcher, ok: owOK, ctx }).catch(() => null);
    const near = hist?.list?.length ? hist.list.reduce((a, b) => (Math.abs(b.dt - t) < Math.abs(a.dt - t) ? b : a)) : null;
    const before = near ? { list: [near] } : null;
    detail = owDetail(got[0].value, before);
  }
  return { kind: 'pm', at: at ? at.toISOString() : '', me, points: me ? [[lat, lon, me.level, null], ...points] : points, detail };
}

/** POST: the app registers (or re-registers) its device for Live Activities; DELETE ?id= forgets it. */
async function devices(request, env) {
  if (!env.DEVICES) return json({ error: 'no device store' }, 503);
  if (request.method === 'DELETE') {
    const id = String(new URL(request.url).searchParams.get('id') || '').replace(/[^0-9A-Za-z-]/g, '').slice(0, 64);
    if (id) await env.DEVICES.delete(`dev:${id}`);
    return json({ ok: true });
  }
  if (request.method !== 'POST') return json({ error: 'method' }, 405);
  let body = null;
  try { body = await request.json(); } catch { /* bad json */ }
  const dev = readDevice(body);
  if (!dev) return json({ error: 'bad device' }, 400);
  // one device: a few registrations a minute at most (the app sends one when something changed, or hourly)
  if (env.DEVICE_LIMIT && !(await env.DEVICE_LIMIT.limit({ key: `dev:${dev.id}` })).success) return json({ error: 'slow down' }, 429, { 'retry-after': '60' });
  // only Plus is pushed to: a free registration (an older app) is simply not stored. An existing record is left
  // alone — free posts stop refreshing it, so it expires on its own 45-day TTL (nothing stored is ever deleted
  // here; a device asks for its own deletion through DELETE /v1/devices).
  if (dev.plan !== 'plus') return json({ ok: true, push: false, plan: 'free', start: false, act: false });
  const saved = await saveDevice(env.DEVICES, dev);
  return json({ ok: true, push: hasAPNs(env), plan: saved.plan, start: !!saved.start, act: !!saved.act });
}

export function readQuery(sp) {
  // ~1 km is plenty for a forecast and is what the privacy policy promises
  const lat = Math.round(parseFloat(sp.get('lat')) * 100) / 100, lon = Math.round(parseFloat(sp.get('lon')) * 100) / 100;
  if (!(lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180)) throw Object.assign(new Error('lat / lon missing or out of range'), { status: 400 });
  const tz = sp.get('tz') || 'Asia/Seoul';
  try { new Intl.DateTimeFormat('en-US', { timeZone: tz }); } catch { throw Object.assign(new Error('bad tz'), { status: 400 }); }
  const prev = sp.get('prev') == null ? null : parseInt(sp.get('prev'), 10);
  const outfitPrev = sp.get('outfitPrev') == null ? null : parseInt(sp.get('outfitPrev'), 10);
  return {
    lat, lon, tz,
    region: ['kr', 'jp', 'other'].includes(sp.get('region')) ? sp.get('region') : 'other',
    plan: sp.get('plan') === 'plus' ? 'plus' : 'free',
    prev: Number.isInteger(prev) && prev >= 0 && prev <= 9 ? prev : null,
    outfitPrev: Number.isInteger(outfitPrev) && outfitPrev >= 0 && outfitPrev <= 14 ? outfitPrev : null,
    debug: sp.get('debug') === '1',   // adds `debug` (which upstream answered) to the answer
    name: sp.get('name') || '',
    lang: normLang(sp.get('lang')),   // ko (default) | en | ja; anything else → en
    v: parseInt(sp.get('v'), 10) || 1,
  };
}

/** Icons an older app does not have, swapped for the nearest one it has (an unknown name would show a plain cloud). */
const LEGACY_ICON = { sleet: 'snowflake' };
export function legacyIcons(scene) {
  const swap = (n) => LEGACY_ICON[n] ?? n;
  for (const row of [...(scene.hours ?? []), ...(scene.days ?? [])]) row[1] = swap(row[1]);
  if (scene.bubble) scene.bubble.icon = swap(scene.bubble.icon);
  for (const t of scene.tiles ?? []) t.icon = swap(t.icon);
  return scene;
}

function json(body, status = 200, extra = {}) {
  return new Response(JSON.stringify(body), { status, headers: { ...JSON_HEADERS, ...extra } });
}

// Two cache layers: this isolate's memory (works everywhere, including workers.dev) and the Workers cache
// (shared per data centre, only on a custom domain). Only usable answers are stored.
const MEM = new Map();
const MEM_MAX = 400;
export function resetCache() { MEM.clear(); }

/** How long one upstream call may take: the app gives up after 15–20 s, so a slow source is dropped (and another
 * source or the cache is used) well before that. */
export const UPSTREAM_TIMEOUT_MS = 4500;
let upstreamTimeout = UPSTREAM_TIMEOUT_MS;
/** tests: a shorter wait */
export function setUpstreamTimeout(ms) { upstreamTimeout = ms ?? UPSTREAM_TIMEOUT_MS; }

/** fetch → JSON. `ok(data)` decides whether it may be cached; `ttl` seconds (MET: from its Expires header). */
async function getJSON(url, { ttl, headers = {}, fetcher = fetch, ok = () => true, ctx = null, kma = false, timeout = upstreamTimeout }) {
  const now = Date.now();
  const m = MEM.get(url);
  if (m && m.until > now) return m.data;
  const cache = typeof caches !== 'undefined' ? caches.default : null;
  const key = new Request(url, { headers: { 'x-purrcast-cache': '1' } });
  if (cache) {
    const hit = await cache.match(key).catch(() => null);
    if (hit) { const data = await hit.json(); MEM.set(url, { data, until: now + ttl * 1000 }); return data; }
  }
  const ac = typeof AbortController !== 'undefined' ? new AbortController() : null;
  let timer = null;
  const late = new Promise((_, reject) => {
    timer = setTimeout(() => { ac?.abort(); reject(new Error(`${new URL(url).host} took over ${timeout} ms`)); }, timeout);
  });
  let res, text;
  try {
    [res, text] = await Promise.race([
      (async () => { const r = await fetcher(url, ac ? { headers, signal: ac.signal } : { headers }); return [r, await r.text()]; })(),
      late,
    ]);
  } finally { clearTimeout(timer); }
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

export async function forecast(q, env, ctx, { now = new Date(), fetcher = fetch, raw = false } = {}) {
  const ua = `Purrcast/1.0 ${env.CONTACT || 'github.com/Moku143/purrcast'}`;
  const metP = getJSON(metUrl(q.lat, q.lon), { ttl: 1800, headers: { 'user-agent': ua }, fetcher, ctx })
    .then(parseMet).catch((e) => ({ error: e }));

  // Apple WeatherKit starts at once beside KMA and MET: the main source abroad, Korea's fallback when KMA is down
  // or slow, and the comparison card's second opinion — never waited for one after another
  const appleP = hasWeatherKit(env) ? apple(q, env, now, fetcher, ctx).catch((e) => ({ error: e })) : null;
  // 미세먼지 alongside: 에어코리아 in Korea, OpenWeather elsewhere; never waited for on its own, never fatal
  const dustP = dust(q, env, now, fetcher, ctx).catch((e) => { console.log('dust failed:', e.message); return null; });
  let f = null;
  if (q.region === 'kr' && env.KMA_SERVICE_KEY) {
    try { f = await korea(q, env, now, fetcher, ctx); } catch (e) { console.log('KMA failed, using WeatherKit / MET:', e.message); f = null; }
  }
  if (!f && appleP) {   // everywhere else (and Korea when KMA is down): Apple WeatherKit
    const a = await appleP;
    if (a.error) console.log('WeatherKit failed, using MET:', a.error.message); else f = a;
  }
  const met = await metP;
  if (!f) {
    if (met.error) throw met.error;
    f = { points: met.points, updated: met.updated, nextSource: 'met', src: 'met' };
    if (q.plan === 'plus') f.next6 = met.points.filter((p) => p.t > now).slice(0, 6);
  } else if (f.src === 'kma') {
    // KMA hourly for the first ~4 days (day 5 is 3-hourly and in words); the hours after come from Apple (the
    // 중기예보's daily low / high, chance and sky take over those days), with Apple's UV / gusts / fog where KMA has
    // none. MET stands in only when Apple does not answer.
    let other = null;
    if (appleP) { const a = await appleP; if (!a.error) other = a.points; }
    if (!other && !met.error) other = met.points;
    if (other) {
      const cut = now.getTime() + 4 * 86400000;
      f.points = f.points.filter((p) => p.t.getTime() < cut);
      const lastKma = f.points[f.points.length - 1]?.t ?? now;
      let j = 0;
      const mp = other;
      f.points = f.points.map((p) => {
        while (j + 1 < mp.length && Math.abs(mp[j + 1].t - p.t) <= Math.abs(mp[j].t - p.t)) j++;   // both lists are sorted
        const m = mp.length && Math.abs(mp[j].t - p.t) <= 3 * 3600000 ? mp[j] : null;
        // the UV comes with the sky it was worked out under (Apple's uvIndex is under Apple's cloud): put back under
        // 기상청's clearer sky, an overcast Apple hour's UV 3 would come out as 10
        return m ? { ...p, uvClear: m.uvClear, uvCloud: m.cloud, gust: p.gust ?? m.gust, fog: m.fog, fogPct: m.fogPct, dew: p.dew ?? m.dew } : p;
      }).concat(mp.filter((p) => p.t > lastKma));
    }
  }

  // 예보 비교: the other sources' next 24 h go to the comparison card only (the main source drives everything else)
  const compare = [{ key: f.src, points: f.points, main: true }];
  if (f.src !== 'apple' && appleP) {
    const a = await appleP;
    if (a.error) console.log('WeatherKit (compare) failed:', a.error.message); else compare.push({ key: 'apple', points: a.points });
  }
  if (f.src !== 'met' && !met.error) compare.push({ key: 'met', points: met.points });
  if (compare.length > 1) f.compare = compare;

  const yday = await history(env, q, now, f, ctx);
  f.dust = await dustP;
  const scene = buildScene(f, { lat: q.lat, lon: q.lon, tz: q.tz, plan: q.plan, prev: q.prev, outfitPrev: q.outfitPrev, yday, now, lang: q.lang });
  if (q.debug) scene.debug = { ...(f.debug ?? {}), src: f.src, points: f.points.length, apple: appleP ? !(await appleP).error : null, met: !met.error };
  return raw ? { scene, f } : scene;   // raw: the Live Activity pass reads the hourly points too
}

/** 미세먼지 for the place: { pm10, pm25, src, station, tomorrow: { pm10Grade, pm25Grade } | null, alarm, history } or null.
 *  Readings are hourly at the source (에어코리아 on the hour, OpenWeather's hour too), so they are kept an hour per ~1 km
 *  cell for every plan; the forecast bulletin comes out four times a day, so three hours. Korea: the nearest 에어코리아
 *  station (the station list is kept a day). Elsewhere: OpenWeather. */
/**
 * 미세먼지 · 초미세먼지. Plus: the station's newest hour (cached an hour) and today's readings so far (`hours`, the day
 * sheet's chart). Free: one reading a day — the first answer of the day for this ~1 km cell is kept in FREE_DAY, like
 * the free forecast (without the namespace: the hourly cache) — and no hours.
 */
export async function dust(q, env, now, fetcher, ctx) {
  const plus = q.plan === 'plus';
  const store = !plus && env.FREE_DAY ? env.FREE_DAY : null;
  const key = `dust:${q.lat.toFixed(2)},${q.lon.toFixed(2)}:${freeDay(now, q.tz)}`;
  if (store) {
    try {
      const kept = await store.get(key, 'json');
      if (kept && (kept.pm10 != null || kept.pm25 != null)) return kept;
    } catch (e) { console.log('FREE_DAY dust read failed:', e.message); }
  }
  let d = await dustNow(q, env, now, fetcher, ctx);
  if (!d) return null;
  if (!plus) { const { hours, ...rest } = d; d = rest; }
  if (store) {
    const put = store.put(key, JSON.stringify(d), { expirationTtl: 30 * 3600 }).catch((e) => console.log('FREE_DAY dust write failed:', e.message));
    if (ctx?.waitUntil) ctx.waitUntil(put); else await put;
  }
  return d;
}

async function dustNow(q, env, now, fetcher, ctx) {
  const kst = (d) => { const p = local(d, 'Asia/Seoul'); return `${p.y}-${pad2(p.m)}-${pad2(p.d)} ${pad2(p.h)}:${pad2(p.mi ?? 0)}`; };
  if (q.region === 'kr' && env.AIRKOREA_SERVICE_KEY) {
    const key = env.AIRKOREA_SERVICE_KEY;
    const st = nearestStation(await getJSON(stationsUrl(key), { ttl: 86400, fetcher, ok: airkoreaOK, ctx, kma: true }), q.lat, q.lon);
    if (!st) return null;
    const today = dayKey(now, 'Asia/Seoul'), tomorrow = dayKey(new Date(now.getTime() + 86400000), 'Asia/Seoul');
    const ymd = (k) => `${k.slice(0, 4)}-${k.slice(4, 6)}-${k.slice(6, 8)}`;
    const region = forecastRegion(st.addr, q.lat, q.lon);
    const province = st.addr.split(/\s+/)[0] || '';
    const [rt, f10, f25, al] = await Promise.allSettled([
      getJSON(realtimeUrl(key, st.name), { ttl: 3600, fetcher, ok: airkoreaOK, ctx, kma: true }),
      getJSON(forecastUrl(key, ymd(today), 'PM10'), { ttl: 3 * 3600, fetcher, ok: airkoreaOK, ctx, kma: true }),
      getJSON(forecastUrl(key, ymd(today), 'PM25'), { ttl: 3 * 3600, fetcher, ok: airkoreaOK, ctx, kma: true }),
      getJSON(alarmUrl(key, local(now, 'Asia/Seoul').y), { ttl: 3600, fetcher, ok: airkoreaOK, ctx, kma: true }),
    ]);
    if (rt.status !== 'fulfilled') throw rt.reason;
    const cur = parseRealtime(rt.value);
    if (!cur) return null;
    const t10 = f10.status === 'fulfilled' ? parseDustForecast(f10.value, region, ymd(tomorrow)) : null;
    const t25 = f25.status === 'fulfilled' ? parseDustForecast(f25.value, region, ymd(tomorrow)) : null;
    return {
      pm10: cur.pm10, pm25: cur.pm25, at: cur.at, src: 'airkorea', station: st.name,
      tomorrow: t10 == null && t25 == null ? null : { pm10Grade: t10, pm25Grade: t25 },
      alarm: al.status === 'fulfilled' ? parseAlarms(al.value, province, kst(now)) : null,
      hours: todayHours(parseHistory(rt.value), ymd(today)),
    };
  }
  if (env.OPENWEATHER_KEY) {
    const key = env.OPENWEATHER_KEY;
    const today = dayKey(now, q.tz);
    const hourOf = (d) => ({ key: dayKey(d, q.tz), h: local(d, q.tz).h });
    const [n, fc, hi] = await Promise.allSettled([
      getJSON(owNowUrl(key, q.lat, q.lon), { ttl: 3600, fetcher, ok: owOK, ctx }),
      getJSON(owForecastUrl(key, q.lat, q.lon), { ttl: 3 * 3600, fetcher, ok: owOK, ctx }),
      q.plan === 'plus' ? getJSON(owHistoryUrl(key, q.lat, q.lon, Math.floor(now.getTime() / 1000) - 24 * 3600, Math.floor(now.getTime() / 1000)), { ttl: 3600, fetcher, ok: owOK, ctx }) : Promise.resolve(null),
    ]);
    if (n.status !== 'fulfilled') throw n.reason;
    const cur = parseOwNow(n.value);
    if (!cur) return null;
    const tm = fc.status === 'fulfilled' ? parseOwTomorrow(fc.value, (d) => dayKey(d, q.tz), dayKey(new Date(now.getTime() + 86400000), q.tz)) : null;
    let hours = hi.status === 'fulfilled' && hi.value ? parseOwHours(hi.value, hourOf, today) : [];
    // the current hour is not always in the history yet
    const nowH = local(now, q.tz).h;
    if (!hours.some((x) => x[0] === nowH) && (cur.pm10 != null || cur.pm25 != null)) hours.push([nowH, cur.pm10, cur.pm25]);
    return { pm10: cur.pm10, pm25: cur.pm25, at: cur.at.toISOString(), src: 'openweather', station: null, tomorrow: tm, alarm: null, hours };
  }
  return null;
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
  // the 중기예보 (days 4–10: the city's low / high, the region's sky and chance) alongside, never fatal
  const mb = midBase(now), mr = midRegions(q.lat, q.lon);
  const midP = Promise.allSettled([
    getJSON(midUrl('getMidTa', key, { regId: mr.ta, tmFc: mb.tmFc }), { ttl: 3 * 3600, fetcher, ok: kmaOK, ctx, kma: true }),
    getJSON(midUrl('getMidLandFcst', key, { regId: mr.land, tmFc: mb.tmFc }), { ttl: 3 * 3600, fetcher, ok: kmaOK, ctx, kma: true }),
  ]);
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
  // 중기예보 for the days the 단기예보 does not reach: its low / high, chance and sky are the day's (as the KMA app shows)
  const [ta, land] = await midP;
  f.debug = { mid: mb.tmFc, midCity: mr.city, midTa: ta.status === 'fulfilled' ? `${Object.keys(parseMidTa(ta.value, mb.date)).length} days` : String(ta.reason?.message),
              midLand: land.status === 'fulfilled' ? `${Object.keys(parseMidLand(land.value, mb.date)).length} days` : String(land.reason?.message) };
  if (ta.status === 'fulfilled' || land.status === 'fulfilled') {
    const temps = ta.status === 'fulfilled' ? parseMidTa(ta.value, mb.date) : {};
    const skies = land.status === 'fulfilled' ? parseMidLand(land.value, mb.date) : {};
    if (ta.status === 'rejected') console.log('KMA 중기 기온 failed:', ta.reason?.message);
    if (land.status === 'rejected') console.log('KMA 중기 육상 failed:', land.reason?.message);
    const lastKmaDay = dayKey(f.points[f.points.length - 1]?.t ?? now, 'Asia/Seoul');
    for (const k of new Set([...Object.keys(temps), ...Object.keys(skies)])) {
      if (k <= lastKmaDay && f.daily[k]?.lo != null && f.daily[k]?.hi != null) continue;   // the 단기예보's own days
      const d = f.daily[k] ?? {};
      if (temps[k]) { d.lo = temps[k].lo ?? d.lo; d.hi = temps[k].hi ?? d.hi; }
      if (skies[k] && k > lastKmaDay) { d.pop = skies[k].pop; d.icon = skies[k].icon; }
      f.daily[k] = d;
    }
  }
  if (plus) {
    const [ultra, ncst, warn] = await Promise.allSettled([
      (async () => { const b = ultraBase(now); return { b, d: parseForecast(await get('getUltraSrtFcst', { base_date: b.date, base_time: b.time }, 600), 'kma-ultra') }; })(),
      (async () => {
        const b = ncstBase(now);
        try { return parseNow(await get('getUltraSrtNcst', { base_date: b.date, base_time: b.time }, 600)); }
        catch (e) {   // at the edge of the hour the newest run may not be out yet: the hour before (not when KMA is just slow)
          if (/took over/.test(e.message)) throw e;
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

/** The free plan's day: from 06:00 to 06:00 the next morning (local), as in Korea where free keeps the 05 h run. */
export const freeDay = (now, tz) => dayKey(new Date(now.getTime() - 6 * 3600000), tz);

/**
 * Apple WeatherKit: one call gives everything. Plus refreshes every 10 min.
 * Free gets one forecast a day, like Korea's 06:00 forecast: the first answer after 06:00 for this ~1 km cell is kept
 * (KV namespace FREE_DAY) and the day is told from it — the hours, the rain, today's low and high. Without the namespace
 * (or when it fails) free falls back to a 30-minute cache.
 */
async function apple(q, env, now, fetcher, ctx) {
  const plus = q.plan === 'plus';
  const store = !plus && env.FREE_DAY ? env.FREE_DAY : null;
  const key = `wk:${q.lat.toFixed(2)},${q.lon.toFixed(2)}:${freeDay(now, q.tz)}:${q.lang}`;
  let w = null;
  if (store) {
    try { w = unpackWeatherKit(await store.get(key, 'json')); } catch (e) { console.log('FREE_DAY read failed:', e.message); }
  }
  if (!w) {
    const jwt = await weatherKitToken(env, { now });
    const url = weatherKitUrl(q.lat, q.lon, { lang: q.lang, tz: q.tz, country: COUNTRY[q.region] ?? null });
    w = parseWeatherKit(await getJSON(url, { ttl: plus ? 600 : 1800, headers: { authorization: `Bearer ${jwt}` }, fetcher, ok: (d) => !!d?.forecastHourly?.hours?.length, ctx }), q.tz);
    if (!w.points.length) throw new Error('WeatherKit: no hourly forecast');
    if (store) {
      w.updated = now;   // "오늘 09:12 기준": when this day's forecast was taken
      const put = store.put(key, packWeatherKit(w), { expirationTtl: 30 * 3600 }).catch((e) => console.log('FREE_DAY write failed:', e.message));
      if (ctx?.waitUntil) ctx.waitUntil(put); else await put;
    }
  }
  const warnings = (w.warnings || []).filter((a) => !a.until || new Date(a.until) > now);
  const f = { points: w.points, updated: w.updated, daily: w.daily, warnings, nextSource: 'apple', src: 'apple' };
  if (store) f.freeAt = w.updated;   // free: the time this day's forecast was taken
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
  // 미세먼지 sources: what each answers for Seoul / Tokyo (the gateway's reason when a key is not approved yet)
  if (env.AIRKOREA_SERVICE_KEY) {
    try {
      const r = await fetch(stationsUrl(env.AIRKOREA_SERVICE_KEY)); const t = await r.text();
      out.airkorea = t.trimStart().startsWith('<') ? kmaXmlError(t).message : (JSON.parse(t)?.response?.header?.resultMsg ?? r.status);
      if (out.airkorea === 'NORMAL_CODE' || r.ok) {
        const d = await dust({ lat: 37.49, lon: 126.84, region: 'kr', tz: 'Asia/Seoul' }, env, new Date(), fetch, null).catch((e) => ({ error: e.message }));
        out.airkoreaDust = d && !d.error ? `${d.station} pm10 ${d.pm10} pm25 ${d.pm25}` : d?.error || 'null';
        for (const [k, u] of [['rt', realtimeUrl(env.AIRKOREA_SERVICE_KEY, '신정동')], ['fc', forecastUrl(env.AIRKOREA_SERVICE_KEY, '2026-10-30', 'PM10')], ['al', alarmUrl(env.AIRKOREA_SERVICE_KEY, 2026)]]) {
          try { const x = await fetch(u); const tx = await x.text(); out['airkorea_' + k] = `${x.status} ${tx.replace(/\s+/g, ' ').slice(0, 200)}`; } catch (e) { out['airkorea_' + k] = String(e.message || e); }
        }
      }
    } catch (e) { out.airkorea = String(e.message || e); }
  } else out.airkorea = 'no key';
  if (env.OPENWEATHER_KEY) {
    try {
      const r = await fetch(owNowUrl(env.OPENWEATHER_KEY, 35.69, 139.7)); const t = await r.text();
      out.openweather = r.ok ? `${r.status} ${parseOwNow(JSON.parse(t))?.pm10 ?? '?'}` : `${r.status} ${t.slice(0, 120)}`;
    } catch (e) { out.openweather = String(e.message || e); }
  } else out.openweather = 'no key';
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
