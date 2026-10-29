import SwiftUI

/// The home-screen icon follows the character shown: each one under its own umbrella. The cat is the primary icon,
/// 아비시니안 and 브리티시숏헤어 are alternate icons (asset catalog AppIcon-abys · AppIcon-brit, listed in project.yml).
/// iOS itself tells the person the icon changed (a short system note), so it only changes when the character does.
@MainActor
enum AppIcon {
    static func name(for c: PurrCharacter) -> String? { c == .cat ? nil : "AppIcon-\(c.rawValue)" }

    static func follow(_ c: PurrCharacter) {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-scene") || args.contains("-reset") { return }      // screenshots and UI tests keep the cat
        let app = UIApplication.shared
        guard app.supportsAlternateIcons, app.applicationState == .active else { return }
        let want = name(for: c)
        guard app.alternateIconName != want else { return }
        app.setAlternateIconName(want) { _ in }
    }
}
