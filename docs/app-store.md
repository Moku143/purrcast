# App Store 등록 자료 (복사해서 붙여 넣기용)

App Store Connect → 앱 → 각 칸에 그대로 넣으면 돼요. 글자 수는 모두 Apple 제한 안이에요 (`python3 docs/store/listing.py`가 확인하고 언어별 페이지를 다시 만들어요).

## 언어 12개

**기본 언어는 영어(미국)**, 나머지 11개를 추가해요. 언어마다 이름 · 부제 · 프로모션 텍스트 · 설명 · 키워드 · 구독 표시 이름이 한 페이지에 있어요.

| App Store Connect 언어 | 앱 언어 | 이름 | 부제 | 페이지 |
|---|---|---|---|---|
| 영어(미국) — 기본 | en | Purrcast: Weather & Outfits | Pixel pets dress for the sky | [store/en-US.md](store/en-US.md) |
| 한국어 | ko | 그르릉날씨 - 날씨, 기온별 옷차림 | 픽셀 친구가 옷 입고 알려주는 날씨 | [store/ko.md](store/ko.md) |
| 일본어 | ja | ゴロゴロ天気 - 天気と服装 | ドット絵のキャラが着替えて伝える天気 | [store/ja.md](store/ja.md) |
| 스페인어(스페인) | es | Purrcast: Tiempo y Ropa | Una mascota pixel que se viste | [store/es-ES.md](store/es-ES.md) |
| 프랑스어 | fr | Purrcast : Météo et Tenues | Un ami pixel qui s’habille | [store/fr-FR.md](store/fr-FR.md) |
| 독일어 | de | Purrcast: Wetter & Outfits | Pixel-Freunde im Wetter-Outfit | [store/de-DE.md](store/de-DE.md) |
| 포르투갈어(브라질) | pt-BR | Purrcast: Clima e Roupas | Um amigo pixel que se veste | [store/pt-BR.md](store/pt-BR.md) |
| 이탈리아어 | it | Purrcast: Meteo e Outfit | Un amico pixel che si veste | [store/it.md](store/it.md) |
| 인도네시아어 | id | Purrcast: Cuaca & Pakaian | Teman piksel berbaju cuaca | [store/id.md](store/id.md) |
| 러시아어 | ru | Purrcast: погода и одежда | Пиксельный друг одет по погоде | [store/ru.md](store/ru.md) |
| 중국어(간체) | zh-Hans | Purrcast：天气穿搭 | 像素角色换装告诉你天气 | [store/zh-Hans.md](store/zh-Hans.md) |
| 중국어(번체) | zh-Hant | Purrcast：天氣穿搭 | 像素角色換裝告訴你天氣 | [store/zh-Hant.md](store/zh-Hant.md) |

- 스페인어(멕시코) · 영어(영국) 등 같은 말의 다른 지역도 추가하고 싶으면 위 페이지를 그대로 복사해 넣으면 돼요 (앱은 지역과 상관없이 같은 말로 나와요).
- 목록에 없는 언어의 나라에서는 기본 언어인 영어가 보여요. 앱도 같아요: 기기 언어가 12개 중 하나면 그 말, 아니면 영어.
- 홈 화면 아이콘 아래 이름: 한국어 아이폰 **그르릉날씨**, 일본어 아이폰 **ゴロゴロ天気**, 그 밖은 **Purrcast** (`Shared/Localization/*/InfoPlist.strings`).
- 홍보 문구에는 "고양이" 대신 **캐릭터 · 픽셀 친구**로 써 두었어요. 키워드에는 검색량 때문에 고양이(cat · 猫 …)를 남겼어요.
- 키워드 칸이 글자가 아니라 바이트로 세져서 넘친다고 나오면 뒤에서부터 빼 주세요.

## 기본 정보

| 칸 | 값 |
|---|---|
| 번들 ID | app.purrcast.ios |
| SKU | purrcast-ios-1 |
| 카테고리 | 날씨 (보조: 라이프스타일) |
| 연령 등급 | 4+ (설문은 모두 "없음") |
| 가격 | 무료 (앱 내 구독 있음) |
| 개인정보 처리방침 URL | https://moku143.github.io/purrcast/privacy.html |
| 지원 URL | https://moku143.github.io/purrcast/support.html |
| 저작권 | © 2026 Purrcast |

## 앱 내 구입 (구독)

App Store Connect → 앱 → 구독:

1. 구독 그룹 만들기: 참조 이름 `Purrcast Plus`, 표시 이름은 언어별 페이지의 "구독 그룹 표시 이름"
2. 구독 두 개 (ID는 앱 코드와 같아야 해요):

| 참조 이름 | 제품 ID | 기간 | 가격 (대한민국) | 체험 |
|---|---|---|---|---|
| Plus Yearly | `app.purrcast.plus.yearly` | 1년 | 19,000원에 가장 가까운 가격 단계 | 신규 구독자 3일 무료 |
| Plus Monthly | `app.purrcast.plus.monthly` | 1개월 | 2,500원에 가장 가까운 가격 단계 | 신규 구독자 3일 무료 |

