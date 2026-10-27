import SwiftUI

/// Tapping a day in the 10-day list, as on the prototype's AppDay screen: a 10-day strip, metric tabs
/// (기온 · 비 · 바람 · 자외선 · 습도), the character dressed for the selected hour beside a summary bubble,
/// one chart per tab with a marker at the selected hour (press or drag across it to read any hour),
/// and a plain-language scale underneath. Everything comes from the stored forecast (`dayDetail`,
/// 8 three-hourly values per day, interpolated to 24 hours); without it only the summary line is shown.
struct DayDetailView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State var start: Int
    @State private var metric: DayMetric = .temp
    @State private var picked: Int?          // hour chosen on the chart; nil → now (today) or noon
    @State private var scrubbing = false
    @Namespace private var ns

    var body: some View {
        let s = model.scene
        if s.days.isEmpty {
            VStack(spacing: 12) {
                Text(L("이 날의 예보가 아직 없어요")).font(.px(16))
                Button(L("닫기")) { dismiss() }.tint(UI.accent)
            }.frame(maxWidth: .infinity, maxHeight: .infinity).background(UI.bg)
        } else {
            sheet(s, index: max(0, min(start, s.days.count - 1)))
        }
    }

    // MARK: sheet

    private func sheet(_ s: WeatherScene, index: Int) -> some View {
        let hourly = DayHourly.make(scene: s, index: index)
        let ink = Ink(night: s.isNight)
        let sel = picked ?? (index == 0 ? (hourly?.now ?? 12) : 12)
        let ctx = DayCtx(scene: s, index: index, day: s.days[index], hourly: hourly, ink: ink, night: s.isNight, sel: sel, metric: metric, scrub: scrubbing)
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                Capsule().fill(Color(red: 127 / 255, green: 135 / 255, blue: 160 / 255).opacity(0.45)).frame(width: 36, height: 5)
                titleRow(ctx)
                strip(ctx)
                tabs(ctx)
                if index == 0, let a = s.alert { alertLine(a, ctx) }
                brief(ctx)
                if hourly != nil {
                    chartCard(ctx).reveal(1)
                    if !scaleItems(ctx).items.isEmpty { scaleCard(ctx).reveal(2) }
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 40)
        }
        .background(sheetBackground(s, ink).ignoresSafeArea())
        .foregroundStyle(ink.ink)
        .onChange(of: start) { _, _ in picked = nil }
    }

    private func sheetBackground(_ s: WeatherScene, _ ink: Ink) -> some View {
        let top = s.isNight ? Color(hex: "#1A2046") : Color(hex: Rules.background[max(0, min(9, s.level))])
        let bottom = s.isNight ? Color(hex: "#0D1126") : Color(hex: "#EEF1F7")
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: s.isNight ? 1 : 0.5))
    }

    // MARK: title · strip · tabs · alert

    private func titleRow(_ c: DayCtx) -> some View {
        ZStack {
            Text(title(c)).font(.px(17))
            HStack {
                Spacer()
                Button { Haptic.soft(); dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(c.ink.ink)
                        .frame(width: 36, height: 36)
                        .background(c.night ? Color.white.opacity(0.12) : Color.white.opacity(0.7)).clipShape(Circle())
                }
                .buttonStyle(.press(0.94)).accessibilityIdentifier("sheet-close").accessibilityLabel(L("닫기"))
            }
        }
        .frame(height: 36)
    }

    private func title(_ c: DayCtx) -> String {
        let date = Calendar.current.date(byAdding: .day, value: c.index, to: Date()) ?? Date()
        let f = DateFormatter(); f.locale = Lang.current.locale; f.dateFormat = L("M월 d일 EEEE")
        let lead = c.index == 0 ? L("오늘") + " · " : (c.index == 1 ? L("내일") + " · " : "")
        return lead + f.string(from: date)
    }

    private func dayNumber(_ i: Int) -> String {
        String(Calendar.current.component(.day, from: Calendar.current.date(byAdding: .day, value: i, to: Date()) ?? Date()))
    }

    private func strip(_ c: DayCtx) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(c.scene.days.enumerated()), id: \.offset) { i, d in
                        stripTile(c, i: i, d: d).id(i)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 2)
            }
            .padding(.horizontal, -16)
            .onAppear { proxy.scrollTo(c.index, anchor: .center) }
            .onChange(of: c.index) { _, i in withAnimation(Motion.gentle) { proxy.scrollTo(i, anchor: .center) } }
        }
    }

    private func stripTile(_ c: DayCtx, i: Int, d: WeatherScene.DayRow) -> some View {
        let on = i == c.index
        let fg = on ? c.inv : c.ink.ink
        return Button { Haptic.select(); withAnimation(Motion.snappy) { start = i } } label: {
            VStack(spacing: 5) {
                Text(i == 0 ? L("오늘") : d.name).font(.ui(11, .medium))
                    .foregroundStyle(on ? c.inv : (i == 0 ? c.ink.blue : c.ink.sub))
                PixelIcon(name: d.icon, size: 28)
                    .frame(width: 40, height: 40)
                    .background(c.night ? Color.white.opacity(0.1) : Color.white.opacity(0.75))
                    .clipShape(DayNotch(n: 3))
                Text(dayNumber(i)).font(.px(13)).foregroundStyle(fg)
                Text("\(model.deg(d.hi))/\(model.deg(d.lo))").font(.px(10)).foregroundStyle(fg.opacity(0.8))
            }
            .frame(width: 52).padding(.top, 7).padding(.bottom, 8)
            .background {
                if on { DayNotch(n: 4).fill(c.ink.ink).matchedGeometryEffect(id: "day", in: ns) }
            }
        }
        .buttonStyle(.press(0.95))
    }

    private func tabs(_ c: DayCtx) -> some View {
        let items: [(DayMetric, String, String)] = [
            (.temp, L("기온"), "thermo_hot"), (.rain, c.snowy ? L("눈") : L("비"), c.snowy ? "snowflake" : "umbrella"),
            (.wind, L("바람"), "wind"), (.uv, L("자외선"), "sun_strong"), (.humidity, L("습도"), "sweat"),
        ]
        return HStack(spacing: 6) {
            ForEach(items, id: \.0) { item in
                let m = item.0
                let on = m == metric || (m == .temp && metric == .feels)
                Button { Haptic.select(); withAnimation(Motion.snappy) { metric = m } } label: {
                    VStack(spacing: 5) { PixelIcon(name: item.2, size: 18); Text(item.1).font(.ui(11, .medium)) }
                        .foregroundStyle(on ? c.inv : c.ink.sub)
                        .frame(maxWidth: .infinity).padding(.top, 8).padding(.bottom, 7)
                        .background {
                            if on { DayNotch(n: 3).fill(c.ink.ink).matchedGeometryEffect(id: "metric", in: ns) }
                            else { Rectangle().stroke(c.ink.line, lineWidth: 2) }
                        }
                }
                .buttonStyle(.press(0.95))
            }
        }
    }

    private func alertLine(_ a: WeatherScene.Alert, _ c: DayCtx) -> some View {
        let n = a.name
        let icon = n.contains("호우") ? "umbrella" : n.contains("폭염") ? "thermo_hot" : n.contains("한파") ? "thermo_cold"
            : n.contains("대설") ? "snowflake" : n.contains("황사") || n.contains("미세") ? "mask" : n.contains("강풍") ? "wind" : "exclaim"
        return HStack(spacing: 8) {
            PixelIcon(name: icon, size: 18)
            Text(a.note.isEmpty ? n : "\(n) · \(a.note)").font(.ui(12)).lineSpacing(3).foregroundStyle(c.ink.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(c.night ? Color(red: 1, green: 170 / 255, blue: 120 / 255).opacity(0.14) : Color(red: 1, green: 240 / 255, blue: 228 / 255).opacity(0.9))
        .overlay(Rectangle().stroke(c.night ? Color(hex: "#FFB08A") : Color(hex: "#E8702E"), lineWidth: 2))
        .padding(.trailing, 3)
    }

    // MARK: character + bubble

    private func brief(_ c: DayCtx) -> some View {
        let feel = c.hourly?.feel[c.sel] ?? Double(c.day.hi + c.day.lo) / 2
        let chance = c.hourly?.chance[c.sel] ?? Double(c.day.chance)
        let rain: RainState = chance >= 50 ? .umbrella : (c.day.chance >= 30 ? .bag : .none)
        let b = briefText(c)
        return HStack(alignment: .bottom, spacing: 4) {
            CharacterSprite(character: model.shownCharacter, level: Rules.level(feels: feel), rain: rain, width: 62)
                .frame(width: 64, height: 74, alignment: .bottom).clipped()
                .reveal(0, rise: 10)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(b.value).font(.px(20)).rolling(b.value)
                    if !b.badge.isEmpty {
                        Text(b.badge).font(.px(11)).foregroundStyle(b.badgeInk)
                            .padding(.horizontal, 6).padding(.vertical, 4).background(b.badgeColor)
                    }
                }
                Text(model.say(b.summary)).font(.ui(14.5)).lineSpacing(6).foregroundStyle(c.ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 12).padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dayBox(fill: c.bubble, border: c.ink.ink, shadow: c.shadow)
            .overlay(alignment: .bottomLeading) { DayTail(outline: c.ink.ink, fill: c.bubble).frame(width: 10, height: 14).offset(x: -8, y: -16) }
            .padding(.trailing, 3)
        }
    }

    // MARK: chart card

    private func chartCard(_ c: DayCtx) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if metric == .wind { windsock(c) }
            chartHeader(c)
            GeometryReader { g in
                let cw = max(1, (g.size.width - 36) / 24)
                VStack(alignment: .leading, spacing: 10) {
                    if metric == .wind { arrowsRow(c, cw: cw) } else { iconsRow(c, cw: cw) }
                    DayChart(ctx: c, spec: spec(c), cw: cw, scrub: scrubView(c), onScrub: { h, on in
                        if on, h != picked { Haptic.select() }
                        picked = h; scrubbing = on
                    })
                    .frame(height: 140)
                    xLabels(c, cw: cw)
                    bands(c, cw: cw)
                }
            }
            .frame(height: chartBlockHeight)
            if metric == .uv { UVBar(uv: Int((c.hourly?.uv.max() ?? 0).rounded()), ink: c.ink) }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 14))
        .background(c.ink.card)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(c.ink.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color(hex: "#1E2A44").opacity(c.night ? 0.22 : 0.08), radius: 9, y: 6)
        .animation(Motion.gentle, value: metric)
    }

    /// icons/arrows row + chart + x labels (+ the umbrella band on the rain tab), with the 10 pt gaps
    private var chartBlockHeight: CGFloat {
        (metric == .wind ? 18 : 22) + 10 + 140 + 10 + 12 + (metric == .rain ? 18 : 0)
    }

    private func chartHeader(_ c: DayCtx) -> some View {
        HStack {
            Text(chartTitle(c)).font(.px(13))
            Spacer()
            if metric == .temp || metric == .feels {
                HStack(spacing: 4) { chip(L("실제"), on: metric == .temp, c) { metric = .temp }; chip(L("체감"), on: metric == .feels, c) { metric = .feels } }
            } else if !legend(c).isEmpty {
                HStack(spacing: 12) {
                    ForEach(Array(legend(c).enumerated()), id: \.offset) { _, l in
                        HStack(spacing: 5) { l.swatch; Text(l.text).font(.ui(11)).foregroundStyle(c.ink.sub) }
                    }
                }
            }
        }
    }

    private func chip(_ t: String, on: Bool, _ c: DayCtx, action: @escaping () -> Void) -> some View {
        Button { Haptic.select(); withAnimation(Motion.snappy, action) } label: {
            Text(t).font(.ui(11, .medium)).foregroundStyle(on ? c.inv : c.ink.sub)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background { if on { Rectangle().fill(c.ink.ink) } else { Rectangle().stroke(c.ink.line, lineWidth: 2) } }
        }.buttonStyle(.plain)
    }

    private func chartTitle(_ c: DayCtx) -> String {
        switch metric {
        case .temp: return L("기온")
        case .feels: return L("체감온도")
        case .rain: return c.snowy ? L("눈 올 확률") : L("비 올 확률")
        case .wind: return L("시간별 바람 (%@)", model.windUnit)
        case .uv: return L("시간별 자외선 지수")
        case .humidity: return L("시간별 습도")
        }
    }

    private struct LegendItem { let text: String; let swatch: AnyView }
    private func legend(_ c: DayCtx) -> [LegendItem] {
        switch metric {
        case .rain:
            return [LegendItem(text: L("확률"), swatch: AnyView(Rectangle().fill(c.ink.blue).frame(width: 14, height: 3)))]
        case .wind:
            let wc = c.windColor
            return [LegendItem(text: L("풍속"), swatch: AnyView(Rectangle().fill(wc).frame(width: 14, height: 3))),
                    LegendItem(text: L("돌풍"), swatch: AnyView(DayDots(color: c.gustColor).frame(width: 14, height: 3)))]
        default: return []
        }
    }

    private func iconsRow(_ c: DayCtx, cw: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<12, id: \.self) { k in
                PixelIcon(name: c.hourly?.icon(k * 2 + 1) ?? "cloud", size: 18)
                    .opacity(c.sel / 2 == k ? 1 : 0.7)
                    .offset(x: CGFloat(k) * cw * 2 + cw - 9, y: 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading).frame(height: 22)
    }

    private func arrowsRow(_ c: DayCtx, cw: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<12, id: \.self) { k in
                DayArrow(deg: c.windDeg, color: c.ink.ink).frame(width: 14, height: 14)
                    .opacity(c.sel / 2 == k ? 1 : 0.7)
                    .offset(x: CGFloat(k) * cw * 2 + cw - 7, y: 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading).frame(height: 18)
    }

    private func xLabels(_ c: DayCtx, cw: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach([0, 6, 12, 18], id: \.self) { h in
                Text(HourLabel.word(h, clock12: model.clock12)).font(.ui(11)).foregroundStyle(c.ink.sub).fixedSize()
                    .offset(x: CGFloat(h) * cw)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading).frame(height: 12)
    }

    /// 우산 band: the hours with a 50 %+ chance, merged into runs
    @ViewBuilder private func bands(_ c: DayCtx, cw: CGFloat) -> some View {
        if metric == .rain, let h = c.hourly {
            HStack(spacing: 8) {
                Text(L("우산")).font(.ui(11)).foregroundStyle(c.ink.sub).frame(width: 28, alignment: .leading)
                ZStack(alignment: .leading) {
                    ForEach(runs(h.chance.map { $0 >= 50 }), id: \.0) { r in
                        Rectangle().fill(c.ink.blue).frame(width: CGFloat(r.1 - r.0) * cw - 2, height: 8).offset(x: CGFloat(r.0) * cw)
                    }
                }
                .frame(width: cw * 24, height: 8, alignment: .leading)
            }
            .frame(height: 8)
        }
    }

    private func runs(_ on: [Bool]) -> [(Int, Int)] {
        var out: [(Int, Int)] = []; var start = 0
        for k in 1...on.count where k == on.count || on[k] != on[start] {
            if on[start] { out.append((start, k)) }
            start = k
        }
        return out
    }

    // MARK: windsock

    private func windsock(_ c: DayCtx) -> some View {
        let w = c.hourly?.wind[c.sel] ?? Double(c.scene.wind.speed)
        let stripes = w < 2 ? 1 : w < 4 ? 2 : w < 8 ? 3 : 4
        let droop: CGFloat = w < 2 ? 9 : w < 4 ? 6 : w < 8 ? 3 : 0
        let pole = c.night ? Color(hex: "#C9D0F0") : Color(hex: "#22203A")
        let d16 = WindCard.dirs
        let from = L(d16[Int((Double(c.windDeg) / 22.5).rounded()) % 16]), to = L(d16[Int((Double((c.windDeg + 180) % 360) / 22.5).rounded()) % 16])
        return HStack(alignment: .bottom, spacing: 14) {
            ZStack(alignment: .topLeading) {
                Rectangle().fill(pole).frame(width: 4, height: 64).offset(x: 8, y: 6)
                Rectangle().fill(pole).frame(width: 8, height: 6).offset(x: 6, y: 2)
                ForEach(0..<stripes, id: \.self) { k in
                    Rectangle().fill(k % 2 == 1 ? Color.white : Color(hex: "#E8702E"))
                        .frame(width: 24, height: CGFloat(20 - k * 3))
                        .overlay(DayStripeBorder(color: c.night ? Color(hex: "#F3F5FF") : Color(hex: "#22203A")))
                        .offset(x: CGFloat(12 + k * 24), y: 8 + CGFloat(k) * droop + CGFloat(k) * 1.5)
                        .animation(Motion.gentle, value: droop)
                }
            }
            .frame(width: 112, height: 70, alignment: .topLeading)
            VStack(alignment: .leading, spacing: 7) {
                Text("\(timeWord(c)) \(model.windText(Int(w.rounded())))").font(.px(13)).rolling(Int(w.rounded()))
                HStack(spacing: 6) {
                    DayArrow(deg: c.windDeg, color: c.ink.ink).frame(width: 14, height: 14)
                    Text(L("%@풍 · %@쪽으로 불어요", from, to)).font(.ui(11)).foregroundStyle(c.ink.sub)
                }
            }
            .padding(.bottom, 4)
        }
        .padding(.bottom, 4)
    }

    // MARK: scale card

    private struct ScaleItem { let title: String; let sub: String; let big: Bool }
    private func scaleItems(_ c: DayCtx) -> (title: String, items: [ScaleItem], cur: Int) {
        guard let h = c.hourly else { return ("", [], 0) }
        switch metric {
        case .temp:
            let parts = [L("새벽"), L("아침"), L("낮"), L("밤")]
            let items = parts.enumerated().map { i, p in
                ScaleItem(title: p, sub: model.deg(Int((h.temp[(i * 6)..<(i * 6 + 6)].reduce(0, +) / 6).rounded())), big: true)
            }
            return (L("시간대별 %@", L("기온")), items, c.sel / 6)
        case .feels:
            let v = Int(h.feel[c.sel].rounded())
            let cur = v <= 0 ? 0 : v <= 8 ? 1 : v <= 16 ? 2 : v <= 22 ? 3 : v <= 27 ? 4 : 5
            let items = [ScaleItem(title: L("추움"), sub: L("%@ 이하", model.deg(0)), big: false), ScaleItem(title: L("쌀쌀"), sub: degRange(1, 8), big: false),
                         ScaleItem(title: L("선선"), sub: degRange(9, 16), big: false), ScaleItem(title: L("쾌적"), sub: degRange(17, 22), big: false),
                         ScaleItem(title: L("따뜻"), sub: degRange(23, 27), big: false), ScaleItem(title: L("더움"), sub: model.deg(28) + "+", big: false)]
            return (L("체감 단계"), items, cur)
        case .wind:
            let wmax = Int((h.wind.max() ?? 0).rounded())
            let cur = wmax < 4 ? 0 : wmax < 8 ? 1 : wmax < 14 ? 2 : 3
            let items = [ScaleItem(title: L("약함"), sub: windRange(0, 3), big: false), ScaleItem(title: L("보통"), sub: windRange(4, 7), big: false),
                         ScaleItem(title: L("강함"), sub: windRange(8, 13), big: false), ScaleItem(title: L("매우 강함"), sub: model.windNumber(14) + "+", big: false)]
            return (L("바람 단계"), items, cur)
        case .uv:
            let m = Int((h.uv.max() ?? 0).rounded())
            let cur = m >= 8 ? 3 : m >= 6 ? 2 : m >= 3 ? 1 : 0
            let items = [ScaleItem(title: L("약함"), sub: "0~2", big: false), ScaleItem(title: L("보통"), sub: "3~5", big: false),
                         ScaleItem(title: L("강함"), sub: "6~7", big: false), ScaleItem(title: L("매우 강함"), sub: "8+", big: false)]
            return (L("자외선 대비"), items, cur)
        case .humidity:
            let items = [ScaleItem(title: L("건조"), sub: "<30%", big: false), ScaleItem(title: L("보송"), sub: "<60%", big: false),
                         ScaleItem(title: L("적당"), sub: "60~70%", big: false), ScaleItem(title: L("습함"), sub: "70%+", big: false),
                         ScaleItem(title: L("끈적"), sub: L("이슬점 %@+", model.deg(21)), big: false)]
            return (L("체감 습도"), items, humidityLevel(h).k)
        case .rain:
            return ("", [], 0)
        }
    }

    private func scaleCard(_ c: DayCtx) -> some View {
        let sc = scaleItems(c)
        return VStack(alignment: .leading, spacing: 10) {
            Text(sc.title).font(.px(13))
            HStack(spacing: 6) {
                ForEach(Array(sc.items.enumerated()), id: \.offset) { i, it in
                    let on = i == sc.cur
                    VStack(spacing: 5) {
                        Text(it.title).font(.ui(12, .medium)).lineLimit(1).minimumScaleFactor(0.7)
                        Text(it.sub).font(it.big ? Font.px(16) : Font.ui(10)).opacity(it.big ? 1 : 0.85).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(on ? c.inv : c.ink.sub)
                    .frame(maxWidth: .infinity).padding(.vertical, 9).padding(.horizontal, 4)
                    .background { if on { DayNotch(n: 3).fill(c.ink.ink) } else { Rectangle().stroke(c.ink.line, lineWidth: 2) } }
                    .animation(Motion.snappy, value: sc.cur)
                }
            }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(c.ink.card)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(c.ink.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color(hex: "#1E2A44").opacity(c.night ? 0.22 : 0.08), radius: 9, y: 6)
    }

    // MARK: chart spec per tab

    private func spec(_ c: DayCtx) -> DayChartSpec {
        guard let h = c.hourly else { return DayChartSpec(vals: Array(repeating: 0, count: 24), ymin: 0, ymax: 1) }
        var s = DayChartSpec(vals: h.temp, ymin: 0, ymax: 1)
        /// the value between two neighbouring hours, for the colour of the curve segment that joins them
        func mid(_ v: [Double], _ i: Int) -> Double { (v[max(0, min(23, i - 1))] + v[max(0, min(23, i))]) / 2 }
        switch metric {
        case .temp, .feels:
            let vals = metric == .feels ? h.feel : h.temp
            let vmin = vals.min() ?? 0, vmax = vals.max() ?? 1
            let ymin = floor((vmin - 2) / 5) * 5, ymax = max(ymin + 15, ceil((vmax + 4) / 5) * 5)
            s.vals = vals; s.ymin = ymin; s.ymax = ymax
            var grid: [(Double, String)] = []
            var y = ymin
            while y <= ymax { grid.append(((y - ymin) / (ymax - ymin), model.deg(Int(y)))); y += 5 }
            s.grid = grid
            s.segColors = (0..<25).map { i in DayTempColor.color(mid(vals, i)) }
            s.areaStops = vals.enumerated().map { i, v in Gradient.Stop(color: DayTempColor.color(v), location: (Double(i) + 0.5) / 24) }
            s.areaHorizontal = true; s.areaOpacity = c.night ? 0.38 : 0.45
            s.showHiLo = true; s.showSel = true
        case .rain:
            s.vals = h.chance; s.ymin = 0; s.ymax = 100
            s.grid = [(0, "0%"), (0.5, "50%"), (1, "100%")]
            s.segColors = Array(repeating: c.ink.blue, count: 25)
        case .wind:
            let gmax = h.gust.max() ?? 1
            let step: Double = gmax > 22 ? 8 : 4
            let ymax = max(step, ceil((gmax + 1) / step) * step)
            s.vals = h.wind; s.line2 = h.gust; s.ymin = 0; s.ymax = ymax
            var grid: [(Double, String)] = []
            var y = 0.0
            while y <= ymax { grid.append((y / ymax, model.windNumber(Int(y)))); y += step }
            s.grid = grid
            s.segColors = Array(repeating: c.windColor, count: 25)
            s.areaStops = [Gradient.Stop(color: c.windColor, location: 0), Gradient.Stop(color: .clear, location: 1)]
            s.areaOpacity = c.night ? 0.42 : 0.35
            s.line2Color = c.gustColor
        case .uv:
            let vals = h.uv
            s.vals = vals; s.ymin = 0; s.ymax = 12
            s.grid = [0, 3, 6, 8, 11].map { (Double($0) / 12, String($0)) }
            s.segColors = (0..<25).map { i in Color(hex: UVScale.band(Int(mid(vals, i).rounded())).color) }
            let top = Color(hex: UVScale.band(Int((h.uv.max() ?? 0).rounded())).color)
            s.areaStops = [Gradient.Stop(color: top, location: 0), Gradient.Stop(color: .clear, location: 1)]
            s.areaOpacity = 0.35
        case .humidity:
            s.vals = h.rh; s.ymin = 0; s.ymax = 100
            s.grid = [(0, "0%"), (0.5, "50%"), (1, "100%")]
            s.segColors = Array(repeating: c.humColor, count: 25)
            s.areaStops = [Gradient.Stop(color: c.humColor, location: 0), Gradient.Stop(color: .clear, location: 1)]
            s.areaOpacity = 0.32
        }
        s.hiText = L("최고 %@", model.deg(Int((s.vals.max() ?? 0).rounded())))
        s.loText = L("최저 %@", model.deg(Int((s.vals.min() ?? 0).rounded())))
        s.selText = "\(timeWord(c)) \(model.deg(Int(s.vals[c.sel].rounded())))"
        return s
    }

    /// The translucent readout above the chart while the finger is on it: only the key value for that hour.
    private func scrubView(_ c: DayCtx) -> DayScrub {
        guard let h = c.hourly else { return DayScrub(time: "", icon: nil, arrow: false, main: "", sub: "", subColor: nil, subInk: nil) }
        let t = timeWord(c)
        switch metric {
        case .temp:
            return DayScrub(time: t, icon: h.icon(c.sel), arrow: false, main: model.deg(Int(h.temp[c.sel].rounded())), sub: L("체감 %@", model.deg(Int(h.feel[c.sel].rounded()))), subColor: nil, subInk: nil)
        case .feels:
            return DayScrub(time: t, icon: h.icon(c.sel), arrow: false, main: L("체감 %@", model.deg(Int(h.feel[c.sel].rounded()))), sub: L("실제 %@", model.deg(Int(h.temp[c.sel].rounded()))), subColor: nil, subInk: nil)
        case .rain:
            let p = Int(h.chance[c.sel].rounded())
            return DayScrub(time: t, icon: p >= 50 ? "umbrella" : "raindrop", arrow: false, main: "\(p)%", sub: c.snowy ? L("눈 올 확률") : L("비 올 확률"), subColor: nil, subInk: nil)
        case .wind:
            let d = L("%@풍", L(WindCard.dirs[Int((Double(c.windDeg) / 22.5).rounded()) % 16]))
            return DayScrub(time: t, icon: nil, arrow: true, main: model.windText(Int(h.wind[c.sel].rounded())), sub: d, subColor: nil, subInk: nil)
        case .uv:
            let v = Int(h.uv[c.sel].rounded()), b = UVScale.band(v)
            return DayScrub(time: t, icon: "sun_strong", arrow: false, main: String(v), sub: L(b.word), subColor: Color(hex: b.color), subInk: Color(hex: b.onColor))
        case .humidity:
            return DayScrub(time: t, icon: "sweat", arrow: false, main: "\(Int(h.rh[c.sel].rounded()))%", sub: L("이슬점 %@", model.deg(h.dew(c.sel))), subColor: nil, subInk: nil)
        }
    }

    // MARK: words

    /// "지금" for the current hour today, otherwise the hour in the clock setting
    private func timeWord(_ c: DayCtx) -> String {
        c.index == 0 && c.hourly?.now == c.sel ? L("지금") : HourLabel.word(c.sel, clock12: model.clock12)
    }

    private func partOfDay(_ h: Int) -> String { h < 5 ? L("밤") : h < 12 ? L("아침") : h < 17 ? L("낮") : h < 21 ? L("저녁") : L("밤") }

    /// A difference in degrees in the unit setting (°F swings are 1.8× the °C ones)
    private func dd(_ v: Int) -> Int { model.unitF ? Int((Double(abs(v)) * 1.8).rounded()) : abs(v) }
    private func degNumber(_ v: Int) -> String { String(model.deg(v).dropLast()) }
    private func degRange(_ a: Int, _ b: Int) -> String { "\(degNumber(a))~\(model.deg(b))" }
    private func windRange(_ a: Int, _ b: Int) -> String { "\(model.windNumber(a))~\(model.windNumber(b))" }

    private struct Brief { var value: String; var badge: String; var badgeColor: Color; var badgeInk: Color; var summary: String }

    private func briefText(_ c: DayCtx) -> Brief {
        guard let h = c.hourly else { return briefNoDetail(c) }
        switch metric {
        case .temp: return briefTemp(c, h)
        case .feels: return briefFeels(c, h)
        case .rain: return briefRain(c, h)
        case .wind: return briefWind(c, h)
        case .uv: return briefUV(c, h)
        case .humidity: return briefHumidity(c, h)
        }
    }

    private func briefNoDetail(_ c: DayCtx) -> Brief {
        let d = c.day
        var t = d.hi - d.lo >= 6 ? L("%@ %@, %@ %@예요. 일교차가 커서 겉옷이 필요해요.", L("아침"), model.deg(d.lo), L("낮"), model.deg(d.hi))
            : L("하루 종일 %@~%@예요.", model.deg(d.lo), model.deg(d.hi))
        if d.chance >= 60 { t += " " + (c.snowy ? L("눈 예보예요. 길이 미끄러울 수 있어요.") : L("비 예보예요. 우산을 챙겨 주세요.")) }
        else if d.chance >= 30 { t += " " + L("비 올 가능성이 %d%%예요. 우산이 있으면 좋아요.", d.chance) }
        return Brief(value: "\(model.deg(d.hi)) / \(model.deg(d.lo))", badge: L("일교차 %d°", dd(d.hi - d.lo)), badgeColor: DayTempColor.color(Double(d.hi)), badgeInk: UI.ink, summary: t)
    }

    private func briefTemp(_ c: DayCtx, _ h: DayHourly) -> Brief {
        let vmin = h.temp.min() ?? 0, vmax = h.temp.max() ?? 0
        let lo = Int(vmin.rounded()), hi = Int(vmax.rounded())
        let loH = h.temp.firstIndex(of: vmin) ?? 6, hiH = h.temp.firstIndex(of: vmax) ?? 15
        var t: String
        if hi >= 30 {
            t = L("%@에 최고 %@예요. 더우니 물을 챙겨 주세요.", partOfDay(hiH), model.deg(hi)) + (lo >= 25 ? " " + L("밤에도 %@ 이상이에요.", model.deg(lo)) : "")
        } else if hi <= 0 || lo <= -5 {
            t = L("%@ %@, %@ %@예요. 많이 추워요.", partOfDay(loH), model.deg(lo), partOfDay(hiH), model.deg(hi))
        } else if hi - lo >= 6 {
            t = L("%@ %@, %@ %@예요. 일교차가 커서 겉옷이 필요해요.", partOfDay(loH), model.deg(lo), partOfDay(hiH), model.deg(hi))
        } else {
            t = L("하루 종일 %@~%@예요.", model.deg(lo), model.deg(hi))
        }
        if c.index > 0 {
            let dh = c.day.hi - c.scene.days[c.index - 1].hi
            t += " " + (dh > 0 ? L("전날보다 최고기온이 %d° 높아요.", dd(dh)) : dh < 0 ? L("전날보다 최고기온이 %d° 낮아요.", dd(dh)) : L("최고기온은 전날과 같아요."))
        } else if let now = h.now {
            t += " " + L("지금은 %@예요.", model.deg(Int(h.temp[now].rounded())))
        }
        return Brief(value: "\(model.deg(hi)) / \(model.deg(lo))", badge: L("일교차 %d°", dd(hi - lo)), badgeColor: DayTempColor.color(vmax), badgeInk: UI.ink, summary: t)
    }

    private func briefFeels(_ c: DayCtx, _ h: DayHourly) -> Brief {
        let vmin = h.feel.min() ?? 0, vmax = h.feel.max() ?? 0
        let lo = Int(vmin.rounded()), hi = Int(vmax.rounded())
        let gap = Int((zip(h.temp, h.feel).reduce(0) { $0 + $1.0 - $1.1 } / 24).rounded())
        let badge = gap > 0 ? L("실제보다 -%d°", dd(gap)) : gap < 0 ? L("실제보다 +%d°", dd(gap)) : L("실제와 비슷")
        let mid = (lo + hi) / 2
        let word = mid <= -10 ? L("매우 추운") : mid <= 0 ? L("추운") : mid <= 8 ? L("쌀쌀한") : mid <= 16 ? L("선선한") : mid <= 22 ? L("쾌적한") : mid <= 27 ? L("따뜻한") : mid <= 32 ? L("더운") : L("매우 더운")
        var t = L("체감 %@~%@, %@ 날이에요.", degNumber(lo), model.deg(hi), word)
        let windy = (h.wind.max() ?? 0) >= 8
        if gap < 0 { t += " " + L("습해서 실제 기온보다 %d° 높게 느껴져요.", dd(gap)) }
        else if gap > 0 {
            t += " " + (windy ? L("바람이 세서 실제 기온보다 %d° 낮게 느껴져요.", dd(gap))
                        : h.rainy ? (c.snowy ? L("눈 때문에 실제 기온보다 %d° 낮게 느껴져요.", dd(gap)) : L("비 때문에 실제 기온보다 %d° 낮게 느껴져요.", dd(gap)))
                        : L("실제 기온보다 %d° 낮게 느껴져요.", dd(gap)))
        } else { t += " " + L("실제 기온과 비슷해요.") }
        if c.index == 0, let now = h.now { t += " " + L("지금 체감은 %@예요.", model.deg(Int(h.feel[now].rounded()))) }
        return Brief(value: "\(model.deg(hi)) / \(model.deg(lo))", badge: badge, badgeColor: DayTempColor.color(vmax), badgeInk: UI.ink, summary: t)
    }

    private func briefRain(_ c: DayCtx, _ h: DayHourly) -> Brief {
        let wet = (0..<24).filter { h.chance[$0] >= 50 }
        let p = h.dayProb
        let value = p >= 10 ? L("최대 %d%%", p) : (c.snowy ? L("눈 없음") : L("비 없음"))
        let badge = wet.isEmpty ? L("우산 없이") : L("우산 %d시간", wet.count)
        var soon = false
        if c.index == 0, let first = wet.first, let now = h.now { soon = first - now >= 0 && first - now <= 1 }
        var pods: [String] = []
        for w in wet { let s = partOfDay(w); if !pods.contains(s) { pods.append(s) } }
        let t: String
        if wet.isEmpty {
            t = p >= 30 ? (c.snowy ? L("눈 올 가능성이 %d%%예요. 우산이 있으면 좋아요.", p) : L("비 올 가능성이 %d%%예요. 우산이 있으면 좋아요.", p))
                : (c.snowy ? L("눈 소식이 없어요.") : L("비 소식이 없어요."))
        } else if c.snowy {
            t = soon ? L("곧 눈 예보예요. 길이 미끄러울 수 있어요.") : L("눈 예보예요. 길이 미끄러울 수 있어요.")
        } else if soon {
            t = L("곧 비 예보예요. 우산을 챙겨 주세요.")
        } else if wet.count >= 10 {
            t = L("하루 종일 비 예보예요. 우산을 챙겨 주세요.")
        } else if pods.count == 1 {
            t = L("%@에 비 예보예요. 우산을 챙겨 주세요.", pods[0])
        } else {
            t = L("비 예보예요. 우산을 챙겨 주세요.")
        }
        return Brief(value: value, badge: badge, badgeColor: c.ink.blue, badgeInk: c.inv, summary: t)
    }

    private func briefWind(_ c: DayCtx, _ h: DayHourly) -> Brief {
        let wmin = Int((h.wind.min() ?? 0).rounded()), wmax = Int((h.wind.max() ?? 0).rounded()), gmax = Int((h.gust.max() ?? 0).rounded())
        let lvl = wmax < 4 ? 0 : wmax < 8 ? 1 : wmax < 14 ? 2 : 3
        var t = [L("바람이 약해요."), L("바람이 조금 있어요."), L("바람이 강해요."), L("바람이 매우 강해요. 바깥 활동은 줄여 주세요.")][lvl]
        if lvl >= 1, let peak = h.wind.firstIndex(of: h.wind.max() ?? 0) { t += " " + L("%@에 가장 세요.", partOfDay(peak)) }
        return Brief(value: "\(model.windNumber(wmin))~\(model.windText(wmax))", badge: L("돌풍 %@", model.windNumber(gmax)), badgeColor: c.windColor, badgeInk: .white, summary: t)
    }

    private func briefUV(_ c: DayCtx, _ h: DayHourly) -> Brief {
        let m = Int((h.uv.max() ?? 0).rounded()), b = UVScale.band(m)
        let k = m >= 8 ? 3 : m >= 6 ? 2 : m >= 3 ? 1 : 0
        let t = [L("자외선이 약해요."), L("자외선 보통이에요. 한낮엔 선크림을 발라 주세요."), L("자외선이 강해요. 선크림과 모자를 챙겨 주세요."), L("자외선이 매우 강해요. 한낮엔 바깥 활동을 줄여 주세요.")][k]
        return Brief(value: L("최고 %@", String(m)), badge: L(b.word), badgeColor: Color(hex: b.color), badgeInk: Color(hex: b.onColor), summary: t)
    }

    private func humidityLevel(_ h: DayHourly) -> (k: Int, avg: Int, dew: Int) {
        let avg = Int((h.rh.reduce(0, +) / 24).rounded()), dew = h.dew(15)
        let k = avg < 30 ? 0 : dew >= 21 ? 4 : (dew >= 18 || avg >= 85) ? 3 : avg >= 70 ? 2 : (dew < 10 && avg < 60) ? 1 : 2
        return (k, avg, dew)
    }

    private func briefHumidity(_ c: DayCtx, _ h: DayHourly) -> Brief {
        let (k, avg, dew) = humidityLevel(h)
        let badge = [L("건조"), L("보송"), avg >= 70 ? L("조금 습함") : L("적당"), dew >= 18 ? L("꿉꿉") : L("습함"), L("끈적")][k]
        let t = [L("건조해요. 물을 자주 마셔 주세요."), L("보송하고 쾌적해요."), avg >= 70 ? L("조금 습해요.") : L("적당해요."),
                 dew >= 18 ? L("꿉꿉해요. 땀이 잘 마르지 않아요.") : L("습해요."),
                 dew >= 24 ? L("매우 끈적해요. 불쾌지수가 매우 높아요.") : L("끈적해요. 불쾌지수가 높아요.")][k] + " " + L("이슬점은 %@예요.", model.deg(dew))
        return Brief(value: L("평균 %d%%", avg), badge: badge, badgeColor: c.humColor, badgeInk: .white, summary: t)
    }
}

// MARK: - model

enum DayMetric: Int { case temp, feels, rain, wind, uv, humidity }

/// Everything the subviews need for one day, resolved once per render.
private struct DayCtx {
    let scene: WeatherScene; let index: Int; let day: WeatherScene.DayRow; let hourly: DayHourly?
    let ink: Ink; let night: Bool; let sel: Int; let metric: DayMetric; let scrub: Bool
    var snowy: Bool { day.icon == "snowflake" }
    var inv: Color { night ? Color(hex: "#141A36") : .white }
    var bubble: Color { night ? Color(hex: "#232B58") : .white }
    var shadow: Color { night ? Color.black.opacity(0.35) : Color(hex: "#1E2A44").opacity(0.18) }
    var windColor: Color { night ? Color(hex: "#4FD1BE") : Color(hex: "#1FA58F") }
    var gustColor: Color { night ? Color(hex: "#2E9E8E") : Color(hex: "#137A69") }
    var humColor: Color { night ? Color(hex: "#9AA6FF") : Color(hex: "#5B6BF0") }
    /// The forecast has one wind direction (now); every hour shows it.
    var windDeg: Int { scene.wind.deg }
}

/// 24 hourly values for one day, interpolated from the 8 three-hourly points of `dayDetail`.
/// Feels-like and gusts are not in the forecast; they are derived the way the prototype does it.
private struct DayHourly {
    var temp: [Double] = [], feel: [Double] = [], chance: [Double] = [], wind: [Double] = [], gust: [Double] = [], uv: [Double] = [], rh: [Double] = []
    var dayProb = 0; var dayIcon = "cloud"; var snowy = false; var rainy = false
    var now: Int?           // today's current hour
    var dawn = 7, dusk = 19

    static func make(scene s: WeatherScene, index: Int) -> DayHourly? {
        guard let all = s.dayDetail, index < all.count, all[index].count >= 2 else { return nil }
        let rows = all[index]
        let next = index + 1 < all.count ? all[index + 1].first : nil
        func hours(_ r: [WeatherScene.DayHour]) -> [Double] { r.enumerated().map { i, x in Double(HourLabel.hour(x.label) ?? i * 3) } }
        let hs = hours(rows)
        func series(_ f: (WeatherScene.DayHour) -> Double) -> [Double] {
            var pts = zip(hs, rows.map(f)).map { ($0, $1) }.sorted { $0.0 < $1.0 }
            if let n = next { pts.append((24, f(n))) }
            return (0..<24).map { h in interp(pts, Double(h)) }
        }
        let day = s.days[index]
        let rainy = day.chance >= 50
        let temp = series { $0.temp }
        let chance = series { max(0, min(100, $0.chance)) }
        let wind = series { max(0, $0.wind) }
        let uv = series { max(0, $0.uv) }
        let rh = series { max(0, min(100, $0.rh)) }
        // feels-like: muggy heat pushes it up (blended in from 20° to 25°), otherwise night, rain and wind pull it down
        let feel: [Double] = (0..<24).map { h in
            let t = temp[h], k = max(0, min(1, (t - 20) / 5))
            let nightness = max(0, min(1, (abs(Double(h) - 13) - 5) / 2.5))
            let cold = t - 1 - nightness - (rainy ? 1 : 0) - max(0, wind[h] - 3) * 0.5
            let hot = t + max(0, (rh[h] - 40) / 15)
            return (1 - k) * cold + k * hot
        }
        var d = DayHourly()
        d.dayProb = day.chance; d.dayIcon = day.icon; d.snowy = day.icon == "snowflake"; d.rainy = rainy
        d.temp = temp; d.feel = feel; d.chance = chance; d.wind = wind; d.uv = uv; d.rh = rh
        d.gust = wind.map { $0 * 1.5 + 0.5 }
        if index == 0, let m = WeatherScene.clockMinutes(s.clock) { d.now = m / 60 }
        return d
    }

    /// Linear interpolation between the known points (flat beyond the ends).
    private static func interp(_ pts: [(Double, Double)], _ x: Double) -> Double {
        guard let first = pts.first, let last = pts.last else { return 0 }
        if x <= first.0 { return first.1 }
        if x >= last.0 { return last.1 }
        for i in 1..<pts.count where x <= pts[i].0 {
            let (x0, y0) = pts[i - 1], (x1, y1) = pts[i]
            return x1 == x0 ? y1 : y0 + (y1 - y0) * (x - x0) / (x1 - x0)
        }
        return last.1
    }

    /// The icon for an hour: the wet icon while rain is likely, a cloud around it on a rainy day, the moon at night.
    func icon(_ h: Int) -> String {
        let wet = snowy ? "snowflake" : (dayIcon == "lightning" ? "lightning" : "raincloud")
        if chance[h] >= 50 { return wet }
        if dayIcon == "raincloud" || dayIcon == "lightning" || snowy { return "cloud" }
        if h < dawn || h >= dusk { return dayIcon == "cloud" ? "cloud" : "moon" }
        return dayIcon
    }

    /// Dew point (°C) at an hour, from the humidity: a simple rule of thumb
    func dew(_ h: Int) -> Int { Int((temp[h] - (100 - rh[h]) / 5).rounded()) }
}

/// The temperature colour ramp (blue → teal → green → yellow → orange → red)
private enum DayTempColor {
    static let stops: [(Double, [Double])] = [(-5, [91, 140, 255]), (5, [76, 195, 181]), (12, [140, 210, 110]), (18, [242, 200, 60]), (24, [255, 160, 70]), (32, [255, 100, 80])]
    static func color(_ v: Double) -> Color {
        var k = 0
        while k < stops.count - 2 && v > stops[k + 1].0 { k += 1 }
        let (t0, c0) = stops[k], (t1, c1) = stops[k + 1]
        let f = max(0, min(1, (v - t0) / (t1 - t0)))
        return Color(red: (c0[0] + (c1[0] - c0[0]) * f) / 255, green: (c0[1] + (c1[1] - c0[1]) * f) / 255, blue: (c0[2] + (c1[2] - c0[2]) * f) / 255)
    }
}

// MARK: - chart

private struct DayChartSpec {
    var vals: [Double]; var ymin: Double; var ymax: Double
    var grid: [(Double, String)] = []
    var segColors: [Color] = []
    var areaStops: [Gradient.Stop]? = nil
    var areaHorizontal = false
    var areaOpacity = 0.35
    var line2: [Double]? = nil
    var line2Color: Color = .clear
    var showHiLo = false
    var showSel = false
    var hiText = "", loText = "", selText = ""
    func y(_ v: Double, _ h: CGFloat) -> CGFloat { h - CGFloat((v - ymin) / max(0.001, ymax - ymin)) * h }
}

private struct DayScrub {
    let time: String; let icon: String?; let arrow: Bool; let main: String; let sub: String; let subColor: Color?; let subInk: Color?
}

/// Catmull-Rom curve through the 24 hourly points (plus flat ends), as cubic segments
private enum DayCurve {
    static func points(_ ys: [CGFloat], cw: CGFloat) -> [CGPoint] {
        guard let f = ys.first, let l = ys.last else { return [] }
        var p = [CGPoint(x: 0, y: f)]
        for (h, y) in ys.enumerated() { p.append(CGPoint(x: CGFloat(h) * cw + cw / 2, y: y)) }
        p.append(CGPoint(x: 24 * cw, y: l))
        return p
    }
    static func add(_ path: inout Path, _ pts: [CGPoint], _ i: Int) {
        let p0 = pts[max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(pts.count - 1, i + 2)]
        let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
        let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
        path.addCurve(to: p2, control1: c1, control2: c2)
    }
    static func line(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard pts.count > 1 else { return p }
        p.move(to: pts[0])
        for i in 0..<(pts.count - 1) { add(&p, pts, i) }
        return p
    }
    static func segment(_ pts: [CGPoint], _ i: Int) -> Path {
        var p = Path(); p.move(to: pts[i]); add(&p, pts, i); return p
    }
    static func area(_ pts: [CGPoint], height: CGFloat) -> Path {
        var p = line(pts)
        guard let l = pts.last else { return p }
        p.addLine(to: CGPoint(x: l.x, y: height)); p.addLine(to: CGPoint(x: 0, y: height)); p.closeSubpath()
        return p
    }
}

private struct DayAreaShape: Shape {
    let pts: [CGPoint]
    func path(in r: CGRect) -> Path { DayCurve.area(pts, height: r.height) }
}

/// The 140 pt chart: dotted grid with labels on the right, gradient area, coloured curve, dotted gust line,
/// the selected-hour marker and tags, and press-or-drag to pick an hour.
private struct DayChart: View {
    let ctx: DayCtx; let spec: DayChartSpec; let cw: CGFloat; let scrub: DayScrub
    /// nil until a drag shows its direction; true = sideways (scrubbing the hours), false = up-down (scrolling)
    @State var sideways: Bool? = nil
    let onScrub: (Int, Bool) -> Void
    let H: CGFloat = 140
    private var W: CGFloat { cw * 24 }

    var body: some View {
        let pts = DayCurve.points(spec.vals.map { spec.y($0, H) }, cw: cw)
        ZStack(alignment: .topLeading) {
            grid
            if let stops = spec.areaStops {
                Group {
                    if spec.areaHorizontal {
                        LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
                            .mask(LinearGradient(colors: [.black, .black.opacity(0.15)], startPoint: .top, endPoint: .bottom))
                    } else {
                        LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
                    }
                }
                .frame(width: W, height: H).clipShape(DayAreaShape(pts: pts)).opacity(spec.areaOpacity)
            }
            curves(pts)
            marker(pts)
            tags
        }
        .frame(maxWidth: .infinity, alignment: .topLeading).frame(height: H)
        .overlay(alignment: .topLeading) { if ctx.scrub { scrubBox } }
        .contentShape(Rectangle())
        // as on the prototype: drag sideways over the chart and the hour follows the finger; an up-down drag still
        // scrolls the sheet (the direction is decided by the first few points); a tap picks that hour
        .simultaneousGesture(DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .onChanged { g in
                if sideways == nil { sideways = abs(g.translation.width) >= abs(g.translation.height) }
                if sideways == true { onScrub(hour(g.location.x), true) }
            }
            .onEnded { g in
                if sideways == true { onScrub(hour(g.location.x), false) }
                sideways = nil
            })
        .onTapGesture(coordinateSpace: .local) { p in Haptic.select(); onScrub(hour(p.x), false) }
    }

    private func hour(_ x: CGFloat) -> Int { max(0, min(23, Int(x / cw))) }

    private var grid: some View {
        ForEach(Array(spec.grid.enumerated()), id: \.offset) { _, g in
            let y = H - CGFloat(g.0) * H
            DayDots(color: ctx.ink.line).frame(width: W, height: 1).offset(y: y - 0.5)
            Text(g.1).font(.ui(11)).foregroundStyle(ctx.ink.sub).fixedSize().offset(x: W + 8, y: y - 6)
        }
    }

    /// The curve as ONE path, coloured along x (hard steps between the colours of neighbouring hours), so the line has
    /// the same width everywhere — no bumps where hour segments meet. The canvas reaches a few points past the plot
    /// so a line on 0 % / 0 UV / 100 % is not cut in half by the chart's edge.
    private func curves(_ pts: [CGPoint]) -> some View {
        let pad: CGFloat = 4
        return Canvas { c, _ in
            guard pts.count > 1 else { return }
            c.translateBy(x: 0, y: pad)
            let style = StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            let path = DayCurve.line(pts)
            let cols = spec.segColors
            if cols.isEmpty || Set(cols.map { "\($0)" }).count == 1 {
                c.stroke(path, with: .color(cols.first ?? ctx.ink.ink), style: style)
            } else {
                var stops: [Gradient.Stop] = []
                for i in 0..<(pts.count - 1) {
                    let col = i < cols.count ? cols[i] : (cols.last ?? ctx.ink.ink)
                    stops.append(.init(color: col, location: pts[i].x / W))
                    stops.append(.init(color: col, location: pts[i + 1].x / W))
                }
                c.stroke(path, with: .linearGradient(Gradient(stops: stops), startPoint: .zero, endPoint: CGPoint(x: W, y: 0)), style: style)
            }
            if let l2 = spec.line2 {
                let p2 = DayCurve.points(l2.map { spec.y($0, H) }, cw: cw)
                c.stroke(DayCurve.line(p2), with: .color(spec.line2Color), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [3, 4]))
            }
        }
        .frame(width: W, height: H + pad * 2)
        .offset(y: -pad)
        .allowsHitTesting(false)
    }

    private var selY: CGFloat { H - spec.y(spec.vals[ctx.sel], H) }

    private func marker(_ pts: [CGPoint]) -> some View {
        let x = CGFloat(ctx.sel) * cw + cw / 2
        return ZStack(alignment: .topLeading) {
            DayDots(color: ctx.ink.ink, vertical: true).frame(width: 2, height: H + 24).offset(x: x - 1, y: -24).opacity(0.7)
            Rectangle().fill(ctx.inv).frame(width: 9, height: 9).overlay(Rectangle().stroke(ctx.ink.ink, lineWidth: 2))
                .offset(x: x - 4.5, y: H - selY - 4.5)
        }
        .animation(ctx.scrub ? nil : Motion.gentle, value: ctx.sel)
    }

    /// 최고 / 최저 tags sit centred on their point and slide aside (or hide) when the selected-hour tag is in the way
    private var tags: some View {
        let vmax = spec.vals.max() ?? 0, vmin = spec.vals.min() ?? 0
        let hiI = spec.vals.firstIndex(of: vmax) ?? 0, loI = spec.vals.firstIndex(of: vmin) ?? 0
        let selBox = CGRect(x: labX(ctx.sel, 54), y: selY + 8, width: 54, height: 21)
        let showSel = spec.showSel && !ctx.scrub
        let hiX = tagX(hiI, 50, selBox, showSel), loX = tagX(loI, 50, selBox, showSel)
        return ZStack(alignment: .bottomLeading) {
            if spec.showHiLo, hiX >= 0 {
                Text(spec.hiText).font(.ui(11, .medium)).foregroundStyle(ctx.inv).padding(.horizontal, 5).padding(.vertical, 3).background(ctx.ink.ink).fixedSize()
                    .offset(x: hiX, y: -(H - spec.y(vmax, H) + 9))
            }
            if spec.showHiLo, loX >= 0 {
                Text(spec.loText).font(.ui(11, .medium)).foregroundStyle(ctx.ink.sub).padding(.horizontal, 5).padding(.vertical, 3).overlay(Rectangle().stroke(ctx.ink.sub, lineWidth: 1)).fixedSize()
                    .offset(x: loX, y: -(H - spec.y(vmin, H) + 9))
            }
            if showSel {
                Text(spec.selText).font(.ui(11, .medium)).foregroundStyle(ctx.ink.ink).padding(.horizontal, 5).padding(.vertical, 3)
                    .background(ctx.bubble).overlay(Rectangle().stroke(ctx.ink.ink, lineWidth: 2)).fixedSize()
                    .offset(x: selBox.minX, y: -(selY + 8))
            }
        }
        .frame(width: W, height: H, alignment: .bottomLeading)
    }

    private func labX(_ i: Int, _ w: CGFloat) -> CGFloat { max(0, min(W - w, CGFloat(i) * cw + cw / 2 - w / 2)) }
    private func tagX(_ i: Int, _ w: CGFloat, _ sel: CGRect, _ selOn: Bool) -> CGFloat {
        let y = H - spec.y(spec.vals[i], H) + 9, x = labX(i, w)
        func hits(_ x: CGFloat) -> Bool { selOn && !(x + w <= sel.minX || sel.maxX <= x || y + 17 <= sel.minY || sel.maxY <= y) }
        if !hits(x) { return x }
        let px = CGFloat(i) * cw + cw / 2
        let x2 = i > ctx.sel ? sel.maxX + 3 : sel.minX - 3 - w
        return x2 >= 0 && x2 + w <= W && px >= x2 + 4 && px <= x2 + w - 4 && !hits(x2) ? x2 : -1
    }

    private var scrubBox: some View {
        let sx = CGFloat(ctx.sel) * cw + cw / 2
        return HStack(spacing: 7) {
            Text(scrub.time).font(.ui(11)).foregroundStyle(ctx.ink.sub).padding(.trailing, 7)
                .overlay(alignment: .trailing) { Rectangle().fill(ctx.ink.sub).frame(width: 1) }
            if let icon = scrub.icon { PixelIcon(name: icon, size: 18) }
            if scrub.arrow { DayArrow(deg: ctx.windDeg, color: ctx.ink.ink).frame(width: 14, height: 14) }
            Text(scrub.main).font(.px(16))
            if let bg = scrub.subColor {
                Text(scrub.sub).font(.ui(11, .medium)).foregroundStyle(scrub.subInk ?? ctx.ink.ink).padding(.horizontal, 5).padding(.vertical, 3).background(bg)
            } else {
                Text(scrub.sub).font(.ui(11)).foregroundStyle(ctx.ink.sub)
            }
        }
        .fixedSize()
        .padding(EdgeInsets(top: 7, leading: 9, bottom: 7, trailing: 10))
        .background(.ultraThinMaterial)
        .background(ctx.night ? Color(red: 24 / 255, green: 30 / 255, blue: 66 / 255).opacity(0.72) : Color.white.opacity(0.72))
        .overlay(Rectangle().stroke(ctx.ink.ink, lineWidth: 2))
        .background(Rectangle().fill(ctx.shadow).offset(x: 3, y: 3))
        .allowsHitTesting(false)
        .alignmentGuide(.leading) { d in ctx.sel <= 5 ? 0 : (ctx.sel >= 19 ? d.width - W : d.width / 2 - sx) }
        .alignmentGuide(.top) { d in d.height + 6 }
    }
}

