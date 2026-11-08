import Foundation
import ActivityKit

/// The Plus rain alert's plumbing on the app's side: ActivityKit hands out a push-to-start token (iOS 17.2+), which
/// goes to the server with the place, plan and character (`POST /v1/devices`); the server's half-hourly pass then
/// pushes the alert about an hour before the rain — a Live Activity that shows on the Dynamic Island / lock screen
/// for a few minutes, with the banner — so the app need not be open. Without a server (the sample provider) nothing
/// is sent and the app's own scheduled notification stays. Only Plus is registered: the server pushes nothing to the
/// free plan, so a free device has no record there.
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
    var active: Bool { pushOK && startToken != nil && ActivityAuthorizationInfo().areActivitiesEnabled }

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
    /// The server has no record of this device (forgotten after Plus ended, or never registered since)
    private var forgotten: Bool {
        get { UserDefaults.standard.bool(forKey: "la.forgotten") }
        set { UserDefaults.standard.set(newValue, forKey: "la.forgotten") }
    }

    /// What the server should hear about this device now: Plus is registered once ActivityKit has handed out a push
    /// token; without Plus there is nothing for it to send, so a device it may know (registered while Plus, or by an
    /// older build that registered free devices too) is forgotten once, and then nothing more is sent.
    enum Step: Equatable { case nothing, register, forget }
    nonisolated static func step(plus: Bool, hasToken: Bool, forgotten: Bool) -> Step {
        if plus { return hasToken ? .register : .nothing }
        return hasToken && !forgotten ? .forget : .nothing
    }

    /// The registration: the alert toggles travel with it, read from the phone each time, so forgetting the device
    /// loses none of them (they are there again the moment Plus is)
    nonisolated static func body(id: String, place p: Place, lang: String, character: PurrCharacter, start: String, rain: Bool, alert: Bool) -> [String: Any] {
        ["id": id, "lat": (p.lat * 100).rounded() / 100, "lon": (p.lon * 100).rounded() / 100, "tz": p.timeZone,
         "region": p.region, "lang": lang, "name": p.short, "char": character.rawValue,
         "plan": "plus", "start": start, "rain": rain, "alert": alert]
    }

    /// The last registration the server took (its JSON), kept so an activity's own token can follow it even when the
    /// system wakes the app in the background just for that token (no model yet)
    private var savedBody: Data? {
        get { UserDefaults.standard.data(forKey: "la.body") }
        set { UserDefaults.standard.set(newValue, forKey: "la.body") }
    }
    private var activitiesWatched = false

    /// Call from the app's init (it runs on a background launch too): each alert the server starts on this phone
    /// hands out its own push token, and that goes to the server, which then keeps the alert in step with the
    /// forecast (the rain's end moving, the amount) and takes it away when the rain is over.
    func watchActivities() {
        guard !activitiesWatched, WeatherSource.serverURL != nil else { return }
        activitiesWatched = true
        Task { [weak self] in
            for a in Activity<RainActivityAttributes>.activities { self?.follow(a) }
            for await a in Activity<RainActivityAttributes>.activityUpdates { self?.follow(a) }
        }
    }

    private func follow(_ a: Activity<RainActivityAttributes>) {
        Task { [weak self] in
            for await data in a.pushTokenUpdates {
                await self?.sendActivityToken(data.map { String(format: "%02x", $0) }.joined())
            }
        }
    }

    private func sendActivityToken(_ hex: String) async {
        guard let base = WeatherSource.serverURL, let saved = savedBody,
              var body = (try? JSONSerialization.jsonObject(with: saved)) as? [String: Any] else { return }
        body["act"] = hex
        guard let data = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]) else { return }
        var req = URLRequest(url: base.appendingPathComponent("v1/devices"))
        req.httpMethod = "POST"; req.httpBody = data
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        _ = try? await session.data(for: req)
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
        guard let base = WeatherSource.serverURL, !model.isSample else { return }
        switch Self.step(plus: model.plus, hasToken: startToken != nil, forgotten: forgotten) {
        case .nothing: return
        case .forget: await forget(base, model); return
        case .register: break
        }
        guard let start = startToken else { return }
        let body = Self.body(id: Self.deviceID, place: model.currentPlace, lang: Lang.current.code, character: model.shownCharacter,
                             start: start, rain: model.notifyRain, alert: model.notifyAlert)
        guard let data = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]) else { return }
        let key = String(decoding: data, as: UTF8.self)
        if !force, key == lastSent, let t = lastSentAt, Date().timeIntervalSince(t) < 3600 { return }
        var req = URLRequest(url: base.appendingPathComponent("v1/devices"))
        req.httpMethod = "POST"; req.httpBody = data
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        guard let (out, resp) = try? await session.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200 else { return }
        lastSent = key; lastSentAt = Date(); forgotten = false; savedBody = data
        if let j = try? JSONSerialization.jsonObject(with: out) as? [String: Any], let ok = j["push"] as? Bool {
            let was = pushOK
            pushOK = ok
            if ok != was { model.planNotifications() }
        }
    }

    /// DELETE /v1/devices?id= once Plus is over: the server stops sending, and the app plans its own rain alert again
    /// if Plus comes back before the server does (the toggles stay on the phone)
    private func forget(_ base: URL, _ model: AppModel) async {
        var c = URLComponents(url: base.appendingPathComponent("v1/devices"), resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "id", value: Self.deviceID)]
        guard let url = c.url else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        guard let (_, resp) = try? await session.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200 else { return }
        forgotten = true; lastSent = nil; lastSentAt = nil
        if pushOK { pushOK = false; model.planNotifications() }
    }
}
