// Every human-readable word the server sends, in the three languages of docs/i18n-glossary.md.
// `strings(lang)` → one object of fixed words plus the small helpers that build clock words
// (14시 · 2PM · 14時, 15~17시 · 3–5PM · 15〜17時). Korean values are the ones the app shipped with.
// Icons, kinds and numbers never change with the language — only text.

export const LANGS = ['ko', 'en', 'ja'];
/** ko | en | ja; anything else → en, nothing → ko. */
export const normLang = (v) => (v == null || v === '' ? 'ko' : LANGS.includes(v) ? v : 'en');

const WD_EN = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const WD = {
  ko: { Sun: '일', Mon: '월', Tue: '화', Wed: '수', Thu: '목', Fri: '금', Sat: '토' },
  en: Object.fromEntries(WD_EN.map((d) => [d, d])),
  ja: { Sun: '日', Mon: '月', Tue: '火', Wed: '水', Thu: '木', Fri: '金', Sat: '土' },
};

/** 기상청 특보 names (kma.js) → the glossary's English / Japanese names. Unknown names pass through. */
const WARN = {
  호우주의보: ['Heavy Rain Advisory', '大雨注意報'], 호우경보: ['Heavy Rain Warning', '大雨警報'],
  대설주의보: ['Heavy Snow Advisory', '大雪注意報'], 대설경보: ['Heavy Snow Warning', '大雪警報'],
  폭염주의보: ['Heat Advisory', '高温注意報'], 폭염경보: ['Heat Warning', '高温警報'],
  한파주의보: ['Cold Wave Advisory', '低温注意報'], 한파경보: ['Cold Wave Warning', '低温警報'],
  강풍주의보: ['Wind Advisory', '強風注意報'], 강풍경보: ['Wind Warning', '暴風警報'],
  태풍주의보: ['Typhoon Advisory', '台風注意報'], 태풍경보: ['Typhoon Warning', '台風警報'],
  건조주의보: ['Dry Weather Advisory', '乾燥注意報'], 건조경보: ['Dry Weather Warning', '乾燥警報'],
  풍랑주의보: ['High Seas Advisory', '波浪注意報'], 풍랑경보: ['High Seas Warning', '波浪警報'],
};

// en clock words: 12-hour, "2PM" · "12AM"
const h12 = (h) => `${h % 12 === 0 ? 12 : h % 12}`;
const mer = (h) => (h < 12 ? 'AM' : 'PM');

