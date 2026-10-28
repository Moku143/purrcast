import Foundation

/// One line of a place search: a country, a region (state · province · prefecture), or a Korean 시도 · 시군구 · 읍면동.
/// Names are in the app's language at the time of the search.
struct PlaceRow: Identifiable, Hashable {
    enum Kind: Hashable { case country, region, kr }
    /// "rg:US" · "rg:US-CA" · "kr:1144000000" — the id of the Place it adds.
    let id: String
    let kind: Kind
    /// "캘리포니아" · "서울 마포구" · "Mapo-gu, Seoul"
    let title: String
    /// The country ("미국", "대한민국"), or for a country "나라 · 57곳".
    let subtitle: String
    /// What adding the row adds; nil for a country that has regions (it lists them instead).
    let place: Place?
    let childCount: Int
}

/// What a search found: whole-name matches of a country / 시도 / 시군구 with everything under them, then the rest.
struct PlaceResults {
    struct Group: Identifiable {
        let head: PlaceRow
        let children: [PlaceRow]
        var id: String { head.id }
    }
    var groups: [Group] = []
    /// The other matches, best first (at most `PlaceIndex.limit`).
    var rows: [PlaceRow] = []

    var isEmpty: Bool { groups.isEmpty && rows.isEmpty }
    /// Every row in the order shown.
    var all: [PlaceRow] { groups.flatMap { [$0.head] + $0.children } + rows }
}

/// The place search index: Purrcast/Resources/places.json (tools/places/build.py) — every country, its states /
/// provinces / prefectures (countries-states-cities-database, ODbL 1.0), and Korea's 시도 · 시군구 · 읍면동 (기상청 격자
/// 목록), with names in ko / en / ja. Read once, lazily, off the main thread; `search` then only compares precomputed keys.
///
/// Matching: the query and every name (ko · en · ja · native · aliases · the Korean romanizations · Japanese readings)
/// go through `PlaceKey.norm` — case, width and accents folded, katakana = hiragana, spaces and hyphens dropped.
/// Ranking: whole or start-of-name matches before matches inside a name; countries, then regions (with Korea's 시도 and
/// 시군구), then Korea's 읍면동; then the language's own order (`PlaceStore.order`).
/// A whole country / 시도 / 시군구 name lists all of its children under it.
@MainActor
final class PlaceIndex {
    static let shared = PlaceIndex()
    /// How many other matches a search lists (an expanded country / 시도 / 시군구 always lists all of its children).
    static let limit = 60

    private var store: PlaceStore?
    private var loader: Task<PlaceStore?, Never>?

    var isLoaded: Bool { store != nil }

    /// Reads the bundled file once (later calls wait for the same work). `isLoaded` stays false when it is missing.
    func load() async {
        if store != nil { return }
        let task: Task<PlaceStore?, Never>
        if let running = loader {
            task = running
        } else {
            task = Task.detached(priority: .userInitiated) { () -> PlaceStore? in PlaceStore.bundled() }
            loader = task
        }
        let loaded = await task.value
        if store == nil { store = loaded }
    }

    /// Rows for what was typed, in the app's language. Empty for an empty query or before `load()` finished.
    func search(_ query: String) -> PlaceResults {
        store?.search(query, lang: Lang.current, limit: Self.limit) ?? PlaceResults()
    }

    /// Index places ("kr:…" · "rg:…") are saved with names in the language of the day; this gives the same place
    /// named in the current language. nil for other places or before the index is loaded.
    func renamed(_ p: Place) -> Place? {
        guard let s = store, Self.handles(p.id), let i = s.entry(id: p.id) else { return nil }
        var q = p
        q.name = s.placeName(i, Lang.current)
        q.short = s.shortName(i, Lang.current)
        q.ko = s.koreanName(i)
        return q
    }

    /// True for ids made from the index.
    nonisolated static func handles(_ id: String) -> Bool { id.hasPrefix("kr:") || id.hasPrefix("rg:") }

    /// A place picked from Apple Maps. Its name stays as Apple gave it; the id is the coordinate rounded to ~100 m
    /// ("mk:35.659,139.700"). Time zone: Korea Asia/Seoul, else Apple's, else the country's, else UTC.
    func mapKitPlace(name: String, short: String, lat: Double, lon: Double, country: String, timeZone: TimeZone?) -> Place {
        let region = PlaceStore.region(for: country)
        var tz = region == "kr" ? "Asia/Seoul" : (timeZone?.identifier ?? "")
        if PlaceStore.validZone(tz) == nil { tz = store?.countryZone(country) ?? "UTC" }
        return Place(id: String(format: "mk:%.3f,%.3f", lat, lon), name: name, short: short.isEmpty ? name : short,
                     lat: lat, lon: lon, region: region, timeZone: tz, sample: PlaceStore.sample(for: region))
    }
}

