import XCTest

/// Launches the app on example weather and saves screenshots as test attachments.
/// CI collects the attachments (ci-output branch) so the screens can be checked against the design canvas.
final class ScreenshotTests: XCTestCase {
    let scenes = ["clear", "maybe", "combo", "tokyo_soon", "spring_rain", "summer_heat", "summer_night", "winter_cold", "winter_snow", "summer_typhoon"]

    override func setUp() { continueAfterFailure = true }   // a simulator hiccup on one picture must not stop the rest

    private func shot(_ name: String, _ args: [String], wait: UInt32 = 1, lang: String = "ko", env: [String: String] = [:], then: ((XCUIApplication) -> Void)? = nil) {
        let app = XCUIApplication()
        for (k, v) in env { app.launchEnvironment[k] = v }
        let locale = ["ko": "ko_KR", "en": "en_US", "ja": "ja_JP", "es": "es_ES", "fr": "fr_FR", "de": "de_DE", "pt-BR": "pt_BR", "it": "it_IT",
                      "id": "id_ID", "ru": "ru_RU", "zh-Hans": "zh_CN", "zh-Hant": "zh_TW"][lang] ?? "en_US"
        app.launchArguments = args + ["-AppleLanguages", "(\(lang))", "-AppleLocale", locale]   // Korean phone by default: 그르릉날씨
        var picture: XCUIScreenshot!
        for attempt in 0..<3 {
            if attempt > 0 { app.terminate(); print("torn picture \(name), again (\(attempt + 1))") }
            app.launch()
            sleep(wait)
            then?(app)
            picture = app.screenshot()
            if Self.torn(picture.image) { sleep(2); picture = app.screenshot() }
            if !Self.torn(picture.image) { break }
        }
        let a = XCTAttachment(screenshot: picture)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
        app.terminate()
    }

