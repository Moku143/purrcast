import Foundation

/// Sunrise and sunset worked out on the phone from the place (NOAA's simple formula, good to about a minute), so the
/// lock-screen circle can turn from the sunset to the next sunrise right when the sun goes down, without the server.
enum SunTimes {
    /// Sunrise and sunset on the place's calendar day that holds `date`; nil while the sun stays up or down all day.
    static func day(_ date: Date, lat: Double, lon: Double, tz: TimeZone) -> (rise: Date, set: Date)? {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let n = Double(cal.ordinality(of: .day, in: .year, for: date) ?? 1)
        let g = 2 * Double.pi / 365 * (n - 1)
        let eq = 229.18 * (0.000075 + 0.001868 * cos(g) - 0.032077 * sin(g) - 0.014615 * cos(2 * g) - 0.040849 * sin(2 * g))
        let decl = 0.006918 - 0.399912 * cos(g) + 0.070257 * sin(g) - 0.006758 * cos(2 * g) + 0.000907 * sin(2 * g)
            - 0.002697 * cos(3 * g) + 0.00148 * sin(3 * g)
        let phi = lat * .pi / 180
        let cosH = cos(90.833 * .pi / 180) / (cos(phi) * cos(decl)) - tan(phi) * tan(decl)
        guard cosH >= -1, cosH <= 1 else { return nil }
        let h = acos(cosH) * 180 / .pi
        // minutes after midnight UTC of the place's date
        let rise = 720 - 4 * (lon + h) - eq, set = 720 - 4 * (lon - h) - eq
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(identifier: "UTC")!
        guard let midnight = utc.date(from: cal.dateComponents([.year, .month, .day], from: date)) else { return nil }
        return (midnight.addingTimeInterval(rise * 60), midnight.addingTimeInterval(set * 60))
    }

    /// The next sunrise or sunset after `now` (within three days).
    static func next(after now: Date, lat: Double, lon: Double, tz: TimeZone) -> (sunset: Bool, at: Date)? {
        for k in -1...2 {
            guard let t = day(now.addingTimeInterval(Double(k) * 86400), lat: lat, lon: lon, tz: tz) else { continue }
            if t.rise > now { return (false, t.rise) }
            if t.set > now { return (true, t.set) }
        }
        return nil
    }
}
