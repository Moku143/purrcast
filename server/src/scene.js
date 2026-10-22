// Normalized forecast → the app's WeatherScene JSON (docs/server-api.md).

import { local, hhmm, hhmm0, dayKey, sunDay, isNight, pad2, offsetMinutes } from './time.js';
import { feelsLike, dewPoint, uvUnderCloud, humidityWord } from './physics.js';
import * as R from './rules.js';

const r1 = (v) => Math.round(v * 10) / 10;
const ri = (v) => (v == null || Number.isNaN(v) ? 0 : Math.round(v));

/**
 * @param {object} f  normalized forecast:
 *   points   hourly points (sorted, may start before now), see providers
 *   now      optional observation { temp, rh, wind, dir, mm, type }
 *   daily    optional { 'YYYYMMDD': { lo, hi } } (KMA TMN / TMX)
 *   warnings optional [{ name, severity }]
 *   next6    optional [{ t, mm }] (KMA 초단기예보, Plus)
 *   nextSource 'kma' | 'met'
 *   updated  Date of the forecast run used
 * @param {object} o  { lat, lon, tz, plan: 'free'|'plus', prev, yday, now: Date }
 */
export function buildScene(f, o) {
  const { lat, lon, tz } = o;
  const offsetMin = (t) => offsetMinutes(t, tz);
  const nowT = o.now ?? new Date();
  const plus = o.plan === 'plus';
  const pts = (f.points || []).filter((p) => p.temp != null);
  if (!pts.length) throw new Error('no forecast points');

  // the point covering now (last point that starts at or before now), then the following hours
  let ci = 0;
  for (let i = 0; i < pts.length; i++) if (pts[i].t <= nowT) ci = i;
  const cur = { ...pts[ci] };
  if (f.now) {   // an observation beats the forecast for "now" (Plus, KMA 실황)
    for (const k of ['temp', 'rh', 'wind', 'dir']) if (f.now[k] != null) cur[k] = f.now[k];
    if (f.now.mm != null) { cur.mm = f.now.mm; cur.type = f.now.type ?? cur.type; }
  }
  const ahead = pts.slice(ci + 1).filter((p) => p.t - nowT < 13 * 3600000);
  const next12 = [cur, ...ahead].slice(0, 13);

  const night = isNight(nowT, lat, lon, tz);
  const feelsRaw = feelsLike(cur.temp, cur.rh, cur.wind);
  const feels = Math.round(feelsRaw);
  const lv = R.level(feelsRaw, o.prev ?? null);

  // rain timing
  const wet = (p) => p.mm >= 0.1 || p.type !== 'none';
  const nowWet = wet(cur);
  const startIdx = ahead.findIndex((p) => wet(p) || (p.pop ?? 0) >= 60);
  const startIn = nowWet ? 0 : startIdx < 0 ? null : Math.max(1, Math.round((ahead[startIdx].t - nowT) / 3600000));
  const startP = startIdx < 0 ? null : ahead[startIdx];
  let endP = startP;
  if (startIdx >= 0) for (let i = startIdx + 1; i < ahead.length && (wet(ahead[i]) || (ahead[i].pop ?? 0) >= 60); i++) endP = ahead[i];
  const H = (p) => local(p.t, tz).h;
  const window2h = startP ? (endP === startP ? `${H(startP)}시쯤` : `${H(startP)}~${H(endP)}시`) : '';
  const tomorrow = startP ? dayKey(startP.t, tz) !== dayKey(nowT, tz) : false;
  const evening = startP ? R.partOfDay(H(startP), tomorrow) : '';
  const maxPop = Math.max(0, ...next12.map((p) => p.pop ?? (wet(p) ? 70 : 0)));
  const rain = R.rainState({ nowWet, startIn, maxPop });
  const snowNext = startP ? startP.type === 'snow' || startP.type === 'sleet' : false;

  // sky layers
  const pr = R.precip(cur);
  const cov = R.cover(cur.cloud);
  const thunder = !!cur.thunder;
  const auxKind = R.aux({ now: cur, feels, night });

  // days (up to 10), from all points; KMA daily min / max override
  const days = [];
  const byDay = new Map();
  for (const p of pts) {
    const k = dayKey(p.t, tz);
    if (k < dayKey(nowT, tz)) continue;
    if (!byDay.has(k)) byDay.set(k, []);
    byDay.get(k).push(p);
  }
  for (const [k, list] of [...byDay.entries()].slice(0, 10)) {
    const temps = list.map((p) => p.temp);
    let lo = Math.min(...temps), hi = Math.max(...temps);
    if (f.daily?.[k]?.lo != null) lo = f.daily[k].lo;
    if (f.daily?.[k]?.hi != null) hi = f.daily[k].hi;
    const chance = Math.max(0, ...list.map((p) => p.pop ?? 0));
    const dayPts = list.filter((p) => { const h = local(p.t, tz).h; return h >= 6 && h <= 20; });
    let ic = 'sun';
    for (const p of (dayPts.length ? dayPts : list)) ic = R.worse(ic, R.icon({ ...p, mm: p.mm >= 0.1 ? p.mm : 0, type: p.mm >= 0.1 ? p.type : 'none' }, false));
    if (ic === 'sun' && chance >= 60) ic = 'raincloud';
    const name = days.length === 0 ? '오늘' : local(list[0].t, tz).wd;
    days.push([name, ic, ri(chance), ri(Math.min(lo, hi)), ri(Math.max(lo, hi))]);
  }
  const today = days[0] || ['오늘', 'sun', 0, ri(cur.temp), ri(cur.temp)];
  const hi = Math.max(today[4], ri(cur.temp)), lo = Math.min(today[3], ri(cur.temp));

  // hourly rows: 지금 + 12 hours
  const hours = next12.map((p, i) => [
    i === 0 ? '지금' : `${H(p)}시`,
    R.icon(p, isNight(p.t, lat, lon, tz)),
    ri(i === 0 ? cur.temp : p.temp),
    ri(p.pop ?? (wet(p) ? 70 : 0)),
    r1(p.mm || 0),
  ]);

  // tiles
  const total = r1(next12.reduce((s, p) => s + (p.mm || 0), 0));
  const rainNote = nowWet ? `지금 ${pr === 'snow' ? '눈' : '비'} · 12시간 ${total}${pr === 'snow' ? 'cm' : 'mm'}`
    : startP ? `${window2h} 비 시작 · ${total}mm` : '12시간 동안 비 소식 없음';
  const todayPts = pts.filter((p) => dayKey(p.t, tz) === dayKey(nowT, tz));
  const uvs = (todayPts.length ? todayPts : next12).map((p) => uvUnderCloud(p.uvClear, p.cloud)).filter((v) => v != null);
  const uv = uvs.length ? Math.round(Math.max(...uvs)) : null;
  const sunToday = sunDay(nowT, lat, lon, tz);
  const sunTomorrow = sunDay(new Date(nowT.getTime() + 86400000), lat, lon, tz);
  let sunTile;
  if (sunToday.polar) {
    sunTile = { icon: 'sunset', label: sunToday.polar === 'day' ? '백야' : '극야', value: '–', unit: '', note: '해가 지지 않아요' };
  } else if (!night) {
    sunTile = { icon: 'sunset', label: '일몰', value: hhmm0(sunToday.set, tz), unit: '', note: `내일 일출 ${hhmm0(sunTomorrow.rise ?? sunToday.rise, tz)}` };
  } else {
    const nextRise = nowT < sunToday.rise ? sunToday.rise : sunTomorrow.rise;
    sunTile = { icon: 'sunrise', label: '일출', value: hhmm0(nextRise, tz), unit: '', note: `일몰 ${hhmm0(sunToday.set, tz)}` };
  }
  const dew = cur.dew ?? dewPoint(cur.temp, cur.rh);
  const tiles = [
    { icon: 'raindrop', label: '강수확률', value: `${ri(maxPop)}%`, unit: '', note: rainNote },
    { kind: 'uv', icon: 'sun_strong', label: '자외선', uv: uv ?? 0, note: R.uvNote(uv) },
    sunTile,
    { icon: 'raindrop', label: '습도', value: cur.rh == null ? '–' : `${ri(cur.rh)}%`, unit: '', note: [humidityWord({ temp: cur.temp, rh: cur.rh, dew, wet: nowWet }), dew == null ? '' : `이슬점 ${ri(dew)}°`].filter(Boolean).join(' · ') },
  ];

  const bub = R.bubble({
    warnings: f.warnings, nowWet, nowPr: pr, nowMm: cur.mm, thunder, startIn, startLabel: window2h, window2h, evening,
    wind: auxKind === 'wind', fog: auxKind === 'fog', feels, night, swing: hi - lo, maxPop, plus, rain, snowNext,
  });

  const scene = {
    time: night ? 'night' : 'day',
    cover: cov,
    precip: pr,
    thunder: thunder ? 'on' : 'off',
    aux: auxKind,
    level: lv,
    rain,
    temp: ri(cur.temp),
    feels,
    hi, lo,
    yday: o.yday == null ? 0 : ri(cur.temp - o.yday),
    cond: R.condition({ pr, cov, thunder, auxKind, night, feels }),
    clock: hhmm(nowT, tz),
    updated: plus ? hhmm0(f.updated ?? nowT, tz) : '06:00',
    bubble: bub,
    mood: feels <= -10 ? 'cold' : 'normal',
    snow: pr === 'snow',
    hours,
    days: days.length ? days : [today],
    tiles,
    wind: { speed: ri(cur.wind), gust: ri(cur.gust ?? (cur.wind ?? 0) * 1.5), deg: ri(cur.dir) },
    plus,
  };
  // day sheet: 8 three-hourly values per day (0, 3, … 21 h) — temp, rain chance, wind, UV, humidity
  scene.dayDetail = [...byDay.entries()].slice(0, days.length).map(([, list]) => {
    const [y, m, d] = [list[0].t, list[0].t, list[0].t].map((t, i) => [local(t, tz).y, local(t, tz).m, local(t, tz).d][i]);
    return [0, 3, 6, 9, 12, 15, 18, 21].map((h) => {
      const target = Date.UTC(y, m - 1, d, h) - offsetMin(list[0].t) * 60000;
      let best = list[0], bd = Infinity;
      for (const p of list) { const x = Math.abs(p.t - target); if (x < bd) { bd = x; best = p; } }
      const uvv = uvUnderCloud(best.uvClear, best.cloud);
      return [`${h}시`, r1(best.temp), ri(best.pop ?? (wet(best) ? 70 : 0)), r1(best.wind ?? 0), r1(h >= 6 && h <= 18 ? uvv ?? 0 : 0), ri(best.rh ?? 0)];
    });
  });
  if (plus && f.next6?.length) {
    scene.next6 = f.next6.slice(0, 6).map((p) => [`${H(p)}시`, r1(p.mm || 0)]);
    scene.nextSource = f.nextSource || 'kma';
  }
  return scene;
}

