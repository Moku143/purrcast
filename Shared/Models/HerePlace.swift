import CoreLocation
import Foundation

/// "지금 위치" as a Place, named in the app's language from a placemark: the app's own fix (LocationService) and a
/// widget's (it closes the day's 날씨 기록 with where the phone is just before midnight).
/// In Korea the place also gets its Korean name ("서울 구로구 오류동"): the server reads the 기상청 warnings by it, and
/// Japanese shows it in katakana ("ソウル オリュドン") — Apple answers Korean addresses in Hangul even in Japanese.
enum HerePlace {
    /// Apple answers in the language asked where it has the names, and in the place's own language where it has not
    /// (Korean towns in Hangul for Chinese, Spanish, Russian …). A name the language cannot read is made again: Korean
    /// places from their Korean name (KoreanNames), elsewhere from Apple's English names, else in Latin letters.
    static func make(_ loc: CLLocation, lang: Lang = .current, mark: (CLLocation, Locale) async -> CLPlacemark?) async -> Place {
        let m = await mark(loc, lang.locale)
        var (city, district) = parts(m)
        let country = m?.isoCountryCode ?? ""
        var ko: String?, gu: String?
        if country == "KR" {
            let k = lang == .ko ? m : await mark(loc, Lang.ko.locale)
            let (kc, kd) = parts(k)
            let n = [shortCity(kc), kd].filter { !$0.isEmpty }.joined(separator: " ")
            ko = KoreanKana.hasHangul(n) ? n : nil
            gu = Self.district(of: k)
        }
        let english = Locale(identifier: "en_US")
        if country == "KR", let ko {
            switch lang {
            case .ko, .ja, .ru: break                                    // from the Korean name below
            case .zhHans, .zhHant:
                // Apple's Chinese when it has it; else the city and the 구 by their characters (the 동 in letters)
                if !(lang.reads(city + district) && hasHan(city + district)) {
                    let words = ko.split(separator: " ").map(String.init)
                    city = words.first.map { KoreanNames.word($0, lang) } ?? ""
                    let g = gu.flatMap { KoreanNames.chinese($0, province: words.first) }.map { lang == .zhHant ? KoreanNames.traditional($0) : $0 }
                    district = g ?? (words.count > 1 ? KoreanNames.latin(words[1]) : "")
                }
            default:
                if !lang.reads(city + district) {
                    let e = parts(await mark(loc, english))
                    if lang.reads(e.0 + e.1), !(e.0 + e.1).isEmpty { (city, district) = e }
                    else {
                        let words = ko.split(separator: " ").map(String.init)
                        city = words.first.map { KoreanNames.word($0, lang) } ?? ""
                        district = words.count > 1 ? KoreanNames.word(words[1], lang) : ""
                    }
                }
            }
        } else if !lang.reads(city + district) {
            let e = parts(await mark(loc, english))
            if lang.reads(e.0 + e.1) { (city, district) = e }
            if !lang.reads(city + district) { city = latin(city); district = latin(district) }
        }
        // a place abroad whose shown name isn't Latin (the app in Korean in Tokyo stores "도쿄") also keeps its
        // English name: the 날씨 달력 shows that to languages that cannot read the stored one — a foreign name must
        // never go through the Korean romanizer ("도쿄" must not come out "Dokyo")
        var en: String? = nil
        if country != "KR", !country.isEmpty, !Lang.en.reads(city + district) {
            let e = parts(await mark(loc, english))
            if Lang.en.reads(e.0 + e.1), !(e.0 + e.1).isEmpty {
                let c = shortCity(e.0)
                en = KoreanNames.join(e.1 == c || e.1.isEmpty ? [c] : [c, e.1])
            }
        }
        var name = KoreanNames.join([shortCity(city), district])
        if name.isEmpty { name = L("지금 위치") }
        var place = Place(id: "here", name: name, short: district.isEmpty ? (shortCity(city).isEmpty ? L("지금 위치") : shortCity(city)) : district,
                          lat: loc.coordinate.latitude, lon: loc.coordinate.longitude,
                          region: country == "KR" ? "kr" : (country == "JP" ? "jp" : "other"),
                          timeZone: (m?.timeZone ?? TimeZone.current).identifier, sample: Place.here.sample, ko: ko,
                          cc: country.count == 2 ? country : nil)
        place.en = en
        return [.ko, .ja, .ru].contains(lang) ? koreanNamed(place, lang) : place
    }

    /// The 시군구 of a Korean placemark ("구로구", "수원시"): the first of its locality and sub-area that is one
    static func district(of m: CLPlacemark?) -> String? {
        for s in [m?.locality, m?.subAdministrativeArea, m?.subLocality].compactMap({ $0 }) {
            if s != m?.administrativeArea, let l = s.last, "구시군".contains(l), KoreanKana.hasHangul(s) { return s }
        }
        return nil
    }

    private static func hasHan(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) || (0x3400...0x4DBF).contains($0.value) }
    }

    /// Letters a language cannot read, in Latin ones (Apple's transliteration: Cyrillic, Greek, Thai, Arabic …)
    static func latin(_ s: String) -> String {
        (s.applyingTransform(.toLatin, reverse: false) ?? s).capitalized
    }

    /// (시도 / state, district) from a placemark.
    static func parts(_ m: CLPlacemark?) -> (String, String) {
        (m?.administrativeArea ?? m?.locality ?? "", m?.subLocality ?? m?.locality ?? m?.subAdministrativeArea ?? "")
    }

    /// "서울특별시" → "서울", "경기도" → "경기"
    static func shortCity(_ s: String) -> String {
        for suffix in ["특별자치시", "특별자치도", "특별시", "광역시", "도"] where s.hasSuffix(suffix) && s.count > suffix.count {
            return String(s.dropLast(suffix.count))
        }
        return s
    }

    /// A Korean place in the language from its Korean name: Korean as is, Japanese in katakana, Russian in Cyrillic,
    /// Chinese by its characters (the 동 in letters); other languages keep a name they can read (Apple's English),
    /// else the Revised Romanization.
    static func koreanNamed(_ p: Place, _ lang: Lang) -> Place {
        guard p.region == "kr" else { return p }
        var q = p
        if q.ko == nil, KoreanKana.hasHangul(p.name) { q.ko = p.name }
        guard let ko = q.ko else { return p }
        let koShort = ko.split(separator: " ").last.map(String.init) ?? ko
        switch lang {
        case .ja:
            let words = ko.split(separator: " ").map(String.init)
            let head = words.first.flatMap { KoreanKana.province($0) }
            q.name = ([head ?? KoreanKana.place(words.first ?? "")] + words.dropFirst().map { KoreanKana.place($0) })
                .filter { !$0.isEmpty }.joined(separator: " ")
            q.short = words.count == 1 ? (head ?? KoreanKana.place(koShort)) : KoreanKana.place(koShort)
        case .ko:
            q.name = ko
            q.short = koShort
        case .ru, .zhHans, .zhHant:
            q.name = KoreanNames.name(ko, lang)
            q.short = KoreanNames.word(koShort, lang)
        default:
            if lang.reads(p.name), lang.reads(p.short) { return q }
            q.name = KoreanNames.name(ko, lang)
            q.short = KoreanNames.word(koShort, lang)
        }
        return q
    }
}
