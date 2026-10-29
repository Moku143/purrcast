import XCTest

/// Launches the app on example weather and saves screenshots as test attachments.
/// CI collects the attachments (ci-output branch) so the screens can be checked against the design canvas.
final class ScreenshotTests: XCTestCase {
    let scenes = ["clear", "maybe", "combo", "tokyo_soon", "spring_rain", "summer_heat", "summer_night", "winter_cold", "winter_snow", "summer_typhoon"]

    private func shot(_ name: String, _ args: [String], wait: UInt32 = 1, lang: String = "ko", then: ((XCUIApplication) -> Void)? = nil) {
        let app = XCUIApplication()
        let locale = ["ko": "ko_KR", "en": "en_US", "ja": "ja_JP"][lang] ?? "en_US"
        app.launchArguments = args + ["-AppleLanguages", "(\(lang))", "-AppleLocale", locale]   // Korean phone by default: 그르릉날씨
        app.launch()
        sleep(wait)
        then?(app)
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
        app.terminate()
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
    }

    func test4Onboarding() {
        shot("onboarding-1", ["-scene", "maybe", "-onboarding"])
        shot("onboarding-2", ["-scene", "maybe", "-onboarding"]) { app in app.buttons["next"].tap(); sleep(1) }
        shot("onboarding-3", ["-scene", "maybe", "-onboarding"]) { app in app.buttons["next"].tap(); sleep(1); app.buttons["next"].tap(); sleep(1) }
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
            for _ in 0..<2 { app.buttons["next"].firstMatch.tap(); sleep(1) }
        }
        shot("f-onb-alerts-off", ["-scene", "maybe", "-onboarding"]) { app in
            for _ in 0..<3 { app.buttons["next"].firstMatch.tap(); sleep(1) }
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
    func test10Layout() {
        let screens: [(String, [String], Int)] = [
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
            ("widgetlab", ["-scene", "spring_rain", "-plus", "-char", "cat", "-open", "widgetLab"], 0),
            ("widgetlab-2", ["-scene", "spring_rain", "-plus", "-char", "cat", "-open", "widgetLab", "-labPage2"], 0),
        ]
        for (name, args, swipes) in screens {
            let app = XCUIApplication()
            app.launchArguments = args + ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
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
