import SwiftUI

// The lower half of the home screen, card by card, as on the prototype:
// UV tile with its scale · wind card with a dial · 예보 비교 · the Plus card (free) · the sources line · the compact header.

/// WHO UV index scale: 0–2 낮음 · 3–5 보통 · 6–7 높음 · 8–10 매우 높음 · 11+ 위험
enum UVScale {
    static let bands: [(hi: Int, word: String, color: String, onColor: String, flex: CGFloat)] = [
        (2, "낮음", "#4CAF50", "#FFFFFF", 3), (5, "보통", "#F2C230", "#1E2A44", 3), (7, "높음", "#F28C28", "#1E2A44", 2),
        (10, "매우 높음", "#E2453C", "#FFFFFF", 3), (99, "위험", "#8E44AD", "#FFFFFF", 1),
    ]
    static func band(_ uv: Int) -> (hi: Int, word: String, color: String, onColor: String, flex: CGFloat) { bands.first { uv <= $0.hi } ?? bands[4] }
}

/// The five coloured segments with a ring marking today's index.
struct UVBar: View {
    let uv: Int; let ink: Ink
    var body: some View {
        GeometryReader { g in
            let total = UVScale.bands.reduce(0) { $0 + $1.flex }
            let gaps = CGFloat(UVScale.bands.count - 1) * 2
            let pos = (min(Double(uv), 11.5) + 0.5) / 12 * g.size.width
            ZStack(alignment: .topLeading) {
                HStack(spacing: 2) {
                    ForEach(Array(UVScale.bands.enumerated()), id: \.offset) { i, b in
                        Rectangle().fill(Color(hex: b.color))
                            .frame(width: (g.size.width - gaps) * b.flex / total, height: 6)
                            .clipShape(UnevenRoundedRectangle(topLeadingRadius: i == 0 ? 3 : 0, bottomLeadingRadius: i == 0 ? 3 : 0,
                                                              bottomTrailingRadius: i == 4 ? 3 : 0, topTrailingRadius: i == 4 ? 3 : 0))
                    }
                }.offset(y: 4)
                Circle().fill(ink.night ? Color(hex: "#1B2142") : .white)
                    .overlay(Circle().stroke(ink.ink, lineWidth: 2))
                    .frame(width: 10, height: 10)
                    .offset(x: pos - 5)
                    .animation(Motion.gentle, value: uv)
            }
        }
        .frame(height: 14)
    }
}

