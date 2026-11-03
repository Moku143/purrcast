import XCTest

/// The review catalog (catalog workflow): every screen of the app on every example weather, in one language per run.
/// CATALOG_LANG ko | en | ja | es | fr | de | pt | it | id | ru | zh-Hans | zh-Hant (xcodebuild passes
/// TEST_RUNNER_CATALOG_LANG through), CATALOG_PART a | b (everything) or c (a quick look at a new language).
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
        let locale = ["ko": "ko_KR", "en": "en_US", "ja": "ja_JP", "es": "es_ES", "fr": "fr_FR", "de": "de_DE", "pt": "pt_BR", "it": "it_IT",
                      "id": "id_ID", "ru": "ru_RU", "zh-Hans": "zh_CN", "zh-Hant": "zh_TW"][lang] ?? "en_US"
        let device = lang == "pt" ? "pt-BR" : lang
        // an English phone reads hours as 3PM (the app's default there); Korean and Japanese as 15시 / 15時
        let clock = lang == "en" && !args.contains("-clock12") ? ["-clock12"] : []
        app.launchArguments = args + clock + ["-AppleLanguages", "(\(device))", "-AppleLocale", locale]
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
        switch part {
        case "a": partA()
        case "c": partC()
        case "d": partD()
        case "e": partE()
        case "f": partF()
        default: partB()
        }
    }

    // MARK: 날씨 기록 — the calendar (Plus) this month and last, a day picked, the week card on home

    private func calendarShots() {
        seq("calendar.this", ["-scene", "maybe", "-plus", "-char", "cat", "-open", "calendar"], swipes: 2, wait: 3)
        seq("calendar.last", ["-scene", "maybe", "-plus", "-char", "cat", "-open", "calendar", "-calMonth", "-1"], swipes: 1, wait: 3)
        steps("calendar.pick", ["-scene", "spring_dust", "-plus", "-char", "abys", "-open", "calendar"], wait: 3) { app, take in
            // a day tapped opens its own page
            let cells = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cal-20'"))
            if cells.count > 1 { cells.element(boundBy: 1).tap(); sleep(2) }
            take()
            for m in ["wind", "humidity"] {
                let b = app.buttons["day-metric-\(m)"].firstMatch
                if b.waitForExistence(timeout: 1) { b.tap(); sleep(1); take() }
            }
        }
        seq("calendar.winter", ["-scene", "winter_snow", "-plus", "-char", "brit", "-open", "calendar"], swipes: 1, wait: 3)
        steps("calendar.card", ["-scene", "maybe", "-char", "cat"]) { app, take in
            let card = app.buttons["week-card"].firstMatch
            for _ in 0..<8 where !(card.exists && card.isHittable) { app.swipeUp(); sleep(1) }
            take()
            if card.exists { card.tap(); sleep(2); take() }          // free: the Plus page
        }
    }

    /// Part f: a day's own page in each look (graph · image · text · mixed) on a rainy day and a dusty one
    private func partF() {
        for (scene, char) in [("maybe", "cat"), ("spring_dust", "abys")] {
            for style in ["graph", "image", "text", "mixed"] {
                steps("daypage.\(style)-\(scene)", ["-scene", scene, "-plus", "-char", char, "-open", "calendar", "-calDay", "0", "-dayStyle", style], wait: 4) { app, take in
                    take()
                    for _ in 0..<2 { app.swipeUp(); sleep(1); take() }
                    if style == "graph" {
                        app.swipeDown(); sleep(1)
                        for m in ["rain", "wind", "humidity", "uv"] {
                            let b = app.buttons["day-metric-\(m)"].firstMatch
                            if b.waitForExistence(timeout: 1) { b.tap(); sleep(1); take() }
                        }
                    }
                }
            }
        }
    }

    /// Part e: just the new 날씨 기록 screens and the Plus page with its new slide
    private func partE() {
        calendarShots()
        steps("paywall.free", ["-scene", "maybe", "-open", "paywall"], wait: 3) { app, take in
            take()
            for _ in 0..<7 { app.swipeLeft(); sleep(1); take() }
        }
        seq("home-plus.maybe", ["-scene", "maybe", "-plus", "-char", "cat"], swipes: 8)
    }

    // MARK: the same language in plain text (설정 → 글씨 → 일반): the system font instead of the pixel one

    private func partD() {
        let p = ["-plainFont"]
        for st in [0, 6] { seq("plain-onboarding.\(st)", ["-scene", "maybe", "-onboarding", "-onbStep", String(st)] + p, wait: st == 0 ? 7 : 3) }
        seq("plain-home.maybe", ["-scene", "maybe", "-plus", "-char", "cat"] + p, swipes: 4)
        seq("plain-home.winter_smog", ["-scene", "winter_smog", "-plus", "-char", "cat"] + p, swipes: 1)
        seq("plain-home.summer_typhoon", ["-scene", "summer_typhoon", "-plus", "-char", "cat"] + p)
        seq("plain-day.maybe", ["-scene", "maybe", "-plus", "-open", "today"] + p, swipes: 1)
        seq("plain-paywall.free", ["-scene", "maybe", "-open", "paywall"] + p, swipes: 1, wait: 3)
        seq("plain-settings.free", ["-scene", "maybe", "-open", "settings"] + p, swipes: 2)
        seq("plain-pages.language", ["-scene", "maybe", "-open", "language"] + p)
    }

    // MARK: a new language at a glance — first run, home, a day, Plus, settings, language search, widgets

    private func partC() {
        for st in 0...6 { seq("onboarding.\(st)", ["-scene", "maybe", "-onboarding", "-onbStep", String(st)], wait: st == 0 ? 7 : 3) }   // the first launch of a run is slow to draw
        seq("home-plus.maybe", ["-scene", "maybe", "-plus", "-char", "cat"], swipes: 7)
        seq("home-plus.winter_smog", ["-scene", "winter_smog", "-plus", "-char", "cat"], swipes: 3)
        seq("home-plus.summer_typhoon", ["-scene", "summer_typhoon", "-plus", "-char", "cat"], swipes: 1)
        seq("home-plus.tokyo_soon", ["-scene", "tokyo_soon", "-plus", "-char", "cat"], swipes: 1)
        seq("home-free.maybe", ["-scene", "maybe", "-char", "cat"], swipes: 2)
        seq("day-today.maybe", ["-scene", "maybe", "-plus", "-open", "today"], swipes: 2)
        seq("day-tab.spring_dust-dust", ["-scene", "spring_dust", "-plus", "-open", "today"], swipes: 1) { app in self.tap(app, "tab-dust") }
        steps("paywall.free", ["-scene", "maybe", "-open", "paywall"], wait: 3) { app, take in
            take()
            for _ in 0..<7 { app.swipeLeft(); sleep(1); take() }
            for _ in 0..<2 { app.swipeUp(); sleep(1); take() }
        }
        calendarShots()
        seq("settings.free", ["-scene", "maybe", "-open", "settings"], swipes: 5)
        seq("pages.language", ["-scene", "maybe", "-open", "language"], swipes: 1)
        // the language list searched in English and in Korean: both find Korean
        for (i, q) in ["korean", "한국어", "日本"].enumerated() {
            steps("search.lang\(i + 1)", ["-scene", "maybe", "-open", "language"]) { app, take in
                let f = app.textFields["lang-search"].firstMatch
                if f.waitForExistence(timeout: 2) { f.tap(); f.typeText(q); sleep(1) }
                let tip = app.buttons["Continue"].firstMatch
                if tip.exists { tip.tap(); sleep(1) }
                take()
            }
        }
        seq("pages.places-plus", ["-scene", "maybe", "-plus", "-open", "places"], swipes: 1)
        seq("pages.sources", ["-scene", "maybe", "-open", "sources"], swipes: 4)
        seq("air.abroad", ["-scene", "tokyo_soon", "-plus", "-open", "air", "-place", "tokyo"], swipes: 1, wait: 7)
        seq("live.lab", ["-scene", "spring_rain", "-plus", "-char", "cat", "-open", "liveLab"], swipes: 2)
        for s in ["maybe", "spring_rain"] {
            for (i, page) in [[], ["-labPage2"], ["-labPage4"], ["-labPage3"]].enumerated() {
                seq("widgets.\(s)-\(i + 1)", ["-scene", s, "-plus", "-char", "cat", "-open", "widgetLab"] + page)
            }
        }
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
        for st in 0...6 { seq("onboarding.\(st)", ["-scene", "maybe", "-onboarding", "-onbStep", String(st)], wait: st == 0 ? 7 : 3) }   // the first launch of a run is slow to draw

        // Plus: every slide, then down to the prices; and the page when Plus is on
        steps("paywall.free", ["-scene", "maybe", "-open", "paywall"], wait: 3) { app, take in
            take()
            for _ in 0..<7 { app.swipeLeft(); sleep(1); take() }
            for _ in 0..<2 { app.swipeUp(); sleep(1); take() }
        }
        seq("paywall.plus", ["-scene", "maybe", "-plus", "-open", "paywall"], swipes: 2, wait: 3)

        calendarShots()
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
