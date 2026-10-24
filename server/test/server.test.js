import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { toGrid, amount, num, parseForecast, parseNow, parseWarnings, splitAreas, vilageBase, ultraBase, kmaXmlError, kmaOK } from '../src/providers/kma.js';
import { parseMet, metUrl } from '../src/providers/met.js';
import { buildScene, validateScene } from '../src/scene.js';
import { level, bubble, uvNote, whenWord, alertNote } from '../src/rules.js';
import { sunDay, local, instant } from '../src/time.js';
import { feelsLike, humidityWord, windWord } from '../src/physics.js';
import worker, { forecast, readQuery, resetCache } from '../src/index.js';
import { beforeEach } from 'node:test';
beforeEach(() => resetCache());

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

test('feels-like: KMA wind chill when cold, KMA summer formula (humidity counts) when warm', () => {
  assert.ok(feelsLike(0, 60, 8) < -4);
  assert.ok(feelsLike(33, 70, 1) > 33.5 && feelsLike(33, 70, 1) < 37, 'humid 33° feels hotter, KMA-style (not the US heat index)');
  assert.ok(feelsLike(33, 30, 1) < feelsLike(33, 70, 1), 'drier air feels cooler');
  assert.equal(feelsLike(18, 60, 3), 18);
  assert.equal(feelsLike(5, 60, 0.5), 5, 'no wind chill below 1.3 m/s');
});

test('how it feels: humidity, wind, UV in everyday words', () => {
  assert.equal(humidityWord({ temp: 8, rh: 92, dew: 7, wet: true }), '눅눅해요', 'cold rain is damp even with a low dew point');
  assert.equal(humidityWord({ temp: 19, rh: 46, dew: 7 }), '보송해요');
  assert.equal(humidityWord({ temp: 30, rh: 70, dew: 24 }), '매우 끈적해요');
  assert.equal(humidityWord({ temp: 27, rh: 60, dew: 19 }), '꿉꿉해요');
  assert.equal(humidityWord({ temp: 20, rh: 25, dew: 0 }), '건조해요');
  assert.equal(windWord(2), '산들바람'); assert.equal(windWord(7), '바람 꽤 강해요'); assert.equal(windWord(9), '바람 강해요'); assert.equal(windWord(15), '강풍 · 외출 주의');
  assert.equal(uvNote(1), '약해요'); assert.ok(uvNote(6).startsWith('강해요')); assert.ok(uvNote(11).startsWith('위험'));
});

