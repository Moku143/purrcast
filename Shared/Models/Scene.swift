import Foundation

/// One forecast as the app draws it. The server answers with exactly this JSON shape (docs/server-api.md);
/// the example scenes in Shared/Data/scenes.json use it too (development, screenshots).
///
/// Decoding is lenient on purpose: a missing field gets a safe default, numbers may be decimals, and values
/// that would break the layout (hi below lo, a wind direction of −12°, a clock without ":") are repaired, so a
/// server mistake shows a slightly plain screen instead of no weather or a crash.
struct WeatherScene: Codable, Identifiable {
    var id: String = ""
    var time: String = "day"            // day | night
    var cover: String = "partly"        // clear | partly | overcast
    var precip: String = "none"         // none | rain | heavy | snow
    var thunder: String = "off"         // on | off
    var aux: String = "none"            // none | wind | fog | heat | frost | dust
    var clouds: Int?                    // 0–100 % cloud now: how many clouds the sky draws (nil: from `cover`)
    var fog: Int = 0                    // 0 none · 1 mist · 2 fog · 3 thick fog: how thick the fog is drawn
    var level: Int = 5                  // outfit 0...14 (JSON "outfit")
    var rain: String = "none"           // none | think | bag | umbrella
    var temp: Int = 0
    var feels: Int = 0
    var hi: Int = 0
    var lo: Int = 0
    var yday: Int = 0                   // vs the same hour yesterday
    var cond: String = ""
    var clock: String = "12:00"         // "13:46"
    var updated: String = ""            // "06:00"
    var bubble: Bubble?
    var hours: [HourRow] = []
    var tiles: [Tile] = []
    var wind = Wind(speed: 0, gust: 0, deg: 0)
    var days: [DayRow] = []
    var place: String?
    var plus: Bool?
    var snow: Bool?
    var mood: String?
    var minutes: [Double]?              // next-hour rain, mm/h per minute (Plus, where a minute source exists)
    var next6: [NextHour]?              // next six hourly slots (Plus)
    var nextSource: String?             // kma | met — which forecast the six hours come from
    var dayDetail: [[DayHour]]?         // per day, the day sheet's rows: one per forecast point (hourly where the forecast is)
    var alert: Alert?                   // official warning in force: name + what it means today (home banner)
    var cmp: Compare?                   // 예보 비교: every source's next 24 h, for the comparison card
    var src: String?                    // kma | apple | met — the source behind everything else

