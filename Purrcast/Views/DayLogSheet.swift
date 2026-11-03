import SwiftUI

/// One day of 날씨 기록 on its own page (tapped in the 날씨 달력). Four looks while one is chosen:
/// graph (the measures as graphs behind tabs), image (the day as a picture), text (every number in a list),
/// mixed (a picture, the temperature line and four tiles).
struct DayLogSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let key: String
    let record: DayRecord?
    var style: DayCardStyle = .graph
    @State private var metric = CalendarDayChart.Metric.temp

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: DayLogText.dayLong(key), trailing: L("닫기")) { dismiss() }
            ScrollView(showsIndicators: false) {
                if let r = record {
                    Group {
                        switch style {
                        case .graph: graphLook(r)
                        case .image: imageLook(r)
                        case .text: textLook(r)
                        case .mixed: mixedLook(r)
                        }
                    }
                    .padding(.bottom, 30)
                    if r.obs == true {
                        Text(L("관측으로 채운 날")).font(.ui(12)).foregroundStyle(UI.sub).padding(.bottom, 24)
                    }
                } else {
                    VStack(spacing: 12) {
                        PixelIcon(name: "question", size: 36)
                        Text(L("기록이 없는 날이에요")).font(.ui(15)).foregroundStyle(UI.sub)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 80)
                }
            }
        }
        .background(UI.bg)
    }

    // MARK: shared pieces

    /// The character in the day's outfit, where it was, its sky and range, what it said
    private func hero(_ r: DayRecord, figure: CGFloat = 92) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                DayFigure(character: model.shownCharacter, level: r.level, width: figure)
                VStack(alignment: .leading, spacing: 6) {
                    if !r.place.isEmpty { Text(r.place).font(.ui(14, .medium)).foregroundStyle(UI.sub) }
                    range(r, big: 38)
                }
                Spacer(minLength: 0)
            }
            say(r)
        }
        .card()
    }

    private func range(_ r: DayRecord, big: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            PixelIcon(name: r.icon, size: big * 0.75).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 4 }
            Text(model.deg(r.hi)).font(.px(big)).foregroundStyle(UI.ink)
            Text(model.deg(r.lo)).font(.px(big * 0.62)).foregroundStyle(UI.sub)
        }
    }

    @ViewBuilder private func say(_ r: DayRecord) -> some View {
        if let s = r.say, s.count == 4 {
            BubbleView(kind: s[0], tone: s[1], icon: s[2], text: s[3], fontSize: 13).fixedSize()
        }
    }

    @ViewBuilder private func alerts(_ r: DayRecord) -> some View {
        if let a = r.alerts, !a.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(a, id: \.self) { n in
                    HStack(spacing: 8) {
                        PixelIcon(name: AlertBanner.icon(n), size: 18)
                        Text(n).font(.ui(14, .semibold))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Color(hex: "#9C2F15")).padding(.horizontal, 14).padding(.vertical, 11)
                    .background(Color(hex: "#FFE3D8"), in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    /// "15~19시 · 5.5mm"
    private func rainText(_ r: DayRecord) -> String? {
        guard r.isWet else { return nil }
        let amount = r.mm > 0 ? DayLogText.mm(r.mm, snow: r.isSnow) : nil
        let when = r.wetHours.map { HourLabel.window($0.0, $0.1, clock12: model.clock12) }
        let t = [when, amount].compactMap { $0 }.joined(separator: " · ")
        return t.isEmpty ? (r.isSnow ? L("눈 온 날") : L("비 온 날")) : t
    }

    private func sun(_ r: DayRecord) -> (String, String)? {
        guard let la = r.lat, let lo = r.lon, let d = DayLogText.date(key) else { return nil }
        let tz = TimeZone(identifier: model.currentPlace.timeZone) ?? .current
        guard let s = SunTimes.day(d, lat: la, lon: lo, tz: tz) else { return nil }
        var c = Calendar(identifier: .gregorian); c.timeZone = tz
        let t: (Date) -> String = { HourLabel.clock(c.component(.hour, from: $0) * 60 + c.component(.minute, from: $0), clock12: model.clock12) }
        return (t(s.rise), t(s.set))
    }

    /// The sky of one three-hour slot: rain where it rained, the day's sky otherwise (a dry slot of a wet day is cloudy;
    /// a clear night shows the moon)
    private func slotIcon(_ r: DayRecord, _ h: Int) -> String {
        let wet = (h..<min(24, h + 3)).contains { r.rain(at: $0) >= 0.1 }
        if wet { return r.isSnow ? "snowflake" : "raincloud" }
        let sky = DayRecord.isWetIcon(r.icon) ? "cloud" : r.icon
        if (h < 6 || h >= 19) && (sky == "sun" || sky == "partly_cloudy") { return "moon" }
        return sky
    }

    private func slotRain(_ r: DayRecord, _ h: Int) -> Double {
        (h..<min(24, h + 3)).reduce(0) { $0 + r.rain(at: $1) }
    }

    /// A white tile: icon and name, the value large, a word under it
    private func tile(_ icon: String, _ title: String, _ value: String, _ note: String? = nil, chip: Int? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                PixelIcon(name: icon, size: 18)
                Text(title).font(.ui(13, .medium)).foregroundStyle(UI.sub).lineLimit(1)
            }
            if let chip { AirGradeChip(grade: chip, size: 15) } else {
                Text(value).font(.px(22)).foregroundStyle(UI.ink).lineLimit(1).minimumScaleFactor(0.6)
            }
            if let note { Text(note).font(.ui(12)).foregroundStyle(UI.sub).lineLimit(1).minimumScaleFactor(0.8) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    /// The four (or so) tiles of the day: rain or feels-like, wind, humidity, UV
    private func tiles(_ r: DayRecord) -> some View {
        var items: [AnyView] = []
        if let t = rainText(r) {
            let parts = t.components(separatedBy: " · ")
            items.append(AnyView(tile(r.isSnow ? "snowflake" : "raincloud", r.isSnow ? L("눈") : L("비"), parts.last ?? t, parts.count > 1 ? parts.first : nil)))
        } else if let a = r.feelsLo, let b = r.feelsHi {
            items.append(AnyView(tile("thermo_cold", L("체감"), "\(model.deg(a)) ~ \(model.deg(b))")))
        }
        if let w = r.windMax { items.append(AnyView(tile("wind", L("바람"), model.windText(w), L("최대")))) }
        if let h = r.rh { items.append(AnyView(tile("raindrop", L("습도"), "\(h)%", L("평균")))) }
        if let u = r.uv { items.append(AnyView(tile("sun_strong", L("자외선"), String(u), L("최고")))) }
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, v in v }
        }
    }

    /// 미세먼지 · 일출 · 일몰 as settings-like rows
    @ViewBuilder private func moreRows(_ r: DayRecord) -> some View {
        let s = sun(r)
        if r.dust != nil || s != nil {
            VStack(spacing: 0) {
                if let g = r.dust {
                    SettingRow(icon: "mask", title: L("미세먼지")) { AirGradeChip(grade: g, size: 13) }
                    if s != nil { RowDivider() }
                }
                if let s {
                    SettingRow(icon: "sunrise", title: L("일출")) { value(s.0) }
                    RowDivider()
                    SettingRow(icon: "sunset", title: L("일몰")) { value(s.1) }
                }
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func value(_ t: String) -> some View { Text(t).font(.px(15)).foregroundStyle(UI.ink) }

    // MARK: 1 · graph — the measures as graphs behind tabs

    private func graphLook(_ r: DayRecord) -> some View {
        let all = CalendarDayChart.Metric.allCases.filter { CalendarDayChart.series($0, r) != nil }
        let m = all.contains(metric) ? metric : (all.first ?? .temp)
        return VStack(alignment: .leading, spacing: 14) {
            hero(r)
            alerts(r)
            if !all.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    if all.count > 1 {
                        HStack(spacing: 8) {
                            ForEach(all, id: \.self) { k in
                                let on = k == m
                                Button { Haptic.select(); withAnimation(Motion.snappy) { metric = k } } label: {
                                    VStack(spacing: 5) {
                                        PixelIcon(name: k.icon(snow: r.isSnow), size: 20)
                                        Text(k.title(snow: r.isSnow)).font(.px(12)).lineLimit(1).minimumScaleFactor(0.7)
                                    }
                                    .foregroundStyle(on ? Color.white : UI.sub)
                                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(on ? UI.ink : Color(hex: "#F2F4F8")))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.press(0.95)).accessibilityIdentifier("day-metric-\(k.rawValue)")
                            }
                        }
                    }
                    CalendarDayChart(metric: m, record: r, clock12: model.clock12, deg: model.deg, wind: model.windText, height: 210, pointLabels: true,
                                     windNumber: model.windNumber, windUnit: model.windUnit)
                        .id(m).transition(.opacity)
                    Text(summary(m, r)).font(.ui(14)).foregroundStyle(UI.ink).fixedSize(horizontal: false, vertical: true)
                }
                .card()
            }
            moreRows(r)
        }
        .padding(.horizontal, 16)
    }

    /// One line under the graph: what that measure came to
    private func summary(_ m: CalendarDayChart.Metric, _ r: DayRecord) -> String {
        switch m {
        case .temp:
            var p = [L("최고 %@ · 최저 %@", model.deg(r.hi), model.deg(r.lo))]
            if let a = r.feelsLo, let b = r.feelsHi { p.append(L("체감 %@ ~ %@", model.deg(a), model.deg(b))) }
            return p.joined(separator: " · ")
        case .rain: return rainText(r).map { r.isSnow ? L("눈 %@", $0) : L("비 %@", $0) } ?? ""
        case .wind: return r.windMax.map { L("바람 최대 %@", model.windText($0)) } ?? ""
        case .humidity: return r.rh.map { L("습도 %d%%", $0) + " · " + L("평균") } ?? ""
        case .uv: return r.uv.map { L("자외선 최고 %d", $0) } ?? ""
        }
    }

    // MARK: 2 · image — the day as a picture

    private func imageLook(_ r: DayRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                DayPicture(record: r, character: model.shownCharacter)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        if !r.place.isEmpty { Text(r.place).font(.ui(14, .medium)).foregroundStyle(UI.sub) }
                        Spacer()
                        range(r, big: 34)
                    }
                    say(r)
                }
                .padding(16)
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
            alerts(r)
            // the day every three hours
            VStack(alignment: .leading, spacing: 12) {
                Text(L("시간별")).font(.px(15)).foregroundStyle(UI.ink)
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(stride(from: 0, to: 24, by: 3)), id: \.self) { h in
                        let mm = slotRain(r, h)
                        VStack(spacing: 6) {
                            Text(HourLabel.word(h, clock12: model.clock12)).font(.ui(12)).foregroundStyle(UI.sub).lineLimit(1).minimumScaleFactor(0.6)
                            PixelIcon(name: slotIcon(r, h), size: 28)
                            Text((r.temps ?? [])[safe: h].flatMap { $0 }.map { model.deg($0) } ?? "–").font(.px(15)).foregroundStyle(UI.ink)
                            Text(mm >= 0.1 ? DayLogText.mm(mm, snow: r.isSnow) : " ").font(.ui(11, .semibold)).foregroundStyle(Color(hex: "#3F6FD8")).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .card()
            tiles(r)
            moreRows(r)
        }
        .padding(.horizontal, 16)
    }

    // MARK: 3 · text — every number in a list

    private func textLook(_ r: DayRecord) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                if !r.place.isEmpty { Text(r.place).font(.ui(15, .medium)).foregroundStyle(UI.sub) }
                range(r, big: 44)
                if let s = r.say, s.count == 4 { Text("“\(s[3])”").font(.ui(16, .semibold)).foregroundStyle(UI.ink) }
            }
            .padding(.horizontal, 22).padding(.top, 6)
            if let a = r.alerts, !a.isEmpty {
                SectionLabel(text: L("특보"))
                RowGroup {
                    ForEach(Array(a.enumerated()), id: \.offset) { i, n in
                        SettingRow(icon: AlertBanner.icon(n), title: n) { EmptyView() }
                        if i < a.count - 1 { RowDivider() }
                    }
                }
            }
            SectionLabel(text: L("기온"))
            RowGroup {
                SettingRow(icon: "thermo_hot", title: L("최고")) { value(model.deg(r.hi)) }
                RowDivider()
                SettingRow(icon: "thermo_cold", title: L("최저")) { value(model.deg(r.lo)) }
                if let a = r.feelsLo, let b = r.feelsHi {
                    RowDivider()
                    SettingRow(icon: "sweat", title: L("체감")) { value("\(model.deg(a)) ~ \(model.deg(b))") }
                }
            }
            SectionLabel(text: L("비 · 바람"))
            RowGroup {
                SettingRow(icon: r.isSnow ? "snowflake" : "raincloud", title: r.isSnow ? L("눈") : L("비")) { value(rainText(r) ?? L("없음")) }
                if let w = r.windMax {
                    RowDivider()
                    SettingRow(icon: "wind", title: L("바람")) { value(L("최대 %@", model.windText(w))) }
                }
                if let h = r.rh {
                    RowDivider()
                    SettingRow(icon: "raindrop", title: L("습도")) { value("\(h)%") }
                }
            }
            SectionLabel(text: L("하늘 · 공기"))
            RowGroup {
                if let u = r.uv {
                    SettingRow(icon: "sun_strong", title: L("자외선")) { value(L("최고 %@", String(u))) }
                    RowDivider()
                }
                if let g = r.dust {
                    SettingRow(icon: "mask", title: L("미세먼지")) { AirGradeChip(grade: g, size: 13) }
                    RowDivider()
                }
                if let s = sun(r) {
                    SettingRow(icon: "sunrise", title: L("일출")) { value(s.0) }
                    RowDivider()
                    SettingRow(icon: "sunset", title: L("일몰")) { value(s.1) }
                }
            }
        }
    }

    // MARK: 4 · mixed — the picture beside the range, the temperature line, four tiles

    private func mixedLook(_ r: DayRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                DayPicture(record: r, character: model.shownCharacter)
                    .frame(width: 124, height: 124).clipShape(RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 8) {
                    if !r.place.isEmpty { Text(r.place).font(.ui(14, .medium)).foregroundStyle(UI.sub) }
                    range(r, big: 34)
                }
                Spacer(minLength: 0)
            }
            .card()
            say(r)
            alerts(r)
            if CalendarDayChart.series(.temp, r) != nil {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("기온")).font(.px(15)).foregroundStyle(UI.ink)
                    CalendarDayChart(metric: .temp, record: r, clock12: model.clock12, deg: model.deg, wind: model.windText, height: 190, pointLabels: true,
                                     windNumber: model.windNumber, windUnit: model.windUnit)
                }
                .card()
            }
            tiles(r)
            moreRows(r)
        }
        .padding(.horizontal, 16)
    }
}

private extension View {
    func card() -> some View {
        padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }
}
