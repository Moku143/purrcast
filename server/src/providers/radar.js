// 비 지도 (Plus, Korea): 기상청 API허브 radar pictures without a base map.
//   observed: nph-rdr_cmp1_imgp (HSR composite, every 10 min)
//   forecast: nph-qpf_ana_imgp (초단기 강수예측 MAPLE, +10 … +60 min from the newest observation)
// Both answer with JSON naming a picture on apihub.kma.go.kr; the picture covers the box below in KMA's LCC
// (standard parallels 30°/60°, origin 0°N 126°E, metres). The app warps it onto its map.
//
// The authKey stays here: the app asks /v1/radar/img?k=obs&tm=… and this server fetches and passes the picture on.

export const APIHUB = 'https://apihub.kma.go.kr';

/** The picture's extent, as 날씨누리's own map asks for it (top left, bottom right) */
export const RADAR_BOX = { x0: -384032.28285233676, y0: 4878817.500765007, x1: 758967.7171476632, y1: 3778150.834098339 };

/** What the app needs to place a picture: the projection and the box */
export const RADAR_PROJ = { kind: 'lcc', lat1: 30, lat2: 60, lat0: 0, lon0: 126, fe: 0, fn: 0, a: 6378137, f: 1 / 298.257222101, ...RADAR_BOX };

/** The picture size asked for (px): wide enough for the app's 440-px warp of Korea */
export const RADAR_SIZE = 640;

const pad = (n) => String(n).padStart(2, '0');

/** "YYYYMMDDHHMM" in KST for a Date */
export function kstStamp(d) {
  const k = new Date(d.getTime() + 9 * 3600000);
  return `${k.getUTCFullYear()}${pad(k.getUTCMonth() + 1)}${pad(k.getUTCDate())}${pad(k.getUTCHours())}${pad(k.getUTCMinutes())}`;
}

/** "YYYY-MM-DD HH:MM" from "YYYYMMDDHHMM" */
export function showStamp(tm) {
  return `${tm.slice(0, 4)}-${tm.slice(4, 6)}-${tm.slice(6, 8)} ${tm.slice(8, 10)}:${tm.slice(10, 12)}`;
}

/** The newest observation that should be out (the composite lands a few minutes after its time), on a 10-minute
 *  step, and the six before it: seven times, oldest first */
export function obsTimes(now, { lagMin = 8, count = 7 } = {}) {
  const t = now.getTime() - lagMin * 60000;
  const last = Math.floor(t / 600000) * 600000;
  return Array.from({ length: count }, (_, i) => kstStamp(new Date(last - (count - 1 - i) * 600000)));
}

/** "YYYYMMDDHHMM" + minutes */
export function addMinutes(tm, min) {
  const d = Date.UTC(+tm.slice(0, 4), +tm.slice(4, 6) - 1, +tm.slice(6, 8), +tm.slice(8, 10), +tm.slice(10, 12)) + min * 60000;
  const k = new Date(d);
  return `${k.getUTCFullYear()}${pad(k.getUTCMonth() + 1)}${pad(k.getUTCDate())}${pad(k.getUTCHours())}${pad(k.getUTCMinutes())}`;
}

function common(tm, size) {
  return {
    PROJ: 'LCC', grid: '2', itv: '10', tm_mode: 'm10', data0: 'RCM', level: 'C', map: 'R', dtm: 'm0',
    zoom_level: '0', zoom_rate: '2', zoom_x: '0000000', zoom_y: '0000000', auto_man: 'a', mode: 'H',
    winnum: '0', size: String(size), height: String(size), color: 'C4', effect: 'N', legend: '0',
    river: 'off', road: 'off', city: 'off', gis_auto: 'off', stnname: 'off', an_frn: '0',
    STARTX: String(RADAR_BOX.x0), STARTY: String(RADAR_BOX.y0), ENDX: String(RADAR_BOX.x1), ENDY: String(RADAR_BOX.y1), ZOOMLVL: '11',
    tm, tm_st: tm, tm_ed: tm, tm2: tm,
  };
}

/** The observed composite (HSR) at `tm` */
export function obsUrl(key, tm, size = RADAR_SIZE) {
  const q = new URLSearchParams({ ...common(tm, size), cmp: 'HSP', obs: 'ECHD', qcd: 'HSLP', dataDtlCd: 'rdr_hsr_0', data1: 'h01', data2: 'hsr', data3: '0', authKey: key });
  return `${APIHUB}/api/typ03/cgi/rdr/nph-rdr_cmp1_imgp?${q}`;
}

/** The 초단기 강수예측 (MAPLE) issued at `tm`, `ef` minutes ahead */
export function qpfUrl(key, tm, ef, size = RADAR_SIZE) {
  const q = new URLSearchParams({ ...common(tm, size), cmp: 'HSR', obs: 'qpf', qcd: 'EXT', qpf: 'M', ef: String(ef), eva: '1', option: '1', dataDtlCd: 'rdr_rdr_qpf_ana1_0', data1: 'r01', data2: 'rdr_qpf_ana1', data3: '0', authKey: key });
  return `${APIHUB}/api/typ03/cgi/rdr/nph-qpf_ana_imgp?${q}`;
}

/** The picture's address in the JSON answer: the first string that names an image (or a path under /), anywhere */
export function imagePath(data) {
  const seen = [];
  const walk = (v) => {
    if (typeof v === 'string') { seen.push(v); return; }
    if (Array.isArray(v)) { v.forEach(walk); return; }
    if (v && typeof v === 'object') Object.values(v).forEach(walk);
  };
  walk(data);
  const img = seen.find((s) => /\.(png|gif|jpe?g)(\?|$)/i.test(s)) || seen.find((s) => s.startsWith('/') && s.length > 4);
  if (!img) return null;
  return img.startsWith('http') ? img : APIHUB + (img.startsWith('/') ? '' : '/') + img;
}

/** The frames the app gets: the last hour observed and the next hour forecast, each a picture on this server */
export function radarFrames(now = new Date()) {
  const obs = obsTimes(now);
  const last = obs[obs.length - 1];
  const frames = obs.map((tm) => ({ t: showStamp(tm), fc: false, url: `/v1/radar/img?k=obs&tm=${tm}` }));
  for (const ef of [10, 20, 30, 40, 50, 60]) {
    frames.push({ t: showStamp(addMinutes(last, ef)), fc: true, url: `/v1/radar/img?k=qpf&tm=${last}&ef=${ef}` });
  }
  return { src: 'kma', at: showStamp(last), proj: RADAR_PROJ, frames, scale: [] };
}
