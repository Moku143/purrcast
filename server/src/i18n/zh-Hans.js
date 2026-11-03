// zh-Hans (简体中文, mainland) — the same keys and shape as the `en:` object in server/src/i18n.js.
// Clock words use the 24-hour style: 15时 · 15–17时 · 约15时 · 明天7–9时.

export default {
  now: '现在', today: '今天', tomorrow: '明天',
  hour: (h) => `${h}时`,
  // 15–17时 · 约15时 · 明天7–9时
  when: (s, e, tomorrow) => { const w = s === e || e == null ? `约${s}时` : `${s}–${e}时`; return tomorrow ? `明天${w}` : w; },
  stopAt: (h, what) => `${what}持续到约${h}时`,                          // 雨持续到约18时
  partOfDay: { morning: '早上', afternoon: '下午', evening: '傍晚', night: '夜间' },
  partTomorrow: (p) => `明天${p}`,
  what: { rain: '雨', snow: '雪', sleet: '雨夹雪' },
  live: { nowFalling: (what, amt) => `正在下${what} · ${amt}`, aboutCm: (n) => `约${n}cm`, over: '雨停了',
    care: { rain: '记得带伞', snow: '路滑请小心', sleet: '路滑请小心' } },
  expect: (when, what) => `${when}有${what}预报`,                         // 15–17时有雨预报 (the app drops the 预报 suffix for the head word)
  cond: { thunder: '雷阵雨', heavy: '大雨', rain: '雨', snow: '雪', heavysnow: '大雪', sleet: '雨夹雪', clear: '晴', partly: '多云', overcast: '阴',
    wind: '有风', windStrong: '大风', fog: '雾', heat: '高温', night: '热夜', frost: '寒潮' },
  bubble: { thunder: '雷电!', downpour: '暴雨!', heavysnow: '大雪!', blizzard: '暴风雪!', windrain: '风雨!', windy: '风大!', fog: '大雾!', fogMid: '薄雾',
    heat: '高温!', tropical: '热夜!', cold: '寒潮!', snow: '雪!', sleet: '雨夹雪!', rain: '雨!', swing: '温差大!', umbrella: '记得带伞' },
  rainKind: ['毛毛雨', '小雨', '中雨', '大雨', '暴雨'],
  rainKindNote: ['只是毛毛雨', '记得带伞', '一定要带伞', '记得带伞和雨衣', '尽量少出门'],
  rainAmount: ['少', '一般', '多', '非常多'],
  feels: ['严寒', '寒冷', '微冷', '凉爽', '温和', '温暖', '炎热', '酷热'],
  humidity: { veryDry: '非常干燥', dry: '干燥', verySticky: '非常闷湿', sticky: '黏腻', muggy: '闷热潮湿', damp: '湿气重', humid: '潮湿', bitHumid: '略潮湿', crisp: '干爽', ok: '舒适' },
  wind: ['无风', '微风', '和风', '有点风', '风较大', '风大', '风很大', '强风 · 外出请小心'],
  uv: { none: '无数据', low: '弱', moderate: '中等 · 涂防晒', high: '强 · 防晒、戴帽子', veryHigh: '很强 · 中午少出门', extreme: '危险 · 中午避免外出' },
  tile: { rainChance: '降水概率', uv: '紫外线', sunset: '日落', sunrise: '日出', humidity: '湿度', polarDay: '极昼', polarNight: '极夜' },
  sunriseTomorrow: (t) => `明天日出 ${t}`, sunsetAt: (t) => `日落 ${t}`,
  polarNote: { day: '太阳不落', night: '太阳不升' },
  dewPoint: (d) => `露点 ${d}°`,
  nowWetNote: (what, amt) => `正在下${what} · 未来12小时 ${amt}`,
  noRain12h: '未来12小时没有降水',
  dust: {
    title: '空气质量', pm10: 'PM10', pm25: 'PM2.5', grade: ['优', '良', '差', '很差'],
    note: ['空气清新', '还算可以', '空气较差 · 记得戴口罩', '空气很差 · 外出请戴口罩'],
    watch: '空气污染预警 · 外出请戴口罩', warning: '空气污染警报 · 少出门并戴口罩',
    yellow: '沙尘 · 请关好窗户，外出戴口罩',
    src: { airkorea: 'AirKorea', openweather: 'OpenWeather' },
    bubble: ['', '', '空气较差 · 记得戴口罩', '空气很差 · 一定要戴口罩'],
  },
  src: { apple: 'Apple 天气', kma: '韩国气象厅', met: 'MET Norway' },
  sep: '、',
  alert: {
    todayCm: (n) => `今天 ${n}cm`, todayMm: (n, word) => `今天 ${n}mm（${word}）`,
    snowCare: '路滑请小心', rainCare: '记得带伞和雨衣',
    icy: '路面结冰，雪天请小心', slippery: '路面湿滑，请小心',
    heavyRain: '雨很大，一定要带伞，最好穿雨衣',
    windRain: '大风大雨', gust: (g) => `阵风 ${g} m/s`, veryWindy: '风非常大',
    stayIn: '尽量少出门', flying: '小心飞来的物品和雨伞', takeCare: '外出请小心',
    heat: (hi) => `白天最高 ${hi}°，戴好帽子、做好防晒，多喝水`, cold: (lo) => `早上 ${lo}°，记得戴手套、围巾，带上暖宝宝`,
    humidity: (rh) => `湿度 ${rh}%`, fire: '注意防火',
    yellowDust: '沙尘严重，记得戴口罩', fineDust: '空气很差，记得戴口罩',
  },
};

export const weekdays = { Sun: '日', Mon: '一', Tue: '二', Wed: '三', Thu: '四', Fri: '五', Sat: '六' };

export const warnings = {
  호우주의보: '暴雨预警', 호우경보: '暴雨警报',
  대설주의보: '暴雪预警', 대설경보: '暴雪警报',
  폭염주의보: '高温预警', 폭염경보: '高温警报',
  한파주의보: '寒潮预警', 한파경보: '寒潮警报',
  강풍주의보: '大风预警', 강풍경보: '大风警报',
  태풍주의보: '台风预警', 태풍경보: '台风警报',
  건조주의보: '干燥预警', 건조경보: '干燥警报',
  풍랑주의보: '海浪预警', 풍랑경보: '海浪警报',
  황사경보: '沙尘警报',
};
