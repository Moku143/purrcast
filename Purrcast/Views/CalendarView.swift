import SwiftUI

/// 날씨 기록: the 이번 주 기록 card on home (everyone), the 날씨 달력 with its 월간 리포트 (Plus).
enum DayLogText {
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Lang.current.locale
        return c
    }
    static func date(_ key: String) -> Date? {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count >= 2 else { return nil }
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!
        return c.date(from: DateComponents(year: p[0], month: p[1], day: p.count > 2 ? p[2] : 1, hour: 12))
    }
    private static func format(_ key: String, _ template: String) -> String {
        guard let d = date(key) else { return key }
        let f = DateFormatter()
        f.locale = Lang.current.locale
        f.timeZone = TimeZone(identifier: "UTC")
        f.setLocalizedDateFormatFromTemplate(template)
        return f.string(from: d)
    }
    /// "2026년 11월" · "November 2026"
    static func monthTitle(_ month: String) -> String { format(month, "yMMMM") }
    /// "11월" · "November"
    static func monthName(_ month: String) -> String { format(month, "MMMM") }
    /// "11월 3일" · "Nov 3"
    static func day(_ key: String) -> String { format(key, "MMMd") }
    /// "11월 3일 (화)" · "Tue, Nov 3"
    static func dayLong(_ key: String) -> String { format(key, "MMMdEEE") }
    /// "화" · "Tue"
    static func weekday(_ key: String) -> String { format(key, "EEE") }
    static func days(_ n: Int) -> String { n == 1 ? L("하루") : L("%d일", n) }
    static func mm(_ v: Double, snow: Bool) -> String {
        let n = v >= 10 ? String(Int(v.rounded())) : (v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v))
        return n + (snow ? "cm" : "mm")
    }
    /// Days in the month ("2026-02" → 28)
    static func length(_ month: String) -> Int {
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(identifier: "UTC")!
        return date(month).flatMap { utc.range(of: .day, in: .month, for: $0)?.count } ?? 30
    }
    /// The month after "2026-11" (or before, `by: -1`)
    static func shift(_ month: String, by n: Int) -> String {
        let p = month.split(separator: "-").compactMap { Int($0) }
        guard p.count == 2 else { return month }
        let i = p[0] * 12 + (p[1] - 1) + n
        return String(format: "%04d-%02d", i / 12, i % 12 + 1)
    }
}

/// The character standing in a day's outfit, cut to the figure (the canvas has room around it for an umbrella)
struct DayFigure: View {
    let character: PurrCharacter
    let level: Int
    var width: CGFloat = 40
    var body: some View {
        let k = width / 300
        CharacterSprite(character: character, level: Rules.clamp(level), rain: .none, width: 480 * k, animate: false)
            .frame(width: 480 * k, height: 560 * k)
            .offset(x: -10 * k, y: -70 * k)
            .frame(width: width, height: 420 * k)
            .clipped()
    }
}

// MARK: home — 이번 주 기록

struct WeekLogCard: View {
    @EnvironmentObject var model: AppModel
    let ink: Ink
    var open: () -> Void