/// Search keys: one spelling for every way a name can be typed. Lower case, accents dropped (Hà Nội → hanoi), full-width
/// and half-width forms folded (ｶﾘﾌｫﾙﾆｱ → かりふぉるにあ), katakana read as hiragana, spaces · hyphens · punctuation dropped.
enum PlaceKey {
    static func norm(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        // most names are ASCII or Hangul syllables: nothing to decompose
        let plain = s.unicodeScalars.allSatisfy { (u: Unicode.Scalar) -> Bool in u.value < 0x80 || (0xAC00...0xD7A3).contains(u.value) }
        if plain {
            for u in s.unicodeScalars {
                if u.value < 0x80 { ascii(u, &out) } else { out.append(u) }
            }
            return String(out)
        }
        var compose = false
        for u in s.decomposedStringWithCompatibilityMapping.unicodeScalars {
            let v = u.value
            if v < 0x80 { ascii(u, &out); continue }
            if v == 0x3099 || v == 0x309A { out.append(u); compose = true; continue }      // kana voicing marks (recomposed below)
            if (0x30A1...0x30F6).contains(v) || v == 0x30FD || v == 0x30FE {               // katakana → hiragana
                if let h = Unicode.Scalar(v - 0x60) { out.append(h) }
                continue
            }
            if (0x02B0...0x02FF).contains(v) { continue }                                   // modifier marks (the okina in Hawaii)
            if let f = fold[v] { out.append(contentsOf: f.unicodeScalars); continue }
            keep(u, &out, &compose)
        }
        let r = String(out)
        return compose ? r.precomposedStringWithCanonicalMapping : r
    }

    /// Letters and digits stay (upper case lowered); accents, spaces, punctuation and symbols go.
    private static func keep(_ u: Unicode.Scalar, _ out: inout String.UnicodeScalarView, _ compose: inout Bool) {
        switch u.properties.generalCategory {
        case .uppercaseLetter, .titlecaseLetter:
            out.append(contentsOf: String(u).lowercased().unicodeScalars)
        case .lowercaseLetter, .otherLetter, .modifierLetter, .decimalNumber, .letterNumber, .otherNumber, .spacingMark:
            if (0x1100...0x11FF).contains(u.value) { compose = true }                       // Hangul jamo: back into syllables
            out.append(u)
        default:
            break
        }
    }

    private static func ascii(_ u: Unicode.Scalar, _ out: inout String.UnicodeScalarView) {
        let v = u.value
        if v >= 0x41 && v <= 0x5A {
            out.append(Unicode.Scalar(UInt8(v + 0x20)))
        } else if (v >= 0x61 && v <= 0x7A) || (v >= 0x30 && v <= 0x39) {
            out.append(u)
        }
    }

    /// Latin letters that do not decompose into a base letter and an accent.
    private static let fold: [UInt32: String] = [
        0xF8: "o", 0xD8: "o", 0xE6: "ae", 0xC6: "ae", 0x153: "oe", 0x152: "oe", 0xDF: "ss", 0x142: "l", 0x141: "l",
        0x111: "d", 0x110: "d", 0xF0: "d", 0xD0: "d", 0xFE: "th", 0xDE: "th", 0x131: "i", 0x127: "h", 0x126: "h",
        0x259: "e", 0x18F: "e", 0x14B: "n", 0x14A: "n",
    ]
}

/// The parsed file with its search keys and orders. Built once off the main thread, then only read.
final class PlaceStore: @unchecked Sendable {
    struct Entry {
        enum Kind { case country, region, kr }
        var kind: Kind
        var code: String          // ISO 3166-1 alpha-2 · ISO 3166-2 · KMA code
        var cc: String            // the country, ISO 3166-1 alpha-2
        var names: [String]       // the entry's own name in ko, en, ja
        var lat: Double
        var lon: Double
        var tz: String
        var parent = -1
        var level = 0             // Korea: 1 시도 · 2 시군구 · 3 읍면동
        var kr: KR? = nil
    }

