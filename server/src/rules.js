// The design kit's judgement rules (kit README §1, rules.json), in one place.

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

/** Rain per hour in everyday terms, and what it means for an umbrella */
export const rainKind = (mm) => (mm >= 30 ? '매우 강한 비' : mm >= 15 ? '강한 비' : mm >= 3 ? '보통 비' : mm >= 1 ? '약한 비' : '이슬비');
export const rainKindNote = (mm) => (mm >= 30 ? '우산으로 막기 어려워요' : mm >= 15 ? '바닥에 물이 고여요' : mm >= 3 ? '우산이 꼭 필요해요' : mm >= 1 ? '우산이 필요해요' : '우산 없이도 괜찮아요');
/** A day's or 12 h total: 조금 · 보통 · 많음 · 매우 많음 */
export const rainAmountWord = (mm) => (mm >= 50 ? '매우 많음' : mm >= 20 ? '많음' : mm >= 5 ? '보통' : '조금');
/** Feels-like in eight steps */
export const feelsWord = (c) => (c <= -10 ? '매우 추움' : c <= 0 ? '추움' : c <= 8 ? '쌀쌀' : c <= 16 ? '선선' : c <= 22 ? '쾌적' : c <= 27 ? '따뜻' : c <= 32 ? '더움' : '매우 더움');

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
  if (p.type === 'snow' || p.type === 'sleet') return 'snow';
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

export function condition({ pr, cov, thunder, auxKind, night, feels }) {
  let base = thunder ? '뇌우' : pr === 'heavy' ? '강한 비' : pr === 'rain' ? '비' : pr === 'snow' ? '눈'
    : cov === 'clear' ? '맑음' : cov === 'partly' ? '구름 조금' : '흐림';
  const extra = auxKind === 'wind' ? (pr === 'none' ? '바람' : '바람 강함')
    : auxKind === 'fog' ? '안개'
    : auxKind === 'heat' ? (night ? '열대야' : '폭염')
    : auxKind === 'frost' ? '한파' : '';
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
export function bubble(c) {
  const { warnings, nowWet, nowPr, thunder, startIn, wind, fog, feels, night, swing, maxPop, rain, snowNext } = c;
  if (warnings?.length) {
    const w = warnings[0].name;
    const ic = /호우|태풍/.test(w) ? (/태풍/.test(w) ? 'wind' : 'raincloud') : /대설/.test(w) ? 'snowflake' : /강풍|풍랑/.test(w) ? 'wind'
      : /폭염/.test(w) ? 'thermo_hot' : /한파/.test(w) ? 'thermo_cold' : /건조/.test(w) ? 'sun_strong' : 'exclaim';
    return B('shout', 'coral', ic, w);
  }
  if (thunder) return B('shout', 'coral', 'lightning', '천둥번개!');
  if (nowPr === 'heavy') return B('shout', 'sky', 'umbrella', '폭우!');
  if (nowPr === 'snow' && c.nowMm >= 3) return B('speech', 'sky', 'snowflake', '폭설!');
  const what = snowNext ? '눈' : '비';
  if (!nowWet && startIn != null && startIn <= 2) {
    return B('speech', 'sky', snowNext ? 'snowflake' : 'umbrella_closed', `${c.when} ${what} 예정`);
  }
  if (wind) return B('speech', 'sky', 'wind', nowWet ? (nowPr === 'snow' ? '눈보라!' : '비바람!') : '바람 세요!');
  if (fog) return B('speech', 'white', 'cloud', '안개 짙어요!');
  if (!night && feels >= 33) return B('shout', 'coral', 'thermo_hot', '폭염!');
  if (night && feels >= 25) return B('speech', 'night', 'sweat', '열대야!');
  if (feels <= -10) return B('shout', 'sky', 'thermo_cold', '한파!');
  if (nowWet) return nowPr === 'snow' ? B('speech', night ? 'night' : 'sky', 'snowman', '눈!') : B('speech', 'sky', 'umbrella', '비!');
  if (startIn != null && startIn <= 12) return B('speech', 'sky', snowNext ? 'snowflake' : 'umbrella_closed', `${c.when} ${what} 예정`);
  if (swing >= 10) return B('speech', 'night', 'daynight', '일교차 커요!');
  if (rain === 'think') return B('thought', 'sky', 'umbrella', '');
  if (rain === 'bag' && maxPop >= 30) return B('speech', 'sky', 'umbrella_closed', '우산 챙겨요');
  return null;
}

/**
 * When rain (or snow) is expected, as the hours people plan around: "15~17시" (first to last wet hour),
 * "15시쯤" when it is one hour, "내일 7~9시" when it starts tomorrow. Always "… 비 예정", never a promise.
 */
export function whenWord(startH, endH, tomorrow) {
  if (startH == null) return '';
  const w = startH === endH || endH == null ? `${startH}시쯤` : `${startH}~${endH}시`;
  return tomorrow ? `내일 ${w}` : w;
}

/** "저녁 비!" style words for rain 6–12 h away. */
export function partOfDay(h, tomorrow) {
  const part = h >= 5 && h < 12 ? '아침' : h >= 12 && h < 17 ? '오후' : h >= 17 && h < 21 ? '저녁' : '밤';
  return tomorrow ? `내일 ${part}` : part;
}

/** WHO / KMA UV index scale: 0–2 낮음 · 3–5 보통 · 6–7 높음 · 8–10 매우 높음 · 11+ 위험 */
export function uvNote(uv) {
  if (uv == null) return '정보 없음';
  return uv <= 2 ? '약해요' : uv <= 5 ? '보통 · 선크림' : uv <= 7 ? '강해요 · 선크림, 모자' : uv <= 10 ? '매우 강해요 · 한낮 외출 줄여요' : '위험 · 한낮 외출 피해요';
}
