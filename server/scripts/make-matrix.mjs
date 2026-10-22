// Every weather the server can send, built by the real server code from fake MET forecasts, for the
// "Widget matrix" workflow: the app renders each one as its widgets, lock-screen widgets and watch screen.
// Output: PurrcastTests/Fixtures/matrix.json  [{ key, group, label, scene, char }]
import { writeFileSync } from 'node:fs';
import { parseMet } from '../src/providers/met.js';
import { buildScene, validateScene } from '../src/scene.js';
import { instant } from '../src/time.js';

const TZ = 'Asia/Seoul';
const COVER = { clear: 8, partly: 50, overcast: 92 };
const COVER_KO = { clear: '맑음', partly: '구름 조금', overcast: '흐림' };

// one fake forecast: `now` describes the current hour, `later` an optional rain/snow spell later on
function series(start, now, later) {
  const ts = [];
  for (let i = 0; i < 240; i++) {
    const inLater = later && i >= later.from && i < later.from + 3;
    const cur = i < 3 ? now : (inLater ? { ...now, precip: later.type, mm: 1.5, cloud: 92 } : { ...now, precip: i < 6 ? now.precip : 'none', thunder: false, fog: false });
    const t = cur.temp + (cur.precip === 'snow' ? 0 : -((i % 24) / 8));
    const sym = cur.thunder ? 'rainandthunder'
      : cur.precip === 'snow' ? 'snow' : cur.precip === 'heavy' ? 'heavyrain' : cur.precip === 'rain' ? 'rain'
      : cur.fog ? 'fog' : cur.cloud >= 70 ? 'cloudy' : cur.cloud >= 30 ? 'partlycloudy_day' : 'clearsky_day';
    const mm = cur.precip === 'heavy' ? 8 : cur.precip === 'none' ? 0 : (cur.mm ?? 1.5);
    ts.push({
      time: new Date(start.getTime() + i * 3600000).toISOString(),
      data: {
        instant: { details: { air_temperature: t, relative_humidity: cur.temp >= 30 ? 40 : 70, wind_speed: cur.wind, wind_speed_of_gust: cur.wind * 1.5,
          wind_from_direction: 225, cloud_area_fraction: cur.cloud, fog_area_fraction: cur.fog ? 80 : 0,
          ultraviolet_index_clear_sky: 4, dew_point_temperature: t - 6 } },
        next_1_hours: { summary: { symbol_code: sym }, details: { precipitation_amount: mm, probability_of_precipitation: mm > 0 ? 90 : 5 } },
      },
    });
  }
  return ts;
}

const out = [];
function add({ time, cover, precip = 'none', thunder = false, aux = 'none', later = null, char = 'cat', label }) {
  const day = time === 'day';
  const start = instant(2026, 10, 21, day ? 14 : 22, 0, TZ);
  const temp = aux === 'heat' ? (day ? 35 : 29) : aux === 'frost' ? -13 : precip === 'snow' || later?.type === 'snow' ? -1 : 15;
  const now = { temp, cloud: COVER[cover], precip, thunder, fog: aux === 'fog', wind: aux === 'wind' ? 11 : 2 };
  const m = parseMet({ properties: { meta: { updated_at: start.toISOString() }, timeseries: series(start, now, later) } });
  const s = buildScene({ points: m.points, updated: start, next6: m.points.slice(1, 7), nextSource: 'met' },
    { lat: 37.57, lon: 126.9, tz: TZ, plan: 'free', now: new Date(start.getTime() + 10 * 60000) });
  validateScene(s);
  if (aux === 'dust') {   // the server can't tell 황사 yet (needs AirKorea): drawn here so its picture can be checked
    s.aux = 'dust'; s.cond = s.cond.replace(/^(맑음|구름 조금|흐림)/, '$1 · 황사');
    if (!s.bubble) s.bubble = { kind: 'speech', tone: 'white', icon: 'mask', text: '황사!' };
  }
  const key = [time, cover, precip, thunder ? 'thunder' : '', aux !== 'none' ? aux : '', later ? 'later-' + later.type + later.from : '', char !== 'cat' ? char : ''].filter(Boolean).join('-');
  out.push({ key, group: label ? '캐릭터별 말풍선' : (time === 'day' ? '낮' : '밤') + ' · ' + COVER_KO[cover], label: label || describe({ precip, thunder, aux, later }), scene: s, char });
}
function describe({ precip, thunder, aux, later }) {
  const p = { none: '', rain: '비', heavy: '강한 비', snow: '눈' }[precip];
  const a = { none: '', wind: '바람', fog: '안개', heat: '폭염', frost: '한파', dust: '황사(서버 미지원)' }[aux];
  const l = later ? (later.from <= 3 ? '곧 ' : '저녁에 ') + (later.type === 'snow' ? '눈' : '비') : '';
  return [p, thunder ? '천둥' : '', a, l].filter(Boolean).join(' + ') || '기본';
}

for (const time of ['day', 'night']) for (const cover of ['clear', 'partly', 'overcast']) {
  for (const aux of ['none', 'wind', 'fog', 'heat', 'frost', 'dust']) add({ time, cover, aux });
  for (const precip of ['rain', 'heavy']) for (const thunder of [false, true]) for (const aux of ['none', 'wind', 'fog', 'heat']) add({ time, cover, precip, thunder, aux });
  for (const aux of ['none', 'wind', 'fog', 'frost']) add({ time, cover, precip: 'snow', aux });
  add({ time, cover, later: { type: 'rain', from: 2 } });
  add({ time, cover, later: { type: 'rain', from: 5 } });
  add({ time, cover, later: { type: 'snow', from: 2 } });
}
// bubble placement per character: open umbrella, umbrella in the bag, long text, short text
for (const char of ['cat', 'abys', 'brit']) {
  add({ time: 'day', cover: 'overcast', precip: 'rain', char, label: char + ' · 비 (우산 폄)' });
  add({ time: 'day', cover: 'partly', later: { type: 'rain', from: 2 }, char, label: char + ' · 곧 비 (긴 말풍선)' });
  add({ time: 'day', cover: 'clear', aux: 'frost', char, label: char + ' · 한파' });
  add({ time: 'day', cover: 'clear', aux: 'heat', char, label: char + ' · 폭염' });
}
writeFileSync(new URL('../../PurrcastTests/Fixtures/matrix.json', import.meta.url), JSON.stringify(out));
console.log(out.length, 'cases');
const seen = {}; for (const o of out) seen[o.scene.cond + '|' + o.scene.rain + '|' + (o.scene.bubble?.text ?? '')] = 1;
console.log(Object.keys(seen).length, 'distinct cond/rain/bubble');
