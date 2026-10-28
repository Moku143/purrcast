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

    /// The name the forecast server is given: Korean for Korean places.
    var serverName: String { ko ?? name }

    /// Computed (not stored) so the names follow `Lang.current`, which tests may change.
    static var here: Place { Place(id: "here", name: L("서울 마포구"), short: L("마포구"), lat: 37.5663, lon: 126.9019, region: "kr", timeZone: "Asia/Seoul", sample: "maybe", ko: "서울 마포구") }

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
