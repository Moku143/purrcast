import Foundation
import BackgroundTasks

/// A best-effort refresh a little before midnight, so the 날씨 기록 closes with where the phone is then. iOS
/// decides whether the task really runs (there is no promise of a run at any time, and none is claimed in the
/// UI — the day sheet shows when the place was really last confirmed). Uses the app's ordinary refresh with the
/// location permission it already has ("While Using" gives no new fix in the background: the last known place is
/// what a run records, which is the honest best effort). No user-facing permission is involved.
enum NightRefresh {
    static let id = "app.purrcast.ios.refresh"

    /// Launch-time registration (BGTaskScheduler requires it before the launch ends)
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: nil) { task in
            let done = { task.setTaskCompleted(success: true) }
            task.expirationHandler = done
            Task { @MainActor in
                if let model = AppModel.shared { await model.refresh(force: true) }
                schedule()          // the next night
                done()
            }
        }
    }

    /// Asks for a run at the next 23:50 of the device's clock (a widget's own 23:55 refresh stays in place either way)
    static func schedule() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        guard let at = cal.nextDate(after: Date(), matching: DateComponents(hour: 23, minute: 50), matchingPolicy: .nextTime) else { return }
        let req = BGAppRefreshTaskRequest(identifier: id)
        req.earliestBeginDate = at
        try? BGTaskScheduler.shared.submit(req)
    }
}