3. 각 구독의 현지화: 12개 언어 모두 언어별 페이지 맨 아래 "구독" 표 (표시 이름 · 설명 55자 안)
4. 심사용 스크린샷: Plus 화면 (`store-frames` 브랜치의 2번 · 9번처럼 Plus가 보이는 장, 또는 앱의 Plus 화면 캡처)
5. **첫 심사 때는 구독을 앱 버전과 같이 제출**해야 해요 (버전 페이지의 "앱 내 구입 및 구독"에 두 개 추가)

앱은 가격 · 기간 · 체험 여부를 App Store에서 받아서 보여 주니, 가격을 바꿔도 앱을 고칠 필요가 없어요. (가격은 ChatGPT · Gemini와 다시 논의 중)

## 앱 개인정보 (개인정보 라벨)

"데이터를 수집합니까?" → **예**

| 데이터 유형 | 수집 | 사용자와 연결 | 추적 | 목적 |
|---|---|---|---|---|
| 위치 · 대략적인 위치 | 예 | 예 | 아니요 | 앱 기능 |
| 식별자 · 기기 ID | 예 | 예 | 아니요 | 앱 기능 |

왜 "연결 예"인가: 비 알림(Live Activity)을 앱을 열지 않아도 보내려고, 서버가 앱이 만든 무작위 기기 ID와 약 1km 좌표 · 푸시 토큰을 함께 45일 동안 보관해요(`server/src/push.js`). 이름 · Apple ID와는 관계없지만 Apple 기준으로는 기기와 연결된 데이터라 "예"가 안전해요.
날씨 달력 기록(매일의 날씨 · 옷차림 · 저장된 위치 이름)은 **기기 안에만** 저장돼요. Plus를 쓰는 날, 앱이나 위젯이 받은 날씨로만 쌓이고 서버에서 지난날을 채우지 않아요.
달력의 공휴일은 서버에서 나라 코드(예: KR)로만 받아요. 위치는 보내지 않아요.
그 밖의 항목(연락처, 사용 데이터, 진단 등)은 모두 수집 안 함. 결제는 Apple이 처리해요.

## 심사 메모 (App Review Information → Notes)

```
Purrcast (Korean name: 그르릉날씨) is a weather app: a pixel character changes clothes by the feels-like temperature and holds an umbrella when it rains. The app is in 12 languages.

- No login. Location is used only to get the forecast for the current place (rounded to ~1 km); the user can turn it off and pick places instead. Widgets may use the location too, to show the weather where the phone is.
- Weather comes from our own server: KMA 기상청 for Korea (with Apple Weather for the later hours), Apple Weather (WeatherKit) elsewhere, MET Norway for the forecast comparison; air quality from AirKorea (Korea) and OpenWeather (elsewhere). Credited in Settings > Data sources.
- Widgets: Home Screen (small, medium, hourly), Lock Screen (circular and rectangular) and the line above the Lock Screen clock (the dressed character with the temperature, the place, rain, UV, sunrise/sunset, wind, air, or all in one line).
- Weather calendar (Plus): each day used with Plus, the day's weather and outfit is saved on the device only, at the place where the phone was at midnight. Nothing is filled in from the server. A monthly report notification comes on the 1st.
- For the rain alert on the Lock Screen / Dynamic Island, the app registers a random device ID, the place rounded to ~1 km and an ActivityKit push token with our server; it is deleted after 45 days without a check-in.
- Purrcast Plus (auto-renewable subscription, yearly / monthly, free trial for new subscribers) unlocks: forecast refresh with every new run, the next-6-hours rain card, short Live Activity alerts (rain or snow an hour before and as it starts, official warnings, poor air, temperature changes), the air quality map with hourly fine dust readings and the Lock Screen air widget, the weather calendar and monthly report, the Apple Watch app and complications, unlimited places, and two more characters. Purchase and restore are on the Plus screen (gear icon > Purrcast Plus, or the character button).
- To test Plus, please use a Sandbox account. The Apple Watch app shows its content only with Plus and gets its data from the iPhone app.
```

연락처: 이름 · 전화는 본인 정보, 이메일은 `oo0785@daum.net` (심사팀만 봐요).

## 스크린샷

GitHub → Actions → **Store screenshots** → Run workflow (언어 칸을 비우면 12개 모두) → 끝나면 `store-frames` 브랜치에 `<언어>/01.png … 10.png`가 생겨요. 6.9인치(1320×2868)만 올리면 다른 크기는 Apple이 줄여서 써요.

| 장 | 내용 |
|---|---|
| 1 | 오늘 뭐 입지 |
| 2 | 옷차림 15단계 |
| 3 | 날씨별 하늘 |
| 4 | 비 알림 |
| 5 | 다음 6시간 (Plus) |
| 6 | 10일 예보 |
| 7 | 미세먼지 · 대기질 (Plus) |
| 8 | 날씨 달력 · 월간 리포트 (Plus) |
| 9 | 홈 화면 · 잠금화면 위젯 · 시계 위 한 줄 |
| 10 | 애플워치 (Plus) |

애플워치 스크린샷은 Actions → **Watch store screenshots**.
