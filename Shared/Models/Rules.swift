import Foundation

/// The judgement rules from the design kit (README §1): outfit from the feels-like temperature,
/// umbrella from rain now / rain coming, one bubble at a time.
enum Rules {
    /// How many outfits each character has (sprites `<char>-stand-0…14-*`, `<char>-lock-0…14`).
    static let levels = 15
    static let maxLevel = levels - 1
    /// Any level number made safe for the sprite and colour tables.
    static func clamp(_ level: Int) -> Int { max(0, min(maxLevel, level)) }

    /// Outfit level 0...14 from feels-like °C. Boundaries are the upper edge of each level (same table as the server):
    ///  0: 35°+ 민소매·모자 · 1: 33–34 · 2: 28–32 · 3: 23–27 · 4: 20–22 · 5: 18–19 · 6: 16–17 · 7: 12–15 · 8: 9–11
    ///  9: 6–8 · 10: 3–5 · 11: 0–2 · 12: −4…−1 · 13: −9…−5 · 14: −10° and below
    static let levelUpper: [Double] = [.infinity, 34.5, 32.5, 27.5, 22.5, 19.5, 17.5, 15.5, 11.5, 8.5, 5.5, 2.5, -0.5, -4.5, -9.5]
    static func level(feels: Double, previous: Int? = nil) -> Int {
        var lv = maxLevel
        for i in 1..<levelUpper.count where feels > levelUpper[i] { lv = i - 1; break }
        // ±1° hysteresis: stay on the previous level unless we are a full degree past its edge
        if let p = previous, abs(p - lv) == 1 {
            let edge = levelUpper[max(p, lv)]
            if abs(feels - edge) < 1.0 { return p }
        }
        return lv
    }
    /// The outfit level of the old ten-outfit table (servers before `outfit` existed sent only this) → today's level.
    static func level(fromLegacy old: Int) -> Int { [1, 2, 3, 4, 5, 6, 7, 9, 11, 14][max(0, min(9, old))] }

    /// Wind as people feel it (same words as the server: Beaufort + KMA everyday guidance).
    static func windWord(ms: Int) -> String {
        switch ms {
        case ..<1: return L("바람 없어요")
        case 1: return L("바람 약해요")
        case 2...3: return L("산들바람")
        case 4...5: return L("바람 조금")
        case 6...7: return L("바람 꽤 강해요")
        case 8...10: return L("바람 강해요")
        case 11...13: return L("매우 강한 바람")
        default: return L("강풍 · 외출 조심하세요")
        }
    }

    /// Background colour per outfit level (the hero gradient starts from it): the design's ten colours spread over the
    /// fifteen outfits by temperature (the new in-between bands sit between their neighbours).
    static let background = ["#FFC2A8", "#FFC2A8", "#FFD3B5", "#FFE8A3", "#F3F0B5", "#D9EFCF", "#D3E6F4", "#CDDCEF",
                             "#CBD8EF", "#C8D4F0", "#C0CDED", "#B7C6EA", "#B3C1E8", "#AEBCE5", "#A9B6E2"]

    /// Umbrella state from precipitation now and the next 12 hours.
    static func rainState(nowMM: Double, startsInHours: Int?, maxChance12h: Int) -> RainState {
        if nowMM > 0 { return .umbrella }
        if let h = startsInHours, h <= 12 { return .bag }
        if maxChance12h >= 30 { return .bag }
        if maxChance12h >= 10 { return .think }
        return .none
    }

    /// Rain timing is always said as a clock time, never as a countdown.
    /// Start is rounded down to 10 minutes (15:57 → 15:50쯤), end up (16:37 → 16:40쯤).
    static func hhmm(_ minutes: Int) -> String {
        let t = ((minutes % 1440) + 1440) % 1440
        return "\(t / 60):" + String(format: "%02d", t % 60)
    }
    /// Rain per hour in everyday terms, and what to do about it
    static func rainKind(_ mm: Double) -> String {
        mm >= 30 ? L("매우 강한 비") : mm >= 15 ? L("강한 비") : mm >= 3 ? L("보통 비") : mm >= 1 ? L("약한 비") : L("이슬비")
    }
    static func rainKindNote(_ mm: Double) -> String {
        mm >= 30 ? L("되도록 외출은 줄이는 게 좋아요") : mm >= 15 ? L("우산·우비 챙기세요") : mm >= 3 ? L("우산 꼭 챙기세요") : mm >= 1 ? L("우산 챙기세요") : L("가볍게 내려요")
    }
    /// Snow per hour, by its water (mm ≈ cm of snow): 약한 눈 · 보통 눈 · 강한 눈
    static func snowKind(_ mm: Double) -> String { mm >= 3 ? L("강한 눈") : mm >= 1 ? L("보통 눈") : L("약한 눈") }
    /// A day's (or 12 h) total: 조금 · 보통 · 많음 · 매우 많음
    static func rainAmountWord(_ mm: Double) -> String { mm >= 50 ? L("매우 많음") : mm >= 20 ? L("많음") : mm >= 5 ? L("보통") : L("조금") }

    /// Feels-like in eight steps, the same words everywhere
    static func feelsWord(_ c: Int) -> String {
        switch c {
        case ...(-10): return L("매우 추움")
        case -9...0: return L("추움")
        case 1...8: return L("쌀쌀")
        case 9...16: return L("선선")
        case 17...22: return L("온화")
        case 23...27: return L("따뜻")
        case 28...32: return L("더움")
        default: return L("매우 더움")
        }
    }
}
