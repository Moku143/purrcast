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
        let pages: [(Int, [String])] = [                                // strongest first (StoreShotView's order)
            (1, ["-scene", "clear", "-char", "cat"]),                   // hero
            (2, ["-scene", "clear", "-char", "cat"]),                   // outfits
            (3, ["-scene", "maybe", "-plus", "-char", "cat"]),          // rain alert (Plus)
            (4, ["-scene", "maybe", "-plus", "-char", "cat"]),          // 날씨 달력 · 월간 리포트 (Plus)
            (5, ["-scene", "clear", "-char", "cat"]),                   // skies
            (6, ["-scene", "seoul_soon", "-plus", "-char", "cat"]),     // next 6 hours (Plus)
            (7, ["-scene", "maybe", "-char", "cat"]),                   // ten days
            (8, ["-scene", "spring_dust", "-plus", "-char", "cat"]),    // dust (Plus)
            (9, ["-scene", "maybe", "-plus", "-char", "cat"]),          // the lock screen and the home screen
            (10, ["-scene", "spring_rain", "-plus", "-char", "cat"]),   // watch (Plus)
        ]
        // every language the app speaks (STORE_LANGS="ko en" takes a few)
        let all = ["ko", "en", "ja", "es", "fr", "de", "pt-BR", "it", "id", "ru", "zh-Hans", "zh-Hant"]
        let langs = ProcessInfo.processInfo.environment["STORE_LANGS"].map { $0.split(separator: " ").map(String.init) } ?? all
        for lang in langs {
            // the language's real default clock (AppModel gives a fresh English install 12h): the harness
            // otherwise launches everyone on 24h, and the English pictures mixed 16:00 with 4PM
            let clock = lang == "en" ? ["-clock12"] : []
            for (n, args) in pages {
                shot("frame-\(lang)-\(n)", args + clock + ["-storeShot", String(n)], wait: 3, lang: lang) { app in
                    // the hero page's four bubbles must sit whole on the canvas in every language: the
                    // picture fails here rather than shipping with a word cut at the edge
                    guard n == 1 else { return }
                    let w = app.windows.firstMatch.frame
                    for i in 1...4 {
                        let bubble = app.descendants(matching: .any)["hero-bubble-\(i)"].firstMatch
                        XCTAssertTrue(bubble.waitForExistence(timeout: 5), "hero bubble \(i) missing (\(lang))")
                        let f = bubble.frame
                        XCTAssertTrue(f.minX >= w.minX + 8 && f.maxX <= w.maxX - 8,
                                      "hero bubble \(i) leaves the canvas (\(lang)): \(f) in \(w)")
                    }
                }
            }
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
        // 이 달 머문 곳, option B: last month toured five countries + 서울 twice — the folded country rows,
        // then every row opened to its cities (-calStaysOpen)
        let world = ["-scene", "maybe", "-plus", "-open", "calendar", "-calWorld", "-calMonth", "-1"]
        shot("cr-stays", world, wait: 3, env: kst) { app in app.swipeUp(); sleep(1) }
        shot("cr-stays-open", world + ["-calStaysOpen"], wait: 3, env: kst) { app in app.swipeUp(); sleep(1) }
        shot("cr-stays-en", world, wait: 3, lang: "en", env: kst) { app in app.swipeUp(); sleep(1) }
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
        // a diagonal drag from the top of the scroll, decided sideways once, early, and held until release:
        // the month turns, the page does not scroll with it, and the sheet is not pulled down
        let t0 = bar.label
        let yTop = bar.frame.minY
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.30))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.42)))
        sleep(2)
        keep("cal-diagonal")
        XCTAssertTrue(bar.exists, "the diagonal drag pulled the sheet down")
        XCTAssertNotEqual(bar.label, t0, "the diagonal drag did not turn the month")
        XCTAssertLessThan(abs(bar.frame.minY - yTop), 10, "the sideways drag also scrolled the page")
        // a day still opens on a tap, and its sheet still closes
        app.swipeRight()
        sleep(2)
        XCTAssertEqual(bar.label, t0, "the swipe back did not return to this month")
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let day = app.buttons["cal-\(df.string(from: Date()))"].firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5), "today's cell is missing")
        day.tap()
        sleep(2)
        XCTAssertFalse(bar.isHittable, "the day sheet did not open on a tap")
        // closed by its own 닫기: a mid-screen swipe scrolls the day sheet's charts, it does not pull the sheet
        let dayClose = app.buttons.matching(identifier: "sheet-close").allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(dayClose, "the day sheet has no reachable 닫기")
        dayClose?.tap()
        sleep(2)
        XCTAssertTrue(bar.isHittable, "the day sheet did not close")
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

    /// The calendar sheet's pull-to-close, back since build 66's feedback: a downward pull at the top closes it
    /// (or springs back when let go early), a pull while scrolled only moves the list, and a sideways drag turns
    /// the month without the sheet moving at all
    func test22CalendarDismiss() {
        let args = ["-scene", "maybe", "-plus", "-open", "calendar", "-calOutfits", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        var app = XCUIApplication()
        app.launchArguments = args
        app.launch()
        let keep = { (name: String) in
            let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; self.add(a)
        }
        var bar = app.buttons["cal-month"].firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 20), "the calendar did not open")
        sleep(2)

        // (1) a sideways drag at the top: the month turns alone — no scroll, and the sheet stays put
        let t0 = bar.label, x0 = bar.frame.minY
        keep("g1-sideways-before")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.35))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.35)))
        sleep(2)
        keep("g1-sideways-after")
        XCTAssertTrue(bar.exists, "the sideways drag pulled the sheet down")
        XCTAssertNotEqual(bar.label, t0, "the sideways drag did not turn the month")
        XCTAssertLessThan(abs(bar.frame.minY - x0), 10, "the sideways drag moved the page (\(abs(bar.frame.minY - x0)) pt)")
        app.swipeRight()
        sleep(2)
        XCTAssertEqual(bar.label, t0, "the swipe back did not return to this month")

        // (2a) a short, slow pull at the top, let go early: the sheet springs back instead of closing
        keep("g2-pull-early-before")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)), withVelocity: 120, thenHoldForDuration: 0.4)
        sleep(2)
        keep("g2-pull-early-after")
        XCTAssertTrue(bar.exists && bar.isHittable, "an early-released pull closed the sheet")
        XCTAssertLessThan(abs(bar.frame.minY - x0), 10, "the sheet did not spring back after an early release")

        // (5) an upward drag at the top: the page scrolls (or rubber-bands), the sheet stays
        app.swipeUp()
        sleep(1)
        keep("g5-up-at-top-after")
        XCTAssertTrue(bar.exists, "an upward drag at the top closed the sheet")
        app.swipeDown()
        sleep(1)

        // (6) a tap on today's date still opens the day sheet, and its 닫기 still closes it
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let day = app.buttons["cal-\(df.string(from: Date()))"].firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5), "today's cell is missing")
        day.tap()
        sleep(2)
        keep("g6-day-tap-after")
        XCTAssertFalse(bar.isHittable, "the day sheet did not open on a tap")
        let dayClose = app.buttons.matching(identifier: "sheet-close").allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(dayClose, "the day sheet has no reachable 닫기")
        dayClose?.tap()
        sleep(2)
        XCTAssertTrue(bar.isHittable, "the day sheet did not close")

        // (3) with the list scrolled down, a downward drag only moves the list — the sheet stays up
        app.swipeUp()
        sleep(1)
        let yScrolled = bar.frame.minY
        XCTAssertGreaterThan(x0 - yScrolled, 60, "the page did not scroll for the scrolled-pull case")
        keep("g3-scrolled-pull-before")
        app.swipeDown()
        sleep(2)
        keep("g3-scrolled-pull-after")
        XCTAssertTrue(bar.exists && bar.isHittable, "a pull on the scrolled list closed the sheet")
        XCTAssertGreaterThan(bar.frame.minY - yScrolled, 60, "the pull did not scroll the list back")

        // (2b) back at the top, a long pull closes the calendar
        keep("g2-pull-close-before")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        sleep(2)
        keep("g2-pull-close-after")
        XCTAssertFalse(bar.exists, "a full pull down did not close the calendar")

        // (4) a diagonal drag, decided sideways once, early: the month turns and the sheet survives
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = args
        app.launch()
        bar = app.buttons["cal-month"].firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 20), "the calendar did not reopen")
        sleep(2)
        let t1 = bar.label, y1 = bar.frame.minY
        keep("g4-diagonal-before")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.30))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.42)))
        sleep(2)
        keep("g4-diagonal-after")
        XCTAssertTrue(bar.exists, "the diagonal drag pulled the sheet down")
        XCTAssertNotEqual(bar.label, t1, "the diagonal drag did not turn the month")
        XCTAssertLessThan(abs(bar.frame.minY - y1), 10, "the diagonal drag also scrolled the page")
    }

    /// The round temperature gauge at one, two and three characters, negatives included: the real lock-screen
    /// circle and the real watch gauge each draw one clean number (the onboarding's doubled digits were the demo
    /// cross-fade, fixed by fading through), and the onboarding's lock page for the preview side
    func test23LockGauge() {
        shot("gauge-widgets", ["-scene", "maybe", "-open", "widgetLab", "-labGauge"], wait: 3) { app in
            for t in ["5", "16", "m5", "m12"] {
                XCTAssertTrue(app.descendants(matching: .any)["lab-gauge-\(t)"].firstMatch.waitForExistence(timeout: 5),
                              "lock gauge \(t) missing")
                XCTAssertTrue(app.descendants(matching: .any)["lab-watch-gauge-\(t)"].firstMatch.exists,
                              "watch gauge \(t) missing")
            }
        }
        shot("gauge-preview-onboarding", ["-scene", "maybe", "-onboarding", "-onbStep", "2"], wait: 4)
    }

    /// The Plus page as App Review will see it, in English: the StoreKit configuration's prices on the plan
    /// cards and the real purchase button. The test-mode button appears only when no products load, so this
    /// test only means anything under review-shot.yml, whose test plan loads the StoreKit configuration.
    func test24ReviewPaywall() {
        shot("review-plus-en", ["-scene", "maybe", "-open", "paywall"], wait: 3, lang: "en") { app in
            // the configuration carries a price per storefront, so the runner's storefront picks the currency
            let price = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", ".*[₩$€£¥].*")).firstMatch
            XCTAssertTrue(price.waitForExistence(timeout: 25), "no price loaded from the StoreKit configuration")
            let buy = app.buttons["subscribe"].firstMatch
            XCTAssertTrue(buy.waitForExistence(timeout: 5), "no purchase button")
            XCTAssertFalse(buy.label.lowercased().contains("test"), "the paywall still offers the test Plus: \(buy.label)")
            XCTAssertTrue(buy.isEnabled, "the purchase button is disabled")
            sleep(2)
        }
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
