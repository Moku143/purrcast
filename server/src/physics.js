// Feels-like temperature and dew point.

/** Feels-like °C the way KMA describes it: wind chill when cold and windy, heat index when hot, else the air temperature. */
export function feelsLike(t, rh, windMs) {
  if (t == null) return null;
  const v = (windMs ?? 0) * 3.6; // km/h
  if (t <= 10 && v >= 4.8) {
    return 13.12 + 0.6215 * t - 11.37 * Math.pow(v, 0.16) + 0.3965 * t * Math.pow(v, 0.16);
  }
  if (t >= 27 && rh != null && rh >= 40) {
    const f = t * 9 / 5 + 32;
    const hi = -42.379 + 2.04901523 * f + 10.14333127 * rh - 0.22475541 * f * rh - 0.00683783 * f * f
      - 0.05481717 * rh * rh + 0.00122874 * f * f * rh + 0.00085282 * f * rh * rh - 0.00000199 * f * f * rh * rh;
    return Math.max(t, (hi - 32) * 5 / 9);
  }
  return t;
}

/** Dew point °C (Magnus). */
export function dewPoint(t, rh) {
  if (t == null || rh == null || rh <= 0) return null;
  const a = 17.62, b = 243.12;
  const g = Math.log(rh / 100) + a * t / (b + t);
  return b * g / (a - g);
}

/** UV index under clouds, from the clear-sky value (cloud 0..100). */
export function uvUnderCloud(uvClear, cloud) {
  if (uvClear == null) return null;
  const c = Math.max(0, Math.min(1, (cloud ?? 0) / 100));
  return uvClear * (1 - 0.75 * Math.pow(c, 3.4));
}
