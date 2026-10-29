import WidgetKit
import SwiftUI

// Home-screen and lock-screen widgets. They show the forecast the app last handed over (SharedStore);
// once the forecast server is connected, the timeline also fetches by itself (see `Provider.fetch`).

struct WeatherEntry: TimelineEntry {
    let date: Date
    let snap: WeatherSnapshot
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry { WeatherEntry(date: Date(), snap: .sample) }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
        // the widget gallery shows a sample; a placed widget shows what the app saved (or asks to open the app)
        completion(WeatherEntry(date: Date(), snap: context.isPreview ? (SharedStore.load() ?? .sample) : (SharedStore.load() ?? .waiting)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        Task {
            let snap = await fetch() ?? SharedStore.load() ?? .waiting
            // free: the morning forecast, refreshed a few times a day; Plus: every 30 minutes
            let next = Calendar.current.date(byAdding: .minute, value: snap.plusActive ? 30 : 180, to: Date()) ?? Date().addingTimeInterval(1800)
            completion(Timeline(entries: [WeatherEntry(date: Date(), snap: snap)], policy: .after(next)))
        }
    }

    /// With a server configured, the widget refreshes the app's current place itself (the plan as of now);
    /// otherwise nil (use what the app saved).
    private func fetch() async -> WeatherSnapshot? {
        guard WeatherSource.serverURL != nil, var last = SharedStore.load(), !last.isSample, let place = last.place else { return nil }
        guard let s = try? await WeatherSource.make().forecast(for: place, plus: last.plusActive, previousLevel: last.scene.level) else { return nil }
        last.scene = s; last.saved = Date()
        if !last.plusActive { last.plus = false }
        SharedStore.save(last)
        return last
    }
}

struct HomeWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: WeatherEntry
    var body: some View {
        switch family {
        case .systemMedium: MediumWidgetView(snap: entry.snap)
        case .accessoryRectangular: LockRectangularView(snap: entry.snap)
        case .accessoryCircular: LockCircularView(snap: entry.snap)
        case .accessoryInline: Text(LockText.inline(entry.snap))
        default: SmallWidgetView(snap: entry.snap)
        }
    }
}

struct PurrcastWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PurrcastWidget", provider: Provider()) { entry in
            HomeWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground(level: entry.snap.scene.level, night: entry.snap.scene.isNight, scene: entry.snap.scene)
                }
        }
        .configurationDisplayName(Brand.name)
        .description(L("옷차림으로 보는 지금 날씨"))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

/// 2×4 with the next six hours, the character dressed for each.
struct HoursWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PurrcastHours", provider: Provider()) { entry in
            HoursWidgetView(snap: entry.snap)
                .containerBackground(for: .widget) {
                    WidgetBackground(level: entry.snap.scene.level, night: entry.snap.scene.isNight, scene: entry.snap.scene)
                }
        }
        .configurationDisplayName(L("시간별 날씨"))
        .description(L("다음 6시간을 시간마다 옷차림으로 보여줘요"))
        .supportedFamilies([.systemMedium])
    }
}

struct RainWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PurrcastRain", provider: Provider()) { entry in
            LockRainCircularView(snap: entry.snap)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName(L("비 올 확률"))
        .description(L("앞으로 몇 시간 안에 비 올 확률"))
        .supportedFamilies([.accessoryCircular])
    }
}

@main
struct PurrcastWidgetBundle: WidgetBundle {
    var body: some Widget {
        PurrcastWidget()
        HoursWidget()
        RainWidget()
    }
}
