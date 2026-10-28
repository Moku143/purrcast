// Normalized forecast → the app's WeatherScene JSON (docs/server-api.md).

import { local, hhmm, hhmm0, dayKey, sunDay, isNight, pad2, offsetMinutes } from './time.js';
import { feelsLike, dewPoint, uvUnderCloud, humidityWord } from './physics.js';
import * as R from './rules.js';
import { strings } from './i18n.js';

const r1 = (v) => Math.round(v * 10) / 10;
const ri = (v) => (v == null || Number.isNaN(v) ? 0 : Math.round(v));

/**
 * @param {object} f  normalized forecast:
 *   points   hourly points (sorted, may start before now), see providers
 *   now      optional observation { temp, rh, wind, dir, mm, type }
 *   daily    optional { 'YYYYMMDD': { lo, hi } } (KMA TMN / TMX)
 *   warnings optional [{ name, severity }]
 *   precip none | rain | heavy | snow | heavysnow (3 cm/h+) | sleet (진눈깨비: rain and snow together)
 *   → scene.alert { name, note } when one is in force (the line under the character on the home screen)
 *   next6    optional [{ t, mm }] (KMA 초단기예보 / WeatherKit hourly, Plus)
 *   minutes  optional [mm/h per minute, up to 60] (WeatherKit forecastNextHour, Plus)
 *   nextSource 'kma' | 'met' | 'apple'
 *   src      'kma' | 'met' | 'apple' — the main forecast's source (nextSource when missing)
 *   updated  Date of the forecast run used
 *   freeAt   free, Apple: when this day's kept forecast was taken (the label; Korea's free label is 06:00)
 * @param {object} o  { lat, lon, tz, plan: 'free'|'plus', prev, yday, now: Date, lang: 'ko'|'en'|'ja' (ko) }
 */