    var body: some View {
        let place = model.currentPlace
        let all = model.days(for: place)
        let byDate = Dictionary(all.map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })
        let tz = TimeZone(identifier: place.timeZone) ?? .current
        let keys = (0..<7).reversed().map { DayLog.dayKey(Date().addingTimeInterval(Double(-$0) * 86400), tz: tz) }
        Button(action: { Haptic.soft(); open() }) {
            Card(ink: ink) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L("이번 주 기록")).font(.px(13)); Spacer()
                    if model.plus { Text(L("기록 %d일", all.count)).font(.ui(11)).foregroundStyle(ink.sub) } else { PlusTag() }
                }
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(keys.enumerated()), id: \.offset) { i, k in
                        let today = i == keys.count - 1
                        VStack(spacing: 5) {
                            Text(today ? L("오늘") : DayLogText.weekday(k)).font(.px(11)).foregroundStyle(today ? ink.ink : ink.sub).lineLimit(1).minimumScaleFactor(0.7)
                            if let r = byDate[k] {
                                DayFigure(character: model.shownCharacter, level: r.level, width: 36)
                                PixelIcon(name: r.icon, size: 22)
                                Text(model.deg(r.hi)).font(.px(13))
                                Text(model.deg(r.lo)).font(.px(11)).foregroundStyle(ink.sub)
                            } else {
                                // a day the phone never looked
                                RoundedRectangle(cornerRadius: 8).stroke(ink.line, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                                    .frame(width: 30, height: 50)
                                Text("–").font(.px(13)).foregroundStyle(ink.faint).frame(height: 22)
                                Text(" ").font(.px(13)); Text(" ").font(.px(11))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                HStack(spacing: 4) {
                    Text(model.plus ? L("눌러서 달력 보기") : L("Plus에서 날씨 달력 · 월간 리포트를 볼 수 있어요")).font(.ui(11.5, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(ink.sub).frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .buttonStyle(.press(0.98))
        .accessibilityIdentifier("week-card")
    }
}

// MARK: 날씨 달력 (Plus)

struct CalendarSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var month = ""
    @State private var selected: String?
    @State private var shareImage: UIImage?
    /// The day tapped: its own page (DayLogSheet)
    @State private var openDay: DayKey?
    /// The day page's look — graph · image · text · mixed (being chosen; screenshots pick one with -dayStyle)
    @State private var style = DayCardStyle.graph

    var body: some View {
        let place = model.currentPlace
        let all = model.days(for: place)
        let byDate = Dictionary(all.map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })
        let tz = TimeZone(identifier: place.timeZone) ?? .current
        let today = DayLog.dayKey(Date(), tz: tz)
        let thisMonth = String(today.prefix(7))
        // back a year: the days the phone missed are filled in from what the weather was
        let first = min(all.first.map { String($0.date.prefix(7)) } ?? thisMonth, model.isSample ? thisMonth : DayLogText.shift(thisMonth, by: -12))
        let m = month.isEmpty ? thisMonth : month
        let report = MonthReport.make(all, month: m)
        VStack(spacing: 0) {
            SheetHeader(title: L("날씨 달력"), trailing: L("닫기")) { dismiss() }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    monthBar(m, canBack: m > first, canNext: m < thisMonth, place: place)
                    reportCard(report, month: m)
                    grid(m, byDate: byDate, today: today)
                    Text(L("날씨를 볼 때마다 그날 날씨가 하루씩 쌓여요.")).font(.ui(12)).foregroundStyle(UI.sub).padding(.top, 2)
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
        }
        .background(UI.bg)
        .sheet(item: $openDay) { d in
            DayLogSheet(key: d.id, record: byDate[d.id], style: style).presentationDetents([.large]).presentationCornerRadius(28)
        }
        .task(id: "fill|\(m)|\(place.id)") { await model.fillHistory(for: place, month: m) }   // the month's missed days
        .task(id: "\(m)|\(all.count)|\(model.shownCharacter.rawValue)") {
            shareImage = ShareCard.render(report: report, month: m, place: place.short, records: all.filter { $0.date.hasPrefix(m + "-") },
                                          character: model.shownCharacter, deg: model.deg)
        }
        .onAppear {
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            func arg(_ k: String) -> String? { args.firstIndex(of: k).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } }
            if let n = arg("-calMonth").flatMap(Int.init) { month = DayLogText.shift(thisMonth, by: n) }
            if let v = arg("-dayStyle").flatMap(DayCardStyle.init(rawValue:)) { style = v }
            if let n = arg("-calDay").flatMap(Int.init) {
                let k = DayLog.dayKey(Date().addingTimeInterval(Double(-n) * 86400), tz: tz)
                selected = k; openDay = DayKey(id: k)
            }
            #endif
        }
    }

    private func monthBar(_ m: String, canBack: Bool, canNext: Bool, place: Place) -> some View {
        HStack(spacing: 10) {
            arrow("chevron.left", enabled: canBack, label: L("이전")) { go(m, -1) }
            VStack(spacing: 2) {
                Text(DayLogText.monthTitle(m)).font(.px(17)).foregroundStyle(UI.ink)
                Text(place.short).font(.ui(12)).foregroundStyle(UI.sub)
            }
            .frame(maxWidth: .infinity)
            arrow("chevron.right", enabled: canNext, label: L("다음")) { go(m, 1) }
        }
        .padding(.top, 2)
    }

    private func arrow(_ name: String, enabled: Bool, label: String, _ action: @escaping () -> Void) -> some View {
        Button { Haptic.soft(); action() } label: {
            Image(systemName: name).font(.system(size: 15, weight: .bold)).frame(width: 40, height: 40)
                .background(Color.white, in: Circle())
        }
        .foregroundStyle(enabled ? UI.ink : UI.faint).disabled(!enabled)
        .buttonStyle(.press(0.92)).accessibilityLabel(Text(label)).accessibilityIdentifier(name == "chevron.left" ? "cal-prev" : "cal-next")
    }

    private func go(_ m: String, _ n: Int) {
        withAnimation(Motion.gentle) { month = DayLogText.shift(m, by: n); selected = nil }
    }

    // MARK: 월간 리포트

    private func reportCard(_ r: MonthReport, month m: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(L("%@ 리포트", DayLogText.monthName(m))).font(.px(15)).foregroundStyle(UI.ink)
                Spacer()
                if r.days > 0, let img = shareImage {
                    ShareLink(item: Image(uiImage: img), preview: SharePreview(L("%@ 리포트", DayLogText.monthName(m)), image: Image(uiImage: img))) {
                        HStack(spacing: 4) { Image(systemName: "square.and.arrow.up").font(.system(size: 12, weight: .bold)); Text(L("리포트 공유")).font(.ui(12.5, .semibold)) }
                            .foregroundStyle(UI.accent)
                    }
                    .accessibilityIdentifier("cal-share")
                }
            }
            if r.days == 0 {
                Text(L("이 달은 기록이 없어요")).font(.ui(14)).foregroundStyle(UI.sub)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    if let lv = r.level {
                        VStack(spacing: 4) {
                            DayFigure(character: model.shownCharacter, level: lv, width: 62)
                            Text(L("자주 입은 옷")).font(.ui(11)).foregroundStyle(UI.sub).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(width: 78)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        stat("raincloud", L("비·눈 온 날"), DayLogText.days(r.wetDays))
                        if let h = r.hottest { stat("thermo_hot", L("가장 더운 날"), "\(DayLogText.day(h.date)) · \(model.deg(h.hi))") }
                        if let c = r.coldest { stat("thermo_cold", L("가장 추운 날"), "\(DayLogText.day(c.date)) · \(model.deg(c.lo))") }
                        if let d = r.dustDays { stat("mask", L("미세먼지 나쁜 날"), DayLogText.days(d)) }
                    }
                }
                if let v = r.vsLast {
                    let shown = model.unitF ? Int((Double(abs(v)) * 1.8).rounded()) : abs(v)
                    Text(abs(v) < 1 ? L("지난달과 비슷해요") : v > 0 ? L("지난달보다 평균 %d° 높아요", shown) : L("지난달보다 평균 %d° 낮아요", shown))
                        .font(.ui(13, .semibold)).foregroundStyle(v >= 1 ? Color(hex: "#E0612F") : v <= -1 ? Color(hex: "#3F6FD8") : UI.ink)
                }
                Text(L("기록 %d일", r.days)).font(.ui(11)).foregroundStyle(UI.sub)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private func stat(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            PixelIcon(name: icon, size: 20)
            Text(title).font(.ui(13)).foregroundStyle(UI.sub).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 6)
            Text(value).font(.px(13)).foregroundStyle(UI.ink).lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    // MARK: the month

    private func grid(_ m: String, byDate: [String: DayRecord], today: String) -> some View {
        let cal = DayLogText.calendar
        let firstDay = DayLogText.date(m) ?? Date()
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(identifier: "UTC")!
        let count = DayLogText.length(m)
        let wd = utc.component(.weekday, from: firstDay)                 // 1 = Sunday
        let lead = (wd - cal.firstWeekday + 7) % 7
        let symbols = cal.shortStandaloneWeekdaySymbols
        let heads = (0..<7).map { symbols[(cal.firstWeekday - 1 + $0) % 7] }
        let cells: [String?] = Array(repeating: nil, count: lead) + (1...count).map { String(format: "%@-%02d", m, $0) }
        let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(Array(heads.enumerated()), id: \.offset) { _, h in
                    Text(h).font(.ui(11, .semibold)).foregroundStyle(UI.sub).lineLimit(1).minimumScaleFactor(0.6).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, k in
                    if let k { cell(k, byDate[k], today: today) } else { Color.clear.frame(height: 80) }
                }
            }
        }
        .padding(10)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
            guard abs(v.translation.width) > abs(v.translation.height) else { return }
            let next = DayLogText.shift(m, by: v.translation.width < 0 ? 1 : -1)
            if next <= String(today.prefix(7)) { withAnimation(Motion.gentle) { month = next; selected = nil } }
        })
    }

    private func cell(_ k: String, _ r: DayRecord?, today: String) -> some View {
        let isToday = k == today, isSel = k == (selected ?? today)
        let future = k > today
        return Button { Haptic.soft(); selected = k; openDay = DayKey(id: k) } label: {
            VStack(spacing: 3) {
                Text(String(Int(k.suffix(2)) ?? 0)).font(.px(12)).foregroundStyle(isToday ? UI.accent : (future ? UI.faint : UI.ink))
                if let r {
                    PixelIcon(name: r.icon, size: 20)
                    Text(model.deg(r.hi)).font(.px(12)).foregroundStyle(UI.ink).lineLimit(1).minimumScaleFactor(0.7)
                    Text(model.deg(r.lo)).font(.px(11)).foregroundStyle(UI.sub).lineLimit(1).minimumScaleFactor(0.7)
                } else {
                    Spacer(minLength: 0)
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 80)
            .background(r.map { Color(hex: Rules.background[Rules.clamp($0.level)]) } ?? Color(hex: "#F5F6F9"), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSel ? UI.ink : (isToday ? UI.accent : .clear), lineWidth: isSel ? 2 : 1.5))
        }
        .buttonStyle(.press(0.95)).disabled(future)
        .accessibilityIdentifier("cal-\(k)")
    }
}

