import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// What the app hands to its widgets and the watch: the latest forecast, the character, the plan and the
/// display settings. Written by the app into the shared App Group; read by the widget timeline and the watch.
struct WeatherSnapshot: Codable {
    var scene: WeatherScene
    var character: PurrCharacter
    var plus: Bool
    var characterName: String
    var placeShort: String
    var saved: Date
    var place: Place? = nil
    var plusUntil: Date? = nil          // end of the paid period; widgets / watch drop Plus after it by themselves
    var unitF: Bool = false
    var clock12: Bool = false
    var isSample: Bool = false          // example weather (no server yet)
    var lang: String? = nil             // 설정 → 언어 on the phone ("" = the device's); the watch follows it
    var windUnit: String = "m/s"        // 설정 → 바람 단위: m/s · km/h · mph (the lock-screen wind circle)
    var stale: Bool = false             // aged past the forecast's end (set by aged(at:), never saved)

    init(scene: WeatherScene, character: PurrCharacter, plus: Bool, characterName: String, placeShort: String, saved: Date,
         place: Place? = nil, plusUntil: Date? = nil, unitF: Bool = false, clock12: Bool = false, isSample: Bool = false, lang: String? = nil,
         windUnit: String = "m/s") {
        self.scene = scene; self.character = character; self.plus = plus; self.characterName = characterName
        self.placeShort = placeShort; self.saved = saved; self.place = place; self.plusUntil = plusUntil
        self.unitF = unitF; self.clock12 = clock12; self.isSample = isSample; self.lang = lang; self.windUnit = windUnit
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        scene = try c.decode(WeatherScene.self, forKey: .scene)
        character = (try? c.decode(PurrCharacter.self, forKey: .character)) ?? .cat
        plus = (try? c.decode(Bool.self, forKey: .plus)) ?? false
        characterName = (try? c.decode(String.self, forKey: .characterName)) ?? ""
        placeShort = (try? c.decode(String.self, forKey: .placeShort)) ?? ""
        saved = (try? c.decode(Date.self, forKey: .saved)) ?? Date()
        place = try? c.decode(Place.self, forKey: .place)
        plusUntil = try? c.decode(Date.self, forKey: .plusUntil)
        unitF = (try? c.decode(Bool.self, forKey: .unitF)) ?? false
        clock12 = (try? c.decode(Bool.self, forKey: .clock12)) ?? false
        isSample = (try? c.decode(Bool.self, forKey: .isSample)) ?? false
        lang = try? c.decode(String.self, forKey: .lang)
        windUnit = (try? c.decode(String.self, forKey: .windUnit)) ?? "m/s"
        stale = (try? c.decode(Bool.self, forKey: .stale)) ?? false
    }

    /// Plus, unless the paid period has ended since the app last ran.
    var plusActive: Bool { plus && (plusUntil.map { $0 > Date() } ?? true) }
    /// Free plan always shows the cat.
    var shownCharacter: PurrCharacter { plusActive ? character : .cat }

    /// The placeholder before the app has handed over anything (`waiting`): none of its numbers are real
    var isWaiting: Bool { isSample && saved == .distantPast }
    /// Nothing real to show a number for: the first-data placeholder, or a forecast aged past its end
    var showsDashes: Bool { isWaiting || stale }
    func deg(_ v: Int) -> String { showsDashes ? "–" : "\(degNumber(v))°" }
    /// The number alone, for the rings that hang their own "°" ("–" on the placeholder)
    func degNumber(_ v: Int) -> String { showsDashes ? "–" : "\(unitF ? Int((Double(v) * 1.8 + 32).rounded()) : v)" }
    /// "4m/s" (or km/h · mph, as set in the app)
    func windText(_ ms: Int) -> String {
        if showsDashes { return "–" }
        switch windUnit {
        case "km/h": return "\(Int((Double(ms) * 3.6).rounded()))km/h"
        case "mph": return "\(Int((Double(ms) * 2.237).rounded()))mph"
        default: return "\(ms)m/s"
        }
    }
    /// "15시" → "오후 3시" when the 12-hour setting is on (and in the app's language)
    func hourLabel(_ l: String) -> String { HourLabel.display(l, clock12: clock12) }
    /// The day rows' names at drawing time: row `i` stands for today + `i` at the place, so its weekday follows
    /// the date actually shown (widgets age the list to now, the phone pushes the watch a fresh one on every
    /// forecast — a demo scene pinned on another weekday is the one case where the stored names would drift).
    func dayName(_ i: Int, at date: Date = Date()) -> String {
        let tz = place.flatMap { TimeZone(identifier: $0.timeZone) } ?? .current
        return DayName.row(i, at: date, tz: tz)
    }

