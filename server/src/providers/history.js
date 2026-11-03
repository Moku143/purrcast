// 날씨 기록's missing days: what the weather actually was, a day at a time.
// Korea: 기상청 지상(종관, ASOS) 일자료 (data.go.kr AsosDalyInfoService, the same service key as the forecast) at the
// nearest ASOS station. Elsewhere, or when that fails: Apple WeatherKit's daily history (forecastDaily with past dates).
// A day: { date: 'YYYY-MM-DD', hi, lo, icon, mm, wet: 'rain' | 'snow' | null }.

const DATA_GO_KR = 'https://apis.data.go.kr/1360000';

// The ASOS stations: number, name, and where to find them. The positions are the town's centre in the KMA grid list
// (Purrcast/Resources/places.json) — close enough to pick the nearest station. Every answer's station name (stnNm) is
// checked against the name here, so a number that does not match falls back to Apple instead of showing another place.
export const ASOS_STATIONS = [
  [90, '속초', 38.2043, 128.5942], [93, '북춘천', 37.9231, 127.7484], [95, '철원', 38.1441, 127.3157],
  [98, '동두천', 37.9009, 127.0627], [99, '파주', 37.7571, 126.782], [100, '대관령', 37.6709, 128.7084],
  [101, '춘천', 37.8785, 127.7323], [102, '백령도', 37.9742, 124.7187], [104, '북강릉', 37.8208, 128.8511],
  [105, '강릉', 37.7491, 128.8785], [106, '동해', 37.5219, 129.1166], [108, '서울', 37.5691, 126.9641],
  [112, '인천', 37.4532, 126.7074], [114, '원주', 37.3391, 127.9221], [115, '울릉도', 37.4806, 130.9038],
  [119, '수원', 37.2547, 126.9741], [121, '영월', 37.1809, 128.464], [127, '충주', 36.9882, 127.9281],
  [129, '서산', 36.7821, 126.4522], [130, '울진', 36.9902, 129.4028], [131, '청주', 36.6443, 127.4877],
  [133, '대전', 36.3594, 127.3583], [135, '추풍령', 36.2116, 128.0009], [136, '안동', 36.5655, 128.7316],
  [137, '상주', 36.408, 128.1613], [138, '포항', 36.0057, 129.3617], [140, '군산', 35.9646, 126.7388],
  [143, '대구', 35.8836, 128.6377], [146, '전주', 35.8264, 127.1364], [152, '울산', 35.5663, 129.3349],
  [155, '창원', 35.1969, 128.5679], [156, '광주', 35.1711, 126.9141], [159, '부산', 35.1032, 129.0345],
  [162, '통영', 34.8513, 128.4353], [165, '목포', 34.8088, 126.3944], [168, '여수', 34.7573, 127.6644],
  [169, '흑산도', 34.6798, 125.4313], [170, '완도', 34.3079, 126.7571], [172, '고창', 35.4327, 126.7041],
  [174, '순천', 34.9476, 127.4893], [177, '홍성', 36.5984, 126.6629], [184, '제주', 33.4963, 126.5332],
  [185, '고산', 33.3474, 126.186], [188, '성산', 33.4387, 126.9129], [189, '서귀포', 33.2541, 126.5596],
  [192, '진주', 35.177, 128.11], [201, '강화', 37.7439, 126.49], [202, '양평', 37.4889, 127.4899],
  [203, '이천', 37.2754, 127.4432], [211, '인제', 38.067, 128.1727], [212, '홍천', 37.6944, 127.8908],
  [216, '태백', 37.1612, 128.988], [217, '정선군', 37.3778, 128.6631], [221, '제천', 37.1298, 128.1932],
  [226, '보은', 36.4865, 127.7316], [232, '천안', 36.8041, 127.1525], [235, '보령', 36.3306, 126.6149],
  [236, '부여', 36.2728, 126.9119], [238, '금산', 36.1059, 127.4903], [239, '세종', 36.48, 127.2891],
  [243, '부안', 35.7285, 126.7357], [244, '임실', 35.6081, 127.2848], [245, '정읍', 35.5669, 126.8581],
  [247, '남원', 35.4133, 127.3925], [248, '장수', 35.6443, 127.5233], [251, '고창군', 35.4327, 126.7041],
  [252, '영광군', 35.2742, 126.5141], [253, '김해시', 35.2255, 128.8917], [254, '순창군', 35.3714, 127.1396],
  [255, '북창원', 35.254, 128.6402], [257, '양산시', 35.3319, 129.0394], [258, '보성군', 34.7683, 127.0821],
  [259, '강진군', 34.6389, 126.7692], [260, '장흥', 34.6785, 126.9091], [261, '해남', 34.5704, 126.6013],
  [262, '고흥', 34.6081, 127.2871], [263, '의령군', 35.3191, 128.2638], [264, '함양군', 35.5175, 127.7274],
  [266, '광양시', 34.9375, 127.6982], [268, '진도군', 34.4838, 126.2655], [271, '봉화', 36.8903, 128.7349],
  [272, '영주', 36.8029, 128.6263], [273, '문경', 36.5836, 128.189], [276, '청송군', 36.4333, 129.0594],
  [277, '영덕', 36.4121, 129.3684], [278, '의성', 36.3498, 128.6994], [279, '구미', 36.1165, 128.3468],
  [281, '영천', 35.9701, 128.9408], [283, '경주시', 35.8532, 129.227], [284, '거창', 35.6836, 127.9117],
  [285, '합천', 35.5636, 128.1679], [288, '밀양', 35.5008, 128.7489], [289, '산청', 35.4125, 127.8756],
  [294, '거제', 34.8774, 128.6234], [295, '남해', 34.8346, 127.8945], [296, '북부산', 35.1942, 128.9925]
];

