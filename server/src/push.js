// Short alerts (Plus) as Live Activity pushes: the app registers its device (a push-to-start token, iOS 17.2+);
// every half hour the Worker's cron looks at each device's place and starts a short activity over APNs — on the
// Dynamic Island / lock screen for a few minutes (DISMISS_AFTER), with the alert banner — for, once each:
//   · an official warning in force (기상청 특보, 황사경보 among them) and 에어코리아's 미세먼지 주의보 / 경보
//   · rain, snow or sleet an hour before it starts, and again when it starts
//   · 미세먼지 climbing to 나쁨 or 매우 나쁨 (not at night)
// At most one per pass, the most urgent first, so a busy day never piles them up. Needs an APNs key: APNS_KEY (the
// .p8 text), APNS_KEY_ID, APPLE_TEAM_ID.
//
// Device records live in the DEVICES KV namespace: dev:<id> → { id, start (push-to-start token), act, lat, lon, tz,
// region, lang, name, char, plan, rain (비 오기 전 on), alert (기상특보 on), sent: { eventKey: until ms }, dustG (the
// 미세먼지 step last seen), at (ms) }.

import { strings, LANGS } from './i18n.js';
import { local, dayKey } from './time.js';
import { warningKind } from './rules.js';

export const APNS_HOST = 'https://api.push.apple.com';
export const BUNDLE_ID = 'app.purrcast.ios';
export const ATTRIBUTES_TYPE = 'RainActivityAttributes';
const MAX_HOURS = 8;   // ActivityKit ends an activity after 8 hours anyway
export const WITHIN_HOURS = 1;       // the alert comes when the rain is this close
export const DISMISS_AFTER = 5 * 60;  // seconds the activity stays on the island / lock screen: in and out
const QUIET = [22, 7];               // 미세먼지 waits out the night (the place's clock); warnings and rain do not

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
  if (body.lang != null) out.lang = LANGS.includes(body.lang) ? body.lang : 'ko';
  if (body.name != null) out.name = String(body.name).slice(0, 40);
  if (body.char != null) out.char = String(body.char).slice(0, 16);
  if (body.plan != null) out.plan = body.plan === 'plus' ? 'plus' : 'free';
  if (body.rain != null) out.rain = !!body.rain;
  if (body.alert != null) out.alert = !!body.alert;
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

const KIND_ICON = { typhoon: 'wind', wind: 'wind', rain: 'raincloud', snow: 'snowflake', heat: 'thermo_hot', cold: 'thermo_cold', dry: 'sun_strong', dust: 'mask' };

/** A short alert's content-state: no rain bar (start and end are the few minutes it is shown) */
function shortState(title, sub, icon, what, now, tz) {
  const t = Math.floor(now.getTime() / 1000);
  return { title, sub, icon, what, falling: false, mm: 0, start: t, end: t + DISMISS_AFTER, endHour: local(now, tz).h };
}

/**
 * What is worth a short alert for this device now, most urgent first (경보 · rain · 주의보 · 미세먼지 주의보 / 경보 ·
 * 미세먼지 climbing): [{ key, keep (ms before the same key may be
 * said again), state }]. `raw` is { scene, f } for its place; `dev` its record (lang, tz, rain / alert toggles, dustG).
 */