    /// Shown before the app has handed over anything (a widget added before the first launch).
    static var waiting: WeatherSnapshot {
        var s = SceneLibrary.scene("clear")
        s.bubble = WeatherScene.Bubble(kind: "thought", tone: "white", icon: "question", text: "")
        s.cond = L("앱을 열어 주세요")
        s.hours = []; s.days = []; s.tiles = []        // no example forecast on a widget that has nothing yet
        s.rain = "none"; s.yday = 0; s.dust = nil       // nor the example's umbrella, its "vs yesterday" or its 미세먼지,
        s.feels = s.temp; s.hi = s.temp; s.lo = s.temp  // nor its "체감" or "큰 일교차" hints
        return WeatherSnapshot(scene: s, character: .cat, plus: false, characterName: PurrCharacter.cat.defaultName,
                               placeShort: Brand.name, saved: .distantPast, isSample: true)
    }

    /// Widget gallery previews.
    static var sample: WeatherSnapshot {
        var s = SceneLibrary.scene("maybe"); s.place = Place.here.name
        return WeatherSnapshot(scene: s, character: .cat, plus: false, characterName: PurrCharacter.cat.defaultName,
                               placeShort: Place.here.short, saved: Date(), isSample: true)
    }

    /// The snapshot as a widget should show it at `date`, without a refresh. Under an hour old, a sample, the
    /// placeholder or a forecast with no hourly rows: returned unchanged. Within the forecast: the hour that
    /// holds `date` becomes "지금" — its temperature, the rows from it on, the clock, and day or night from the
    /// sun — and past midnight the day list turns (hi · lo from the new first day; "어제보다" and the day's
    /// 미세먼지 dropped, they belonged to a day now gone). Past the last forecast hour: the waiting dashes and
    /// "앱을 열어 주세요" — numbers are never invented. The outfit and its prop stay as saved (the last real
    /// feels-like chose them), and the aged hour's feels is its temperature (the saved feels went with its hour).
    /// Pure: nothing is written back, so the app still sees how old the stored forecast really is.
    func aged(at date: Date = Date()) -> WeatherSnapshot {
        guard !isSample, !stale, scene.hours.count >= 2, let p = place, let tz = TimeZone(identifier: p.timeZone),
              date.timeIntervalSince(saved) >= 3600 else { return self }
        var out = self
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        var s = out.scene
        guard let i = s.hourIndex(at: date, tz: tz, now: saved) else {
            // the forecast has run out: no numbers at all, and the bubble asks for the app
            s.hours = []; s.days = []; s.tiles = []
            s.rain = "none"; s.yday = 0; s.dust = nil
            s.feels = s.temp; s.hi = s.temp; s.lo = s.temp
            s.bubble = WeatherScene.Bubble(kind: "thought", tone: "white", icon: "question", text: "")
            s.cond = L("앱을 열어 주세요")
            out.scene = s; out.stale = true
            return out
        }
        let row = s.hours[i]
        s.temp = row.temp; s.feels = row.temp
        s.hours = Array(s.hours[i...])
        s.hours[0].label = "지금"
        let c = cal.dateComponents([.hour, .minute], from: date)
        s.clock = String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
        if let sun = SunTimes.day(date, lat: p.lat, lon: p.lon, tz: tz) {
            s.time = date >= sun.rise && date < sun.set ? "day" : "night"
        }
        let turned = cal.dateComponents([.day], from: cal.startOfDay(for: saved), to: cal.startOfDay(for: date)).day ?? 0
        if turned > 0 {
            if turned < s.days.count {
                s.days = Array(s.days.dropFirst(turned))
                s.days[0].name = L("오늘")
                if s.days.count > 1 { s.days[1].name = L("내일") }
                s.hi = s.days[0].hi; s.lo = s.days[0].lo
            } else {
                s.days = []; s.hi = s.temp; s.lo = s.temp
            }
            s.yday = 0
            s.dust = nil
        }
        out.scene = s
        return out
    }