    enum CodingKeys: String, CodingKey {
        // `level` travels as "outfit" (0…14, fifteen outfits); the old ten-outfit "level" is only read (LegacyKeys)
        case level = "outfit"
        case time, cover, precip, thunder, aux, clouds, fog, rain, temp, feels, hi, lo, yday, cond, clock, updated, bubble, hours, tiles, wind, days, place, plus, snow, mood, minutes, next6, nextSource, dayDetail, alert, cmp, src
    }
    private enum LegacyKeys: String, CodingKey { case level }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func s(_ k: CodingKeys, _ d: String) -> String { (try? c.decodeIfPresent(String.self, forKey: k)) ?? d }
        func n(_ k: CodingKeys, _ d: Int) -> Int { ((try? c.decodeIfPresent(Double.self, forKey: k)) ?? nil).map { Int($0.rounded()) } ?? d }
        time = s(.time, "day"); cover = s(.cover, "partly"); precip = s(.precip, "none"); thunder = s(.thunder, "off")
        aux = s(.aux, "none"); rain = s(.rain, "none")
        clouds = ((try? c.decodeIfPresent(Double.self, forKey: .clouds)) ?? nil).map { max(0, min(100, Int($0.rounded()))) }
        fog = max(0, min(3, n(.fog, aux == "fog" ? 2 : 0)))
        temp = n(.temp, 0); feels = n(.feels, temp)
        // the outfit: the server's own (with its hysteresis) when it sends one; from a server of the ten-outfit days
        // it is worked out here from the feels-like temperature (its old level number means other clothes now)
        if let o = (try? c.decodeIfPresent(Double.self, forKey: .level)) ?? nil {
            level = Rules.clamp(Int(o.rounded()))
        } else if c.contains(.feels) || c.contains(.temp) {
            level = Rules.level(feels: Double(feels))
        } else {
            let old = ((try? decoder.container(keyedBy: LegacyKeys.self).decodeIfPresent(Double.self, forKey: .level)) ?? nil) ?? 4
            level = Rules.level(fromLegacy: Int(old.rounded()))
        }
        let a = n(.hi, temp), b = n(.lo, temp)
        hi = max(a, b, temp); lo = min(a, b, temp)
        yday = n(.yday, 0)
        cond = s(.cond, ""); updated = s(.updated, "")
        let ck = s(.clock, "")
        clock = Self.clockMinutes(ck) == nil ? "12:00" : ck
        bubble = (try? c.decodeIfPresent(Bubble.self, forKey: .bubble))
        hours = Self.lossy(c, .hours)
        tiles = Self.lossy(c, .tiles)
        wind = (try? c.decodeIfPresent(Wind.self, forKey: .wind)) ?? Wind(speed: 0, gust: 0, deg: 0)
        days = Self.lossy(c, .days)
        place = (try? c.decodeIfPresent(String.self, forKey: .place)) ?? nil
        plus = (try? c.decodeIfPresent(Bool.self, forKey: .plus)) ?? nil
        snow = (try? c.decodeIfPresent(Bool.self, forKey: .snow)) ?? nil
        mood = (try? c.decodeIfPresent(String.self, forKey: .mood)) ?? nil
        minutes = (try? c.decodeIfPresent([Double].self, forKey: .minutes)) ?? nil
        let n6: [NextHour] = Self.lossy(c, .next6)
        next6 = n6.isEmpty ? nil : n6
        nextSource = (try? c.decodeIfPresent(String.self, forKey: .nextSource)) ?? nil
        dayDetail = (try? c.decodeIfPresent([[DayHour]].self, forKey: .dayDetail)) ?? nil
        alert = (try? c.decodeIfPresent(Alert.self, forKey: .alert)) ?? nil
        let cm = (try? c.decodeIfPresent(Compare.self, forKey: .cmp)) ?? nil
        cmp = (cm?.sources.count ?? 0) >= 2 ? cm : nil
        src = (try? c.decodeIfPresent(String.self, forKey: .src)) ?? nil
    }

    /// Decode an array, skipping elements that do not parse instead of failing the whole forecast.
    private static func lossy<T: Decodable>(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys) -> [T] {
        guard var u = try? c.nestedUnkeyedContainer(forKey: k) else { return [] }
        var out: [T] = []
        while !u.isAtEnd {
            if let v = try? u.decode(T.self) { out.append(v) } else { _ = try? u.decode(Skip.self) }
        }
        return out
    }
    /// Decodes (and so steps over) any element.
    private struct Skip: Decodable { init(from decoder: Decoder) throws {} }

    /// "13:46" → 826, nil when it is not a clock time
    static func clockMinutes(_ s: String) -> Int? {
        let a = s.split(separator: ":")
        guard a.count == 2, let h = Int(a[0]), let m = Int(a[1]), (0..<24).contains(h), (0..<60).contains(m) else { return nil }
        return h * 60 + m
    }

    /// { start: hour of slot 0, snow, sources: [{ name, key, main, t: [24], r: [24] }] } — a slot a source has no point for is null.
    struct Compare: Codable {
        var start: Int; var snow: Bool; var sources: [Source]
        struct Source: Codable {
            var name: String; var key: String; var main: Bool; var t: [Int?]; var r: [Double?]
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                name = (try? c.decode(String.self, forKey: .name)) ?? ""
                key = (try? c.decode(String.self, forKey: .key)) ?? ""
                main = (try? c.decode(Bool.self, forKey: .main)) ?? false
                t = ((try? c.decode([Double?].self, forKey: .t)) ?? []).map { $0.map { Int($0.rounded()) } }
                r = (try? c.decode([Double?].self, forKey: .r)) ?? []
            }
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            start = (((try? c.decode(Int.self, forKey: .start)) ?? 0) % 24 + 24) % 24
            snow = (try? c.decode(Bool.self, forKey: .snow)) ?? false
            sources = ((try? c.decode([Source].self, forKey: .sources)) ?? []).filter { $0.t.contains { $0 != nil } }
        }
    }

    struct Alert: Codable, Equatable {
        var name: String; var note: String
        init(name: String, note: String) { self.name = name; self.note = note }
    }

    struct Bubble: Codable {
        var kind: String; var tone: String; var icon: String; var text: String
        init(kind: String, tone: String, icon: String, text: String) { self.kind = kind; self.tone = tone; self.icon = icon; self.text = text }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            kind = (try? c.decode(String.self, forKey: .kind)) ?? "speech"
            tone = (try? c.decode(String.self, forKey: .tone)) ?? "white"
            icon = (try? c.decode(String.self, forKey: .icon)) ?? "none"
            text = (try? c.decode(String.self, forKey: .text)) ?? ""
        }
    }
    struct Wind: Codable {
        var speed: Int; var gust: Int; var deg: Int
        init(speed: Int, gust: Int, deg: Int) { self.speed = speed; self.gust = gust; self.deg = deg }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            func n(_ k: CodingKeys) -> Int { ((try? c.decode(Double.self, forKey: k)).map { Int($0.rounded()) }) ?? 0 }
            speed = max(0, n(.speed)); gust = max(speed, n(.gust)); deg = ((n(.deg) % 360) + 360) % 360
        }
    }
    struct Tile: Codable {
        var kind: String?; var icon: String; var label: String; var value: String?; var unit: String?; var note: String; var uv: Int?
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            kind = try? c.decode(String.self, forKey: .kind)
            icon = (try? c.decode(String.self, forKey: .icon)) ?? "cloud"
            label = (try? c.decode(String.self, forKey: .label)) ?? ""
            value = try? c.decode(String.self, forKey: .value)
            unit = try? c.decode(String.self, forKey: .unit)
            note = (try? c.decode(String.self, forKey: .note)) ?? ""
            uv = (try? c.decode(Double.self, forKey: .uv)).map { Int($0.rounded()) }
        }
    }
    /// ["14시", "cloud", 18, 20, 0]  → label, icon, temp, chance %, mm
    struct HourRow: Codable {
        var label: String; var icon: String; var temp: Int; var chance: Int; var mm: Double
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            label = try c.decode(String.self); icon = try c.decode(String.self)
            temp = Int(try c.decode(Double.self).rounded())
            chance = max(0, min(100, Int(((try? c.decode(Double.self)) ?? 0).rounded())))
            mm = max(0, (try? c.decode(Double.self)) ?? 0)
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.unkeyedContainer()
            try c.encode(label); try c.encode(icon); try c.encode(temp); try c.encode(chance); try c.encode(mm)
        }
    }
    /// ["수", "raincloud", 60, 12, 16] → name, icon, chance %, lo, hi
    struct DayRow: Codable {
        var name: String; var icon: String; var chance: Int; var lo: Int; var hi: Int
        init(name: String, icon: String, chance: Int, lo: Int, hi: Int) { self.name = name; self.icon = icon; self.chance = chance; self.lo = lo; self.hi = hi }
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            name = try c.decode(String.self); icon = try c.decode(String.self)
            chance = max(0, min(100, Int(((try? c.decode(Double.self)) ?? 0).rounded())))
            let a = Int(try c.decode(Double.self).rounded()), b = Int(try c.decode(Double.self).rounded())
            lo = min(a, b); hi = max(a, b)
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
            label = try c.decode(String.self); mm = max(0, (try? c.decode(Double.self)) ?? 0)
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.unkeyedContainer()
            try c.encode(label); try c.encode(mm)
        }
    }
    /// ["9시", 13, 20, 3, 4, 70, 0.4, 5.2, 225] → hour label, °C, rain chance %, wind m/s, UV, humidity %, then for the
    /// whole 3-hour slot: precipitation mm (cm on a snowy day), strongest gust m/s, wind direction ° (where it comes from).
    /// One of 8 per day. Older answers stop after humidity: `mm`, `gust` and `dir` are nil then.
    struct DayHour: Codable {
        var label: String; var temp: Double; var chance: Double; var wind: Double; var uv: Double; var rh: Double
        var mm: Double?; var gust: Double?; var dir: Double?
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            label = try c.decode(String.self)
            temp = try c.decode(Double.self)
            chance = (try? c.decode(Double.self)) ?? 0; wind = (try? c.decode(Double.self)) ?? 0
            uv = (try? c.decode(Double.self)) ?? 0; rh = (try? c.decode(Double.self)) ?? 0
            // optional tail: decoded only when present (a missing or null value stays nil)
            func more() -> Double? {
                if c.isAtEnd { return nil }
                if (try? c.decodeNil()) == true { return nil }
                return try? c.decode(Double.self)
            }
            mm = more().map { max(0, $0) }
            gust = more().map { max(0, $0) }
            dir = more().map { ($0.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) }
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.unkeyedContainer()
            try c.encode(label); try c.encode(temp); try c.encode(chance); try c.encode(wind); try c.encode(uv); try c.encode(rh)
            // the tail only when there is one (a nil in the middle is written as null so the positions stay right)
            if mm != nil || gust != nil || dir != nil { try c.encode(mm); try c.encode(gust); try c.encode(dir) }
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
    private static var cache: [Lang: [String: WeatherScene]] = [:]
    private static let lock = NSLock()
    /// The example scenes in the current language (the language can change while the app runs).
    static var all: [String: WeatherScene] {
        let lang = Lang.current
        lock.lock(); defer { lock.unlock() }
        if let c = cache[lang] { return c }
        let d = load(lang); cache[lang] = d
        return d
    }
    private static func load(_ lang: Lang) -> [String: WeatherScene] {
        // the Korean originals, or the translated copies (server/scripts/translate-scenes.mjs) for English / Japanese
        let name = lang == .ko ? "scenes" : "scenes.\(lang.rawValue)"
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") ?? Bundle.main.url(forResource: "scenes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        var dict: [String: WeatherScene] = [:]
        for (k, v) in raw {   // one bad scene never takes the others down
            guard let d = try? JSONSerialization.data(withJSONObject: v), var s = try? JSONDecoder().decode(WeatherScene.self, from: d) else { continue }
            s.id = k; dict[k] = s
        }
        return dict
    }
    /// An example scene; never crashes even if the bundle has none.
    static func scene(_ key: String) -> WeatherScene {
        if let s = all[key] ?? all["clear"] ?? all.values.first { return s }
        var s = WeatherScene(); s.id = key; s.cond = "—"
        return s
    }
}
