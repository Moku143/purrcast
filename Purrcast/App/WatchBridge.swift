import Foundation
import WatchConnectivity
import os

private let log = Logger(subsystem: "app.purrcast", category: "watch")

/// Phone side of the watch link: sends the latest snapshot as the application context (the watch always gets
/// the newest one, even if it was asleep). Keeps the last snapshot and resends it once the session is up and
/// whenever the watch app gets installed.
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()
    private var last: WeatherSnapshot?
    private let lock = NSLock()

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ snap: WeatherSnapshot) {
        lock.lock(); last = snap; lock.unlock()
        push()
    }

    private func push() {
        lock.lock(); let snap = last; lock.unlock()
        guard let snap, WCSession.isSupported() else { return }
        let s = WCSession.default
        guard s.activationState == .activated, s.isPaired, s.isWatchAppInstalled,
              let data = try? JSONEncoder().encode(snap) else {
            log.notice("not sent: activated \(s.activationState == .activated) paired \(s.isPaired) installed \(s.isWatchAppInstalled)")
            return
        }
        do {
            try s.updateApplicationContext(["snapshot": data])
            log.notice("sent \(data.count) bytes, plus \(snap.plusActive), \(snap.scene.cond, privacy: .public)")
        } catch {
            log.error("send failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        log.notice("phone session activated \(activationState.rawValue) paired \(session.isPaired) installed \(session.isWatchAppInstalled)")
        push()
    }
    func sessionWatchStateDidChange(_ session: WCSession) { push() }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
}
