// Apple WeatherKit REST API — every region except Korea (Korea keeps 기상청; MET Norway is the fallback everywhere).
// https://developer.apple.com/documentation/weatherkitrestapi
// Auth: a JWT (ES256) signed with the WeatherKit key from developer.apple.com, 1 h long, cached in memory.
// Secrets: WEATHERKIT_KEY_ID (10 chars), WEATHERKIT_KEY_P8 (the .p8 file's text), APPLE_TEAM_ID;
// var WEATHERKIT_SERVICE_ID (the bundle id, default app.purrcast.ios).
// Attribution required: "Weather data provided by  Weather" + https://weatherkit.apple.com/legal-attribution.html
// Units (REST, fixed): °C · km/h · mm · metres · 0–1 fractions.

import { dayKey } from '../time.js';

export const WK_HOST = 'https://weatherkit.apple.com';
const DATASETS = 'currentWeather,forecastHourly,forecastDaily,forecastNextHour,weatherAlerts';

export function hasWeatherKit(env) {
  return !!(env?.WEATHERKIT_KEY_P8 && env?.WEATHERKIT_KEY_ID && env?.APPLE_TEAM_ID);
}

export function weatherKitUrl(lat, lon, { lang = 'en', tz = 'UTC', country = null } = {}) {
  const q = (v) => (Math.round(v * 10000) / 10000).toFixed(4).replace(/\.?0+$/, '');
  let u = `${WK_HOST}/api/v1/weather/${encodeURIComponent(lang)}/${q(lat)}/${q(lon)}?dataSets=${DATASETS}&timezone=${encodeURIComponent(tz)}`;
  if (country) u += `&countryCode=${encodeURIComponent(country)}`;   // needed for weatherAlerts
  return u;
}

// ---- JWT (ES256 via WebCrypto: the Worker has no node:crypto) ----

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

const TOKENS = new Map();   // kid → { jwt, exp (ms) }
export function resetWeatherKitTokens() { TOKENS.clear(); }

