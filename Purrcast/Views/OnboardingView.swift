import SwiftUI
import CoreLocation
import UserNotifications

/// First run: what it is · home widgets · the lock screen · watch · 날씨 달력 · location · notifications · Plus.
struct OnboardingView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var purchases: Purchases
    @State private var step = OnboardingView.firstStep
    /// Screenshots: -onbStep 3 opens on that page
    private static var firstStep: Int {
        #if DEBUG
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "-onbStep"), i + 1 < a.count, let n = Int(a[i + 1]) { return max(0, min(7, n)) }
        #endif
        return 0
    }
    @State private var showPlus = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The pictures on the first pages cycle through the weather (rain → clear → snow → wind) to show
    /// the character, widgets and watch changing with it.
    @State private var demo = 0
    private static let demoKeys = ["spring_rain", "clear", "winter_snow", "spring_chill"]

    private let count = 8
    /// The pages with their own two buttons (location, notifications, Plus)
    private static let placeStep = 5, alertsStep = 6, plusStep = 7

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0: intro
                case 1: widgets
                case 2: lockWidgets
                case 3: watch
                case 4: calendar
                case Self.placeStep: place
                case Self.alertsStep: alerts
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
                if step >= Self.placeStep { backLink.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4) }
                buttons
            }
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
        .background(
            ZStack {
                LinearGradient(colors: [Color(hex: step == Self.plusStep ? "#FFF3D6" : "#E4F3D9"), Color(hex: "#F4F6FA")], startPoint: .top, endPoint: .bottom)
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
        case Self.placeStep:
            VStack(spacing: 10) {
                PrimaryButton(title: L("지금 위치 쓰기")) { model.location.ask(); model.useLocation = true; next() }
                secondary(L("나중에 · 서울로 볼게요")) { model.useLocation = false; next() }
            }
        case Self.alertsStep:
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
        case Self.plusStep:
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

    /// How a demo picture gives way to the next: the old one fades fully out before the new one fades in. A plain
    /// cross-fade overlaid both pictures for 0.6 s, so two scenes' numbers sat on each other for a fifth of the
    /// time — not the gauge's own '16 over 18' (that was HangingDegree's stray '°'), but the same doubled look.
    private static let demoFade = AnyTransition.asymmetric(
        insertion: .opacity.animation(.easeIn(duration: 0.25).delay(0.3)),
        removal: .opacity.animation(.easeOut(duration: 0.25)))

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
                sky(s, 349, 470).id("sky\(demo)").transition(Self.demoFade)
                VStack(spacing: 0) {
                    HStack(spacing: 6) { PixelIcon(name: s.hours.first?.icon ?? "cloud", size: 28); Text("\(s.temp)°").font(.px(30)) }
                        .foregroundStyle(s.time == "night" ? .white : UI.ink)
                        .padding(.top, 24)
                    Spacer()
                    CharacterSprite(character: .cat, level: s.level, rain: rainState(s), mood: Mood(rawValue: s.mood ?? "normal") ?? .normal, width: 240)
                        .padding(.bottom, 18)
                }
                .id("cat\(demo)").transition(Self.demoFade)
            }
            .frame(width: 349, height: 470).clipShape(RoundedRectangle(cornerRadius: 28))
            .frame(maxWidth: .infinity).padding(.top, 24)
            Text(L("옷차림으로 보는 날씨")).font(.px(22)).padding(.top, 20)
            Text(L("체감온도에 맞춰 옷을 입고, 비가 오면 우산을 펴요.")).font(.system(size: 14)).foregroundStyle(UI.sub).padding(.top, 8)
            Text(L("한국은 기상청, 해외는 Apple 날씨 예보예요.")).font(.system(size: 14)).foregroundStyle(UI.sub).padding(.top, 4)
            Text(L("홈 카드는 꾹 눌러 원하는 순서로 옮길 수 있어요.")).font(.system(size: 14)).foregroundStyle(UI.sub).padding(.top, 4)
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
            VStack(spacing: 12) {
                // the home screen: the medium and the small widget at the size iOS gives them
                homeWidget(329, 155) { MediumWidgetView(snap: snap) }
                HStack(alignment: .top, spacing: 10) {
                    homeWidget(155, 155) { SmallWidgetView(snap: snap) }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("캐릭터와 지금 날씨")).font(.ui(13, .semibold))
                        Text(L("체감 · 일몰 · 비 확률, 옆에는 10일")).font(.ui(12)).foregroundStyle(UI.sub)
                        Text(L("홈 화면을 길게 눌러 추가해요")).font(.ui(12)).foregroundStyle(UI.sub)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
                }
            }
            .id("w\(demo)").transition(Self.demoFade)
            .padding(12).frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [Color(hex: "#A7B6E8"), Color(hex: "#F2B8A0")], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 28)).padding(.top, 18)
            Text(L("홈 화면 위젯")).font(.px(22))
            Text(L("홈 화면: 캐릭터와 지금 날씨 · 10일 · 시간별")).font(.system(size: 14)).foregroundStyle(UI.sub)
        }
        .foregroundStyle(UI.ink).padding(.horizontal, 20)
    }

    private var lockWidgets: some View {
        let snap = demoSnap
        return VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 10) {
                // the lock screen: the line above the clock, the rectangle and the circles (iOS draws them white)
                ZStack {
                    LinearGradient(colors: [Color(hex: "#5B5FA8"), Color(hex: "#2E2F66")], startPoint: .top, endPoint: .bottom)
                    VStack(spacing: 8) {
                        // the line above the clock, one of its kinds at a time (the character dressed for now and the
                        // temperature first)
                        let kinds: [LockInlineView.Kind] = [.temp, .rain, .uv, .sun, .wind, .place]
                        LockInlineView(kind: kinds[demo % kinds.count], snap: snap).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                        Text("9:41").font(.system(size: 80, weight: .bold)).padding(.top, -10)
                        HStack(alignment: .top, spacing: 12) {
                            LockRectangularView(snap: snap).frame(width: 158, height: 72)
                            LockCircularView(snap: snap).frame(width: 72, height: 72)
                            LockRainCircularView(snap: snap).frame(width: 72, height: 72)
                        }
                        .padding(.top, 6)
                        HStack(spacing: 12) {
                            LockUVCircularView(snap: snap).frame(width: 72, height: 72)
                            LockSunCircularView(snap: snap, now: Date()).frame(width: 72, height: 72)
                            LockWindCircularView(snap: snap).frame(width: 72, height: 72)
                            LockDustCircularView(snap: snap, preview: true).frame(width: 72, height: 72)
                        }
                        .padding(.top, 14)
                    }.foregroundStyle(.white)
                }
                .frame(width: 331, height: 400).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .id("l\(demo)").transition(Self.demoFade)
            .padding(12).frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [Color(hex: "#4B5090"), Color(hex: "#F2B8A0")], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 28)).padding(.top, 18)
            Text(L("잠금 화면 위젯")).font(.px(22))
            Text(L("잠금 화면: 기온 · 비 올 확률 · 자외선 · 일출·일몰 · 바람 · 미세먼지")).font(.system(size: 14)).foregroundStyle(UI.sub)
            Text(L("시계 위 한 줄: 옷 입은 캐릭터와 기온 · 위치 · 비 · 자외선 · 일출·일몰 · 바람")).font(.system(size: 14)).foregroundStyle(UI.sub)
        }
        .foregroundStyle(UI.ink).padding(.horizontal, 20)
    }

    /// 날씨 달력 (Plus): two weeks as the calendar draws them, the month's report under it
    private var calendar: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 14) {
                CalendarPreview(cell: 42, deg: { model.deg($0) })
                HStack(alignment: .center, spacing: 14) {
                    DayFigure(character: .cat, level: 7, width: 70)
                    VStack(alignment: .leading, spacing: 8) {
                        reportLine("raincloud", L("비·눈 온 날"), DayLogText.days(4))
                        reportLine("thermo_hot", L("가장 더운 날"), model.deg(21))
                        reportLine("thermo_cold", L("가장 추운 날"), model.deg(4))
                    }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
            }
            .padding(14).frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 28))
            .padding(.top, 18)
            HStack { Text(L("날씨 달력 · 월간 리포트")).font(.px(22)); Spacer(); PlusTag() }
            Text(L("날씨를 볼 때마다 그날 날씨와 옷차림이 달력에 쌓여요.")).font(.system(size: 14)).foregroundStyle(UI.sub)
            Text(L("달마다 비 온 날 · 가장 더운 날 · 자주 입은 옷을 정리해 1일에 알려 드려요.")).font(.system(size: 14)).foregroundStyle(UI.sub)
        }
        .foregroundStyle(UI.ink).padding(.horizontal, 20)
    }

    private func reportLine(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            PixelIcon(name: icon, size: 18)
            Text(title).font(.ui(13)).foregroundStyle(UI.sub)
            Spacer(minLength: 4)
            Text(value).font(.px(13)).foregroundStyle(UI.ink)
        }
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
            .id("wp\(demo)").transition(Self.demoFade)
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
