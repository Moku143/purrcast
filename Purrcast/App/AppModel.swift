import SwiftUI
import UserNotifications

enum WindUnit: String, CaseIterable, Codable { case ms, kmh, mph
    var label: String { self == .ms ? "m/s" : (self == .kmh ? "km/h" : "mph") }
}

/// App-wide state: places and their forecasts, plan, character, names, units, settings.
/// Settings persist in the App Group defaults so the widgets see the same character and units.
@MainActor
final class AppModel: ObservableObject {
    // weather
    @Published private(set) var raw: WeatherScene
    @Published private(set) var hasData: Bool                 // false until a forecast for the current place arrived
    @Published var places: [Place] { didSet { persist() } }
    @Published var currentIndex = 0 { didSet { if currentIndex != oldValue { Task { await refresh(force: true) } } } }
    @Published private(set) var loading = false
    @Published private(set) var lastError: String?
    @Published private(set) var previews: [String: WeatherScene] = [:]   // for the places list
    @Published private(set) var hereIsLive = false            // "지금 위치" really is the phone's location
    let provider: WeatherProvider
    let location = LocationService()

    // plan · character
    @Published var plus: Bool { didSet {
        persist()
        // Plus over: back to a place the free plan has (extra places stay saved, locked until Plus comes back)
        if !plus, !placeOpen(currentIndex) { currentIndex = 0 }
        if plus != oldValue { publish(); planNotifications(); Task { await refresh(force: true) } }   // Plus over: the rain alert goes too
    } }
    @Published var plusUntil: Date? { didSet { publish() } }
    @Published var character: PurrCharacter { didSet { persist(); publish() } }
    @Published var names: [String: String] { didSet { persist(); publish() } }

    // settings
    @Published var unitF: Bool { didSet { persist(); publish() } }
    @Published var clock12: Bool { didSet { persist(); publish() } }
    @Published var wind: WindUnit { didSet { persist() } }
    @Published var pixelFont: Bool { didSet { FontPref.pixel = pixelFont; persist() } }
    @Published var useLocation: Bool { didSet { persist(); if useLocation { location.ask() }; Task { await refresh(force: true) } } }
    @Published var notifyRain: Bool { didSet { persist(); notificationsChanged(turnedOn: notifyRain && !oldValue) } }
    @Published var notifyMorning: Bool { didSet { persist(); notificationsChanged(turnedOn: notifyMorning && !oldValue) } }
    @Published var notifyChange: Bool { didSet { persist(); notificationsChanged(turnedOn: notifyChange && !oldValue) } }   // 어제와 기온 비교, 아침에
    /// 기상특보 알림 (설정 → 알림). Stored only: the server has to push warnings; Notifications.swift has no hook yet.
    // TODO: send the preference to the server (push) once 기상특보 push exists; until then warnings show in the bubble only.
    @Published var notifyAlert: Bool { didSet { persist(); notificationsChanged(turnedOn: notifyAlert && !oldValue) } }
    /// 가까운 비 알림 (Plus): 다음 6시간 (한국) · 다음 1시간 (분 단위). Stored only until Notifications.swift plans it.
    // TODO: plan a near-rain notification from `minutes` / `next6` in Notifications.plan.
    @Published var notifyNearRain: Bool { didSet { persist(); notificationsChanged(turnedOn: notifyNearRain && !oldValue) } }
    /// 말투: "" follows the character (고양이 존댓말 · 브리티시숏헤어 격식 · 아비시니안 반말), or a Voice rawValue chosen in 설정 (Plus)
    @Published var voiceChoice: String { didSet { persist(); notificationsChanged(turnedOn: false) } }
    @Published var morningTime: Date { didSet { persist(); planNotifications() } }
    /// 설정 → 언어: "" follows the device, or ko · en · ja. The whole app, the widgets, the watch and the server's words change.
    @Published var language: String { didSet { if language != oldValue { languageChanged() } } }
    @Published var onboarded: Bool { didSet { persist() } }

    /// UI tests / design review only (compiled out of release builds): a fixed example scene, Plus forced on.
    let pinnedScene: String?
    let debugPlus: Bool

    static let freeExtraPlaces = 1
    private var generation = 0
    private var lastRefresh: Date?
    private var lastLevel: [String: Int] = [:]

