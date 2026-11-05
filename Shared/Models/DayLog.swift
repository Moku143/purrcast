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
    var place: String = ""              // the place's name that day (on a trip, where you were), in the language then
    var placeKo: String? = nil          // the same in Korean, for a Korean place (shown again in any language)
    var seenHi: Int? = nil              // the warmest and coldest temperature seen that day
    var seenLo: Int? = nil
    var hours: [String: Double]? = nil  // hour → mm while the day lasts, so two refreshes in one hour count once
    var obs: Bool? = nil                // true: filled in from observations (the server), not by the phone
    // the day in more detail (the calendar's day card)
    var temps: [Int?]? = nil            // 0…23 h: °C as seen, else as last forecast
    var rain: [Double?]? = nil          // 0…23 h: mm as last forecast, at least a trace where it was seen falling
    var winds: [Int?]? = nil            // 0…23 h: wind m/s (every few hours, from the day sheet)
    var rhs: [Int?]? = nil              // 0…23 h: humidity %
    var uvs: [Int?]? = nil              // 0…23 h: UV index
    var seenH: [Int]? = nil             // hours whose temperature was seen (while the day lasts)
    var windMax: Int? = nil             // m/s
    var rh: Int? = nil                  // average humidity %
    var uv: Int? = nil                  // the highest UV
    var alerts: [String]? = nil         // 기상특보 in force that day
    var wetFrom: Int? = nil             // when it rained or snowed (hours, from observations)
    var wetTo: Int? = nil
    var lat: Double? = nil              // where the day was (sunrise · sunset)
    var lon: Double? = nil
    var tz: String? = nil               // that place's time zone (its country: the day's holidays, on a trip too)
    var cc: String? = nil               // the country that day ("KR")
    var city: String? = nil             // the city that day ("서울" — Korean for a Korean city), for the stays
    var confirmed: Date? = nil          // when the day's place was last confirmed (the last look that wrote it)
    /// The day sheet's own rows for the day (the last forecast of it seen, past hours as they were) and that day's
    /// 미세먼지 readings by the hour: the past day opens in the same day sheet as a forecast day. Kept a little over a
    /// year; older days keep their summary only.
    var rows: [WeatherScene.DayHour]? = nil
    var air: WeatherScene.Dust? = nil
    /// 대기질 (Plus): the day's highest index (통합대기환경지수 in Korea; nil abroad, where only the step is known),
    /// its step, main pollutant, kind (cai | pm) and the hour it peaked
    var aqi: Int? = nil
    var aqiGrade: Int? = nil
    var aqiMain: String? = nil
    var aqiKind: String? = nil
    var aqiHour: Int? = nil
    /// The day's average feels-like (°C, its hours as last seen) and the character shown as the day ended
    var feels: Double? = nil
    var char: String? = nil
    /// Recorded while Plus was on (the 날씨 달력 keeps only these days; nil: a day kept before this was known)
    var plus: Bool? = nil

    var id: String { date }
    /// The day's outfit: its average feels-like; the middle of its range for a day without hours
    var level: Int { Rules.level(feels: feels ?? Double(hi + lo) / 2) }
    var character: PurrCharacter? { char.flatMap(PurrCharacter.init(rawValue:)) }
    /// Where the day was, in the language shown now (a Korean place from its Korean name)
    func placeName(_ lang: Lang = .current) -> String { placeKo.map { KoreanNames.word($0, lang) } ?? place }
    /// The day sheet's full place ("서울 마포구"): the city with the district
    func fullPlaceName(_ lang: Lang = .current) -> String {
        let d = placeName(lang)
        guard let raw = city, !raw.isEmpty else { return d }
        let c = KoreanNames.word(raw, lang)
        return c == d || d.isEmpty ? (d.isEmpty ? c : d) : KoreanNames.join([c, d])
    }
    var isWet: Bool { wet != nil }
    var isSnow: Bool { wet == "snow" }
    /// Rain (mm) recorded for one hour, 0 when none
    func rain(at h: Int) -> Double {
        guard let r = rain, h >= 0, h < r.count, let v = r[h] else { return 0 }
        return v
    }
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
    /// Days that keep their hours (the day sheet); older ones keep the summary
    static let detailDays = 400
    /// "지금 위치" farther than this from where the day began starts the day over there — city scale, so an
    /// ordinary commute (which crosses 5 km and a district name) keeps the morning's seen rain and temperatures
    static let restartKm = 30.0
    /// A small move: the unnamed fix keeps the previous name, and the 대기질 reading still counts as this place's
    static let moveKm = 5.0

    static func km(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
        let r = Double.pi / 180, x = (d - b) * r * cos((a + c) / 2 * r), y = (c - a) * r
        return (x * x + y * y).squareRoot() * 6371
    }

    /// The widget's last refresh of the day: a little before midnight where the place is (when the next one would come
    /// later), so the 날씨 기록 closes with where the phone is then. nil when the regular one comes first.
    static func closingRefresh(after now: Date, regular next: Date, tz: TimeZone) -> Date? {
        var c = Calendar(identifier: .gregorian); c.timeZone = tz
        guard let at = c.nextDate(after: now, matching: DateComponents(hour: 23, minute: 55), matchingPolicy: .nextTime),
              at < next, at.timeIntervalSince(now) > 120 else { return nil }
        return at
    }

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

    /// The days only the server filled in (the phone never saw them) go: the calendar keeps the days used
    func dropFilled(_ placeID: String) {
        let all = records(placeID)
        let kept = all.filter { $0.obs != true || $0.seenHi != nil }
        if kept.count != all.count { save(kept, for: placeID) }
    }

    /// Places no longer in the list lose their days (the app passes the ids it still has). The "here" file is the
    /// 날씨 달력's whole timeline, so it stays whatever the list says (location turned off must not erase the past).
    func keepOnly(_ ids: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        let keep = Set(ids.union(["here"]).map { file($0).lastPathComponent })
        for f in files where f.pathExtension == "json" && !keep.contains(f.lastPathComponent) { try? FileManager.default.removeItem(at: f) }
    }

    static func dayKey(_ date: Date, tz: TimeZone) -> String {
        var c = Calendar(identifier: .gregorian); c.timeZone = tz
        let d = c.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", d.year ?? 2000, d.month ?? 1, d.day ?? 1)
    }

    /// Folds one forecast into the place's day: the latest high and low (widened by what was seen), the sky,
    /// rain or snow seen falling, the worst 미세먼지, the character shown.
    /// The day is where the phone was as it ended: "지금 위치" moved more than `restartKm` starts the day over at the new
    /// place (its forecast has the whole day, the past hours as they were), so the last look before midnight decides it.
    func record(_ s: WeatherScene, place: Place, character: PurrCharacter? = nil, plus: Bool? = nil, at now: Date = Date()) {
        guard let today = s.days.first else { return }
        let tz = TimeZone(identifier: place.timeZone) ?? .current
        let key = Self.dayKey(now, tz: tz)
        var c = Calendar(identifier: .gregorian); c.timeZone = tz
        let hour = String(c.component(.hour, from: now))

        var all = records(place.id)
        let fresh = DayRecord(date: key, hi: today.hi, lo: today.lo, icon: today.icon)
        var r = all.last(where: { $0.date == key }) ?? fresh
        if r.obs == true { return }                       // an observed day stays as observed
        if let la = r.lat, let lo = r.lon, Self.km(la, lo, place.lat, place.lon) > Self.restartKm { r = fresh }
        if let c = character { r.char = c.rawValue }
        if let p = plus, r.plus != true { r.plus = p }     // a day seen with Plus at any time stays a Plus day
        r.seenHi = max(r.seenHi ?? s.temp, s.temp)
        r.seenLo = min(r.seenLo ?? s.temp, s.temp)
        r.hi = max(today.hi, r.seenHi ?? today.hi)
        r.lo = min(today.lo, r.seenLo ?? today.lo)
        r.icon = today.icon
        r.chance = today.chance
        r.place = place.short
        r.tz = place.timeZone
        // the day's country and city, for the stays and flags (the city in Korean for a Korean place)
        r.cc = place.cc ?? (place.region == "kr" ? "KR" : place.region == "jp" ? "JP" : nil)
        r.city = (place.region == "kr" ? place.ko : nil).flatMap { $0.split(separator: " ").first.map(String.init) }
            ?? place.name.split(separator: " ").first.map(String.init)
        r.confirmed = now                                                 // when this place was last confirmed
        r.placeKo = place.region == "kr" ? place.ko.flatMap { $0.split(separator: " ").last.map(String.init) } : nil
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
        // finished days drop their working lists (only today's needs them); after a year and a bit, the hours go too
        let cut = Self.dayKey(now.addingTimeInterval(-Double(Self.detailDays) * 86400), tz: tz)
        all = all.map { var x = $0
            if x.date != key { x.hours = nil; x.seenH = nil }
            if x.date < cut { x.rows = nil; x.air = nil; x.temps = nil; x.rain = nil; x.winds = nil; x.rhs = nil; x.uvs = nil }
            return x }
        all.append(r)
        all.sort { $0.date < $1.date }
        if all.count > Self.keepDays { all.removeFirst(all.count - Self.keepDays) }
        save(all, for: place.id)
    }
}