export function alertEvents(raw, dev, { now }) {
  const S = strings(dev.lang || 'ko'), tz = dev.tz || 'Asia/Seoul', out = [];
  const f = raw?.f || {}, scene = raw?.scene || {};
  const day = 24 * 3600000;
  if (dev.alert !== false) {
    // official warnings in force (기상청 특보 — 황사경보 among them): each once, again only a day after it has gone
    for (const w of f.warnings || []) {
      const k = warningKind(w.name), name = S.warning(w.name);
      const yellow = k === 'dust' && /황사|dust|黄砂/i.test(String(w.name));
      const sub = scene.alert?.name === name && scene.alert?.note ? scene.alert.note
        : k === 'dust' ? (yellow ? S.alert.yellowDust : S.alert.fineDust) : S.alert.takeCare;
      out.push({ key: `w:${w.name}`, keep: day, rank: (w.severity ?? 1) >= 2 ? 0 : 2, state: shortState(name, sub, KIND_ICON[k] ?? 'exclaim', yellow ? 'yellow' : 'alert', now, tz) });
    }
    // 에어코리아's 미세먼지 / 초미세먼지 주의보 · 경보
    const al = f.dust?.alarm;
    if (al) {
      const [t, sub] = String(al.kind === 'warning' ? S.dust.warning : S.dust.watch).split(/ · |・/);
      const title = al.item === 'PM25' && S.dust.pm25 !== S.dust.pm10 ? t.replace(S.dust.pm10, S.dust.pm25) : t;
      out.push({ key: `a:${al.item}:${al.kind}`, keep: day, rank: 3, state: shortState(title, sub || '', 'mask', 'dust', now, tz) });
    }
  }
  if (dev.rain !== false) {
    // rain, snow or sleet: an hour before it starts, and again when it starts
    const act = rainActivity(f, { now, tz, lang: dev.lang || 'ko' });
    if (act) out.push({ key: `p:${act.key}:${act.falling ? 'now' : 'soon'}`, keep: Math.max(act.end - now.getTime(), 0) + 3600000, rank: 1, state: act.state });
  }
  if (dev.alert !== false) {
    // 미세먼지 climbing to 나쁨 or worse: once per step it reaches (a 황사 warning already said it; not at night)
    const d = scene.dust, g = d?.grade;
    const h = local(now, tz).h, quiet = h >= QUIET[0] || h < QUIET[1];
    if (g != null && g >= 2 && g > (dev.dustG ?? 0) && !quiet && !out.some((e) => e.state.what === 'yellow' || e.state.what === 'dust')) {
      const fine = (d.pm25Grade ?? -1) > (d.pm10Grade ?? -1);
      const note = String(S.dust.note[g] || '').split(/ · |・/);
      out.push({ key: `d:${dayKey(now, tz)}:${g}`, keep: day, rank: 4, dust: g,
        state: shortState(`${fine ? S.dust.pm25 : S.dust.pm10} ${S.dust.grade[g]}`, note[1] || note[0] || '', 'mask', 'dust', now, tz) });
    }
  }
  // 경보 first, then the rain (it will not wait), then 주의보, 미세먼지 주의보 / 경보, 미세먼지 climbing
  return out.sort((a, b) => a.rank - b.rank);
}

/** What a rain alert's content says, for telling whether a newer forecast changed it */
const said = (s) => s && [s.title, s.sub, s.icon, s.falling, s.mm, s.endHour].join('|');

/**
 * The alert on the phone now (`dev.live`: the newest one started, { key, kind: 'rain' | 'short', at, state }) once the
 * phone has sent its own token (`dev.act`): a rain alert follows the forecast — updated when its words change (the
 * rain's end moving, the amount, rain now instead of soon) and ended when the rain is over; a short alert (a warning,
 * 미세먼지) is ended once its few minutes are up. Returns { event: 'update' | 'end', state, end? } or null.
 */
export function liveStep(dev, raw, { now }) {
  const live = dev.live;
  if (!live || !dev.act) return null;
  const t = now.getTime();
  if (live.kind !== 'rain') return t - live.at >= DISMISS_AFTER * 1000 ? { event: 'end', state: live.state } : null;
  const act = dev.rain === false ? null : rainActivity(raw?.f || {}, { now, tz: dev.tz || 'Asia/Seoul', lang: dev.lang || 'ko' });
  if (!act || act.end <= t) return { event: 'end', state: live.state };
  return said(act.state) === said(live.state) ? null : { event: 'update', state: act.state, end: act.end };
}

