// zh-Hant (繁體中文, Taiwan) — the same keys and shape as the `en:` object in server/src/i18n.js.
// Clock words use the 24-hour style: 15時 · 15–17時 · 約15時 · 明天7–9時.

export default {
  now: '現在', today: '今天', tomorrow: '明天',
  hour: (h) => `${h}時`,
  // 15–17時 · 約15時 · 明天7–9時
  when: (s, e, tomorrow) => { const w = s === e || e == null ? `約${s}時` : `${s}–${e}時`; return tomorrow ? `明天${w}` : w; },
  stopAt: (h, what) => `${what}持續到約${h}時`,                          // 雨持續到約18時
  partOfDay: { morning: '早上', afternoon: '下午', evening: '傍晚', night: '夜晚' },
  partTomorrow: (p) => `明天${p}`,
  what: { rain: '雨', snow: '雪', sleet: '雨夾雪' },
  live: { nowFalling: (what, amt) => `正在下${what} · ${amt}`, aboutCm: (n) => `約${n}cm`, over: '雨停了',
    care: { rain: '記得帶傘', snow: '路滑請小心', sleet: '路滑請小心' } },
  expect: (when, what) => `${when}有${what}預報`,                         // 15–17時有雨預報 (the app drops the 預報 suffix for the head word)
  cond: { thunder: '雷雨', heavy: '大雨', rain: '雨', snow: '雪', heavysnow: '大雪', sleet: '雨夾雪', clear: '晴', partly: '晴時多雲', overcast: '陰',
    wind: '有風', windStrong: '強風', fog: '霧', heat: '熱浪', night: '熱帶夜', frost: '寒流' },
  bubble: { thunder: '雷電!', downpour: '豪雨!', heavysnow: '大雪!', blizzard: '暴風雪!', windrain: '風雨!', windy: '風大!', fog: '濃霧!', fogMid: '薄霧',
    heat: '熱浪!', tropical: '熱帶夜!', cold: '寒流!', snow: '雪!', sleet: '雨夾雪!', rain: '雨!', swing: '溫差大!', umbrella: '記得帶傘' },
  rainKind: ['毛毛雨', '小雨', '中雨', '大雨', '暴雨'],
  rainKindNote: ['只是毛毛雨', '記得帶傘', '一定要帶傘', '記得帶傘和雨衣', '盡量少出門比較好'],
  rainAmount: ['少', '普通', '多', '非常多'],
  feels: ['嚴寒', '寒冷', '微冷', '涼爽', '溫和', '溫暖', '炎熱', '酷熱'],
  humidity: { veryDry: '非常乾燥', dry: '乾燥', verySticky: '非常黏膩', sticky: '黏膩', muggy: '悶濕', damp: '濕氣重', humid: '潮濕', bitHumid: '略濕', crisp: '乾爽', ok: '舒適' },
  wind: ['無風', '微風', '和風', '有點風', '風頗大', '風大', '風很大', '強風 · 外出請小心'],
  uv: { none: '無資料', low: '弱', moderate: '中等 · 擦防曬', high: '強 · 防曬、帽子', veryHigh: '非常強 · 中午減少外出比較好', extreme: '危險 · 中午避免外出比較好' },
  tile: { rainChance: '降雨機率', uv: '紫外線', sunset: '日落', sunrise: '日出', humidity: '濕度', polarDay: '永晝', polarNight: '永夜' },
  sunriseTomorrow: (t) => `明天日出 ${t}`, sunsetAt: (t) => `日落 ${t}`,
  polarNote: { day: '太陽不會下山', night: '太陽不會升起' },
  dewPoint: (d) => `露點 ${d}°`,
  nowWetNote: (what, amt) => `正在下${what} · 未來12小時 ${amt}`,
  noRain12h: '未來12小時不會下雨',
  dust: {
    title: '空氣品質', pm10: 'PM10', pm25: 'PM2.5', grade: ['良好', '普通', '差', '非常差'],
    note: ['空氣清新', '還算可以', '空氣混濁 · 請帶口罩', '空氣很混濁 · 外出請戴口罩'],
    watch: '空氣品質注意報 · 外出請戴口罩', warning: '空氣品質警報 · 減少外出並戴口罩',
    yellow: '沙塵 · 請關上窗戶，外出請戴口罩',
    src: { airkorea: 'AirKorea', openweather: 'OpenWeather' },
    bubble: ['', '', '空氣差 · 記得帶口罩', '空氣非常差 · 一定要戴口罩'],
  },
  src: { apple: 'Apple 天氣', kma: '韓國氣象廳', met: 'MET Norway' },
  sep: '、',
  alert: {
    todayCm: (n) => `今天 ${n}cm`, todayMm: (n, word) => `今天 ${n}mm（${word}）`,
    snowCare: '路滑請小心', rainCare: '記得帶傘和雨衣',
    icy: '路面濕滑，雪地請小心', slippery: '路面濕滑，請小心',
    heavyRain: '雨很大，一定要帶傘，有雨衣更好',
    windRain: '強風大雨', gust: (g) => `陣風 ${g} m/s`, veryWindy: '風非常強',
    stayIn: '盡量少出門比較好', flying: '小心飛來的物品和雨傘', takeCare: '外出請小心',
    heat: (hi) => `白天最高 ${hi}°，記得帶帽子和防曬，多喝水`, cold: (lo) => `早上 ${lo}°，記得帶手套、圍巾和暖暖包`,
    humidity: (rh) => `濕度 ${rh}%`, fire: '小心火燭',
    yellowDust: '沙塵嚴重，記得帶口罩', fineDust: '空氣很差，記得帶口罩',
  },
};

export const weekdays = { Sun: '日', Mon: '一', Tue: '二', Wed: '三', Thu: '四', Fri: '五', Sat: '六' };

export const warnings = {
  호우주의보: '豪雨注意報', 호우경보: '豪雨警報',
  대설주의보: '大雪注意報', 대설경보: '大雪警報',
  폭염주의보: '高溫注意報', 폭염경보: '高溫警報',
  한파주의보: '低溫注意報', 한파경보: '低溫警報',
  강풍주의보: '強風注意報', 강풍경보: '強風警報',
  태풍주의보: '颱風注意報', 태풍경보: '颱風警報',
  건조주의보: '乾燥注意報', 건조경보: '乾燥警報',
  풍랑주의보: '風浪注意報', 풍랑경보: '風浪警報',
  황사경보: '沙塵警報',
};