extension DayLog {
    /// The day in detail: the temperature hour by hour (seen, else the latest forecast), rain by the hour, the
    /// the strongest wind, humidity, UV and warnings.
    static func detail(_ r: inout DayRecord, _ s: WeatherScene, hour now: Int, place: Place) {
        var temps = r.temps ?? Array(repeating: nil, count: 24)
        var rain = r.rain ?? Array(repeating: nil, count: 24)
        var seen = Set(r.seenH ?? [])
        func hourOf(_ label: String) -> Int? { label == "자정" ? 0 : HourLabel.hour(label) }
        // the day sheet's rows for today (every few hours, the past ones as they were)
        var winds: [Double] = [], rhs: [Double] = [], uvs: [Double] = []
        var windH = r.winds ?? Array(repeating: nil, count: 24), rhH = r.rhs ?? Array(repeating: nil, count: 24), uvH = r.uvs ?? Array(repeating: nil, count: 24)
        for row in s.dayDetail?.first ?? [] {
            guard let h = hourOf(row.label), h < 24 else { continue }
            if !seen.contains(h) { temps[h] = Int(row.temp.rounded()) }
            winds.append(row.wind); rhs.append(row.rh); uvs.append(row.uv)
            windH[h] = Int(row.wind.rounded()); rhH[h] = Int(row.rh.rounded()); uvH[h] = Int(row.uv.rounded())
        }
        windH[now] = s.wind.speed
        r.winds = windH; r.rhs = rhH; r.uvs = uvH
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
        let windNow = Double(s.wind.speed)
        if let w = (winds + [windNow]).max() { r.windMax = max(r.windMax ?? 0, Int(w.rounded())) }
        if !rhs.isEmpty { r.rh = Int((rhs.reduce(0, +) / Double(rhs.count)).rounded()) }
        if let u = uvs.max() { r.uv = max(r.uv ?? 0, Int(u.rounded())) }
        if let a = s.alert?.name, !a.isEmpty, !(r.alerts ?? []).contains(a) { r.alerts = (r.alerts ?? []) + [a] }
        r.feels = Self.averageFeels(temps: temps, winds: windH, rhs: rhH, rainy: (s.days.first?.chance ?? 0) >= 50) ?? r.feels
        r.lat = (place.lat * 100).rounded() / 100; r.lon = (place.lon * 100).rounded() / 100
        if let rows = s.dayDetail?.first, rows.count >= 2 { r.rows = rows }
        if let d = s.dust, let hs = d.hours, !hs.isEmpty {
            r.air = WeatherScene.Dust(pm10: nil, pm25: nil, pm10Grade: nil, pm25Grade: nil, grade: d.grade, note: "", src: "", srcKey: d.srcKey, hours: hs)
        }
    }

