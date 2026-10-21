import Foundation

/// One example weather situation, as drawn on the design canvas (Resources/Data/scenes.json).
/// Until the forecast server is wired in, the app runs on these. The server answers with exactly this JSON shape
/// (docs/server-api.md), so switching over is only a matter of setting PurrcastServerURL.
struct WeatherScene: Codable, Identifiable {
    var id: String = ""
    var time: String            // day | night
    var cover: String           // clear | partly | overcast
    var precip: String          // none | rain | heavy | snow
    var thunder: String         // on | off
    var aux: String             // none | wind | fog | heat | frost | dust
    var level: Int              // outfit 0...9
    var rain: String            // none | think | bag | umbrella
    var temp: Int
    var feels: Int
    var hi: Int
    var lo: Int
    var yday: Int               // vs the same hour yesterday
    var cond: String
    var clock: String           // "13:46"
    var updated: String         // "06:00"
    var bubble: Bubble?
    var hours: [HourRow]
    var tiles: [Tile]
    var wind: Wind
    var days: [DayRow]
    var place: String?
    var plus: Bool?
    var snow: Bool?
    var mood: String?
    var minutes: [Double]?      // next-hour rain, mm/h per minute (Plus, minute-forecast regions)
    var next6: [NextHour]?      // KMA six-hour slots (Plus, Korea)

    enum CodingKeys: String, CodingKey {
        case time, cover, precip, thunder, aux, level, rain, temp, feels, hi, lo, yday, cond, clock, updated, bubble, hours, tiles, wind, days, place, plus, snow, mood, minutes, next6
    }

    struct Bubble: Codable { var kind: String; var tone: String; var icon: String; var text: String }
    struct Wind: Codable { var speed: Int; var gust: Int; var deg: Int }
    struct Tile: Codable {
        var kind: String?; var icon: String; var label: String; var value: String?; var unit: String?; var note: String; var uv: Int?
    }
    /// ["14시", "cloud", 18, 20, 0]  → label, icon, temp, chance %, mm
    struct HourRow: Codable {
        var label: String; var icon: String; var temp: Int; var chance: Int; var mm: Double
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            label = try c.decode(String.self); icon = try c.decode(String.self)
            temp = Int(try c.decode(Double.self)); chance = Int(try c.decode(Double.self)); mm = try c.decode(Double.self)
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.unkeyedContainer()
            try c.encode(label); try c.encode(icon); try c.encode(temp); try c.encode(chance); try c.encode(mm)
        }
    }
    /// ["수", "raincloud", 60, 12, 16] → name, icon, chance %, lo, hi
    struct DayRow: Codable {
        var name: String; var icon: String; var chance: Int; var lo: Int; var hi: Int
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            name = try c.decode(String.self); icon = try c.decode(String.self)
            chance = Int(try c.decode(Double.self)); lo = Int(try c.decode(Double.self)); hi = Int(try c.decode(Double.self))
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.unkeyedContainer()
            try c.encode(name); try c.encode(icon); try c.encode(chance); try c.encode(lo); try c.encode(hi)
        }
    }
    /// ["15시", 0.8] → label, mm
    struct NextHour: Codable {
        var label: String; var mm: Double
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            label = try c.decode(String.self); mm = try c.decode(Double.self)
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.unkeyedContainer()
            try c.encode(label); try c.encode(mm)
        }
    }

    var isNight: Bool { time == "night" }
    var isPlus: Bool { plus ?? false }
    var isSnow: Bool { snow ?? false }
    var maxChance12h: Int { hours.map { $0.chance }.max() ?? 0 }
    var anyMM: Bool { hours.contains { $0.mm > 0 } }
    var anyChance: Bool { hours.contains { $0.chance >= 10 } }
}

enum SceneLibrary {
    static let order = ["clear", "maybe", "combo", "tokyo_soon", "seoul_soon", "spring_chill", "spring_dust", "spring_rain",
                        "summer_monsoon", "summer_night", "summer_heat", "summer_typhoon", "winter_eve", "winter_cold", "winter_snow"]
    static let all: [String: WeatherScene] = {
        guard let url = Bundle.main.url(forResource: "scenes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              var dict = try? JSONDecoder().decode([String: WeatherScene].self, from: data) else { return [:] }
        for k in dict.keys { dict[k]?.id = k }
        return dict
    }()
    static func scene(_ key: String) -> WeatherScene { all[key] ?? all["clear"]! }
}
