import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { toGrid, amount, parseForecast, parseNow, parseWarnings, vilageBase, ultraBase } from '../src/providers/kma.js';
import { parseMet, metUrl } from '../src/providers/met.js';
import { buildScene, validateScene } from '../src/scene.js';
import { level, bubble } from '../src/rules.js';
import { sunDay, local, instant } from '../src/time.js';
import { feelsLike } from '../src/physics.js';
import worker, { forecast, readQuery } from '../src/index.js';

const TZ = 'Asia/Seoul';
const SEOUL = { lat: 37.5663, lon: 126.9019, tz: TZ };
const at = (h, mi = 0, d = 21) => instant(2026, 10, d, h, mi, TZ);   // 2026-10-21 local

/** MET-shaped JSON: hourly entries from `start` with per-hour overrides */
function met(start, hours, base = {}) {
  const ts = [];
  for (let i = 0; i < hours.length; i++) {
    const h = { temp: 18, rh: 60, wind: 3, cloud: 10, mm: 0, pop: 0, sym: 'clearsky_day', uv: 3, ...base, ...hours[i] };
    ts.push({
      time: new Date(start.getTime() + i * 3600000).toISOString(),
      data: {
        instant: { details: { air_temperature: h.temp, relative_humidity: h.rh, wind_speed: h.wind, wind_speed_of_gust: h.gust ?? h.wind * 1.6, wind_from_direction: 225, cloud_area_fraction: h.cloud, ultraviolet_index_clear_sky: h.uv, dew_point_temperature: h.dew ?? 9, fog_area_fraction: h.fog ?? 0 } },
        next_1_hours: { summary: { symbol_code: h.sym }, details: { precipitation_amount: h.mm, probability_of_precipitation: h.pop } },
      },
    });
  }
  return { properties: { meta: { updated_at: start.toISOString() }, timeseries: ts } };
}
const flat = (n, o = {}) => Array.from({ length: n }, () => ({ ...o }));

test('KMA grid: Seoul city hall → 60,127; Busan → 98,76', () => {
  assert.deepEqual(toGrid(37.5665, 126.978), { nx: 60, ny: 127 });
  assert.deepEqual(toGrid(35.1796, 129.0756), { nx: 98, ny: 76 });
});

test('sunrise / sunset in Seoul on 21 Oct 2026 (about 06:43 / 17:49 KST)', () => {
  const s = sunDay(at(12), 37.5665, 126.978, TZ);
  const r = local(s.rise, TZ), e = local(s.set, TZ);
  const mins = (p) => p.h * 60 + p.mi;
  assert.ok(Math.abs(mins(r) - (6 * 60 + 43)) <= 8, `rise ${r.h}:${r.mi}`);
  assert.ok(Math.abs(mins(e) - (17 * 60 + 49)) <= 8, `set ${e.h}:${e.mi}`);
});

test('outfit level boundaries and ±1° hysteresis', () => {
  assert.equal(level(35), 0); assert.equal(level(30), 1); assert.equal(level(25), 2); assert.equal(level(21), 3);
  assert.equal(level(18), 4); assert.equal(level(14), 5); assert.equal(level(10), 6); assert.equal(level(6), 7);
  assert.equal(level(0), 8); assert.equal(level(-12), 9);
  assert.equal(level(19.8, 4), 4, 'just over the 19.5 edge stays in 4 from 4');
  assert.equal(level(20.6, 4), 3, 'a full degree past the edge changes');
});

test('feels-like: wind chill when cold, heat index when hot', () => {
  assert.ok(feelsLike(0, 60, 8) < -4);
  assert.ok(feelsLike(33, 70, 1) > 38);
  assert.equal(feelsLike(18, 60, 3), 18);
});

