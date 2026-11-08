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
                    // (a zero width — a layout pass before the size is known — would make the count infinite)
                    let stripH = Sky.tile.height * g.size.width / Sky.tile.width
                    let n = stripH > 0 ? min(12, max(1, Int((g.size.height / stripH).rounded(.up)))) : 1
                    SkyParticles(scene: scene, width: max(1, g.size.width), tiles: n, animate: animate)
                }
            } else if night {
                Color(red: 16 / 255, green: 20 / 255, blue: 48 / 255).opacity(0.64)
            }
        }
    }
}

/// The sun tile's time for the small rows: "17:52" as the forecast writes it — or "5:52PM" where the person
/// uses the 12-hour clock, the way the lock-screen sun widget already shows it (ko·ja·zh keep 24 h, like
/// their hour labels do).
/// The sun tile's own icon: the sunset by day, the sunrise at night
func sunTileIcon(_ s: WeatherScene) -> String {
    s.tiles.first(where: { $0.icon == "sunset" || $0.icon == "sunrise" })?.icon ?? "sunset"
}
func sunsetTile(_ s: WeatherScene, clock12: Bool) -> String? {
    guard let t = s.tiles.first(where: { $0.icon == "sunset" || $0.icon == "sunrise" })?.value else { return nil }
    guard clock12, Lang.current.isLatinLike, let m = WeatherScene.clockMinutes(t) else { return t }
    return HourLabel.clock(m, clock12: true)
}
/// Where a bubble's tail should sit: `gap` points above the character's head (ears included), or above the open
/// umbrella — measured per outfit from the sprites (anchors.json), so a hood or a hat never touches the bubble.
func bubbleBottom(_ c: PurrCharacter, _ rain: RainState, level: Int, spriteHeight h: CGFloat, gap: CGFloat = 5) -> CGFloat {
    let a = c.anchors, lv = Rules.clamp(level)
    let top = CGFloat(rain == .umbrella ? a.umb_top[lv] : a.head_top[lv]) / Sprite.height
    return h * (1 - top) + gap
}
/// How far the bubble moves sideways from the sprite's middle to sit over the head (or the umbrella's tip when it is up)
func bubbleShiftX(_ c: PurrCharacter, _ rain: RainState, level: Int, spriteWidth w: CGFloat) -> CGFloat {
    let a = c.anchors, lv = Rules.clamp(level)
    let x = rain == .umbrella ? Sprite.umbrellaTipX : CGFloat(a.head_cx[lv])
    return (x - Sprite.width / 2) / Sprite.width * w
}
func chanceNow(_ s: WeatherScene) -> Int { s.hours.prefix(6).map { $0.chance }.max() ?? 0 }

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

