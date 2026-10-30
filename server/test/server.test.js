import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { toGrid, amount, num, parseForecast, parseNow, parseWarnings, splitAreas, vilageBase, ultraBase, kmaXmlError, kmaOK } from '../src/providers/kma.js';
import { parseMet, metUrl } from '../src/providers/met.js';
import { parseWeatherKit, weatherKitUrl, weatherKitToken, hasWeatherKit, resetWeatherKitTokens } from '../src/providers/weatherkit.js';
import { buildScene, validateScene } from '../src/scene.js';
import { level, outfit, bubble, uvNote, whenWord, alertNote, condition, rainKind, feelsWord, warningKind } from '../src/rules.js';
import { strings, normLang, warningName, hourLabel } from '../src/i18n.js';
import { sunDay, local, instant } from '../src/time.js';
import { feelsLike, humidityWord, windWord } from '../src/physics.js';
import worker, { forecast, readQuery, resetCache, setUpstreamTimeout, legacyIcons } from '../src/index.js';
import { beforeEach } from 'node:test';
beforeEach(() => { resetCache(); resetWeatherKitTokens(); });

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
  assert.equal(level(18), 4); assert.equal(level(17), 5); assert.equal(level(16), 5); assert.equal(level(13), 6, '13°: a jacket, not a knit alone');
  assert.equal(level(10), 6); assert.equal(level(9), 7); assert.equal(level(6), 7);
  assert.equal(level(0), 8); assert.equal(level(-12), 9);
  assert.equal(level(19.8, 4), 4, 'just over the 19.5 edge stays in 4 from 4');
  assert.equal(level(20.6, 4), 3, 'a full degree past the edge changes');
});

test('fifteen outfits: the bands and ±1° hysteresis', () => {
  const at = { 36: 0, 35: 0, 34: 1, 33: 1, 32: 2, 28: 2, 27: 3, 23: 3, 22: 4, 20: 4, 19: 5, 18: 5, 17: 6, 16: 6, 15: 7, 12: 7,
    11: 8, 9: 8, 8: 9, 6: 9, 5: 10, 3: 10, 2: 11, 0: 11, '-1': 12, '-4': 12, '-5': 13, '-9': 13, '-10': 14, '-20': 14 };
  for (const [c, o] of Object.entries(at)) assert.equal(outfit(Number(c)), o, `${c}°`);
  assert.equal(outfit(11.9, 8), 8, 'just over the 11.5 edge stays in 8 from 8');
  assert.equal(outfit(12.6, 8), 7, 'a full degree past the edge changes');
  assert.equal(outfit(-9.8, 13), 13); assert.equal(outfit(-10.6, 13), 14);
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
  assert.equal(windWord(2), '산들바람'); assert.equal(windWord(7), '바람 꽤 강해요'); assert.equal(windWord(9), '바람 강해요'); assert.equal(windWord(15), '강풍 · 외출 조심하세요');
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
  assert.equal(s.level, 4); assert.equal(s.outfit, outfit(s.feels)); assert.equal(s.temp, 18); assert.equal(s.hours.length, 13); assert.equal(s.hours[0][0], '지금');
  assert.equal(s.hours[1][0], '14시'); assert.equal(s.tiles[2].label, '일몰'); assert.equal(s.updated, '06:00');
  assert.equal(s.cond, '맑음');
  assert.equal(s.dayDetail.length, s.days.length); assert.equal(s.dayDetail[1].length, 8); assert.equal(s.dayDetail[1][4][0], '12시');
  assert.deepEqual(s.dayDetail[1][4].slice(6), [0, 4.8, 225], 'dry slot: no rain, gust 1.6 × 3 m/s, wind from the south-west');
});

test('day sheet chance: 30 % at 13 h between 20 % hours shows as 30 % in the 12–15 h slot, as in the day row', () => {
  const hrs = flat(40, { cloud: 60, sym: 'partlycloudy' });
  const i22 = (h) => 11 + h;
  for (let h = 0; h < 24; h++) hrs[i22(h)] = { ...hrs[i22(h)], pop: 20 };
  hrs[i22(13)] = { ...hrs[i22(13)], pop: 30 };
  const s = buildScene({ points: parseMet(met(at(13), hrs)).points }, { ...SEOUL, plan: 'free', now: at(13, 40) });
  assert.equal(s.days[1][2], 30);
  assert.equal(s.dayDetail[1][4][2], 30, '12–15 h'); assert.equal(s.dayDetail[1][5][2], 20, '15–18 h');
});

test('day sheet rows: + the 3-hour slot\'s rain (MET 6-hourly points spread over their hours), strongest gust, wind direction', () => {
  const hrs = flat(40, { cloud: 90, sym: 'cloudy' });   // 13:00 on the 21st + 40 h, so the 22nd is covered hour by hour
  const i22 = (h) => 11 + h;                             // index of h:00 on the 22nd
  hrs[i22(12)] = { cloud: 95, mm: 1.2, pop: 80, sym: 'rain' }; hrs[i22(13)] = { cloud: 95, mm: 2.0, pop: 80, sym: 'rain' };
  hrs[i22(14)] = { cloud: 95, mm: 0.6, pop: 70, sym: 'rain' };
  hrs[i22(16)] = { ...hrs[i22(16)], wind: 6, gust: 12.4 };
  const j = met(at(13), hrs);
  j.properties.timeseries[i22(9)].data.instant.details.wind_from_direction = 90;
  // after the hourly part MET steps 6 hours at a time, with next_6_hours only: 6 mm over 6 h is 1 mm in each hour
  const last = new Date(j.properties.timeseries.at(-1).time).getTime();   // 04:00 on the 23rd
  for (let k = 1; k <= 4; k++) {
    j.properties.timeseries.push({ time: new Date(last + k * 6 * 3600000).toISOString(), data: {
      instant: { details: { air_temperature: 15, relative_humidity: 70, wind_speed: 2, wind_from_direction: 180, cloud_area_fraction: 90 } },
      next_6_hours: { summary: { symbol_code: 'rain' }, details: { precipitation_amount: 6, probability_of_precipitation: 80 } } } });
  }
  const s = buildScene({ points: parseMet(j).points }, { ...SEOUL, plan: 'free', now: at(13, 40) });
  validateScene(s);
  const d22 = s.dayDetail[1], d23 = s.dayDetail[2];
  assert.ok(s.dayDetail.every((d) => d.every((r) => r.length === 9)), 'label + 5 point values + mm, gust, direction');
  assert.deepEqual(d22.map((r) => r[6]), [0, 0, 0, 0, 3.8, 0, 0, 0], '12–15h holds 1.2 + 2.0 + 0.6 mm');
  assert.equal(d22[5][7], 12.4, 'the strongest gust in 15–18h'); assert.equal(d22[4][7], 4.8);
  assert.equal(d22[3][8], 90); assert.equal(d22[4][8], 225);
  assert.deepEqual(d23.slice(3, 7).map((r) => r[6]), [2, 3, 3, 3], '10:00 and 16:00 points (6 h each, 1 mm/h) split over the slots');
  assert.equal(d23[4][7], 3, 'no gust in the source: 1.5 × wind'); assert.equal(d23[4][8], 180);
  // chance: the slot's highest, so the sheet's curve reaches the day's chance (13 h at 80 % sits between the 12 and 15 h slots)
  s.dayDetail.forEach((d, i) => assert.equal(Math.max(...d.map((r) => r[2])), s.days[i][2], `day ${i}: curve peak = the day's chance`));
  // older answers (6 values per row) still pass; anything else does not
  validateScene({ ...s, dayDetail: s.dayDetail.map((d) => d.map((r) => r.slice(0, 6))) });
  assert.throws(() => validateScene({ ...s, dayDetail: [[['0시', 1, 2, 3, 4, 5, 6, 7]]] }), /dayDetail/);
  assert.throws(() => validateScene({ ...s, dayDetail: [[['0시', 1, 2, 3, 4, 5, -1, 7, 90]]] }), /dayDetail/);
});

