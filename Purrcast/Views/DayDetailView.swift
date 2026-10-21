import SwiftUI

/// Tapping a day in the 10-day list: the day strip on top, the character dressed for that day,
/// a one-line summary, and the temperature curve over the day.
struct DayDetailView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State var start: Int
    @State private var metric = 0

    private let metrics = [("thermo_hot", "기온"), ("umbrella_closed", "비"), ("wind", "바람"), ("sun_strong", "자외선"), ("raindrop", "습도")]

    var body: some View {
        let s = model.scene
        let d = s.days[min(start, s.days.count - 1)]
        let mid = (d.hi + d.lo) / 2
        let lv = Rules.level(feels: Double(mid))
        let rain: RainState = d.chance >= 60 ? .umbrella : (d.chance >= 30 ? .bag : .none)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(title(d, index: start)).font(.px(18))
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).frame(width: 32, height: 32).background(Color.white).clipShape(Circle()) }
                        .buttonStyle(.plain).accessibilityIdentifier("sheet-close")
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(s.days.enumerated()), id: \.offset) { i, x in
                            Button { start = i } label: {
                                VStack(spacing: 4) {
                                    Text(x.name).font(.px(11)).foregroundStyle(i == start ? .white : UI.sub)
                                    PixelIcon(name: x.icon, size: 26)
                                    Text(dayNumber(i)).font(.px(14))
                                    Text("\(x.hi)°/\(x.lo)°").font(.system(size: 9)).foregroundStyle(i == start ? .white.opacity(0.8) : UI.sub)
                                }
                                .foregroundStyle(i == start ? .white : UI.ink)
                                .frame(width: 50).padding(.vertical, 8)
                                .background(i == start ? UI.ink : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain)
                        }
                    }
                }

                HStack(spacing: 6) {
                    ForEach(Array(metrics.enumerated()), id: \.offset) { i, m in
                        Button { metric = i } label: {
                            VStack(spacing: 3) { PixelIcon(name: m.0, size: 18); Text(m.1).font(.system(size: 11, weight: .medium)) }
                                .foregroundStyle(i == metric ? .white : UI.ink)
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(i == metric ? UI.ink : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain)
                    }
                }

                HStack(alignment: .top, spacing: 8) {
                    CharacterSprite(character: model.shownCharacter, level: lv, rain: rain, width: 92)
                        .frame(width: 92, height: 108).clipped()
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("\(model.deg(d.hi)) / \(model.deg(d.lo))").font(.px(20))
                            Text("일교차 \(d.hi - d.lo)°").font(.px(11)).padding(.horizontal, 6).padding(.vertical, 2).background(Color(hex: "#FFE8A3"))
                        }
                        Text(summary(d)).font(.system(size: 13)).foregroundStyle(UI.ink)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white).overlay(Rectangle().stroke(UI.ink, lineWidth: 2))
                }

                Card(ink: Ink(night: false)) {
                    Text(metrics[metric].1).font(.px(13))
                    curve(d, metric: metric).frame(height: 150)
                    HStack { ForEach(["0시", "6시", "12시", "18시", "24시"], id: \.self) { t in Text(model.hourLabel(t)).font(.system(size: 10)).foregroundStyle(UI.sub); if t != "24시" { Spacer() } } }
                }

                Card(ink: Ink(night: false)) {
                    Text("시간대별 \(metrics[metric].1)").font(.px(13))
                    HStack(spacing: 8) {
                        ForEach(Array(["새벽", "아침", "낮", "밤"].enumerated()), id: \.offset) { i, n in
                            let v = band(d, i)
                            VStack(spacing: 4) { Text(n).font(.system(size: 11)); Text(value(v, metric: metric)).font(.px(16)) }
                                .foregroundStyle(i == 2 ? .white : UI.ink)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(i == 2 ? UI.ink : Color.white).overlay(Rectangle().stroke(UI.ink, lineWidth: 1.5))
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

    private func summary(_ d: WeatherScene.DayRow) -> String {
        var t = "\(d.lo)°로 가장 쌀쌀하고, 오후에 \(d.hi)°로 가장 따뜻해요."
        if d.chance >= 30 { t += " 비 올 확률 \(d.chance)%, 우산 챙겨요." }
        return t
    }

    /// Smooth day curve from lo (around 5 am) to hi (around 3 pm), 24 points.
    private func series(_ d: WeatherScene.DayRow, metric: Int) -> [Double] {
        (0..<25).map { h in
            let x = Double(h)
            let lo = Double(d.lo), span = Double(d.hi - d.lo)
            var k: Double
            if x < 5 { k = 0.15 - x * 0.03 }                                   // night, cooling to the low at 5 am
            else if x <= 15 { k = 0.5 - 0.5 * cos((x - 5) / 10 * Double.pi) }  // warming to the high at 3 pm
            else { k = max(0.3, 1 - (x - 15) / 14) }                          // evening
            let t = lo + span * k
            switch metric {
            case 1: return Double(d.chance) * max(0, sin(x / 24 * .pi))           // rain chance through the day
            case 2: return 2 + 3 * sin(x / 24 * .pi)                               // wind m/s
            case 3: return max(0, 7 * sin((x - 6) / 12 * .pi))                     // UV
            case 4: return 80 - 30 * sin((x - 3) / 24 * .pi)                       // humidity %
            default: return t
            }
        }
    }

    private func band(_ d: WeatherScene.DayRow, _ i: Int) -> Double { series(d, metric: metric)[[3, 8, 14, 21][i]] }
    private func value(_ v: Double, metric: Int) -> String {
        switch metric {
        case 1, 4: return "\(Int(v.rounded()))%"
        case 2: return model.windText(Int(v.rounded()))
        case 3: return "\(Int(v.rounded()))"
        default: return model.deg(Int(v.rounded()))
        }
    }

    private func curve(_ d: WeatherScene.DayRow, metric: Int) -> some View {
        let ys = series(d, metric: metric)
        let lo = ys.min() ?? 0, hi = max((ys.max() ?? 1), lo + 1)
        return GeometryReader { g in
            let pt = { (i: Int) -> CGPoint in
                CGPoint(x: g.size.width * CGFloat(i) / 24, y: g.size.height * (1 - CGFloat((ys[i] - lo) / (hi - lo))) * 0.8 + g.size.height * 0.1)
            }
            ZStack {
                Path { p in p.move(to: CGPoint(x: 0, y: g.size.height)); for i in 0..<ys.count { p.addLine(to: pt(i)) }; p.addLine(to: CGPoint(x: g.size.width, y: g.size.height)) }
                    .fill(LinearGradient(colors: [Color(hex: "#C9E3A0").opacity(0.7), .clear], startPoint: .top, endPoint: .bottom))
                Path { p in p.move(to: pt(0)); for i in 1..<ys.count { p.addLine(to: pt(i)) } }
                    .stroke(Color(hex: "#7DBE4E"), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
                let now = Calendar.current.component(.hour, from: Date())
                Rectangle().fill(UI.ink).frame(width: 1.5).position(x: pt(now).x, y: g.size.height / 2).opacity(start == 0 ? 0.6 : 0)
            }
        }
    }
}
