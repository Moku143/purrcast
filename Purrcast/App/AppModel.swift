import SwiftUI

enum WindUnit: String, CaseIterable, Codable { case ms, kmh, mph
    var label: String { self == .ms ? "m/s" : (self == .kmh ? "km/h" : "mph") }
}

/// App-wide state: places and their forecasts, plan, character, names, units, settings.
/// Settings persist in the App Group defaults so the widgets see the same character and units.
@MainActor
final class AppModel: ObservableObject {
    // weather
    @Published private(set) var raw: WeatherScene
    @Published var places: [Place] { didSet { persist() } }
    @Published var currentIndex = 0 { didSet { Task { await refresh() } } }
    @Published private(set) var loading = false
    @Published private(set) var lastError: String?
    @Published private(set) var previews: [String: WeatherScene] = [:]   // for the places list
    let provider: WeatherProvider

    // plan · character
    @Published var plus: Bool { didSet { persist(); publish() } }
    @Published var character: PurrCharacter { didSet { persist(); publish() } }
    @Published var names: [String: String] { didSet { persist(); publish() } }

    // settings
    @Published var unitF: Bool { didSet { persist() } }
    @Published var clock12: Bool { didSet { persist() } }
    @Published var wind: WindUnit { didSet { persist() } }
    @Published var pixelFont: Bool { didSet { FontPref.pixel = pixelFont; persist() } }
    @Published var useLocation: Bool { didSet { persist() } }
    @Published var notifyRain: Bool { didSet { persist() } }
    @Published var notifyMorning: Bool { didSet { persist() } }
    @Published var morningTime: Date { didSet { persist() } }
    @Published var notifyAlerts: Bool { didSet { persist() } }
    @Published var onboarded: Bool { didSet { persist() } }

    /// set by launch arguments (UI tests) so a test always sees the same weather
    let pinnedScene: String?
    /// Plus forced on by a launch argument (UI tests / design review), independent of StoreKit
    let debugPlus: Bool

    static let freeExtraPlaces = 1

    init() {
        let args = ProcessInfo.processInfo.arguments
        func arg(_ k: String) -> String? { args.firstIndex(of: k).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } }
        pinnedScene = arg("-scene")
        debugPlus = args.contains("-plus")
        let d = SharedStore.defaults
        let testing = pinnedScene != nil || args.contains("-reset")

        provider = WeatherSource.make(sceneOverride: pinnedScene)
        raw = SceneLibrary.scene(pinnedScene ?? Place.here.sample)