/// Medium, hourly (2×4): place and temperature top left, the weather icon top right; the character standing on the
/// hours panel with its bubble, and beside it the 2×2's list (☂ · sun · 체감 · 최고 최저, all one size) down to its
/// feet; the next six hours on the panel — time, sky, temperature and rain. On the small phones (SE, mini: under
/// 157 pt tall) the icon goes, so the list keeps clear of the top, and the temperature is a size down, clear of the panel.
struct HoursWidgetView: View {
    let snap: WeatherSnapshot
    var body: some View {
        let s = snap.scene, ink = Ink(night: s.isNight), lv = Rules.clamp(s.level)
        let rain = RainState(rawValue: s.rain) ?? .none
        let hours = Array(s.hours.dropFirst().prefix(6))
        GeometryReader { g in
            let catW: CGFloat = 40, catH = catW * Sprite.height / Sprite.width
            let panelH: CGFloat = 70, panelTop = g.size.height - 8 - panelH
            let small = g.size.height < 157
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(snap.placeShort).font(.px(11)).lineLimit(1).minimumScaleFactor(0.7).probe("place")
                    Text(snap.deg(s.temp)).font(.px(small ? 36 : 44)).lineLimit(1).probe("temp").padding(.top, 4)
                }
                .halo(ink)
                .padding(.leading, 14).padding(.top, 10)
                if !small {
                    PixelIcon(name: s.hours.first?.icon ?? "cloud", size: 16).probe("icon")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 14).padding(.top, 10)
                }
                // the 2×2's list (SmallStack), every line right-aligned and one size, standing on the panel beside the character
                UniformList(snap: snap, room: max(60, g.size.width * 0.365 - catW / 2 - 17.5))
                    .halo(ink)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 13.5)      // the words' ink on the weather icon's right edge (14)
                    .frame(height: panelTop - 5, alignment: .bottom)
                ZStack(alignment: .bottom) {
                    CharacterSprite(character: snap.shownCharacter, level: lv, rain: rain, width: catW, animate: false).probe("cat")
                        .frame(width: catW, height: catH, alignment: .bottom)
                    if let b = s.bubble {
                        BubbleView(kind: b.kind, tone: b.tone, icon: b.icon, text: Compact.bubbleWord(s, max: 5), fontSize: 9).fixedSize().probe("bubble")
                            .scaleEffect(0.64, anchor: .bottom)
                            .padding(.bottom, bubbleBottom(snap.shownCharacter, rain, level: lv, spriteHeight: catH, gap: 3))
                            .offset(x: bubbleShiftX(snap.shownCharacter, rain, level: lv, spriteWidth: catW))
                    }
                }
                .frame(width: catW + 40, height: catH + 40, alignment: .bottom)
                .position(x: g.size.width * 0.635, y: panelTop - 1 - (catH + 40) / 2)
                HStack(spacing: 0) {
                    ForEach(Array(hours.enumerated()), id: \.offset) { i, h in
                        VStack(spacing: 1.5) {
                            Text(snap.hourLabel(h.label)).font(.px(snap.clock12 ? 7 : 9)).lineLimit(1).minimumScaleFactor(0.7).opacity(0.85).probe("h\(i)label")
                            PixelIcon(name: h.icon, size: 20).probe("h\(i)icon")
                            Text(snap.deg(h.temp)).font(.px(11)).lineLimit(1).probe("h\(i)temp")
                            Text(h.mm > 0 ? (h.mm >= 10 ? "\(Int(h.mm.rounded()))mm" : String(format: "%gmm", (h.mm * 10).rounded() / 10)) : "–")
                                .font(.px(8)).lineLimit(1).foregroundStyle(h.mm > 0 ? ink.blue : ink.faint).probe("h\(i)mm")
                        }
                        .frame(maxWidth: .infinity).probe("h\(i)")
                    }
                }
                .halo(ink)
                .padding(.horizontal, 2)
                .frame(height: panelH)
                .background(WidgetPanel(ink: ink))
                .padding(.horizontal, 8).padding(.top, panelTop)
            }
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
/// widgets keep the same margins). On the 6.1" phones (158) the list's widest lines get a little less room; on the
/// SE (148, under 152) the character is drawn smaller in proportion. The list steps down as one wherever its words
/// would reach the character (UniformList).
private struct SmallFace: View {
    let snap: WeatherSnapshot
    var body: some View {
        GeometryReader { g in face(side: min(g.size.width, g.size.height)) }
    }