    /// A Korean row's levels, for "서울 마포구 아현동" · "Ahyeon-dong, Mapo-gu, Seoul" · "ソウル マポ区 アヒョンドン".
    struct KR {
        var sido: String          // 서울특별시
        var short: String         // 서울
        var en1: String           // Seoul
        var ja1: String           // ソウル
        var l2: String            // 마포구 · 성남시 분당구 · "" (세종)
        var l3: String            // 아현동 · ""
        var r2: String            // Mapo-gu
        var r3: String            // Ahyeon-dong
        var k2 = ""               // マポ区 (KoreanKana)
        var k3 = ""               // アヒョンドン
    }

    private struct Hit {
        let entry: Int
        let match: Int            // 0 a whole name · 1 the start of a name · 2 inside a name
    }

    private static let sep = "\u{1}"

    private var entries: [Entry] = []
    /// Per entry: its normalized names between separators ("\u{1}seoul\u{1}서울\u{1}…\u{1}").
    private var keys: [NSString] = []
    private var children: [[Int]] = []
    /// Per language (ko · en · ja), each entry's position in that language's order.
    private var rank: [[Int32]] = []
    private var byID: [String: Int] = [:]
    private var countryIndex: [String: Int] = [:]

    static func bundled() -> PlaceStore? {
        guard let url = Bundle.main.url(forResource: "places", withExtension: "json") else { return nil }
        return PlaceStore(url: url)
    }

    /// Row layouts: see tools/places/build.py.
    init?(url: URL) {
        guard let data = try? Data(contentsOf: url),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let countries = root["countries"] as? [[Any]],
              let regions = root["regions"] as? [[Any]],
              let korea = root["kr"] as? [[Any]] else { return nil }
        readCountries(countries)
        readRegions(regions)
        readKorea(korea)
        guard !entries.isEmpty else { return nil }
        finish()
    }

    // MARK: reading

    private static func str(_ row: [Any], _ i: Int) -> String {
        i < row.count ? (row[i] as? String ?? "") : ""
    }
    private static func num(_ row: [Any], _ i: Int) -> Double {
        i < row.count ? ((row[i] as? NSNumber)?.doubleValue ?? 0) : 0
    }

    private func add(_ e: Entry, id: String, keys raw: [String]) {
        var seen = Set<String>()
        var list: [String] = []
        for k in raw where !k.isEmpty && seen.insert(k).inserted { list.append(k) }
        entries.append(e)
        keys.append(NSString(string: Self.sep + list.joined(separator: Self.sep) + Self.sep))
        byID[id] = entries.count - 1
    }

    /// [iso2, ko, en, ja, native, lat, lon, tz, [aliases]]
    private func readCountries(_ rows: [[Any]]) {
        for r in rows {
            let cc = Self.str(r, 0)
            guard !cc.isEmpty, countryIndex[cc] == nil else { continue }
            let names = [Self.str(r, 1), Self.str(r, 2), Self.str(r, 3)]
            let aliases: [String] = r.count > 8 ? (r[8] as? [String] ?? []) : []
            var k = names
            k.append(Self.str(r, 4))
            k += aliases
            let e = Entry(kind: .country, code: cc, cc: cc, names: names, lat: Self.num(r, 5), lon: Self.num(r, 6), tz: Self.str(r, 7))
            add(e, id: "rg:" + cc, keys: k.map(PlaceKey.norm))
            countryIndex[cc] = entries.count - 1
        }
    }

    /// [iso3166-2, country, ko, en, ja, native, lat, lon, tz, parent]
    private func readRegions(_ rows: [[Any]]) {
        for r in rows {
            let code = Self.str(r, 0), cc = Self.str(r, 1)
            guard !code.isEmpty, byID["rg:" + code] == nil, let parent = countryIndex[cc] else { continue }
            let names = [Self.str(r, 2), Self.str(r, 3), Self.str(r, 4)]
            var k = names
            k.append(Self.str(r, 5))
            if cc == "JP", let n = Int(code.dropFirst(3)), n >= 1, n <= Self.prefectureReadings.count {
                k.append(Self.prefectureReadings[n - 1])
            }
            let e = Entry(kind: .region, code: code, cc: cc, names: names, lat: Self.num(r, 6), lon: Self.num(r, 7),
                          tz: Self.str(r, 8), parent: parent)
            add(e, id: "rg:" + code, keys: k.map(PlaceKey.norm))
        }
    }

