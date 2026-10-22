import SwiftUI

// The widget faces, shared by the widget extension, the in-app preview page and onboarding.
// Sizes follow the iPhone 16 widget grid: small 170 x 170, medium 364 x 170.

struct WidgetBackground: View {
    let level: Int
    let night: Bool
    var scene: WeatherScene? = nil
    var animate = false        // widgets draw one still frame; the app's previews can move
    var body: some View {
        let bg = Rules.background[max(0, min(9, level))]
        ZStack {
            LinearGradient(colors: [Color(hex: bg), Color.mix(bg, "#8E9CC4", 0.28)], startPoint: .top, endPoint: .bottom)
            if let scene {
                SkyTint(scene: scene)
                GeometryReader { g in SkyParticles(scene: scene, width: g.size.width, tiles: 1, animate: animate) }
            } else if night {
                Color(red: 16 / 255, green: 20 / 255, blue: 48 / 255).opacity(0.64)
            }
        }
    }
}

private func sunsetTile(_ s: WeatherScene) -> String? {
    s.tiles.first { $0.icon == "sunset" || $0.icon == "sunrise" }?.value
}
private func chanceNow(_ s: WeatherScene) -> Int { s.hours.prefix(6).map { $0.chance }.max() ?? 0 }

/// Medium: place · sunset · issue time, character with its bubble on the left, temperature and five hours on the right.
struct MediumWidgetView: View {
    let snap: WeatherSnapshot
    var body: some View {
        let s = snap.scene, ink = Ink(night: s.isNight), lv = max(0, min(9, s.level))
        let rain = RainState(rawValue: s.rain) ?? .none
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(snap.placeShort).font(.px(11))
                if let t = sunsetTile(s) { PixelIcon(name: "sunset", size: 12); Text(t).font(.px(11)) }
                Spacer()
                Text(s.isPlus ? "\(s.updated) 받음" : "\(s.updated) 기준").font(.px(10)).opacity(0.75)
                PixelIcon(name: s.hours.first?.icon ?? "cloud", size: 16)
            }
            HStack(alignment: .bottom, spacing: 4) {
                ZStack(alignment: .top) {
                    CharacterSprite(character: snap.shownCharacter, level: lv, rain: rain, width: 92, animate: false)
                        .frame(width: 92, height: 107, alignment: .bottom).offset(y: 6)
                    if let b = s.bubble {
                        BubbleView(kind: b.kind, tone: b.tone, icon: b.icon, text: b.text, fontSize: 10).fixedSize().scaleEffect(0.9).offset(y: 2)
                    }
                }
                .frame(width: 110, height: 112, alignment: .bottom)
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("강수확률 \(chanceNow(s))%").font(.px(10))
                            Text("체감 \(snap.deg(s.feels))").font(.px(10))
                        }
                        Text(snap.deg(s.temp)).font(.px(34))
                    }
                    HStack(spacing: 0) {
                        ForEach(Array(s.hours.dropFirst().prefix(5).enumerated()), id: \.offset) { _, h in
                            VStack(spacing: 2) {
                                Text(snap.hourLabel(h.label)).font(.px(snap.clock12 ? 7 : 9)).opacity(0.8)
                                PixelIcon(name: h.icon, size: 16)
                                Text(snap.deg(h.temp)).font(.px(10))
                                Text(h.mm > 0 ? (h.mm == h.mm.rounded() ? "\(Int(h.mm))mm" : String(format: "%.1fmm", h.mm)) : "–")
                                    .font(.px(8)).foregroundStyle(h.mm > 0 ? ink.blue : ink.faint)
                            }.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .foregroundStyle(ink.ink)
    }
}

