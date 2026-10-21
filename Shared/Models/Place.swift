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

    static let here = Place(id: "here", name: "서울 마포구", short: "마포구", lat: 37.5663, lon: 126.9019, region: "kr", timeZone: "Asia/Seoul", sample: "maybe")

    /// The search list used while there is no geocoding server. Names in Korean, as the app shows them.
    static let catalog: [Place] = [
        Place(id: "seoul-jongno", name: "서울 종로구", short: "종로구", lat: 37.5735, lon: 126.9790, region: "kr", timeZone: "Asia/Seoul", sample: "seoul_soon"),
        Place(id: "seoul-gangnam", name: "서울 강남구", short: "강남구", lat: 37.5172, lon: 127.0473, region: "kr", timeZone: "Asia/Seoul", sample: "combo"),
        Place(id: "seoul-mapo", name: "서울 마포구", short: "마포구", lat: 37.5663, lon: 126.9019, region: "kr", timeZone: "Asia/Seoul", sample: "maybe"),
        Place(id: "busan", name: "부산 해운대구", short: "해운대", lat: 35.1631, lon: 129.1636, region: "kr", timeZone: "Asia/Seoul", sample: "clear"),
        Place(id: "incheon", name: "인천 연수구", short: "연수구", lat: 37.4101, lon: 126.6783, region: "kr", timeZone: "Asia/Seoul", sample: "spring_rain"),
        Place(id: "daegu", name: "대구 중구", short: "대구", lat: 35.8693, lon: 128.6062, region: "kr", timeZone: "Asia/Seoul", sample: "summer_heat"),
        Place(id: "daejeon", name: "대전 유성구", short: "유성구", lat: 36.3624, lon: 127.3563, region: "kr", timeZone: "Asia/Seoul", sample: "spring_chill"),
        Place(id: "gwangju", name: "광주 동구", short: "광주", lat: 35.1460, lon: 126.9231, region: "kr", timeZone: "Asia/Seoul", sample: "summer_monsoon"),
        Place(id: "jeju", name: "제주 제주시", short: "제주", lat: 33.4996, lon: 126.5312, region: "kr", timeZone: "Asia/Seoul", sample: "summer_typhoon"),
        Place(id: "gangneung", name: "강원 강릉시", short: "강릉", lat: 37.7519, lon: 128.8761, region: "kr", timeZone: "Asia/Seoul", sample: "winter_snow"),
        Place(id: "tokyo", name: "도쿄 신주쿠", short: "도쿄", lat: 35.6938, lon: 139.7034, region: "jp", timeZone: "Asia/Tokyo", sample: "tokyo_soon"),
        Place(id: "osaka", name: "오사카", short: "오사카", lat: 34.6937, lon: 135.5023, region: "jp", timeZone: "Asia/Tokyo", sample: "summer_night"),
        Place(id: "newyork", name: "뉴욕", short: "뉴욕", lat: 40.7128, lon: -74.0060, region: "other", timeZone: "America/New_York", sample: "winter_eve"),
        Place(id: "london", name: "런던", short: "런던", lat: 51.5074, lon: -0.1278, region: "other", timeZone: "Europe/London", sample: "spring_dust"),
        Place(id: "paris", name: "파리", short: "파리", lat: 48.8566, lon: 2.3522, region: "other", timeZone: "Europe/Paris", sample: "spring_chill"),
        Place(id: "bangkok", name: "방콕", short: "방콕", lat: 13.7563, lon: 100.5018, region: "other", timeZone: "Asia/Bangkok", sample: "summer_heat"),
        Place(id: "sapporo", name: "삿포로", short: "삿포로", lat: 43.0618, lon: 141.3545, region: "jp", timeZone: "Asia/Tokyo", sample: "winter_cold"),
    ]
}
