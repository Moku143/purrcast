import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var purchases: Purchases
    @Binding var route: Route?
    @Environment(\.dismiss) private var dismiss
    @State private var showQuiet = false

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "설정") { dismiss() }
            ScrollView {
                VStack(spacing: 0) {
                    plan
                    SectionLabel(text: "지역")
                    RowGroup {
                        SettingRow(icon: "star", title: "지금 위치 쓰기", subtitle: model.hereIsLive ? model.places.first { $0.id == "here" }?.name : (model.location.allowed || model.location.undecided ? "끄면 서울 마포구로 봐요" : "아이폰 설정에서 위치를 허용해 주세요")) {
                            toggle($model.useLocation)
                        }
                        RowDivider()
                        Button { go(.places) } label: {
                            SettingRow(icon: "sun", title: "저장한 지역") { trailingText("\(max(0, model.places.count - 1))곳") }
                        }.buttonStyle(.row)
                    }

                    SectionLabel(text: "단위")
                    RowGroup {
                        SettingRow(title: "온도") { Pills(options: [(false, "°C"), (true, "°F")], value: $model.unitF) }
                        RowDivider()
                        SettingRow(title: "시간") { Pills(options: [(false, "24시간"), (true, "12시간")], value: $model.clock12) }
                        RowDivider()
                        SettingRow(title: "바람") { Pills(options: WindUnit.allCases.map { ($0, $0.label) }, value: $model.wind) }
                    }

                    SectionLabel(text: "알림")
                    RowGroup {
                        SettingRow(icon: "umbrella_closed", title: "비 오기 전") { toggle($model.notifyRain) }
                        RowDivider()
                        SettingRow(icon: "sun", title: "아침 요약") {
                            HStack(spacing: 8) {
                                DatePicker("", selection: $model.morningTime, displayedComponents: .hourAndMinute).labelsHidden()
                                    .onChange(of: model.morningTime) { _, _ in Haptic.select() }
                                toggle($model.notifyMorning)
                            }
                        }
                        RowDivider()
                        SettingRow(icon: "daynight", title: "기온 변화", subtitle: "아침에 어제와 비교해 알려 드려요") { toggle($model.notifyChange) }
                        RowDivider()
                        SettingRow(icon: "zzz", title: "조용한 시간") { trailingText("22:00~07:00") }
                    }

                    SectionLabel(text: "화면")
                    RowGroup {
                        SettingRow(title: "글씨") { Pills(options: [(true, "픽셀"), (false, "일반")], value: $model.pixelFont) }
                        RowDivider()
                        Button { go(.character) } label: {
                            SettingRow(icon: "fish", title: "캐릭터", plus: !model.plus) { trailingText(model.name(of: model.shownCharacter)) }
                        }.buttonStyle(.row)
                        RowDivider()
                        // 말투: the character's own by default (고양이 존댓말 · 브리티시숏헤어 격식 · 아비시니안 반말), Plus can choose
                        VStack(alignment: .leading, spacing: 8) {
                            SettingRow(icon: "music", title: "말투", subtitle: model.plus ? model.voice.sample : "Plus에서 고를 수 있어요", plus: !model.plus) { EmptyView() }
                            if model.plus {
                                Pills(options: [("", "캐릭터 기본")] + Voice.allCases.map { ($0.rawValue, $0.name) }, value: $model.voiceChoice)
                                    .padding(.horizontal, 14).padding(.bottom, 10)
                            }
                        }
                    }

                    SectionLabel(text: "위젯 · 워치")
                    RowGroup {
                        Button { go(.widgets) } label: {
                            SettingRow(icon: "sparkle", title: "위젯 미리보기 · 추가하는 법") { chevron }
                        }.buttonStyle(.row).accessibilityIdentifier("widgets")
                        RowDivider()
                        SettingRow(icon: "star", title: "애플워치", subtitle: model.plus ? "워치에 \(Brand.name)를 설치하면 바로 보여요" : "Plus에서 워치 앱이 열려요", plus: !model.plus) { EmptyView() }
                    }

                    SectionLabel(text: "정보")
                    RowGroup {
                        Button { go(.sources) } label: {
                            SettingRow(title: "데이터 출처", subtitle: model.isSample ? "지금은 예시 날씨" : "기상청 · MET Norway") { chevron }
                        }.buttonStyle(.row)
                        RowDivider()
                        Link(destination: Legal.privacy) { SettingRow(title: "개인정보 처리방침") { chevron } }.buttonStyle(.plain)
                        if let mail = Legal.support {
                            RowDivider()
                            Link(destination: mail) { SettingRow(title: "문의하기") { chevron } }.buttonStyle(.plain)
                        }
                        RowDivider()
                        SettingRow(title: "버전") { trailingText(Self.version) }
                    }
                    Text(model.isSample ? "지금은 예시 날씨로 보여요 (서버 연결 전)" : "")
                        .font(.ui(11)).foregroundStyle(UI.faint).padding(.top, 14).padding(.bottom, 30)
                }
            }
        }
        .background(UI.bg)
    }

    @ViewBuilder private var plan: some View {
        if model.plus {
            RowGroup {
                SettingRow(icon: "sparkle", title: "Plus 구독 중", subtitle: purchases.statusLine) {
                    Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                        HStack(spacing: 4) { Text("관리"); Image(systemName: "chevron.right").font(.ui(11, .bold)) }
                            .font(.system(size: 14)).foregroundStyle(UI.sub)
                    }
                }
            }.padding(.top, 6)
        } else {
            Button { go(.paywall) } label: {
                HStack(spacing: 12) {
                    PixelIcon(name: "sparkle", size: 26)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(Brand.plus + (purchases.trialText(Purchases.yearly).map { " · \($0)" } ?? "")).font(.px(16)).foregroundStyle(UI.ink)
                        Text(PaywallView.features.prefix(4).map { $0.check }.joined(separator: " · ")).font(.ui(12)).foregroundStyle(UI.sub)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.ui(13, .bold)).foregroundStyle(UI.accent)
                }
                .padding(16).background(UI.accentSoft).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.press(0.98)).padding(.horizontal, 16).padding(.top, 6)
            .accessibilityIdentifier("go-plus")
        }
    }

    private func toggle(_ b: Binding<Bool>) -> some View {
        Toggle("", isOn: b).labelsHidden().tint(UI.accent).onChange(of: b.wrappedValue) { _, _ in Haptic.select() }
    }
    private func trailingText(_ t: String) -> some View {
        HStack(spacing: 4) {
            Text(t).font(.system(size: 14)).foregroundStyle(UI.sub)
            Image(systemName: "chevron.right").font(.ui(11, .bold)).foregroundStyle(UI.faint)
        }
    }
    private var chevron: some View { Image(systemName: "chevron.right").font(.ui(11, .bold)).foregroundStyle(UI.faint) }

    private func go(_ r: Route) {
        Haptic.soft()
        route = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { route = r }
    }

    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0" }
}