/// Small: place, icon; the character (bubble as an icon only) and the temperature.
struct SmallWidgetView: View {
    let snap: WeatherSnapshot
    var body: some View {
        let s = snap.scene, ink = Ink(night: s.isNight), lv = max(0, min(9, s.level))
        let rain = RainState(rawValue: s.rain) ?? .none
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(snap.placeShort).font(.px(11))
                Spacer()
                PixelIcon(name: s.hours.first?.icon ?? "cloud", size: 16)
            }
            HStack(alignment: .bottom, spacing: 0) {
                ZStack(alignment: .top) {
                    CharacterSprite(character: snap.shownCharacter, level: lv, rain: rain, width: 72, animate: false)
                        .frame(width: 72, height: 84, alignment: .bottom).offset(y: 10)
                    if let b = s.bubble {
                        BubbleView(kind: b.kind, tone: b.tone, icon: b.icon, text: "", fontSize: 10).fixedSize().offset(x: 0, y: 12)
                    }
                }
                .frame(width: 72, height: 112, alignment: .bottom)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(snap.deg(s.temp)).font(.px(30))
                    if let t = sunsetTile(s) { HStack(spacing: 2) { PixelIcon(name: "sunset", size: 11); Text(t).font(.px(9)) } }
                    Text("체감 \(snap.deg(s.feels))").font(.px(9))
                    Text("강수 \(chanceNow(s))%").font(.px(9))
                }
            }
        }
        .foregroundStyle(ink.ink)
    }
}

/// Lock screen, rectangular: white character silhouette, temperature, condition and the rain line.
struct LockRectangularView: View {
    let snap: WeatherSnapshot
    var body: some View {
        let s = snap.scene, lv = max(0, min(9, s.level))
        HStack(spacing: 6) {
            Image(snap.shownCharacter.lock(level: lv)).resizable().scaledToFit().frame(width: 40, height: 52)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) { PixelIcon(name: s.hours.first?.icon ?? "cloud", size: 12).colorMultiply(.white); Text(snap.deg(s.temp)).font(.system(size: 15, weight: .bold)) }
                Text(LockText.line(s)).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                Text("☂ \(chanceNow(s))% · \(snap.deg(s.lo))~\(snap.deg(s.hi))").font(.system(size: 11)).opacity(0.8)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Lock screen, circular: today's range as a gauge with the temperature in the middle.
struct LockCircularView: View {
    let snap: WeatherSnapshot
    var body: some View {
        let s = snap.scene
        let u = { (v: Int) -> Int in snap.unitF ? Int((Double(v) * 1.8 + 32).rounded()) : v }
        Gauge(value: Double(s.temp), in: Double(min(s.lo, s.temp))...Double(max(s.hi, s.temp, s.lo + 1))) {
            Text("°")
        } currentValueLabel: {
            Text("\(u(s.temp))").font(.system(size: 18, weight: .bold))
        } minimumValueLabel: {
            Text("\(u(s.lo))").font(.system(size: 9))
        } maximumValueLabel: {
            Text("\(u(s.hi))").font(.system(size: 9))
        }
        .gaugeStyle(.accessoryCircular)
    }
}

/// Lock screen, circular: chance of rain
struct LockRainCircularView: View {
    let snap: WeatherSnapshot
    var body: some View {
        let c = chanceNow(snap.scene)
        ZStack {
            AccessoryWidgetBackgroundCompat()
            VStack(spacing: 0) {
                Image(systemName: c >= 30 ? "umbrella.fill" : "umbrella").font(.system(size: 14, weight: .semibold))
                Text("\(c)%").font(.system(size: 14, weight: .bold))
            }
        }
    }
}

struct AccessoryWidgetBackgroundCompat: View {
    var body: some View { Circle().fill(Color.white.opacity(0.18)) }
}

enum LockText {
    /// One line for the lock screen: the bubble text when there is one, the condition otherwise.
    static func line(_ s: WeatherScene) -> String { s.bubble?.text ?? s.cond }
    /// Inline lock widget (above the clock): "☂ 15~17시 비 · 18°"
    static func inline(_ snap: WeatherSnapshot) -> String {
        let s = snap.scene
        let lead = (s.bubble?.icon.hasPrefix("umbrella") ?? false) ? "☂ " : ""
        return lead + line(s) + " · " + snap.deg(s.temp)
    }
}
