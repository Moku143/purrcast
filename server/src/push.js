// The rain alert (Plus) as a Live Activity push: the app registers its device (a push-to-start token, iOS 17.2+);
// every half hour the Worker's cron looks at each device's place and, when rain (or snow) is due within the hour
// or falling now, starts the activity once over APNs — on the Dynamic Island / lock screen for a few minutes
// (DISMISS_AFTER), with the alert banner — and says nothing more about that rain. Needs an APNs key: APNS_KEY (the
// .p8 text), APNS_KEY_ID, APPLE_TEAM_ID.
//
// Device records live in the DEVICES KV namespace: dev:<id> → { id, start (push-to-start token), act (the running
// activity's update token), key (which rain the activity is about), until (ms), lat, lon, tz, region, lang, name,
// char, plan, at (ms) }.

import { strings } from './i18n.js';
import { local, dayKey } from './time.js';

export const APNS_HOST = 'https://api.push.apple.com';
export const BUNDLE_ID = 'app.purrcast.ios';
export const ATTRIBUTES_TYPE = 'RainActivityAttributes';
const MAX_HOURS = 8;   // ActivityKit ends an activity after 8 hours anyway
export const WITHIN_HOURS = 1;       // the alert comes when the rain is this close
export const DISMISS_AFTER = 10 * 60; // seconds the activity stays on the island / lock screen

export const hasAPNs = (env) => !!(env.APNS_KEY && env.APNS_KEY_ID && env.APPLE_TEAM_ID);

// ---- JWT (ES256 via WebCrypto, as for WeatherKit) ----

const b64url = (bytes) => {
  const bin = typeof bytes === 'string' ? bytes : String.fromCharCode(...new Uint8Array(bytes));
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};
const utf8 = (s) => new TextEncoder().encode(s);
function pemToPkcs8(pem) {
  const body = String(pem).replace(/-----BEGIN [^-]+-----/g, '').replace(/-----END [^-]+-----/g, '').replace(/\s+/g, '');
  const bin = atob(body);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out.buffer;
}
let TOKEN = null;   // { jwt, iat }
export function resetApnsToken() { TOKEN = null; }

