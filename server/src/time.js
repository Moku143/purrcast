// Local-time helpers (no libraries): everything the app shows is in the place's own time zone.

const WD = { Sun: '일', Mon: '월', Tue: '화', Wed: '수', Thu: '목', Fri: '금', Sat: '토' };

/** Calendar parts of an instant in a time zone. */
export function local(date, tz) {
  const f = new Intl.DateTimeFormat('en-US', {
    timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit',
    weekday: 'short', hourCycle: 'h23',
  });
  const o = {};
  for (const p of f.formatToParts(date)) o[p.type] = p.value;
  return { y: +o.year, m: +o.month, d: +o.day, h: +o.hour % 24, mi: +o.minute, wd: WD[o.weekday] || o.weekday };
}

/** Offset of the zone from UTC at that instant, in minutes (KST → 540). */
export function offsetMinutes(date, tz) {
  const p = local(date, tz);
  const asUTC = Date.UTC(p.y, p.m - 1, p.d, p.h, p.mi);
  return Math.round((asUTC - Math.floor(date.getTime() / 60000) * 60000) / 60000);
}

/** The instant of a wall-clock time in a zone (y, m 1-12, d, h, mi). */
export function instant(y, m, d, h, mi, tz) {
  const guess = new Date(Date.UTC(y, m - 1, d, h, mi));
  const off = offsetMinutes(guess, tz);
  const t = new Date(guess.getTime() - off * 60000);
  const off2 = offsetMinutes(t, tz);           // DST edge: re-check once
  return off2 === off ? t : new Date(guess.getTime() - off2 * 60000);
}

export const pad2 = (n) => String(n).padStart(2, '0');
export const hhmm = (date, tz) => { const p = local(date, tz); return `${p.h}:${pad2(p.mi)}`; };
export const hhmm0 = (date, tz) => { const p = local(date, tz); return `${pad2(p.h)}:${pad2(p.mi)}`; };
export const dayKey = (date, tz) => { const p = local(date, tz); return `${p.y}${pad2(p.m)}${pad2(p.d)}`; };

/** Sunrise / sunset (SunCalc's algorithm, −0.833° horizon). `date` is any instant on the wanted local day. */
export function sunTimes(date, lat, lon) {
  const rad = Math.PI / 180, dayMs = 86400000, J1970 = 2440588, J2000 = 2451545;
  const toDays = (d) => d.valueOf() / dayMs - 0.5 + J1970 - J2000;
  const fromJ = (j) => new Date((j + 0.5 - J1970) * dayMs);
  const lw = rad * -lon, phi = rad * lat;
  const d = toDays(date);
  const n = Math.round(d - 0.0009 - lw / (2 * Math.PI));
  const ds = 0.0009 + lw / (2 * Math.PI) + n;
  const M = rad * (357.5291 + 0.98560028 * ds);
  const C = rad * (1.9148 * Math.sin(M) + 0.02 * Math.sin(2 * M) + 0.0003 * Math.sin(3 * M));
  const L = M + C + rad * 102.9372 + Math.PI;
  const dec = Math.asin(Math.sin(L) * Math.sin(rad * 23.4397));
  const Jnoon = J2000 + ds + 0.0053 * Math.sin(M) - 0.0069 * Math.sin(2 * L);
  const cosw = (Math.sin(rad * -0.833) - Math.sin(phi) * Math.sin(dec)) / (Math.cos(phi) * Math.cos(dec));
  if (cosw < -1) return { rise: null, set: null, polar: 'day' };
  if (cosw > 1) return { rise: null, set: null, polar: 'night' };
  const w = Math.acos(cosw);
  const Jset = J2000 + 0.0009 + (w + lw) / (2 * Math.PI) + n + 0.0053 * Math.sin(M) - 0.0069 * Math.sin(2 * L);
  const Jrise = Jnoon - (Jset - Jnoon);
  return { rise: fromJ(Jrise), set: fromJ(Jset), polar: null };
}

/** Sun times for the local day containing `date` (computed from that day's local noon). */
export function sunDay(date, lat, lon, tz) {
  const p = local(date, tz);
  return sunTimes(instant(p.y, p.m, p.d, 12, 0, tz), lat, lon);
}

/** Is the sun down at this instant? */
export function isNight(date, lat, lon, tz) {
  const s = sunDay(date, lat, lon, tz);
  if (s.polar) return s.polar === 'night';
  return date < s.rise || date >= s.set;
}
