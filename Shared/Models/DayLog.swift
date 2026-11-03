import Foundation

/// One day of 날씨 기록 for one place: the day's high and low, its sky, rain or snow, the worst 미세먼지 — written
/// whenever the app or a widget fetches that place's weather.
struct DayRecord: Codable, Equatable, Identifiable {
    var date: String                    // "2026-11-03", the place's own calendar day
    var hi: Int
    var lo: Int
    var icon: String                    // the day's sky (its 10-day row's icon)
    var chance: Int = 0                 // the day's rain chance %
    var wet: String? = nil              // "rain" | "snow": seen falling, or the day forecast wet at 60 %+
    var mm: Double = 0                  // rain or snow the hours seen added up (mm)
    var dust: Int? = nil                // the worst 미세먼지 grade seen (0…3)
    var place: String = ""              // the place's name that day (on a trip, where you were)
    var seenHi: Int? = nil              // the warmest and coldest temperature seen that day
    var seenLo: Int? = nil
    var hours: [String: Double]? = nil  // hour → mm while the day lasts, so two refreshes in one hour count once
    var obs: Bool? = nil                // true: filled in from observations (the server), not by the phone
    // the day in more detail (the calendar's day card)
    var temps: [Int?]? = nil            // 0…23 h: °C as seen, else as last forecast
    var rain: [Double?]? = nil          // 0…23 h: mm as last forecast, at least a trace where it was seen falling
    var seenH: [Int]? = nil             // hours whose temperature was seen (while the day lasts)
    var feelsHi: Int? = nil
    var feelsLo: Int? = nil
    var windMax: Int? = nil             // m/s
    var rh: Int? = nil                  // average humidity %
    var uv: Int? = nil                  // the highest UV
    var alerts: [String]? = nil         // 기상특보 in force that day
    var say: [String]? = nil            // the character's bubble that day: kind, tone, icon, text
    var wetFrom: Int? = nil             // when it rained or snowed (hours, from observations)
    var wetTo: Int? = nil
    var lat: Double? = nil              // where the day was (sunrise · sunset)
    var lon: Double? = nil

    var id: String { date }
    /// The day's outfit, as the notifications draw it: the middle of its range
    var level: Int { Rules.level(feels: Double(hi + lo) / 2) }
    var isWet: Bool { wet != nil }
    var isSnow: Bool { wet == "snow" }
    /// The hours it rained or snowed: observed, else the first and last wet hour of the record
    var wetHours: (Int, Int)? {
        if let a = wetFrom, let b = wetTo { return (a, b) }
        guard let r = rain else { return nil }
        let wet = r.indices.filter { (r[$0] ?? 0) >= 0.1 }
        guard let a = wet.first, let b = wet.last else { return nil }
        return (a, b)
    }

    static func isWetIcon(_ i: String) -> Bool { ["raincloud", "snowflake", "sleet", "lightning"].contains(i) }
    static func isSnowIcon(_ i: String) -> Bool { i == "snowflake" || i == "sleet" }
}

/// 날씨 기록 on the phone: a small file per place in the App Group (about 40 KB a year), kept three years.
/// The app (every refresh, every place it previews) and the widgets (their own refreshes) both write it.
struct DayLog {
    var dir: URL = DayLog.defaultDir
    static let keepDays = 3 * 366

