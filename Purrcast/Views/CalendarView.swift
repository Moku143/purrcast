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
                    if let k = selected ?? (m == thisMonth ? today : nil) { dayPanel(k, byDate[k]) }
                    Text(L("날씨를 볼 때마다 그날 날씨가 하루씩 쌓여요.")).font(.ui(11)).foregroundStyle(UI.sub).padding(.top, 2)
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
        }
        .background(UI.bg)
        .task(id: "fill|\(m)|\(place.id)") { await model.fillHistory(for: place, month: m) }   // the month's missed days
        .task(id: "\(m)|\(all.count)|\(model.shownCharacter.rawValue)") {
            shareImage = ShareCard.render(report: report, month: m, place: place.short, records: all.filter { $0.date.hasPrefix(m + "-") },
                                          character: model.shownCharacter, deg: model.deg)
        }
        .onAppear {
            #if DEBUG
            if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "-calMonth"), i + 1 < ProcessInfo.processInfo.arguments.count,
               let n = Int(ProcessInfo.processInfo.arguments[i + 1]) { month = DayLogText.shift(thisMonth, by: n) }
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
                    if let k { cell(k, byDate[k], today: today) } else { Color.clear.frame(height: 66) }
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
        return Button { Haptic.soft(); withAnimation(Motion.snappy) { selected = k } } label: {
            VStack(spacing: 2) {
                Text(String(Int(k.suffix(2)) ?? 0)).font(.px(10)).foregroundStyle(isToday ? UI.accent : (future ? UI.faint : UI.ink))
                if let r {
                    PixelIcon(name: r.icon, size: 18)
                    Text(model.deg(r.hi)).font(.px(10)).foregroundStyle(UI.ink).lineLimit(1).minimumScaleFactor(0.7)
                    Text(model.deg(r.lo)).font(.px(9)).foregroundStyle(UI.sub).lineLimit(1).minimumScaleFactor(0.7)
                } else {
                    Spacer(minLength: 0)
                }
            }
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, minHeight: 66, maxHeight: 66)
            .background(r.map { Color(hex: Rules.background[Rules.clamp($0.level)]) } ?? Color(hex: "#F5F6F9"), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSel ? UI.ink : (isToday ? UI.accent : .clear), lineWidth: isSel ? 2 : 1.5))
        }
        .buttonStyle(.press(0.95)).disabled(future)
        .accessibilityIdentifier("cal-\(k)")
    }

    // MARK: the day picked

    private func dayPanel(_ k: String, _ r: DayRecord?) -> some View {
        HStack(alignment: .center, spacing: 14) {
            if let r {
                DayFigure(character: model.shownCharacter, level: r.level, width: 64)
                VStack(alignment: .leading, spacing: 6) {
                    Text(DayLogText.dayLong(k)).font(.px(15)).foregroundStyle(UI.ink)
                    if !r.place.isEmpty { Text(r.place).font(.ui(12)).foregroundStyle(UI.sub) }
                    HStack(spacing: 6) {
                        PixelIcon(name: r.icon, size: 20)
                        Text(L("최고 %@ · 최저 %@", model.deg(r.hi), model.deg(r.lo))).font(.ui(13.5, .semibold)).foregroundStyle(UI.ink)
                    }
                    if r.isWet {
                        Text(r.mm > 0 ? (r.isSnow ? L("눈 %@", DayLogText.mm(r.mm, snow: true)) : L("비 %@", DayLogText.mm(r.mm, snow: false)))
                                      : (r.isSnow ? L("눈 온 날") : L("비 온 날")))
                            .font(.ui(13)).foregroundStyle(Color(hex: "#3F6FD8"))
                    }
                    if let g = r.dust { HStack(spacing: 6) { Text(L("미세먼지")).font(.ui(13)).foregroundStyle(UI.sub); AirGradeChip(grade: g, size: 11) } }
                    if r.obs == true { Text(L("관측으로 채운 날")).font(.ui(11)).foregroundStyle(UI.sub) }
                }
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(DayLogText.dayLong(k)).font(.px(15)).foregroundStyle(UI.ink)
                    Text(L("기록이 없는 날이에요")).font(.ui(13)).foregroundStyle(UI.sub)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("cal-day")
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
