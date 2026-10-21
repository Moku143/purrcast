// MET Norway Locationforecast 2.0 (complete). Free, worldwide, CC BY 4.0 — "Data from MET Norway".
// Terms: identify with a User-Agent that has contact info, at most 4 decimals in coordinates, respect caching.
// https://docs.api.met.no/doc/locationforecast/HowTO

export const MET_URL = 'https://api.met.no/weatherapi/locationforecast/2.0/complete';

export function metUrl(lat, lon) {
  const q = (v) => (Math.round(v * 10000) / 10000).toFixed(4).replace(/\.?0+$/, '');
  return `${MET_URL}?lat=${q(lat)}&lon=${q(lon)}`;
}

/** MET JSON → normalized hourly points. Each point covers [t, t + step h). */
export function parseMet(json) {
  const ts = json?.properties?.timeseries ?? [];
  const out = [];
  for (let i = 0; i < ts.length; i++) {
    const e = ts[i];
    const det = e.data?.instant?.details ?? {};
    const n1 = e.data?.next_1_hours, n6 = e.data?.next_6_hours;
    const t = new Date(e.time);
    const nextT = i + 1 < ts.length ? new Date(ts[i + 1].time) : new Date(t.getTime() + 3600000);
    const step = Math.max(1, Math.round((nextT - t) / 3600000));
    const sym = (n1 ?? n6)?.summary?.symbol_code ?? '';
    let mm = 0;
    if (n1?.details?.precipitation_amount != null) mm = n1.details.precipitation_amount;
    else if (n6?.details?.precipitation_amount != null) mm = n6.details.precipitation_amount / 6;
    const pop = n1?.details?.probability_of_precipitation ?? n6?.details?.probability_of_precipitation ?? null;
    let type = 'none';
    if (mm > 0 || /rain|sleet|snow|showers/.test(sym)) {
      type = /sleet/.test(sym) ? 'sleet' : /snow/.test(sym) ? 'snow' : 'rain';
      if (mm <= 0) type = 'none'; // symbol says showers somewhere in the period but this hour is dry
    }
    // probability_of_precipitation exists only in the Nordic model; elsewhere estimate it from amount + symbol
    let chance = pop == null ? null : Math.round(pop);
    if (chance == null) {
      chance = mm >= 1 ? 90 : mm >= 0.3 ? 75 : mm > 0 ? 60   // mm is per hour
        : /rain|sleet|snow|showers/.test(sym) ? 35 : (det.cloud_area_fraction ?? 0) >= 90 ? 15 : (det.cloud_area_fraction ?? 0) >= 60 ? 10 : 0;
    }
    out.push({
      t, step, source: 'met',
      temp: det.air_temperature ?? null,
      rh: det.relative_humidity ?? null,
      dew: det.dew_point_temperature ?? null,
      wind: det.wind_speed ?? null,
      gust: det.wind_speed_of_gust ?? null,
      dir: det.wind_from_direction ?? null,
      cloud: det.cloud_area_fraction ?? null,
      fog: (det.fog_area_fraction ?? 0) >= 50 || /fog/.test(sym),
      uvClear: det.ultraviolet_index_clear_sky ?? null,
      mm: Math.round(mm * 10) / 10,
      pop: chance,
      popEstimated: pop == null,
      type,
      thunder: /thunder/.test(sym),
      symbol: sym,
    });
  }
  return { points: out, updated: json?.properties?.meta?.updated_at ? new Date(json.properties.meta.updated_at) : null };
}
