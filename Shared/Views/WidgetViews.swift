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

/// Medium (2×4): the 2×2 face on the left, as wide as the widget is tall, and the next five days on the right on
/// a soft panel down to the bottom edge — day, weather, chance of rain, low, the range bar (the app's 10-day
/// colours) and high.
struct MediumWidgetView: View {
    let snap: WeatherSnapshot
    var body: some View {
        let ink = Ink(night: snap.scene.isNight)
        GeometryReader { g in
            HStack(spacing: 0) {
                SmallFace(snap: snap).frame(width: min(g.size.height, g.size.width / 2))
                WidgetDayList(snap: snap, ink: ink)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(WidgetPanel(ink: ink))
                    .padding(.leading, 2).padding(.trailing, 8).padding(.vertical, 8)
            }
        }
        .foregroundStyle(ink.ink)
        .padding(-16)          // laid out from the widget's own edges (the hosts keep iOS's 16-pt margin)
    }
}

/// Medium, hourly (2×4): place and temperature on the left, the weather and today's high / low on the right, and
/// the next six hours on a panel below — each with its time, the character dressed for that hour (an open umbrella
/// when it rains), its sky and temperature.
struct HoursWidgetView: View {
    let snap: WeatherSnapshot
    var body: some View {
        let s = snap.scene, ink = Ink(night: s.isNight)
        let hours = Array(s.hours.dropFirst().prefix(6))
        let feelsGap = Double(s.feels - s.temp)      // the hours give the temperature; dress for how it feels
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(snap.placeShort).font(.px(11)).lineLimit(1).minimumScaleFactor(0.7).probe("place")
                    Text(snap.deg(s.temp)).font(.px(34)).lineLimit(1).probe("temp")
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 3) {
                    PixelIcon(name: s.hours.first?.icon ?? "cloud", size: 16).probe("icon")
                    Text(Compact.condWord(s)).font(.px(11)).lineLimit(1).probe("cond")
                    Text(L("최고 %@ · 최저 %@", snap.deg(s.hi), snap.deg(s.lo))).font(.px(9)).lineLimit(1).probe("hilo")
                }
            }
            .halo(ink)
            .padding(.horizontal, 14).padding(.top, 10)
            Spacer(minLength: 2)
            HStack(spacing: 0) {
                ForEach(Array(hours.enumerated()), id: \.offset) { i, h in
                    VStack(spacing: 1) {
                        Text(snap.hourLabel(h.label)).font(.px(snap.clock12 ? 7 : 9)).lineLimit(1).minimumScaleFactor(0.7).opacity(0.85).halo(ink).probe("h\(i)label")
                        CharacterSprite(character: snap.shownCharacter, level: Rules.level(feels: Double(h.temp) + feelsGap),
                                        rain: h.mm >= 0.1 ? .umbrella : .none, width: 34, animate: false).probe("h\(i)cat")
                        HStack(spacing: 2) {
                            PixelIcon(name: h.icon, size: 12).probe("h\(i)icon")
                            Text(snap.deg(h.temp)).font(.px(10)).lineLimit(1).probe("h\(i)temp")
                        }
                        .halo(ink)
                    }
                    .frame(maxWidth: .infinity).probe("h\(i)")
                }
            }
            .padding(.vertical, 5).padding(.horizontal, 2)
            .background(WidgetPanel(ink: ink))
            .padding(.horizontal, 8).padding(.bottom, 8)
        }
        .foregroundStyle(ink.ink)
        .padding(-16)          // laid out from the widget's own edges (the hosts keep iOS's 16-pt margin)
    }
}

/// The see-through panel the lists sit on: lets the sky show through while rain streaks fade behind the words.
private struct WidgetPanel: View {
    let ink: Ink
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(ink.night ? Color.white.opacity(0.08) : Color.white.opacity(0.42))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(ink.night ? Color.white.opacity(0.12) : Color.white.opacity(0.55), lineWidth: 1))
    }
}

