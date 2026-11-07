import Foundation

/// A place the user follows. `region` decides which extras exist: Korea gets the KMA six-hour rain,
/// Japan and a few others get minute-by-minute rain, everywhere else hourly only.
struct Place: Codable, Hashable, Identifiable {
    var id: String
    var name: String          // shown in the app ("서울 마포구")
    var short: String         // shown on widgets / the watch ("마포구")
    var lat: Double
    var lon: Double
    var region: String        // kr | jp | other
    var timeZone: String
    /// Which example scene the sample provider shows for this place (until the server is connected).
    var sample: String
    /// A Korean place's name in Korean ("서울 구로구 오류동"), whatever language the app shows: the server reads the
    /// 기상청 warnings by it, and Japanese names are made from it. nil elsewhere (and in places saved before it existed).
    var ko: String? = nil
    /// The country ("KR"), from the geocoder for 지금 위치; nil on places saved before it existed (the 날씨 달력
    /// falls back to the time zone's country for their flags)
    var cc: String? = nil
    /// A place abroad in English ("Tokyo Shibuya"), kept when its shown name isn't in Latin letters, so the
    /// 날씨 달력 can show the day to every language without romanizing a foreign name as if it were Korean
    var en: String? = nil

    /// The name the forecast server is given: Korean for Korean places.
    var serverName: String { ko ?? name }

    /// Computed (not stored) so the names follow `Lang.current`, which tests may change.
    /// Before the person grants location or picks a place, the app stands in their region's big city, not 마포구:
    /// the device's region decides (an American first launch opens on 뉴욕), and Korea keeps 서울 마포구.
    static var here: Place { defaultPlace(region: deviceRegion()) }

    /// The device region `here` reads — swappable, so the unit tests can stand in Korea whatever simulator runs them.
    static var deviceRegion: () -> String? = { Locale.current.region?.identifier }

    /// The stand-in place for a device region: the capital, or the city better known than it. Regions the table
    /// does not know fall back to 서울 마포구, like before. The id stays "here" everywhere — it is the same
    /// "no place picked yet" stand-in, so saved places, 지금 위치 and the widgets' spot-taking all go on as they were.
    static func defaultPlace(region: String?) -> Place {
        let seoul = Place(id: "here", name: L("서울 마포구"), short: L("마포구"), lat: 37.5663, lon: 126.9019, region: "kr", timeZone: "Asia/Seoul", sample: "maybe", ko: "서울 마포구")
        guard let r = region, r != "KR" else { return seoul }
        let t: [String: (name: String, lat: Double, lon: Double, region: String, tz: String, sample: String)] = [
            "US": ("뉴욕", 40.7128, -74.0060, "other", "America/New_York", "winter_eve"),
            "JP": ("도쿄", 35.6764, 139.6500, "jp", "Asia/Tokyo", "tokyo_soon"),
            "GB": ("런던", 51.5074, -0.1278, "other", "Europe/London", "spring_chill"),
            "FR": ("파리", 48.8566, 2.3522, "other", "Europe/Paris", "spring_chill"),
            "DE": ("베를린", 52.5200, 13.4050, "other", "Europe/Berlin", "spring_chill"),
            "ES": ("마드리드", 40.4168, -3.7038, "other", "Europe/Madrid", "clear"),
            "IT": ("로마", 41.9028, 12.4964, "other", "Europe/Rome", "clear"),
            "BR": ("상파울루", -23.5505, -46.6333, "other", "America/Sao_Paulo", "summer_night"),
            "ID": ("자카르타", -6.1944, 106.8229, "other", "Asia/Jakarta", "summer_monsoon"),
            "RU": ("모스크바", 55.7558, 37.6173, "other", "Europe/Moscow", "winter_snow"),
            "SG": ("싱가포르", 1.3521, 103.8198, "other", "Asia/Singapore", "summer_heat"),
            "TW": ("타이베이", 25.0330, 121.5654, "other", "Asia/Taipei", "maybe"),
            "TH": ("방콕", 13.7563, 100.5018, "other", "Asia/Bangkok", "summer_heat"),
            "CN": ("상하이", 31.2304, 121.4737, "other", "Asia/Shanghai", "maybe"),
            "HK": ("홍콩", 22.3193, 114.1694, "other", "Asia/Hong_Kong", "summer_night"),
            "AU": ("시드니", -33.8688, 151.2093, "other", "Australia/Sydney", "clear"),
            "CA": ("토론토", 43.6532, -79.3832, "other", "America/Toronto", "winter_eve"),
            "MX": ("멕시코시티", 19.4326, -99.1332, "other", "America/Mexico_City", "clear"),
            "IN": ("뉴델리", 28.6139, 77.2090, "other", "Asia/Kolkata", "spring_dust"),
        ]
        guard let v = t[r] else { return seoul }
        return Place(id: "here", name: L(v.name), short: L(v.name), lat: v.lat, lon: v.lon, region: v.region, timeZone: v.tz, sample: v.sample)
    }