        if !testing, let data = d.data(forKey: "places"), let p = try? JSONDecoder().decode([Place].self, from: data), !p.isEmpty {
            places = p
        } else {
            places = [Place.here]
        }
        plus = debugPlus || (!testing && d.bool(forKey: "plus"))
        character = arg("-char").flatMap(PurrCharacter.init(rawValue:)) ?? (testing ? .cat : PurrCharacter(rawValue: d.string(forKey: "character") ?? "") ?? .cat)
        names = testing ? [:] : (d.dictionary(forKey: "names") as? [String: String] ?? [:])
        unitF = !testing && d.bool(forKey: "unitF")
        clock12 = !testing && d.bool(forKey: "clock12")
        wind = WindUnit(rawValue: d.string(forKey: "wind") ?? "") ?? .ms
        pixelFont = testing ? true : (d.object(forKey: "pixelFont") as? Bool ?? true)
        useLocation = testing ? true : (d.object(forKey: "useLocation") as? Bool ?? true)
        notifyRain = d.object(forKey: "notifyRain") as? Bool ?? true
        notifyMorning = d.object(forKey: "notifyMorning") as? Bool ?? true
        morningTime = d.object(forKey: "morningTime") as? Date ?? Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
        notifyAlerts = d.object(forKey: "notifyAlerts") as? Bool ?? true
        onboarded = testing ? !args.contains("-onboarding") : d.bool(forKey: "onboarded")
        FontPref.pixel = pixelFont
    }

    // MARK: weather

    var currentPlace: Place { places[min(currentIndex, places.count - 1)] }

    func refresh() async {
        loading = true; defer { loading = false }
        do {
            raw = try await provider.forecast(for: currentPlace, plus: plus)
            lastError = nil
            publish()
        } catch {
            lastError = "날씨를 못 받았어요. 잠시 뒤 다시 해 볼게요."
        }
    }

    func refreshPreviews() async {
        for p in places {
            if let s = try? await provider.forecast(for: p, plus: plus) { previews[p.id] = s }
        }
    }

    /// The forecast as this plan sees it: free gets no minute data and the 06:00 stored forecast.
    var scene: WeatherScene { Self.planView(raw, plus: plus) }

    static func planView(_ raw: WeatherScene, plus: Bool) -> WeatherScene {
        var s = raw
        if !plus && (s.minutes != nil || s.next6 != nil) {
            s.minutes = nil; s.next6 = nil; s.plus = false; s.updated = "06:00"
            if var b = s.bubble, b.icon.hasPrefix("umbrella") { b.text = hourWindow(s.hours) + " 비!"; s.bubble = b }
        } else if plus { s.plus = true }
        return s
    }

    /// "16~18시" from the hourly rows with rain
    static func hourWindow(_ hours: [WeatherScene.HourRow]) -> String {
        let r = hours.enumerated().filter { i, h in i > 0 && (h.mm > 0 || h.icon == "raincloud") }.map { $0.element.label.replacingOccurrences(of: "시", with: "") }
        guard let f = r.first, let l = r.last else { return "" }
        return r.count == 1 ? f + "시쯤" : f + "~" + l + "시"
    }

    // MARK: places

    var canAddPlace: Bool { plus || places.count < 1 + Self.freeExtraPlaces }
    func add(_ p: Place) { guard !places.contains(where: { $0.id == p.id }) else { return }; places.append(p) }
    func remove(at offsets: IndexSet) {
        let keep = offsets.filter { places[$0].id != "here" }
        places.remove(atOffsets: IndexSet(keep))
        if currentIndex >= places.count { currentIndex = 0 }
    }

    // MARK: character

    /// Free plan always shows the cat.
    var shownCharacter: PurrCharacter { plus ? character : .cat }
    func name(of c: PurrCharacter) -> String { names[c.rawValue] ?? c.defaultName }
    func rename(_ c: PurrCharacter, to n: String) {
        let t = n.trimmingCharacters(in: .whitespacesAndNewlines)
        names[c.rawValue] = t.isEmpty ? nil : String(t.prefix(8))
    }

    // MARK: formatting

    func deg(_ v: Int) -> String { "\(unitF ? Int((Double(v) * 1.8 + 32).rounded()) : v)°" }
    func delta(_ v: Int) -> String {
        let d = unitF ? Int((Double(abs(v)) * 1.8).rounded()) : abs(v)
        return v > 0 ? "+\(d)°" : (v < 0 ? "−\(d)°" : "같음")
    }
    func windText(_ ms: Int) -> String {
        switch wind {
        case .ms: return "\(ms)m/s"
        case .kmh: return "\(Int((Double(ms) * 3.6).rounded()))km/h"
        case .mph: return "\(Int((Double(ms) * 2.237).rounded()))mph"
        }
    }
    /// "15시" → "오후 3시" in 12-hour mode
    func hourLabel(_ l: String) -> String {
        guard clock12, l.hasSuffix("시"), let h = Int(l.dropLast()) else { return l }
        return (h < 12 ? "오전 " : "오후 ") + "\(h % 12 == 0 ? 12 : h % 12)시"
    }

    // MARK: persistence · widgets

    private func persist() {
        guard pinnedScene == nil else { return }
        let d = SharedStore.defaults
        if let data = try? JSONEncoder().encode(places) { d.set(data, forKey: "places") }
        d.set(plus && !debugPlus, forKey: "plus")
        d.set(character.rawValue, forKey: "character"); d.set(names, forKey: "names")
        d.set(unitF, forKey: "unitF"); d.set(clock12, forKey: "clock12"); d.set(wind.rawValue, forKey: "wind")
        d.set(pixelFont, forKey: "pixelFont"); d.set(useLocation, forKey: "useLocation")
        d.set(notifyRain, forKey: "notifyRain"); d.set(notifyMorning, forKey: "notifyMorning"); d.set(morningTime, forKey: "morningTime")
        d.set(notifyAlerts, forKey: "notifyAlerts"); d.set(onboarded, forKey: "onboarded")
    }

    /// Hand the current forecast to the widgets and the watch.
    func publish() {
        let snap = WeatherSnapshot(scene: scene, character: character, plus: plus, characterName: name(of: shownCharacter),
                                   placeShort: currentPlace.short, saved: Date())
        SharedStore.save(snap)
        WatchBridge.shared.send(snap)
        if pinnedScene == nil {
            Notifications.plan(scene: scene, place: currentPlace.short, rain: notifyRain, morning: notifyMorning,
                               morningTime: morningTime, unitF: unitF)
        }
    }
}
