import Foundation

/// Words, not sentences, for the places with no room: home-screen widgets, the lock screen, the watch.
/// Pattern: `head · temperature · tail` — "비 · 16° · 우산", "15~17시 비 · 18° · 우산", "한파 · -13° · 체감 -16°".
///
/// Official names stay as they are (호우주의보, 태풍경보, 폭염, 한파, 폭우, 폭설, 열대야, 천둥번개, 황사 …):
/// the server only sends them above their thresholds, so a word in a widget means the real thing.
/// Everything else is shortened to a word ("15~17시 비 예정" → "15~17시 비", "우산 챙겨요" → "우산").
enum Compact {
    /// Alert and weather names that are kept as they are (after the "!" is removed).
    static let keep: Set<String> = ["폭염", "한파", "폭우", "폭설", "열대야", "천둥번개", "황사", "태풍", "꽃샘추위", "비바람", "눈보라", "비", "눈", "진눈깨비"]

    /// The first word: the alert name when there is one, the weather otherwise.
    static func head(_ s: WeatherScene) -> String {
        if let t = s.bubble?.text.replacingOccurrences(of: "!", with: "").trimmingCharacters(in: .whitespaces), !t.isEmpty {
            if keep.contains(t) || t.hasSuffix("주의보") || t.hasSuffix("경보") || t.hasSuffix("특보") { return t }
            if t.hasSuffix(" 예보") || t.hasSuffix(" 예정") { return String(t.dropLast(3)) }   // "15~17시 비 예정" → "15~17시 비"
            switch t {
            case "바람 세요": return "강한 바람"
            case "안개 짙어요": return "짙은 안개"
            case "일교차 커요": return "큰 일교차"
            case "우산 챙겨요": return condWord(s)                              // the umbrella goes in the tail
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
        if (rain == .umbrella || rain == .bag) && !h.contains("우산") { return "우산" }
        if abs(s.feels - s.temp) >= 3 { return "체감 \(deg(s.feels))" }
        if s.hi - s.lo >= 10 && !h.contains("일교차") { return "큰 일교차" }
        if s.aux == "wind" && !h.contains("바람") { return "바람" }
        if s.aux == "fog" && !h.contains("안개") { return "안개" }
        if s.aux == "dust" && !h.contains("황사") { return "황사" }
        return s.temp >= (s.hi + s.lo) / 2 ? "최저 \(deg(s.lo))" : "최고 \(deg(s.hi))"
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
