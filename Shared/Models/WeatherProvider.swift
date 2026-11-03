import Foundation

/// Where the forecast comes from. The app only ever talks to this protocol.
///
/// - `ServerWeatherProvider`: our server (server/ in this repo), which merges 기상청 and MET Norway and answers with
///   the `WeatherScene` JSON (docs/server-api.md). On whenever `PurrcastServerURL` is set in Info.plist.
/// - `SampleWeatherProvider`: the example scenes from the design. Only while there is no server (development,
///   screenshots); the app then labels everything "예시 날씨" and plans no notifications.
protocol WeatherProvider {
    var name: String { get }
    var isSample: Bool { get }
    /// `fresh`: the person asked (pull to refresh) — skip the URL cache and ask the server itself
    func forecast(for place: Place, plus: Bool, previousLevel: Int?, fresh: Bool) async throws -> WeatherScene
    /// The 대기질 지도 (Plus): air quality around the place
    func airMap(for place: Place) async throws -> AirMap
    /// 날씨 기록's missing days (Plus): what each past day's weather was, "YYYY-MM-DD" … "YYYY-MM-DD"
    func history(for place: Place, from: String, to: String) async throws -> [DayRecord]
}

extension WeatherProvider {
    func forecast(for place: Place, plus: Bool, previousLevel: Int?) async throws -> WeatherScene {
        try await forecast(for: place, plus: plus, previousLevel: previousLevel, fresh: false)
    }
    /// Without the server: a made-up field around the place (the example weather)
    func airMap(for place: Place) async throws -> AirMap { AirMap.sample(lat: place.lat, lon: place.lon, korea: place.region == "kr") }
    /// Without the server: nothing to fill in (the example weather makes up its own days)
    func history(for place: Place, from: String, to: String) async throws -> [DayRecord] { [] }
}

extension SampleWeatherProvider {
    /// The example's map, its index made from the example's own 미세먼지 (so the card and the sheet agree with it)
    func airMap(for place: Place) async throws -> AirMap {
        let d = SceneLibrary.scene(sceneOverride ?? place.sample).dust
        return AirMap.sample(lat: place.lat, lon: place.lon, korea: place.region == "kr", pm10: d?.pm10, pm25: d?.pm25)
    }

}

enum WeatherSource {
    /// The server URL from Info.plist (`PurrcastServerURL`), empty until the server is deployed.
    static var serverURL: URL? {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "PurrcastServerURL") as? String,
              !s.trimmingCharacters(in: .whitespaces).isEmpty, s.hasPrefix("https://") else { return nil }
        return URL(string: s)
    }

    /// `sceneOverride` pins one example scene (UI tests); it only applies to the sample provider.
    static func make(sceneOverride: String? = nil) -> WeatherProvider {
        if sceneOverride == nil, let url = serverURL { return ServerWeatherProvider(baseURL: url) }
        return SampleWeatherProvider(sceneOverride: sceneOverride)
    }
}

/// Example weather from the design canvas (Shared/Data/scenes.json).
struct SampleWeatherProvider: WeatherProvider {
    var sceneOverride: String?
    var name: String { L("예시 날씨") }
    var isSample: Bool { true }

    func forecast(for place: Place, plus: Bool, previousLevel: Int?, fresh: Bool) async throws -> WeatherScene {
        var s = SceneLibrary.scene(sceneOverride ?? place.sample)
        s.place = place.name
        if !plus && place.region == "kr" { s.alert = nil }     // the server sends 기상특보 to Plus only (free: the 06:00 run)
        return s
    }
}

/// Our forecast server. GET {base}/v1/forecast?lat=..&lon=..&region=..&tz=..&plan=free|plus&lang=ko|en|ja&outfitPrev=..&name=..
/// → 200 with one `WeatherScene` as JSON. Coordinates are sent rounded to ~1 km.
struct ServerWeatherProvider: WeatherProvider {
    let baseURL: URL
    var session: URLSession = .shared
    /// Keep and use the phone's record of temperatures for 전일 대비 (off in tests)
    var history = true
    var name: String { L("기상청 · MET Norway") }
    var isSample: Bool { false }

