import SwiftUI

/// The modular face as it looks with the Purrcast complications (Plus page, matrix): date and time, the big slot
/// (the bubble's words, temperature, feels-like, high · low · rain), and three circles (today's range gauge,
/// chance of rain, the cat). Drawn with the same views the complications use.
struct WatchFacePreview: View {
    let snap: WeatherSnapshot
    private let accent = Color(hex: "#FF9F43")

    private var dateText: String {
        let f = DateFormatter(); f.locale = Lang.current.locale
        f.setLocalizedDateFormatFromTemplate("EEEd")
        return f.string(from: WatchClock.date)
    }

    var body: some View {
        ZStack {
            Color.black
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(dateText).font(.system(size: 14, weight: .semibold)).foregroundStyle(accent)
                        .lineLimit(1).minimumScaleFactor(0.7).probe("date")
                    Spacer(minLength: 0)
                    Text(WatchClock.now(clock12: snap.clock12)).font(.system(size: 40, weight: .light)).foregroundStyle(.white)
                        .lineLimit(1).fixedSize().probe("time")
                }
                WatchSummary(snap: snap).padding(.top, 12).probe("rect")
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    WatchTempGauge(snap: snap).foregroundStyle(.white).frame(width: 52, height: 52).probe("gauge")
                    Spacer(minLength: 0)
                    WatchRainRing(snap: snap).foregroundStyle(.white).frame(width: 52, height: 52).probe("rainCircle")
                    Spacer(minLength: 0)
                    WatchCatSlot(snap: snap).frame(width: 52, height: 52).probe("faceCircle")   // the whole cat, as the complication shows
                }
            }
            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 14)
        }
    }
}

/// An analog face with the Purrcast complications, as in the design: a pixel icon in each corner with one number
/// (temperature · chance of rain · feels-like in its colour · the next sunset or sunrise), and the cat in today's
/// outfit standing in the lower sub-dial. On the watch the corner numbers curve along the rim.
struct WatchAnalogPreview: View {
    let snap: WeatherSnapshot
    var body: some View {
        let f = WatchFacts(snap: snap)
        GeometryReader { g in
            let w = g.size.width, h = g.size.height, c = CGPoint(x: w / 2, y: h / 2), k = w / 208
            ZStack {
                Color.black
                // the cat under the centre (6 o'clock side), no plate
                WatchCatSlot(snap: snap).frame(width: 44 * k, height: 51 * k).position(x: c.x, y: c.y + 52 * k).probe("cat")
                Canvas { ctx, _ in
                    func pt(_ r: CGFloat, _ deg: Double) -> CGPoint {
                        CGPoint(x: c.x + r * k * CGFloat(sin(deg * .pi / 180)), y: c.y - r * k * CGFloat(cos(deg * .pi / 180)))
                    }
                    for i in 0..<60 {
                        var p = Path(); p.move(to: pt(92, Double(i) * 6)); p.addLine(to: pt(i % 5 == 0 ? 80 : 87, Double(i) * 6))
                        ctx.stroke(p, with: .color(i % 5 == 0 ? .white : .white.opacity(0.35)),
                                   style: StrokeStyle(lineWidth: (i % 5 == 0 ? 3 : 1.2) * k, lineCap: .round))
                    }
                    let now = Calendar.current.dateComponents([.hour, .minute, .second], from: WatchClock.date)
                    let hr = Double((now.hour ?? 10) % 12) * 30 + Double(now.minute ?? 9) * 0.5, mn = Double(now.minute ?? 9) * 6, sc = Double(now.second ?? 36) * 6
                    let hands: [(len: Double, deg: Double, width: Double, color: Color)] =
                        [(42, hr, 6, .white), (68, mn, 4, .white), (76, sc, 1.6, Color(hex: "#FF9F43"))]
                    for (len, deg, width, color) in hands {
                        var p = Path(); p.move(to: c); p.addLine(to: pt(CGFloat(len), deg))
                        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: CGFloat(width) * k, lineCap: .round))
                    }
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - 4 * k, y: c.y - 4 * k, width: 8 * k, height: 8 * k)), with: .color(Color(hex: "#FF9F43")))
                }
                VStack {
                    HStack {
                        WatchCornerPreview(icon: f.icon, text: f.temp, color: .white).probe("cornerTL")
                        Spacer(minLength: 0)
                        WatchCornerPreview(icon: f.rainIcon, text: "\(f.chance)%", color: Color(hex: "#8EC5FF"), leading: false).probe("cornerTR")
                    }
                    Spacer(minLength: 0)
                    HStack {
                        WatchCornerPreview(icon: f.feelsIcon, text: f.feels, color: TempColor.of(f.s.feels)).probe("cornerBL")
                        Spacer(minLength: 0)
                        WatchCornerPreview(icon: f.sun.icon, text: f.sun.time, color: Color(hex: "#FFD59A"), leading: false).probe("cornerBR")
                    }
                }
                .padding(16 * k)
            }
        }
    }
}

