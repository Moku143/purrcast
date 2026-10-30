# Purrcast

옷차림으로 보는 날씨. 픽셀 캐릭터(고양이 · 아비시니안 · 브리티시숏헤어)가 체감온도에 맞춰 옷을 입고, 비가 오면 우산을 챙겨요.

## 확인하는 법 (맥 없이)

`main`에 올라오면 GitHub가 Mac에서 앱을 빌드하고, 아이폰 · 애플워치 시뮬레이터에서 화면을 찍어요.

* **Actions** 탭 → 맨 위 실행이 초록색이면 빌드 성공
* 찍힌 화면은 **`ci-output` 브랜치**의 `shots/` 폴더 (`home-…`, `page-…`, `onboarding-…`, `watch-…`)
* 에러가 있으면 같은 브랜치의 `errors.txt`

## 구조

| 폴더 | 내용 |
|---|---|
| `Purrcast/` | 아이폰 앱 (홈 · 날짜 상세 · 지역 · 설정 · 캐릭터 · Plus · 온보딩) |
| `PurrcastWidgets/` | 홈 화면 · 잠금 화면 위젯 |
| `PurrcastWatch/`, `PurrcastWatchWidgets/` | 애플워치 앱 · 컴플리케이션 (Plus) |
| `Shared/` | 셋이 같이 쓰는 코드 · 캐릭터 그림 · 아이콘 · 글꼴 · 예시 날씨 |
| `Config/` | 권한(App Group) · 결제 테스트 파일 |
| `docs/` | 서버 API 약속(`server-api.md`), 개인정보 처리방침(`privacy.html`) |

## 날씨 데이터

지금은 디자인의 **예시 날씨**(`Shared/Data/scenes.json`)로 돌아가요. 서버가 생기면 `project.yml`의
`PurrcastServerURL` 세 곳(앱 · 위젯 · 워치)에 주소만 넣으면 실제 날씨로 바뀌어요. 서버가 돌려줄 모양은
[`docs/server-api.md`](docs/server-api.md).

## 결제

StoreKit 2. 상품 ID `app.purrcast.plus.yearly`(19,000원) · `app.purrcast.plus.monthly`(2,500원), 둘 다 3일 무료.
App Store Connect에 같은 ID로 만들면 그대로 동작해요.

## 출시 전에 남은 것

1. Apple Developer Program 가입 → App Store Connect에 앱 · 구독 · App Group(`group.app.purrcast`, `group.app.purrcast.watch`) 등록
2. 서명 정보를 GitHub Secrets에 넣고 TestFlight 업로드 단계 켜기
3. 저장소 Settings → Pages → `main` / `docs` (개인정보 처리방침 주소)
4. 날씨 서버 (맨 마지막)

## 개발자용

```
brew install xcodegen && xcodegen generate && open Purrcast.xcodeproj
```
시뮬레이터 실행 인자: `-scene maybe -plus -char brit -open settings` (예시 날씨 · Plus · 캐릭터 · 바로 열 화면)
