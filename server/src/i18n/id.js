// Purrcast server words — Bahasa Indonesia (id). Same keys and shape as the `en:` object in server/src/i18n.js.
// Clock words use the 24-hour style: 15:00 · 15–17 · sekitar 15:00 · besok 7–9.

const h24 = (h) => `${h}:00`;

export default {
  now: 'Sekarang', today: 'Hari ini', tomorrow: 'Besok',
  hour: (h) => h24(h),
  // 15–17 · sekitar 15:00 · besok 7–9
  when: (s, e, tomorrow) => {
    const w = s === e || e == null ? `sekitar ${h24(s)}` : `${s}–${e}`;
    return tomorrow ? `besok ${w}` : w;
  },
  stopAt: (h, what) => `${what} sampai sekitar ${h24(h)}`,                // Hujan sampai sekitar 18:00
  partOfDay: { morning: 'pagi', afternoon: 'siang', evening: 'sore', night: 'malam' },
  partTomorrow: (p) => `besok ${p}`,
  what: { rain: 'Hujan', snow: 'Salju', sleet: 'Hujan es' },
  live: { nowFalling: (what, amt) => `${what} sekarang · ${amt}`, aboutCm: (n) => `sekitar ${n}cm`, over: 'Hujan sudah berhenti',
    care: { rain: 'Bawa payung', snow: 'Hati-hati licin', sleet: 'Hati-hati licin' } },
  expect: (when, what) => `${what} ${when}`,                              // Hujan 15–17
  cond: { thunder: 'Badai petir', heavy: 'Hujan lebat', rain: 'Hujan', snow: 'Salju', heavysnow: 'Salju lebat', sleet: 'Hujan es', clear: 'Cerah', partly: 'Berawan sebagian', overcast: 'Berawan',
    wind: 'Berangin', windStrong: 'Angin kencang', fog: 'Kabut', heat: 'Gelombang panas', night: 'Malam gerah', frost: 'Gelombang dingin' },
  bubble: { thunder: 'Petir!', downpour: 'Hujan deras!', heavysnow: 'Salju lebat!', blizzard: 'Badai salju!', windrain: 'Hujan angin!', windy: 'Berangin!', fog: 'Kabut tebal!', fogMid: 'Kabut tipis',
    heat: 'Gelombang panas!', tropical: 'Malam gerah!', cold: 'Gelombang dingin!', snow: 'Salju!', sleet: 'Hujan es!', rain: 'Hujan!', swing: 'Beda suhu besar!', umbrella: 'Bawa payung' },
  rainKind: ['Gerimis', 'Hujan ringan', 'Hujan sedang', 'Hujan lebat', 'Hujan sangat lebat'],
  rainKindNote: ['Cuma gerimis tipis', 'Bawa payung', 'Jangan lupa payung', 'Bawa payung dan jas hujan', 'Sebaiknya di rumah saja kalau bisa'],
  rainAmount: ['Sedikit', 'Sedang', 'Banyak', 'Sangat banyak'],
  feels: ['Sangat dingin', 'Dingin', 'Agak dingin', 'Sejuk', 'Sedang', 'Hangat', 'Panas', 'Sangat panas'],
  humidity: { veryDry: 'Sangat kering', dry: 'Kering', verySticky: 'Sangat lengket', sticky: 'Lengket', muggy: 'Gerah', damp: 'Pengap', humid: 'Lembap', bitHumid: 'Agak lembap', crisp: 'Segar', ok: 'Nyaman' },
  wind: ['Tenang', 'Angin lemah', 'Angin sepoi', 'Agak berangin', 'Cukup berangin', 'Berangin', 'Sangat berangin', 'Angin kencang · Hati-hati di luar'],
  uv: { none: 'Tidak ada data', low: 'Rendah', moderate: 'Sedang · Tabir surya', high: 'Tinggi · Tabir surya, topi', veryHigh: 'Sangat tinggi · Sebaiknya kurangi keluar di tengah hari', extreme: 'Ekstrem · Sebaiknya hindari keluar di tengah hari' },
  tile: { rainChance: 'Peluang hujan', uv: 'UV', sunset: 'Terbenam', sunrise: 'Terbit', humidity: 'Kelembapan', polarDay: 'Matahari tengah malam', polarNight: 'Malam kutub' },
  sunriseTomorrow: (t) => `Terbit besok ${t}`, sunsetAt: (t) => `Terbenam ${t}`,
  polarNote: { day: 'Matahari tidak terbenam', night: 'Matahari tidak terbit' },
  dewPoint: (d) => `Titik embun ${d}°`,
  nowWetNote: (what, amt) => `${what} sekarang · ${amt} dalam 12 jam ke depan`,
  noRain12h: 'Tidak ada hujan 12 jam ke depan',
  dust: {
    title: 'Kualitas udara', pm10: 'PM10', pm25: 'PM2.5', grade: ['Baik', 'Sedang', 'Buruk', 'Sangat buruk'],
    note: ['Udara bersih', 'Cukup baik', 'Udara berpolusi · Bawa masker', 'Udara sangat berpolusi · Pakai masker saat di luar'],
    watch: 'Waspada debu halus · Pakai masker saat di luar', warning: 'Peringatan debu halus · Sebaiknya di rumah dan pakai masker saat di luar',
    yellow: 'Debu kuning · Tutup jendela dan pakai masker saat di luar',
    src: { airkorea: 'AirKorea', openweather: 'OpenWeather' },
    bubble: ['', '', 'Udara buruk · Bawa masker', 'Udara sangat buruk · Pakai masker'],
  },
  src: { apple: 'Apple Weather', kma: 'KMA', met: 'MET Norway' },
  sep: ', ',
  alert: {
    todayCm: (n) => `${n}cm hari ini`, todayMm: (n, word) => `${n}mm hari ini (${word})`,
    snowCare: 'Hati-hati licin', rainCare: 'Bawa payung dan jas hujan',
    icy: 'Jalan licin, hati-hati di jalan bersalju', slippery: 'Jalan licin, hati-hati',
    heavyRain: 'Hujan banyak, bawa payung (jas hujan juga membantu)',
    windRain: 'Hujan angin kencang', gust: (g) => `Embusan ${g} m/s`, veryWindy: 'Angin sangat kencang',
    stayIn: 'Sebaiknya di rumah saja kalau bisa', flying: 'Hati-hati benda terbang dan payungmu', takeCare: 'Hati-hati saat keluar',
    heat: (hi) => `Tertinggi ${hi}°, pakai topi dan tabir surya, sering-sering minum air`, cold: (lo) => `Terendah ${lo}°, bawa sarung tangan, syal, dan penghangat tangan`,
    humidity: (rh) => `Kelembapan ${rh}%`, fire: 'Hati-hati dengan api',
    yellowDust: 'Debu kuning parah, bawa masker', fineDust: 'Kualitas udara buruk, bawa masker',
  },
};

export const weekdays = { Sun: 'Min', Mon: 'Sen', Tue: 'Sel', Wed: 'Rab', Thu: 'Kam', Fri: 'Jum', Sat: 'Sab' };

export const warnings = {
  '호우주의보': 'Waspada Hujan Lebat', '호우경보': 'Peringatan Hujan Lebat',
  '대설주의보': 'Waspada Salju Lebat', '대설경보': 'Peringatan Salju Lebat',
  '폭염주의보': 'Waspada Panas', '폭염경보': 'Peringatan Panas',
  '한파주의보': 'Waspada Gelombang Dingin', '한파경보': 'Peringatan Gelombang Dingin',
  '강풍주의보': 'Waspada Angin Kencang', '강풍경보': 'Peringatan Angin Kencang',
  '태풍주의보': 'Waspada Topan', '태풍경보': 'Peringatan Topan',
  '건조주의보': 'Waspada Cuaca Kering', '건조경보': 'Peringatan Cuaca Kering',
  '풍랑주의보': 'Waspada Gelombang Tinggi', '풍랑경보': 'Peringatan Gelombang Tinggi',
  '황사경보': 'Peringatan Debu Kuning',
};
