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
        case 6: tenDays
        case 7: dust
        case 8: widgets
        case 9: lockScreen
        case 10: watch
        default: hero
        }
    }

    /// One family of colours for every page: the app's sky, lighter or deeper (the outfit page keeps its own warm-to-
    /// cool wash, the night pages go deep)
    private enum Tone {
        static let hero = ["#8DB6EC", "#5C8ED6"], skies = ["#86A2E2", "#5873C6"], rain = ["#3A4890", "#1A2050"]
        static let hours = ["#7FAEE6", "#4C7CC6"], days = ["#8FB2E8", "#6185CF"], dust = ["#94A6DD", "#6878BE"], widgets = ["#86B9DF", "#5A8CC4"]
        static let lock = ["#5B66A8", "#2E3470"], watch = ["#363B5E", "#121428"]
    }

    // MARK: 1 · 오늘 뭐 입지? 고양이를 보면 알아요

    /// The character at the bottom and, over its head, the bubbles it says on other days popping up one over another
    /// (each half under the next: the icons show, the words may not); today's bubble in front, on its head
    private var hero: some View {
        let s = model.scene
        // what it says on other days, top (back) to bottom (front)
        let others: [(String, String, String, String)] = [
            ("speech", "white", "cloud", L("안개가 짙어요!")),
            ("shout", "coral", "lightning", L("천둥번개!")),
            ("speech", "sky", "snowflake", L("폭설!")),
            ("speech", "white", "mask", L("미세먼지 나쁨 · 마스크 챙기세요")),
            ("speech", "night", "daynight", L("일교차 커요!")),
            ("shout", "coral", "thermo_hot", L("폭염!")),
            ("speech", "sky", "umbrella_closed", L("%@ %@ 예보", HourLabel.window(16, 19, clock12: model.clock12), L("비"))),
        ]
        // bursting out over the head: where each one lands, its tilt and size (the words may run under the next)
        let spots: [(x: CGFloat, y: CGFloat, r: Double, k: CGFloat)] = [
            (-100, 0, -9, 1.15), (100, 20, 8, 1.25), (-6, 70, -4, 1.2), (-90, 134, 6, 1.3),
            (104, 150, -7, 1.2), (40, 214, 5, 1.35), (-96, 248, -6, 1.25),
        ]
        return shot(L("오늘 뭐 입지?"), L("캐릭터를 보면 알아요"), bg: Tone.hero) {
            VStack(spacing: -34) {
                ZStack(alignment: .top) {
                    ForEach(Array(others.enumerated()), id: \.offset) { i, b in
                        BubbleView(kind: b.0, tone: b.1, icon: b.2, text: b.3, fontSize: 26)
                            .fixedSize()
                            .scaleEffect(spots[i].k)
                            .rotationEffect(.degrees(spots[i].r))
                            .offset(x: spots[i].x, y: spots[i].y)
                            .zIndex(Double(i))
                    }
                }
                .frame(width: Self.canvas.width, height: 330, alignment: .top)
                .zIndex(1)
                cat(s, width: 290, bubbleSize: 28).zIndex(2)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 14)
        }
    }

    // MARK: 2 · 체감온도에 맞춰 옷을 갈아입어요

    /// Nine of the fifteen outfits, hot to cold, each on its own colour
    private var outfits: some View {
        let steps: [(Int, Int)] = [(0, 36), (2, 30), (3, 25), (5, 19), (6, 17), (8, 10), (10, 4), (12, -2), (14, -12)]
        return shot(L("체감온도에 맞춰"), L("옷을 갈아입어요"), bg: ["#FFD9BF", "#B7C6EA"], light: false) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(130), spacing: 8), count: 3), spacing: 12) {
                ForEach(steps, id: \.0) { lv, t in
                    VStack(spacing: 4) {
                        CharacterSprite(character: model.shownCharacter, level: lv, rain: .none, width: 130, animate: false)
                            .frame(width: 130, height: 152, alignment: .bottom)
                        Text("\(t)°").font(.px(24)).foregroundStyle(Color(hex: "#1E2A44"))
                    }
                    .padding(.vertical, 8)
                    .frame(width: 130)
                    .background(Color(hex: Rules.background[lv]).opacity(0.85), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
            }
            .padding(.top, 20)
        }
    }

    // MARK: 3 · 하늘이 바뀌면 고양이도 바뀌어요

    /// Four weathers, each tile its own sky with the character dressed for it
    private var skies: some View {
        let keys = ["summer_heat", "spring_rain", "winter_snow", "summer_night"]
        return shot(L("구름이 흐르고"), L("비와 눈이 내려요"), bg: Tone.skies) {
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
        let soon = RainActivityAttributes.ContentState(title: L("%@쯤 비 예보", HourLabel.word(16, clock12: model.clock12)), sub: "1mm · " + L("우산 챙기세요"),
                                                       icon: "umbrella_closed", what: "rain", falling: false, mm: 1, start: now + 3600, end: now + 3 * 3600, endHour: 19)
        return shot(L("비 오기 1시간 전"), L("미리 알려줘요"), bg: [], plus: true) {
            VStack(spacing: 14) {
                // the phone in use: the island opens with the alert over whatever is on the screen
                phone(dark: false, scale: 1.1, topInset: 54, island: AnyView(island(a, soon))) {
                    HomeView(route: .constant(nil), day: .constant(nil))
                }
                .frame(width: Self.canvas.width, height: 470, alignment: .top)
                .clipped()
                .mask(LinearGradient(stops: [.init(color: .black, location: 0.8), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                label(L("잠금 화면")).padding(.top, 8)
                RainLockView(a: a, s: soon)
                    .frame(width: 336)
                    .background(Color(hex: "#141938").opacity(0.96), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .scaleEffect(1.22).padding(.vertical, 18)
                    .shadow(color: .black.opacity(0.3), radius: 14, y: 8)
            }
            .padding(.top, 2)
        }
        .background {
            ZStack(alignment: .top) {
                LinearGradient(colors: Tone.rain.map { Color(hex: $0) }, startPoint: .top, endPoint: .bottom)
                SkyParticles(scene: SceneLibrary.scene("spring_rain"), width: Self.canvas.width, tiles: 3, animate: false)
                    .frame(width: Self.canvas.width, height: Self.canvas.height, alignment: .top).opacity(0.5)
            }
        }
    }

    // MARK: 5 · 언제, 얼마나 비가 오는지

    /// The next six hours, big: when it starts, a bar per hour with its amount, the hour and its chance
    private var nextHours: some View {
        let s = model.scene, six = s.next6 ?? []
        let R = six.map { $0.mm }, peak = max(R.max() ?? 0, 1)
        // the same words as the app's card: the first rainy stretch, "15~17시 비 예보"
        let hr = { (i: Int) -> Int in HourLabel.hour(six[i].label) ?? 0 }
        var head = L("6시간 동안 비 소식 없어요")
        if let st = R.firstIndex(where: { $0 >= 0.1 }) {
            let en = R[st...].firstIndex(where: { $0 < 0.1 }), last = en == nil ? R.count - 1 : en! - 1
            head = st == 0 ? L("지금 %@ · 시간당 %@", L("비"), "\(HomeView.mmText(R[0]))mm")
                : st == last ? L("%@쯤 %@ 예보", HourLabel.word(hr(st), clock12: model.clock12), L("비"))
                : L("%@ %@ 예보", HourLabel.window(hr(st), hr(last), clock12: model.clock12), L("비"))
        }
        return shot(L("언제, 얼마나"), L("비가 오는지"), bg: Tone.hours, plus: true) {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 12) {
                    PixelIcon(name: "umbrella_closed", size: 34)
                    Text(head).font(.px(28)).lineLimit(1).minimumScaleFactor(0.7)
                }
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(Array(six.enumerated()), id: \.offset) { i, r in
                        VStack(spacing: 8) {
                            Text(r.mm >= 0.1 ? "\(HomeView.mmText(r.mm))mm" : " ").font(.px(16)).foregroundStyle(Color(hex: "#2F6BD8"))
                                .lineLimit(1).minimumScaleFactor(0.6)
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(r.mm >= 0.1 ? Color(hex: "#3D7BE8") : Color(hex: "#D8E2F4"))
                                .frame(height: r.mm >= 0.1 ? max(14, r.mm / peak * 380) : 8)
                            Text(model.hourLabel(r.label)).font(.px(17)).lineLimit(1).minimumScaleFactor(0.7)
                            let c = s.hours.first { $0.label == r.label }?.chance ?? 0
                            Text(c >= 10 ? "\(c)%" : "–").font(.px(16)).foregroundStyle(c >= 10 ? Color(hex: "#2F6BD8") : Color(hex: "#9AA6C0"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 490, alignment: .bottom)
            }
            .foregroundStyle(Color(hex: "#1E2A44"))
            .padding(24)
            .frame(width: 400)
            .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 18, y: 10)
            .padding(.top, 16)
        }
    }

    // MARK: 6 · 열흘 뒤 날씨까지 미리 볼 수 있어요

    /// The ten days, big: the day, its weather, the chance of rain, the low, the range and the high
    private var tenDays: some View {
        let days = model.scene.days
        let lo = days.map(\.lo).min() ?? 0, hi = days.map(\.hi).max() ?? 1, span = CGFloat(max(1, hi - lo))
        return shot(L("열흘 뒤 날씨까지"), L("미리 볼 수 있어요"), bg: Tone.days) {
            VStack(spacing: 0) {
                ForEach(Array(days.prefix(10).enumerated()), id: \.offset) { i, d in
                    HStack(spacing: 10) {
                        Text(d.name).font(.px(21)).frame(width: 50, alignment: .leading).lineLimit(1).minimumScaleFactor(0.6)
                        PixelIcon(name: d.icon, size: 32)
                        Text(d.chance >= 10 ? "\(d.chance)%" : "").font(.px(15)).foregroundStyle(Color(hex: "#2F6BD8")).frame(width: 44, alignment: .leading)
                        Text(model.deg(d.lo)).font(.px(20)).foregroundStyle(Color(hex: "#6B7894")).frame(width: 40, alignment: .trailing)
                        GeometryReader { g in
                            let x0 = CGFloat(d.lo - lo) / span * g.size.width, x1 = CGFloat(d.hi - lo) / span * g.size.width
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(hex: "#E3E8F2")).frame(height: 8)
                                Capsule().fill(LinearGradient(colors: [Color(hex: "#6FA8FF"), Color(hex: "#FFA94D")], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(8, x1 - x0), height: 8).offset(x: x0)
                            }
                            .frame(maxHeight: .infinity)
                        }
                        Text(model.deg(d.hi)).font(.px(20)).frame(width: 40, alignment: .trailing)
                    }
                    .frame(height: 62)
                    if i < min(days.count, 10) - 1 { Rectangle().fill(Color(hex: "#E8ECF4")).frame(height: 1) }
                }
            }
            .foregroundStyle(Color(hex: "#1E2A44"))
            .padding(.horizontal, 20).padding(.vertical, 8)
            .frame(width: 404)
            .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 18, y: 10)
            .padding(.top, 10)
        }
    }

    // MARK: 7 · 미세먼지도 한눈에

    private var dust: some View {
        shot(L("미세먼지도"), L("한눈에"), bg: Tone.dust) {
            zoomed(1.09, height: 700) { DayDetailView(start: 0, startMetric: .dust, focus: true) }
                .background(Color(hex: "#FFF6E6"), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        }
    }

    // MARK: 7 · 홈 화면에서 바로 확인해요

    private var widgets: some View {
        let snap = model.snapshot
        return shot(L("홈 화면에서"), L("바로 확인해요"), bg: Tone.widgets) {
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

    // MARK: 8 · 잠금화면에서도 바로 보여요

    /// The top of a lock screen, large: the inline line over the time, the rectangle and two circles under it, the
    /// app's sky as the wallpaper, the character in front
    private var lockScreen: some View {
        let snap = model.snapshot, s = snap.scene, lv = Rules.clamp(s.level)
        return shot(L("잠금화면에서도"), L("바로 보여요"), bg: []) {
            VStack(spacing: 6) {
                Text(LockText.inline(snap)).font(.system(size: 19, weight: .semibold)).lineLimit(1)
                Text("9:41").font(.system(size: 112, weight: .bold, design: .rounded)).padding(.top, -10)
                HStack(alignment: .top, spacing: 10) {
                    glass(166, 74) { LockRectangularView(snap: snap) }
                    glass(74, 74, circle: true) { LockCircularView(snap: snap) }
                    glass(74, 74, circle: true) { LockDustCircularView(snap: snap) }
                }
                .scaleEffect(1.15)
                .padding(.top, 16)
                CharacterSprite(character: model.shownCharacter, level: lv, rain: RainState(rawValue: s.rain) ?? .none, width: 270, animate: false)
                    .padding(.top, 40)
            }
            .foregroundStyle(.white)
            .padding(.top, 14)
        }
        .background {
            ZStack(alignment: .top) {
                LinearGradient(colors: Tone.lock.map { Color(hex: $0) }, startPoint: .top, endPoint: .bottom)
                SkyParticles(scene: s, width: Self.canvas.width, tiles: 3, animate: false)
                    .frame(width: Self.canvas.width, height: Self.canvas.height, alignment: .top).opacity(0.5)
            }
        }
    }

    /// A lock-screen widget as iOS draws it: straight on the wallpaper, nothing behind it
    private func glass<C: View>(_ w: CGFloat, _ h: CGFloat, circle: Bool = false, @ViewBuilder _ c: () -> C) -> some View {
        c().foregroundStyle(.white).frame(width: w, height: h).padding(circle ? 0 : 8)
    }

    // MARK: 9 · 애플워치에서도 캐릭터와 함께

    /// Two faces with the complications, the watch app, and the complications themselves large
    private var watch: some View {
        let snap = model.snapshot
        return shot(L("애플워치에서도"), L("캐릭터와 함께"), bg: Tone.watch, plus: true) {
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
    private func shot<C: View>(_ l1: String, _ l2: String, bg: [String], light: Bool = true, plus: Bool = false, highlight: Color? = nil, @ViewBuilder _ c: () -> C) -> some View {
        let ink = light ? Color.white : Color(hex: "#1E2A44")
        let hi = highlight ?? (light ? yellow : Color(hex: "#E2603A"))
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

    /// An iPhone (402 × 874 screen at `k`) running `content`, its bottom running off the picture; `island` in place
    /// of the closed one (a Live Activity opening it), `topInset` the room the page leaves for the status bar
    private func phone<C: View>(dark: Bool, scale k: CGFloat = 0.8, topInset: CGFloat = 0, island: AnyView? = nil, @ViewBuilder _ content: () -> C) -> some View {
        let w: CGFloat = 402, h: CGFloat = 874, bezel: CGFloat = 11
        return ZStack(alignment: .top) {
            content()
                .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: topInset) }
                .frame(width: w, height: h, alignment: .top)
                .clipped()
            statusBar(dark: dark)
            if let island { island.padding(.top, 9).shadow(color: .black.opacity(0.3), radius: 12, y: 6) }
            else { Capsule().fill(Color.black).frame(width: 126, height: 37).padding(.top, 11) }
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