// MARK: - small pixel pieces

/// Pixel corners: a box with every corner cut by one `n` pt step.
private struct DayNotch: Shape {
    let n: CGFloat
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + n, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX - n, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX - n, y: r.minY + n))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + n)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - n)); p.addLine(to: CGPoint(x: r.maxX - n, y: r.maxY - n))
        p.addLine(to: CGPoint(x: r.maxX - n, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX + n, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX + n, y: r.maxY - n))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - n)); p.addLine(to: CGPoint(x: r.minX, y: r.minY + n)); p.addLine(to: CGPoint(x: r.minX + n, y: r.minY + n))
        p.closeSubpath()
        return p
    }
}

/// A dotted 3-on / 3-off line (horizontal, or vertical)
private struct DayDots: View {
    let color: Color
    var vertical = false
    var body: some View {
        Canvas { c, size in
            var p = Path()
            if vertical { p.move(to: CGPoint(x: size.width / 2, y: 0)); p.addLine(to: CGPoint(x: size.width / 2, y: size.height)) }
            else { p.move(to: CGPoint(x: 0, y: size.height / 2)); p.addLine(to: CGPoint(x: size.width, y: size.height / 2)) }
            c.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: vertical ? size.width : size.height, dash: [3, 3]))
        }
    }
}

