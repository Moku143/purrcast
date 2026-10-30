import Foundation
import UIKit

/// The Plus rain alert from the server: the app hands its APNs device token, place and plan to `POST /v1/devices`,
/// and the server's half-hourly pass pushes "6시쯤 비 예보 · 우산 챙기세요" about an hour before the rain — the app
/// need not be open for the forecast to be fresh. Without a server (the sample provider) nothing is sent, and the
/// app's own scheduled notification stays in place (AppModel.planNotifications).
@MainActor
final class RainPush {
    static let shared = RainPush()
    private weak var model: AppModel?
    private var lastSent: String?
    private var lastSentAt: Date?
    private var pushOK = false        // the server confirmed it can push (an APNs key is set)
    var session: URLSession = .shared

    /// True once the server has this device's token and can push: the rain alert comes from there.
    var active: Bool { pushOK && token != nil }

    static let deviceID: String = {
        let k = "device.id"
        if let v = UserDefaults.standard.string(forKey: k) { return v }
        let v = UUID().uuidString
        UserDefaults.standard.set(v, forKey: k)
        return v
    }()
    var token: String? {
        get { UserDefaults.standard.string(forKey: "push.token") }
        set { UserDefaults.standard.set(newValue, forKey: "push.token") }
    }

    /// At launch: ask APNs for the device token (PushDelegate gets it) and send what we already know.
    func start(_ model: AppModel) {
        self.model = model
        guard WeatherSource.serverURL != nil else { return }
        UIApplication.shared.registerForRemoteNotifications()
        Task { await register(model) }
    }

    func tokenArrived(_ data: Data) {
        let hex = data.map { String(format: "%02x", $0) }.joined()
        let changed = hex != token
        token = hex
        if let model { Task { await register(model, force: changed) } }
    }

    /// The device as the server should know it now; sent when something changed (or an hour has passed).
    func register(_ model: AppModel, force: Bool = false) async {
        guard let base = WeatherSource.serverURL, !model.isSample, let token else { return }
        let p = model.currentPlace
        let body: [String: Any] = [
            "id": Self.deviceID, "token": token, "lat": (p.lat * 100).rounded() / 100, "lon": (p.lon * 100).rounded() / 100, "tz": p.timeZone,
            "region": p.region, "lang": Lang.current.code, "name": p.short, "plan": model.plus ? "plus" : "free",
            "rain": model.notifyRain, "clock12": model.clock12,
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

/// Receives the APNs device token for RainPush.
final class PushDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in RainPush.shared.tokenArrived(deviceToken) }
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // no token (simulator, or no network): the app's own scheduled notification covers the rain
    }
}
