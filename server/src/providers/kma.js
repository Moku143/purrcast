// 기상청 (KMA) via 공공데이터포털 — 단기예보 · 초단기예보 · 초단기실황 · 기상특보.
// Needs a service key (data.go.kr, free): put the *decoding* key in the KMA_SERVICE_KEY secret.
// Licence: 공공누리 제1유형 (출처표시).

import { instant, local, pad2 } from '../time.js';

const BASE = 'https://apis.data.go.kr/1360000';
const TZ = 'Asia/Seoul';

/** WGS84 → KMA 5 km grid (Lambert conformal conic, the formula from the API guide). */
export function toGrid(lat, lon) {
  const RE = 6371.00877, GRID = 5.0, SLAT1 = 30.0, SLAT2 = 60.0, OLON = 126.0, OLAT = 38.0, XO = 43, YO = 136;
  const D = Math.PI / 180, re = RE / GRID;
  const s1 = SLAT1 * D, s2 = SLAT2 * D, olon = OLON * D, olat = OLAT * D;
  let sn = Math.tan(Math.PI * 0.25 + s2 * 0.5) / Math.tan(Math.PI * 0.25 + s1 * 0.5);
  sn = Math.log(Math.cos(s1) / Math.cos(s2)) / Math.log(sn);
  let sf = Math.tan(Math.PI * 0.25 + s1 * 0.5);
  sf = Math.pow(sf, sn) * Math.cos(s1) / sn;
  let ro = Math.tan(Math.PI * 0.25 + olat * 0.5);
  ro = re * sf / Math.pow(ro, sn);
  let ra = Math.tan(Math.PI * 0.25 + lat * D * 0.5);
  ra = re * sf / Math.pow(ra, sn);
  let th = lon * D - olon;
  if (th > Math.PI) th -= 2 * Math.PI;
  if (th < -Math.PI) th += 2 * Math.PI;
  th *= sn;
  return { nx: Math.floor(ra * Math.sin(th) + XO + 0.5), ny: Math.floor(ro - ra * Math.cos(th) + YO + 0.5) };
}

const ymd = (p) => `${p.y}${pad2(p.m)}${pad2(p.d)}`;
const back = (date, minutes) => new Date(date.getTime() - minutes * 60000);

/** Latest 단기예보 base (02, 05, … 23 h; published ~10 min after). `fixed` = force a base hour today (free plan: 5). */
export function vilageBase(now, fixed = null) {
  const p = local(now, TZ);
  if (fixed != null) {
    if (p.h * 60 + p.mi >= fixed * 60 + 15) return { date: ymd(p), time: `${pad2(fixed)}00`, at: instant(p.y, p.m, p.d, fixed, 0, TZ) };
    const y = local(back(now, 24 * 60), TZ);   // before today's run is out: yesterday 23 h
    return { date: ymd(y), time: '2300', at: instant(y.y, y.m, y.d, 23, 0, TZ) };
  }
  const t = back(now, 15);
  const q = local(t, TZ);
  const hours = [2, 5, 8, 11, 14, 17, 20, 23].filter((h) => h <= q.h);
  if (hours.length) { const h = hours[hours.length - 1]; return { date: ymd(q), time: `${pad2(h)}00`, at: instant(q.y, q.m, q.d, h, 0, TZ) }; }
  const y = local(back(now, 24 * 60), TZ);
  return { date: ymd(y), time: '2300', at: instant(y.y, y.m, y.d, 23, 0, TZ) };
}

/** 초단기예보 base: HH30, published ~HH45. */
export function ultraBase(now) {
  const t = back(now, 45);
  const p = local(t, TZ);
  return { date: ymd(p), time: `${pad2(p.h)}30`, at: instant(p.y, p.m, p.d, p.h, 30, TZ) };
}

/** 초단기실황 base: HH00, published ~HH40. */
export function ncstBase(now) {
  const t = back(now, 40);
  const p = local(t, TZ);
  return { date: ymd(p), time: `${pad2(p.h)}00`, at: instant(p.y, p.m, p.d, p.h, 0, TZ) };
}

