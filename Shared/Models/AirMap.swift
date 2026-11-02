import Foundation

/// The 대기질 지도 (Plus): air quality around the place, from GET /v1/airmap (docs/server-api.md).
/// Korea: every 에어코리아 station near the place with its 통합대기환경지수; elsewhere: OpenWeather at a grid, PM2.5 / PM10
/// on WHO's steps. `level` 0–4 is the step (0 좋음 · 1 보통 · 2 나쁨 · 3 매우 나쁨) plus how far into it — the map's colour.
struct AirMap: Decodable, Equatable {
    var kind: String = "cai"            // cai (통합대기환경지수, Korea) | pm (PM2.5 / PM10, elsewhere)
    var at: String = ""                 // the hour of the readings ("2026-11-02 18:00" in Korea, an ISO time elsewhere)
    var me: Me?
    var points: [Point] = []
    var detail: Detail?

    /// The sheet behind the map: the index now and yesterday at this hour, the pollutant behind it, every pollutant
    struct Detail: Decodable, Equatable {
        var value: Int?                 // 통합대기환경지수 (Korea); nil elsewhere
        var level: Double
        var grade: Int
        var main: String?               // pm10 · pm25 · o3 · no2 · so2 · co
        var station: String?
        var at: String = ""
        var yday: Yday?
        var items: [Item] = []
        struct Yday: Decodable, Equatable { var value: Int?; var level: Double }
        /// ["pm10", 46, "㎍/㎥"]
        struct Item: Decodable, Equatable {
            var key: String; var value: Double; var unit: String
            init(key: String, value: Double, unit: String) { self.key = key; self.value = value; self.unit = unit }
            init(from decoder: Decoder) throws {
                var c = try decoder.unkeyedContainer()
                key = try c.decode(String.self); value = try c.decode(Double.self); unit = (try? c.decode(String.self)) ?? ""
            }
        }
        init(value: Int?, level: Double, grade: Int, main: String?, station: String?, at: String, yday: Yday?, items: [Item]) {
            self.value = value; self.level = level; self.grade = grade; self.main = main; self.station = station; self.at = at; self.yday = yday; self.items = items
        }
        enum CodingKeys: String, CodingKey { case value, level, grade, main, station, at, yday, items }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            value = (try? c.decodeIfPresent(Double.self, forKey: .value)).flatMap { $0 }.map { Int($0.rounded()) }
            level = max(0, min(3.99, (try? c.decode(Double.self, forKey: .level)) ?? 0))
            grade = max(0, min(3, (try? c.decode(Int.self, forKey: .grade)) ?? Int(level)))
            main = try? c.decodeIfPresent(String.self, forKey: .main)
            station = try? c.decodeIfPresent(String.self, forKey: .station)
            at = (try? c.decode(String.self, forKey: .at)) ?? ""
            yday = try? c.decodeIfPresent(Yday.self, forKey: .yday)
            items = ((try? c.decode([FailableDecodable<Item>].self, forKey: .items)) ?? []).compactMap(\.value)
        }
    }

    struct Me: Decodable, Equatable {
        var value: Int?                 // 통합대기환경지수 (Korea); nil elsewhere
        var level: Double
        var grade: Int
        enum CodingKeys: String, CodingKey { case value, level, grade }
        init(value: Int?, level: Double, grade: Int) { self.value = value; self.level = level; self.grade = grade }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            value = (try? c.decodeIfPresent(Double.self, forKey: .value)).flatMap { $0 }.map { Int($0.rounded()) }
            level = max(0, min(3.99, (try? c.decode(Double.self, forKey: .level)) ?? 0))
            grade = max(0, min(3, (try? c.decode(Int.self, forKey: .grade)) ?? Int(level)))
        }
    }

    /// [lat, lon, level, value|null]
    struct Point: Decodable, Equatable {
        var lat: Double, lon: Double, level: Double
        var value: Int?
        init(lat: Double, lon: Double, level: Double, value: Int?) { self.lat = lat; self.lon = lon; self.level = level; self.value = value }
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            lat = try c.decode(Double.self); lon = try c.decode(Double.self)
            level = max(0, min(3.99, try c.decode(Double.self)))
            value = c.isAtEnd ? nil : (try? c.decodeIfPresent(Double.self)).flatMap { $0 }.map { Int($0.rounded()) }
        }
    }

    enum CodingKeys: String, CodingKey { case kind, at, me, points, detail }
    init(kind: String, at: String, me: Me?, points: [Point], detail: Detail? = nil) { self.kind = kind; self.at = at; self.me = me; self.points = points; self.detail = detail }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = (try? c.decode(String.self, forKey: .kind)) ?? "cai"
        at = (try? c.decode(String.self, forKey: .at)) ?? ""
        me = try? c.decodeIfPresent(Me.self, forKey: .me)
        points = ((try? c.decode([FailableDecodable<Point>].self, forKey: .points)) ?? []).compactMap(\.value)
        detail = try? c.decodeIfPresent(Detail.self, forKey: .detail)
    }

    /// The example weather's map: a made-up, smooth field of stations around the place (a little worse to the
    /// north-west, as on a hazy day), so the card can be seen and captured without the server.
    static func sample(lat: Double, lon: Double, korea: Bool) -> AirMap {
        var pts: [Point] = []
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 33) / Double(1 << 31) }
        for _ in 0..<(korea ? 70 : 17) {
            let y = lat + (rnd() - 0.5) * 0.9, x = lon + (rnd() - 0.5) * 1.1
            let lv = max(0, min(3.99, 0.9 + (y - lat) * 1.6 - (x - lon) * 1.1 + (rnd() - 0.5) * 0.5))
            pts.append(Point(lat: y, lon: x, level: lv, value: korea ? Int(lv * 50 + 4) : nil))
        }
        let here = Point(lat: lat, lon: lon, level: korea ? 1.78 : 0.96, value: korea ? 89 : nil)
        let detail = korea
            ? Detail(value: 89, level: 1.78, grade: 1, main: "pm10", station: L("마포구"), at: "", yday: .init(value: 61, level: 1.22),
                     items: [.init(key: "pm10", value: 46, unit: "㎍/㎥"), .init(key: "pm25", value: 10, unit: "㎍/㎥"), .init(key: "o3", value: 38, unit: "ppb"),
                             .init(key: "no2", value: 11, unit: "ppb"), .init(key: "so2", value: 2, unit: "ppb"), .init(key: "co", value: 0.4, unit: "ppm")])
            : Detail(value: nil, level: 0.96, grade: 0, main: "pm25", station: nil, at: "", yday: .init(value: nil, level: 1.3),
                     items: [.init(key: "pm10", value: 18.2, unit: "㎍/㎥"), .init(key: "pm25", value: 9.1, unit: "㎍/㎥"), .init(key: "o3", value: 61.2, unit: "㎍/㎥"),
                             .init(key: "no2", value: 12.3, unit: "㎍/㎥"), .init(key: "so2", value: 1.1, unit: "㎍/㎥"), .init(key: "co", value: 230.4, unit: "㎍/㎥")])
        return AirMap(kind: korea ? "cai" : "pm", at: "", me: Me(value: here.value, level: here.level, grade: Int(here.level)), points: [here] + pts, detail: detail)
    }
}

/// One element of a list that is skipped when it cannot be read, instead of failing the whole list
struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}