const rad = (d) => (d * Math.PI) / 180;
export function km(lat1, lon1, lat2, lon2) {
  const a = Math.sin(rad(lat2 - lat1) / 2) ** 2 + Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(rad(lon2 - lon1) / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.sqrt(a));
}

/** The nearest ASOS station within `maxKm`, or null */
export function nearestAsos(lat, lon, maxKm = 60) {
  let best = null;
  for (const [id, name, la, lo] of ASOS_STATIONS) {
    const d = km(lat, lon, la, lo);
    if (d <= maxKm && (!best || d < best.km)) best = { id, name, km: d };
  }
  return best;
}

export const ymd8 = (k) => k.replace(/-/g, '');

export function asosUrl(key, stnId, from, to) {
  const q = new URLSearchParams({ pageNo: '1', numOfRows: '100', dataType: 'JSON', dataCd: 'ASOS', dateCd: 'DAY', startDt: ymd8(from), endDt: ymd8(to), stnIds: String(stnId) });
  return `${DATA_GO_KR}/AsosDalyInfoService/getWthrDataList?serviceKey=${encodeURIComponent(key)}&${q}`;
}

const n = (v) => { const x = typeof v === 'number' ? v : parseFloat(v); return Number.isFinite(x) && Math.abs(x) < 900 ? x : null; };