export function buildScene(f, o) {
  const { lat, lon, tz } = o;
  const S = strings(o.lang);   // every word in the answer comes from here
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
  const tomorrow = startP ? dayKey(startP.t, tz) !== dayKey(nowT, tz) : false;
  const when = startP ? R.whenWord(H(startP), H(endP), tomorrow, S) : '';   // 15~17시 · 15시쯤 · 내일 7~9시
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
    const name = days.length === 0 ? S.today : S.weekday(local(list[0].t, tz).wdEn);
    days.push([name, ic, ri(chance), ri(Math.min(lo, hi)), ri(Math.max(lo, hi))]);
  }
  const today = days[0] || [S.today, 'sun', 0, ri(cur.temp), ri(cur.temp)];
  const hi = Math.max(today[4], ri(cur.temp)), lo = Math.min(today[3], ri(cur.temp));

  // hourly rows: 지금 + 12 hours
  const hours = next12.map((p, i) => [
    i === 0 ? S.now : S.hour(H(p)),
    R.icon(p, isNight(p.t, lat, lon, tz)),
    ri(i === 0 ? cur.temp : p.temp),
    ri(p.pop ?? (wet(p) ? 70 : 0)),
    r1(p.mm || 0),
  ]);

  // tiles
  const total = r1(next12.reduce((s, p) => s + (p.mm || 0), 0));
  const amt = pr === 'snow' || pr === 'heavysnow' ? `${total}cm` : `${total}mm (${R.rainAmountWord(total, S)})`;   // sleet is measured as water, like rain
  const rainNote = nowWet ? S.nowWetNote(pr === 'snow' || pr === 'heavysnow' ? S.what.snow : pr === 'sleet' ? S.what.sleet : S.what.rain, amt)
    : startP ? `${S.expect(when, snowNext ? S.what.snow : S.what.rain)} · ${amt}` : S.noRain12h;
  const todayPts = pts.filter((p) => dayKey(p.t, tz) === dayKey(nowT, tz));
  const uvs = (todayPts.length ? todayPts : next12).map((p) => uvUnderCloud(p.uvClear, p.cloud)).filter((v) => v != null);
  const uv = uvs.length ? Math.round(Math.max(...uvs)) : null;
  const sunToday = sunDay(nowT, lat, lon, tz);
  const sunTomorrow = sunDay(new Date(nowT.getTime() + 86400000), lat, lon, tz);
  let sunTile;
  if (sunToday.polar) {
    sunTile = { icon: 'sunset', label: sunToday.polar === 'day' ? S.tile.polarDay : S.tile.polarNight, value: '–', unit: '', note: S.polarNote[sunToday.polar] };
  } else if (!night) {
    sunTile = { icon: 'sunset', label: S.tile.sunset, value: hhmm0(sunToday.set, tz), unit: '', note: S.sunriseTomorrow(hhmm0(sunTomorrow.rise ?? sunToday.rise, tz)) };
  } else {
    const nextRise = nowT < sunToday.rise ? sunToday.rise : sunTomorrow.rise;
    sunTile = { icon: 'sunrise', label: S.tile.sunrise, value: hhmm0(nextRise, tz), unit: '', note: S.sunsetAt(hhmm0(sunToday.set, tz)) };
  }
  const dew = cur.dew ?? dewPoint(cur.temp, cur.rh);
  const tiles = [
    { icon: 'raindrop', label: S.tile.rainChance, value: `${ri(maxPop)}%`, unit: '', note: rainNote },
    { kind: 'uv', icon: 'sun_strong', label: S.tile.uv, uv: uv ?? 0, note: R.uvNote(uv, S) },
    sunTile,
    { icon: 'raindrop', label: S.tile.humidity, value: cur.rh == null ? '–' : `${ri(cur.rh)}%`, unit: '', note: [humidityWord({ temp: cur.temp, rh: cur.rh, dew, wet: nowWet }, S), dew == null ? '' : S.dewPoint(ri(dew))].filter(Boolean).join(' · ') },
  ];

  const bub = R.bubble({
    warnings: f.warnings, nowWet, nowPr: pr, nowMm: cur.mm, thunder, startIn, when,
    wind: auxKind === 'wind', fog: auxKind === 'fog' ? Math.max(2, R.fogLevel(cur)) : 0, feels, night, swing: hi - lo, maxPop, plus, rain, snowNext,
  }, S);

  const scene = {
    time: night ? 'night' : 'day',
    cover: cov,
    clouds: cur.cloud == null ? null : ri(cur.cloud),   // 0–100 %, how many clouds the sky draws
    fog: R.fogLevel(cur),                                // 0–3, how thick the fog is drawn
    precip: pr,
    thunder: thunder ? 'on' : 'off',
    aux: auxKind,
    level: lv,
    rain,
    temp: ri(cur.temp),
    feels,
    hi, lo,
    yday: o.yday == null ? 0 : ri(cur.temp - o.yday),
    cond: R.condition({ pr, cov, thunder, auxKind, night, feels }, S),
    clock: hhmm(nowT, tz),
    updated: plus ? hhmm0(f.updated ?? nowT, tz) : f.freeAt ? hhmm0(f.freeAt, tz) : '06:00',   // free: Korea's 06:00 forecast, or when Apple's day was taken
    bubble: bub,
    mood: feels <= -10 ? 'cold' : 'normal',
    snow: pr === 'snow' || pr === 'heavysnow',               // amounts in cm (sleet counts as water, mm)
    hours,
    days: days.length ? days : [today],
    tiles,
    wind: { speed: ri(cur.wind), gust: ri(cur.gust ?? (cur.wind ?? 0) * 1.5), deg: ri(cur.dir) },
    plus,
    src: f.src || f.nextSource || 'met',
  };
  if (f.warnings?.length) {
    const w = f.warnings[0].name;
    scene.alert = { name: S.warning(w), note: R.alertNote(w, { total, pr, nowWet, when, endH: nowWet && endP ? (H(endP) + 1) % 24 : null, hi, lo, gust: ri(cur.gust ?? 0), rh: cur.rh == null ? null : ri(cur.rh) }, S) };
  }
  // day sheet: 8 three-hourly values per day (0, 3, … 21 h) — temp, rain chance, wind, UV, humidity (the point nearest
  // the slot), then what the whole 3-hour slot holds: the precipitation (mm; cm when it falls as snow, as in `hours`),
  // the strongest gust and the wind direction (degrees it comes from). Points cover [t, t + step h) with mm per hour
  // (MET's 6-hourly points too), so a slot takes each point's amount for the hours it overlaps.
  const HOUR = 3600000;
  scene.dayDetail = [...byDay.entries()].slice(0, days.length).map(([, list]) => {
    const [y, m, d] = [list[0].t, list[0].t, list[0].t].map((t, i) => [local(t, tz).y, local(t, tz).m, local(t, tz).d][i]);
    return [0, 3, 6, 9, 12, 15, 18, 21].map((h) => {
      const target = Date.UTC(y, m - 1, d, h) - offsetMin(list[0].t) * 60000;
      const end = target + 3 * HOUR;
      let best = list[0], bd = Infinity;
      for (const p of list) { const x = Math.abs(p.t - target); if (x < bd) { bd = x; best = p; } }
      const uvv = uvUnderCloud(best.uvClear, best.cloud);
      const gustOf = (p) => p.gust ?? (p.wind != null ? p.wind * 1.5 : null);   // no gust in the source (KMA alone): 1.5 × wind, as `wind.gust`
      let mm = 0, gust = null;
      for (const p of pts) {
        const from = +p.t, overlap = Math.min(from + (p.step || 1) * HOUR, end) - Math.max(from, target);
        if (overlap <= 0) continue;
        mm += (p.mm || 0) * overlap / HOUR;
        const g = gustOf(p);
        if (g != null && (gust == null || g > gust)) gust = g;
      }
      if (gust == null) gust = gustOf(best);   // a slot before the first point (earlier today): the nearest point's
      let dir = best.dir, dd = Infinity;
      if (dir == null) for (const p of list) { const x = Math.abs(p.t - target); if (p.dir != null && x < dd) { dd = x; dir = p.dir; } }
      dir = ri((((dir ?? cur.dir ?? 0) % 360) + 360) % 360) % 360;
      return [S.hour(h), r1(best.temp), ri(best.pop ?? (wet(best) ? 70 : 0)), r1(best.wind ?? 0), r1(h >= 6 && h <= 18 ? uvv ?? 0 : 0), ri(best.rh ?? 0),
        r1(mm), r1(Math.max(gust ?? 0, best.wind ?? 0)), dir];
    });
  });
  if (plus && f.next6?.length) scene.next6 = f.next6.slice(0, 6).map((p) => [S.hour(H(p)), r1(p.mm || 0)]);
  if (plus && (f.next6?.length || f.minutes?.length)) scene.nextSource = f.nextSource || 'kma';   // who the rain-soon card cites
  if (f.compare?.length > 1) scene.cmp = compareBlock(f.compare, cur, nowT, tz, S);
  if (plus && f.minutes?.length) scene.minutes = f.minutes.slice(0, 60).map((v) => (Number.isFinite(v) ? Math.round(v * 100) / 100 : 0));
  return scene;
}