/** Throws with a list of problems when a scene does not match what the app decodes (docs/server-api.md). */
export function validateScene(s) {
  const bad = [];
  const str = (k, opts) => { if (typeof s[k] !== 'string') bad.push(`${k} not a string`); else if (opts && !opts.includes(s[k])) bad.push(`${k}=${s[k]}`); };
  const int = (k) => { if (!Number.isInteger(s[k])) bad.push(`${k} not an integer`); };
  str('time', ['day', 'night']); str('cover', ['clear', 'partly', 'overcast']); str('precip', ['none', 'rain', 'heavy', 'snow']);
  str('thunder', ['on', 'off']); str('aux', ['none', 'wind', 'fog', 'heat', 'frost', 'dust']); str('rain', ['none', 'think', 'bag', 'umbrella']);
  for (const k of ['level', 'temp', 'feels', 'hi', 'lo', 'yday']) int(k);
  if (!(s.level >= 0 && s.level <= 9)) bad.push('level out of 0…9');
  for (const k of ['cond', 'clock', 'updated']) str(k);
  if (s.bubble != null) for (const k of ['kind', 'tone', 'icon', 'text']) if (typeof s.bubble[k] !== 'string') bad.push(`bubble.${k}`);
  if (!Array.isArray(s.hours) || s.hours.length < 1) bad.push('hours empty');
  else s.hours.forEach((h, i) => { if (!(h.length === 5 && typeof h[0] === 'string' && typeof h[1] === 'string' && h.slice(2).every(Number.isFinite))) bad.push(`hours[${i}]`); });
  if (!Array.isArray(s.days) || s.days.length < 1) bad.push('days empty');
  else s.days.forEach((d, i) => { if (!(d.length === 5 && typeof d[0] === 'string' && typeof d[1] === 'string' && d.slice(2).every(Number.isFinite))) bad.push(`days[${i}]`); });
  if (!Array.isArray(s.tiles)) bad.push('tiles');
  else s.tiles.forEach((t, i) => { if (typeof t.icon !== 'string' || typeof t.label !== 'string' || typeof t.note !== 'string') bad.push(`tiles[${i}]`); });
  if (!s.wind || !['speed', 'gust', 'deg'].every((k) => Number.isFinite(s.wind[k]))) bad.push('wind');
  if (s.next6 != null && !(Array.isArray(s.next6) && s.next6.every((n) => n.length === 2 && typeof n[0] === 'string' && Number.isFinite(n[1])))) bad.push('next6');
  if (s.minutes != null && !(Array.isArray(s.minutes) && s.minutes.every(Number.isFinite))) bad.push('minutes');
  if (s.dayDetail != null && !(Array.isArray(s.dayDetail) && s.dayDetail.every((d) => Array.isArray(d) && d.every((h) => h.length === 6 && typeof h[0] === 'string' && h.slice(1).every(Number.isFinite))))) bad.push('dayDetail');
  if (bad.length) throw new Error('scene does not match the app: ' + bad.join(', '));
  return true;
}

export { pad2 };
