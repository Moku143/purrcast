"""App Store listing texts for every language the app speaks — the source of docs/store/<locale>.md.

Run `python3 docs/store/listing.py` to check Apple's limits (name / subtitle 30, promotional text 170, keywords 100,
description 4000, subscription display name 30 / description 45) and write the per-language pages.
"""
import os, sys

# App Store Connect locale, app language, then the texts
L = {}

L["ko"] = dict(
    name="그르릉날씨 - 날씨, 기온별 옷차림",
    subtitle="픽셀 친구가 옷 입고 알려주는 날씨",
    promo="체감온도에 맞춰 옷을 갈아입는 픽셀 캐릭터가 오늘 날씨를 알려 줘요. 매일의 날씨와 옷차림은 날씨 달력에 쌓이고, 잠금화면 시계 위에도 옷 입은 캐릭터가 나와요.",
    keywords="고양이,위젯,우산,비알림,체감온도,픽셀,잠금화면,애플워치,날씨달력,예보,기상청,오늘날씨,일교차,미세먼지,코디",
    description="""오늘 뭐 입지? 캐릭터를 보면 알아요.

그르릉날씨는 픽셀 캐릭터가 체감온도에 맞춰 옷을 갈아입고, 비가 오면 우산을 펴서 날씨를 보여 주는 날씨 앱이에요. 숫자를 읽지 않아도 한눈에 오늘 날씨가 보여요. 한국은 기상청, 해외는 Apple 날씨 예보예요.

• 옷 15단계: 민소매부터 롱패딩·털 후드까지, 체감온도에 맞춰 갈아입어요
• 우산 3단계: 지금 비가 오면 우산을 펴고, 곧 올 비는 가방에 챙기고, 애매하면 고민해요
• 비 오는 시간을 미리: "15~17시 비 예보"처럼 알려 줘요
• 날씨 그림: 구름이 흐르고, 비와 눈이 내리고, 별이 반짝이고, 번개가 쳐요
• 시간별 · 10일 예보, 날짜별 상세 그래프(기온 · 체감 · 비 · 바람 · 자외선 · 습도 · 미세먼지)
• 미세먼지 · 초미세먼지, 예보 비교(Apple 날씨 · MET Norway, 한국에서는 기상청까지)
• 홈 화면 위젯과 잠금 화면 위젯
• 잠금 화면 시계 위 한 줄: 옷 입은 캐릭터와 기온 · 위치 · 비 · 자외선 · 일출·일몰 · 바람
• 이번 주 기록: 최근 7일의 날씨와 옷차림
• 홈 카드는 꾹 눌러 원하는 순서로
• 아침 요약 알림
• 12개 언어, °C / °F, 24시간 / 12시간, 픽셀 · 일반 글씨

그르릉날씨 Plus
• 새 예보가 나올 때마다 업데이트
• 가까운 비: 앞으로 6시간, 언제 얼마나 오는지 (Apple 날씨가 분 단위를 주는 곳은 분 단위로)
• 비·눈 1시간 전과 올 때 알림, 잠금 화면 라이브 액티비티
• 기상특보 · 황사 · 미세먼지 · 기온 변화 알림
• 대기질 지도: 통합대기환경지수 · 오염 물질 6종 · 매시간 미세먼지, 잠금 화면 미세먼지 위젯
• 날씨 달력 · 월간 리포트: 매일의 날씨와 옷차림이 달력에 쌓이고, 지난날도 시간별로 다시 보고, 매달 1일 리포트 알림 · 공유 카드
• 애플워치 앱 · 컴플리케이션
• 지역 무제한
• 캐릭터 바꾸기: 아비시니안 · 브리티시숏헤어, 이름 · 말투

날씨 정보: 기상청(공공누리 제1유형), Apple 날씨, MET Norway(CC BY 4.0), 에어코리아(공공누리 제1유형), OpenWeather

구독 안내
Plus는 연간 또는 월간 자동 갱신 구독이에요. 처음 구독하면 무료 체험이 있을 수 있고, 체험이 끝나면 선택한 요금이 Apple 계정으로 결제돼요. 기간이 끝나기 24시간 전까지 해지하지 않으면 자동으로 갱신되고, 해지는 기기의 설정 > Apple 계정 > 구독에서 언제든 할 수 있어요.
이용약관: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
개인정보 처리방침: https://moku143.github.io/purrcast/privacy.html""",
    group="그르릉날씨 Plus",
    yearly="그르릉날씨 Plus 연간",
    monthly="그르릉날씨 Plus 월간",
    iap="가까운 비 · 대기질 · 날씨 달력 · 애플워치 · 캐릭터",
)