    static var defaultDir: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedStore.groupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("DayLog", isDirectory: true)
    }

    private func file(_ placeID: String) -> URL {
        let safe = placeID.map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" ? String($0) : "_" }.joined()
        return dir.appendingPathComponent("\(safe).json")
    }

    /// Every day kept for the place, oldest first
    func records(_ placeID: String) -> [DayRecord] {
        guard let d = try? Data(contentsOf: file(placeID)), let r = try? JSONDecoder().decode([DayRecord].self, from: d) else { return [] }
        return r.sorted { $0.date < $1.date }
    }

    func save(_ r: [DayRecord], for placeID: String) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(r) { try? d.write(to: file(placeID), options: .atomic) }
    }

    /// Places no longer in the list lose their days (the app passes the ids it still has)
    func keepOnly(_ ids: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        let keep = Set(ids.map { file($0).lastPathComponent })
        for f in files where f.pathExtension == "json" && !keep.contains(f.lastPathComponent) { try? FileManager.default.removeItem(at: f) }
    }

    static func dayKey(_ date: Date, tz: TimeZone) -> String {
        var c = Calendar(identifier: .gregorian); c.timeZone = tz
        let d = c.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", d.year ?? 2000, d.month ?? 1, d.day ?? 1)
    }

    /// Folds one forecast into the place's day: the latest high and low (widened by what was seen), the sky,
    /// rain or snow seen falling, the worst 미세먼지.
    func record(_ s: WeatherScene, place: Place, at now: Date = Date()) {
        guard let today = s.days.first else { return }
        let tz = TimeZone(identifier: place.timeZone) ?? .current
        let key = Self.dayKey(now, tz: tz)
        var c = Calendar(identifier: .gregorian); c.timeZone = tz
        let hour = String(c.component(.hour, from: now))

        var all = records(place.id)
        var r = all.last(where: { $0.date == key }) ?? DayRecord(date: key, hi: today.hi, lo: today.lo, icon: today.icon)
        if r.obs == true { return }                       // an observed day stays as observed
        r.seenHi = max(r.seenHi ?? s.temp, s.temp)
        r.seenLo = min(r.seenLo ?? s.temp, s.temp)
        r.hi = max(today.hi, r.seenHi ?? today.hi)
        r.lo = min(today.lo, r.seenLo ?? today.lo)
        r.icon = today.icon
        r.chance = today.chance
        r.place = place.short
        // rain or snow: falling now (this hour's amount counted once), or the day forecast wet at 60 %+
        let falling = s.precip != "none"
        var hours = r.hours ?? [:]
        if falling { hours[hour] = max(hours[hour] ?? 0, s.hours.first?.mm ?? 0) }
        r.hours = hours
        r.mm = hours.values.reduce(0, +)
        let snowy = s.isSnow || s.precip == "snow" || DayRecord.isSnowIcon(today.icon)
        if falling || r.wet != nil || (today.chance >= 60 && DayRecord.isWetIcon(today.icon)) {
            r.wet = snowy ? "snow" : (r.wet == "snow" ? "snow" : "rain")
        }
        if let g = s.dust?.grade { r.dust = max(r.dust ?? 0, g) }
        Self.detail(&r, s, hour: c.component(.hour, from: now), place: place)

        all.removeAll { $0.date == key }
        // finished days drop their working lists (only today's needs them)
        all = all.map { var x = $0; if x.date != key { x.hours = nil; x.seenH = nil }; return x }
        all.append(r)
        all.sort { $0.date < $1.date }
        if all.count > Self.keepDays { all.removeFirst(all.count - Self.keepDays) }
        save(all, for: place.id)
    }
}

extension DayLog {
    /// The day in detail: the temperature hour by hour (seen, else the latest forecast), rain by the hour, the
    /// feels-like range, the strongest wind, humidity, UV, warnings and the character's bubble.
    static func detail(_ r: inout DayRecord, _ s: WeatherScene, hour now: Int, place: Place) {
        var temps = r.temps ?? Array(repeating: nil, count: 24)
        var rain = r.rain ?? Array(repeating: nil, count: 24)
        var seen = Set(r.seenH ?? [])
        func hourOf(_ label: String) -> Int? { label == "자정" ? 0 : HourLabel.hour(label) }
        // the day sheet's rows for today (every few hours, the past ones as they were)
        var winds: [Double] = [], rhs: [Double] = [], uvs: [Double] = []
        for row in s.dayDetail?.first ?? [] {
            guard let h = hourOf(row.label), h < 24 else { continue }
            if !seen.contains(h) { temps[h] = Int(row.temp.rounded()) }
            winds.append(row.wind); rhs.append(row.rh); uvs.append(row.uv)
        }
        // the next hours, one by one, until the day ends ("지금" first)
        var last = -1
        for (i, row) in s.hours.enumerated() {
            guard let h = i == 0 ? now : hourOf(row.label), h > last else { break }
            last = h
            if !seen.contains(h) { temps[h] = row.temp }
            rain[h] = row.mm
        }
        // what was seen now
        temps[now] = s.temp; seen.insert(now)
        if s.precip != "none" { rain[now] = max(rain[now] ?? 0, s.hours.first?.mm ?? 0, 0.1) }
        r.temps = temps; r.rain = rain; r.seenH = seen.sorted()
        r.feelsHi = max(r.feelsHi ?? s.feels, s.feels)
        r.feelsLo = min(r.feelsLo ?? s.feels, s.feels)
        let windNow = Double(s.wind.speed)
        if let w = (winds + [windNow]).max() { r.windMax = max(r.windMax ?? 0, Int(w.rounded())) }
        if !rhs.isEmpty { r.rh = Int((rhs.reduce(0, +) / Double(rhs.count)).rounded()) }
        if let u = uvs.max() { r.uv = max(r.uv ?? 0, Int(u.rounded())) }
        if let a = s.alert?.name, !a.isEmpty, !(r.alerts ?? []).contains(a) { r.alerts = (r.alerts ?? []) + [a] }
        // the bubble: a warning's shout stays; otherwise the latest word of the day
        if let b = s.bubble, !b.text.isEmpty, !(r.say?.first == "shout" && b.kind != "shout") { r.say = [b.kind, b.tone, b.icon, b.text] }
        r.lat = (place.lat * 100).rounded() / 100; r.lon = (place.lon * 100).rounded() / 100
    }