    private func face(side: CGFloat) -> some View {
        let s = snap.scene, ink = Ink(night: s.isNight), lv = Rules.clamp(s.level)
        let rain = RainState(rawValue: s.rain) ?? .none
        let tiny = side < 152, k: CGFloat = tiny ? side / 170 : 1
        let less = max(0, 170 - side) * 0.25      // the wide lines' caps, a touch narrower on smaller widgets
        return ZStack(alignment: .topLeading) {
            HStack(spacing: 4) {
                Text(snap.placeShort).font(.px(11)).lineLimit(1).minimumScaleFactor(0.7).probe("place")
                Spacer(minLength: 0)
                PixelIcon(name: s.hours.first?.icon ?? "cloud", size: 16).probe("icon")
            }
            .halo(ink)
            .padding(.top, 9).padding(.leading, 12).padding(.trailing, SmallStack.edge)
            // the big number's last glyph (°) carries ~2.5 pt of its own room: set in that much so its ink meets the edge
            Text(snap.deg(s.temp)).font(.px(35)).lineLimit(1).minimumScaleFactor(0.7).probe("temp").halo(ink)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 44).padding(.trailing, SmallStack.edge - 2.5)
            ZStack(alignment: .bottom) {
                CharacterSprite(character: snap.shownCharacter, level: lv, rain: rain, width: 72 * k, animate: false).probe("cat")
                    .frame(width: 72 * k, height: 84 * k, alignment: .bottom)
                if let b = s.bubble {
                    // a word ("비", "한파", "폭염") fits above the head; longer names show just the icon here
                    BubbleView(kind: b.kind, tone: b.tone, icon: b.icon, text: Compact.bubbleWord(s, max: 5), fontSize: 9).fixedSize().probe("bubble")
                        .scaleEffect(0.66 * k, anchor: .bottom)      // small enough that a warning name clears "-12°"
                        .padding(.bottom, bubbleBottom(snap.shownCharacter, rain, level: lv, spriteHeight: 84 * k))
                        .offset(x: bubbleShiftX(snap.shownCharacter, rain, level: lv, spriteWidth: 72 * k))
                }
            }
            .frame(width: 80 * k, height: 118 * k, alignment: .bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, 13 * k).padding(.bottom, 8 * k)
            // close together at the bottom right (SmallStack): the rain chance and the sun with their pixel icons, then
            // 체감 and 최고 · 최저 in words at the bottom, every line one size
            UniformList(snap: snap, room: 80 - less, feelsRoom: 74 - less)
                .halo(ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, SmallStack.edge - 0.5).padding(.bottom, 9)
        }
    }
}

/// The sunset (sunrise at night) line of the lists, the same size as every other line (☂, 체감, 최고 · 최저): one
/// text size down the whole list. `size` is the list's text size; the icon as ☂'s.
struct SunLine: View {
    let icon: String
    let time: String
    var size: CGFloat = 9
    var iconSize: CGFloat? = nil      // ☂'s icon size on that list (the widgets' 11 by default)
    var nudge: CGFloat = 0            // drawn half a point short of the edge on some lists (the watch's): onto it
    var k: CGFloat = 1                // the list's shared step down (UniformList)
    var body: some View {
        HStack(spacing: iconGap(size * k)) {
            PixelIcon(name: icon, size: ((iconSize ?? size * 11 / 9) * k).rounded()).probe("sunsetIcon")
            Text(time).font(.pxScaled(size, k)).probe("sunsetText")
        }
        .offset(x: nudge * k)
    }
}

/// The bottom-right list (☂ · the sun · 체감 · 최고 최저), every line one size. Each line has its room (`room` for
/// 최고 · 최저, the widest; `narrow` beside the character's coat on the watch; `feelsRoom` for 체감 on the 2×2); when a
/// line would not fit its room, the whole list steps down together — never that one line alone — so the sizes stay
/// matched. ViewThatFits takes the first step whose lines all fit (a line's room as leading padding up to `room`).
struct UniformList: View {
    let snap: WeatherSnapshot
    var order: [String] = SmallStack.order
    var size: CGFloat = 9              // the list's text size (as `.px` takes it)
    var icon: CGFloat = 11             // its icons
    var thermo = false                 // 최고 · 최저 behind the thermometers
    var spacing: CGFloat = 0.9
    var room: CGFloat
    var narrow: CGFloat? = nil
    var feelsRoom: CGFloat? = nil
    var sunNudge: CGFloat = 0

    var body: some View {
        ViewThatFits(in: .horizontal) {
            stack(1); stack(0.94); stack(0.88); stack(0.82); stack(0.76); stack(0.7)
        }
        .frame(maxWidth: room, alignment: .trailing)
    }