/** A signed WeatherKit JWT, reused until ~5 minutes before it expires. */
export async function weatherKitToken(env, { now = new Date() } = {}) {
  const kid = env.WEATHERKIT_KEY_ID, team = env.APPLE_TEAM_ID, sub = env.WEATHERKIT_SERVICE_ID || 'app.purrcast.ios';
  const ck = `${kid}|${team}|${sub}`;
  const hit = TOKENS.get(ck);
  if (hit && hit.exp - now.getTime() > 5 * 60000) return hit.jwt;
  const iat = Math.floor(now.getTime() / 1000), exp = iat + 3600;
  const header = b64url(utf8(JSON.stringify({ alg: 'ES256', kid, id: `${team}.${sub}` })));
  const payload = b64url(utf8(JSON.stringify({ iss: team, iat, exp, sub })));
  const key = await crypto.subtle.importKey('pkcs8', pemToPkcs8(env.WEATHERKIT_KEY_P8), { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, utf8(`${header}.${payload}`));   // raw r||s, as JWS wants
  const jwt = `${header}.${payload}.${b64url(sig)}`;
  TOKENS.set(ck, { jwt, exp: exp * 1000 });
  return jwt;
}

// ---- parsing ----

const r1 = (v) => Math.round(v * 10) / 10;
const pct = (v) => (v == null ? null : Math.round(v * 100));          // 0–1 → %
const ms = (v) => (v == null ? null : Math.round((v / 3.6) * 10) / 10);   // km/h → m/s
const SEVERITY = { extreme: 3, severe: 2, moderate: 1, minor: 0, unknown: 0 };
/** WeatherKit's uvIndex is already under the forecast sky; scene.js applies physics.uvUnderCloud, so undo it here. */
function uvClearFrom(uv, cloud) {
  if (uv == null) return null;
  const c = Math.max(0, Math.min(1, (cloud ?? 0) / 100));
  return uv / (1 - 0.75 * Math.pow(c, 3.4));
}

/** precipitationType clear | precipitation | rain | snow | sleet | hail | mixed → none | rain | snow | sleet */
function ptype(v) {
  switch (v) {
    case 'snow': return 'snow';
    case 'sleet': case 'hail': case 'mixed': return 'sleet';
    case 'rain': case 'precipitation': return 'rain';
    default: return 'none';
  }
}
/** conditionCode (Clear, Rain, HeavySnow, Thunderstorms, FreezingDrizzle, …) → a precipitation type. */
function codeType(code) {
  const c = String(code || '');
  if (/Snow|Flurries|Blizzard/.test(c)) return 'snow';
  if (/Sleet|Freezing|Hail|Wintry/.test(c)) return 'sleet';
  if (/Rain|Drizzle|Showers|Thunderstorm/.test(c)) return 'rain';
  return 'none';
}

/** WeatherKit JSON → { points, updated, now, daily, minutes, warnings } (the normalized forecast of providers/met.js). */
export function parseWeatherKit(json, tz = 'UTC') {
  const hours = json?.forecastHourly?.hours ?? [];
  const points = [];
  for (const h of hours) {
    if (h.temperature == null) continue;
    const mm = r1(h.precipitationAmount ?? 0);
    const code = h.conditionCode || '';
    let type = ptype(h.precipitationType);
    if (type === 'none' && mm > 0) type = codeType(code) === 'none' ? 'rain' : codeType(code);
    if (mm <= 0) type = 'none';   // a type with no amount this hour is dry (same rule as MET)
    const chance = pct(h.precipitationChance);
    points.push({
      t: new Date(h.forecastStart), step: 1, source: 'apple',
      temp: h.temperature,
      rh: pct(h.humidity),
      dew: h.temperatureDewPoint ?? null,
      wind: ms(h.windSpeed),
      gust: ms(h.windGust),
      dir: h.windDirection ?? null,
      cloud: pct(h.cloudCover),
      fog: (h.visibility != null && h.visibility < 1000) || /Fog|Haze/.test(code),
      vis: h.visibility ?? null,
      uvClear: uvClearFrom(h.uvIndex, pct(h.cloudCover)),
      mm,
      pop: chance ?? (mm > 0 ? 70 : 0),
      popEstimated: chance == null,
      type,
      thunder: /Thunderstorm/.test(code),
      symbol: code,
    });
  }
  points.sort((a, b) => a.t - b.t);

  const c = json?.currentWeather;
  let now = null;
  if (c && c.temperature != null) {
    const mm = r1(c.precipitationIntensity ?? 0);   // mm/h now
    const t = codeType(c.conditionCode);
    now = {
      t: c.asOf ? new Date(c.asOf) : null,
      temp: c.temperature, rh: pct(c.humidity), wind: ms(c.windSpeed), dir: c.windDirection ?? null,
      mm, type: mm > 0 && t === 'none' ? 'rain' : mm > 0 ? t : 'none',
    };
  }

  const daily = {};
  for (const d of json?.forecastDaily?.days ?? []) {
    if (!d.forecastStart) continue;
    const k = dayKey(new Date(d.forecastStart), tz);
    daily[k] = { lo: d.temperatureMin ?? null, hi: d.temperatureMax ?? null };
  }

  let minutes = null;
  const nh = json?.forecastNextHour;
  if (Array.isArray(nh?.minutes) && nh.minutes.length) {
    minutes = nh.minutes.slice(0, 60).map((m) => Math.round((m.precipitationIntensity ?? 0) * 100) / 100);
  }

  const warnings = (json?.weatherAlerts?.alerts ?? []).map((a) => ({
    name: a.description || [a.eventSource, a.severity].filter(Boolean).join(' ') || 'Weather alert',
    severity: SEVERITY[a.severity] ?? 0,
    until: a.expireTime ?? null,   // a kept (free) forecast drops an alert once it has expired
  })).sort((a, b) => b.severity - a.severity);

  const meta = c?.metadata ?? json?.forecastHourly?.metadata;
  const updated = meta?.readTime ? new Date(meta.readTime) : c?.asOf ? new Date(c.asOf) : null;
  return { points, updated, now, daily, minutes, warnings, minutesStart: nh?.forecastStart ? new Date(nh.forecastStart) : null };
}

/** A parsed forecast as JSON for storage (KV), and back. Dates travel as ISO strings. */
export function packWeatherKit(w) {
  return JSON.stringify({ ...w, points: w.points.map((p) => ({ ...p, t: p.t.toISOString() })), updated: w.updated?.toISOString() ?? null,
    now: null, minutes: null, minutesStart: null });
}
export function unpackWeatherKit(json) {
  if (!json?.points?.length) return null;
  return { ...json, points: json.points.map((p) => ({ ...p, t: new Date(p.t) })), updated: json.updated ? new Date(json.updated) : null };
}