/// Small (2×2): place and weather icon on top, the temperature under the icon, the character at the bottom left,
/// sunset · feels · rain at the bottom right — as placed on the layout board.
struct SmallWidgetView: View {
    let snap: WeatherSnapshot
    var body: some View {
        SmallFace(snap: snap)
            .foregroundStyle(Ink(night: snap.scene.isNight).ink)
            .padding(-16)      // laid out from the widget's own edges (the hosts keep iOS's 16-pt margin)
    }
}

/// The 2×2 face, measured from the widget's edges (170 × 170 on the board; anchored to the edges, so smaller
/// widgets keep the same margins).
private struct SmallFace: View {
    let snap: WeatherSnapshot
    var body: some View {
        let s = snap.scene, ink = Ink(night: s.isNight), lv = Rules.clamp(s.level)
        let rain = RainState(rawValue: s.rain) ?? .none
        ZStack(alignment: .topLeading) {
            HStack(spacing: 4) {
                Text(snap.placeShort).font(.px(11)).lineLimit(1).minimumScaleFactor(0.7).probe("place")
                Spacer(minLength: 0)
                PixelIcon(name: s.hours.first?.icon ?? "cloud", size: 16).probe("icon")
            }
            .halo(ink)
            .padding(.top, 9).padding(.horizontal, 12)
            Text(snap.deg(s.temp)).font(.px(30)).lineLimit(1).minimumScaleFactor(0.7).probe("temp").halo(ink)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 40).padding(.trailing, 10)
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
            .frame(width: 80, height: 118, alignment: .bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, 13).padding(.bottom, 8)
            VStack(alignment: .trailing, spacing: 4) {
                if let t = sunsetTile(s) { HStack(spacing: 2) { PixelIcon(name: "sunset", size: 11).probe("sunsetIcon"); Text(t).font(.px(9)).probe("sunsetText") } }
                Text(L("체감 %@", snap.deg(s.feels))).font(.px(9)).probe("feels")
                Text(L("강수 %d%%", chanceNow(s))).font(.px(9)).probe("chance")
            }
            .lineLimit(1).minimumScaleFactor(0.8)
            .halo(ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 13).padding(.bottom, 9)
        }
    }
}

/// The next five days for the medium widget, like the app's 10-day card.
private struct WidgetDayList: View {
    let snap: WeatherSnapshot
    let ink: Ink
    var body: some View {
        let days = Array(snap.scene.days.prefix(5))
        let wmin = days.map { $0.lo }.min() ?? 0, wmax = days.map { $0.hi }.max() ?? 1
        let span = CGFloat(max(1, wmax - wmin))
        VStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                HStack(spacing: 4) {
                    Text(d.name).font(.px(10)).frame(width: Lang.current == .en ? 34 : 22, alignment: .leading).probe("d\(i)name")
                    PixelIcon(name: d.icon, size: 16).probe("d\(i)icon")
                    Text(d.chance >= 10 ? "\(d.chance)%" : "").font(.px(8)).foregroundStyle(ink.blue).frame(width: 20, alignment: .leading).probe("d\(i)chance")
                    Text(snap.deg(d.lo)).font(.px(10)).foregroundStyle(ink.sub).frame(width: 22, alignment: .trailing).probe("d\(i)lo")
                    GeometryReader { b in
                        ZStack(alignment: .leading) {
                            Capsule().fill(ink.track)
                            Capsule().fill(LinearGradient(colors: [Color(hex: "#6FA8FF"), Color(hex: "#FFA94D")], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(5, CGFloat(d.hi - d.lo) / span * b.size.width))
                                .offset(x: CGFloat(d.lo - wmin) / span * b.size.width)
                        }
                    }
                    .frame(height: 5).probe("d\(i)bar")
                    Text(snap.deg(d.hi)).font(.px(10)).frame(width: 22, alignment: .trailing).probe("d\(i)hi")
                }
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxHeight: .infinity)
                .probe("d\(i)")
            }
        }
        .halo(ink)
    }
}

extension View {
    /// A soft glow in the sky's own light behind widget words, so heavy rain or snow does not cut through them.
    func halo(_ ink: Ink) -> some View {
        let c = ink.night ? Color(hex: "#0B0F24") : Color.white
        return shadow(color: c.opacity(ink.night ? 0.75 : 0.8), radius: 1).shadow(color: c.opacity(ink.night ? 0.55 : 0.6), radius: 3)
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
