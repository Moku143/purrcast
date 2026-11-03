import CoreLocation
import Foundation

/// The widget's own look at where the phone is, for "지금 위치" (NSWidgetWantsLocation; only when the app's location
/// permission covers widgets): the phone's last fix when it is recent, else one request, given a few seconds.
@MainActor
final class WidgetLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var waiter: CheckedContinuation<CLLocation?, Never>?

    func fix() async -> CLLocation? {
        guard manager.isAuthorizedForWidgetUpdates else { return nil }
        if let l = manager.location, -l.timestamp.timeIntervalSinceNow < 15 * 60 { return l }
        return await withCheckedContinuation { c in
            waiter = c
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyKilometer
            manager.requestLocation()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                self.finish(self.manager.location)
            }
        }
    }

    /// "지금 위치" where the phone is now: the saved place when it has not gone far (its names stay as the app made them),
    /// else the new spot, named the way the app names it. nil when the widget may not look.
    static func here(from saved: Place) async -> Place? {
        let w = WidgetLocation()
        guard let loc = await w.fix() else { return nil }
        if DayLog.km(saved.lat, saved.lon, loc.coordinate.latitude, loc.coordinate.longitude) < 1.5 { return saved }
        return await HerePlace.make(loc) { l, locale in
            (try? await CLGeocoder().reverseGeocodeLocation(l, preferredLocale: locale))?.first
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let l = locations.last
        Task { @MainActor in self.finish(l) }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(self.manager.location) }
    }
    private func finish(_ l: CLLocation?) {
        let w = waiter; waiter = nil
        w?.resume(returning: l)
    }
}
