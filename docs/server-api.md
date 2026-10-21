# Purrcast forecast server — API contract

The app (and its widgets) get the forecast from **one** endpoint. Until the server exists the app runs on the
example scenes in `Shared/Data/scenes.json`; those examples are already in exactly this format, so they double as
test fixtures for the server.

To switch the app over, put the server's base URL in `PurrcastServerURL` (project.yml → Info.plist of the app,
the widget extension and the watch). Nothing else changes in the app.

## Request

```
GET {base}/v1/forecast?lat=37.5663&lon=126.9019&region=kr&tz=Asia/Seoul&plan=plus&lang=ko
Accept: application/json
```

| param  | meaning |
|--------|---------|
| lat, lon | place, 4 decimals |
| region | `kr` (기상청 + MET Norway, six-hour rain), `jp` (minute rain), `other` (hourly only) |
| tz     | IANA time zone of the place; every clock time in the answer is local to it |
| plan   | `free` → the 06:00 forecast only, no `minutes` / `next6`; `plus` → latest run, with them |
| lang   | `ko` for now |

## Response — one `WeatherScene` (200, JSON)

```jsonc
{
  "time": "day",            // day | night (sun below the horizon)
  "cover": "overcast",      // clear | partly | overcast       ─┐ sky layers the app draws
  "precip": "none",         // none | rain | heavy | snow       │
  "thunder": "off",         // on | off                         │
  "aux": "none",            // none | wind | fog | heat | frost | dust ─┘
  "level": 4,               // outfit 0…9 from the feels-like temperature (rules below)
  "rain": "bag",            // none | think | bag | umbrella  (rules below)
  "temp": 18, "feels": 17, "hi": 19, "lo": 13,
  "yday": -1,               // temp now minus temp at the same hour yesterday
  "cond": "흐림",            // condition word
  "clock": "13:46",         // local time of the answer
  "updated": "06:00",       // issue time of the forecast used
  "bubble": { "kind": "speech", "tone": "sky", "icon": "umbrella_closed", "text": "15:50쯤 비!" },   // or null
  "mood": "normal",         // normal | happy | cold   (optional)
  "snow": false,            // true when the mm values are snow cm (optional)
  "place": "서울 마포구",     // optional, the app fills it in when missing
  "hours": [ ["지금", "cloud", 18, 10, 0], ["14시", "cloud", 18, 20, 0], … ],      // 13 rows: label, icon, °C, chance %, mm
  "days":  [ ["오늘", "raincloud", 70, 13, 19], ["수", "raincloud", 60, 12, 16], … ], // 10 rows: name, icon, chance %, lo, hi
  "tiles": [ { "icon": "raindrop", "label": "강수확률", "value": "70%", "unit": "", "note": "15~17시쯤 비 시작 · 7mm" },
             { "kind": "uv", "icon": "sun_strong", "label": "자외선", "uv": 2, "note": "구름이 많아 약해요" },
             { "icon": "sunset", "label": "일몰", "value": "17:52", "unit": "", "note": "내일 일출 06:49" },
             { "icon": "raindrop", "label": "습도", "value": "72%", "unit": "", "note": "이슬점 13°" } ],
  "wind": { "speed": 4, "gust": 7, "deg": 225 },       // m/s, m/s, degrees the wind comes from
  "minutes": [0, 0, 0.2, …],                            // Plus · jp/other where available: 60 values, mm/h per minute
  "next6": [ ["15시", 0], ["16시", 0.8], … ],            // Plus · kr: KMA ultra-short-term, 6 hourly slots, mm
  "plus": true                                          // echo of the plan
}
```

Icon names are the pixel icons in the app: `sun sun_strong partly_cloudy cloud raincloud lightning snowflake wind
dust moon umbrella umbrella_closed raindrop thermo_hot thermo_cold sunrise sunset …` (Shared/SharedAssets.xcassets).

## Rules the server applies (same as the design kit)

**Outfit level** from the feels-like °C, ±1° hysteresis against the previous answer for the same place:

| level | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|---|
| feels °C | ≥33 | 28–32 | 23–27 | 20–22 | 17–19 | 12–16 | 9–11 | 5–8 | −9–4 | ≤−10 |

**Umbrella** (`rain`): raining now → `umbrella`; rain starts within 12 h or chance ≥ 30 % → `bag`;
chance 10–29 % → `think`; otherwise `none`.

**Bubble**: one at a time, priority: rain coming / now › warnings (특보) › big temperature drop › heat / cold › nothing.
Rain timing is a clock time, never a countdown: start rounded **down** to 10 minutes, said conservatively
(“15:50쯤 비!”); free plan says the hour window (“15~17시 비!”).

## Sources

* **기상청 (KMA)** — 단기예보 + 초단기예보 (`next6`), 기상특보. Needs a data.go.kr service key (free).
* **MET Norway Locationforecast 2.0** — everything outside Korea, and the comparison. Free; requires a
  descriptive `User-Agent` with contact info, caching by `Expires`/`If-Modified-Since`, and attribution
  “Data from MET Norway” (CC BY 4.0) — the app shows it on 데이터 출처.

## Caching

Cache per (rounded lat/lon to 0.01°, plan) until the source's next issue time; free answers can be served from the
06:00 run all day.
