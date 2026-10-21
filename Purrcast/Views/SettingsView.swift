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
                        SettingRow(icon: "star", title: "지금 위치 쓰기", subtitle: Place.here.name) {
                            Toggle("", isOn: $model.useLocation).labelsHidden().tint(UI.accent)
                        }
                        RowDivider()
                        Button { go(.places) } label: {
                            SettingRow(icon: "sun", title: "저장한 지역") { trailingText("\(max(0, model.places.count - 1))곳") }
                        }.buttonStyle(.plain)
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
                                toggle($model.notifyMorning)
                            }
                        }
                        RowDivider()
                        SettingRow(icon: "exclaim", title: "기상특보") { toggle($model.notifyAlerts) }
                        RowDivider()
                        SettingRow(icon: "zzz", title: "조용한 시간") { trailingText("22:00~07:00") }
                    }

                    SectionLabel(text: "화면")
                    RowGroup {
                        SettingRow(title: "글씨") { Pills(options: [(true, "픽셀"), (false, "일반")], value: $model.pixelFont) }
                        RowDivider()
                        Button { go(.character) } label: {
                            SettingRow(icon: "fish", title: "캐릭터", plus: !model.plus) { trailingText(model.name(of: model.shownCharacter)) }
                        }.buttonStyle(.plain)
                    }

                    SectionLabel(text: "위젯 · 워치")
                    RowGroup {
                        Button { go(.widgets) } label: {
                            SettingRow(icon: "sparkle", title: "위젯 미리보기 · 추가하는 법") { chevron }
                        }.buttonStyle(.plain).accessibilityIdentifier("widgets")
                        RowDivider()
                        SettingRow(icon: "star", title: "애플워치", plus: !model.plus) { trailingText(model.plus ? "켜짐" : "꺼짐") }
                    }

                    SectionLabel(text: "정보")
                    RowGroup {
                        Button { go(.sources) } label: {
                            SettingRow(title: "데이터 출처", subtitle: "기상청 · MET Norway") { chevron }
                        }.buttonStyle(.plain)
                        RowDivider()
                        Link(destination: Legal.privacy) { SettingRow(title: "개인정보 처리방침") { chevron } }.buttonStyle(.plain)
                        if let mail = Legal.support {
                            RowDivider()
                            Link(destination: mail) { SettingRow(title: "문의하기") { chevron } }.buttonStyle(.plain)
                        }
                        RowDivider()
                        SettingRow(title: "버전") { trailingText(Self.version) }
                    }
                    Text(model.provider.name == "예시 날씨" ? "지금은 예시 날씨로 보여요 (서버 연결 전)" : "")
                        .font(.system(size: 11)).foregroundStyle(UI.faint).padding(.top, 14).padding(.bottom, 30)
                }
            }
        }
        .background(UI.bg)
    }

    @ViewBuilder private var plan: some View {
        if model.plus {
            RowGroup {
                SettingRow(icon: "sparkle", title: "Plus 구독 중", subtitle: purchases.renewal ?? "연간") {
                    Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                        HStack(spacing: 4) { Text("관리"); Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)) }
                            .font(.system(size: 14)).foregroundStyle(UI.sub)
                    }
                }
            }.padding(.top, 6)
        } else {
            Button { go(.paywall) } label: {
                HStack(spacing: 12) {
                    PixelIcon(name: "sparkle", size: 26)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Purrcast Plus · 3일 무료").font(.px(16)).foregroundStyle(UI.ink)
                        Text("광고 제거 · 애플워치 · 캐릭터 · 가까운 비").font(.system(size: 12)).foregroundStyle(UI.sub)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(UI.accent)
                }
                .padding(16).background(UI.accentSoft).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain).padding(.horizontal, 16).padding(.top, 6)
            .accessibilityIdentifier("go-plus")
        }
    }

    private func toggle(_ b: Binding<Bool>) -> some View { Toggle("", isOn: b).labelsHidden().tint(UI.accent) }
    private func trailingText(_ t: String) -> some View {
        HStack(spacing: 4) {
            Text(t).font(.system(size: 14)).foregroundStyle(UI.sub)
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(UI.faint)
        }
    }
    private var chevron: some View { Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(UI.faint) }

    private func go(_ r: Route) {
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
                Text("날씨는 Purrcast 서버가 두 곳의 예보를 합쳐서 보내요.").font(.system(size: 15)).foregroundStyle(UI.ink)
                source("기상청", "한국", "기본 예보 · 기상특보 · 다음 6시간(Plus)", "공공누리 제1유형(출처표시)")
                source("MET Norway", "전 세계", "해외 예보 · 예보 비교 · Data from MET Norway", "CC BY 4.0")
                VStack(alignment: .leading, spacing: 6) {
                    Text("그 밖에").font(.system(size: 13, weight: .semibold)).foregroundStyle(UI.sub)
                    Text("일출 · 일몰: 위치로 폰에서 계산").font(.system(size: 13)).foregroundStyle(UI.ink)
                    Text("글꼴: Galmuri11 (SIL OFL 1.1)").font(.system(size: 13)).foregroundStyle(UI.ink)
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
            HStack { Text(name).font(.px(17)); Spacer(); Text(area).font(.system(size: 12)).foregroundStyle(UI.sub) }
            Text(use).font(.system(size: 13)).foregroundStyle(UI.ink)
            Text(license).font(.system(size: 12)).foregroundStyle(UI.sub)
        }
        .foregroundStyle(UI.ink).padding(16).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
