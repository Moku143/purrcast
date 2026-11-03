// Purrcast server words — Deutsch (Deutschland). Same keys and shape as the `en` object in src/i18n.js.
// Clock words: 24-hour with "Uhr", "15 Uhr" · "15–17 Uhr" · "gegen 15 Uhr" · "morgen 7–9 Uhr".
// Imperatives that only ever follow a comma inside alertNote's join (snowCare, rainCare, stayIn, flying) start
// lower case, as German writes them mid-sentence.

const uhr = (h) => `${h} Uhr`;
// partOfDay words → the same part of tomorrow ("morgens" → "morgen früh")
const TOMORROW = { morgens: 'morgen früh', nachmittags: 'morgen Nachmittag', abends: 'morgen Abend', nachts: 'morgen Nacht' };

export default {
  now: 'Jetzt', today: 'Heute', tomorrow: 'Morgen',
  hour: (h) => uhr(h),
  // 15–17 Uhr · gegen 15 Uhr · morgen 7–9 Uhr
  when: (s, e, tomorrow) => {
    const w = s === e || e == null ? `gegen ${uhr(s)}` : `${s}–${e} Uhr`;
    return tomorrow ? `morgen ${w}` : w;
  },
  stopAt: (h, what) => `${what} bis etwa ${uhr(h)}`,
  partOfDay: { morning: 'morgens', afternoon: 'nachmittags', evening: 'abends', night: 'nachts' },
  partTomorrow: (p) => TOMORROW[p] ?? `morgen ${p}`,
  what: { rain: 'Regen', snow: 'Schnee', sleet: 'Schneeregen' },
  live: { nowFalling: (what, amt) => `Jetzt ${what} · ${amt}`, aboutCm: (n) => `etwa ${n} cm`, over: 'Der Regen hat aufgehört',
    care: { rain: 'Nimm einen Schirm mit', snow: 'Pass auf, es ist glatt', sleet: 'Pass auf, es ist glatt' } },
  expect: (when, what) => `${what} ${when}`,                             // Regen 15–17 Uhr
  cond: { thunder: 'Gewitter', heavy: 'Starker Regen', rain: 'Regen', snow: 'Schnee', heavysnow: 'Starker Schneefall', sleet: 'Schneeregen', clear: 'Klar', partly: 'Teilweise bewölkt', overcast: 'Bewölkt',
    wind: 'Windig', windStrong: 'Starker Wind', fog: 'Nebel', heat: 'Hitzewelle', night: 'Tropennacht', frost: 'Kältewelle' },
  bubble: { thunder: 'Gewitter!', downpour: 'Wolkenbruch!', heavysnow: 'Starker Schneefall!', blizzard: 'Schneesturm!', windrain: 'Wind und Regen!', windy: 'Windig!', fog: 'Dichter Nebel!', fogMid: 'Leichter Nebel',
    heat: 'Hitzewelle!', tropical: 'Tropennacht!', cold: 'Kältewelle!', snow: 'Schnee!', sleet: 'Schneeregen!', rain: 'Regen!', swing: 'Große Schwankung!', umbrella: 'Nimm einen Schirm mit' },
  rainKind: ['Nieselregen', 'Leichter Regen', 'Mäßiger Regen', 'Starker Regen', 'Sehr starker Regen'],
  rainKindNote: ['Nur leichter Nieselregen', 'Nimm einen Schirm mit', 'Vergiss den Schirm nicht', 'Nimm Schirm und Regenjacke mit', 'Bleib lieber drinnen, wenn du kannst'],
  rainAmount: ['Wenig', 'Mäßig', 'Viel', 'Sehr viel'],
  feels: ['Eiskalt', 'Kalt', 'Kühl', 'Frisch', 'Mild', 'Warm', 'Heiß', 'Sehr heiß'],
  humidity: { veryDry: 'Sehr trocken', dry: 'Trocken', verySticky: 'Sehr klebrig', sticky: 'Klebrig', muggy: 'Schwül', damp: 'Klamm', humid: 'Feucht', bitHumid: 'Etwas feucht', crisp: 'Angenehm trocken', ok: 'Angenehm' },
  wind: ['Windstill', 'Leiser Zug', 'Leichte Brise', 'Etwas Wind', 'Ziemlich windig', 'Windig', 'Sehr windig', 'Sturm · Draußen aufpassen'],
  uv: { none: 'Keine Daten', low: 'Niedrig', moderate: 'Mäßig · Sonnencreme', high: 'Hoch · Sonnencreme, Hut', veryHigh: 'Sehr hoch · Mittags lieber weniger draußen sein', extreme: 'Extrem · Mittags lieber drinnen bleiben' },
  tile: { rainChance: 'Regenchance', uv: 'UV', sunset: 'Sonnenuntergang', sunrise: 'Sonnenaufgang', humidity: 'Luftfeuchtigkeit', polarDay: 'Mitternachtssonne', polarNight: 'Polarnacht' },
  sunriseTomorrow: (t) => `Aufgang morgen ${t}`, sunsetAt: (t) => `Untergang ${t}`,
  polarNote: { day: 'Die Sonne geht nicht unter', night: 'Die Sonne geht nicht auf' },
  dewPoint: (d) => `Taupunkt ${d}°`,
  nowWetNote: (what, amt) => `Jetzt ${what} · ${amt} in den nächsten 12 h`,
  noRain12h: 'Kein Regen in den nächsten 12 Stunden',
  dust: {
    title: 'Luftqualität', pm10: 'PM10', pm25: 'PM2.5', grade: ['Gut', 'Mäßig', 'Schlecht', 'Sehr schlecht'],
    note: ['Die Luft ist klar', 'Geht so', 'Die Luft ist trüb · Nimm eine Maske mit', 'Sehr trübe Luft · Draußen Maske tragen'],
    watch: 'Feinstaubwarnung · Draußen Maske tragen', warning: 'Feinstaubalarm · Bleib möglichst drinnen und trag draußen eine Maske',
    yellow: 'Gelbstaub · Fenster schließen und draußen Maske tragen',
    src: { airkorea: 'AirKorea', openweather: 'OpenWeather' },
    bubble: ['', '', 'Schlechte Luft · Nimm eine Maske mit', 'Sehr schlechte Luft · Vergiss die Maske nicht'],
  },
  src: { apple: 'Apple Weather', kma: 'KMA', met: 'MET Norway' },
  sep: ', ',
  alert: {
    todayCm: (n) => `Heute ${n} cm`, todayMm: (n, word) => `Heute ${n} mm (${word})`,
    snowCare: 'pass auf, es ist glatt', rainCare: 'nimm Schirm und Regenjacke mit',
    icy: 'Glatte Wege, pass im Schnee gut auf', slippery: 'Glatte Wege, pass gut auf',
    heavyRain: 'Viel Regen, nimm einen Schirm mit (eine Regenjacke hilft auch)',
    windRain: 'Starker Wind und Regen', gust: (g) => `Böen ${g} m/s`, veryWindy: 'Sehr starker Wind',
    stayIn: 'bleib lieber drinnen, wenn du kannst', flying: 'achte auf herumfliegende Dinge und deinen Schirm', takeCare: 'Pass draußen gut auf dich auf',
    heat: (hi) => `Hoch ${hi}°, denk an Hut und Sonnencreme und trink viel Wasser`, cold: (lo) => `Tief ${lo}°, nimm Handschuhe, Schal und Handwärmer mit`,
    humidity: (rh) => `Luftfeuchtigkeit ${rh} %`, fire: 'Vorsicht mit Feuer',
    yellowDust: 'Starker Gelbstaub, nimm eine Maske mit', fineDust: 'Schlechte Luft, nimm eine Maske mit',
  },
};

export const weekdays = { Sun: 'So', Mon: 'Mo', Tue: 'Di', Wed: 'Mi', Thu: 'Do', Fri: 'Fr', Sat: 'Sa' };

export const warnings = {
  호우주의보: 'Warnung: Starkregen', 호우경보: 'Unwetterwarnung: Starkregen',
  대설주의보: 'Warnung: Schneefall', 대설경보: 'Unwetterwarnung: Schneefall',
  폭염주의보: 'Hitzewarnung', 폭염경보: 'Warnung vor extremer Hitze',
  한파주의보: 'Kältewarnung', 한파경보: 'Warnung vor strengem Frost',
  강풍주의보: 'Warnung: Sturmböen', 강풍경보: 'Unwetterwarnung: Orkanböen',
  태풍주의보: 'Warnung: Taifun', 태풍경보: 'Unwetterwarnung: Taifun',
  건조주의보: 'Warnung: Trockenheit', 건조경보: 'Warnung: große Trockenheit',
  풍랑주의보: 'Warnung: hoher Seegang', 풍랑경보: 'Unwetterwarnung: hoher Seegang',
  황사경보: 'Gelbstaubwarnung',
};
