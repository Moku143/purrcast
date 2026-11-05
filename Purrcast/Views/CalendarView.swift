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
    /// "11월" · "Nov" (the month picker)
    static func monthShort(_ month: String) -> String { format(month, "MMM") }
    /// "2026년" · "2026"
    static func year(_ y: Int) -> String { format(String(format: "%04d-01", y), "y") }
    /// "11월 3일" · "Nov 3"
    static func day(_ key: String) -> String { format(key, "MMMd") }
    /// "11월 3일 (화)" · "Tue, Nov 3"
    static func dayLong(_ key: String) -> String { format(key, "MMMdEEE") }
    /// "화" · "Tue"
    static func weekday(_ key: String) -> String { format(key, "EEE") }
    /// 1 = Sunday … 7 = Saturday
    static func weekdayNumber(_ key: String) -> Int {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!
        return date(key).map { c.component(.weekday, from: $0) } ?? 0
    }
    /// The weekend in color, as Korean and Japanese calendars have it: Sunday red, Saturday blue (nil on weekdays)
    static func weekendInk(_ weekday: Int) -> Color? {
        weekday == 1 ? Color(hex: "#E5484D") : weekday == 7 ? Color(hex: "#3B6FE0") : nil
    }
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
    /// The last month the 날씨 달력 can turn to: December four years on — as far as the holiday tables reach
    /// (tools/holidays/make.py builds last year to four years ahead, so through 2030 from 2026)
    static func lastMonth(from thisMonth: String) -> String { String(format: "%04d-12", (Int(thisMonth.prefix(4)) ?? 2026) + 4) }
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

// MARK: the calendar in small

/// The 날씨 달력 on made-up days, as the calendar draws them (the Plus page, the first-run pages, the store pictures):
/// two weeks — the date (today circled), the sky with the high and low, or the outfit worn
struct CalendarPreview: View {
    var character: PurrCharacter = .cat
    var outfits = false
    var cell: CGFloat = 40
    var deg: (Int) -> String = { "\($0)°" }
    /// The second week's Thursday is "today"
    static let today = 11
    static let days: [(icon: String, hi: Int, lo: Int)] = [
        ("sun", 21, 13), ("partly_cloudy", 20, 12), ("cloud", 18, 12), ("raincloud", 16, 11), ("raincloud", 15, 10), ("partly_cloudy", 17, 9), ("sun", 19, 9),
        ("sun", 18, 8), ("cloud", 16, 8), ("partly_cloudy", 15, 7), ("raincloud", 13, 6), ("cloud", 12, 5), ("sun", 13, 4), ("sun", 14, 5),
    ]

