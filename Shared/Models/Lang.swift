import Foundation

/// The language the app speaks: Korean, English, Japanese, and the languages the pixel font can draw — Spanish,
/// French, German, Portuguese, Italian, Indonesian, Russian, Chinese (simplified · traditional). 설정 → 언어 picks one
/// (shared with the widgets through the App Group, and sent to the watch); "기기 설정" follows the device (a language
/// the app lacks → en).
/// Tests set `current` to pin one. User-visible text goes through `L(…)`: the key is the Korean source text, looked up in
/// Shared/Localization/<lang>.lproj/Localizable.strings. A missing key shows the Korean text.
enum Lang: String, CaseIterable {
    case ko, en, ja, es, fr, de, pt, it, id, ru
    case zhHans = "zh-Hans", zhHant = "zh-Hant"

    /// Korean · Japanese · Chinese: wide glyphs, no spaces between words, hour words like 15시 / 15時
    var isCJK: Bool { self == .ko || self == .ja || self == .zhHans || self == .zhHant }
    /// Spanish, French … : Latin letters as wide as English, so English layouts fit
    var isLatinLike: Bool { !isCJK }

    /// The defaults key for the picked language ("" = the device's).
    static let pickKey = "appLanguage"
    private static let store = UserDefaults(suiteName: SharedStore.groupID) ?? .standard
    private static let device = detect()
    /// The language the device asks for (what "기기 설정" means).
    static var deviceLanguage: Lang { device }
    /// Set by tests (and previews) to pin a language.
    private static var pinned: Lang?

    static var current: Lang {
        get { pinned ?? picked ?? device }
        set { pinned = newValue }
    }
    /// The language chosen in 설정 → 언어, nil for the device's.
    static var picked: Lang? {
        get { Lang(rawValue: store.string(forKey: pickKey) ?? "") }
        set { store.set(newValue?.rawValue ?? "", forKey: pickKey) }
    }
    /// The language's own name, the same in every language ("한국어", "English", "日本語").
    var nativeName: String {
        switch self {
        case .ko: return "한국어"; case .en: return "English"; case .ja: return "日本語"; case .es: return "Español"
        case .fr: return "Français"; case .de: return "Deutsch"; case .pt: return "Português (Brasil)"; case .it: return "Italiano"
        case .id: return "Bahasa Indonesia"; case .ru: return "Русский"; case .zhHans: return "简体中文"; case .zhHant: return "繁體中文"
        }
    }
    /// The language's name in English (search, the store)
    var englishName: String {
        switch self {
        case .ko: return "Korean"; case .en: return "English"; case .ja: return "Japanese"; case .es: return "Spanish"
        case .fr: return "French"; case .de: return "German"; case .pt: return "Portuguese (Brazil)"; case .it: return "Italian"
        case .id: return "Indonesian"; case .ru: return "Russian"; case .zhHans: return "Chinese (Simplified)"; case .zhHant: return "Chinese (Traditional)"
        }
    }
    /// What to search a language by: its own name, its English name, and its name in every language the app has
    /// ("한국어", "Korean", "Coreano", "韓国語" all find Korean)
    var searchNames: [String] {
        var out = [nativeName, englishName]
        for l in Lang.allCases {
            if let n = l.locale.localizedString(forIdentifier: lproj) { out.append(n) }
        }
        return out
    }
    /// The code sent to the server (`lang=`).
    var code: String { rawValue }

    static func detect(_ preferred: [String] = Locale.preferredLanguages) -> Lang {
        let first = (preferred.first ?? "en").lowercased()
        if first.hasPrefix("zh") {
            // zh-Hant-TW, zh-HK, zh-TW → traditional; zh-Hans, zh-CN, zh-SG, zh → simplified
            return first.contains("hant") || first.contains("-tw") || first.contains("-hk") || first.contains("-mo") ? .zhHant : .zhHans
        }
        for l in Lang.allCases where l != .zhHans && l != .zhHant && first.hasPrefix(l.rawValue) { return l }
        return .en
    }

    /// The locale used for dates (day names, "10월 21일") in this language.
    var locale: Locale {
        switch self {
        case .ko: return Locale(identifier: "ko_KR"); case .en: return Locale(identifier: "en_US"); case .ja: return Locale(identifier: "ja_JP")
        case .es: return Locale(identifier: "es_ES"); case .fr: return Locale(identifier: "fr_FR"); case .de: return Locale(identifier: "de_DE")
        case .pt: return Locale(identifier: "pt_BR"); case .it: return Locale(identifier: "it_IT"); case .id: return Locale(identifier: "id_ID")
        case .ru: return Locale(identifier: "ru_RU"); case .zhHans: return Locale(identifier: "zh_Hans_CN"); case .zhHant: return Locale(identifier: "zh_Hant_TW")
        }
    }

    /// The folder name of the language's strings: Brazilian Portuguese lives in pt-BR.lproj, the rest under their own code.
    var lproj: String { self == .pt ? "pt-BR" : rawValue }

    /// The .lproj bundle for each language, loaded once (the main bundle when it is missing).
    private static let bundles: [Lang: Bundle] = {
        var d: [Lang: Bundle] = [:]
        for l in Lang.allCases {
            if let p = Bundle.main.path(forResource: l.lproj, ofType: "lproj"), let b = Bundle(path: p) { d[l] = b }
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
        for (p, isPM) in [("上午", false), ("下午", true)] where t.hasPrefix(p) { pm = isPM; t = String(t.dropFirst(p.count)) }
        for s in ["시", "時", "时", " Uhr", " h", "h"] where t.hasSuffix(s) { t = String(t.dropLast(s.count)); break }
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
        case .ja: return clock12 ? (h < 12 ? "午前" : "午後") + "\(h12)時" : "\(h)時"
        case .zhHans: return clock12 ? (h < 12 ? "上午" : "下午") + "\(h12)时" : "\(h)时"
        case .zhHant: return clock12 ? (h < 12 ? "上午" : "下午") + "\(h12)時" : "\(h)時"
        case .de: return clock12 ? "\(h12)\(h < 12 ? "AM" : "PM")" : "\(h) Uhr"
        case .fr: return clock12 ? "\(h12)\(h < 12 ? "AM" : "PM")" : "\(h) h"
        case .pt: return clock12 ? "\(h12)\(h < 12 ? "AM" : "PM")" : "\(h)h"
        default: return clock12 ? "\(h12)\(h < 12 ? "AM" : "PM")" : String(format: "%02d:00", h)   // en es it id ru
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
        case .zhHans: return "\(a)–\(b)时"
        case .zhHant: return "\(a)–\(b)時"
        case .de where !clock12: return "\(a)–\(b) Uhr"
        case .fr where !clock12: return "\(a) h–\(b) h"
        case .pt where !clock12: return "\(a)h–\(b)h"
        default:
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
        if Lang.current.isLatinLike, clock12 { return "\(h % 12 == 0 ? 12 : h % 12):" + String(format: "%02d", m) + (h < 12 ? "AM" : "PM") }
        return "\(h):" + String(format: "%02d", m)
    }
}