    /// The widget timeline from `now` on: this snapshot aged at each hour boundary of the place's clock until
    /// `until` (at most `cap` entries), plus one where the sun next rises or sets, so a widget whose refreshes
    /// are deferred or failing still follows the clock. A sample or placeholder gets its single entry.
    func timelineEntries(now: Date, until: Date, cap: Int = 24) -> [(date: Date, snap: WeatherSnapshot)] {
        guard !isSample, let p = place, let tz = TimeZone(identifier: p.timeZone) else { return [(now, self)] }
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        var out: [(date: Date, snap: WeatherSnapshot)] = [(now, aged(at: now))]
        var m = cal.dateComponents([.year, .month, .day, .hour], from: now)
        m.minute = 0; m.second = 0
        var t = (cal.date(from: m) ?? now).addingTimeInterval(3600)
        while t < until, out.count < cap {
            out.append((t, aged(at: t)))
            t = t.addingTimeInterval(3600)
        }
        if let sun = SunTimes.next(after: now, lat: p.lat, lon: p.lon, tz: tz), sun.at.addingTimeInterval(30) < until,
           !out.contains(where: { abs($0.date.timeIntervalSince(sun.at)) < 90 }) {
            out.append((sun.at.addingTimeInterval(30), aged(at: sun.at.addingTimeInterval(30))))
            out.sort { $0.date < $1.date }
        }
        return out
    }
}

enum SharedStore {
    #if os(watchOS)
    static let groupID = "group.app.purrcast.watch"   // watch app + complications (the phone reaches the watch over WatchConnectivity)
    #else
    static let groupID = "group.app.purrcast"         // phone app + widgets
    #endif
    static var defaults: UserDefaults { UserDefaults(suiteName: groupID) ?? .standard }
    private static let key = "snapshot.v1"

    /// `reload`: the app's saves have the widgets redraw; a widget saving its own refresh passes false (a reload from
    /// there asks every widget for a new timeline, each of which fetches and saves again — round and round)
    static func save(_ snap: WeatherSnapshot, reload: Bool = true) {
        guard let data = try? JSONEncoder().encode(snap) else { return }
        defaults.set(data, forKey: key)
        #if canImport(WidgetKit) && !os(watchOS)
        if reload { WidgetCenter.shared.reloadAllTimelines() }
        #endif
    }

    static func load() -> WeatherSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WeatherSnapshot.self, from: data)
    }

    /// A widget's own forecast for `place`, put onto what is saved now (read again just before saving): only the
    /// weather and its time change, so what the app saved while the widget waited (units, character, language, plan)
    /// stays. 지금 위치 also takes the spot the widget found it at (the weather is for there). nil when the app has
    /// gone to another place meanwhile, or nothing real is saved: the widget leaves it alone.
    static func withWidgetForecast(_ s: WeatherScene, for place: Place, onto now: WeatherSnapshot?, at date: Date = Date()) -> WeatherSnapshot? {
        guard var snap = now, !snap.isSample, let saved = snap.place, saved.id == place.id else { return nil }
        snap.scene = s
        snap.saved = date
        if place.id == "here" { snap.place = place; snap.placeShort = place.short }
        return snap
    }
}