test('scene: rain in a few hours → bag + "16~17시 비 예보" (the hours people plan around)', () => {
  const hrs = flat(40, { cloud: 90, sym: 'cloudy' });
  hrs[3] = { cloud: 95, mm: 1.2, pop: 70, sym: 'rain' }; hrs[4] = { cloud: 95, mm: 2.0, pop: 70, sym: 'rain' };
  const m = parseMet(met(at(13), hrs));
  const s = buildScene({ points: m.points }, { ...SEOUL, plan: 'plus', now: at(13, 40) });
  validateScene(s);
  assert.equal(s.rain, 'bag');
  assert.equal(s.bubble.text, '16~17시 비 예보');
  assert.match(s.tiles[0].note, /^16~17시 비 예보 · /);
  assert.equal(s.tiles[0].value, '70%');
});

test('scene: 60 % before the rain is not rain — "18~23시", not "16~23시" (기상청 gives the dry hours 60 %)', () => {
  // now 15:07; 16 and 17 h: 60 %, no amount; 18–20 h rain; 21–23 h 0.5 mm; 0 h 30 %
  const hrs = flat(40, { cloud: 90, sym: 'cloudy', pop: 30 });
  hrs[0] = { cloud: 95, pop: 60, sym: 'cloudy' }; hrs[1] = { cloud: 95, pop: 60, sym: 'cloudy' }; hrs[2] = { cloud: 95, pop: 60, sym: 'cloudy' };
  for (const [i, mm] of [[3, 1], [4, 2], [5, 2], [6, 0.5], [7, 0.5], [8, 0.5]]) hrs[i] = { cloud: 95, mm, pop: 60, sym: 'rain' };
  const m = parseMet(met(at(15), hrs));
  const s = buildScene({ points: m.points }, { ...SEOUL, plan: 'plus', now: at(15, 7) });
  validateScene(s);
  assert.equal(s.rain, 'bag');
  assert.equal(s.bubble.text, '18~23시 비 예보');
  assert.match(s.tiles[0].note, /^18~23시 비 예보 · /);
  // a dry 60 % hour inside the spell still belongs to it; the 60 % hours after it do not
  hrs[5] = { cloud: 95, pop: 60, sym: 'cloudy' }; hrs[9] = { cloud: 95, pop: 60, sym: 'cloudy' };
  const t = buildScene({ points: parseMet(met(at(15), hrs)).points }, { ...SEOUL, plan: 'plus', now: at(15, 7) });
  assert.equal(t.bubble.text, '18~23시 비 예보');
  // no amounts anywhere (only chances): a 60 % chance still says when
  const dry = flat(40, { cloud: 90, sym: 'cloudy', pop: 20 });
  dry[3] = { cloud: 95, pop: 70, sym: 'cloudy' }; dry[4] = { cloud: 95, pop: 70, sym: 'cloudy' };
  const u = buildScene({ points: parseMet(met(at(15), dry)).points }, { ...SEOUL, plan: 'plus', now: at(15, 7) });
  assert.equal(u.bubble.text, '18~19시 비 예보');
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
  assert.equal(s.time, 'night'); assert.equal(s.level, 9); assert.equal(s.outfit, 14); assert.ok(s.feels <= -10);
  assert.equal(s.bubble.text, '한파!'); assert.equal(s.mood, 'cold'); assert.equal(s.tiles[2].label, '일출');
});

test('bubble priority: official warning first', () => {
  const b = bubble({ warnings: [{ name: '호우경보', severity: 2 }], thunder: true, nowWet: true, nowPr: 'heavy', feels: 20 });
  assert.deepEqual(b, { kind: 'shout', tone: 'coral', icon: 'raincloud', text: '호우경보' });
});

