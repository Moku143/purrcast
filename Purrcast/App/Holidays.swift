import Foundation

/// Public holidays in every country, for the 날씨 달력: Purrcast/Resources/Holidays.json, made by
/// tools/holidays/make.py from the open-source `holidays` package (national holidays with substitute days —
/// 대체공휴일, 振替休日, "observed"). The place's country comes from its time zone (zone.tab).
enum Holidays {
    private struct File: Decodable { let zones: [String: String]; let countries: [String: Country] }
    /// `lang`: the country's own language (the app's code); a day's names: "" in that language, else by app language
    private struct Country: Decodable { let lang: String; let days: [String: [String: String]] }

    private static let file: File? = {
        guard let url = Bundle.main.url(forResource: "Holidays", withExtension: "json"), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(File.self, from: data)
    }()

    /// "KR" for "Asia/Seoul"
    static func country(timeZone: String) -> String? { file?.zones[timeZone] }

    /// The holiday on a day ("2026-10-05") where the place is: in the app's language, else English, else the
    /// country's own; nil on an ordinary day
    static func name(_ key: String, timeZone: String, lang: Lang = .current) -> String? {
        guard let cc = country(timeZone: timeZone), let c = file?.countries[cc], let d = c.days[key] else { return nil }
        if c.lang == lang.rawValue, let own = d[""] { return own }
        return d[lang.rawValue] ?? d["en"] ?? d[""]
    }

    /// The month's holidays ("2026-10"), day by day — each day where it was spent (`timeZone` of the day: on a trip
    /// the days abroad take that country's holidays)
    static func month(_ month: String, timeZone: (String) -> String, lang: Lang = .current) -> [(key: String, name: String)] {
        (1...DayLogText.length(month)).compactMap { d in
            let k = String(format: "%@-%02d", month, d)
            return name(k, timeZone: timeZone(k), lang: lang).map { (k, $0) }
        }
    }
}