    /// [KMA code, 1단계, 2단계, 3단계, lat, lon, 시도 short, 시도 en, 시도 ja, 2단계 romanized, 3단계 romanized]
    /// Level by level, so every row finds its parent whatever the file's order.
    private func readKorea(_ rows: [[Any]]) {
        guard let korea = countryIndex["KR"] else { return }
        var sido: [String: Int] = [:]
        var sigungu: [String: Int] = [:]
        for level in 1...3 {
            for r in rows {
                var n = KR(sido: Self.str(r, 1), short: Self.str(r, 6), en1: Self.str(r, 7), ja1: Self.str(r, 8),
                           l2: Self.str(r, 2), l3: Self.str(r, 3), r2: Self.str(r, 9), r3: Self.str(r, 10))
                let rowLevel = !n.l3.isEmpty ? 3 : (!n.l2.isEmpty ? 2 : 1)
                guard rowLevel == level else { continue }
                n.k2 = KoreanKana.place(n.l2)
                n.k3 = KoreanKana.place(n.l3)
                let parent: Int?
                switch level {
                case 1: parent = sido[n.sido] == nil ? korea : nil          // 세종 repeats itself once: keep the first
                case 2: parent = sido[n.sido]
                default: parent = n.l2.isEmpty ? sido[n.sido] : sigungu[n.sido + "|" + n.l2]
                }
                let code = Self.str(r, 0)
                guard let p = parent, !code.isEmpty, byID["kr:" + code] == nil else { continue }
                let e = Entry(kind: .kr, code: code, cc: "KR", names: Self.ownNames(n, level), lat: Self.num(r, 4), lon: Self.num(r, 5),
                              tz: "Asia/Seoul", parent: p, level: level, kr: n)
                add(e, id: "kr:" + code, keys: Self.koreanKeys(n, level))
                if level == 1 { sido[n.sido] = entries.count - 1 }
                if level == 2 { sigungu[n.sido + "|" + n.l2] = entries.count - 1 }
            }
        }
    }

    private static func ownNames(_ n: KR, _ level: Int) -> [String] {
        switch level {
        case 1: return [n.sido, n.en1, n.ja1]
        case 2: return [n.l2, n.r2, n.k2]
        default: return [n.l3, n.r3, n.k3]
        }
    }

    /// Own names plus the composed ones, so "서울 마포", "Mapo-gu, Seoul", "ソウル Mapo" and "ソウル マポ" all match.
    private static func koreanKeys(_ n: KR, _ level: Int) -> [String] {
        let full = PlaceKey.norm(n.sido), short = PlaceKey.norm(n.short)
        let en1 = PlaceKey.norm(n.en1), ja1 = PlaceKey.norm(n.ja1)
        if level == 1 {
            var out = [full, short, en1, ja1]
            out += (sidoAliases[n.sido] ?? []).map(PlaceKey.norm)
            return out
        }
        let k2 = PlaceKey.norm(n.l2), r2 = PlaceKey.norm(n.r2), j2 = PlaceKey.norm(n.k2)
        let w2: [String] = n.l2.split(separator: " ").map { PlaceKey.norm(String($0)) }
        let rw2: [String] = n.r2.split(separator: " ").map { PlaceKey.norm(String($0)) }
        let up2: String = rw2.reversed().joined()                       // small → big: bundanggu + seongnamsi
        if level == 2 {
            var out = [k2, r2]
            if w2.count > 1 { out += w2; out += rw2 }                  // 성남시 분당구: "분당구" and "성남시" alone too
            out.append(short + k2)
            out.append(full + k2)
            out.append(up2 + en1)
            out.append(en1 + r2)
            out.append(ja1 + r2)
            out.append(j2)
            out += n.k2.split(separator: " ").map { PlaceKey.norm(String($0)) }
            out.append(ja1 + j2)
            return out
        }
        let k3 = PlaceKey.norm(n.l3), r3 = PlaceKey.norm(n.r3), j3 = PlaceKey.norm(n.k3)
        var out = [k3, r3, j3]
        out.append(short + k2 + k3)
        out.append(r3 + up2 + en1)
        out.append(en1 + r2 + r3)
        out.append(ja1 + r2 + r3)
        out.append(ja1 + j2 + j3)
        return out
    }