/// Wind: speed · gusts · 16-point direction on the left, a dial on the right (dot = where it comes from, arrow = where it goes).
struct WindCard: View {
    @EnvironmentObject var model: AppModel
    let wind: WeatherScene.Wind; let ink: Ink
    private var strength: String {
        wind.speed < 4 ? L("약함") : wind.speed < 9 ? L("보통") : wind.speed < 14 ? L("강함") : L("매우 강함")
    }
    static let dirs = ["북", "북북동", "북동", "동북동", "동", "동남동", "남동", "남남동", "남", "남남서", "남서", "서남서", "서", "서북서", "북서", "북북서"]
    private var dirName: String { L("%@풍", L(Self.dirs[Int((Double(wind.deg) / 22.5).rounded()) % 16])) }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) { PixelIcon(name: "wind", size: 16); Text(L("바람") + " · " + strength).font(.ui(12, .semibold)).foregroundStyle(ink.sub) }
                    .padding(.bottom, 6)
                row(L("바람"), model.windText(wind.speed), line: true)
                row(L("돌풍"), model.windText(wind.gust), line: true)
                row(L("방향"), "\(dirName) \(wind.deg)°", line: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            dial.frame(width: 104, height: 104)
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 14))
        .background(ink.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(ink.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color(hex: "#1E2A44").opacity(ink.night ? 0.22 : 0.08), radius: 9, y: 6)
    }
    private func row(_ k: String, _ v: String, line: Bool) -> some View {
        VStack(spacing: 0) {
            HStack { Text(k).font(.px(14)); Spacer(); Text(v).font(.px(14)).foregroundStyle(ink.sub).lineLimit(1) }
                .padding(.vertical, 11)
            if line { Rectangle().fill(ink.line).frame(height: 1) }
        }
    }
    /// 128-pt dial drawn at 0.8125 (104 pt): ticks every 5°, longer every 30°, gaps for the four labels.
    private var dial: some View {
        let r: CGFloat = 64
        func pt(_ deg: Double, _ rad: CGFloat) -> CGPoint { let a = deg * .pi / 180; return CGPoint(x: r + rad * sin(a), y: r - rad * cos(a)) }
        let from = Double(wind.deg), to = Double((wind.deg + 180) % 360)
        return ZStack {
            Canvas { ctx, _ in
                var minor = Path(), major = Path()
                for a in stride(from: 0, to: 360, by: 5) {
                    if a % 90 == 0 || [5, 85, 95, 175, 185, 265, 275, 355].contains(a) { continue }
                    let p1 = pt(Double(a), 60), p2 = pt(Double(a), a % 30 == 0 ? 52 : 55)
                    if a % 30 == 0 { major.move(to: p1); major.addLine(to: p2) } else { minor.move(to: p1); minor.addLine(to: p2) }
                }
                ctx.stroke(minor, with: .color(ink.night ? .white.opacity(0.28) : Color(hex: "#1E2A44").opacity(0.25)), lineWidth: 1.2)
                ctx.stroke(major, with: .color(ink.night ? .white.opacity(0.55) : Color(hex: "#1E2A44").opacity(0.5)), lineWidth: 1.6)
                var arrow = Path()
                arrow.move(to: pt(from, 45)); arrow.addLine(to: pt(from, 26))
                arrow.move(to: pt(to, 26)); arrow.addLine(to: pt(to, 39))
                ctx.stroke(arrow, with: .color(ink.ink), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                let base = pt(to, 38), tip = pt(to, 47)
                func wing(_ s: Double) -> CGPoint { let a = (to + s * 90) * .pi / 180; return CGPoint(x: base.x + 5.5 * sin(a), y: base.y - 5.5 * cos(a)) }
                var head = Path(); head.move(to: tip); head.addLine(to: wing(1)); head.addLine(to: wing(-1)); head.closeSubpath()
                ctx.fill(head, with: .color(ink.ink))
                ctx.fill(Path(ellipseIn: CGRect(x: pt(from, 45).x - 4.5, y: pt(from, 45).y - 4.5, width: 9, height: 9)), with: .color(ink.ink))
            }
            .animation(Motion.gentle, value: wind.deg)
            Text(L("북")).font(.px(12)).foregroundStyle(ink.ink).position(x: r, y: 5)
            Text(L("동")).font(.px(12)).foregroundStyle(ink.sub).position(x: 123, y: r)
            Text(L("남")).font(.px(12)).foregroundStyle(ink.sub).position(x: r, y: 123)
            Text(L("서")).font(.px(12)).foregroundStyle(ink.sub).position(x: 5, y: r)
            VStack(spacing: 3) {
                Text(model.windNumber(wind.speed)).font(.px(24)).rolling(wind.speed)
                Text(model.windUnit).font(.px(12)).opacity(0.8)
            }.position(x: r, y: r + 2)
        }
        .frame(width: 128, height: 128)
        .scaleEffect(0.8125)
    }
}