    /// The store pictures' city, one per store language (-storeCity, debug builds): each market's page shows its
    /// own city instead of 마포구. Only the label and the spot change — the region stays "kr" and the weather is
    /// the pinned example, so every page keeps exactly the cards, legends and numbers the pictures always had; the
    /// time zone is the picture machine's own, so the day rows can never disagree with the date over the clock.
    static func storeCity(_ lang: String) -> Place? {
        let c: [String: (name: String, lat: Double, lon: Double)] = [
            "ko": ("서울", 37.5663, 126.9779), "en": ("New York", 40.7128, -74.0060),
            "ja": ("東京", 35.6764, 139.6500), "es": ("Madrid", 40.4168, -3.7038),
            "fr": ("Paris", 48.8566, 2.3522), "de": ("Berlin", 52.5200, 13.4050),
            "pt-BR": ("São Paulo", -23.5505, -46.6333), "pt": ("São Paulo", -23.5505, -46.6333),
            "it": ("Roma", 41.9028, 12.4964), "id": ("Jakarta", -6.1944, 106.8229),
            "ru": ("Москва", 55.7558, 37.6173), "zh-Hans": ("新加坡", 1.3521, 103.8198),
            "zh-Hant": ("台北", 25.0330, 121.5654),
        ]
        guard let v = c[lang] else { return nil }
        return Place(id: "store", name: v.name, short: v.name, lat: v.lat, lon: v.lon, region: "kr",
                     timeZone: TimeZone.current.identifier, sample: "maybe", ko: lang == "ko" ? "서울" : nil)
    }

    /// The search list used while there is no geocoding server. Names in the app's language, as it shows them.
    static var catalog: [Place] { [
        Place(id: "seoul-jongno", name: L("서울 종로구"), short: L("종로구"), lat: 37.5735, lon: 126.9790, region: "kr", timeZone: "Asia/Seoul", sample: "seoul_soon", ko: "서울 종로구"),
        Place(id: "seoul-gangnam", name: L("서울 강남구"), short: L("강남구"), lat: 37.5172, lon: 127.0473, region: "kr", timeZone: "Asia/Seoul", sample: "combo", ko: "서울 강남구"),
        Place(id: "seoul-mapo", name: L("서울 마포구"), short: L("마포구"), lat: 37.5663, lon: 126.9019, region: "kr", timeZone: "Asia/Seoul", sample: "maybe", ko: "서울 마포구"),
        Place(id: "busan", name: L("부산 해운대구"), short: L("해운대"), lat: 35.1631, lon: 129.1636, region: "kr", timeZone: "Asia/Seoul", sample: "clear", ko: "부산 해운대구"),
        Place(id: "incheon", name: L("인천 연수구"), short: L("연수구"), lat: 37.4101, lon: 126.6783, region: "kr", timeZone: "Asia/Seoul", sample: "spring_rain", ko: "인천 연수구"),
        Place(id: "daegu", name: L("대구 중구"), short: L("대구"), lat: 35.8693, lon: 128.6062, region: "kr", timeZone: "Asia/Seoul", sample: "summer_heat", ko: "대구 중구"),
        Place(id: "daejeon", name: L("대전 유성구"), short: L("유성구"), lat: 36.3624, lon: 127.3563, region: "kr", timeZone: "Asia/Seoul", sample: "spring_chill", ko: "대전 유성구"),
        Place(id: "gwangju", name: L("광주 동구"), short: L("광주"), lat: 35.1460, lon: 126.9231, region: "kr", timeZone: "Asia/Seoul", sample: "summer_monsoon", ko: "광주 동구"),
        Place(id: "jeju", name: L("제주 제주시"), short: L("제주"), lat: 33.4996, lon: 126.5312, region: "kr", timeZone: "Asia/Seoul", sample: "summer_typhoon", ko: "제주 제주시"),
        Place(id: "gangneung", name: L("강원 강릉시"), short: L("강릉"), lat: 37.7519, lon: 128.8761, region: "kr", timeZone: "Asia/Seoul", sample: "winter_snow", ko: "강원 강릉시"),
        Place(id: "tokyo", name: L("도쿄 신주쿠"), short: L("도쿄"), lat: 35.6938, lon: 139.7034, region: "jp", timeZone: "Asia/Tokyo", sample: "tokyo_soon"),
        Place(id: "osaka", name: L("오사카"), short: L("오사카"), lat: 34.6937, lon: 135.5023, region: "jp", timeZone: "Asia/Tokyo", sample: "summer_night"),
        Place(id: "newyork", name: L("뉴욕"), short: L("뉴욕"), lat: 40.7128, lon: -74.0060, region: "other", timeZone: "America/New_York", sample: "winter_eve"),
        Place(id: "london", name: L("런던"), short: L("런던"), lat: 51.5074, lon: -0.1278, region: "other", timeZone: "Europe/London", sample: "spring_dust"),
        Place(id: "paris", name: L("파리"), short: L("파리"), lat: 48.8566, lon: 2.3522, region: "other", timeZone: "Europe/Paris", sample: "spring_chill"),
        Place(id: "bangkok", name: L("방콕"), short: L("방콕"), lat: 13.7563, lon: 100.5018, region: "other", timeZone: "Asia/Bangkok", sample: "summer_heat"),
        Place(id: "sapporo", name: L("삿포로"), short: L("삿포로"), lat: 43.0618, lon: 141.3545, region: "jp", timeZone: "Asia/Tokyo", sample: "winter_cold"),
    ] }
}