/// One of the day's measures hour by hour: a line (기온 · 바람 · 습도) with its highest and lowest marked, or bars
/// (비 · 자외선) with the highest marked. Under the temperature line, the hours of rain as small bars.
struct CalendarDayChart: View {
    enum Metric: String, CaseIterable { case temp, rain, wind, humidity, uv
        func title(snow: Bool) -> String {
            switch self { case .temp: return L("기온"); case .rain: return snow ? L("눈") : L("비"); case .wind: return L("바람"); case .humidity: return L("습도"); case .uv: return L("자외선") }
        }
        func icon(snow: Bool) -> String {
            switch self { case .temp: return "thermo_hot"; case .rain: return snow ? "snowflake" : "umbrella"; case .wind: return "wind"; case .humidity: return "sweat"; case .uv: return "sun_strong" }
        }
    }
    /// The hours that have a value; nil when there is too little to draw
    static func series(_ m: Metric, _ r: DayRecord) -> [Double?]? {
        func doubles(_ a: [Int?]?) -> [Double?]? {
            guard let a else { return nil }
            return a.map { (x: Int?) -> Double? in x.map { Double($0) } }
        }
        var v: [Double?]?
        switch m {
        case .temp: v = doubles(r.temps)
        case .rain: v = r.rain
        case .wind: v = doubles(r.winds)
        case .humidity: v = doubles(r.rhs)
        case .uv: v = doubles(r.uvs)
        }
        guard let vals = v, vals.count == 24 else { return nil }
        let present: [Double] = vals.compactMap { $0 }
        switch m {
        case .rain: return present.contains(where: { $0 >= 0.1 }) ? vals : nil      // no bars on a dry day
        case .uv: return present.contains(where: { $0 > 0 }) ? vals : nil
        default: return present.count >= 3 ? vals : nil
        }
    }