/// 데이터 출처
struct SourcesView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("날씨는 \(Brand.name) 서버가 두 곳의 예보를 합쳐서 보내요.").font(.system(size: 15)).foregroundStyle(UI.ink)
                source("기상청", "한국", "기본 예보 · 기상특보 · 다음 6시간(Plus) · 출처: 기상청", "공공누리 제1유형(출처표시)")
                source("MET Norway", "전 세계", "해외 예보 · 4~10일 예보 · 자외선 · Data from MET Norway", "CC BY 4.0 · 앱에 맞게 그림과 문구로 바꿔 보여줘요")
                Link("MET Norway 라이선스 (CC BY 4.0)", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!)
                    .font(.ui(12)).tint(UI.accent)
                VStack(alignment: .leading, spacing: 6) {
                    Text("그 밖에").font(.ui(13, .semibold)).foregroundStyle(UI.sub)
                    Text("일출 · 일몰: 위치로 폰에서 계산").font(.ui(13)).foregroundStyle(UI.ink)
                    Text("글꼴: Galmuri11 (SIL OFL 1.1)").font(.ui(13)).foregroundStyle(UI.ink)
                }
            }
            .padding(20)
        }
        .background(UI.bg)
        .navigationTitle("데이터 출처").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() }.tint(UI.accent) } }
    }
    private func source(_ name: String, _ area: String, _ use: String, _ license: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(name).font(.px(17)); Spacer(); Text(area).font(.ui(12)).foregroundStyle(UI.sub) }
            Text(use).font(.ui(13)).foregroundStyle(UI.ink)
            Text(license).font(.ui(12)).foregroundStyle(UI.sub)
        }
        .foregroundStyle(UI.ink).padding(16).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
