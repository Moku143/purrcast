import SwiftUI

// The Apple Watch slots from the design (워치 페이스 · 아날로그 / 모듈러, 스마트 스택), drawn in colour: watchOS shows
// complications in full colour unless the person picks one colour for the face (then it tints them itself).
// The watch extension puts these in its widgets; the phone draws the same views for the Plus page and the matrix.

/// A temperature as a colour: blue −5° · teal 5° · green 12° · yellow 18° · orange 24° · red 32° (the design's scale).
enum TempColor {
    private static let stops: [(t: Double, r: Double, g: Double, b: Double)] =
        [(-5, 91, 140, 255), (5, 76, 195, 181), (12, 140, 210, 110), (18, 242, 200, 60), (24, 255, 160, 70), (32, 255, 100, 80)]
    static func of(_ v: Int) -> Color {
        var k = 0
        while k < stops.count - 2 && Double(v) > stops[k + 1].t { k += 1 }
        let a = stops[k], b = stops[k + 1]
        let f = max(0, min(1, (Double(v) - a.t) / (b.t - a.t)))
        return Color(red: (a.r + (b.r - a.r) * f) / 255, green: (a.g + (b.g - a.g) * f) / 255, blue: (a.b + (b.b - a.b) * f) / 255)
    }
}

/// What the watch slots say, from one snapshot.
struct WatchFacts {
    let snap: WeatherSnapshot
    var s: WeatherScene { snap.scene }
    var level: Int { max(0, min(9, s.level)) }
    var rain: RainState { RainState(rawValue: s.rain) ?? .none }
    var icon: String { s.hours.first?.icon ?? "cloud" }
    var temp: String { snap.deg(s.temp) }
    var feels: String { snap.deg(s.feels) }
    var chance: Int { s.hours.prefix(6).map { $0.chance }.max() ?? 0 }
    var rainIcon: String { chance >= 50 ? "umbrella" : "raindrop" }
    var feelsIcon: String { s.feels <= 5 ? "thermo_cold" : "thermo_hot" }
    /// The next sunset (or sunrise at night) and its time.
    var sun: (icon: String, time: String) {
        let t = s.tiles.first { $0.icon == "sunset" || $0.icon == "sunrise" }
        return (t?.icon ?? (s.isNight ? "sunrise" : "sunset"), t?.value ?? "--:--")
    }
    /// The bubble's words, or the weather in one word.
    var head: String { s.bubble?.text ?? cond }
    var headIcon: String { s.bubble.map { $0.icon == "none" ? icon : $0.icon } ?? icon }
    var cond: String { s.cond.components(separatedBy: " · ").first ?? s.cond }
    var range: String {
        L("최고 %@ · 최저 %@", snap.deg(s.hi), snap.deg(s.lo)) + (chance >= 10 ? " · " + L("강수 %d%%", chance) : "")
    }
    var sprite: String { snap.shownCharacter.stand(level: level, rain: rain) }
}

// MARK: corners (analog face): an icon in the corner, one number along the rim

/// One corner as the phone previews it (on the watch, the number is the corner's curved label).
struct WatchCornerPreview: View {
    let icon: String
    let text: String
    let color: Color
    var leading = true
    var body: some View {
        HStack(spacing: 4) {
            if leading { PixelIcon(name: icon, size: 18) }
            Text(text).font(.px(14)).foregroundStyle(color)
            if !leading { PixelIcon(name: icon, size: 18) }
        }
    }
}

// MARK: circular slots

/// The whole cat in today's outfit, small and without a plate (the analog face's lower sub-dial).
struct WatchCatSlot: View {
    let snap: WeatherSnapshot
    var body: some View {
        Image(WatchFacts(snap: snap).sprite).resizable().interpolation(.high).scaledToFit()
    }
}

/// The cat's head and shoulders in a disc of today's outfit colour (the modular face's third circle).
struct WatchCatDisc: View {
    let snap: WeatherSnapshot
    var body: some View {
        let f = WatchFacts(snap: snap)
        GeometryReader { g in
            let d = min(g.size.width, g.size.height), k = d / 54
            ZStack {
                Circle().fill(Color(hex: Rules.background[f.level]))
                Image(f.sprite).resizable().interpolation(.high)
                    .frame(width: 96 * k, height: 112 * k)
                    .position(x: d / 2, y: 112 * k / 2 - 5 * k)
            }
            .frame(width: d, height: d).clipShape(Circle())
        }
    }
}

