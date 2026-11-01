import SwiftUI

/// The App Store screenshots (debug builds, `-storeShot 1…8`): a big two-line caption (the second line in a
/// highlight colour) over a bold background, and the app's own parts cut out large with the character in front —
/// drawn by the app itself in its own font, so every language comes out of the same build. Laid out for the
/// 6.9-inch canvas (440 × 956 pt → 1320 × 2868 px) and scaled to whatever simulator takes the picture.
struct StoreShotView: View {
    @EnvironmentObject var model: AppModel
    let page: Int

    static let canvas = CGSize(width: 440, height: 956)
    private let yellow = Color(hex: "#FFD84D")

    var body: some View {
        GeometryReader { g in
            let k = min(g.size.width / Self.canvas.width, g.size.height / Self.canvas.height)
            content
                .frame(width: Self.canvas.width, height: Self.canvas.height)
                .clipped()
                .scaleEffect(k, anchor: .topLeading)
                .frame(width: g.size.width, height: g.size.height, alignment: .topLeading)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        switch page {
        case 2: outfits
        case 3: skies
        case 4: rainAlert
        case 5: nextHours
        case 6: dust
        case 7: widgets
        case 8: watch
        default: hero
        }
    }

    // MARK: 1 · 오늘 뭐 입지? 고양이를 보면 알아요

    /// The app's sky in a big rounded window, the temperature in it, the character in front, its feet over the
    /// window's edge
    private var hero: some View {
        let s = model.scene, lv = Rules.clamp(s.level), ink = Ink(night: s.isNight)
        let w: CGFloat = 392, h: CGFloat = 560
        return shot(L("오늘 뭐 입지?"), L("고양이를 보면 알아요"), bg: ["#5AA2EE", "#2E6FCB"]) {
            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topTrailing) {
                    SkyBase(level: lv, night: s.isNight)
                    SkyTint(scene: s)
                    SkyParticles(scene: s, width: w, tiles: 2, animate: false).frame(width: w, height: h, alignment: .top)
                    VStack(alignment: .trailing, spacing: 8) {
                        Text(model.deg(s.temp)).font(.px(104))
                        Text(s.cond).font(.px(24))
                        Text(L("최고 %@ · 최저 %@", model.deg(s.hi), model.deg(s.lo))).font(.px(16))
                    }
                    .foregroundStyle(ink.ink)
                    .padding(.top, 26).padding(.trailing, 26)
                }
                .frame(width: w, height: h)
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).strokeBorder(Color.white, lineWidth: 6))
                .shadow(color: .black.opacity(0.22), radius: 20, y: 12)
                cat(s, width: 286, bubbleSize: 20)
                    .offset(x: 6, y: h + 36 - 286 * Sprite.height / Sprite.width)
            }
            .frame(width: w)
            .padding(.top, 4)
        }
    }

    // MARK: 2 · 체감온도에 맞춰 옷을 갈아입어요

    private var outfits: some View {
        let steps: [(Int, Int)] = [(1, 34), (3, 25), (6, 17), (8, 10), (11, 1), (14, -12)]
        return shot(L("체감온도에 맞춰"), L("옷을 갈아입어요"), bg: ["#FFD9BF", "#B7C6EA"], light: false) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(128), spacing: 8), count: 3), spacing: 18) {
                ForEach(steps, id: \.0) { lv, t in
                    VStack(spacing: 6) {
                        CharacterSprite(character: model.shownCharacter, level: lv, rain: .none, width: 128, animate: false)
                            .frame(width: 128, height: 150, alignment: .bottom)
                        Text("\(t)°").font(.px(24)).foregroundStyle(Color(hex: "#1E2A44"))
                    }
                    .padding(.vertical, 10)
                    .frame(width: 128)
                    .background(Color(hex: Rules.background[lv]).opacity(0.85), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
            }
            .padding(.top, 34)
        }
    }

    // MARK: 3 · 하늘이 바뀌면 고양이도 바뀌어요

    /// Four weathers, each tile its own sky with the character dressed for it
    private var skies: some View {
        let keys = ["summer_heat", "spring_rain", "winter_snow", "summer_night"]
        return shot(L("하늘이 바뀌면"), L("고양이도 바뀌어요"), bg: ["#8A6CF0", "#5B3FC4"]) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(194), spacing: 12), count: 2), spacing: 12) {
                ForEach(keys, id: \.self) { k in skyTile(SceneLibrary.scene(k)) }
            }
            .padding(.top, 10)
        }
    }

    private func skyTile(_ s: WeatherScene) -> some View {
        let lv = Rules.clamp(s.level), ink = Ink(night: s.isNight), w: CGFloat = 194, h: CGFloat = 318
        return ZStack(alignment: .top) {
            SkyBase(level: lv, night: s.isNight)
            SkyTint(scene: s)
            SkyParticles(scene: s, width: w, tiles: 1, animate: false).frame(width: w, height: h, alignment: .top)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(model.deg(s.temp)).font(.px(30))
                Text(s.cond.components(separatedBy: " · ").first ?? s.cond).font(.px(16))
            }
            .foregroundStyle(ink.ink)
            .padding(.top, 16)
            CharacterSprite(character: model.shownCharacter, level: lv, rain: RainState(rawValue: s.rain) ?? .none, width: 172, animate: false)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 8)
        }
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.white.opacity(0.9), lineWidth: 4))
    }

    // MARK: 4 · 비 오기 1시간 전 미리 알려줘요

    /// The island the alert opens and the lock-screen card, big, the character under its umbrella beside them
    private var rainAlert: some View {
        let lv = Rules.clamp(model.scene.level)
        let a = RainActivityAttributes(place: model.currentPlace.short, character: model.shownCharacter.rawValue, level: lv)
        let now = Int(Date().timeIntervalSince1970)
        let soon = RainActivityAttributes.ContentState(title: L("%@쯤 비 예보", HourLabel.word(18, clock12: model.clock12)), sub: "1mm · " + L("우산 챙기세요"),
                                                       icon: "umbrella_closed", what: "rain", falling: false, mm: 1, start: now + 3600, end: now + 3 * 3600, endHour: 20)
        let k: CGFloat = 1.08
        return shot(L("비 오기 1시간 전"), L("미리 알려줘요"), bg: [], plus: true) {
            ZStack(alignment: .top) {
                VStack(spacing: 12) {
                    label(L("다이내믹 아일랜드"))
                    island(a, soon).scaleEffect(k).frame(height: 132 * k).shadow(color: .black.opacity(0.35), radius: 18, y: 10)
                    label(L("잠금 화면")).padding(.top, 22)
                    RainLockView(a: a, s: soon)
                        .frame(width: 370)
                        .background(Color(hex: "#141938").opacity(0.96), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .scaleEffect(k).padding(.vertical, 10)
                        .shadow(color: .black.opacity(0.3), radius: 14, y: 8)
                }
                CharacterSprite(character: model.shownCharacter, level: lv, rain: .umbrella, width: 250, animate: false)
                    .offset(x: 80, y: 360)
            }
            .padding(.top, 10)
        }
        .background {
            ZStack(alignment: .top) {
                LinearGradient(colors: [Color(hex: "#3A4890"), Color(hex: "#1A2050")], startPoint: .top, endPoint: .bottom)
                SkyParticles(scene: SceneLibrary.scene("spring_rain"), width: Self.canvas.width, tiles: 3, animate: false)
                    .frame(width: Self.canvas.width, height: Self.canvas.height, alignment: .top).opacity(0.5)
            }
        }
    }

    // MARK: 5 · 언제, 얼마나 비가 오는지

    private var nextHours: some View {
        shot(L("언제, 얼마나"), L("비가 오는지"), bg: ["#3FA9E8", "#1D74C2"], plus: true) {
            ZStack(alignment: .bottomTrailing) {
                zoomed(1.04, height: 600) { HomeView(route: .constant(nil), day: .constant(nil), focus: "next6") }
                CharacterSprite(character: model.shownCharacter, level: Rules.clamp(model.scene.level), rain: .umbrella, width: 210, animate: false)
                    .offset(x: -4, y: 150)
            }
        }
    }

    // MARK: 6 · 미세먼지도 한눈에

    private var dust: some View {
        shot(L("미세먼지도"), L("한눈에"), bg: ["#F2A541", "#D9781F"]) {
            ZStack(alignment: .bottomLeading) {
                zoomed(1.04, height: 600) { DayDetailView(start: 0, startMetric: .dust, focus: true) }
                    .background(Color(hex: "#FFF6E6"), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                cat(model.scene, width: 200, bubbleSize: 0).offset(x: 8, y: 170)
            }
        }
    }

    // MARK: 7 · 홈 화면에서 바로 확인해요

    private var widgets: some View {
        let snap = model.snapshot
        return shot(L("홈 화면에서"), L("바로 확인해요"), bg: ["#4CC38A", "#23955F"]) {
            phone(dark: false) {
                ZStack(alignment: .top) {
                    LinearGradient(colors: [Color(hex: "#B9D3F2"), Color(hex: "#E8D9F2")], startPoint: .top, endPoint: .bottom)
                    VStack(spacing: 22) {
                        widget(364, 170, snap) { MediumWidgetView(snap: snap) }
                        widget(364, 170, snap) { HoursWidgetView(snap: snap) }
                        HStack(alignment: .top, spacing: 24) {
                            widget(170, 170, snap) { SmallWidgetView(snap: snap) }
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(62), spacing: 24), count: 2), spacing: 24) {
                                ForEach(0..<4, id: \.self) { _ in blankIcon }
                            }
                        }
                        Spacer()
                        HStack(spacing: 28) { ForEach(0..<4, id: \.self) { _ in blankIcon } }
                            .padding(.vertical, 14).padding(.horizontal, 18)
                            .background(Color.white.opacity(0.28), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                            .padding(.bottom, 14)
                    }
                    .padding(.top, 70)
                }
            }
        }
    }

    // MARK: 8 · 애플워치에서도 고양이와 함께

    /// Two faces with the complications, the watch app, and the complications themselves large
    private var watch: some View {
        let snap = model.snapshot
        return shot(L("애플워치에서도"), L("고양이와 함께"), bg: ["#363B5E", "#121428"], plus: true) {
            VStack(spacing: 18) {
                HStack(spacing: 10) {
                    WatchCase(scale: 0.93) { WatchFacePreview(snap: snap) }
                    WatchCase(scale: 0.93) { WatchAnalogPreview(snap: snap) }
                }
                WatchCase(scale: 0.93) { WatchAppScreen(snap: snap) }
                HStack(spacing: 16) {
                    piece { WatchTempGauge(snap: snap) }
                    piece { WatchRainRing(snap: snap) }
                    piece { WatchSunDisc(snap: snap) }
                    piece { WatchCatSlot(snap: snap) }
                }
            }
            .padding(.top, 6)
        }
    }

    private func piece<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        c().foregroundStyle(.white).frame(width: 54, height: 54)
            .scaleEffect(1.45).frame(width: 80, height: 80)
            .background(Color(hex: "#1C1C22"), in: Circle())
    }

    // MARK: parts

    /// The caption (two lines, the app's pixel font; the second in the highlight colour) over the background, the
    /// page's picture under it, and — App Review 2.3.2 — the subscription named in small type at the bottom
    private func shot<C: View>(_ l1: String, _ l2: String, bg: [String], light: Bool = true, plus: Bool = false, @ViewBuilder _ c: () -> C) -> some View {
        let ink = light ? Color.white : Color(hex: "#1E2A44")
        let hi = light ? yellow : Color(hex: "#E2603A")
        return VStack(spacing: 0) {
            VStack(spacing: 10) {
                Text(l1).font(.px(38)).foregroundStyle(ink)
                Text(l2).font(.px(38)).foregroundStyle(hi)
            }
            .shadow(color: .black.opacity(light ? 0.18 : 0), radius: 0, x: 0, y: 3)
            .multilineTextAlignment(.center)
            .lineLimit(1).minimumScaleFactor(0.6)
            .padding(.horizontal, 22)
            .padding(.top, 60)
            .frame(height: 200, alignment: .top)
            c().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .overlay(alignment: .bottom) {
            if plus {
                Text(L("Plus 구독 기능")).font(.ui(13, .medium)).foregroundStyle(ink.opacity(0.75)).padding(.bottom, 22)
            }
        }
        .background { if !bg.isEmpty { LinearGradient(colors: bg.map { Color(hex: $0) }, startPoint: .top, endPoint: .bottom) } }
    }

    /// The character dressed for `s`, with the bubble over its head (or umbrella) when `bubbleSize` > 0
    private func cat(_ s: WeatherScene, width catW: CGFloat, bubbleSize: CGFloat) -> some View {
        let lv = Rules.clamp(s.level), rain = RainState(rawValue: s.rain) ?? .none
        let catH = catW * Sprite.height / Sprite.width, a = model.shownCharacter.anchors
        let tipY = CGFloat(rain == .umbrella ? a.umb_top[lv] : a.head_top[lv]) / Sprite.height * catH
        let tipX = (rain == .umbrella ? Sprite.umbrellaTipX : CGFloat(a.head_cx[lv])) / Sprite.width * catW
        return ZStack(alignment: .topLeading) {
            CharacterSprite(character: model.shownCharacter, level: lv, rain: rain, mood: Mood(rawValue: s.mood ?? "normal") ?? .normal, width: catW, animate: false)
            if bubbleSize > 0, let b = s.bubble {
                BubbleView(kind: b.kind, tone: b.tone, icon: b.icon, text: HomeView.bubbleLines(model.say(b.text)), fontSize: bubbleSize)
                    .fixedSize()
                    .alignmentGuide(.leading) { d in d.width / 2 - tipX }
                    .alignmentGuide(.top) { d in d.height - tipY + 6 }
            }
        }
        .frame(width: catW, height: catH, alignment: .topLeading)
    }

    /// A small heading over a part of the picture
    private func label(_ t: String) -> some View {
        Text(t).font(.ui(13, .semibold)).foregroundStyle(Color.white.opacity(0.7))
    }

    /// A part of the app laid out at the phone's width (402 pt) and shown `k` times larger, its top under the caption
    private func zoomed<C: View>(_ k: CGFloat, height: CGFloat, @ViewBuilder _ c: () -> C) -> some View {
        c().frame(width: 402, height: height / k, alignment: .top)
            .scaleEffect(k, anchor: .top)
            .frame(width: 402 * k, height: height, alignment: .top)
            .padding(.top, 6)
    }

    /// An iPhone (402 × 874 screen at 0.8) running `content`, its bottom running off the picture
    private func phone<C: View>(dark: Bool, @ViewBuilder _ content: () -> C) -> some View {
        let w: CGFloat = 402, h: CGFloat = 874, k: CGFloat = 0.8, bezel: CGFloat = 11
        return ZStack(alignment: .top) {
            content()
                .frame(width: w, height: h, alignment: .top)
                .clipped()
            statusBar(dark: dark)
            Capsule().fill(Color.black).frame(width: 126, height: 37).padding(.top, 11)   // the island
        }
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: 55, style: .continuous))
        .padding(bezel)
        .background(RoundedRectangle(cornerRadius: 55 + bezel, style: .continuous).fill(Color(hex: "#15161C")))
        .overlay(RoundedRectangle(cornerRadius: 55 + bezel, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 1.5))
        .scaleEffect(k, anchor: .top)
        .frame(width: (w + 2 * bezel) * k, height: (h + 2 * bezel) * k, alignment: .top)
        .shadow(color: .black.opacity(0.22), radius: 22, y: 12)
        .environment(\.colorScheme, .light)
    }

    /// 9:41 and the bars, as the system draws them
    private func statusBar(dark: Bool) -> some View {
        HStack {
            Text("9:41").font(.system(size: 17, weight: .semibold)).padding(.leading, 30)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "cellularbars"); Image(systemName: "wifi"); Image(systemName: "battery.100")
            }
            .font(.system(size: 15, weight: .semibold)).padding(.trailing, 28)
        }
        .foregroundStyle(dark ? Color.white : Color.black)
        .frame(height: 54)
    }

    private func widget<C: View>(_ w: CGFloat, _ h: CGFloat, _ snap: WeatherSnapshot, @ViewBuilder _ c: () -> C) -> some View {
        c().padding(16).frame(width: w, height: h)
            .background(WidgetBackground(level: snap.scene.level, night: snap.scene.isNight, scene: snap.scene))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
    }

    /// Another app's place on the home screen: a plain frosted tile (no real app's icon)
    private var blankIcon: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.white.opacity(0.45)).frame(width: 62, height: 62)
    }

    /// The Dynamic Island opened by the alert (≈ 371 pt wide), as the system draws a Live Activity's expanded form
    private func island(_ a: RainActivityAttributes, _ s: RainActivityAttributes.ContentState) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                RainCat(a: a, s: s, width: 48).padding(.leading, 4)
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.title).font(.px(17)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                    Text(a.place.isEmpty ? s.sub : "\(a.place) · \(s.sub)").font(.ui(12)).foregroundStyle(Color(hex: "#C9D0F0")).lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            RainBar(s: s).padding(.horizontal, 4).padding(.top, 2)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(width: 371)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 44, style: .continuous))
    }
}
