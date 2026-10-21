import Foundation
import WatchConnectivity

/// Phone side of the watch link: sends the latest snapshot as the application context
/// (the watch always gets the newest one, even if it was asleep).
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ snap: WeatherSnapshot) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              WCSession.default.isPaired, WCSession.default.isWatchAppInstalled,
              let data = try? JSONEncoder().encode(snap) else { return }
        try? WCSession.default.updateApplicationContext(["snapshot": data])
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
}
