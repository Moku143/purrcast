import SwiftUI

/// 위젯 미리보기 · 추가하는 법: the widgets as they look with the current weather, and how to add them.
struct WidgetGalleryView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var snap: WeatherSnapshot {
        model.snapshot
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                label("홈 화면")
                HStack(alignment: .top, spacing: 14) {
                    widgetBox(170, 170) { SmallWidgetView(snap: snap) }
                    VStack(alignment: .leading, spacing: 8) {
                        step("1", "홈 화면 빈 곳을 길게 눌러요")
                        step("2", "왼쪽 위 ‘편집’ → ‘위젯 추가’")
                        step("3", "\(Brand.name)를 찾아 크기를 골라요")
                    }
                }
                widgetBox(364, 170) { MediumWidgetView(snap: snap) }

                label("잠금 화면")
                ZStack {
                    LinearGradient(colors: [Color(hex: "#5B5FA8"), Color(hex: "#2E2F66")], startPoint: .top, endPoint: .bottom)
                    VStack(spacing: 10) {
                        Text(LockText.inline(snap)).font(.system(size: 13, weight: .semibold))
                        Text("9:41").font(.system(size: 64, weight: .semibold, design: .rounded))
                        HStack(spacing: 12) {
                            LockRectangularView(snap: snap).frame(width: 160, height: 66)
                            LockCircularView(snap: snap).frame(width: 60, height: 60)
                            LockRainCircularView(snap: snap).frame(width: 60, height: 60)
                        }
                    }
                    .foregroundStyle(.white).padding(.vertical, 18)
                }
                .clipShape(RoundedRectangle(cornerRadius: 26))
                Text("잠금 화면을 길게 눌러 ‘사용자화’ → 잠금 화면 → 위젯 칸에서 \(Brand.name)를 골라요.").font(.system(size: 12)).foregroundStyle(UI.sub)
            }
            .padding(16)
        }
        .background(UI.bg)
        .navigationTitle("위젯").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() }.tint(UI.accent) } }
    }

    private func label(_ t: String) -> some View { Text(t).font(.px(15)).foregroundStyle(UI.ink).padding(.top, 6) }
    private func step(_ n: String, _ t: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(n).font(.px(12)).foregroundStyle(.white).frame(width: 18, height: 18).background(UI.accent).clipShape(Circle())
            Text(t).font(.system(size: 13)).foregroundStyle(UI.ink)
        }
    }
    private func widgetBox<C: View>(_ w: CGFloat, _ h: CGFloat, @ViewBuilder _ c: () -> C) -> some View {
        c().padding(14).frame(width: w, height: h)
            .background(WidgetBackground(level: snap.scene.level, night: snap.scene.isNight, scene: snap.scene))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}
