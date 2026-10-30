// The design kit's judgement rules (kit README §1, rules.json), in one place.
// Every function that returns words takes a trailing `lang` ('ko' default, or a strings() object) — see i18n.js.

import { strings } from './i18n.js';
import { gradePM10, gradePM25, gradePM10WHO, gradePM25WHO } from './providers/airkorea.js';

/** Outfit 0…14 from the feels-like °C (the app's fifteen outfits, scene field `outfit`), with ±1° hysteresis
 *  against the outfit shown last time. The usual Korean 기온별 옷차림 bands, split finer:
 *  0: 35°+ · 1: 33–34 · 2: 28–32 · 3: 23–27 · 4: 20–22 · 5: 18–19 · 6: 16–17 · 7: 12–15 · 8: 9–11 · 9: 6–8
 *  10: 3–5 · 11: 0–2 · 12: −4…−1 · 13: −9…−5 · 14: −10° and below */
export const OUTFITS = 15;
const OUTFIT_UPPER = [Infinity, 34.5, 32.5, 27.5, 22.5, 19.5, 17.5, 15.5, 11.5, 8.5, 5.5, 2.5, -0.5, -4.5, -9.5];
export function outfit(feels, prev = null) { return banded(OUTFIT_UPPER, feels, prev); }

/** The old ten-outfit level 0…9 (scene field `level`), still sent for app builds from before the fifteen outfits.
 *  12–16° is jacket / trench weather (a knit alone is for 16–17°), 5–9° a coat. */
const UPPER = [Infinity, 32.5, 27.5, 22.5, 19.5, 17.5, 15.5, 9.5, 4.5, -9.5];
export function level(feels, prev = null) { return banded(UPPER, feels, prev); }

