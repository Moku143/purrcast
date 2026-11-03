import Foundation

/// "전일 대비" kept on the phone: every forecast the app or a widget fetches leaves its current temperature here
/// (App Group, about two days, per ~10 km cell), and the next one compares with this time yesterday.
/// The server's own figure (`WeatherScene.yday`, from its KV store) is used only when the phone has nothing
/// for yesterday at this time — the first day, or a day the phone never refreshed around this hour.
struct TempHistory {
    struct Reading: Codable, Equatable {
        var t: Int        // minutes since 1970
        var v: Double     // °C
    }

    var defaults: UserDefaults = SharedStore.defaults
    static let key = "tempHistory.v1"
    /// Readings closer together than this replace each other (a widget and the app refreshing a minute apart)
    static let spacing = 20
    /// Kept a little over two days: yesterday at this time plus the hours either side
    static let keep = 50 * 60
    /// Places kept (the most recently seen)
    static let maxCells = 24

    /// ~10 km: the "here" place moving around town still finds yesterday's readings
    static func cell(lat: Double, lon: Double) -> String { String(format: "%.1f,%.1f", lat, lon) }

    private func load() -> [String: [Reading]] {
        guard let d = defaults.data(forKey: Self.key), let m = try? JSONDecoder().decode([String: [Reading]].self, from: d) else { return [:] }
        return m
    }
    private func save(_ m: [String: [Reading]]) {
        if let d = try? JSONEncoder().encode(m) { defaults.set(d, forKey: Self.key) }
    }

    func record(_ temp: Double, lat: Double, lon: Double, at now: Date = Date()) {
        let t = Int(now.timeIntervalSince1970 / 60)
        var m = load()
        let c = Self.cell(lat: lat, lon: lon)
        var list = (m[c] ?? []).filter { t - $0.t < Self.keep && $0.t <= t }
        if let last = list.last, t - last.t < Self.spacing { list.removeLast() }
        list.append(Reading(t: t, v: temp))
        m[c] = list
        // drop the places not seen for longest, and any whose readings have all aged out
        m = m.filter { !$0.value.isEmpty && t - ($0.value.last?.t ?? 0) < Self.keep }
        if m.count > Self.maxCells {
            let keepKeys = m.sorted { ($0.value.last?.t ?? 0) > ($1.value.last?.t ?? 0) }.prefix(Self.maxCells).map(\.key)
            m = m.filter { keepKeys.contains($0.key) }
        }
        save(m)
    }

    /// The temperature at this place 24 hours before `now`: between two readings within 1½ hours either side of it,
    /// or one reading within half an hour of it; nil when the phone has nothing that close.
    func yesterday(lat: Double, lon: Double, at now: Date = Date()) -> Double? {
        let target = Int(now.timeIntervalSince1970 / 60) - 24 * 60
        let list = load()[Self.cell(lat: lat, lon: lon)] ?? []
        let before = list.last { $0.t <= target }
        let after = list.first { $0.t >= target }
        if let a = before, let b = after, target - a.t <= 90, b.t - target <= 90 {
            if b.t == a.t { return a.v }
            return a.v + (b.v - a.v) * Double(target - a.t) / Double(b.t - a.t)
        }
        if let a = before, target - a.t <= 30 { return a.v }
        if let b = after, b.t - target <= 30 { return b.v }
        return nil
    }

    /// Records the scene's temperature and gives the difference from yesterday at this time: the phone's own readings
    /// first, the server's figure otherwise.
    func apply(to s: inout WeatherScene, lat: Double, lon: Double, at now: Date = Date()) {
        let y = yesterday(lat: lat, lon: lon, at: now)
        record(Double(s.temp), lat: lat, lon: lon, at: now)
        if let y { s.yday = Int((Double(s.temp) - y).rounded()) }
    }
}