    private func stack(_ k: CGFloat) -> some View {
        let s = snap.scene
        let other = min(narrow ?? room, room)
        return VStack(alignment: .trailing, spacing: spacing * k) {
            ForEach(order, id: \.self) { item in
                switch item {
                case "sun":
                    if let t = sunsetTile(s, clock12: snap.clock12) {
                        SunLine(icon: sunTileIcon(s), time: t, size: size, iconSize: icon, nudge: sunNudge, k: k)
                            .fixedSize().padding(.leading, room - other)
                    }
                case "chance":
                    if !snap.showsDashes {
                        ChanceLine(chance: chanceNow(s), size: size, icon: icon, k: k).probe("chance")
                            .fixedSize().padding(.leading, room - other)
                    }
                case "feels":
                    Text(L("체감 %@", snap.deg(s.feels))).font(.pxScaled(size, k)).probe("feels")
                        .fixedSize().padding(.leading, room - min(feelsRoom ?? other, other))
                default:
                    if !snap.showsDashes { HiLoLine(snap: snap, size: size, thermo: thermo, icon: icon, k: k).probe("hilo").fixedSize() }
                }
            }
        }
        .multilineTextAlignment(.trailing)
    }
}

/// The gap between a pixel icon and its words, the same on every line: a quarter of the text size
func iconGap(_ size: CGFloat) -> CGFloat { (size / 4).rounded() }

/// A width cap that hugs its content: no wider than its words (or than `max`, where long words shrink) — unlike
/// `.frame(maxWidth:)`, which takes the whole width it is offered, so the list's lines keep their own lengths
struct CapWidth: Layout {
    var max: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let v = subviews.first else { return .zero }
        return v.sizeThatFits(ProposedViewSize(width: Swift.min(proposal.width ?? .infinity, max), height: proposal.height))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}
extension View { func capWidth(_ w: CGFloat) -> some View { CapWidth(max: w) { self } } }


/// The small widget's and the watch's list at the bottom right, top to bottom: 강수확률, the sunset (sunrise at night),
/// 체감, and 최고 · 최저 at the very bottom — the two with pixel icons above the two in words
enum SmallStack {
    static let order = ["chance", "sun", "feels", "hilo"]
    /// The one right edge of the 2×2 (from the widget's edge to the ink): the weather icon, the big temperature and
    /// every line of the list end on it. Near enough the edge that the bottom line keeps clear of the character's
    /// feet on the 6.1" phones' 158-pt widgets.
    static var edge: CGFloat = 9.5
}

/// The chance of rain in the next hours (강수확률; 강수 alone is the amount, in mm): a pixel icon before the percentage,
/// as the sunset row has its icon.
struct ChanceLine: View {
    let chance: Int
    var size: CGFloat = 9
    var icon: CGFloat = 11
    var k: CGFloat = 1      // the list's shared step down (UniformList)
    /// The umbrella from 50 % (as the watch's corner), the raindrop below
    static func iconName(_ chance: Int) -> String { chance >= 50 ? "umbrella" : "raindrop" }
    var body: some View {
        HStack(spacing: iconGap(size * k)) {
            PixelIcon(name: Self.iconName(chance), size: (icon * k).rounded())
            Text("\(chance)%")
        }
        .font(.pxScaled(size, k))
        .accessibilityElement(children: .ignore).accessibilityLabel(L("강수확률 %d%%", chance))
    }
}