function banded(upper, feels, prev) {
  let lv = upper.length - 1;
  for (let i = 1; i < upper.length; i++) if (feels > upper[i]) { lv = i - 1; break; }
  if (prev != null && Math.abs(prev - lv) === 1) {
    const edge = upper[Math.max(prev, lv)];
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
  if (p.mm > 0 || p.type !== 'none') return p.type === 'snow' ? 'snowflake' : p.type === 'sleet' ? 'sleet' : 'raincloud';
  const c = p.cloud ?? 0;
  if (c >= 70) return 'cloud';
  if (c >= 30) return night ? 'cloud' : 'partly_cloudy';
  return night ? 'moon' : 'sun';
}

const ICON_RANK = { lightning: 6, snowflake: 5, sleet: 4, raincloud: 3, cloud: 2, partly_cloudy: 1, sun: 0, moon: 0 };
export const worse = (a, b) => (ICON_RANK[a] >= ICON_RANK[b] ? a : b);

export const cover = (cloud) => (cloud == null ? 'partly' : cloud >= 70 ? 'overcast' : cloud >= 30 ? 'partly' : 'clear');

export function precip(p) {
  if (!(p.mm > 0) && p.type === 'none') return 'none';
  if (p.type === 'snow') return p.mm >= 3 ? 'heavysnow' : 'snow';
  if (p.type === 'sleet') return 'sleet';
  return p.mm >= 6 ? 'heavy' : 'rain';
}

/** How thick the fog is, for the picture: 0 none · 1 mist (옅은 안개) · 2 fog · 3 thick fog (짙은 안개).
 * From visibility (Apple: < 3 km · < 1 km · < 200 m) or MET's fog area (≥ 25 · 50 · 80 %); a fog symbol alone is 2. */
export function fogLevel(p) {
  let l = 0;
  if (p.vis != null) l = Math.max(l, p.vis < 200 ? 3 : p.vis < 1000 ? 2 : p.vis < 3000 ? 1 : 0);
  if (p.fogPct != null) l = Math.max(l, p.fogPct >= 80 ? 3 : p.fogPct >= 50 ? 2 : p.fogPct >= 25 ? 1 : 0);
  if (p.fog && l < 2) l = 2;
  return l;
}

/** One auxiliary effect (the design shows at most one): fog › wind › heat › frost › dust (미세먼지 나쁨 or worse). */
export function aux({ now, feels, night, dust }) {
  if (now.fog) return 'fog';
  if ((now.wind ?? 0) >= 8 || (now.gust ?? 0) >= 14) return 'wind';
  if ((!night && feels >= 33) || (night && feels >= 25)) return 'heat';
  if (feels <= -10) return 'frost';
  if (dust != null && dust >= 2) return 'dust';
  return 'none';
}

/** The scene's 미세먼지 block from a provider reading: values, each grade, the worse grade, the card's note, tomorrow.
 *  The note: a 황사 warning from 기상청 › 에어코리아 경보 / 주의보 › the grade's own line. */
export function dustBlock(d, warnings, S) {
  if (!d || (d.pm10 == null && d.pm25 == null)) return null;
  const T = S.dust;
  // Korea: 환경부's four steps; elsewhere the same four on WHO's values (the app's scale card says which)
  const [G10, G25] = d.src === 'airkorea' ? [gradePM10, gradePM25] : [gradePM10WHO, gradePM25WHO];
  const g10 = G10(d.pm10), g25 = G25(d.pm25);
  const grade = Math.max(g10 ?? 0, g25 ?? 0);
  const yellow = (warnings || []).some((w) => /황사|yellow dust|黄砂/i.test(w.name || ''));
  const alarmLine = d.alarm?.kind === 'warning' ? T.warning : d.alarm?.kind === 'watch' ? T.watch : null;
  // each row's own line: 황사 on the 미세먼지 row, an 경보 / 주의보 on its item's row, else the grade's line
  const note10 = yellow ? T.yellow : alarmLine && d.alarm.item !== 'PM25' ? alarmLine : g10 == null ? '' : T.note[g10];
  const note25 = alarmLine && d.alarm.item === 'PM25' ? alarmLine : g25 == null ? '' : T.note[g25];
  const note = yellow ? T.yellow : alarmLine ? alarmLine : T.note[grade];   // the one line for the worse of the two
  const out = { pm10: d.pm10, pm25: d.pm25, pm10Grade: g10, pm25Grade: g25, grade, note, note10, note25, src: T.src[d.src] ?? d.src, srcKey: d.src };
  if (d.station) out.station = d.station;
  if (d.at) out.at = d.at;
  if (d.alarm) out.alarm = d.alarm.kind;
  if (yellow) out.yellow = true;
  if (d.tomorrow) {
    // Korea sends grades; OpenWeather sends tomorrow's worst values
    const t10 = d.tomorrow.pm10Grade ?? G10(d.tomorrow.pm10), t25 = d.tomorrow.pm25Grade ?? G25(d.tomorrow.pm25);
    if (t10 != null || t25 != null) out.tomorrow = { pm10Grade: t10, pm25Grade: t25 };
  }
  if (Array.isArray(d.hours) && d.hours.length) out.hours = d.hours;   // Plus: today's readings so far, [[hour, pm10, pm25]]
  return out;
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
 * Rain timing is the clock window (15~17시 비 예보), never a countdown.
 */
export function bubble(c, lang = c.lang ?? 'ko') {
  const S = strings(lang), T = S.bubble;
  const { warnings, nowWet, nowPr, thunder, startIn, wind, fog, feels, night, swing, maxPop, rain } = c;
  const next = c.next ?? (c.snowNext ? 'snow' : 'rain');   // what is coming: rain | snow | sleet
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
  const what = S.what[next] ?? S.what.rain;
  const nextIcon = next === 'snow' ? 'snowflake' : next === 'sleet' ? 'sleet' : 'umbrella_closed';
  if (!nowWet && startIn != null && startIn <= 2) {
    return B('speech', 'sky', nextIcon, S.expect(c.when, what));
  }
  if (wind) return B('speech', 'sky', 'wind', nowWet ? (nowPr === 'snow' || nowPr === 'heavysnow' ? T.blizzard : T.windrain) : T.windy);
  if (fog) return B('speech', 'white', 'cloud', fog >= 3 ? T.fog : T.fogMid);   // fog: its thickness (fogLevel)
  if (c.dust != null && c.dust >= 2 && S.dust.bubble[c.dust]) return B('speech', 'white', 'mask', S.dust.bubble[c.dust]);
  if (!night && feels >= 33) return B('shout', 'coral', 'thermo_hot', T.heat);
  if (night && feels >= 25) return B('speech', 'night', 'sweat', T.tropical);
  if (feels <= -10) return B('shout', 'sky', 'thermo_cold', T.cold);
  if (nowWet) return nowPr === 'snow' || nowPr === 'heavysnow' ? B('speech', night ? 'night' : 'sky', 'snowman', T.snow) : nowPr === 'sleet' ? B('speech', 'sky', 'umbrella', T.sleet) : B('speech', 'sky', 'umbrella', T.rain);
  if (startIn != null && startIn <= 12) return B('speech', 'sky', nextIcon, S.expect(c.when, what));
  if (swing >= 10) return B('speech', 'night', 'daynight', T.swing);
  if (rain === 'think') return B('thought', 'sky', 'umbrella', '');
  if (rain === 'bag' && maxPop >= 30) return B('speech', 'sky', 'umbrella_closed', T.umbrella);
  return null;
}

/**
 * When rain (or snow) is expected, as the hours people plan around: "15~17시" (first to last wet hour),
 * "15시쯤" when it is one hour, "내일 7~9시" when it starts tomorrow. Always "… 비 예보", never a promise.
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
 * The line under the character when an official warning is in force: the warning's name, what it means today in
 * one short clause from the forecast, and what to do. "대설주의보 · 오늘 6cm, 18시까지 눈 예보, 미끄러우니 조심하세요".
 */
export function alertNote(name, c, lang = c.lang ?? 'ko') {
  const S = strings(lang), A = S.alert, sep = S.sep;
  const { total, pr, nowWet, when, endH, hi, lo, gust, rh } = c;   // `name` is the KMA name (or Apple's description); `when` already in this language
  // clauses after the first start in lower case in English ("6mm today (Light), rain until around 6PM, take …")
  const join = (...parts) => parts.filter(Boolean).map((p, i) => (i && S.lang === 'en' ? p.charAt(0).toLowerCase() + p.slice(1) : p)).join(sep);
  const k = warningKind(name);
  const timing = (what) => (nowWet ? (endH == null ? '' : S.stopAt(endH, what)) : (when ? S.expect(when, what) : ''));
  if (k === 'snow') return total || timing(S.what.snow) ? join(total ? A.todayCm(total) : '', timing(S.what.snow), A.snowCare) : A.icy;
  if (k === 'rain') return total || timing(S.what.rain) ? join(total ? A.todayMm(total, rainAmountWord(total, S)) : '', timing(S.what.rain), A.rainCare) : A.heavyRain;
  if (k === 'typhoon') return join(A.windRain, gust ? A.gust(gust) : '', A.stayIn);
  if (k === 'wind') return join(gust ? A.gust(gust) : A.veryWindy, A.flying);
  if (k === 'heat') return A.heat(hi);
  if (k === 'cold') return A.cold(lo);
  if (k === 'dry') return join(rh == null ? '' : A.humidity(rh), A.fire);
  if (k === 'dust') return /황사|dust|黄砂/i.test(String(name)) ? A.yellowDust : A.fineDust;
  return /snow|sleet/.test(pr) ? A.slippery : A.takeCare;
}