test('KMA amounts and parsing', () => {
  assert.equal(amount('강수없음'), 0); assert.equal(amount('1mm 미만'), 0.5); assert.equal(amount('1.0mm'), 1);
  assert.equal(amount('30.0~50.0mm'), 40); assert.equal(amount('50.0mm 이상'), 50); assert.equal(amount('적설없음'), 0);
  const items = [];
  const add = (date, time, cat, v) => items.push({ fcstDate: date, fcstTime: time, category: cat, fcstValue: v });
  add('20261021', '1500', 'TMP', '17'); add('20261021', '1500', 'POP', '60'); add('20261021', '1500', 'PCP', '1.0mm'); add('20261021', '1500', 'PTY', '1'); add('20261021', '1500', 'SKY', '4');
  add('20261021', '1600', 'TMP', '16'); add('20261021', '1600', 'POP', '20'); add('20261021', '1600', 'PCP', '강수없음'); add('20261021', '1600', 'PTY', '0'); add('20261021', '1600', 'SKY', '3');
  add('20261022', '0600', 'TMN', '9'); add('20261022', '1500', 'TMX', '19');
  const f = parseForecast({ response: { header: { resultCode: '00' }, body: { items: { item: items } } } }, 'kma');
  const p15 = f.points.find((p) => local(p.t, TZ).h === 15 && local(p.t, TZ).d === 21);
  assert.equal(p15.temp, 17); assert.equal(p15.mm, 1); assert.equal(p15.type, 'rain'); assert.equal(p15.cloud, 90);
  assert.deepEqual(f.daily['20261022'], { lo: 9, hi: 19 });
  assert.throws(() => parseForecast({ response: { header: { resultCode: '30', resultMsg: 'SERVICE KEY IS NOT REGISTERED' } } }, 'kma'), /30/);
});

test('KMA base times', () => {
  assert.equal(vilageBase(at(5, 20)).time, '0500');
  assert.equal(vilageBase(at(5, 5)).time, '0200');
  assert.equal(vilageBase(at(1, 0)).time, '2300');
  assert.equal(vilageBase(at(13, 0), 5).time, '0500', 'free keeps the morning run');
  assert.equal(vilageBase(at(4, 0), 5).time, '2300', 'free before 05:15 uses last night');
  assert.equal(ultraBase(at(14, 50)).time, '1430');
  assert.equal(ultraBase(at(14, 40)).time, '1330');
});

test('KMA warnings: keep only the ones naming the place', () => {
  const j = { response: { header: { resultCode: '00' }, body: { items: { item: [{ t6: 'o 호우경보 : 서울, 인천, 경기도\no 강풍주의보 : 제주도' }] } } } };
  assert.deepEqual(parseWarnings(j, '서울 마포구').map((w) => w.name), ['호우경보']);
  assert.deepEqual(parseWarnings(j, '제주 제주시').map((w) => w.name), ['강풍주의보']);
  assert.deepEqual(parseWarnings(j, '부산 해운대구'), []);
});

test('MET URL keeps at most 4 decimals', () => {
  assert.match(metUrl(37.566312345, 126.90190001), /lat=37\.5663&lon=126\.9019$/);
});

test('scene: clear dry day — no umbrella, no bubble, sun tile, valid for the app', () => {
  const m = parseMet(met(at(13), flat(40)));
  const s = buildScene({ points: m.points, updated: at(13) }, { ...SEOUL, plan: 'free', now: at(13, 40) });
  validateScene(s);
  assert.equal(s.time, 'day'); assert.equal(s.cover, 'clear'); assert.equal(s.rain, 'none'); assert.equal(s.bubble, null);
  assert.equal(s.level, 4); assert.equal(s.temp, 18); assert.equal(s.hours.length, 13); assert.equal(s.hours[0][0], '지금');
  assert.equal(s.hours[1][0], '14시'); assert.equal(s.tiles[2].label, '일몰'); assert.equal(s.updated, '06:00');
  assert.equal(s.cond, '맑음');
});

