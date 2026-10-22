import XCTest

/// Launches the app on example weather and saves screenshots as test attachments.
/// CI collects the attachments (ci-output branch) so the screens can be checked against the design canvas.
final class ScreenshotTests: XCTestCase {
    let scenes = ["clear", "maybe", "combo", "tokyo_soon", "spring_rain", "summer_heat", "summer_night", "winter_cold", "winter_snow", "summer_typhoon"]

    private func shot(_ name: String, _ args: [String], wait: UInt32 = 1, then: ((XCUIApplication) -> Void)? = nil) {
        let app = XCUIApplication()
        app.launchArguments = args + ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]   // Korean phone: 그르릉날씨
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
    }

    func test4Onboarding() {
        shot("onboarding-1", ["-scene", "maybe", "-onboarding"])
        shot("onboarding-2", ["-scene", "maybe", "-onboarding"]) { app in app.buttons["next"].tap(); sleep(1) }
        shot("onboarding-3", ["-scene", "maybe", "-onboarding"]) { app in app.buttons["next"].tap(); sleep(1); app.buttons["next"].tap(); sleep(1) }
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
}
