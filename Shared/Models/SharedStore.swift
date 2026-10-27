import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// What the app hands to its widgets and the watch: the latest forecast, the character, the plan and the
/// display settings. Written by the app into the shared App Group; read by the widget timeline and the watch.
struct WeatherSnapshot: Codable {
    var scene: WeatherScene
    var character: PurrCharacter
    var plus: Bool
    var characterName: String
    var placeShort: String
    var saved: Date
    var place: Place? = nil
    var plusUntil: Date? = nil          // end of the paid period; widgets / watch drop Plus after it by themselves
    var unitF: Bool = false
    var clock12: Bool = false
    var isSample: Bool = false          // example weather (no server yet)
    var lang: String? = nil             // 설정 → 언어 on the phone ("" = the device's); the watch follows it

    init(scene: WeatherScene, character: PurrCharacter, plus: Bool, characterName: String, placeShort: String, saved: Date,
         place: Place? = nil, plusUntil: Date? = nil, unitF: Bool = false, clock12: Bool = false, isSample: Bool = false, lang: String? = nil) {
        self.scene = scene; self.character = character; self.plus = plus; self.characterName = characterName
        self.placeShort = placeShort; self.saved = saved; self.place = place; self.plusUntil = plusUntil
        self.unitF = unitF; self.clock12 = clock12; self.isSample = isSample; self.lang = lang
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        scene = try c.decode(WeatherScene.self, forKey: .scene)
        character = (try? c.decode(PurrCharacter.self, forKey: .character)) ?? .cat
        plus = (try? c.decode(Bool.self, forKey: .plus)) ?? false
        characterName = (try? c.decode(String.self, forKey: .characterName)) ?? ""
        placeShort = (try? c.decode(String.self, forKey: .placeShort)) ?? ""
        saved = (try? c.decode(Date.self, forKey: .saved)) ?? Date()
        place = try? c.decode(Place.self, forKey: .place)
        plusUntil = try? c.decode(Date.self, forKey: .plusUntil)
        unitF = (try? c.decode(Bool.self, forKey: .unitF)) ?? false
        clock12 = (try? c.decode(Bool.self, forKey: .clock12)) ?? false
        isSample = (try? c.decode(Bool.self, forKey: .isSample)) ?? false
        lang = try? c.decode(String.self, forKey: .lang)
    }

    /// Plus, unless the paid period has ended since the app last ran.
    var plusActive: Bool { plus && (plusUntil.map { $0 > Date() } ?? true) }
    /// Free plan always shows the cat.
    var shownCharacter: PurrCharacter { plusActive ? character : .cat }

    func deg(_ v: Int) -> String { "\(unitF ? Int((Double(v) * 1.8 + 32).rounded()) : v)°" }
    /// "15시" → "오후 3시" when the 12-hour setting is on (and in the app's language)
    func hourLabel(_ l: String) -> String { HourLabel.display(l, clock12: clock12) }

    /// Shown before the app has handed over anything (a widget added before the first launch).
    static var waiting: WeatherSnapshot {
        var s = SceneLibrary.scene("clear")
        s.bubble = WeatherScene.Bubble(kind: "thought", tone: "white", icon: "question", text: "")
        s.cond = L("앱을 열어 주세요")
        return WeatherSnapshot(scene: s, character: .cat, plus: false, characterName: PurrCharacter.cat.defaultName,
                               placeShort: Brand.name, saved: .distantPast, isSample: true)
    }

    /// Widget gallery previews.
    static var sample: WeatherSnapshot {
        var s = SceneLibrary.scene("maybe"); s.place = Place.here.name
        return WeatherSnapshot(scene: s, character: .cat, plus: false, characterName: PurrCharacter.cat.defaultName,
                               placeShort: Place.here.short, saved: Date(), isSample: true)
    }
}

enum SharedStore {
    #if os(watchOS)
    static let groupID = "group.app.purrcast.watch"   // watch app + complications (the phone reaches the watch over WatchConnectivity)
    #else
    static let groupID = "group.app.purrcast"         // phone app + widgets
    #endif
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
