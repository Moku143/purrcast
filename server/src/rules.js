// The design kit's judgement rules (kit README §1, rules.json), in one place.
// Every function that returns words takes a trailing `lang` ('ko' default, or a strings() object) — see i18n.js.

import { strings } from './i18n.js';

/** Outfit level 0…9 from the feels-like °C, with ±1° hysteresis against the previous level. */
const UPPER = [Infinity, 32.5, 27.5, 22.5, 19.5, 16.5, 11.5, 8.5, 4.5, -9.5];
export function level(feels, prev = null) {
  let lv = 9;
  for (let i = 1; i < UPPER.length; i++) if (feels > UPPER[i]) { lv = i - 1; break; }
  if (feels > 32.5) lv = 0;
  if (prev != null && Math.abs(prev - lv) === 1) {
    const edge = UPPER[Math.max(prev, lv)];
    if (Math.abs(feels - edge) < 1.0) return prev;
  }
  return lv;
}

/** Rain per hour in everyday terms (이슬비 · 약한 비 · 보통 비 · 강한 비 · 매우 강한 비), and what it means for an umbrella */
const rainStep = (mm) => (mm >= 30 ? 4 : mm >= 15 ? 3 : mm >= 3 ? 2 : mm >= 1 ? 1 : 0);
export const rainKind = (mm, lang = 'ko') => strings(lang).rainKind[rainStep(mm)];
export const rainKindNote = (mm, lang = 'ko') => strings(lang).rainKindNote[rainStep(mm)];
/** A day's or 12 h total: 조금 · 보통 · 많음 · 매우 많음 */
export const rainAmountWord = (mm, lang = 'ko') => strings(lang).rainAmount[mm >= 50 ? 3 : mm >= 20 ? 2 : mm >= 5 ? 1 : 0];
/** Feels-like in eight steps: 매우 추움 … 매우 더움 */
export const feelsWord = (c, lang = 'ko') => strings(lang).feels[c <= -10 ? 0 : c <= 0 ? 1 : c <= 8 ? 2 : c <= 16 ? 3 : c <= 22 ? 4 : c <= 27 ? 5 : c <= 32 ? 6 : 7];

/** Pixel icon for one hour. */
export function icon(p, night) {
  if (p.thunder) return 'lightning';
  if (p.mm > 0 || p.type !== 'none') return p.type === 'snow' || p.type === 'sleet' ? 'snowflake' : 'raincloud';
  const c = p.cloud ?? 0;
  if (c >= 70) return 'cloud';
  if (c >= 30) return night ? 'cloud' : 'partly_cloudy';
  return night ? 'moon' : 'sun';
}

const ICON_RANK = { lightning: 5, snowflake: 4, raincloud: 3, cloud: 2, partly_cloudy: 1, sun: 0, moon: 0 };
export const worse = (a, b) => (ICON_RANK[a] >= ICON_RANK[b] ? a : b);

export const cover = (cloud) => (cloud == null ? 'partly' : cloud >= 70 ? 'overcast' : cloud >= 30 ? 'partly' : 'clear');

export function precip(p) {
  if (!(p.mm > 0) && p.type === 'none') return 'none';
  if (p.type === 'snow') return p.mm >= 3 ? 'heavysnow' : 'snow';
  if (p.type === 'sleet') return 'sleet';
  return p.mm >= 6 ? 'heavy' : 'rain';
}

/** One auxiliary effect (the design shows at most one): fog › wind › heat › frost. */
export function aux({ now, feels, night }) {
  if (now.fog) return 'fog';
  if ((now.wind ?? 0) >= 8 || (now.gust ?? 0) >= 14) return 'wind';
  if ((!night && feels >= 33) || (night && feels >= 25)) return 'heat';
  if (feels <= -10) return 'frost';
  return 'none';
}