test('alert line under the character: the warning name + what it means today', () => {
  // what it means today, then what to do
  assert.equal(alertNote('대설주의보', { total: 6, pr: 'snow', nowWet: true, when: '', endH: 18, hi: 0, lo: -5 }), '오늘 6cm, 18시까지 눈 예보, 미끄러우니 조심하세요');
  assert.equal(alertNote('대설주의보', { total: 6, pr: 'snow', nowWet: false, when: '15~17시', endH: null, hi: 0, lo: -5 }), '오늘 6cm, 15~17시 눈 예보, 미끄러우니 조심하세요');
  assert.equal(alertNote('대설주의보', { total: 0, pr: 'none', nowWet: false, when: '', endH: null }), '바닥이 미끄러우니 눈길 조심하세요');
  assert.equal(alertNote('호우주의보', { total: 42, pr: 'rain', nowWet: false, when: '15~19시', endH: null, hi: 25, lo: 22 }), '오늘 42mm (많음), 15~19시 비 예보, 우산·우비 챙기세요');
  assert.equal(alertNote('호우경보', { total: 69, pr: 'heavy', nowWet: true, when: '', endH: 18 }), '오늘 69mm (매우 많음), 18시까지 비 예보, 우산·우비 챙기세요');
  assert.equal(alertNote('호우주의보', { total: 0, pr: 'none', nowWet: false, when: '', endH: null }), '비가 많이 와요, 우산 꼭 챙기고 우비도 있으면 좋아요');
  assert.equal(alertNote('폭염경보', { total: 0, pr: 'none', hi: 36, lo: 27 }), '낮 최고 36°, 모자·선크림을 챙기고 물을 자주 마시는 게 좋아요');
  assert.equal(alertNote('한파주의보', { total: 0, pr: 'none', hi: -6, lo: -14 }), '아침 -14°, 장갑·목도리·핫팩 챙기세요');
  assert.equal(alertNote('강풍주의보', { gust: 18 }), '돌풍 18 m/s, 날리는 물건과 우산 조심하세요');
  assert.equal(alertNote('풍랑주의보', {}), '바람이 매우 강해요, 날리는 물건과 우산 조심하세요');
  assert.equal(alertNote('태풍경보', { gust: 26 }), '강한 비바람, 돌풍 26 m/s, 되도록 외출은 줄이는 게 좋아요');
  assert.equal(alertNote('건조주의보', { rh: 25 }), '습도 25%, 불씨 조심하세요');
  assert.equal(alertNote('황사경보', {}), '황사가 심해요, 마스크 챙기세요');
  assert.equal(alertNote('미세먼지경보', {}), '미세먼지가 심해요, 마스크 챙기세요');
  assert.equal(alertNote('해일주의보', { pr: 'snow' }), '바닥이 미끄러우니 조심하세요');
  assert.equal(alertNote('해일주의보', { pr: 'none' }), '외출할 때 조심하세요');
  const hrs = flat(40, { cloud: 95, mm: 3, pop: 90, sym: 'rain' });
  const m = parseMet(met(at(13), hrs));
  const s = buildScene({ points: m.points, warnings: [{ name: '호우주의보', severity: 1 }] }, { ...SEOUL, plan: 'plus', now: at(13, 40) });
  validateScene(s);
  assert.equal(s.alert.name, '호우주의보'); assert.match(s.alert.note, /^오늘 \d+(\.\d)?mm/);
  assert.equal(s.bubble.text, '호우주의보');
});

// ---- languages (docs/i18n-glossary.md) ----

test('lang: ko default, en / ja chosen, anything else → en', () => {
  assert.equal(readQuery(new URLSearchParams('lat=37.57&lon=126.9')).lang, 'ko');
  assert.equal(readQuery(new URLSearchParams('lat=37.57&lon=126.9&lang=ja')).lang, 'ja');
  assert.equal(readQuery(new URLSearchParams('lat=37.57&lon=126.9&lang=fr')).lang, 'en');
  assert.equal(normLang(undefined), 'ko'); assert.equal(normLang('EN'), 'en');
});

test('scene in en / ja: rain in a few hours → "Rain 4–5PM" · "16〜17時 雨", labels and tiles translated, icons and numbers unchanged', () => {
  const hrs = flat(40, { cloud: 90, sym: 'cloudy' });
  hrs[3] = { cloud: 95, mm: 1.2, pop: 70, sym: 'rain' }; hrs[4] = { cloud: 95, mm: 2.0, pop: 70, sym: 'rain' };
  const m = parseMet(met(at(13), hrs));
  const build = (lang) => buildScene({ points: m.points, next6: m.points.slice(1, 7) }, { ...SEOUL, plan: 'plus', now: at(13, 40), lang });
  const ko = build('ko'), en = build('en'), ja = build('ja');
  for (const s of [en, ja]) validateScene(s);
  assert.equal(en.bubble.text, 'Rain 4–5PM'); assert.match(en.tiles[0].note, /^Rain 4–5PM · /);
  assert.equal(ja.bubble.text, '16〜17時 雨の予報'); assert.match(ja.tiles[0].note, /^16〜17時 雨の予報 · /);
  assert.equal(ko.bubble.text, '16~17시 비 예보');
  assert.deepEqual([en.bubble.kind, en.bubble.tone, en.bubble.icon], [ko.bubble.kind, ko.bubble.tone, ko.bubble.icon]);
  assert.equal(en.cond, 'Cloudy'); assert.equal(ja.cond, '曇り');
  assert.deepEqual(en.hours.slice(0, 3).map((h) => h[0]), ['Now', '2PM', '3PM']); assert.deepEqual(ja.hours.slice(0, 3).map((h) => h[0]), ['今', '14時', '15時']);
  assert.deepEqual(en.hours.map((h) => h.slice(1)), ko.hours.map((h) => h.slice(1)), 'icons and numbers do not change with the language');
  assert.equal(en.days[0][0], 'Today'); assert.equal(en.days[1][0], 'Thu'); assert.equal(ja.days[0][0], '今日'); assert.equal(ja.days[1][0], '木'); assert.equal(ko.days[1][0], '목');
  assert.deepEqual(en.tiles.map((t) => t.label), ['Rain chance', 'UV', 'Sunset', 'Humidity']);
  assert.deepEqual(ja.tiles.map((t) => t.label), ['降水確率', '紫外線', '日の入り', '湿度']);
  assert.match(en.tiles[2].note, /^Sunrise tomorrow \d\d:\d\d$/); assert.match(ja.tiles[2].note, /^明日の日の出 \d\d:\d\d$/);
  assert.match(en.tiles[3].note, /^Comfortable · Dew point \d+°$/); assert.match(ja.tiles[3].note, /^ちょうどいい · 露点 \d+°$/);
  assert.equal(en.next6[0][0], '2PM'); assert.equal(ja.next6[0][0], '14時');
  assert.deepEqual(en.dayDetail[0].map((h) => h[0]), ['12AM', '3AM', '6AM', '9AM', '12PM', '3PM', '6PM', '9PM']);
  assert.equal(ja.dayDetail[0][5][0], '15時');
  assert.equal(en.updated, ko.updated); assert.equal(en.clock, ko.clock);
  const dry = buildScene({ points: parseMet(met(at(13), flat(40))).points }, { ...SEOUL, plan: 'free', now: at(13, 40), lang: 'en' });
  assert.equal(dry.tiles[0].note, 'No rain for the next 12 hours'); assert.equal(dry.updated, '06:00');
  assert.equal(buildScene({ points: parseMet(met(at(13), flat(40))).points }, { ...SEOUL, plan: 'free', now: at(13, 40), lang: 'ja' }).tiles[0].note, '12時間 雨の心配はありません');
});

