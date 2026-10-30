import SwiftUI

/// 미세먼지 steps, colours and ranges — shared by the app, the widgets and the watch.
enum DustScale {
    static let words = ["좋음", "보통", "나쁨", "매우 나쁨"]
    static let colors = ["#4CAF50", "#F2C230", "#F28C28", "#E2453C"]
    static let onColors = ["#FFFFFF", "#1E2A44", "#1E2A44", "#FFFFFF"]
    /// The upper bound of each step (the last one is where the bar ends): 환경부 PM10 30 · 80 · 150, PM2.5 15 · 35 · 75;
    /// abroad WHO's 2021 24-hour values (the guideline, then interim targets 3 and 1): PM10 45 · 75 · 150, PM2.5 15 · 37.5 · 75.
    static func bounds(pm25: Bool, who: Bool = false) -> [Double] {
        who ? (pm25 ? [0, 15, 37.5, 75, 150] : [0, 45, 75, 150, 300]) : (pm25 ? [0, 15, 35, 75, 150] : [0, 30, 80, 150, 300])
    }
    /// 0 좋음 … 3 매우 나쁨
    static func grade(_ v: Double, pm25: Bool, who: Bool = false) -> Int {
        let b = bounds(pm25: pm25, who: who)
        return v <= b[1] ? 0 : v <= b[2] ? 1 : v <= b[3] ? 2 : 3
    }
    /// "0~15", "16~35", "36~75", "76+" — the step's range as the scale card prints it
    static func range(_ i: Int, pm25: Bool, who: Bool = false) -> String {
        let b = bounds(pm25: pm25, who: who)
        let n = { (v: Double) -> String in v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }
        if i >= 3 { return n(b[3] + 1) + "+" }
        return (i == 0 ? "0" : n(floor(b[i]) + 1)) + "~" + n(b[i + 1])
    }
    /// Where a value sits in its grade's segment (0…1 across the whole bar).
    static func position(_ v: Double, pm25: Bool, who: Bool = false) -> Double {
        let b = bounds(pm25: pm25, who: who)
        for i in 0..<4 where v <= b[i + 1] || i == 3 {
            let t = min(1, max(0, (v - b[i]) / (b[i + 1] - b[i])))
            return (Double(i) + t) / 4
        }
        return 1
    }
}