    var body: some View {
        let cal = DayLogText.calendar
        let symbols = cal.shortStandaloneWeekdaySymbols
        let heads = (0..<7).map { symbols[(cal.firstWeekday - 1 + $0) % 7] }
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(Array(heads.enumerated()), id: \.offset) { i, h in
                    Text(h).font(.ui(cell * 0.26)).foregroundStyle(DayLogText.weekendInk((cal.firstWeekday - 1 + i) % 7 + 1) ?? UI.faint)
                        .lineLimit(1).minimumScaleFactor(0.6).frame(width: cell)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(cell), spacing: 0), count: 7), spacing: cell * 0.12) {
                ForEach(Array(Self.days.enumerated()), id: \.offset) { i, d in
                    let isToday = i == Self.today, future = i > Self.today
                    let weekend = DayLogText.weekendInk((cal.firstWeekday - 1 + i % 7) % 7 + 1)
                    VStack(spacing: cell * 0.06) {
                        Text("\(i + 3)").font(.ui(cell * 0.3, isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? Color.white : (weekend.map { future ? $0.opacity(0.45) : $0 } ?? (future ? UI.faint : UI.ink)))
                            .frame(width: cell * 0.62, height: cell * 0.62)
                            .background(Circle().fill(isToday ? UI.ink : Color.clear))
                        if !future {
                            if outfits {
                                DayFigure(character: character, level: Rules.level(feels: Double(d.hi + d.lo) / 2 - 1), width: cell * 0.9)
                            } else {
                                PixelIcon(name: d.icon, size: cell * 0.5)
                                HStack(spacing: 1) {
                                    Text(deg(d.hi)).font(.px(cell * 0.24)).foregroundStyle(UI.ink)
                                    Text(deg(d.lo)).font(.px(cell * 0.24)).foregroundStyle(UI.faint)
                                }
                                .lineLimit(1).minimumScaleFactor(0.6)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(width: cell, height: cell * (outfits ? 2.0 : 1.75))
                }
            }
        }
    }
}

// MARK: home — 이번 주 기록

struct WeekLogCard: View {
    @EnvironmentObject var model: AppModel
    let ink: Ink
    var open: () -> Void

    var body: some View {
        let all = model.timelineDays()
        let byDate = Dictionary(all.map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })
        let tz = TimeZone.current
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
                                DayFigure(character: r.character ?? model.shownCharacter, level: r.level, width: 36)
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
    /// The month as the weather (sky · high · low) or as the outfits worn
    @State private var outfits = false
    /// The month picker (the month's name tapped)
    @State private var picking = false
    /// Which way the month turned (+1: on to the next), for the slide; the finger's pull while dragging
    @State private var turn = 1
    @State private var pull: CGFloat = 0
    /// A sideways drag is turning the month: a day under the finger is not opened when it lifts
    @State private var dragging = false
    /// Opens this many months away from now (the store picture: last month, every day filled)
    var startMonths = 0
    /// Bumped when a country's holidays arrive from the server (the month draws again)
    @State private var holidaysCame = 0
    /// Screenshots: the tab a day opened by -calDay starts on ("-calTab dust")
    @State private var calTab: DayMetric = .temp

    var body: some View {
        // one calendar: the timeline of where the user was; today and the future run on the device's own clock
        let all = model.timelineDays()
        let byDate = Dictionary(all.map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })
        let tz = TimeZone.current
        let today = DayLog.dayKey(Date(), tz: tz)
        let thisMonth = String(today.prefix(7))
        // back to the first month with a day recorded (only the days used with Plus are kept; nothing is filled in)
        let first = min(all.first.map { String($0.date.prefix(7)) } ?? thisMonth, thisMonth)
        // and ahead to December four years on: as far as the holiday tables reach. Future days stay empty and
        // shut; only their holidays show, and a month without records says so instead of inventing any.
        let last = DayLogText.lastMonth(from: thisMonth)
        let m = month.isEmpty ? thisMonth : month
        let report = MonthReport.make(all, month: m)
        // the stays feed the 이 달 머문 곳 card — shown only when the month really had more than one place
        // (a one-place month says nothing; the cells never carry a place, which read as clutter)
        let monthStays = Stays.make(all).filter { $0.from <= m + "-31" && $0.to >= m + "-01" }
        let manyPlaces = Set(monthStays.map { "\($0.cc ?? "")|\($0.city)" }).count > 1
        // each day's holidays where it was spent (a recorded day keeps its place's time zone); other days: the device
        let dayZone: (String) -> String = { byDate[$0]?.tz ?? tz.identifier }
        let holidays = holidaysCame >= 0 ? Holidays.month(m, timeZone: dayZone) : []
        VStack(spacing: 0) {
            SheetHeader(title: L("날씨 달력"), trailing: L("닫기")) { dismiss() }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    monthBar(m, first: first, last: last, thisMonth: thisMonth)
                    // the month and its report slide together; a sideways drag anywhere turns the month
                    ZStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 14) {
                            grid(m, byDate: byDate, today: today, holidays: holidays)
                            if manyPlaces { staysCard(monthStays, month: m) }
                            if !holidays.isEmpty { holidayList(holidays) }
                            reportCard(report, month: m)
                        }
                        .id(m)
                        .transition(.asymmetric(insertion: .move(edge: turn > 0 ? .trailing : .leading).combined(with: .opacity),
                                                removal: .move(edge: turn > 0 ? .leading : .trailing).combined(with: .opacity)))
                    }
                    .offset(x: pull)
                    Text(L("날씨를 볼 때마다 그날 날씨가 하루씩 쌓여요.")).font(.ui(12)).foregroundStyle(UI.sub).padding(.top, 2)
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
                .contentShape(Rectangle())
            }
            .clipped()
            // on the ScrollView itself, not its content: since iOS 18, a simultaneous drag on the content keeps
            // the ScrollView from scrolling at all (test20CalendarScroll measured 0 pt of vertical movement)
            .simultaneousGesture(swipe(m, first: first, last: last))
        }
        .background(UI.bg)
        .sheet(item: $openDay) { d in
            // a day with hours opens the same day sheet as a forecast day; one without, its numbers in rows
            if let r = byDate[d.id], let sc = r.scene(tz: TimeZone(identifier: r.tz ?? "") ?? tz), let date = DayLog.date(d.id) {
                DayDetailView(start: 0, startMetric: calTab, past: .init(scene: sc, date: date, air: r.aqiGrade.map { .init(value: r.aqi, grade: $0, main: r.aqiMain, kind: r.aqiKind ?? "cai", hour: r.aqiHour) },
                                                    character: r.character, place: r.fullPlaceName(), cc: r.cc,
                                                    confirmed: r.confirmed, tz: TimeZone(identifier: r.tz ?? "") ?? tz, here: true,
                                                    holiday: Holidays.name(d.id, timeZone: r.tz ?? tz.identifier)))
                    .presentationDetents([.large]).presentationCornerRadius(28)
            } else {
                DayLogSheet(key: d.id, record: byDate[d.id], holiday: Holidays.name(d.id, timeZone: byDate[d.id]?.tz ?? tz.identifier)).presentationDetents([.large]).presentationCornerRadius(28)
            }
        }
        .task(id: "holidays|\(m)") {
            // this month's countries: where the place is now and where its recorded days were (a week-old table is asked again)
            guard !model.isSample, let base = WeatherSource.serverURL else { return }
            let zones = [tz.identifier] + all.filter { $0.date.hasPrefix(m + "-") }.compactMap(\.tz)
            if await Holidays.refresh(Set(zones.compactMap(Holidays.country(timeZone:))), base: base) { holidaysCame += 1 }
        }
        .task(id: "\(m)|\(all.count)|\(model.shownCharacter.rawValue)") {
            shareImage = ShareCard.render(report: report, month: m, place: "", records: all.filter { $0.date.hasPrefix(m + "-") },
                                          character: report.character ?? model.shownCharacter, deg: model.deg)
        }
        .onAppear {
            if let asked = model.calendarMonth { month = asked; model.calendarMonth = nil }    // a 월간 리포트 tapped
            else if startMonths != 0, month.isEmpty { month = DayLogText.shift(thisMonth, by: startMonths) }
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            func arg(_ k: String) -> String? { args.firstIndex(of: k).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } }
            if let n = arg("-calMonth").flatMap(Int.init) { month = DayLogText.shift(thisMonth, by: n) }
            if args.contains("-calOutfits") { outfits = true }
            if args.contains("-calPick") { picking = true }
            if let t = arg("-calTab"), let i = ["temp", "feels", "rain", "wind", "uv", "humidity", "dust"].firstIndex(of: t) {
                calTab = DayMetric(rawValue: i) ?? .temp
            }
            if let n = arg("-calDay").flatMap(Int.init) {
                let k = DayLog.dayKey(Date().addingTimeInterval(Double(-n) * 86400), tz: tz)
                selected = k; openDay = DayKey(id: k)
            }
            #endif
        }
    }

    /// 오늘 (back to this month) · the month between its arrows (tapped: any month) · 날씨 | 옷차림
    private func monthBar(_ m: String, first: String, last: String, thisMonth: String) -> some View {
        HStack(spacing: 6) {
            Button { Haptic.soft(); turnTo(thisMonth, from: m) } label: {
                Text(L("오늘")).font(.ui(13, .semibold)).foregroundStyle(m == thisMonth ? UI.faint : UI.ink)
                    .lineLimit(1).fixedSize()
                    .padding(.horizontal, 11).frame(height: 38).background(Color.white, in: Capsule())
            }
            .buttonStyle(.press(0.94)).disabled(m == thisMonth).accessibilityIdentifier("cal-today")
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                arrow("chevron.left", enabled: m > first, label: L("이전")) { go(m, -1) }
                Button { Haptic.soft(); picking = true } label: {
                    VStack(spacing: 1) {
                        HStack(spacing: 3) {
                            Text(DayLogText.monthTitle(m)).font(.px(15)).foregroundStyle(UI.ink).lineLimit(1).fixedSize()
                            Image(systemName: "chevron.down").font(.system(size: 8, weight: .heavy)).foregroundStyle(UI.sub)
                        }
                    }
                    .padding(.horizontal, 2).frame(height: 48).contentShape(Rectangle())
                }
                .buttonStyle(.press(0.96)).accessibilityIdentifier("cal-month")
                .popover(isPresented: $picking, arrowEdge: .top) {
                    MonthPicker(selected: m, first: first, last: last) { k in
                        picking = false
                        if k != m { turnTo(k, from: m) }
                    }
                    .presentationCompactAdaptation(.popover)
                }
                arrow("chevron.right", enabled: m < last, label: L("다음")) { go(m, 1) }
            }
            .padding(.horizontal, 2).frame(height: 48).background(Color.white, in: Capsule())
            Spacer(minLength: 0)
            // the month as the weather, or as what was worn: with their names where they fit
            ViewThatFits(in: .horizontal) {
                modes(labels: true, icons: true)
                modes(labels: true, icons: false)
                modes(labels: false, icons: true)
            }
        }
        .padding(.top, 2)
    }

    private func modes(labels: Bool, icons: Bool) -> some View {
        HStack(spacing: 0) {
            modeButton(on: !outfits, id: "cal-mode-weather", text: labels ? L("날씨") : nil) {
                if icons { PixelIcon(name: "partly_cloudy", size: 15) }
            } action: { outfits = false }
            modeButton(on: outfits, id: "cal-mode-outfits", text: labels ? L("옷차림") : nil) {
                if icons { Image(model.shownCharacter.faceImage).resizable().interpolation(.none).scaledToFit().frame(width: 15, height: 15) }
            } action: { outfits = true }
        }
        .padding(3).background(Color.white, in: Capsule())
        .fixedSize()
    }

    private func modeButton<C: View>(on: Bool, id: String, text: String?, @ViewBuilder _ c: () -> C, action: @escaping () -> Void) -> some View {
        Button { Haptic.select(); withAnimation(Motion.snappy, action) } label: {
            HStack(spacing: 3) {
                c()
                if let text { Text(text).font(.ui(12, on ? .semibold : .regular)).foregroundStyle(on ? UI.ink : UI.sub).lineLimit(1).fixedSize() }
            }
            .padding(.horizontal, text == nil ? 9 : 7).frame(height: 32)
            .background(on ? Color(hex: "#E9ECF3") : Color.clear, in: Capsule())
        }
        .buttonStyle(.press(0.94)).accessibilityIdentifier(id)
        .accessibilityLabel(Text(id == "cal-mode-weather" ? L("날씨") : L("옷차림")))
    }

    private func arrow(_ name: String, enabled: Bool, label: String, _ action: @escaping () -> Void) -> some View {
        Button { Haptic.soft(); action() } label: {
            Image(systemName: name).font(.system(size: 13, weight: .bold)).frame(width: 26, height: 40)
        }
        .foregroundStyle(enabled ? UI.ink : UI.faint).disabled(!enabled)
        .buttonStyle(.press(0.92)).accessibilityLabel(Text(label)).accessibilityIdentifier(name == "chevron.left" ? "cal-prev" : "cal-next")
    }

    /// A sideways drag anywhere on the page: the page follows the finger (held back where there is no month to go
    /// to), and past a third of a thumb's width the month turns
    private func swipe(_ m: String, first: String, last: String) -> some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { v in
                let w = v.translation.width
                guard abs(w) > abs(v.translation.height) * 1.2 else { return }
                dragging = true
                let can = w < 0 ? m < last : m > first
                pull = can ? w * 0.6 : w * 0.18
            }
            .onEnded { v in
                // the day's button hears the same lift: it stays shut a moment longer
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { dragging = false }
                let w = v.translation.width, far = v.predictedEndTranslation.width
                let sideways = abs(w) > abs(v.translation.height) * 1.2
                let n = w < 0 ? 1 : -1
                let next = DayLogText.shift(m, by: n)
                if sideways, abs(w) > 60 || abs(far) > 160, next >= first, next <= last {
                    Haptic.soft()
                    turnTo(next, from: m)
                } else {
                    withAnimation(Motion.snappy) { pull = 0 }
                }
            }
    }

    private func go(_ m: String, _ n: Int) { turnTo(DayLogText.shift(m, by: n), from: m) }

    /// To another month, sliding the way it lies: the direction is set a frame ahead, so the month leaving slides
    /// out the same way the new one comes in
    private func turnTo(_ k: String, from m: String) {
        turn = k > m ? 1 : -1
        DispatchQueue.main.async {
            withAnimation(Motion.gentle) { month = k; selected = nil; pull = 0 }
        }
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
                            DayFigure(character: r.character ?? model.shownCharacter, level: lv, width: 62)
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

    private func grid(_ m: String, byDate: [String: DayRecord], today: String, holidays: [(key: String, name: String)]) -> some View {
        let off = Dictionary(holidays.map { ($0.key, $0.name) }, uniquingKeysWith: { a, _ in a })
        let cal = DayLogText.calendar
        let firstDay = DayLogText.date(m) ?? Date()
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(identifier: "UTC")!
        let count = DayLogText.length(m)
        let wd = utc.component(.weekday, from: firstDay)                 // 1 = Sunday
        let lead = (wd - cal.firstWeekday + 7) % 7
        let symbols = cal.shortStandaloneWeekdaySymbols
        let heads = (0..<7).map { symbols[(cal.firstWeekday - 1 + $0) % 7] }
        let cells: [String?] = Array(repeating: nil, count: lead) + (1...count).map { String(format: "%@-%02d", m, $0) }
        let cols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(Array(heads.enumerated()), id: \.offset) { i, h in
                    Text(h).font(.ui(12)).foregroundStyle(DayLogText.weekendInk((cal.firstWeekday - 1 + i) % 7 + 1) ?? UI.faint)
                        .lineLimit(1).minimumScaleFactor(0.6).frame(maxWidth: .infinity)
                }
            }
            // the gap between week rows is clearly larger than any gap inside a cell, so nothing reads as the
            // next week's date (the old layout hung the holiday name at the cell's bottom, right above the date below)
            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, k in
                    if let k { cell(k, byDate[k], today: today, holiday: off[k]) } else { Color.clear.frame(height: cellHeight) }
                }
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private var cellHeight: CGFloat { outfits ? 96 : 88 }

    /// 이 달 머문 곳: each stay of the month — flag, city, and the dates (clipped to this month)
    private func staysCard(_ stays: [Stay], month m: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("이 달 머문 곳")).font(.px(13)).foregroundStyle(UI.ink)
            ForEach(stays, id: \.from) { st in
                HStack(spacing: 8) {
                    Text(Stay.flag(st.cc) ?? st.cc ?? "·").font(.ui(13))
                    Text(KoreanNames.word(st.city, .current)).font(.ui(13, .semibold)).foregroundStyle(UI.ink).lineLimit(1)
                    Spacer(minLength: 6)
                    Text(stayRange(st, month: m)).font(.ui(12)).foregroundStyle(UI.sub).lineLimit(1).minimumScaleFactor(0.8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityIdentifier("cal-stays")
    }

    private func stayRange(_ st: Stay, month m: String) -> String {
        let from = max(st.from, m + "-01"), to = min(st.to, m + "-31")
        return from == to ? DayLogText.day(from) : "\(DayLogText.day(from)) ~ \(DayLogText.day(to))"
    }

    /// The month's holidays where the place is, under the month: "10월 3일  개천절"
    private func holidayList(_ days: [(key: String, name: String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(days, id: \.key) { d in
                HStack(spacing: 10) {
                    Text(DayLogText.day(d.key)).font(.ui(13, .semibold)).foregroundStyle(DayLogText.weekendInk(1) ?? UI.ink).frame(minWidth: 64, alignment: .leading)
                    Text(HolidayNames.display(d.name)).font(.ui(13)).foregroundStyle(UI.ink).lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityIdentifier("cal-holidays")
    }

    /// One day: its number (today in a dark circle), then its sky and range — or the outfit worn that day
    private func cell(_ k: String, _ r: DayRecord?, today: String, holiday: String?) -> some View {
        let isToday = k == today, future = k > today
        let weekend = holiday != nil ? DayLogText.weekendInk(1) : DayLogText.weekendInk(DayLogText.weekdayNumber(k))   // a holiday in Sunday's red
        return Button { guard !dragging else { return }; Haptic.soft(); selected = k; openDay = DayKey(id: k) } label: {
            // everything a day says sits together under its number — nothing hangs at the cell's bottom, where it
            // would read as the next week's date. A future day is told by having no weather, not by fading.
            VStack(spacing: 3) {
                Text(String(Int(k.suffix(2)) ?? 0)).font(.ui(14, isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? Color.white : (weekend ?? UI.ink))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(isToday ? UI.ink : Color.clear))
                if let h = holiday {
                    // the short name right under the number, at a fixed size; a name that cannot fit shows
                    // nothing here (the red number alone) — the list below and the day sheet keep the full name
                    ViewThatFits(in: .horizontal) {
                        Text(HolidayNames.short(h) ?? HolidayNames.display(h))
                            .font(.ui(10, .semibold)).foregroundStyle(DayLogText.weekendInk(1) ?? UI.sub)
                            .lineLimit(1).fixedSize().padding(.horizontal, 1)
                        Color.clear.frame(width: 0, height: 0)
                    }
                }
                if let r {
                    if outfits {
                        DayFigure(character: r.character ?? model.shownCharacter, level: r.level, width: 40)
                    } else {
                        PixelIcon(name: r.icon, size: 22)
                        HStack(spacing: 2) {
                            Text(model.deg(r.hi)).font(.px(11)).foregroundStyle(UI.ink)
                            Text(model.deg(r.lo)).font(.px(11)).foregroundStyle(UI.sub)
                        }
                        .lineLimit(1).minimumScaleFactor(0.6)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: cellHeight, maxHeight: cellHeight, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.press(0.95)).disabled(future)
        .accessibilityIdentifier("cal-\(k)")
    }
}

// MARK: the month picker

/// Any month at once: the year between its arrows, its twelve months (the months with no 날씨 기록 to show — before
/// the first kept, after this one — greyed out)
struct MonthPicker: View {
    let selected: String
    let first: String
    let last: String
    let pick: (String) -> Void
    @State private var year: Int

    init(selected: String, first: String, last: String, pick: @escaping (String) -> Void) {
        self.selected = selected; self.first = first; self.last = last; self.pick = pick
        _year = State(initialValue: Int(selected.prefix(4)) ?? 2026)
    }

    var body: some View {
        let firstYear = Int(first.prefix(4)) ?? year, lastYear = Int(last.prefix(4)) ?? year
        VStack(spacing: 14) {
            HStack {
                yearArrow("chevron.left", enabled: year > firstYear, label: L("이전")) { year -= 1 }
                Spacer()
                Text(DayLogText.year(year)).font(.px(17)).foregroundStyle(UI.ink).contentTransition(.numericText())
                Spacer()
                yearArrow("chevron.right", enabled: year < lastYear, label: L("다음")) { year += 1 }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(1...12, id: \.self) { mo in
                    let k = String(format: "%04d-%02d", year, mo)
                    let on = k == selected, open = k >= first && k <= last
                    Button { Haptic.select(); pick(k) } label: {
                        Text(DayLogText.monthShort(k)).font(.ui(14, on ? .bold : .regular))
                            .foregroundStyle(on ? Color.white : (open ? UI.ink : UI.faint))
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity).frame(height: 40)
                            .background(on ? UI.ink : Color(hex: "#F2F4F8"), in: Capsule())
                    }
                    .buttonStyle(.press(0.94)).disabled(!open)
                    .accessibilityIdentifier("pick-\(k)")
                }
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(Color.white)
    }

    private func yearArrow(_ name: String, enabled: Bool, label: String, _ action: @escaping () -> Void) -> some View {
        Button { Haptic.soft(); withAnimation(Motion.snappy, action) } label: {
            Image(systemName: name).font(.system(size: 14, weight: .bold)).frame(width: 40, height: 36)
                .background(Color(hex: "#F2F4F8"), in: Capsule())
        }
        .foregroundStyle(enabled ? UI.ink : UI.faint).disabled(!enabled)
        .buttonStyle(.press(0.92)).accessibilityLabel(Text(label))
        .accessibilityIdentifier(name == "chevron.left" ? "pick-prev-year" : "pick-next-year")
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

struct DayKey: Identifiable { let id: String }