    func forecast(for place: Place, plus: Bool, previousLevel: Int?, fresh: Bool) async throws -> WeatherScene {
        var c = URLComponents(url: baseURL.appendingPathComponent("v1/forecast"), resolvingAgainstBaseURL: false)!
        var q = [
            URLQueryItem(name: "lat", value: String(format: "%.2f", place.lat)),
            URLQueryItem(name: "lon", value: String(format: "%.2f", place.lon)),
            URLQueryItem(name: "region", value: place.region),
            URLQueryItem(name: "tz", value: place.timeZone),
            URLQueryItem(name: "plan", value: plus ? "plus" : "free"),
            URLQueryItem(name: "lang", value: Lang.current.code),
            URLQueryItem(name: "name", value: place.serverName),   // Korean for Korean places: 기상청 warnings go by it
            URLQueryItem(name: "v", value: "2"),   // knows the 'sleet' icon (older apps get 'snowflake' in its place)
        ]
        // the outfit shown last time (0…14) for the server's ±1° hysteresis ("prev" was the old ten-outfit number)
        if let p = previousLevel { q.append(URLQueryItem(name: "outfitPrev", value: String(p))) }
        c.queryItems = q
        var req = URLRequest(url: c.url!, timeoutInterval: 20)   // the server gives up on a slow source after ~5 s
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        // the server's answers are cacheable for ten minutes (Plus) — a pull to refresh means "now", not the cached one
        if fresh { req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData }
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
        var s = try JSONDecoder().decode(WeatherScene.self, from: data)
        guard !s.hours.isEmpty, !s.days.isEmpty else { throw URLError(.cannotParseResponse) }
        s.id = place.id
        if s.place == nil { s.place = place.name }
        // 전일 대비 from the phone's own record of yesterday (the server's figure when it has none)
        if history { TempHistory().apply(to: &s, lat: place.lat, lon: place.lon) }
        return s
    }
}

extension ServerWeatherProvider {
    /// GET {base}/v1/airmap?lat=..&lon=..&region=.. → the 대기질 지도 (docs/server-api.md)
    func airMap(for place: Place) async throws -> AirMap {
        var c = URLComponents(url: baseURL.appendingPathComponent("v1/airmap"), resolvingAgainstBaseURL: false)!
        c.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.2f", place.lat)),
            URLQueryItem(name: "lon", value: String(format: "%.2f", place.lon)),
            URLQueryItem(name: "region", value: place.region),
        ]
        var req = URLRequest(url: c.url!, timeoutInterval: 20)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
        let m = try JSONDecoder().decode(AirMap.self, from: data)
        guard !m.points.isEmpty else { throw URLError(.cannotParseResponse) }
        return m
    }

    /// GET {base}/v1/history?lat=..&lon=..&region=..&tz=..&from=..&to=.. → { days: [{date, hi, lo, icon, mm, wet}], src }
    /// (기상청 ASOS in Korea, Apple's daily history elsewhere), as observed days of 날씨 기록
    func history(for place: Place, from: String, to: String) async throws -> [DayRecord] {
        var c = URLComponents(url: baseURL.appendingPathComponent("v1/history"), resolvingAgainstBaseURL: false)!
        c.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.2f", place.lat)),
            URLQueryItem(name: "lon", value: String(format: "%.2f", place.lon)),
            URLQueryItem(name: "region", value: place.region),
            URLQueryItem(name: "tz", value: place.timeZone),
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to),
        ]
        var req = URLRequest(url: c.url!, timeoutInterval: 20)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
        struct Answer: Decodable {
            struct Day: Decodable {
                var date: String; var hi: Double; var lo: Double; var icon: String; var mm: Double?; var wet: String?
                var wetFrom: Int?; var wetTo: Int?; var rh: Double?; var windMax: Double?; var uv: Double?
            }
            var days: [Day]
        }
        return try JSONDecoder().decode(Answer.self, from: data).days.map {
            var r = DayRecord(date: $0.date, hi: Int($0.hi.rounded()), lo: Int($0.lo.rounded()), icon: $0.icon)
            r.mm = $0.mm ?? 0; r.wet = $0.wet; r.obs = true; r.place = place.short
            r.placeKo = place.region == "kr" ? place.ko.flatMap { $0.split(separator: " ").last.map(String.init) } : nil
            r.wetFrom = $0.wetFrom; r.wetTo = $0.wetTo
            r.rh = $0.rh.map { Int($0.rounded()) }; r.windMax = $0.windMax.map { Int($0.rounded()) }; r.uv = $0.uv.map { Int($0.rounded()) }
            return r
        }
    }
}