    /// Observed days from the server: a missing day is added; a day the phone saw takes the observed high, low, sky
    /// and rain, and keeps what only the phone knows (미세먼지, where it was).
    func merge(_ observed: [DayRecord], placeID: String) {
        guard !observed.isEmpty else { return }
        var all = records(placeID)
        var at = Dictionary(all.enumerated().map { ($1.date, $0) }, uniquingKeysWith: { a, _ in a })
        for o in observed {
            if let i = at[o.date] {
                var r = all[i]
                r.hi = o.hi; r.lo = o.lo; r.icon = o.icon; r.mm = o.mm; r.wet = o.wet; r.obs = true; r.hours = nil
                r.wetFrom = o.wetFrom; r.wetTo = o.wetTo
                if let x = o.rh { r.rh = x }
                if let x = o.windMax { r.windMax = x }
                if let x = o.uv { r.uv = x }
                if r.place.isEmpty { r.place = o.place }
                all[i] = r
            } else {
                all.append(o); at[o.date] = all.count - 1
            }
        }
        all.sort { $0.date < $1.date }
        if all.count > Self.keepDays { all.removeFirst(all.count - Self.keepDays) }
        save(all, for: placeID)
    }
}

/// What a month adds up to (the 월간 리포트)
struct MonthReport: Equatable {
    var days: Int                       // days recorded
    var wetDays: Int
    var snowDays: Int
    var hottest: DayRecord?
    var coldest: DayRecord?
    var dustDays: Int?                  // 나쁨 or worse; nil where the month has no 미세먼지 at all
    var level: Int?                     // the outfit worn most
    var mean: Double?                   // the middle of the days' ranges, averaged
    var vsLast: Int?                    // ° warmer (+) or colder (−) than the month before (both need a week of days)

    /// `month`: "2026-11"
    static func make(_ all: [DayRecord], month: String) -> MonthReport {
        let m = all.filter { $0.date.hasPrefix(month + "-") }
        let mean: ([DayRecord]) -> Double? = { $0.isEmpty ? nil : $0.map { Double($0.hi + $0.lo) / 2 }.reduce(0, +) / Double($0.count) }
        var counts: [Int: Int] = [:]
        for r in m { counts[r.level, default: 0] += 1 }
        let level = counts.max { a, b in a.value == b.value ? a.key > b.key : a.value < b.value }?.key
        let withDust = m.filter { $0.dust != nil }
        var vs: Int?
        let prev = all.filter { $0.date.hasPrefix(previous(month) + "-") }
        if m.count >= 7, prev.count >= 7, let a = mean(m), let b = mean(prev) { vs = Int((a - b).rounded()) }
        return MonthReport(days: m.count, wetDays: m.filter { $0.isWet }.count, snowDays: m.filter { $0.isSnow }.count,
                           hottest: m.max { $0.hi == $1.hi ? $0.date > $1.date : $0.hi < $1.hi },
                           coldest: m.min { $0.lo == $1.lo ? $0.date < $1.date : $0.lo < $1.lo },
                           dustDays: withDust.isEmpty ? nil : withDust.filter { ($0.dust ?? 0) >= 2 }.count,
                           level: level, mean: mean(m), vsLast: vs)
    }