export function condition({ pr, cov, thunder, auxKind, night, feels, lang }, l = lang ?? 'ko') {
  const C = strings(l).cond;
  const base = thunder ? C.thunder : pr === 'heavy' ? C.heavy : pr === 'rain' ? C.rain : pr === 'snow' ? C.snow : pr === 'heavysnow' ? C.heavysnow : pr === 'sleet' ? C.sleet
    : cov === 'clear' ? C.clear : cov === 'partly' ? C.partly : C.overcast;
  const extra = auxKind === 'wind' ? (pr === 'none' ? C.wind : C.windStrong)
    : auxKind === 'fog' ? C.fog
    : auxKind === 'heat' ? (night ? C.night : C.heat)
    : auxKind === 'frost' ? C.frost : '';
  return extra ? `${base} · ${extra}` : base;
}

/** Umbrella: raining now → umbrella; starts within 12 h or 12 h chance ≥ 30 % → bag; 10–29 % → think. */
export function rainState({ nowWet, startIn, maxPop }) {
  if (nowWet) return 'umbrella';
  if (startIn != null && startIn <= 12) return 'bag';
  if (maxPop >= 30) return 'bag';
  if (maxPop >= 10) return 'think';
  return 'none';
}

const B = (kind, tone, icon, text) => ({ kind, tone, icon, text });

/**
 * One bubble at a time, by the design's priority:
 * 1 official warning · 2 own call: thunder / heavy rain / heavy snow · 3 rain starting within 2 h ·
 * 4 strong wind / thick fog · 5 extreme feels-like · 6 temperature swing / umbrella dilemma / umbrella packed.
 * Rain timing is the clock window (15~17시 비 예정), never a countdown.
 */
export function bubble(c, lang = c.lang ?? 'ko') {
  const S = strings(lang), T = S.bubble;
  const { warnings, nowWet, nowPr, thunder, startIn, wind, fog, feels, night, swing, maxPop, rain, snowNext } = c;
  if (warnings?.length) {
    const w = warnings[0].name;   // the KMA name (or Apple's own description): icons are chosen from it, the text is its translation
    const k = warningKind(w);
    const ic = k === 'typhoon' || k === 'wind' ? 'wind' : k === 'rain' ? 'raincloud' : k === 'snow' ? 'snowflake'
      : k === 'heat' ? 'thermo_hot' : k === 'cold' ? 'thermo_cold' : k === 'dry' ? 'sun_strong' : 'exclaim';
    return B('shout', 'coral', ic, S.warning(w));
  }
  if (thunder) return B('shout', 'coral', 'lightning', T.thunder);
  if (nowPr === 'heavy') return B('shout', 'sky', 'umbrella', T.downpour);
  if (nowPr === 'heavysnow') return B('speech', 'sky', 'snowflake', T.heavysnow);
  const what = snowNext ? S.what.snow : S.what.rain;
  if (!nowWet && startIn != null && startIn <= 2) {
    return B('speech', 'sky', snowNext ? 'snowflake' : 'umbrella_closed', S.expect(c.when, what));
  }
  if (wind) return B('speech', 'sky', 'wind', nowWet ? (nowPr === 'snow' || nowPr === 'heavysnow' ? T.blizzard : T.windrain) : T.windy);
  if (fog) return B('speech', 'white', 'cloud', T.fog);
  if (!night && feels >= 33) return B('shout', 'coral', 'thermo_hot', T.heat);
  if (night && feels >= 25) return B('speech', 'night', 'sweat', T.tropical);
  if (feels <= -10) return B('shout', 'sky', 'thermo_cold', T.cold);
  if (nowWet) return nowPr === 'snow' || nowPr === 'heavysnow' ? B('speech', night ? 'night' : 'sky', 'snowman', T.snow) : nowPr === 'sleet' ? B('speech', 'sky', 'umbrella', T.sleet) : B('speech', 'sky', 'umbrella', T.rain);
  if (startIn != null && startIn <= 12) return B('speech', 'sky', snowNext ? 'snowflake' : 'umbrella_closed', S.expect(c.when, what));
  if (swing >= 10) return B('speech', 'night', 'daynight', T.swing);
  if (rain === 'think') return B('thought', 'sky', 'umbrella', '');
  if (rain === 'bag' && maxPop >= 30) return B('speech', 'sky', 'umbrella_closed', T.umbrella);
  return null;
}

