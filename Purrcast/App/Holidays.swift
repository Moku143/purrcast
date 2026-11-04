import Foundation

/// Public holidays for the 날씨 달력, in every country: substitute days (대체공휴일, 振替休日, "observed"), election days
/// and the like, from the server (/v1/holidays, made from the open-source `holidays` package). The app keeps only its
/// countries' latest tables — each new one replaces the last — and asks again when the calendar opens a week later.
/// A place's country comes from its time zone (Purrcast/Resources/HolidayZones.json, from zone.tab).
enum Holidays {
    struct Table: Codable {
        let cc: String
        /// The country's own language (the app's code; nil for a country with no holidays known); a day's names:
        /// "" in that language, else by app language
        let lang: String?
        let days: [String: [String: String]]
        var fetched: Date?
    }

    /// How long a table is good for before the calendar asks for a newer one (a newly set 임시공휴일 shows within it)
    static let fresh: TimeInterval = 7 * 86400

    private static let zones: [String: String] = {
        guard let url = Bundle.main.url(forResource: "HolidayZones", withExtension: "json"), let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }()
    private static let lock = NSLock()
    private static var tables: [String: Table] = [:]

    static var dir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Holidays", isDirectory: true)
    }
    private static func file(_ cc: String) -> URL { dir.appendingPathComponent("\(cc).json") }

    /// "KR" for "Asia/Seoul"
    static func country(timeZone: String) -> String? { zones[timeZone] }

    /// The country's table as last received (from memory, else the phone)
    static func table(_ cc: String) -> Table? {
        lock.lock(); defer { lock.unlock() }
        if let t = tables[cc] { return t }
        guard let d = try? Data(contentsOf: file(cc)), let t = try? JSONDecoder().decode(Table.self, from: d) else { return nil }
        tables[cc] = t
        return t
    }

    /// A table from the server takes the place of the one kept (nothing older stays on the phone)
    @discardableResult
    static func install(_ data: Data, fetched: Date = Date()) -> Table? {
        guard var t = try? JSONDecoder().decode(Table.self, from: data) else { return nil }
        t.fetched = fetched
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(t) { try? d.write(to: file(t.cc), options: .atomic) }
        lock.lock(); tables[t.cc] = t; lock.unlock()
        return t
    }

    /// Asks the server for the countries whose table is missing or a week old; true when any came
    static func refresh(_ countries: Set<String>, base: URL, now: Date = Date()) async -> Bool {
        var got = false
        for cc in countries.sorted() {
            if let t = table(cc), let f = t.fetched, now.timeIntervalSince(f) < fresh { continue }
            var c = URLComponents(url: base.appendingPathComponent("v1/holidays"), resolvingAgainstBaseURL: false)!
            c.queryItems = [URLQueryItem(name: "cc", value: cc)]
            guard let url = c.url, let res = try? await URLSession.shared.data(from: url),
                  (res.1 as? HTTPURLResponse)?.statusCode == 200, let t = install(res.0, fetched: now), t.cc == cc else { continue }
            got = true
        }
        return got
    }

    /// The holiday on a day ("2026-10-05") where the place is: in the app's language, else English, else the
    /// country's own; nil on an ordinary day (or before the country's table has come)
    static func name(_ key: String, timeZone: String, lang: Lang = .current) -> String? {
        guard let cc = country(timeZone: timeZone), let c = table(cc), let d = c.days[key] else { return nil }
        if c.lang == lang.rawValue, let own = d[""] { return own }
        return d[lang.rawValue] ?? d["en"] ?? d[""]
    }

    /// The month's holidays ("2026-10"), day by day — each day where it was spent (`timeZone` of the day: a day
    /// recorded abroad takes that country's holidays)
    static func month(_ month: String, timeZone: (String) -> String, lang: Lang = .current) -> [(key: String, name: String)] {
        (1...DayLogText.length(month)).compactMap { d in
            let k = String(format: "%@-%02d", month, d)
            return name(k, timeZone: timeZone(k), lang: lang).map { (k, $0) }
        }
    }
}
