import SwiftUI

/// The App Store screenshots (debug builds, `-storeShot 1…8`): a big two-line caption over the app's own views —
/// the home page, the day sheet, the widgets, the Live Activity, the watch — drawn by the app itself in its own
/// font, so every language comes out of the same build. Laid out for the 6.9-inch canvas (440 × 956 pt →
/// 1320 × 2868 px) and scaled to whatever simulator takes the picture.
struct StoreShotView: View {
    @EnvironmentObject var model: AppModel
    let page: Int

    static let canvas = CGSize(width: 440, height: 956)
    /// The phone inside the picture: an iPhone 16 Pro screen (402 × 874) drawn at this scale
    static let phoneK: CGFloat = 0.8

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

    // MARK: pages

    @ViewBuilder private var content: some View {
        switch page {
        case 2: outfits
        case 3: rainAlert
        case 4: nextHours
        case 5: dust
        case 6: widgets
        case 7: watch
        case 8: characters
        default: hero
        }
    }

    /// 1 · 오늘 뭐 입지? 고양이를 보면 알아요 — the app's sky over the whole picture, the character big with its
    /// bubble, the temperature and the weather in words beside it
    private var hero: some View {
        let s = model.scene, lv = Rules.clamp(s.level), ink = Ink(night: s.isNight)
        let rain = RainState(rawValue: s.rain) ?? .none
        let catW: CGFloat = 300, catH = catW * Sprite.height / Sprite.width
        let a = model.shownCharacter.anchors
        let tipY = CGFloat(rain == .umbrella ? a.umb_top[lv] : a.head_top[lv]) / Sprite.height * catH
        let tipX = (rain == .umbrella ? Sprite.umbrellaTipX : CGFloat(a.head_cx[lv])) / Sprite.width * catW
        return shot(L("오늘 뭐 입지?"), L("고양이를 보면 알아요"), bg: [], light: s.isNight) {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .trailing, spacing: 12) {
                    Text(deg(s.temp)).font(.px(120))
                    Text(s.cond).font(.px(26))
                    Text(L("최고 %@ · 최저 %@", deg(s.hi), deg(s.lo))).font(.px(18))
                }
                .foregroundStyle(ink.ink)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 30).padding(.top, 10)
                ZStack(alignment: .topLeading) {
                    CharacterSprite(character: model.shownCharacter, level: lv, rain: rain, mood: Mood(rawValue: s.mood ?? "normal") ?? .normal, width: catW, animate: false)
                    if let b = s.bubble {
                        BubbleView(kind: b.kind, tone: b.tone, icon: b.icon, text: HomeView.bubbleLines(model.say(b.text)), fontSize: 21)
                            .fixedSize()
                            .alignmentGuide(.leading) { d in d.width / 2 - tipX }
                            .alignmentGuide(.top) { d in d.height - tipY + 6 }
                    }
                }
                .frame(width: catW, height: catH, alignment: .topLeading)
                .padding(.leading, 24)
                .frame(maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.bottom, 18)
            }
        }
        .background {
            ZStack {
                SkyBase(level: lv, night: s.isNight)
                SkyTint(scene: s)
                SkyParticles(scene: s, width: Self.canvas.width, tiles: 3, animate: false)
                    .frame(width: Self.canvas.width, height: Self.canvas.height, alignment: .top)
            }
        }
    }

    /// 2 · 체감온도에 맞춰 옷을 갈아입어요 — six of the fifteen outfits, hot to cold
    private var outfits: some View {
        let steps: [(Int, Int)] = [(1, 34), (3, 25), (6, 17), (8, 10), (11, 1), (14, -12)]
        return shot(L("체감온도에 맞춰"), L("옷을 갈아입어요"), bg: ["#FFD9BF", "#B7C6EA"]) {
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
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    /// 3 · 비 오기 1시간 전 미리 알려줘요 — the lock screen with the rain Live Activity, the island floating above
    private var rainAlert: some View {
        let lv = Rules.clamp(model.scene.level)
        let a = RainActivityAttributes(place: model.currentPlace.short, character: model.shownCharacter.rawValue, level: lv)
        let now = Int(Date().timeIntervalSince1970)
        let soon = RainActivityAttributes.ContentState(title: L("%@쯤 비 예보", HourLabel.word(18, clock12: model.clock12)), sub: "1mm · " + L("우산 챙기세요"),
                                                       icon: "umbrella_closed", what: "rain", falling: false, mm: 1, start: now + 3600, end: now + 3 * 3600, endHour: 20)
        let k: CGFloat = 1.08
        return shot(L("비 오기 1시간 전"), L("미리 알려줘요"), bg: [], light: true, plus: true) {
            VStack(spacing: 14) {
                label(L("다이내믹 아일랜드"))
                island(a, soon).scaleEffect(k).frame(height: 132 * k).shadow(color: .black.opacity(0.35), radius: 18, y: 10)
                label(L("잠금 화면")).padding(.top, 34)
                VStack(spacing: 0) {
                    Text("9:41").font(.system(size: 92, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.92))
                    HStack(spacing: 14) {
                        lockCircle { LockCircularView(snap: model.snapshot) }
                        lockCircle { LockRainCircularView(snap: model.snapshot) }
                        lockCircle { LockDustCircularView(snap: model.snapshot) }
                    }
                    .padding(.bottom, 26)
                    RainLockView(a: a, s: soon)
                        .frame(width: 370)
                        .background(Color(hex: "#141938").opacity(0.95), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .scaleEffect(k).padding(.vertical, 8)
                        .shadow(color: .black.opacity(0.3), radius: 14, y: 8)
                }
            }
            .padding(.top, 18)
        }
        .background {
            ZStack(alignment: .top) {
                LinearGradient(colors: [Color(hex: "#3A4478"), Color(hex: "#1A2046")], startPoint: .top, endPoint: .bottom)
                SkyParticles(scene: SceneLibrary.scene("spring_rain"), width: Self.canvas.width, tiles: 3, animate: false)
                    .frame(width: Self.canvas.width, height: Self.canvas.height, alignment: .top).opacity(0.45)
            }
        }
    }

    /// 4 · 언제, 얼마나 비가 오는지 — the home page scrolled to the next six hours
    private var nextHours: some View {
        shot(L("언제, 얼마나"), L("비가 오는지"), bg: ["#CDDCEF", "#93ABDB"], plus: true) {
            zoomed(1.06, height: 640) { HomeView(route: .constant(nil), day: .constant(nil), focus: "next6") }
        }
    }

    /// 5 · 미세먼지도 한눈에 — the day sheet's 미세먼지 tab
    private var dust: some View {
        shot(L("미세먼지도"), L("한눈에"), bg: ["#F4E9CF", "#DCC79B"]) {
            zoomed(1.06, height: 700) { DayDetailView(start: 0, startMetric: .dust, focus: true) }
        }
    }

    /// 6 · 홈 화면에서 바로 확인해요 — the widgets on a home screen
    private var widgets: some View {
        let snap = model.snapshot
        return shot(L("홈 화면에서"), L("바로 확인해요"), bg: ["#DDF1D3", "#A6D3B6"]) {
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

    /// 7 · 애플워치에서도 고양이와 함께 — the watch app and a face with the complications
    private var watch: some View {
        let snap = model.snapshot
        return shot(L("애플워치에서도"), L("고양이와 함께"), bg: ["#3B3F5C", "#16182A"], light: true, plus: true) {
            // the face with the complications big, the watch app beside it
            ZStack {
                WatchCase(scale: 0.8) { WatchAppScreen(snap: snap) }.offset(x: -118, y: -150)
                WatchCase(scale: 1.45) { WatchFacePreview(snap: snap) }.offset(x: 40, y: 110)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 8 · 세 마리 중에 골라요 — the three characters, the cat in front
    private var characters: some View {
        func one(_ c: PurrCharacter, _ w: CGFloat) -> some View {
            VStack(spacing: 8) {
                CharacterSprite(character: c, level: 6, rain: .none, width: w, animate: false)
                Text(model.name(of: c)).font(.px(20)).foregroundStyle(Color(hex: "#1E2A44"))
                    .lineLimit(1).minimumScaleFactor(0.6).frame(width: 200)
            }
        }
        return shot(L("세 마리 중에"), L("골라요"), bg: ["#FFEBB0", "#FFC2A8"], plus: true) {
            ZStack {
                one(.abys, 190).offset(x: -112, y: -60)
                one(.brit, 190).offset(x: 112, y: -60)
                one(.cat, 230).offset(y: 150)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: parts

    private func deg(_ v: Int) -> String { model.deg(v) }

    /// A small grey heading over a part of the picture
    private func label(_ t: String) -> some View {
        Text(t).font(.ui(13, .semibold)).foregroundStyle(Color.white.opacity(0.65))
    }

    /// A part of the app laid out at the phone's width (402 pt) and shown `k` times larger, its top under the caption
    private func zoomed<C: View>(_ k: CGFloat, height: CGFloat, @ViewBuilder _ c: () -> C) -> some View {
        c().frame(width: 402, height: height / k, alignment: .top)
            .scaleEffect(k, anchor: .top)
            .frame(width: 402 * k, height: height, alignment: .top)
            .padding(.top, 6)
    }

    /// The caption (two lines, the app's pixel font) over a soft gradient, then the page's picture
    private func shot<C: View>(_ l1: String, _ l2: String, bg: [String], light: Bool = false, plus: Bool = false, @ViewBuilder _ c: () -> C) -> some View {
        let ink = light ? Color.white : Color(hex: "#1E2A44")
        return VStack(spacing: 0) {
            VStack(spacing: 10) {
                Text(l1).font(.px(36))
                Text(l2).font(.px(36))
            }
            .foregroundStyle(ink)
            .multilineTextAlignment(.center)
            .lineLimit(1).minimumScaleFactor(0.6)
            .padding(.horizontal, 24)
            .padding(.top, 62)
            .frame(height: 200, alignment: .top)
            c().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        // App Review 2.3.2: what needs the subscription is said on the picture (small, at the bottom)
        .overlay(alignment: .bottom) {
            if plus {
                Text(L("Plus 구독 기능")).font(.ui(13, .medium)).foregroundStyle(ink.opacity(0.7)).padding(.bottom, 22)
            }
        }
        .background { if !bg.isEmpty { LinearGradient(colors: bg.map { Color(hex: $0) }, startPoint: .top, endPoint: .bottom) } }
    }

    /// An iPhone (402 × 874 screen at `phoneK`) running `content`, its bottom running off the picture; `lift` shows the
    /// content scrolled up by that many points
    private func phone<C: View>(dark: Bool, statusBar: Bool = true, lift: CGFloat = 0, @ViewBuilder _ content: () -> C) -> some View {
        let w: CGFloat = 402, h: CGFloat = 874, k = Self.phoneK, bezel: CGFloat = 11
        return ZStack(alignment: .top) {
            content()
                .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: lift > 0 ? 0 : 54) }
                .frame(width: w, height: h + lift)
                .offset(y: -lift)
                .frame(width: w, height: h, alignment: .top)
                .clipped()
            if statusBar { self.statusBar(dark: dark, solid: lift > 0) }
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

    /// 9:41 and the bars, as the system draws them; `solid` puts a strip behind them (a page scrolled under it)
    private func statusBar(dark: Bool, solid: Bool) -> some View {
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
        .background { if solid { Rectangle().fill(.ultraThinMaterial) } }
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

    private func lockCircle<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        c().foregroundStyle(.white).frame(width: 66, height: 66)
            .background(Color.white.opacity(0.16), in: Circle())
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
