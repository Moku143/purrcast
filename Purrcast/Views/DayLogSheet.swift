import SwiftUI

/// A 날씨 기록 day that has no hours to chart (only its observed summary from the server, or a day kept from long
/// ago): its numbers in grouped rows, like the settings. A day with hours opens the day sheet itself (DayDetailView).
struct DayLogSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let key: String
    let record: DayRecord?

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: DayLogText.dayLong(key), trailing: L("닫기")) { dismiss() }
            ScrollView(showsIndicators: false) {
                if let r = record {
                    list(r).padding(.bottom, 30)
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

    private func value(_ t: String) -> some View { Text(t).font(.px(15)).foregroundStyle(UI.ink) }

    /// "15~19시 · 5.5mm"
    private func rainText(_ r: DayRecord) -> String? {
        guard r.isWet else { return nil }
        let amount = r.mm > 0 ? DayLogText.mm(r.mm, snow: r.isSnow) : nil
        let when = r.wetHours.map { HourLabel.window($0.0, $0.1, clock12: model.clock12) }
        let t = [when, amount].compactMap { $0 }.joined(separator: " · ")
        return t.isEmpty ? (r.isSnow ? L("눈 온 날") : L("비 온 날")) : t
    }

    private func sun(_ r: DayRecord) -> (String, String)? {
        guard let la = r.lat, let lo = r.lon, let d = DayLog.date(key) else { return nil }
        let tz = TimeZone(identifier: model.currentPlace.timeZone) ?? .current
        guard let s = SunTimes.day(d, lat: la, lon: lo, tz: tz) else { return nil }
        var c = Calendar(identifier: .gregorian); c.timeZone = tz
        let t: (Date) -> String = { HourLabel.clock(c.component(.hour, from: $0) * 60 + c.component(.minute, from: $0), clock12: model.clock12) }
        return (t(s.rise), t(s.set))
    }

    private func list(_ r: DayRecord) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                DayFigure(character: r.character ?? model.shownCharacter, level: r.level, width: 84)
                VStack(alignment: .leading, spacing: 6) {
                    if !r.place.isEmpty { Text(r.place).font(.ui(14, .medium)).foregroundStyle(UI.sub) }
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        PixelIcon(name: r.icon, size: 30).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 4 }
                        Text(model.deg(r.hi)).font(.px(40)).foregroundStyle(UI.ink)
                        Text(model.deg(r.lo)).font(.px(25)).foregroundStyle(UI.sub)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22).padding(.top, 6)
            SectionLabel(text: L("기온"))
            RowGroup {
                SettingRow(icon: "thermo_hot", title: L("최고")) { value(model.deg(r.hi)) }
                RowDivider()
                SettingRow(icon: "thermo_cold", title: L("최저")) { value(model.deg(r.lo)) }
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
            if r.uv != nil || r.dust != nil || sun(r) != nil {
                SectionLabel(text: L("하늘 · 공기"))
                RowGroup {
                    if let u = r.uv {
                        SettingRow(icon: "sun_strong", title: L("자외선")) { value(L("최고 %@", String(u))) }
                    }
                    if let g = r.dust {
                        if r.uv != nil { RowDivider() }
                        SettingRow(icon: "mask", title: L("미세먼지")) { AirGradeChip(grade: g, size: 13) }
                    }
                    if let s = sun(r) {
                        if r.uv != nil || r.dust != nil { RowDivider() }
                        SettingRow(icon: "sunrise", title: L("일출")) { value(s.0) }
                        RowDivider()
                        SettingRow(icon: "sunset", title: L("일몰")) { value(s.1) }
                    }
                }
            }
        }
    }
}
