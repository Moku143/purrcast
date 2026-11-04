import Foundation
import UserNotifications

/// Local notifications planned from the latest forecast, re-planned after every refresh and whenever a
/// notification setting changes. Hour labels in the forecast are the *place's* local time, so the fire time is
/// computed in that time zone and scheduled as an interval (correct wherever the phone is).
/// (기상특보 push needs the server to send it; until then warnings show in the bubble only.)
enum Notifications {
    static func plan(scene s: WeatherScene, place: Place, rain: Bool, morning: Bool, change: Bool, morningTime: Date, unitF: Bool, voice: Voice = .polite, clock12: Bool = false, character: PurrCharacter = .cat, plus: Bool = false, monthly: MonthlyFire? = nil) {
        let deg = { (v: Int) -> String in "\(unitF ? Int((Double(v) * 1.8 + 32).rounded()) : v)°" }
        let c = UNUserNotificationCenter.current()
        c.getNotificationSettings { settings in
            c.removePendingNotificationRequests(withIdentifiers: ids)
            let allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            // 아침 요약: the next 7 mornings
            for m in morningPlan(allowed: allowed, enabled: morning, scene: s, place: place, morningTime: morningTime, unitF: unitF, plus: plus, voice: voice) {
                let n = UNMutableNotificationContent()
                n.title = m.title
                n.body = m.body   // no picture: the app icon is enough
                c.add(UNNotificationRequest(identifier: m.id, content: n, trigger: UNCalendarNotificationTrigger(dateMatching: m.at, repeats: false)))
            }
            guard allowed else { return }

            // 비 오기 전: an hour before the first rainy hour (as the Live Activity does) (quiet hours 22:00–07:00 skipped)
            if rain, let first = firstRain(s, tz: TimeZone(identifier: place.timeZone) ?? .current) {
                let (fire, _) = first
                let at = fire.addingTimeInterval(-60 * 60)
                let localHour = Calendar.current.component(.hour, from: at)
                if at.timeIntervalSinceNow > 60, localHour >= 7, localHour < 22 {
                    let n = UNMutableNotificationContent()
                    var cal = Calendar.current; cal.timeZone = TimeZone(identifier: place.timeZone) ?? .current
                    let h = cal.component(.hour, from: fire)
                    n.title = voice.say(L("%@쯤 비 예보 · 우산 챙기세요", HourLabel.word(h, clock12: clock12)))
                    n.body = voice.say(L("%@ · 1시간 안에 비가 올 수 있어요", place.short))
                    n.sound = .default
                    // the chosen character in today's outfit under its open umbrella, in the rain (or snow) that is coming
                    let icon = s.hours.dropFirst().first(where: { $0.mm > 0 || ["raincloud", "lightning", "snowflake", "sleet"].contains($0.icon) })?.icon ?? "raincloud"
                    if let a = NotificationArt.attachment(character, level: s.level, rain: .umbrella, sky: NotificationArt.wetSky(icon: icon), falling: true, id: "rain") { n.attachments = [a] }
                    c.add(UNNotificationRequest(identifier: "rain", content: n,
                                                trigger: UNTimeIntervalNotificationTrigger(timeInterval: at.timeIntervalSinceNow, repeats: false)))
                }
            }

            // the next morning at the chosen time (the user's own clock): still today's when the time is ahead (opening
            // the app at 3 am must not wipe the 7 am summary), else tomorrow's — for the change line below
            let t = Calendar.current.dateComponents([.hour, .minute], from: morningTime)
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            comps.hour = t.hour ?? 7; comps.minute = t.minute ?? 0
            let stillToday = (Calendar.current.date(from: comps).map { $0.timeIntervalSinceNow > 60 } ?? false)
            if !stillToday { comps = Calendar.current.dateComponents([.year, .month, .day], from: Date().addingTimeInterval(86400)); comps.hour = t.hour ?? 7; comps.minute = t.minute ?? 0 }
            let tomorrow = stillToday ? s.days.first : (s.days.count > 1 ? s.days[1] : nil)   // the day the next summary is about
            let today = stillToday ? nil : s.days.first   // the day before it, for the change line (unknown once that day has begun)

            // 기온 변화: how tomorrow compares with today (said the next morning as "어제보다")
            if change, let d = tomorrow, let y = today {
                let n = UNMutableNotificationContent()
                n.title = voice.say(changeTitle(place: place.short, todayHi: d.hi, yesterdayHi: y.hi, unitF: unitF))
                n.body = voice.say(changeBody(d, deg: deg))
                // a minute after the summary so the two never collapse into one line
                var cc = comps; cc.minute = (cc.minute ?? 0) + 1
                if cc.minute == 60 { cc.minute = 0; cc.hour = ((cc.hour ?? 7) + 1) % 24 }
                c.add(UNNotificationRequest(identifier: "change", content: n, trigger: UNCalendarNotificationTrigger(dateMatching: cc, repeats: false)))
            }

            // 월간 리포트 (Plus): the 1st, opening the 날씨 달력 at the month that just ended
            if let m = monthly {
                let n = UNMutableNotificationContent()
                n.title = voice.say(L("%@ 리포트가 나왔어요", DayLogText.monthName(m.month)))
                n.body = voice.say(L("비·눈 온 날과 가장 덥고 추웠던 날, 자주 입은 옷을 정리했어요."))
                n.sound = .default
                n.userInfo = ["open": "calendar", "month": m.month]
                c.add(UNNotificationRequest(identifier: "monthly", content: n, trigger: UNCalendarNotificationTrigger(dateMatching: m.at, repeats: false)))
            }
        }
    }

