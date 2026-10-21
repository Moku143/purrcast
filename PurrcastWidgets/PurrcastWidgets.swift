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
        completion(WeatherEntry(date: Date(), snap: SharedStore.load() ?? .sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        Task {
            let snap = await fetch() ?? SharedStore.load() ?? .sample
            // free: the 06:00 forecast, refreshed a few times a day; Plus: every 30 minutes
            let next = Calendar.current.date(byAdding: .minute, value: snap.plus ? 30 : 180, to: Date()) ?? Date().addingTimeInterval(1800)
            completion(Timeline(entries: [WeatherEntry(date: Date(), snap: snap)], policy: .after(next)))
        }
    }

    /// With a server configured, the widget asks for the saved place itself; otherwise nil (use what the app saved).
    private func fetch() async -> WeatherSnapshot? {
        guard WeatherSource.serverURL != nil, var last = SharedStore.load() else { return nil }
        let place = Place.catalog.first { $0.short == last.placeShort } ?? Place.here
        guard let s = try? await WeatherSource.make().forecast(for: place, plus: last.plus) else { return nil }
        last.scene = s; last.saved = Date()
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
        case .accessoryInline: Text(LockText.inline(entry.snap.scene))
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
        .configurationDisplayName("Purrcast")
        .description("옷차림으로 보는 지금 날씨")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct RainWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PurrcastRain", provider: Provider()) { entry in
            LockRainCircularView(snap: entry.snap)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("비 올 확률")
        .description("앞으로 몇 시간 안에 비 올 확률")
        .supportedFamilies([.accessoryCircular])
    }
}

@main
struct PurrcastWidgetBundle: WidgetBundle {
    var body: some Widget {
        PurrcastWidget()
        RainWidget()
    }
}
