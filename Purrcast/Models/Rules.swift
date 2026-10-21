import Foundation

/// The judgement rules from the design kit (README §1): outfit from the feels-like temperature,
/// umbrella from rain now / rain coming, one bubble at a time.
enum Rules {
    /// Outfit level 0...9 from feels-like °C. Boundaries are the upper edge of each level.
    static let levelUpper: [Double] = [.infinity, 32.5, 27.5, 22.5, 19.5, 16.5, 11.5, 8.5, 4.5, -9.5]
    static func level(feels: Double, previous: Int? = nil) -> Int {
        // 0: 33+, 1: 28-32, 2: 23-27, 3: 20-22, 4: 17-19, 5: 12-16, 6: 9-11, 7: 5-8, 8: -9...4, 9: <= -10
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

    /// Background colour per outfit level (the hero gradient starts from it).
    static let background = ["#FFC2A8", "#FFD3B5", "#FFE8A3", "#F3F0B5", "#D9EFCF", "#D3E6F4", "#CDDCEF", "#C8D4F0", "#B7C6EA", "#A9B6E2"]

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
    static func rainKind(_ mm: Double) -> String { mm >= 6 ? "강한 비" : (mm >= 2.5 ? "보통 비" : "약한 비") }
}