    /// The Intel simulator now and then hands back a torn frame: bands of pure black rows across the picture.
    /// (Nothing the app draws is pure black from edge to edge.)
    private static func torn(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return false }
        let w = cg.width, h = cg.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let drawn: Bool = px.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return false }
        // separate bands of black rows (the Dynamic Island grown into a Live Activity is one band, a torn frame many)
        var bands = 0, inBand = false
        for y in stride(from: 0, to: h, by: 2) {
            var black = 0, n = 0
            for x in stride(from: 0, to: w, by: 8) {
                let i = (y * w + x) * 4
                n += 1
                if px[i] < 4 && px[i + 1] < 4 && px[i + 2] < 4 { black += 1 }
            }
            let row = black * 10 > n * 9
            if row && !inBand { bands += 1 }
            inBand = row
        }
        return bands >= 3
    }

    func test1HomeScreens() {
        for (i, key) in scenes.enumerated() {
            let (plan, char) = [("free", "cat"), ("plus", "abys"), ("plus", "brit")][i % 3]
            shot("home-\(key)-\(plan)-\(char)", ["-scene", key, "-char", char] + (plan == "plus" ? ["-plus"] : []))
        }
    }

    func test2Pages() {
        for page in ["character", "paywall", "settings", "places", "widgets", "day", "sources"] {
            shot("page-\(page)-free", ["-scene", "maybe", "-open", page], wait: 2)
        }
        for page in ["character", "settings", "widgets", "day"] {
            shot("page-\(page)-plus-brit", ["-scene", "winter_cold", "-plus", "-char", "brit", "-open", page], wait: 2)
        }
    }

    func test3Scroll() {
        shot("home-scrolled", ["-scene", "maybe", "-plus"]) { app in
            app.swipeUp(); sleep(1)
        }
        // the lower cards: wind dial · 예보 비교 · tiles · footer
        shot("home-cards", ["-scene", "maybe", "-plus"]) { app in
            for _ in 0..<3 { app.swipeUp() }; sleep(1)
        }
        shot("home-bottom", ["-scene", "maybe"]) { app in
            for _ in 0..<6 { app.swipeUp() }; sleep(1)
        }
        // the 미세먼지 card under a 황사 line (spring_dust: 매우 나쁨 / 나쁨)
        // a zoomed display (320 pt wide): the hero scales down, nothing is cut off
        shot("home-narrow", ["-scene", "combo", "-plus", "-char", "brit", "-narrow"])
        // the longest bubble the server sends (미세먼지 매우 나쁨 · 마스크 꼭 챙기세요): the hero must stay the screen's width
        shot("home-dust-top", ["-scene", "spring_dust", "-plus", "-char", "brit"])
        shot("home-smog-top", ["-scene", "winter_smog", "-plus", "-char", "brit"])   // bad air without 황사: the grey sky
        shot("home-dust-top-en", ["-scene", "spring_dust", "-plus", "-char", "brit", "-lang", "en"])
        shot("home-dust-top-ja", ["-scene", "spring_dust", "-plus", "-char", "brit", "-lang", "ja"])
        // the umbrella up: the bubble points at its tip
        shot("home-umbrella-top", ["-scene", "spring_rain", "-plus", "-char", "cat"])
        shot("home-rainsoon-top-ja", ["-scene", "maybe", "-plus", "-char", "abys", "-lang", "ja"])
        // no rain in the six hours but a chance in the hourly forecast: the card says both
        shot("home-next6-dry", ["-scene", "clear", "-plus"])
        // a typhoon hour past 15mm: the top line rises to it
        shot("home-next6-heavy", ["-scene", "summer_typhoon", "-plus"])
        shot("home-dust", ["-scene", "spring_dust", "-plus"]) { app in
            for _ in 0..<2 { app.swipeUp() }; sleep(1)
        }
        // the day sheet's 미세먼지 tab (today's readings, Plus) and the 자외선 tab with its five-step scale
        shot("day-dust", ["-scene", "spring_dust", "-plus", "-open", "today"], wait: 2) { app in   // the readings are today's
            app.buttons["tab-dust"].firstMatch.tap(); sleep(1); app.swipeUp(); sleep(1)
        }
        // tomorrow's sheet: the 미세먼지 tab with the step forecast and the scale (no chart yet)
        shot("day-dust-tomorrow", ["-scene", "spring_dust", "-plus", "-open", "day"], wait: 2) { app in
            app.buttons["tab-dust"].firstMatch.tap(); sleep(1)
        }
        // abroad (OpenWeather, WHO steps): the same tab
        shot("day-dust-jp", ["-scene", "tokyo_soon", "-plus", "-open", "today"], wait: 2) { app in
            app.buttons["tab-dust"].firstMatch.tap(); sleep(1)
        }
        shot("day-uv", ["-scene", "summer_heat", "-plus", "-open", "day"], wait: 2) { app in
            app.buttons["tab-uv"].firstMatch.tap(); sleep(1); app.swipeUp(); sleep(1)
        }
    }

    func test4Onboarding() {
        shot("onboarding-1", ["-scene", "maybe", "-onboarding"])
        shot("onboarding-2", ["-scene", "maybe", "-onboarding"]) { app in app.buttons["next"].tap(); sleep(1) }
        shot("onboarding-3", ["-scene", "maybe", "-onboarding"]) { app in app.buttons["next"].tap(); sleep(1); app.buttons["next"].tap(); sleep(1) }
        shot("onboarding-4", ["-scene", "maybe", "-onboarding", "-onbStep", "3"], wait: 2)
    }

    /// Plus page on the watch slide; settings at the 언어 row; the character sheet's 말투 (Plus).
    func test7NewParts() {
        shot("page-paywall-watch", ["-scene", "maybe", "-open", "paywall"], wait: 2) { app in
            for _ in 0..<2 { app.swipeLeft(); sleep(1) }
        }
        shot("page-settings-language", ["-scene", "maybe", "-plus", "-open", "settings"], wait: 2) { app in
            app.swipeUp(); sleep(1)
        }
        shot("page-character-voice", ["-scene", "maybe", "-plus", "-char", "abys", "-open", "character"], wait: 2) { app in
            app.swipeUp(); sleep(1)
        }
        // place search: empty field, a country (lists its regions), a 시도, a foreign name typed in Korean
        for (name, q) in [("empty", ""), ("usa", "미국"), ("seoul", "서울"), ("california", "캘리포니아")] {
            shot("search-\(name)", ["-scene", "maybe", "-plus", "-open", "places"], wait: 2) { app in
                app.buttons["search"].firstMatch.tap(); sleep(1)
                if !q.isEmpty { app.textFields["search-field"].firstMatch.typeText(q); sleep(2) }
            }
        }
        for (lang, key, q) in [("en", "us", "United States"), ("ja", "us", "アメリカ"), ("ja", "jp", "日本")] {
            shot("search-\(lang)-\(key)", ["-scene", "maybe", "-plus", "-open", "places"], wait: 2, lang: lang) { app in
                app.buttons["search"].firstMatch.tap(); sleep(1)
                app.textFields["search-field"].firstMatch.typeText(q); sleep(2)
            }
        }
        for lang in ["en", "ja"] {
            shot("lang-\(lang)-paywall-watch", ["-scene", "maybe", "-open", "paywall"], wait: 2, lang: lang) { app in
                for _ in 0..<2 { app.swipeLeft(); sleep(1) }
            }
            shot("lang-\(lang)-home-cards", ["-scene", "maybe", "-plus"], lang: lang) { app in
                for _ in 0..<3 { app.swipeUp() }; sleep(1)
            }
            shot("lang-\(lang)-character", ["-scene", "maybe", "-plus", "-char", "abys", "-open", "character"], wait: 2, lang: lang)
        }
    }

    /// The new pixel font everywhere, 언어 · Language in settings, the licence page and the TestFlight test trial.
    func test8FontLanguageTrial() {
        shot("f-settings-top", ["-scene", "maybe", "-open", "settings"], wait: 2)
        shot("f-language", ["-scene", "maybe", "-open", "language"], wait: 2)
        shot("f-language-en", ["-scene", "maybe", "-open", "language"], wait: 2) { app in
            app.buttons["lang-en"].firstMatch.tap(); sleep(2)
        }
        shot("f-licenses", ["-scene", "maybe", "-open", "licenses"], wait: 2)
        shot("f-app-icon", ["-scene", "maybe", "-open", "appIcon"], wait: 2)
        shot("f-app-icon-plus", ["-scene", "maybe", "-plus", "-open", "appIcon"], wait: 2)
        shot("f-paywall-test", ["-scene", "maybe", "-open", "paywall"], wait: 3) { app in
            app.swipeUp(); sleep(1)
        }
        shot("f-after-test-trial", ["-scene", "maybe", "-open", "paywall"], wait: 3) { app in
            app.swipeUp(); sleep(1)
            app.buttons["subscribe"].firstMatch.tap(); sleep(2)
            app.buttons["settings"].firstMatch.tap(); sleep(2)
        }
        shot("f-onb-watch", ["-scene", "maybe", "-onboarding"]) { app in
            for _ in 0..<3 { app.buttons["next"].firstMatch.tap(); sleep(1) }
        }
        // from the location page (-onbStep 5: the calendar page came before it, so four "next" taps no longer reach it)
        shot("f-onb-alerts-off", ["-scene", "maybe", "-onboarding", "-onbStep", "5"], wait: 2) { app in
            app.buttons["나중에 · 서울로 볼게요"].firstMatch.tap(); sleep(1)
            app.switches.element(boundBy: 0).tap(); sleep(1)
            app.switches.element(boundBy: 1).tap(); sleep(1)
        }
        shot("f-home", ["-scene", "maybe", "-plus", "-char", "abys"])
        shot("f-home-cards", ["-scene", "maybe", "-plus"]) { app in
            for _ in 0..<3 { app.swipeUp() }; sleep(1)
        }
        shot("f-day", ["-scene", "spring_rain", "-plus", "-open", "day"], wait: 2)
        for lang in ["en", "ja"] {
            shot("f-\(lang)-home", ["-scene", "maybe", "-plus", "-char", "brit"], lang: lang)
            shot("f-\(lang)-day", ["-scene", "maybe", "-plus", "-open", "day"], wait: 2, lang: lang)
        }
    }

    /// The same app on an English and a Japanese phone (strings, sample scenes, 話し方).
    func test6Languages() {
        for lang in ["en", "ja"] {
            shot("lang-\(lang)-home", ["-scene", "maybe", "-plus", "-char", "brit"], lang: lang)
            shot("lang-\(lang)-snow", ["-scene", "winter_snow", "-plus", "-char", "abys"], lang: lang)
            shot("lang-\(lang)-settings", ["-scene", "maybe", "-plus", "-char", "brit", "-open", "settings"], wait: 2, lang: lang)
            shot("lang-\(lang)-day", ["-scene", "maybe", "-plus", "-open", "day"], wait: 2, lang: lang)
            shot("lang-\(lang)-paywall", ["-scene", "maybe", "-open", "paywall"], wait: 2, lang: lang)
            shot("lang-\(lang)-onboarding", ["-scene", "maybe", "-onboarding"], lang: lang)
        }
    }

    /// App Store screenshots: the store workflow runs this on the 6.9" simulator (iPhone 16 Pro Max).
    func test5StoreShots() {
        shot("store-1-home", ["-scene", "maybe", "-char", "cat"])
        shot("store-2-rain", ["-scene", "spring_rain", "-plus", "-char", "abys"])
        shot("store-3-snow", ["-scene", "winter_snow", "-plus", "-char", "brit"])
        shot("store-4-characters", ["-scene", "summer_heat", "-plus", "-char", "brit", "-open", "character"], wait: 2)
        shot("store-5-widgets", ["-scene", "maybe", "-plus", "-char", "cat", "-open", "widgets"], wait: 2)
        shot("store-6-day", ["-scene", "clear", "-plus", "-char", "abys", "-open", "day"], wait: 2)
    }

    /// The App Store pictures (6.9-inch simulator: 1320 × 2868), the caption and the app's own views, in each language
    func test11StoreFrames() {
        let pages: [(Int, [String])] = [
            (1, ["-scene", "clear", "-char", "cat"]),
            (2, ["-scene", "clear", "-char", "cat"]),
            (3, ["-scene", "clear", "-char", "cat"]),
            (4, ["-scene", "maybe", "-plus", "-char", "cat"]),
            (5, ["-scene", "seoul_soon", "-plus", "-char", "cat"]),
            (6, ["-scene", "maybe", "-char", "cat"]),
            (7, ["-scene", "spring_dust", "-plus", "-char", "cat"]),
            (8, ["-scene", "maybe", "-plus", "-char", "cat"]),          // 날씨 달력 · 월간 리포트 (Plus)
            (9, ["-scene", "maybe", "-plus", "-char", "cat"]),          // the lock screen and the home screen
            (10, ["-scene", "spring_rain", "-plus", "-char", "cat"]),
        ]
        // every language the app speaks (STORE_LANGS="ko en" takes a few)
        let all = ["ko", "en", "ja", "es", "fr", "de", "pt-BR", "it", "id", "ru", "zh-Hans", "zh-Hant"]
        let langs = ProcessInfo.processInfo.environment["STORE_LANGS"].map { $0.split(separator: " ").map(String.init) } ?? all
        for lang in langs {
            for (n, args) in pages { shot("frame-\(lang)-\(n)", args + ["-storeShot", String(n)], wait: 3, lang: lang) }
        }
    }

    /// iOS's note when the icon changes: set plainly ("loud") it shows; when the icon follows a character ("quiet") it
    /// should not. The attachment names say whether an alert was found in the app (app1) or on SpringBoard (sb1).
    func test9IconNote() {
        for mode in ["loud", "quiet", "loud", "quiet"].enumerated() {
            let app = XCUIApplication()
            app.launchArguments = ["-iconTest", mode.element, "-scene", "clear", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
            app.launch()
            let inApp = app.alerts.firstMatch.waitForExistence(timeout: 5)
            let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.exists
            let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            a.name = "icon-note-\(mode.offset)-\(mode.element)-app\(inApp ? 1 : 0)-sb\(sb ? 1 : 0)"
            a.lifetime = .keepAlways
            add(a)
            print("ICONTEST \(mode.element) app=\(inApp) springboard=\(sb)")
            app.terminate()
        }
    }

    /// The layout board: each screen's screenshot and every element on it with its frame (points), as
    /// layout-<screen>.png + layout-<screen>.json. Scrolling screens are taken at a few scroll positions.
    func test12AirMap() {
        // 대기질 (Plus) on home between 미세먼지 and 바람, and its sheet; map tiles given time to load
        shot("home-air", ["-scene", "winter_smog", "-plus"], wait: 2) { app in
            for _ in 0..<2 { app.swipeUp() }; sleep(5)
        }
        shot("home-air-2", ["-scene", "winter_smog", "-plus"], wait: 2) { app in
            for _ in 0..<3 { app.swipeUp() }; sleep(5)
        }
        shot("air-sheet", ["-scene", "winter_smog", "-plus", "-open", "air"], wait: 6)
        shot("air-sheet-2", ["-scene", "winter_smog", "-plus", "-open", "air"], wait: 4) { app in
            app.swipeUp(); sleep(2)
        }
        shot("air-sheet-jp", ["-scene", "tokyo_soon", "-plus", "-open", "air", "-place", "tokyo"], wait: 6, lang: "ja")
        shot("air-sheet-en-2", ["-scene", "tokyo_soon", "-plus", "-open", "air", "-place", "tokyo"], wait: 4, lang: "en") { app in
            app.swipeUp(); sleep(2)
        }
    }

    func test13Skies() {
        // every sky by air (clean · 미세먼지 · 황사), by day and by night, and the home screen on a 미세먼지 day and a 황사경보 day
        shot("skylab-day", ["-scene", "clear", "-open", "skyLab"], wait: 2)
        shot("skylab-night", ["-scene", "clear", "-open", "skyLab", "-skyNight"], wait: 2)
        shot("home-smog", ["-scene", "winter_smog", "-plus", "-char", "cat"], wait: 2)
        shot("home-yellow", ["-scene", "spring_dust", "-plus", "-char", "cat"], wait: 2)
        shot("home-yellow-2", ["-scene", "spring_dust", "-plus", "-char", "cat"], wait: 2) { app in app.swipeUp(); sleep(1) }
        // the island's short alerts: rain, snow, 황사경보, 미세먼지, a 경보
        shot("livelab-alerts", ["-scene", "spring_rain", "-plus", "-char", "cat", "-open", "liveLab"], wait: 2)
        shot("livelab-alerts-2", ["-scene", "spring_rain", "-plus", "-char", "cat", "-open", "liveLab"], wait: 2) { app in app.swipeUp(); sleep(1) }
    }

    func test14Alerts() {
        // every warning the home screen can show: the bubble over the character and the line under it
        for p in 1...6 { shot("alertlab-\(p)", ["-scene", "clear", "-open", "alertLab", "-alertPage", String(p)], wait: 2) }
        // and the home screen itself on the example days that carry one
        for s in ["summer_monsoon", "summer_heat", "summer_typhoon", "winter_cold", "winter_snow", "spring_dust"] {
            shot("alerthome-\(s)", ["-scene", s, "-char", "cat"], wait: 2)
        }
    }

    func test15WidgetAir() {
        // the home-screen widgets and the watch on a 황사 day (기상청 황사경보) and on a 미세먼지 day (smog, no 황사)
        shot("widgetlab-yellow", ["-scene", "spring_dust", "-plus", "-char", "cat", "-open", "widgetLab"], wait: 2)
        shot("widgetlab-smog", ["-scene", "winter_smog", "-plus", "-char", "cat", "-open", "widgetLab"], wait: 2)
    }

    /// The Apple Watch App Store faces (on a 2× phone: cut out at 416 × 496): the analog and the modular face with the
    /// complications, on the 장맛비 day, in every language the app speaks (STORE_LANGS="ko en" takes a few)
    func test16WatchStore() {
        let all = ["ko", "en", "ja", "es", "fr", "de", "pt-BR", "it", "id", "ru", "zh-Hans", "zh-Hant"]
        let langs = ProcessInfo.processInfo.environment["STORE_LANGS"].map { $0.split(separator: " ").map(String.init) } ?? all
        for lang in langs {
            for face in ["analog", "modular"] {
                let args = ["-scene", "summer_monsoon", "-plus", "-char", "cat", "-watchFace", face, "-storeTime", "10:09"] + (lang == "en" ? ["-clock12"] : [])
                shot("watchface-\(lang)-\(face)", args, wait: 2, lang: lang)
            }
        }
    }

    /// Plus page now (alerts an hour before, the 대기질 page), the English 미세먼지 card ("Fine dust"), a free 황사 day
    func test17PlusCheck() {
        for lang in ["ko", "en", "ja"] {
            shot("plus-\(lang)-alerts", ["-scene", "maybe", "-open", "paywall"], wait: 3, lang: lang) { app in
                for _ in 0..<2 { app.swipeLeft(); sleep(1) }
            }
            shot("plus-\(lang)-air", ["-scene", "maybe", "-open", "paywall"], wait: 3, lang: lang) { app in
                for _ in 0..<3 { app.swipeLeft(); sleep(1) }
                sleep(3)
            }
        }
        shot("en-dust-card", ["-scene", "maybe", "-plus"], wait: 2, lang: "en") { app in
            for _ in 0..<2 { app.swipeUp() }; sleep(2)
        }
        shot("en-day-dust", ["-scene", "spring_dust", "-plus", "-open", "today"], wait: 2, lang: "en") { app in
            app.buttons["tab-dust"].firstMatch.tap(); sleep(1); app.swipeUp(); sleep(1)
        }
        shot("free-yellow", ["-scene", "spring_dust", "-char", "cat"], wait: 2)
        shot("free-promo", ["-scene", "maybe", "-char", "cat"], wait: 2) { app in
            for _ in 0..<6 { app.swipeUp() }; sleep(1)
        }
    }

    /// Small sheet buttons take a tap next to their letters too (a 44-pt area): 설정's 완료 tapped above its text and
    /// the Plus page's ✕ tapped to its right each close their sheet. (Before the 44-pt area, both taps missed.)
    func test19TapAreas() {
        for (open, dx, dy) in [("settings", 0.0, -18.0), ("paywall", 18.0, 0.0)] {
            let app = XCUIApplication()
            app.launchArguments = ["-scene", "maybe", "-open", open, "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
            app.launch()
            let close = app.buttons["sheet-close"]
            XCTAssertTrue(close.waitForExistence(timeout: 15), open)
            sleep(2)
            let f = close.frame
            close.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: dx, dy: dy)).tap()
            let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: close)
            wait(for: [gone], timeout: 6)
            XCTAssertFalse(close.exists, "\(open): a tap \(dx), \(dy) pt from the centre of the \(f.width) × \(f.height) pt close button did not close the sheet")
        }
    }

    /// The calendar rework's captures, under stable names (ci-output then holds them in calendar-rework/):
    /// the trip month in three languages, a future December, 설날 2027, the outfit tab, both day sheets, the
    /// report, the narrowest width and the largest text size
    func test21CalendarRework() {
        // a Korean user's device clock: today, future days and their holidays follow the device's own time zone
        let kst = ["TZ": "Asia/Seoul"]
        let cal = ["-scene", "maybe", "-plus", "-open", "calendar", "-calTrip"]
        shot("cr-ko-nov2026-trip", cal, wait: 3, env: kst)
        shot("cr-ko-dec2026", cal + ["-calMonth", "1"], wait: 3, env: kst)
        // February 2027: 설날 and its 연휴 (the short names under red numbers)
        let toFeb2027 = (2027 - Calendar.current.component(.year, from: Date())) * 12 + (2 - Calendar.current.component(.month, from: Date()))
        shot("cr-ko-feb2027", cal + ["-calMonth", String(toFeb2027)], wait: 3, env: kst)
        shot("cr-ja", cal, wait: 3, lang: "ja", env: kst)
        shot("cr-en", cal, wait: 3, lang: "en", env: kst)
        shot("cr-outfits", cal + ["-calOutfits"], wait: 3, env: kst)
        shot("cr-day-sheet-seoul", cal + ["-calDay", "1"], wait: 3, env: kst)
        shot("cr-day-sheet-tokyo", cal + ["-calDay", "3"], wait: 3, env: kst)
        shot("cr-report", cal, wait: 3, env: kst) { app in app.swipeUp(); app.swipeUp(); sleep(1) }
        shot("cr-narrow", ["-scene", "maybe", "-plus", "-calTrip", "-narrowCal"], wait: 3, env: kst)
        shot("cr-narrow-feb2027", ["-scene", "maybe", "-plus", "-calTrip", "-narrowCal", "-calMonth", String(toFeb2027)], wait: 3, env: kst)
        shot("cr-large-text", cal + ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"], wait: 3, env: kst)
    }

    /// The 날씨 달력 page scrolls up (the report below the month stays reachable), the sideways month swipe still
    /// turns the month, and a past month's page scrolls too. Outfit cells make the page taller than any iPhone.
    func test20CalendarScroll() {
        let app = XCUIApplication()
        app.launchArguments = ["-scene", "maybe", "-plus", "-open", "calendar", "-calOutfits", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        let bar = app.buttons["cal-month"].firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 20), "the calendar did not open")
        sleep(2)
        let keep = { (name: String) in
            let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; self.add(a)
        }
        let y0 = bar.frame.minY
        app.swipeUp()
        sleep(1)
        let moved = y0 - bar.frame.minY
        keep("cal-scroll-this")
        XCTAssertGreaterThan(moved, 60, "this month's page did not scroll up (moved \(moved) pt)")
        // the sideways swipe still turns the month (back, from wherever the page is scrolled)
        let title0 = bar.label
        app.swipeRight()
        sleep(2)
        XCTAssertNotEqual(bar.label, title0, "the sideways swipe no longer turns the month")
        // and the past month, its 리포트 below, scrolls the same way
        app.swipeDown()
        sleep(1)
        let y1 = bar.frame.minY
        app.swipeUp()
        sleep(1)
        let movedPast = y1 - bar.frame.minY
        keep("cal-scroll-last")
        XCTAssertGreaterThan(movedPast, 60, "the past month's page did not scroll up (moved \(movedPast) pt)")
    }

    /// First run with the 이전 button, the fuller widget and watch pages; the merged rain slide of the Plus page
    func test18Onboard() {
        for lang in ["ko", "en", "ja"] {
            for st in 0...7 { shot("onb-\(lang)-\(st)", ["-scene", "spring_rain", "-onboarding", "-onbStep", String(st)], wait: 3, lang: lang) }
            shot("plus-\(lang)-rain", ["-scene", "maybe", "-open", "paywall"], wait: 3, lang: lang) { app in app.swipeLeft(); sleep(2) }
        }
        shot("onb-back", ["-scene", "spring_rain", "-onboarding", "-onbStep", "2"], wait: 3) { app in app.buttons["back"].firstMatch.tap(); sleep(1) }
    }

    func test10Layout() {
        var screens: [(String, [String], Int)] = [
            ("home-1", ["-scene", "maybe", "-plus", "-char", "cat"], 0),
            ("home-2", ["-scene", "maybe", "-plus", "-char", "cat"], 1),
            ("home-3", ["-scene", "maybe", "-plus", "-char", "cat"], 3),
            ("home-rain", ["-scene", "spring_rain", "-plus", "-char", "cat"], 0),
            ("day", ["-scene", "maybe", "-plus", "-open", "day"], 0),
            ("day-2", ["-scene", "maybe", "-plus", "-open", "day"], 1),
            ("settings-1", ["-scene", "maybe", "-plus", "-open", "settings"], 0),
            ("settings-2", ["-scene", "maybe", "-plus", "-open", "settings"], 2),
            ("character", ["-scene", "maybe", "-plus", "-open", "character"], 0),
            ("places", ["-scene", "maybe", "-plus", "-open", "places"], 0),
            ("widgets", ["-scene", "maybe", "-plus", "-open", "widgets"], 0),
            ("paywall", ["-scene", "maybe", "-open", "paywall"], 0),
            ("appicon", ["-scene", "maybe", "-open", "appIcon"], 0),
            ("sources", ["-scene", "maybe", "-open", "sources"], 0),
            ("sources-2", ["-scene", "maybe", "-open", "sources"], 2),
            ("widgetlab", ["-scene", "spring_rain", "-plus", "-char", "cat", "-open", "widgetLab"], 0),
            ("widgetlab-dust", ["-scene", "spring_dust", "-plus", "-char", "cat", "-open", "widgetLab"], 0),
            ("widgetlab-dust-en", ["-scene", "spring_dust", "-plus", "-char", "cat", "-open", "widgetLab", "-lang", "en"], 0),
            ("widgetlab-dust-ja", ["-scene", "spring_dust", "-plus", "-char", "cat", "-open", "widgetLab", "-lang", "ja"], 0),
            ("watchlab", ["-scene", "spring_rain", "-plus", "-char", "cat", "-open", "widgetLab", "-labPage3"], 0),
            ("watchlab-dust", ["-scene", "spring_dust", "-plus", "-char", "cat", "-open", "widgetLab", "-labPage3"], 0),
            ("locklab", ["-scene", "spring_dust", "-plus", "-char", "cat", "-open", "widgetLab", "-labPage4"], 0),
            ("locklab-en", ["-scene", "spring_dust", "-plus", "-char", "cat", "-open", "widgetLab", "-labPage4", "-lang", "en"], 0),
            ("locklab-ja", ["-scene", "spring_dust", "-plus", "-char", "cat", "-open", "widgetLab", "-labPage4", "-lang", "ja"], 0),
            ("livelab", ["-scene", "spring_rain", "-plus", "-char", "cat", "-open", "liveLab"], 0),
            ("widgetlab-2", ["-scene", "spring_rain", "-plus", "-char", "cat", "-open", "widgetLab", "-labPage2"], 0),
        ]
        // the 날씨 달력's farthest month, December four years on (through 2030 now): holidays may show, nothing invented
        let toLastDecember = (4 * 12) + (12 - Calendar.current.component(.month, from: Date()))
        screens.append(("cal-future", ["-scene", "maybe", "-plus", "-open", "calendar", "-calMonth", String(toLastDecember)], 0))
        // the widgets three hours after the app last ran: the forecast aged by the clock, nothing repeated as "now"
        screens.append(("widgetlab-aged", ["-scene", "spring_rain", "-plus", "-char", "cat", "-open", "widgetLab", "-labAged"], 0))
        // a past day from the calendar: the summary and the 미세먼지 tab speak in the past tense
        screens.append(("cal-past-day", ["-scene", "maybe", "-plus", "-open", "calendar", "-calDay", "1"], 0))
        screens.append(("cal-past-dust", ["-scene", "maybe", "-plus", "-open", "calendar", "-calDay", "1", "-calTab", "dust"], 0))
        // the widgets in English and Japanese, and with the longest words each language can produce
        let lab = ["-scene", "spring_rain", "-plus", "-char", "cat", "-open", "widgetLab"]
        // before the app has handed over anything: every widget, lock-screen line and complication without numbers
        for (name, page) in [("widgetlab-waiting", []), ("widgetlab-2-waiting", ["-labPage2"]), ("watchlab-waiting", ["-labPage3"]),
                             ("locklab-waiting", ["-labPage4"]), ("inlinelab-waiting", ["-labPage5"])] {
            screens.append((name, lab + page + ["-labWaiting"], 0))
        }
        let langs = [("ko", ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]), ("en", ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]),
                     ("ja", ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"])]
        for (code, la) in langs {
            if code != "ko" {
                screens.append(("widgetlab-\(code)", lab + la, 0))
                screens.append(("widgetlab-2-\(code)", lab + ["-labPage2"] + la, 0))
            }
            screens.append(("widgetlab-stress-\(code)", lab + ["-labStress"] + la, 0))
            screens.append(("widgetlab-2-stress-\(code)", lab + ["-labPage2", "-labStress"] + la, 0))
        }
        for (name, args, swipes) in screens {
            let app = XCUIApplication()
            app.launchArguments = args.contains("-AppleLanguages") ? args : args + ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
            app.launch()
            sleep(2)
            for _ in 0..<swipes { app.swipeUp() }
            if swipes > 0 { sleep(1) }
            let png = app.screenshot().pngRepresentation
            var items: [[String: Any]] = []
            func walk(_ e: XCUIElementSnapshot, _ depth: Int) {
                let f = e.frame
                if f.width >= 1, f.height >= 1, f.width.isFinite, f.height.isFinite {
                    items.append(["type": Int(e.elementType.rawValue), "id": e.identifier, "label": e.label,
                                  "value": e.value.map { "\($0)" } ?? "", "x": Double(f.minX), "y": Double(f.minY),
                                  "w": Double(f.width), "h": Double(f.height), "depth": depth])
                }
                for c in e.children { walk(c, depth + 1) }
            }
            if let snap = try? app.snapshot() { walk(snap, 0) }
            let screen = app.frame
            let doc: [String: Any] = ["screen": name, "w": Double(screen.width), "h": Double(screen.height), "elements": items]
            let shot = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
            shot.name = "layout-\(name)"; shot.lifetime = .keepAlways; add(shot)
            if let json = try? JSONSerialization.data(withJSONObject: doc) {
                let a = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
                a.name = "layout-\(name)"; a.lifetime = .keepAlways; add(a)
            }
            app.terminate()
        }
    }
}
