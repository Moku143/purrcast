import SwiftUI

/// The home screen: sky + character + temperature up top, then the cards (next hour · hourly · 10 days · details).
struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @Binding var route: Route?
    @Binding var day: Int?
    private let heroH: CGFloat = 372
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var scrolled = false

    /// What the sky is made of; when it changes the whole sky cross-fades
    private func skyKey(_ s: WeatherScene) -> String { "\(s.time)|\(s.cover)|\(s.precip)|\(s.thunder)|\(s.aux)|\(s.clouds ?? -1)|\(s.fog)|\(s.gloom)" }

    var body: some View {
        let s = model.scene
        let ink = Ink(night: s.isNight)
        let lv = Rules.clamp(s.level)
        ZStack(alignment: .top) {
            background(level: lv, night: s.isNight).ignoresSafeArea()
                .animation(Motion.fade, value: lv).animation(Motion.fade, value: s.isNight)
            SkyTint(scene: s).ignoresSafeArea()
                .id("tint" + skyKey(s)).transition(.opacity)
            if model.hasData {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        // how far the page has scrolled (drives the compact header)
                        GeometryReader { g in
                            let y = g.frame(in: .named("home")).minY
                            Color.clear
                                .onAppear { setScrolled(y) }
                                .onChange(of: y) { _, v in setScrolled(v) }
                        }
                        .frame(height: 0)
                        hero(s, ink: ink, level: lv)
                            .frame(height: heroH)
                            .parallaxHero()
                        if let e = model.lastError { notice(e, ink: ink).transition(.move(edge: .top).combined(with: .opacity)) }
                        if let a = s.alert { alertBanner(a, ink: ink).reveal(0).settleInScroll() }
                        if let head = nextHour(s) { nextHourCard(s, head: head, ink: ink).reveal(1).settleInScroll() }
                        hourlyCard(s, ink: ink).reveal(2).settleInScroll()
                        dailyCard(s, ink: ink).reveal(3).settleInScroll()
                        tilesGrid(s, ink: ink).reveal(4).settleInScroll()
                        if !model.plus { PlusPromoCard(ink: ink) { route = .paywall }.reveal(5).settleInScroll() }
                        HomeFooter(scene: s, region: model.currentPlace.region, isSample: model.isSample, ink: ink) { route = .sources }.reveal(6)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 44)
                }
                .coordinateSpace(name: "home")
                .overlay(alignment: .top) {
                    CompactHeader(place: s.place ?? model.currentPlace.name, text: "\(deg(s.temp)) \(s.cond)", level: lv, ink: ink, shown: scrolled)
                }
                .refreshable { await model.refresh(force: true) }
                .transition(.opacity)
            } else {
                waiting(ink: ink).transition(.opacity)
            }
        }
        .foregroundStyle(ink.ink)
        .animation(Motion.fade, value: skyKey(s))
        .animation(Motion.gentle, value: model.hasData)
        .animation(Motion.gentle, value: model.lastError)
    }

    /// The compact header shows once the page has moved 240 pt up.
    private func setScrolled(_ y: CGFloat) {
        let on = y < -240
        if on != scrolled { DispatchQueue.main.async { scrolled = on } }
    }

    /// First launch, before any forecast arrived (or it failed): the cat waits, no made-up numbers.
    private func waiting(ink: Ink) -> some View {
        VStack(spacing: 18) {
            Spacer()
            CharacterSprite(character: model.shownCharacter, level: 5, rain: .none, width: 150)
            if model.lastError == nil {
                ProgressView().tint(ink.ink)
                Text(model.say(L("날씨를 불러오는 중이에요"))).font(.px(15))
            } else {
                Text(model.say(model.lastError ?? "")).font(.px(14)).multilineTextAlignment(.center).padding(.horizontal, 30)
                Button(L("다시 시도")) { Task { await model.refresh(force: true) } }
                    .font(.px(15)).padding(.horizontal, 22).padding(.vertical, 10).background(ink.btn).clipShape(Capsule())
                    .accessibilityIdentifier("retry")
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func notice(_ text: String, ink: Ink) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark").font(.ui(13, .bold))
            Text(model.say(text)).font(.ui(12, .medium))
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(ink.card).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    /// Official warning in force (호우주의보 …): its name and what it means today, under the character, above the hours.
    private func alertBanner(_ a: WeatherScene.Alert, ink: Ink) -> some View {
        HStack(spacing: 10) {
            PixelIcon(name: alertIcon(a.name), size: 18)
            (Text(a.name).font(.px(13)) + Text(" · ").font(.px(13)) + Text(model.say(a.note)).font(.px(13)))
                .lineLimit(3).minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(ink.night ? Color(hex: "#FF9A6A").opacity(0.18) : Color(hex: "#FFF1E6"))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ink.night ? Color(hex: "#FFB08A").opacity(0.5) : Color(hex: "#F0A070").opacity(0.7), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(ink.night ? Color(hex: "#FFD2BC") : Color(hex: "#8A3A1C"))
    }
    private func alertIcon(_ name: String) -> String {
        // the server names the warning in the app's language; match the Korean key or its translation
        func has(_ keys: String...) -> Bool { keys.contains { name.contains($0) || name.contains(L($0)) } }
        return has("대설") ? "snowflake" : has("태풍", "강풍", "풍랑", "폭풍") ? "wind"
        : has("호우") ? "raincloud" : has("폭염") ? "thermo_hot" : has("한파") ? "thermo_cold"
        : has("건조") ? "sun_strong" : "exclaim"
    }

    // MARK: hero

    private func background(level: Int, night: Bool) -> some View {
        SkyBase(level: level, night: night)
    }

    private func feelsPart(_ s: WeatherScene) -> some View {
        Text(L("체감 %@ %@", deg(s.feels), Rules.feelsWord(s.feels))).rolling(s.feels)
    }

    private func ydayPart(_ s: WeatherScene, _ ink: Ink) -> some View {
        HStack(spacing: 5) {
            Text(L("전일 대비"))
            Text(delta(s.yday)).foregroundStyle(s.yday > 0 ? ink.hot : (s.yday < 0 ? ink.blue : ink.ink)).rolling(s.yday)
        }
    }

    private func hero(_ s: WeatherScene, ink: Ink, level: Int) -> some View {
        let char = model.shownCharacter
        let rain = RainState(rawValue: s.rain) ?? .none
        let catW: CGFloat = 176, catH = catW * Sprite.height / Sprite.width
        // positions from the layout board (2026-10-29): the character a little lower and to the right, the temperature
        // a little lower, the weather words down beside the character's body
        let feetY: CGFloat = 379
        let catTop = feetY - Sprite.feetY / Sprite.height * catH
        let headX: CGFloat = 100 - 16 + 3.3   // hero is inside the 16 pt side padding
        let a = char.anchors
        let catLeft = headX - CGFloat(a.head_cx[level]) * catW / Sprite.width
        let tipY = catTop + CGFloat(rain == .umbrella ? a.umb_top[level] : a.head_top[level]) / Sprite.height * catH - 4

        return ZStack(alignment: .topLeading) {
            // top row: place + buttons
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Button { route = .places } label: {
                        HStack(spacing: 6) {
                            Image(systemName: model.hereIsLive && model.currentPlace.id == "here" ? "location.fill" : "mappin").font(.ui(13, .bold))
                            Text(s.place ?? model.currentPlace.name).font(.px(17))
                        }
                    }.buttonStyle(.press(0.97)).accessibilityIdentifier("place")
                    Text(s.isPlus ? L("%@ 업데이트 · Plus", s.updated) : L("오늘 %@ 기준", s.updated)).font(.px(11)).opacity(0.8)
                }
                Spacer()
                HStack(spacing: 8) {
                    roundButton(ink, id: "character", label: L("캐릭터")) { route = .character } content: { Image(char.faceImage).resizable().scaledToFit().frame(width: 26, height: 26) }
                    roundButton(ink, id: "places", label: L("지역")) { route = .places } content: { Image(systemName: "plus").font(.system(size: 16, weight: .bold)) }
                    roundButton(ink, id: "settings", label: L("설정")) { route = .settings } content: { Image(systemName: "gearshape.fill").font(.system(size: 16)) }
                }
            }
            .padding(.horizontal, 4).padding(.top, 8)

            // the temperature, right
            Text(deg(s.temp)).font(.px(88)).rolling(s.temp)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 12).padding(.top, 91)
                .reveal(0, rise: 10)

            // the weather in words, right, beside the character's body
            VStack(alignment: .trailing, spacing: 10) {
                Text(s.cond).font(.px(17)).id(s.cond).transition(.opacity.combined(with: .move(edge: .trailing)))
                Text(L("최고 %@ · 최저 %@", deg(s.hi), deg(s.lo))).font(.px(12)).rolling(s.hi * 1000 + s.lo)
                // one line when it fits beside the character's head, else two ("Feels 17° Pleasant" / "vs yesterday -1°")
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 5) { feelsPart(s); Text("·"); ydayPart(s, ink) }
                    VStack(alignment: .trailing, spacing: 6) { feelsPart(s); ydayPart(s, ink) }
                }
                .font(.px(12)).lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: 230, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 6).padding(.top, 303)
            .animation(Motion.gentle, value: s.cond)
            .reveal(0, rise: 10)

            // the character, feet on the first card (slides up into place on first show)
            CharacterSprite(character: char, level: level, rain: rain, mood: Mood(rawValue: s.mood ?? "normal") ?? .normal, width: catW)
                .offset(x: catLeft, y: catTop)
                .reveal(0, rise: 28)
                .animation(Motion.gentle, value: catLeft)

            if let b = s.bubble {
                BubbleView(kind: b.kind, tone: b.tone, icon: b.icon, text: model.say(b.text), live: true)
                    .fixedSize()
                    .alignmentGuide(.leading) { d in d.width / 2 - headX }
                    .alignmentGuide(.top) { d in d.height - tipY }
                    .id(b.text + b.icon)
                    .transition(.opacity)
            }
        }
        .animation(Motion.bouncy, value: s.bubble?.text)
        .frame(maxWidth: .infinity, minHeight: heroH, maxHeight: heroH, alignment: .topLeading)
        .background(alignment: .topLeading) {
            // weather pixels (clouds, rain, snow, wind …), edge to edge, two tiles high, fading out above the first card
            SkyParticles(scene: s, width: UIScreen.main.bounds.width, tiles: 2)
                .frame(width: UIScreen.main.bounds.width, height: heroH, alignment: .top)
                .clipped()
                .mask(LinearGradient(stops: [.init(color: .black, location: 0.7), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                .offset(x: -16)
                .id("sky" + skyKey(s)).transition(.opacity)
        }
    }

    private func roundButton<C: View>(_ ink: Ink, id: String, label: String, action: @escaping () -> Void, @ViewBuilder content c: () -> C) -> some View {
        Button { Haptic.soft(); action() } label: { c().frame(width: 36, height: 36).background(ink.btn).clipShape(Circle()) }
            .buttonStyle(.press(0.9)).accessibilityIdentifier(id).accessibilityLabel(label)
    }

    // MARK: cards

    /// Plus: rain coming soon. Korea → 기상청 초단기 next 6 hours; where Apple has minute-by-minute rain (Japan, the
    /// US, the UK, …) → the next hour by the minute; elsewhere → the next 6 hours from the hourly forecast.
    private func nextHour(_ s: WeatherScene) -> (title: String, legend: String, head: String, sub: String, icon: String, bars: [Double], ticks: [String])? {
        guard s.isPlus else { return nil }
        let nowMin: Int = WeatherScene.clockMinutes(s.clock) ?? 12 * 60
        // "강수확률 40% · " from the hours the card covers, left out when it would read 0 %
        let chanceTail = { (hours: Int) -> String in
            let c = s.hours.prefix(hours).map { $0.chance }.max() ?? 0
            return c >= 10 ? L("강수확률 %d%%", c) + " · " : ""
        }
        if s.nextSource != "kma", let mm = s.minutes, !mm.isEmpty { return minutesCard(s, mm, nowMin: nowMin, chanceTail: chanceTail(2)) }
        if let six = s.next6 {
            let R = six.map { $0.mm }
            var head = L("6시간 동안 비 소식 없어요"), sub = "", icon = "cloud"
            if let st = R.firstIndex(where: { $0 >= 0.1 }) {
                let en = R[st...].firstIndex(where: { $0 < 0.1 })
                let last = en == nil ? R.count - 1 : en! - 1
                // what falls in those hours: snow (sleet) when any wet hour says so — 초단기예보 and WeatherKit give snow
                // as water (mm), about as many cm of snow, so the card says "약 1cm"
                let wetRows = six[st...last]
                let snow = wetRows.contains { $0.snow } && !wetRows.contains { $0.kind == 0 }
                let sleet = !snow && wetRows.contains { $0.sleet || $0.snow }
                let what = snow ? L("눈") : sleet ? L("진눈깨비") : L("비")
                let amount = { (v: Double) -> String in snow ? L("약 %@cm", Self.mmText(v)) : "\(Self.mmText(v))mm" }
                // the hours people plan around: "15~17시 비 예보" (what the forecast says, not a promise); raining
                // now: how hard, "지금 비 · 시간당 2mm"
                let hr = { (i: Int) -> Int in HourLabel.hour(six[i].label) ?? 0 }
                head = st == 0 ? L("지금 %@ · 시간당 %@", what, amount(R[0]))
                    : (st == last ? L("%@쯤 %@ 예보", HourLabel.word(hr(st), clock12: model.clock12), what)
                                  : L("%@ %@ 예보", HourLabel.window(hr(st), hr(last), clock12: model.clock12), what))
                let peak = R.max() ?? 0
                // until when the forecast has it; past the 6 hours: the average and the heaviest hour instead
                let wet = Array(R[st...])
                let peakAt = st + (wet.firstIndex(of: peak) ?? 0)
                let stop = en == nil ? L("평균 시간당 %@ · 가장 많이 오는 때 %@", amount(wet.reduce(0, +) / Double(wet.count)), HourLabel.word(hr(peakAt), clock12: model.clock12))
                    : L("%@까지 %@ 예보", HourLabel.word((hr(last) + 1) % 24, clock12: model.clock12), what)
                let kind = snow ? "\(Rules.snowKind(peak)) · \(L("미끄러우니 조심하세요"))" : "\(Rules.rainKind(peak)) · \(Rules.rainKindNote(peak))"
                sub = chanceTail(7) + "\(kind) · \(stop)"
                icon = snow ? "snowflake" : sleet ? "sleet" : st == 0 ? "umbrella" : "umbrella_closed"
            }
            let legend = s.nextSource == "met" ? "MET Norway · Plus" : s.nextSource == "apple" ? L("Apple 날씨 · Plus") : L("기상청 초단기 · Plus")
            return (L("다음 6시간"), legend, head, sub, icon, R, six.map { model.hourLabel($0.label) })
        }
        if let mm = s.minutes, !mm.isEmpty { return minutesCard(s, mm, nowMin: nowMin, chanceTail: chanceTail(2)) }
        return nil
    }

    /// Rain per hour as people read it: "2", "0.5", "12"
    static func mmText(_ v: Double) -> String {
        v >= 10 ? String(Int(v.rounded())) : { let r = (v * 10).rounded() / 10; return r == r.rounded() ? String(Int(r)) : String(format: "%.1f", r) }()
    }

    private func minutesCard(_ s: WeatherScene, _ mm: [Double], nowMin: Int, chanceTail: String) -> (title: String, legend: String, head: String, sub: String, icon: String, bars: [Double], ticks: [String]) {
        var head = L("1시간 동안 비 소식 없어요"), sub = "", icon = "cloud"
        if let st = mm.firstIndex(where: { $0 >= 0.1 }) {
            let en = mm[st...].firstIndex(where: { $0 < 0.1 }).map { $0 - st }
            // clock times, pulled earlier to the 10 minutes for the start (15:57 → 15:50쯤) and later for the end
            let hhmm = { (t: Int) -> String in HourLabel.clock(t, clock12: model.clock12) }
            let s10 = (nowMin + st) / 10 * 10
            head = st == 0 ? L("지금 비 · 시간당 %@mm", Self.mmText(mm[0]))
                : (s10 > nowMin ? L("%@쯤 비 예보", hhmm(s10)) : L("%@ 전 비 예보", hhmm((nowMin + st + 9) / 10 * 10)))
            // until when, when it ends inside the hour; otherwise how hard it is already says what to do
            let stop = en == nil ? "" : " · " + L("%@까지 비 예보", hhmm((nowMin + st + en! + 9) / 10 * 10))
            let peak = mm.max() ?? 0
            sub = chanceTail + "\(Rules.rainKind(peak)) · \(Rules.rainKindNote(peak))" + stop
            icon = st == 0 ? "umbrella" : "umbrella_closed"
        } else if let h = s.hours.dropFirst().prefix(3).first(where: { $0.mm >= 0.1 || $0.chance >= 30 }) {
            // the minute forecast is dry for the hour, but the hourly one has rain soon after: say so, so the card
            // and the bubble ("22시쯤 비 예보") do not seem to disagree
            let at = model.hourLabel(h.label)
            sub = h.chance >= 10 ? L("시간별로는 %@쯤 비 예보 · 강수확률 %d%%", at, h.chance) : L("시간별로는 %@쯤 비 예보", at)
        }
        let span = mm.count
        return (L("다음 1시간"), L("분 단위 · Plus"), head, sub, icon, mm, [L("지금")] + [1, 2, 3, 4].map { L("%d분", span * $0 / 4) })
    }

    private func nextHourCard(_ s: WeatherScene, head: (title: String, legend: String, head: String, sub: String, icon: String, bars: [Double], ticks: [String]), ink: Ink) -> some View {
        let six = head.bars.count <= 6          // hours as fat bars, minutes as thin ones
        return Card(ink: ink) {
            HStack(alignment: .firstTextBaseline) { Text(head.title).font(.px(13)); Spacer(); Text(head.legend).font(.ui(11)).foregroundStyle(ink.sub) }
            HStack(spacing: 8) { PixelIcon(name: head.icon, size: 20); Text(model.say(head.head)).font(.px(15)).id(head.head).transition(.opacity) }
            if !head.sub.isEmpty { Text(model.say(head.sub)).font(.ui(12)).foregroundStyle(ink.sub).padding(.leading, 28).padding(.top, -9).fixedSize(horizontal: false, vertical: true) }
            ZStack(alignment: .bottomLeading) {
                ForEach(0..<3, id: \.self) { gi in
                    let labels = [L("약"), L("보통"), L("강")], levels: [Double] = [0.5, 2.5, 6.0]
                    let y = 64 - min(1, levels[gi] / 6) * 64
                    HStack(spacing: 4) {
                        Rectangle().fill(ink.line).frame(height: 1)
                        Text(labels[gi]).font(.ui(10)).foregroundStyle(ink.sub).frame(width: 22, alignment: .trailing)
                    }.offset(y: y - 64)
                }
                HStack(alignment: .bottom, spacing: six ? 8 : 1) {
                    ForEach(Array(head.bars.enumerated()), id: \.offset) { i, v in
                        GrowBar(height: v >= 0.1 ? max(3, min(1, v / 6) * 64) : 2, color: v >= 0.1 ? ink.blue : ink.track, radius: six ? 4 : 1, delay: Double(i) * (six ? 0.05 : 0.004))
                    }
                }.padding(.trailing, 26)
            }
            // bottom-aligned: with light rain the bars are only a few points tall, and a centred ZStack would
            // float the whole chart (강 line included) up into the words above it
            .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64, alignment: .bottomLeading)
            .padding(.top, 10)          // room for the 강 line's label above the bars, clear of the words over it
            HStack {
                ForEach(Array(head.ticks.enumerated()), id: \.offset) { i, t in
                    Text(t).font(.ui(10)).foregroundStyle(ink.sub)
                    if i < head.ticks.count - 1 { Spacer() }
                }
            }.padding(.trailing, 26)
        }
    }

    private func hourlyCard(_ s: WeatherScene, ink: Ink) -> some View {
        Card(ink: ink) {
            HStack(alignment: .firstTextBaseline) { Text(L("시간별")).font(.px(13)); Spacer(); Text(s.anyChance || s.anyMM ? L("강수확률 · 강수량") : L("12시간 동안 비 소식 없음")).font(.ui(11)).foregroundStyle(ink.sub) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(s.hours.enumerated()), id: \.offset) { i, h in
                        VStack(spacing: 7) {
                            Text(i == 0 ? h.label : model.hourLabel(h.label)).font(.px(i == 0 || !model.clock12 ? 12 : 10)).foregroundStyle(i == 0 ? ink.ink : ink.sub)
                            PixelIcon(name: h.icon, size: 28)
                            Text(deg(h.temp)).font(.px(15)).rolling(h.temp)
                            if s.anyChance { Text(h.chance >= 10 ? "\(h.chance)%" : "–").font(.px(11)).foregroundStyle(h.chance >= 10 ? ink.blue : ink.faint).rolling(h.chance) }
                            if s.anyMM { Text(h.mm > 0 ? mmText(h.mm, snow: s.isSnow) : " ").font(.px(11)).foregroundStyle(ink.blue) }
                        }.frame(width: 50)
                    }
                }
            }.padding(.horizontal, -8)
        }
    }

    private func dailyCard(_ s: WeatherScene, ink: Ink) -> some View {
        let wmin = s.days.map { $0.lo }.min() ?? 0, wmax = s.days.map { $0.hi }.max() ?? 1
        let span = CGFloat(max(1, wmax - wmin))
        return Card(ink: ink) {
            Text(L("10일")).font(.px(13))
            VStack(spacing: 0) {
                ForEach(Array(s.days.enumerated()), id: \.offset) { i, d in
                    Button { day = i } label: { HStack(spacing: 9) {
                        Text(d.name).font(.px(13)).frame(width: Lang.current == .en ? 48 : 34, alignment: .leading)   // "Today"
                        PixelIcon(name: d.icon, size: 24)
                        Text(d.chance >= 10 ? "\(d.chance)%" : "").font(.px(11)).foregroundStyle(ink.blue).frame(width: 34, alignment: .leading)
                        Text(deg(d.lo)).font(.px(13)).foregroundStyle(ink.sub).frame(width: 28, alignment: .trailing).rolling(d.lo)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(ink.track).frame(height: 6)
                                RangeBar(width: CGFloat(d.hi - d.lo) / span * g.size.width, offset: CGFloat(d.lo - wmin) / span * g.size.width, delay: 0.03 * Double(i))
                            }.frame(height: g.size.height)
                        }.frame(height: 6)
                        Text(deg(d.hi)).font(.px(13)).frame(width: 28, alignment: .trailing).rolling(d.hi)
                        Image(systemName: "chevron.right").font(.ui(10, .bold)).foregroundStyle(ink.faint)
                    }
                    .frame(height: 42).contentShape(Rectangle()) }
                    .buttonStyle(.row).accessibilityIdentifier("day-\(i)")
                    .simultaneousGesture(TapGesture().onEnded { Haptic.soft() })
                    if i < s.days.count - 1 { Rectangle().fill(ink.line).frame(height: 1) }
                }
            }
        }
    }

    /// 강수확률 · 자외선 / 바람 (full width) / 예보 비교 (full width) / 일몰 · 습도 — the prototype's order.
    private func tilesGrid(_ s: WeatherScene, ink: Ink) -> some View {
        let first = Array(s.tiles.prefix(2)), rest = Array(s.tiles.dropFirst(2))
        return VStack(spacing: 12) {
            tileRows(first, ink: ink)
            if let d = s.dust { DustCard(dust: d, ink: ink) }
            WindCard(wind: s.wind, ink: ink)
            if let c = s.cmp { CompareCard(cmp: c, updated: s.updated, ink: ink) }
            if !rest.isEmpty { tileRows(rest, ink: ink) }
        }
    }

    /// Two tiles per row, both as tall as the taller one (강수확률 next to 자외선 with its scale).
    private func tileRows(_ ts: [WeatherScene.Tile], ink: Ink) -> some View {
        VStack(spacing: 12) {
            ForEach(Array(stride(from: 0, to: ts.count, by: 2)), id: \.self) { i in
                HStack(alignment: .top, spacing: 12) {
                    tile(ts[i], ink: ink)
                    if i + 1 < ts.count { tile(ts[i + 1], ink: ink) } else { Color.clear.frame(maxWidth: .infinity) }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tile(_ t: WeatherScene.Tile, ink: Ink) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) { PixelIcon(name: t.icon, size: 16); Text(t.label).font(.ui(12, .semibold)).foregroundStyle(ink.sub) }
            if let uv = t.uv, t.kind == "uv" {
                let b = UVScale.band(uv)
                HStack(spacing: 6) {
                    Text(String(uv)).font(.px(26)).rolling(String(uv))
                    Text(L(b.word)).font(.px(11)).foregroundStyle(Color(hex: b.onColor))
                        .padding(.horizontal, 7).padding(.vertical, 4).background(Color(hex: b.color)).clipShape(RoundedRectangle(cornerRadius: 7))
                }
                UVBar(uv: uv, ink: ink)
            } else {
                HStack(alignment: .center, spacing: 6) {
                    Text(t.value ?? "").font(.px(26)).rolling(t.value ?? "")
                    if let u = t.unit, !u.isEmpty { Text(u).font(.px(13)) }
                }
            }
            Spacer(minLength: 0)
            Text(model.say(t.note)).font(.ui(12)).foregroundStyle(ink.sub).lineLimit(2).lineSpacing(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(ink.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(ink.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color(hex: "#1E2A44").opacity(ink.night ? 0.22 : 0.08), radius: 9, y: 6)
    }

    // MARK: formatting

    private func deg(_ v: Int) -> String { model.deg(v) }
    private func delta(_ v: Int) -> String { model.delta(v) }
    private func mmText(_ mm: Double, snow: Bool) -> String {
        let n = mm == mm.rounded() ? String(Int(mm)) : String(format: "%.1f", mm)
        return n + (snow ? "cm" : "mm")
    }
}

/// A bar that grows up from the baseline when it first appears.
private struct GrowBar: View {
    let height: CGFloat; let color: Color; let radius: CGFloat; var delay: Double = 0
    @State private var grown = false
    @Environment(\.accessibilityReduceMotion) private var reduce
    var body: some View {
        RoundedRectangle(cornerRadius: radius).fill(color)
            .frame(height: grown || reduce ? height : 2)
            .animation(Motion.gentle.delay(delay), value: height)
            .onAppear { withAnimation(Motion.gentle.delay(0.2 + delay)) { grown = true } }
    }
}

/// The 10-day temperature range: fills in from its low end.
private struct RangeBar: View {
    let width: CGFloat; let offset: CGFloat; var delay: Double = 0
    @State private var grown = false
    @Environment(\.accessibilityReduceMotion) private var reduce
    var body: some View {
        Capsule().fill(LinearGradient(colors: [Color(hex: "#6FA8FF"), Color(hex: "#FFA94D")], startPoint: .leading, endPoint: .trailing))
            .frame(width: grown || reduce ? max(6, width) : 6, height: 6)
            .offset(x: offset)
            .animation(Motion.gentle, value: width)
            .onAppear { withAnimation(Motion.gentle.delay(0.25 + delay)) { grown = true } }
    }
}

private extension View {
    /// The hero scrolls a touch slower than the cards and fades as it leaves (parallax).
    @ViewBuilder func parallaxHero() -> some View {
        if #available(iOS 17.0, *) {
            self.scrollTransition(.interactive, axis: .vertical) { content, phase in
                content.offset(y: phase.value < 0 ? -phase.value * 60 : 0).opacity(1 + Double(min(0, phase.value)) * 0.7)
            }
        } else { self }
    }
}
