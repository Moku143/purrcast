// Purrcast server words — italiano. Same keys and shape as the `en` object in src/i18n.js.
// Clock words: 24-hour, "15:00" · "15–17" · "verso le 15:00" · "domani 7–9".

const hh = (h) => `${h}:00`;
const le = (h) => (h === 1 ? "l'" : 'le ');        // verso le 15:00 · verso l'1:00
const alle = (h) => (h === 1 ? "all'" : 'alle ');  // fino alle 18:00 · fino all'1:00

export default {
  now: 'Ora', today: 'Oggi', tomorrow: 'Domani',
  hour: (h) => hh(h),
  // 15–17 · verso le 15:00 · domani 7–9
  when: (s, e, tomorrow) => {
    const w = s === e || e == null ? `verso ${le(s)}${hh(s)}` : `${s}–${e}`;
    return tomorrow ? `domani ${w}` : w;
  },
  stopAt: (h, what) => `${what} fino ${alle(h)}${hh(h)} circa`,         // Pioggia fino alle 18:00 circa
  partOfDay: { morning: 'mattina', afternoon: 'pomeriggio', evening: 'sera', night: 'notte' },
  partTomorrow: (p) => `domani ${p}`,                                  // domani pomeriggio
  what: { rain: 'Pioggia', snow: 'Neve', sleet: 'Nevischio' },
  live: { nowFalling: (what, amt) => `${what} in corso · ${amt}`, aboutCm: (n) => `circa ${n} cm`, over: 'Ha smesso di piovere',
    care: { rain: "Porta l'ombrello", snow: 'Attenzione, si scivola', sleet: 'Attenzione, si scivola' } },
  expect: (when, what) => `${what} ${when}`,                             // Pioggia 15–17
  cond: { thunder: 'Temporale', heavy: 'Pioggia forte', rain: 'Pioggia', snow: 'Neve', heavysnow: 'Forte nevicata', sleet: 'Nevischio', clear: 'Sereno', partly: 'Poco nuvoloso', overcast: 'Nuvoloso',
    wind: 'Ventoso', windStrong: 'Vento forte', fog: 'Nebbia', heat: 'Caldo intenso', night: 'Notte tropicale', frost: 'Gelo' },
  bubble: { thunder: 'Temporale!', downpour: 'Nubifragio!', heavysnow: 'Forte nevicata!', blizzard: 'Bufera di neve!', windrain: 'Vento e pioggia!', windy: 'Ventoso!', fog: 'Nebbia fitta!', fogMid: 'Nebbia leggera',
    heat: 'Caldo intenso!', tropical: 'Notte tropicale!', cold: 'Gelo!', snow: 'Neve!', sleet: 'Nevischio!', rain: 'Pioggia!', swing: 'Forte escursione!', umbrella: "Porta l'ombrello" },
  rainKind: ['Pioviggine', 'Pioggia debole', 'Pioggia moderata', 'Pioggia forte', 'Pioggia molto forte'],
  rainKindNote: ['Solo pioggerella', "Porta l'ombrello", "Non dimenticare l'ombrello", 'Porta ombrello e impermeabile', 'Se puoi, meglio restare al chiuso'],
  rainAmount: ['Debole', 'Moderata', 'Abbondante', 'Molto abbondante'],
  feels: ['Gelido', 'Freddo', 'Freddino', 'Fresco', 'Mite', 'Caldo', 'Molto caldo', 'Torrido'],
  humidity: { veryDry: 'Molto secco', dry: 'Secco', verySticky: 'Molto afoso', sticky: 'Afoso', muggy: 'Pesante', damp: 'Umidiccio', humid: 'Umido', bitHumid: "Un po' umido", crisp: 'Asciutto', ok: 'Confortevole' },
  wind: ['Niente vento', 'Vento debole', 'Brezza leggera', "Un po' ventoso", 'Abbastanza ventoso', 'Ventoso', 'Molto ventoso', 'Burrasca · Fai attenzione fuori'],
  uv: { none: 'Nessun dato', low: 'Basso', moderate: 'Moderato · Crema solare', high: 'Alto · Crema solare, cappello', veryHigh: 'Molto alto · Meglio uscire poco nelle ore centrali', extreme: 'Estremo · Meglio non uscire nelle ore centrali' },
  tile: { rainChance: 'Prob. pioggia', uv: 'UV', sunset: 'Tramonto', sunrise: 'Alba', humidity: 'Umidità', polarDay: 'Sole di mezzanotte', polarNight: 'Notte polare' },
  sunriseTomorrow: (t) => `Alba domani ${t}`, sunsetAt: (t) => `Tramonto ${t}`,
  polarNote: { day: 'Il sole non tramonta', night: 'Il sole non sorge' },
  dewPoint: (d) => `Punto di rugiada ${d}°`,
  nowWetNote: (what, amt) => `${what} in corso · ${amt} nelle prossime 12 ore`,
  noRain12h: 'Niente pioggia nelle prossime 12 ore',
  dust: {
    title: "Qualità dell'aria", pm10: 'PM10', pm25: 'PM2.5', grade: ['Buono', 'Moderato', 'Scadente', 'Molto scadente'],
    note: ["L'aria è pulita", 'Tutto sommato bene', 'Aria poco pulita · Porta la mascherina', "Aria inquinata · Indossa la mascherina all'aperto"],
    watch: "Avviso polveri sottili · Indossa la mascherina all'aperto", warning: "Allerta polveri sottili · Se puoi resta al chiuso e indossa la mascherina all'aperto",
    yellow: "Sabbia gialla · Chiudi le finestre e indossa la mascherina all'aperto",
    src: { airkorea: 'AirKorea', openweather: 'OpenWeather' },
    bubble: ['', '', 'Aria scadente · Porta la mascherina', 'Aria molto scadente · Indossa la mascherina'],
  },
  src: { apple: 'Apple Weather', kma: 'KMA', met: 'MET Norway' },
  sep: ', ',
  alert: {
    todayCm: (n) => `${n} cm oggi`, todayMm: (n, word) => `${n} mm oggi (${word})`,
    snowCare: 'Attenzione, si scivola', rainCare: 'Porta ombrello e impermeabile',
    icy: 'Terreno scivoloso, attenzione sulla neve', slippery: 'Terreno scivoloso, fai attenzione',
    heavyRain: "Tanta pioggia, porta l'ombrello (meglio anche l'impermeabile)",
    windRain: 'Vento forte e pioggia', gust: (g) => `Raffiche ${g} m/s`, veryWindy: 'Vento molto forte',
    stayIn: 'Se puoi, meglio restare al chiuso', flying: "Attenzione agli oggetti in volo e all'ombrello", takeCare: 'Fai attenzione quando esci',
    heat: (hi) => `Massima ${hi}°, metti cappello e crema solare e bevi spesso`, cold: (lo) => `Minima ${lo}°, porta guanti, sciarpa e scaldamani`,
    humidity: (rh) => `Umidità ${rh}%`, fire: 'Attenzione al fuoco',
    yellowDust: 'Molta sabbia gialla, porta la mascherina', fineDust: 'Aria di cattiva qualità, porta la mascherina',
  },
};

export const weekdays = { Sun: 'dom', Mon: 'lun', Tue: 'mar', Wed: 'mer', Thu: 'gio', Fri: 'ven', Sat: 'sab' };

// KMA warnings: 주의보 (advisory, the lower level) → "Avviso …", 경보 (warning, the higher level) → "Allerta …".
export const warnings = {
  호우주의보: 'Avviso forti piogge', 호우경보: 'Allerta forti piogge',
  대설주의보: 'Avviso forti nevicate', 대설경보: 'Allerta forti nevicate',
  폭염주의보: 'Avviso caldo intenso', 폭염경보: 'Allerta caldo intenso',
  한파주의보: 'Avviso gelo', 한파경보: 'Allerta gelo',
  강풍주의보: 'Avviso vento forte', 강풍경보: 'Allerta vento forte',
  태풍주의보: 'Avviso tifone', 태풍경보: 'Allerta tifone',
  건조주의보: 'Avviso tempo secco', 건조경보: 'Allerta tempo secco',
  풍랑주의보: 'Avviso mare agitato', 풍랑경보: 'Allerta mare agitato',
  황사경보: 'Allerta sabbia gialla',
};
