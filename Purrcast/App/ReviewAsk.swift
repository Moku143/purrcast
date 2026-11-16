import SwiftUI

/// Apple's own rating prompt (StoreKit's requestReview, App Review 5.6.1: the system prompt only, nothing given for a
/// rating, no prompt of our own). Asked at a calm moment: once the forecast has been seen on `needDays` different days,
/// a few seconds after today's weather shows on home with nothing else on screen; at most once per app version and
/// `gapDays` apart (iOS itself shows it at most three times a year, and may show nothing).
enum ReviewAsk {
    static var store: UserDefaults = .standard
    static let needDays = 3
    static let gapDays: Double = 60

    private static func dayKey(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
    static var appVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "" }

    /// Home showed a real forecast: today counts once
    static func sawWeather(now: Date = Date()) {
        let day = dayKey(now)
        guard store.string(forKey: "review.lastDay") != day else { return }
        store.set(day, forKey: "review.lastDay")
        store.set(store.integer(forKey: "review.days") + 1, forKey: "review.days")
    }

    /// Enough days of use, not yet asked in this version, and long enough since the last time
    static func due(now: Date = Date(), version: String = appVersion) -> Bool {
        guard store.integer(forKey: "review.days") >= needDays, store.string(forKey: "review.version") != version else { return false }
        if let t = store.object(forKey: "review.askedAt") as? Date, now.timeIntervalSince(t) < gapDays * 86_400 { return false }
        return true
    }

    static func asked(now: Date = Date(), version: String = appVersion) {
        store.set(version, forKey: "review.version")
        store.set(now, forKey: "review.askedAt")
    }

    /// Nothing over home: no sheet, no full-screen ad, no system alert
    @MainActor static var homeAlone: Bool {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }), let root = scene.keyWindow?.rootViewController else { return false }
        return root.presentedViewController == nil
    }
}
