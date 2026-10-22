import SwiftUI
import CoreLocation
import UserNotifications

/// First run: what it is · widgets · watch · location · notifications · Plus.
struct OnboardingView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var purchases: Purchases
    @State private var step = 0
    @State private var showPlus = false

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
            .transition(.opacity)

            HStack(spacing: 6) {
                ForEach(0..<count, id: \.self) { i in
                    Capsule().fill(i == step ? UI.accent : UI.faint.opacity(0.5)).frame(width: i == step ? 18 : 6, height: 6)
                }
            }.padding(.bottom, 16)
            buttons.padding(.horizontal, 20).padding(.bottom, 12)
        }
        .background(LinearGradient(colors: [Color(hex: step == 5 ? "#FFF3D6" : "#E4F3D9"), Color(hex: "#F4F6FA")], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: step)
        .sheet(isPresented: $showPlus, onDismiss: { model.onboarded = true }) { PaywallView() }
    }

    @ViewBuilder private var buttons: some View {
        switch step {
        case 3:
            VStack(spacing: 10) {
                PrimaryButton(title: "지금 위치 쓰기") { model.location.ask(); model.useLocation = true; next() }
                secondary("나중에 · 서울로 볼게요") { model.useLocation = false; next() }
            }
        case 4:
            VStack(spacing: 10) {
                PrimaryButton(title: "알림 켜기") {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                        Task { @MainActor in model.planNotifications() }
                    }
                    next()
                }
                secondary("나중에") { model.notifyRain = false; model.notifyMorning = false; next() }
            }
        case 5:
            VStack(spacing: 10) {
                PrimaryButton(title: "Plus 자세히 보기") { showPlus = true }
                secondary("무료로 시작하기") { model.onboarded = true }.accessibilityIdentifier("start-free")
            }
        default:
            PrimaryButton(title: "다음") { next() }.accessibilityIdentifier("next")
        }
    }

    private func next() { step = min(count - 1, step + 1) }
    private func secondary(_ t: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t).font(.px(16)).foregroundStyle(UI.ink).frame(maxWidth: .infinity).frame(height: 50)
                .background(Color.white).overlay(RoundedRectangle(cornerRadius: 16).stroke(UI.line)).clipShape(RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain)
    }

    private var sample: WeatherSnapshot {
        WeatherSnapshot(scene: SceneLibrary.scene("maybe"), character: .cat, plus: false, characterName: "", placeShort: "서울", saved: Date())
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) { PixelIcon(name: "raincloud", size: 28); Text("26°").font(.px(30)) }
                .frame(maxWidth: .infinity).padding(.top, 40)
            HStack(alignment: .bottom, spacing: -30) {
                CharacterSprite(character: .cat, level: 2, rain: .umbrella, width: 190)
                Spacer()
            }.padding(.top, 30)
            Text("옷차림으로 보는 날씨").font(.px(22)).padding(.top, 20)
            Text("체감온도에 맞춰 옷을 입고, 비가 오면 우산을 펴요.").font(.system(size: 14)).foregroundStyle(UI.sub).padding(.top, 8)
        }
        .foregroundStyle(UI.ink).padding(.horizontal, 22)
    }

    private var widgets: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 12) {
                MediumWidgetView(snap: sample).padding(14).frame(width: 330, height: 160)
                    .background(WidgetBackground(level: 4, night: false, scene: sample.scene)).clipShape(RoundedRectangle(cornerRadius: 22))
                ZStack {
                    LinearGradient(colors: [Color(hex: "#5B5FA8"), Color(hex: "#2E2F66")], startPoint: .top, endPoint: .bottom)
                    VStack(spacing: 6) {
                        Text("9:41").font(.system(size: 54, weight: .semibold, design: .rounded))
                        HStack(spacing: 10) {
                            LockRectangularView(snap: sample).frame(width: 150, height: 60)
                            LockCircularView(snap: sample).frame(width: 56, height: 56)
                        }
                    }.foregroundStyle(.white)
                }
                .frame(width: 330, height: 170).clipShape(RoundedRectangle(cornerRadius: 22))
            }
            .padding(14).frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [Color(hex: "#A7B6E8"), Color(hex: "#F2B8A0")], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 28)).padding(.top, 24)
            Text("위젯").font(.px(22))
            Text("홈 화면 · 잠금 화면에서 바로 봐요.").font(.system(size: 14)).foregroundStyle(UI.sub)
        }
        .foregroundStyle(UI.ink).padding(.horizontal, 20)
    }

    private var watch: some View {
        VStack(spacing: 16) {
            HStack { Text("애플워치").font(.px(22)); Spacer(); PlusTag() }.padding(.top, 30)
            ZStack {
                RoundedRectangle(cornerRadius: 40).fill(Color(hex: "#15161C")).frame(width: 170, height: 204)
                RoundedRectangle(cornerRadius: 30).fill(LinearGradient(colors: [Color(hex: "#D9EFCF"), Color(hex: "#B9D7C2")], startPoint: .top, endPoint: .bottom)).frame(width: 150, height: 184)
                VStack(alignment: .leading, spacing: 0) {
                    HStack { Text("서울").font(.px(10)); Spacer(); Text("13:46").font(.px(10)) }
                    Text("18°").font(.px(36)).frame(maxWidth: .infinity, alignment: .trailing)
                    HStack(alignment: .bottom) {
                        CharacterSprite(character: .cat, level: 4, rain: .bag, width: 60, animate: false).frame(width: 60, height: 70)
                        VStack(alignment: .trailing, spacing: 2) { Text("흐림").font(.px(10)); Text("체감 17°").font(.px(9)) }
                    }
                }
                .foregroundStyle(UI.ink).frame(width: 128, height: 164)
            }
            Text("워치 앱 · 워치 페이스 · 컴플리케이션").font(.system(size: 14)).foregroundStyle(UI.sub)
            Text("Plus에서 쓸 수 있어요.").font(.system(size: 14)).foregroundStyle(UI.sub)
        }
        .foregroundStyle(UI.ink).padding(.horizontal, 22)
    }

    private var place: some View {
        VStack(spacing: 26) {
            Circle().fill(Color.white).frame(width: 110, height: 110)
                .overlay(Image(systemName: "mappin.and.ellipse").font(.system(size: 40, weight: .bold)).foregroundStyle(UI.accent))
                .padding(.top, 90)
            Text("어디 날씨를 볼까요?").font(.px(22))
            CharacterSprite(character: .cat, level: 4, rain: .none, width: 120).padding(.top, 30)
        }
        .foregroundStyle(UI.ink)
    }

    private var alerts: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("알림").font(.px(22)).padding(.top, 30)
            RowGroup {
                SettingRow(icon: "umbrella_closed", title: "비 오기 전") { Toggle("", isOn: $model.notifyRain).labelsHidden().tint(UI.accent) }
                RowDivider()
                SettingRow(icon: "sun", title: "아침 요약") { Toggle("", isOn: $model.notifyMorning).labelsHidden().tint(UI.accent) }
                DatePicker("", selection: $model.morningTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel).labelsHidden().frame(height: 150).clipped()
            }
            .padding(.horizontal, -16)
        }
        .foregroundStyle(UI.ink).padding(.horizontal, 22)
    }

    private var plus: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Plus").font(.px(22)); Spacer(); if let t = purchases.trialText(Purchases.yearly) { Text(t).font(.px(13)).foregroundStyle(UI.accent) } }.padding(.top, 30)
            HStack(spacing: -10) {
                ForEach(PurrCharacter.allCases) { c in CharacterSprite(character: c, level: 3, rain: .none, width: 110, animate: false) }
            }.frame(maxWidth: .infinity).padding(.top, 20)
            FlowChecks(items: PaywallView.features.map { $0.check })
            if let y = purchases.price(Purchases.yearly), let m = purchases.price(Purchases.monthly) {
                Text("연 \(y) · 월 \(m) · 자동 갱신").font(.px(14)).frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(UI.ink).padding(.horizontal, 22)
    }
}
