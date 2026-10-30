// 에어코리아 (한국환경공단) via 공공데이터포털 — 미세먼지 · 초미세먼지 for Korea.
//   측정소정보 getMsrstnList: every station with its WGS84 position (cached a day; the nearest one is picked here,
//     so no TM coordinate conversion is needed)
//   대기오염정보 getMsrstnAcctoRtmsDnstyInfo: the station's last 24 hourly readings (PM10 · PM2.5 ㎍/㎥)
//   대기오염정보 getMinuDustFrcstDspth: today's forecast bulletin — tomorrow's grade per region (PM10 · PM2.5)
//   미세먼지 경보 getUlfptcaAlarmInfo: 주의보 / 경보 in force per province
// Needs a data.go.kr service key (the same account key as 기상청): AIRKOREA_SERVICE_KEY. Licence: 공공누리 제1유형.

const BASE = 'https://apis.data.go.kr/B552584';

export function airkoreaUrl(svc, op, key, params) {
  const q = new URLSearchParams({ returnType: 'json', pageNo: '1', numOfRows: '100', ...params });
  return `${BASE}/${svc}/${op}?serviceKey=${encodeURIComponent(key)}&${q}`;
}
export const stationsUrl = (key) => airkoreaUrl('MsrstnInfoInqireSvc', 'getMsrstnList', key, { numOfRows: '1000', ver: '1.1' });   // 1.1: dmX / dmY in their right places
export const realtimeUrl = (key, station) => airkoreaUrl('ArpltnInforInqireSvc', 'getMsrstnAcctoRltmMesureDnsty', key, { stationName: station, dataTerm: 'DAILY', ver: '1.5', numOfRows: '30' });   // 1.5: with PM2.5
export const forecastUrl = (key, ymd, code) => airkoreaUrl('ArpltnInforInqireSvc', 'getMinuDustFrcstDspth', key, { searchDate: ymd, InformCode: code });
export const alarmUrl = (key, year) => airkoreaUrl('UlfptcaAlarmInqireSvc', 'getUlfptcaAlarmInfo', key, { year: String(year), numOfRows: '200' });

export const items = (json) => {
  const b = json?.response?.body?.items;
  return Array.isArray(b) ? b : Array.isArray(b?.item) ? b.item : [];
};
export const airkoreaOK = (json) => json?.response?.header?.resultCode === '00';

/** 환경부 grades, 0 좋음 · 1 보통 · 2 나쁨 · 3 매우 나쁨. */
export const gradePM10 = (v) => (v == null ? null : v <= 30 ? 0 : v <= 80 ? 1 : v <= 150 ? 2 : 3);
export const gradePM25 = (v) => (v == null ? null : v <= 15 ? 0 : v <= 35 ? 1 : v <= 75 ? 2 : 3);
const GRADE_WORD = { 좋음: 0, 보통: 1, 나쁨: 2, 매우나쁨: 3, '매우 나쁨': 3 };

const km = (a, b, c, d) => {
  const R = 6371, r = Math.PI / 180, x = (c - a) * r, y = (d - b) * r;
  const h = Math.sin(x / 2) ** 2 + Math.cos(a * r) * Math.cos(c * r) * Math.sin(y / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
};

/** The nearest station: { name, addr, km }. Stations without a position are skipped. */
export function nearestStation(json, lat, lon) {
  let best = null;
  for (const it of items(json)) {
    // dmX / dmY: the latitude and longitude, but which is which has differed between versions — told apart by range
    const a = parseFloat(it.dmX), b = parseFloat(it.dmY);
    if (!Number.isFinite(a) || !Number.isFinite(b)) continue;
    const y = a > 100 ? b : a, x = a > 100 ? a : b;
    const d = km(lat, lon, y, x);
    if (!best || d < best.km) best = { name: it.stationName, addr: it.addr || '', km: Math.round(d * 10) / 10 };
  }
  return best;
}

const num = (v) => { const n = parseFloat(v); return Number.isFinite(n) && n >= 0 ? n : null; };

/** The newest hour with a reading: { pm10, pm25, at: 'YYYY-MM-DD HH:mm' } (values may be null when a sensor is down). */
export function parseRealtime(json) {
  for (const it of items(json)) {
    const pm10 = num(it.pm10Value), pm25 = num(it.pm25Value);
    if (pm10 == null && pm25 == null) continue;
    return { pm10, pm25, at: it.dataTime || '' };
  }
  return null;
}

/** The last 24 readings, oldest first, for a trend: [{ at, pm10, pm25 }]. */
export function parseHistory(json) {
  return items(json).map((it) => ({ at: it.dataTime || '', pm10: num(it.pm10Value), pm25: num(it.pm25Value) })).reverse();
}

// 예보 regions as 에어코리아 names them in informGrade: "서울 : 보통,제주 : 좋음,전남 : 좋음,…"
const REGION = [
  ['서울', '서울'], ['인천', '인천'], ['부산', '부산'], ['대구', '대구'], ['광주', '광주'], ['대전', '대전'], ['울산', '울산'], ['세종', '세종'],
  ['제주', '제주'], ['충북', '충북'], ['충남', '충남'], ['전북', '전북'], ['전남', '전남'], ['경북', '경북'], ['경남', '경남'],
];
/** The forecast region for a station address ("서울 구로구 …", "경기 고양시 …"): 경기 and 강원 are split in the bulletin. */
export function forecastRegion(addr, lat, lon) {
  const a = String(addr || '').trim();
  for (const [k, r] of REGION) if (a.startsWith(k)) return r;
  if (a.startsWith('경기')) return lat >= 37.55 ? '경기북부' : '경기남부';
  if (a.startsWith('강원')) return lon >= 128.45 ? '영동' : '영서';
  return null;
}

/** Tomorrow's grade (0–3) for a region from the bulletin, or null. Picks the item whose informData is tomorrow. */
export function parseForecast(json, region, tomorrowYmd) {
  if (!region) return null;
  for (const it of items(json)) {
    if (it.informData !== tomorrowYmd) continue;
    const m = String(it.informGrade || '').split(',').map((s) => s.split(':').map((x) => x.trim()));
    const hit = m.find(([r]) => r === region) || m.find(([r]) => r && region.startsWith(r));
    if (hit && hit[1] in GRADE_WORD) return GRADE_WORD[hit[1]];
  }
  return null;
}

/** 주의보 / 경보 in force for a province ("서울", "경기", …): { kind: 'watch' | 'warning', item: 'PM10' | 'PM25' } or null.
 *  `now` is the Seoul-local 'YYYY-MM-DD HH:mm' to compare issue/clear times with. */
export function parseAlarms(json, province, nowKst) {
  let best = null;
  for (const it of items(json)) {
    if (!province || !String(it.districtName || '').startsWith(province)) continue;
    if (it.clearDate) continue;   // cleared
    const issued = `${it.issueDate || ''} ${it.issueTime || ''}`.trim();
    if (issued && nowKst && issued > nowKst) continue;
    const kind = /경보/.test(it.issueGbn || '') ? 'warning' : /주의보/.test(it.issueGbn || '') ? 'watch' : null;
    if (!kind) continue;
    const item = /25/.test(it.itemCode || '') ? 'PM25' : 'PM10';
    if (!best || (kind === 'warning' && best.kind !== 'warning')) best = { kind, item };
  }
  return best;
}
