# Purrcast forecast server — API contract

The app (and its widgets) get the forecast from **one** endpoint. Until the server exists the app runs on the
example scenes in `Shared/Data/scenes.json`; those examples are already in exactly this format, so they double as
test fixtures for the server.

To switch the app over, put the server's base URL in `PurrcastServerURL` (project.yml → Info.plist of the app,
the widget extension and the watch). Nothing else changes in the app.

## Request

```
GET {base}/v1/forecast?lat=37.57&lon=126.90&region=kr&tz=Asia/Seoul&plan=plus&lang=ko&prev=4&name=서울 마포구
Accept: application/json
```

| param  | meaning |
|--------|---------|
| lat, lon | place, rounded to 2 decimals (~1 km) by the app and again by the server |
| region | `kr` (기상청 + MET Norway, six-hour rain), `jp` (minute rain), `other` (hourly only) |
| tz     | IANA time zone of the place; every clock time in the answer is local to it |
| plan   | `free` → the 06:00 forecast only, no `minutes` / `next6`; `plus` → latest run, with them |
| lang   | `ko` for now |
| prev   | optional, the outfit level the app showed last for this place (±1° hysteresis) |
| name   | optional, the place name ("서울 마포구"); used to match 기상특보 areas |

## Response — one `WeatherScene` (200, JSON)

```jsonc
{
  "time": "day",            // day | night (sun below the horizon)
  "cover": "overcast",      // clear | partly | overcast       ─┐ sky layers the app draws
  "precip": "none",         // none | rain | heavy | snow | heavysnow | sleet│
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
  "next6": [ ["15시", 0], ["16시", 0.8], … ],            // Plus: next 6 hourly slots, mm
  "nextSource": "kma",                                  // kma (초단기예보) | met — the card's legend
  "dayDetail": [ [ ["0시", 9.5, 10, 2.1, 0, 82], … 8 per day ], … one per day ],  // °C, chance %, wind m/s, UV, humidity %
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
Rain ahead is said as the hours people plan around, never as a promise: `15~17시 비 예정` (first to last wet hour),
`15시쯤 비 예정` (one hour), `내일 7~9시 비 예정`. The next-6-hours card says when it may stop (`18시쯤 그칠 예보`).

## Implementation

`server/` in this repo (Cloudflare Worker): `src/index.js` (request, cache, merge, fallbacks), `src/providers/` (MET, KMA),
`src/rules.js` (the rules below), `src/scene.js` (builds and validates this JSON). `node --test test/*.test.js` runs
the rules and the contract against fake upstreams; `scripts/live-check.mjs` against the real ones.

## Sources

* **기상청 (KMA)** — 단기예보 + 초단기예보 (`next6`), 기상특보. Needs a data.go.kr service key (free).
* **MET Norway Locationforecast 2.0** — everything outside Korea, and the comparison. Free; requires a
  descriptive `User-Agent` with contact info, caching by `Expires`/`If-Modified-Since`, and attribution
  “Data from MET Norway” (CC BY 4.0) — the app shows it on 데이터 출처.

## Caching

Cache per (rounded lat/lon to 0.01°, plan) until the source's next issue time; free answers can be served from the
06:00 run all day.

## 판단 기준 (사람이 느끼는 대로)

| 항목 | 기준 | 출처 |
|---|---|---|
| 체감온도 | 기온 10°C 이하·바람 1.3 m/s 이상이면 기상청 겨울 체감온도(JAG/TI 바람냉각), 20°C 이상이면 기상청 2022년 여름 체감온도(습구온도 반영), 그 사이는 기온 그대로 | 기상청 기후자료 체감온도 |
| 습도 느낌 | 습도 20% 미만 매우 건조 · 30% 미만 건조 · 이슬점 24° 이상 숨 막히게 끈적 · 21° 이상 끈적 · 18° 이상 꿉꿉 · 비 오거나 85% 이상이면 습함(15° 미만이면 눅눅) · 70% 이상 조금 습함 · 이슬점 10° 미만이고 60% 미만이면 보송 · 그 밖은 적당 | NWS 이슬점 체감 단계 + 상대습도 보정 |
| 바람 느낌 | 0.5 미만 없음 · 1.6 미만 거의 없음 · 3.4 미만 산들바람 · 5.5 미만 머리카락 날림 · 8 미만 우산 뒤집힐 수 있음 · 10.8 미만 걷기 힘듦 · 13.9 미만 매우 강함 · 그 이상 위험(강풍주의보 14 m/s) | 보퍼트 풍력계급 + 기상청 특보 기준 |
| 자외선 | 0–2 약함 · 3–5 보통 · 6–7 강함 · 8–10 매우 강함 · 11+ 위험 | WHO / 기상청 자외선지수 |
| 불쾌지수 | 68 미만 낮음 · 68–75 보통 · 75–80 높음 · 80 이상 매우 높음 (`discomfortIndex`) | 기상청 생활기상지수 |

## 문구 규칙

- **비 시각은 시간대로**: "15~17시 비 예정", "15시쯤 비 예정", "내일 7~9시 비 예정". "2시간 뒤" 같은 남은 시간이나 단정("올 듯")은 쓰지 않아요. 그치는 때는 "18시쯤 그칠 예보".
- **고유명사 알림은 그대로**: 기상청 특보 이름(호우주의보 · 태풍경보 · 대설주의보 …)과 기준 이상일 때만 나오는 이름(폭염 33° · 열대야 밤 25° · 한파 -10° · 폭우 · 폭설 · 천둥번개)은 다른 말로 바꾸지 않아요. 위젯 · 워치에서도 이 이름이 그대로 보여요.
- **위젯 · 잠금 화면 · 워치는 문장이 아니라 단어**: `머리말 · 기온 · 꼬리말` (`Shared/Models/Compact.swift`)
  - 머리말: 특보 · 알림 이름, 없으면 날씨 한 단어 (비 · 눈 · 맑음 · 흐림 · 15~17시 비 · 강한 바람 · 짙은 안개)
  - 꼬리말: 다음으로 알아야 할 것 하나 — 우산(지금 비 · 비 예보) → 체감 N°(3° 이상 차이) → 큰 일교차(10° 이상) → 바람 · 안개 · 황사 → 최고/최저
  - 예: `비 · 16° · 우산` · `15~17시 비 · 18° · 우산` · `한파 · -13° · 체감 -16°` · `호우주의보 · 18° · 우산` · `맑음 · 19° · 큰 일교차`
  - 2x2 · 워치의 말풍선에는 5글자까지만 (비 · 한파 · 폭염), 4x2는 9글자까지 (15~17시 비 · 호우주의보); 더 길면 아이콘만

## 특보 띠 · 눈의 종류

- `alert { name, note }`: 기상청 특보가 있을 때만. 홈 화면 캐릭터 아래, 시간별 위에 띠로 보여요 — "대설주의보 · 오늘 6cm, 18시쯤 그칠 예보", "폭염경보 · 낮 최고 36°, 한낮 외출 줄여요". 위젯·워치에는 자리가 없어 이름만 (호우주의보 · 18° · 우산).
- `precip`: `snow` (눈) · `heavysnow` (시간당 3cm 이상, 말풍선 폭설!) · `sleet` (진눈깨비: 비와 눈이 함께, 양은 mm). 하늘 그림도 따로 — 눈은 큰 눈송이(3·4·5px, 테두리 할로), 많은 눈은 더 촘촘하게, 진눈깨비는 빗줄기와 젖은 눈송이가 함께.
