# App Store 등록 자료 (복사해서 붙여 넣기용)

App Store Connect → 앱 → 각 칸에 그대로 넣으면 돼요. 글자 수는 Apple 제한 안에 맞춰 두었어요.

## 기본 정보

| 칸 | 값 |
|---|---|
| 이름 (30자) | Purrcast – 옷차림 날씨 |
| 부제 (30자) | 고양이가 입은 옷으로 보는 오늘 날씨 |
| 번들 ID | app.purrcast.ios |
| SKU | purrcast-ios-1 |
| 기본 언어 | 한국어 |
| 카테고리 | 날씨 (보조: 라이프스타일) |
| 연령 등급 | 4+ (설문은 모두 "없음") |
| 가격 | 무료 (앱 내 구독 있음) |
| 개인정보 처리방침 URL | https://moku143.github.io/purrcast/privacy.html |
| 지원 URL | https://moku143.github.io/purrcast/support.html |
| 저작권 | © 2026 Purrcast |

## 프로모션 텍스트 (170자, 언제든 바꿀 수 있어요)

체감온도에 맞춰 옷을 갈아입는 픽셀 고양이가 오늘 날씨를 알려 줘요. 비가 오면 우산을 펴고, 곧 올 비는 가방에 챙겨요.

## 설명

```
오늘 뭐 입지? 고양이를 보면 알아요.

Purrcast는 픽셀 고양이가 체감온도에 맞춰 옷을 갈아입고, 비가 오면 우산을 펴서 날씨를 보여 주는 날씨 앱이에요. 숫자를 읽지 않아도 한눈에 오늘 날씨가 보여요.

• 옷 10단계: 민소매부터 롱패딩까지, 체감온도에 맞춰 갈아입어요
• 우산 3단계: 지금 비가 오면 우산을 펴고, 곧 올 비는 가방에 챙기고, 애매하면 고민해요
• 비 시각은 시계로: "16~18시 비!"처럼 언제 오는지 알려 줘요
• 날씨 그림: 구름, 비, 눈, 바람, 안개, 별, 번개가 화면에서 움직여요
• 시간별 · 10일 예보, 자외선 · 일출 · 일몰 · 습도 · 바람
• 홈 화면 · 잠금 화면 위젯
• 비 오기 전 알림, 아침 요약
• °C / °F, 24시간 / 12시간

Purrcast Plus
• 새 예보가 나올 때마다 업데이트
• 가까운 비: 앞으로 6시간, 언제 얼마나 오는지
• 애플워치 앱 · 컴플리케이션
• 지역 여러 곳
• 캐릭터 바꾸기: 아비시니안 · 브리티시숏헤어

날씨 정보: 기상청(공공누리 제1유형), MET Norway(CC BY 4.0)

구독 안내
Plus는 연간 또는 월간 자동 갱신 구독이에요. 처음 구독하면 무료 체험이 있을 수 있고, 체험이 끝나면 선택한 요금이 Apple 계정으로 결제돼요. 기간이 끝나기 24시간 전까지 해지하지 않으면 자동으로 갱신되고, 해지는 기기의 설정 > Apple 계정 > 구독에서 언제든 할 수 있어요.
이용약관: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
개인정보 처리방침: https://moku143.github.io/purrcast/privacy.html
```

## 키워드 (100자, 쉼표로)

```
날씨,옷차림,고양이,위젯,우산,비,기온,체감온도,픽셀,잠금화면,애플워치,강수,예보,기상청,오늘날씨
```

## 앱 내 구입 (구독)

App Store Connect → 앱 → 구독:

1. 구독 그룹 만들기: 이름 `Purrcast Plus`, 표시 이름(한국어) `Purrcast Plus`
2. 구독 두 개 (ID는 앱 코드와 같아야 해요):

| 참조 이름 | 제품 ID | 기간 | 가격 (대한민국) | 체험 |
|---|---|---|---|---|
| Plus Yearly | `app.purrcast.plus.yearly` | 1년 | 14,900원에 가장 가까운 가격 단계 | 신규 구독자 3일 무료 |
| Plus Monthly | `app.purrcast.plus.monthly` | 1개월 | 1,900원에 가장 가까운 가격 단계 | 신규 구독자 3일 무료 |

3. 각 구독의 현지화(한국어): 표시 이름 `Purrcast Plus 연간` / `Purrcast Plus 월간`, 설명 `가까운 비 · 애플워치 · 캐릭터 · 지역 여러 곳`
4. 심사용 스크린샷: GitHub Actions의 "Store screenshots"에서 나온 Plus 화면을 올려요
5. **첫 심사 때는 구독을 앱 버전과 같이 제출**해야 해요 (버전 페이지의 "앱 내 구입 및 구독"에 두 개 추가)

앱은 가격 · 기간 · 체험 여부를 App Store에서 받아서 보여 주니, 가격을 바꿔도 앱을 고칠 필요가 없어요.

## 앱 개인정보 (개인정보 라벨)

"데이터를 수집합니까?" → **예**

| 데이터 유형 | 수집 | 사용자와 연결 | 추적 | 목적 |
|---|---|---|---|---|
| 위치 · 대략적인 위치 | 예 | 아니요 | 아니요 | 앱 기능 |

그 밖의 항목(연락처, 식별자, 사용 데이터, 진단 등)은 모두 수집 안 함. 결제는 Apple이 처리해요.

## 심사 메모 (App Review Information → Notes)

```
Purrcast is a weather app: a pixel cat changes clothes by the feels-like temperature and holds an umbrella when it rains.

- No login. Location is used only to get the forecast for the current place (rounded to ~1 km); the user can turn it off and pick places instead.
- Weather comes from our own server (KMA 기상청 for Korea, MET Norway elsewhere), credited in Settings > 데이터 출처.
- Purrcast Plus (auto-renewable subscription, yearly / monthly, free trial for new subscribers) unlocks: forecast refresh with every new run, the next-6-hours rain card, the Apple Watch app and complications, unlimited places, and two more characters. Purchase and restore are on the Plus screen (gear icon > Purrcast Plus, or the character button).
- To test Plus, please use a Sandbox account. The Apple Watch app shows its content only with Plus and gets its data from the iPhone app.
```

연락처: 이름 · 전화 · 이메일은 본인 정보로 채워 주세요 (심사팀만 봐요).

## 스크린샷

GitHub → Actions → **Store screenshots** → Run workflow → 끝나면 `store-shots` 브랜치에 6.9인치(1320×2868) 6장이 생겨요. 6.9인치만 올리면 다른 크기는 Apple이 줄여서 써요. 애플워치 스크린샷은 iOS 빌드의 `ci-output` 브랜치 `shots/watch-*.png`.