/**
 * The half-hourly pass: every Plus device with a push-to-start token gets its place's forecast (shared per ~1 km
 * cell); of what is worth an alert there, the most urgent one it has not been told yet is pushed — one per pass.
 * `forecastRaw(q)` gives { scene, f } for a place. Returns counts.
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
  const t = now.getTime();
  let cursor;
  do {
    const page = await store.list({ prefix: 'dev:', cursor, limit: 200 });
    cursor = page.list_complete ? null : page.cursor;
    for (const k of page.keys) {
      let dev;
      try { dev = await store.get(k.name, 'json'); } catch { continue; }
      if (!dev) continue;
      out.devices++;
      if (dev.plan !== 'plus' || !dev.start || (dev.rain === false && dev.alert === false)) { out.skipped++; continue; }
      const raw = await rawFor(dev);
      if (!raw || raw.error) { out.errors++; continue; }
      try {
        const sent = Object.fromEntries(Object.entries(dev.sent || {}).filter(([, until]) => until > t));
        const events = alertEvents(raw, dev, { now });
        // a warning still in force stays "said" for as long as it lasts (and a day after)
        for (const e of events) if (sent[e.key] && e.key.startsWith('w:')) sent[e.key] = Math.max(sent[e.key], t + e.keep);
        const next = events.find((e) => !sent[e.key]);
        const g = raw.scene?.dust?.grade;
        const h = local(now, dev.tz || 'Asia/Seoul').h, quiet = h >= QUIET[0] || h < QUIET[1];
        // the step last seen: it goes down at any hour, up only when it could be said (so a climb at night is told in the morning)
        let dustG = dev.dustG ?? 0;
        if (g != null && (g < dustG || !quiet)) dustG = g;
        let changed = dustG !== (dev.dustG ?? 0) || Object.keys(sent).length !== Object.keys(dev.sent || {}).length;
        // the alert already on the phone: kept in step with the forecast, or taken away
        let live = dev.live || null, act = dev.act || null;
        const step = liveStep(dev, raw, { now });
        // rain now after "rain soon": the alert on the phone says so (an update), no second alert
        const nextRain = next && next.key.startsWith('p:') ? next : null;
        if (step?.event === 'update' || (nextRain && live?.kind === 'rain' && act && step?.event !== 'end')) {
          const st = step?.state || nextRain.state;
          const body = activityBody('update', { state: st, now, end: step?.end ?? nextRain.state.end * 1000 });
          const r = await sendLiveActivity(env, act, body, { fetcher, now });
          if (r.ok) { live = { ...live, state: st }; if (nextRain) sent[nextRain.key] = t + nextRain.keep; changed = true; }
          else if (r.dead) { live = null; act = null; changed = true; }
        } else if (step?.event === 'end') {
          await sendLiveActivity(env, act, activityBody('end', { state: step.state, now }), { fetcher, now });
          live = null; act = null; changed = true;
        }
        const pending = events.find((e) => !sent[e.key]);
        if (pending) {
          const next = pending;
          // a new alert: the one before it goes first, so they never pile up
          if (live && act) await sendLiveActivity(env, act, activityBody('end', { state: live.state, now }), { fetcher, now });
          const body = activityBody('start', { state: next.state, place: dev.name || '', char: dev.char, level: raw.scene?.level, now });
          const r = await sendLiveActivity(env, dev.start, body, { fetcher, now });
          if (r.ok) {
            out.started++; sent[next.key] = t + next.keep; changed = true;
            // its own token comes from the phone (woken for it); the old one belonged to the alert just ended
            live = { key: next.key, kind: next.key.startsWith('p:') ? 'rain' : 'short', at: t, state: next.state }; act = null;
          }
          else {
            out.errors++; console.log('APNs start failed:', r.status, r.reason);
            if (r.dead) { dev.start = null; changed = true; }
            if (next.dust) dustG = dev.dustG ?? 0;   // not told: try again next pass
          }
        } else out.skipped++;
        if (changed) {
          const { key, until, ...rest } = dev;   // the old single-rain memory is replaced by `sent`
          // the phone may have sent a new alert's token while this pass ran: that one wins
          let latest = null;
          try { latest = await store.get(k.name, 'json'); } catch { /* keep ours */ }
          if (latest?.act && latest.act !== dev.act) act = latest.act;
          await store.put(k.name, JSON.stringify({ ...rest, sent, dustG, live, act }), { expirationTtl: DEV_TTL });
        }
      } catch (e) { out.errors++; console.log('activity failed:', e.message); }
    }
  } while (cursor);
  return out;
}
