// 기상청 vs Apple 날씨 side by side for a few Korean places (run in CI with the keys; prints a plain-text report).
//   node scripts/compare-sources.mjs            → every place below
// For each place: the raw 기상청 numbers (초단기실황 = the observation, 초단기예보, 단기예보 latest run and the 05 h run the
// free plan uses), Apple's currentWeather and hourly forecast (temperature and Apple's own feels-like), MET Norway, and what
// our server answers (free and Plus): temp, feels, outfit level, hi / lo.
import { forecast, readQuery } from '../src/index.js';
import { toGrid, vilageBase, ultraBase, ncstBase, kmaUrl, parseForecast, parseNow } from '../src/providers/kma.js';
import { hasWeatherKit, weatherKitUrl, weatherKitToken } from '../src/providers/weatherkit.js';
import { metUrl, parseMet } from '../src/providers/met.js';
import { feelsLike } from '../src/physics.js';
import { local } from '../src/time.js';

const env = {
  KMA_SERVICE_KEY: process.env.KMA_SERVICE_KEY || '', CONTACT: 'github.com/Moku143/purrcast',
  WEATHERKIT_KEY_ID: process.env.WEATHERKIT_KEY_ID || '', WEATHERKIT_KEY_P8: process.env.WEATHERKIT_KEY_P8 || '',
  APPLE_TEAM_ID: process.env.APPLE_TEAM_ID || '', WEATHERKIT_SERVICE_ID: process.env.WEATHERKIT_SERVICE_ID || 'app.purrcast.ios',
};
const PLACES = [
  ['서울 구로구 오류동', 37.49, 126.84],
  ['서울 마포구', 37.57, 126.9],
  ['서울 강남구', 37.5, 127.03],
  ['부산 해운대구', 35.16, 129.16],
  ['강원 춘천시', 37.88, 127.73],
];
const TZ = 'Asia/Seoul';
const now = new Date();
const hh = (t) => String(local(t, TZ).h).padStart(2, '0');
const f1 = (v) => (v == null ? '  –  ' : (Math.round(v * 10) / 10).toFixed(1).padStart(5));
const out = [];
const say = (s = '') => { out.push(s); console.log(s); };

async function getJson(url, headers = {}) {
  const r = await fetch(url, { headers });
  const t = await r.text();
  if (t.trimStart().startsWith('<')) throw new Error(t.slice(0, 200));
  return JSON.parse(t);
}

