import WidgetKit
import SwiftUI
import ActivityKit

/// The rain Live Activity: the character in today's outfit with the umbrella beside "6시쯤 비 예보 · 1mm · 우산
/// 챙기세요" and a bar that fills as the rain approaches (la-final mock: A compact, B expanded, C raining, D lock screen).
/// Started, updated and ended by the server over APNs (Plus); the app only hands over its tokens.
struct RainLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RainActivityAttributes.self) { context in
            RainLockView(a: context.attributes, s: context.state)
                .activityBackgroundTint(Color(hex: "#1A2046"))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let a = context.attributes, s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RainCat(a: a, s: s, width: 48).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(s.title).font(.px(17)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                        Text(a.place.isEmpty ? s.sub : "\(a.place) · \(s.sub)").font(.ui(12)).foregroundStyle(Color(hex: "#C9D0F0")).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    RainBar(s: s).padding(.horizontal, 4).padding(.top, 2)
                }
            } compactLeading: {
                RainCat(a: a, s: s, width: 22)
            } compactTrailing: {
                Text(RainLiveWords.short(s)).font(.px(12)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            } minimal: {
                PixelIcon(name: s.icon, size: 16)
            }
            .keylineTint(Color(hex: "#4C8DFF"))
        }
    }
}
