import SwiftUI

/// What the 시간별 and 10일 cards show: the weather (as before), rain, wind, or what to wear. One switch on 시간별;
/// 10일 follows it.
enum HomeMetric: String, CaseIterable {
    case weather, rain, wind, outfit

    var title: String {
        switch self { case .weather: return "날씨"; case .rain: return "비"; case .wind: return "바람"; case .outfit: return "옷차림" }
    }
    var icon: String {
        switch self { case .weather: return "partly_cloudy"; case .rain: return "raindrop"; case .wind: return "wind"; case .outfit: return "scarf" }
    }

    struct HourWind { let speed: Int; let dir: Int? }

    /// The wind for each of the 시간별 hours: now from the scene, then the day sheets' rows of the same hour
    /// (today's, then tomorrow's); nil where no row has it
    static func hourWinds(_ s: WeatherScene) -> [HourWind?] {
        // the day sheets' rows on one clock: today's hours, then tomorrow's +24 (rows can be every hour or every three)
        let days = (s.dayDetail ?? []).prefix(2)
        var rows: [(Int, WeatherScene.DayHour)] = []
        for (d, day) in days.enumerated() {
            for r in day { if let h = HourLabel.hour(r.label) ?? (r.label == "자정" ? 0 : nil) { rows.append((h + 24 * d, r)) } }
        }
        let now = WeatherScene.clockMinutes(s.clock).map { $0 / 60 } ?? HourLabel.hour(s.hours.first?.label ?? "") ?? 0
        var last = now
        return s.hours.enumerated().map { i, h in
            if i == 0 { return HourWind(speed: s.wind.speed, dir: s.wind.deg) }
            guard var hh = HourLabel.hour(h.label) else { return nil }
            while hh <= last { hh += 24 }          // past midnight: tomorrow's hour
            last = hh
            // that hour's row, else the nearest within two hours (a three-hourly forecast)
            guard let best = rows.min(by: { abs($0.0 - hh) < abs($1.0 - hh) }), abs(best.0 - hh) <= 2 else { return nil }
            return HourWind(speed: Int(best.1.wind.rounded()), dir: best.1.dir.map { Int($0.rounded()) })
        }
    }

    /// How warm hour `i` feels (the app's own rule: night, rain and wind make it colder, humid heat warmer)
    static func hourFeels(_ s: WeatherScene, _ i: Int, wind: HourWind?) -> Double {
        let h = s.hours[i]
        if i == 0 { return Double(s.feels) }
        let hour = HourLabel.hour(h.label) ?? 12
        return Rules.hourFeel(temp: Double(h.temp), hour: hour, wind: Double(wind?.speed ?? s.wind.speed), rh: 60, rainy: h.mm > 0 || h.chance >= 60)
    }

    /// Day `i` in eight three-hour slices: the rain forecast in each (mm), and the day's total
    static func dayRain(_ s: WeatherScene, _ i: Int) -> (bins: [Double], mm: Double) {
        var bins = [Double](repeating: 0, count: 8)
        guard let rows = s.dayDetail?[safe: i] else { return (bins, 0) }
        for r in rows {
            guard let h = HourLabel.hour(r.label) ?? (r.label == "자정" ? 0 : nil), h >= 0, h < 24 else { continue }
            bins[h / 3] += max(0, r.mm ?? 0)
        }
        return (bins, bins.reduce(0, +))
    }

    /// The slice of today the clock is in
    static func nowBin(_ s: WeatherScene) -> Int? {
        guard let m = WeatherScene.clockMinutes(s.clock) else { return nil }
        return min(7, m / 180)
    }

    /// Day `i`'s wind through the day (m/s, in order) and its range
    static func dayWind(_ s: WeatherScene, _ i: Int) -> (values: [Double], lo: Int, hi: Int) {
        let v = (s.dayDetail?[safe: i] ?? []).map(\.wind)
        guard let lo = v.min(), let hi = v.max() else { return ([], 0, 0) }
        return (v, Int(lo.rounded()), Int(hi.rounded()))
    }

