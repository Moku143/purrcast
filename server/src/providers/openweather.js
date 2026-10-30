// OpenWeather Air Pollution API — 미세먼지 · 초미세먼지 outside Korea (free plan, 1M calls a month, commercial use allowed;
// the app credits "Air quality © OpenWeather"). Needs OPENWEATHER_KEY.
//   /air_pollution: the current hour's components (pm10, pm2_5 in ㎍/㎥)
//   /air_pollution/forecast: hourly for 4 days → tomorrow's worst hour
//   /air_pollution/history: hourly readings between two unix times → today's hours so far (the day sheet's chart)

const BASE = 'https://api.openweathermap.org/data/2.5';
export const owNowUrl = (key, lat, lon) => `${BASE}/air_pollution?lat=${lat}&lon=${lon}&appid=${encodeURIComponent(key)}`;
export const owForecastUrl = (key, lat, lon) => `${BASE}/air_pollution/forecast?lat=${lat}&lon=${lon}&appid=${encodeURIComponent(key)}`;
export const owHistoryUrl = (key, lat, lon, start, end) => `${BASE}/air_pollution/history?lat=${lat}&lon=${lon}&start=${start}&end=${end}&appid=${encodeURIComponent(key)}`;
export const owOK = (json) => Array.isArray(json?.list) && json.list.length > 0;

const r0 = (v) => (Number.isFinite(v) ? Math.round(v) : null);

/** { pm10, pm25, at: Date } from the current reading. */
export function parseOwNow(json) {
  const it = json?.list?.[0];
  if (!it?.components) return null;
  return { pm10: r0(it.components.pm10), pm25: r0(it.components.pm2_5), at: new Date((it.dt || 0) * 1000) };
}

/** Tomorrow's highest PM10 and PM2.5 (㎍/㎥) in the place's day, from the hourly forecast. `dayKeyOf(t)` gives a day key. */
export function parseOwTomorrow(json, dayKeyOf, tomorrowKey) {
  let pm10 = null, pm25 = null;
  for (const it of json?.list || []) {
    if (dayKeyOf(new Date((it.dt || 0) * 1000)) !== tomorrowKey) continue;
    const a = r0(it.components?.pm10), b = r0(it.components?.pm2_5);
    if (a != null && (pm10 == null || a > pm10)) pm10 = a;
    if (b != null && (pm25 == null || b > pm25)) pm25 = b;
  }
  return pm10 == null && pm25 == null ? null : { pm10, pm25 };
}

/** Today's readings by local hour from the history (or forecast) list: [[hour, pm10, pm25]], one per hour, oldest first.
 *  `hourOf(t)` gives (dayKey, hour) in the place's time zone. */
export function parseOwHours(json, hourOf, todayKey) {
  const out = [];
  for (const it of json?.list || []) {
    const { key, h } = hourOf(new Date((it.dt || 0) * 1000));
    if (key !== todayKey) continue;
    const a = r0(it.components?.pm10), b = r0(it.components?.pm2_5);
    if (a == null && b == null) continue;
    if (out.length && out[out.length - 1][0] === h) continue;
    out.push([h, a, b]);
  }
  return out;
}