/// The day's high and low: in words, "최고 15° 최저 14°" (the widgets), or behind the kit's hot and cold thermometers
/// (the watch, where the words do not fit beside the character). Widened by the temperature now: the day reached it.
struct HiLoLine: View {
    let snap: WeatherSnapshot
    var size: CGFloat = 9
    var thermo = false
    var icon: CGFloat = 11
    var k: CGFloat = 1      // the list's shared step down (UniformList)
    var body: some View {
        let s = snap.scene
        let hi = snap.deg(max(s.hi, s.temp)), lo = snap.deg(min(s.lo, s.temp))
        Group {
            if thermo {
                HStack(spacing: iconGap(size * k)) {
                    PixelIcon(name: "thermo_hot", size: (icon * k).rounded())
                    Text(hi).padding(.trailing, size * k / 2)
                    PixelIcon(name: "thermo_cold", size: (icon * k).rounded())
                    Text(lo).probe("hiloEnd")
                }
                .fixedSize()      // its own width, no more: the last number ends on the list's right edge
            } else {
                Text(L("최고 %@ 최저 %@", hi, lo))
            }
        }
        .font(.pxScaled(size, k))
        .accessibilityElement(children: .ignore).accessibilityLabel(L("최고 %@ 최저 %@", hi, lo))
    }
}

/// The watch's list, top to bottom (the looks on offer): "chance" 강수확률 · "sun" sunset / sunrise · "feels" 체감 ·
/// "hilo" 최고 · 최저 behind the thermometers
enum WatchHiLo { static var order = ["chance", "sun", "feels", "hilo"] }


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
                    Text(snap.dayName(i)).font(.px(10)).lineLimit(1).minimumScaleFactor(0.6).frame(width: Lang.current.isLatinLike ? 34 : 22, alignment: .leading).probe("d\(i)name")
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
    /// A faint edge in the sky's own light around widget words — just enough that a rain or snow streak crossing a
    /// letter does not merge with it, without looking lit up.
    func halo(_ ink: Ink) -> some View {
        let c = ink.night ? Color(hex: "#0B0F24") : Color.white
        return shadow(color: c.opacity(ink.night ? 0.45 : 0.4), radius: 0.7)
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
                Text(Compact.head(s, weather: true)).font(.ui(12, .medium)).lineLimit(1).minimumScaleFactor(0.7).opacity(0.85).probe("lockLine")
                // the placeholder and a stale widget drop the "–~–" range: one dash line reads, three look broken
                Text(snap.showsDashes ? Compact.tail(s, deg: snap.deg, weather: true)
                                      : "\(Compact.tail(s, deg: snap.deg, weather: true)) · \(snap.deg(s.lo))~\(snap.deg(s.hi))")
                    .font(.ui(11)).opacity(0.65).probe("lockTail")
            }
            Spacer(minLength: 0)
        }
    }
}

/// The ring the lock-screen temperature and UV circles share (the watch gauge's shape, in the lock screen's one
/// colour): a 240° arc open at the bottom, brightening to the right, a hollow ring at `frac` — a hole in the arc, as
/// the lock screen draws no black — and whatever goes in the middle and under it (sized by `k`, 1 at 54 pt).
struct LockRing<Middle: View, Under: View>: View {
    let frac: Double
    let middle: (CGFloat) -> Middle
    let under: (CGFloat) -> Under
    var body: some View {
        GeometryReader { g in
            let d = min(g.size.width, g.size.height), k = d / 54, lw = 4.5 * k, r = 22 * k
            let c = CGPoint(x: g.size.width / 2, y: g.size.height / 2)
            let a = (-120 + 240 * max(0, min(1, frac))) * .pi / 180
            let dot = CGPoint(x: c.x + r * CGFloat(sin(a)), y: c.y - r * CGFloat(cos(a)))
            ZStack {
                ZStack {
                    GaugeArc(radius: r).stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: lw, lineCap: .round))
                    GaugeArc(radius: r).stroke(LinearGradient(colors: [.white.opacity(0.35), .white], startPoint: .leading, endPoint: .trailing),
                                              style: StrokeStyle(lineWidth: lw, lineCap: .round))
                    Circle().frame(width: 9.5 * k, height: 9.5 * k).position(dot).blendMode(.destinationOut)
                }
                .compositingGroup()
                Circle().stroke(Color.white, lineWidth: 1.8 * k).frame(width: 7 * k, height: 7 * k).position(dot)
                // a little above the middle: the ring is open at the bottom, so its weight sits higher
                middle(k).foregroundStyle(.white).fixedSize().position(x: c.x, y: c.y - 2.5 * k)
                under(k).position(x: c.x, y: c.y + 17 * k)
            }
        }
    }
}