    /// How warm day `i` feels while people are out (8 to 20 h), else the middle of its range
    static func dayFeels(_ s: WeatherScene, _ i: Int) -> Double {
        let rows = (s.dayDetail?[safe: i] ?? []).compactMap { r -> Double? in
            guard let h = HourLabel.hour(r.label), (8...20).contains(h) else { return nil }
            return Rules.hourFeel(temp: r.temp, hour: h, wind: r.wind, rh: r.rh, rainy: (r.mm ?? 0) > 0 || r.chance >= 60)
        }
        if !rows.isEmpty { return rows.reduce(0, +) / Double(rows.count) }
        guard i < s.days.count else { return Double(s.feels) }
        return Double(s.days[i].lo + s.days[i].hi) / 2
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { i >= 0 && i < count ? self[i] : nil }
}

/// The four choices in the app's pixel look: each an icon and a word, the chosen one on a white tile
struct MetricSwitch: View {
    @Binding var metric: HomeMetric
    let ink: Ink
    var body: some View {
        HStack(spacing: 4) {
            ForEach(HomeMetric.allCases, id: \.self) { m in
                let on = m == metric
                Button {
                    guard m != metric else { return }
                    Haptic.select()
                    withAnimation(Motion.gentle) { metric = m }
                } label: {
                    HStack(spacing: 4) {
                        PixelIcon(name: m.icon, size: 14)
                        Text(L(m.title)).font(.px(11)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(on ? ink.ink : ink.sub)
                    .frame(maxWidth: .infinity).frame(height: 30)
                    .background(on ? ink.btn : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(on ? ink.cardBorder : .clear, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.press(0.96))
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("metric-\(m.rawValue)")
            }
        }
        .padding(3)
        .background(ink.track.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// One hour's rain as a column of pixel blocks (more blocks for more rain); a likely shower without an amount
/// shows one pale block
struct PixelRainColumn: View {
    let mm: Double
    let chance: Int
    let ink: Ink
    static let steps: [Double] = [0.1, 0.3, 0.5, 1, 1.5, 2, 3, 5, 7, 10, 15]
    var body: some View {
        let n = mm > 0 ? max(1, Self.steps.filter { mm >= $0 }.count) : 0
        VStack(spacing: 1) {
            Spacer(minLength: 0)
            if n == 0 && chance >= 30 {
                Rectangle().fill(ink.blue.opacity(0.28)).frame(width: 18, height: 3)
            }
            ForEach(0..<n, id: \.self) { k in
                // heavier rain darker toward the top, as the radar's colours
                Rectangle().fill(n - k > 8 ? Color(hex: "#E8292A") : n - k > 6 ? Color(hex: "#F2B705") : ink.blue).frame(width: 18, height: 3)
            }
        }
        .frame(width: 22)
        .background(alignment: .bottom) { Rectangle().fill(ink.track).frame(width: 22, height: 2) }
    }
}

/// Where the wind blows to: a stepped pixel arrow turned from north (the wind comes from `deg`)
struct WindArrow: View {
    let deg: Int?
    let ink: Ink
    var body: some View {
        Group {
            if let d = deg {
                Canvas { c, size in
                    let u = size.width / 7     // a 7 × 7 pixel arrow pointing up
                    let cells: [(Int, Int)] = [(3, 0), (2, 1), (3, 1), (4, 1), (1, 2), (3, 2), (5, 2), (3, 3), (3, 4), (3, 5), (3, 6)]
                    for (x, y) in cells { c.fill(Path(CGRect(x: CGFloat(x) * u, y: CGFloat(y) * u, width: u, height: u)), with: .color(ink.ink)) }
                }
                .rotationEffect(.degrees(Double(d) + 180))
            } else {
                Rectangle().fill(ink.faint).frame(width: 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A day in eight three-hour slices: each a pixel cell filled from the bottom by its rain; the slice now outlined
struct DayRainStrip: View {
    let bins: [Double]
    let now: Int?
    let ink: Ink
    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(bins.enumerated()), id: \.offset) { k, mm in
                let f = mm <= 0 ? 0 : min(1, 0.25 + log10(1 + mm) * 0.55)
                ZStack(alignment: .bottom) {
                    Rectangle().fill(ink.track)
                    Rectangle().fill(ink.blue).frame(height: 22 * f)
                }
                .frame(width: 7)
                .overlay(Rectangle().strokeBorder(k == now ? ink.ink : .clear, lineWidth: 1.5))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A day's wind as a stepped line (the pixel look), 0 at the bottom, the strongest of the ten days at the top
struct WindSpark: View {
    let values: [Double]
    let ink: Ink
    var body: some View {
        Canvas { c, size in
            guard values.count > 1 else { return }
            let top = max(6, values.max() ?? 1)
            let w = size.width / CGFloat(values.count)
            var p = Path()
            for (i, v) in values.enumerated() {
                let y = size.height - CGFloat(v / top) * (size.height - 2) - 1
                let x0 = CGFloat(i) * w
                if i == 0 { p.move(to: CGPoint(x: x0, y: y)) } else { p.addLine(to: CGPoint(x: x0, y: y)) }
                p.addLine(to: CGPoint(x: x0 + w, y: y))
            }
            c.stroke(p, with: .color(ink.blue), style: StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter))
        }
        .background(alignment: .bottom) { Rectangle().fill(ink.track).frame(height: 1) }
        .frame(maxWidth: .infinity)
    }
}
