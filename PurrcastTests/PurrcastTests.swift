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
        // 미세먼지: the example scenes carry the block; a scene without it decodes to nil; a broken block is dropped, not fatal
        let ex = SceneLibrary.all
        let dust = try XCTUnwrap(ex["spring_dust"]?.dust)
        XCTAssertEqual(dust.pm10, 162); XCTAssertEqual(dust.grade, 3); XCTAssertEqual(dust.pm25Grade, 2); XCTAssertEqual(dust.station, "마포구"); XCTAssertEqual(dust.tomorrow?.pm10Grade, 2)
        XCTAssertTrue(dust.note.hasPrefix("황사"))
        XCTAssertNil(ex["combo"]?.dust)
        XCTAssertEqual(DustScale.position(39, pm25: false), 0.25 + 9.0 / 50 / 4, accuracy: 0.001)
        XCTAssertEqual(DustScale.position(0, pm25: true), 0); XCTAssertEqual(DustScale.position(999, pm25: true), 1)
        // the scale card's ranges: 환경부 at home, WHO abroad
        XCTAssertEqual((0..<4).map { DustScale.range($0, pm25: true) }, ["0~15", "16~35", "36~75", "76+"])
        XCTAssertEqual((0..<4).map { DustScale.range($0, pm25: false, who: true) }, ["0~45", "46~75", "76~150", "151+"])
        XCTAssertEqual(DustScale.range(1, pm25: true, who: true), "16~37.5"); XCTAssertEqual(DustScale.grade(40, pm25: false, who: true), 0); XCTAssertEqual(DustScale.grade(40, pm25: false), 1)
        // today's readings (Plus): [hour, pm10, pm25], a sensor gap as null; older answers have none
        let hoursJSON = """
        {"pm10": 39, "pm25": 29, "grade": 1, "note": "", "src": "에어코리아", "srcKey": "airkorea", "hours": [[0, 20, 10], [1, 22, null], [13, 39, 29]]}
        """.data(using: .utf8)!
        let withHours = try JSONDecoder().decode(WeatherScene.Dust.self, from: hoursJSON)
        XCTAssertEqual(withHours.hours?.count, 3); XCTAssertEqual(withHours.hours?[1].pm10, 22); XCTAssertNil(withHours.hours?[1].pm25); XCTAssertEqual(withHours.hours?[2].hour, 13)
        XCTAssertFalse(withHours.who); XCTAssertNil(ex["maybe"]?.dust?.hours); XCTAssertEqual(dust.hours?.count, 14)
        // the 6-hour card's rows: [label, mm, kind] — older rows without a kind are rain
        let six = try JSONDecoder().decode([WeatherScene.NextHour].self, from: #"[["15시", 0.8], ["16시", 1.2, 1], ["17시", 0.3, 2]]"#.data(using: .utf8)!)
        XCTAssertEqual(six.map(\.kind), [0, 1, 2]); XCTAssertTrue(six[1].snow); XCTAssertTrue(six[2].sleet)
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

    func testChangeNotificationWords() throws {
        XCTAssertEqual(Notifications.changeTitle(place: "마포구", todayHi: 15, yesterdayHi: 19, unitF: false), "마포구 · 어제보다 4° 낮아요")
        XCTAssertEqual(Notifications.changeTitle(place: "마포구", todayHi: 20, yesterdayHi: 19, unitF: false), "마포구 · 어제와 비슷해요")
        XCTAssertEqual(Notifications.changeTitle(place: "NYC", todayHi: 25, yesterdayHi: 20, unitF: true), "NYC · 어제보다 9° 높아요")
        let d = WeatherScene.DayRow(name: "금", icon: "raincloud", chance: 70, lo: 9, hi: 19)
        XCTAssertEqual(Notifications.changeBody(d, deg: { "\($0)°" }), "오늘 9° ~ 19° · 일교차가 커요 · 비 예보")
        XCTAssertEqual(Notifications.morningBody(d), "비 예보예요 · 우산 챙기세요")
        XCTAssertEqual(Notifications.morningBody(WeatherScene.DayRow(name: "금", icon: "raincloud", chance: 40, lo: 9, hi: 19)), "강수확률 40% · 우산 챙기세요")
        XCTAssertEqual(Notifications.morningBody(WeatherScene.DayRow(name: "금", icon: "snowflake", chance: 80, lo: -3, hi: 1)), "눈 예보예요 · 미끄러우니 조심하세요")
        XCTAssertEqual(Notifications.morningBody(WeatherScene.DayRow(name: "금", icon: "sleet", chance: 80, lo: -1, hi: 3)), "진눈깨비 예보예요 · 미끄러우니 조심하세요")
        // the full morning line-up: free from the day's forecast, Plus with a third line
        let all = try JSONDecoder().decode([String: WeatherScene].self, from: fixture("server-scenes"))
        let sc = try XCTUnwrap(all["plus"]), day0 = try XCTUnwrap(sc.days.first)
        let free = Notifications.morningDetail(sc, day: day0, plus: false, today: true, unitF: false)
        XCTAssertTrue(free.hasPrefix("🌧️ " + sc.cond + " · "), free)   // a sky emoji leads the first line
        XCTAssertTrue(free.contains("16~18시 비 예보"), free); XCTAssertTrue(free.hasSuffix("\n☂️ 우산 챙기세요"), free)
        XCTAssertTrue(free.contains("체감 "), free); XCTAssertTrue(free.contains("일몰 "), free)
        XCTAssertEqual(free.components(separatedBy: "\n").count, 3)
        XCTAssertFalse(free.contains("어제보다"))
        XCTAssertEqual(free.components(separatedBy: "우산").count, 2, "the umbrella is said once")
        var warned = sc; warned.alert = WeatherScene.Alert(name: "호우주의보", note: "오늘 40mm, 18시까지 비 예보, 우산 꼭 챙기세요")
        let plusText = Notifications.morningDetail(warned, day: day0, plus: true, today: true, unitF: false)
        XCTAssertTrue(plusText.contains("\n⚠️ 호우주의보"), plusText)
        XCTAssertEqual(plusText.components(separatedBy: "우산").count, 2, "the warning line says it, the umbrella line is dropped: \(plusText)")
        // 미세먼지 in the morning: the grade, the finer one when it differs, a mask line at 나쁨+
        var dusty = sc; dusty.dust = WeatherScene.Dust(pm10: 95, pm25: 29, pm10Grade: 2, pm25Grade: 1, grade: 2, note: "", src: "에어코리아")
        let dl = Notifications.morningDetail(dusty, day: day0, plus: false, today: true, unitF: false)
        XCTAssertTrue(dl.contains("\n😷 미세먼지 나쁨 · 초미세먼지 보통 · 마스크를 챙겨 주세요\n"), dl)
        XCTAssertEqual(dl.components(separatedBy: "마스크").count, 2, "the mask is said once: \(dl)")
        // Plus: a 주의보 in force takes the line
        dusty.dust = WeatherScene.Dust(pm10: 95, pm25: 80, pm10Grade: 2, pm25Grade: 3, grade: 3, note: "", src: "에어코리아", alarm: "watch")
        let dl3 = Notifications.morningDetail(dusty, day: day0, plus: true, today: true, unitF: false)
        XCTAssertTrue(dl3.contains("\n😷 초미세먼지 주의보 · 창문을 닫고 외출할 땐 마스크를 착용해 주세요\n"), dl3)
        XCTAssertEqual(dl3.components(separatedBy: "마스크").count, 2, dl3)
        dusty.dust = WeatherScene.Dust(pm10: 22, pm25: 11, pm10Grade: 0, pm25Grade: 0, grade: 0, note: "", src: "에어코리아")
        let dl2 = Notifications.morningDetail(dusty, day: day0, plus: false, today: true, unitF: false)
        XCTAssertTrue(dl2.contains("\n미세먼지 좋음\n"), dl2); XCTAssertFalse(dl2.contains("초미세먼지"))
        let tomorrow = Notifications.morningDetail(sc, day: sc.days[1], plus: false, today: false, unitF: false)
        XCTAssertFalse(tomorrow.contains("체감"), "tomorrow's summary has no now-values: \(tomorrow)")
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
        XCTAssertEqual(Lang.detect(["ko-KR"]), .ko); XCTAssertEqual(Lang.detect(["ja-JP"]), .ja); XCTAssertEqual(Lang.detect(["de-DE"]), .de); XCTAssertEqual(Lang.detect(["nl-NL"]), .en); XCTAssertEqual(Lang.detect([]), .en)
        XCTAssertEqual(Lang.detect(["zh-Hant-TW"]), .zhHant); XCTAssertEqual(Lang.detect(["zh-CN"]), .zhHans); XCTAssertEqual(Lang.detect(["pt-BR"]), .pt)
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

    // MARK: 전일 대비 kept on the phone

    private func history() -> TempHistory {
        let d = UserDefaults(suiteName: "test.tempHistory")!
        d.removePersistentDomain(forName: "test.tempHistory")
        return TempHistory(defaults: d)
    }

    func testYesterdayFromThePhone() {
        let h = history()
        let day = Date(timeIntervalSince1970: 1_780_000_000)   // a fixed moment
        let m: (Int) -> Date = { day.addingTimeInterval(Double($0) * 60) }
        // yesterday: 12° an hour before this time, 14° an hour after
        h.record(12, lat: 37.55, lon: 126.91, at: m(-60))
        h.record(14, lat: 37.55, lon: 126.91, at: m(60))
        XCTAssertEqual(h.yesterday(lat: 37.55, lon: 126.91, at: m(24 * 60))!, 13, accuracy: 0.01)   // in between
        // a few km away is the same ~10 km cell
        XCTAssertNotNil(h.yesterday(lat: 37.52, lon: 126.93, at: m(24 * 60)))
        // nothing near this time yesterday: no answer
        XCTAssertNil(h.yesterday(lat: 37.55, lon: 126.91, at: m(24 * 60 + 300)))
        // one reading within half an hour is enough
        XCTAssertEqual(h.yesterday(lat: 37.55, lon: 126.91, at: m(24 * 60 + 80))!, 14, accuracy: 0.01)
        // another city has its own record
        XCTAssertNil(h.yesterday(lat: 35.68, lon: 139.69, at: m(24 * 60)))
    }

    func testYesterdayAppliedToTheScene() {
        let h = history()
        let t0 = Date(timeIntervalSince1970: 1_780_000_000)
        var s = WeatherScene(); s.temp = 10; s.yday = 5    // the server says +5
        h.apply(to: &s, lat: 37.55, lon: 126.91, at: t0)
        XCTAssertEqual(s.yday, 5)                            // the phone has no yesterday yet: the server's figure stays
        var t = WeatherScene(); t.temp = 7; t.yday = 0
        h.apply(to: &t, lat: 37.55, lon: 126.91, at: t0.addingTimeInterval(86400 + 600))
        XCTAssertEqual(t.yday, -3)                           // 7° now, 10° this time yesterday
        // readings a minute apart replace each other; old ones age out after two days
        h.record(8, lat: 37.55, lon: 126.91, at: t0.addingTimeInterval(86400 + 660))
        XCTAssertNil(h.yesterday(lat: 37.55, lon: 126.91, at: t0.addingTimeInterval(4 * 86400)))
    }

    // MARK: 날씨 기록

    private func dayLog() -> DayLog {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("daylog-\(UUID().uuidString)")
        return DayLog(dir: dir)
    }

    private func scene(temp: Int, hi: Int, lo: Int, icon: String = "sun", chance: Int = 0, precip: String = "none", dust: Int? = nil) -> WeatherScene {
        var s = WeatherScene(); s.temp = temp; s.hi = hi; s.lo = lo; s.precip = precip
        s.days = [WeatherScene.DayRow(name: "오늘", icon: icon, chance: chance, lo: lo, hi: hi)]
        if let dust { s.dust = try? JSONDecoder().decode(WeatherScene.Dust.self, from: Data("{\"grade\": \(dust)}".utf8)) }
        return s
    }

    func testDayLogFoldsADay() {
        let log = dayLog()
        var place = Place.here; place.timeZone = "Asia/Seoul"
        let morning = Date(timeIntervalSince1970: 1_780_000_000)      // the same Seoul day, hours apart
        log.record(scene(temp: 9, hi: 15, lo: 8, dust: 1), place: place, at: morning)
        log.record(scene(temp: 16, hi: 15, lo: 8, icon: "raincloud", chance: 70, precip: "rain", dust: 2), place: place, at: morning.addingTimeInterval(4 * 3600))
        let r = log.records(place.id)
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0].hi, 16)                 // warmer than forecast: what was seen counts
        XCTAssertEqual(r[0].lo, 8)
        XCTAssertEqual(r[0].wet, "rain")
        XCTAssertEqual(r[0].dust, 2)                // the worst of the day
        XCTAssertEqual(r[0].icon, "raincloud")
        // the next day is its own line, and the finished day lets go of its hours
        log.record(scene(temp: 5, hi: 10, lo: 3), place: place, at: morning.addingTimeInterval(86400))
        let r2 = log.records(place.id)
        XCTAssertEqual(r2.count, 2)
        XCTAssertNil(r2[0].hours)
        XCTAssertNil(r2[1].wet)
        // places no longer listed lose their days
        log.keepOnly(["somewhere-else"])
        XCTAssertTrue(log.records(place.id).isEmpty)
    }

    /// The calendar keeps the days used with Plus: a day seen with Plus stays a Plus day; days only the server filled
    /// in (an older build) are dropped, days the phone saw are kept
    func testDayLogPlusDays() {
        let log = dayLog()
        var place = Place.here; place.timeZone = "Asia/Seoul"
        let t = Date(timeIntervalSince1970: 1_780_000_000)
        log.record(scene(temp: 9, hi: 15, lo: 8), place: place, plus: false, at: t)
        XCTAssertEqual(log.records(place.id).last?.plus, false)
        log.record(scene(temp: 10, hi: 15, lo: 8), place: place, plus: true, at: t.addingTimeInterval(3600))
        log.record(scene(temp: 11, hi: 15, lo: 8), place: place, plus: false, at: t.addingTimeInterval(7200))
        XCTAssertEqual(log.records(place.id).last?.plus, true)
        var filled = DayRecord(date: "2026-01-02", hi: 3, lo: -4, icon: "sun"); filled.obs = true
        var seen = DayRecord(date: "2026-01-03", hi: 4, lo: -3, icon: "sun"); seen.obs = true; seen.seenHi = 4
        log.save(log.records(place.id) + [filled, seen], for: place.id)
        log.dropFilled(place.id)
        XCTAssertEqual(log.records(place.id).map(\.date).filter { $0.hasPrefix("2026-01") }, ["2026-01-03"])
    }

    /// Holidays where the place is, from its time zone: each table from the server replaces the last; names in the
    /// app's language where there is one, else English; a day recorded abroad takes that country's holidays
    func testHolidays() {
        defer { Lang.current = .ko }
        XCTAssertEqual(Holidays.country(timeZone: "Asia/Seoul"), "KR")
        XCTAssertEqual(Holidays.country(timeZone: "America/New_York"), "US")
        let kr = #"{"cc":"KR","lang":"ko","days":{"2026-10-03":{"":"개천절","en":"National Foundation Day"},"2026-10-05":{"":"개천절 대체공휴일","en":"Alternative holiday for National Foundation Day"},"2026-10-09":{"":"한글날","en":"Hangul Day"}}}"#
        let jp = #"{"cc":"JP","lang":"ja","days":{"2026-10-12":{"":"スポーツの日","en":"Sports Day"}}}"#
        let t0 = Date(timeIntervalSince1970: 1_790_000_000)
        Holidays.install(Data(kr.utf8), fetched: t0)
        Holidays.install(Data(jp.utf8), fetched: t0)
        Lang.current = .ko
        XCTAssertEqual(Holidays.name("2026-10-05", timeZone: "Asia/Seoul"), "개천절 대체공휴일")
        XCTAssertNil(Holidays.name("2026-10-06", timeZone: "Asia/Seoul"))
        XCTAssertEqual(Holidays.name("2026-10-12", timeZone: "Asia/Tokyo"), "Sports Day")     // no Korean name: English
        XCTAssertEqual(Holidays.month("2026-10", timeZone: { _ in "Asia/Seoul" }).map(\.key), ["2026-10-03", "2026-10-05", "2026-10-09"])
        let trip = Holidays.month("2026-10", timeZone: { $0 >= "2026-10-10" && $0 <= "2026-10-13" ? "Asia/Tokyo" : "Asia/Seoul" }).map(\.key)
        XCTAssertEqual(trip, ["2026-10-03", "2026-10-05", "2026-10-09", "2026-10-12"])
        Lang.current = .ja
        XCTAssertEqual(Holidays.name("2026-10-12", timeZone: "Asia/Tokyo"), "スポーツの日")
        // a newer table takes the old one's place
        Holidays.install(Data(#"{"cc":"KR","lang":"ko","days":{"2026-10-09":{"":"한글날"}}}"#.utf8), fetched: t0.addingTimeInterval(86400))
        Lang.current = .ko
        XCTAssertNil(Holidays.name("2026-10-03", timeZone: "Asia/Seoul"))
        XCTAssertEqual(Holidays.table("KR")?.fetched, t0.addingTimeInterval(86400))
        // a country with no holidays known (the server sends no language): kept, so it is not asked again all week
        XCTAssertNotNil(Holidays.install(Data(#"{"cc":"AQ","days":{}}"#.utf8), fetched: t0))
        XCTAssertNil(Holidays.name("2026-10-03", timeZone: "Antarctica/Troll"))
        XCTAssertEqual(Holidays.table("AQ")?.fetched, t0)
    }

    /// "지금 위치" after a location attempt: one failed fix keeps the last place (not the default 서울); an unnamed fix
    /// (geocoding offline) at the same spot keeps the last names and region; location off goes back to the default
    func testHereKeepsThePlaceWhenAFixFails() {
        var tokyo = Place.here; tokyo.name = "東京 新宿区"; tokyo.short = "新宿区"; tokyo.lat = 35.69; tokyo.lon = 139.70
        tokyo.region = "jp"; tokyo.timeZone = "Asia/Tokyo"; tokyo.ko = nil
        XCTAssertEqual(AppModel.nextHere(previous: tokyo, fix: nil, allowed: true), tokyo)
        XCTAssertEqual(AppModel.nextHere(previous: tokyo, fix: nil, allowed: false), Place.here)
        var unnamed = tokyo; unnamed.name = L("지금 위치"); unnamed.short = L("지금 위치"); unnamed.region = "other"; unnamed.lat += 0.01
        XCTAssertEqual(AppModel.nextHere(previous: tokyo, fix: unnamed, allowed: true), tokyo)
        var far = unnamed; far.lat = 34.69                              // 오사카: a new place even unnamed
        XCTAssertEqual(AppModel.nextHere(previous: tokyo, fix: far, allowed: true), far)
        var named = tokyo; named.name = "東京 渋谷区"; named.lat += 0.02
        XCTAssertEqual(AppModel.nextHere(previous: tokyo, fix: named, allowed: true), named)
    }

    /// A stand-in server: answers each place with a scene of its own id, fails the places in `failing`, and holds
    /// the answers for the places in `slow` a while (a request that comes back late)
    private final class FakeWeather: WeatherProvider {
        private let lock = NSLock()
        private var _failing: Set<String> = [], _slow: Set<String> = [], _asked: [String] = []
        var failing: Set<String> { get { lock.withLock { _failing } } set { lock.withLock { _failing = newValue } } }
        var slow: Set<String> { get { lock.withLock { _slow } } set { lock.withLock { _slow = newValue } } }
        var asked: [String] { lock.withLock { _asked } }
        var name: String { "fake" }
        var isSample: Bool { false }
        func forecast(for place: Place, plus: Bool, previousLevel: Int?, fresh: Bool) async throws -> WeatherScene {
            lock.withLock { _asked.append(place.id) }
            if slow.contains(place.id) { try await Task.sleep(nanoseconds: 600_000_000) }
            if failing.contains(place.id) { throw URLError(.notConnectedToInternet) }
            var s = SceneLibrary.scene("clear")
            s.id = place.id; s.place = place.name
            return s
        }
    }

    private func testPlace(_ id: String) -> Place {
        var p = Place.here; p.id = id; p.name = id; p.short = id; p.ko = nil; p.region = "jp"; p.timeZone = "Asia/Tokyo"
        return p
    }

    /// Waits for the model's refreshes to settle (a place switch starts one of its own)
    @MainActor private func settle(_ m: AppModel) async {
        for _ in 0..<100 where m.loading { try? await Task.sleep(nanoseconds: 50_000_000) }
    }

    /// Offline, switched from A to C: C's own forecast from the places list shows (with data), never A's
    @MainActor func testOfflineSwitchShowsThatPlacesForecast() async {
        let fake = FakeWeather()
        let m = AppModel(provider: fake)
        let a = testPlace("test-a"), c = testPlace("test-c")
        m.places = [a, c]
        m.currentIndex = 0
        await m.refresh(force: true); await settle(m)
        XCTAssertEqual(m.raw.id, a.id)
        await m.refreshPreviews()
        fake.failing = [c.id]
        m.currentIndex = 1
        await m.refresh(force: true); await settle(m)
        XCTAssertEqual(m.raw.id, c.id)
        XCTAssertTrue(m.hasData)
        XCTAssertNotNil(m.lastError)            // said as a wait, with C's own data on screen
    }

    /// Launched offline with a saved forecast: this place's weather stays on screen with its own id (the scene is
    /// stored without one), and a forecast saved for another place is never taken for this one's
    @MainActor func testOfflineLaunchKeepsTheSavedForecast() async {
        let d = SharedStore.defaults
        let keys = ["snapshot.v1", "places", "lastRefresh"]
        let before = keys.map { d.object(forKey: $0) }
        defer { for (k, v) in zip(keys, before) { if let v { d.set(v, forKey: k) } else { d.removeObject(forKey: k) } } }
        let a = testPlace("test-a"), b = testPlace("test-b")
        d.set(try? JSONEncoder().encode([a, b]), forKey: "places")
        func saved(for p: Place) {
            var s = SceneLibrary.scene("clear"); s.id = p.id; s.temp = 23
            SharedStore.save(WeatherSnapshot(scene: s, character: .cat, plus: false, characterName: "", placeShort: p.short, saved: Date(), place: p))
        }
        let fake = FakeWeather()
        fake.failing = [a.id, b.id]

        // saved for A, the list starting at A: A's weather, with A's id back
        saved(for: a)
        XCTAssertEqual(SharedStore.load()?.scene.id, "")         // the id really is not stored
        let m = AppModel(provider: fake)
        XCTAssertTrue(m.hasData)
        XCTAssertEqual(m.raw.id, a.id)
        XCTAssertEqual(m.raw.temp, 23)
        await m.refresh(force: true); await settle(m)
        XCTAssertTrue(m.hasData)                                 // offline: the saved weather stays
        XCTAssertEqual(m.raw.id, a.id)
        XCTAssertEqual(m.raw.temp, 23)
        XCTAssertNotNil(m.lastError)                             // said as a wait, with the saved weather on screen

        // saved for B, the list starting at A: B's weather is not shown as A's, and B's id never comes in
        saved(for: b)
        let other = AppModel(provider: fake)
        XCTAssertFalse(other.hasData)
        XCTAssertNotEqual(other.raw.id, b.id)
        XCTAssertNotEqual(other.raw.id, a.id)
        await other.refresh(force: true); await settle(other)
        XCTAssertFalse(other.hasData)
        XCTAssertNotEqual(other.raw.id, b.id)
        XCTAssertNotEqual(other.raw.temp, 23)
    }

    /// A failure that comes back after the switch (the old place's request) leaves the new place's screen alone
    @MainActor func testLateFailureLeavesTheNewPlace() async {
        let fake = FakeWeather()
        let m = AppModel(provider: fake)
        let a = testPlace("test-a"), c = testPlace("test-c")
        m.places = [a, c]
        m.currentIndex = 0
        await settle(m)
        fake.failing = [a.id]; fake.slow = [a.id]
        let old = Task { await m.refresh(force: true) }
        for _ in 0..<40 where !fake.asked.contains(a.id) { try? await Task.sleep(nanoseconds: 25_000_000) }
        m.currentIndex = 1                      // starts C's refresh, which answers at once
        await old.value; await settle(m)
        XCTAssertEqual(m.raw.id, c.id)
        XCTAssertTrue(m.hasData)
        XCTAssertNil(m.lastError)
    }

    /// A widget's own forecast changes only the weather and its time: what the app saved meanwhile stays; another place
    /// saved meanwhile is left alone; 지금 위치 comes with the spot the widget found
    func testWidgetForecastKeepsTheAppsSettings() {
        let a = testPlace("test-a"), b = testPlace("test-b")
        let t0 = Date(timeIntervalSince1970: 1_790_000_000)
        var old = SceneLibrary.scene("clear"); old.temp = 3
        var fresh = SceneLibrary.scene("maybe"); fresh.temp = 12
        // what the app saved while the widget was fetching
        let now = WeatherSnapshot(scene: old, character: .brit, plus: true, characterName: "나비", placeShort: a.short, saved: t0,
                                  place: a, plusUntil: t0.addingTimeInterval(86400), unitF: true, clock12: true, lang: "en", windUnit: "mph")
        let out = SharedStore.withWidgetForecast(fresh, for: a, onto: now, at: t0.addingTimeInterval(60))
        XCTAssertEqual(out?.scene.temp, 12)
        XCTAssertEqual(out?.saved, t0.addingTimeInterval(60))
        XCTAssertEqual(out?.character, .brit); XCTAssertEqual(out?.characterName, "나비")
        XCTAssertEqual(out?.plus, true); XCTAssertEqual(out?.plusUntil, t0.addingTimeInterval(86400))
        XCTAssertEqual(out?.unitF, true); XCTAssertEqual(out?.clock12, true)
        XCTAssertEqual(out?.lang, "en"); XCTAssertEqual(out?.windUnit, "mph")
        XCTAssertEqual(out?.place?.id, a.id); XCTAssertEqual(out?.placeShort, a.short)
        // the app went to another place meanwhile, or nothing real is saved: nothing to save
        XCTAssertNil(SharedStore.withWidgetForecast(fresh, for: b, onto: now))
        XCTAssertNil(SharedStore.withWidgetForecast(fresh, for: a, onto: nil))
        var sample = now; sample.isSample = true
        XCTAssertNil(SharedStore.withWidgetForecast(fresh, for: a, onto: sample))
        // 지금 위치 somewhere new: the weather comes with the spot it is for
        var hereNow = now; hereNow.place = Place.here; hereNow.placeShort = Place.here.short
        var moved = Place.here; moved.name = "부산 해운대구"; moved.short = "해운대구"; moved.lat = 35.16; moved.lon = 129.16
        let h = SharedStore.withWidgetForecast(fresh, for: moved, onto: hereNow)
        XCTAssertEqual(h?.place?.lat, 35.16); XCTAssertEqual(h?.placeShort, "해운대구")
        XCTAssertEqual(h?.unitF, true); XCTAssertEqual(h?.character, .brit)
    }

    /// The end of Plus the widgets get: a day past the paid period when it renews by itself, the paid period's end
    /// when it will not; nothing when the plan is not active (expired, revoked or refunded)
    func testWidgetPlusAllowance() {
        let end = Date(timeIntervalSince1970: 1_790_000_000)
        XCTAssertEqual(Purchases.widgetAllowance, 86400)
        XCTAssertEqual(Purchases.widgetPlusUntil(active: true, expires: end, willRenew: true, testUntil: nil), end.addingTimeInterval(86400))
        XCTAssertEqual(Purchases.widgetPlusUntil(active: true, expires: end, willRenew: false, testUntil: nil), end)
        XCTAssertNil(Purchases.widgetPlusUntil(active: false, expires: end, willRenew: true, testUntil: nil))     // revoked, refunded or expired
        XCTAssertNil(Purchases.widgetPlusUntil(active: true, expires: nil, willRenew: true, testUntil: nil))
        let test = end.addingTimeInterval(1000)
        XCTAssertEqual(Purchases.widgetPlusUntil(active: false, expires: nil, willRenew: false, testUntil: test), test)   // TestFlight test Plus
        // as the widgets see it: renewed last night with the app not opened since → still Plus; cancelled → Free at the end
        var snap = WeatherSnapshot.sample; snap.plus = true
        snap.plusUntil = Purchases.widgetPlusUntil(active: true, expires: Date().addingTimeInterval(-6 * 3600), willRenew: true, testUntil: nil)
        XCTAssertTrue(snap.plusActive)
        snap.plusUntil = Purchases.widgetPlusUntil(active: true, expires: Date().addingTimeInterval(-6 * 3600), willRenew: false, testUntil: nil)
        XCTAssertFalse(snap.plusActive)
        snap.plusUntil = Purchases.widgetPlusUntil(active: true, expires: Date().addingTimeInterval(-25 * 3600), willRenew: true, testUntil: nil)
        XCTAssertFalse(snap.plusActive)       // past the allowance too
    }

    /// Before the app has handed over anything the widgets show no example numbers: no hours, days or tiles, a dash
    /// for every temperature, the wind and the lock-screen lines; the gallery's sample keeps its numbers
    func testWidgetPlaceholderHasNoNumbers() {
        let w = WeatherSnapshot.waiting
        XCTAssertTrue(w.isWaiting)
        XCTAssertTrue(w.scene.hours.isEmpty); XCTAssertTrue(w.scene.days.isEmpty); XCTAssertTrue(w.scene.tiles.isEmpty)
        XCTAssertEqual(w.deg(w.scene.temp), "–"); XCTAssertEqual(w.degNumber(w.scene.hi), "–"); XCTAssertEqual(w.windText(3), "–")
        for k: LockInlineView.Kind in [.temp, .rain, .uv, .sun, .wind] { XCTAssertEqual(LockInlineView.line(k, w).1, "–", "\(k)") }
        XCTAssertEqual(LockInlineView.line(.place, w).1, w.placeShort)
        XCTAssertEqual(LockInlineView.line(.dust, w).1, "\(L("미세먼지")) · Plus")
        // nor the example's advice: no umbrella, no "vs yesterday", no 미세먼지 grade, no rain chance on the watch
        XCTAssertEqual(w.scene.rain, "none"); XCTAssertEqual(w.scene.yday, 0); XCTAssertNil(w.scene.dust)
        XCTAssertFalse(LockText.inline(w).contains(L("우산")), LockText.inline(w))
        XCTAssertFalse(LockText.inline(w).contains(L("큰 일교차")), LockText.inline(w))
        XCTAssertEqual(Compact.tail(w.scene, deg: w.deg, weather: true), L("최저 %@", "–"))
        XCTAssertEqual(WatchFacts(snap: w).chanceText, "–")
        XCTAssertEqual(WatchFacts(snap: .sample).chanceText, "\(WatchFacts(snap: .sample).chance)%")
        // the gallery preview and a real saved forecast are not the placeholder
        let sample = WeatherSnapshot.sample
        XCTAssertFalse(sample.isWaiting)
        XCTAssertEqual(sample.deg(18), "18°"); XCTAssertEqual(sample.degNumber(18), "18")
        var real = WeatherSnapshot(scene: SceneLibrary.scene("clear"), character: .cat, plus: false, characterName: "", placeShort: "", saved: .distantPast)
        XCTAssertFalse(real.isWaiting)                                   // not marked as an example
        real.unitF = true
        XCTAssertEqual(real.deg(20), "68°")
    }

    /// The time an offline forecast is from: the clock today, the date with it on another day
    func testFetchedLabelSaysTheDay() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 14, minute: 0))!
        let today = cal.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 9, minute: 5))!
        let before = cal.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 13, minute: 40))!
        XCTAssertEqual(AppModel.fetchedLabel(today, now: now, clock12: false, calendar: cal), HourLabel.clock(9 * 60 + 5, clock12: false))
        let old = AppModel.fetchedLabel(before, now: now, clock12: false, calendar: cal)
        XCTAssertTrue(old.hasPrefix(DayLogText.day("2026-11-01")), old)
        XCTAssertTrue(old.hasSuffix(HourLabel.clock(13 * 60 + 40, clock12: false)), old)
    }

    private func agingSnap(savedAt saved: Date, hours: String, days: [WeatherScene.DayRow]) throws -> WeatherSnapshot {
        var s = SceneLibrary.scene("maybe")
        s.temp = 12; s.feels = 11; s.hi = 19; s.lo = 8; s.yday = 2; s.time = "day"
        s.rain = "umbrella"; s.level = 7
        s.hours = try JSONDecoder().decode([WeatherScene.HourRow].self, from: Data(hours.utf8))
        s.days = days
        return WeatherSnapshot(scene: s, character: .cat, plus: true, characterName: "보리", placeShort: "마포구",
                               saved: saved, place: Place.here)
    }

    /// The widgets age their saved forecast by the clock: an hour on, that hour's row becomes "지금" (its
    /// temperature, the clock, the rain amounts); fresh, sample and waiting snapshots are untouched
    func testWidgetAgesWithTheHourlyForecast() throws {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let saved = cal.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 9, minute: 10))!
        let snap = try agingSnap(savedAt: saved,
                                 hours: #"[["지금","raincloud",12,70,1.2],["10시","raincloud",13,70,2],["11시","cloud",14,40,0],["12시","cloud",15,10,0],["13시","sun",16,0,0]]"#,
                                 days: [.init(name: "오늘", icon: "raincloud", chance: 70, lo: 8, hi: 19)])
        let at = cal.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 11, minute: 20))!
        let aged = snap.aged(at: at)
        XCTAssertEqual(aged.scene.temp, 14)
        XCTAssertEqual(aged.scene.feels, 14)
        XCTAssertEqual(aged.scene.hours.map(\.label), ["지금", "12시", "13시"])
        XCTAssertEqual(aged.scene.clock, "11:20")
        XCTAssertEqual(aged.deg(aged.scene.temp), "14°")
        XCTAssertEqual(aged.scene.hi, 19, "the same day keeps its range")
        XCTAssertEqual(aged.scene.yday, 2, "the same day keeps its vs-yesterday line")
        XCTAssertFalse(aged.stale)
        XCTAssertEqual(aged.scene.level, 7, "the outfit stays as the last real feels-like chose it")
        // the rain line follows the hour: it was raining at 9 (1.2mm), the 11-o'clock row is dry
        XCTAssertEqual(snap.scene.hours[0].mm, 1.2, accuracy: 0.01)
        XCTAssertLessThan(aged.scene.hours[0].mm, 0.1)
        // under an hour: unchanged
        XCTAssertEqual(snap.aged(at: saved.addingTimeInterval(1800)).scene.temp, 12)
        // sample and waiting: unchanged
        XCTAssertTrue(WeatherSnapshot.sample.aged(at: at).isSample)
        XCTAssertTrue(WeatherSnapshot.waiting.aged(at: at).isWaiting)
    }

    /// Midnight turns the day list: the new day's name says 오늘, its range takes over, and the lines that
    /// compared with a day now gone ("어제보다", the day's 미세먼지) are dropped
    func testWidgetAgingAcrossMidnight() throws {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let saved = cal.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 23, minute: 30))!
        let snap = try agingSnap(savedAt: saved,
                                 hours: #"[["지금","cloud",10,10,0],["0시","cloud",9,10,0],["1시","cloud",8,10,0],["2시","cloud",8,10,0]]"#,
                                 days: [.init(name: "오늘", icon: "cloud", chance: 10, lo: 8, hi: 19),
                                        .init(name: "내일", icon: "sun", chance: 0, lo: 6, hi: 15),
                                        .init(name: "금", icon: "sun", chance: 0, lo: 5, hi: 14)])
        let at = cal.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 1, minute: 10))!
        let aged = snap.aged(at: at)
        XCTAssertEqual(aged.scene.temp, 8)
        XCTAssertEqual(aged.scene.days.map(\.name), [L("오늘"), L("내일")])
        XCTAssertEqual(aged.scene.hi, 15); XCTAssertEqual(aged.scene.lo, 6)
        XCTAssertEqual(aged.scene.yday, 0)
        XCTAssertNil(aged.scene.dust)
        XCTAssertEqual(aged.scene.time, "night")
    }

    /// Past the last forecast hour nothing is invented: the dashes of the waiting look, and the bubble asks for
    /// the app — on every number the widgets and complications show
    func testWidgetAgingBeyondTheForecast() throws {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let saved = cal.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 9, minute: 10))!
        let snap = try agingSnap(savedAt: saved,
                                 hours: #"[["지금","raincloud",12,70,1.2],["10시","raincloud",13,70,2]]"#,
                                 days: [.init(name: "오늘", icon: "raincloud", chance: 70, lo: 8, hi: 19)])
        let aged = snap.aged(at: cal.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 15, minute: 0))!)
        XCTAssertTrue(aged.stale); XCTAssertTrue(aged.showsDashes); XCTAssertFalse(aged.isWaiting)
        XCTAssertEqual(aged.deg(aged.scene.temp), "–")
        XCTAssertEqual(aged.degNumber(aged.scene.lo), "–")
        XCTAssertEqual(aged.windText(4), "–")
        XCTAssertTrue(aged.scene.hours.isEmpty); XCTAssertTrue(aged.scene.days.isEmpty)
        XCTAssertEqual(aged.scene.cond, L("앱을 열어 주세요"))
        XCTAssertEqual(aged.scene.yday, 0); XCTAssertNil(aged.scene.dust)
        XCTAssertEqual(aged.placeShort, "마포구", "the place still names the widget")
    }

    /// The widget timeline holds one entry per hour of the place's clock, each aged to its moment
    func testTimelineEntriesAreHourly() throws {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let saved = cal.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 9, minute: 10))!
        let snap = try agingSnap(savedAt: saved,
                                 hours: #"[["지금","raincloud",12,70,1.2],["10시","raincloud",13,70,2],["11시","cloud",14,40,0],["12시","cloud",15,10,0],["13시","sun",16,0,0]]"#,
                                 days: [.init(name: "오늘", icon: "raincloud", chance: 70, lo: 8, hi: 19)])
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 9, minute: 40))!
        let until = cal.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 13, minute: 0))!
        let entries = snap.timelineEntries(now: now, until: until)
        XCTAssertEqual(entries.map { cal.dateComponents([.hour, .minute], from: $0.date) }.map { "\($0.hour!):\($0.minute!)" },
                       ["9:40", "10:0", "11:0", "12:0"])
        XCTAssertEqual(entries[0].snap.scene.temp, 12, "fresh at first")
        XCTAssertEqual(entries[2].snap.scene.temp, 14, "the 11-o'clock entry carries the 11-o'clock row")
        XCTAssertEqual(snap.timelineEntries(now: now, until: until, cap: 2).count, 2)
        XCTAssertEqual(WeatherSnapshot.sample.timelineEntries(now: now, until: until).count, 1, "a sample has nothing to age")
    }

    private func stampScene(temp: Int = 12, rain: Bool = false, mm: Double = 1.0) throws -> WeatherScene {
        var s = WeatherScene(); s.temp = temp; s.feels = temp; s.precip = rain ? "rain" : "none"
        let icon = rain ? "raincloud" : "sun", chance = rain ? 70 : 0
        s.days = [WeatherScene.DayRow(name: "오늘", icon: icon, chance: chance, lo: temp - 3, hi: temp + 3)]
        s.hours = try JSONDecoder().decode([WeatherScene.HourRow].self, from: Data("[[\"지금\",\"\(icon)\",\(temp),\(chance),\(rain ? mm : 0)]]".utf8))
        return s
    }
    private func herePlace(lat: Double, lon: Double, tz: String, region: String, short: String) -> Place {
        Place(id: "here", name: short, short: short, lat: lat, lon: lon, region: region, timeZone: tz, sample: "maybe", ko: nil)
    }

    /// Holiday names in the 달력: the cell's short table (ko and ja), substitutes, temporaries and elections by
    /// pattern, 크리스마스 everywhere, and no short form for other languages (the fit rule decides there)
    func testHolidayCellNames() {
        XCTAssertEqual(HolidayNames.short("기독탄신일"), "크리스마스")
        XCTAssertEqual(HolidayNames.short("신정"), "새해")
        XCTAssertEqual(HolidayNames.short("설날 연휴"), "설 연휴")
        XCTAssertEqual(HolidayNames.short("설날"), "설날")
        XCTAssertEqual(HolidayNames.short("부처님오신날"), "석가탄신일")
        XCTAssertEqual(HolidayNames.short("개천절 대체공휴일"), "대체휴일")
        XCTAssertEqual(HolidayNames.short("임시공휴일"), "임시휴일")
        XCTAssertEqual(HolidayNames.short("대통령 선거일"), "선거일")
        XCTAssertEqual(HolidayNames.short("建国記念の日"), "建国記念")
        XCTAssertEqual(HolidayNames.short("スポーツの日"), "スポーツ")
        XCTAssertEqual(HolidayNames.short("振替休日"), "振替休日")
        XCTAssertNil(HolidayNames.short("Thanksgiving"), "other languages go by the fit rule")
        XCTAssertEqual(HolidayNames.display("기독탄신일"), "크리스마스")
        XCTAssertEqual(HolidayNames.display("설날 대체공휴일"), "설날 대체휴일")
        XCTAssertEqual(HolidayNames.display("부처님오신날"), "부처님오신날", "the full name stays in the list")
    }

    /// The stays: consecutive days in one city are one run; the country or city changing ends it, and records too
    /// old to carry a city fall back to the 30-km rule; the flag comes from the country code or stays letters
    func testStaysOnTheTimeline() {
        func day(_ d: String, cc: String? = nil, city: String? = nil, lat: Double? = nil, lon: Double? = nil) -> DayRecord {
            var r = DayRecord(date: d, hi: 10, lo: 3, icon: "sun"); r.cc = cc; r.city = city; r.lat = lat; r.lon = lon; return r
        }
        let trip = [day("2026-11-01", cc: "KR", city: "서울"), day("2026-11-02", cc: "KR", city: "서울"),
                    day("2026-11-03", cc: "JP", city: "도쿄"), day("2026-11-05", cc: "JP", city: "도쿄"),
                    day("2026-11-06", cc: "KR", city: "서울")]
        let stays = Stays.make(trip)
        XCTAssertEqual(stays.map(\.city), ["서울", "도쿄", "서울"])
        XCTAssertEqual(stays.map(\.days), [2, 2, 1])
        XCTAssertEqual(stays[1].from, "2026-11-03"); XCTAssertEqual(stays[1].to, "2026-11-05")
        // old records without a city: over 30 km ends the stay, under it does not
        let old = [day("2026-10-01", lat: 37.57, lon: 126.98), day("2026-10-02", lat: 37.50, lon: 127.03),
                   day("2026-10-03", lat: 35.18, lon: 129.07)]
        XCTAssertEqual(Stays.make(old).count, 2, "9 km stays, 320 km does not")
        XCTAssertEqual(Stay.flag("KR"), "🇰🇷"); XCTAssertEqual(Stay.flag("JP"), "🇯🇵")
        XCTAssertNil(Stay.flag(nil)); XCTAssertNil(Stay.flag("ZZZ"))
        // the day sheet's full place: the city with the district
        var r = day("2026-11-01", cc: "KR", city: "서울"); r.place = "마포구"; r.placeKo = "마포구"
        Lang.current = .ko
        XCTAssertEqual(r.fullPlaceName(), "서울 마포구")
        XCTAssertEqual(day("2025-01-01").fullPlaceName(), "", "no invented place on an old record")
    }

    /// The midnight stamp: the last look before midnight decides the day and its country; a Seoul → LA flight
    /// lives one date twice and keeps LA's record; the date line can skip a day with nothing invented; the app
    /// and a widget write the same day as one; old records carry no stamp and show none
    func testMidnightLocationStamp() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let log = DayLog(dir: dir)
        let seoul = herePlace(lat: 37.57, lon: 126.98, tz: "Asia/Seoul", region: "kr", short: "마포구")
        let la = herePlace(lat: 34.05, lon: -118.24, tz: "America/Los_Angeles", region: "us", short: "LA")
        var kst = Calendar(identifier: .gregorian); kst.timeZone = TimeZone(identifier: "Asia/Seoul")!
        var pt = Calendar(identifier: .gregorian); pt.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        // Seoul, Nov 5 22:00 KST — then LA, where Nov 5 comes round again (Nov 6 10:00 KST = Nov 5 17:00 PT)
        let inSeoul = kst.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 22))!
        let inLA = kst.date(from: DateComponents(year: 2026, month: 11, day: 6, hour: 10))!
        log.record(try stampScene(rain: true), place: seoul, plus: true, at: inSeoul)
        log.record(try stampScene(temp: 20), place: la, plus: true, at: inLA)
        var days = log.records("here")
        XCTAssertEqual(days.map(\.date), ["2026-11-05"], "the repeated date is one day, the last look's")
        XCTAssertEqual(days[0].cc, "US"); XCTAssertEqual(days[0].tz, "America/Los_Angeles")
        XCTAssertEqual(days[0].confirmed, inLA)
        XCTAssertNil(days[0].wet, "the restart at the new city drops the other city's rain")
        // the other way the date line skips a day: LA Nov 6 18:00 PT, then Seoul when it is already Nov 8
        let backHome = kst.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 9))!
        log.record(try stampScene(temp: 20), place: la, plus: true, at: pt.date(from: DateComponents(year: 2026, month: 11, day: 6, hour: 18))!)
        log.record(try stampScene(temp: 5, rain: true), place: seoul, plus: true, at: backHome)
        days = log.records("here")
        XCTAssertEqual(days.map(\.date), ["2026-11-05", "2026-11-06", "2026-11-08"], "the skipped date simply has no day")
        // an ordinary commute (> 5 km, same city scale) keeps the morning's seen rain and temperatures
        let gangnam = herePlace(lat: 37.50, lon: 127.03, tz: "Asia/Seoul", region: "kr", short: "강남구")
        let morning = kst.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 9, minute: 30))!
        log.record(try stampScene(temp: 12), place: gangnam, plus: true, at: morning.addingTimeInterval(3600))
        let today = log.records("here").last!
        XCTAssertEqual(today.date, "2026-11-08")
        XCTAssertEqual(today.wet, "rain", "the 9-km commute kept the morning's rain")
        XCTAssertEqual(today.seenLo, 5, "and the morning's temperature")
        XCTAssertEqual(today.place, "강남구", "while the name follows the newest look")
        // a real city change (> 30 km) still starts the day over
        let incheonFar = herePlace(lat: 37.46, lon: 126.44, tz: "Asia/Seoul", region: "kr", short: "인천")
        log.record(try stampScene(temp: 12), place: incheonFar, plus: true, at: morning.addingTimeInterval(7200))
        XCTAssertEqual(log.records("here").last!.seenLo, 12, "a 50-km move starts the day over there")
        XCTAssertNil(log.records("here").last!.wet, "with none of the other city's rain")
        // the widget writes through its own DayLog instance into the same day
        let widgetLog = DayLog(dir: dir)
        widgetLog.record(try stampScene(temp: 9), place: incheonFar, plus: true, at: morning.addingTimeInterval(10800))
        let merged = log.records("here").last!
        XCTAssertEqual(merged.seenLo, 9, "the app's and the widget's writes fold into one record")
        // an old record without the stamp: decodes with nothing, and the day sheet shows nothing
        let legacy = try JSONDecoder().decode(DayRecord.self, from: Data(#"{"date":"2025-01-01","hi":5,"lo":-2,"icon":"sun"}"#.utf8))
        XCTAssertNil(legacy.cc); XCTAssertNil(legacy.confirmed)
        XCTAssertNil(DayDetailView.confirmedLine(nil, tz: .current, clock12: false))
        // the honest wording: near midnight it is the day's place; earlier it is only the last confirmation
        let night = kst.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 23, minute: 55))!
        XCTAssertEqual(DayDetailView.confirmedLine(night, tz: TimeZone(identifier: "Asia/Seoul")!, clock12: false), L("밤 %@ 위치", "11:55"))
        let evening = kst.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 18, minute: 12))!
        XCTAssertEqual(DayDetailView.confirmedLine(evening, tz: TimeZone(identifier: "Asia/Seoul")!, clock12: true),
                       L("마지막 확인 %@", HourLabel.clock(18 * 60 + 12, clock12: true)))
        // the widget's closing refresh stays at 23:55 local across the DST fall-back night
        let next = pt.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 20))!.addingTimeInterval(12 * 3600)
        let close = DayLog.closingRefresh(after: pt.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 20))!, regular: next, tz: pt.timeZone)
        XCTAssertNotNil(close)
        if let c = close { XCTAssertEqual(pt.component(.hour, from: c), 23); XCTAssertEqual(pt.component(.minute, from: c), 55) }
    }

    /// One calendar: the timeline is the "here" log; a user with location off gets their first saved place; and
    /// removing places (or turning location off) never erases the timeline file
    func testOneCalendarTimeline() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let log = DayLog(dir: dir)
        var seoul = DayRecord(date: "2026-11-01", hi: 18, lo: 9, icon: "sun"); seoul.seenHi = 17; seoul.plus = true
        var tokyo = DayRecord(date: "2026-11-02", hi: 20, lo: 12, icon: "cloud"); tokyo.seenHi = 19; tokyo.plus = true
        log.save([seoul], for: "here")
        log.save([tokyo], for: "tokyo")
        let places = [Place.here, Place(id: "tokyo", name: "도쿄", short: "도쿄", lat: 35.68, lon: 139.69, region: "jp", timeZone: "Asia/Tokyo", sample: "maybe", ko: nil)]
        // the "here" log wins: looking at 도쿄 (its own file) never marks the timeline
        XCTAssertEqual(AppModel.timeline(from: log, places: places).map(\.date), ["2026-11-01"])
        // no "here" days (location off): the first saved place stands in
        log.save([], for: "here")
        XCTAssertEqual(AppModel.timeline(from: log, places: places).map(\.date), ["2026-11-02"])
        // keepOnly: removed places lose their file, the timeline never does
        log.save([seoul], for: "here")
        log.keepOnly([])
        XCTAssertEqual(log.records("here").count, 1, "the timeline survives an empty place list")
        XCTAssertEqual(log.records("tokyo").count, 0, "a removed place loses its days")
    }

    /// A 날씨 기록 day speaks in the past tense: every present-tense sentence the day sheet can show for a past
    /// day has a past form, none of the past forms gives advice, and all 12 languages translate each one (a
    /// missing entry would fall back to the Korean key, which the test catches)
    func testPastDayWordsAreInThePastTense() {
        XCTAssertEqual(PastWords.said.count, 23)
        XCTAssertEqual(PastWords.key("%@ %@이에요.", past: true), "%@ %@이었어요.")        // 미세먼지 좋음"이었어요"
        XCTAssertEqual(PastWords.key("%@ %@이에요.", past: false), "%@ %@이에요.")
        XCTAssertEqual(PastWords.key("바람이 약해요.", past: true), "바람이 약했어요.")
        XCTAssertEqual(PastWords.key("자외선이 약해요.", past: true), "자외선이 약했어요.")
        XCTAssertEqual(PastWords.key("체감 %@~%@, %@ 날이에요.", past: true), "체감 %@~%@, %@ 날이었어요.")
        for (present, past) in PastWords.said {
            XCTAssertNotEqual(present, past, present)
            for bad in ["좋아요", "주세요", "챙기", "조심", "느껴져요", "이에요.", "해요.", "세요.", "예요."] {
                XCTAssertFalse(past.contains(bad), "a present-tense or advice word on a past day: \(past)")
            }
            for l in Lang.allCases where l != .ko {
                XCTAssertNotEqual(l.string(past), past, "\(l.rawValue): no translation for \(past)")
            }
        }
    }

    /// 날씨 달력 browses to December four years on (the holiday tables' reach), never further, and back to the
    /// first record; the debug shift walks there and home across the years
    func testCalendarBrowsesFourYearsAhead() {
        XCTAssertEqual(DayLogText.lastMonth(from: "2026-11"), "2030-12")
        XCTAssertEqual(DayLogText.lastMonth(from: "2027-01"), "2031-12")
        XCTAssertEqual(DayLogText.shift("2026-11", by: 49), "2030-12")
        XCTAssertEqual(DayLogText.shift("2030-12", by: -49), "2026-11")
        XCTAssertEqual(DayLogText.length("2030-12"), 31)
    }

    /// 아침 요약 for a week: morning0…6 at the chosen time, today's first while that time is ahead; numbers only in the
    /// next three; nothing when notifications are not allowed or the summary is off; every id (the older single
    /// "morning" too) cleared before planning; Plus still adds its own lines, free does not
    func testMorningSummaryWeek() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let time = cal.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 7, minute: 30))!
        let early = cal.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 5, minute: 0))!
        let late = cal.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 9, minute: 0))!
        let s = SceneLibrary.scene("maybe")
        var place = Place.here; place.short = "마포구"; place.name = "서울 마포구"
        func plan(_ now: Date, plus: Bool = false, scene: WeatherScene? = nil) -> [Notifications.Morning] {
            Notifications.mornings(scene ?? s, place: place, morningTime: time, unitF: false, plus: plus, now: now, calendar: cal)
        }
        let week = plan(early)
        XCTAssertEqual(week.map(\.id), (0..<7).map { "morning\($0)" })
        XCTAssertEqual(week.map { $0.at.day }, [4, 5, 6, 7, 8, 9, 10])          // today's while 7:30 is ahead
        XCTAssertTrue(week.allSatisfy { $0.at.hour == 7 && $0.at.minute == 30 && $0.at.month == 11 })
        XCTAssertEqual(plan(late).map { $0.at.day }, [5, 6, 7, 8, 9, 10, 11])   // 7:30 has passed: from tomorrow
        // numbers for days 0–2 only (that day's range), none at all for days 3–6
        XCTAssertEqual(week[0].title, L("%@ · 오늘 %@ ~ %@", "마포구", "\(s.days[0].lo)°", "\(s.days[0].hi)°"))
        XCTAssertEqual(plan(late)[0].title, L("%@ · 오늘 %@ ~ %@", "마포구", "\(s.days[1].lo)°", "\(s.days[1].hi)°"))
        for m in week.prefix(3) { XCTAssertTrue(m.title.contains("°"), m.title) }
        for m in week.dropFirst(3) {
            XCTAssertNil(m.title.rangeOfCharacter(from: .decimalDigits), m.title)
            XCTAssertNil(m.body.rangeOfCharacter(from: .decimalDigits), m.body)
            XCTAssertFalse(m.title.contains("°") || m.body.contains("°") || m.body.contains("%"), m.body)
        }
        // not allowed, or the summary off: nothing pending; every id cleared first (the one-summary "morning" too)
        XCTAssertTrue(Notifications.morningPlan(allowed: false, enabled: true, scene: s, place: place, morningTime: time, unitF: false, plus: true, now: early, calendar: cal).isEmpty)
        XCTAssertTrue(Notifications.morningPlan(allowed: true, enabled: false, scene: s, place: place, morningTime: time, unitF: false, plus: true, now: early, calendar: cal).isEmpty)
        XCTAssertEqual(Notifications.morningPlan(allowed: true, enabled: true, scene: s, place: place, morningTime: time, unitF: false, plus: false, now: early, calendar: cal), week)
        XCTAssertTrue(Set(Notifications.ids).isSuperset(of: Set(week.map(\.id) + ["morning", "rain", "change", "monthly"])))
        // free and Plus as before: the day-to-day change is a Plus line (today's summary only)
        var warmer = s; warmer.yday = 3; warmer.alert = nil
        let said = L("어제보다 %d° 높아요", 3)
        XCTAssertTrue(plan(early, plus: true, scene: warmer)[0].body.contains(said))
        XCTAssertFalse(plan(early, plus: false, scene: warmer)[0].body.contains(said))
        XCTAssertFalse(plan(early, plus: true, scene: warmer)[1].body.contains(said))     // tomorrow's is not "vs yesterday"
        // a short forecast: the days it has, the plain reminder after
        var short = s; short.days = Array(s.days.prefix(2))
        let few = plan(early, scene: short)
        XCTAssertTrue(few[1].title.contains("°")); XCTAssertEqual(few[2].title, "마포구")
    }

    /// Only Plus is registered with the server (its pushes are Plus-only): a free device posts nothing; becoming Plus
    /// registers; losing Plus forgets the device once and then sends nothing; the alert toggles stay on the phone and
    /// go with every registration, so a forget loses none of them
    func testDeviceRegistrationFollowsPlus() {
        // free: nothing posted; a device the server may know from before (it had a push token) is forgotten once
        XCTAssertEqual(LiveActivities.step(plus: false, hasToken: false, forgotten: false), .nothing)
        XCTAssertEqual(LiveActivities.step(plus: false, hasToken: true, forgotten: false), .forget)
        XCTAssertEqual(LiveActivities.step(plus: false, hasToken: true, forgotten: true), .nothing)
        // free → Plus: registered once ActivityKit has handed out a token
        XCTAssertEqual(LiveActivities.step(plus: true, hasToken: true, forgotten: true), .register)
        XCTAssertEqual(LiveActivities.step(plus: true, hasToken: false, forgotten: true), .nothing)
        XCTAssertEqual(LiveActivities.step(plus: true, hasToken: true, forgotten: false), .register)
        // Plus → free (a lapse seen at launch too): forgotten, then quiet
        XCTAssertEqual(LiveActivities.step(plus: false, hasToken: true, forgotten: false), .forget)
        // the registration says Plus and carries the phone's toggles as they are now
        var p = Place.here; p.lat = 37.5665; p.lon = 126.978
        for (rain, alert) in [(false, true), (true, false)] {
            let b = LiveActivities.body(id: "dev", place: p, lang: "ko", character: .brit, start: "ab12", rain: rain, alert: alert)
            XCTAssertEqual(b["plan"] as? String, "plus")
            XCTAssertEqual(b["rain"] as? Bool, rain); XCTAssertEqual(b["alert"] as? Bool, alert)
            XCTAssertEqual(b["lat"] as? Double, 37.57); XCTAssertEqual(b["lon"] as? Double, 126.98)   // ~1 km, as before
            XCTAssertEqual(b["start"] as? String, "ab12"); XCTAssertEqual(b["char"] as? String, "brit")
        }
    }

    func testMonthReport() {
        func day(_ d: String, _ hi: Int, _ lo: Int, wet: String? = nil, dust: Int? = nil) -> DayRecord {
            var r = DayRecord(date: d, hi: hi, lo: lo, icon: wet == nil ? "sun" : "raincloud"); r.wet = wet; r.dust = dust; return r
        }
        var all = (1...10).map { day(String(format: "2026-10-%02d", $0), 20, 12) }
        all += [day("2026-11-01", 15, 8, wet: "rain", dust: 2), day("2026-11-02", 18, 9, dust: 0), day("2026-11-03", 12, 2, wet: "snow", dust: 3)]
        all += (4...9).map { day(String(format: "2026-11-%02d", $0), 14, 6) }
        let m = MonthReport.make(all, month: "2026-11")
        XCTAssertEqual(m.days, 9)
        XCTAssertEqual(m.wetDays, 2)
        XCTAssertEqual(m.snowDays, 1)
        XCTAssertEqual(m.hottest?.date, "2026-11-02")
        XCTAssertEqual(m.coldest?.date, "2026-11-03")
        XCTAssertEqual(m.dustDays, 2)
        XCTAssertEqual(m.vsLast, -6)                // about 10° a day against October's 16°
        XCTAssertNil(MonthReport.make(all, month: "2026-10").vsLast)   // September has no days
        XCTAssertEqual(MonthReport.previous("2026-01"), "2025-12")
    }

    /// The day is where the phone was as it ended: "지금 위치" moving far starts the day over there (a few km does
    /// not); the character shown is kept; an observed day from elsewhere does not overwrite it
    func testDayLogFollowsWhereTheDayEnded() throws {
        let log = dayLog()
        var s = scene(temp: 12, hi: 15, lo: 8, icon: "cloud", chance: 10)
        let rows = #"[[["0시",9,10,2,0,80],["3시",8,10,3,0,85],["6시",8,20,3,0,88],["9시",11,40,4,2,70],["12시",14,60,6,4,60],["15시",15,70,7,3,65],["18시",12,50,5,0,75],["21시",10,20,3,0,80]]]"#
        s.dayDetail = try JSONDecoder().decode([[WeatherScene.DayHour]].self, from: Data(rows.utf8))
        var home = Place.here; home.timeZone = "Asia/Seoul"; home.lat = 37.56; home.lon = 126.90
        let t = Date(timeIntervalSince1970: 1_780_000_000)
        log.record(s, place: home, character: .cat, at: t)
        var r = try XCTUnwrap(log.records("here").last)
        XCTAssertEqual(r.char, "cat")
        let feels = try XCTUnwrap(r.feels)
        XCTAssertLessThan(feels, 11.5)              // night and wind pull the day's feels-like under its middle
        XCTAssertEqual(r.level, Rules.level(feels: feels))
        // on to 수원 (~35 km): the day starts over there
        var trip = home; trip.short = "수원"; trip.lat = 37.26; trip.lon = 127.03
        var s2 = s; s2.temp = 20; s2.days = [WeatherScene.DayRow(name: "오늘", icon: "sun", chance: 0, lo: 10, hi: 21)]
        log.record(s2, place: trip, character: .abys, at: t.addingTimeInterval(3600))
        r = try XCTUnwrap(log.records("here").last)
        XCTAssertEqual(log.records("here").count, 1)
        XCTAssertEqual(r.place, "수원")
        XCTAssertEqual(r.lo, 10)                    // not the morning's 8 at home
        XCTAssertEqual(r.character, .abys)
        // a couple of km more is still the same day
        var near = trip; near.lat += 0.02
        s2.temp = 22
        log.record(s2, place: near, character: .abys, at: t.addingTimeInterval(7200))
        XCTAssertEqual(log.records("here").last?.seenLo, 20)
        // observations for home do not overwrite a day spent in 수원; observations for 수원 do
        var o = DayRecord(date: r.date, hi: 30, lo: 25, icon: "sun"); o.obs = true
        log.merge([o], placeID: "here", near: (home.lat, home.lon))
        XCTAssertEqual(log.records("here").last?.hi, 22)
        log.merge([o], placeID: "here", near: (trip.lat, trip.lon))
        XCTAssertEqual(log.records("here").last?.hi, 30)
        // the report shows the character of most days
        var a = (1...3).map { DayRecord(date: "2026-11-0\($0)", hi: 10, lo: 2, icon: "sun") }
        a[0].char = "abys"; a[1].char = "abys"; a[2].char = "cat"
        XCTAssertEqual(MonthReport.make(a, month: "2026-11").character, .abys)
    }

    /// Korean places in every language: the Revised Romanization with its sound changes, the Kontsevich Cyrillic,
    /// Chinese characters for 시도 and 시군구; a name the language cannot read is never kept
    func testKoreanPlaceNamesInEveryLanguage() {
        XCTAssertEqual(KoreanNames.latin("오류동"), "Oryu-dong")
        XCTAssertEqual(KoreanNames.latin("종로구"), "Jongno-gu")
        XCTAssertEqual(KoreanNames.latin("신림동"), "Sillim-dong")
        XCTAssertEqual(KoreanNames.latin("왕십리"), "Wangsimni")
        XCTAssertEqual(KoreanNames.latin("삼성1동"), "Samseong 1-dong")
        XCTAssertEqual(KoreanNames.cyrillic("오류동"), "Орю-дон")
        XCTAssertEqual(KoreanNames.cyrillic("강남구"), "Каннам-гу")
        XCTAssertEqual(KoreanNames.chinese("구로구"), "九老区")
        XCTAssertEqual(KoreanNames.chinese("고성군", province: "경남"), "固城郡")
        XCTAssertNil(KoreanNames.chinese("오류동"))
        XCTAssertEqual(KoreanNames.name("서울 오류동", .zhHant), "首爾 Oryu-dong")
        XCTAssertEqual(KoreanNames.name("경기 수원시 영통구", .zhHans), "京畿道水原市灵通区")
        XCTAssertEqual(KoreanNames.name("서울 오류동", .fr), "Séoul Oryu-dong")
        XCTAssertEqual(KoreanNames.name("서울 오류동", .ru), "Сеул Орю-дон")
        XCTAssertEqual(KoreanNames.name("서울 오류동", .es), "Seúl Oryu-dong")
        XCTAssertFalse(Lang.zhHans.reads("서울 오류동"))
        XCTAssertTrue(Lang.zhHans.reads("首尔 九老区"))
        XCTAssertFalse(Lang.es.reads("東京"))
        XCTAssertTrue(Lang.fr.reads("Île-de-France"))
        XCTAssertTrue(Lang.ru.reads("Сеул"))
        // a saved Korean place renamed for the language
        let p = Place(id: "here", name: "서울 오류동", short: "오류동", lat: 37.49, lon: 126.84, region: "kr", timeZone: "Asia/Seoul", sample: "maybe", ko: "서울 오류동")
        XCTAssertEqual(HerePlace.koreanNamed(p, .zhHans).short, "Oryu-dong")
        XCTAssertEqual(HerePlace.koreanNamed(p, .ru).name, "Сеул Орю-дон")
        XCTAssertEqual(HerePlace.koreanNamed(p, .de).name, "Seoul Oryu-dong")
        XCTAssertEqual(HerePlace.koreanNamed(p, .ja).short, "オリュドン")
        // a day keeps its Korean place and shows it in the language of now
        var r = DayRecord(date: "2026-11-03", hi: 10, lo: 2, icon: "sun"); r.place = "오류동"; r.placeKo = "오류동"
        XCTAssertEqual(r.placeName(.en), "Oryu-dong")
        XCTAssertEqual(r.placeName(.ko), "오류동")
    }

    /// The home cards: the saved order kept, a card new to it placed after the one it follows by default; tiles
    /// always two to a row — they trade places with each other and move among the whole cards in pairs
    func testHomeCardOrder() {
        let present = ["hourly", "daily", "wind", "week", "tile0", "tile1", "tile2", "tile3", "dust"]
        let d = HomeLayout.order(saved: [], present: present, tiles: 4)
        XCTAssertEqual(d, ["hourly", "daily", "tile0", "tile1", "dust", "wind", "tile2", "tile3", "week"])
        // an order with tiles apart: put back two by two
        let o = HomeLayout.order(saved: ["week", "hourly", "tile1", "daily", "tile0", "wind", "tile2", "tile3"], present: present + ["air"], tiles: 4)
        XCTAssertEqual(HomeLayout.rows(o), [["week"], ["hourly"], ["tile1", "tile0"], ["dust"], ["air"], ["daily"], ["wind"], ["tile2", "tile3"]])
        XCTAssertFalse(HomeLayout.rows(HomeLayout.order(saved: ["week", "tile1", "wind", "tile0"], present: present, tiles: 4)).contains { $0.count == 1 && HomeLayout.isHalf($0[0]) })
        // a whole card over a pair: above it coming up, below it going down
        XCTAssertEqual(HomeLayout.move("week", to: "tile3", in: d), ["hourly", "daily", "tile0", "tile1", "dust", "wind", "week", "tile2", "tile3"])
        XCTAssertEqual(HomeLayout.move("hourly", to: "tile1", in: d), ["daily", "tile0", "tile1", "hourly", "dust", "wind", "tile2", "tile3", "week"])
        // a tile over a whole card: the pair goes; over a tile: the two trade places
        XCTAssertEqual(HomeLayout.move("tile0", to: "dust", in: d), ["hourly", "daily", "dust", "tile0", "tile1", "wind", "tile2", "tile3", "week"])
        XCTAssertEqual(HomeLayout.move("tile0", to: "tile3", in: d), ["hourly", "daily", "tile3", "tile1", "dust", "wind", "tile2", "tile0", "week"])
        XCTAssertEqual(HomeLayout.move("week", to: "daily", in: ["hourly", "daily", "week"]), ["hourly", "week", "daily"])
    }

    /// The lock screen's lines above the clock: each piece of the weather on its own
    func testLockScreenLines() throws {
        Lang.current = .ko
        var s = WeatherScene(); s.temp = 9; s.lo = 9; s.hi = 18
        s.days = [WeatherScene.DayRow(name: "오늘", icon: "sun", chance: 0, lo: 9, hi: 18), WeatherScene.DayRow(name: "목", icon: "raincloud", chance: 60, lo: 8, hi: 15)]
        let hours = #"[["지금","sun",9,0,0],["15시","raincloud",10,70,1.5]]"#
        s.hours = try JSONDecoder().decode([WeatherScene.HourRow].self, from: Data(hours.utf8))
        XCTAssertEqual(LockInlineView.rainLine(s), "15시쯤 비 예보")
        s.hours = []
        XCTAssertEqual(LockInlineView.rainLine(s), "내일 비 60%")
        s.days[1].chance = 10
        XCTAssertEqual(LockInlineView.rainLine(s), "10일 동안 비 소식 없어요")
        let snap = WeatherSnapshot(scene: s, character: .cat, plus: true, characterName: "", placeShort: "마포구", saved: Date())
        XCTAssertEqual(LockInlineView.line(.temp, snap).1, "9°")
        XCTAssertEqual(LockInlineView.line(.place, snap).1, "마포구")
        XCTAssertEqual(Rules.windFrom(225), "남서풍")
    }

    /// The widget's last refresh of the day comes at 23:55 where the place is, unless the regular one comes first
    func testClosingRefreshBeforeMidnight() throws {
        let tz = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        var c = Calendar(identifier: .gregorian); c.timeZone = tz
        let at = try XCTUnwrap(c.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 22, minute: 10)))
        let close = try XCTUnwrap(DayLog.closingRefresh(after: at, regular: at.addingTimeInterval(3 * 3600), tz: tz))
        XCTAssertEqual(c.component(.hour, from: close), 23)
        XCTAssertEqual(c.component(.minute, from: close), 55)
        XCTAssertNil(DayLog.closingRefresh(after: at, regular: at.addingTimeInterval(1800), tz: tz))
    }

    /// The 월간 리포트 comes on the 1st after the morning summary, about the month that just ended
    func testMonthlyReportFiresOnTheFirst() throws {
        var c = Calendar(identifier: .gregorian); c.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        let morning = try XCTUnwrap(c.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 7, minute: 0)))
        let mid = try XCTUnwrap(c.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 22)))
        let a = try XCTUnwrap(Notifications.monthlyFire(after: mid, morning: morning, calendar: c))
        XCTAssertEqual(a.month, "2026-11")
        XCTAssertEqual([a.at.year, a.at.month, a.at.day, a.at.hour, a.at.minute], [2026, 12, 1, 7, 2])
        // the 1st before the morning time: today, about the month before
        let early = try XCTUnwrap(c.date(from: DateComponents(year: 2027, month: 1, day: 1, hour: 6)))
        let b = try XCTUnwrap(Notifications.monthlyFire(after: early, morning: morning, calendar: c))
        XCTAssertEqual(b.month, "2026-12")
        XCTAssertEqual([b.at.year, b.at.month, b.at.day], [2027, 1, 1])
        // the 1st after it: next month's
        let late = try XCTUnwrap(c.date(from: DateComponents(year: 2027, month: 1, day: 1, hour: 9)))
        XCTAssertEqual(Notifications.monthlyFire(after: late, morning: morning, calendar: c)?.month, "2027-01")
    }

    /// Chinese writes no spaces: the watch bubble breaks after the time instead of showing only its icon
    func testChineseBubbleBreaksAfterTheTime() {
        Lang.current = .zhHans
        defer { Lang.current = .ko }
        var s = WeatherScene()
        s.bubble = WeatherScene.Bubble(kind: "speech", tone: "sky", icon: "umbrella", text: "16–19时有雨预报")
        XCTAssertEqual(Compact.bubbleWord(s, max: 5), "16–19时\n有雨")
        s.bubble?.text = "空气较差 · 记得戴口罩"
        XCTAssertEqual(Compact.bubbleWord(s, max: 5), "空气较差")
    }

    /// A long word with no space (Spanish "Despejado", French "Dégagé") stays in the bubble instead of leaving the icon alone
    func testLongWordBubbleKeepsItsWord() {
        Lang.current = .es
        defer { Lang.current = .ko }
        var s = WeatherScene()
        s.cond = "Despejado"
        XCTAssertEqual(Compact.bubbleWord(s, max: 5), "Despejado")
        s.cond = "Superlongwordthatcannotfit"
        XCTAssertEqual(Compact.bubbleWord(s, max: 5), "")
        // Spanish opens its exclamation too: neither mark stays in a widget's words
        s.bubble = WeatherScene.Bubble(kind: "alert", tone: "warm", icon: "moon", text: "¡Noche tropical!")
        XCTAssertEqual(Compact.head(s), "Noche tropical")
    }

    /// The calendar's day card: the temperature hour by hour (seen over forecast), rain by the hour, the day's extremes
    func testDayDetail() throws {
        var s = WeatherScene(); s.temp = 12; s.feels = 10; s.precip = "rain"
        s.days = [WeatherScene.DayRow(name: "오늘", icon: "raincloud", chance: 70, lo: 8, hi: 15)]
        s.hours = try JSONDecoder().decode([WeatherScene.HourRow].self, from: Data(#"[["지금","raincloud",12,70,1.2],["15시","raincloud",13,70,2],["16시","cloud",14,40,0],["23시","cloud",9,10,0],["0시","cloud",8,10,0]]"#.utf8))
        s.dayDetail = try JSONDecoder().decode([[WeatherScene.DayHour]].self, from: Data(#"[[["0시",9,10,2,0,80],["3시",8,10,3,0,85],["6시",8,20,3,0,88],["9시",11,40,4,2,70],["12시",14,60,6,4,60],["15시",15,70,7,3,65],["18시",12,50,5,0,75],["21시",10,20,3,0,80]]]"#.utf8))
        var r = DayRecord(date: "2026-11-03", hi: 15, lo: 8, icon: "raincloud")
        DayLog.detail(&r, s, hour: 14, place: Place.here)
        XCTAssertEqual(r.temps?[14] ?? nil, 12)          // seen now
        XCTAssertEqual(r.temps?[16] ?? nil, 14)          // the next hours' forecast
        XCTAssertEqual(r.temps?[3] ?? nil, 8)            // the day sheet's earlier points
        XCTAssertNil(r.temps?[1] ?? nil)
        XCTAssertEqual(r.rain?[14] ?? nil, 1.2)
        XCTAssertEqual(r.wetHours?.0, 14); XCTAssertEqual(r.wetHours?.1, 15)
        XCTAssertEqual(r.windMax, 7); XCTAssertEqual(r.rh, 75); XCTAssertEqual(r.uv, 4)
        XCTAssertEqual(r.seenH, [14])
    }

    /// A 날씨 기록 day opens in the day sheet: its scene has the day's rows and no "now"
    func testPastDayScene() {
        var r = DayRecord(date: "2026-11-02", hi: 19, lo: 9, icon: "raincloud")
        r.wet = "rain"
        r.temps = (0..<24).map { $0 % 3 == 0 ? 9 + $0 / 3 : nil }
        r.rain = (0..<24).map { $0 >= 15 && $0 <= 18 ? 1.5 : nil }
        r.winds = (0..<24).map { $0 % 3 == 0 ? 3 : nil }
        r.lat = 37.57; r.lon = 126.98
        let s = r.scene(tz: TimeZone(identifier: "Asia/Seoul")!)
        XCTAssertNotNil(s)
        XCTAssertEqual(s?.dayDetail?.first?.count, 8)
        XCTAssertEqual(s?.dayDetail?.first?[5].mm, 1.5)          // 15 h
        XCTAssertEqual(s?.clock, "")
        XCTAssertEqual(s?.tiles.count, 2)                          // sunrise · sunset
        XCTAssertNil(DayRecord(date: "2026-11-01", hi: 10, lo: 3, icon: "sun").scene(tz: .current))   // a summary only
    }
}
