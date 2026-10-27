import XCTest
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
        XCTAssertEqual(plus.dayDetail?.first?.count, 8)
        XCTAssertEqual(plus.dayDetail?.first?[5].mm, 2.8, "16 h + 17 h of rain in the 15–18 h slot")
        XCTAssertEqual(plus.dayDetail?.first?[5].gust, 7); XCTAssertEqual(plus.dayDetail?.first?[5].dir, 225)
        XCTAssertEqual(plus.bubble?.text, "16~18시 비 예정")
        XCTAssertEqual(AppModel.planView(plus, plus: false).bubble?.text, "16~18시 비 예정", "the free plan keeps the window from the morning run")
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

    /// Widgets and the watch show words with the temperature between them; official names stay as they are.
    func testCompactWords() {
        var s = WeatherScene(); s.temp = 16; s.feels = 15; s.hi = 18; s.lo = 11; s.cond = "비"; s.rain = "umbrella"
        s.bubble = WeatherScene.Bubble(kind: "speech", tone: "sky", icon: "umbrella", text: "비!")
        XCTAssertEqual(Compact.line(s, deg: { "\($0)°" }), "비 · 16° · 우산")
        s.bubble?.text = "호우주의보"
        XCTAssertEqual(Compact.head(s), "호우주의보")
        s.bubble?.text = "15~17시 비 예정"; s.rain = "bag"
        XCTAssertEqual(Compact.line(s, deg: { "\($0)°" }), "15~17시 비 · 16° · 우산")
        s.bubble?.text = "한파!"; s.rain = "none"; s.temp = -13; s.feels = -16; s.cond = "맑음 · 한파"
        XCTAssertEqual(Compact.line(s, deg: { "\($0)°" }), "한파 · -13° · 체감 -16°")
        s.bubble = nil; s.temp = 19; s.feels = 18; s.hi = 20; s.lo = 9; s.cond = "맑음"
        XCTAssertEqual(Compact.line(s, deg: { "\($0)°" }), "맑음 · 19° · 큰 일교차")
        s.bubble = WeatherScene.Bubble(kind: "speech", tone: "sky", icon: "umbrella_closed", text: "우산 챙겨요"); s.rain = "bag"; s.hi = 21
        XCTAssertEqual(Compact.line(s, deg: { "\($0)°" }), "맑음 · 19° · 우산")
        XCTAssertEqual(Compact.bubbleWord(s, max: 5), "맑음")
    }

    /// The sky draws as much as falls: a drizzle thins the streaks, a downpour doubles them.
    func testSkyDensityFollowsAmount() {
        XCTAssertEqual(Sky.density(precip: "rain", mm: 0.5), 0.45, accuracy: 0.01)
        XCTAssertEqual(Sky.density(precip: "rain", mm: 3), 1.0, accuracy: 0.01)
        XCTAssertEqual(Sky.density(precip: "heavy", mm: 30), 2.0, accuracy: 0.01)
        XCTAssertEqual(Sky.density(precip: "snow", mm: 0.2), 0.45, accuracy: 0.01)
        XCTAssertEqual(Sky.density(precip: "heavysnow", mm: 6), 2.0, accuracy: 0.01)
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
        XCTAssertEqual(c.say("15시쯤 비 예정 · 우산 챙기세요"), "15시쯤 비 예정 · 우산 챙겨")
        XCTAssertEqual(f.say("바람 세요!"), "바람이 셉니다!"); XCTAssertEqual(c.say("안개 짙어요!"), "안개 짙어!")
        XCTAssertEqual(f.say("호우주의보"), "호우주의보"); XCTAssertEqual(c.say("15~17시 비 예정"), "15~17시 비 예정")
        XCTAssertEqual(Voice.polite.say("많이 추워요."), "많이 추워요.")
        XCTAssertEqual(PurrCharacter.brit.defaultVoice, .formal); XCTAssertEqual(PurrCharacter.abys.defaultVoice, .casual)
    }

    // MARK: languages

    /// The same code in English and Japanese: words from the glossary, hour labels in each language's style.
    func testEnglishWords() {
        Lang.current = .en
        defer { Lang.current = .ko }
        XCTAssertEqual(Brand.name, "Purrcast")
        XCTAssertEqual(Rules.feelsWord(20), "Pleasant")
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
        XCTAssertEqual(L("%@쯤 비 예정 · 우산 챙기세요", HourLabel.word(15, clock12: true)), "Rain around 3PM · Take an umbrella")
        // one tone: the voices leave English alone and the picker has nothing to show
        XCTAssertEqual(Voice.casual.say("Rain expected. Take an umbrella."), "Rain expected. Take an umbrella.")
        XCTAssertTrue(Voice.choices.isEmpty)
        XCTAssertEqual(Place.here.name, "Seoul Mapo-gu")
    }

    func testJapaneseWords() {
        Lang.current = .ja
        defer { Lang.current = .ko }
        XCTAssertEqual(Brand.name, "ゴロゴロ天気")
        XCTAssertEqual(Rules.feelsWord(20), "快適")
        XCTAssertEqual(Notifications.changeTitle(place: "麻浦区", todayHi: 15, yesterdayHi: 19, unitF: false), "麻浦区・昨日より4°低い")
        XCTAssertEqual(Notifications.changeTitle(place: "麻浦区", todayHi: 20, yesterdayHi: 19, unitF: false), "麻浦区・昨日とほぼ同じ")
        XCTAssertEqual(HourLabel.hour("15時"), 15); XCTAssertEqual(HourLabel.hour("午後3時"), 15)
        XCTAssertEqual(HourLabel.word(15, clock12: false), "15時"); XCTAssertEqual(HourLabel.window(15, 17, clock12: false), "15〜17時")
        XCTAssertEqual(L("%@쯤 비 예정 · 우산 챙기세요", HourLabel.word(15, clock12: false)), "15時ごろ雨・傘をお持ちください")
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
        XCTAssertEqual(L("%@쯤 비 예정 · 우산 챙기세요", HourLabel.word(15, clock12: false)), "15시쯤 비 예정 · 우산 챙기세요")
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
        Lang.current = .ja
        XCTAssertEqual(index.renamed(p)?.name, "ソウル Mapo-gu")
        XCTAssertNil(index.renamed(Place.catalog[0]), "catalog and Apple Maps places are not the index's")
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
