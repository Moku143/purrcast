// Purrcast server words — français (France). Same keys and shape as the `en` object in src/i18n.js.
// Clock words: 24-hour, "15 h" · "15 h–17 h" · "vers 15 h" · "demain 7 h–9 h".

const hr = (h) => `${h} h`;

export default {
  now: 'Maintenant', today: 'Aujourd’hui', tomorrow: 'Demain',
  hour: (h) => hr(h),
  // 15 h–17 h · vers 15 h · demain 7 h–9 h
  when: (s, e, tomorrow) => {
    const w = s === e || e == null ? `vers ${hr(s)}` : `${hr(s)}–${hr(e)}`;
    return tomorrow ? `demain ${w}` : w;
  },
  stopAt: (h, what) => `${what} jusque vers ${hr(h)}`,
  partOfDay: { morning: 'matin', afternoon: 'après-midi', evening: 'soir', night: 'nuit' },
  partTomorrow: (p) => `demain ${p}`,
  what: { rain: 'Pluie', snow: 'Neige', sleet: 'Neige fondue' },
  live: { nowFalling: (what, amt) => `${what} maintenant · ${amt}`, aboutCm: (n) => `env. ${n} cm`, over: 'La pluie s’est arrêtée',
    care: { rain: 'Prenez un parapluie', snow: 'Attention, ça glisse', sleet: 'Attention, ça glisse' } },
  expect: (when, what) => `${what} ${when}`,                             // Pluie 15 h–17 h
  cond: { thunder: 'Orage', heavy: 'Pluie forte', rain: 'Pluie', snow: 'Neige', heavysnow: 'Fortes neiges', sleet: 'Neige fondue', clear: 'Dégagé', partly: 'Partiellement nuageux', overcast: 'Nuageux',
    wind: 'Venteux', windStrong: 'Vent fort', fog: 'Brouillard', heat: 'Canicule', night: 'Nuit tropicale', frost: 'Vague de froid' },
  bubble: { thunder: 'Éclairs !', downpour: 'Déluge !', heavysnow: 'Fortes neiges !', blizzard: 'Blizzard !', windrain: 'Vent et pluie !', windy: 'Venteux !', fog: 'Brouillard dense !', fogMid: 'Brouillard léger',
    heat: 'Canicule !', tropical: 'Nuit tropicale !', cold: 'Vague de froid !', snow: 'Neige !', sleet: 'Neige fondue !', rain: 'Pluie !', swing: 'Forte amplitude !', umbrella: 'Prenez un parapluie' },
  rainKind: ['Bruine', 'Pluie faible', 'Pluie modérée', 'Pluie forte', 'Pluie très forte'],
  rainKindNote: ['Juste une petite bruine', 'Prenez un parapluie', 'N’oubliez pas le parapluie', 'Prenez un parapluie et un imperméable', 'Mieux vaut rester à l’intérieur si possible'],
  rainAmount: ['Faible', 'Modérée', 'Forte', 'Très forte'],
  feels: ['Glacial', 'Froid', 'Frisquet', 'Frais', 'Doux', 'Chaud', 'Très chaud', 'Caniculaire'],
  humidity: { veryDry: 'Très sec', dry: 'Sec', verySticky: 'Très collant', sticky: 'Collant', muggy: 'Lourd', damp: 'Moite', humid: 'Humide', bitHumid: 'Un peu humide', crisp: 'Léger', ok: 'Confortable' },
  wind: ['Calme', 'Vent très léger', 'Brise légère', 'Un peu de vent', 'Assez venteux', 'Venteux', 'Très venteux', 'Tempête · Prudence dehors'],
  uv: { none: 'Pas de données', low: 'Faible', moderate: 'Modéré · Crème solaire', high: 'Fort · Crème solaire, chapeau', veryHigh: 'Très fort · Mieux vaut limiter les sorties à la mi-journée', extreme: 'Extrême · Mieux vaut éviter les sorties à la mi-journée' },
  tile: { rainChance: 'Risque de pluie', uv: 'UV', sunset: 'Coucher', sunrise: 'Lever', humidity: 'Humidité', polarDay: 'Soleil de minuit', polarNight: 'Nuit polaire' },
  sunriseTomorrow: (t) => `Lever demain ${t}`, sunsetAt: (t) => `Coucher ${t}`,
  polarNote: { day: 'Le soleil ne se couche pas', night: 'Le soleil ne se lève pas' },
  dewPoint: (d) => `Point de rosée ${d}°`,
  nowWetNote: (what, amt) => `${what} maintenant · ${amt} dans les 12 prochaines heures`,
  noRain12h: 'Pas de pluie dans les 12 prochaines heures',
  dust: {
    title: 'Qualité de l’air', pm10: 'PM10', pm25: 'PM2.5', grade: ['Bon', 'Moyen', 'Mauvais', 'Très mauvais'],
    note: ['L’air est pur', 'Plutôt correct', 'L’air est voilé · Prenez un masque', 'Air très voilé · Portez un masque dehors'],
    watch: 'Vigilance particules fines · Portez un masque dehors', warning: 'Alerte particules fines · Restez à l’intérieur si possible et portez un masque dehors',
    yellow: 'Poussière jaune · Fermez les fenêtres et portez un masque dehors',
    src: { airkorea: 'AirKorea', openweather: 'OpenWeather' },
    bubble: ['', '', 'Air mauvais · Prenez un masque', 'Air très mauvais · Portez un masque'],
  },
  src: { apple: 'Apple Weather', kma: 'KMA', met: 'MET Norway' },
  sep: ', ',
  alert: {
    todayCm: (n) => `${n} cm aujourd’hui`, todayMm: (n, word) => `${n} mm aujourd’hui (${word})`,
    snowCare: 'Attention, ça glisse', rainCare: 'Prenez un parapluie et un imperméable',
    icy: 'Sol glissant, attention sur la neige', slippery: 'Sol glissant, faites attention',
    heavyRain: 'Beaucoup de pluie, prenez un parapluie (un imperméable aide aussi)',
    windRain: 'Vent fort et pluie', gust: (g) => `Rafales ${g} m/s`, veryWindy: 'Vent très fort',
    stayIn: 'Mieux vaut rester à l’intérieur si possible', flying: 'Attention aux objets qui s’envolent et à votre parapluie', takeCare: 'Soyez prudent en sortant',
    heat: (hi) => `Max ${hi}°, portez un chapeau et de la crème solaire et buvez souvent`, cold: (lo) => `Min ${lo}°, prenez des gants, une écharpe et une chaufferette`,
    humidity: (rh) => `Humidité ${rh}%`, fire: 'Attention au feu',
    yellowDust: 'Beaucoup de poussière jaune, prenez un masque', fineDust: 'Air de mauvaise qualité, prenez un masque',
  },
};

export const weekdays = { Sun: 'dim', Mon: 'lun', Tue: 'mar', Wed: 'mer', Thu: 'jeu', Fri: 'ven', Sat: 'sam' };

export const warnings = {
  호우주의보: 'Vigilance fortes pluies', 호우경보: 'Alerte fortes pluies',
  대설주의보: 'Vigilance fortes neiges', 대설경보: 'Alerte fortes neiges',
  폭염주의보: 'Vigilance canicule', 폭염경보: 'Alerte canicule',
  한파주의보: 'Vigilance grand froid', 한파경보: 'Alerte grand froid',
  강풍주의보: 'Vigilance vent fort', 강풍경보: 'Alerte vent fort',
  태풍주의보: 'Vigilance typhon', 태풍경보: 'Alerte typhon',
  건조주의보: 'Vigilance air sec', 건조경보: 'Alerte air sec',
  풍랑주의보: 'Vigilance mer forte', 풍랑경보: 'Alerte mer forte',
  황사경보: 'Alerte poussière jaune',
};
