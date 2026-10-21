import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// What the app hands to its widgets (and later the watch): the latest forecast, the character and the plan.
/// Written by the app into the shared App Group; read by the widget timeline.
struct WeatherSnapshot: Codable {
    var scene: WeatherScene
    var character: PurrCharacter
    var plus: Bool
    var characterName: String
    var placeShort: String
    var saved: Date

    /// Free plan always shows the cat.
    var shownCharacter: PurrCharacter { plus ? character : .cat }

    /// Used by widget previews and when the app has not run yet.
    static var sample: WeatherSnapshot {
        var s = SceneLibrary.scene("maybe"); s.place = Place.here.name
        return WeatherSnapshot(scene: s, character: .cat, plus: false, characterName: PurrCharacter.cat.defaultName, placeShort: Place.here.short, saved: Date())
    }
}

enum SharedStore {
    static let groupID = "group.app.purrcast"
    static var defaults: UserDefaults { UserDefaults(suiteName: groupID) ?? .standard }
    private static let key = "snapshot.v1"

    static func save(_ snap: WeatherSnapshot) {
        guard let data = try? JSONEncoder().encode(snap) else { return }
        defaults.set(data, forKey: key)
        #if canImport(WidgetKit) && !os(watchOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    static func load() -> WeatherSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WeatherSnapshot.self, from: data)
    }
}
