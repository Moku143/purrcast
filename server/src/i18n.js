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
    stopAt: (h, what) => `${h}시까지 ${what} 예보`,                     // the forecast has it until then: 18시까지 비 예보
    partOfDay: { morning: '아침', afternoon: '오후', evening: '저녁', night: '밤' },
    partTomorrow: (p) => `내일 ${p}`,
    what: { rain: '비', snow: '눈', sleet: '진눈깨비' },
    // the Live Activity (Dynamic Island / lock screen): "지금 비 · 1mm" / "6시쯤 비 예보", "1mm · 우산 챙기세요"
    live: { nowFalling: (what, amt) => `지금 ${what} · ${amt}`, aboutCm: (n) => `약 ${n}cm`, over: '비가 그쳤어요',
      care: { rain: '우산 챙기세요', snow: '미끄러우니 조심하세요', sleet: '미끄러우니 조심하세요' } },
    expect: (when, what) => `${when} ${what} 예보`,                       // 15~17시 비 예보 (the forecast says so, not a promise)
    cond: { thunder: '뇌우', heavy: '강한 비', rain: '비', snow: '눈', heavysnow: '많은 눈', sleet: '진눈깨비', clear: '맑음', partly: '구름 조금', overcast: '흐림',
      wind: '바람', windStrong: '바람 강함', fog: '안개', heat: '폭염', night: '열대야', frost: '한파' },
    bubble: { thunder: '천둥번개!', downpour: '폭우!', heavysnow: '폭설!', blizzard: '눈보라!', windrain: '비바람!', windy: '바람 세요!', fog: '안개가 짙어요!', fogMid: '안개가 옅어요',
      heat: '폭염!', tropical: '열대야!', cold: '한파!', snow: '눈!', sleet: '진눈깨비!', rain: '비!', swing: '일교차 커요!', umbrella: '우산 챙기세요' },
    rainKind: ['이슬비', '약한 비', '보통 비', '강한 비', '매우 강한 비'],
    rainKindNote: ['가볍게 내려요', '우산 챙기세요', '우산 꼭 챙기세요', '우산·우비 챙기세요', '되도록 외출은 줄이는 게 좋아요'],
    rainAmount: ['조금', '보통', '많음', '매우 많음'],
    feels: ['매우 추움', '추움', '쌀쌀', '선선', '온화', '따뜻', '더움', '매우 더움'],
    humidity: { veryDry: '매우 건조해요', dry: '건조해요', verySticky: '매우 끈적해요', sticky: '끈적해요', muggy: '꿉꿉해요', damp: '눅눅해요', humid: '습해요', bitHumid: '조금 습해요', crisp: '보송해요', ok: '적당해요' },
    wind: ['바람 없어요', '바람 약해요', '산들바람', '바람 조금', '바람 꽤 강해요', '바람 강해요', '매우 강한 바람', '강풍 · 외출 조심하세요'],
    uv: { none: '정보 없음', low: '약해요', moderate: '보통 · 선크림', high: '강해요 · 선크림, 모자', veryHigh: '매우 강해요 · 한낮 외출은 줄이는 게 좋아요', extreme: '위험 · 한낮 외출은 피하는 게 좋아요' },
    tile: { rainChance: '강수확률', uv: '자외선', sunset: '일몰', sunrise: '일출', humidity: '습도', polarDay: '백야', polarNight: '극야' },
    sunriseTomorrow: (t) => `내일 일출 ${t}`, sunsetAt: (t) => `일몰 ${t}`,
    polarNote: { day: '해가 지지 않아요', night: '해가 뜨지 않아요' },
    dewPoint: (d) => `이슬점 ${d}°`,
    nowWetNote: (what, amt) => `지금 ${what} · 앞으로 12시간 ${amt}`,
    noRain12h: '12시간 동안 비 소식 없어요',
    dust: {
      title: '미세먼지', pm10: '미세먼지', pm25: '초미세먼지', grade: ['좋음', '보통', '나쁨', '매우 나쁨'],
      note: ['공기가 맑아요', '괜찮은 편이에요', '공기가 탁해요 · 마스크를 챙겨 주세요', '공기가 많이 탁해요 · 외출할 땐 마스크를 착용해 주세요'],
      watch: '미세먼지 주의보 · 외출할 땐 마스크를 착용해 주세요', warning: '미세먼지 경보 · 외출을 줄이고 마스크를 착용해 주세요',
      yellow: '황사 · 창문을 닫고 외출할 땐 마스크를 착용해 주세요',
      src: { airkorea: '에어코리아', openweather: 'OpenWeather' },
      bubble: ['', '', '미세먼지 나쁨 · 마스크 챙기세요', '미세먼지 매우 나쁨 · 마스크 꼭 챙기세요'],
    },
    src: { apple: 'Apple 날씨', kma: '기상청', met: 'MET Norway' },
    sep: ', ',
    alert: {
      todayCm: (n) => `오늘 ${n}cm`, todayMm: (n, word) => `오늘 ${n}mm (${word})`,
      // what to do comes last, in the same words the rest of the app uses (챙기세요 · 조심하세요 · ~하는 게 좋아요)
      snowCare: '미끄러우니 조심하세요', rainCare: '우산·우비 챙기세요',
      icy: '바닥이 미끄러우니 눈길 조심하세요', slippery: '바닥이 미끄러우니 조심하세요',
      heavyRain: '비가 많이 와요, 우산 꼭 챙기고 우비도 있으면 좋아요',
      windRain: '강한 비바람', gust: (g) => `돌풍 ${g} m/s`, veryWindy: '바람이 매우 강해요',
      stayIn: '되도록 외출은 줄이는 게 좋아요', flying: '날리는 물건과 우산 조심하세요', takeCare: '외출할 때 조심하세요',
      heat: (hi) => `낮 최고 ${hi}°, 모자·선크림을 챙기고 물을 자주 마시는 게 좋아요`, cold: (lo) => `아침 ${lo}°, 장갑·목도리·핫팩 챙기세요`,
      humidity: (rh) => `습도 ${rh}%`, fire: '불씨 조심하세요',
      yellowDust: '황사가 심해요, 마스크 챙기세요', fineDust: '미세먼지가 심해요, 마스크 챙기세요',
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
    stopAt: (h, what) => `${what} until around ${h12(h)}${mer(h)}`,
    partOfDay: { morning: 'morning', afternoon: 'afternoon', evening: 'evening', night: 'night' },
    partTomorrow: (p) => `tomorrow ${p}`,
    what: { rain: 'Rain', snow: 'Snow', sleet: 'Sleet' },
    live: { nowFalling: (what, amt) => `${what} now · ${amt}`, aboutCm: (n) => `about ${n}cm`, over: 'The rain has stopped',
      care: { rain: 'Take an umbrella', snow: 'Watch your step', sleet: 'Watch your step' } },
    expect: (when, what) => `${what} ${when}`,                             // Rain 3–5PM
    cond: { thunder: 'Thunderstorm', heavy: 'Heavy rain', rain: 'Rain', snow: 'Snow', heavysnow: 'Heavy snow', sleet: 'Sleet', clear: 'Clear', partly: 'Partly cloudy', overcast: 'Cloudy',
      wind: 'Windy', windStrong: 'Strong wind', fog: 'Fog', heat: 'Heat wave', night: 'Tropical night', frost: 'Cold wave' },
    bubble: { thunder: 'Lightning!', downpour: 'Downpour!', heavysnow: 'Heavy snow!', blizzard: 'Blizzard!', windrain: 'Wind and rain!', windy: 'Windy!', fog: 'Thick fog!', fogMid: 'Light fog',
      heat: 'Heat wave!', tropical: 'Tropical night!', cold: 'Cold wave!', snow: 'Snow!', sleet: 'Sleet!', rain: 'Rain!', swing: 'Big temp swing!', umbrella: 'Take an umbrella' },
    rainKind: ['Drizzle', 'Light rain', 'Moderate rain', 'Heavy rain', 'Very heavy rain'],
    rainKindNote: ['Just a light drizzle', 'Take an umbrella', "Don't forget an umbrella", 'Take an umbrella and a raincoat', 'Best to stay in if you can'],
    rainAmount: ['Light', 'Moderate', 'Heavy', 'Very heavy'],
    feels: ['Freezing', 'Cold', 'Chilly', 'Cool', 'Mild', 'Warm', 'Hot', 'Very hot'],
    humidity: { veryDry: 'Very dry', dry: 'Dry', verySticky: 'Very sticky', sticky: 'Sticky', muggy: 'Muggy', damp: 'Damp', humid: 'Humid', bitHumid: 'A bit humid', crisp: 'Crisp', ok: 'Comfortable' },
    wind: ['Calm', 'Light air', 'Gentle breeze', 'Breezy', 'Quite windy', 'Windy', 'Very windy', 'Gale · Take care outside'],
    uv: { none: 'No data', low: 'Low', moderate: 'Moderate · Sunscreen', high: 'High · Sunscreen, hat', veryHigh: 'Very high · Best to limit midday outings', extreme: 'Extreme · Best to avoid midday outings' },
    tile: { rainChance: 'Rain chance', uv: 'UV', sunset: 'Sunset', sunrise: 'Sunrise', humidity: 'Humidity', polarDay: 'Midnight sun', polarNight: 'Polar night' },
    sunriseTomorrow: (t) => `Sunrise tomorrow ${t}`, sunsetAt: (t) => `Sunset ${t}`,
    polarNote: { day: "The sun doesn't set", night: "The sun doesn't rise" },
    dewPoint: (d) => `Dew point ${d}°`,
    nowWetNote: (what, amt) => `${what} now · ${amt} in the next 12h`,
    noRain12h: 'No rain for the next 12 hours',
    dust: {
      title: 'Air quality', pm10: 'PM10', pm25: 'PM2.5', grade: ['Good', 'Moderate', 'Poor', 'Very poor'],
      note: ['The air is clear', 'Fairly okay', 'The air is hazy · Bring a mask', 'Very hazy · Wear a mask outdoors'],
      watch: 'Fine dust advisory · Wear a mask outdoors', warning: 'Fine dust warning · Stay in when you can and wear a mask outdoors',
      yellow: 'Yellow dust · Close the windows and wear a mask outdoors',
      src: { airkorea: 'AirKorea', openweather: 'OpenWeather' },
      bubble: ['', '', 'Poor air · Bring a mask', 'Very poor air · Wear a mask'],
    },
    src: { apple: 'Apple Weather', kma: 'KMA', met: 'MET Norway' },
    sep: ', ',
    alert: {
      todayCm: (n) => `${n}cm today`, todayMm: (n, word) => `${n}mm today (${word})`,
      snowCare: 'Watch your step', rainCare: 'Take an umbrella and a raincoat',
      icy: 'Slippery ground, watch your step on the snow', slippery: 'Slippery ground, watch your step',
      heavyRain: 'Lots of rain, take an umbrella (a raincoat helps too)',
      windRain: 'Strong wind and rain', gust: (g) => `Gusts ${g} m/s`, veryWindy: 'Very strong wind',
      stayIn: 'Best to stay in if you can', flying: 'Watch out for flying objects and your umbrella', takeCare: 'Take care when you go out',
      heat: (hi) => `High ${hi}°, wear a hat and sunscreen and drink water often`, cold: (lo) => `Low ${lo}°, take gloves, a scarf and a hand warmer`,
      humidity: (rh) => `Humidity ${rh}%`, fire: 'Careful with fire',
      yellowDust: 'Heavy yellow dust, take a mask', fineDust: 'Poor air quality, take a mask',
    },
    warning: (name) => WARN[name]?.[0] ?? name,
  },
  ja: {
    now: '今', today: '今日', tomorrow: '明日',
    hour: (h) => `${h}時`,
    // 15〜17時 · 15時ごろ · 明日7〜9時
    when: (s, e, tomorrow) => { const w = s === e || e == null ? `${s}時ごろ` : `${s}〜${e}時`; return tomorrow ? `明日${w}` : w; },
    stopAt: (h, what) => `${h}時ごろまで${what}の予報`,
    partOfDay: { morning: '朝', afternoon: '午後', evening: '夕方', night: '夜' },
    partTomorrow: (p) => `明日の${p}`,
    what: { rain: '雨', snow: '雪', sleet: 'みぞれ' },
    live: { nowFalling: (what, amt) => `今、${what}・${amt}`, aboutCm: (n) => `約${n}cm`, over: '雨がやみました',
      care: { rain: '傘をお持ちください', snow: '滑りやすいのでご注意ください', sleet: '滑りやすいのでご注意ください' } },
    expect: (when, what) => `${when} ${what}の予報`,                       // 15〜17時 雨の予報
    cond: { thunder: '雷雨', heavy: '強い雨', rain: '雨', snow: '雪', heavysnow: '大雪', sleet: 'みぞれ', clear: '晴れ', partly: '晴れ時々曇り', overcast: '曇り',
      wind: '風', windStrong: '強風', fog: '霧', heat: '猛暑', night: '熱帯夜', frost: '寒波' },
    bubble: { thunder: '雷!', downpour: '豪雨!', heavysnow: '大雪!', blizzard: '吹雪!', windrain: '雨風!', windy: '強風!', fog: '濃霧!', fogMid: '霧は薄め',
      heat: '猛暑!', tropical: '熱帯夜!', cold: '寒波!', snow: '雪!', sleet: 'みぞれ!', rain: '雨!', swing: '寒暖差大!', umbrella: '傘をお持ちください' },
    rainKind: ['霧雨', '弱い雨', 'やや強い雨', '強い雨', '激しい雨'],
    rainKindNote: ['ぱらつく程度です', '傘をお持ちください', '傘を必ずお持ちください', '傘とレインコートをお持ちください', 'なるべく外出は控えたほうがいいです'],
    rainAmount: ['少なめ', '普通', '多め', '非常に多い'],
    feels: ['極寒', '寒い', '肌寒い', '涼しい', '穏やか', '暖かい', '暑い', '猛暑'],
    humidity: { veryDry: '非常に乾燥', dry: '乾燥', verySticky: '非常にべたつく', sticky: 'べたつく', muggy: '蒸し暑い', damp: 'じめじめ', humid: '湿っぽい', bitHumid: 'やや湿っぽい', crisp: 'さらっと', ok: 'ちょうどいい' },
    wind: ['無風', '弱い風', 'そよ風', 'やや風あり', 'かなり強い', '強い', '非常に強い', '暴風 · 外出にご注意ください'],
    uv: { none: '情報なし', low: '弱い', moderate: '中程度 · 日焼け止め', high: '強い · 日焼け止め、帽子', veryHigh: '非常に強い · 日中の外出は控えたほうがいいです', extreme: '危険 · 日中の外出は避けたほうがいいです' },
    tile: { rainChance: '降水確率', uv: '紫外線', sunset: '日の入り', sunrise: '日の出', humidity: '湿度', polarDay: '白夜', polarNight: '極夜' },
    sunriseTomorrow: (t) => `明日の日の出 ${t}`, sunsetAt: (t) => `日の入り ${t}`,
    polarNote: { day: '日が沈みません', night: '日が昇りません' },
    dewPoint: (d) => `露点 ${d}°`,
    nowWetNote: (what, amt) => `今 ${what} · この先12時間 ${amt}`,
    noRain12h: '12時間 雨の心配はありません',
    dust: {
      title: '大気汚染', pm10: 'PM10', pm25: 'PM2.5', grade: ['良い', '普通', '悪い', 'とても悪い'],
      note: ['空気がきれいです', 'まあまあです', '空気がかすんでいます・マスクをお持ちください', 'かなりかすんでいます・外出時はマスクを着用してください'],
      watch: 'PM2.5注意報・外出時はマスクを着用してください', warning: 'PM2.5警報・外出を控え、マスクを着用してください',
      yellow: '黄砂・窓を閉め、外出時はマスクを着用してください',
      src: { airkorea: 'AirKorea', openweather: 'OpenWeather' },
      bubble: ['', '', 'PM2.5 悪い・マスクを', 'PM2.5 とても悪い・マスク必須'],
    },
    src: { apple: 'Apple 天気', kma: '気象庁', met: 'MET Norway' },
    sep: '、',
    alert: {
      todayCm: (n) => `今日 ${n}cm`, todayMm: (n, word) => `今日 ${n}mm (${word})`,
      snowCare: '滑りやすいのでご注意ください', rainCare: '傘とレインコートをお持ちください',
      icy: '路面が滑りやすいので雪道にご注意ください', slippery: '路面が滑りやすいのでご注意ください',
      heavyRain: '雨が強いです、傘は必ず、レインコートもあると安心です',
      windRain: '強い雨風', gust: (g) => `突風 ${g} m/s`, veryWindy: '風が非常に強いです',
      stayIn: 'なるべく外出は控えたほうがいいです', flying: '飛ばされやすい物と傘にご注意ください', takeCare: '外出の際はご注意ください',
      heat: (hi) => `最高 ${hi}°、帽子と日焼け止めを使い、こまめに水分をとったほうがいいです`, cold: (lo) => `朝 ${lo}°、手袋・マフラー・カイロをお持ちください`,
      humidity: (rh) => `湿度 ${rh}%`, fire: '火の元にご注意ください',
      yellowDust: '黄砂がひどいです、マスクをお持ちください', fineDust: 'PM2.5が多いです、マスクをお持ちください',
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