test('words per language: condition, when, hour, rain kind, feels, humidity, wind, UV', () => {
  const c = { pr: 'rain', cov: 'overcast', thunder: false, auxKind: 'none', night: false, feels: 15 };
  assert.equal(condition(c), '비'); assert.equal(condition(c, 'en'), 'Rain'); assert.equal(condition(c, 'ja'), '雨');
  assert.equal(condition({ ...c, pr: 'none', auxKind: 'wind' }, 'en'), 'Cloudy · Windy'); assert.equal(condition({ ...c, auxKind: 'wind' }, 'ja'), '雨 · 強風');
  assert.equal(whenWord(15, 17, false, 'en'), '3–5PM'); assert.equal(whenWord(15, 15, false, 'en'), 'around 3PM'); assert.equal(whenWord(7, 9, true, 'en'), 'tomorrow 7–9AM');
  assert.equal(whenWord(11, 13, false, 'en'), '11AM–1PM');
  assert.equal(whenWord(15, 17, false, 'ja'), '15〜17時'); assert.equal(whenWord(15, 15, false, 'ja'), '15時ごろ'); assert.equal(whenWord(7, 9, true, 'ja'), '明日7〜9時');
  assert.equal(hourLabel(0, 'en'), '12AM'); assert.equal(hourLabel(12, 'en'), '12PM'); assert.equal(hourLabel(14, 'ko'), '14시'); assert.equal(hourLabel(14, 'ja'), '14時');
  assert.equal(rainKind(5, 'en'), 'Moderate rain'); assert.equal(rainKind(5, 'ja'), 'やや強い雨'); assert.equal(rainKind(5), '보통 비');
  assert.equal(feelsWord(20, 'en'), 'Mild'); assert.equal(feelsWord(20), '온화'); assert.equal(feelsWord(-12, 'ja'), '極寒');
  assert.equal(humidityWord({ temp: 8, rh: 92, dew: 7, wet: true }, 'en'), 'Damp'); assert.equal(humidityWord({ temp: 30, rh: 70, dew: 24 }, 'ja'), '非常にべたつく');
  assert.equal(windWord(2, 'en'), 'Gentle breeze'); assert.equal(windWord(15, 'ja'), '暴風 · 外出にご注意ください');
  assert.equal(uvNote(1, 'en'), 'Low'); assert.equal(uvNote(null, 'ja'), '情報なし'); assert.ok(uvNote(11, 'en').startsWith('Extreme'));
  assert.equal(strings('en').bubble.umbrella, 'Take an umbrella'); assert.equal(strings('ja').bubble.thunder, '雷!');
});

