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

    /// 통합대기환경지수 of one pollutant from its breakpoints (as the server does), index edges 0 · 50 · 100 · 250 · 500
    static func subIndex(_ key: String, _ v: Double?) -> Int? {
        let bp: [String: [Double]] = ["pm10": [0, 30, 80, 150, 600], "pm25": [0, 15, 35, 75, 500]]
        guard let v, let b = bp[key] else { return nil }
        let e: [Double] = [0, 50, 100, 250, 500]
        for i in 0..<4 where v <= b[i + 1] { return Int((e[i] + (v - b[i]) / (b[i + 1] - b[i]) * (e[i + 1] - e[i])).rounded()) }
        return 500
    }
    /// The step plus how far into it, 0–3.99, for an index
    static func level(_ cai: Int) -> Double {
        let e: [Double] = [0, 50, 100, 250, 500], v = Double(cai)
        for i in 0..<4 where v <= e[i + 1] { return min(3.99, Double(i) + (v - e[i]) / (e[i + 1] - e[i])) }
        return 3.99
    }

    /// The example weather's map: a made-up, smooth field of stations around the place (a little worse to the
    /// north-west, as on a hazy day), its middle the example's own 미세먼지, so the card can be seen without the server.
    static func sample(lat: Double, lon: Double, korea: Bool, pm10: Double? = nil, pm25: Double? = nil) -> AirMap {
        let p10 = pm10 ?? 46, p25 = pm25 ?? 10
        let s10 = subIndex("pm10", p10) ?? 0, s25 = subIndex("pm25", p25) ?? 0
        let cai = max(s10, s25), here = level(cai)
        var pts: [Point] = []
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 33) / Double(1 << 31) }
        for _ in 0..<(korea ? 70 : 17) {
            let y = lat + (rnd() - 0.5) * 0.9, x = lon + (rnd() - 0.5) * 1.1
            let lv = max(0, min(3.99, here + (y - lat) * 1.6 - (x - lon) * 1.1 + (rnd() - 0.5) * 0.5))
            pts.append(Point(lat: y, lon: x, level: lv, value: korea ? Int(lv * 50 + 4) : nil))
        }
        let yday = max(0, here - 0.5)
        let ugm = "㎍/㎥"
        let detail = korea
            ? Detail(value: cai, level: here, grade: Int(here), main: s10 >= s25 ? "pm10" : "pm25", station: L("마포구"), at: "", yday: .init(value: Int(yday * 50), level: yday),
                     items: [.init(key: "pm10", value: p10, unit: ugm), .init(key: "pm25", value: p25, unit: ugm), .init(key: "o3", value: 38, unit: "ppb"),
                             .init(key: "no2", value: 11, unit: "ppb"), .init(key: "so2", value: 2, unit: "ppb"), .init(key: "co", value: 0.4, unit: "ppm")])
            : Detail(value: nil, level: 0.96, grade: 0, main: "pm25", station: nil, at: "", yday: .init(value: nil, level: 1.3),
                     items: [.init(key: "pm10", value: 18.2, unit: ugm), .init(key: "pm25", value: 9.1, unit: ugm), .init(key: "o3", value: 61.2, unit: ugm),
                             .init(key: "no2", value: 12.3, unit: ugm), .init(key: "so2", value: 1.1, unit: ugm), .init(key: "co", value: 230.4, unit: ugm)])
        let me = korea ? Me(value: cai, level: here, grade: Int(here)) : Me(value: nil, level: 0.96, grade: 0)
        return AirMap(kind: korea ? "cai" : "pm", at: "", me: me, points: [Point(lat: lat, lon: lon, level: me.level, value: me.value)] + pts, detail: detail)
    }
}

/// One element of a list that is skipped when it cannot be read, instead of failing the whole list
struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}
