import Foundation

/// 이벤트: a character given to everyone who opens the app while the server's /v1/promo says an event is on (its id,
/// the character and when it ends). Taking it (the home banner's 받기) keeps it for good, with or without Plus
/// (AppModel.gifts); with iCloud에 보관 on it is also saved in the person's own iCloud, so a reinstall or a new phone
/// gets it back (CloudLog). No event, or no server: no banner.
@MainActor
final class Promo: ObservableObject {
    static let shared = Promo()

    struct Event: Equatable {
        var id: String
        var char: PurrCharacter
        /// the app's launch (the banner says 출시 기념)
        var launch = false
        /// the first moment after the event (the banner shows the day before it)
        var end: Date
        /// "12월 31일" in the app's language: the event's last day
        var lastDay: String {
            let f = DateFormatter(); f.locale = Lang.current.locale
            f.setLocalizedDateFormatFromTemplate("MMMd")
            return f.string(from: end.addingTimeInterval(-1))
        }
    }

    /// The event on now (nil: none, or the server could not be reached)
    @Published private(set) var event: Event?
    /// Banners closed with ×, by event id
    @Published private(set) var closed: Set<String>

    init() { closed = Set(SharedStore.defaults.stringArray(forKey: "promoClosed") ?? []) }

    /// Asks the server; at launch and on every return to the app
    func load() async {
        #if DEBUG
        // screenshots: -promo capy is an event ending in 30 days; otherwise none while testing
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "-promo"), i + 1 < a.count, let c = PurrCharacter(rawValue: a[i + 1]), c.isPlus {
            event = Event(id: "debug-\(c.rawValue)", char: c, launch: true, end: Calendar.current.date(byAdding: .day, value: 30, to: Calendar.current.startOfDay(for: Date())) ?? Date())
            closed = []
            return
        }
        if a.contains("-scene") || a.contains("-reset") { return }
        #endif
        guard let base = WeatherSource.serverURL else { return }
        var r = URLRequest(url: base.appendingPathComponent("v1/promo"))
        r.timeoutInterval = 5
        guard let (data, resp) = try? await URLSession.shared.data(for: r), (resp as? HTTPURLResponse)?.statusCode == 200 else { return }
        event = Self.decode(data)
    }

    /// The server's answer: {"active":true,"id":"capy-2026","char":"capy","kind":"launch","end":"2026-12-31T15:00:00.000Z"}
    /// or {"active":false}
    nonisolated static func decode(_ data: Data, now: Date = Date()) -> Event? {
        struct Answer: Decodable { var active: Bool; var id: String?; var char: String?; var kind: String?; var end: String? }
        guard let a = try? JSONDecoder().decode(Answer.self, from: data), a.active, let id = a.id, !id.isEmpty,
              let c = a.char.flatMap(PurrCharacter.init(rawValue:)), c.isPlus,
              let e = a.end.flatMap(date), e > now else { return nil }
        return Event(id: id, char: c, launch: a.kind == "launch", end: e)
    }

    nonisolated private static func date(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }

    /// The event the home banner shows: on now and not closed (before or after taking the gift)
    var banner: Event? { event.flatMap { closed.contains($0.id) ? nil : $0 } }

    func close(_ e: Event) {
        closed.insert(e.id)
        SharedStore.defaults.set(closed.sorted(), forKey: "promoClosed")
    }
}
