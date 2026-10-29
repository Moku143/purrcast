import UIKit
import UserNotifications

/// The picture on every notification: the chosen character in the outfit for that moment's feels-like temperature,
/// under that forecast's sky (notify-bg-<sky>, pixel art). Its umbrella: packed when the day's forecast has rain or
/// snow, open under falling rain / snowflakes (it stays dry under the canopy) for the rain alert and when it is
/// raining as a morning notification arrives.
enum NotificationArt {
    enum Sky: String, CaseIterable { case clear, partly, cloudy, rain, snow, storm }

    /// The sky for a forecast icon (the hourly / daily rows' icon names).
    static func sky(icon: String) -> Sky {
        switch icon {
        case "sun", "moon", "sun_strong": return .clear
        case "partly_cloudy": return .partly
        case "raincloud", "raindrop": return .rain
        case "snowflake", "sleet": return .snow
        case "lightning": return .storm
        default: return .cloudy
        }
    }

    /// The sky while rain or snow is falling (an hour that is wet whatever its icon says).
    static func wetSky(icon: String) -> Sky { icon == "snowflake" || icon == "sleet" ? .snow : icon == "lightning" ? .storm : .rain }

    static let side: CGFloat = 600

    static func render(_ c: PurrCharacter, level: Int, rain: RainState, sky: Sky, falling: Bool) -> UIImage? {
        let lv = Rules.clamp(level)
        guard let bg = UIImage(named: "notify-bg-\(sky.rawValue)"),
              let sprite = UIImage(named: c.stand(level: lv, rain: rain)) else { return nil }
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: fmt).image { ctx in
            let g = ctx.cgContext
            g.interpolationQuality = .none
            bg.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
            // the whole character, feet near the bottom, its head in the middle
            let k = side * 0.86 / Sprite.height
            let hcx = CGFloat(c.anchors.head_cx[min(lv, c.anchors.head_cx.count - 1)])
            let rect = CGRect(x: side / 2 - hcx * k, y: side * 0.965 - Sprite.feetY * k, width: Sprite.width * k, height: Sprite.height * k)
            if falling {
                // the open umbrella's canopy (the same on every sprite: x 0…392, down to y 179) keeps the space under it dry
                let dry = rain == .umbrella ? CGRect(x: rect.minX - 8, y: rect.minY + 179 * k, width: 392 * k + 16, height: side) : .null
                fallingThings(snow: sky == .snow, in: g, dry: dry)
            }
            sprite.draw(in: rect)
        }
    }

    /// Rain: pale 1-cell streaks 7–9 cells long; snow: small pixel flakes. Always in the same places (seeded).
    private static func fallingThings(snow: Bool, in g: CGContext, dry: CGRect) {
        let cell = side / 50
        var seed: UInt64 = snow ? 11 : 7
        func next(_ n: Int) -> Int { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Int((seed >> 33) % UInt64(n)) }
        g.setFillColor(UIColor(red: 238 / 255, green: 245 / 255, blue: 1, alpha: 0.92).cgColor)
        var placed = 0, tries = 0
        while placed < (snow ? 26 : 40) && tries < 2000 {
            tries += 1
            let x = CGFloat(next(48) + 1) * cell, y = CGFloat(next(46) - 3) * cell
            if snow {
                let r = CGRect(x: x, y: y, width: cell * 3, height: cell * 3)
                if r.intersects(dry) { continue }
                g.fill(CGRect(x: x + cell, y: y, width: cell, height: cell * 3))
                g.fill(CGRect(x: x, y: y + cell, width: cell * 3, height: cell))
            } else {
                let r = CGRect(x: x, y: y, width: cell, height: CGFloat(7 + next(3)) * cell)
                if r.intersects(dry) { continue }
                g.fill(r)
            }
            placed += 1
        }
    }

    /// The picture as a notification attachment (written to a file of its own: iOS moves the file into its store).
    static func attachment(_ c: PurrCharacter, level: Int, rain: RainState, sky: Sky, falling: Bool, id: String) -> UNNotificationAttachment? {
        guard let img = render(c, level: level, rain: rain, sky: sky, falling: falling), let data = img.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(id)-\(UUID().uuidString).png")
        do {
            try data.write(to: url)
            return try UNNotificationAttachment(identifier: id, url: url, options: nil)
        } catch { return nil }
    }

    /// The outfit for a whole day from its low and high (the daily rows carry no feels-like): the middle of the day's range.
    static func dayLevel(lo: Int, hi: Int) -> Int { Rules.level(feels: Double(lo + hi) / 2) }
}