L["en-US"] = dict(
    name="Purrcast: Weather & Outfits",
    subtitle="Pixel pets dress for the sky",
    promo="A pixel pet dresses for the feels-like temperature and holds an umbrella in the rain. Every day's weather and outfit fill a calendar, and it waits above your clock.",
    keywords="rain,umbrella,widget,what to wear,forecast,cat,pixel,lock screen,watch,clothes,calendar,cute",
    description="""What should I wear today? Ask your pixel pet.

Purrcast shows the weather through a pixel pet: it changes clothes with the feels-like temperature and opens its umbrella when rain comes. No numbers to read — one look and you know. Forecasts come from Apple Weather worldwide and the Korea Meteorological Administration in Korea.

• 15 outfits, from tank top to fur-hooded puffer
• Umbrella states: raining now, rain later (packed in the bag), maybe
• Rain ahead: "Rain 3–5 PM" — and the umbrella goes in the bag
• Living sky: clouds drift, rain and snow fall, stars twinkle, lightning flashes
• Hourly and 10-day forecast, with detailed charts for each day: temperature, feels-like, rain, wind, UV, humidity, air
• Air quality and forecasts side by side (Apple Weather and MET Norway; in Korea, KMA too)
• Home Screen and Lock Screen widgets
• Above the Lock Screen clock: the dressed character and the temperature, the place, rain, UV, sunrise and sunset, wind
• This week: the last seven days' weather and outfits
• Press and hold a card on Home to move it where you like
• Morning summary
• 12 languages, °C / °F, 24-hour / 12-hour, pixel or plain text

Purrcast Plus
• Updates with every new forecast run
• Next 6 hours of rain: when and how much — minute by minute where Apple Weather offers it
• Alerts an hour before rain or snow and as it starts, with a Lock Screen Live Activity
• Official warnings, poor air and temperature-change alerts
• Air quality map with six pollutants and hourly fine dust, plus a Lock Screen air widget
• Weather calendar and monthly report: every day's weather and outfit saved to a calendar, past days in hourly detail, a report and share card on the 1st of each month
• Apple Watch app and complications
• Unlimited places
• More characters: Abyssinian and British Shorthair, with a name of your own

Weather data: Apple Weather, Korea Meteorological Administration (KOGL Type 1), MET Norway (CC BY 4.0), AirKorea (KOGL Type 1), OpenWeather

Subscriptions
Plus is an auto-renewing yearly or monthly subscription. New subscribers may get a free trial; after it ends, the selected price is charged to your Apple Account. It renews automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel any time in Settings > Apple Account > Subscriptions.
Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://moku143.github.io/purrcast/privacy.html""",
    group="Purrcast Plus",
    yearly="Purrcast Plus Yearly",
    monthly="Purrcast Plus Monthly",
    iap="Rain soon, air, calendar, Watch, characters",
)

if __name__ == "__main__":
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import listing, listing_more  # noqa: F401  (the other languages add themselves to listing.L)
    L = listing.L
    limits = dict(name=30, subtitle=30, promo=170, keywords=100, description=4000, group=30, yearly=30, monthly=30, iap=45)
    bad = 0
    for loc, t in L.items():
        for k, n in limits.items():
            v = t.get(k, "")
            if not v:
                print(f"{loc}: {k} missing"); bad += 1
            elif len(v) > n:
                print(f"{loc}: {k} {len(v)} > {n}"); bad += 1
    print("locales", len(L), "problems", bad)
    out = os.path.dirname(os.path.abspath(__file__))
    for loc, t in L.items():
        with open(os.path.join(out, f"{loc}.md"), "w") as f:
            f.write(f"# {loc}\n\n| 칸 | 값 | 글자 |\n|---|---|---|\n")
            for k, label in [("name", "이름"), ("subtitle", "부제"), ("keywords", "키워드")]:
                f.write(f"| {label} | {t[k]} | {len(t[k])} |\n")
            f.write(f"\n## 프로모션 텍스트 ({len(t['promo'])}자)\n\n```\n{t['promo']}\n```\n")
            f.write(f"\n## 설명 ({len(t['description'])}자)\n\n```\n{t['description']}\n```\n")
            f.write(f"\n## 구독\n\n| 칸 | 값 |\n|---|---|\n| 구독 그룹 표시 이름 | {t['group']} |\n| 연간 표시 이름 | {t['yearly']} |\n| 월간 표시 이름 | {t['monthly']} |\n| 설명 (두 구독 같음, {len(t['iap'])}자) | {t['iap']} |\n")