test('KMA amounts and parsing', () => {
  assert.equal(amount('강수없음'), 0); assert.equal(amount('1mm 미만'), 0.5); assert.equal(amount('1.0mm'), 1);
  assert.equal(amount('30.0~50.0mm'), 40); assert.equal(amount('50.0mm 이상'), 50); assert.equal(amount('적설없음'), 0);
  assert.equal(amount('약한 비'), 1); assert.equal(amount('강한 비'), 20); assert.equal(amount(-999), 0);
  assert.equal(num('-999'), null); assert.equal(num('12.5'), 12.5); assert.equal(num(undefined), null);
  const items = [];
  const add = (date, time, cat, v) => items.push({ fcstDate: date, fcstTime: time, category: cat, fcstValue: v });
  add('20261021', '1400', 'TMP', '18'); add('20261021', '1400', 'PTY', '0'); add('20261021', '1400', 'SKY', '3');
  add('20261021', '1500', 'TMP', '17'); add('20261021', '1500', 'POP', '60'); add('20261021', '1500', 'PCP', '1.0mm'); add('20261021', '1500', 'PTY', '1'); add('20261021', '1500', 'SKY', '4');
  add('20261021', '1600', 'TMP', '16'); add('20261021', '1600', 'POP', '20'); add('20261021', '1600', 'PCP', '강수없음'); add('20261021', '1600', 'PTY', '0'); add('20261021', '1600', 'SKY', '3');
  add('20261022', '0600', 'TMN', '9'); add('20261022', '1500', 'TMX', '19');
  const f = parseForecast({ response: { header: { resultCode: '00' }, body: { items: { item: items } } } }, 'kma');
  // KMA reports the weather of 14~15 h at 15 h: our 14 h point (covering 14–15) gets it; temperatures stay put
  const at = (h) => f.points.find((p) => local(p.t, TZ).h === h && local(p.t, TZ).d === 21);
  assert.equal(at(14).temp, 18); assert.equal(at(14).mm, 1); assert.equal(at(14).type, 'rain'); assert.equal(at(14).cloud, 90); assert.equal(at(14).pop, 60);
  assert.equal(at(15).temp, 17); assert.equal(at(15).mm, 0); assert.equal(at(15).type, 'none');
  assert.equal(parseNow({ response: { header: { resultCode: '00' }, body: { items: { item: [{ baseDate: '20261021', baseTime: '1300', category: 'T1H', obsrValue: -999 }] } } } }), null, 'missing observation');
  assert.match(kmaXmlError('<OpenAPI_ServiceResponse><cmmMsgHeader><errMsg>SERVICE ERROR</errMsg><returnAuthMsg>SERVICE_KEY_IS_NOT_REGISTERED_ERROR</returnAuthMsg><returnReasonCode>30</returnReasonCode></cmmMsgHeader></OpenAPI_ServiceResponse>').message, /30 SERVICE_KEY_IS_NOT_REGISTERED_ERROR/);
  assert.equal(kmaOK({ response: { header: { resultCode: '03', resultMsg: 'NO_DATA' } } }), false);
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

test('KMA warnings: province, its listed cities, never sea zones', () => {
  const t6 = 'o 호우경보 : 서울, 경기도(가평, 양평), 강원도(강원북부산지)\no 풍랑주의보 : 인천·경기북부앞바다, 제주도남쪽먼바다\no 강풍주의보 : 제주도\no 폭염주의보 : 광주, 전라남도(나주)';
  const j = { response: { header: { resultCode: '00' }, body: { items: { item: [{ t6, t7: 'o 강풍 예비특보 : 서울' }] } } } };
  const names = (place) => parseWarnings(j, place).map((w) => w.name);
  assert.deepEqual(names('서울 마포구'), ['호우경보']);
  assert.deepEqual(names('경기 가평군'), ['호우경보']);
  assert.deepEqual(names('경기 성남시'), [], 'bracketed list does not include 성남');
  assert.deepEqual(names('인천 연수구'), [], 'sea zones never apply on land');
  assert.deepEqual(names('제주 제주시'), ['강풍주의보']);
  assert.deepEqual(names('광주 동구'), ['폭염주의보']);
  assert.deepEqual(names('부산 해운대구'), []);
  assert.deepEqual(parseWarnings({ response: { header: { resultCode: '00' }, body: { items: { item: [{ t6: 'o 없 음' }] } } } }, '서울 마포구'), []);
  assert.deepEqual(splitAreas('서울, 경기도(가평, 양평)'), [{ name: '서울', sub: [] }, { name: '경기도', sub: ['가평', '양평'] }]);
});

test('MET URL keeps at most 4 decimals', () => {
  assert.match(metUrl(37.566312345, 126.90190001), /lat=37\.5663&lon=126\.9019$/);
  const q = readQuery(new URLSearchParams('lat=37.566312&lon=126.901901'));
  assert.equal(q.lat, 37.57); assert.equal(q.lon, 126.9);
});

test('scene: clear dry day — no umbrella, no bubble, sun tile, valid for the app', () => {
  const m = parseMet(met(at(13), flat(40)));
  const s = buildScene({ points: m.points, updated: at(13) }, { ...SEOUL, plan: 'free', now: at(13, 40) });
  validateScene(s);
  assert.equal(s.time, 'day'); assert.equal(s.cover, 'clear'); assert.equal(s.rain, 'none'); assert.equal(s.bubble, null);
  assert.equal(s.level, 4); assert.equal(s.temp, 18); assert.equal(s.hours.length, 13); assert.equal(s.hours[0][0], '지금');
  assert.equal(s.hours[1][0], '14시'); assert.equal(s.tiles[2].label, '일몰'); assert.equal(s.updated, '06:00');
  assert.equal(s.cond, '맑음');
  assert.equal(s.dayDetail.length, s.days.length); assert.equal(s.dayDetail[1].length, 8); assert.equal(s.dayDetail[1][4][0], '12시');
});

test('scene: rain in a few hours → bag + "16~17시 비 예정" (the hours people plan around)', () => {
  const hrs = flat(40, { cloud: 90, sym: 'cloudy' });
  hrs[3] = { cloud: 95, mm: 1.2, pop: 70, sym: 'rain' }; hrs[4] = { cloud: 95, mm: 2.0, pop: 70, sym: 'rain' };
  const m = parseMet(met(at(13), hrs));
  const s = buildScene({ points: m.points }, { ...SEOUL, plan: 'plus', now: at(13, 40) });
  validateScene(s);
  assert.equal(s.rain, 'bag');
  assert.equal(s.bubble.text, '16~17시 비 예정');
  assert.match(s.tiles[0].note, /^16~17시 비 예정 · /);
  assert.equal(s.tiles[0].value, '70%');
});

test('when words: 15~17시 · 15시쯤 · 내일 7~9시', () => {
  assert.equal(whenWord(15, 17, false), '15~17시'); assert.equal(whenWord(15, 15, false), '15시쯤');
  assert.equal(whenWord(7, 9, true), '내일 7~9시');
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

test('alert line under the character: the warning name + what it means today', () => {
  assert.equal(alertNote('대설주의보', { total: 6, pr: 'snow', nowWet: true, when: '', endH: 18, hi: 0, lo: -5 }), '오늘 6cm, 18시쯤 그칠 예보');
  assert.equal(alertNote('호우주의보', { total: 42, pr: 'rain', nowWet: false, when: '15~19시', endH: null, hi: 25, lo: 22 }), '오늘 42mm (많음), 15~19시 비 예정');
  assert.equal(alertNote('폭염경보', { total: 0, pr: 'none', hi: 36, lo: 27 }), '낮 최고 36°, 한낮 외출 줄여요');
  assert.equal(alertNote('한파주의보', { total: 0, pr: 'none', hi: -6, lo: -14 }), '아침 -14°, 많이 추워요');
  assert.equal(alertNote('강풍주의보', { gust: 18 }), '돌풍 18 m/s, 외출 주의');
  const hrs = flat(40, { cloud: 95, mm: 3, pop: 90, sym: 'rain' });
  const m = parseMet(met(at(13), hrs));
  const s = buildScene({ points: m.points, warnings: [{ name: '호우주의보', severity: 1 }] }, { ...SEOUL, plan: 'plus', now: at(13, 40) });
  validateScene(s);
  assert.equal(s.alert.name, '호우주의보'); assert.match(s.alert.note, /^오늘 \d+(\.\d)?mm/);
  assert.equal(s.bubble.text, '호우주의보');
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

test('official names stay as they are above their thresholds: warnings, 폭염 · 열대야 · 한파 · 폭우 · 폭설 · 천둥번개', () => {
  const base = { warnings: [], nowWet: false, nowPr: 'none', thunder: false, startIn: null, wind: false, fog: false, feels: 20, night: false, swing: 0, maxPop: 0, rain: 'none', when: '' };
  assert.equal(bubble({ ...base, warnings: [{ name: '호우주의보' }] }).text, '호우주의보');
  assert.equal(bubble({ ...base, warnings: [{ name: '태풍경보' }], feels: 35 }).text, '태풍경보');
  assert.equal(bubble({ ...base, thunder: true, nowWet: true, nowPr: 'heavy' }).text, '천둥번개!');
  assert.equal(bubble({ ...base, nowWet: true, nowPr: 'heavy' }).text, '폭우!');
  assert.equal(bubble({ ...base, nowWet: true, nowPr: 'heavysnow', nowMm: 3 }).text, '폭설!');
  assert.equal(bubble({ ...base, feels: 33 }).text, '폭염!');
  assert.equal(bubble({ ...base, feels: 25, night: true }).text, '열대야!');
  assert.equal(bubble({ ...base, feels: -10 }).text, '한파!');
  assert.equal(bubble({ ...base, feels: 32 }), null);        // under the threshold: no alert word
});

test('snow kinds: 눈 · 많은 눈 (3 cm/h+) · 진눈깨비', () => {
  const hrs = flat(40, { cloud: 95, mm: 1, pop: 90, sym: 'snow' });
  const s = buildScene({ points: parseMet(met(at(13), hrs)).points }, { ...SEOUL, plan: 'plus', now: at(13, 40) });
  validateScene(s); assert.equal(s.precip, 'snow'); assert.equal(s.cond, '눈'); assert.equal(s.snow, true);
  const h2 = flat(40, { cloud: 95, mm: 4, pop: 90, sym: 'heavysnow' });
  const s2 = buildScene({ points: parseMet(met(at(13), h2)).points }, { ...SEOUL, plan: 'plus', now: at(13, 40) });
  validateScene(s2); assert.equal(s2.precip, 'heavysnow'); assert.equal(s2.bubble.text, '폭설!'); assert.match(s2.tiles[0].note, /cm/);
  const h3 = flat(40, { cloud: 95, mm: 2, pop: 90, sym: 'sleet' });
  const s3 = buildScene({ points: parseMet(met(at(13), h3)).points }, { ...SEOUL, plan: 'plus', now: at(13, 40) });
  validateScene(s3); assert.equal(s3.precip, 'sleet'); assert.equal(s3.cond, '진눈깨비'); assert.equal(s3.bubble.text, '진눈깨비!'); assert.match(s3.tiles[0].note, /mm/);
});
