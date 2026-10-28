import SwiftUI

// The widget faces, shared by the widget extension, the in-app preview page and onboarding.
// Sizes follow the iPhone 16 widget grid: small 170 x 170, medium 364 x 170.

/// The sky behind everything (app and widgets): the outfit colour as a see-through wash over a pale sky by day
/// (a deep one by night), thinning towards the bottom, with soft light from above — so it reads as air and depth
/// rather than one flat sheet of colour.
struct SkyBase: View {
    let level: Int
    let night: Bool
    var body: some View {
        let bg = Rules.background[Rules.clamp(level)]
        GeometryReader { g in
            let r = max(g.size.width, g.size.height)
            ZStack {
                Color(hex: night ? "#0B0F24" : "#F2F5FB")
                if night {
                    LinearGradient(stops: [.init(color: Color(hex: bg).opacity(0.92), location: 0), .init(color: Color(hex: bg).opacity(0.78), location: 0.35),
                                           .init(color: Color.mix(bg, "#0B0F24", 0.78), location: 0.66), .init(color: Color(hex: "#0B0F22"), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                } else {
                    LinearGradient(stops: [.init(color: Color(hex: bg).opacity(0.92), location: 0), .init(color: Color(hex: bg).opacity(0.76), location: 0.5),
                                           .init(color: Color.mix(bg, "#8E9CC4", 0.34).opacity(0.72), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
                // light from above, and a thin bright haze low in the sky
                RadialGradient(colors: [Color.white.opacity(night ? 0.08 : 0.50), Color.white.opacity(0)],
                               center: UnitPoint(x: 0.85, y: -0.05), startRadius: 0, endRadius: r * 0.9)
                LinearGradient(stops: [.init(color: .white.opacity(0), location: 0.45), .init(color: .white.opacity(night ? 0.04 : 0.22), location: 0.7),
                                       .init(color: .white.opacity(0), location: 0.95)], startPoint: .top, endPoint: .bottom)
            }
        }
    }
}

struct WidgetBackground: View {
    let level: Int
    let night: Bool
    var scene: WeatherScene? = nil
    var animate = false        // widgets draw one still frame; the app's previews can move
    var body: some View {
        ZStack {
            SkyBase(level: level, night: false)      // night comes from the sky's own night wash (or the veil below)
            if let scene {
                SkyTint(scene: scene)
                GeometryReader { g in
                    // the sky picture is a wide strip: repeat its rain / snow / wind / fog down the whole surface
                    // (a small widget or the watch is taller than one strip, and the character stands in the lower part)
                    let stripH = Sky.tile.height * g.size.width / Sky.tile.width
                    SkyParticles(scene: scene, width: g.size.width, tiles: max(1, Int((g.size.height / stripH).rounded(.up))), animate: animate)
                }
            } else if night {
                Color(red: 16 / 255, green: 20 / 255, blue: 48 / 255).opacity(0.64)
            }
        }
    }
}

func sunsetTile(_ s: WeatherScene) -> String? {
    s.tiles.first { $0.icon == "sunset" || $0.icon == "sunrise" }?.value
}
/// Where a bubble's tail should sit: `gap` points above the character's head (ears included), or above the open
/// umbrella — measured per outfit from the sprites (anchors.json), so a hood or a hat never touches the bubble.
func bubbleBottom(_ c: PurrCharacter, _ rain: RainState, level: Int, spriteHeight h: CGFloat, gap: CGFloat = 5) -> CGFloat {
    let a = c.anchors, lv = Rules.clamp(level)
    let top = CGFloat(rain == .umbrella ? a.umb_top[lv] : a.head_top[lv]) / Sprite.height
    return h * (1 - top) + gap
}
private func chanceNow(_ s: WeatherScene) -> Int { s.hours.prefix(6).map { $0.chance }.max() ?? 0 }

/// Medium: place · sunset · issue time, character with its bubble on the left, temperature and five hours on the right.
struct MediumWidgetView: View {
    let snap: WeatherSnapshot
    var body: some View {
        let s = snap.scene, ink = Ink(night: s.isNight), lv = Rules.clamp(s.level)
        let rain = RainState(rawValue: s.rain) ?? .none
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(snap.placeShort).font(.px(11)).probe("place")
                if let t = sunsetTile(s) { PixelIcon(name: "sunset", size: 12).probe("sunsetIcon"); Text(t).font(.px(11)).probe("sunsetText") }
                Spacer()
                Text(s.isPlus ? L("%@ 받음", s.updated) : L("%@ 기준", s.updated)).font(.px(10)).opacity(0.75).probe("issued")
                PixelIcon(name: s.hours.first?.icon ?? "cloud", size: 16).probe("icon")
            }
            HStack(alignment: .bottom, spacing: 4) {
                ZStack(alignment: .bottom) {
                    // 86 pt wide so a bubble over the open umbrella still clears the top row
                    CharacterSprite(character: snap.shownCharacter, level: lv, rain: rain, width: 86, animate: false).probe("cat")
                        .frame(width: 86, height: 100, alignment: .bottom)
                    if let b = s.bubble {
                        BubbleView(kind: b.kind, tone: b.tone, icon: b.icon, text: Compact.bubbleWord(s, max: 9), fontSize: 10).fixedSize().probe("bubble").scaleEffect(0.85, anchor: .bottom)
                            .padding(.bottom, bubbleBottom(snap.shownCharacter, rain, level: lv, spriteHeight: 100, gap: 4))
                    }
                }
                .frame(width: 110, height: 126, alignment: .bottom).offset(y: 9)
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(L("강수확률 %d%%", chanceNow(s))).font(.px(10)).probe("chance")
                            Text(L("체감 %@", snap.deg(s.feels))).font(.px(10)).probe("feels")
                        }
                        Text(snap.deg(s.temp)).font(.px(34)).probe("temp")
                    }
                    HStack(spacing: 0) {
                        ForEach(Array(s.hours.dropFirst().prefix(5).enumerated()), id: \.offset) { i, h in
                            VStack(spacing: 2) {
                                Text(snap.hourLabel(h.label)).font(.px(snap.clock12 ? 7 : 9)).opacity(0.8).probe("h\(i)label")
                                PixelIcon(name: h.icon, size: 16).probe("h\(i)icon")
                                Text(snap.deg(h.temp)).font(.px(10)).probe("h\(i)temp")
                                Text(h.mm > 0 ? (h.mm == h.mm.rounded() ? "\(Int(h.mm))mm" : String(format: "%.1fmm", h.mm)) : "–")
                                    .font(.px(8)).foregroundStyle(h.mm > 0 ? ink.blue : ink.faint).probe("h\(i)mm")
                            }.frame(maxWidth: .infinity).probe("h\(i)")
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
        let s = snap.scene, ink = Ink(night: s.isNight), lv = Rules.clamp(s.level)
        let rain = RainState(rawValue: s.rain) ?? .none
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(snap.placeShort).font(.px(11)).probe("place")
                Spacer()
                PixelIcon(name: s.hours.first?.icon ?? "cloud", size: 16).probe("icon")
            }
            HStack(alignment: .bottom, spacing: 0) {
                ZStack(alignment: .bottom) {
                    CharacterSprite(character: snap.shownCharacter, level: lv, rain: rain, width: 72, animate: false).probe("cat")
                        .frame(width: 72, height: 84, alignment: .bottom)
                    if let b = s.bubble {
                        // a word ("비", "한파", "폭염") fits above the head; longer names show just the icon here
                        BubbleView(kind: b.kind, tone: b.tone, icon: b.icon, text: Compact.bubbleWord(s, max: 5), fontSize: 9).fixedSize().probe("bubble")
                            .scaleEffect(0.85, anchor: .bottom)
                            .padding(.bottom, bubbleBottom(snap.shownCharacter, rain, level: lv, spriteHeight: 84))
                    }
                }
                .frame(width: 80, height: 118, alignment: .bottom).offset(y: 8)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(snap.deg(s.temp)).font(.px(30)).probe("temp")
                    if let t = sunsetTile(s) { HStack(spacing: 2) { PixelIcon(name: "sunset", size: 11).probe("sunsetIcon"); Text(t).font(.px(9)).probe("sunsetText") } }
                    Text(L("체감 %@", snap.deg(s.feels))).font(.px(9)).probe("feels")
                    Text(L("강수 %d%%", chanceNow(s))).font(.px(9)).probe("chance")
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
        let s = snap.scene, lv = Rules.clamp(s.level)
        HStack(spacing: 6) {
            Image(snap.shownCharacter.lock(level: lv)).resizable().scaledToFit().frame(width: 40, height: 52)
                .opacity(0.62)     // see-through, like the system's own lock-screen glyphs
                .probe("lockCat")
            VStack(alignment: .leading, spacing: 1) {
                Text(snap.deg(s.temp)).font(.system(size: 15, weight: .semibold)).opacity(0.92).probe("lockTemp")
                Text(LockText.line(s)).font(.ui(12, .medium)).lineLimit(1).opacity(0.85).probe("lockLine")
                Text("\(Compact.tail(s, deg: snap.deg)) · \(snap.deg(s.lo))~\(snap.deg(s.hi))").font(.ui(11)).opacity(0.65).probe("lockTail")
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
        ZStack {
        AccessoryWidgetBackgroundCompat()      // the soft glass disc behind it, like the rain-chance circle
        Gauge(value: Double(s.temp), in: Double(min(s.lo, s.temp))...Double(max(s.hi, s.temp, s.lo + 1))) {
            Text("°")
        } currentValueLabel: {
            Text("\(u(s.temp))").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white.opacity(0.92))
        } minimumValueLabel: {
            Text("\(u(s.lo))").font(.ui(9)).foregroundStyle(.white.opacity(0.65))
        } maximumValueLabel: {
            Text("\(u(s.hi))").font(.ui(9)).foregroundStyle(.white.opacity(0.65))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(Gradient(colors: [.white.opacity(0.18), .white.opacity(0.95)]))   // from today's low (faint) to high (solid white)   // iOS draws lock widgets as frosted glass over the wallpaper; this matches it
        }
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
                Image(systemName: "umbrella").font(.system(size: 14, weight: .medium)).opacity(0.75)
                Text("\(c)%").font(.system(size: 14, weight: .semibold)).opacity(0.92)
            }
        }
    }
}

struct AccessoryWidgetBackgroundCompat: View {
    var body: some View { Circle().fill(Color.white.opacity(0.12)) }
}

enum LockText {
    /// One word for the lock screen: the alert name when there is one (호우주의보, 한파 …), the weather otherwise.
    /// (no "!" and no emoji: the lock screen shows one colour and stays calm)
    static func line(_ s: WeatherScene) -> String { Compact.head(s) }
    /// Inline lock widget and watch inline complication: "비 · 16° · 우산" — words with the temperature between them.
    static func inline(_ snap: WeatherSnapshot) -> String { Compact.line(snap.scene, deg: snap.deg) }
}