    /// The day's average feels-like from its hours (the gaps between the day sheet's rows filled in straight); nil with
    /// fewer than six temperatures
    static func averageFeels(temps: [Int?], winds: [Int?], rhs: [Int?], rainy: Bool) -> Double? {
        guard temps.count == 24, temps.compactMap({ $0 }).count >= 6 else { return nil }
        func filled(_ a: [Int?], _ none: Double) -> [Double] {
            let known = a.indices.compactMap { i in a[i].map { (i, Double($0)) } }
            guard !known.isEmpty else { return Array(repeating: none, count: 24) }
            return (0..<24).map { h in
                let before = known.last { $0.0 <= h }, after = known.first { $0.0 >= h }
                switch (before, after) {
                case let (b?, f?): return b.0 == f.0 ? b.1 : b.1 + (f.1 - b.1) * Double(h - b.0) / Double(f.0 - b.0)
                case let (b?, nil): return b.1
                case let (nil, f?): return f.1
                default: return none
                }
            }
        }
        let t = filled(temps, 0), w = filled(winds.count == 24 ? winds : Array(repeating: nil, count: 24), 2)
        let h = filled(rhs.count == 24 ? rhs : Array(repeating: nil, count: 24), 60)
        let sum = (0..<24).reduce(0.0) { $0 + Rules.hourFeel(temp: t[$1], hour: $1, wind: w[$1], rh: h[$1], rainy: rainy) }
        return (sum / 24 * 10).rounded() / 10
    }

