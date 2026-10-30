import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// The rain Live Activity (Dynamic Island / lock screen), started by the server over APNs when rain or snow is due
/// within two hours (Plus). The server fills both halves (server/src/push.js): the keys here are its JSON keys.
struct RainActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String      // "6시쯤 비 예보" / "지금 비 · 1mm"
        var sub: String        // "1mm · 우산 챙기세요" / "7시까지 비 예보"
        var icon: String       // umbrella_closed | umbrella | snowflake | sleet | cloud
        var what: String       // rain | snow | sleet
        var falling: Bool
        var mm: Double
        var start: Int         // unix seconds: when it starts (now, when falling)
        var end: Int           // unix seconds: until when the forecast has it
        var endHour: Int

        var startDate: Date { Date(timeIntervalSince1970: TimeInterval(start)) }
        var endDate: Date { Date(timeIntervalSince1970: TimeInterval(max(end, start + 60))) }
    }
    var place: String          // "오류동"
    var character: String      // cat | abys | brit
    var level: Int             // the outfit (0…14)
}
#endif
