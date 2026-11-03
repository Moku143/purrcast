// Purrcast server words — Português (Brasil). Same keys and shape as the `en:` object in server/src/i18n.js.
// Clock words use the Brazilian 24-hour style: 15h · 15h–17h · por volta das 15h · amanhã 7h–9h.

// "das 15h" but "da 1h"
const das = (h) => (h === 1 ? 'da' : 'das');

export default {
  now: 'Agora', today: 'Hoje', tomorrow: 'Amanhã',
  hour: (h) => `${h}h`,
  // 15h–17h · por volta das 15h · amanhã 7h–9h
  when: (s, e, tomorrow) => {
    const w = s === e || e == null ? `por volta ${das(s)} ${s}h` : `${s}h–${e}h`;
    return tomorrow ? `amanhã ${w}` : w;
  },
  stopAt: (h, what) => `${what} até por volta ${das(h)} ${h}h`,            // Chuva até por volta das 18h
  partOfDay: { morning: 'manhã', afternoon: 'tarde', evening: 'noitinha', night: 'noite' },
  partTomorrow: (p) => `amanhã de ${p}`,
  what: { rain: 'Chuva', snow: 'Neve', sleet: 'Chuva com neve' },
  live: { nowFalling: (what, amt) => `${what} agora · ${amt}`, aboutCm: (n) => `cerca de ${n}cm`, over: 'A chuva parou',
    care: { rain: 'Leve um guarda-chuva', snow: 'Cuidado ao andar', sleet: 'Cuidado ao andar' } },
  expect: (when, what) => `${what} ${when}`,                               // Chuva 15h–17h
  cond: { thunder: 'Trovoada', heavy: 'Chuva forte', rain: 'Chuva', snow: 'Neve', heavysnow: 'Neve forte', sleet: 'Chuva com neve', clear: 'Céu limpo', partly: 'Parcialmente nublado', overcast: 'Nublado',
    wind: 'Vento', windStrong: 'Vento forte', fog: 'Nevoeiro', heat: 'Onda de calor', night: 'Noite abafada', frost: 'Onda de frio' },
  bubble: { thunder: 'Trovoada!', downpour: 'Temporal!', heavysnow: 'Neve forte!', blizzard: 'Nevasca!', windrain: 'Chuva com vento!', windy: 'Muito vento!', fog: 'Nevoeiro denso!', fogMid: 'Nevoeiro leve',
    heat: 'Onda de calor!', tropical: 'Noite abafada!', cold: 'Onda de frio!', snow: 'Neve!', sleet: 'Chuva com neve!', rain: 'Chuva!', swing: 'Muita variação!', umbrella: 'Leve um guarda-chuva' },
  rainKind: ['Garoa', 'Chuva fraca', 'Chuva moderada', 'Chuva forte', 'Chuva muito forte'],
  rainKindNote: ['Só uma garoa leve', 'Leve um guarda-chuva', 'Não esqueça o guarda-chuva', 'Leve guarda-chuva e capa de chuva', 'Melhor ficar em casa se puder'],
  rainAmount: ['Leve', 'Moderada', 'Forte', 'Muito forte'],
  feels: ['Congelante', 'Frio', 'Friozinho', 'Fresco', 'Ameno', 'Quentinho', 'Quente', 'Muito quente'],
  humidity: { veryDry: 'Muito seco', dry: 'Seco', verySticky: 'Muito pegajoso', sticky: 'Pegajoso', muggy: 'Abafado', damp: 'Bem úmido', humid: 'Úmido', bitHumid: 'Um pouco úmido', crisp: 'Sequinho', ok: 'Agradável' },
  wind: ['Sem vento', 'Vento fraco', 'Brisa leve', 'Um pouco de vento', 'Bastante vento', 'Vento forte', 'Vento muito forte', 'Vendaval · Cuidado ao sair'],
  uv: { none: 'Sem dados', low: 'Baixo', moderate: 'Moderado · Protetor solar', high: 'Alto · Protetor solar, chapéu', veryHigh: 'Muito alto · Melhor limitar as saídas ao meio-dia', extreme: 'Extremo · Melhor evitar sair ao meio-dia' },
  tile: { rainChance: 'Chance de chuva', uv: 'UV', sunset: 'Pôr do sol', sunrise: 'Nascer do sol', humidity: 'Umidade', polarDay: 'Sol da meia-noite', polarNight: 'Noite polar' },
  sunriseTomorrow: (t) => `Nascer do sol amanhã ${t}`, sunsetAt: (t) => `Pôr do sol ${t}`,
  polarNote: { day: 'O sol não se põe', night: 'O sol não nasce' },
  dewPoint: (d) => `Ponto de orvalho ${d}°`,
  nowWetNote: (what, amt) => `${what} agora · ${amt} nas próximas 12h`,
  noRain12h: 'Sem chuva nas próximas 12 horas',
  dust: {
    title: 'Qualidade do ar', pm10: 'PM10', pm25: 'PM2.5', grade: ['Boa', 'Moderada', 'Ruim', 'Muito ruim'],
    note: ['O ar está limpo', 'Está razoável', 'O ar está pesado · Leve uma máscara', 'Ar muito pesado · Use máscara ao sair'],
    watch: 'Aviso de poeira fina · Use máscara ao sair', warning: 'Alerta de poeira fina · Fique em casa se puder e use máscara ao sair',
    yellow: 'Poeira amarela · Feche as janelas e use máscara ao sair',
    src: { airkorea: 'AirKorea', openweather: 'OpenWeather' },
    bubble: ['', '', 'Ar ruim · Leve uma máscara', 'Ar muito ruim · Use máscara'],
  },
  src: { apple: 'Apple Weather', kma: 'KMA', met: 'MET Norway' },
  sep: ', ',
  alert: {
    todayCm: (n) => `${n}cm hoje`, todayMm: (n, word) => `${n}mm hoje (${word})`,
    snowCare: 'Cuidado ao andar', rainCare: 'Leve guarda-chuva e capa de chuva',
    icy: 'Chão escorregadio, cuidado ao andar na neve', slippery: 'Chão escorregadio, cuidado ao andar',
    heavyRain: 'Muita chuva, leve um guarda-chuva (uma capa de chuva também ajuda)',
    windRain: 'Chuva e vento fortes', gust: (g) => `Rajadas ${g} m/s`, veryWindy: 'Vento muito forte',
    stayIn: 'Melhor ficar em casa se puder', flying: 'Cuidado com objetos voando e com o guarda-chuva', takeCare: 'Cuidado ao sair',
    heat: (hi) => `Máx. ${hi}°, use chapéu e protetor solar e beba água com frequência`, cold: (lo) => `Mín. ${lo}°, leve luvas, cachecol e aquecedor de mãos`,
    humidity: (rh) => `Umidade ${rh}%`, fire: 'Cuidado com fogo',
    yellowDust: 'Muita poeira amarela, leve uma máscara', fineDust: 'Ar ruim, leve uma máscara',
  },
};

export const weekdays = { Sun: 'dom', Mon: 'seg', Tue: 'ter', Wed: 'qua', Thu: 'qui', Fri: 'sex', Sat: 'sáb' };

export const warnings = {
  호우주의보: 'Aviso de chuva forte', 호우경보: 'Alerta de chuva forte',
  대설주의보: 'Aviso de neve forte', 대설경보: 'Alerta de neve forte',
  폭염주의보: 'Aviso de calor', 폭염경보: 'Alerta de calor',
  한파주의보: 'Aviso de frio intenso', 한파경보: 'Alerta de frio intenso',
  강풍주의보: 'Aviso de vento forte', 강풍경보: 'Alerta de vento forte',
  태풍주의보: 'Aviso de tufão', 태풍경보: 'Alerta de tufão',
  건조주의보: 'Aviso de tempo seco', 건조경보: 'Alerta de tempo seco',
  풍랑주의보: 'Aviso de mar agitado', 풍랑경보: 'Alerta de mar agitado',
  황사경보: 'Alerta de poeira amarela',
};