/// 예보 비교: a temperature line per source, a strip that darkens with how many sources expect rain, one line per source.
/// The main source drives the cat and the bubble; the others are here so people can see where the sources agree.
struct CompareCard: View {
    @EnvironmentObject var model: AppModel
    let cmp: WeatherScene.Compare; let updated: String; let ink: Ink
    private var wet: String { cmp.snow ? L("눈") : L("비") }
    private var unit: String { cmp.snow ? "cm" : "mm" }
    private var n: Int { cmp.sources.count }
    private var N: Int { cmp.sources.map { $0.t.count }.max() ?? 0 }
    private func hourOf(_ i: Int) -> Int { (cmp.start + i) % 24 }
    private func color(_ key: String) -> Color { key == "kma" ? Color(hex: "#2F7BEA") : key == "met" ? Color(hex: "#E8702E") : ink.ink }
    private func word(_ h: Int) -> String { HourLabel.word(h, clock12: model.clock12) }

    /// first wet slot, the window and the total for one source
    private func span(_ s: WeatherScene.Compare.Source) -> (first: Int, a: Int, b: Int, mm: Int)? {
        let idx = s.r.indices.filter { (s.r[$0] ?? 0) >= 0.1 }
        guard let f = idx.first, let l = idx.last else { return nil }
        let mm = s.r.compactMap { $0 }.reduce(0, +)
        return (f, hourOf(f), hourOf(l + 1), max(1, Int(mm.rounded())))
    }
    private var summary: String {
        let spans = cmp.sources.map(span), wetOnes = spans.compactMap { $0 }
        let all = n == 3 ? L("세 곳") : L("두 곳")
        if wetOnes.isEmpty { return L("%@ 모두 %d시간 동안 %@ 없음", all, N >= 24 ? 24 : N - 1, wet) }
        if wetOnes.count == n {
            let a = wetOnes.map { $0.first }.min()!, b = wetOnes.map { $0.first }.max()!
            let start = b - a <= 1 ? L("%@쯤 시작", word(hourOf(a))) : L("%@ 사이 시작", HourLabel.window(hourOf(a), hourOf(b), clock12: model.clock12))
            return L("%@ 모두 %@ 예보 · %@", all, wet, start)
        }
        let names = zip(cmp.sources, spans).filter { $0.1 != nil }.map { $0.0.name }.joined(separator: " · ")
        return L("%@만 %@ 예보 · 나머지는 %@ 없음", names, wet, wet)
    }