    let metric: Metric
    let record: DayRecord
    let clock12: Bool
    let deg: (Int) -> String
    let wind: (Int) -> String

    private var color: Color {
        switch metric { case .temp: return Color(hex: "#E0612F"); case .rain: return Color(hex: "#5B8CF0"); case .wind: return Color(hex: "#3FA58E"); case .humidity: return Color(hex: "#4C9BD8"); case .uv: return Color(hex: "#E8A21B") }
    }
    private var bars: Bool { metric == .rain || metric == .uv }
    private func text(_ v: Double) -> String {
        switch metric {
        case .temp: return deg(Int(v.rounded()))
        case .rain: return DayLogText.mm(v, snow: record.isSnow)
        case .wind: return wind(Int(v.rounded()))
        case .humidity: return "\(Int(v.rounded()))%"
        case .uv: return String(Int(v.rounded()))
        }
    }

    /// The plot's height, and whether every third hour carries its value (the day page) or only the extremes (small)
    var height: CGFloat = 100
    var pointLabels = false

    var body: some View {
        let values = Self.series(metric, record) ?? Array(repeating: nil, count: 24)
        let pts: [(Int, Double)] = values.enumerated().compactMap { i, v in v.map { (i, $0) } }
        let hi = pts.map(\.1).max() ?? 0
        let lo = bars ? 0 : (pts.map(\.1).min() ?? 0)
        let under: [Double] = metric == .temp ? (record.rain ?? []).map { $0 ?? 0 } : []
        let maxMM = max(under.max() ?? 0, 1)
        let ticks = pointLabels ? Array(stride(from: 0, to: 24, by: 3)) : [0, 6, 12, 18]
        GeometryReader { g in
            let w = g.size.width - 24, ox: CGFloat = 12
            let labelRow: CGFloat = 18, top: CGFloat = pointLabels ? 22 : 16
            let plotH = g.size.height - labelRow - top - 6
            let base = g.size.height - labelRow - 4
            let x: (Int) -> CGFloat = { ox + CGFloat($0) / 23 * w }
            let y: (Double) -> CGFloat = { top + (hi == lo ? plotH / 2 : CGFloat((hi - $0) / (hi - lo)) * plotH) }
            let barH: (Double) -> CGFloat = { max(3, CGFloat($0 / max(hi, 0.1)) * (plotH - 4)) }
            ZStack(alignment: .topLeading) {
                // a faint line at each tick
                ForEach(ticks, id: \.self) { t in
                    Rectangle().fill(UI.line).frame(width: 1, height: base - top + 4).position(x: x(t), y: top + (base - top + 4) / 2 - 2)
                }
                // the hours of rain under the temperature line
                ForEach(Array(under.enumerated()), id: \.offset) { i, mm in
                    if mm >= 0.1 {
                        let bh = max(4, CGFloat(mm / maxMM) * min(28, plotH / 3))
                        RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#7FA6F0").opacity(0.75)).frame(width: max(3, w / 24 - 3), height: bh)
                            .position(x: x(i), y: base - bh / 2)
                    }
                }
                if bars {
                    ForEach(Array(pts.enumerated()), id: \.offset) { _, p in
                        RoundedRectangle(cornerRadius: 2).fill(color.opacity(p.1 == hi ? 1 : 0.6)).frame(width: max(4, w / 24 - 3), height: barH(p.1))
                            .position(x: x(p.0), y: base - barH(p.1) / 2)
                    }
                    if let a = pts.first(where: { $0.1 == hi }) { label(text(hi), x: x(a.0), y: base - barH(a.1) - 10, width: g.size.width, strong: true) }
                } else {
                    Path { p in
                        for (n, pt) in pts.enumerated() { let q = CGPoint(x: x(pt.0), y: y(pt.1)); if n == 0 { p.move(to: q) } else { p.addLine(to: q) } }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: pointLabels ? 3 : 2.5, lineCap: .round, lineJoin: .round))
                    if pointLabels {
                        // every third hour: a dot and its value (the warmest and coldest in bold)
                        ForEach(ticks, id: \.self) { t in
                            if let v = values[safe: t] ?? nil {
                                dot(at: CGPoint(x: x(t), y: y(v)), big: v == hi || v == lo)
                                label(text(v), x: x(t), y: y(v) - 13, width: g.size.width, strong: v == hi || v == lo)
                            }
                        }
                    } else {
                        if let a = pts.first(where: { $0.1 == hi }) { dot(at: CGPoint(x: x(a.0), y: y(a.1)), big: true); label(text(hi), x: x(a.0), y: y(a.1) - 11, width: g.size.width, strong: true) }
                        if let b = pts.first(where: { $0.1 == lo }), hi != lo { dot(at: CGPoint(x: x(b.0), y: y(b.1)), big: true); label(text(lo), x: x(b.0), y: y(b.1) + 12, width: g.size.width, strong: true) }
                    }
                }
                // the hours along the bottom, each under its line
                ForEach(ticks, id: \.self) { t in
                    Text(HourLabel.word(t, clock12: clock12)).font(.ui(pointLabels ? 11.5 : 10.5)).foregroundStyle(UI.sub).lineLimit(1).fixedSize()
                        .position(x: x(t), y: g.size.height - labelRow / 2)
                }
            }
        }
        .frame(height: height)
    }

    private func dot(at p: CGPoint, big: Bool) -> some View {
        Circle().fill(big ? color : Color.white).overlay(Circle().stroke(color, lineWidth: 2)).frame(width: big ? 9 : 7, height: big ? 9 : 7).position(p)
    }
    private func label(_ t: String, x: CGFloat, y: CGFloat, width: CGFloat, strong: Bool) -> some View {
        Text(t).font(.px(strong ? 13 : 11.5)).foregroundStyle(strong ? UI.ink : UI.sub).fixedSize().position(x: min(max(x, 18), width - 18), y: y)
    }
}