    /// The 대기질 map's index for the place now, kept as the day's highest (the map refreshes hourly, Plus)
    func recordAir(value: Int?, grade: Int, main: String?, kind: String, place: Place, at now: Date = Date()) {
        let tz = TimeZone(identifier: place.timeZone) ?? .current
        let key = Self.dayKey(now, tz: tz)
        var all = records(place.id)
        guard let i = all.lastIndex(where: { $0.date == key }) else { return }      // a day the forecast already began
        var r = all[i]
        var c = Calendar(identifier: .gregorian); c.timeZone = tz
        let higher = (value ?? -1) > (r.aqi ?? -1) || (value == nil && grade > (r.aqiGrade ?? -1))
        if r.aqiGrade == nil || higher {
            r.aqi = value; r.aqiGrade = grade; r.aqiMain = main; r.aqiHour = c.component(.hour, from: now)
        }
        r.aqiKind = kind
        all[i] = r
        save(all, for: place.id)
    }

    /// Observed days from the server: a missing day is added; a day the phone saw takes the observed high, low, sky
    /// and rain, and keeps what only the phone knows (미세먼지, where it was). A day the phone spent somewhere else
    /// ("지금 위치" on a trip; `near` is where the observations are for) stays as the phone had it.
    func merge(_ observed: [DayRecord], placeID: String, near: (Double, Double)? = nil) {
        guard !observed.isEmpty else { return }
        var all = records(placeID)
        var at = Dictionary(all.enumerated().map { ($1.date, $0) }, uniquingKeysWith: { a, _ in a })
        for o in observed {
            if let i = at[o.date] {
                var r = all[i]
                if let n = near, let la = r.lat, let lo = r.lon, Self.km(la, lo, n.0, n.1) > Self.moveKm { continue }
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
    var character: PurrCharacter?       // the character shown on most of the days (nil: none recorded)
    var mean: Double?                   // the middle of the days' ranges, averaged
    var vsLast: Int?                    // ° warmer (+) or colder (−) than the month before (both need a week of days)

    /// `month`: "2026-11"
    static func make(_ all: [DayRecord], month: String) -> MonthReport {
        let m = all.filter { $0.date.hasPrefix(month + "-") }
        let mean: ([DayRecord]) -> Double? = { $0.isEmpty ? nil : $0.map { Double($0.hi + $0.lo) / 2 }.reduce(0, +) / Double($0.count) }
        var counts: [Int: Int] = [:]
        for r in m { counts[r.level, default: 0] += 1 }
        let level = counts.max { a, b in a.value == b.value ? a.key > b.key : a.value < b.value }?.key
        var chars: [PurrCharacter: Int] = [:]
        for r in m { if let c = r.character { chars[c, default: 0] += 1 } }
        let character = chars.max { a, b in a.value == b.value ? a.key.rawValue > b.key.rawValue : a.value < b.value }?.key
        let withDust = m.filter { $0.dust != nil }
        var vs: Int?
        let prev = all.filter { $0.date.hasPrefix(previous(month) + "-") }
        if m.count >= 7, prev.count >= 7, let a = mean(m), let b = mean(prev) { vs = Int((a - b).rounded()) }
        return MonthReport(days: m.count, wetDays: m.filter { $0.isWet }.count, snowDays: m.filter { $0.isSnow }.count,
                           hottest: m.max { $0.hi == $1.hi ? $0.date > $1.date : $0.hi < $1.hi },
                           coldest: m.min { $0.lo == $1.lo ? $0.date < $1.date : $0.lo < $1.lo },
                           dustDays: withDust.isEmpty ? nil : withDust.filter { ($0.dust ?? 0) >= 2 }.count,
                           level: level, character: character, mean: mean(m), vsLast: vs)
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
            if back == 0 {
                // today as the scene has it: its range and sky, wet when its sky is
                r.hi = s.days.first?.hi ?? s.hi; r.lo = s.days.first?.lo ?? s.lo; r.icon = s.days.first?.icon ?? r.icon
                r.wet = DayRecord.isWetIcon(r.icon) ? (DayRecord.isSnowIcon(r.icon) ? "snow" : "rain") : nil
            }
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
                let a = back == 0 ? 15 : Int(rnd() * 12), b = back == 0 ? 19 : min(23, a + 3 + Int(rnd() * 9))
                r.rain = (0..<24).map { $0 >= a && $0 <= b ? (rnd() * 3).rounded() / 2 + 0.5 : nil }
                r.mm = (r.rain ?? []).compactMap { $0 }.reduce(0, +)
            } else {
                r.rain = nil; r.mm = 0
            }
            if r.icon == "lightning" { r.alerts = [L("호우경보")] }
            r.windMax = 2 + Int(rnd() * 8); r.rh = 40 + Int(rnd() * 50); r.uv = max(0, Int((Double(r.hi) / 5 - rnd() * 2).rounded()))
            // every three hours, as the day sheet gives them: wind picks up in the afternoon, the air dries by day, UV peaks at noon
            var w: [Int?] = Array(repeating: nil, count: 24), h: [Int?] = Array(repeating: nil, count: 24), u: [Int?] = Array(repeating: nil, count: 24)
            for t in stride(from: 0, to: 24, by: 3) {
                let day: Double = max(0.0, sin(Double(t - 6) / 12.0 * Double.pi))     // 0 at night, 1 at noon
                w[t] = max(1, Int((Double(r.windMax ?? 4) * (0.45 + 0.55 * day)).rounded()))
                h[t] = min(98, Int((Double(r.rh ?? 60) + 18.0 * (0.5 - day)).rounded()))
                u[t] = Int((Double(r.uv ?? 0) * day).rounded())
            }
            r.winds = w; r.rhs = h; r.uvs = u
            r.feels = DayLog.averageFeels(temps: temps, winds: w, rhs: h, rainy: r.isWet)
            if let g = r.dust {
                // 미세먼지 hour by hour around the day's step (worse in the morning rush and the evening), and the index
                let base10: Double = [22, 55, 110, 170][max(0, min(3, g))]
                var hs: [WeatherScene.Dust.Reading] = []
                for t in 0..<24 {
                    let wave: Double = 1.0 + 0.25 * sin(Double(t - 4) / 24.0 * 2.0 * Double.pi) + (rnd() - 0.5) * 0.15
                    let p10 = (base10 * wave).rounded()
                    hs.append(WeatherScene.Dust.Reading(hour: t, pm10: p10, pm25: (p10 * 0.55).rounded()))
                }
                r.air = WeatherScene.Dust(pm10: nil, pm25: nil, pm10Grade: nil, pm25Grade: nil, grade: g, note: "", src: "", srcKey: "airkorea", hours: hs)
                r.aqi = [38, 72, 142, 268][max(0, min(3, g))] + Int(rnd() * 8); r.aqiGrade = g; r.aqiMain = g >= 2 ? "pm10" : "pm25"
                r.aqiKind = "cai"; r.aqiHour = 9
            }
            r.lat = place.lat; r.lon = place.lon
            out.append(r)
        }
        // a few days the phone never opened
        for i in [9, 23, 24, 51] where i < out.count { out.remove(at: out.count - 1 - i) }
        return out
    }
}
#endif

/// One run of days spent in one city, for the 날씨 달력: consecutive recorded days make a stay, and a stay ends
/// when the country or the city changes. Records too old to carry a city fall back to a move over 30 km.
struct Stay: Equatable {
    var cc: String?
    var city: String
    var from: String
    var to: String
    var days: Int
    var lat: Double? = nil              // the newest day's spot (the 30-km rule for city-less old records)
    var lon: Double? = nil

