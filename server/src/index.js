// Purrcast forecast server — Cloudflare Worker.
//   GET /v1/forecast?lat=&lon=&region=kr|jp|other&tz=&plan=free|plus&lang=ko[&prev=0..9][&name=서울 마포구]
//   GET /health
// Korea: 기상청 단기예보 (+ Plus: 초단기실황 · 초단기예보 · 특보), days 4–10 and UV from MET Norway.
// Elsewhere: MET Norway. Any source failing falls back to the other where possible.
//
// Bindings (wrangler.toml / secrets): KMA_SERVICE_KEY (secret), CONTACT (var, for MET's User-Agent),
// HISTORY (optional KV namespace: yesterday-at-this-hour temperatures for "전일 대비").

import { metUrl, parseMet } from './providers/met.js';
import { toGrid, vilageBase, ultraBase, ncstBase, kmaUrl, parseForecast, parseNow, parseWarnings } from './providers/kma.js';
import { buildScene, validateScene } from './scene.js';
import { local, pad2 } from './time.js';

const JSON_HEADERS = { 'content-type': 'application/json; charset=utf-8', 'access-control-allow-origin': '*' };

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (url.pathname === '/health') return json({ ok: true, kma: !!env.KMA_SERVICE_KEY, time: new Date().toISOString() });
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
  };
}

function json(body, status = 200, extra = {}) {
  return new Response(JSON.stringify(body), { status, headers: { ...JSON_HEADERS, ...extra } });
}

/** fetch → JSON, through the Workers cache when there is one (tests run without it). */
async function getJSON(url, { ttl, headers = {}, fetcher = fetch }) {
  const cache = typeof caches !== 'undefined' ? caches.default : null;
  const key = new Request(url, { headers: { 'x-purrcast-cache': '1' } });
  if (cache) {
    const hit = await cache.match(key);
    if (hit) return hit.json();
  }
  const res = await fetcher(url, { headers });
  if (!res.ok) throw new Error(`${new URL(url).host} ${res.status}`);
  const text = await res.text();
  const data = JSON.parse(text);
  if (cache && ttl > 0) {
    await cache.put(key, new Response(text, { headers: { 'content-type': 'application/json', 'cache-control': `public, max-age=${ttl}` } }));
  }
  return data;
}

export async function forecast(q, env, ctx, { now = new Date(), fetcher = fetch } = {}) {
  const ua = `Purrcast/1.0 ${env.CONTACT || 'github.com/Moku143/purrcast'}`;
  const metP = getJSON(metUrl(q.lat, q.lon), { ttl: 1800, headers: { 'user-agent': ua }, fetcher })
    .then(parseMet).catch((e) => ({ error: e }));

  let f = null;
  if (q.region === 'kr' && env.KMA_SERVICE_KEY) {
    try { f = await korea(q, env, now, fetcher); } catch (e) { console.log('KMA failed, using MET:', e.message); f = null; }
  }
  const met = await metP;
  if (!f) {
    if (met.error) throw met.error;
    f = { points: met.points, updated: met.updated, nextSource: 'met' };
    if (q.plan === 'plus') f.next6 = met.points.filter((p) => p.t > now).slice(0, 6);
  } else if (!met.error) {
    // KMA covers ~3 days: add MET for the rest, and MET's UV / gusts / fog where KMA has none
    const lastKma = f.points[f.points.length - 1]?.t ?? now;
    f.points = f.points.map((p) => {
      const m = nearest(met.points, p.t);
      return m ? { ...p, uvClear: m.uvClear, gust: p.gust ?? m.gust, fog: m.fog, dew: p.dew ?? m.dew } : p;
    }).concat(met.points.filter((p) => p.t > lastKma));
  }

  const yday = await history(env, q, now, f, ctx);
  return buildScene(f, { lat: q.lat, lon: q.lon, tz: q.tz, plan: q.plan, prev: q.prev, yday, now });
}

function nearest(points, t) {
  let best = null, d = Infinity;
  for (const p of points) { const x = Math.abs(p.t - t); if (x < d) { d = x; best = p; } }
  return d <= 3 * 3600000 ? best : null;
}

async function korea(q, env, now, fetcher) {
  const key = env.KMA_SERVICE_KEY;
  const { nx, ny } = toGrid(q.lat, q.lon);
  const plus = q.plan === 'plus';
  const vb = vilageBase(now, plus ? null : 5);       // free: the 05 h run ("06:00 기준")
  const vil = parseForecast(await getJSON(kmaUrl('getVilageFcst', key, { base_date: vb.date, base_time: vb.time, nx, ny }), { ttl: plus ? 1800 : 6 * 3600, fetcher }), 'kma');
  const f = { points: vil.points, daily: vil.daily, updated: vb.at, nextSource: 'kma' };
  if (plus) {
    const [ultra, ncst, warn] = await Promise.allSettled([
      (async () => { const b = ultraBase(now); return { b, d: parseForecast(await getJSON(kmaUrl('getUltraSrtFcst', key, { base_date: b.date, base_time: b.time, nx, ny }), { ttl: 600, fetcher }), 'kma-ultra') }; })(),
      (async () => { const b = ncstBase(now); return parseNow(await getJSON(kmaUrl('getUltraSrtNcst', key, { base_date: b.date, base_time: b.time, nx, ny }), { ttl: 600, fetcher })); })(),
      (async () => parseWarnings(await getJSON(kmaUrl('getPwnStatus', key, {}), { ttl: 600, fetcher }), q.name))(),
    ]);
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

/** "전일 대비": remember this hour's temperature per ~1 km cell for 2 days (KV), read yesterday's. */
async function history(env, q, now, f, ctx) {
  if (!env.HISTORY) return null;
  const p = local(now, q.tz);
  const cell = `${q.lat.toFixed(2)},${q.lon.toFixed(2)}`;
  const k = (d) => `t:${cell}:${d.y}${pad2(d.m)}${pad2(d.d)}${pad2(d.h)}`;
  const y = local(new Date(now.getTime() - 86400000), q.tz);
  const cur = f.now?.temp ?? f.points.find((x) => x.t <= now && now - x.t < 3600000)?.temp;
  try {
    if (cur != null) {
      const put = env.HISTORY.put(k(p), String(cur), { expirationTtl: 2 * 86400 + 3600 });
      if (ctx?.waitUntil) ctx.waitUntil(put); else await put;
    }
    const v = await env.HISTORY.get(k(y));
    return v == null ? null : parseFloat(v);
  } catch { return null; }
}