/// The watch app's hours page as the watch draws it (the first-run page): the time at the top right, then rows.
struct WatchListPreview: View {
    let snap: WeatherSnapshot
    var body: some View {
        let s = snap.scene
        ZStack(alignment: .topTrailing) {
            Color.black
            VStack(spacing: 8) {
                ForEach(Array(s.hours.prefix(3).enumerated()), id: \.offset) { _, h in
                    HStack(spacing: 8) {
                        Text(snap.hourLabel(h.label)).font(.px(snap.clock12 ? 10 : 13)).lineLimit(1).minimumScaleFactor(0.6).frame(width: 46, alignment: .leading)
                        PixelIcon(name: h.icon, size: 20)
                        Spacer()
                        if h.chance >= 10 { Text("\(h.chance)%").font(.px(11)).foregroundStyle(Color(hex: "#9CC0FF")) }
                        Text(snap.deg(h.temp)).font(.px(15))
                    }
                    .padding(.horizontal, 12).frame(height: 44)
                    .background(Color(hex: "#1C1C20")).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .foregroundStyle(.white).padding(.horizontal, 10).padding(.top, 40)
            Text(WatchClock.now(clock12: snap.clock12)).font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white).padding(.top, 9).padding(.trailing, 22)
        }
    }
}

/// The time the pictures show: now, as the watch would (12- or 24-hour), or a set time for the App Store pictures
/// (-storeTime 10:09, debug builds).
enum WatchClock {
    static var date: Date {
        #if DEBUG
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "-storeTime"), i + 1 < a.count {
            let p = a[i + 1].split(separator: ":").compactMap { Int($0) }
            if p.count == 2, let d = Calendar.current.date(bySettingHour: p[0], minute: p[1], second: 36, of: Date()) { return d }
        }
        #endif
        return Date()
    }
    static func now(clock12: Bool) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = clock12 ? "h:mm" : "HH:mm"
        return f.string(from: date)
    }
}

/// The App Store pictures of the faces (-watchFace analog | modular, debug builds): the face at the 46-mm watch's
/// size (208 × 248 pt) in the middle of a black screen. On a 2× phone that is the store's 416 × 496 pixels, cut out.
struct WatchFaceShot: View {
    @EnvironmentObject var model: AppModel
    let kind: String
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Group {
                if kind == "modular" { WatchFacePreview(snap: model.snapshot) } else { WatchAnalogPreview(snap: model.snapshot) }
            }
            .frame(width: 208, height: 248)
        }
    }
}

/// The watch app's first page next to a watch face with the complications, each in an Apple Watch case — the Plus
/// page and the first-run page show the person's own place and weather in them. `scale` sets the size (0.57 →
/// 122-pt cases).
struct WatchPairPreview: View {
    let snap: WeatherSnapshot
    var scale: CGFloat = 0.57
    var body: some View {
        HStack(spacing: 16 * scale / 0.57) {
            WatchCase(scale: scale) { WatchAppScreen(snap: snap) }
            WatchCase(scale: scale) { WatchFacePreview(snap: snap) }
        }
    }
}

/// An Apple Watch: dark case, crown and side button, the screen drawn at the watch's own size (184 × 224) and scaled.
struct WatchCase<Content: View>: View {
    var scale: CGFloat
    @ViewBuilder var content: Content
    var body: some View {
        let k = scale / 0.57
        ZStack {
            RoundedRectangle(cornerRadius: 36 * k, style: .continuous).fill(Color(hex: "#111114"))
                .frame(width: 122 * k, height: 146 * k)
                .shadow(color: .black.opacity(0.25), radius: 8 * k, y: 5 * k)
            content.frame(width: 184, height: 224)
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                .scaleEffect(scale)
                .frame(width: 184 * scale, height: 224 * scale)
        }
        .overlay(alignment: .trailing) {
            VStack(spacing: 10 * k) {
                Capsule().fill(Color(hex: "#3A3A40")).frame(width: 5 * k, height: 20 * k)    // crown
                Capsule().fill(Color(hex: "#2A2A30")).frame(width: 4 * k, height: 26 * k)    // side button
            }.offset(x: 4 * k, y: -6 * k)
        }
        .accessibilityHidden(true)
    }
}

/// The watch app's first page as the watch shows it: the sky to the edges, the place in the clock's row, the time
/// at the top right.
struct WatchAppScreen: View {
    let snap: WeatherSnapshot
    var body: some View {
        ZStack(alignment: .topTrailing) {
            WatchNow(snap: snap)
            Text(WatchClock.now(clock12: snap.clock12)).font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
                .shadow(color: .black.opacity(0.25), radius: 1.5).probe("clock")
                .accessibilityHidden(true)      // the system's clock: not a part to move on the layout board
                .padding(.top, 9).padding(.trailing, 22)
        }
    }
}
