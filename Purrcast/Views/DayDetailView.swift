import SwiftUI

/// Tapping a day in the 10-day list: the day strip, the character dressed for that day, a one-line summary,
/// and the day's 3-hourly forecast (temperature, rain chance, wind, UV, humidity) as a curve and four bands.
/// Everything comes from the forecast (`dayDetail`); without it only the summary is shown.
struct DayDetailView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State var start: Int
    @State private var metric = 0
    @Namespace private var ns

    private let metrics = [("thermo_hot", "기온"), ("umbrella_closed", "비"), ("wind", "바람"), ("sun_strong", "자외선"), ("raindrop", "습도")]

    var body: some View {
        let s = model.scene
        if s.days.isEmpty {
            VStack(spacing: 12) {
                Text("이 날의 예보가 아직 없어요").font(.px(16))
                Button("닫기") { dismiss() }.tint(UI.accent)
            }.frame(maxWidth: .infinity, maxHeight: .infinity).background(UI.bg)
        } else {
            content(s, index: max(0, min(start, s.days.count - 1)))
        }
    }

    private func content(_ s: WeatherScene, index: Int) -> some View {
        let d = s.days[index]
        let detail: [WeatherScene.DayHour]? = s.dayDetail.flatMap { index < $0.count && $0[index].count >= 2 ? $0[index] : nil }
        let lv = Rules.level(feels: Double(d.hi + d.lo) / 2)
        let rain: RainState = d.chance >= 60 ? .umbrella : (d.chance >= 30 ? .bag : .none)
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(title(d, index: index)).font(.px(18))
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).frame(width: 32, height: 32).background(Color.white).clipShape(Circle()) }
                        .buttonStyle(.plain).accessibilityIdentifier("sheet-close").accessibilityLabel("닫기")
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(s.days.enumerated()), id: \.offset) { i, x in
                            Button { Haptic.select(); withAnimation(Motion.snappy) { start = i } } label: {
                                VStack(spacing: 4) {
                                    Text(x.name).font(.px(11)).foregroundStyle(i == index ? .white : UI.sub)
                                    PixelIcon(name: x.icon, size: 26)
                                    Text(dayNumber(i)).font(.px(14))
                                    Text("\(model.deg(x.hi))/\(model.deg(x.lo))").font(.ui(9)).foregroundStyle(i == index ? .white.opacity(0.8) : UI.sub)
                                }
                                .foregroundStyle(i == index ? .white : UI.ink)
                                .frame(width: 50).padding(.vertical, 8)
                                .background {
                                    if i == index { RoundedRectangle(cornerRadius: 12).fill(UI.ink).matchedGeometryEffect(id: "day", in: ns) }
                                    else { RoundedRectangle(cornerRadius: 12).fill(Color.white) }
                                }
                            }.buttonStyle(.press(0.95))
                        }
                    }
                }

                HStack(alignment: .top, spacing: 8) {
                    CharacterSprite(character: model.shownCharacter, level: lv, rain: rain, width: 92)
                        .reveal(0, rise: 12)
                        .frame(width: 92, height: 108).clipped()
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("\(model.deg(d.hi)) / \(model.deg(d.lo))").font(.px(20)).rolling(d.hi * 1000 + d.lo)
                            Text("일교차 \(d.hi - d.lo)°").font(.px(11)).padding(.horizontal, 6).padding(.vertical, 2).background(Color(hex: "#FFE8A3"))
                        }
                        Text(model.say(summary(d, detail))).font(.ui(15)).foregroundStyle(UI.ink)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white).overlay(Rectangle().stroke(UI.ink, lineWidth: 2))
                }

                if let detail {
                    HStack(spacing: 6) {
                        ForEach(Array(metrics.enumerated()), id: \.offset) { i, m in
                            Button { Haptic.select(); withAnimation(Motion.snappy) { metric = i } } label: {
                                VStack(spacing: 3) { PixelIcon(name: m.0, size: 18); Text(m.1).font(.ui(11, .medium)) }
                                    .foregroundStyle(i == metric ? .white : UI.ink)
                                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                                    .background {
                                        if i == metric { RoundedRectangle(cornerRadius: 10).fill(UI.ink).matchedGeometryEffect(id: "metric", in: ns) }
                                        else { RoundedRectangle(cornerRadius: 10).fill(Color.white) }
                                    }
                            }.buttonStyle(.press(0.95))
                        }
                    }

                    Card(ink: Ink(night: false)) {
                        Text(metrics[metric].1).font(.px(13)).id(metric).transition(.opacity)
                        curve(values(detail)).frame(height: 150)
                            .animation(Motion.gentle, value: metric)
                        HStack {
                            ForEach(Array(detail.enumerated()), id: \.offset) { i, h in
                                if i % 2 == 0 {
                                    Text(model.hourLabel(h.label)).font(.ui(10)).foregroundStyle(UI.sub)
                                    if i < detail.count - 2 { Spacer() }
                                }
                            }
                        }
                    }

                    Card(ink: Ink(night: false)) {
                        Text("시간대별 \(metrics[metric].1)").font(.px(13))
                        HStack(spacing: 8) {
                            ForEach(Array(bands(detail).enumerated()), id: \.offset) { i, b in
                                VStack(spacing: 4) { Text(b.0).font(.ui(11)); Text(value(b.1)).font(.px(16)).rolling(value(b.1)) }
                                    .foregroundStyle(i == 2 ? .white : UI.ink)
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(i == 2 ? UI.ink : Color.white).overlay(Rectangle().stroke(UI.ink, lineWidth: 1.5))
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(hex: Rules.background[lv]).opacity(0.55).ignoresSafeArea())
        .foregroundStyle(UI.ink)
    }

    private func title(_ d: WeatherScene.DayRow, index: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: index, to: Date()) ?? Date()
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "M월 d일 EEEE"
        let lead = index == 0 ? "오늘" : (index == 1 ? "내일" : d.name)
        return "\(lead) · \(f.string(from: date))"
    }

    private func dayNumber(_ i: Int) -> String {
        String(Calendar.current.component(.day, from: Calendar.current.date(byAdding: .day, value: i, to: Date()) ?? Date()))
    }

    /// One friendly line about the day, broad rather than itemised, never a clock time, never a promise.
    private func summary(_ d: WeatherScene.DayRow, _ detail: [WeatherScene.DayHour]?) -> String {
        var t: String
        let lo = d.lo, hi = d.hi
        var loPart = "아침", hiPart = "낮"
        if let detail, let cold = detail.min(by: { $0.temp < $1.temp }), let warm = detail.max(by: { $0.temp < $1.temp }) {
            loPart = partOfDay(cold.label); hiPart = partOfDay(warm.label)
        }
        if hi >= 30 {
            t = "\(hiPart)에 최고 \(model.deg(hi))예요. 더우니 물을 챙겨 주세요." + (lo >= 25 ? " 밤에도 \(model.deg(lo)) 이상이에요." : "")
        } else if hi <= 0 || lo <= -5 {
            t = "\(loPart) \(model.deg(lo)), \(hiPart) \(model.deg(hi))예요. 많이 추워요."
        } else if hi - lo >= 6 {
            t = "\(loPart) \(model.deg(lo)), \(hiPart) \(model.deg(hi))예요. 일교차가 커요."
        } else {
            t = "하루 종일 \(model.deg(lo))~\(model.deg(hi))예요."
        }
        // vs the day before (the 10-day list has yesterday only as "today" when looking at tomorrow+)
        let s = model.scene
        if let i = s.days.firstIndex(where: { $0.name == d.name && $0.hi == d.hi && $0.lo == d.lo }), i > 0 {
            let diff = d.hi - s.days[i - 1].hi
            if abs(diff) >= 3 { t += " 전날보다 \(abs(diff))° \(diff > 0 ? "높아요" : "낮아요")." }
        } else if i0(d), abs(s.yday) >= 3 {
            t += " 어제 이맘때보다 \(abs(s.yday))° \(s.yday > 0 ? "높아요" : "낮아요")."
        }
        if d.chance >= 60 { t += d.icon == "snowflake" ? " 눈 예보예요. 길이 미끄러울 수 있어요." : " 비 예보예요. 우산을 챙겨 주세요." }
        else if d.chance >= 30 { t += " 비 올 가능성이 \(d.chance)%예요. 우산이 있으면 좋아요." }
        return t
    }

    private func i0(_ d: WeatherScene.DayRow) -> Bool { model.scene.days.first.map { $0.name == d.name && $0.hi == d.hi } ?? false }

    /// "9시" → 아침 (never a clock time in a sentence)
    private func partOfDay(_ label: String) -> String {
        let h = Int(label.replacingOccurrences(of: "시", with: "")) ?? 12
        return h < 5 ? "밤" : h < 12 ? "아침" : h < 17 ? "낮" : h < 21 ? "저녁" : "밤"
    }

    private func values(_ detail: [WeatherScene.DayHour]) -> [Double] {
        detail.map { h in
            switch metric { case 1: return h.chance; case 2: return h.wind; case 3: return h.uv; case 4: return h.rh; default: return h.temp }
        }
    }

    /// 새벽 · 아침 · 낮 · 밤 from the 3-hourly values (around 3, 9, 15, 21 h)
    private func bands(_ detail: [WeatherScene.DayHour]) -> [(String, Double)] {
        let v = values(detail)
        let pick = { (i: Int) -> Double in v[min(i, v.count - 1)] }
        return [("새벽", pick(1)), ("아침", pick(3)), ("낮", pick(5)), ("밤", pick(7))]
    }

    private func value(_ v: Double) -> String {
        switch metric {
        case 1, 4: return "\(Int(v.rounded()))%"
        case 2: return model.windText(Int(v.rounded()))
        case 3: return "\(Int(v.rounded()))"
        default: return model.deg(Int(v.rounded()))
        }
    }

    private func curve(_ ys: [Double]) -> some View {
        let lo = ys.min() ?? 0, hi = max(ys.max() ?? 1, lo + 1)
        return GeometryReader { g in
            CurveShape(ys: ys.map { ($0 - lo) / (hi - lo) }, fill: true)
                .fill(LinearGradient(colors: [Color(hex: "#C9E3A0").opacity(0.7), .clear], startPoint: .top, endPoint: .bottom))
            CurveShape(ys: ys.map { ($0 - lo) / (hi - lo) }, fill: false)
                .stroke(Color(hex: "#7DBE4E"), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
            let n = max(1, ys.count - 1)
            ForEach(0..<ys.count, id: \.self) { i in
                Circle().fill(Color(hex: "#7DBE4E")).frame(width: 6, height: 6)
                    .position(x: g.size.width * CGFloat(i) / CGFloat(n), y: g.size.height * (1 - CGFloat((ys[i] - lo) / (hi - lo))) * 0.8 + g.size.height * 0.1)
            }
        }
    }
}

/// The day curve as an animatable shape, so switching 기온 → 비 → 바람 morphs the line instead of swapping it.
private struct CurveShape: Shape {
    var ys: [Double]          // 0…1
    var fill: Bool
    var animatableData: AnimatableVector { get { AnimatableVector(ys) } set { ys = newValue.values } }
    func path(in r: CGRect) -> Path {
        var p = Path()
        guard ys.count > 1 else { return p }
        let n = CGFloat(ys.count - 1)
        let pt = { (i: Int) -> CGPoint in CGPoint(x: r.width * CGFloat(i) / n, y: r.height * (1 - CGFloat(ys[i])) * 0.8 + r.height * 0.1) }
        if fill { p.move(to: CGPoint(x: 0, y: r.height)); p.addLine(to: pt(0)) } else { p.move(to: pt(0)) }
        for i in 1..<ys.count { p.addLine(to: pt(i)) }
        if fill { p.addLine(to: CGPoint(x: r.width, y: r.height)); p.closeSubpath() }
        return p
    }
}

/// A fixed-length list of doubles SwiftUI can interpolate.
struct AnimatableVector: VectorArithmetic {
    var values: [Double]
    init(_ v: [Double]) { values = v }
    static var zero: AnimatableVector { AnimatableVector([]) }
    static func + (a: AnimatableVector, b: AnimatableVector) -> AnimatableVector { AnimatableVector(zip(a.values, b.values).map(+)) }
    static func - (a: AnimatableVector, b: AnimatableVector) -> AnimatableVector { AnimatableVector(zip(a.values, b.values).map(-)) }
    mutating func scale(by rhs: Double) { values = values.map { $0 * rhs } }
    var magnitudeSquared: Double { values.reduce(0) { $0 + $1 * $1 } }
}
