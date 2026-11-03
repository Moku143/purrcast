import CoreLocation
import Foundation

/// "지금 위치" as a Place, named in the app's language from a placemark: the app's own fix (LocationService) and a
/// widget's (it closes the day's 날씨 기록 with where the phone is just before midnight).
/// In Korea the place also gets its Korean name ("서울 구로구 오류동"): the server reads the 기상청 warnings by it, and
/// Japanese shows it in katakana ("ソウル オリュドン") — Apple answers Korean addresses in Hangul even in Japanese.
enum HerePlace {
    static func make(_ loc: CLLocation, lang: Lang = .current, mark: (CLLocation, Locale) async -> CLPlacemark?) async -> Place {
        let m = await mark(loc, lang.locale)
        let (city, district) = parts(m)
        var name = [shortCity(city), district].filter { !$0.isEmpty }.joined(separator: " ")
        if name.isEmpty { name = L("지금 위치") }
        let country = m?.isoCountryCode ?? ""
        var ko: String?
        if country == "KR" {
            let k = lang == .ko ? m : await mark(loc, Lang.ko.locale)
            let (kc, kd) = parts(k)
            let n = [shortCity(kc), kd].filter { !$0.isEmpty }.joined(separator: " ")
            ko = KoreanKana.hasHangul(n) ? n : nil
        }
        let place = Place(id: "here", name: name, short: district.isEmpty ? (shortCity(city).isEmpty ? L("지금 위치") : shortCity(city)) : district,
                          lat: loc.coordinate.latitude, lon: loc.coordinate.longitude,
                          region: country == "KR" ? "kr" : (country == "JP" ? "jp" : "other"),
                          timeZone: (m?.timeZone ?? TimeZone.current).identifier, sample: Place.here.sample, ko: ko)
        return lang == .ja ? koreanNamed(place, .ja) : place
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

    /// A Korean place in Korean or Japanese from its Korean name: Korean shows it as is, Japanese in katakana.
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
        default:
            break
        }
        return q
    }
}