export function kmaUrl(op, key, params) {
  const svc = op === 'getPwnStatus' ? 'WthrWrnInfoService' : 'VilageFcstInfoService_2.0';
  // 단기예보 runs out to 5 days (since 2024-11): ~12 categories × ~110 hours, so ask for plenty
  const q = new URLSearchParams({ pageNo: '1', numOfRows: op === 'getVilageFcst' ? '2000' : '200', dataType: 'JSON', ...params });
  return `${BASE}/${svc}/${op}?serviceKey=${encodeURIComponent(key)}&${q}`;
}

/** A KMA number, or null for missing values (the guide marks |v| ≥ 900, e.g. −999, as missing). */
export function num(v) {
  const n = typeof v === 'number' ? v : parseFloat(v);
  return Number.isFinite(n) && Math.abs(n) < 900 ? n : null;
}

/** "강수없음" / "1mm 미만" / "1.0mm" / "30.0~50.0mm" / "50.0mm 이상" / day-5 words "약한 비" → mm; "적설없음" / "1cm 미만" → cm */
export function amount(v) {
  if (v == null) return 0;
  if (typeof v === 'number') return Math.abs(v) >= 900 ? 0 : v;
  const s = String(v).trim();
  if (!s || /없음/.test(s) || s === '-' || s === '0') return 0;
  if (/미만/.test(s)) return 0.5;
  if (/강한/.test(s)) return 20;      // KMA bands: 약한 < 3, 보통 3–15, 강한 ≥ 15 mm/h
  if (/보통/.test(s)) return 8;
  if (/약한/.test(s)) return 1;
  const r = s.match(/([\d.]+)\s*~\s*([\d.]+)/);
  if (r) return (parseFloat(r[1]) + parseFloat(r[2])) / 2;
  const n = parseFloat(s);
  return Number.isFinite(n) ? n : 0;
}

const SKY_CLOUD = { 1: 10, 3: 60, 4: 90 };
const ptyType = (v) => ({ 0: 'none', 1: 'rain', 2: 'sleet', 3: 'snow', 4: 'rain', 5: 'rain', 6: 'sleet', 7: 'snow' })[+v] ?? 'none';

export function items(json) {
  const h = json?.response?.header;
  if (h && h.resultCode && h.resultCode !== '00') throw new Error(`KMA ${h.resultCode} ${h.resultMsg}`);
  const it = json?.response?.body?.items?.item;
  return Array.isArray(it) ? it : it ? [it] : [];
}

/** Is this a usable KMA answer (only those get cached)? */
export function kmaOK(json) {
  return json?.response?.header?.resultCode === '00' && items(json).length > 0;
}

/** data.go.kr gateway errors come back as XML even with dataType=JSON (key not registered, quota, expired). */
export function kmaXmlError(text) {
  const pick = (tag) => (text.match(new RegExp(`<${tag}>([^<]*)</${tag}>`)) || [])[1];
  const code = pick('returnReasonCode') || pick('resultCode') || '?';
  const msg = pick('returnAuthMsg') || pick('errMsg') || pick('resultMsg') || 'XML error';
  return new Error(`KMA gateway ${code} ${msg}`);
}

// Fields that describe the *preceding* hour in KMA's forecasts ("19시 날씨 = 18~19시"): rain amount, rain type,
// sky, chance, lightning. Our points cover [t, t + 1 h), so these move to the point an hour earlier.
const PERIOD_FIELDS = ['PCP', 'RN1', 'SNO', 'PTY', 'SKY', 'POP', 'LGT'];
/** 'YYYYMMDD' + n days, as 'YYYYMMDD' */
function dayOffset(ymd8, n) {
  const d = new Date(Date.UTC(+ymd8.slice(0, 4), +ymd8.slice(4, 6) - 1, +ymd8.slice(6, 8) + n));
  return `${d.getUTCFullYear()}${pad2(d.getUTCMonth() + 1)}${pad2(d.getUTCDate())}`;
}

