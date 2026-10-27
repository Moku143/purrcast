import SwiftUI

/// Tapping a day in the 10-day list, as on the prototype's AppDay screen: a 10-day strip, metric tabs
/// (기온 · 비 · 바람 · 자외선 · 습도), the character dressed for the selected hour beside a summary bubble,
/// one chart per tab with a marker at the selected hour (tap an hour, or drag sideways across the chart to read any hour),
/// and a plain-language scale underneath. Everything comes from the stored forecast (`dayDetail`, 8 three-hourly
/// rows per day: the point values are interpolated to 24 hours, the 3-hour rain amounts spread over their hours);
/// without it only the summary line is shown.
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
                if let h = hourly {
                    chartCard(ctx, h).reveal(1)
                    if !scaleItems(ctx, h).items.isEmpty { scaleCard(ctx, h).reveal(2) }
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 40)
        }
        .background(sheetBackground(s).ignoresSafeArea())
        .foregroundStyle(ink.ink)
        .onChange(of: start) { _, _ in picked = nil; scrubbing = false }
    }

    /// Day: the outfit colour fading into #EEF1F7 over the first 420 pt · night: navy all the way down
    private func sheetBackground(_ s: WeatherScene) -> some View {
        let top = s.isNight ? Color(hex: "#1A2046") : Color(hex: Rules.background[max(0, min(9, s.level))])
        let bottom = s.isNight ? Color(hex: "#0D1126") : Color(hex: "#EEF1F7")
        return GeometryReader { g in
            LinearGradient(colors: [top, bottom], startPoint: .top,
                           endPoint: UnitPoint(x: 0.5, y: s.isNight ? 1 : min(1, 420 / max(1, g.size.height))))
        }
    }

    // MARK: title · strip · tabs · alert

    private func titleRow(_ c: DayCtx) -> some View {
        ZStack {
            Text(title(c)).font(.px(17)).lineLimit(1).minimumScaleFactor(0.8).padding(.horizontal, 42)
            HStack {
                Spacer()
                Button { Haptic.soft(); dismiss() } label: {
                    DayCloseX(color: c.ink.ink).frame(width: 14, height: 14)
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
                Text(i == 0 ? L("오늘") : d.name).font(.px(11)).lineLimit(1).minimumScaleFactor(0.7)
                    .foregroundStyle(on ? c.inv : (i == 0 ? c.ink.blue : c.ink.sub))
                PixelIcon(name: d.icon, size: 28)
                    .frame(width: 40, height: 40)
                    .background(c.night ? Color.white.opacity(0.1) : Color.white.opacity(0.75))
                    .clipShape(DayNotch(n: 3))
                Text(dayNumber(i)).font(.px(13)).foregroundStyle(fg)
                Text("\(model.deg(d.hi))/\(model.deg(d.lo))").font(.px(10)).lineLimit(1).minimumScaleFactor(0.7).foregroundStyle(fg.opacity(0.8))
            }
            .frame(width: 52).padding(.top, 7).padding(.bottom, 8)
            .background {
                if on { DayNotch(n: 4).fill(c.ink.ink).matchedGeometryEffect(id: "day", in: ns) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.press(0.95))
    }

    private func tabs(_ c: DayCtx) -> some View {
        let items: [(DayMetric, String, String)] = [
            (.temp, L("기온"), "thermo_hot"), (.rain, c.snowy ? L("눈") : L("비"), c.snowy ? "snowflake" : "umbrella"),
            (.wind, L("바람"), "wind"), (.uv, L("자외선"), "sun_strong"), (.humidity, L("습도"), "sweat"),
        ]
        return HStack(spacing: 6) {
            ForEach(items, id: \.0) { item in tab(c, item) }
        }
    }

    /// One tab: 8 / 7 pt padding inside a 2 pt border (the selected one is filled to the same size)
    private func tab(_ c: DayCtx, _ item: (DayMetric, String, String)) -> some View {
        let m = item.0
        let on = m == metric || (m == .temp && metric == .feels)
        return Button { Haptic.select(); withAnimation(Motion.snappy) { metric = m } } label: {
            VStack(spacing: 5) {
                PixelIcon(name: item.2, size: 18)
                Text(item.1).font(.px(11)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(on ? c.inv : c.ink.sub)
            .frame(maxWidth: .infinity).padding(.top, 10).padding(.bottom, 9)
            .background {
                if on { DayNotch(n: 3).fill(c.ink.ink).matchedGeometryEffect(id: "metric", in: ns) }
                else { Rectangle().strokeBorder(c.line, lineWidth: 2) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.press(0.95))
    }

    /// The alert's icon from its name, in any language (the same words as the server's `warningKind`)
    private func alertIcon(_ name: String) -> String {
        let w = name.lowercased()
        func has(_ words: [String]) -> Bool { words.contains(where: { w.contains($0) }) }
        if has(["태풍", "typhoon", "hurricane", "tropical storm", "tropical cyclone", "台風"]) { return "exclaim" }
        if has(["대설", "snow", "blizzard", "ice storm", "winter storm", "大雪", "暴風雪"]) { return "snowflake" }
        if has(["호우", "rain", "flood", "大雨", "洪水"]) { return "umbrella" }
        if has(["강풍", "풍랑", "wind", "gale", "storm", "強風", "暴風", "波浪"]) { return "wind" }
        if has(["폭염", "heat", "高温", "猛暑"]) { return "thermo_hot" }
        if has(["한파", "cold", "freez", "frost", "低温", "寒波", "霜"]) { return "thermo_cold" }
        if has(["황사", "미세먼지", "dust", "smoke", "air quality", "黄砂"]) { return "mask" }
        return "exclaim"
    }

    private func alertLine(_ a: WeatherScene.Alert, _ c: DayCtx) -> some View {
        let n = a.name
        return HStack(spacing: 8) {
            PixelIcon(name: alertIcon(n), size: 18)
            Text(a.note.isEmpty ? n : "\(n) · \(model.say(a.note))").font(.px(12)).lineSpacing(3).foregroundStyle(c.ink.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(c.night ? Color(red: 1, green: 170 / 255, blue: 120 / 255).opacity(0.14) : Color(red: 1, green: 240 / 255, blue: 228 / 255).opacity(0.9))
        .overlay(Rectangle().strokeBorder(c.night ? Color(hex: "#FFB08A") : Color(hex: "#E8702E"), lineWidth: 2))
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
            bubble(c, b)
        }
    }

    private func bubble(_ c: DayCtx, _ b: Brief) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(b.value).font(.px(20)).lineLimit(1).minimumScaleFactor(0.7).rolling(b.value)
                if !b.badge.isEmpty {
                    Text(b.badge).font(.px(11)).lineLimit(1).foregroundStyle(b.badgeInk)
                        .padding(.horizontal, 6).padding(.vertical, 4).background(b.badgeColor)
                }
            }
            Text(model.say(b.summary)).font(.ui(14.5)).lineSpacing(5).foregroundStyle(c.ink.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        // 12 / 14 pt padding inside the 2 pt outline, as on the prototype
        .padding(.vertical, 14).padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dayBox(fill: c.bubble, border: c.ink.ink, shadow: c.shadow)
        .overlay(alignment: .bottomLeading) { DayTail(outline: c.ink.ink, fill: c.bubble).frame(width: 10, height: 14).offset(x: -8, y: -16) }
        .padding(.trailing, 3)
    }

    // MARK: chart card

    private func chartCard(_ c: DayCtx, _ h: DayHourly) -> some View {
        let sp = spec(c, h)
        return VStack(alignment: .leading, spacing: 10) {
            if metric == .wind { windsock(c, h) }
            chartHeader(c, h)
            GeometryReader { g in chartBlock(c, h, sp, width: g.size.width) }
                .frame(height: chartBlockHeight)
            if metric == .uv { DayUVBar(uv: h.uvMax, ink: c.ink.ink, inv: c.inv) }
        }
        .dayCard(c)
        .animation(Motion.gentle, value: metric)
    }

    /// icons (or arrows) · the chart · hour labels (· the umbrella band), 10 pt apart
    private func chartBlock(_ c: DayCtx, _ h: DayHourly, _ sp: DayChartSpec, width: CGFloat) -> some View {
        let cw = DayChart.hourWidth(width)
        return VStack(alignment: .leading, spacing: 10) {
            if metric == .wind { arrowsRow(c, cw: cw) } else { iconsRow(c, h, cw: cw) }
            DayChart(ctx: c, spec: sp, cw: cw, scrub: scrubView(c, h), onScrub: { hr, on in
                if on, hr != picked { Haptic.select() }
                picked = hr; scrubbing = on
            })
            .frame(height: DayChart.H)
            xLabels(c, cw: cw)
            if metric == .rain { umbrellaBand(c, h, cw: cw) }
        }
    }

    private var chartBlockHeight: CGFloat {
        (metric == .wind ? 18 : 22) + 10 + DayChart.H + 10 + 12 + (metric == .rain ? 18 : 0)
    }

    private func chartHeader(_ c: DayCtx, _ h: DayHourly) -> some View {
        HStack(spacing: 8) {
            Text(chartTitle(c, h)).font(.px(13)).lineLimit(1).minimumScaleFactor(0.75)
            Spacer(minLength: 4)
            if metric == .temp || metric == .feels {
                HStack(spacing: 4) {
                    chip(L("실제"), on: metric == .temp, c) { metric = .temp }
                    chip(L("체감"), on: metric == .feels, c) { metric = .feels }
                }
            } else {
                legendRow(c, h)
            }
        }
    }

    private func chip(_ t: String, on: Bool, _ c: DayCtx, action: @escaping () -> Void) -> some View {
        Button { Haptic.select(); withAnimation(Motion.snappy, action) } label: {
            Text(t).font(.px(11)).lineLimit(1).foregroundStyle(on ? c.inv : c.ink.sub)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background { if on { Rectangle().fill(c.ink.ink) } else { Rectangle().strokeBorder(c.line, lineWidth: 2) } }
        }
        .buttonStyle(.plain)
    }

    private func chartTitle(_ c: DayCtx, _ h: DayHourly) -> String {
        switch metric {
        case .temp: return L("기온")
        case .feels: return L("체감온도")
        case .rain:
            if h.hasMM { return c.snowy ? L("눈 · 눈 올 확률") : L("빗물 · 비 올 확률") }
            return c.snowy ? L("눈 올 확률") : L("비 올 확률")
        case .wind: return L("시간별 바람 (%@)", model.windUnit)
        case .uv: return L("시간별 자외선 지수")
        case .humidity: return L("시간별 습도")
        }
    }

    private struct LegendItem { let text: String; let swatch: AnyView }
    private func legend(_ c: DayCtx, _ h: DayHourly) -> [LegendItem] {
        switch metric {
        case .rain:
            let line = LegendItem(text: L("확률"), swatch: AnyView(Rectangle().fill(c.ink.blue).frame(width: 14, height: 3)))
            guard h.hasMM else { return [line] }
            let bar = Rectangle().fill(c.barFill).frame(width: 8, height: 10)
                .overlay(alignment: .top) { Rectangle().fill(c.ink.blue).frame(height: 3) }
            return [LegendItem(text: c.snowy ? L("눈(cm)") : L("빗물(mm)"), swatch: AnyView(bar)), line]
        case .wind:
            return [LegendItem(text: L("풍속"), swatch: AnyView(Rectangle().fill(c.windColor).frame(width: 14, height: 3))),
                    LegendItem(text: L("돌풍"), swatch: AnyView(DayDots(color: c.gustColor).frame(width: 14, height: 3)))]
        default: return []
        }
    }

    @ViewBuilder private func legendRow(_ c: DayCtx, _ h: DayHourly) -> some View {
        let items = legend(c, h)
        if !items.isEmpty {
            HStack(spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, l in
                    HStack(spacing: 5) { l.swatch; Text(l.text).font(.px(11)).lineLimit(1).foregroundStyle(c.ink.sub) }
                }
            }
            .fixedSize()
        }
    }

    /// One weather icon per two hours (the brighter one holds the selected hour)
    private func iconsRow(_ c: DayCtx, _ h: DayHourly, cw: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<12, id: \.self) { k in
                PixelIcon(name: h.icon(k * 2 + 1), size: 18)
                    .opacity(c.sel / 2 == k ? 1 : 0.7)
                    .offset(x: CGFloat(k) * cw * 2 + cw - 9, y: 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading).frame(height: 22)
    }

    /// Where the wind blows, every two hours (from each hour's own direction)
    private func arrowsRow(_ c: DayCtx, cw: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<12, id: \.self) { k in
                DayArrow(deg: c.dir(k * 2 + 1), color: c.ink.ink).frame(width: 14, height: 14)
                    .opacity(c.sel / 2 == k ? 1 : 0.7)
                    .offset(x: CGFloat(k) * cw * 2 + cw - 7, y: 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading).frame(height: 18)
    }

    private func xLabels(_ c: DayCtx, cw: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach([0, 6, 12, 18], id: \.self) { h in
                Text(HourLabel.word(h, clock12: model.clock12)).font(.px(11)).foregroundStyle(c.ink.sub).lineLimit(1).fixedSize()
                    .offset(x: CGFloat(h) * cw)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading).frame(height: 12)
    }

    /// 우산 band: the hours with a 50 %+ chance, merged into runs, lined up with the chart's hours
    /// (an umbrella marks the row in the label column on the right, where the chart has its scale)
    private func umbrellaBand(_ c: DayCtx, _ h: DayHourly, cw: CGFloat) -> some View {
        let wet = runs(h.chance.map { $0 >= 50 })
        return ZStack(alignment: .topLeading) {
            ForEach(wet, id: \.0) { r in
                Rectangle().fill(c.ink.blue).frame(width: max(2, CGFloat(r.1 - r.0) * cw - 2), height: 8).offset(x: CGFloat(r.0) * cw)
            }
            PixelIcon(name: "umbrella", size: 14).opacity(wet.isEmpty ? 0.45 : 1)
                .offset(x: cw * 24 + 8, y: -3)
                .accessibilityLabel(L("우산"))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading).frame(height: 8)
    }

    private func runs(_ on: [Bool]) -> [(Int, Int)] {
        guard !on.isEmpty else { return [] }
        var out: [(Int, Int)] = []; var start = 0
        for k in 1...on.count where k == on.count || on[k] != on[start] {
            if on[start] { out.append((start, k)) }
            start = k
        }
        return out
    }

    // MARK: windsock

    private func windsock(_ c: DayCtx, _ h: DayHourly) -> some View {
        let w = h.wind[c.sel], deg = c.dir(c.sel)
        let d16 = WindCard.dirs
        let from = L(d16[Int((Double(deg) / 22.5).rounded()) % 16]), to = L(d16[Int((Double((deg + 180) % 360) / 22.5).rounded()) % 16])
        return HStack(alignment: .bottom, spacing: 14) {
            sock(c, w)
            VStack(alignment: .leading, spacing: 7) {
                Text("\(timeWord(c)) \(model.windText(Int(w.rounded())))").font(.px(13)).rolling(Int(w.rounded()))
                HStack(spacing: 6) {
                    DayArrow(deg: deg, color: c.ink.ink).frame(width: 14, height: 14)
                    Text(L("%@풍 · %@쪽으로 불어요", from, to)).font(.px(11)).lineLimit(1).minimumScaleFactor(0.8).foregroundStyle(c.ink.sub)
                }
            }
            .padding(.bottom, 4)
        }
        .padding(.bottom, 4)
    }

    /// The windsock: stripes stand out further and droop less as the wind gets stronger
    private func sock(_ c: DayCtx, _ w: Double) -> some View {
        let stripes = w < 2 ? 1 : w < 4 ? 2 : w < 8 ? 3 : 4
        let droop: CGFloat = w < 2 ? 9 : w < 4 ? 6 : w < 8 ? 3 : 0
        let pole = c.night ? Color(hex: "#C9D0F0") : Color(hex: "#22203A")
        return ZStack(alignment: .topLeading) {
            Rectangle().fill(pole).frame(width: 4, height: 64).offset(x: 8, y: 6)
            Rectangle().fill(pole).frame(width: 8, height: 6).offset(x: 6, y: 2)
            ForEach(0..<stripes, id: \.self) { k in
                Rectangle().fill(k % 2 == 1 ? Color.white : Color(hex: "#E8702E"))
                    .frame(width: 24, height: CGFloat(20 - k * 3))
                    .overlay(DayStripeBorder(color: c.night ? Color(hex: "#F3F5FF") : Color(hex: "#22203A")))
                    .offset(x: CGFloat(12 + k * 24), y: 8 + CGFloat(k) * droop + CGFloat(k) * 1.5)
            }
        }
        .animation(Motion.gentle, value: droop)
        .frame(width: 112, height: 70, alignment: .topLeading)
    }

    // MARK: scale card

    private struct ScaleItem { let title: String; let sub: String; let big: Bool }
    private func scaleItems(_ c: DayCtx, _ h: DayHourly) -> (title: String, items: [ScaleItem], cur: Int) {
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
            let cur = windLevel(h)
            let items = [ScaleItem(title: L("약함"), sub: windRange(0, 3), big: false), ScaleItem(title: L("보통"), sub: windRange(4, 7), big: false),
                         ScaleItem(title: L("강함"), sub: windRange(8, 13), big: false), ScaleItem(title: L("매우 강함"), sub: model.windNumber(14) + "+", big: false)]
            return (L("바람 단계"), items, cur)
        case .uv:
            let m = h.uvMax
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

    private func scaleCard(_ c: DayCtx, _ h: DayHourly) -> some View {
        let sc = scaleItems(c, h)
        return VStack(alignment: .leading, spacing: 10) {
            Text(sc.title).font(.px(13))
            HStack(spacing: 6) {
                ForEach(Array(sc.items.enumerated()), id: \.offset) { i, it in
                    scaleBox(c, it, on: i == sc.cur)
                }
            }
            .animation(Motion.snappy, value: sc.cur)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dayCard(c)
    }

    /// 9 / 6 pt padding inside a 2 pt border (the current step is filled, with pixel corners)
    private func scaleBox(_ c: DayCtx, _ it: ScaleItem, on: Bool) -> some View {
        VStack(spacing: 5) {
            Text(it.title).font(.px(12)).lineLimit(1).minimumScaleFactor(0.6)
            Text(it.sub).font(.px(it.big ? 16 : 10)).opacity(it.big ? 1 : 0.85).lineLimit(1).minimumScaleFactor(0.6)
        }
        .foregroundStyle(on ? c.inv : c.ink.sub)
        .frame(maxWidth: .infinity).padding(.vertical, 11).padding(.horizontal, 6)
        .background { if on { DayNotch(n: 3).fill(c.ink.ink) } else { Rectangle().strokeBorder(c.line, lineWidth: 2) } }
    }

    // MARK: chart spec per tab

    private func spec(_ c: DayCtx, _ h: DayHourly) -> DayChartSpec {
        switch metric {
        case .temp, .feels: return tempSpec(c, h)
        case .rain: return rainSpec(c, h)
        case .wind: return windSpec(c, h)
        case .uv: return uvSpec(c, h)
        case .humidity: return humiditySpec(c, h)
        }
    }

    /// The value between two neighbouring hours, for the colour of the curve segment that joins them
    private func mid(_ v: [Double], _ i: Int) -> Double { (v[max(0, min(23, i - 1))] + v[max(0, min(23, i))]) / 2 }

    private func tempSpec(_ c: DayCtx, _ h: DayHourly) -> DayChartSpec {
        let vals = metric == .feels ? h.feel : h.temp
        let vmin = vals.min() ?? 0, vmax = vals.max() ?? 0
        let axis = tempAxis(vmin, vmax)
        var s = DayChartSpec(vals: vals, ymin: axis.ymin, ymax: axis.ymax)
        s.grid = axis.grid
        s.segColors = (0..<25).map { i in DayTempColor.color(mid(vals, i)) }
        s.areaStops = vals.enumerated().map { i, v in Gradient.Stop(color: DayTempColor.color(v), location: (Double(i) + 0.5) / 24) }
        s.areaHorizontal = true; s.areaOpacity = c.night ? 0.38 : 0.45
        s.showHiLo = true; s.showSel = true
        s.hiText = L("최고 %@", model.deg(Int(vmax.rounded())))
        s.loText = L("최저 %@", model.deg(Int(vmin.rounded())))
        s.selText = "\(timeWord(c)) \(model.deg(Int(vals[c.sel].rounded())))"
        return s
    }

    /// Grid every 5 °C (10 °F), 2° of room under the coldest hour and enough over the warmest for its 최고 tag
    private func tempAxis(_ vmin: Double, _ vmax: Double) -> (ymin: Double, ymax: Double, grid: [(Double, String)]) {
        let f = model.unitF
        let step: Double = f ? 10 : 5
        let lo = f ? vmin * 1.8 + 32 : vmin, hi = f ? vmax * 1.8 + 32 : vmax
        let a = floor((lo - (f ? 4 : 2)) / step) * step
        var b = max(a + 3 * step, ceil((hi + (f ? 7 : 4)) / step) * step)
        while (b - hi) / (b - a) * Double(DayChart.plotHeight) < 34 { b += step }   // the 22 pt 최고 tag 9 pt over its point, and a little air
        var grid: [(Double, String)] = []
        var y = a
        while y <= b + 0.001 { grid.append(((y - a) / (b - a), "\(Int(y))°")); y += step }
        return (f ? (a - 32) / 1.8 : a, f ? (b - 32) / 1.8 : b, grid)
    }

    private func rainSpec(_ c: DayCtx, _ h: DayHourly) -> DayChartSpec {
        var s = DayChartSpec(vals: h.chance, ymin: 0, ymax: 100)
        s.grid = [(0, "0%"), (0.5, "50%"), (1, "100%")]
        s.segColors = [c.ink.blue]
        if h.hasMM {
            s.bars = h.mm.map { barHeight($0) }
            s.barFill = c.barFill; s.barCap = c.ink.blue
        }
        return s
    }

    /// A bar's height (share of the plot) in three bands: up to 1 mm/h the lower third, 1–4 the middle, 4–10+ the top
    private func barHeight(_ v: Double) -> Double {
        if v <= 1 { return v / 3 }
        if v <= 4 { return 1.0 / 3 + (v - 1) / 9 }
        return 2.0 / 3 + min(1, (v - 4) / 6) / 3
    }

    private func windSpec(_ c: DayCtx, _ h: DayHourly) -> DayChartSpec {
        let axis = windAxis(h.gust.max() ?? 1)
        var s = DayChartSpec(vals: h.wind, ymin: 0, ymax: axis.ymax)
        s.grid = axis.grid
        s.line2 = h.gust; s.line2Color = c.gustColor
        s.segColors = [c.windColor]
        s.areaStops = [Gradient.Stop(color: c.windColor, location: 0), Gradient.Stop(color: .clear, location: 1)]
        s.areaOpacity = c.night ? 0.42 : 0.35
        return s
    }

    /// Grid in the wind unit of the settings: every 4 m/s (8 past 22 m/s gusts), round steps in km/h and mph
    private func windAxis(_ gmax: Double) -> (ymax: Double, grid: [(Double, String)]) {
        let f: Double = model.windUnit == "km/h" ? 3.6 : (model.windUnit == "mph" ? 2.237 : 1)
        let top = gmax * f
        var steps: [Double] = [5, 10, 20, 25, 50]                  // mph
        if f == 1 { steps = [gmax > 22 ? 8 : 4] }                   // m/s, as the prototype
        else if f > 3 { steps = [10, 20, 30, 40, 50, 100] }         // km/h
        let step = steps.first(where: { ceil((top + f) / $0) <= 5 }) ?? (steps.last ?? 4)
        let ymaxD = max(step, ceil((top + f) / step) * step)
        var grid: [(Double, String)] = []
        var y = 0.0
        while y <= ymaxD + 0.001 { grid.append((y / ymaxD, "\(Int(y))")); y += step }
        return (ymaxD / f, grid)
    }

    private func uvSpec(_ c: DayCtx, _ h: DayHourly) -> DayChartSpec {
        let vals = h.uv
        var s = DayChartSpec(vals: vals, ymin: 0, ymax: 12)
        s.grid = [0, 3, 6, 8, 11].map { (Double($0) / 12, String($0)) }
        s.segColors = (0..<25).map { i in Color(hex: UVScale.band(Int(mid(vals, i).rounded())).color) }
        let top = Color(hex: UVScale.band(h.uvMax).color)
        s.areaStops = [Gradient.Stop(color: top, location: 0), Gradient.Stop(color: .clear, location: 1)]
        s.areaOpacity = 0.35
        return s
    }

    private func humiditySpec(_ c: DayCtx, _ h: DayHourly) -> DayChartSpec {
        var s = DayChartSpec(vals: h.rh, ymin: 0, ymax: 100)
        s.grid = [(0, "0%"), (0.5, "50%"), (1, "100%")]
        s.segColors = [c.humColor]
        s.areaStops = [Gradient.Stop(color: c.humColor, location: 0), Gradient.Stop(color: .clear, location: 1)]
        s.areaOpacity = 0.32
        return s
    }

    /// The translucent readout above the chart while the finger moves across it: only the key value for that hour.
    private func scrubView(_ c: DayCtx, _ h: DayHourly) -> DayScrub {
        let t = timeWord(c), i = c.sel
        switch metric {
        case .temp:
            return DayScrub(time: t, icon: h.icon(i), main: model.deg(Int(h.temp[i].rounded())), sub: L("체감 %@", model.deg(Int(h.feel[i].rounded()))))
        case .feels:
            return DayScrub(time: t, icon: h.icon(i), main: L("체감 %@", model.deg(Int(h.feel[i].rounded()))), sub: L("실제 %@", model.deg(Int(h.temp[i].rounded()))))
        case .rain:
            let p = Int(h.chance[i].rounded()), amount = (h.mm[i] * 10).rounded() / 10
            var sub = c.snowy ? L("눈 올 확률") : L("비 올 확률")
            if h.hasMM, amount > 0 { sub += " · " + number(amount) + (c.snowy ? "cm" : "mm") }
            return DayScrub(time: t, icon: p >= 50 ? "umbrella" : "raindrop", main: "\(p)%", sub: sub)
        case .wind:
            let d = c.dir(i)
            return DayScrub(time: t, arrow: d, main: model.windText(Int(h.wind[i].rounded())), sub: L("%@풍", L(WindCard.dirs[Int((Double(d) / 22.5).rounded()) % 16])))
        case .uv:
            let v = Int(h.uv[i].rounded()), b = UVScale.band(v)
            return DayScrub(time: t, icon: "sun_strong", main: String(v), sub: L(b.word), subColor: Color(hex: b.color), subInk: Color(hex: b.onColor))
        case .humidity:
            return DayScrub(time: t, icon: "sweat", main: "\(Int(h.rh[i].rounded()))%", sub: L("이슬점 %@", model.deg(h.dew(i))))
        }
    }

    // MARK: words

    /// "지금" for the current hour today, otherwise the hour in the clock setting
    private func timeWord(_ c: DayCtx) -> String {
        c.index == 0 && c.hourly?.now == c.sel ? L("지금") : HourLabel.word(c.sel, clock12: model.clock12)
    }

    private func partOfDay(_ h: Int) -> String { h < 5 ? L("밤") : h < 12 ? L("아침") : h < 17 ? L("낮") : h < 21 ? L("저녁") : L("밤") }
    /// The same word inside an English sentence ("in the evening", not "in the Evening")
    private func partOfDayInText(_ h: Int) -> String { Lang.current == .en ? partOfDay(h).lowercased() : partOfDay(h) }

    /// A difference in degrees in the unit setting (°F swings are 1.8× the °C ones)
    private func dd(_ v: Int) -> Int { model.unitF ? Int((Double(abs(v)) * 1.8).rounded()) : abs(v) }
    private func degNumber(_ v: Int) -> String { String(model.deg(v).dropLast()) }
    private func degRange(_ a: Int, _ b: Int) -> String { "\(degNumber(a))~\(model.deg(b))" }
    private func windRange(_ a: Int, _ b: Int) -> String { "\(model.windNumber(a))~\(model.windNumber(b))" }
    /// 2.0 → "2", 0.4 → "0.4"
    private func number(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }
    /// Half-up rounding, as the prototype does it (−2.5 → −2)
    private func roundHalfUp(_ v: Double) -> Int { Int(floor(v + 0.5)) }

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
        var t = d.hi - d.lo >= 6 ? L("%@ %@, %@ %@예요. 일교차가 커서 겉옷이 필요해요.", L("아침"), model.deg(d.lo), partOfDayInText(14), model.deg(d.hi))
            : L("하루 종일 %@~%@예요.", degNumber(d.lo), model.deg(d.hi))
        if d.chance >= 60 { t += " " + (c.snowy ? L("눈 예보예요. 길이 미끄러울 수 있어요.") : L("비 예보예요. 우산을 챙겨 주세요.")) }
        else if d.chance >= 30 { t += " " + (c.snowy ? L("눈 올 가능성이 %d%%예요. 우산을 챙기는 게 좋을 것 같아요.", d.chance) : L("비 올 가능성이 %d%%예요. 우산을 챙기는 게 좋을 것 같아요.", d.chance)) }
        return Brief(value: "\(model.deg(d.hi)) / \(model.deg(d.lo))", badge: L("일교차 %d°", dd(d.hi - d.lo)), badgeColor: DayTempColor.color(Double(d.hi)), badgeInk: UI.ink, summary: t)
    }

    private func briefTemp(_ c: DayCtx, _ h: DayHourly) -> Brief {
        let vmin = h.temp.min() ?? 0, vmax = h.temp.max() ?? 0
        let lo = Int(vmin.rounded()), hi = Int(vmax.rounded())
        let loH = h.temp.firstIndex(of: vmin) ?? 6, hiH = h.temp.firstIndex(of: vmax) ?? 15
        var t: String
        if hi >= 30 {
            t = L("%@에 최고 %@예요. 더우니 물을 챙겨 주세요.", partOfDayInText(hiH), model.deg(hi)) + (lo >= 25 ? " " + L("밤에도 %@ 이상이에요.", model.deg(lo)) : "")
        } else if hi <= 0 || lo <= -5 {
            t = L("%@ %@, %@ %@예요. 많이 추워요.", partOfDay(loH), model.deg(lo), partOfDayInText(hiH), model.deg(hi))
        } else if hi - lo >= 6 {
            t = L("%@ %@, %@ %@예요. 일교차가 커서 겉옷이 필요해요.", partOfDay(loH), model.deg(lo), partOfDayInText(hiH), model.deg(hi))
        } else {
            t = L("하루 종일 %@~%@예요.", degNumber(lo), model.deg(hi))
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
        let gap = roundHalfUp(zip(h.temp, h.feel).reduce(0) { $0 + $1.0 - $1.1 } / 24)
        let badge = gap > 0 ? L("실제보다 -%d°", dd(gap)) : gap < 0 ? L("실제보다 +%d°", dd(gap)) : L("실제와 비슷")
        let mid = roundHalfUp(Double(lo + hi) / 2)
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

    /// The day's rain (snow in cm on a snowy day): the amount, how much that is and the highest chance; the sentence
    /// says when to take an umbrella.
    private func briefRain(_ c: DayCtx, _ h: DayHourly) -> Brief {
        let wet = (0..<24).filter { h.chance[$0] >= 50 }
        let p = h.dayProb
        let value: String, badge: String
        if h.hasMM {
            let total = h.total, unit = c.snowy ? "cm" : "mm"
            value = total >= 1 ? "\(roundHalfUp(total))\(unit)" : (total > 0 ? L("%@ 미만", "1\(unit)") : (c.snowy ? L("눈 없음") : L("비 없음")))
            let word = total >= 50 ? L("매우 많음") : total >= 20 ? L("많음") : total >= 5 ? L("보통") : L("조금")
            badge = (total >= 1 ? word + " · " : "") + L("최대 %d%%", p)
        } else {
            // an older forecast without amounts: the chance and the umbrella hours
            value = p >= 10 ? L("최대 %d%%", p) : (c.snowy ? L("눈 없음") : L("비 없음"))
            badge = wet.isEmpty ? L("우산 없이") : L("우산 %d시간", wet.count)
        }
        var soon = false
        if c.index == 0, let first = wet.first, let now = h.now { soon = first - now >= 0 && first - now <= 1 }
        var pods: [String] = []
        for w in wet { let s = partOfDayInText(w); if !pods.contains(s) { pods.append(s) } }
        let t: String
        if wet.isEmpty {
            t = p >= 30 ? (c.snowy ? L("눈 올 가능성이 %d%%예요. 우산을 챙기는 게 좋을 것 같아요.", p) : L("비 올 가능성이 %d%%예요. 우산을 챙기는 게 좋을 것 같아요.", p))
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

    private func windLevel(_ h: DayHourly) -> Int {
        let wmax = Int((h.wind.max() ?? 0).rounded())
        return wmax < 4 ? 0 : wmax < 8 ? 1 : wmax < 14 ? 2 : 3
    }

    private func briefWind(_ c: DayCtx, _ h: DayHourly) -> Brief {
        let wmin = Int((h.wind.min() ?? 0).rounded()), wmax = Int((h.wind.max() ?? 0).rounded()), gmax = Int((h.gust.max() ?? 0).rounded())
        let lvl = windLevel(h)
        var t = [L("바람이 약해요."), L("바람이 조금 있어요."), L("바람이 강해요."), L("바람이 매우 강해요. 바깥 활동은 줄여 주세요.")][lvl]
        if lvl >= 1, let peak = h.wind.firstIndex(of: h.wind.max() ?? 0) { t += " " + L("%@에 가장 세요.", partOfDayInText(peak)) }
        let value = wmin == wmax ? model.windText(wmax) : "\(model.windNumber(wmin))~\(model.windText(wmax))"
        return Brief(value: value, badge: L("돌풍 %@", model.windNumber(gmax)), badgeColor: c.windColor, badgeInk: .white, summary: t)
    }

    private func briefUV(_ c: DayCtx, _ h: DayHourly) -> Brief {
        let m = h.uvMax, b = UVScale.band(m)
        let k = m >= 8 ? 3 : m >= 6 ? 2 : m >= 3 ? 1 : 0
        let t = [L("자외선이 약해요."), L("자외선 보통이에요. 한낮엔 선크림을 바르는 게 좋을 것 같아요."), L("자외선이 강해요. 선크림과 모자를 챙겨 주세요."), L("자외선이 매우 강해요. 한낮엔 바깥 활동을 줄여 주세요.")][k]
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
        let t = [L("건조해요. 물을 자주 마시는 게 좋을 것 같아요."), L("보송하고 쾌적해요."), avg >= 70 ? L("조금 습해요.") : L("적당해요."),
                 dew >= 18 ? L("꿉꿉해요. 땀이 잘 마르지 않아요.") : L("습해요."),
                 dew >= 24 ? L("매우 끈적해요. 불쾌지수가 매우 높아요.") : L("끈적해요. 불쾌지수가 높아요.")][k] + " " + L("이슬점은 %@예요.", model.deg(dew))
        return Brief(value: L("평균 %d%%", avg), badge: badge, badgeColor: c.humColor, badgeInk: .white, summary: t)
    }
}

// MARK: - model

enum DayMetric: Int { case temp, feels, rain, wind, uv, humidity }

/// Everything the subviews need for one day, resolved once per render. Colours are the prototype's.
private struct DayCtx {
    let scene: WeatherScene; let index: Int; let day: WeatherScene.DayRow; let hourly: DayHourly?
    let ink: Ink; let night: Bool; let sel: Int; let metric: DayMetric; let scrub: Bool
    var snowy: Bool { day.icon == "snowflake" }
    var inv: Color { night ? Color(hex: "#141A36") : .white }
    var bubble: Color { night ? Color(hex: "#232B58") : .white }
    var shadow: Color { night ? Color.black.opacity(0.35) : Color(hex: "#1E2A44").opacity(0.18) }
    var line: Color { night ? Color.white.opacity(0.12) : Color(hex: "#1E2A44").opacity(0.10) }
    var cardFill: Color { night ? Color.white.opacity(0.08) : Color.white.opacity(0.66) }
    var cardBorder: Color { night ? Color.white.opacity(0.13) : Color.white.opacity(0.85) }
    var windColor: Color { night ? Color(hex: "#4FD1BE") : Color(hex: "#1FA58F") }
    var gustColor: Color { night ? Color(hex: "#2E9E8E") : Color(hex: "#137A69") }
    var humColor: Color { night ? Color(hex: "#9AA6FF") : Color(hex: "#5B6BF0") }
    var barFill: Color { night ? Color(hex: "#9CC0FF").opacity(0.55) : Color(hex: "#1F5BD0").opacity(0.35) }
    /// The wind direction (degrees it comes from) at an hour: each hour's own, or the one direction of an older forecast
    func dir(_ h: Int) -> Int {
        guard let d = hourly?.dir, d.count == 24 else { return scene.wind.deg }
        return Int(d[max(0, min(23, h))].rounded()) % 360
    }
}

/// 24 hourly values for one day from the 8 three-hourly rows of `dayDetail`: point values (temperature, chance, wind,
/// gusts, UV, humidity) are interpolated, wind directions by the shorter way round, and each 3-hour rain amount is spread
/// over its own hours. Feels-like is derived the way the prototype does it; gusts too when the forecast has none.
private struct DayHourly {
    var temp: [Double] = [], feel: [Double] = [], chance: [Double] = [], wind: [Double] = [], gust: [Double] = []
    var uv: [Double] = [], rh: [Double] = [], mm: [Double] = [], dir: [Double] = []
    var hasMM = false       // the forecast has amounts (older answers only have the chance)
    var total = 0.0         // the day's amount, mm (cm on a snowy day)
    var dayProb = 0; var dayIcon = "cloud"; var snowy = false; var rainy = false
    var now: Int?           // today's current hour
    var dawn = 7, dusk = 19
    var uvMax: Int { Int((uv.max() ?? 0).rounded()) }

    static func make(scene s: WeatherScene, index: Int) -> DayHourly? {
        guard let all = s.dayDetail, index < all.count, index < s.days.count, all[index].count >= 2 else { return nil }
        let rows = all[index]
        let next = index + 1 < all.count ? all[index + 1].first : nil
        let hs: [Double] = rows.enumerated().map { i, x in Double(HourLabel.hour(x.label) ?? i * 3) }
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
        // gusts: the strongest in each slot when the forecast has them, else 1.5 × wind + 0.5 (as the prototype); never below the wind
        var gust = wind.map { $0 * 1.5 + 0.5 }
        if rows.contains(where: { $0.gust != nil }) { gust = series { $0.gust ?? ($0.wind * 1.5 + 0.5) } }
        // directions: the shorter way round between the rows (350° → 10° passes north)
        let deg = Double(s.wind.deg)
        var dpts = zip(hs, rows.map { $0.dir ?? deg }).map { ($0, $1) }.sorted { $0.0 < $1.0 }
        if let n = next { dpts.append((24, n.dir ?? deg)) }
        // feels-like: muggy heat pushes it up (blended in from 20° to 25°), otherwise night, rain and wind pull it down
        let feel: [Double] = (0..<24).map { h in
            let t = temp[h], k = max(0, min(1, (t - 20) / 5))
            let nightness = max(0, min(1, (abs(Double(h) - 13) - 5) / 2.5))
            let cold = t - 1 - nightness - (rainy ? 1 : 0) - max(0, wind[h] - 3) * 0.5
            let hot = t + max(0, (rh[h] - 40) / 15)
            return (1 - k) * cold + k * hot
        }
        var d = DayHourly()
        d.temp = temp; d.feel = feel; d.chance = chance; d.wind = wind; d.uv = uv; d.rh = rh
        d.gust = zip(gust, wind).map { max($0, $1) }
        d.dir = (0..<24).map { h in interpAngle(dpts, Double(h)) }
        // rain: every slot's amount spread over its own hours
        d.hasMM = rows.contains { $0.mm != nil }
        d.mm = spread(hs, rows.map { $0.mm ?? 0 })
        d.total = rows.reduce(0) { $0 + max(0, $1.mm ?? 0) }
        d.dayProb = day.chance; d.dayIcon = day.icon; d.snowy = day.icon == "snowflake"; d.rainy = rainy
        if index == 0, let m = WeatherScene.clockMinutes(s.clock) { d.now = m / 60 }
        // night icons from the sunset / sunrise tile when there is one ("17:52" → from 18 h)
        for t in s.tiles {
            guard let v = t.value, let m = WeatherScene.clockMinutes(v) else { continue }
            let h = Int((Double(m) / 60).rounded(.up))
            if t.icon == "sunset" { d.dusk = max(16, min(21, h)) }
            if t.icon == "sunrise" { d.dawn = max(4, min(9, h)) }
        }
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

    /// Angles (degrees) interpolated the shorter way round, kept in 0..<360.
    private static func interpAngle(_ pts: [(Double, Double)], _ x: Double) -> Double {
        func norm(_ a: Double) -> Double { (a.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) }
        guard let first = pts.first, let last = pts.last else { return 0 }
        if x <= first.0 { return norm(first.1) }
        if x >= last.0 { return norm(last.1) }
        for i in 1..<pts.count where x <= pts[i].0 {
            let (x0, a0) = pts[i - 1], (x1, a1) = pts[i]
            guard x1 > x0 else { return norm(a1) }
            var delta = (a1 - a0).truncatingRemainder(dividingBy: 360)
            if delta > 180 { delta -= 360 } else if delta < -180 { delta += 360 }
            return norm(a0 + delta * (x - x0) / (x1 - x0))
        }
        return norm(last.1)
    }

    /// Each slot's amount over its hours, leaning towards the wetter neighbour so the bars rise and fall smoothly;
    /// every slot keeps exactly its own total (a dry slot stays dry).
    private static func spread(_ hs: [Double], _ amounts: [Double]) -> [Double] {
        var out = Array(repeating: 0.0, count: 24)
        let n = min(hs.count, amounts.count)
        guard n > 0 else { return out }
        let order = (0..<n).sorted { hs[$0] < hs[$1] }
        let start = order.map { hs[$0] }, amt = order.map { max(0, amounts[$0]) }
        var len: [Double] = []
        for k in 0..<n {
            let next: Double = k + 1 < n ? start[k + 1] : start[k] + 3.0
            len.append(Swift.max(1.0, next - start[k]))
        }
        var rate: [(Double, Double)] = []
        for k in 0..<n { rate.append((start[k] + len[k] / 2.0, amt[k] / len[k])) }
        for k in 0..<n where amt[k] > 0 {
            let hours = (0..<24).filter { Double($0) >= start[k] && Double($0) < start[k] + len[k] }
            guard !hours.isEmpty else { continue }
            let raw = hours.map { interp(rate, Double($0) + 0.5) }
            let sum = raw.reduce(0, +)
            for (j, h) in hours.enumerated() { out[h] = sum > 0 ? raw[j] / sum * amt[k] : amt[k] / Double(hours.count) }
        }
        return out
    }

    /// The icon for an hour: the wet icon while rain is likely, a cloud around it on a rainy day, the moon at night.
    func icon(_ h: Int) -> String {
        let wet = snowy ? "snowflake" : (dayIcon == "lightning" ? "lightning" : "raincloud")
        if chance[h] >= 50 || (hasMM && mm[h] >= 0.3) { return wet }
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
    var grid: [(Double, String)] = []        // (fraction of the value range, label)
    var segColors: [Color] = []              // one colour, or one per curve segment (25)
    var areaStops: [Gradient.Stop]? = nil
    var areaHorizontal = false
    var areaOpacity = 0.35
    var line2: [Double]? = nil               // gusts, dotted
    var line2Color: Color = .clear
    var bars: [Double]? = nil                // rain per hour, as a fraction of the plot height
    var barFill: Color = .clear
    var barCap: Color = .clear
    var showHiLo = false
    var showSel = false
    var hiText = "", loText = "", selText = ""
    /// y of a value: the range fills the plot under a little headroom (`DayChart.top`), so 100 % is never cut off
    func y(_ v: Double) -> CGFloat { DayChart.y(frac: (v - ymin) / max(0.001, ymax - ymin)) }
}

private struct DayScrub {
    var time: String; var icon: String? = nil; var arrow: Int? = nil; var main: String; var sub: String
    var subColor: Color? = nil; var subInk: Color? = nil
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

/// Sizes of the chart's tags and readout, measured once they are laid out (0 최고 · 1 최저 · 2 selected hour · 3 readout)
private struct DaySizes: PreferenceKey {
    static var defaultValue: [Int: CGSize] = [:]
    static func reduce(value: inout [Int: CGSize], nextValue: () -> [Int: CGSize]) { value.merge(nextValue()) { $1 } }
}

private struct DaySizeReader: View {
    let key: Int
    var body: some View { GeometryReader { g in Color.clear.preference(key: DaySizes.self, value: [key: g.size]) } }
}

/// The chart: dotted grid with labels on the right, rain bars, gradient area, coloured curve, dotted gust line,
/// the selected-hour marker and tags, and the readout above it while the finger moves across.
/// A tap picks that hour; a sideways drag from anywhere follows the finger (an up-down drag still scrolls the sheet).
private struct DayChart: View {
    /// plot height · headroom inside it above the top grid line · label column right of the plot (+5 pt to spare, as the 288 + 36 of 329 pt on the prototype)
    static let H: CGFloat = 180
    static let top: CGFloat = 10
    static let gutter: CGFloat = 36
    static var plotHeight: CGFloat { H - top }
    static func y(frac: Double) -> CGFloat { top + plotHeight * CGFloat(1 - frac) }
    static func hourWidth(_ width: CGFloat) -> CGFloat { max(1, (width - gutter - 5) / 24) }

    let ctx: DayCtx; let spec: DayChartSpec; let cw: CGFloat; let scrub: DayScrub
    let onScrub: (Int, Bool) -> Void
    /// nil until a drag shows its direction; true = sideways (scrubbing the hours), false = up-down (scrolling)
    @State var sideways: Bool? = nil
    @State var sizes: [Int: CGSize] = [:]
    private var W: CGFloat { cw * 24 }
    private var H: CGFloat { DayChart.H }

    var body: some View {
        let pts = DayCurve.points(spec.vals.map { spec.y($0) }, cw: cw)
        ZStack(alignment: .topLeading) {
            grid
            if let bars = spec.bars { barsView(bars) }
            if spec.areaStops != nil { area(pts) }
            curves(pts)
            marker
            tags
            if ctx.scrub { scrubBox }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading).frame(height: H, alignment: .topLeading)
        .onPreferenceChange(DaySizes.self) { sizes = $0 }
        .contentShape(Rectangle())
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
    private func px(_ i: Int) -> CGFloat { CGFloat(i) * cw + cw / 2 }
    private func clampX(_ x: CGFloat, _ w: CGFloat) -> CGFloat { max(0, min(W - w, x)) }

    private var grid: some View {
        ForEach(Array(spec.grid.enumerated()), id: \.offset) { _, g in
            let y = DayChart.y(frac: g.0)
            DayDots(color: ctx.line).frame(width: W, height: 1).offset(y: y - 0.5)
            Text(g.1).font(.px(11)).foregroundStyle(ctx.ink.sub).lineLimit(1).fixedSize()
                .frame(height: 12).offset(x: W + 8, y: y - 6)
        }
    }

    /// Rain per hour: 8 pt bars (with a 3 pt cap) under the chance curve
    private func barsView(_ bars: [Double]) -> some View {
        ForEach(0..<min(24, bars.count), id: \.self) { i in
            let h = bars[i] > 0.0001 ? max(3, CGFloat(min(1, bars[i])) * DayChart.plotHeight) : 0
            if h > 0 {
                Rectangle().fill(spec.barFill)
                    .overlay(alignment: .top) { Rectangle().fill(spec.barCap).frame(height: 3) }
                    .frame(width: max(2, cw - 4), height: h)
                    .offset(x: CGFloat(i) * cw + 2, y: H - h)
            }
        }
        .allowsHitTesting(false)
    }

    private func area(_ pts: [CGPoint]) -> some View {
        let stops = spec.areaStops ?? []
        return Group {
            if spec.areaHorizontal {
                LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
                    .mask(LinearGradient(colors: [.black, .black.opacity(0.15)], startPoint: .top, endPoint: .bottom))
            } else {
                LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
            }
        }
        .frame(width: W, height: H).clipShape(DayAreaShape(pts: pts)).opacity(spec.areaOpacity)
        .allowsHitTesting(false)
    }

    /// The curve as ONE path, coloured along x (hard steps between the colours of neighbouring hours), so the line has
    /// the same width everywhere — no bumps where hour segments meet. The canvas reaches a few points past the plot
    /// so a line on 0 % / 0 UV / 100 % is never cut in half. Gusts: 3 on, 4 off, square ends (as on the prototype).
    private func curves(_ pts: [CGPoint]) -> some View {
        let pad: CGFloat = 4
        return Canvas { c, _ in
            guard pts.count > 1 else { return }
            c.translateBy(x: 0, y: pad)
            let style = StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            let path = DayCurve.line(pts)
            let cols = spec.segColors
            if cols.count <= 1 {
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
                let p2 = DayCurve.points(l2.map { spec.y($0) }, cw: cw)
                c.stroke(DayCurve.line(p2), with: .color(spec.line2Color), style: StrokeStyle(lineWidth: 3, lineCap: .butt, lineJoin: .round, dash: [3, 4]))
            }
        }
        .frame(width: W, height: H + pad * 2)
        .offset(y: -pad)
        .allowsHitTesting(false)
    }

    /// Dotted line from above the plot (from the readout while scrubbing) and a 13 pt square on the curve
    private var marker: some View {
        let x = px(ctx.sel), y = spec.y(spec.vals[ctx.sel])
        let from: CGFloat = ctx.scrub ? -6 : -24
        return ZStack(alignment: .topLeading) {
            DayDots(color: ctx.ink.ink, vertical: true).frame(width: 2, height: H - from).offset(x: x - 1, y: from).opacity(0.7)
            Rectangle().fill(ctx.inv).overlay(Rectangle().strokeBorder(ctx.ink.ink, lineWidth: 2))
                .frame(width: 13, height: 13).offset(x: x - 6.5, y: y - 6.5)
        }
        .animation(ctx.scrub ? nil : Motion.gentle, value: ctx.sel)
        .allowsHitTesting(false)
    }

    // MARK: tags

    /// A tag's measured size (an estimate until it has been laid out once)
    private func size(_ k: Int, _ text: String, _ h: CGFloat) -> CGSize { sizes[k] ?? CGSize(width: CGFloat(text.count) * 8 + 14, height: h) }

    /// Where the tags go (top-left corners; nil = hidden), never touching each other or the marker. The selected-hour
    /// tag sits above its point (below it when there is no room) and slides to either side when that lets 최고 / 최저
    /// fit; those sit above their points, slide sideways as far as their point stays under them, 최저 may drop under its
    /// point, and a tag with no room left is hidden (최고 when the selected hour is the warmest: its tag says it already).
    /// While the finger scrubs, the selected-hour tag is away, so 최고 / 최저 only make way for the marker.
    private var tagPlan: (hi: CGPoint?, lo: CGPoint?, sel: CGPoint?) {
        let vals = spec.vals
        guard vals.count == 24, let vmax = vals.max(), let vmin = vals.min() else { return (nil, nil, nil) }
        let sx = px(ctx.sel), sy = spec.y(vals[ctx.sel])
        let mark = CGRect(x: sx - 6.5, y: sy - 6.5, width: 13, height: 13)
        let ss = size(2, spec.selText, 26), hs = size(0, spec.hiText, 22), ls = size(1, spec.loText, 24)
        let selY = sy - 8 - ss.height >= -2 ? sy - 8 - ss.height : sy + 8
        let hiI = vals.firstIndex(of: vmax) ?? 0, loI = vals.firstIndex(of: vmin) ?? 0
        let selOn = spec.showSel && !ctx.scrub
        let xs = [clampX(sx - ss.width / 2, ss.width), clampX(sx - ss.width + 4, ss.width), clampX(sx - 4, ss.width)]
        var best: (hi: CGRect?, lo: CGRect?, sel: CGRect)?
        var bestScore = -1
        for x in xs {
            let sel = CGRect(x: x, y: selY, width: ss.width, height: ss.height)
            var taken = [mark]
            if selOn { taken.append(sel) }
            let hi = spec.showHiLo ? place(px(hiI), spec.y(vmax), hs, taken, under: false) : nil
            if let hi { taken.append(hi) }
            let lo = spec.showHiLo ? place(px(loI), spec.y(vmin), ls, taken, under: true) : nil
            let score = (hi == nil ? 0 : 2) + (lo == nil ? 0 : 1)
            if score > bestScore { best = (hi, lo, sel); bestScore = score }
            if score == 3 || !spec.showHiLo || !selOn { break }
        }
        guard let b = best else { return (nil, nil, nil) }
        return (b.hi?.origin, b.lo?.origin, selOn ? b.sel.origin : nil)
    }

    /// A 최고 / 최저 tag over (or, `under`, below) its point at x0: centred, else slid just clear of what is in the way
    /// while the point stays at least 4 pt inside the tag; nil when nothing fits.
    private func place(_ x0: CGFloat, _ py: CGFloat, _ s: CGSize, _ taken: [CGRect], under: Bool) -> CGRect? {
        func free(_ r: CGRect) -> Bool {
            r.minY >= -2 && r.maxY <= H + 2 && !taken.contains(where: { $0.insetBy(dx: -2, dy: -2).intersects(r) })
        }
        let lo = max(0, x0 - s.width + 4), hi = min(W - s.width, x0 - 4)
        let centre = lo <= hi ? min(max(x0 - s.width / 2, lo), hi) : clampX(x0 - s.width / 2, s.width)
        var xs = [centre]
        if lo <= hi {
            for b in taken { xs.append(b.maxX + 3); xs.append(b.minX - 3 - s.width) }
            xs = xs.filter { $0 >= lo - 0.5 && $0 <= hi + 0.5 }.sorted { abs($0 - centre) < abs($1 - centre) }
        }
        var ys = [py - 9 - s.height]
        if under { ys.append(py + 9) }
        for y in ys {
            for x in xs {
                let r = CGRect(x: x, y: y, width: s.width, height: s.height)
                if free(r) { return r }
            }
        }
        return nil
    }

    private var tags: some View {
        let p = tagPlan
        return ZStack(alignment: .topLeading) {
            if spec.showHiLo {
                Text(spec.hiText).font(.px(11)).lineLimit(1).foregroundStyle(ctx.inv)
                    .padding(.horizontal, 5).padding(.vertical, 3).background(ctx.ink.ink).fixedSize()
                    .background(DaySizeReader(key: 0))
                    .opacity(p.hi == nil ? 0 : 1).offset(x: p.hi?.x ?? 0, y: p.hi?.y ?? 0)
                Text(spec.loText).font(.px(11)).lineLimit(1).foregroundStyle(ctx.ink.sub)
                    .padding(.horizontal, 6).padding(.vertical, 4).overlay(Rectangle().strokeBorder(ctx.ink.sub, lineWidth: 1)).fixedSize()
                    .background(DaySizeReader(key: 1))
                    .opacity(p.lo == nil ? 0 : 1).offset(x: p.lo?.x ?? 0, y: p.lo?.y ?? 0)
            }
            if spec.showSel {
                Text(spec.selText).font(.px(11)).lineLimit(1).foregroundStyle(ctx.ink.ink)
                    .padding(.horizontal, 7).padding(.vertical, 5)
                    .background(ctx.bubble).overlay(Rectangle().strokeBorder(ctx.ink.ink, lineWidth: 2)).fixedSize()
                    .background(DaySizeReader(key: 2))
                    .opacity(p.sel == nil ? 0 : 1).offset(x: p.sel?.x ?? 0, y: p.sel?.y ?? 0)
            }
        }
        .frame(width: W, height: H, alignment: .topLeading)
        .animation(ctx.scrub ? nil : Motion.gentle, value: ctx.sel)
        .allowsHitTesting(false)
    }

    // MARK: readout

    /// Above the plot (6 pt over it, on top of the icon row), centred on the hour; at the left edge up to 5 h and at the
    /// right edge from 19 h, and never past either edge.
    private var scrubBox: some View {
        let s = sizes[3]
        let w = s?.width ?? 0, h = s?.height ?? 36
        let full = W + DayChart.gutter
        let sx = px(ctx.sel)
        let want = ctx.sel <= 5 ? 0 : (ctx.sel >= 19 ? full - w : sx - w / 2)
        let x = min(max(0, want), max(0, full - w))
        return scrubContent
            .background(DaySizeReader(key: 3))
            .opacity(s == nil ? 0 : 1)
            .offset(x: x, y: -(h + 6))
            .allowsHitTesting(false)
    }

    private var scrubContent: some View {
        HStack(spacing: 7) {
            Text(scrub.time).font(.px(11)).lineLimit(1).foregroundStyle(ctx.ink.sub).padding(.trailing, 7)
                .overlay(alignment: .trailing) { Rectangle().fill(ctx.ink.sub).frame(width: 1) }
            if let icon = scrub.icon { PixelIcon(name: icon, size: 18) }
            if let deg = scrub.arrow { DayArrow(deg: deg, color: ctx.ink.ink).frame(width: 14, height: 14) }
            Text(scrub.main).font(.px(16)).lineLimit(1)
            scrubSub
        }
        .fixedSize()
        // 7 / 10 / 7 / 9 pt inside the 2 pt outline
        .padding(EdgeInsets(top: 9, leading: 11, bottom: 9, trailing: 12))
        .background(ctx.night ? Color(red: 24 / 255, green: 30 / 255, blue: 66 / 255).opacity(0.72) : Color.white.opacity(0.72))
        .background(.ultraThinMaterial)
        .overlay(Rectangle().strokeBorder(ctx.ink.ink, lineWidth: 2))
        .background(DayDropShadow().fill(ctx.shadow))
    }

    @ViewBuilder private var scrubSub: some View {
        if let bg = scrub.subColor {
            Text(scrub.sub).font(.px(11)).lineLimit(1).foregroundStyle(scrub.subInk ?? ctx.ink.ink)
                .padding(.horizontal, 5).padding(.vertical, 3).background(bg)
        } else {
            Text(scrub.sub).font(.px(11)).lineLimit(1).foregroundStyle(ctx.ink.sub)
        }
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

/// The solid 3 pt offset shadow of a box, drawn only where it shows (right and bottom), so a see-through box stays clean
private struct DayDropShadow: Shape {
    var d: CGFloat = 3
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.addRect(CGRect(x: r.maxX, y: r.minY + d, width: d, height: r.height))
        p.addRect(CGRect(x: r.minX + d, y: r.maxY, width: r.width - d, height: d))
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
        let to = ((deg + 180) % 360 + 360) % 360, idx = Int((Double(to) / 45).rounded()) % 8
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

/// The close button's pixel cross (7 × 7 grid)
private struct DayCloseX: View {
    let color: Color
    private static let rows: [[Int]] = [[0, 1, 5, 6], [0, 1, 2, 4, 5, 6], [1, 2, 3, 4, 5], [2, 3, 4], [1, 2, 3, 4, 5], [0, 1, 2, 4, 5, 6], [0, 1, 5, 6]]
    var body: some View {
        Canvas { c, size in
            let s = size.width / 7
            var p = Path()
            for (y, row) in Self.rows.enumerated() { for x in row { p.addRect(CGRect(x: CGFloat(x) * s, y: CGFloat(y) * s, width: s, height: s)) } }
            c.fill(p, with: .color(color))
        }
    }
}

/// Bubble tail pointing left at the character (outline + fill), the prototype's 5 × 7 pixel shape, flush right
private struct DayTail: View {
    let outline: Color; let fill: Color
    private static let outer: [CGFloat] = [3, 4, 5, 4, 3, 2, 1]      // widths of rows 0…6
    private static let inner: [CGFloat] = [0, 1, 2, 3, 2, 1, 0]
    var body: some View {
        Canvas { c, size in
            let s = size.width / 5
            var o = Path(), i = Path()
            for k in 0..<7 {
                o.addRect(CGRect(x: size.width - Self.outer[k] * s, y: CGFloat(k) * s, width: Self.outer[k] * s, height: s))
                if Self.inner[k] > 0 { i.addRect(CGRect(x: size.width - Self.inner[k] * s, y: CGFloat(k) * s, width: Self.inner[k] * s, height: s)) }
            }
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

/// The UV scale under the UV chart: five coloured segments and a square marking the day's highest index
private struct DayUVBar: View {
    let uv: Int; let ink: Color; let inv: Color
    var body: some View {
        GeometryReader { g in
            let total = UVScale.bands.reduce(0) { $0 + $1.flex }
            let gaps = CGFloat(UVScale.bands.count - 1) * 2
            let pos = CGFloat((min(Double(uv), 11.5) + 0.5) / 12) * g.size.width
            ZStack(alignment: .topLeading) {
                HStack(spacing: 2) {
                    ForEach(Array(UVScale.bands.enumerated()), id: \.offset) { _, b in
                        Rectangle().fill(Color(hex: b.color)).frame(width: (g.size.width - gaps) * b.flex / total, height: 6)
                    }
                }
                .offset(y: 4)
                Rectangle().fill(inv).overlay(Rectangle().strokeBorder(ink, lineWidth: 2))
                    .frame(width: 14, height: 14)
                    .offset(x: pos - 7)
                    .animation(Motion.gentle, value: uv)
            }
        }
        .frame(height: 14)
    }
}

private extension View {
    /// Hard-edged box with a 2 pt outline (inside its frame) and a solid 3 pt offset shadow
    func dayBox(fill: Color, border: Color, shadow: Color) -> some View {
        self.background(fill).overlay(Rectangle().strokeBorder(border, lineWidth: 2))
            .background(Rectangle().fill(shadow).offset(x: 3, y: 3))
    }

    /// The frosted card: 14 / 14 / 14 / 16 pt padding inside a 1 pt border, 20 pt corners, a soft shadow by day
    func dayCard(_ c: DayCtx) -> some View {
        self.padding(EdgeInsets(top: 15, leading: 17, bottom: 15, trailing: 15))
            .background {
                RoundedRectangle(cornerRadius: 20).fill(c.cardFill)
                    .shadow(color: Color(hex: "#1E2A44").opacity(c.night ? 0 : 0.08), radius: 9, y: 6)
            }
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(c.cardBorder, lineWidth: 1))
    }
}