/// Lock screen, circular: today's low → high on the ring, now as the ring's hollow dot, "18°" in the middle and
/// "low · high" under it; straight on the wallpaper, nothing behind it
struct LockCircularView: View {
    let snap: WeatherSnapshot
    var pixel = false     // the lock screen's own type, like the clock; the lab can still show the pixel number
    var body: some View {
        let s = snap.scene
        let lo = min(s.lo, s.temp), hi = max(s.hi, s.temp)
        LockRing(frac: snap.showsDashes ? 0 : Double(s.temp - lo) / Double(max(1, hi - lo))) { k in
            // the digits a touch left of the middle with the "°" hanging off them: the small raised degree makes a
            // whole-centred "18°" look pushed left, digits-only centring looks pushed right — this sits between
            let f: Font = pixel ? .px(13 * k) : .system(size: 13 * k, weight: .semibold)
            return HangingDegree(text: snap.degNumber(s.temp), font: f).offset(x: -1.3 * k)
        } under: { k in
            Text("\(snap.degNumber(s.lo)) · \(snap.degNumber(s.hi))").font(.system(size: 7 * k, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
        }
    }
}

/// Lock screen, circular: today's highest UV index on the same ring (0 … 11+), the number in the middle and a small
/// sun under it instead of numbers
struct LockUVCircularView: View {
    let snap: WeatherSnapshot
    var body: some View {
        let uv = snap.scene.tiles.first { $0.kind == "uv" }?.uv ?? 0
        LockRing(frac: Double(min(uv, 11)) / 11) { k in
            Text(snap.showsDashes ? "–" : "\(uv)").font(.system(size: 14 * k, weight: .semibold))
        } under: { k in
            Image("icon-sun-lock").interpolation(.none).resizable().frame(width: 12 * k, height: 12 * k).opacity(0.9)
        }
    }
}

/// Lock screen, circular: whichever comes next — the sunset through the day, the sunrise through the night — its
/// icon (a half sun on the horizon, the arrow down or up) over the time. Worked out on the phone from the place, and
/// the widget's timeline has an entry right after each one, so it turns over the moment the sun sets or rises.
/// Without a place (or where the sun stays up or down all day), the forecast's own sun tile.
struct LockSunCircularView: View {
    let snap: WeatherSnapshot
    var now = Date()
    var body: some View {
        let next: (sunset: Bool, time: String) = {
            if let p = snap.place, let tz = TimeZone(identifier: p.timeZone), let n = SunTimes.next(after: now, lat: p.lat, lon: p.lon, tz: tz) {
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = tz
                f.dateFormat = snap.clock12 ? "h:mm" : "HH:mm"
                return (n.sunset, f.string(from: n.at))
            }
            let t = snap.scene.tiles.first { $0.icon == "sunset" || $0.icon == "sunrise" }
            return (t?.icon != "sunrise", t?.value ?? "–")
        }()
        VStack(spacing: 3) {
            Image(next.sunset ? "icon-sunset-lock" : "icon-sunrise-lock").interpolation(.none).resizable().frame(width: 26, height: 26).opacity(0.9)
            Text(next.time).font(.system(size: 14, weight: .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Lock screen, circular: the wind — an arrow pointing where it blows, the speed (in the app's wind unit) under it
struct LockWindCircularView: View {
    let snap: WeatherSnapshot
    var body: some View {
        let w = snap.scene.wind
        VStack(spacing: 3) {
            // the forecast gives where the wind comes from; the arrow points the way it goes
            Image(systemName: "location.north.fill").font(.system(size: 20, weight: .semibold))
                .rotationEffect(.degrees(Double(w.deg) + 180)).opacity(w.speed > 0 && !snap.showsDashes ? 0.9 : 0.4)
                .frame(width: 26, height: 26)
            Text(snap.windText(w.speed)).font(.system(size: 14, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Lock screen, circular: chance of rain — a round white umbrella drawn for the lock screen over the percentage,
/// straight on the wallpaper like the 미세먼지 circle
struct LockRainCircularView: View {
    let snap: WeatherSnapshot
    var body: some View {
        let c = chanceNow(snap.scene)
        VStack(spacing: 3) {
            Image("icon-umbrella-lock").interpolation(.none).resizable().frame(width: 26, height: 26).opacity(0.9)
            Text(snap.showsDashes ? "–" : "\(c)%").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.92))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Lock screen, circular: 미세먼지 (Plus — the free plan's forecast is the morning one, not the live readings) — just
/// the dust icon over the step's word (좋음 · 보통 · 나쁨 · 매우 나쁨), straight on the wallpaper like the character in the
/// rectangle; on the free plan the icon faint over "Plus"
struct LockDustCircularView: View {
    let snap: WeatherSnapshot
    /// The widget gallery shows what the circle looks like with Plus (its description says it is a Plus widget)
    var preview = false
    var body: some View {
        let d = snap.scene.dust
        let g = d.map { max(0, min(3, $0.grade)) }
        let open = snap.plusActive || preview
        VStack(spacing: 3) {
            // the icon in the character's lock-screen style: white, the outline cut out, mid tones see-through;
            // faint on the free plan, with "Plus" under it
            Image("icon-\(d.map { DustFacts.icon($0) } ?? "pm10")-lock").interpolation(.none).resizable()
                .frame(width: 26, height: 26).opacity(open ? 0.9 : 0.3)
            Text(open ? (g.map { L(DustScale.words[$0]) } ?? "–") : "Plus").font(.system(size: 14, weight: .semibold))
                .lineLimit(1).minimumScaleFactor(0.6).foregroundStyle(.white.opacity(open ? 0.92 : 0.55))
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AccessoryWidgetBackgroundCompat: View {
    var body: some View { Circle().fill(Color.white.opacity(0.12)) }
}

/// Lock screen, above the clock (accessoryInline): one piece of the weather on one line, an icon before it — the
/// system draws both in the lock screen's one colour, at its own text size. The temperature line is the lock-screen
/// rectangle made small: the character in what to wear now (`<char>-inline-<level>`, its lock-screen picture down to
/// the hem of the top, a template image at text height) and the temperature now.
struct LockInlineView: View {
    enum Kind { case temp, place, rain, uv, sun, wind, dust }
    let kind: Kind
    let snap: WeatherSnapshot
    var now = Date()
    var preview = false

    var body: some View {
        let (icon, text) = Self.line(kind, snap, now: now, preview: preview)
        Label {
            Text(text)
        } icon: {
            if kind == .temp { Image("\(snap.shownCharacter.rawValue)-inline-\(Rules.clamp(snap.scene.level))").renderingMode(.template) }
            else { Image(systemName: icon) }
        }
    }

    /// (SF Symbol, text) for each kind; before the app has handed over anything, the icon with a dash (the place and
    /// the Plus-only 미세먼지 still say what they say)
    static func line(_ kind: Kind, _ snap: WeatherSnapshot, now: Date = Date(), preview: Bool = false) -> (String, String) {
        let l = shown(kind, snap, now: now, preview: preview)
        return snap.showsDashes && kind != .place && kind != .dust ? (l.0, "–") : l
    }

    private static func shown(_ kind: Kind, _ snap: WeatherSnapshot, now: Date, preview: Bool) -> (String, String) {
        let s = snap.scene
        switch kind {
        case .temp:
            // the temperature now (the character before it shows what to wear)
            return ("thermometer.medium", snap.deg(s.temp))
        case .place:
            return (snap.place?.id == "here" ? "location.fill" : "mappin", snap.placeShort)
        case .rain:
            return ("umbrella.fill", rainLine(s, now: now))
        case .uv:
            let uv = s.tiles.first { $0.kind == "uv" }?.uv ?? 0
            return ("sun.max.fill", "\(L("자외선")) \(uv) \(L(UVScale.band(uv).word))")
        case .sun:
            if let p = snap.place, let tz = TimeZone(identifier: p.timeZone), let n = SunTimes.next(after: now, lat: p.lat, lon: p.lon, tz: tz) {
                var c = Calendar(identifier: .gregorian); c.timeZone = tz
                let t = HourLabel.clock(c.component(.hour, from: n.at) * 60 + c.component(.minute, from: n.at), clock12: snap.clock12)
                return (n.sunset ? "sunset.fill" : "sunrise.fill", "\(L(n.sunset ? "일몰" : "일출")) \(t)")
            }
            let t = s.tiles.first { $0.icon == "sunset" || $0.icon == "sunrise" }
            return (t?.icon == "sunrise" ? "sunrise.fill" : "sunset.fill", "\(L(t?.icon == "sunrise" ? "일출" : "일몰")) \(t?.value ?? "–")")
        case .wind:
            let w = s.wind
            return ("wind", w.speed > 0 ? "\(Rules.windFrom(w.deg)) \(snap.windText(w.speed))" : L("바람 없어요"))
        case .dust:
            // Plus, as the circle (the free plan's forecast is the morning one, not the live readings)
            guard snap.plusActive || preview else { return ("aqi.medium", "\(L("미세먼지")) · Plus") }
            guard let d = s.dust else { return ("aqi.medium", "\(L("미세먼지")) –") }
            var parts = ["\(L("미세먼지")) \(L(DustScale.words[max(0, min(3, d.pm10Grade ?? d.grade))]))"]
            if let g = d.pm25Grade { parts.append("\(L("초미세")) \(L(DustScale.words[max(0, min(3, g))]))") }
            return ("aqi.medium", parts.joined(separator: " · "))
        }
    }

    /// Rain today when it is coming ("16시쯤 비 예보"), else today's chance, else the next wet day in ten, else none
    static func rainLine(_ s: WeatherScene, now: Date = Date()) -> String {
        let wetIcons: Set<String> = ["raincloud", "lightning", "snowflake", "sleet"]
        if let i = s.hours.indices.first(where: { s.hours[$0].mm > 0 || (wetIcons.contains(s.hours[$0].icon) && s.hours[$0].chance >= 50) }) {
            let h = s.hours[i]
            let snow = h.icon == "snowflake" || h.icon == "sleet" || s.isSnow
            if i == 0 { return snow ? L("지금 눈이 와요") : L("지금 비가 와요") }
            return L("%@쯤 %@ 예보", h.label, snow ? L("눈") : L("비"))
        }
        if let d = s.days.first, d.chance >= 30 { return L("강수확률 %d%%", d.chance) }
        if let i = s.days.indices.dropFirst().first(where: { s.days[$0].chance >= 50 }) {
            let d = s.days[i]
            let snow = d.icon == "snowflake" || d.icon == "sleet"
            // the day by its whole name (일요일 · Sunday), tomorrow as 내일
            let f = DateFormatter(); f.locale = Lang.current.locale; f.setLocalizedDateFormatFromTemplate("EEEE")
            let name = i == 1 ? L("내일") : f.string(from: now.addingTimeInterval(Double(i) * 86400))
            return L(snow ? "%@ 눈 %d%%" : "%@ 비 %d%%", name, d.chance)
        }
        return L("10일 동안 비 소식 없어요")
    }
}

enum LockText {
    /// One word for the lock screen: the alert name when there is one (호우주의보, 한파 …), the weather otherwise.
    /// (no "!" and no emoji: the lock screen shows one colour and stays calm)
    static func line(_ s: WeatherScene) -> String { Compact.head(s) }
    /// Inline lock widget and watch inline complication: "비 · 16° · 우산" — words with the temperature between them;
    /// the weather only (미세먼지 has its own circle).
    static func inline(_ snap: WeatherSnapshot) -> String { Compact.line(snap.scene, deg: snap.deg, weather: true) }
}
