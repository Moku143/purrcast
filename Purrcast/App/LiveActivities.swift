import Foundation
import ActivityKit

/// The Plus rain alert's plumbing on the app's side: ActivityKit hands out a push-to-start token (iOS 17.2+), which
/// goes to the server with the place, plan and character (`POST /v1/devices`); the server's half-hourly pass then
/// pushes the alert about an hour before the rain — a Live Activity that shows on the Dynamic Island / lock screen
/// for a few minutes, with the banner — so the app need not be open. Without a server (the sample provider) nothing
/// is sent and the app's own scheduled notification stays.
@MainActor
final class LiveActivities {
    static let shared = LiveActivities()
    private var watching = false
    private var lastSent: String?          // the last registration body, so the same one is not sent again
    private var lastSentAt: Date?
    private var pushOK = false             // the server confirmed it can push (an APNs key is set)
    var session: URLSession = .shared

    /// True once the server has the push-to-start token and can push: the app then leaves the rain alert to the
    /// activity instead of scheduling its own notification.
    var active: Bool { pushOK && startToken != nil }

    static let deviceID: String = {
        let k = "device.id"
        if let v = UserDefaults.standard.string(forKey: k) { return v }
        let v = UUID().uuidString
        UserDefaults.standard.set(v, forKey: k)
        return v
    }()
    private(set) var startToken: String? {
        get { UserDefaults.standard.string(forKey: "la.start") }
        set { UserDefaults.standard.set(newValue, forKey: "la.start") }
    }

    /// Call once at launch: follow the tokens ActivityKit hands out and register each new one.
    func watch(_ model: AppModel) {
        guard !watching, WeatherSource.serverURL != nil else { return }
        watching = true
        if #available(iOS 17.2, *) {
            Task { [weak self, weak model] in
                for await data in Activity<RainActivityAttributes>.pushToStartTokenUpdates {
                    let hex = data.map { String(format: "%02x", $0) }.joined()
                    guard let self, let model else { return }
                    self.startToken = hex
                    await self.register(model, force: true)
                }
            }
        }
    }

    /// The device as the server should know it now. Sent when something changed (or an hour has passed).
    func register(_ model: AppModel, force: Bool = false) async {
        guard let base = WeatherSource.serverURL, !model.isSample, let start = startToken else { return }
        let p = model.currentPlace
        let body: [String: Any] = [
            "id": Self.deviceID, "lat": (p.lat * 100).rounded() / 100, "lon": (p.lon * 100).rounded() / 100, "tz": p.timeZone,
            "region": p.region, "lang": Lang.current.code, "name": p.short, "char": model.shownCharacter.rawValue,
            "plan": model.plus ? "plus" : "free", "start": start, "rain": model.notifyRain,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]) else { return }
        let key = String(decoding: data, as: UTF8.self)
        if !force, key == lastSent, let t = lastSentAt, Date().timeIntervalSince(t) < 3600 { return }
        var req = URLRequest(url: base.appendingPathComponent("v1/devices"))
        req.httpMethod = "POST"; req.httpBody = data
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        guard let (out, resp) = try? await session.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200 else { return }
        lastSent = key; lastSentAt = Date()
        if let j = try? JSONSerialization.jsonObject(with: out) as? [String: Any], let ok = j["push"] as? Bool {
            let was = pushOK
            pushOK = ok
            if ok != was { model.planNotifications() }
        }
    }
}
