import XCTest

/// The review catalog (catalog workflow): every screen of the app on every example weather, in one language per run.
/// CATALOG_LANG ko | en | ja (xcodebuild passes TEST_RUNNER_CATALOG_LANG through), CATALOG_PART a | b.
/// Attachments are named "<section>.<case>.<nn>" (nn: the scroll position, 00 = top) for the catalog page.
final class CatalogTests: XCTestCase {
    static let scenes = ["clear", "maybe", "combo", "tokyo_soon", "seoul_soon", "spring_chill", "spring_dust", "winter_smog", "spring_rain",
                         "summer_monsoon", "summer_night", "summer_heat", "summer_typhoon", "winter_eve", "winter_cold", "winter_snow"]
    private var env: [String: String] { ProcessInfo.processInfo.environment }
    private var lang: String { env["CATALOG_LANG"] ?? "ko" }
    private var part: String { env["CATALOG_PART"] ?? "a" }

    override func setUp() { continueAfterFailure = true }

    private func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        let locale = ["ko": "ko_KR", "en": "en_US", "ja": "ja_JP"][lang] ?? "en_US"
        // an English phone reads hours as 3PM (the app's default there); Korean and Japanese as 15시 / 15時
        let clock = lang == "en" && !args.contains("-clock12") ? ["-clock12"] : []
        app.launchArguments = args + clock + ["-AppleLanguages", "(\(lang))", "-AppleLocale", locale]
        app.launch()
        return app
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        // no dots: the exporter reads ".03" as a file extension and drops it
        a.name = name.replacingOccurrences(of: ".", with: "~")
        a.lifetime = .keepAlways
        add(a)
    }

    /// One launch: the top, then a picture after each swipe up.
    private func seq(_ name: String, _ args: [String], swipes: Int = 0, wait: UInt32 = 2, before: ((XCUIApplication) -> Void)? = nil) {
        let app = launch(args)
        sleep(wait)
        before?(app)
        attach(app, "\(name).00")
        if swipes > 0 {
            for i in 1...swipes {
                app.swipeUp(); sleep(1)
                attach(app, String(format: "%@.%02d", name, i))
            }
        }
        app.terminate()
    }

    /// One launch, pictures taken by the caller in order.
    private func steps(_ name: String, _ args: [String], wait: UInt32 = 2, _ body: (XCUIApplication, () -> Void) -> Void) {
        let app = launch(args)
        sleep(wait)
        var n = 0
        body(app) { self.attach(app, String(format: "%@.%02d", name, n)); n += 1 }
        app.terminate()
    }

    private func tap(_ app: XCUIApplication, _ id: String) {
        let b = app.buttons[id].firstMatch
        if b.waitForExistence(timeout: 2) { b.tap(); sleep(1) }
    }

    func testCatalog() {
        if part == "a" { partA() } else { partB() }
    }

    // MARK: the weather — home (Plus · free, top to bottom), the other characters, the day sheets

    private func partA() {
        for s in Self.scenes {
            seq("home-plus.\(s)", ["-scene", s, "-plus", "-char", "cat"], swipes: 7)
            seq("home-free.\(s)", ["-scene", s, "-char", "cat"], swipes: 6)
            seq("char-abys.\(s)", ["-scene", s, "-plus", "-char", "abys"])
            seq("char-brit.\(s)", ["-scene", s, "-plus", "-char", "brit"])
            seq("day-today.\(s)", ["-scene", s, "-plus", "-open", "today"], swipes: 2)
            seq("day-next.\(s)", ["-scene", s, "-plus", "-open", "day"], swipes: 1)
        }
        // every tab of the day sheet: Korea with 미세먼지, abroad, a stormy day
        for s in ["spring_dust", "tokyo_soon", "summer_typhoon"] {
            for t in ["temp", "feels", "rain", "wind", "uv", "humidity", "dust"] {
                seq("day-tab.\(s)-\(t)", ["-scene", s, "-plus", "-open", "today"], swipes: 1) { app in self.tap(app, "tab-\(t)") }
            }
        }
        // later days (no hours that far out), and the free day sheet
        for s in ["maybe", "tokyo_soon"] {
            for d in [3, 6, 9] { seq("day-later.\(s)-\(d)", ["-scene", s, "-plus", "-open", "day\(d)"], swipes: 1) }
        }
        seq("day-free.maybe", ["-scene", "maybe", "-open", "today"], swipes: 2)
        seq("day-free.spring_dust", ["-scene", "spring_dust", "-open", "today"], swipes: 2)
    }

    // MARK: everything else — first run, Plus, settings and its pages, places, 대기질, notices, labs, widgets

    private func partB() {
        for st in 0...6 { seq("onboarding.\(st)", ["-scene", "maybe", "-onboarding", "-onbStep", String(st)], wait: 3) }

        // Plus: every slide, then down to the prices; and the page when Plus is on
        steps("paywall.free", ["-scene", "maybe", "-open", "paywall"], wait: 3) { app, take in
            take()
            for _ in 0..<6 { app.swipeLeft(); sleep(1); take() }
            for _ in 0..<2 { app.swipeUp(); sleep(1); take() }
        }
        seq("paywall.plus", ["-scene", "maybe", "-plus", "-open", "paywall"], swipes: 2, wait: 3)

        seq("settings.free", ["-scene", "maybe", "-open", "settings"], swipes: 5)
        seq("settings.plus", ["-scene", "maybe", "-plus", "-char", "abys", "-open", "settings"], swipes: 5)
        seq("pages.character-free", ["-scene", "maybe", "-open", "character"], swipes: 2)
        seq("pages.character-plus", ["-scene", "maybe", "-plus", "-char", "abys", "-open", "character"], swipes: 2)
        seq("pages.places-free", ["-scene", "maybe", "-open", "places"], swipes: 1)
        seq("pages.places-plus", ["-scene", "maybe", "-plus", "-open", "places"], swipes: 1)
        let queries = ["ko": ["서울", "미국", "도쿄"], "en": ["Seoul", "United States", "Tokyo"], "ja": ["ソウル", "アメリカ", "東京"]][lang] ?? []
        steps("search.empty", ["-scene", "maybe", "-plus", "-open", "places"]) { app, take in
            self.tap(app, "search"); take()
        }
        for (i, q) in queries.enumerated() {
            steps("search.q\(i + 1)", ["-scene", "maybe", "-plus", "-open", "places"]) { app, take in
                self.tap(app, "search")
                let f = app.textFields["search-field"].firstMatch
                if f.waitForExistence(timeout: 2) { f.typeText(q); sleep(2) }
                // the keyboard's one-time "slide to type" tip
                let tip = app.buttons["Continue"].firstMatch
                if tip.exists { tip.tap(); sleep(1) }
                take()
            }
        }
        seq("pages.language", ["-scene", "maybe", "-open", "language"], swipes: 1)
        seq("pages.licenses", ["-scene", "maybe", "-open", "licenses"], swipes: 3)
        seq("pages.appicon-free", ["-scene", "maybe", "-open", "appIcon"], swipes: 1)
        seq("pages.appicon-plus", ["-scene", "maybe", "-plus", "-open", "appIcon"], swipes: 1)
        seq("pages.sources", ["-scene", "maybe", "-open", "sources"], swipes: 4)
        seq("pages.widgets", ["-scene", "maybe", "-plus", "-open", "widgets"], swipes: 4)
        seq("air.korea", ["-scene", "winter_smog", "-plus", "-open", "air"], swipes: 2, wait: 7)
        seq("air.abroad", ["-scene", "tokyo_soon", "-plus", "-open", "air", "-place", "tokyo"], swipes: 2, wait: 7)
        for n in ["stale", "fail", "loading"] { seq("notice.\(n)", ["-scene", "maybe", "-plus", "-notice", n], wait: 3) }

        // the labs: every sky, every warning, the island, every widget on every weather
        seq("sky.day", ["-scene", "clear", "-open", "skyLab"])
        seq("sky.night", ["-scene", "clear", "-open", "skyLab", "-skyNight"])
        for p in 1...8 { seq("alerts.\(p)", ["-scene", "clear", "-open", "alertLab", "-alertPage", String(p)]) }
        seq("live.lab", ["-scene", "spring_rain", "-plus", "-char", "cat", "-open", "liveLab"], swipes: 2)
        for s in Self.scenes {
            for (i, page) in [[], ["-labPage2"], ["-labPage4"], ["-labPage3"]].enumerated() {
                seq("widgets.\(s)-\(i + 1)", ["-scene", s, "-plus", "-char", "cat", "-open", "widgetLab"] + page)
            }
        }
        seq("widgets.stress-1", ["-scene", "spring_rain", "-plus", "-char", "cat", "-open", "widgetLab", "-labStress"])
        seq("widgets.stress-2", ["-scene", "spring_rain", "-plus", "-char", "cat", "-open", "widgetLab", "-labPage2", "-labStress"])
        seq("widgets.free-1", ["-scene", "maybe", "-char", "cat", "-open", "widgetLab"])
        seq("widgets.free-3", ["-scene", "maybe", "-char", "cat", "-open", "widgetLab", "-labPage4"])
        // other units: °F, km/h and the 12-hour clock (English: °F and mph)
        let units = lang == "en" ? ["-unitF", "-wind", "mph"] : ["-unitF", "-wind", "kmh", "-clock12"]
        seq("units.home", ["-scene", "maybe", "-plus", "-char", "cat"] + units, swipes: 2)
        seq("units.widgets-1", ["-scene", "maybe", "-plus", "-char", "cat", "-open", "widgetLab"] + units)
        seq("units.widgets-3", ["-scene", "maybe", "-plus", "-char", "cat", "-open", "widgetLab", "-labPage4"] + units)
        seq("units.day", ["-scene", "maybe", "-plus", "-open", "today"] + units, swipes: 1)
    }
}
