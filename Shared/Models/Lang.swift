import Foundation

/// The language the app speaks: Korean (default), English, Japanese. Chosen once at launch from the device
/// language (ko → ko, ja → ja, everything else → en); tests set `current` to pin one.
/// User-visible text goes through `L(…)`: the key is the Korean source text, looked up in
/// Shared/Localization/<lang>.lproj/Localizable.strings. A missing key shows the Korean text.
enum Lang: String, CaseIterable {
    case ko, en, ja

    static var current: Lang = detect()
    /// The code sent to the server (`lang=`).
    var code: String { rawValue }

    static func detect(_ preferred: [String] = Locale.preferredLanguages) -> Lang {
        let first = (preferred.first ?? "en").lowercased()
        if first.hasPrefix("ko") { return .ko }
        if first.hasPrefix("ja") { return .ja }
        return .en
    }

    /// The locale used for dates (day names, "10월 21일") in this language.
    var locale: Locale {
        switch self {
        case .ko: return Locale(identifier: "ko_KR")
        case .en: return Locale(identifier: "en_US")
        case .ja: return Locale(identifier: "ja_JP")
        }
    }

    /// The .lproj bundle for each language, loaded once (the main bundle when it is missing).
    private static let bundles: [Lang: Bundle] = {
        var d: [Lang: Bundle] = [:]
        for l in Lang.allCases {
            if let p = Bundle.main.path(forResource: l.rawValue, ofType: "lproj"), let b = Bundle(path: p) { d[l] = b }
        }
        return d
    }()

    /// The text for `key` in this language; the key itself (Korean) when the table has no entry.
    func string(_ key: String) -> String {
        guard let b = Self.bundles[self] ?? Self.bundles[.ko] else { return key }
        return b.localizedString(forKey: key, value: key, table: "Localizable")
    }
}

/// The text for a Korean key in the current language.
func L(_ key: String) -> String { Lang.current.string(key) }

/// A format key ("%d시쯤 비 예정") filled in with `args` (en / ja values may reorder them with %1$@ …).
func L(_ key: String, _ args: CVarArg...) -> String { String(format: Lang.current.string(key), arguments: args) }

/// Hour labels the app builds itself, in the current language. The server's own labels ("14시", "2PM", "14時",
/// "지금") are parsed back to an hour so the 12/24-hour setting and the language apply to them too.
enum HourLabel {
    /// "14시" / "오후 2시" / "2PM" / "14:00" / "14時" / "午後2時" → 14; nil for "지금", "Now", "30분" …
    static func hour(_ label: String) -> Int? {
        var t = label.trimmingCharacters(in: .whitespaces)
        var pm: Bool?
        for (p, isPM) in [("오전", false), ("오후", true), ("午前", false), ("午後", true)] where t.hasPrefix(p) {
            pm = isPM; t = String(t.dropFirst(p.count)).trimmingCharacters(in: .whitespaces)
        }
        for s in ["시", "時"] where t.hasSuffix(s) { t = String(t.dropLast(s.count)) }
        let up = t.uppercased()
        if up.hasSuffix("AM") { pm = false; t = String(t.dropLast(2)) } else if up.hasSuffix("PM") { pm = true; t = String(t.dropLast(2)) }
        if let c = t.firstIndex(of: ":") { t = String(t[..<c]) }
        guard let h = Int(t.trimmingCharacters(in: .whitespaces)), (0..<24).contains(h) else { return nil }
        if let pm { return h % 12 + (pm ? 12 : 0) }
        return h
    }

    /// 15 → ko "15시" / "오후 3시" · en "15:00" / "3PM" · ja "15時" / "午後3時"
    static func word(_ h: Int, clock12: Bool) -> String {
        let h12 = h % 12 == 0 ? 12 : h % 12
        switch Lang.current {
        case .ko: return clock12 ? (h < 12 ? "오전 " : "오후 ") + "\(h12)시" : "\(h)시"
        case .en: return clock12 ? "\(h12)\(h < 12 ? "AM" : "PM")" : String(format: "%02d:00", h)
        case .ja: return clock12 ? (h < 12 ? "午前" : "午後") + "\(h12)時" : "\(h)時"
        }
    }

    /// A server hour label in the current language and clock setting; labels that are not an hour stay as they are.
    static func display(_ label: String, clock12: Bool) -> String {
        guard let h = hour(label) else { return label }
        return word(h, clock12: clock12)
    }

    /// 15…17 → ko "15~17시" · en "3–5PM" (12 h) / "15:00–17:00" · ja "15〜17時"
    static func window(_ a: Int, _ b: Int, clock12: Bool) -> String {
        switch Lang.current {
        case .ko: return "\(a)~\(b)시"
        case .ja: return "\(a)〜\(b)時"
        case .en:
            guard clock12 else { return String(format: "%02d:00–%02d:00", a, b) }
            let h = { (x: Int) -> Int in x % 12 == 0 ? 12 : x % 12 }
            let sa = a < 12 ? "AM" : "PM", sb = b < 12 ? "AM" : "PM"
            return sa == sb ? "\(h(a))–\(h(b))\(sb)" : "\(h(a))\(sa)–\(h(b))\(sb)"
        }
    }

    /// Minutes of the day → ko / ja "15:50" · en "3:50PM" (12 h) / "15:50"
    static func clock(_ minutes: Int, clock12: Bool) -> String {
        let t = ((minutes % 1440) + 1440) % 1440
        let h = t / 60, m = t % 60
        if Lang.current == .en, clock12 { return "\(h % 12 == 0 ? 12 : h % 12):" + String(format: "%02d", m) + (h < 12 ? "AM" : "PM") }
        return "\(h):" + String(format: "%02d", m)
    }
}
