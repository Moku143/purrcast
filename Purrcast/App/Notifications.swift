import Foundation
import UserNotifications

/// Local notifications planned from the latest forecast. Re-planned after every refresh, so they always follow
/// the newest data. (Warnings / 기상특보 need the server to push; that part waits for the server.)
enum Notifications {
    static func plan(scene s: WeatherScene, place: String, rain: Bool, morning: Bool, morningTime: Date, unitF: Bool) {
        let deg = { (v: Int) -> String in "\(unitF ? Int((Double(v) * 1.8 + 32).rounded()) : v)°" }
        let c = UNUserNotificationCenter.current()
        c.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            c.removePendingNotificationRequests(withIdentifiers: ["rain", "morning"])

            // 비 오기 전: 30 minutes before the first rainy hour today (quiet hours 22:00–07:00 skipped)
            if rain, let fire = firstRain(s) {
                let at = fire.addingTimeInterval(-30 * 60)
                let h = Calendar.current.component(.hour, from: at)
                if at > Date(), h >= 7, h < 22 {
                    let n = UNMutableNotificationContent()
                    let hh = Calendar.current.component(.hour, from: fire)
                    n.title = "\(hh)시쯤 비 와요"
                    n.body = "\(place) · 우산 챙기세요 ☂"
                    n.sound = .default
                    add(c, "rain", n, at)
                }
            }

            // 아침 요약: tomorrow at the chosen time, with tomorrow's numbers
            if morning, s.days.count > 1 {
                let d = s.days[1]
                let n = UNMutableNotificationContent()
                n.title = "\(place) · 오늘 \(deg(d.lo)) ~ \(deg(d.hi))"
                n.body = d.chance >= 30 ? "비 올 확률 \(d.chance)% · 우산 챙기세요" : "옷차림은 앱에서 확인해 보세요"
                let t = Calendar.current.dateComponents([.hour, .minute], from: morningTime)
                var day = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                day = Calendar.current.date(bySettingHour: t.hour ?? 7, minute: t.minute ?? 0, second: 0, of: day) ?? day
                add(c, "morning", n, day)
            }
        }
    }

    /// Start of the first hour today with rain in the hourly rows ("16시").
    private static func firstRain(_ s: WeatherScene) -> Date? {
        guard let row = s.hours.dropFirst().first(where: { $0.mm > 0 || $0.icon == "raincloud" || $0.icon == "lightning" }),
              row.label.hasSuffix("시"), let h = Int(row.label.dropLast()) else { return nil }
        var d = Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: Date()) ?? Date()
        if d < Date() { d = Calendar.current.date(byAdding: .day, value: 1, to: d) ?? d }
        return d
    }

    private static func add(_ c: UNUserNotificationCenter, _ id: String, _ n: UNMutableNotificationContent, _ at: Date) {
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: at)
        c.add(UNNotificationRequest(identifier: id, content: n, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
    }
}
