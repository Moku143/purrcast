import SwiftUI
import CoreLocation
import UserNotifications

/// First run: what it is · widgets · watch · location · notifications · Plus.
struct OnboardingView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var purchases: Purchases
    @State private var step = 0
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
            buttons.padding(.horizontal, 20).padding(.bottom, 12)
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
            PrimaryButton(title: L("다음")) { next() }.accessibilityIdentifier("next")
        }
    }

    private func next() { Haptic.soft(); step = min(count - 1, step + 1) }

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

    private var widgets: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 12) {
                MediumWidgetView(snap: demoSnap).padding(16).frame(width: 330, height: 160)
                    .background(WidgetBackground(level: demoScene.level, night: demoScene.time == "night", scene: demoScene, animate: !reduceMotion))
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .id("w\(demo)").transition(.opacity)
                ZStack {
                    LinearGradient(colors: [Color(hex: "#5B5FA8"), Color(hex: "#2E2F66")], startPoint: .top, endPoint: .bottom)
                    VStack(spacing: 6) {
                        Text("9:41").font(.system(size: 54, weight: .semibold, design: .rounded))
                        HStack(spacing: 10) {
                            LockRectangularView(snap: demoSnap).frame(width: 150, height: 60)
                            LockCircularView(snap: demoSnap).frame(width: 56, height: 56)
                        }
                    }.foregroundStyle(.white)
                }
                .frame(width: 330, height: 170).clipShape(RoundedRectangle(cornerRadius: 22))
            }
            .padding(14).frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [Color(hex: "#A7B6E8"), Color(hex: "#F2B8A0")], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 28)).padding(.top, 24)
            Text(L("위젯")).font(.px(22))
            Text(L("홈 화면 · 잠금 화면에서 바로 봐요.")).font(.system(size: 14)).foregroundStyle(UI.sub)
        }
        .foregroundStyle(UI.ink).padding(.horizontal, 20)
    }

    private var watch: some View {
        VStack(spacing: 16) {
            HStack { Text(L("애플워치")).font(.px(22)); Spacer(); PlusTag() }.padding(.top, 30)
            WatchPairPreview(snap: demoSnap, scale: 0.72)
                .id("wp\(demo)").transition(.opacity)
                .padding(.top, 10)
            Text(L("워치 앱 · 워치 페이스 · 컴플리케이션")).font(.system(size: 14)).foregroundStyle(UI.sub)
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
