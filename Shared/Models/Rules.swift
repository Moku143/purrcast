import Foundation

/// The judgement rules from the design kit (README §1): outfit from the feels-like temperature,
/// umbrella from rain now / rain coming, one bubble at a time.
enum Rules {
    /// Outfit level 0...9 from feels-like °C. Boundaries are the upper edge of each level (same table as the server:
    /// the usual 기온별 옷차림 bands — 12–16° is jacket / trench weather, a knit alone is for 16–17°).
    static let levelUpper: [Double] = [.infinity, 32.5, 27.5, 22.5, 19.5, 17.5, 15.5, 9.5, 4.5, -9.5]
    static func level(feels: Double, previous: Int? = nil) -> Int {
        // 0: 33+, 1: 28-32, 2: 23-27, 3: 20-22, 4: 18-19, 5: 16-17, 6: 10-15, 7: 5-9, 8: -9...4, 9: <= -10
        var lv = 9
        for i in 1..<levelUpper.count where feels > levelUpper[i] { lv = i - 1; break }
        if feels > 32.5 { lv = 0 }
        // ±1° hysteresis: stay on the previous level unless we are a full degree past its edge
        if let p = previous, abs(p - lv) == 1 {
            let edge = levelUpper[max(p, lv)]
            if abs(feels - edge) < 1.0 { return p }
        }
        return lv
    }

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
        default: return L("강풍 · 외출 주의")
        }
    }

    /// Background colour per outfit level (the hero gradient starts from it).
    static let background = ["#FFB899", "#FFCAA6", "#FFE38C", "#EDF0A4", "#CDEFC0", "#C4E2F8", "#BDD5F4", "#B9CAF3", "#A8BCEE", "#9AAEE8"]

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
    /// Rain per hour in everyday terms (what it means for an umbrella)
    static func rainKind(_ mm: Double) -> String {
        mm >= 30 ? L("매우 강한 비") : mm >= 15 ? L("강한 비") : mm >= 3 ? L("보통 비") : mm >= 1 ? L("약한 비") : L("이슬비")
    }
    static func rainKindNote(_ mm: Double) -> String {
        mm >= 30 ? L("우산으로 막기 어려워요") : mm >= 15 ? L("바닥에 물이 고여요") : mm >= 3 ? L("우산이 꼭 필요해요") : mm >= 1 ? L("우산이 필요해요") : L("우산 없이도 괜찮아요")
    }
    /// A day's (or 12 h) total: 조금 · 보통 · 많음 · 매우 많음
    static func rainAmountWord(_ mm: Double) -> String { mm >= 50 ? L("매우 많음") : mm >= 20 ? L("많음") : mm >= 5 ? L("보통") : L("조금") }

    /// Feels-like in eight steps, the same words everywhere
    static func feelsWord(_ c: Int) -> String {
        switch c {
        case ...(-10): return L("매우 추움")
        case -9...0: return L("추움")
        case 1...8: return L("쌀쌀")
        case 9...16: return L("선선")
        case 17...22: return L("쾌적")
        case 23...27: return L("따뜻")
        case 28...32: return L("더움")
        default: return L("매우 더움")
        }
    }
}
