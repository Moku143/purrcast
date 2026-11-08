import WidgetKit
import SwiftUI

// Home-screen and lock-screen widgets. They show the forecast the app last handed over (SharedStore);
// once the forecast server is connected, the timeline also fetches by itself (see `Provider.fetch`).

struct WeatherEntry: TimelineEntry {
    let date: Date
    let snap: WeatherSnapshot
    var preview = false     // the widget gallery
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry { WeatherEntry(date: Date(), snap: .sample) }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
        // the widget gallery shows a sample; a placed widget shows what the app saved (aged to now, or asks to open the app)
        completion(WeatherEntry(date: Date(), snap: context.isPreview ? (SharedStore.load() ?? .sample) : (SharedStore.load()?.aged() ?? .waiting),
                                preview: context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        Task {
            let fetchedSnap = await fetch()
            let snap = fetchedSnap ?? SharedStore.load() ?? .waiting
            // free: the morning forecast, refreshed a few times a day; Plus: every 30 minutes
            let now = Date()
            var next = Calendar.current.date(byAdding: .minute, value: snap.plusActive ? 30 : 180, to: now) ?? now.addingTimeInterval(1800)
            // and once just before midnight: the day's 날씨 기록 closes with where the phone is then
            if let p = snap.place, let tz = TimeZone(identifier: p.timeZone) {
                if let close = DayLog.closingRefresh(after: now, regular: next, tz: tz) { next = close }
                // Plus: and once just after it, for the new day's 최고 · 최저 from the newest forecast (free: the saved
                // forecast's next day takes over at 0시, in the entries below)
                if snap.plusActive, let open = DayLog.openingRefresh(after: now, regular: next, tz: tz) { next = open }
            }
            // the entries age the forecast by the hour (and at the sun's turn) instead of repeating its "now":
            // when the fetch failed they go on to the forecast's end, covering the refreshes the system defers
            let until = fetchedSnap != nil ? next : now.addingTimeInterval(24 * 3600)
            let entries = snap.timelineEntries(now: now, until: until).map { WeatherEntry(date: $0.date, snap: $0.snap) }
            completion(Timeline(entries: entries, policy: .after(next)))
        }
    }

    /// With a server configured, the widget refreshes the app's current place itself (the plan as of now) —
    /// "지금 위치" where the phone is now, when the location permission covers widgets; otherwise nil (use what the
    /// app saved).
    private func fetch() async -> WeatherSnapshot? {
        guard WeatherSource.serverURL != nil, let last = SharedStore.load(), !last.isSample, var place = last.place else { return nil }
        if place.id == "here", let p = await WidgetLocation.here(from: place), p != place { place = p }
        guard let s = try? await WeatherSource.make().forecast(for: place, plus: last.plusActive, previousLevel: last.scene.level) else { return nil }
        DayLog().record(s, place: place, character: last.shownCharacter, plus: last.plusActive)   // the 날씨 기록 fills on the widget's refreshes too
        // read again now: the app may have saved new settings or another place while the widget waited
        guard let snap = SharedStore.withWidgetForecast(s, for: place, onto: SharedStore.load()) else { return nil }
        SharedStore.save(snap, reload: false)       // no reload from here: that would start every widget's refresh again
        return snap
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
            LockAccessory(inline: .temp, entry: entry) { LockCircularView(snap: entry.snap) }
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName(L("오늘 기온"))
        .description(L("지금 기온과 오늘 최저 · 최고"))
        .supportedFamilies([.accessoryCircular, .accessoryInline])
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
            LockAccessory(inline: .rain, entry: entry) { LockRainCircularView(snap: entry.snap) }
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName(L("비 올 확률"))
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}

/// Lock screen: today's highest UV index on the temperature circle's ring
struct UVWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PurrcastUV", provider: Provider()) { entry in
            LockAccessory(inline: .uv, entry: entry) { LockUVCircularView(snap: entry.snap) }.containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName(L("자외선"))
        .description(L("오늘 가장 높은 자외선 지수"))
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}

/// Lock screen: the next sunrise or sunset — its icon over the time
struct SunWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PurrcastSun", provider: Provider()) { entry in
            LockAccessory(inline: .sun, entry: entry) { LockSunCircularView(snap: entry.snap, now: entry.date) }.containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName(L("일출 · 일몰"))
        .description(L("다음 일출 또는 일몰 시각"))
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}

/// Lock screen: the wind — an arrow the way it blows, the speed under it
struct WindWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PurrcastWind", provider: Provider()) { entry in
            LockAccessory(inline: .wind, entry: entry) { LockWindCircularView(snap: entry.snap) }.containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName(L("바람"))
        .description(L("지금 바람이 부는 방향과 세기"))
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}

/// Lock screen (Plus): 미세먼지 in the circle's place — the dust icon over the step's word, nothing behind it
struct DustWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PurrcastDust", provider: Provider()) { entry in
            LockAccessory(inline: .dust, entry: entry) { LockDustCircularView(snap: entry.snap, preview: entry.preview) }.containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName(L("미세먼지"))
        .description(L("미세먼지 · 초미세먼지 등급 · Plus에서 쓸 수 있어요"))
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}

/// Lock screen, above the clock only: where the forecast is for (지금 위치: where the phone is)
struct PlaceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PurrcastPlace", provider: Provider()) { entry in
            LockInlineView(kind: .place, snap: entry.snap, now: entry.date).containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName(L("지금 위치"))
        .description(L("날씨를 보고 있는 곳의 이름"))
        .supportedFamilies([.accessoryInline])
    }
}

/// One lock-screen widget in its two shapes: the circle, or the line above the clock
struct LockAccessory<Circle: View>: View {
    @Environment(\.widgetFamily) var family
    let inline: LockInlineView.Kind
    let entry: WeatherEntry
    @ViewBuilder let circle: () -> Circle
    var body: some View {
        if family == .accessoryInline {
            LockInlineView(kind: inline, snap: entry.snap, now: entry.date, preview: entry.preview)
        } else {
            circle()
        }
    }
}

@main
struct PurrcastWidgetBundle: WidgetBundle {
    var body: some Widget {
        PurrcastWidget()
        HoursWidget()
        LockWidgets().body
        RainLiveActivity()
    }
}

/// The lock screen's circles and lines (a bundle of their own: a bundle takes at most ten at one level)
struct LockWidgets: WidgetBundle {
    var body: some Widget {
        TempWidget()
        RainWidget()
        DustWidget()
        UVWidget()
        SunWidget()
        WindWidget()
        PlaceWidget()
    }
}