test('warnings translate by the glossary table, unknown names pass through', () => {
  assert.equal(warningName('호우주의보', 'en'), 'Heavy Rain Advisory'); assert.equal(warningName('호우주의보', 'ja'), '大雨注意報');
  assert.equal(warningName('태풍경보', 'en'), 'Typhoon Warning'); assert.equal(warningName('강풍경보', 'ja'), '暴風警報');
  assert.equal(warningName('호우주의보', 'ko'), '호우주의보'); assert.equal(warningName('황사경보', 'en'), '황사경보');
  const b = bubble({ warnings: [{ name: '대설경보', severity: 2 }], feels: 0 }, 'en');
  assert.deepEqual(b, { kind: 'shout', tone: 'coral', icon: 'snowflake', text: 'Heavy Snow Warning' });
  assert.equal(alertNote('대설주의보', { total: 6, pr: 'snow', nowWet: true, when: '', endH: 18, hi: 0, lo: -5 }, 'en'), '6cm today, snow until around 6PM, watch your step');
  assert.equal(alertNote('대설주의보', { total: 6, pr: 'snow', nowWet: true, when: '', endH: 18, hi: 0, lo: -5 }, 'ja'), '今日 6cm、18時ごろまで雪の予報、滑りやすいのでご注意ください');
  assert.equal(alertNote('폭염경보', { total: 0, pr: 'none', hi: 36, lo: 27 }, 'en'), 'High 36°, wear a hat and sunscreen and drink water often');
  const hrs = flat(40, { cloud: 95, mm: 3, pop: 90, sym: 'rain' });
  const s = buildScene({ points: parseMet(met(at(13), hrs)).points, warnings: [{ name: '호우주의보', severity: 1 }] }, { ...SEOUL, plan: 'plus', now: at(13, 40), lang: 'en' });
  validateScene(s);
  assert.equal(s.alert.name, 'Heavy Rain Advisory'); assert.equal(s.bubble.text, 'Heavy Rain Advisory'); assert.match(s.alert.note, /^\d+(\.\d)?mm today \(/);
  assert.equal(s.bubble.icon, 'raincloud');
});

test('HTTP: lang=en answers in English', async () => {
  const now = at(9, 0);
  const fetcher = fakeFetch([['api.met.no', met(now, flat(48))]]);
  const q = readQuery(new URLSearchParams('lat=37.5663&lon=126.9019&region=other&tz=Asia/Seoul&plan=free&lang=en'));
  const s = await forecast(q, {}, null, { now, fetcher });
  validateScene(s);
  assert.equal(s.cond, 'Clear'); assert.equal(s.hours[0][0], 'Now'); assert.equal(s.days[0][0], 'Today');
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

test('Korea, Plus in the afternoon: today\'s low and the morning hours come from the earlier runs', async () => {
  const now = at(13, 50);
  const hours = (from, n, temp) => {   // a 단기예보 answer: n hours from `from`, plus TMN / TMX when given
    const items = [];
    for (let i = 0; i < n; i++) {
      const p = local(new Date(from.getTime() + i * 3600000), TZ);
      const date = `${p.y}${String(p.m).padStart(2, '0')}${String(p.d).padStart(2, '0')}`, time = `${String(p.h).padStart(2, '0')}00`;
      for (const [c, v] of [['TMP', String(temp(p.h))], ['POP', '0'], ['PCP', '강수없음'], ['PTY', '0'], ['SKY', '1'], ['REH', '40'], ['WSD', '1.0'], ['VEC', '200']]) items.push({ fcstDate: date, fcstTime: time, category: c, fcstValue: v });
    }
    return items;
  };
  const day = (h) => (h < 7 ? 2 + h * 0.2 : h <= 15 ? 3 + h * 0.65 : 22 - h * 0.6);   // 2° at dawn, 13° mid-afternoon
  const today = '20261021';
  const ok = (item) => ({ response: { header: { resultCode: '00' }, body: { items: { item } } } });
  const latest = ok(hours(at(12, 0), 36, day));                                                     // 11 h run: no TMN / TMX for today
  const five = ok([...hours(at(6, 0), 40, day), { fcstDate: today, fcstTime: '0600', category: 'TMN', fcstValue: '2.0' }, { fcstDate: today, fcstTime: '1500', category: 'TMX', fcstValue: '13.0' }]);
  const eve = ok([...hours(at(0, 0), 46, day), { fcstDate: today, fcstTime: '0600', category: 'TMN', fcstValue: '1.0' }]);
  const fetcher = fakeFetch([
    ['getVilageFcst', (url) => (url.includes('base_time=0500') ? five : url.includes('base_time=2300') ? eve : latest)],
    ['getUltraSrtFcst', new Error('down')], ['getUltraSrtNcst', new Error('down')],
    ['getPwnStatus', { response: { header: { resultCode: '00' }, body: { items: { item: [] } } } }],
    ['api.met.no', met(now, flat(240, { temp: 12 }))],
  ]);
  const q = readQuery(new URLSearchParams('lat=37.5663&lon=126.9019&region=kr&tz=Asia/Seoul&plan=plus&name=서울 마포구'));
  const s = await forecast(q, { KMA_SERVICE_KEY: 'k' }, null, { now, fetcher });
  validateScene(s);
  assert.equal(s.lo, 2, 'today\'s low is the 05 h run\'s TMN, not the lowest hour still ahead');
  assert.equal(s.hi, 13);
  assert.equal(s.days[0][3], 2);
  assert.equal(Math.round(s.dayDetail[0][0][1]), 2, '0시 from yesterday\'s 23 h run, not the first hour of the 11 h run');
  assert.equal(Math.round(s.dayDetail[0][3][1]), Math.round(day(9)), '9시 from the 05 h run');
});

test('Korea, KMA hanging → the answer comes from MET within the upstream time limit', async () => {
  const now = at(9, 0);
  setUpstreamTimeout(300);
  const base = fakeFetch([['api.met.no', met(now, flat(48))]]);
  const fetcher = (url, opts) => (url.includes('apis.data.go.kr') ? new Promise(() => {}) : base(url, opts));   // never answers
  const q = readQuery(new URLSearchParams('lat=37.5663&lon=126.9019&region=kr&tz=Asia/Seoul&plan=plus'));
  const t0 = Date.now();
  try {
    const s = await forecast(q, { KMA_SERVICE_KEY: 'k' }, null, { now, fetcher });
    validateScene(s);
    assert.equal(s.src, 'met');
    assert.ok(Date.now() - t0 < 2000, `answered in ${Date.now() - t0} ms`);
  } finally { setUpstreamTimeout(); }
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

// ---- Apple WeatherKit (every region but Korea; MET when it is not configured or fails) ----

/** WeatherKit-shaped JSON: 48 hourly from `start` (REST units: °C, km/h, mm, m, 0–1), 10 daily, 60 minutes, one alert */
function weatherKit(start, { wetHours = [], minuteRain = false, alert = true, temp = 20 } = {}) {
  const hours = [];
  for (let i = 0; i < 48; i++) {
    const wet = wetHours.includes(i);
    hours.push({
      forecastStart: new Date(start.getTime() + i * 3600000).toISOString(), cloudCover: wet ? 0.95 : 0.2, conditionCode: wet ? 'Rain' : 'MostlyClear',
      daylight: true, humidity: 0.62, precipitationAmount: wet ? 1.8 : 0, precipitationIntensity: wet ? 1.8 : 0, precipitationChance: wet ? 0.8 : 0.05,
      precipitationType: wet ? 'rain' : 'clear', pressure: 1013, pressureTrend: 'steady', snowfallIntensity: 0, snowfallAmount: 0,
      temperature: temp, temperatureApparent: temp, temperatureDewPoint: 12.5, uvIndex: 4, visibility: 18000, windDirection: 180, windGust: 36, windSpeed: 18,
    });
  }
  const days = [];
  for (let i = 0; i < 10; i++) {
    const d = new Date(start.getTime() + i * 86400000);
    days.push({ forecastStart: d.toISOString(), forecastEnd: new Date(d.getTime() + 86400000).toISOString(), conditionCode: 'MostlyClear', temperatureMax: temp + 5, temperatureMin: temp - 5, precipitationChance: 0.1, precipitationType: 'clear', precipitationAmount: 0 });
  }
  const minutes = Array.from({ length: 60 }, (_, i) => ({ startTime: new Date(start.getTime() + i * 60000).toISOString(), precipitationChance: minuteRain && i >= 20 ? 0.7 : 0, precipitationIntensity: minuteRain && i >= 20 ? 0.5 + i / 100 : 0 }));
  const alerts = alert ? [{ name: 'test-alert-1', areaName: 'Tokyo', certainty: 'likely', countryCode: 'JP', description: 'Heavy Rain Warning', detailsUrl: 'https://example.invalid', effectiveTime: start.toISOString(), expireTime: new Date(start.getTime() + 6 * 3600000).toISOString(), issuedTime: start.toISOString(), precedence: 0, severity: 'severe', source: 'JMA', eventSource: 'JMA', urgency: 'expected', responses: [] }] : [];
  return {
    currentWeather: { name: 'CurrentWeather', metadata: { readTime: start.toISOString(), expireTime: new Date(start.getTime() + 600000).toISOString() }, asOf: start.toISOString(), cloudCover: 0.3, conditionCode: 'PartlyCloudy', daylight: true, humidity: 0.6, precipitationIntensity: 0, temperature: temp + 0.7, temperatureApparent: temp, temperatureDewPoint: 12, uvIndex: 4, visibility: 20000, windDirection: 190, windGust: 30, windSpeed: 14.4 },
    forecastHourly: { name: 'HourWeather', metadata: { readTime: start.toISOString() }, hours },
    forecastDaily: { name: 'DailyWeather', metadata: {}, days },
    forecastNextHour: { name: 'NextHourForecast', metadata: {}, forecastStart: start.toISOString(), forecastEnd: new Date(start.getTime() + 3600000).toISOString(), minutes, summary: [] },
    weatherAlerts: { name: 'WeatherAlertCollection', metadata: {}, alerts, detailsUrl: 'https://example.invalid' },
  };
}

/** A throw-away P-256 key as the .p8 PEM text Apple hands out */
async function testP8() {
  const kp = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
  const der = new Uint8Array(await crypto.subtle.exportKey('pkcs8', kp.privateKey));
  const b64 = btoa(String.fromCharCode(...der)).match(/.{1,64}/g).join('\n');
  return { pem: `-----BEGIN PRIVATE KEY-----\n${b64}\n-----END PRIVATE KEY-----\n`, publicKey: kp.publicKey };
}
const wkEnv = (pem) => ({ WEATHERKIT_KEY_P8: pem, WEATHERKIT_KEY_ID: 'ABC123DEFG', APPLE_TEAM_ID: '9865Z67LR4', WEATHERKIT_SERVICE_ID: 'app.purrcast.ios' });

test('WeatherKit: URL (lang, 4 decimals, tz, country) and the parsed shapes in our units', () => {
  assert.equal(weatherKitUrl(35.693812, 139.70341, { lang: 'ja', tz: 'Asia/Tokyo', country: 'JP' }),
    'https://weatherkit.apple.com/api/v1/weather/ja/35.6938/139.7034?dataSets=currentWeather,forecastHourly,forecastDaily,forecastNextHour,weatherAlerts&timezone=Asia%2FTokyo&countryCode=JP');
  assert.doesNotMatch(weatherKitUrl(40.7, -74, { lang: 'en', tz: 'America/New_York' }), /countryCode/);
  const start = instant(2026, 10, 21, 15, 0, 'Asia/Tokyo');
  const w = parseWeatherKit(weatherKit(start, { wetHours: [3, 4], minuteRain: true }), 'Asia/Tokyo');
  assert.equal(w.points.length, 48);
  const p = w.points[0];
  assert.equal(p.source, 'apple'); assert.equal(p.step, 1); assert.equal(p.t.getTime(), start.getTime());
  assert.equal(p.temp, 20); assert.equal(p.rh, 62); assert.equal(p.dew, 12.5); assert.equal(p.wind, 5); assert.equal(p.gust, 10); assert.equal(p.dir, 180);
  assert.equal(p.cloud, 20); assert.equal(p.fog, false); assert.equal(p.mm, 0); assert.equal(p.pop, 5); assert.equal(p.type, 'none'); assert.equal(p.thunder, false); assert.equal(p.symbol, 'MostlyClear');
  assert.ok(Math.abs(p.uvClear - 4 / (1 - 0.75 * Math.pow(0.2, 3.4))) < 1e-9, 'uvIndex is already under cloud: undone so scene.js lands back on 4');
  const wet = w.points[3];
  assert.equal(wet.mm, 1.8); assert.equal(wet.pop, 80); assert.equal(wet.type, 'rain'); assert.equal(wet.cloud, 95);
  assert.deepEqual(w.now, { t: start, temp: 20.7, rh: 60, wind: 4, dir: 190, mm: 0, type: 'none' });
  assert.deepEqual(w.daily['20261021'], { lo: 15, hi: 25 }); assert.equal(Object.keys(w.daily).length, 10);
  assert.equal(w.minutes.length, 60); assert.equal(w.minutes[0], 0); assert.equal(w.minutes[20], 0.7); assert.equal(w.minutesStart.getTime(), start.getTime());
  assert.deepEqual(w.warnings, [{ name: 'Heavy Rain Warning', severity: 2, until: new Date(start.getTime() + 6 * 3600000).toISOString() }]);
  assert.equal(w.updated.getTime(), start.getTime());
  // thunder, snow, sleet, fog, missing fields
  const j = weatherKit(start, { alert: false });
  Object.assign(j.forecastHourly.hours[0], { conditionCode: 'Thunderstorms', precipitationType: 'rain', precipitationAmount: 4 });
  Object.assign(j.forecastHourly.hours[1], { conditionCode: 'Snow', precipitationType: 'snow', precipitationAmount: 2 });
  Object.assign(j.forecastHourly.hours[2], { conditionCode: 'Sleet', precipitationType: 'mixed', precipitationAmount: 1 });
  Object.assign(j.forecastHourly.hours[3], { conditionCode: 'Fog', visibility: 400 });
  Object.assign(j.forecastHourly.hours[4], { precipitationType: 'rain', precipitationAmount: 0 });
  delete j.forecastNextHour;
  const v = parseWeatherKit(j, 'Asia/Tokyo');
  assert.equal(v.points[0].thunder, true); assert.equal(v.points[0].type, 'rain');
  assert.equal(v.points[1].type, 'snow'); assert.equal(v.points[2].type, 'sleet'); assert.equal(v.points[3].fog, true);
  assert.equal(v.points[4].type, 'none', 'a type with no amount this hour is dry');
  assert.equal(v.minutes, null); assert.deepEqual(v.warnings, []);
  assert.deepEqual(parseWeatherKit({}).points, []);
});

test('WeatherKit JWT: ES256 over WebCrypto, header / payload as Apple wants, cached until near expiry', async () => {
  const { pem, publicKey } = await testP8();
  const env = wkEnv(pem);
  assert.equal(hasWeatherKit(env), true); assert.equal(hasWeatherKit({ WEATHERKIT_KEY_ID: 'x' }), false);
  const now = at(12, 0);
  const jwt = await weatherKitToken(env, { now });
  const [h, p, s] = jwt.split('.');
  const dec = (x) => JSON.parse(Buffer.from(x.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString());
  assert.deepEqual(dec(h), { alg: 'ES256', kid: 'ABC123DEFG', id: '9865Z67LR4.app.purrcast.ios' });
  const iat = Math.floor(now.getTime() / 1000);
  assert.deepEqual(dec(p), { iss: '9865Z67LR4', iat, exp: iat + 3600, sub: 'app.purrcast.ios' });
  const sig = Buffer.from(s.replace(/-/g, '+').replace(/_/g, '/'), 'base64');
  assert.equal(sig.length, 64, 'raw r||s');
  assert.equal(await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, publicKey, sig, new TextEncoder().encode(`${h}.${p}`)), true);
  assert.equal(await weatherKitToken(env, { now: new Date(now.getTime() + 50 * 60000) }), jwt, 'reused with 10 minutes left');
  assert.notEqual(await weatherKitToken(env, { now: new Date(now.getTime() + 56 * 60000) }), jwt, 'renewed under 5 minutes');
});

test('Tokyo, Plus: WeatherKit with the key — bearer JWT sent, nextSource apple, minutes present, alert passes through', async () => {
  const { pem } = await testP8();
  const now = instant(2026, 10, 21, 15, 0, 'Asia/Tokyo');
  let auth = null, wkUrl = null;
  const fetcher = async (url, init) => {
    if (url.includes('weatherkit.apple.com')) {
      auth = init?.headers?.authorization; wkUrl = url;
      return new Response(JSON.stringify(weatherKit(now, { wetHours: [3, 4], minuteRain: true })), { status: 200 });
    }
    return fakeFetch([['api.met.no', met(now, flat(48, { temp: 5 }))]])(url);
  };
  const q = readQuery(new URLSearchParams('lat=35.69&lon=139.70&region=jp&tz=Asia/Tokyo&plan=plus&lang=en'));
  const s = await forecast(q, wkEnv(pem), null, { now, fetcher });
  validateScene(s);
  assert.match(auth, /^Bearer [\w-]+\.[\w-]+\.[\w-]+$/);
  assert.match(wkUrl, /\/weather\/en\/35\.69\/139\.7\?.*countryCode=JP/);
  assert.equal(s.src, 'apple'); assert.equal(s.nextSource, 'apple'); assert.equal(s.next6, undefined, 'minute rain stands in for the 6-hour card');
  assert.equal(s.minutes.length, 60); assert.equal(s.minutes[30], 0.8);
  assert.equal(s.temp, 21, 'currentWeather wins for now (20.7 → 21), not MET\'s 5°');
  assert.equal(s.clock, '15:00'); assert.equal(s.updated, '15:00');
  assert.equal(s.days[0][3], 15); assert.equal(s.days[0][4], 25, 'daily min / max from forecastDaily');
  assert.equal(s.rain, 'bag'); assert.equal(s.hours[3][4], 1.8);
  assert.equal(s.alert.name, 'Heavy Rain Warning'); assert.equal(s.bubble.text, 'Heavy Rain Warning'); assert.equal(s.bubble.icon, 'raincloud');
  assert.match(s.alert.note, /mm today/);
  assert.equal(s.tiles[1].uv, 4, 'UV index as Apple gave it');
  // free: no minutes / next6 / now
  const free = await forecast(readQuery(new URLSearchParams('lat=35.69&lon=139.70&region=jp&tz=Asia/Tokyo&plan=free')), wkEnv(pem), null, { now, fetcher });
  validateScene(free);
  assert.equal(free.src, 'apple'); assert.equal(free.minutes, undefined); assert.equal(free.next6, undefined); assert.equal(free.temp, 20);
});

test('Tokyo, free: one Apple forecast a day (the first after 06:00 is kept), Plus stays live', async () => {
  const { pem } = await testP8();
  const kv = new Map();
  const FREE_DAY = { get: async (k, type) => (kv.has(k) ? (type === 'json' ? JSON.parse(kv.get(k)) : kv.get(k)) : null), put: async (k, v) => { kv.set(k, v); } };
  const env = { ...wkEnv(pem), FREE_DAY };
  let calls = 0, temp = 20;
  const fetcher = async (url) => {
    if (url.includes('weatherkit.apple.com')) {
      calls++;
      const json = weatherKit(start, { temp });
      return new Response(JSON.stringify(json), { status: 200 });
    }
    return fakeFetch([['api.met.no', met(start, flat(72, { temp: 5 }))]])(url);
  };
  const tk = (d, h, mi = 0) => instant(2026, 10, d, h, mi, 'Asia/Tokyo');
  let start = tk(21, 9);
  const q = (plan) => readQuery(new URLSearchParams(`lat=35.69&lon=139.70&region=jp&tz=Asia/Tokyo&plan=${plan}&lang=en`));
  const morning = await forecast(q('free'), env, null, { now: tk(21, 9, 12), fetcher });
  assert.equal(calls, 1); assert.equal(morning.updated, '09:12', 'the label says when the day\'s forecast was taken');
  assert.equal(kv.size, 1);
  // the afternoon: Apple has moved on (25°), free still tells the day from the morning forecast
  resetCache(); temp = 25; start = tk(21, 15);
  const afternoon = await forecast(q('free'), env, null, { now: tk(21, 15, 30), fetcher });
  validateScene(afternoon);
  assert.equal(calls, 1, 'no new Apple call for free'); assert.equal(afternoon.temp, 20); assert.equal(afternoon.updated, '09:12');
  assert.equal(afternoon.alert, undefined, 'the morning\'s alert expired at 15:00 (6 h after it was issued)');
  const plus = await forecast(q('plus'), env, null, { now: tk(21, 15, 30), fetcher });
  assert.equal(calls, 2); assert.equal(plus.temp, 26, 'Plus: Apple now (25.7)');
  // before 06:00 the next morning: still yesterday's day; after 06:00: a new one
  resetCache();
  const dawn = await forecast(q('free'), env, null, { now: tk(22, 5, 30), fetcher });
  assert.equal(dawn.updated, '09:12'); assert.equal(calls, 2);
  resetCache(); start = tk(22, 7);
  const next = await forecast(q('free'), env, null, { now: tk(22, 7, 5), fetcher });
  assert.equal(calls, 3); assert.equal(next.updated, '07:05'); assert.equal(next.temp, 25);
});

test('WeatherKit 401 (or no key) → MET carries on; Korea still uses KMA with the key set', async () => {
  const { pem } = await testP8();
  const now = instant(2026, 10, 21, 15, 0, 'Asia/Tokyo');
  const fetcher = async (url) => url.includes('weatherkit.apple.com') ? new Response('{"reason":"NOT_ENABLED"}', { status: 401 }) : fakeFetch([['api.met.no', met(now, flat(48, { temp: 7 }))]])(url);
  const q = readQuery(new URLSearchParams('lat=35.69&lon=139.70&region=jp&tz=Asia/Tokyo&plan=plus'));
  const s = await forecast(q, wkEnv(pem), null, { now, fetcher });
  validateScene(s);
  assert.equal(s.src, 'met'); assert.equal(s.nextSource, 'met'); assert.equal(s.temp, 7); assert.equal(s.minutes, undefined);
  const noKey = await forecast(q, { WEATHERKIT_KEY_ID: 'only-the-id' }, null, { now, fetcher: fakeFetch([['api.met.no', met(now, flat(48, { temp: 7 }))]]) });
  assert.equal(noKey.src, 'met');
  // Korea keeps KMA even with WeatherKit configured
  const kst = at(13, 50);
  let appleCalled = false;
  const krFetch = async (url) => {
    if (url.includes('weatherkit.apple.com')) { appleCalled = true; return new Response('{}', { status: 200 }); }
    return fakeFetch([['getVilageFcst', kmaFixture(kst)], ['api.met.no', met(kst, flat(240, { temp: 12 }))]])(url);
  };
  const kr = await forecast(readQuery(new URLSearchParams('lat=37.5663&lon=126.9019&region=kr&tz=Asia/Seoul&plan=free')), { ...wkEnv(pem), KMA_SERVICE_KEY: 'k' }, null, { now: kst, fetcher: krFetch });
  validateScene(kr);
  assert.equal(kr.src, 'kma'); assert.equal(appleCalled, true);   // Apple is fetched for the comparison card only
  assert.deepEqual(kr.cmp.sources.map((s) => s.key), ['kma', 'met']);   // an empty Apple answer leaves 기상청 + MET in the comparison
});

test('예보 비교: the main source first, the others for the same 24 hours; absent elsewhere', async () => {
  const kst = at(13, 50);
  const { pem } = await testP8();
  const krFetch = async (url) => {
    if (url.includes('weatherkit.apple.com')) return new Response(JSON.stringify(weatherKit(kst)), { status: 200 });
    return fakeFetch([['getVilageFcst', kmaFixture(kst)], ['api.met.no', met(kst, flat(240, { temp: 12 }))]])(url);
  };
  const kr = await forecast(readQuery(new URLSearchParams('lat=37.5663&lon=126.9019&region=kr&tz=Asia/Seoul&plan=free&lang=ko')), { ...wkEnv(pem), KMA_SERVICE_KEY: 'k' }, null, { now: kst, fetcher: krFetch });
  validateScene(kr);
  assert.equal(kr.cmp.sources.length, 3);
  assert.deepEqual(kr.cmp.sources.map((s) => s.key), ['kma', 'apple', 'met']);
  assert.deepEqual(kr.cmp.sources.map((s) => s.name), ['기상청', 'Apple 날씨', 'MET Norway']);
  assert.equal(kr.cmp.sources[0].main, true); assert.equal(kr.cmp.sources[1].main, false);
  for (const s of kr.cmp.sources) { assert.equal(s.t.length, 24); assert.equal(s.r.length, 24); assert.ok(Number.isInteger(s.t[0])); }
  assert.ok(Number.isInteger(kr.cmp.start) && kr.cmp.start >= 0 && kr.cmp.start < 24);
  // Tokyo: Apple main + MET; English names
  const jp = await forecast(readQuery(new URLSearchParams('lat=35.69&lon=139.7&region=jp&tz=Asia/Tokyo&plan=free&lang=en')), wkEnv(pem), null, { now: kst, fetcher: krFetch });
  assert.deepEqual(jp.cmp.sources.map((s) => s.name), ['Apple Weather', 'MET Norway']);
  // MET only: no comparison
  const only = await forecast(readQuery(new URLSearchParams('lat=35.69&lon=139.7&region=jp&tz=Asia/Tokyo&plan=free')), {}, null, { now: kst, fetcher: krFetch });
  assert.equal(only.cmp, undefined);
});

test('warning kinds from Apple / JMA / NWS alert names (icons and notes), KMA names unchanged', () => {
  assert.equal(warningKind('호우경보'), 'rain'); assert.equal(warningKind('대설주의보'), 'snow'); assert.equal(warningKind('태풍경보'), 'typhoon');
  assert.equal(warningKind('Flash Flood Warning'), 'rain'); assert.equal(warningKind('Winter Storm Warning'), 'snow'); assert.equal(warningKind('High Wind Advisory'), 'wind');
  assert.equal(warningKind('Excessive Heat Warning'), 'heat'); assert.equal(warningKind('Freeze Warning'), 'cold'); assert.equal(warningKind('大雨警報'), 'rain'); assert.equal(warningKind('Tsunami Warning'), 'other');
  assert.equal(bubble({ warnings: [{ name: 'Winter Storm Warning', severity: 2 }], feels: 0 }, 'en').icon, 'snowflake');
  assert.equal(alertNote('Excessive Heat Warning', { total: 0, pr: 'none', hi: 38, lo: 27 }, 'en'), 'High 38°, wear a hat and sunscreen and drink water often');
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
  // its own icon (rain and snow together) in the hours and the days; an older app (no v=2) gets the snowflake
  assert.equal(s3.hours[0][1], 'sleet'); assert.equal(s3.days[0][1], 'sleet');
  const old = legacyIcons(JSON.parse(JSON.stringify(s3)));
  assert.equal(old.hours[0][1], 'snowflake'); assert.equal(old.days[0][1], 'snowflake'); assert.equal(old.precip, 'sleet');
  assert.equal(readQuery(new URLSearchParams('lat=37.5&lon=127')).v, 1);
  assert.equal(readQuery(new URLSearchParams('lat=37.5&lon=127&v=2')).v, 2);
});

test('sleet on the way: "진눈깨비 예보" with the sleet icon, not snow', () => {
  const base = { warnings: [], nowWet: false, nowPr: 'none', thunder: false, startIn: 2, when: '15~17시', wind: false, fog: 0, feels: 2, night: false, swing: 4, maxPop: 80, rain: 'bag' };
  assert.deepEqual(bubble({ ...base, next: 'sleet' }), { kind: 'speech', tone: 'sky', icon: 'sleet', text: '15~17시 진눈깨비 예보' });
  assert.deepEqual(bubble({ ...base, next: 'snow' }), { kind: 'speech', tone: 'sky', icon: 'snowflake', text: '15~17시 눈 예보' });
  assert.deepEqual(bubble({ ...base, next: 'rain' }), { kind: 'speech', tone: 'sky', icon: 'umbrella_closed', text: '15~17시 비 예보' });
  assert.match(bubble({ ...base, next: 'sleet' }, 'en').text, /^Sleet /);
});

test('KMA extended days: PCP · SNO · WSD codes become amounts (글피 from a 05 h run)', () => {
  const items = [];
  const add = (date, time, cat, v) => items.push({ baseDate: '20261021', baseTime: '0500', fcstDate: date, fcstTime: time, category: cat, fcstValue: v });
  add('20261022', '1200', 'TMP', '18'); add('20261022', '1200', 'PCP', '2.5'); add('20261022', '1200', 'WSD', '2'); add('20261022', '1200', 'PTY', '1');
  add('20261024', '1200', 'TMP', '15'); add('20261024', '1200', 'PCP', '2'); add('20261024', '1200', 'WSD', '3'); add('20261024', '1200', 'PTY', '1');
  add('20261024', '1500', 'TMP', '14'); add('20261024', '1500', 'SNO', '2'); add('20261024', '1500', 'PTY', '3'); add('20261024', '1500', 'WSD', '1');
  const f = parseForecast({ response: { header: { resultCode: '00' }, body: { items: { item: items } } } }, 'kma');
  const p = Object.fromEntries(f.points.map((x) => [`${x.t.getUTCDate()}-${x.t.getUTCHours()}`, x]));
  assert.equal(p['22-3'].wind, 2);                      // +1 day: real numbers stay
  assert.equal(p['24-3'].wind, 10); assert.equal(p['24-3'].mm, 8);   // +3 day: code 3 → 10 m/s, 보통 비 → 8 mm
  assert.equal(p['24-6'].wind, 2); assert.equal(p['24-6'].mm, 2);    // 많은 눈 → 2 cm
});