    init() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        #else
        let args: [String] = []
        #endif
        func arg(_ k: String) -> String? { args.firstIndex(of: k).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } }
        let pinned = arg("-scene"), forcePlus = args.contains("-plus")
        pinnedScene = pinned
        debugPlus = forcePlus
        let d = SharedStore.defaults
        let testing = pinned != nil || args.contains("-reset")
        if testing && !args.contains("-keepLanguage") { Lang.picked = nil }   // screenshots follow the simulator's language
        if let l = arg("-lang"), let lang = Lang(rawValue: l) { Lang.picked = lang }   // -lang en: screenshots in that language

        let prov = WeatherSource.make(sceneOverride: pinned)
        provider = prov

        var loadedPlaces = [Place.here]
        if !testing, let data = d.data(forKey: "places"), let p = try? JSONDecoder().decode([Place].self, from: data), !p.isEmpty {
            loadedPlaces = p
        }
        places = loadedPlaces

        // what to show before the first answer: the last forecast for this place (server mode), or the example
        if prov.isSample {
            raw = SceneLibrary.scene(pinned ?? loadedPlaces[0].sample)
            hasData = true
        } else if let last = SharedStore.load(), !last.isSample, last.place?.id == loadedPlaces[0].id {
            raw = last.scene
            hasData = true
        } else {
            raw = WeatherScene()
            hasData = false
        }

        plus = forcePlus || (!testing && d.bool(forKey: "plus"))
        plusUntil = nil
        character = arg("-char").flatMap(PurrCharacter.init(rawValue:)) ?? (testing ? .cat : PurrCharacter(rawValue: d.string(forKey: "character") ?? "") ?? .cat)
        names = testing ? [:] : (d.dictionary(forKey: "names") as? [String: String] ?? [:])
        unitF = !testing && d.bool(forKey: "unitF")
        // English reads hours as "3PM" unless the person chose otherwise; Korean and Japanese as "15시" / "15時"
        clock12 = testing ? false : (d.object(forKey: "clock12") as? Bool ?? (Lang.current == .en))
        wind = WindUnit(rawValue: d.string(forKey: "wind") ?? "") ?? .ms
        pixelFont = testing ? true : (d.object(forKey: "pixelFont") as? Bool ?? true)
        useLocation = testing ? false : (d.object(forKey: "useLocation") as? Bool ?? true)
        notifyRain = d.object(forKey: "notifyRain") as? Bool ?? true
        notifyMorning = d.object(forKey: "notifyMorning") as? Bool ?? true
        notifyChange = d.object(forKey: "notifyChange") as? Bool ?? true
        notifyAlert = d.object(forKey: "notifyAlert") as? Bool ?? true
        notifyNearRain = d.object(forKey: "notifyNearRain") as? Bool ?? true
        voiceChoice = d.string(forKey: "voiceChoice") ?? ""
        language = Lang.picked?.rawValue ?? ""
        morningTime = d.object(forKey: "morningTime") as? Date ?? Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
        onboarded = testing ? !args.contains("-onboarding") : d.bool(forKey: "onboarded")
        FontPref.pixel = pixelFont
    }

    // MARK: weather

    var currentPlace: Place { places[max(0, min(currentIndex, places.count - 1))] }
    var isSample: Bool { provider.isSample }

    /// Fetch the current place. Answers that arrive after a newer request (quick place switching) are dropped.
    /// Without `force` it only fetches when the data is old: Plus 10 minutes, free 1 hour, or a new day.
    func refresh(force: Bool = false) async {
        if !force, let t = lastRefresh, Date().timeIntervalSince(t) < (plus ? 600 : 3600),
           Calendar.current.isDate(t, inSameDayAs: Date()) { return }
        generation += 1
        let mine = generation
        loading = true
        defer { if mine == generation { loading = false } }

        await updateHere()
        let place = currentPlace
        // one quiet retry before saying anything: a dropped connection or a slow moment upstream usually passes
        for attempt in 0..<2 {
            do {
                let s = try await provider.forecast(for: place, plus: plus, previousLevel: lastLevel[place.id])
                guard mine == generation else { return }
                raw = s; hasData = true; lastError = nil; lastRefresh = Date()
                lastLevel[place.id] = s.level
                publish()
                return
            } catch {
                guard mine == generation else { return }
                // the request was called off (the app went to the background, a newer refresh): not a failure
                if Self.isCancel(error) { return }
                if attempt == 0 { try? await Task.sleep(nanoseconds: 1_500_000_000); guard mine == generation else { return }; continue }
                // said as a wait, not a failure; with data on screen, which time it is from
                lastError = hasData ? L("새 날씨를 불러오는 중이에요 · 지금은 %@ 날씨예요", shownTime) : L("날씨를 불러오는 데 시간이 걸리고 있어요. 잠시 후 아래로 당겨 주세요.")
            }
        }
    }

    /// When the weather on screen was fetched ("13:40"), or the forecast's own time when it came from the cache
    private var shownTime: String {
        guard let t = lastRefresh else { return raw.updated }
        let c = Calendar.current.dateComponents([.hour, .minute], from: t)
        return HourLabel.clock((c.hour ?? 0) * 60 + (c.minute ?? 0), clock12: clock12)
    }

    static func isCancel(_ e: Error) -> Bool {
        if e is CancellationError { return true }
        if let u = e as? URLError, u.code == .cancelled { return true }
        return false
    }

    /// Keep the "here" place on the phone's location (when allowed), else a fixed default city.
    private func updateHere() async {
        guard pinnedScene == nil, let i = places.firstIndex(where: { $0.id == "here" }) else { return }
        if useLocation, let p = await location.currentPlace() {
            if places[i] != p { places[i] = p }
            hereIsLive = true
        } else {
            hereIsLive = false
            if places[i] != Place.here { places[i] = Place.here }
        }
    }

    func refreshPreviews() async {
        for p in places {
            if let s = try? await provider.forecast(for: p, plus: plus, previousLevel: lastLevel[p.id]) { previews[p.id] = s }
        }
    }

    /// The forecast as this plan sees it: free gets no minute data and the 06:00 stored forecast.
    var scene: WeatherScene { Self.planView(raw, plus: plus) }

    static func planView(_ raw: WeatherScene, plus: Bool) -> WeatherScene {
        var s = raw
        if !plus && (s.minutes != nil || s.next6 != nil) {
            s.minutes = nil; s.next6 = nil; s.plus = false; s.updated = "06:00"
        } else if plus { s.plus = true }
        return s
    }

    // MARK: places

    var canAddPlace: Bool { plus || places.count < 1 + Self.freeExtraPlaces }
    /// The free plan opens the first places only ("here" and one more); the rest wait for Plus.
    func placeOpen(_ i: Int) -> Bool { plus || i < 1 + Self.freeExtraPlaces }
    func add(_ p: Place) { guard !places.contains(where: { $0.id == p.id }) else { return }; places.append(p) }
    func remove(at offsets: IndexSet) {
        let removable = IndexSet(offsets.filter { places[$0].id != "here" })
        guard !removable.isEmpty else { return }
        let currentID = currentPlace.id
        places.remove(atOffsets: removable)
        let newIndex = places.firstIndex { $0.id == currentID } ?? 0
        if newIndex != currentIndex { currentIndex = newIndex } else if !places.contains(where: { $0.id == currentID }) { Task { await refresh(force: true) } }
    }

    // MARK: character

    /// Free plan always shows the cat.
    var shownCharacter: PurrCharacter { plus ? character : .cat }
    /// The voice the character speaks in: the free plan is always 존댓말.
    var voice: Voice { (plus ? (Voice(rawValue: voiceChoice) ?? shownCharacter.defaultVoice) : .polite).effective }
    /// Weather text in the current voice (information unchanged, endings only).
    func say(_ text: String) -> String { voice.say(text) }
    func name(of c: PurrCharacter) -> String { names[c.rawValue] ?? c.defaultName }
    func rename(_ c: PurrCharacter, to n: String) {
        let t = n.trimmingCharacters(in: .whitespacesAndNewlines)
        names[c.rawValue] = t.isEmpty ? nil : String(t.prefix(8))
    }

    // MARK: formatting

    func deg(_ v: Int) -> String { "\(unitF ? Int((Double(v) * 1.8 + 32).rounded()) : v)°" }
    func delta(_ v: Int) -> String {
        let d = unitF ? Int((Double(abs(v)) * 1.8).rounded()) : abs(v)
        return v > 0 ? "+\(d)°" : (v < 0 ? "−\(d)°" : L("같음"))
    }
    func windText(_ ms: Int) -> String { windNumber(ms) + windUnit }
    func windNumber(_ ms: Int) -> String {
        switch wind {
        case .ms: return "\(ms)"
        case .kmh: return "\(Int((Double(ms) * 3.6).rounded()))"
        case .mph: return "\(Int((Double(ms) * 2.237).rounded()))"
        }
    }
    var windUnit: String { wind == .ms ? "m/s" : wind == .kmh ? "km/h" : "mph" }
    /// "15시" → "오후 3시" in 12-hour mode (in the app's language)
    func hourLabel(_ l: String) -> String { HourLabel.display(l, clock12: clock12) }

    // MARK: persistence · widgets · watch · notifications

    private func persist() {
        guard pinnedScene == nil else { return }
        let d = SharedStore.defaults
        if let data = try? JSONEncoder().encode(places) { d.set(data, forKey: "places") }
        d.set(plus && !debugPlus, forKey: "plus")
        d.set(character.rawValue, forKey: "character"); d.set(names, forKey: "names")
        d.set(unitF, forKey: "unitF"); d.set(clock12, forKey: "clock12"); d.set(wind.rawValue, forKey: "wind")
        d.set(pixelFont, forKey: "pixelFont"); d.set(useLocation, forKey: "useLocation")
        d.set(notifyRain, forKey: "notifyRain"); d.set(notifyMorning, forKey: "notifyMorning"); d.set(notifyChange, forKey: "notifyChange")
        d.set(notifyAlert, forKey: "notifyAlert"); d.set(notifyNearRain, forKey: "notifyNearRain"); d.set(morningTime, forKey: "morningTime"); d.set(voiceChoice, forKey: "voiceChoice")
        d.set(onboarded, forKey: "onboarded")
    }

    var snapshot: WeatherSnapshot {
        WeatherSnapshot(scene: scene, character: character, plus: plus, characterName: name(of: shownCharacter),
                        placeShort: currentPlace.short, saved: Date(), place: currentPlace, plusUntil: plusUntil,
                        unitF: unitF, clock12: clock12, isSample: isSample, lang: language)
    }

    /// A new language: saved place names follow it, the example scene too, and the forecast is asked for again
    /// (the server writes its sentences in the app's language). Widgets and the watch get the new snapshot.
    private func languageChanged() {
        Lang.picked = Lang(rawValue: language)
        places = places.map { renamed($0) }
        // places from the search index ("kr:" · "rg:") need the index: read it first when it is not loaded yet
        if !PlaceIndex.shared.isLoaded && places.contains(where: { PlaceIndex.handles($0.id) }) {
            Task {
                await PlaceIndex.shared.load()
                self.places = self.places.map { PlaceIndex.shared.renamed($0) ?? $0 }
                self.publish()
            }
        }
        if provider.isSample { raw = SceneLibrary.scene(pinnedScene ?? currentPlace.sample) }
        previews = [:]
        publish()
        Task { await refresh(force: true) }
    }

    /// A saved place named in the current language: "here" (when not live) and catalog places from their tables,
    /// index places ("kr:" · "rg:") from the search index. Apple Maps picks ("mk:") keep the name they were added with,
    /// except Korean ones, which read in katakana in Japanese and go back to their Korean name in Korean.
    private func renamed(_ p: Place) -> Place {
        if p.id == "here" && !hereIsLive { return Place.here }
        if let c = Place.catalog.first(where: { $0.id == p.id }) {
            var q = p; q.name = c.name; q.short = c.short; q.ko = c.ko; return q
        }
        if let q = PlaceIndex.shared.renamed(p) { return q }
        return Self.koreanNamed(p, Lang.current)
    }

    /// A Korean place outside the index and the catalog ("here" while live, Apple Maps picks): Japanese reads its Korean
    /// name in katakana, Korean gets the Korean name back, English keeps the name it has.
    nonisolated static func koreanNamed(_ p: Place, _ lang: Lang) -> Place {
        guard p.region == "kr" else { return p }
        var q = p
        if q.ko == nil, KoreanKana.hasHangul(p.name) { q.ko = p.name }
        guard let ko = q.ko else { return p }
        let koShort = ko.split(separator: " ").last.map(String.init) ?? ko
        switch lang {
        case .ja:
            let words = ko.split(separator: " ").map(String.init)
            let head = words.first.flatMap { KoreanKana.province($0) }
            q.name = ([head ?? KoreanKana.place(words.first ?? "")] + words.dropFirst().map { KoreanKana.place($0) })
                .filter { !$0.isEmpty }.joined(separator: " ")
            q.short = words.count == 1 ? (head ?? KoreanKana.place(koShort)) : KoreanKana.place(koShort)
        case .ko:
            q.name = ko
            q.short = koShort
        case .en:
            break
        }
        return q
    }

    /// Hand the current forecast to the widgets and the watch, and re-plan notifications from it.
    func publish() {
        guard hasData else { return }
        let snap = snapshot
        SharedStore.save(snap)
        WatchBridge.shared.send(snap)
        planNotifications()
        Task { await LiveActivities.shared.register(self) }   // the place, plan or character may have changed
    }

    func planNotifications() {
        guard pinnedScene == nil, hasData else { return }
        // example weather must never turn into a real-looking alert
        // free: the morning summary only (rain and the day-to-day change are Plus)
        // the rain alert comes as the Live Activity's own banner once the server can push it; else the app's own
        let rainHere = notifyRain && plus && !isSample && !LiveActivities.shared.active
        Task { await LiveActivities.shared.register(self) }   // the toggle travels with the device
        Notifications.plan(scene: scene, place: currentPlace, rain: rainHere, morning: notifyMorning && !isSample,
                           change: notifyChange && plus && !isSample, morningTime: morningTime, unitF: unitF, voice: voice, clock12: clock12,
                           character: shownCharacter, plus: plus)
    }

    /// A toggle went on: ask for permission if nobody asked yet, then plan.
    private func notificationsChanged(turnedOn: Bool) {
        guard turnedOn else { planNotifications(); return }
        UNUserNotificationCenter.current().getNotificationSettings { s in
            if s.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                    Task { @MainActor in self.planNotifications() }
                }
            } else {
                Task { @MainActor in self.planNotifications() }
            }
        }
    }
}
