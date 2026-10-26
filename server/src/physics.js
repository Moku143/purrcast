// Feels-like temperature and dew point.

import { strings } from './i18n.js';

/**
 * Feels-like °C the way KMA computes it (data.kma.go.kr → 체감온도):
 *  - winter (air ≤ 10 °C and wind ≥ 1.3 m/s): the JAG/TI wind-chill formula
 *  - summer (air ≥ 20 °C): the 2022 formula on the Stull wet-bulb temperature, so humidity counts
 *  - otherwise the air temperature itself
 */
export function feelsLike(t, rh, windMs) {
  if (t == null) return null;
  const w = windMs ?? 0;
  if (t <= 10 && w >= 1.3) {
    const v = w * 3.6; // km/h
    return 13.12 + 0.6215 * t - 11.37 * Math.pow(v, 0.16) + 0.3965 * t * Math.pow(v, 0.16);
  }
  if (t >= 20 && rh != null) {
    const r = Math.max(5, Math.min(100, rh));
    const tw = t * Math.atan(0.151977 * Math.sqrt(r + 8.313659)) + Math.atan(t + r) - Math.atan(r - 1.67633)
      + 0.00391838 * Math.pow(r, 1.5) * Math.atan(0.023101 * r) - 4.686035;
    return -0.2442 + 0.55399 * tw + 0.45535 * t - 0.0022 * tw * tw + 0.00278 * tw * t + 3.0;
  }
  return t;
}

/** 불쾌지수 (KMA temperature-humidity index): < 68 낮음 · 68–75 보통 · 75–80 높음 · 80+ 매우 높음 */
export function discomfortIndex(t, rh) {
  if (t == null || rh == null) return null;
  return 1.8 * t - 0.55 * (1 - rh / 100) * (1.8 * t - 26) + 32;
}

/**
 * How the air feels on the skin, in everyday Korean. Dew point says how much water is in the air
 * (NWS: ≤ 10 °C comfortable, 16–18 sticky, 18+ muggy, 21+ oppressive), but on a cold wet day a low
 * dew point still feels damp, so relative humidity and rain weigh in too.
 */
export function humidityWord({ temp, rh, dew, wet }, lang = 'ko') {
  const H = strings(lang).humidity;
  if (rh == null) return '';
  if (rh < 20) return H.veryDry;
  if (rh < 30) return H.dry;
  if (dew != null && dew >= 24) return H.verySticky;
  if (dew != null && dew >= 21) return H.sticky;
  if (dew != null && dew >= 18) return H.muggy;
  if (wet || rh >= 85) return temp != null && temp < 15 ? H.damp : H.humid;
  if (rh >= 70) return H.bitHumid;
  if (dew != null && dew < 10 && rh < 60) return H.crisp;
  return H.ok;
}

/**
 * Wind as people feel it (Beaufort, with KMA's everyday guidance: umbrellas turn around 7 m/s,
 * walking gets hard around 9–10 m/s, 강풍주의보 at 14 m/s).
 */
export function windWord(ms, lang = 'ko') {
  if (ms == null) return '';
  const W = strings(lang).wind;
  return W[ms < 0.5 ? 0 : ms < 1.6 ? 1 : ms < 3.4 ? 2 : ms < 5.5 ? 3 : ms < 8 ? 4 : ms < 10.8 ? 5 : ms < 13.9 ? 6 : 7];
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
