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
    func forecast(for place: Place, plus: Bool, previousLevel: Int?) async throws -> WeatherScene
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

    func forecast(for place: Place, plus: Bool, previousLevel: Int?) async throws -> WeatherScene {
        var s = SceneLibrary.scene(sceneOverride ?? place.sample)
        s.place = place.name
        return s
    }
}

/// Our forecast server. GET {base}/v1/forecast?lat=..&lon=..&region=..&tz=..&plan=free|plus&lang=ko|en|ja&prev=..&name=..
/// → 200 with one `WeatherScene` as JSON. Coordinates are sent rounded to ~1 km.
struct ServerWeatherProvider: WeatherProvider {
    let baseURL: URL
    var session: URLSession = .shared
    var name: String { L("기상청 · MET Norway") }
    var isSample: Bool { false }

    func forecast(for place: Place, plus: Bool, previousLevel: Int?) async throws -> WeatherScene {
        var c = URLComponents(url: baseURL.appendingPathComponent("v1/forecast"), resolvingAgainstBaseURL: false)!
        var q = [
            URLQueryItem(name: "lat", value: String(format: "%.2f", place.lat)),
            URLQueryItem(name: "lon", value: String(format: "%.2f", place.lon)),
            URLQueryItem(name: "region", value: place.region),
            URLQueryItem(name: "tz", value: place.timeZone),
            URLQueryItem(name: "plan", value: plus ? "plus" : "free"),
            URLQueryItem(name: "lang", value: Lang.current.code),
            URLQueryItem(name: "name", value: place.serverName),   // Korean for Korean places: 기상청 warnings go by it
        ]
        if let p = previousLevel { q.append(URLQueryItem(name: "prev", value: String(p))) }
        c.queryItems = q
        var req = URLRequest(url: c.url!, timeoutInterval: 15)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
        var s = try JSONDecoder().decode(WeatherScene.self, from: data)
        guard !s.hours.isEmpty, !s.days.isEmpty else { throw URLError(.cannotParseResponse) }
        s.id = place.id
        if s.place == nil { s.place = place.name }
        return s
    }
}
