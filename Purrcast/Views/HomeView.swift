import SwiftUI

/// The home screen: sky + character + temperature up top, then the cards (next hour · hourly · 10 days · details).
struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @Binding var route: Route?
    @Binding var day: Int?
    private let heroH: CGFloat = 372

    var body: some View {
        let s = model.scene
        let ink = Ink(night: s.isNight)
        let lv = max(0, min(9, s.level))
        ZStack(alignment: .top) {
            background(level: lv, night: s.isNight).ignoresSafeArea()
            SkyTint(scene: s).ignoresSafeArea()
            if model.hasData {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        hero(s, ink: ink, level: lv)
                            .frame(height: heroH)
                        if let e = model.lastError { notice(e, ink: ink) }
                        if let head = nextHour(s) { nextHourCard(s, head: head, ink: ink) }
                        hourlyCard(s, ink: ink)
                        dailyCard(s, ink: ink)
                        tilesGrid(s, ink: ink)
                        Text(model.isSample ? "예시 날씨예요 · 실제 날씨는 서버 연결 후" : "기상청 · Data from MET Norway")
                            .font(.ui(11)).foregroundStyle(ink.sub).padding(.top, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 44)
                }
                .refreshable { await model.refresh(force: true) }
            } else {
                waiting(ink: ink)
            }
        }
        .foregroundStyle(ink.ink)
    }

    /// First launch, before any forecast arrived (or it failed): the cat waits, no made-up numbers.
    private func waiting(ink: Ink) -> some View {
        VStack(spacing: 18) {
            Spacer()
            CharacterSprite(character: model.shownCharacter, level: 4, rain: .none, width: 150)
            if model.lastError == nil {
                ProgressView().tint(ink.ink)
                Text("날씨를 받아 오는 중이에요").font(.px(15))
            } else {
                Text(model.lastError ?? "").font(.px(14)).multilineTextAlignment(.center).padding(.horizontal, 30)
                Button("다시 시도") { Task { await model.refresh(force: true) } }
                    .font(.px(15)).padding(.horizontal, 22).padding(.vertical, 10).background(ink.btn).clipShape(Capsule())
                    .accessibilityIdentifier("retry")
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func notice(_ text: String, ink: Ink) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark").font(.system(size: 13, weight: .bold))
            Text(text).font(.ui(12, .medium))
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(ink.card).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: hero

    private func background(level: Int, night: Bool) -> some View {
        let bg = Rules.background[level]
        return LinearGradient(stops: night
            ? [.init(color: Color(hex: bg), location: 0), .init(color: Color(hex: bg), location: 0.35), .init(color: .mix(bg, "#0B0F24", 0.78), location: 0.66), .init(color: Color(hex: "#0B0F22"), location: 1)]
            : [.init(color: Color(hex: bg), location: 0), .init(color: Color(hex: bg), location: 0.4), .init(color: .mix(bg, "#8E9CC4", 0.32), location: 1)],
            startPoint: .top, endPoint: .bottom)
    }

    private func hero(_ s: WeatherScene, ink: Ink, level: Int) -> some View {
        let char = model.shownCharacter
        let rain = RainState(rawValue: s.rain) ?? .none
        let catW: CGFloat = 176, catH = catW * Sprite.height / Sprite.width
        let feetY: CGFloat = 368
        let catTop = feetY - Sprite.feetY / Sprite.height * catH
        let headX: CGFloat = 100 - 16   // hero is inside the 16 pt side padding
        let a = char.anchors
        let catLeft = headX - CGFloat(a.head_cx[level]) * catW / Sprite.width
        let tipY = catTop + CGFloat(rain == .umbrella ? a.umb_top[level] : a.head_top[level]) / Sprite.height * catH - 4

        return ZStack(alignment: .topLeading) {
            // top row: place + buttons
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Button { route = .places } label: {
                        HStack(spacing: 6) {
                            Image(systemName: model.hereIsLive && model.currentPlace.id == "here" ? "location.fill" : "mappin").font(.system(size: 13, weight: .bold))
                            Text(s.place ?? model.currentPlace.name).font(.px(17))
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("place")
                    Text(s.isPlus ? "\(s.updated) 받음 · Plus" : "오늘 \(s.updated) 기준").font(.px(11)).opacity(0.8)
                }
                Spacer()
                HStack(spacing: 8) {
                    roundButton(ink, id: "character", label: "캐릭터") { route = .character } content: { Image(char.faceImage).resizable().scaledToFit().frame(width: 26, height: 26) }
                    roundButton(ink, id: "places", label: "지역") { route = .places } content: { Image(systemName: "plus").font(.system(size: 16, weight: .bold)) }
                    roundButton(ink, id: "settings", label: "설정") { route = .settings } content: { Image(systemName: "gearshape.fill").font(.system(size: 16)) }
                }
            }
            .padding(.horizontal, 4).padding(.top, 8)

            // temperature block, right
            VStack(alignment: .trailing, spacing: 10) {
                Text(deg(s.temp)).font(.px(88))
                Text(s.cond).font(.px(17))
                Text("최고 \(deg(s.hi)) · 최저 \(deg(s.lo))").font(.px(12))
                HStack(spacing: 5) {
                    Text("체감 \(deg(s.feels))"); Text("·"); Text("전일 대비")
                    Text(delta(s.yday)).foregroundStyle(s.yday > 0 ? ink.hot : (s.yday < 0 ? ink.blue : ink.ink))
                }.font(.px(12))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 6).padding(.top, 64)

            // the character, feet on the first card
            CharacterSprite(character: char, level: level, rain: rain, mood: Mood(rawValue: s.mood ?? "normal") ?? .normal, width: catW)
                .offset(x: catLeft, y: catTop)

            if let b = s.bubble {
                BubbleView(kind: b.kind, tone: b.tone, icon: b.icon, text: b.text)
                    .fixedSize()
                    .alignmentGuide(.leading) { d in d.width / 2 - headX }
                    .alignmentGuide(.top) { d in d.height - tipY }
            }
        }
        .frame(maxWidth: .infinity, minHeight: heroH, maxHeight: heroH, alignment: .topLeading)
        .background(alignment: .topLeading) {
            // weather pixels (clouds, rain, snow, wind …), edge to edge, two tiles high, fading out above the first card
            SkyParticles(scene: s, width: UIScreen.main.bounds.width, tiles: 2)
                .frame(width: UIScreen.main.bounds.width, height: heroH, alignment: .top)
                .clipped()
                .mask(LinearGradient(stops: [.init(color: .black, location: 0.7), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                .offset(x: -16)
        }
    }

    private func roundButton<C: View>(_ ink: Ink, id: String, label: String, action: @escaping () -> Void, @ViewBuilder content c: () -> C) -> some View {
        Button(action: action) { c().frame(width: 36, height: 36).background(ink.btn).clipShape(Circle()) }
            .buttonStyle(.plain).accessibilityIdentifier(id).accessibilityLabel(label)
    }

    // MARK: cards

    private func nextHour(_ s: WeatherScene) -> (title: String, legend: String, head: String, sub: String, icon: String, bars: [Double], ticks: [String])? {
        guard s.isPlus else { return nil }
        let chance = s.hours.prefix(3).map { $0.chance }.max() ?? 0
        let nowMin: Int = WeatherScene.clockMinutes(s.clock) ?? 12 * 60
        if let six = s.next6 {
            let R = six.map { $0.mm }
            var head = "6시간 동안 비 소식 없음", sub = "", icon = "cloud"
            if let st = R.firstIndex(where: { $0 >= 0.1 }) {
                let en = R[st...].firstIndex(where: { $0 < 0.1 })
                let last = en == nil ? R.count - 1 : en! - 1
                let hr = { (i: Int) in six[i].label.replacingOccurrences(of: "시", with: "") }
                head = st == 0 ? "지금 비" : (st == last ? "\(hr(st))시쯤 비 예정" : "\(hr(st))~\(hr(last))시 비 예정")
                let stop = en == nil ? "6시간 넘게 이어질 수 있어요" : "\(((Int(hr(last)) ?? 0) + 1) % 24)시쯤 그칠 듯"
                sub = "\(Rules.rainKind(R.max() ?? 0)) · \(stop) · 가능성 \(chance)%"
                icon = st == 0 ? "umbrella" : "umbrella_closed"
            }
            return ("다음 6시간", s.nextSource == "met" ? "MET Norway · Plus" : "기상청 초단기 · Plus", head, sub, icon, R, six.map { model.hourLabel($0.label) })
        }
        if let mm = s.minutes {
            var head = "1시간 동안 비 소식 없음", sub = "", icon = "cloud"
            if let st = mm.firstIndex(where: { $0 >= 0.1 }) {
                let en = mm[st...].firstIndex(where: { $0 < 0.1 }).map { $0 - st }
                let start = nowMin + st, s10 = start / 10 * 10
                head = st == 0 ? "지금 비" : (s10 > nowMin ? "\(Rules.hhmm(s10))쯤 비 예정" : "\(Rules.hhmm((start + 9) / 10 * 10)) 전 비 예정")
                let stop = en == nil ? "한동안 이어질 수 있어요" : "\(Rules.hhmm((start + en! + 9) / 10 * 10))쯤 그칠 듯"
                sub = "\(Rules.rainKind(mm.max() ?? 0)) · \(stop) · 가능성 \(chance)%"
                icon = st == 0 ? "umbrella" : "umbrella_closed"
            }
            let span = mm.count
            return ("다음 1시간", "분 단위 · Plus", head, sub, icon, mm, ["지금"] + [1, 2, 3, 4].map { "\(span * $0 / 4)분" })
        }
        return nil
    }

    private func nextHourCard(_ s: WeatherScene, head: (title: String, legend: String, head: String, sub: String, icon: String, bars: [Double], ticks: [String]), ink: Ink) -> some View {
        let six = s.next6 != nil
        return Card(ink: ink) {
            HStack(alignment: .firstTextBaseline) { Text(head.title).font(.px(13)); Spacer(); Text(head.legend).font(.ui(11)).foregroundStyle(ink.sub) }
            HStack(spacing: 8) { PixelIcon(name: head.icon, size: 20); Text(head.head).font(.px(15)) }
            if !head.sub.isEmpty { Text(head.sub).font(.ui(12)).foregroundStyle(ink.sub).padding(.leading, 28).padding(.top, -9) }
            ZStack(alignment: .bottomLeading) {
                ForEach(0..<3, id: \.self) { gi in
                    let labels = ["약", "보통", "강"], levels: [Double] = [0.5, 2.5, 6.0]
                    let y = 64 - min(1, levels[gi] / 6) * 64
                    HStack(spacing: 4) {
                        Rectangle().fill(ink.line).frame(height: 1)
                        Text(labels[gi]).font(.ui(10)).foregroundStyle(ink.sub).frame(width: 22, alignment: .trailing)
                    }.offset(y: y - 64)
                }
                HStack(alignment: .bottom, spacing: six ? 8 : 1) {
                    ForEach(Array(head.bars.enumerated()), id: \.offset) { _, v in
                        RoundedRectangle(cornerRadius: six ? 4 : 1).fill(v >= 0.1 ? ink.blue : ink.track)
                            .frame(height: v >= 0.1 ? max(3, min(1, v / 6) * 64) : 2)
                    }
                }.padding(.trailing, 26)
            }
            .frame(height: 64)
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
            HStack(alignment: .firstTextBaseline) { Text("시간별").font(.px(13)); Spacer(); Text("강수확률 · 강수량").font(.ui(11)).foregroundStyle(ink.sub) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(s.hours.enumerated()), id: \.offset) { i, h in
                        VStack(spacing: 7) {
                            Text(i == 0 ? h.label : model.hourLabel(h.label)).font(.px(i == 0 || !model.clock12 ? 12 : 10)).foregroundStyle(i == 0 ? ink.ink : ink.sub)
                            PixelIcon(name: h.icon, size: 28)
                            Text(deg(h.temp)).font(.px(15))
                            if s.anyChance { Text(h.chance >= 10 ? "\(h.chance)%" : "–").font(.px(11)).foregroundStyle(h.chance >= 10 ? ink.blue : ink.faint) }
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
            Text("10일").font(.px(13))
            VStack(spacing: 0) {
                ForEach(Array(s.days.enumerated()), id: \.offset) { i, d in
                    Button { day = i } label: { HStack(spacing: 9) {
                        Text(d.name).font(.px(13)).frame(width: 34, alignment: .leading)
                        PixelIcon(name: d.icon, size: 24)
                        Text(d.chance >= 10 ? "\(d.chance)%" : "").font(.px(11)).foregroundStyle(ink.blue).frame(width: 34, alignment: .leading)
                        Text(deg(d.lo)).font(.px(13)).foregroundStyle(ink.sub).frame(width: 28, alignment: .trailing)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(ink.track).frame(height: 6)
                                Capsule().fill(LinearGradient(colors: [Color(hex: "#6FA8FF"), Color(hex: "#FFA94D")], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: CGFloat(d.hi - d.lo) / span * g.size.width, height: 6)
                                    .offset(x: CGFloat(d.lo - wmin) / span * g.size.width)
                            }.frame(height: g.size.height)
                        }.frame(height: 6)
                        Text(deg(d.hi)).font(.px(13)).frame(width: 28, alignment: .trailing)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(ink.faint)
                    }
                    .frame(height: 42).contentShape(Rectangle()) }
                    .buttonStyle(.plain).accessibilityIdentifier("day-\(i)")
                    if i < s.days.count - 1 { Rectangle().fill(ink.line).frame(height: 1) }
                }
            }
        }
    }

    private func tilesGrid(_ s: WeatherScene, ink: Ink) -> some View {
        let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: cols, spacing: 12) {
            ForEach(Array(s.tiles.enumerated()), id: \.offset) { _, t in
                Card(ink: ink) {
                    HStack(spacing: 6) { PixelIcon(name: t.icon, size: 16); Text(t.label).font(.ui(12, .semibold)).foregroundStyle(ink.sub) }
                    Text(t.uv.map { String($0) } ?? (t.value ?? "")).font(.px(26))
                    Text(t.note).font(.ui(12)).foregroundStyle(ink.sub).lineLimit(2)
                }
            }
            Card(ink: ink) {
                HStack(spacing: 6) { PixelIcon(name: "wind", size: 16); Text("바람").font(.ui(12, .semibold)).foregroundStyle(ink.sub) }
                Text("\(wind(s.wind.speed))").font(.px(26))
                Text("돌풍 \(wind(s.wind.gust)) · \(dir(s.wind.deg))").font(.ui(12)).foregroundStyle(ink.sub)
            }
        }
    }

    // MARK: formatting

    private func deg(_ v: Int) -> String { model.deg(v) }
    private func delta(_ v: Int) -> String { model.delta(v) }
    private func mmText(_ mm: Double, snow: Bool) -> String {
        let n = mm == mm.rounded() ? String(Int(mm)) : String(format: "%.1f", mm)
        return n + (snow ? "cm" : "mm")
    }
    private func wind(_ ms: Int) -> String { model.windText(ms) }
    private func dir(_ deg: Int) -> String {
        let d = ["북", "북북동", "북동", "동북동", "동", "동남동", "남동", "남남동", "남", "남남서", "남서", "서남서", "서", "서북서", "북서", "북북서"]
        let i = Int((Double(((deg % 360) + 360) % 360) / 22.5).rounded()) % 16
        return d[i] + "풍"
    }
}
