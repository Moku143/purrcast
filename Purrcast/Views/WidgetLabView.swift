import SwiftUI

/// The layout board's widget page (UI tests: -open widgetLab). Every widget at its real size on a 393-pt-wide iPhone,
/// home-screen ones on their own background, lock-screen ones on a lock-screen-like wallpaper, the watch app's first
/// page at the 46-mm screen's size, each in a box named lab-<widget> so the board can cut it out and let its parts
/// be moved.
struct WidgetLabView: View {
    @EnvironmentObject var model: AppModel

    /// -labPage2: the widgets that do not fit on the first page (the hourly 2×4)
    private var second: Bool { ProcessInfo.processInfo.arguments.contains("-labPage2") }
    /// -labPage3: the watch complications at their real sizes on a black face
    private var third: Bool { ProcessInfo.processInfo.arguments.contains("-labPage3") }
    /// -labPage4: the lock-screen widgets on a lock screen
    private var fourth: Bool { ProcessInfo.processInfo.arguments.contains("-labPage4") }
    /// -labStress: the longest words each language can put on a widget, to see what still fits
    private var stress: Bool { ProcessInfo.processInfo.arguments.contains("-labStress") }

    var body: some View {
        let snap = stress ? Self.stressed(model.snapshot) : model.snapshot
        if third { watchPage(snap) } else if fourth { lockPage(snap) } else if second {
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

    // MARK: page 4 — the lock screen as the phone shows it: wallpaper, the clock, the inline line above it, then
    // the widgets in their frosted glass (the system tints everything one colour; white here)
    private func lockPage(_ snap: WeatherSnapshot) -> some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(hex: "#3A4066"), Color(hex: "#1B1F3A")], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 10) {
                Text(LockText.inline(snap)).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                    .accessibilityIdentifier("lab-lock-inline")
                Text("9:41").font(.system(size: 88, weight: .bold)).foregroundStyle(.white).padding(.top, -8)
                HStack(alignment: .top, spacing: 10) {
                    glass("lab-lock-rect", 158, 72) { LockRectangularView(snap: snap) }
                    glass("lab-lock-temp", 72, 72, circle: true) { LockCircularView(snap: snap) }
                    glass("lab-lock-rain", 72, 72, circle: true) { LockRainCircularView(snap: snap) }
                }
                HStack(alignment: .top, spacing: 10) {
                    glass("lab-lock-dust", 72, 72, circle: true) { LockDustCircularView(snap: snap) }
                    glass("lab-lock-dust-2", 72, 72, circle: true) { LockDustCircularView(snap: Self.dusted(snap, grade: 1)) }
                    glass("lab-lock-dust-3", 72, 72, circle: true) { LockDustCircularView(snap: Self.dusted(snap, grade: 0)) }
                    glass("lab-lock-dust-4", 72, 72, circle: true) { LockDustCircularView(snap: Self.dusted(snap, grade: 2)) }
                }
                .padding(.top, 14)
                Text(L("위: 사각 · 기온 · 비 확률 — 아래: 미세먼지 (매우 나쁨 · 보통 · 좋음 · 나쁨)")).font(.ui(11)).foregroundStyle(.white.opacity(0.6)).padding(.top, 6)
            }
            .padding(.top, 70)
        }
    }

    /// The snapshot with its 미세먼지 at another step (for the lab's row of circles)
    static func dusted(_ base: WeatherSnapshot, grade: Int) -> WeatherSnapshot {
        var n = base
        let pm10: [Double] = [20, 60, 120, 200], pm25: [Double] = [10, 25, 50, 90]
        n.scene.dust = WeatherScene.Dust(pm10: pm10[grade], pm25: pm25[grade], pm10Grade: grade, pm25Grade: grade, grade: grade, note: "", src: "에어코리아", srcKey: "airkorea")
        return n
    }

    /// The system's frosted glass behind a lock-screen widget (white glyphs over it)
    private func glass<C: View>(_ id: String, _ w: CGFloat, _ h: CGFloat, circle: Bool = false, @ViewBuilder _ c: () -> C) -> some View {
        c().foregroundStyle(.white).frame(width: w, height: h)
            .padding(circle ? 0 : 8)
            .background(circle ? AnyShapeStyle(Color.clear) : AnyShapeStyle(Color.white.opacity(0.14)))
            .clipShape(RoundedRectangle(cornerRadius: circle ? w / 2 : 20, style: .continuous))
            .accessibilityElement(children: .contain).accessibilityIdentifier(id)
    }

    // MARK: page 3 — the watch complications at size, with the same views the watch extension draws: the analog
    // face (four corners + the cat in the lower sub-dial), the modular face (big slot + three circles), then each
    // circle, the corner pieces, the big rectangle, one line, and the Smart Stack card
    private func watchPage(_ snap: WeatherSnapshot) -> some View {
        let f = WatchFacts(snap: snap)
        return VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                WatchCase(scale: 0.9) { WatchAnalogPreview(snap: snap) }.accessibilityElement(children: .contain).accessibilityIdentifier("lab-watch-analog")
                WatchCase(scale: 0.9) { WatchFacePreview(snap: snap) }.accessibilityElement(children: .contain).accessibilityIdentifier("lab-watch-modular")
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    circle54 { WatchTempGauge(snap: snap) }.accessibilityIdentifier("lab-w-temp")
                    circle54 { WatchRainRing(snap: snap) }.accessibilityIdentifier("lab-w-rain")
                    circle54 { WatchFeelsDisc(snap: snap) }.accessibilityIdentifier("lab-w-feels")
                    circle54 { WatchSunDisc(snap: snap) }.accessibilityIdentifier("lab-w-sun")
                    WatchCatSlot(snap: snap).frame(width: 54, height: 54).accessibilityIdentifier("lab-w-cat")
                }
                HStack(spacing: 16) {
                    WatchCornerPreview(icon: f.icon, text: f.temp, color: .white)
                    WatchCornerPreview(icon: f.rainIcon, text: "\(f.chance)%", color: Color(hex: "#8EC5FF"))
                    WatchCornerPreview(icon: f.feelsIcon, text: f.feels, color: TempColor.of(f.s.feels))
                    WatchCornerPreview(icon: f.sun.icon, text: f.sun.time, color: Color(hex: "#FFD59A"))
                    if let d = snap.scene.dust { WatchCornerPreview(icon: DustFacts.icon(d), text: L(DustScale.words[max(0, min(3, d.grade))]), color: Color(hex: DustScale.colors[max(0, min(3, d.grade))])) }
                }
                .accessibilityElement(children: .contain).accessibilityIdentifier("lab-w-corners")
                WatchSummary(snap: snap).frame(width: 170).accessibilityIdentifier("lab-w-summary")
                Text(LockText.inline(snap)).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white).accessibilityIdentifier("lab-w-inline")
                WatchSummary(snap: snap, plate: true).padding(.horizontal, 8).frame(width: 170, height: 74)
                    .background(WatchSummaryPlate(snap: snap)).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityIdentifier("lab-w-stack")
            }
            .padding(14)
            .background(Color.black).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: "#ECEAF4"))
    }

    private func circle54<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        c().frame(width: 54, height: 54).background(Color(hex: "#1C1C20")).clipShape(Circle())
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
