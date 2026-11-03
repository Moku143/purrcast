import CoreLocation
import Foundation

/// "지금 위치": one when-in-use fix, turned into a Place with a name in the app's language (reverse geocoding on the phone).
/// Coordinates leave the phone only rounded to ~1 km (ServerWeatherProvider), as the privacy policy says.
@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var status: CLAuthorizationStatus
    private let manager = CLLocationManager()
    private var waiters: [CheckedContinuation<CLLocation?, Never>] = []

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var allowed: Bool { status == .authorizedWhenInUse || status == .authorizedAlways }
    var undecided: Bool { status == .notDetermined }

    func ask() { if undecided { manager.requestWhenInUseAuthorization() } }

    /// The current place, or nil when location is off / unavailable (named by HerePlace).
    func currentPlace() async -> Place? {
        guard allowed, let loc = await fix() else { return nil }
        return await HerePlace.make(loc) { l, locale in await self.mark(l, locale) }
    }

    /// Reverse geocoding, remembered per ~100 m and language so a refresh does not ask Apple again for the same spot.
    private var marks: [String: CLPlacemark] = [:]
    private func mark(_ loc: CLLocation, _ locale: Locale) async -> CLPlacemark? {
        let key = String(format: "%.3f,%.3f,%@", loc.coordinate.latitude, loc.coordinate.longitude, locale.identifier)
        if let m = marks[key] { return m }
        let m = (try? await CLGeocoder().reverseGeocodeLocation(loc, preferredLocale: locale))?.first
        if let m { if marks.count > 20 { marks = [:] }; marks[key] = m }
        return m
    }

    /// "서울특별시" → "서울", "경기도" → "경기"
    nonisolated static func shortCity(_ s: String) -> String { HerePlace.shortCity(s) }

    private func fix() async -> CLLocation? {
        if let l = manager.location, -l.timestamp.timeIntervalSinceNow < 600 { return l }
        return await withCheckedContinuation { c in
            waiters.append(c)
            if waiters.count == 1 { manager.requestLocation() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let l = locations.last
        Task { @MainActor in self.finish(l) }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        Task { @MainActor in self.status = s }
    }
    private func finish(_ l: CLLocation?) {
        let w = waiters; waiters = []
        w.forEach { $0.resume(returning: l) }
    }
}