test('scene: rain from 16 to 17 h → bag + clock-time window, never a countdown', () => {
  const hrs = flat(40, { cloud: 90, sym: 'cloudy' });
  hrs[3] = { cloud: 95, mm: 1.2, pop: 70, sym: 'rain' }; hrs[4] = { cloud: 95, mm: 2.0, pop: 70, sym: 'rain' };
  const m = parseMet(met(at(13), hrs));
  const s = buildScene({ points: m.points }, { ...SEOUL, plan: 'plus', now: at(13, 40) });
  validateScene(s);
  assert.equal(s.rain, 'bag');
  assert.equal(s.bubble.text, '16~17시 비!');
  assert.doesNotMatch(JSON.stringify(s), /분 뒤|시간 뒤|후에/);
  assert.equal(s.tiles[0].value, '70%');
});

test('scene: heavy rain now → umbrella + 폭우, thunder → 천둥번개', () => {
  const m = parseMet(met(at(13), flat(30, { cloud: 100, mm: 8, pop: 90, sym: 'heavyrain' })));
  const s = buildScene({ points: m.points }, { ...SEOUL, plan: 'plus', now: at(13, 10) });
  assert.equal(s.rain, 'umbrella'); assert.equal(s.precip, 'heavy'); assert.equal(s.bubble.text, '폭우!');
  const t = parseMet(met(at(13), flat(30, { cloud: 100, mm: 3, pop: 90, sym: 'rainandthunder' })));
  const s2 = buildScene({ points: t.points }, { ...SEOUL, plan: 'plus', now: at(13, 10) });
  assert.equal(s2.thunder, 'on'); assert.equal(s2.bubble.text, '천둥번개!');
});

test('scene: cold windy night → level 9, 한파 or wind, night tile = 일출', () => {
  const m = parseMet(met(at(21), flat(30, { temp: -8, wind: 6, cloud: 0, sym: 'clearsky_night' })));
  const s = buildScene({ points: m.points }, { ...SEOUL, plan: 'free', now: at(21, 30) });
  validateScene(s);
  assert.equal(s.time, 'night'); assert.equal(s.level, 9); assert.ok(s.feels <= -10);
  assert.equal(s.bubble.text, '한파!'); assert.equal(s.mood, 'cold'); assert.equal(s.tiles[2].label, '일출');
});

test('bubble priority: official warning first', () => {
  const b = bubble({ warnings: [{ name: '호우경보', severity: 2 }], thunder: true, nowWet: true, nowPr: 'heavy', feels: 20 });
  assert.deepEqual(b, { kind: 'shout', tone: 'coral', icon: 'raincloud', text: '호우경보' });
});

test('every example scene the app ships with passes the contract check', () => {
  const scenes = JSON.parse(readFileSync(new URL('../../Shared/Data/scenes.json', import.meta.url)));
  for (const [k, s] of Object.entries(scenes)) assert.doesNotThrow(() => validateScene(s), k);
});

// ---- whole request with fake upstreams ----

function kmaFixture(now) {
  const items = [];
  for (let i = 1; i <= 60; i++) {
    const t = new Date(now.getTime() + i * 3600000);
    const p = local(t, TZ);
    const date = `${p.y}${String(p.m).padStart(2, '0')}${String(p.d).padStart(2, '0')}`, time = `${String(p.h).padStart(2, '0')}00`;
    const wet = i >= 2 && i <= 4;
    for (const [c, v] of [['TMP', String(15 - (i % 6))], ['POP', wet ? '80' : '10'], ['PCP', wet ? '2.0mm' : '강수없음'], ['PTY', wet ? '1' : '0'], ['SKY', '4'], ['REH', '70'], ['WSD', '2.5'], ['VEC', '200']]) {
      items.push({ fcstDate: date, fcstTime: time, category: c, fcstValue: v });
    }
  }
  return { response: { header: { resultCode: '00' }, body: { items: { item: items } } } };
}