// MARK: the picture to share

/// The month on one card: the place and month, the outfit worn most, the numbers, every day as a coloured square.
struct ShareCard: View {
    let report: MonthReport
    let month: String
    let place: String
    let records: [DayRecord]
    let character: PurrCharacter
    let deg: (Int) -> String

    @MainActor static func render(report: MonthReport, month: String, place: String, records: [DayRecord], character: PurrCharacter, deg: @escaping (Int) -> String) -> UIImage? {
        let r = ImageRenderer(content: ShareCard(report: report, month: month, place: place, records: records, character: character, deg: deg))
        r.scale = 3
        return r.uiImage
    }

    var body: some View {
        let byDay = Dictionary(records.map { (Int($0.date.suffix(2)) ?? 0, $0) }, uniquingKeysWith: { a, _ in a })
        let count = DayLogText.length(month)
        let last = records.last.flatMap { Int($0.date.suffix(2)) } ?? 0
        // the month so far; a finished month in full
        let shown = month < String(DayLog.dayKey(Date(), tz: .current).prefix(7)) ? count : last
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(L("%@ 리포트", DayLogText.monthName(month))).font(.px(22)).foregroundStyle(UI.ink)
                Spacer()
                Text(Brand.name).font(.px(13)).foregroundStyle(UI.accent)
            }
            Text("\(place) · \(DayLogText.monthTitle(month))").font(.system(size: 13)).foregroundStyle(UI.sub)
            HStack(alignment: .center, spacing: 14) {
                if let lv = report.level { DayFigure(character: character, level: lv, width: 84) }
                VStack(alignment: .leading, spacing: 8) {
                    line(L("비·눈 온 날"), DayLogText.days(report.wetDays))
                    if let h = report.hottest { line(L("가장 더운 날"), "\(DayLogText.day(h.date)) · \(deg(h.hi))") }
                    if let c = report.coldest { line(L("가장 추운 날"), "\(DayLogText.day(c.date)) · \(deg(c.lo))") }
                    if let d = report.dustDays { line(L("미세먼지 나쁜 날"), DayLogText.days(d)) }
                }
            }
            // every day of the month, coloured by its outfit's warmth
            let cols = Array(repeating: GridItem(.fixed(30), spacing: 5), count: 8)
            LazyVGrid(columns: cols, alignment: .leading, spacing: 5) {
                ForEach(1...count, id: \.self) { d in
                    if d <= shown {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6).fill(byDay[d].map { Color(hex: Rules.background[Rules.clamp($0.level)]) } ?? Color(hex: "#EEF0F4"))
                            if let r = byDay[d] { PixelIcon(name: r.icon, size: 18) }
                        }
                        .frame(width: 30, height: 30)
                    }
                }
            }
        }
        .padding(22)
        .frame(width: 340)
        .background(Color(hex: "#FBF7F1"))
    }

    private func line(_ t: String, _ v: String) -> some View {
        HStack(spacing: 8) {
            Text(t).font(.system(size: 13)).foregroundStyle(UI.sub)
            Spacer(minLength: 4)
            Text(v).font(.px(13)).foregroundStyle(UI.ink)
        }
    }
}

enum DayCardStyle: String { case graph, image, text, mixed }

/// The day as the notifications draw it: the character in that day's outfit under that day's sky, the umbrella open
/// when it rained (made once per look, then kept)
struct DayPicture: View {
    let record: DayRecord
    let character: PurrCharacter
    private static var cache: [String: UIImage] = [:]

    var body: some View {
        let sky = record.isWet ? NotificationArt.wetSky(icon: record.icon) : NotificationArt.sky(icon: record.icon)
        let rain: RainState = record.isWet ? .umbrella : .none
        let key = "\(character.rawValue)|\(record.level)|\(rain.rawValue)|\(sky.rawValue)"
        let img = Self.cache[key] ?? {
            let i = NotificationArt.render(character, level: record.level, rain: rain, sky: sky, falling: record.isWet)
            if let i { Self.cache[key] = i }
            return i
        }()
        Group {
            if let img { Image(uiImage: img).resizable().interpolation(.none).scaledToFill() } else { Color(hex: "#DDE6F3") }
        }
        .frame(maxWidth: .infinity)
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

struct DayKey: Identifiable { let id: String }
