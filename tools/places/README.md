# Place search index (`Purrcast/Resources/places.json`)

The 지역 search in the iPhone app (not the widgets or the watch) looks in this bundled file first and asks Apple Maps
(`MKLocalSearchCompleter`) for everything else. `Purrcast/App/PlaceIndex.swift` reads it; `build.py` writes it.

## Sources and licences

| Part | Source | Licence |
|---|---|---|
| Countries and their states / provinces / prefectures, with Korean, English and Japanese names, coordinates, time zones | [countries-states-cities-database](https://github.com/dr5hn/countries-states-cities-database) by dr5hn (`json/countries.json`, `json/states.json`) | [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/) |
| Japan's 47 prefectures: consistent names (東京都 · 도쿄도 · Tokyo) | written in `build.py` | — |
| Korea: 시도 · 시군구 · 읍면동 with coordinates | 기상청 단기예보 조회서비스, 격자 · 위경도 목록 (the xlsx in the API guide) | 공공데이터 (출처: 기상청) |
| English names of Korean places | `romanize.py` (Revised Romanization, from the Hangul names) | — |

**ODbL.** `places.json` is a derived database of countries-states-cities-database, so it is shared under the
ODbL 1.0 as well: it is here in this repository, in full, under the same licence, and anyone may take it. The app
shows the attribution in 설정 → 데이터 출처 → 그 밖에 ("지역 이름: countries-states-cities-database (ODbL 1.0) ·
기상청 격자 위경도"). Keep both if the file is changed or moved.

## Rebuilding

```
# countries-states-cities-database: only the two files used (the full repository is large)
git clone --depth 1 --filter=blob:none --sparse https://github.com/dr5hn/countries-states-cities-database csc
git -C csc sparse-checkout set --no-cone /json/countries.json /json/states.json

# 기상청 격자 · 위경도 xlsx: 공공데이터포털 (data.go.kr) → 기상청_단기예보 조회서비스 → 참고문서,
# the API guide zip ("…오픈API활용가이드…zip"); the list is the xlsx inside it ("…격자_위경도….xlsx").

pip install openpyxl
python3 tools/places/build.py csc/json/countries.json csc/json/states.json <격자_위경도.xlsx>
```

It prints the counts and the size (about 250 countries, 5,300 regions, 3,800 Korean places, 1.1 MB). Then run the
unit tests (`PurrcastTests`, the place search tests check a few known places and orders).

## Layout

```
{"v": 1, "src": "…",
 "countries": [[iso2, ko, en, ja, native, lat, lon, tz, [aliases]], …],
 "regions":   [[iso3166-2, country iso2, ko, en, ja, native, lat, lon, tz, parent iso3166-2], …],
 "kr":        [[KMA code, 시도, 시군구, 읍면동, lat, lon, 시도 short, 시도 en, 시도 ja, 시군구 romanized, 읍면동 romanized], …]}
```

Korea comes only from the 기상청 list (the regions list has no `KR-` rows). A 시군구 split into 구 is written
"수원시 장안구"; 세종 has no 시군구 (its 읍면동 sit right under the 시도).

## How the app uses it

- Ids that survive a language change: `kr:<KMA code>`, `rg:<ISO 3166-2>` (a country without regions: `rg:<ISO2>`).
  Apple Maps picks are `mk:<lat>,<lon>` (3 decimals) and keep the name they were added with.
- Names in the app's language: Korea "서울 마포구" · "Mapo-gu, Seoul" · "ソウル Mapo-gu"; elsewhere
  "캘리포니아, 미국" · "California, United States" · "カリフォルニア, アメリカ合衆国".
- A country, 시도 or 시군구 typed in full lists everything under it, in the language's order: Korean ㄱㄴㄷ, English
  A–Z, Japanese with Japan's prefectures in JIS order (北海道 → 沖縄県) and Korea in 기상청 code order.