/** 단기예보 / 초단기예보 items → hourly points (+ daily min / max from TMN / TMX). */
export function parseForecast(json, source) {
  const by = new Map();
  const daily = {};
  for (const it of items(json)) {
    const k = `${it.fcstDate}${it.fcstTime}`;
    if (!by.has(k)) by.set(k, { date: it.fcstDate, time: it.fcstTime });
    by.get(k)[it.category] = it.fcstValue;
    if (it.category === 'TMN' || it.category === 'TMX') {
      const v = num(it.fcstValue);
      if (v != null) { daily[it.fcstDate] = daily[it.fcstDate] || {}; daily[it.fcstDate][it.category === 'TMN' ? 'lo' : 'hi'] = v; }
    }
  }
  // the extended days (글피 from the 02–14 h runs, 그글피 from 17–23 h; guide 2610) carry PCP · SNO · WSD as
  // qualitative codes, not amounts: 1 약한 비 (< 3 mm) · 2 보통 비 (3–15) · 3 강한 비 (15+); 눈 1 보통 (< 1 cm) · 2 많은 눈;
  // 바람 1 약한 (< 4 m/s) · 2 약간 강한 (4–9) · 3 강한 (9+)
  const first = items(json)[0];
  const baseDate = first?.baseDate, baseHour = first?.baseTime ? +String(first.baseTime).slice(0, 2) : 0;
  const codedFrom = baseDate ? dayOffset(baseDate, baseHour >= 17 ? 4 : 3) : null;
  const CODE = { PCP: { 1: '1', 2: '8', 3: '20' }, SNO: { 1: '0.5', 2: '2' }, WSD: { 1: '2', 2: '6', 3: '10' } };
  const rows = [...by.values()].sort((a, b) => (a.date + a.time).localeCompare(b.date + b.time)).map((r) => {
    if (codedFrom && r.date >= codedFrom) for (const k of ['PCP', 'SNO', 'WSD']) if (r[k] != null && CODE[k][String(r[k]).trim()]) r[k] = CODE[k][String(r[k]).trim()];
    return { ...r, t: instant(+r.date.slice(0, 4), +r.date.slice(4, 6), +r.date.slice(6, 8), +r.time.slice(0, 2), +r.time.slice(2, 4), TZ) };
  });
  const at = new Map(rows.map((r) => [r.t.getTime(), r]));
  const points = rows.map((r) => {
    // weather of [t, t+1h) is reported at t+1h; temperature / wind / humidity are the values at t
    const w = at.get(r.t.getTime() + 3600000) || r;
    const pick = (k) => (PERIOD_FIELDS.includes(k) ? w[k] : r[k]);
    const temp = num(r.TMP ?? r.T1H);
    const type = ptyType(pick('PTY') ?? 0);
    const rainMm = amount(pick('PCP') ?? pick('RN1'));
    const snowCm = amount(pick('SNO'));
    return {
      t: r.t, step: 1, source,
      temp,
      rh: num(r.REH),
      dew: null,
      wind: num(r.WSD),
      gust: null,
      dir: num(r.VEC),
      cloud: pick('SKY') == null ? null : SKY_CLOUD[+pick('SKY')] ?? null,
      fog: false,
      uvClear: null,
      mm: Math.round((type === 'snow' && snowCm > 0 ? snowCm : rainMm) * 10) / 10,
      pop: num(pick('POP')),
      type: type !== 'none' || rainMm > 0 ? (type === 'none' ? 'rain' : type) : 'none',
      thunder: num(pick('LGT')) > 0,
      symbol: '',
    };
  }).filter((p) => p.temp != null);
  return { points, daily, total: json?.response?.body?.totalCount ?? null, got: items(json).length };
}

