import XCTest

/// Launches the app on every example scene and saves a screenshot of the home screen as a test attachment.
/// CI collects the attachments so the screens can be checked against the design canvas.
final class ScreenshotTests: XCTestCase {
    let scenes = ["clear", "maybe", "combo", "tokyo_soon", "seoul_soon", "spring_rain", "summer_heat", "winter_eve", "winter_cold", "winter_snow"]

    func testHomeScreens() {
        for key in scenes {
            for (plan, char) in [("free", "cat"), ("plus", "abys"), ("plus", "scot")] {
                let app = XCUIApplication()
                app.launchArguments = ["-scene", key, "-char", char] + (plan == "plus" ? ["-plus"] : [])
                app.launch()
                sleep(1)
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "home-\(key)-\(plan)-\(char)"
                shot.lifetime = .keepAlways
                add(shot)
                app.terminate()
            }
        }
    }
}