/** 예보 비교: each source's temperature and precipitation for this hour and the next 23, so people can see where sources agree.
 *  { start: hour of slot 0, snow, sources: [{ name, key, main, t: [24 ints], r: [24 mm] }] } — a source without a point near a slot gets null. */
function compareBlock(list, cur, nowT, tz, S) {
  const t0 = new Date(cur.t);
  const slots = Array.from({ length: 24 }, (_, i) => new Date(t0.getTime() + i * 3600000));
  const sources = list.map((s) => {
    const pts = (s.points || []).filter((p) => p.temp != null);
    let j = 0;
    const near = slots.map((h) => {
      while (j + 1 < pts.length && Math.abs(pts[j + 1].t - h) <= Math.abs(pts[j].t - h)) j++;
      return pts.length && Math.abs(pts[j].t - h) <= 1.5 * 3600000 ? pts[j] : null;
    });
    return { name: S.src[s.key] ?? s.key, key: s.key, main: !!s.main,
      t: near.map((p) => (p ? Math.round(p.temp) : null)), r: near.map((p) => (p ? Math.round((p.mm || 0) * 10) / 10 : null)) };
  }).filter((s) => s.t.some((v) => v != null));
  const snow = (list[0].points || []).some((p) => p.t >= t0 && p.t - t0 < 24 * 3600000 && p.type === 'snow' && (p.mm || 0) >= 0.1);
  return { start: local(t0, tz).h, snow, sources };
}

/** Throws with a list of problems when a scene does not match what the app decodes (docs/server-api.md). */
export function validateScene(s) {
  const bad = [];
  const str = (k, opts) => { if (typeof s[k] !== 'string') bad.push(`${k} not a string`); else if (opts && !opts.includes(s[k])) bad.push(`${k}=${s[k]}`); };
  const int = (k) => { if (!Number.isInteger(s[k])) bad.push(`${k} not an integer`); };
  str('time', ['day', 'night']); str('cover', ['clear', 'partly', 'overcast']); str('precip', ['none', 'rain', 'heavy', 'snow', 'heavysnow', 'sleet']);
  str('thunder', ['on', 'off']); str('aux', ['none', 'wind', 'fog', 'heat', 'frost', 'dust']); str('rain', ['none', 'think', 'bag', 'umbrella']);
  for (const k of ['level', 'temp', 'feels', 'hi', 'lo', 'yday']) int(k);
  if (!(s.level >= 0 && s.level <= 9)) bad.push('level out of 0…9');
  for (const k of ['cond', 'clock', 'updated']) str(k);
  if (s.cmp != null) {
    if (!Number.isInteger(s.cmp.start) || !Array.isArray(s.cmp.sources) || s.cmp.sources.length < 2) bad.push('cmp');
    else s.cmp.sources.forEach((x, i) => { if (!(typeof x.name === 'string' && typeof x.key === 'string' && x.t?.length >= 2 && x.t.length <= 24 && x.r?.length === x.t.length)) bad.push(`cmp.sources[${i}]`); });
  }
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
  if (s.nextSource != null && typeof s.nextSource !== 'string') bad.push('nextSource');
  if (s.src != null && typeof s.src !== 'string') bad.push('src');
  // dayDetail rows: 6 values (older answers) or 9 (+ mm, gust, direction); the app reads both
  if (s.dayDetail != null && !(Array.isArray(s.dayDetail) && s.dayDetail.every((d) => Array.isArray(d) && d.every((h) => (h.length === 6 || h.length === 9)
    && typeof h[0] === 'string' && h.slice(1).every(Number.isFinite) && (h.length === 6 || (h[6] >= 0 && h[7] >= 0 && h[8] >= 0 && h[8] < 360)))))) bad.push('dayDetail');
  if (bad.length) throw new Error('scene does not match the app: ' + bad.join(', '));
  return true;
}

export { pad2 };
