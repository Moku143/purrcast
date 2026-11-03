import SwiftUI
import CoreLocation
import UserNotifications

/// First run: what it is · widgets · watch · location · notifications · Plus.
struct OnboardingView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var purchases: Purchases
    @State private var step = OnboardingView.firstStep
    /// Screenshots: -onbStep 3 opens on that page
    private static var firstStep: Int {
        #if DEBUG
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "-onbStep"), i + 1 < a.count, let n = Int(a[i + 1]) { return max(0, min(5, n)) }
        #endif
        return 0
    }
    @State private var showPlus = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The pictures on the first pages cycle through the weather (rain → clear → snow → wind) to show
    /// the character, widgets and watch changing with it.
    @State private var demo = 0
    private static let demoKeys = ["spring_rain", "clear", "winter_snow", "spring_chill"]

    private let count = 6

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0: intro
                case 1: widgets
                case 2: watch
                case 3: place
                case 4: alerts
                default: plus
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .id(step)
            .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                              removal: .move(edge: .leading).combined(with: .opacity)))

            HStack(spacing: 6) {
                ForEach(0..<count, id: \.self) { i in
                    Capsule().fill(i == step ? UI.accent : UI.faint.opacity(0.5)).frame(width: i == step ? 18 : 6, height: 6)
                }
            }.padding(.bottom, 16)
            VStack(spacing: 2) {
                if step >= 3 { backLink.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4) }
                buttons
            }
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
        .background(
            ZStack {
                LinearGradient(colors: [Color(hex: step == 5 ? "#FFF3D6" : "#E4F3D9"), Color(hex: "#F4F6FA")], startPoint: .top, endPoint: .bottom)
            }
            .ignoresSafeArea()
        )
        .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.4), value: step)
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.8))
                withAnimation(.easeInOut(duration: 0.6)) { demo += 1 }
            }
        }
        .sheet(isPresented: $showPlus, onDismiss: { model.onboarded = true }) { PaywallView() }
    }

    @ViewBuilder private var buttons: some View {
        switch step {
        case 3:
            VStack(spacing: 10) {
                PrimaryButton(title: L("지금 위치 쓰기")) { model.location.ask(); model.useLocation = true; next() }
                secondary(L("나중에 · 서울로 볼게요")) { model.useLocation = false; next() }
            }
        case 4:
            VStack(spacing: 10) {
                // both switched off: nothing to ask permission for
                PrimaryButton(title: model.notifyRain || model.notifyMorning ? L("알림 켜기") : L("다음")) {
                    if model.notifyRain || model.notifyMorning {
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                            Task { @MainActor in model.planNotifications() }
                        }
                    }
                    next()
                }
                secondary(L("나중에")) { model.notifyRain = false; model.notifyMorning = false; next() }
            }
        case 5:
            VStack(spacing: 10) {
                PrimaryButton(title: L("Plus 자세히 보기")) { showPlus = true }
                secondary(L("무료로 시작하기")) { model.onboarded = true }.accessibilityIdentifier("start-free")
            }
        default:
            HStack(spacing: 10) {
                if step > 0 { backButton.frame(width: 110) }
                PrimaryButton(title: L("다음")) { next() }.accessibilityIdentifier("next")
            }
        }
    }

    /// 이전: back one page (the pages that already have two buttons of their own show it small, above them)
    private var backButton: some View { secondary(L("이전")) { back() }.accessibilityIdentifier("back") }
    private var backLink: some View {
        Button { back() } label: {
            HStack(spacing: 4) { Image(systemName: "chevron.left").font(.system(size: 13, weight: .bold)); Text(L("이전")).font(.px(14)) }
                .foregroundStyle(UI.sub).frame(height: 44)
        }
        .accessibilityIdentifier("back")
    }

    private func next() { Haptic.soft(); step = min(count - 1, step + 1) }
    private func back() { Haptic.soft(); step = max(0, step - 1) }

    private var demoScene: WeatherScene { SceneLibrary.scene(Self.demoKeys[demo % Self.demoKeys.count]) }
    /// The demo weather under the person's own place name (지금 위치 until the location step has found it).
    private var demoSnap: WeatherSnapshot {
        let place = model.hereIsLive || model.currentPlace.id != "here" ? model.currentPlace.short : L("지금 위치")
        return WeatherSnapshot(scene: demoScene, character: .cat, plus: false, characterName: "", placeShort: place, saved: Date(),
                               unitF: model.unitF, clock12: model.clock12)
    }
    private func rainState(_ s: WeatherScene) -> RainState { RainState(rawValue: s.rain) ?? .none }
    /// A piece of sky for the pictures: the weather's colour wash with its moving rain, snow or wind.
    private func sky(_ s: WeatherScene, _ w: CGFloat, _ h: CGFloat) -> some View {
        ZStack(alignment: .top) {
            WidgetBackground(level: s.level, night: s.time == "night", scene: nil)      // the outfit colour underneath
            SkyTint(scene: s)
            SkyParticles(scene: s, width: w, tiles: max(1, Int((h / (Sky.tile.height * w / Sky.tile.width)).rounded(.up))), animate: !reduceMotion)
        }
        .frame(width: w, height: h, alignment: .top).clipped()
    }

    private func secondary(_ t: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t).font(.px(16)).foregroundStyle(UI.ink).frame(maxWidth: .infinity).frame(height: 50)
                .background(Color.white).overlay(RoundedRectangle(cornerRadius: 16).stroke(UI.line)).clipShape(RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.press(0.97))
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 0) {
            let s = demoScene
            ZStack(alignment: .top) {
                sky(s, 349, 360).id("sky\(demo)").transition(.opacity)
                VStack(spacing: 0) {
                    HStack(spacing: 6) { PixelIcon(name: s.hours.first?.icon ?? "cloud", size: 28); Text("\(s.temp)°").font(.px(30)) }
                        .foregroundStyle(s.time == "night" ? .white : UI.ink)
                        .padding(.top, 22)
                    Spacer()
                    CharacterSprite(character: .cat, level: s.level, rain: rainState(s), mood: Mood(rawValue: s.mood ?? "normal") ?? .normal, width: 190)
                        .padding(.bottom, 14)
                }
                .id("cat\(demo)").transition(.opacity)
            }
            .frame(width: 349, height: 360).clipShape(RoundedRectangle(cornerRadius: 28))
            .frame(maxWidth: .infinity).padding(.top, 24)
            Text(L("옷차림으로 보는 날씨")).font(.px(22)).padding(.top, 20)
            Text(L("체감온도에 맞춰 옷을 입고, 비가 오면 우산을 펴요.")).font(.system(size: 14)).foregroundStyle(UI.sub).padding(.top, 8)
        }
        .foregroundStyle(UI.ink).padding(.horizontal, 22)
    }

    /// A home-screen widget at its real size on its own weather
    private func homeWidget<C: View>(_ w: CGFloat, _ h: CGFloat, @ViewBuilder _ c: () -> C) -> some View {
        c().padding(16).frame(width: w, height: h)
            .background(WidgetBackground(level: demoScene.level, night: demoScene.time == "night", scene: demoScene, animate: !reduceMotion))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var widgets: some View {
        let snap = demoSnap
        return VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 10) {
                // the home screen: the small and the medium widget at the size iOS gives them
                HStack(spacing: 10) {
                    homeWidget(155, 155) { SmallWidgetView(snap: snap) }
                    homeWidget(166, 155) { MediumWidgetView(snap: snap) }
                }
                // the lock screen: the line above the clock, the rectangle and the circles (iOS draws them white)
                ZStack {
                    LinearGradient(colors: [Color(hex: "#5B5FA8"), Color(hex: "#2E2F66")], startPoint: .top, endPoint: .bottom)
                    VStack(spacing: 8) {
                        Text(LockText.inline(snap)).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Text("9:41").font(.system(size: 56, weight: .semibold, design: .rounded)).padding(.top, -6)
                        HStack(alignment: .top, spacing: 10) {
                            LockRectangularView(snap: snap).frame(width: 148, height: 62)
                            LockCircularView(snap: snap).frame(width: 60, height: 60)
                            LockRainCircularView(snap: snap).frame(width: 60, height: 60)
                        }
                        HStack(spacing: 10) {
                            LockUVCircularView(snap: snap).frame(width: 60, height: 60)
                            LockSunCircularView(snap: snap, now: Date()).frame(width: 60, height: 60)
                            LockWindCircularView(snap: snap).frame(width: 60, height: 60)
                            LockDustCircularView(snap: snap, preview: true).frame(width: 60, height: 60)
                        }
                    }.foregroundStyle(.white)
                }
                .frame(width: 331, height: 250).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .id("w\(demo)").transition(.opacity)
            .padding(12).frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [Color(hex: "#A7B6E8"), Color(hex: "#F2B8A0")], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 28)).padding(.top, 18)
            Text(L("위젯")).font(.px(22))
            Text(L("홈 화면: 캐릭터와 지금 날씨 · 10일 · 시간별")).font(.system(size: 14)).foregroundStyle(UI.sub)
            Text(L("잠금 화면: 기온 · 비 올 확률 · 자외선 · 일출·일몰 · 바람 · 미세먼지")).font(.system(size: 14)).foregroundStyle(UI.sub)
        }
        .foregroundStyle(UI.ink).padding(.horizontal, 20)
    }

    private func circle<C: View>(_ label: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(spacing: 5) {
            c().frame(width: 50, height: 50).background(Color(hex: "#1C1C20")).clipShape(Circle())
            Text(label).font(.system(size: 11)).foregroundStyle(UI.sub)
        }
    }

    private var watch: some View {
        var snap = demoSnap; snap.plus = true
        return VStack(alignment: .leading, spacing: 12) {
            HStack { Text(L("애플워치")).font(.px(22)); Spacer(); PlusTag() }.padding(.top, 24)
            VStack(spacing: 12) {
                // the app's first page beside the modular face, then the analog face beside the app's other pages
                WatchPairPreview(snap: snap, scale: 0.7)
                HStack(spacing: 16 * 0.7 / 0.57) {
                    WatchCase(scale: 0.7) { WatchAnalogPreview(snap: snap) }
                    WatchCase(scale: 0.7) { WatchListPreview(snap: snap) }
                }
            }
            .id("wp\(demo)").transition(.opacity)
            .frame(maxWidth: .infinity).padding(.top, 2)
            // every complication, as it sits in a watch face
            HStack(spacing: 10) {
                circle(L("기온")) { WatchTempGauge(snap: snap).foregroundStyle(.white) }
                circle(L("비 확률")) { WatchRainRing(snap: snap).foregroundStyle(.white) }
                circle(L("체감")) { WatchFeelsDisc(snap: snap) }
                circle(L("일몰")) { WatchSunDisc(snap: snap) }
                circle(L("캐릭터")) { WatchCatSlot(snap: snap) }
            }
            .frame(maxWidth: .infinity).padding(.top, 4)
            Text(L("워치 앱: 지금 날씨 · 시간별 · 10일")).font(.system(size: 14)).foregroundStyle(UI.sub).padding(.top, 4)
            Text(L("워치 페이스: 기온 · 비 확률 · 체감 · 일몰 · 캐릭터 · 요약")).font(.system(size: 14)).foregroundStyle(UI.sub)
            Text(L("Plus에서 쓸 수 있어요.")).font(.system(size: 14)).foregroundStyle(UI.sub)
        }
        .foregroundStyle(UI.ink).padding(.horizontal, 22)
    }

    private var place: some View {
        VStack(spacing: 26) {
            Circle().fill(Color.white).frame(width: 110, height: 110)
                .overlay(Image(systemName: "mappin.and.ellipse").font(.system(size: 40, weight: .bold)).foregroundStyle(UI.accent))
                .padding(.top, 90)
            Text(L("어디 날씨를 볼까요?")).font(.px(22))
            CharacterSprite(character: .cat, level: 5, rain: .none, width: 120).padding(.top, 30)
        }
        .foregroundStyle(UI.ink)
    }

    private var alerts: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("알림")).font(.px(22)).padding(.top, 30)
            RowGroup {
                SettingRow(icon: "umbrella_closed", title: L("비 오기 전")) { Toggle("", isOn: $model.notifyRain).labelsHidden().tint(UI.accent) }
                RowDivider()
                SettingRow(icon: "sun", title: L("아침 요약")) {
                    HStack(spacing: 8) {
                        DatePicker("", selection: $model.morningTime, displayedComponents: .hourAndMinute).labelsHidden()
                            .disabled(!model.notifyMorning).opacity(model.notifyMorning ? 1 : 0.4)
                        Toggle("", isOn: $model.notifyMorning).labelsHidden().tint(UI.accent)
                    }
                }
            }
            .padding(.horizontal, -16)
        }
        .foregroundStyle(UI.ink).padding(.horizontal, 22)
    }

    private var plus: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Plus").font(.px(22)); Spacer(); if let t = purchases.trialText(Purchases.yearly) { Text(t).font(.px(13)).foregroundStyle(UI.accent) } }.padding(.top, 30)
            HStack(spacing: -10) {
                ForEach(PurrCharacter.allCases) { c in CharacterSprite(character: c, level: 4, rain: .none, width: 110, animate: false) }
            }.frame(maxWidth: .infinity).padding(.top, 20)
            FlowChecks(items: PaywallView.features.map { $0.check })
            if let y = purchases.price(Purchases.yearly), let m = purchases.price(Purchases.monthly) {
                Text(L("연 %@ · 월 %@ · 자동 갱신", y, m)).font(.px(14)).frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(UI.ink).padding(.horizontal, 22)
    }
}
