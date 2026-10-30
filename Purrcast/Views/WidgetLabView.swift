import SwiftUI

/// The layout board's widget page (UI tests: -open widgetLab). Every widget at its real size on a 393-pt-wide iPhone,
/// home-screen ones on their own background, lock-screen ones on a lock-screen-like wallpaper, the watch app's first
/// page at the 46-mm screen's size, each in a box named lab-<widget> so the board can cut it out and let its parts
/// be moved.
struct WidgetLabView: View {
    @EnvironmentObject var model: AppModel

    /// -labPage2: the widgets that do not fit on the first page (the hourly 2×4)
    private var second: Bool { ProcessInfo.processInfo.arguments.contains("-labPage2") }
    /// -labStress: the longest words each language can put on a widget, to see what still fits
    private var stress: Bool { ProcessInfo.processInfo.arguments.contains("-labStress") }

    var body: some View {
        let snap = stress ? Self.stressed(model.snapshot) : model.snapshot
        if second {
            VStack(spacing: 16) {
                home("lab-hours", 364, 170, snap) { HoursWidgetView(snap: snap) }
            }
            .padding(.top, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(hex: "#ECEAF4"))
        } else {
            first(snap)
        }
    }

    private func first(_ snap: WeatherSnapshot) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                home("lab-small", 170, 170, snap) { SmallWidgetView(snap: snap) }
                WatchAppScreen(snap: snap).frame(width: 208, height: 248)
                    .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                    .accessibilityElement(children: .contain).accessibilityIdentifier("lab-watch")
            }
            home("lab-medium", 364, 170, snap) { MediumWidgetView(snap: snap) }
            HStack(alignment: .top, spacing: 12) {
                lock("lab-rect", 172, 76) { LockRectangularView(snap: snap) }
                lock("lab-circle", 76, 76, circle: true) { LockCircularView(snap: snap) }
                lock("lab-rain", 76, 76, circle: true) { LockRainCircularView(snap: snap) }
            }
            lock("lab-inline", 257, 26) {
                Text(LockText.inline(snap)).font(.system(size: 15, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            // 미세먼지 on the lock screen, beside the temperature circle it matches
            HStack(alignment: .top, spacing: 12) {
                lock("lab-circle-2", 76, 76, circle: true) { LockCircularView(snap: snap) }
                lock("lab-dust-circle", 76, 76, circle: true) { LockDustCircularView(snap: snap) }
            }
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: "#ECEAF4"))
    }

    /// The widest content each language can produce: a long place, minus temperatures, 12-hour clocks, 100 %,
    /// the longest weather word and warning name, rain amounts with a decimal.
    static func stressed(_ base: WeatherSnapshot) -> WeatherSnapshot {
        var n = base, s = n.scene
        let lang = Lang.current
        n.placeShort = lang == .en ? "Rancho Cucamonga" : lang == .ja ? "南アルプス市" : "종로1·2·3·4가동"
        n.clock12 = true; n.unitF = false
        s.temp = -12; s.feels = -19; s.hi = -5; s.lo = -15; s.level = 13; s.rain = "umbrella"
        s.cond = lang == .en ? "Very heavy rain" : lang == .ja ? "晴れ時々曇り" : "매우 강한 비"
        s.bubble = WeatherScene.Bubble(kind: "shout", tone: "coral", icon: "exclaim",
                                       text: lang == .en ? "Winter Weather Advisory" : lang == .ja ? "大雨注意報" : "호우주의보")
        s.updated = "23:59"
        for i in s.tiles.indices where s.tiles[i].icon == "sunset" || s.tiles[i].icon == "sunrise" {
            s.tiles[i].value = HourLabel.clock(22 * 60 + 58, clock12: true)
        }
        for i in s.hours.indices {
            s.hours[i].label = i == 0 ? L("지금") : HourLabel.word(9 + i, clock12: false)   // 10 … → 오전 10시 · 10AM · 午前10時
            s.hours[i].temp = -10 - i % 5; s.hours[i].chance = 100; s.hours[i].mm = 9.9; s.hours[i].icon = "raincloud"
        }
        for i in s.days.indices { s.days[i].chance = 100; s.days[i].lo = -15; s.days[i].hi = -5 }
        n.scene = s
        return n
    }

    private func home<C: View>(_ id: String, _ w: CGFloat, _ h: CGFloat, _ snap: WeatherSnapshot, @ViewBuilder _ c: () -> C) -> some View {
        c().padding(16).frame(width: w, height: h)
            .background(WidgetBackground(level: snap.scene.level, night: snap.scene.isNight, scene: snap.scene))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .accessibilityElement(children: .contain).accessibilityIdentifier(id)
    }

    private func lock<C: View>(_ id: String, _ w: CGFloat, _ h: CGFloat, circle: Bool = false, @ViewBuilder _ c: () -> C) -> some View {
        c().foregroundStyle(.white).frame(width: w, height: h)
            .padding(circle ? 0 : 6)
            .background(LinearGradient(colors: [Color(hex: "#5B5FA8"), Color(hex: "#2E2F66")], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: circle ? w / 2 + 6 : 12, style: .continuous))
            .accessibilityElement(children: .contain).accessibilityIdentifier(id)
    }
}
