// Writes scenes produced by the real server code (fake upstreams) for the iOS unit tests,
// so the app is tested against exactly what the server sends.
import { writeFileSync } from 'node:fs';
import { parseMet } from '../src/providers/met.js';
import { buildScene, validateScene } from '../src/scene.js';
import { instant } from '../src/time.js';

const TZ = 'Asia/Seoul';
const start = instant(2026, 10, 21, 13, 0, TZ);
const ts = [];
for (let i = 0; i < 240; i++) {
  const wet = i >= 3 && i <= 5;
  ts.push({
    time: new Date(start.getTime() + i * 3600000).toISOString(),
    data: {
      instant: { details: { air_temperature: 16 - (i % 24) / 4, relative_humidity: 70, wind_speed: 4, wind_speed_of_gust: 7, wind_from_direction: 225, cloud_area_fraction: wet ? 95 : 60, ultraviolet_index_clear_sky: 3, dew_point_temperature: 9 } },
      next_1_hours: { summary: { symbol_code: wet ? 'rain' : 'cloudy' }, details: { precipitation_amount: wet ? 1.4 : 0, probability_of_precipitation: wet ? 80 : 10 } },
    },
  });
}
const m = parseMet({ properties: { meta: { updated_at: start.toISOString() }, timeseries: ts } });
const out = {};
for (const plan of ['free', 'plus']) {
  const s = buildScene({ points: m.points, updated: start, next6: m.points.slice(1, 7), nextSource: 'met' }, { lat: 37.57, lon: 126.9, tz: TZ, plan, now: instant(2026, 10, 21, 13, 40, TZ) });
  validateScene(s);
  out[plan] = s;
}
writeFileSync(new URL('../../PurrcastTests/Fixtures/server-scenes.json', import.meta.url), JSON.stringify(out, null, 1));
console.log('fixtures written', Object.keys(out));