/**
 * When rain (or snow) is expected, as the hours people plan around: "15~17시" (first to last wet hour),
 * "15시쯤" when it is one hour, "내일 7~9시" when it starts tomorrow. Always "… 비 예정", never a promise.
 */
export function whenWord(startH, endH, tomorrow, lang = 'ko') {
  if (startH == null) return '';
  return strings(lang).when(startH, endH, tomorrow);
}

/** "저녁 비!" style words for rain 6–12 h away. */
export function partOfDay(h, tomorrow, lang = 'ko') {
  const S = strings(lang);
  const part = S.partOfDay[h >= 5 && h < 12 ? 'morning' : h >= 12 && h < 17 ? 'afternoon' : h >= 17 && h < 21 ? 'evening' : 'night'];
  return tomorrow ? S.partTomorrow(part) : part;
}

/** WHO / KMA UV index scale: 0–2 낮음 · 3–5 보통 · 6–7 높음 · 8–10 매우 높음 · 11+ 위험 */
export function uvNote(uv, lang = 'ko') {
  const U = strings(lang).uv;
  if (uv == null) return U.none;
  return uv <= 2 ? U.low : uv <= 5 ? U.moderate : uv <= 7 ? U.high : uv <= 10 ? U.veryHigh : U.extreme;
}

/**
 * What a warning is about, from its name: KMA's Korean names, and the English / Japanese words Apple WeatherKit
 * alerts use (their description passes through untranslated). Unknown → 'other'.
 */
export function warningKind(name) {
  const w = String(name || '');
  if (/태풍|typhoon|hurricane|tropical (storm|cyclone)|台風/i.test(w)) return 'typhoon';
  if (/대설|snow|blizzard|ice storm|winter storm|大雪|暴風雪/i.test(w)) return 'snow';
  if (/호우|rain|flood|大雨|洪水/i.test(w)) return 'rain';
  if (/강풍|풍랑|wind|gale|storm|強風|暴風|波浪/i.test(w)) return 'wind';
  if (/폭염|heat|高温|猛暑/i.test(w)) return 'heat';
  if (/한파|cold|freez|frost|wind chill|低温|寒波|霜/i.test(w)) return 'cold';
  if (/건조|dry|fire weather|red flag|乾燥/i.test(w)) return 'dry';
  if (/황사|미세먼지|dust|smoke|air quality|黄砂/i.test(w)) return 'dust';
  return 'other';
}

/**
 * The line under the character when an official warning is in force: the warning's name and what it means
 * today, in one short clause from the forecast. "대설주의보 · 오늘 6cm, 18시쯤 그칠 예보".
 */
export function alertNote(name, c, lang = c.lang ?? 'ko') {
  const S = strings(lang), A = S.alert, sep = S.sep;
  const { total, pr, nowWet, when, endH, hi, lo, gust, rh } = c;   // `name` is the KMA name (or Apple's description); `when` already in this language
  const end = endH == null ? '' : S.stopAt(endH);
  const k = warningKind(name);
  if (k === 'snow') return [total ? A.todayCm(total) : '', nowWet ? end : (when ? S.expect(when, S.what.snow) : '')].filter(Boolean).join(sep) || A.icy;
  if (k === 'rain') return [total ? A.todayMm(total, rainAmountWord(total, S)) : '', nowWet ? end : (when ? S.expect(when, S.what.rain) : '')].filter(Boolean).join(sep) || A.heavyRain;
  if (k === 'typhoon') return [A.windRain, gust ? A.gust(gust) : '', A.takeCare].filter(Boolean).join(sep);
  if (k === 'wind') return [gust ? A.gust(gust) : A.veryWindy, A.takeCare].join(sep);
  if (k === 'heat') return A.heat(hi);
  if (k === 'cold') return A.cold(lo);
  if (k === 'dry') return [rh == null ? '' : A.humidity(rh), A.fire].filter(Boolean).join(sep);
  if (k === 'dust') return A.mask;
  return /snow|sleet/.test(pr) ? A.icy : A.takeCare;
}