    /// Other names people use for a 시도 (the old ones too), and how Japanese writes them in kana.
    private static let sidoAliases: [String: [String]] = [
        "서울특별시": ["서울시"],
        "부산광역시": ["부산시", "プサン"],
        "대구광역시": ["대구시", "テグ"],
        "인천광역시": ["인천시", "インチョン"],
        "대전광역시": ["대전시", "テジョン"],
        "울산광역시": ["울산시", "ウルサン"],
        "세종특별자치시": ["세종시", "セジョン"],
        "경기도": ["Gyeonggi-do", "キョンギド"],
        "강원특별자치도": ["강원도", "Gangwon-do", "カンウォンド"],
        "충청북도": ["Chungbuk", "Chungcheongbuk-do", "チュンチョンブクト"],
        "충청남도": ["Chungnam", "Chungcheongnam-do", "チュンチョンナムド"],
        "전북특별자치도": ["전라북도", "Jeollabuk-do", "チョルラブクト"],
        "전남광주통합특별시": ["광주광역시", "광주", "전라남도", "전남", "Gwangju", "South Jeolla", "Jeollanam-do", "光州", "全羅南道", "クァンジュ", "チョルラナムド"],
        "경상북도": ["Gyeongbuk", "Gyeongsangbuk-do", "キョンサンブクト"],
        "경상남도": ["Gyeongnam", "Gyeongsangnam-do", "キョンサンナムド"],
        "제주특별자치도": ["제주도", "Jeju-do", "チェジュ"],
    ]

    /// Japan's prefectures in JIS order (JP-01 … JP-47), read in hiragana, so "とうきょう" finds 東京都.
    private static let prefectureReadings = [
        "ほっかいどう", "あおもり", "いわて", "みやぎ", "あきた", "やまがた", "ふくしま", "いばらき", "とちぎ", "ぐんま",
        "さいたま", "ちば", "とうきょう", "かながわ", "にいがた", "とやま", "いしかわ", "ふくい", "やまなし", "ながの",
        "ぎふ", "しずおか", "あいち", "みえ", "しが", "きょうと", "おおさか", "ひょうご", "なら", "わかやま",
        "とっとり", "しまね", "おかやま", "ひろしま", "やまぐち", "とくしま", "かがわ", "えひめ", "こうち", "ふくおか",
        "さが", "ながさき", "くまもと", "おおいた", "みやざき", "かごしま", "おきなわ",
    ]

    private func finish() {
        children = Array(repeating: [], count: entries.count)
        for i in entries.indices where entries[i].parent >= 0 { children[entries[i].parent].append(i) }
        rank = Lang.allCases.map { order(for: $0) }
    }

    // MARK: orders

    private static func slot(_ lang: Lang) -> Int { lang == .ko ? 0 : (lang == .en ? 1 : 2) }

    /// Each entry's position in the language's own order:
    /// ko — Hangul code-point order of the Korean name (ㄱㄴㄷ); en — A–Z, case and accents ignored;
    /// ja — Japan's prefectures in JIS order (北海道 01 → 沖縄 47), Korea in KMA code order, everything else by the
    /// Japanese name in Japanese collation (kana order).
    private func order(for lang: Lang) -> [Int32] {
        let idx = Array(entries.indices)
        let sorted: [Int]
        switch lang {
        case .ko:
            let k: [String] = idx.map { title($0, .ko) }
            sorted = idx.sorted { (a: Int, b: Int) -> Bool in k[a] != k[b] ? k[a] < k[b] : a < b }
        case .en:
            let k: [String] = idx.map { Self.latinFold(title($0, .en)) }
            sorted = idx.sorted { (a: Int, b: Int) -> Bool in k[a] != k[b] ? k[a] < k[b] : a < b }
        case .ja:
            let k: [(group: Int, key: String)] = idx.map { jaKey($0) }
            let ja = Locale(identifier: "ja_JP")
            sorted = idx.sorted { (a: Int, b: Int) -> Bool in
                let x = k[a], y = k[b]
                if x.group != y.group { return x.group < y.group }
                if x.key == y.key { return a < b }
                if x.group < 2 { return x.key < y.key }
                return x.key.compare(y.key, options: [], range: nil, locale: ja) == .orderedAscending
            }
        }
        var r = [Int32](repeating: 0, count: entries.count)
        for (pos, i) in sorted.enumerated() { r[i] = Int32(pos) }
        return r
    }

