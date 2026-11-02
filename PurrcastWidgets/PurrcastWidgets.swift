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
            let now = Date()
            let next = Calendar.current.date(byAdding: .minute, value: snap.plusActive ? 30 : 180, to: now) ?? now.addingTimeInterval(1800)
            var entries = [WeatherEntry(date: now, snap: snap)]
            // the sunrise / sunset circle turns over right when the sun rises or sets, before the next refresh
            if let p = snap.place, let tz = TimeZone(identifier: p.timeZone),
               let sun = SunTimes.next(after: now, lat: p.lat, lon: p.lon, tz: tz), sun.at < next {
                entries.append(WeatherEntry(date: sun.at.addingTimeInterval(30), snap: snap))
            }
            completion(Timeline(entries: entries, policy: .after(next)))
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
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

/// Lock screen: the temperature circle on its own (today's range as a ring, now in the middle)
struct TempWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PurrcastTemp", provider: Provider()) { entry in
            LockCircularView(snap: entry.snap)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName(L("오늘 기온"))
        .description(L("지금 기온과 오늘 최저 · 최고"))
        .supportedFamilies([.accessoryCircular])
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
        .supportedFamilies([.accessoryCircular])
    }
}

/// Lock screen: today's highest UV index on the temperature circle's ring
struct UVWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PurrcastUV", provider: Provider()) { entry in
            LockUVCircularView(snap: entry.snap).containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName(L("자외선"))
        .description(L("오늘 가장 높은 자외선 지수"))
        .supportedFamilies([.accessoryCircular])
    }
}

/// Lock screen: the next sunrise or sunset — its icon over the time
struct SunWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PurrcastSun", provider: Provider()) { entry in
            LockSunCircularView(snap: entry.snap, now: entry.date).containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName(L("일출 · 일몰"))
        .description(L("다음 일출 또는 일몰 시각"))
        .supportedFamilies([.accessoryCircular])
    }
}

/// Lock screen: the wind — an arrow the way it blows, the speed under it
struct WindWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PurrcastWind", provider: Provider()) { entry in
            LockWindCircularView(snap: entry.snap).containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName(L("바람"))
        .description(L("지금 바람이 부는 방향과 세기"))
        .supportedFamilies([.accessoryCircular])
    }
}

/// Lock screen (Plus): 미세먼지 in the circle's place — the dust icon over the step's word, nothing behind it
struct DustWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PurrcastDust", provider: Provider()) { entry in
            DustLockView(snap: entry.snap).containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName(L("미세먼지"))
        .description(L("미세먼지 · 초미세먼지 등급 (Plus)"))
        .supportedFamilies([.accessoryCircular])
    }
}

struct DustLockView: View {
    let snap: WeatherSnapshot
    var body: some View { LockDustCircularView(snap: snap) }
}

@main
struct PurrcastWidgetBundle: WidgetBundle {
    var body: some Widget {
        PurrcastWidget()
        HoursWidget()
        TempWidget()
        RainWidget()
        DustWidget()
        UVWidget()
        SunWidget()
        WindWidget()
        RainLiveActivity()
    }
}