function fakeFetch(routes) {
  return async (url) => {
    for (const [pat, body] of routes) if (url.includes(pat)) {
      if (body instanceof Error) return new Response('down', { status: 503 });
      return new Response(JSON.stringify(typeof body === 'function' ? body(url) : body), { status: 200 });
    }
    return new Response('{}', { status: 404 });
  };
}

test('Korea, Plus: KMA + MET merged, next six hours from 초단기예보, valid', async () => {
  const now = at(13, 50);
  const ultra = kmaFixture(now);
  ultra.response.body.items.item = ultra.response.body.items.item
    .filter((it) => ['TMP', 'PCP', 'PTY', 'SKY', 'REH', 'WSD', 'VEC'].includes(it.category))
    .map((it) => ({ ...it, category: it.category === 'TMP' ? 'T1H' : it.category === 'PCP' ? 'RN1' : it.category }))
    .slice(0, 6 * 7);
  const fetcher = fakeFetch([
    ['getVilageFcst', kmaFixture(now)],
    ['getUltraSrtFcst', ultra],
    ['getUltraSrtNcst', { response: { header: { resultCode: '00' }, body: { items: { item: [
      { baseDate: '20261021', baseTime: '1300', category: 'T1H', obsrValue: 14.2 }, { baseDate: '20261021', baseTime: '1300', category: 'RN1', obsrValue: 0 },
      { baseDate: '20261021', baseTime: '1300', category: 'PTY', obsrValue: 0 }, { baseDate: '20261021', baseTime: '1300', category: 'REH', obsrValue: 70 }] } } } }],
    ['getPwnStatus', { response: { header: { resultCode: '00' }, body: { items: { item: [] } } } }],
    ['api.met.no', met(now, flat(240, { temp: 12, cloud: 80, sym: 'cloudy' }))],
  ]);
  const q = readQuery(new URLSearchParams('lat=37.5663&lon=126.9019&region=kr&tz=Asia/Seoul&plan=plus&name=서울 마포구'));
  const s = await forecast(q, { KMA_SERVICE_KEY: 'k' }, null, { now, fetcher });
  validateScene(s);
  assert.equal(s.temp, 14, 'observation wins for now');
  assert.equal(s.next6.length, 6); assert.equal(s.nextSource, 'kma');
  assert.equal(s.rain, 'bag');
  assert.ok(s.days.length >= 7, `days ${s.days.length} (KMA 3 days + MET after)`);
});

test('Korea, KMA down → MET carries on', async () => {
  const now = at(9, 0);
  const fetcher = fakeFetch([['apis.data.go.kr', new Error('down')], ['api.met.no', met(now, flat(48))]]);
  const q = readQuery(new URLSearchParams('lat=37.5663&lon=126.9019&region=kr&tz=Asia/Seoul&plan=free'));
  const s = await forecast(q, { KMA_SERVICE_KEY: 'k' }, null, { now, fetcher });
  validateScene(s);
  assert.equal(s.temp, 18);
});

test('Tokyo, Plus: MET only, next six hours labelled MET', async () => {
  const now = instant(2026, 10, 21, 15, 0, 'Asia/Tokyo');
  const fetcher = fakeFetch([['api.met.no', met(now, flat(48, { temp: 20 }))]]);
  const q = readQuery(new URLSearchParams('lat=35.69&lon=139.70&region=jp&tz=Asia/Tokyo&plan=plus'));
  const s = await forecast(q, {}, null, { now, fetcher });
  validateScene(s);
  assert.equal(s.nextSource, 'met'); assert.equal(s.clock, '15:00');
});

test('HTTP: /health, bad input 400, unknown path 404', async () => {
  assert.equal((await worker.fetch(new Request('https://x/health'), {}, null)).status, 200);
  assert.equal((await worker.fetch(new Request('https://x/v1/forecast?lat=999&lon=1'), {}, null)).status, 400);
  assert.equal((await worker.fetch(new Request('https://x/nope'), {}, null)).status, 404);
});
