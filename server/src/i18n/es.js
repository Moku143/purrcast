// Spanish (neutral, understood in Spain and Latin America) — the same keys and shape as the `en:` object in src/i18n.js.
// Clock words use the 24-hour clock: 15:00 · 15–17 h · hacia las 15:00 · mañana 7–9 h.

const h24 = (h) => `${h}:00`;

export default {
  now: 'Ahora', today: 'Hoy', tomorrow: 'Mañana',
  hour: (h) => h24(h),
  // 15–17 h · hacia las 15:00 · mañana 7–9 h
  when: (s, e, tomorrow) => {
    const w = s === e || e == null ? `hacia las ${h24(s)}` : `${s}–${e} h`;
    return tomorrow ? `mañana ${w}` : w;
  },
  stopAt: (h, what) => `${what} hasta las ${h24(h)}`,
  partOfDay: { morning: 'por la mañana', afternoon: 'por la tarde', evening: 'al anochecer', night: 'por la noche' },
  partTomorrow: (p) => `mañana ${p}`,                                     // Lluvia mañana por la tarde
  what: { rain: 'Lluvia', snow: 'Nieve', sleet: 'Aguanieve' },
  live: { nowFalling: (what, amt) => `${what} ahora · ${amt}`, aboutCm: (n) => `unos ${n} cm`, over: 'Ha dejado de llover',
    care: { rain: 'Lleva paraguas', snow: 'Cuidado, resbala', sleet: 'Cuidado, resbala' } },
  expect: (when, what) => `${what} ${when}`,                             // Lluvia 15–17 h
  cond: { thunder: 'Tormenta', heavy: 'Lluvia intensa', rain: 'Lluvia', snow: 'Nieve', heavysnow: 'Nevada intensa', sleet: 'Aguanieve', clear: 'Despejado', partly: 'Parcialmente nublado', overcast: 'Nublado',
    wind: 'Viento', windStrong: 'Viento fuerte', fog: 'Niebla', heat: 'Ola de calor', night: 'Noche tropical', frost: 'Ola de frío' },
  bubble: { thunder: '¡Relámpagos!', downpour: '¡Aguacero!', heavysnow: '¡Nevada intensa!', blizzard: '¡Ventisca!', windrain: '¡Viento y lluvia!', windy: '¡Hace viento!', fog: '¡Niebla densa!', fogMid: 'Niebla ligera',
    heat: '¡Ola de calor!', tropical: '¡Noche tropical!', cold: '¡Ola de frío!', snow: '¡Nieve!', sleet: '¡Aguanieve!', rain: '¡Lluvia!', swing: '¡Gran amplitud térmica!', umbrella: 'Lleva paraguas' },
  rainKind: ['Llovizna', 'Lluvia débil', 'Lluvia moderada', 'Lluvia intensa', 'Lluvia muy intensa'],
  rainKindNote: ['Solo una llovizna ligera', 'Lleva paraguas', 'No olvides el paraguas', 'Lleva paraguas e impermeable', 'Mejor quedarse en casa si puedes'],
  rainAmount: ['Poca', 'Moderada', 'Mucha', 'Muchísima'],
  feels: ['Gélido', 'Frío', 'Fresco', 'Agradable', 'Templado', 'Cálido', 'Calor', 'Mucho calor'],
  humidity: { veryDry: 'Muy seco', dry: 'Seco', verySticky: 'Muy pegajoso', sticky: 'Pegajoso', muggy: 'Bochornoso', damp: 'Cargado', humid: 'Húmedo', bitHumid: 'Algo húmedo', crisp: 'Ambiente fresco', ok: 'Confortable' },
  wind: ['Calma', 'Ventolina', 'Brisa suave', 'Algo de viento', 'Bastante viento', 'Viento fuerte', 'Viento muy fuerte', 'Temporal · Cuidado al salir'],
  uv: { none: 'Sin datos', low: 'Bajo', moderate: 'Moderado · Protector solar', high: 'Alto · Protector solar, gorro', veryHigh: 'Muy alto · Mejor salir poco al mediodía', extreme: 'Extremo · Mejor no salir al mediodía' },
  tile: { rainChance: 'Prob. de lluvia', uv: 'UV', sunset: 'Atardecer', sunrise: 'Amanecer', humidity: 'Humedad', polarDay: 'Sol de medianoche', polarNight: 'Noche polar' },
  sunriseTomorrow: (t) => `Amanecer mañana ${t}`, sunsetAt: (t) => `Atardecer ${t}`,
  polarNote: { day: 'El sol no se pone', night: 'El sol no sale' },
  dewPoint: (d) => `Punto de rocío ${d}°`,
  nowWetNote: (what, amt) => `${what} ahora · ${amt} en las próximas 12 h`,
  noRain12h: 'Sin lluvia en las próximas 12 horas',
  dust: {
    title: 'Calidad del aire', pm10: 'PM10', pm25: 'PM2.5', grade: ['Buena', 'Moderada', 'Mala', 'Muy mala'],
    note: ['El aire está limpio', 'Bastante bien', 'El aire está turbio · Lleva mascarilla', 'Aire muy turbio · Usa mascarilla al salir'],
    watch: 'Aviso por partículas · Usa mascarilla al salir', warning: 'Alerta por partículas · Quédate en casa si puedes y usa mascarilla al salir',
    yellow: 'Polvo amarillo · Cierra las ventanas y usa mascarilla al salir',
    src: { airkorea: 'AirKorea', openweather: 'OpenWeather' },
    bubble: ['', '', 'Aire malo · Lleva mascarilla', 'Aire muy malo · Usa mascarilla'],
  },
  src: { apple: 'Apple Weather', kma: 'KMA', met: 'MET Norway' },
  sep: ', ',
  alert: {
    todayCm: (n) => `${n} cm hoy`, todayMm: (n, word) => `${n} mm hoy (${word})`,
    snowCare: 'Cuidado, resbala', rainCare: 'Lleva paraguas e impermeable',
    icy: 'El suelo resbala, cuidado con la nieve', slippery: 'El suelo resbala, ten cuidado',
    heavyRain: 'Mucha lluvia, lleva paraguas (un impermeable también ayuda)',
    windRain: 'Viento y lluvia fuertes', gust: (g) => `Rachas de ${g} m/s`, veryWindy: 'Viento muy fuerte',
    stayIn: 'Mejor quedarse en casa si puedes', flying: 'Cuidado con los objetos que vuelan y con el paraguas', takeCare: 'Ten cuidado al salir',
    heat: (hi) => `Máxima de ${hi}°, ponte gorro y protector solar y bebe agua a menudo`, cold: (lo) => `Mínima de ${lo}°, lleva guantes, bufanda y un calentador de manos`,
    humidity: (rh) => `Humedad ${rh}%`, fire: 'Cuidado con el fuego',
    yellowDust: 'Mucho polvo amarillo, lleva mascarilla', fineDust: 'Mala calidad del aire, lleva mascarilla',
  },
};

export const weekdays = { Sun: 'dom', Mon: 'lun', Tue: 'mar', Wed: 'mié', Thu: 'jue', Fri: 'vie', Sat: 'sáb' };

export const warnings = {
  호우주의보: 'Aviso por lluvia intensa', 호우경보: 'Alerta por lluvia intensa',
  대설주의보: 'Aviso por nevada intensa', 대설경보: 'Alerta por nevada intensa',
  폭염주의보: 'Aviso por calor', 폭염경보: 'Alerta por calor',
  한파주의보: 'Aviso por ola de frío', 한파경보: 'Alerta por ola de frío',
  강풍주의보: 'Aviso por viento', 강풍경보: 'Alerta por viento',
  태풍주의보: 'Aviso por tifón', 태풍경보: 'Alerta por tifón',
  건조주의보: 'Aviso por tiempo seco', 건조경보: 'Alerta por tiempo seco',
  풍랑주의보: 'Aviso por oleaje', 풍랑경보: 'Alerta por oleaje',
  황사경보: 'Alerta por polvo amarillo',
};