    private func jaKey(_ i: Int) -> (group: Int, key: String) {
        let e = entries[i]
        if e.kind == .region && e.cc == "JP" { return (0, e.code) }   // JP-01 … JP-47
        if e.kind == .kr { return (1, e.code) }
        return (2, title(i, .ja))
    }

    private static func latinFold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    // MARK: names

    func entry(id: String) -> Int? { byID[id] }

    func id(_ i: Int) -> String { (entries[i].kind == .kr ? "kr:" : "rg:") + entries[i].code }

    func countryName(_ cc: String, _ lang: Lang) -> String {
        if cc == "KR" { return lang.string("대한민국") }
        guard let i = countryIndex[cc] else { return cc }
        return entries[i].names[Self.slot(lang)]
    }

    /// The row's own line: a country or region by its name, a Korean row with its 시도 ("서울 마포구").
    func title(_ i: Int, _ lang: Lang) -> String {
        let e = entries[i]
        switch e.kind {
        case .country: return countryName(e.cc, lang)
        case .region: return e.names[Self.slot(lang)]
        case .kr:
            guard let n = e.kr else { return e.names[Self.slot(lang)] }
            return Self.koreanTitle(n, e.level, lang)
        }
    }

    /// ko "서울 마포구 아현동" (short 시도, big → small) · en "Ahyeon-dong, Mapo-gu, Seoul" (small → big) ·
    /// ja "ソウル マポ区 アヒョンドン" (katakana, KoreanKana). A 시도 alone by its full name ("서울특별시" · "Seoul" · "ソウル").
    private static func koreanTitle(_ n: KR, _ level: Int, _ lang: Lang) -> String {
        if level == 1 { return lang == .ko ? n.sido : (lang == .en ? n.en1 : n.ja1) }
        let dong = level == 3
        switch lang {
        case .ko:
            return joined([n.short, n.l2, dong ? n.l3 : ""], " ")
        case .en:
            var parts: [String] = dong ? [n.r3] : []
            parts += n.r2.split(separator: " ").reversed().map { String($0) }
            parts.append(n.en1)
            return joined(parts, ", ")
        case .ja:
            return joined([n.ja1, n.k2, dong ? n.k3 : ""], " ")
        }
    }

    private static func joined(_ parts: [String], _ sep: String) -> String {
        parts.filter { !$0.isEmpty }.joined(separator: sep)
    }

    /// The name a saved place shows: regions with their country ("캘리포니아, 미국" · "California, United States").
    func placeName(_ i: Int, _ lang: Lang) -> String {
        let e = entries[i]
        if e.kind == .region { return title(i, lang) + ", " + countryName(e.cc, lang) }
        return title(i, lang)
    }

    /// For widgets and the watch: Korea the last level ("마포구" · "Mapo-gu"), regions their own name.
    func shortName(_ i: Int, _ lang: Lang) -> String {
        let e = entries[i]
        guard e.kind == .kr, let n = e.kr else { return title(i, lang) }
        switch e.level {
        case 1: return lang == .ko ? n.short : (lang == .en ? n.en1 : n.ja1)
        case 2: return Self.lastWord(lang == .ko ? n.l2 : (lang == .en ? n.r2 : n.k2))
        default: return lang == .ko ? n.l3 : (lang == .en ? n.r3 : n.k3)
        }
    }

    private static func lastWord(_ s: String) -> String {
        s.split(separator: " ").last.map { String($0) } ?? s
    }

    /// A Korean row's Korean name, for the server (기상청 warnings go by it); nil for other rows.
    func koreanName(_ i: Int) -> String? {
        entries[i].kind == .kr ? placeName(i, .ko) : nil
    }

    func subtitle(_ i: Int, _ lang: Lang) -> String {
        let e = entries[i]
        guard e.kind == .country else { return countryName(e.cc, lang) }
        let n = children[i].count
        return n == 0 ? lang.string("나라") : String(format: lang.string("나라 · %d곳"), n)
    }

    // MARK: places

    static func region(for cc: String) -> String { cc == "KR" ? "kr" : (cc == "JP" ? "jp" : "other") }

    /// The example scene the sample provider shows (until the server is connected): Korea the 기상청 six hours,
    /// Japan the minute rain, elsewhere a clear day.
    static func sample(for region: String) -> String { region == "kr" ? "seoul_soon" : (region == "jp" ? "tokyo_soon" : "clear") }