/// Wind arrow in the pixel style, pointing where the wind blows to (`deg` is where it comes from), snapped to 45°.
private struct DayArrow: View {
    let deg: Int; let color: Color
    var body: some View {
        let to = (deg + 180) % 360, idx = Int((Double(to) / 45).rounded()) % 8
        let diagonal = idx % 2 == 1, rot = Double(idx / 2) * 90
        Canvas { c, size in
            let s = size.width / 7
            var p = Path()
            if diagonal {   // north-east
                p.addRect(CGRect(x: 3 * s, y: 0, width: 4 * s, height: s)); p.addRect(CGRect(x: 6 * s, y: 0, width: s, height: 4 * s))
                for i in 0..<6 { p.addRect(CGRect(x: CGFloat(5 - i) * s, y: CGFloat(1 + i) * s, width: s, height: s)) }
            } else {        // up
                p.addRect(CGRect(x: 3 * s, y: 0, width: s, height: 7 * s))
                p.addRect(CGRect(x: 2 * s, y: s, width: 3 * s, height: s)); p.addRect(CGRect(x: s, y: 2 * s, width: 5 * s, height: s))
            }
            c.fill(p, with: .color(color))
        }
        .rotationEffect(.degrees(rot))
    }
}

/// Bubble tail pointing left at the character (outline + fill)
private struct DayTail: View {
    let outline: Color; let fill: Color
    var body: some View {
        Canvas { c, size in
            // 5 x 7 pixel grid: outline rows 2·3·4·5·4·3·2 wide, fill rows 1·2·3·2·1 inside, all flush right
            let s = size.width / 5
            var o = Path(), i = Path()
            for k in 0..<7 { let w = CGFloat(5 - abs(k - 3)); o.addRect(CGRect(x: size.width - w * s, y: CGFloat(k) * s, width: w * s, height: s)) }
            for k in 1..<6 { let w = CGFloat(3 - abs(k - 3)); i.addRect(CGRect(x: size.width - w * s, y: CGFloat(k) * s, width: w * s, height: s)) }
            c.fill(o, with: .color(outline)); c.fill(i, with: .color(fill))
        }
    }
}

/// Windsock stripe outline (all sides but the left)
private struct DayStripeBorder: View {
    let color: Color
    var body: some View {
        Canvas { c, size in
            var p = Path()
            p.addRect(CGRect(x: 0, y: 0, width: size.width, height: 2)); p.addRect(CGRect(x: 0, y: size.height - 2, width: size.width, height: 2))
            p.addRect(CGRect(x: size.width - 2, y: 0, width: 2, height: size.height))
            c.fill(p, with: .color(color))
        }
    }
}

private extension View {
    /// Hard-edged box with a 2 pt outline and a solid 3 pt offset shadow
    func dayBox(fill: Color, border: Color, shadow: Color) -> some View {
        self.background(fill).overlay(Rectangle().stroke(border, lineWidth: 2))
            .background(Rectangle().fill(shadow).offset(x: 3, y: 3))
    }
}