    var body: some View {
        let all = cmp.sources.flatMap { $0.t.compactMap { $0 } }
        let lo = Double((all.min() ?? 0) - 1), hi = Double((all.max() ?? 1) + 1)
        let hiLab = Int(floor(hi - 1)), loLab = Int(ceil(lo + 1))
        Card(ink: ink) {
            HStack(alignment: .firstTextBaseline) { Text(L("예보 비교")).font(.px(13)); Spacer(); Text(L("%d곳", n)).font(.ui(11)).foregroundStyle(ink.sub) }
            Text(summary).font(.px(14)).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            // temperature lines
            ZStack(alignment: .topTrailing) {
                Canvas { ctx, size in
                    let w = size.width - 4
                    func X(_ i: Int) -> CGFloat { 2 + CGFloat(i) * w / CGFloat(max(1, N - 1)) }
                    func Y(_ v: Double) -> CGFloat { 8 + (hi - v) / (hi - lo) * 70 }
                    for v in [Double(loLab), Double(hiLab)] {
                        var g = Path(); g.move(to: CGPoint(x: 0, y: Y(v))); g.addLine(to: CGPoint(x: size.width, y: Y(v)))
                        ctx.stroke(g, with: .color(ink.line), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                    for s in cmp.sources {
                        var p = Path(); var pen = false
                        for (i, v) in s.t.enumerated() {
                            guard let v else { pen = false; continue }
                            let pt = CGPoint(x: X(i), y: Y(Double(v)))
                            if pen { p.addLine(to: pt) } else { p.move(to: pt); pen = true }
                        }
                        ctx.stroke(p, with: .color(color(s.key).opacity(s.main ? 1 : 0.9)), style: StrokeStyle(lineWidth: s.main ? 2.6 : 1.8, lineCap: .round, lineJoin: .round))
                    }
                }
                VStack(alignment: .trailing, spacing: 0) {
                    Text(model.deg(hiLab)).font(.px(10)).foregroundStyle(ink.sub).offset(y: 8 + (hi - Double(hiLab)) / (hi - lo) * 70 - 12)
                    Spacer()
                    Text(model.deg(loLab)).font(.px(10)).foregroundStyle(ink.sub).offset(y: 8 + (hi - Double(loLab)) / (hi - lo) * 70 - 92 + 12)
                }
            }
            .frame(height: 92)
            // agreement strip + ticks
            VStack(spacing: 5) {
                HStack(spacing: 2) {
                    ForEach(0..<max(1, N), id: \.self) { i in
                        let k = cmp.sources.filter { i < $0.r.count && ($0.r[i] ?? 0) >= 0.1 }.count
                        RoundedRectangle(cornerRadius: 2).fill(k > 0 ? ink.blue.opacity(0.25 + 0.75 * Double(k) / Double(n)) : ink.track)
                    }
                }.frame(height: 14)
                GeometryReader { g in
                    let ticks = [0, Int((Double(N - 1) / 4).rounded()), Int((Double(N - 1) / 2).rounded()), Int((Double(N - 1) * 3 / 4).rounded()), N - 1]
                    ForEach(Array(ticks.enumerated()), id: \.offset) { j, i in
                        Text(i == 0 ? L("지금") : word(hourOf(i))).font(.px(10)).foregroundStyle(ink.sub).fixedSize()
                            .alignmentGuide(.leading) { d in d.width * (j == 0 ? 0.25 : j == 4 ? 0.75 : 0.5) - (CGFloat(i) + 0.5) / CGFloat(max(1, N)) * g.size.width }
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.frame(height: 11)
            }
            // one line per source
            VStack(spacing: 0) {
                ForEach(Array(cmp.sources.enumerated()), id: \.offset) { i, s in
                    let sp = span(s)
                    let hiT = s.t.compactMap { $0 }.max() ?? 0, loT = s.t.compactMap { $0 }.min() ?? 0
                    HStack(spacing: 8) {
                        Circle().fill(color(s.key)).frame(width: 10, height: 10)
                        Text(s.name).font(.px(13)).frame(width: 96, alignment: .leading).lineLimit(1).minimumScaleFactor(0.8)
                        Text(sp.map { "\(HourLabel.window($0.a, $0.b, clock12: model.clock12)) \(wet) · \($0.mm)\(unit)" } ?? L("%@ 없음", wet))
                            .font(.px(12)).foregroundStyle(sp == nil ? ink.sub : ink.blue).frame(maxWidth: .infinity, alignment: .leading).lineLimit(1).minimumScaleFactor(0.8)
                        Text("\(model.deg(hiT)) / \(model.deg(loT))").font(.px(12)).foregroundStyle(ink.sub)
                    }
                    .padding(.vertical, 9)
                    if i < n - 1 { Rectangle().fill(ink.line).frame(height: 1) }
                }
            }
            Text(L("%@ 기준 · %@", updated, cmp.sources.map { $0.key == "met" ? "MET Norway(CC BY 4.0)" : $0.name }.joined(separator: " · ")))
                .font(.ui(10)).foregroundStyle(ink.sub).lineSpacing(2)
        }
    }
}

/// The Plus card at the end of the free home screen: what Plus adds, the prices, one button.
struct PlusPromoCard: View {
    @EnvironmentObject var purchases: Purchases
    let ink: Ink; let action: () -> Void
    private var lines: [String] {
        [(Features.adsInFree ? L("광고 제거") : L("말투 고르기")) + " · " + L("캐릭터 바꾸기"),
         L("새 예보마다 업데이트") + " · " + L("가까운 비"),
         L("애플워치") + " · " + L("지역 여러 곳")]
    }
    var body: some View {
        Button { Haptic.soft(); action() } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) { PixelIcon(name: "sparkle", size: 20); Text(L("그르릉날씨 Plus")).font(.px(15)) }
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(lines, id: \.self) { Text("· " + $0).font(.ui(12)).lineSpacing(2) }
                }
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(L("월 %@", purchases.price(Purchases.monthly) ?? "–")).font(.px(13))
                        if let y = purchases.price(Purchases.yearly) {
                            Text(purchases.yearlySaving().map { L("연 %@ · %d%% 할인", y, $0) } ?? L("연 %@", y)).font(.ui(11)).foregroundStyle(ink.sub)
                        }
                    }
                    Spacer()
                    Text(L("3일 무료로 써보기")).font(.px(12)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 12).background(Color(hex: "#E8702E")).clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ink.night ? Color(hex: "#FFAA78").opacity(0.13) : Color(hex: "#FFF4E8").opacity(0.8))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(ink.night ? Color(hex: "#FFBE8C").opacity(0.28) : Color.white.opacity(0.85), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color(hex: "#1E2A44").opacity(ink.night ? 0 : 0.08), radius: 9, y: 6)
        }
        .buttonStyle(.press(0.98)).accessibilityIdentifier("plus-card")
    }
}