    static func validZone(_ id: String) -> String? { !id.isEmpty && TimeZone(identifier: id) != nil ? id : nil }

    func countryZone(_ cc: String) -> String? {
        guard let i = countryIndex[cc] else { return nil }
        return Self.validZone(entries[i].tz)
    }

    /// Korea Asia/Seoul; others their own zone, else the country's, else UTC.
    func timeZone(_ i: Int) -> String {
        let e = entries[i]
        if e.cc == "KR" { return "Asia/Seoul" }
        if let tz = Self.validZone(e.tz) { return tz }
        return countryZone(e.cc) ?? "UTC"
    }

    func place(_ i: Int, _ lang: Lang) -> Place? {
        let e = entries[i]
        if e.kind == .country && !children[i].isEmpty { return nil }
        let region = Self.region(for: e.cc)
        return Place(id: id(i), name: placeName(i, lang), short: shortName(i, lang), lat: e.lat, lon: e.lon,
                     region: region, timeZone: timeZone(i), sample: Self.sample(for: region), ko: koreanName(i))
    }

    func row(_ i: Int, _ lang: Lang) -> PlaceRow {
        let kind: PlaceRow.Kind
        switch entries[i].kind {
        case .country: kind = .country
        case .region: kind = .region
        case .kr: kind = .kr
        }
        return PlaceRow(id: id(i), kind: kind, title: title(i, lang), subtitle: subtitle(i, lang),
                        place: place(i, lang), childCount: children[i].count)
    }

    // MARK: search

    /// How general an entry is: country 0 · region / 시도 1 · 시군구 2 · 읍면동 3.
    private func depth(_ i: Int) -> Int {
        switch entries[i].kind {
        case .country: return 0
        case .region: return 1
        case .kr: return entries[i].level
        }
    }

    /// Ranking tier: countries, then regions (with 시도 and 시군구), then 읍면동.
    private func tier(_ i: Int) -> Int {
        switch entries[i].kind {
        case .country: return 0
        case .region: return 1
        case .kr: return entries[i].level == 3 ? 2 : 1
        }
    }

    private func isUnder(_ i: Int, _ heads: Set<Int>) -> Bool {
        guard !heads.isEmpty else { return false }
        var p = i
        while p >= 0 {
            if heads.contains(p) { return true }
            p = entries[p].parent
        }
        return false
    }

    func search(_ text: String, lang: Lang, limit: Int) -> PlaceResults {
        let q = PlaceKey.norm(text)
        guard !q.isEmpty else { return PlaceResults() }
        let r = rank[Self.slot(lang)]
        let anywhere = NSString(string: q) as String
        let start = NSString(string: Self.sep + q) as String
        let whole = NSString(string: Self.sep + q + Self.sep) as String
        var hits: [Hit] = []
        for i in keys.indices {
            let k = keys[i]
            guard k.range(of: anywhere, options: .literal).location != NSNotFound else { continue }
            let m: Int
            if k.range(of: whole, options: .literal).location != NSNotFound {
                m = 0
            } else if k.range(of: start, options: .literal).location != NSNotFound {
                m = 1
            } else {
                m = 2
            }
            hits.append(Hit(entry: i, match: m))
        }

        // a whole country / 시도 / 시군구 name lists everything under it; the most general level wins ("중구": every 중구)
        let exact: [Int] = hits.filter { $0.match == 0 && !children[$0.entry].isEmpty }.map { $0.entry }
        var heads: [Int] = []
        if let top = exact.map({ depth($0) }).min() {
            heads = Array(exact.filter { depth($0) == top }.sorted { r[$0] < r[$1] }.prefix(8))
        }
        var result = PlaceResults()
        for h in heads {
            let kids = children[h].sorted { r[$0] < r[$1] }.map { row($0, lang) }
            result.groups.append(PlaceResults.Group(head: row(h, lang), children: kids))
        }

        // the rest: whole / start-of-name matches first, then by tier, then whole before start, then the language's order
        let headSet = Set(heads)
        var ranked: [(key: (Int, Int, Int, Int32), entry: Int)] = []
        for h in hits where !isUnder(h.entry, headSet) {
            ranked.append((key: (h.match == 2 ? 1 : 0, tier(h.entry), h.match, r[h.entry]), entry: h.entry))
        }
        ranked.sort { $0.key < $1.key }
        result.rows = ranked.prefix(limit).map { row($0.entry, lang) }
        return result
    }
}
