import WidgetKit
import SwiftUI

// Watch complications: the character silhouette with the temperature (rectangular), today's range (circular),
// rain chance (corner) and one line (inline). Data: what the watch app saved from the phone.

struct WatchEntry: TimelineEntry { let date: Date; let snap: WeatherSnapshot }

struct WatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchEntry { WatchEntry(date: Date(), snap: .sample) }
    func getSnapshot(in context: Context, completion: @escaping (WatchEntry) -> Void) {
        completion(WatchEntry(date: Date(), snap: SharedStore.load() ?? (context.isPreview ? .sample : .waiting)))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchEntry>) -> Void) {
        let e = WatchEntry(date: Date(), snap: SharedStore.load() ?? .waiting)
        completion(Timeline(entries: [e], policy: .after(Date().addingTimeInterval(1800))))
    }
}

struct ComplicationView: View {
    @Environment(\.widgetFamily) var family
    let entry: WatchEntry
    var body: some View {
        let s = entry.snap.scene
        if !entry.snap.plusActive {
            Text("Plus").font(.system(size: 12, weight: .bold))
        } else {
            switch family {
            case .accessoryRectangular: LockRectangularView(snap: entry.snap)
            case .accessoryCorner:
                Text(entry.snap.deg(s.temp)).font(.system(size: 20, weight: .bold))
                    .widgetLabel { Text(LockText.line(s)) }
            case .accessoryInline: Text(LockText.inline(entry.snap))
            default: LockCircularView(snap: entry.snap)
            }
        }
    }
}

@main
struct PurrcastComplications: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PurrcastWatch", provider: WatchProvider()) { e in
            ComplicationView(entry: e).containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName(Brand.name)
        .description("옷차림으로 보는 지금 날씨")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}
