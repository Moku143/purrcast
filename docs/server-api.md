# Purrcast forecast server — API contract

The app (and its widgets) get the forecast from **one** endpoint. Until the server exists the app runs on the
example scenes in `Shared/Data/scenes.json`; those examples are already in exactly this format, so they double as
test fixtures for the server.

To switch the app over, put the server's base URL in `PurrcastServerURL` (project.yml → Info.plist of the app,
the widget extension and the watch). Nothing else changes in the app.

## Request

```
GET {base}/v1/forecast?lat=37.57&lon=126.90&region=kr&tz=Asia/Seoul&plan=plus&lang=ko&outfitPrev=5&name=서울 마포구&v=2
Accept: application/json
```

| param  | meaning |
|--------|---------|
| lat, lon | place, rounded to 2 decimals (~1 km) by the app and again by the server |
| region | `kr` (기상청 + MET Norway, six-hour rain), `jp` / `other` (Apple WeatherKit: minute rain where Apple has it, MET Norway without a key) |
| tz     | IANA time zone of the place; every clock time in the answer is local to it |
| plan   | `free` → one forecast a day (Korea: the 06:00 forecast; Apple countries: the first answer after 06:00, kept for the day), no `minutes` / `next6`; `plus` → latest run, with them |
| lang   | `ko` (default) · `en` · `ja`; any other value → `en`. Changes the words in the answer only — see [Languages](#languages) |
| outfitPrev | optional, the outfit (0…14) the app showed last for this place (±1° hysteresis) |
| prev   | optional, the old ten-outfit level (0…9) — sent by app builds from before the fifteen outfits |
| name   | optional, the place name ("서울 마포구"); used to match 기상특보 areas |
| v      | optional, what the app knows: `2` = the `sleet` icon. Without it (older builds) `sleet` is sent as `snowflake` |

## Response — one `WeatherScene` (200, JSON)

```jsonc
{
  "time": "day",            // day | night (sun below the horizon)
  "cover": "overcast",      // clear | partly | overcast       ─┐ sky layers the app draws
  "precip": "none",         // none | rain | heavy | snow | heavysnow | sleet│
  "thunder": "off",         // on | off                         │
  "aux": "none",            // none | wind | fog | heat | frost | dust ─┘
  "clouds": 92,             // 0–100 % cloud now (null when unknown): how many clouds are drawn, how far down
  "fog": 0,                 // 0 none · 1 mist · 2 fog · 3 thick fog (visibility / MET fog area): how thick it is drawn
  "outfit": 5,              // outfit 0…14 from the feels-like temperature (rules below) — what the app draws
  "level": 4,               // the old ten-outfit number 0…9, kept for app builds from before the fifteen outfits
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
  "minutes": [0, 0, 0.2, …],                            // Plus · WeatherKit forecastNextHour where Apple has it: up to 60 values, mm/h per minute, from now
  "next6": [ ["15시", 0], ["16시", 0.8], … ],            // Plus: next 6 hourly slots, mm
  "nextSource": "kma",                                  // kma (초단기예보) | apple | met — the card's legend
  "src": "kma",                                         // kma | apple | met — where the main forecast came from (attribution)
  "cmp": { "start": 14, "snow": false,                  // 예보 비교 (both plans): this hour + 23 more, every source we have for the place
           "sources": [ { "name": "기상청", "key": "kma", "main": true, "t": [18, 18, …], "r": [0, 0.4, …] },   // °C · mm (cm when snow); null = no point
                        { "name": "Apple 날씨", "key": "apple", "main": false, "t": […], "r": […] },
                        { "name": "MET Norway", "key": "met", "main": false, "t": […], "r": […] } ] },   // absent with one source only
  "dayDetail": [ [ ["0시", 9.5, 10, 2.1, 0, 82, 0.4, 3.6, 225], … one per forecast point ], … one per day ],
      // the day sheet: one row per forecast point of the day (every hour where the forecast is hourly, 3- or 6-hourly
      // further out), the same points the day's row in `days` is made from, so its highest chance and amounts agree.
      // Row: label, °C, chance %, wind m/s, UV, humidity %, then for the hours the point covers inside the day:
      // precipitation mm (cm when it falls as snow, as in `hours`), strongest gust m/s, wind direction ° (where it
      // comes from). A point from the day before that runs past midnight opens the day as a 0 h row.
      // Older answers: 8 three-hourly rows, or 6 values per row; the app reads all of these.
  "plus": true                                          // echo of the plan
}
```

Icon names are the pixel icons in the app: `sun sun_strong partly_cloudy cloud raincloud lightning snowflake sleet wind
dust moon umbrella umbrella_closed raindrop thermo_hot thermo_cold sunrise sunset …` (Shared/SharedAssets.xcassets).

## Rules the server applies (same as the design kit)

**Outfit** (`outfit`) from the feels-like °C, ±1° hysteresis against the outfit the app showed last (`outfitPrev`):

| outfit | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| feels °C | ≥35 | 33–34 | 28–32 | 23–27 | 20–22 | 18–19 | 16–17 | 12–15 | 9–11 | 6–8 | 3–5 | 0–2 | −4…−1 | −9…−5 | ≤−10 |

The old `level` (still sent, against `prev`) uses the ten bands ≥33 · 28–32 · 23–27 · 20–22 · 18–19 · 16–17 · 10–15 · 5–9 · −9…4 · ≤−10.
An app that gets no `outfit` (an older server) works it out from `feels` itself.

**Umbrella** (`rain`): raining now → `umbrella`; rain starts within 12 h or chance ≥ 30 % → `bag`;
chance 10–29 % → `think`; otherwise `none`.

**Bubble**: one at a time, priority: rain coming / now › warnings (특보) › big temperature drop › heat / cold › nothing.
Rain ahead is said as the hours people plan around, never as a promise: `15~17시 비 예보` (first to last wet hour),
`15시쯤 비 예보` (one hour), `내일 7~9시 비 예보`; snow and sleet the same way (`15~17시 진눈깨비 예보`, with the `sleet` icon).
The next-6-hours card says until when (`18시까지 비 예보`).

## Languages

`lang` picks the dictionary (`server/src/i18n.js`, words from `docs/i18n-glossary.md`). Keys, icons, kinds, tones, numbers,
`clock` and `updated` (free: `06:00`) are the same in every language; only the text fields change:

| field | ko | en | ja |
|---|---|---|---|
| `cond` | `비 · 바람 강함` | `Rain · Strong wind` | `雨 · 強風` |
| `bubble.text` (rain ahead) | `15~17시 비 예보` · `15시쯤 비 예보` · `내일 7~9시 비 예보` | `Rain 3–5PM` · `Rain around 3PM` · `Rain tomorrow 7–9AM` | `15〜17時 雨の予報` · `15時ごろ 雨の予報` · `明日7〜9時 雨の予報` |
| `bubble.text` (fixed) | `비!` `폭우!` `한파!` `우산 챙겨요` | `Rain!` `Downpour!` `Cold wave!` `Take an umbrella` | `雨!` `豪雨!` `寒波!` `傘を持って` |
| `bubble.text` / `alert.name` (특보) | `호우주의보` (KMA name) | `Heavy Rain Advisory` (glossary table; unknown names pass through) | `大雨注意報` |
| `alert.note` | `오늘 6cm, 18시까지 눈 예보, 미끄러우니 조심하세요` | `6cm today, snow until around 6PM, watch your step` | `今日 6cm、18時ごろまで雪の予報、滑りやすいのでご注意ください` |
| `hours[][0]`, `next6[][0]` | `지금` `14시` | `Now` `2PM` | `今` `14時` |
| `dayDetail[][][0]` | `0시` … `21시` | `12AM` … `9PM` | `0時` … `21時` |
| `days[][0]` | `오늘` `월`…`일` | `Today` `Mon`…`Sun` | `今日` `月`…`日` |
| `tiles[].label` | `강수확률` `자외선` `일몰`/`일출` `습도` | `Rain chance` `UV` `Sunset`/`Sunrise` `Humidity` | `降水確率` `紫外線` `日の入り`/`日の出` `湿度` |
| rain tile note | `15~17시 비 예보 · 7mm (보통)` · `12시간 동안 비 소식 없어요` | `Rain 3–5PM · 7mm (Moderate)` · `No rain for the next 12 hours` | `15〜17時 雨の予報 · 7mm (普通)` · `12時間 雨の心配はありません` |
| UV note | `강해요 · 선크림, 모자` | `High · Sunscreen, hat` | `強い · 日焼け止め、帽子` |
| sun tile note | `내일 일출 06:49` / `일몰 17:52` | `Sunrise tomorrow 06:49` / `Sunset 17:52` | `明日の日の出 06:49` / `日の入り 17:52` |
| humidity note | `적당해요 · 이슬점 13°` | `Comfortable · Dew point 13°` | `ちょうどいい · 露点 13°` |

Tone: en short and friendly, sentence case; ja です・ます, concise. The app's 말투 switch (존댓말 · 격식 · 반말) applies to `ko` only.

## Implementation

`server/` in this repo (Cloudflare Worker): `src/index.js` (request, cache, merge, fallbacks), `src/providers/` (KMA, WeatherKit, MET),
`src/rules.js` (the rules below), `src/i18n.js` (the three dictionaries), `src/scene.js` (builds and validates this JSON). `node --test test/*.test.js` runs
the rules and the contract against fake upstreams; `scripts/live-check.mjs` against the real ones.

## Sources

| region | main source (`src`) | adds | fallback |
|---|---|---|---|
| `kr` | **기상청 (KMA)** 단기예보; Plus: 초단기실황 (`now`), 초단기예보 (`next6`), 기상특보 (`alert`) | MET Norway: days 4–10, UV, gusts, fog | MET Norway (no key, or KMA down) → then WeatherKit if configured |
| `jp`, `other` | **Apple WeatherKit** currentWeather (`now`), forecastHourly (hours, `next6`), forecastDaily (lo / hi), forecastNextHour (`minutes`, only where Apple has it), weatherAlerts (`alert`, in the request `lang`) | — | MET Norway (no key, 401, or any error) |

* **기상청 (KMA)** — needs a data.go.kr service key (free). 공공누리 제1유형 (출처표시).
* **Apple WeatherKit REST** — needs `WEATHERKIT_KEY_ID` + `WEATHERKIT_KEY_P8` (the .p8) + `APPLE_TEAM_ID`; service id = bundle id
  (`WEATHERKIT_SERVICE_ID`, wrangler var). 500,000 calls / month in the developer membership; answers are cached 10 min (Plus) / 30 min (free)
  per ~1 km cell. Attribution is required wherever its data is shown: “Weather data provided by  Weather” (the Apple Weather mark or
  the words) plus a link to <https://weatherkit.apple.com/legal-attribution.html> — the app shows it on 데이터 출처 when `src` is `apple`.
* **MET Norway Locationforecast 2.0** — the fallback everywhere, and the comparison for Korea. Free; requires a
  descriptive `User-Agent` with contact info, caching by `Expires`/`If-Modified-Since`, and attribution
  “Data from MET Norway” (CC BY 4.0) — the app shows it on 데이터 출처.

## Caching

Cache per (rounded lat/lon to 0.01°, plan) until the source's next issue time; free answers are told from one
forecast a day: Korea's 06:00 run, and in Apple countries the first WeatherKit answer after 06:00 local for the cell,
kept in the `FREE_DAY` KV namespace (06:00 → 06:00; the label `updated` is when it was taken). Today's low / high in
Korea always cover 00–24 h: the earlier runs (05 h, yesterday 23 h) fill what later runs leave out.

## 판단 기준 (사람이 느끼는 대로)

| 항목 | 기준 | 출처 |
|---|---|---|
| 체감온도 | 기온 10°C 이하·바람 1.3 m/s 이상이면 기상청 겨울 체감온도(JAG/TI 바람냉각), 20°C 이상이면 기상청 2022년 여름 체감온도(습구온도 반영), 그 사이는 기온 그대로 | 기상청 기후자료 체감온도 |
| 습도 느낌 | 습도 20% 미만 매우 건조 · 30% 미만 건조 · 이슬점 24° 이상 숨 막히게 끈적 · 21° 이상 끈적 · 18° 이상 꿉꿉 · 비 오거나 85% 이상이면 습함(15° 미만이면 눅눅) · 70% 이상 조금 습함 · 이슬점 10° 미만이고 60% 미만이면 보송 · 그 밖은 적당 | NWS 이슬점 체감 단계 + 상대습도 보정 |
| 바람 느낌 | 0.5 미만 없음 · 1.6 미만 거의 없음 · 3.4 미만 산들바람 · 5.5 미만 머리카락 날림 · 8 미만 우산 뒤집힐 수 있음 · 10.8 미만 걷기 힘듦 · 13.9 미만 매우 강함 · 그 이상 위험(강풍주의보 14 m/s) | 보퍼트 풍력계급 + 기상청 특보 기준 |
| 자외선 | 0–2 약함 · 3–5 보통 · 6–7 강함 · 8–10 매우 강함 · 11+ 위험 | WHO / 기상청 자외선지수 |
| 불쾌지수 | 68 미만 낮음 · 68–75 보통 · 75–80 높음 · 80 이상 매우 높음 (`discomfortIndex`) | 기상청 생활기상지수 |

## 문구 규칙

- **비 시각은 시간대로**: "15~17시 비 예보", "15시쯤 비 예보", "내일 7~9시 비 예보". "2시간 뒤" 같은 남은 시간이나 단정("올 듯")은 쓰지 않아요. 언제까지는 "18시까지 비 예보".
- **고유명사 알림은 그대로**: 기상청 특보 이름(호우주의보 · 태풍경보 · 대설주의보 …)과 기준 이상일 때만 나오는 이름(폭염 33° · 열대야 밤 25° · 한파 -10° · 폭우 · 폭설 · 천둥번개)은 다른 말로 바꾸지 않아요. 위젯 · 워치에서도 이 이름이 그대로 보여요.
- **위젯 · 잠금 화면 · 워치는 문장이 아니라 단어**: `머리말 · 기온 · 꼬리말` (`Shared/Models/Compact.swift`)
  - 머리말: 특보 · 알림 이름, 없으면 날씨 한 단어 (비 · 눈 · 맑음 · 흐림 · 15~17시 비 · 강한 바람 · 짙은 안개)
  - 꼬리말: 다음으로 알아야 할 것 하나 — 우산(지금 비 · 비 예보) → 체감 N°(3° 이상 차이) → 큰 일교차(10° 이상) → 바람 · 안개 · 황사 → 최고/최저
  - 예: `비 · 16° · 우산` · `15~17시 비 · 18° · 우산` · `한파 · -13° · 체감 -16°` · `호우주의보 · 18° · 우산` · `맑음 · 19° · 큰 일교차`
  - 2x2 · 워치의 말풍선에는 5글자까지만 (비 · 한파 · 폭염), 4x2는 9글자까지 (15~17시 비 · 호우주의보); 더 길면 아이콘만

## 특보 띠 · 눈의 종류

- `alert { name, note }`: 기상청 특보가 있을 때만. 홈 화면 캐릭터 아래, 시간별 위에 띠로 보여요 — "대설주의보 · 오늘 6cm, 18시까지 눈 예보, 미끄러우니 조심하세요", "폭염경보 · 낮 최고 36°, 한낮 외출 줄여요". 위젯·워치에는 자리가 없어 이름만 (호우주의보 · 18° · 우산).
- `precip`: `snow` (눈) · `heavysnow` (시간당 3cm 이상, 말풍선 폭설!) · `sleet` (진눈깨비: 비와 눈이 함께, 양은 mm). 하늘 그림도 따로 — 눈은 큰 눈송이(3·4·5px, 테두리 할로), 많은 눈은 더 촘촘하게, 진눈깨비는 빗줄기와 젖은 눈송이가 함께.
- 하늘에 내리는 양은 그 시각의 mm(눈은 cm)를 따라가요 (`Sky.density`): 비 1mm 미만 0.3배 · 3mm 1배 · 15mm 1.6배 · 30mm 2배, 눈 0.5cm 0.6배 · 1cm 1배 · 3cm 1.6배 · 6cm 2배 (사이는 비례). 빗줄기 길이도 같이 달라져요.

## 말투 (앱)

서버는 존댓말 하나만 보내고, 앱이 어미만 바꿔요 (`Shared/Models/Voice.swift`). 정보는 그대로.
- 캐릭터 기본: 고양이 존댓말 · 브리티시숏헤어 격식 · 아비시니안 반말. Plus는 설정 → 화면 → 말투에서 고를 수 있고, 무료는 존댓말.
- 적용: 홈 말풍선 · 특보 띠 · 다음 6시간 카드 · 타일 설명 · 날짜 상세 · 알림. 위젯 · 워치 · 특보 이름은 단어라 그대로.
- 예: 비 예보예요. 우산을 챙겨 주세요. → 비 예보입니다. 우산을 챙겨 주십시오. / 비 예보야. 우산을 챙겨.
