# Purrcast 날씨 서버

기상청 + Apple WeatherKit + MET Norway 예보를 받아서 앱이 그대로 그리는 JSON 하나로 만들어 주는 작은 서버예요.
Cloudflare Workers 무료 플랜(하루 10만 요청)에서 돌아가고, 코드 의존성이 없어요.

- 한국: 기상청 단기예보 (Plus는 초단기실황 · 초단기예보 · 기상특보까지), 4~10일째와 자외선은 MET Norway
- 그 밖: Apple WeatherKit (현재 · 시간별 · 일별 · 1시간 분 단위 비(`minutes`, 지원 국가만) · 기상 경보). 키가 없으면 MET Norway
- 한쪽이 안 되면 다른 쪽으로 이어서 답해요 (기상청 · WeatherKit 키가 없거나 멈춰도 MET로 동작)
- 응답 형식: `../docs/server-api.md` · 판단 규칙: `src/rules.js` (디자인 킷 규칙 그대로)

## 연결하기 (한 번만, 약 20분)

1. **기상청 키** (무료, 승인 1~2일)
   [공공데이터포털](https://www.data.go.kr)에서 로그인 → 아래 세 개를 각각 "활용신청":
   - 기상청_단기예보 ((구)_동네예보) 조회서비스
   - 기상청_기상특보 조회서비스
   승인되면 마이페이지 → 인증키의 **Decoding 키**를 복사해요.

2. **Cloudflare** (무료)
   [cloudflare.com](https://dash.cloudflare.com/sign-up) 가입 → 오른쪽 위 프로필 → My Profile → API Tokens →
   Create Token → 템플릿 "Edit Cloudflare Workers" → 만들기 → 토큰 복사.
   대시보드 오른쪽 아래 **Account ID**도 복사.

3. **GitHub에 넣기**
   저장소 Settings → Secrets and variables → Actions → New repository secret:
   - `CLOUDFLARE_API_TOKEN` = 2번 토큰
   - `CLOUDFLARE_ACCOUNT_ID` = 2번 Account ID
   - `KMA_SERVICE_KEY` = 1번 Decoding 키 (없으면 한국도 MET Norway로 동작)
   - `AIRKOREA_SERVICE_KEY` = 같은 data.go.kr 키 (에어코리아 대기오염정보·측정소정보·미세먼지 경보 활용신청 후). 없으면 한국 미세먼지 카드가 안 나와요
   - `OPENWEATHER_KEY` = OpenWeather API 키 (해외 미세먼지, 무료 플랜). 없으면 해외 미세먼지 카드가 안 나와요
   - `WEATHERKIT_KEY_ID`, `WEATHERKIT_KEY_P8`, `APPLE_TEAM_ID` = 아래 **Apple WeatherKit** (없으면 한국 밖은 MET Norway로 동작)

3-1. **Apple WeatherKit 키** (유료 개발자 계정에 포함, 한 달 50만 호출 무료)
   - [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list) → Identifiers → App ID `app.purrcast.ios`의
     Capabilities에서 **WeatherKit** 체크 (App Services 탭도).
   - Keys → 새 키 → **WeatherKit** 체크 → 만들기 → `.p8` 파일 내려받기 (한 번만 받을 수 있어요). 화면의 **Key ID**(10자)를 메모.
   - GitHub secrets: `WEATHERKIT_KEY_ID` = Key ID, `WEATHERKIT_KEY_P8` = `.p8` 파일 내용 전체 (`-----BEGIN PRIVATE KEY-----`부터
     `-----END PRIVATE KEY-----`까지, 줄바꿈 그대로), `APPLE_TEAM_ID` = 팀 ID (`9865Z67LR4`, TestFlight 워크플로가 이미 쓰는 secret).
     서비스 ID는 번들 ID와 같아서 `wrangler.toml`의 `WEATHERKIT_SERVICE_ID = "app.purrcast.ios"`로 들어가요.
   - 키를 만든 직후 몇 시간은 401이 날 수 있어요 (Apple 쪽 반영). 그동안은 MET Norway로 답해요.
   - **표기 의무**: WeatherKit 데이터를 보여 주는 화면에는 "Weather data provided by  Weather"(Apple Weather 마크 또는 글자)와
     [법적 고지 링크](https://weatherkit.apple.com/legal-attribution.html)를 두어야 해요 — 앱의 데이터 출처 화면에 MET Norway · 기상청과 나란히.

4. **배포**
   Actions → **Server** → Run workflow. 끝나면 로그의 "Deploy" 단계에 주소가 나와요:
   `https://purrcast.oo0785.workers.dev` (지금 올라가 있는 주소)
   브라우저로 `…/health`를 열어 `{"ok":true,"kma":true,"weatherkit":true}`가 보이면 끝.

5. **앱에 연결**
   같은 Settings 화면의 **Variables** 탭 → New repository variable → `SERVER_URL` = 4번 주소.
   TestFlight 빌드가 이 주소를 앱에 넣어요 (주소가 없거나 응답이 없으면 빌드가 멈춰요 — 예시 날씨로 출시되는 일이 없게).

## 확인

- `node --test test/*.test.js` — 가짜 응답으로 규칙 · 합치기 · 실패 대응 · 앱 형식 검사 (GitHub가 올릴 때마다 실행)
- `node scripts/live-check.mjs` — 실제 MET Norway(+ 키가 있으면 기상청 · WeatherKit)로 서울 · 제주 · 도쿄 · 뉴욕 · 레이캬비크를 받아 형식 검사. 결과는 `server-output` 브랜치의 `live.txt` (마지막 줄에 도쿄 · 뉴욕이 어느 소스를 썼는지)
- `node scripts/make-fixtures.mjs` — 앱 단위 테스트가 쓰는 서버 응답 견본을 다시 만들어요

## 사용자가 늘면 (권장)

- **내 도메인 연결**: workers.dev 주소에서는 Cloudflare 공용 캐시가 꺼져 있어서, 지금은 서버 메모리 캐시만 써요.
  사용자가 많아지면 도메인(연 1~2만 원)을 Cloudflare에 연결하고 `wrangler.toml`에
  `routes = [{ pattern = "api.내도메인", custom_domain = true }]`를 넣으면 공용 캐시까지 켜져요.
  MET Norway는 앱 전체로 초당 20회 이하, 기상청 개발 계정은 하루 1만 회라 캐시가 중요해요.
- **연락처**: MET Norway는 User-Agent에 연락처를 원해요. `wrangler.toml`의 `CONTACT`에 이메일을 넣어 주세요.
- **첫 배포 직후**: `…/health?deep=1`을 열면 MET · 기상청 · WeatherKit에 실제로 한 번씩 물어보고 결과(`met: 200`, `kma: NORMAL_SERVICE`, `weatherkit: 200` 또는 `"no key"`)를 보여 줘요.
  키 등록 오류(`30 SERVICE_KEY_IS_NOT_REGISTERED_ERROR`)는 승인 후 1~2시간 뒤에 풀리기도 해요.

## 선택: "전일 대비"

어제 같은 시각 기온과 비교하려면 기록이 필요해요. `npx wrangler kv namespace create HISTORY`로 만든 id를
`wrangler.toml`의 `[[kv_namespaces]]`에 넣으면 켜져요. 없으면 0(같음)으로 보여요.