/** A signed APNs provider token, reused for up to 50 minutes (APNs wants one between 20 and 60 minutes old at most). */
export async function apnsToken(env, now = new Date()) {
  const iat = Math.floor(now.getTime() / 1000);
  if (TOKEN && iat - TOKEN.iat < 50 * 60) return TOKEN.jwt;
  const header = b64url(utf8(JSON.stringify({ alg: 'ES256', kid: env.APNS_KEY_ID })));
  const payload = b64url(utf8(JSON.stringify({ iss: env.APPLE_TEAM_ID, iat })));
  const key = await crypto.subtle.importKey('pkcs8', pemToPkcs8(env.APNS_KEY), { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, utf8(`${header}.${payload}`));
  TOKEN = { jwt: `${header}.${payload}.${b64url(sig)}`, iat };
  return TOKEN.jwt;
}

/** One Live Activity push: event start | update | end. Returns { ok, status, reason }. 410 / BadDeviceToken → the token is dead. */
export async function sendLiveActivity(env, token, body, { fetcher = fetch, now = new Date() } = {}) {
  const jwt = await apnsToken(env, now);
  const res = await fetcher(`${APNS_HOST}/3/device/${token}`, {
    method: 'POST',
    headers: {
      authorization: `bearer ${jwt}`,
      'apns-topic': `${BUNDLE_ID}.push-type.liveactivity`,
      'apns-push-type': 'liveactivity',
      'apns-priority': '10',
      'apns-expiration': '0',
      'content-type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  let reason = '';
  if (!res.ok) { try { reason = (await res.json())?.reason || ''; } catch { /* no body */ } }
  return { ok: res.ok, status: res.status, reason, dead: res.status === 410 || reason === 'BadDeviceToken' || reason === 'Unregistered' };
}

// ---- what to say ----

const r1 = (v) => Math.round(v * 10) / 10;
const mmText = (v) => (v >= 10 ? String(Math.round(v)) : String(r1(v)));
const kindOf = (p) => (p.type === 'snow' || p.type === 'heavysnow' ? 'snow' : p.type === 'sleet' ? 'sleet' : 'rain');
const wet = (p) => (p.mm || 0) >= 0.1 || ['rain', 'heavy', 'snow', 'heavysnow', 'sleet'].includes(p.type);

/**
 * The rain (snow) the activity is about, from the next hours (`f.next6` when the source has it, else the hourly
 * points): null when nothing falls within `within` hours and nothing is falling now. Otherwise
 * { key, start, end, falling, what, mm, state } where `state` is the activity's content-state.
 */
export function rainActivity(f, { now, tz, lang = 'ko', within = WITHIN_HOURS }) {
  const S = strings(lang);
  const nowT = now.getTime();
  // the hour rows from now on: next6 covers the first hours, the hourly points carry on after it
  const rows = [];
  const seen = new Set();
  for (const p of [...(f.next6 || []), ...f.points]) {
    const t = p.t.getTime();
    if (t + 3600000 <= nowT) continue;             // the hour is over
    if (t > nowT + 12 * 3600000) break;
    const h = Math.floor(t / 3600000);
    if (seen.has(h)) continue;
    seen.add(h); rows.push({ t, mm: p.mm || 0, kind: kindOf(p), wet: wet(p) });
  }
  rows.sort((a, b) => a.t - b.t);
  if (!rows.length) return null;
  const nowWet = f.now?.mm > 0 || (rows[0].t <= nowT && rows[0].wet);
  const first = rows.findIndex((r) => r.wet);
  if (first < 0) return null;
  const startT = Math.max(rows[first].t, nowWet ? nowT : rows[first].t);
  if (!nowWet && rows[first].t > nowT + within * 3600000) return null;
  let last = first;
  while (last + 1 < rows.length && rows[last + 1].wet) last++;
  const endT = Math.min(rows[last].t + 3600000, startT + MAX_HOURS * 3600000);
  const run = rows.slice(first, last + 1);
  const kinds = run.map((r) => r.kind);
  const what = kinds.every((k) => k === 'snow') ? 'snow' : kinds.some((k) => k === 'snow' || k === 'sleet') ? 'sleet' : 'rain';
  const peak = Math.max(...run.map((r) => r.mm), nowWet ? (f.now?.mm || 0) : 0);
  const word = S.what[what];
  const amount = what === 'snow' ? S.live.aboutCm(mmText(peak)) : `${mmText(Math.max(peak, 0.1))}mm`;
  const startH = local(new Date(rows[first].t), tz).h, endH = local(new Date(endT), tz).h;
  const falling = nowWet;
  const title = falling ? S.live.nowFalling(word, amount) : S.expect(S.when(startH, null, false), word);
  const sub = falling ? S.stopAt(endH, word) : `${amount} · ${S.live.care[what]}`;
  const icon = what === 'snow' ? 'snowflake' : what === 'sleet' ? 'sleet' : falling ? 'umbrella' : 'umbrella_closed';
  return {
    key: `${dayKey(new Date(rows[first].t), tz)}:${startH}:${what}`,
    start: startT, end: endT, falling, what, mm: peak,
    state: { title, sub, icon, what, falling, mm: r1(peak), start: Math.floor(startT / 1000), end: Math.floor(endT / 1000), endHour: endH },
  };
}

/** The APNs body for a push-to-start, an update, or the end of the activity. */
export function activityBody(event, { state, place, char, level, now, end }) {
  const ts = Math.floor(now.getTime() / 1000);
  if (event === 'start') {
    return { aps: { timestamp: ts, event: 'start', 'content-state': state, 'attributes-type': ATTRIBUTES_TYPE,
      attributes: { place, character: char || 'cat', level: level ?? 5 },
      alert: { title: state.title, body: place ? `${place} · ${state.sub}` : state.sub, sound: 'default' },
      'stale-date': ts + DISMISS_AFTER, 'dismissal-date': ts + DISMISS_AFTER } };
  }
  if (event === 'end') return { aps: { timestamp: ts, event: 'end', 'content-state': state, 'dismissal-date': ts } };
  return { aps: { timestamp: ts, event: 'update', 'content-state': state, 'stale-date': ts + 3900, 'dismissal-date': Math.floor(end / 1000) + 600 } };
}

// ---- devices ----

const DEV_TTL = 45 * 86400;   // a device the app has not confirmed in 45 days is forgotten

/** The app's registration (JSON body) checked and tidied, or null. Fields the body leaves out stay undefined, so a
 *  later registration (say, only the activity's token) never wipes what an earlier one said. */
export function readDevice(body) {
  if (!body || typeof body !== 'object') return null;
  const id = String(body.id || '').replace(/[^0-9A-Za-z-]/g, '').slice(0, 64);
  const lat = Math.round(parseFloat(body.lat) * 100) / 100, lon = Math.round(parseFloat(body.lon) * 100) / 100;
  if (!id || !(lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180)) return null;
  const hex = (v) => (typeof v === 'string' && /^[0-9a-fA-F]{32,512}$/.test(v) ? v.toLowerCase() : null);
  const out = { id, lat, lon };
  if (body.tz != null) {
    const tz = String(body.tz);
    try { new Intl.DateTimeFormat('en-US', { timeZone: tz }); } catch { return null; }
    out.tz = tz;
  }
  if (body.start != null) out.start = hex(body.start);
  if (body.act != null) out.act = hex(body.act);
  if (body.region != null) out.region = ['kr', 'jp', 'other'].includes(body.region) ? body.region : 'other';
  if (body.lang != null) out.lang = ['ko', 'en', 'ja'].includes(body.lang) ? body.lang : 'ko';
  if (body.name != null) out.name = String(body.name).slice(0, 40);
  if (body.char != null) out.char = String(body.char).slice(0, 16);
  if (body.plan != null) out.plan = body.plan === 'plus' ? 'plus' : 'free';
  if (body.rain != null) out.rain = !!body.rain;
  return out;
}

export async function saveDevice(store, dev, now = new Date()) {
  const key = `dev:${dev.id}`;
  let old = null;
  try { old = await store.get(key, 'json'); } catch { /* fresh */ }
  const merged = { tz: 'Asia/Seoul', region: 'other', lang: 'ko', name: '', char: 'cat', plan: 'free', start: null, act: null, ...(old || {}), ...dev, at: now.getTime() };
  if (dev.start === null) merged.start = old?.start ?? null;   // a bad token in the body never drops a good one
  if (dev.act === null) merged.act = old?.act ?? null;
  await store.put(key, JSON.stringify(merged), { expirationTtl: DEV_TTL });
  return merged;
}

/**
 * The half-hourly pass: every Plus device with a push-to-start token gets its place's forecast (shared per ~1 km
 * cell); rain within the hour that the device has not been told about yet is pushed once. `forecastRaw(q)` gives
 * { scene, f } for a place. Returns counts.
 */
export async function runActivities(env, { forecastRaw, fetcher = fetch, now = new Date() }) {
  const store = env.DEVICES;
  const out = { devices: 0, started: 0, skipped: 0, errors: 0 };
  if (!store || !hasAPNs(env)) return out;
  const raws = new Map();
  const rawFor = async (dev) => {
    const ck = `${dev.lat},${dev.lon},${dev.region},${dev.lang}`;
    if (!raws.has(ck)) raws.set(ck, forecastRaw({ lat: dev.lat, lon: dev.lon, tz: dev.tz, region: dev.region, plan: 'plus', lang: dev.lang, name: dev.name, prev: null, outfitPrev: null, v: 2 }).catch((e) => ({ error: e })));
    return raws.get(ck);
  };
  let cursor;
  do {
    const page = await store.list({ prefix: 'dev:', cursor, limit: 200 });
    cursor = page.list_complete ? null : page.cursor;
    for (const k of page.keys) {
      let dev;
      try { dev = await store.get(k.name, 'json'); } catch { continue; }
      if (!dev) continue;
      out.devices++;
      if (dev.plan !== 'plus' || !dev.start || dev.rain === false) { out.skipped++; continue; }
      const raw = await rawFor(dev);
      if (!raw || raw.error) { out.errors++; continue; }
      const act = rainActivity(raw.f, { now, tz: dev.tz, lang: dev.lang });
      try {
        if (act && dev.key !== act.key) {
          // this rain has not been announced: once, then remember it until the rain is past
          const body = activityBody('start', { state: act.state, place: dev.name || '', char: dev.char, level: raw.scene?.level, now, end: act.end });
          const r = await sendLiveActivity(env, dev.start, body, { fetcher, now });
          if (r.ok) { out.started++; await store.put(k.name, JSON.stringify({ ...dev, key: act.key, until: act.end }), { expirationTtl: DEV_TTL }); }
          else { out.errors++; if (r.dead) await store.put(k.name, JSON.stringify({ ...dev, start: null }), { expirationTtl: DEV_TTL }); console.log('APNs start failed:', r.status, r.reason); }
        } else {
          out.skipped++;
          if (!act && dev.key && dev.until && dev.until < now.getTime()) await store.put(k.name, JSON.stringify({ ...dev, key: null, until: null }), { expirationTtl: DEV_TTL });
        }
      } catch (e) { out.errors++; console.log('activity failed:', e.message); }
    }
  } while (cursor);
  return out;
}
