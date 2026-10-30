import XCTest
import UIKit
@testable import Purrcast

/// Logic checks that run on every GitHub build: decoding (including what the real server sends), the design's
/// rules, the free / Plus view, notifications timing, the widget snapshot.
@MainActor
final class PurrcastTests: XCTestCase {

    /// The assertions below are the Korean wording; the test host may run on an English simulator.
    override func setUp() {
        super.setUp()
        Lang.current = .ko
    }
    override func tearDown() {
        Lang.current = .ko
        super.tearDown()
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    // MARK: decoding

    func testServerScenesDecode() throws {
        let all = try JSONDecoder().decode([String: WeatherScene].self, from: fixture("server-scenes"))
        let plus = try XCTUnwrap(all["plus"]), free = try XCTUnwrap(all["free"])
        XCTAssertEqual(plus.hours.count, 13)
        XCTAssertEqual(plus.days.count, 10)
        XCTAssertEqual(plus.next6?.count, 6)
        XCTAssertEqual(plus.nextSource, "met")
        XCTAssertEqual(plus.dayDetail?.first?.count, 11, "today from 13 h: one row per forecast hour")
        XCTAssertEqual(plus.dayDetail?[1].count, 24)
        XCTAssertEqual(plus.dayDetail?.first?[3].label, "16시"); XCTAssertEqual(plus.dayDetail?.first?[3].mm, 1.4, "each hour its own rain")
        XCTAssertEqual(plus.dayDetail?.first?[3].gust, 7); XCTAssertEqual(plus.dayDetail?.first?[3].dir, 225)
        XCTAssertEqual(plus.dayDetail?.first?.map { Int($0.chance) }.max(), plus.days.first?.chance, "the sheet's highest chance is the day's")
        XCTAssertEqual(plus.bubble?.text, "16~18시 비 예보")
        XCTAssertEqual(AppModel.planView(plus, plus: false).bubble?.text, "16~18시 비 예보", "the free plan keeps the window from the morning run")
        XCTAssertNil(free.next6)
        XCTAssertEqual(free.updated, "06:00")
    }

    func testEveryExampleSceneDecodes() {
        XCTAssertEqual(SceneLibrary.all.count, SceneLibrary.order.count)
        for k in SceneLibrary.order {
            let s = SceneLibrary.scene(k)
            XCTAssertEqual(s.id, k)
            XCTAssertFalse(s.hours.isEmpty, k); XCTAssertFalse(s.days.isEmpty, k)
            XCTAssert((0...Rules.maxLevel).contains(s.level), k)
            XCTAssertEqual(s.level, Rules.level(feels: Double(s.feels)), "\(k): the example's outfit fits its feels-like")
        }
    }

    func testLenientDecodingRepairsBadValues() throws {
        let json = #"""
        {"temp": 18.6, "hi": 12, "lo": 20, "outfit": 22, "clock": "1346",
         "wind": {"speed": 3.4, "gust": 1, "deg": -12},
         "hours": [["지금", "cloud", 18, 10, 0], ["bad"], ["15시", "rain", 17.5, null, 1.25]],
         "days": [["오늘", "sun", 0, 20, 12]],
         "tiles": [{"icon": "raindrop", "label": "습도"}],
         "bubble": {"text": "비!"}}
        """#
        let s = try JSONDecoder().decode(WeatherScene.self, from: Data(json.utf8))
        XCTAssertEqual(s.temp, 19)
        XCTAssertEqual(s.level, 14, "an outfit past the last one is the last one")
        XCTAssertLessThanOrEqual(s.lo, s.hi)
        XCTAssertEqual(s.clock, "12:00", "a clock without ':' is replaced")
        XCTAssertEqual(s.wind.deg, 348)
        XCTAssertEqual(s.wind.gust, s.wind.speed)
        XCTAssertEqual(s.hours.count, 2, "the malformed row is skipped")
        XCTAssertEqual(s.hours[1].chance, 0)
        XCTAssertEqual(s.days[0].lo, 12); XCTAssertEqual(s.days[0].hi, 20)
        XCTAssertEqual(s.tiles.first?.note, "")
        XCTAssertEqual(s.bubble?.kind, "speech")
        XCTAssertEqual(s.time, "day"); XCTAssertEqual(s.precip, "none")
    }

    /// Day-sheet rows: older answers have 6 values, newer ones add mm · gust · direction; both decode and round-trip.
    func testDayDetailRowsOldAndNew() throws {
        let json = #"[["0시", 9.5, 10, 2.1, 0, 82], ["3시", 9, 60, 3, 0, 90, 1.4, 6.2, 370], ["6시", 8, 70, 3, 0, 90, null, 5, 200]]"#
        let rows = try JSONDecoder().decode([WeatherScene.DayHour].self, from: Data(json.utf8))
        XCTAssertNil(rows[0].mm); XCTAssertNil(rows[0].gust); XCTAssertNil(rows[0].dir)
        XCTAssertEqual(rows[1].mm, 1.4); XCTAssertEqual(rows[1].gust, 6.2); XCTAssertEqual(rows[1].dir, 10, "370° is 10°")
        XCTAssertNil(rows[2].mm); XCTAssertEqual(rows[2].gust, 5); XCTAssertEqual(rows[2].dir, 200)
        let again = try JSONDecoder().decode([WeatherScene.DayHour].self, from: JSONEncoder().encode(rows))
        XCTAssertNil(again[0].dir); XCTAssertEqual(again[1].mm, 1.4); XCTAssertEqual(again[2].dir, 200); XCTAssertEqual(again[0].rh, 82)
    }

    func testClockParsing() {
        XCTAssertEqual(WeatherScene.clockMinutes("13:46"), 826)
        XCTAssertNil(WeatherScene.clockMinutes("1346"))
        XCTAssertNil(WeatherScene.clockMinutes("25:00"))
        XCTAssertNil(WeatherScene.clockMinutes(""))
    }

    // MARK: rules (must match server/src/rules.js)

    func testOutfitLevels() {
        // fifteen outfits: 35+ · 33–34 · 28–32 · 23–27 · 20–22 · 18–19 · 16–17 · 12–15 · 9–11 · 6–8 · 3–5 · 0–2 · −4…−1 · −9…−5 · −10−
        let at: [(Double, Int)] = [(36, 0), (35, 0), (34, 1), (33, 1), (32, 2), (28, 2), (27, 3), (23, 3), (22, 4), (20, 4),
                                   (19, 5), (18, 5), (17, 6), (16, 6), (15, 7), (12, 7), (11, 8), (9, 8), (8, 9), (6, 9),
                                   (5, 10), (3, 10), (2, 11), (0, 11), (-1, 12), (-4, 12), (-5, 13), (-9, 13), (-10, 14), (-20, 14)]
        for (c, lv) in at { XCTAssertEqual(Rules.level(feels: c), lv, "\(c)°") }
        XCTAssertEqual(Rules.level(feels: 11.9, previous: 8), 8)
        XCTAssertEqual(Rules.level(feels: 12.6, previous: 8), 7)
        XCTAssertEqual(Rules.levelUpper.count, Rules.levels)
        XCTAssertEqual(Rules.background.count, Rules.levels)
        XCTAssertEqual(Rules.clamp(-3), 0); XCTAssertEqual(Rules.clamp(99), Rules.maxLevel)
    }

    /// Every character has every outfit in every state, and an anchor for each.
    func testFifteenOutfitsPerCharacter() {
        for c in PurrCharacter.allCases {
            XCTAssertEqual(c.anchors.head_top.count, Rules.levels, c.rawValue)
            XCTAssertEqual(c.anchors.umb_top.count, Rules.levels, c.rawValue)
            XCTAssertEqual(c.anchors.head_cx.count, Rules.levels, c.rawValue)
        }
    }

    /// A server from the ten-outfit days sends only "level": the outfit comes from the feels-like temperature instead.
    func testOldServerLevelIsReadFromFeels() throws {
        let s = try JSONDecoder().decode(WeatherScene.self, from: Data(#"{"level": 8, "temp": -3, "feels": -6}"#.utf8))
        XCTAssertEqual(s.level, 13)
        let t = try JSONDecoder().decode(WeatherScene.self, from: Data(#"{"level": 9}"#.utf8))
        XCTAssertEqual(t.level, 14, "no temperature at all: the old number is translated (old 9 = −10° and below)")
        let again = try JSONDecoder().decode(WeatherScene.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(again.level, 13, "the outfit round-trips")
    }

    /// Every notification picture can be drawn: each character, each outfit, each umbrella state, each sky.
    /// A few are kept as attachments (notify-*) to look at.
    func testNotificationPictures() {
        for c in PurrCharacter.allCases {
            for lv in 0..<Rules.levels {
                for r in [RainState.none, .bag, .umbrella] {
                    let img = NotificationArt.render(c, level: lv, rain: r, sky: .rain, falling: r == .umbrella)
                    XCTAssertEqual(img?.size, CGSize(width: 600, height: 600), "\(c) \(lv) \(r)")
                }
            }
        }
        for sky in NotificationArt.Sky.allCases { XCTAssertNotNil(UIImage(named: "notify-bg-\(sky.rawValue)"), sky.rawValue) }
        let keep: [(PurrCharacter, Int, RainState, NotificationArt.Sky, Bool)] = [
            (.cat, 7, .bag, .rain, false), (.cat, 7, .umbrella, .rain, true), (.cat, 1, .none, .clear, false),
            (.abys, 12, .umbrella, .snow, true), (.abys, 5, .none, .partly, false), (.brit, 9, .bag, .cloudy, false),
            (.brit, 4, .umbrella, .storm, true), (.cat, 14, .bag, .snow, false)]
        for (c, lv, r, sky, f) in keep {
            guard let png = NotificationArt.render(c, level: lv, rain: r, sky: sky, falling: f)?.pngData() else { XCTFail(); continue }
            let a = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
            a.name = "notify-\(c.rawValue)-\(lv)-\(r.rawValue)-\(sky.rawValue)"; a.lifetime = .keepAlways
            add(a)
        }
        XCTAssertEqual(NotificationArt.sky(icon: "partly_cloudy"), .partly)
        XCTAssertEqual(NotificationArt.sky(icon: "snowflake"), .snow)
        XCTAssertEqual(NotificationArt.sky(icon: "sleet"), .snow)
        XCTAssertEqual(NotificationArt.wetSky(icon: "sleet"), .snow)
        XCTAssertEqual(NotificationArt.dayLevel(lo: 9, hi: 19), Rules.level(feels: 14))
    }

    /// The home-screen icon names: the sun faces follow the character, the app's own icon is the cat on sky blue.
    func testAppIconNames() {
        XCTAssertEqual(AppIcon.choice(of: nil), "sun-blue")
        XCTAssertEqual(AppIcon.choice(of: "AppIcon-sun-blue-abys"), "sun-blue")
        XCTAssertEqual(AppIcon.choice(of: "AppIcon-sun-peach-cat"), "sun-peach")
        XCTAssertEqual(AppIcon.choice(of: "AppIcon-rain-cat"), "rain-cat")
        XCTAssertEqual(AppIcon.choice(of: "AppIcon-partly"), "partly")
        let blue = AppIcon.sun[0], peach = AppIcon.sun[1]
        XCTAssertNil(blue.iconName(.cat))
        XCTAssertEqual(blue.iconName(.abys), "AppIcon-sun-blue-abys")
        XCTAssertEqual(peach.iconName(.cat), "AppIcon-sun-peach-cat")
        XCTAssertEqual(AppIcon.weather[0].iconName(.brit), "AppIcon-partly")
        for c in AppIcon.sun + AppIcon.weather + AppIcon.characters {
            for ch in PurrCharacter.allCases { XCTAssertNotNil(UIImage(named: c.preview(ch)), c.preview(ch)) }
        }
    }

    func testFreePlanHidesPlusData() {
        let raw = SceneLibrary.scene("seoul_soon")
        XCTAssertNotNil(raw.next6)
        let free = AppModel.planView(raw, plus: false)
        XCTAssertNil(free.next6); XCTAssertNil(free.minutes)
        XCTAssertEqual(free.updated, "06:00")
        XCTAssertFalse(free.bubble?.text.contains(":") ?? false, "free never says a minute-exact time")
        XCTAssertNotNil(AppModel.planView(raw, plus: true).next6)
    }

    // MARK: notifications

    func testFirstRainUsesThePlacesTimeZone() throws {
        var s = WeatherScene()
        s.hours = try JSONDecoder().decode([WeatherScene.HourRow].self, from: Data(#"[["지금","cloud",18,10,0],["16시","raincloud",17,70,2]]"#.utf8))
        let tokyo = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tokyo
        let now = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 13, minute: 0)))
        let (fire, hour) = try XCTUnwrap(Notifications.firstRain(s, tz: tokyo, now: now))
        XCTAssertEqual(hour, 16)
        XCTAssertEqual(fire.timeIntervalSince(now), 3 * 3600, accuracy: 1)
    }

    /// The morning notification's hour is found across midnight (the next day's 7시, not today's).
    func testHourRowForTheMorningNotification() throws {
        var s = WeatherScene()
        s.hours = try JSONDecoder().decode([WeatherScene.HourRow].self, from: Data(#"""
            [["지금","cloud",18,10,0],["22시","cloud",17,10,0],["23시","raincloud",16,70,1],["0시","raincloud",15,80,2],
             ["1시","cloud",15,20,0],["2시","cloud",15,10,0],["3시","cloud",14,10,0],["4시","cloud",14,10,0],["5시","cloud",14,10,0],
             ["6시","cloud",14,20,0],["7시","raincloud",14,80,1.5],["8시","cloud",15,30,0]]
            """#.utf8))
        let seoul = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        var cal = Calendar(identifier: .gregorian); cal.timeZone = seoul
        let now = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 21, minute: 10)))
        let at = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 7, minute: 30)))
        let row = try XCTUnwrap(Notifications.hourRow(s, at: at, tz: seoul, now: now))
        XCTAssertEqual(row.label, "7시"); XCTAssertEqual(row.mm, 1.5)
        XCTAssertNil(Notifications.hourRow(s, at: at.addingTimeInterval(86400), tz: seoul, now: now), "beyond the forecast")
        XCTAssertEqual(NotificationArt.wetSky(icon: "cloud"), .rain)
    }

    // MARK: widgets / watch snapshot

    func testSnapshotDropsPlusAfterItEnds() {
        var snap = WeatherSnapshot.sample
        snap.plus = true; snap.character = .brit
        snap.plusUntil = Date().addingTimeInterval(3600)
        XCTAssertTrue(snap.plusActive); XCTAssertEqual(snap.shownCharacter, .brit)
        snap.plusUntil = Date().addingTimeInterval(-60)
        XCTAssertFalse(snap.plusActive); XCTAssertEqual(snap.shownCharacter, .cat)
    }

    func testSnapshotUnitsAndRoundTrip() throws {
        var snap = WeatherSnapshot.sample
        snap.unitF = true; snap.clock12 = true; snap.place = Place.catalog[0]
        XCTAssertEqual(snap.deg(20), "68°")
        XCTAssertEqual(snap.hourLabel("15시"), "오후 3시")
        let back = try JSONDecoder().decode(WeatherSnapshot.self, from: JSONEncoder().encode(snap))
        XCTAssertEqual(back.place?.id, Place.catalog[0].id)
        XCTAssertTrue(back.unitF)
        // an older snapshot without the new fields still decodes
        let old = #"{"scene":{"temp":5},"character":"abys","plus":true,"characterName":"아비","placeShort":"종로구","saved":0}"#
        let o = try JSONDecoder().decode(WeatherSnapshot.self, from: Data(old.utf8))
        XCTAssertEqual(o.scene.temp, 5); XCTAssertNil(o.plusUntil); XCTAssertFalse(o.unitF)
    }

    // MARK: sky layer and places

    func testSkyComposition() {
        XCTAssertFalse(Sky.data.isEmpty)
        let storm = Sky.compose(time: "day", cover: "overcast", precip: "rain", thunder: true, aux: ["none"])
        XCTAssertTrue(storm.items.contains { $0.a == "flash" })
        let clearNight = Sky.compose(time: "night", cover: "clear", precip: "none", thunder: false, aux: ["none"])
        XCTAssertTrue(clearNight.items.contains { $0.a == "twinkle" }, "stars on a clear night")
        let rainyNight = Sky.compose(time: "night", cover: "overcast", precip: "rain", thunder: false, aux: ["none"])
        XCTAssertFalse(rainyNight.items.contains { $0.a == "twinkle" }, "no stars when it rains")
        // more cloud, more clouds, reaching further down; dark ones before rain; fog as thick as it is
        let n = [10, 25, 40, 55, 70, 85, 100].map { Sky.cloudItems(pct: $0, night: false, gloom: 0, wet: false).count }
        XCTAssertEqual(n, n.sorted()); XCTAssertEqual(n.first, 0)
        let low = { (p: Int) in Sky.cloudItems(pct: p, night: false, gloom: 0, wet: false).map { $0.y }.max() ?? 0 }
        XCTAssertLessThan(low(25), low(100))
        let fair = Sky.cloudItems(pct: 50, night: false, gloom: 0, wet: false), gloomy = Sky.cloudItems(pct: 50, night: false, gloom: 2, wet: false)
        XCTAssertNotEqual(fair.map { $0.c }, gloomy.map { $0.c })
        let fogs = (1...3).map { f in Sky.compose(time: "day", cover: "partly", precip: "none", thunder: false, aux: [], fog: f).items.filter { $0.t == "img" }.count }
        XCTAssertEqual(fogs, fogs.sorted()); XCTAssertLessThan(fogs[0], fogs[2])
    }

    func testPlaceCatalogIDsAreUnique() {
        let ids = Place.catalog.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertFalse(ids.contains("here"))
        for p in Place.catalog { XCTAssertNotNil(TimeZone(identifier: p.timeZone), p.id) }
    }

    func testShortCityNames() {
        XCTAssertEqual(LocationService.shortCity("서울특별시"), "서울")
        XCTAssertEqual(LocationService.shortCity("부산광역시"), "부산")
        XCTAssertEqual(LocationService.shortCity("경기도"), "경기")
        XCTAssertEqual(LocationService.shortCity("제주특별자치도"), "제주")
    }

    func testChangeNotificationWords() {
        XCTAssertEqual(Notifications.changeTitle(place: "마포구", todayHi: 15, yesterdayHi: 19, unitF: false), "마포구 · 어제보다 4° 낮아요")
        XCTAssertEqual(Notifications.changeTitle(place: "마포구", todayHi: 20, yesterdayHi: 19, unitF: false), "마포구 · 어제와 비슷해요")
        XCTAssertEqual(Notifications.changeTitle(place: "NYC", todayHi: 25, yesterdayHi: 20, unitF: true), "NYC · 어제보다 9° 높아요")
        let d = WeatherScene.DayRow(name: "금", icon: "raincloud", chance: 70, lo: 9, hi: 19)
        XCTAssertEqual(Notifications.changeBody(d, deg: { "\($0)°" }), "오늘 9° ~ 19° · 일교차가 커요 · 비 예보")
        XCTAssertEqual(Notifications.morningBody(d), "비 예보예요 · 우산 챙기세요")
        XCTAssertEqual(Notifications.morningBody(WeatherScene.DayRow(name: "금", icon: "raincloud", chance: 40, lo: 9, hi: 19)), "강수확률 40% · 우산 챙기세요")
        XCTAssertEqual(Notifications.morningBody(WeatherScene.DayRow(name: "금", icon: "snowflake", chance: 80, lo: -3, hi: 1)), "눈 예보예요 · 미끄러우니 조심하세요")
        XCTAssertEqual(Notifications.morningBody(WeatherScene.DayRow(name: "금", icon: "sleet", chance: 80, lo: -1, hi: 3)), "진눈깨비 예보예요 · 미끄러우니 조심하세요")
    }

    /// Widgets and the watch show words with the temperature between them; official names stay as they are.
    func testCompactWords() {
        var s = WeatherScene(); s.temp = 16; s.feels = 15; s.hi = 18; s.lo = 11; s.cond = "비"; s.rain = "umbrella"
        s.bubble = WeatherScene.Bubble(kind: "speech", tone: "sky", icon: "umbrella", text: "비!")
        XCTAssertEqual(Compact.line(s, deg: { "\($0)°" }), "비 · 16° · 우산")
        s.bubble?.text = "호우주의보"
        XCTAssertEqual(Compact.head(s), "호우주의보")
        s.bubble?.text = "15~17시 비 예보"; s.rain = "bag"
        XCTAssertEqual(Compact.line(s, deg: { "\($0)°" }), "15~17시 비 · 16° · 우산")
        s.bubble?.text = "15~17시 비 예정"      // an older server
        XCTAssertEqual(Compact.line(s, deg: { "\($0)°" }), "15~17시 비 · 16° · 우산")
        s.bubble?.text = "안개가 짙어요!"; s.rain = "none"
        XCTAssertEqual(Compact.head(s), "짙은 안개")
        s.bubble?.text = "안개가 옅어요"
        XCTAssertEqual(Compact.head(s), "옅은 안개")
        s.bubble?.text = "한파!"; s.rain = "none"; s.temp = -13; s.feels = -16; s.cond = "맑음 · 한파"
        XCTAssertEqual(Compact.line(s, deg: { "\($0)°" }), "한파 · -13° · 체감 -16°")
        s.bubble = nil; s.temp = 19; s.feels = 18; s.hi = 20; s.lo = 9; s.cond = "맑음"
        XCTAssertEqual(Compact.line(s, deg: { "\($0)°" }), "맑음 · 19° · 큰 일교차")
        s.bubble = WeatherScene.Bubble(kind: "speech", tone: "sky", icon: "umbrella_closed", text: "우산 챙기세요"); s.rain = "bag"; s.hi = 21
        XCTAssertEqual(Compact.line(s, deg: { "\($0)°" }), "맑음 · 19° · 우산")
        s.bubble?.text = "우산 챙겨요"           // an older server
        XCTAssertEqual(Compact.line(s, deg: { "\($0)°" }), "맑음 · 19° · 우산")
        XCTAssertEqual(Compact.bubbleWord(s, max: 5), "맑음")
    }

    /// The sky draws as much as falls: a drizzle thins the streaks, a downpour doubles them.
    func testSkyDensityFollowsAmount() {
        XCTAssertEqual(Sky.density(precip: "rain", mm: 0.5), 0.40, accuracy: 0.01)
        XCTAssertEqual(Sky.density(precip: "rain", mm: 3), 1.0, accuracy: 0.01)
        XCTAssertEqual(Sky.density(precip: "heavy", mm: 40), 2.8, accuracy: 0.01)
        XCTAssertEqual(Sky.density(precip: "snow", mm: 0.2), 0.38, accuracy: 0.01)
        XCTAssertEqual(Sky.density(precip: "heavysnow", mm: 8), 2.6, accuracy: 0.01)
        // every step of the amount draws more than the one before
        let steps = [0.3, 1, 3, 6, 12, 25, 40].map { mm in
            Sky.compose(time: "day", cover: "overcast", precip: mm >= 6 ? "heavy" : "rain", thunder: false, aux: [], mm: mm).items.filter { $0.a == "fall" }.count }
        XCTAssertEqual(steps, steps.sorted()); XCTAssertEqual(Set(steps).count, steps.count, "\(steps)")
        let light = Sky.compose(time: "day", cover: "overcast", precip: "rain", thunder: false, aux: [], mm: 0.5).items.filter { $0.a == "fall" }.count
        let normal = Sky.compose(time: "day", cover: "overcast", precip: "rain", thunder: false, aux: [], mm: 5).items.filter { $0.a == "fall" }.count
        let pour = Sky.compose(time: "day", cover: "overcast", precip: "heavy", thunder: false, aux: [], mm: 30).items.filter { $0.a == "fall" }.count
        XCTAssertLessThan(light, normal); XCTAssertLessThan(normal, pour)
    }

    /// 말투: the same information in 존댓말 · 격식 · 반말
    func testVoices() {
        let f = Voice.formal, c = Voice.casual
        XCTAssertEqual(f.say("비 예보예요. 우산을 챙겨 주세요."), "비 예보입니다. 우산을 챙겨 주십시오.")
        XCTAssertEqual(c.say("비 예보예요. 우산을 챙겨 주세요."), "비 예보야. 우산을 챙겨.")
        XCTAssertEqual(f.say("아침 13°, 낮 19°예요. 일교차가 커요."), "아침 13°, 낮 19°입니다. 일교차가 큽니다.")
        XCTAssertEqual(c.say("아침 13°, 낮 19°예요. 일교차가 커요."), "아침 13°, 낮 19°야. 일교차가 커.")
        XCTAssertEqual(f.say("아침 -14°예요. 많이 추워요."), "아침 -14°입니다. 많이 춥습니다.")
        XCTAssertEqual(c.say("12시간 동안 비 소식 없어요"), "12시간 동안 비 소식 없어")
        XCTAssertEqual(f.say("보송해요 · 이슬점 7°"), "보송합니다 · 이슬점 7°")
        XCTAssertEqual(c.say("15시쯤 비 예보 · 우산 챙기세요"), "15시쯤 비 예보 · 우산 챙겨")
        XCTAssertEqual(f.say("바람 세요!"), "바람이 셉니다!"); XCTAssertEqual(c.say("안개 짙어요!"), "안개 짙어!")
        XCTAssertEqual(f.say("호우주의보"), "호우주의보"); XCTAssertEqual(c.say("15~17시 비 예보"), "15~17시 비 예보")
        // the new wording: 챙기세요 · 조심하세요 · ~하는 게 좋아요, and warning lines with ", " between clauses
        XCTAssertEqual(f.say("비 예보예요. 우산 챙기세요."), "비 예보입니다. 우산 챙기십시오.")
        XCTAssertEqual(c.say("비 예보예요. 우산 챙기세요."), "비 예보야. 우산 챙겨.")
        XCTAssertEqual(f.say("안개가 짙어요!"), "안개가 짙습니다!"); XCTAssertEqual(c.say("안개가 옅어요"), "안개가 옅어")
        XCTAssertEqual(f.say("오늘 6cm, 18시까지 눈 예보, 미끄러우니 조심하세요"), "오늘 6cm, 18시까지 눈 예보, 미끄러우니 조심하십시오")
        XCTAssertEqual(c.say("오늘 6cm, 18시까지 눈 예보, 미끄러우니 조심하세요"), "오늘 6cm, 18시까지 눈 예보, 미끄러우니 조심해")
        XCTAssertEqual(f.say("비가 많이 와요, 우산 꼭 챙기고 우비도 있으면 좋아요"), "비가 많이 옵니다, 우산 꼭 챙기고 우비도 있으면 좋습니다")
        XCTAssertEqual(c.say("비가 많이 와요, 우산 꼭 챙기고 우비도 있으면 좋아요"), "비가 많이 와, 우산 꼭 챙기고 우비도 있으면 좋아")
        XCTAssertEqual(f.say("황사가 심해요, 마스크 챙기세요"), "황사가 심합니다, 마스크 챙기십시오")
        XCTAssertEqual(c.say("낮 최고 35°, 모자·선크림을 챙기고 물을 자주 마시는 게 좋아요"), "낮 최고 35°, 모자·선크림을 챙기고 물을 자주 마시는 게 좋아")
        XCTAssertEqual(f.say("강풍 · 외출 조심하세요"), "강풍 · 외출 조심하십시오")
        XCTAssertEqual(c.say("이슬비 · 가볍게 내려요 · 18시까지 비 예보"), "이슬비 · 가볍게 내려 · 18시까지 비 예보")
        XCTAssertEqual(f.say("새 날씨를 불러오는 중이에요 · 지금은 13:40 날씨예요"), "새 날씨를 불러오는 중입니다 · 지금은 13:40 날씨입니다")
        XCTAssertEqual(c.say("날씨를 불러오는 데 시간이 걸리고 있어요. 잠시 후 아래로 당겨 주세요."), "날씨를 불러오는 데 시간이 걸리고 있어. 잠시 후 아래로 당겨 줘.")
        XCTAssertEqual(f.say("바람이 매우 강해요. 바깥 활동은 줄이는 게 좋아요. 밤에 가장 세요."), "바람이 매우 강합니다. 바깥 활동은 줄이는 게 좋습니다. 밤에 가장 셉니다.")
        XCTAssertEqual(Voice.polite.say("많이 추워요."), "많이 추워요.")
        XCTAssertEqual(PurrCharacter.brit.defaultVoice, .formal); XCTAssertEqual(PurrCharacter.abys.defaultVoice, .casual)
    }

    // MARK: languages

    /// The same code in English and Japanese: words from the glossary, hour labels in each language's style.
    func testEnglishWords() {
        Lang.current = .en
        defer { Lang.current = .ko }
        XCTAssertEqual(Brand.name, "Purrcast")
        XCTAssertEqual(Rules.feelsWord(20), "Mild")
        XCTAssertEqual(Rules.windWord(ms: 2), "Gentle breeze")
        XCTAssertEqual(Rules.rainKind(5), "Moderate rain")
        XCTAssertEqual(L("설정"), "Settings")
        XCTAssertEqual(L("%@ · 어제보다 %d° 낮아요", "NYC", 4), "NYC · 4° cooler than yesterday")
        XCTAssertEqual(Notifications.changeTitle(place: "NYC", todayHi: 15, yesterdayHi: 19, unitF: false), "NYC · 4° cooler than yesterday")
        XCTAssertEqual(Notifications.morningBody(WeatherScene.DayRow(name: "Fri", icon: "raincloud", chance: 70, lo: 9, hi: 19)), "Rain expected · Take an umbrella")
        // a server-English scene on the lock screen / watch
        var s = WeatherScene(); s.temp = 16; s.feels = 15; s.hi = 18; s.lo = 11; s.cond = "Rain"; s.rain = "umbrella"
        s.bubble = WeatherScene.Bubble(kind: "speech", tone: "sky", icon: "umbrella", text: "Rain!")
        XCTAssertEqual(Compact.line(s, deg: { "\($0)°" }), "Rain · 16° · Umbrella")
        s.bubble?.text = "Heavy Rain Advisory"
        XCTAssertEqual(Compact.head(s), "Heavy Rain Advisory")
        // hour labels: "3PM" in 12-hour mode, "15:00" otherwise; windows as "3–5PM"
        XCTAssertEqual(HourLabel.hour("3PM"), 15); XCTAssertEqual(HourLabel.hour("12AM"), 0); XCTAssertEqual(HourLabel.hour("15:00"), 15)
        XCTAssertEqual(HourLabel.hour("Now"), nil)
        XCTAssertEqual(HourLabel.word(15, clock12: true), "3PM"); XCTAssertEqual(HourLabel.word(15, clock12: false), "15:00")
        XCTAssertEqual(HourLabel.window(15, 17, clock12: true), "3–5PM"); XCTAssertEqual(HourLabel.window(11, 13, clock12: true), "11AM–1PM")
        XCTAssertEqual(L("%@쯤 비 예보 · 우산 챙기세요", HourLabel.word(15, clock12: true)), "Rain around 3PM · Take an umbrella")
        // one tone: the voices leave English alone and the picker has nothing to show
        XCTAssertEqual(Voice.casual.say("Rain expected. Take an umbrella."), "Rain expected. Take an umbrella.")
        XCTAssertTrue(Voice.choices.isEmpty)
        XCTAssertEqual(Place.here.name, "Seoul Mapo-gu")
    }

    func testJapaneseWords() {
        Lang.current = .ja
        defer { Lang.current = .ko }
        XCTAssertEqual(Brand.name, "ゴロゴロ天気")
        XCTAssertEqual(Rules.feelsWord(20), "穏やか")
        XCTAssertEqual(Notifications.changeTitle(place: "麻浦区", todayHi: 15, yesterdayHi: 19, unitF: false), "麻浦区・昨日より4°低い")
        XCTAssertEqual(Notifications.changeTitle(place: "麻浦区", todayHi: 20, yesterdayHi: 19, unitF: false), "麻浦区・昨日とほぼ同じ")
        XCTAssertEqual(HourLabel.hour("15時"), 15); XCTAssertEqual(HourLabel.hour("午後3時"), 15)
        XCTAssertEqual(HourLabel.word(15, clock12: false), "15時"); XCTAssertEqual(HourLabel.window(15, 17, clock12: false), "15〜17時")
        XCTAssertEqual(L("%@쯤 비 예보 · 우산 챙기세요", HourLabel.word(15, clock12: false)), "15時ごろ雨の予報・傘をお持ちください")
        XCTAssertEqual(Voice.casual.say("今日 6cm、18時ごろまで雪の予報、滑りやすいのでご注意ください"), "今日 6cm、18時ごろまで雪の予報、滑りやすいので気をつけて")
        XCTAssertEqual(Voice.casual.say("天気の読み込みに時間がかかっています。少ししてから下に引いてください。"), "天気の読み込みに時間がかかってるよ。少ししてから下に引いて。")
        var s = WeatherScene(); s.temp = 16; s.feels = 15; s.hi = 18; s.lo = 11; s.cond = "雨"; s.rain = "umbrella"
        s.bubble = WeatherScene.Bubble(kind: "speech", tone: "sky", icon: "umbrella", text: "雨!")
        XCTAssertEqual(Compact.line(s, deg: { "\($0)°" }), "雨 · 16° · 傘")
        // 丁寧 leaves the text alone, タメ口 swaps the fixed endings, formal counts as polite
        XCTAssertEqual(Voice.polite.say("雨の予報です。傘をお持ちください。"), "雨の予報です。傘をお持ちください。")
        XCTAssertEqual(Voice.formal.say("雨の予報です。傘をお持ちください。"), "雨の予報です。傘をお持ちください。")
        XCTAssertEqual(Voice.casual.say("雨の予報です。傘をお持ちください。"), "雨の予報だよ。傘持ってって。")
        XCTAssertEqual(Voice.casual.say("寒暖差が大きいです"), "寒暖差が大きいよ")
        XCTAssertEqual(Voice.choices, [.polite, .casual])
        XCTAssertEqual(Voice.formal.effective, .polite)
    }

    func testKoreanHourLabels() {
        XCTAssertEqual(HourLabel.hour("15시"), 15); XCTAssertEqual(HourLabel.hour("오후 3시"), 15); XCTAssertNil(HourLabel.hour("지금"))
        XCTAssertEqual(HourLabel.word(15, clock12: false), "15시"); XCTAssertEqual(HourLabel.word(15, clock12: true), "오후 3시")
        XCTAssertEqual(HourLabel.window(15, 17, clock12: false), "15~17시")
        XCTAssertEqual(HourLabel.clock(950, clock12: false), "15:50")
        XCTAssertEqual(L("%@쯤 비 예보 · 우산 챙기세요", HourLabel.word(15, clock12: false)), "15시쯤 비 예보 · 우산 챙기세요")
        XCTAssertEqual(Lang.detect(["ko-KR"]), .ko); XCTAssertEqual(Lang.detect(["ja-JP"]), .ja); XCTAssertEqual(Lang.detect(["de-DE"]), .en); XCTAssertEqual(Lang.detect([]), .en)
    }

    // MARK: place search (Purrcast/Resources/places.json)

    private func placeIndex() async throws -> PlaceIndex {
        let index = PlaceIndex.shared
        await index.load()
        XCTAssertTrue(index.isLoaded, "places.json is in the app bundle")
        return index
    }

    /// Any of the three languages (and any width / case) finds the same place; nothing is listed before typing.
    func testPlaceSearchFindsEveryLanguage() async throws {
        let index = try await placeIndex()
        XCTAssertTrue(index.search("").isEmpty)
        XCTAssertTrue(index.search("  ").isEmpty)
        for q in ["캘리포니아", "カリフォルニア", "かりふぉるにあ", "California", "ＣＡＬＩＦＯＲＮＩＡ"] {
            XCTAssertTrue(index.search(q).all.contains(where: { $0.id == "rg:US-CA" }), q)
        }
        let row = try XCTUnwrap(index.search("캘리포니아").rows.first)
        XCTAssertEqual(row.id, "rg:US-CA")
        XCTAssertEqual(row.title, "캘리포니아"); XCTAssertEqual(row.subtitle, "미국")
        let ca = try XCTUnwrap(row.place)
        XCTAssertEqual(ca.name, "캘리포니아, 미국"); XCTAssertEqual(ca.short, "캘리포니아")
        XCTAssertEqual(ca.region, "other"); XCTAssertEqual(ca.timeZone, "America/Los_Angeles")
        XCTAssertNotNil(index.search("とうきょう").all.first(where: { $0.id == "rg:JP-13" }), "Japanese readings of the prefectures")
        Lang.current = .ja
        XCTAssertEqual(index.renamed(ca)?.name, "カリフォルニア, アメリカ合衆国")
    }

    /// A country lists all of its regions, in the app language's own order.
    func testCountryListsItsRegionsInOrder() async throws {
        let index = try await placeIndex()
        let us = try XCTUnwrap(index.search("미국").groups.first)
        XCTAssertEqual(us.head.id, "rg:US")
        XCTAssertNil(us.head.place, "a country with regions lists them instead of being added")
        XCTAssertGreaterThanOrEqual(us.children.count, 50)
        let ko = us.children.map { $0.title }
        XCTAssertEqual(ko, ko.sorted(), "ㄱㄴㄷ")
        XCTAssertTrue(ko.contains("캘리포니아"))

        Lang.current = .en
        let en = try XCTUnwrap(index.search("United States").groups.first).children.map { $0.title }
        XCTAssertEqual(en.first, "Alabama")
        XCTAssertEqual(en.count, ko.count)

        Lang.current = .ja
        let jp = try XCTUnwrap(index.search("日本").groups.first).children
        XCTAssertEqual(jp.count, 47)
        XCTAssertEqual(jp.first?.title, "北海道"); XCTAssertEqual(jp.last?.title, "沖縄県")
        XCTAssertEqual(jp.map { $0.id }, (1...47).map { String(format: "rg:JP-%02d", $0) }, "JIS code order")
        XCTAssertEqual(try XCTUnwrap(index.search("アメリカ").groups.first).head.id, "rg:US")
    }

    /// Korea down to 읍면동: 시도 → 시군구 → 읍면동, names in each language, ids that survive a language change.
    func testKoreanPlaces() async throws {
        let index = try await placeIndex()
        let mapo = try XCTUnwrap(index.search("마포").rows.first)
        XCTAssertEqual(mapo.title, "서울 마포구"); XCTAssertEqual(mapo.id, "kr:1144000000")
        let p = try XCTUnwrap(mapo.place)
        XCTAssertEqual(p.name, "서울 마포구"); XCTAssertEqual(p.short, "마포구")
        XCTAssertEqual(p.region, "kr"); XCTAssertEqual(p.timeZone, "Asia/Seoul")

        let seoul = try XCTUnwrap(index.search("서울").groups.first)
        XCTAssertEqual(seoul.children.count, 25)
        XCTAssertEqual(seoul.children.first?.title, "서울 강남구")
        let gu = try XCTUnwrap(index.search("마포구").groups.first)
        XCTAssertTrue(gu.children.contains { $0.title == "서울 마포구 아현동" })
        XCTAssertTrue(index.search("분당").rows.contains { $0.title == "경기 성남시 분당구" && $0.place?.short == "분당구" })
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(index.search("한국").groups.first).children.count, 16)

        Lang.current = .en
        XCTAssertEqual(index.search("Mapo").rows.first?.title, "Mapo-gu, Seoul")
        XCTAssertEqual(index.renamed(p)?.name, "Mapo-gu, Seoul"); XCTAssertEqual(index.renamed(p)?.short, "Mapo-gu")
        XCTAssertEqual(index.renamed(p)?.ko, "서울 마포구", "the server gets the Korean name in every language")
        Lang.current = .ja
        XCTAssertEqual(index.renamed(p)?.name, "ソウル マポ区"); XCTAssertEqual(index.renamed(p)?.short, "マポ区")
        XCTAssertEqual(index.renamed(p)?.serverName, "서울 마포구")
        XCTAssertEqual(index.search("オリュ").rows.first?.title, "ソウル クロ区 オリュジェ1ドン", "katakana finds Korean places (the index has 오류제1동)")
        XCTAssertEqual(index.search("まぽ").rows.first?.title, "ソウル マポ区")
        XCTAssertNil(index.renamed(Place.catalog[0]), "catalog and Apple Maps places are not the index's")
    }

    /// Korean place names read in katakana for Japanese (Apple answers Korean addresses in Hangul).
    func testKoreanKana() {
        let cases: [(String, String)] = [
            ("서울", "ソウル"), ("오류동", "オリュドン"), ("구로구", "クロ区"), ("마포구", "マポ区"), ("종로구", "チョンノ区"),
            ("강남구", "カンナム区"), ("영등포구", "ヨンドゥンポ区"), ("관악구", "クァナク区"), ("신림동", "シルリムドン"),
            ("왕십리", "ワンシムニ"), ("해운대구", "ヘウンデ区"), ("성남시 분당구", "ソンナム市 プンダン区"), ("판교동", "パンギョドン"),
            ("여의도동", "ヨウィドドン"), ("역삼1동", "ヨクサム1ドン"), ("목동", "モクトン"), ("안양시", "アニャン市"),
            ("수원시", "スウォン市"), ("신월동", "シンウォルドン"), ("강릉시", "カンヌン市"), ("압구정동", "アプクジョンドン"),
            ("제주시", "チェジュ市"), ("의정부시", "ウィジョンブ市"), ("청주시", "チョンジュ市"), ("대구", "大邱"), ("중구", "チュン区"), ("오류1동", "オリュ1ドン"),
            ("Seoul", "Seoul"),
        ]
        for (ko, ja) in cases { XCTAssertEqual(KoreanKana.place(ko), ja, ko) }
        XCTAssertEqual(KoreanKana.province("서울특별시"), "ソウル")
        XCTAssertEqual(KoreanKana.province("충청북도"), "忠清北道")
        XCTAssertEqual(KoreanKana.province("충청북"), "忠清北道")
        XCTAssertNil(KoreanKana.province("Tokyo"))

        // "here" in Korea: the Korean name kept for the server, katakana in Japanese, Korean back in Korean
        let here = Place(id: "here", name: "서울 오류동", short: "오류동", lat: 37.49, lon: 126.84, region: "kr",
                         timeZone: "Asia/Seoul", sample: "maybe", ko: "서울 오류동")
        let ja = AppModel.koreanNamed(here, .ja)
        XCTAssertEqual(ja.name, "ソウル オリュドン"); XCTAssertEqual(ja.short, "オリュドン"); XCTAssertEqual(ja.serverName, "서울 오류동")
        XCTAssertEqual(AppModel.koreanNamed(ja, .ko).name, "서울 오류동")
        let tokyo = Place(id: "mk:35.662,139.704", name: "渋谷区", short: "渋谷区", lat: 35.66, lon: 139.70, region: "jp",
                          timeZone: "Asia/Tokyo", sample: "tokyo_soon")
        XCTAssertEqual(AppModel.koreanNamed(tokyo, .ja), tokyo, "only Korean places change")
    }

    func testSearchKeys() {
        XCTAssertEqual(PlaceKey.norm("Mapo-gu, Seoul"), "mapoguseoul")
        XCTAssertEqual(PlaceKey.norm("Hà Nội"), "hanoi")
        XCTAssertEqual(PlaceKey.norm("ｶﾘﾌｫﾙﾆｱ"), PlaceKey.norm("かりふぉるにあ"))
        XCTAssertEqual(PlaceKey.norm("ガ"), "が")
        XCTAssertEqual(PlaceKey.norm("서울 마포구"), "서울마포구")
        XCTAssertEqual(PlaceKey.norm("서울・마포"), "서울마포")
    }

    func testMapKitPlace() {
        let tokyo = PlaceIndex.shared.mapKitPlace(name: "渋谷区", short: "渋谷区", lat: 35.66184, lon: 139.70361, country: "JP",
                                                  timeZone: TimeZone(identifier: "Asia/Tokyo"))
        XCTAssertEqual(tokyo.id, "mk:35.662,139.704"); XCTAssertEqual(tokyo.region, "jp"); XCTAssertEqual(tokyo.timeZone, "Asia/Tokyo")
        let gangnam = PlaceIndex.shared.mapKitPlace(name: "역삼동", short: "", lat: 37.5, lon: 127.03, country: "KR", timeZone: nil)
        XCTAssertEqual(gangnam.region, "kr"); XCTAssertEqual(gangnam.timeZone, "Asia/Seoul"); XCTAssertEqual(gangnam.short, "역삼동")
        let nowhere = PlaceIndex.shared.mapKitPlace(name: "X", short: "X", lat: 0, lon: 0, country: "", timeZone: nil)
        XCTAssertEqual(nowhere.region, "other"); XCTAssertEqual(nowhere.timeZone, "UTC")
        XCTAssertEqual(AppleSearch.shortName("Shibuya, Tokyo", korean: false), "Shibuya")
        XCTAssertEqual(AppleSearch.shortName("서울특별시 강남구 역삼동", korean: true), "역삼동")
    }
}