const DICT = {
  ko: {
    now: '지금', today: '오늘', tomorrow: '내일',
    hour: (h) => `${h}시`,
    // 15~17시 · 15시쯤 · 내일 7~9시
    when: (s, e, tomorrow) => { const w = s === e || e == null ? `${s}시쯤` : `${s}~${e}시`; return tomorrow ? `내일 ${w}` : w; },
    stopAt: (h) => `${h}시쯤 그칠 예보`,
    partOfDay: { morning: '아침', afternoon: '오후', evening: '저녁', night: '밤' },
    partTomorrow: (p) => `내일 ${p}`,
    what: { rain: '비', snow: '눈', sleet: '진눈깨비' },
    expect: (when, what) => `${when} ${what} 예정`,                       // 15~17시 비 예정
    cond: { thunder: '뇌우', heavy: '강한 비', rain: '비', snow: '눈', heavysnow: '많은 눈', sleet: '진눈깨비', clear: '맑음', partly: '구름 조금', overcast: '흐림',
      wind: '바람', windStrong: '바람 강함', fog: '안개', heat: '폭염', night: '열대야', frost: '한파' },
    bubble: { thunder: '천둥번개!', downpour: '폭우!', heavysnow: '폭설!', blizzard: '눈보라!', windrain: '비바람!', windy: '바람 세요!', fog: '안개 짙어요!', fogMid: '안개 꼈어요',
      heat: '폭염!', tropical: '열대야!', cold: '한파!', snow: '눈!', sleet: '진눈깨비!', rain: '비!', swing: '일교차 커요!', umbrella: '우산 챙겨요' },
    rainKind: ['이슬비', '약한 비', '보통 비', '강한 비', '매우 강한 비'],
    rainKindNote: ['우산 없이도 괜찮아요', '우산이 필요해요', '우산이 꼭 필요해요', '바닥에 물이 고여요', '우산으로 막기 어려워요'],
    rainAmount: ['조금', '보통', '많음', '매우 많음'],
    feels: ['매우 추움', '추움', '쌀쌀', '선선', '쾌적', '따뜻', '더움', '매우 더움'],
    humidity: { veryDry: '매우 건조해요', dry: '건조해요', verySticky: '매우 끈적해요', sticky: '끈적해요', muggy: '꿉꿉해요', damp: '눅눅해요', humid: '습해요', bitHumid: '조금 습해요', crisp: '보송해요', ok: '적당해요' },
    wind: ['바람 없어요', '바람 약해요', '산들바람', '바람 조금', '바람 꽤 강해요', '바람 강해요', '매우 강한 바람', '강풍 · 외출 주의'],
    uv: { none: '정보 없음', low: '약해요', moderate: '보통 · 선크림', high: '강해요 · 선크림, 모자', veryHigh: '매우 강해요 · 한낮 외출 줄여요', extreme: '위험 · 한낮 외출 피해요' },
    tile: { rainChance: '강수확률', uv: '자외선', sunset: '일몰', sunrise: '일출', humidity: '습도', polarDay: '백야', polarNight: '극야' },
    sunriseTomorrow: (t) => `내일 일출 ${t}`, sunsetAt: (t) => `일몰 ${t}`,
    polarNote: { day: '해가 지지 않아요', night: '해가 뜨지 않아요' },
    dewPoint: (d) => `이슬점 ${d}°`,
    nowWetNote: (what, amt) => `지금 ${what} · 12시간 ${amt}`,
    noRain12h: '12시간 동안 비 소식 없어요',
    src: { apple: 'Apple 날씨', kma: '기상청', met: 'MET Norway' },
    sep: ', ',
    alert: {
      todayCm: (n) => `오늘 ${n}cm`, todayMm: (n, word) => `오늘 ${n}mm (${word})`,
      icy: '눈길 조심', heavyRain: '강한 비 주의', windRain: '강한 비바람', gust: (g) => `돌풍 ${g} m/s`, veryWindy: '바람 매우 강함', takeCare: '외출 주의',
      heat: (hi) => `낮 최고 ${hi}°, 한낮 외출 줄여요`, cold: (lo) => `아침 ${lo}°, 많이 추워요`,
      humidity: (rh) => `습도 ${rh}%`, fire: '불조심', mask: '마스크 챙겨요',
    },
    warning: (name) => name,
  },
  en: {
    now: 'Now', today: 'Today', tomorrow: 'Tomorrow',
    hour: (h) => `${h12(h)}${mer(h)}`,
    // 3–5PM · 11AM–1PM · around 3PM · tomorrow 7–9AM
    when: (s, e, tomorrow) => {
      const w = s === e || e == null ? `around ${h12(s)}${mer(s)}` : mer(s) === mer(e) ? `${h12(s)}–${h12(e)}${mer(e)}` : `${h12(s)}${mer(s)}–${h12(e)}${mer(e)}`;
      return tomorrow ? `tomorrow ${w}` : w;
    },
    stopAt: (h) => `Should stop around ${h12(h)}${mer(h)}`,
    partOfDay: { morning: 'morning', afternoon: 'afternoon', evening: 'evening', night: 'night' },
    partTomorrow: (p) => `tomorrow ${p}`,
    what: { rain: 'Rain', snow: 'Snow', sleet: 'Sleet' },
    expect: (when, what) => `${what} ${when}`,                             // Rain 3–5PM
    cond: { thunder: 'Thunderstorm', heavy: 'Heavy rain', rain: 'Rain', snow: 'Snow', heavysnow: 'Heavy snow', sleet: 'Sleet', clear: 'Clear', partly: 'Partly cloudy', overcast: 'Cloudy',
      wind: 'Windy', windStrong: 'Strong wind', fog: 'Fog', heat: 'Heat wave', night: 'Tropical night', frost: 'Cold wave' },
    bubble: { thunder: 'Lightning!', downpour: 'Downpour!', heavysnow: 'Heavy snow!', blizzard: 'Blizzard!', windrain: 'Wind and rain!', windy: 'Windy!', fog: 'Thick fog!', fogMid: 'Foggy',
      heat: 'Heat wave!', tropical: 'Tropical night!', cold: 'Cold wave!', snow: 'Snow!', sleet: 'Sleet!', rain: 'Rain!', swing: 'Big temp swing!', umbrella: 'Take an umbrella' },
    rainKind: ['Drizzle', 'Light rain', 'Moderate rain', 'Heavy rain', 'Very heavy rain'],
    rainKindNote: ['Fine without an umbrella', 'Take an umbrella', "You'll really need an umbrella", 'Puddles on the ground', "An umbrella won't be enough"],
    rainAmount: ['Light', 'Moderate', 'Heavy', 'Very heavy'],
    feels: ['Freezing', 'Cold', 'Chilly', 'Cool', 'Pleasant', 'Warm', 'Hot', 'Very hot'],
    humidity: { veryDry: 'Very dry', dry: 'Dry', verySticky: 'Very sticky', sticky: 'Sticky', muggy: 'Muggy', damp: 'Damp', humid: 'Humid', bitHumid: 'A bit humid', crisp: 'Crisp', ok: 'Comfortable' },
    wind: ['Calm', 'Light air', 'Gentle breeze', 'Breezy', 'Quite windy', 'Windy', 'Very windy', 'Gale · Take care outside'],
    uv: { none: 'No data', low: 'Low', moderate: 'Moderate · Sunscreen', high: 'High · Sunscreen, hat', veryHigh: 'Very high · Limit midday outings', extreme: 'Extreme · Avoid midday outings' },
    tile: { rainChance: 'Rain chance', uv: 'UV', sunset: 'Sunset', sunrise: 'Sunrise', humidity: 'Humidity', polarDay: 'Midnight sun', polarNight: 'Polar night' },
    sunriseTomorrow: (t) => `Sunrise tomorrow ${t}`, sunsetAt: (t) => `Sunset ${t}`,
    polarNote: { day: "The sun doesn't set", night: "The sun doesn't rise" },
    dewPoint: (d) => `Dew point ${d}°`,
    nowWetNote: (what, amt) => `${what} now · ${amt} in 12h`,
    noRain12h: 'No rain for the next 12 hours',
    src: { apple: 'Apple Weather', kma: 'KMA', met: 'MET Norway' },
    sep: ', ',
    alert: {
      todayCm: (n) => `${n}cm today`, todayMm: (n, word) => `${n}mm today (${word})`,
      icy: 'Watch for icy roads', heavyRain: 'Heavy rain, take care', windRain: 'Strong wind and rain', gust: (g) => `Gusts ${g} m/s`, veryWindy: 'Very strong wind', takeCare: 'Take care outside',
      heat: (hi) => `High ${hi}°, limit midday outings`, cold: (lo) => `Low ${lo}°, bundle up`,
      humidity: (rh) => `Humidity ${rh}%`, fire: 'Fire risk', mask: 'Take a mask',
    },
    warning: (name) => WARN[name]?.[0] ?? name,
  },
  ja: {
    now: '今', today: '今日', tomorrow: '明日',
    hour: (h) => `${h}時`,
    // 15〜17時 · 15時ごろ · 明日7〜9時
    when: (s, e, tomorrow) => { const w = s === e || e == null ? `${s}時ごろ` : `${s}〜${e}時`; return tomorrow ? `明日${w}` : w; },
    stopAt: (h) => `${h}時ごろ止む見込み`,
    partOfDay: { morning: '朝', afternoon: '午後', evening: '夕方', night: '夜' },
    partTomorrow: (p) => `明日の${p}`,
    what: { rain: '雨', snow: '雪', sleet: 'みぞれ' },
    expect: (when, what) => `${when} ${what}`,                             // 15〜17時 雨
    cond: { thunder: '雷雨', heavy: '強い雨', rain: '雨', snow: '雪', heavysnow: '大雪', sleet: 'みぞれ', clear: '晴れ', partly: '晴れ時々曇り', overcast: '曇り',
      wind: '風', windStrong: '強風', fog: '霧', heat: '猛暑', night: '熱帯夜', frost: '寒波' },
    bubble: { thunder: '雷!', downpour: '豪雨!', heavysnow: '大雪!', blizzard: '吹雪!', windrain: '雨風!', windy: '強風!', fog: '濃霧!', fogMid: '霧が出てる',
      heat: '猛暑!', tropical: '熱帯夜!', cold: '寒波!', snow: '雪!', sleet: 'みぞれ!', rain: '雨!', swing: '寒暖差大!', umbrella: '傘を持って' },
    rainKind: ['霧雨', '弱い雨', 'やや強い雨', '強い雨', '激しい雨'],
    rainKindNote: ['傘なしでも大丈夫です', '傘が必要です', '傘が必須です', '地面に水がたまります', '傘では防ぎきれません'],
    rainAmount: ['少なめ', '普通', '多め', '非常に多い'],
    feels: ['極寒', '寒い', '肌寒い', '涼しい', '快適', '暖かい', '暑い', '猛暑'],
    humidity: { veryDry: '非常に乾燥', dry: '乾燥', verySticky: '非常にべたつく', sticky: 'べたつく', muggy: '蒸し暑い', damp: 'じめじめ', humid: '湿っぽい', bitHumid: 'やや湿っぽい', crisp: 'さらっと', ok: 'ちょうどいい' },
    wind: ['無風', '弱い風', 'そよ風', 'やや風あり', 'かなり強い', '強い', '非常に強い', '暴風 · 外出注意'],
    uv: { none: '情報なし', low: '弱い', moderate: '中程度 · 日焼け止め', high: '強い · 日焼け止め、帽子', veryHigh: '非常に強い · 日中の外出は控えめに', extreme: '危険 · 日中の外出は避けて' },
    tile: { rainChance: '降水確率', uv: '紫外線', sunset: '日の入り', sunrise: '日の出', humidity: '湿度', polarDay: '白夜', polarNight: '極夜' },
    sunriseTomorrow: (t) => `明日の日の出 ${t}`, sunsetAt: (t) => `日の入り ${t}`,
    polarNote: { day: '日が沈みません', night: '日が昇りません' },
    dewPoint: (d) => `露点 ${d}°`,
    nowWetNote: (what, amt) => `今 ${what} · 12時間 ${amt}`,
    noRain12h: '12時間 雨の心配はありません',
    src: { apple: 'Apple 天気', kma: '気象庁', met: 'MET Norway' },
    sep: '、',
    alert: {
      todayCm: (n) => `今日 ${n}cm`, todayMm: (n, word) => `今日 ${n}mm (${word})`,
      icy: '雪道に注意', heavyRain: '強い雨に注意', windRain: '強い雨風', gust: (g) => `突風 ${g} m/s`, veryWindy: '風が非常に強い', takeCare: '外出注意',
      heat: (hi) => `最高 ${hi}°、日中の外出は控えめに`, cold: (lo) => `朝 ${lo}°、かなり冷えます`,
      humidity: (rh) => `湿度 ${rh}%`, fire: '火の用心', mask: 'マスクを持って',
    },
    warning: (name) => WARN[name]?.[1] ?? name,
  },
};

for (const l of LANGS) {
  DICT[l].lang = l;
  DICT[l].weekday = (wdEn) => WD[l][wdEn] ?? wdEn;   // 'Mon' → 월 · Mon · 月
  Object.freeze(DICT[l]);
}

/** The dictionary for a language (or a dictionary passed through unchanged). */
export function strings(lang = 'ko') {
  if (lang && typeof lang === 'object') return lang;
  return DICT[normLang(lang)];
}

export const hourLabel = (h, lang) => strings(lang).hour(h);
export const warningName = (name, lang) => strings(lang).warning(name);