/// Today's low → high as an arc coloured by temperature, the temperature now in the middle.
struct WatchTempGauge: View {
    let snap: WeatherSnapshot
    var body: some View {
        let s = snap.scene, u = { (v: Int) -> Int in snap.unitF ? Int((Double(v) * 1.8 + 32).rounded()) : v }
        Gauge(value: Double(s.temp), in: Double(min(s.lo, s.temp))...Double(max(s.hi, s.temp, s.lo + 1))) {
            Text("°")
        } currentValueLabel: {
            Text("\(u(s.temp))°").font(.px(15))
        } minimumValueLabel: {
            Text("\(u(s.lo))").font(.system(size: 9, weight: .semibold)).foregroundStyle(Color(hex: "#9EA3B5"))
        } maximumValueLabel: {
            Text("\(u(s.hi))").font(.system(size: 9, weight: .semibold)).foregroundStyle(Color(hex: "#9EA3B5"))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(Gradient(colors: [TempColor.of(s.lo), TempColor.of(s.hi)]))
    }
}

/// Chance of rain as a blue ring, the umbrella (or a drop) and the percentage inside.
struct WatchRainRing: View {
    let snap: WeatherSnapshot
    var body: some View {
        let f = WatchFacts(snap: snap)
        Gauge(value: Double(f.chance), in: 0...100) {
            Text("%")
        } currentValueLabel: {
            VStack(spacing: 1) {
                PixelIcon(name: f.rainIcon, size: 13)
                Text("\(f.chance)%").font(.px(10))
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(Color(hex: "#5AA0FF"))
    }
}

/// Feels-like in a circle: the thermometer and the number in its colour.
struct WatchFeelsDisc: View {
    let snap: WeatherSnapshot
    var body: some View {
        let f = WatchFacts(snap: snap)
        VStack(spacing: 1) {
            PixelIcon(name: f.feelsIcon, size: 16)
            Text(f.feels).font(.px(13)).foregroundStyle(TempColor.of(f.s.feels))
        }
    }
}

/// The next sunset or sunrise in a circle.
struct WatchSunDisc: View {
    let snap: WeatherSnapshot
    var body: some View {
        let f = WatchFacts(snap: snap)
        VStack(spacing: 1) {
            PixelIcon(name: f.sun.icon, size: 16)
            Text(f.sun.time).font(.px(11)).foregroundStyle(Color(hex: "#FFD59A"))
        }
    }
}

// MARK: rectangular

/// The big slot. On a face (black): the bubble's words in orange with its icon, the temperature with feels-like and
/// the weather, then high · low · rain. In the Smart Stack (on its own colour plate): the cat at the left, the words
/// as a white chip, then the same numbers.
struct WatchSummary: View {
    let snap: WeatherSnapshot
    var plate = false
    var body: some View {
        let f = WatchFacts(snap: snap), s = f.s
        if plate {
            let ink = s.isNight ? Color(hex: "#F3F5FF") : Color(hex: "#1A2440")
            HStack(alignment: .bottom, spacing: 4) {
                Image(f.sprite).resizable().interpolation(.high).scaledToFit()
                    .frame(width: 54).padding(.bottom, -6)
                VStack(alignment: .leading, spacing: 4) {
                    if s.bubble != nil {
                        HStack(spacing: 3) {
                            PixelIcon(name: f.headIcon, size: 11)
                            Text(f.head).font(.px(10)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(Color(hex: "#1A2440"))
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(Color.white)
                        .overlay(Rectangle().stroke(Color(hex: "#1A2440"), lineWidth: 1.5))
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(f.temp).font(.px(26))
                        Text(f.cond).font(.px(10)).lineLimit(1)
                    }
                    Text(L("체감 %@", f.feels) + (f.chance >= 10 ? " · " + L("강수 %d%%", f.chance) : "")).font(.px(9)).opacity(0.85).lineLimit(1)
                }
                .foregroundStyle(ink)
                Spacer(minLength: 0)
            }
        } else {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    PixelIcon(name: f.headIcon, size: 15)
                    Text(f.head).font(.px(13)).foregroundStyle(Color(hex: "#FFB08A")).lineLimit(1).minimumScaleFactor(0.7)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(f.temp).font(.px(24)).foregroundStyle(.white)
                    Text(L("체감 %@", f.feels) + " · " + f.cond).font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "#9EA3B5")).lineLimit(1).minimumScaleFactor(0.8)
                }
                Text(f.range).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(hex: "#9EA3B5"))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The Smart Stack plate behind `WatchSummary(plate: true)`: today's outfit colour (deep blue at night).
struct WatchSummaryPlate: View {
    let snap: WeatherSnapshot
    var body: some View {
        let s = snap.scene
        s.isNight ? Color(hex: "#1B2142") : Color(hex: Rules.background[max(0, min(9, s.level))])
    }
}
