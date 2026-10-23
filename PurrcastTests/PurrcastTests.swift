import XCTest
@testable import Purrcast

/// Logic checks that run on every GitHub build: decoding (including what the real server sends), the design's
/// rules, the free / Plus view, notifications timing, the widget snapshot.
@MainActor
final class PurrcastTests: XCTestCase {

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
        XCTAssertEqual(plus.dayDetail?.first?.count, 8)
        XCTAssertEqual(plus.bubble?.text, "2시간 뒤 비 예보")
        XCTAssertEqual(AppModel.planView(plus, plus: false).bubble?.text, "오늘 비 예보", "free plan says it loosely")
        XCTAssertNil(free.next6)
        XCTAssertEqual(free.updated, "06:00")
    }

    func testEveryExampleSceneDecodes() {
        XCTAssertEqual(SceneLibrary.all.count, SceneLibrary.order.count)
        for k in SceneLibrary.order {
            let s = SceneLibrary.scene(k)
            XCTAssertEqual(s.id, k)
            XCTAssertFalse(s.hours.isEmpty, k); XCTAssertFalse(s.days.isEmpty, k)
            XCTAssert((0...9).contains(s.level), k)
        }
    }

    func testLenientDecodingRepairsBadValues() throws {
        let json = #"""
        {"temp": 18.6, "hi": 12, "lo": 20, "level": 14, "clock": "1346",
         "wind": {"speed": 3.4, "gust": 1, "deg": -12},
         "hours": [["지금", "cloud", 18, 10, 0], ["bad"], ["15시", "rain", 17.5, null, 1.25]],
         "days": [["오늘", "sun", 0, 20, 12]],
         "tiles": [{"icon": "raindrop", "label": "습도"}],
         "bubble": {"text": "비!"}}
        """#
        let s = try JSONDecoder().decode(WeatherScene.self, from: Data(json.utf8))
        XCTAssertEqual(s.temp, 19)
        XCTAssertEqual(s.level, 9)
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

    func testClockParsing() {
        XCTAssertEqual(WeatherScene.clockMinutes("13:46"), 826)
        XCTAssertNil(WeatherScene.clockMinutes("1346"))
        XCTAssertNil(WeatherScene.clockMinutes("25:00"))
        XCTAssertNil(WeatherScene.clockMinutes(""))
    }

    // MARK: rules (must match server/src/rules.js)

    func testOutfitLevels() {
        XCTAssertEqual(Rules.level(feels: 35), 0); XCTAssertEqual(Rules.level(feels: 30), 1); XCTAssertEqual(Rules.level(feels: 25), 2)
        XCTAssertEqual(Rules.level(feels: 21), 3); XCTAssertEqual(Rules.level(feels: 18), 4); XCTAssertEqual(Rules.level(feels: 14), 5)
        XCTAssertEqual(Rules.level(feels: 10), 6); XCTAssertEqual(Rules.level(feels: 6), 7); XCTAssertEqual(Rules.level(feels: 0), 8)
        XCTAssertEqual(Rules.level(feels: -12), 9)
        XCTAssertEqual(Rules.level(feels: 19.8, previous: 4), 4)
        XCTAssertEqual(Rules.level(feels: 20.6, previous: 4), 3)
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
        XCTAssertEqual(Notifications.morningBody(d), "비 예보예요 · 우산을 챙겨 주세요")
    }
}
