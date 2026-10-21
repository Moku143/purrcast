import Foundation
import UserNotifications

/// Local notifications planned from the latest forecast, re-planned after every refresh and whenever a
/// notification setting changes. Hour labels in the forecast are the *place's* local time, so the fire time is
/// computed in that time zone and scheduled as an interval (correct wherever the phone is).
/// (기상특보 push needs the server to send it; until then warnings show in the bubble only.)
enum Notifications {
    static func plan(scene s: WeatherScene, place: Place, rain: Bool, morning: Bool, morningTime: Date, unitF: Bool) {
        let deg = { (v: Int) -> String in "\(unitF ? Int((Double(v) * 1.8 + 32).rounded()) : v)°" }
        let c = UNUserNotificationCenter.current()
        c.getNotificationSettings { settings in
            c.removePendingNotificationRequests(withIdentifiers: ["rain", "morning"])
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

            // 비 오기 전: 30 minutes before the first rainy hour (quiet hours 22:00–07:00 skipped)
            if rain, let first = firstRain(s, tz: TimeZone(identifier: place.timeZone) ?? .current) {
                let (fire, hour) = first
                let at = fire.addingTimeInterval(-30 * 60)
                let localHour = Calendar.current.component(.hour, from: at)
                if at.timeIntervalSinceNow > 60, localHour >= 7, localHour < 22 {
                    let n = UNMutableNotificationContent()
                    n.title = "\(hour)시쯤 비 와요"
                    n.body = "\(place.short) · 우산 챙기세요"
                    n.sound = .default
                    c.add(UNNotificationRequest(identifier: "rain", content: n,
                                                trigger: UNTimeIntervalNotificationTrigger(timeInterval: at.timeIntervalSinceNow, repeats: false)))
                }
            }

            // 아침 요약: tomorrow at the chosen time (the user's own clock), with tomorrow's numbers
            if morning, s.days.count > 1 {
                let d = s.days[1]
                let n = UNMutableNotificationContent()
                n.title = "\(place.short) · 오늘 \(deg(d.lo)) ~ \(deg(d.hi))"
                n.body = d.chance >= 30 ? "비 올 확률 \(d.chance)% · 우산 챙기세요" : "옷차림은 앱에서 확인해 보세요"
                let t = Calendar.current.dateComponents([.hour, .minute], from: morningTime)
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date().addingTimeInterval(86400))
                comps.hour = t.hour ?? 7; comps.minute = t.minute ?? 0
                c.add(UNNotificationRequest(identifier: "morning", content: n, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
            }
        }
    }

    /// Start of the first rainy hour in the hourly rows ("16시", in the place's time zone) and that hour.
    static func firstRain(_ s: WeatherScene, tz: TimeZone, now: Date = Date()) -> (Date, Int)? {
        guard let row = s.hours.dropFirst().first(where: { $0.mm > 0 || $0.icon == "raincloud" || $0.icon == "lightning" }),
              row.label.hasSuffix("시"), let h = Int(row.label.dropLast()), (0..<24).contains(h) else { return nil }
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        guard var d = cal.date(bySettingHour: h, minute: 0, second: 0, of: now) else { return nil }
        if d < now { d = cal.date(byAdding: .day, value: 1, to: d) ?? d }
        return (d, h)
    }
}
