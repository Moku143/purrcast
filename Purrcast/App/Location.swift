import CoreLocation
import Foundation

/// "지금 위치": one when-in-use fix, turned into a Place with a Korean name (reverse geocoding on the phone).
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

    /// The current place, or nil when location is off / unavailable.
    func currentPlace() async -> Place? {
        guard allowed, let loc = await fix() else { return nil }
        let marks = try? await CLGeocoder().reverseGeocodeLocation(loc, preferredLocale: Locale(identifier: "ko_KR"))
        let m = marks?.first
        let city = m?.administrativeArea ?? m?.locality ?? ""
        let district = m?.subLocality ?? m?.locality ?? m?.subAdministrativeArea ?? ""
        var name = [Self.shortCity(city), district].filter { !$0.isEmpty }.joined(separator: " ")
        if name.isEmpty { name = "지금 위치" }
        let country = m?.isoCountryCode ?? ""
        return Place(id: "here", name: name, short: district.isEmpty ? (Self.shortCity(city).isEmpty ? "지금 위치" : Self.shortCity(city)) : district,
                     lat: loc.coordinate.latitude, lon: loc.coordinate.longitude,
                     region: country == "KR" ? "kr" : (country == "JP" ? "jp" : "other"),
                     timeZone: (m?.timeZone ?? TimeZone.current).identifier, sample: Place.here.sample)
    }

    /// "서울특별시" → "서울", "경기도" → "경기"
    nonisolated static func shortCity(_ s: String) -> String {
        for suffix in ["특별자치시", "특별자치도", "특별시", "광역시", "도"] where s.hasSuffix(suffix) && s.count > suffix.count {
            return String(s.dropLast(suffix.count))
        }
        return s
    }

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