say(`기상청 vs Apple 날씨 · ${local(now, TZ).y}-${local(now, TZ).m}-${local(now, TZ).d} ${hh(now)}:${String(local(now, TZ).mi).padStart(2, '0')} KST`);
say('');
for (const [name, lat, lon] of PLACES) {
  say(`━━ ${name} (${lat}, ${lon})`);
  const { nx, ny } = toGrid(lat, lon);
  const key = env.KMA_SERVICE_KEY;
  let ncst = null, ultra = null, vil = null, vil5 = null, apple = null, met = null;
  try {
    const b = ncstBase(now);
    ncst = parseNow(await getJson(kmaUrl('getUltraSrtNcst', key, { base_date: b.date, base_time: b.time, nx, ny })));
    if (!ncst) { const p = ncstBase(new Date(now - 3600000)); ncst = parseNow(await getJson(kmaUrl('getUltraSrtNcst', key, { base_date: p.date, base_time: p.time, nx, ny }))); }
  } catch (e) { say(`  초단기실황 실패: ${e.message}`); }
  try { const b = ultraBase(now); ultra = parseForecast(await getJson(kmaUrl('getUltraSrtFcst', key, { base_date: b.date, base_time: b.time, nx, ny })), 'u'); ultra.base = `${b.date} ${b.time}`; } catch (e) { say(`  초단기예보 실패: ${e.message}`); }
  try { const b = vilageBase(now); vil = parseForecast(await getJson(kmaUrl('getVilageFcst', key, { base_date: b.date, base_time: b.time, nx, ny })), 'v'); vil.base = `${b.date} ${b.time}`; } catch (e) { say(`  단기예보 실패: ${e.message}`); }
  try { const b = vilageBase(now, 5); vil5 = parseForecast(await getJson(kmaUrl('getVilageFcst', key, { base_date: b.date, base_time: b.time, nx, ny })), 'v5'); vil5.base = `${b.date} ${b.time}`; } catch (e) { say(`  단기예보(05시) 실패: ${e.message}`); }
  if (hasWeatherKit(env)) {
    try { apple = await getJson(weatherKitUrl(lat, lon, { lang: 'ko', tz: TZ, country: 'KR' }), { authorization: `Bearer ${await weatherKitToken(env)}` }); }
    catch (e) { say(`  WeatherKit 실패: ${e.message}`); }
  }
  try { met = parseMet(await getJson(metUrl(lat, lon), { 'user-agent': 'Purrcast/1.0 github.com/Moku143/purrcast' })); } catch (e) { say(`  MET 실패: ${e.message}`); }

  // now
  const c = apple?.currentWeather;
  if (ncst) say(`  기상청 실황 (${ncst.t ? hh(ncst.t) + ':00 관측' : '?'})  기온 ${f1(ncst.temp)}  습도 ${ncst.rh ?? '–'}%  바람 ${f1(ncst.wind)} m/s  → 우리 체감 ${f1(feelsLike(ncst.temp, ncst.rh, ncst.wind))}`);
  if (c) say(`  Apple 현재  (${c.asOf?.slice(11, 16)}Z)        기온 ${f1(c.temperature)}  습도 ${Math.round(c.humidity * 100)}%  바람 ${f1(c.windSpeed / 3.6)} m/s  돌풍 ${f1(c.windGust / 3.6)}  → Apple 체감 ${f1(c.temperatureApparent)}  (${c.conditionCode})`);
  // daily
  const today = `${local(now, TZ).y}${String(local(now, TZ).m).padStart(2, '0')}${String(local(now, TZ).d).padStart(2, '0')}`;
  const ad = apple?.forecastDaily?.days?.find((d) => d.forecastStart && local(new Date(d.forecastStart), TZ).d === local(now, TZ).d);
  say(`  오늘 최저/최고  기상청 ${f1(vil?.daily?.[today]?.lo)} / ${f1(vil?.daily?.[today]?.hi)}   Apple ${f1(ad?.temperatureMin)} / ${f1(ad?.temperatureMax)}`);
  // hourly table, now … +12 h
  const ah = new Map((apple?.forecastHourly?.hours ?? []).map((h) => [new Date(h.forecastStart).getTime(), h]));
  const at = (list, t) => list?.points?.find((p) => p.t.getTime() === t);
  const mt = (t) => met?.points?.find((p) => Math.abs(p.t - t) < 1800000);
  const start = new Date(now); start.setUTCMinutes(0, 0, 0);
  say(`  시각 | 단기(${vil?.base?.slice(9) ?? '?'}) 단기(05) 초단기 | Apple 기온 Apple체감 | MET  | 차이(Apple−기상청)`);
  for (let i = 0; i <= 12; i++) {
    const t = start.getTime() + i * 3600000;
    const v = at(vil, t), v5 = at(vil5, t), u = at(ultra, t), a = ah.get(t), m = mt(t);
    const kma = u?.temp ?? v?.temp;
    const diff = a && kma != null ? a.temperature - kma : null;
    say(`  ${hh(new Date(t))}시 | ${f1(v?.temp)}     ${f1(v5?.temp)}  ${f1(u?.temp)} | ${f1(a?.temperature)}   ${f1(a?.temperatureApparent)}   | ${f1(m?.temp)} | ${diff == null ? '' : (diff >= 0 ? '+' : '') + diff.toFixed(1)}`);
  }
  // our answers
  for (const plan of ['free', 'plus']) {
    try {
      const s = await forecast(readQuery(new URLSearchParams({ lat, lon, region: 'kr', tz: TZ, plan, name: name.split(' ').slice(0, 2).join(' ') })), env, null, { now });
      say(`  우리 서버 (${plan}): ${s.temp}° 체감 ${s.feels}° 옷 단계 ${s.level} · 최저/최고 ${s.lo}/${s.hi} · ${s.cond} · 기준 ${s.updated}`);
    } catch (e) { say(`  우리 서버 (${plan}) 실패: ${e.message}`); }
  }
  say('');
}
