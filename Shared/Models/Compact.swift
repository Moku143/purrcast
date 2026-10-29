import Foundation

/// Words, not sentences, for the places with no room: home-screen widgets, the lock screen, the watch.
/// Pattern: `head · temperature · tail` — "비 · 16° · 우산", "15~17시 비 · 18° · 우산", "한파 · -13° · 체감 -16°".
///
/// Official names stay as they are (호우주의보, 태풍경보, 폭염, 한파, 폭우, 폭설, 열대야, 천둥번개, 황사 …):
/// the server only sends them above their thresholds, so a word in a widget means the real thing.
/// Everything else is shortened to a word ("15~17시 비 예보" → "15~17시 비", "우산 챙기세요" → "우산").
/// The server's text is already in the app's language, so the words are compared in that language (L).
enum Compact {
    /// Alert and weather names that are kept as they are (after the "!" is removed), Korean keys.
    static let keepKeys = ["폭염", "한파", "폭우", "폭설", "열대야", "천둥번개", "황사", "태풍", "꽃샘추위", "비바람", "눈보라", "비", "눈", "진눈깨비"]
    /// The same names in the current language.
    static var keep: Set<String> { Set(keepKeys.map { L($0) }) }

    /// The first word: the alert name when there is one, the weather otherwise.
    static func head(_ s: WeatherScene) -> String {
        if let t = s.bubble?.text.replacingOccurrences(of: "!", with: "").trimmingCharacters(in: .whitespaces), !t.isEmpty {
            if keep.contains(t) || t.hasSuffix(L("주의보")) || t.hasSuffix(L("경보")) || t.hasSuffix(L("특보")) { return t }
            let forecast = L(" 예보"), expected = L(" 예정")
            if t.hasSuffix(forecast) { return String(t.dropLast(forecast.count)) }   // "15~17시 비 예보" → "15~17시 비"
            if t.hasSuffix(expected) { return String(t.dropLast(expected.count)) }   // an older server: "… 예정"
            switch t {
            case L("바람 세요"): return L("강한 바람")
            case L("안개가 짙어요"), L("안개 짙어요"): return L("짙은 안개")
            case L("안개가 옅어요"): return L("옅은 안개")
            case L("일교차 커요"): return L("큰 일교차")
            case L("우산 챙기세요"), L("우산 챙겨요"): return condWord(s)          // the umbrella goes in the tail
            default: return t
            }
        }
        return condWord(s)
    }

    /// The weather in a word, from the condition ("강한 비 · 바람 강함" → "강한 비").
    static func condWord(_ s: WeatherScene) -> String {
        s.cond.components(separatedBy: " · ").first ?? s.cond
    }

    /// The second word: the one thing most worth knowing next to the temperature.
    /// 우산 (rain now or expected) · 체감 N° (feels 3° off) · 큰 일교차 · 바람 · 안개 · 최고/최저.
    static func tail(_ s: WeatherScene, deg: (Int) -> String) -> String {
        let h = head(s)
        let rain = RainState(rawValue: s.rain) ?? .none
        if (rain == .umbrella || rain == .bag) && !h.localizedCaseInsensitiveContains(L("우산")) { return L("우산") }
        if abs(s.feels - s.temp) >= 3 { return L("체감 %@", deg(s.feels)) }
        if s.hi - s.lo >= 10 && !h.localizedCaseInsensitiveContains(L("일교차")) { return L("큰 일교차") }
        if s.aux == "wind" && !h.localizedCaseInsensitiveContains(L("바람")) { return L("바람") }
        if s.aux == "fog" && !h.localizedCaseInsensitiveContains(L("안개")) { return L("안개") }
        if s.aux == "dust" && !h.localizedCaseInsensitiveContains(L("황사")) { return L("황사") }
        return s.temp >= (s.hi + s.lo) / 2 ? L("최저 %@", deg(s.lo)) : L("최고 %@", deg(s.hi))
    }

    /// "비 · 16° · 우산": the one line for inline complications and the lock screen.
    static func line(_ s: WeatherScene, deg: (Int) -> String) -> String {
        "\(head(s)) · \(deg(s.temp)) · \(tail(s, deg: deg))"
    }

    /// For the small bubble above the character: only when it is a word or two.
    static func bubbleWord(_ s: WeatherScene, max: Int) -> String {
        let h = head(s)
        return h.count <= max ? h : ""
    }
}