/** ASOS daily rows → days. Throws when the answer is for another station than asked (a wrong number in the table). */
export function parseAsos(json, station) {
  const code = json?.response?.header?.resultCode;
  if (code !== '00') throw new Error(`ASOS ${code ?? 'no answer'} ${json?.response?.header?.resultMsg ?? ''}`.trim());
  let items = json?.response?.body?.items?.item ?? [];
  if (!Array.isArray(items)) items = [items];
  const days = [];
  for (const it of items) {
    if (station && it.stnNm && it.stnNm !== station.name) throw new Error(`ASOS station ${station.id} is ${it.stnNm}, not ${station.name}`);
    const hi = n(it.maxTa), lo = n(it.minTa);
    if (!it.tm || hi == null || lo == null) continue;
    const mm = n(it.sumRn) ?? 0, cloud = n(it.avgTca), snowCm = Math.max(n(it.ddMefs) ?? 0, 0);
    const w = String(it.iscs || '');
    const thunder = /뇌전/.test(w);
    const snowy = /눈|진눈깨비/.test(w) || snowCm > 0;
    const sleetOnly = /진눈깨비/.test(w) && !/[^진]눈|^눈|\{눈/.test(w);
    const wet = mm >= 0.1 || /비|소나기|눈|진눈깨비/.test(w);
    const icon = thunder ? 'lightning' : wet ? (snowy ? (sleetOnly ? 'sleet' : 'snowflake') : 'raincloud')
      : cloud == null ? 'partly_cloudy' : cloud >= 7 ? 'cloud' : cloud >= 3 ? 'partly_cloudy' : 'sun';
    const day = { date: String(it.tm).slice(0, 10), hi: Math.round(hi), lo: Math.round(lo), icon, mm: Math.round(mm * 10) / 10, wet: wet ? (snowy ? 'snow' : 'rain') : null };
    // when it rained or snowed: the phenomena field's times, e.g. "{비}0300-2100. {박무}0600-0900."
    const spans = [...w.matchAll(/\{(비|소나기|눈|진눈깨비|뇌전)\}\s*(\d{4})-(\d{4})/g)].map((m) => [parseInt(m[2].slice(0, 2), 10), parseInt(m[3].slice(0, 2), 10)]);
    if (wet && spans.length) { day.wetFrom = Math.min(...spans.map((x) => x[0])); day.wetTo = Math.min(23, Math.max(...spans.map((x) => x[1]))); }
    const rh = n(it.avgRhm), ws = n(it.maxWs);
    if (rh != null) day.rh = Math.round(rh);
    if (ws != null) day.windMax = Math.round(ws);
    days.push(day);
  }
  return days;
}

// ---- Apple WeatherKit: the daily forecast for past dates is the day as it was ----

const WK_ICON = [
  [/Thunder|StrongStorms|Hurricane|TropicalStorm/, 'lightning'],
  [/Sleet|Freezing|WintryMix/, 'sleet'],
  [/Snow|Flurries|Blizzard/, 'snowflake'],
  [/Rain|Drizzle|Showers/, 'raincloud'],
  [/MostlyCloudy|^Cloudy|Foggy|Haze|Smoky|Dust/, 'cloud'],
  [/PartlyCloudy|Breezy|Windy/, 'partly_cloudy'],
  [/Clear|Hot|Frigid/, 'sun'],
];

export function weatherKitHistoryUrl(host, lat, lon, from, to, tz) {
  const q = (v) => (Math.round(v * 10000) / 10000).toFixed(4).replace(/\.?0+$/, '');
  // a day either side: the days are cut by the place's own calendar below
  const start = new Date(Date.parse(`${from}T00:00:00Z`) - 86400000).toISOString().replace(/\.\d+Z$/, 'Z');
  const end = new Date(Date.parse(`${to}T00:00:00Z`) + 2 * 86400000).toISOString().replace(/\.\d+Z$/, 'Z');
  return `${host}/api/v1/weather/en/${q(lat)}/${q(lon)}?dataSets=forecastDaily&dailyStart=${start}&dailyEnd=${end}&timezone=${encodeURIComponent(tz)}`;
}

export function parseWeatherKitHistory(json, from, to, dayKeyOf) {
  const days = [];
  for (const d of json?.forecastDaily?.days ?? []) {
    if (!d.forecastStart || d.temperatureMax == null || d.temperatureMin == null) continue;
    const date = dayKeyOf(new Date(d.forecastStart));
    if (date < from || date > to) continue;
    const mm = Math.max(0, d.precipitationAmount ?? 0);
    const code = String(d.conditionCode || '');
    let icon = (WK_ICON.find(([re]) => re.test(code)) ?? [null, 'partly_cloudy'])[1];
    const type = String(d.precipitationType || '').toLowerCase();
    const wetIcon = ['raincloud', 'snowflake', 'sleet', 'lightning'].includes(icon);
    const wet = mm >= 0.2 || wetIcon;
    if (wet && !wetIcon) icon = type === 'snow' ? 'snowflake' : type === 'sleet' || type === 'mixed' ? 'sleet' : 'raincloud';
    const snowy = icon === 'snowflake' || icon === 'sleet' || type === 'snow' || (d.snowfallAmount ?? 0) > 0;
    const day = { date, hi: Math.round(d.temperatureMax), lo: Math.round(d.temperatureMin), icon, mm: Math.round(mm * 10) / 10, wet: wet ? (snowy ? 'snow' : 'rain') : null };
    if (d.maxUvIndex != null) day.uv = Math.round(d.maxUvIndex);
    days.push(day);
  }
  return days;
}