/** 초단기실황 → the observation now. */
export function parseNow(json) {
  const o = {};
  let base = null;
  for (const it of items(json)) { o[it.category] = it.obsrValue; base = base || `${it.baseDate}${it.baseTime}`; }
  if (num(o.T1H) == null) return null;           // a missing observation must never become −999°
  const type = ptyType(o.PTY ?? 0);
  return {
    t: base ? instant(+base.slice(0, 4), +base.slice(4, 6), +base.slice(6, 8), +base.slice(8, 10), 0, TZ) : null,
    temp: num(o.T1H), rh: num(o.REH), wind: num(o.WSD), dir: num(o.VEC),
    mm: amount(o.RN1), type: type === 'none' && amount(o.RN1) > 0 ? 'rain' : type,
  };
}

// 기상특보 from getPwnStatus: `t6` lists the warnings in force, one per line:
//   "o 호우경보 : 서울, 인천, 경기도(가평, 양평), 강원도(강원북부산지)"   ·   "o 없 음" when there are none.
// A warning applies when the place's province is listed — and, when the province comes with a list of its
// own areas in brackets, when the place's city / county is in that list (sub-zones like "서울동남권" count for
// the whole city). Sea zones (앞바다, 먼바다) never apply to a land place. When the text cannot be read nothing
// is shown, which is the safe failure. (A stricter version would map coordinates to 특보구역 codes and use getPwnCd.)
const PROVINCE = {
  서울: ['서울'], 부산: ['부산'], 대구: ['대구'], 인천: ['인천'], 광주: ['광주광역시', '광주'], 대전: ['대전'], 울산: ['울산'], 세종: ['세종'],
  경기: ['경기'], 강원: ['강원'], 충북: ['충청북도', '충북'], 충남: ['충청남도', '충남'], 전북: ['전라북도', '전북'],
  전남: ['전라남도', '전남'], 경북: ['경상북도', '경북'], 경남: ['경상남도', '경남'], 제주: ['제주'],
};
const SEVERITY = (name) => (/경보/.test(name) ? 2 : /주의보/.test(name) ? 1 : 0);
const bare = (w) => w.replace(/(특별자치시|특별자치도|특별시|광역시|시|군|구)$/, '');

/** "서울, 경기도(가평, 양평), 강원도(강원북부산지)" → [{ name: '서울', sub: [] }, { name: '경기도', sub: ['가평', '양평'] }, …] */
export function splitAreas(text) {
  const out = []; let depth = 0, cur = '';
  for (const ch of text + ',') {
    if (ch === '(') depth++;
    if (ch === ')') depth--;
    if (ch === ',' && depth === 0) {
      const m = cur.trim().match(/^([^()]+?)\s*(?:\((.*)\))?$/);
      if (m) out.push({ name: m[1].trim(), sub: m[2] ? m[2].split(/[,·]/).map((x) => x.trim()).filter(Boolean) : [] });
      cur = '';
    } else cur += ch;
  }
  return out;
}

export function parseWarnings(json, placeName) {
  const words = String(placeName || '').trim().split(/\s+/);
  const first = words[0] || '', second = words[1] || '';
  const key = Object.keys(PROVINCE).find((k) => first.startsWith(k));
  if (!key) return [];
  const names = PROVINCE[key];
  const city = bare(second);
  const text = items(json).map((it) => it.t6 || '').join('\n');
  const out = [];
  for (const line of text.split(/\n|(?=o\s)/)) {
    const m = line.match(/([가-힣]+(?:주의보|경보))\s*:\s*(.+)/);
    if (!m || /해제/.test(line)) continue;
    const hit = splitAreas(m[2]).some((a) => {
      if (/앞바다|먼바다|해상|연안/.test(a.name)) return false;
      if (!names.some((n) => a.name.startsWith(n))) return false;
      if (key === '광주' && a.name.startsWith('광주') === false) return false;
      if (!a.sub.length) return true;
      // bracketed areas: city / county names, or sub-zones of the city itself ("서울동남권")
      if (a.sub.some((x) => /권$/.test(x) || x.startsWith(key))) return true;
      return !!city && a.sub.some((x) => bare(x) === city || x.includes(city));
    });
    if (hit) out.push({ name: m[1], severity: SEVERITY(m[1]) });
  }
  out.sort((a, b) => b.severity - a.severity);
  return out.filter((w, i) => out.findIndex((x) => x.name === w.name) === i);
}
