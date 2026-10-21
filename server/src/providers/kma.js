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
  const q = new URLSearchParams({ pageNo: '1', numOfRows: op === 'getVilageFcst' ? '1200' : '200', dataType: 'JSON', ...params });
  return `${BASE}/${svc}/${op}?serviceKey=${encodeURIComponent(key)}&${q}`;
}

/** "강수없음" / "1mm 미만" / "1.0mm" / "30.0~50.0mm" / "50.0mm 이상" → mm; "적설없음" / "1cm 미만" → cm */
export function amount(v) {
  if (v == null) return 0;
  if (typeof v === 'number') return v;
  const s = String(v).trim();
  if (!s || /없음/.test(s) || s === '-' || s === '0') return 0;
  if (/미만/.test(s)) return 0.5;
  const r = s.match(/([\d.]+)\s*~\s*([\d.]+)/);
  if (r) return (parseFloat(r[1]) + parseFloat(r[2])) / 2;
  const n = parseFloat(s);
  return Number.isFinite(n) ? n : 0;
}

const SKY_CLOUD = { 1: 10, 3: 60, 4: 90 };
const ptyType = (v) => ({ 0: 'none', 1: 'rain', 2: 'sleet', 3: 'snow', 4: 'rain', 5: 'rain', 6: 'sleet', 7: 'snow' })[+v] ?? 'none';

function items(json) {
  const h = json?.response?.header;
  if (h && h.resultCode && h.resultCode !== '00') throw new Error(`KMA ${h.resultCode} ${h.resultMsg}`);
  const it = json?.response?.body?.items?.item;
  return Array.isArray(it) ? it : it ? [it] : [];
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
      daily[it.fcstDate] = daily[it.fcstDate] || {};
      daily[it.fcstDate][it.category === 'TMN' ? 'lo' : 'hi'] = parseFloat(it.fcstValue);
    }
  }
  const points = [...by.values()].sort((a, b) => (a.date + a.time).localeCompare(b.date + b.time)).map((r) => {
    const t = instant(+r.date.slice(0, 4), +r.date.slice(4, 6), +r.date.slice(6, 8), +r.time.slice(0, 2), +r.time.slice(2, 4), TZ);
    const temp = r.TMP ?? r.T1H;
    const type = ptyType(r.PTY ?? 0);
    const rainMm = amount(r.PCP ?? r.RN1);
    const snowCm = amount(r.SNO);
    return {
      t, step: 1, source,
      temp: temp == null ? null : parseFloat(temp),
      rh: r.REH == null ? null : parseFloat(r.REH),
      dew: null,
      wind: r.WSD == null ? null : parseFloat(r.WSD),
      gust: null,
      dir: r.VEC == null ? null : parseFloat(r.VEC),
      cloud: r.SKY == null ? null : SKY_CLOUD[+r.SKY] ?? null,
      fog: false,
      uvClear: null,
      mm: Math.round((type === 'snow' && snowCm > 0 ? snowCm : rainMm) * 10) / 10,
      pop: r.POP == null ? null : parseFloat(r.POP),
      type: type !== 'none' || rainMm > 0 ? (type === 'none' ? 'rain' : type) : 'none',
      thunder: r.LGT != null && parseFloat(r.LGT) > 0,
      symbol: '',
    };
  });
  return { points, daily };
}

/** 초단기실황 → the observation now. */
export function parseNow(json) {
  const o = {};
  let base = null;
  for (const it of items(json)) { o[it.category] = it.obsrValue; base = base || `${it.baseDate}${it.baseTime}`; }
  if (o.T1H == null) return null;
  const type = ptyType(o.PTY ?? 0);
  return {
    t: base ? instant(+base.slice(0, 4), +base.slice(4, 6), +base.slice(6, 8), +base.slice(8, 10), 0, TZ) : null,
    temp: parseFloat(o.T1H), rh: o.REH == null ? null : parseFloat(o.REH),
    wind: o.WSD == null ? null : parseFloat(o.WSD), dir: o.VEC == null ? null : parseFloat(o.VEC),
    mm: amount(o.RN1), type: type === 'none' && amount(o.RN1) > 0 ? 'rain' : type,
  };
}

// 기상특보: the national status text lists each warning with its areas ("o 호우경보 : 서울, 인천, 경기도(…)").
// We keep the warnings whose area list names the place's province / city. Experimental: when the text cannot be
// read nothing is shown, which is the safe failure.
const PROVINCE = {
  서울: ['서울'], 부산: ['부산'], 대구: ['대구'], 인천: ['인천'], 광주: ['광주'], 대전: ['대전'], 울산: ['울산'], 세종: ['세종'],
  경기: ['경기'], 강원: ['강원'], 충북: ['충청북도', '충북'], 충남: ['충청남도', '충남'], 전북: ['전라북도', '전북'],
  전남: ['전라남도', '전남'], 경북: ['경상북도', '경북'], 경남: ['경상남도', '경남'], 제주: ['제주'],
};
const SEVERITY = (name) => (/경보/.test(name) ? 2 : /주의보/.test(name) ? 1 : 0);

export function parseWarnings(json, placeName) {
  const first = String(placeName || '').trim().split(/\s+/)[0] || '';
  const key = Object.keys(PROVINCE).find((k) => first.startsWith(k)) || first;
  const words = PROVINCE[key] || (key ? [key] : []);
  const text = items(json).map((it) => Object.values(it).filter((v) => typeof v === 'string').join('\n')).join('\n');
  const out = [];
  for (const line of text.split(/\n|(?=o\s)/)) {
    const m = line.match(/([가-힣]+(?:주의보|경보))\s*:\s*(.+)/);
    if (!m) continue;
    if (/해제/.test(line)) continue;
    if (words.some((w) => m[2].includes(w))) out.push({ name: m[1], severity: SEVERITY(m[1]) });
  }
  out.sort((a, b) => b.severity - a.severity);
  return out.filter((w, i) => out.findIndex((x) => x.name === w.name) === i);
}
