import Foundation
import UserNotifications

/// Local notifications planned from the latest forecast, re-planned after every refresh and whenever a
/// notification setting changes. Hour labels in the forecast are the *place's* local time, so the fire time is
/// computed in that time zone and scheduled as an interval (correct wherever the phone is).
/// (기상특보 push needs the server to send it; until then warnings show in the bubble only.)
enum Notifications {
    static func plan(scene s: WeatherScene, place: Place, rain: Bool, morning: Bool, change: Bool, morningTime: Date, unitF: Bool, voice: Voice = .polite, clock12: Bool = false, character: PurrCharacter = .cat) {
        let deg = { (v: Int) -> String in "\(unitF ? Int((Double(v) * 1.8 + 32).rounded()) : v)°" }
        let c = UNUserNotificationCenter.current()
        c.getNotificationSettings { settings in
            c.removePendingNotificationRequests(withIdentifiers: ["rain", "morning", "change"])
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

            // 비 오기 전: 30 minutes before the first rainy hour (quiet hours 22:00–07:00 skipped)
            if rain, let first = firstRain(s, tz: TimeZone(identifier: place.timeZone) ?? .current) {
                let (fire, _) = first
                let at = fire.addingTimeInterval(-30 * 60)
                let localHour = Calendar.current.component(.hour, from: at)
                if at.timeIntervalSinceNow > 60, localHour >= 7, localHour < 22 {
                    let n = UNMutableNotificationContent()
                    var cal = Calendar.current; cal.timeZone = TimeZone(identifier: place.timeZone) ?? .current
                    let h = cal.component(.hour, from: fire)
                    n.title = voice.say(L("%@쯤 비 예보 · 우산 챙기세요", HourLabel.word(h, clock12: clock12)))
                    n.body = voice.say(L("%@ · 30분 안에 비가 올 수 있어요", place.short))
                    n.sound = .default
                    // the chosen character in today's outfit under its open umbrella, in the rain (or snow) that is coming
                    let icon = s.hours.dropFirst().first(where: { $0.mm > 0 || ["raincloud", "lightning", "snowflake", "sleet"].contains($0.icon) })?.icon ?? "raincloud"
                    if let a = NotificationArt.attachment(character, level: s.level, rain: .umbrella, sky: NotificationArt.wetSky(icon: icon), falling: true, id: "rain") { n.attachments = [a] }
                    c.add(UNNotificationRequest(identifier: "rain", content: n,
                                                trigger: UNTimeIntervalNotificationTrigger(timeInterval: at.timeIntervalSinceNow, repeats: false)))
                }
            }

            // tomorrow morning at the chosen time (the user's own clock), with tomorrow's numbers
            let t = Calendar.current.dateComponents([.hour, .minute], from: morningTime)
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date().addingTimeInterval(86400))
            comps.hour = t.hour ?? 7; comps.minute = t.minute ?? 0
            let today = s.days.first, tomorrow = s.days.count > 1 ? s.days[1] : nil
            // the hour the morning notifications arrive in, when the forecast reaches it: rain then → umbrella open
            let atMorning = Calendar.current.date(from: comps).flatMap { hourRow(s, at: $0, tz: TimeZone(identifier: place.timeZone) ?? .current) }

            // 아침 요약
            if morning, let d = tomorrow {
                let n = UNMutableNotificationContent()
                n.title = voice.say(L("%@ · 오늘 %@ ~ %@", place.short, deg(d.lo), deg(d.hi)))
                n.body = voice.say(morningBody(d))
                if let a = dayPicture(d, character, now: atMorning, id: "morning") { n.attachments = [a] }
                c.add(UNNotificationRequest(identifier: "morning", content: n, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
            }

            // 기온 변화: how tomorrow compares with today (said the next morning as "어제보다")
            if change, let d = tomorrow, let y = today {
                let n = UNMutableNotificationContent()
                n.title = voice.say(changeTitle(place: place.short, todayHi: d.hi, yesterdayHi: y.hi, unitF: unitF))
                n.body = voice.say(changeBody(d, deg: deg))
                if let a = dayPicture(d, character, now: atMorning, id: "change") { n.attachments = [a] }
                // a minute after the summary so the two never collapse into one line
                var cc = comps; cc.minute = (cc.minute ?? 0) + 1
                if cc.minute == 60 { cc.minute = 0; cc.hour = ((cc.hour ?? 7) + 1) % 24 }
                c.add(UNNotificationRequest(identifier: "change", content: n, trigger: UNCalendarNotificationTrigger(dateMatching: cc, repeats: false)))
            }
        }
    }

    /// A day's picture: the outfit for its range under its sky; the umbrella open in the rain when it is raining as the
    /// notification arrives (`now`, that hour's row), else packed when rain or snow is likely that day (30 %+).
    static func dayPicture(_ d: WeatherScene.DayRow, _ c: PurrCharacter, now: WeatherScene.HourRow? = nil, id: String) -> UNNotificationAttachment? {
        let lv = NotificationArt.dayLevel(lo: d.lo, hi: d.hi)
        if let r = now, r.mm > 0 {
            return NotificationArt.attachment(c, level: lv, rain: .umbrella, sky: NotificationArt.wetSky(icon: r.icon), falling: true, id: id)
        }
        return NotificationArt.attachment(c, level: lv, rain: d.chance >= 30 ? .bag : .none, sky: NotificationArt.sky(icon: d.icon), falling: false, id: id)
    }

    /// The forecast row of the hour that holds `target` (rows after "지금" are consecutive hours of the place's clock).
    static func hourRow(_ s: WeatherScene, at target: Date, tz: TimeZone, now: Date = Date()) -> WeatherScene.HourRow? {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        var prev = now
        for row in s.hours.dropFirst() {
            guard let h = HourLabel.hour(row.label), var d = cal.date(bySettingHour: h, minute: 0, second: 0, of: prev) else { continue }
            if d < prev { d = cal.date(byAdding: .day, value: 1, to: d) ?? d }
            prev = d
            if target >= d && target < d.addingTimeInterval(3600) { return row }
            if d > target { break }
        }
        return nil
    }

    static func morningBody(_ d: WeatherScene.DayRow) -> String {
        if d.chance >= 60 {
            return d.icon == "snowflake" ? L("눈 예보예요 · 미끄러우니 조심하세요")
                : d.icon == "sleet" ? L("진눈깨비 예보예요 · 미끄러우니 조심하세요") : L("비 예보예요 · 우산 챙기세요")
        }
        if d.chance >= 30 { return L("강수확률 %d%% · 우산 챙기세요", d.chance) }
        return d.hi - d.lo >= 8 ? L("일교차가 커요") : L("옷차림은 앱에서 확인해 보세요")
    }

    /// "어제보다 4° 낮아요" / "어제와 비슷해요" (the day's high, °F-aware)
    static func changeTitle(place: String, todayHi: Int, yesterdayHi: Int, unitF: Bool) -> String {
        let diff = todayHi - yesterdayHi
        let shown = unitF ? Int((Double(abs(diff)) * 1.8).rounded()) : abs(diff)
        if abs(diff) < 2 { return L("%@ · 어제와 비슷해요", place) }
        return diff > 0 ? L("%@ · 어제보다 %d° 높아요", place, shown) : L("%@ · 어제보다 %d° 낮아요", place, shown)
    }
    static func changeBody(_ d: WeatherScene.DayRow, deg: (Int) -> String) -> String {
        var parts = [L("오늘 %@ ~ %@", deg(d.lo), deg(d.hi))]
        if d.hi - d.lo >= 8 { parts.append(L("일교차가 커요")) }
        if d.chance >= 60 { parts.append(L("비 예보")) } else if d.chance >= 30 { parts.append(L("비 올 수도")) }
        return parts.joined(separator: L(" · "))
    }

    /// Start of the first rainy hour in the hourly rows ("16시", in the place's time zone) and that hour.
    static func firstRain(_ s: WeatherScene, tz: TimeZone, now: Date = Date()) -> (Date, Int)? {
        guard let row = s.hours.dropFirst().first(where: { $0.mm > 0 || ["raincloud", "lightning", "sleet"].contains($0.icon) }),
              let h = HourLabel.hour(row.label) else { return nil }
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        guard var d = cal.date(bySettingHour: h, minute: 0, second: 0, of: now) else { return nil }
        if d < now { d = cal.date(byAdding: .day, value: 1, to: d) ?? d }
        return (d, h)
    }
}
