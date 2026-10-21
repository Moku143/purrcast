import Foundation

/// Where the forecast comes from. The app only ever talks to this protocol.
///
/// - `SampleWeatherProvider` (now): the example scenes from the design, so every screen can be built and checked.
/// - `ServerWeatherProvider` (later): our own server, which merges MET Norway and 기상청 and answers with the
///   same JSON shape as `WeatherScene` (docs/server-api.md). Setting `PurrcastServerURL` in Info.plist switches over;
///   nothing else in the app changes.
protocol WeatherProvider {
    var name: String { get }
    func forecast(for place: Place, plus: Bool) async throws -> WeatherScene
}

enum WeatherSource {
    /// The server URL from Info.plist (`PurrcastServerURL`), empty until the server exists.
    static var serverURL: URL? {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "PurrcastServerURL") as? String,
              !s.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return URL(string: s)
    }

    /// `sceneOverride` pins one example scene (UI tests, the design review); it only applies to the sample provider.
    static func make(sceneOverride: String? = nil) -> WeatherProvider {
        if sceneOverride == nil, let url = serverURL { return ServerWeatherProvider(baseURL: url) }
        return SampleWeatherProvider(sceneOverride: sceneOverride)
    }
}

/// Example weather from the design canvas (Shared/Data/scenes.json).
struct SampleWeatherProvider: WeatherProvider {
    var sceneOverride: String?
    var name: String { "예시 날씨" }

    func forecast(for place: Place, plus: Bool) async throws -> WeatherScene {
        var s = SceneLibrary.scene(sceneOverride ?? place.sample)
        s.place = place.name
        return s
    }
}

/// Our forecast server. GET {base}/v1/forecast?lat=..&lon=..&region=..&tz=..&plan=free|plus&lang=ko
/// → 200 with one `WeatherScene` as JSON. See docs/server-api.md for every field.
struct ServerWeatherProvider: WeatherProvider {
    let baseURL: URL
    var session: URLSession = .shared
    var name: String { "Purrcast 서버" }

    func forecast(for place: Place, plus: Bool) async throws -> WeatherScene {
        var c = URLComponents(url: baseURL.appendingPathComponent("v1/forecast"), resolvingAgainstBaseURL: false)!
        c.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.4f", place.lat)),
            URLQueryItem(name: "lon", value: String(format: "%.4f", place.lon)),
            URLQueryItem(name: "region", value: place.region),
            URLQueryItem(name: "tz", value: place.timeZone),
            URLQueryItem(name: "plan", value: plus ? "plus" : "free"),
            URLQueryItem(name: "lang", value: "ko"),
        ]
        var req = URLRequest(url: c.url!, timeoutInterval: 15)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
        var s = try JSONDecoder().decode(WeatherScene.self, from: data)
        s.id = place.id
        if s.place == nil { s.place = place.name }
        return s
    }
}