    /// "2026-11" → "2026-10"
    static func previous(_ month: String) -> String {
        let p = month.split(separator: "-").compactMap { Int($0) }
        guard p.count == 2 else { return month }
        return p[1] == 1 ? String(format: "%04d-12", p[0] - 1) : String(format: "%04d-%02d", p[0], p[1] - 1)
    }
}

#if DEBUG
extension DayLog {
    /// Made-up days for screenshots: about 75 days before today around the scene's own temperatures, with rain,
    /// a little snow when it is cold, and 미세먼지 in Korea. The same days every run.
    static func sample(for place: Place, scene s: WeatherScene, today: Date = Date()) -> [DayRecord] {
        let tz = TimeZone(identifier: place.timeZone) ?? .current
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 11) / Double(1 << 53) }
        let hi0 = Double(s.days.first?.hi ?? s.hi), lo0 = Double(s.days.first?.lo ?? s.lo)
        var out: [DayRecord] = []
        for back in stride(from: 74, through: 0, by: -1) {
            let d = today.addingTimeInterval(Double(-back) * 86400)
            // a little warmer further back (the season turning), with a few-day wobble
            let drift = Double(back) * 0.09 + 2.2 * sin(Double(back) / 3.1)
            let hi = Int((hi0 + drift + (rnd() - 0.5) * 3).rounded())
            let lo = min(hi - 3, Int((lo0 + drift + (rnd() - 0.5) * 3).rounded()))
            let x = rnd()
            let cold = Double(hi + lo) / 2 < 2
            let icon = x < 0.18 ? (cold ? "snowflake" : "raincloud") : x < 0.24 && !cold ? "lightning" : x < 0.45 ? "cloud" : x < 0.7 ? "partly_cloudy" : "sun"
            var r = DayRecord(date: DayLog.dayKey(d, tz: tz), hi: hi, lo: lo, icon: icon, chance: DayRecord.isWetIcon(icon) ? 70 + Int(rnd() * 25) : Int(rnd() * 30))
            if DayRecord.isWetIcon(icon) { r.wet = DayRecord.isSnowIcon(icon) ? "snow" : "rain"; r.mm = (rnd() * 18).rounded() + 1 }
            if place.region == "kr" { let y = rnd(); r.dust = y < 0.45 ? 0 : y < 0.8 ? 1 : y < 0.95 ? 2 : 3 }
            r.place = place.short
            if back == 0 { r.hi = s.days.first?.hi ?? s.hi; r.lo = s.days.first?.lo ?? s.lo; r.icon = s.days.first?.icon ?? r.icon }
            // the day in detail: coldest near dawn, warmest mid-afternoon; rain in a run of hours
            let low = Double(r.lo), span = Double(r.hi - r.lo)
            var temps: [Int?] = []
            for h in 0..<24 {
                let angle: Double = Double(h - 15) / 24.0 * 2.0 * Double.pi
                let x: Double = (cos(angle) + 1.0) / 2.0                         // 1 at 15 h, 0 at 3 h
                let k: Double = h < 6 ? 0.05 * Double(6 - h) : 0.0               // still falling until dawn
                let t: Double = low + span * max(0.0, x - k)
                temps.append(Int(t.rounded()))
            }
            r.temps = temps
            if r.isWet {
                let a = Int(rnd() * 12), b = min(23, a + 3 + Int(rnd() * 9))
                r.rain = (0..<24).map { $0 >= a && $0 <= b ? (rnd() * 3).rounded() / 2 + 0.5 : nil }
                r.mm = (r.rain ?? []).compactMap { $0 }.reduce(0, +)
                r.say = ["speech", "sky", DayRecord.isSnowIcon(icon) ? "snowflake" : "umbrella", L("우산 챙기세요")]
            } else if (r.dust ?? 0) >= 2 {
                r.say = ["speech", "coral", "mask", L("미세먼지 나쁨 · 마스크 챙기세요")]
            }
            if icon == "lightning" { r.alerts = [L("호우경보")] }
            r.feelsLo = r.lo - 2; r.feelsHi = r.hi - 1
            r.windMax = 2 + Int(rnd() * 8); r.rh = 40 + Int(rnd() * 50); r.uv = max(0, Int((Double(r.hi) / 5 - rnd() * 2).rounded()))
            r.lat = place.lat; r.lon = place.lon
            out.append(r)
        }
        // a few days the phone never opened
        for i in [9, 23, 24, 51] where i < out.count { out.remove(at: out.count - 1 - i) }
        return out
    }
}
#endif