    /// "🇯🇵" for a two-letter country, else nil (the view shows the letters instead)
    static func flag(_ cc: String?) -> String? {
        guard let cc, cc.count == 2, cc.uppercased().allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
        return String(cc.uppercased().unicodeScalars.compactMap { UnicodeScalar(0x1F1E6 + $0.value - 65).map(Character.init) })
    }
}

enum Stays {
    /// The stays in `records` (oldest first). A day without any place information joins the stay it follows.
    static func make(_ records: [DayRecord]) -> [Stay] {
        var out: [Stay] = []
        for r in records.sorted(by: { $0.date < $1.date }) {
            let city = r.city ?? r.placeName(.ko)
            if var last = out.popLast() {
                if !changed(from: last, to: r) {
                    last.to = r.date; last.days += 1
                    last.lat = r.lat ?? last.lat; last.lon = r.lon ?? last.lon
                    if last.city.isEmpty { last.city = city }
                    out.append(last); continue
                }
                out.append(last)
            }
            out.append(Stay(cc: r.cc, city: city, from: r.date, to: r.date, days: 1, lat: r.lat, lon: r.lon))
        }
        return out
    }

    private static func changed(from a: Stay, to b: DayRecord) -> Bool {
        if let ac = a.cc, let bc = b.cc, ac != bc { return true }
        if let bCity = b.city, !a.city.isEmpty { return a.city != bCity }
        // old records without a city: a move over 30 km ends the stay
        if let la = a.lat, let lo = a.lon, let lb = b.lat, let ob = b.lon { return DayLog.km(la, lo, lb, ob) > 30 }
        return false
    }
}

extension WeatherScene.DayHour: Equatable {
    static func == (a: Self, b: Self) -> Bool {
        a.label == b.label && a.temp == b.temp && a.chance == b.chance && a.wind == b.wind && a.uv == b.uv && a.rh == b.rh
            && a.mm == b.mm && a.gust == b.gust && a.dir == b.dir
    }
}

extension DayRecord {
    /// The day as a scene for the day sheet: its own rows when the phone kept them, else rows made from the hourly
    /// values (temperature, rain, wind, humidity, UV); nil for a day with too little to draw (an observed day only).
    func scene(tz: TimeZone) -> WeatherScene? {
        var rows = self.rows ?? []
        if rows.count < 2, let t = temps, t.compactMap({ $0 }).count >= 3 {
            // the hours with a temperature, as the day sheet's rows: [label, °C, chance, wind, UV, humidity, mm]
            var arr: [[Any]] = []
            for h in 0..<24 {
                guard let temp = t[h] else { continue }
                let mm = rain(at: h)
                func near(_ a: [Int?]?) -> Double {
                    guard let a, a.count == 24 else { return 0 }
                    if let v = a[h] { return Double(v) }
                    // the nearest hour that has one (wind, humidity and UV come every few hours)
                    for d in 1..<24 { if h - d >= 0, let v = a[h - d] { return Double(v) }; if h + d < 24, let v = a[h + d] { return Double(v) } }
                    return 0
                }
                arr.append(["\(h):00", temp, mm >= 0.1 ? 80 : 0, near(winds), near(uvs), near(rhs), mm])
            }
            if let data = try? JSONSerialization.data(withJSONObject: arr),
               let made = try? JSONDecoder().decode([WeatherScene.DayHour].self, from: data) { rows = made }
        }
        guard rows.count >= 2 else { return nil }
        var s = WeatherScene()
        s.days = [WeatherScene.DayRow(name: "", icon: icon, chance: isWet ? max(chance, 60) : chance, lo: lo, hi: hi)]
        s.dayDetail = [rows]
        s.time = "day"; s.level = level; s.clock = ""          // no "now": the whole day is past
        s.hi = hi; s.lo = lo; s.temp = hi; s.place = place
        s.snow = isSnow
        s.dust = air
        if let a = alerts?.first { s.alert = WeatherScene.Alert(name: a, note: "") }   // the day's 기상특보
        if let w = windMax { s.wind = WeatherScene.Wind(speed: w, gust: 0, deg: 0) }
        // sunrise and sunset, for the night icons
        if let la = lat, let lo = lon, let d = DayLog.date(date), let sun = SunTimes.day(d, lat: la, lon: lo, tz: tz) {
            var c = Calendar(identifier: .gregorian); c.timeZone = tz
            func hm(_ x: Date) -> String { String(format: "%02d:%02d", c.component(.hour, from: x), c.component(.minute, from: x)) }
            s.tiles = [Self.tile("sunrise", hm(sun.rise)), Self.tile("sunset", hm(sun.set))]
        }
        return s
    }

    private static func tile(_ icon: String, _ value: String) -> WeatherScene.Tile {
        let j = "{\"icon\":\"\(icon)\",\"label\":\"\",\"value\":\"\(value)\",\"note\":\"\"}"
        return (try? JSONDecoder().decode(WeatherScene.Tile.self, from: Data(j.utf8)))!
    }
}

extension DayLog {
    /// "2026-11-03" → that day at noon UTC
    static func date(_ key: String) -> Date? {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!
        return c.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 12))
    }
}
