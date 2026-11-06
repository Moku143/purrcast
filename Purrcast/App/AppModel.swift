import SwiftUI
import Combine
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
    @Published var places: [Place] { didSet { persist(); if !isSample { dayLog.keepOnly(Set(places.map(\.id))) } } }
    @Published var currentIndex = 0 { didSet { if currentIndex != oldValue { Task { await refresh(force: true) } } } }
    @Published private(set) var loading = false
    @Published private(set) var lastError: String?
    private var debugNotice: String?
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
    @Published var wind: WindUnit { didSet { persist(); publish() } }
    /// The 대기질 지도 and its sheet (Plus), for the place on screen
    @Published var airMap: AirMap?
    @Published var airMapFailed = false     // no map for this place (no source there, or the server is unreachable): the card hides
    private var airMapKey = ""
    @Published var pixelFont: Bool { didSet { FontPref.pixel = pixelFont; persist() } }
    @Published var useLocation: Bool { didSet { persist(); if useLocation { location.ask() }; Task { await refresh(force: true) } } }
    @Published var notifyRain: Bool { didSet { persist(); notificationsChanged(turnedOn: notifyRain && !oldValue) } }
    @Published var notifyMorning: Bool { didSet { persist(); notificationsChanged(turnedOn: notifyMorning && !oldValue) } }
    @Published var notifyChange: Bool { didSet { persist(); notificationsChanged(turnedOn: notifyChange && !oldValue) } }   // 어제와 기온 비교, 아침에
    /// 기상특보 알림 (설정 → 알림). Stored only: the server has to push warnings; Notifications.swift has no hook yet.
    // TODO: send the preference to the server (push) once 기상특보 push exists; until then warnings show in the bubble only.
    @Published var notifyAlert: Bool { didSet { persist(); notificationsChanged(turnedOn: notifyAlert && !oldValue) } }
    @Published var notifyMonthly: Bool { didSet { persist(); notificationsChanged(turnedOn: notifyMonthly && !oldValue) } }   // 월간 리포트, 매달 1일
    /// The month the 날씨 달력 opens at once (a 월간 리포트 notification tapped); nil: this month
    var calendarMonth: String?
    /// The home cards' order as the person moved them (empty: the default, HomeLayout)
    @Published var homeOrder: [String] { didSet { persist() } }
    /// 말투: "" follows the character (고양이 존댓말 · 브리티시숏헤어 격식 · 아비시니안 반말), or a Voice rawValue chosen in 설정 (Plus)
    @Published var voiceChoice: String { didSet { persist(); notificationsChanged(turnedOn: false) } }
    @Published var morningTime: Date { didSet { persist(); planNotifications() } }
    /// 설정 → 언어: "" follows the device, or ko · en · ja. The whole app, the widgets, the watch and the server's words change.
    @Published var language: String { didSet { if language != oldValue { languageChanged() } } }
    @Published var onboarded: Bool { didSet { persist() } }

    /// UI tests / design review only (compiled out of release builds): a fixed example scene, Plus forced on.
    let pinnedScene: String?
    let debugPlus: Bool
    /// 날씨 기록 (the weekly card, the calendar): written on every real forecast; screenshots show made-up days
    let dayLog = DayLog()
    @Published private(set) var dayLogVersion = 0
    /// The app's one live model (the night refresh task reaches it here; tests make their own and leave it alone)
    static weak var shared: AppModel?

    static let freeExtraPlaces = 1
    private var generation = 0
    /// When the weather on screen was fetched (kept with the snapshot, so a launch offline knows how old it is)
    private var lastRefresh: Date? { didSet { SharedStore.defaults.set(lastRefresh, forKey: "lastRefresh") } }
    /// A location permission given later (the system prompt answered after the first refresh) refreshes at once
    private var locationWatch: AnyCancellable?
    private var lastLevel: [String: Int] = [:]

    /// `provider`: a stand-in weather source (unit tests); nil → the server, or the example weather without one
    init(provider injected: WeatherProvider? = nil) {
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

        let prov = injected ?? WeatherSource.make(sceneOverride: pinned)
        provider = prov

        var loadedPlaces = [Place.here]
        if !testing, let data = d.data(forKey: "places"), let p = try? JSONDecoder().decode([Place].self, from: data), !p.isEmpty {
            loadedPlaces = p
        }
        if let id = arg("-place"), let p = Place.catalog.first(where: { $0.id == id }) { loadedPlaces = [p] }   // screenshots abroad
        places = loadedPlaces

        // what to show before the first answer: the last forecast for this place (server mode), or the example
        if prov.isSample {
            raw = SceneLibrary.scene(pinned ?? loadedPlaces[0].sample)
            hasData = true
        } else if let last = SharedStore.load(), !last.isSample, last.place?.id == loadedPlaces[0].id {
            var s = last.scene
            s.id = loadedPlaces[0].id       // the id is not stored with the scene: this place's, as checked above
            raw = s
            hasData = true
            lastRefresh = d.object(forKey: "lastRefresh") as? Date
        } else {
            raw = WeatherScene()
            hasData = false
        }

        plus = forcePlus || (!testing && d.bool(forKey: "plus"))
        plusUntil = nil
        character = arg("-char").flatMap(PurrCharacter.init(rawValue:)) ?? (testing ? .cat : PurrCharacter(rawValue: d.string(forKey: "character") ?? "") ?? .cat)
        names = testing ? [:] : (d.dictionary(forKey: "names") as? [String: String] ?? [:])
        unitF = args.contains("-unitF") || (!testing && d.bool(forKey: "unitF"))
        // English reads hours as "3PM" unless the person chose otherwise; Korean and Japanese as "15시" / "15時"
        clock12 = testing ? args.contains("-clock12") : (d.object(forKey: "clock12") as? Bool ?? (Lang.current == .en))
        wind = arg("-wind").flatMap(WindUnit.init(rawValue:)) ?? (testing ? .ms : WindUnit(rawValue: d.string(forKey: "wind") ?? "") ?? .ms)
        debugNotice = arg("-notice")      // screenshots: stale · fail · loading (the notices the home screen can show)
        pixelFont = testing ? !args.contains("-plainFont") : (d.object(forKey: "pixelFont") as? Bool ?? true)   // screenshots: -plainFont for 일반 글씨
        useLocation = testing ? false : (d.object(forKey: "useLocation") as? Bool ?? true)
        notifyRain = d.object(forKey: "notifyRain") as? Bool ?? true
        notifyMorning = d.object(forKey: "notifyMorning") as? Bool ?? true
        notifyChange = d.object(forKey: "notifyChange") as? Bool ?? true
        notifyAlert = d.object(forKey: "notifyAlert") as? Bool ?? true
        notifyMonthly = d.object(forKey: "notifyMonthly") as? Bool ?? true
        homeOrder = testing ? (arg("-homeOrder").map { $0.split(separator: ",").map(String.init) } ?? []) : (d.stringArray(forKey: "homeOrder") ?? [])
        voiceChoice = d.string(forKey: "voiceChoice") ?? ""
        language = Lang.picked?.rawValue ?? ""
        morningTime = d.object(forKey: "morningTime") as? Date ?? Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
        onboarded = testing ? !args.contains("-onboarding") : d.bool(forKey: "onboarded")
        FontPref.pixel = pixelFont
        if !testing { for p in places { dayLog.dropFilled(p.id) } }   // days an older build filled in from the server
        locationWatch = location.$status.removeDuplicates().dropFirst().sink { [weak self] s in
            guard s == .authorizedWhenInUse || s == .authorizedAlways else { return }
            Task { await self?.refresh(force: true) }
        }
        if injected == nil { Self.shared = self }   // the app's one live model (after full initialization)
    }

    // MARK: weather

    var currentPlace: Place { places[max(0, min(currentIndex, places.count - 1))] }
    /// Whether the person's place is in Korea (the Plus page's words: 기상청's next six hours there, Apple's minutes
    /// elsewhere) — from the last forecast handed to the widgets, else the app's language
    static var hereIsKorea: Bool { SharedStore.load()?.place.map { $0.region == "kr" } ?? (Lang.current == .ko) }
    var isSample: Bool { provider.isSample }
    /// The weather held is the place on screen's (after a switch offline it can still be the last place's)
    private var weatherIsThisPlace: Bool { isSample || raw.id.isEmpty || raw.id == currentPlace.id }

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
        // the first refresh of a new day asks for a new forecast, not the one the phone cached last night
        let newDay = lastRefresh.map { !Calendar.current.isDate($0, inSameDayAs: Date()) } ?? false
        // one quiet retry before saying anything: a dropped connection or a slow moment upstream usually passes
        for attempt in 0..<2 {
            do {
                let s = try await provider.forecast(for: place, plus: plus, previousLevel: lastLevel[place.id], fresh: force || newDay)
                guard mine == generation else { return }
                raw = s; hasData = true; lastError = nil; lastRefresh = Date()
                lastLevel[place.id] = s.level
                if !provider.isSample {
                    dayLog.record(s, place: place, character: shownCharacter, plus: plus); dayLogVersion += 1
                }
                publish()
                #if DEBUG
                switch debugNotice {
                case "stale": lastError = L("새 날씨를 불러오는 중이에요 · 지금은 %@ 날씨예요", shownTime)
                case "fail": hasData = false; lastError = L("날씨를 불러오는 데 시간이 걸리고 있어요. 잠시 후 아래로 당겨 주세요.")
                case "loading": hasData = false
                default: break
                }
                #endif
                return
            } catch {
                guard mine == generation else { return }
                // the request was called off (the app went to the background, a newer refresh): not a failure
                if Self.isCancel(error) { return }
                if attempt == 0 { try? await Task.sleep(nanoseconds: 1_500_000_000); guard mine == generation else { return }; continue }
                // the place was switched (or deleted) offline: its own last forecast from the places list, else nothing
                // (its fetch time is unknown here, so the notice falls back to the forecast's own time)
                if !isSample, raw.id != place.id {
                    if let p = previews[place.id] { raw = p; hasData = true; lastRefresh = nil } else { hasData = false }
                }
                // said as a wait, not a failure; with data on screen, which time it is from
                lastError = hasData ? L("새 날씨를 불러오는 중이에요 · 지금은 %@ 날씨예요", shownTime) : L("날씨를 불러오는 데 시간이 걸리고 있어요. 잠시 후 아래로 당겨 주세요.")
            }
        }
    }

    /// When the weather on screen was fetched ("13:40"), or the forecast's own time when it came from the cache
    private var shownTime: String {
        guard let t = lastRefresh else { return raw.updated }
        return Self.fetchedLabel(t, clock12: clock12)
    }

    /// "13:40" today; "11월 1일 13:40" on another day (an old forecast must not pass for today's)
    static func fetchedLabel(_ t: Date, now: Date = Date(), clock12: Bool, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: t)
        let clock = HourLabel.clock((c.hour ?? 0) * 60 + (c.minute ?? 0), clock12: clock12)
        guard !calendar.isDate(t, inSameDayAs: now) else { return clock }
        return DayLogText.day(DayLog.dayKey(t, tz: calendar.timeZone)) + " " + clock
    }

    static func isCancel(_ e: Error) -> Bool {
        if e is CancellationError { return true }
        if let u = e as? URLError, u.code == .cancelled { return true }
        return false
    }

    /// Keep the "here" place on the phone's location (when allowed), else a fixed default city.
    private func updateHere() async {
        guard pinnedScene == nil, let i = places.firstIndex(where: { $0.id == "here" }) else { return }
        let allowed = useLocation && location.allowed
        let fix = allowed ? await location.currentPlace() : nil
        let next = Self.nextHere(previous: places[i], fix: fix, allowed: allowed)
        hereIsLive = allowed && (fix != nil || hereIsLive)
        if places[i] != next { places[i] = next }
    }

    /// "지금 위치" after asking for the phone's location. Location off → the default city. No fix this time (indoors,
    /// on the subway, timed out) → where it was last. A fix Apple could not name (offline) at the same spot → the
    /// last named place, so its region (기상청 in Korea) and names stay.
    static func nextHere(previous: Place, fix: Place?, allowed: Bool) -> Place {
        guard allowed else { return Place.here }
        guard let f = fix else { return previous }
        let unnamed = L("지금 위치")
        if f.name == unnamed, previous.name != unnamed,
           DayLog.km(previous.lat, previous.lon, f.lat, f.lon) <= DayLog.moveKm { return previous }
        return f
    }

    func refreshPreviews() async {
        for p in places {
            if let s = try? await provider.forecast(for: p, plus: plus, previousLevel: lastLevel[p.id]) {
                previews[p.id] = s
                if !provider.isSample { dayLog.record(s, place: p, character: shownCharacter, plus: plus) }
            }
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

    /// The place's 날씨 기록, oldest first (example weather: made-up days so the card and the calendar have something)
    func days(for place: Place) -> [DayRecord] {
        _ = dayLogVersion
        #if DEBUG
        if isSample { return DayLog.sample(for: place, scene: raw) }
        #endif
        return dayLog.records(place.id)
    }
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
    /// The 날씨 달력's days: the days the phone recorded while Plus was on (nothing filled in from before)
    func calendarDays(for place: Place) -> [DayRecord] {
        days(for: place).filter { $0.plus != false && ($0.obs != true || $0.seenHi != nil) }
    }
    /// The 날씨 달력's one timeline: where the user actually was. The "here" log holds only real locations (the
    /// app's refresh writes the place on screen into that place's own file, and a saved place's preview goes into
    /// its file too — looking at 도쿄 never marks a day as spent there). Someone who keeps location off has no
    /// "here" days, so their first saved place stands in.
    func timelineDays() -> [DayRecord] {
        #if DEBUG
        if isSample { return days(for: Place.here) }
        #endif
        _ = dayLogVersion
        return Self.timeline(from: dayLog, places: places)
    }
    /// The timeline from what the log holds: the "here" days, else the first saved place's (location kept off)
    nonisolated static func timeline(from log: DayLog, places: [Place]) -> [DayRecord] {
        let keep: (DayRecord) -> Bool = { $0.plus != false && ($0.obs != true || $0.seenHi != nil) }
        let here = log.records("here").filter(keep)
        if !here.isEmpty { return here }
        guard let p = places.first(where: { $0.id != "here" }) else { return [] }
        return log.records(p.id).filter(keep)
    }

    /// Fetch the 대기질 지도 for the place on screen, again when the forecast was refreshed (the readings are hourly)
    func loadAirMap() async {
        let place = currentPlace, key = "\(place.id)|\(scene.updated)|\(scene.clock)"
        guard key != airMapKey else { return }
        if !airMapKey.hasPrefix(place.id + "|") { airMap = nil }
        airMapKey = key
        do {
            let m = try await provider.airMap(for: place)
            if currentPlace.id == place.id { airMap = m; airMapFailed = false }
            // 날씨 기록: the day's 대기질 (its highest index)
            if !isSample, let d = m.detail { dayLog.recordAir(value: d.value, grade: d.grade, main: d.main, kind: m.kind, place: place); dayLogVersion += 1 }
        } catch {
            airMapKey = ""                                          // asked again next time
            // called off (the card's task restarted, the app went away): not a failure, the card stays
            if !Self.isCancel(error), airMap == nil { airMapFailed = true }
        }
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
        d.set(notifyAlert, forKey: "notifyAlert"); d.set(notifyMonthly, forKey: "notifyMonthly"); d.set(homeOrder, forKey: "homeOrder"); d.set(morningTime, forKey: "morningTime"); d.set(voiceChoice, forKey: "voiceChoice")
        d.set(onboarded, forKey: "onboarded")
    }

    var snapshot: WeatherSnapshot {
        WeatherSnapshot(scene: scene, character: character, plus: plus, characterName: name(of: shownCharacter),
                        placeShort: currentPlace.short, saved: Date(), place: currentPlace, plusUntil: plusUntil,
                        unitF: unitF, clock12: clock12, isSample: isSample, lang: Lang.current.rawValue,   // the language the app shows (the watch shows the same)
                        windUnit: windUnit)
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
    nonisolated static func koreanNamed(_ p: Place, _ lang: Lang) -> Place { HerePlace.koreanNamed(p, lang) }

    /// Hand the current forecast to the widgets and the watch, and re-plan notifications from it.
    func publish() {
        guard hasData, weatherIsThisPlace else { return }
        let snap = snapshot
        SharedStore.save(snap)
        WatchBridge.shared.send(snap)
        planNotifications()
        Task { await LiveActivities.shared.register(self) }   // the place, plan or character may have changed
    }

    func planNotifications() {
        guard pinnedScene == nil, hasData, weatherIsThisPlace else { return }
        // example weather must never turn into a real-looking alert
        // free: the morning summary only (rain and the day-to-day change are Plus)
        // the rain alert comes as the Live Activity's own banner once the server can push it; else the app's own
        let rainHere = notifyRain && plus && !isSample && !LiveActivities.shared.active
        Task { await LiveActivities.shared.register(self) }   // the toggle travels with the device
        // the 월간 리포트: Plus, for a month that has days recorded
        var monthly: Notifications.MonthlyFire?
        if notifyMonthly && plus && !isSample, let f = Notifications.monthlyFire(after: Date(), morning: morningTime),
           timelineDays().contains(where: { $0.date.hasPrefix(f.month + "-") }) { monthly = f }
        Notifications.plan(scene: scene, place: currentPlace, rain: rainHere, morning: notifyMorning && !isSample,
                           change: notifyChange && plus && !isSample, morningTime: morningTime, unitF: unitF, voice: voice, clock12: clock12,
                           character: shownCharacter, plus: plus, monthly: monthly)
    }

    /// A toggle went on: ask for permission if nobody asked yet, then plan.
    private func notificationsChanged(turnedOn: Bool) {
        Task { await LiveActivities.shared.register(self) }   // the server's short alerts follow the toggles
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