    /// Every id plan() may leave pending, all cleared before each plan ("morning" was the one summary of builds up to 63)
    static let ids = ["rain", "morning", "change", "monthly"] + morningIDs
    static let morningIDs = (0..<7).map { "morning\($0)" }

    struct Morning: Equatable {
        var id: String
        var at: DateComponents      // the user's own clock
        var title: String
        var body: String
    }

    /// The 아침 요약 to leave pending: none when notifications are not allowed or the summary is off
    static func morningPlan(allowed: Bool, enabled: Bool, scene s: WeatherScene, place: Place, morningTime: Date, unitF: Bool,
                            plus: Bool, voice: Voice = .polite, now: Date = Date(), calendar cal: Calendar = .current) -> [Morning] {
        guard allowed, enabled else { return [] }
        return mornings(s, place: place, morningTime: morningTime, unitF: unitF, plus: plus, voice: voice, now: now, calendar: cal)
    }

    /// The 아침 요약 for the next 7 mornings at the chosen time (the user's own clock), today's first while that time is
    /// still ahead (opening the app at 3 am must not wipe the 7 am summary): the next three with that day's forecast
    /// numbers, the four after them a plain reminder without numbers (a forecast that many days old is not worth
    /// repeating). The app re-plans them all after every refresh, so a phone that opens the app keeps a fresh week.
    static func mornings(_ s: WeatherScene, place: Place, morningTime: Date, unitF: Bool, plus: Bool, voice: Voice = .polite,
                         now: Date = Date(), calendar cal: Calendar = .current) -> [Morning] {
        let deg = { (v: Int) -> String in "\(unitF ? Int((Double(v) * 1.8 + 32).rounded()) : v)°" }
        let t = cal.dateComponents([.hour, .minute], from: morningTime)
        func at(_ dayOffset: Int) -> DateComponents? {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: now)) else { return nil }
            var c = cal.dateComponents([.year, .month, .day], from: day)
            c.hour = t.hour ?? 7; c.minute = t.minute ?? 0
            return c
        }
        let stillToday = at(0).flatMap { cal.date(from: $0) }.map { $0.timeIntervalSince(now) > 60 } ?? false
        let first = stillToday ? 0 : 1
        return (0..<7).compactMap { k -> Morning? in
            let i = first + k               // the forecast's day (0 = today)
            guard let c = at(i) else { return nil }
            if k < 3, i < s.days.count {
                let d = s.days[i]
                return Morning(id: morningIDs[k], at: c, title: voice.say(L("%@ · 오늘 %@ ~ %@", place.short, deg(d.lo), deg(d.hi))),
                               body: voice.say(morningDetail(s, day: d, plus: plus, today: i == 0, unitF: unitF)))
            }
            return Morning(id: morningIDs[k], at: c, title: place.short, body: voice.say(L("옷차림은 앱에서 확인해 보세요")))
        }
    }

    /// When the 월간 리포트 comes and which month it is about
    struct MonthlyFire: Equatable {
        var at: DateComponents      // the user's own clock
        var month: String           // "2026-10"
    }

    /// The next 1st of a month, two minutes after the morning summary's time (so the two never collapse into one
    /// line): today when it is the 1st and that time is still ahead (the month before), else the 1st of next month.
    static func monthlyFire(after now: Date, morning: Date, calendar cal: Calendar = .current) -> MonthlyFire? {
        let t = cal.dateComponents([.hour, .minute], from: morning)
        var h = t.hour ?? 7, mi = (t.minute ?? 0) + 2
        if mi >= 60 { mi -= 60; h = (h + 1) % 24 }
        func key(_ d: Date) -> String { let c = cal.dateComponents([.year, .month], from: d); return String(format: "%04d-%02d", c.year ?? 2000, c.month ?? 1) }
        var today = cal.dateComponents([.year, .month, .day], from: now)
        if today.day == 1 {
            today.hour = h; today.minute = mi
            if let at = cal.date(from: today), at.timeIntervalSince(now) > 60,
               let before = cal.date(byAdding: .month, value: -1, to: now) {
                return MonthlyFire(at: today, month: key(before))
            }
        }
        guard let first = cal.date(from: cal.dateComponents([.year, .month], from: now)),
              let next = cal.date(byAdding: .month, value: 1, to: first) else { return nil }
        var at = cal.dateComponents([.year, .month, .day], from: next)
        at.hour = h; at.minute = mi
        return MonthlyFire(at: at, month: key(now))
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

    /// The forecast row of the hour that holds `target` (WeatherScene.hourIndex walks the rows; the widgets age
    /// their snapshot with the same walk).
    static func hourRow(_ s: WeatherScene, at target: Date, tz: TimeZone, now: Date = Date()) -> WeatherScene.HourRow? {
        s.hourIndex(at: target, tz: tz, now: now).map { s.hours[$0] }
    }

    /// The whole morning, one thing per line: ① sky and rain (its hours and amount) ② the swing, how it feels, UV,
    /// sunset ③ 미세먼지 (Plus: a 주의보 / 경보 in force instead of the grade) ④ Plus: the warning in force, else the
    /// change from yesterday and strong wind ⑤ what to take — said once (a warning line already says it). A few
    /// emoji lead the lines people act on: the sky, a mask at 나쁨 or worse, the umbrella or a warning.
    /// Free plans this from the 06:00 forecast, Plus from the latest.
    static func morningDetail(_ s: WeatherScene, day d: WeatherScene.DayRow, plus: Bool, today: Bool, unitF: Bool) -> String {
        let snowy = d.icon == "snowflake" || d.icon == "sleet"
        var sky: [String] = []
        if today, !s.cond.isEmpty { sky.append(s.cond) }
        if d.chance >= 30, today, let t = s.tiles.first, t.note.contains(L(" 예보")) { sky.append(t.note) }   // "16~18시 비 예보 · 4mm (조금)"
        else if d.chance >= 60, !(today && s.isSnow && !s.cond.isEmpty) { sky.append(snowy ? L("눈 예보") : L("비 예보")) }   // "눈 · 눈 예보" says it twice
        else if d.chance >= 30 { sky.append(L("강수확률 %d%%", d.chance)) }
        var day: [String] = []
        if d.hi - d.lo >= 8 { day.append(L("일교차 %d°", d.hi - d.lo)) }
        if today { day.append(L("체감 %@", Rules.feelsWord(s.feels))) }
        if today, let uv = s.tiles.first(where: { $0.kind == "uv" })?.uv, uv >= 3 { day.append(L("자외선 %@", UVScale.band(uv).word)) }
        if today, let sun = s.tiles.first(where: { $0.icon == "sunset" }), let v = sun.value, v != "–" { day.append(L("일몰 %@", v)) }
        // 미세먼지: the grade(s), the finer one only when it differs; a mask line when 나쁨 or worse. Plus: a 주의보 /
        // 경보 in force is the line instead (the server's own words for it)
        var dustLine: [String] = []
        var masked = false
        if today, let dd = s.dust {
            if plus, let kind = dd.alarm, kind == "watch" || kind == "warning" {
                let item = dd.pm25Grade.map { $0 >= (dd.pm10Grade ?? 0) } == true ? L("초미세먼지") : L("PM10")
                dustLine.append("\(item) \(kind == "warning" ? L("경보") : L("주의보")) · " + L("창문을 닫고 외출할 땐 마스크를 착용해 주세요"))
                masked = true
            } else {
                if let g = dd.pm10Grade { dustLine.append(L("미세먼지 %@", L(DustScale.words[g]))) }
                if let g = dd.pm25Grade, g != dd.pm10Grade { dustLine.append(L("초미세먼지 %@", L(DustScale.words[g]))) }
                if dd.grade >= 2 { dustLine.append(dd.grade >= 3 ? L("외출할 땐 마스크를 착용해 주세요") : L("마스크를 챙겨 주세요")); masked = true }
            }
        }
        var extra: [String] = []
        var warned = false
        if plus {
            if let a = s.alert { extra.append("\(a.name) · \(a.note)"); warned = true }
            else {
                if today, abs(s.yday) >= 2 {
                    let shown = unitF ? Int((Double(abs(s.yday)) * 1.8).rounded()) : abs(s.yday)
                    extra.append(s.yday > 0 ? L("어제보다 %d° 높아요", shown) : L("어제보다 %d° 낮아요", shown))
                }
                if today, s.wind.speed >= 9 { extra.append(L("바람 %@", Rules.windWord(ms: s.wind.speed))) }
                if today, s.aux == "dust", s.dust == nil { extra.append(L("미세먼지 · 마스크 챙기세요")) }   // an older answer without the block
            }
        }
        let skyEmoji = today && s.isSnow ? "🌨️ " : (d.chance >= 60 ? (snowy ? "🌨️ " : "🌧️ ") : s.cover == "clear" && today ? "☀️ " : d.chance >= 30 ? "🌦️ " : "☁️ ")
        var lines: [String] = []
        if !sky.isEmpty { lines.append(skyEmoji + sky.joined(separator: " · ")) }
        if !day.isEmpty { lines.append(day.joined(separator: " · ")) }
        if !dustLine.isEmpty { lines.append((masked ? "😷 " : "") + dustLine.joined(separator: " · ")) }
        if !extra.isEmpty { lines.append((warned ? "⚠️ " : "") + extra.joined(separator: " · ")) }
        if d.chance >= 30, !warned { lines.append(snowy ? "⚠️ " + L("미끄러우니 조심하세요") : "☂️ " + L("우산 챙기세요")) }
        if lines.isEmpty { lines.append(morningBody(d)) }
        return lines.joined(separator: "\n")
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

/// A tapped notification's page: the 월간 리포트 opens the 날씨 달력 at its month. (Set as the delegate at launch, so a
/// tap that opens the app arrives too; banners while the app is open stay off, as without a delegate.)
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    static let shared = NotificationRouter()
    /// The month a 월간 리포트 tap asked for, until the app opens it
    @Published var calendarMonth: String?

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler done: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        if info["open"] as? String == "calendar" {
            let m = info["month"] as? String ?? ""
            DispatchQueue.main.async { self.calendarMonth = m }
        }
        done()
    }
}
