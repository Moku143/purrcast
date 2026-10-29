import SwiftUI

/// The layout board's widget page (UI tests: -open widgetLab). Every widget at its real size on a 393-pt-wide iPhone,
/// home-screen ones on their own background, lock-screen ones on a lock-screen-like wallpaper, the watch app's first
/// page at the 46-mm screen's size, each in a box named lab-<widget> so the board can cut it out and let its parts
/// be moved.
struct WidgetLabView: View {
    @EnvironmentObject var model: AppModel

    /// -labPage2: the widgets that do not fit on the first page (the hourly 2×4)
    private var second: Bool { ProcessInfo.processInfo.arguments.contains("-labPage2") }

    var body: some View {
        let snap = model.snapshot
        if second {
            VStack(spacing: 16) {
                home("lab-hours", 364, 170, snap) { HoursWidgetView(snap: snap) }
            }
            .padding(.top, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(hex: "#ECEAF4"))
        } else {
            first(snap)
        }
    }

    private func first(_ snap: WeatherSnapshot) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                home("lab-small", 170, 170, snap) { SmallWidgetView(snap: snap) }
                WatchAppScreen(snap: snap).frame(width: 208, height: 248)
                    .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                    .accessibilityElement(children: .contain).accessibilityIdentifier("lab-watch")
            }
            home("lab-medium", 364, 170, snap) { MediumWidgetView(snap: snap) }
            HStack(alignment: .top, spacing: 12) {
                lock("lab-rect", 172, 76) { LockRectangularView(snap: snap) }
                lock("lab-circle", 76, 76, circle: true) { LockCircularView(snap: snap) }
                lock("lab-rain", 76, 76, circle: true) { LockRainCircularView(snap: snap) }
            }
            lock("lab-inline", 257, 26) {
                Text(LockText.inline(snap)).font(.system(size: 15, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: "#ECEAF4"))
    }

    private func home<C: View>(_ id: String, _ w: CGFloat, _ h: CGFloat, _ snap: WeatherSnapshot, @ViewBuilder _ c: () -> C) -> some View {
        c().padding(16).frame(width: w, height: h)
            .background(WidgetBackground(level: snap.scene.level, night: snap.scene.isNight, scene: snap.scene))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .accessibilityElement(children: .contain).accessibilityIdentifier(id)
    }

    private func lock<C: View>(_ id: String, _ w: CGFloat, _ h: CGFloat, circle: Bool = false, @ViewBuilder _ c: () -> C) -> some View {
        c().foregroundStyle(.white).frame(width: w, height: h)
            .padding(circle ? 0 : 6)
            .background(LinearGradient(colors: [Color(hex: "#5B5FA8"), Color(hex: "#2E2F66")], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: circle ? w / 2 + 6 : 12, style: .continuous))
            .accessibilityElement(children: .contain).accessibilityIdentifier(id)
    }
}
