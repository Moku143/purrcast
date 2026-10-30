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

enum RainLiveWords {
    /// The compact island has room for a few characters: "6시 비" / "비 1mm"
    static func short(_ s: RainActivityAttributes.ContentState) -> String {
        if s.falling { return s.mm >= 0.1 ? "\(s.what == "snow" ? L("눈") : L("비")) \(mmText(s.mm))\(s.what == "snow" ? "cm" : "mm")" : (s.what == "snow" ? L("눈") : L("비")) }
        return s.title.replacingOccurrences(of: L(" 예보"), with: "")
    }
    static func mmText(_ v: Double) -> String { v >= 10 ? String(Int(v.rounded())) : { let r = (v * 10).rounded() / 10; return r == r.rounded() ? String(Int(r)) : String(format: "%.1f", r) }() }
}

/// The character dressed for the day: under the open umbrella once it rains, the umbrella packed before
struct RainCat: View {
    let a: RainActivityAttributes; let s: RainActivityAttributes.ContentState; var width: CGFloat = 56
    var body: some View {
        let c = PurrCharacter(rawValue: a.character) ?? .cat
        CharacterSprite(character: c, level: Rules.clamp(a.level), rain: s.falling ? .umbrella : .bag, width: width, animate: false)
            .frame(width: width, alignment: .bottom)
    }
}

/// From now to when the rain is past: filled to the start before it rains, draining while it rains
struct RainBar: View {
    let s: RainActivityAttributes.ContentState
    var body: some View {
        let start = Date(), end = s.endDate
        VStack(spacing: 4) {
            ProgressView(timerInterval: start...max(end, start.addingTimeInterval(60)), countsDown: false, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                .tint(Color(hex: "#4C8DFF")).progressViewStyle(.linear)
            HStack {
                Text(L("지금")).font(.ui(10)).foregroundStyle(Color(hex: "#9AA3C7"))
                Spacer()
                Text(L("%d시", s.endHour)).font(.ui(10)).foregroundStyle(Color(hex: "#9AA3C7"))
            }
        }
    }
}

/// Lock screen (and the banner on phones without the island): the mock's D
struct RainLockView: View {
    let a: RainActivityAttributes; let s: RainActivityAttributes.ContentState
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RainCat(a: a, s: s, width: 56)
            VStack(alignment: .leading, spacing: 5) {
                Text(s.title).font(.px(17)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                Text(a.place.isEmpty ? s.sub : "\(a.place) · \(s.sub)").font(.ui(12)).foregroundStyle(Color(hex: "#C9D0F0")).lineLimit(2).minimumScaleFactor(0.8)
                RainBar(s: s)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}