/// Under the last card: every source used for this place, with Apple's required attribution line.
struct HomeFooter: View {
    let scene: WeatherScene; let region: String; let isSample: Bool; let ink: Ink; let sources: () -> Void
    private var lines: [String] {
        var out: [String] = []
        if isSample { out.append(L("예시 날씨예요 · 실제 날씨는 서버 연결 후")) }
        if region == "kr" { out.append(scene.next6 != nil ? L("기상청 · 기상특보 · 예보 비교 · 다음 6시간 (공공누리 제1유형)") : L("기상청 · 기상특보 · 예보 비교 (공공누리 제1유형)")) }
        out.append(L("MET Norway · 예보 비교 (CC BY 4.0, 그래프로 바꿔 씀)"))
        return out
    }
    private var usesApple: Bool { scene.src == "apple" || (scene.cmp?.sources.contains { $0.key == "apple" } ?? false) }
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                if usesApple {
                    // Apple's attribution: the Apple Weather mark, linking to their legal page
                    Link(destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!) {
                        HStack(spacing: 3) { Image(systemName: "apple.logo").font(.system(size: 10)); Text("Weather").font(.ui(10, .semibold)) }
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(ink.sub, lineWidth: 1))
                    }
                }
                Button { sources() } label: { Text(L("기타 데이터 출처")).underline() }.buttonStyle(.plain).accessibilityIdentifier("sources")
            }
            ForEach(lines, id: \.self) { Text($0) }
            Text(scene.isPlus ? L("Plus · 새 예보 나올 때마다") : L("무료 · 매일 06:00에 받아요")).opacity(0.8)
        }
        .font(.ui(10)).lineSpacing(2).foregroundStyle(ink.sub)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4).padding(.top, 8)
    }
}

/// Scrolled state: a frosted band under the status bar with the place and "17° 맑음".
struct CompactHeader: View {
    let place: String; let text: String; let level: Int; let ink: Ink; let shown: Bool
    var body: some View {
        HStack {
            Text(place).font(.px(15)); Spacer(); Text(text).font(.px(15))
        }
        .lineLimit(1)
        .padding(.horizontal, 22).padding(.bottom, 14).padding(.top, 8)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .background(ink.night ? Color(hex: "#141A38").opacity(0.82) : Color(hex: Rules.background[level]).opacity(0.85))
        .overlay(alignment: .bottom) { Rectangle().fill(ink.line).frame(height: 1) }
        .foregroundStyle(ink.ink)
        .opacity(shown ? 1 : 0)
        .animation(.easeOut(duration: 0.18), value: shown)
        .allowsHitTesting(false)
    }
}

/// How far the home scroll view has moved (for the compact header).
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
