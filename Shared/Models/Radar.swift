import Foundation

/// 비 지도 (Plus, Korea): the 기상청 radar over the last hour and its 초단기 강수예측 for the next, as the server sends
/// it (`GET /v1/radar`). Each frame is a picture of the whole radar area in its own map projection (Lambert conformal
/// conic, `proj`); the app warps it onto the map. The example weather sends small made-up rain fields instead.
struct RadarMap: Decodable, Equatable {
    var src: String = "kma"
    var at: String = ""                     // the newest observed frame ("2026-11-08 16:50", the place's local time)
    var proj: Proj = .latlon
    var frames: [Frame] = []
    /// The source's colours and the rain they stand for (mm/h, lower edge), so the app redraws the frames in its own
    /// colours and can read the rain at a point. Empty: the colours are used as they come.
    var scale: [Step] = []

    struct Frame: Decodable, Equatable {
        var t: String                       // "2026-11-08 16:50"
        var fc: Bool = false                // a forecast frame (초단기 강수예측), not an observation
        var url: String?                    // the picture (PNG), on the server
        var grid: Grid?                     // the example's made-up field, mm/h, in its own lat/lon box
    }

    /// mm/h on a lat/lon lattice: `rows` × `cols`, north row first
    struct Grid: Decodable, Equatable {
        var cols: Int
        var rows: Int
        var v: [Double]
    }

    struct Step: Decodable, Equatable {
        var rgb: String                     // "#00C8FF"
        var mm: Double
    }

    /// Where a frame's pixels are. `lcc`: Lambert conformal conic on the ellipsoid (`a`, `f`), the picture's corners
    /// `x0,y0` (top left) … `x1,y1` (bottom right) in projected metres. `latlon`: plain degrees, the box `n s w e`.
    struct Proj: Decodable, Equatable {
        var kind: String
        var lat1 = 30.0, lat2 = 60.0, lat0 = 38.0, lon0 = 126.0
        var fe = 0.0, fn = 0.0
        var a = 6378137.0, f = 1 / 298.257222101
        var x0 = 0.0, y0 = 0.0, x1 = 0.0, y1 = 0.0
        var n = 0.0, s = 0.0, w = 0.0, e = 0.0

        static let latlon = Proj(kind: "latlon")
        init(kind: String) { self.kind = kind }

        enum CodingKeys: String, CodingKey { case kind, lat1, lat2, lat0, lon0, fe, fn, a, f, x0, y0, x1, y1, n, s, w, e }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            kind = (try? c.decode(String.self, forKey: .kind)) ?? "lcc"
            func d(_ k: CodingKeys, _ def: Double) -> Double { (try? c.decode(Double.self, forKey: k)) ?? def }
            lat1 = d(.lat1, 30); lat2 = d(.lat2, 60); lat0 = d(.lat0, 38); lon0 = d(.lon0, 126)
            fe = d(.fe, 0); fn = d(.fn, 0); a = d(.a, 6378137); f = d(.f, 1 / 298.257222101)
            x0 = d(.x0, 0); y0 = d(.y0, 0); x1 = d(.x1, 0); y1 = d(.y1, 0)
            n = d(.n, 0); s = d(.s, 0); w = d(.w, 0); e = d(.e, 0)
        }

        /// Where (lat, lon) falls in the picture, 0…1 across and down (outside: beyond that range)
        func unit(lat: Double, lon: Double) -> (u: Double, v: Double) {
            if kind == "latlon" { return ((lon - w) / (e - w), (n - lat) / (n - s)) }
            let (x, y) = lcc(lat: lat, lon: lon)
            return ((x - x0) / (x1 - x0), (y0 - y) / (y0 - y1))
        }

        /// Lambert conformal conic, two standard parallels, on the ellipsoid (Snyder, Map Projections 15-1 … 15-11)
        func lcc(lat: Double, lon: Double) -> (Double, Double) {
            let r = Double.pi / 180, ecc = (f * (2 - f)).squareRoot()
            func m(_ p: Double) -> Double { cos(p) / (1 - ecc * ecc * sin(p) * sin(p)).squareRoot() }
            func t(_ p: Double) -> Double { tan(.pi / 4 - p / 2) / pow((1 - ecc * sin(p)) / (1 + ecc * sin(p)), ecc / 2) }
            let p1 = lat1 * r, p2 = lat2 * r, p0 = lat0 * r
            let nn = abs(lat1 - lat2) < 1e-9 ? sin(p1) : (log(m(p1)) - log(m(p2))) / (log(t(p1)) - log(t(p2)))
            let F = m(p1) / (nn * pow(t(p1), nn))
            let rho = a * F * pow(t(lat * r), nn), rho0 = a * F * pow(t(p0), nn)
            let th = nn * (lon - lon0) * r
            return (fe + rho * sin(th), fn + rho0 - rho * cos(th))
        }
    }

    /// Rain level for a rate (mm/h): 0 none · 1 weak (< 1) · 2 rain (< 5) · 3 (< 10) · 4 heavy (< 30) · 5 very heavy
    static func level(_ mm: Double) -> Int {
        mm < 0.1 ? 0 : mm < 1 ? 1 : mm < 5 ? 2 : mm < 10 ? 3 : mm < 30 ? 4 : 5
    }
    /// The app's colours per level (1…5), and the legend's words
    static let colors = ["#8EC5FF", "#3D8BFF", "#2DBE6C", "#F6C933", "#F2453D"]
    static let words = ["약한 비", "비", "다소 강한 비", "강한 비", "매우 강한 비"]

    /// The example: rain bands drifting east-north-east over Korea, six frames back, now, six ahead (ten minutes apart)
    static func sample(lat: Double, lon: Double, now: Date = Date(), tz: TimeZone = TimeZone(identifier: "Asia/Seoul") ?? .current) -> RadarMap {
        var p = Proj(kind: "latlon"); p.n = 39.8; p.s = 32.4; p.w = 123.6; p.e = 132.4
        let cols = 88, rows = 74
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let base = cal.date(bySetting: .second, value: 0, of: now) ?? now
        let m = cal.component(.minute, from: base)
        let snapped = base.addingTimeInterval(-Double(m % 10) * 60)
        let f = DateFormatter(); f.calendar = cal; f.timeZone = tz; f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd HH:mm"
        // three cells: (lat, lon, radius°, peak mm/h, drift °/frame lat, lon)
        let cells: [(Double, Double, Double, Double, Double, Double)] = [
            (lat + 0.55, lon - 1.6, 0.55, 14, 0.02, 0.16),
            (lat - 1.4, lon - 2.2, 0.8, 6, 0.03, 0.14),
            (38.4, 128.6, 0.45, 3, 0.0, 0.12),
        ]
        var frames: [Frame] = []
        for k in -6...6 {
            var v = [Double](repeating: 0, count: cols * rows)
            for j in 0..<rows {
                let la = p.n - (Double(j) + 0.5) / Double(rows) * (p.n - p.s)
                for i in 0..<cols {
                    let lo = p.w + (Double(i) + 0.5) / Double(cols) * (p.e - p.w)
                    var mm = 0.0
                    for c in cells {
                        let cl = c.0 + c.4 * Double(k), co = c.1 + c.5 * Double(k)
                        let d = ((la - cl) * (la - cl) + (lo - co) * (lo - co) * 0.62) / (c.2 * c.2)
                        // a ragged edge, so it reads as radar and not as a blur
                        let wob = 0.18 * sin(la * 23 + lo * 17 + Double(k) * 0.7) + 0.12 * cos(lo * 31 - la * 11)
                        mm += c.3 * exp(-d * 1.6) * (1 + wob)
                    }
                    v[j * cols + i] = mm < 0.12 ? 0 : mm
                }
            }
            let t = f.string(from: snapped.addingTimeInterval(Double(k) * 600))
            frames.append(Frame(t: t, fc: k > 0, url: nil, grid: Grid(cols: cols, rows: rows, v: v)))
        }
        return RadarMap(src: "sample", at: frames[6].t, proj: p, frames: frames, scale: [])
    }
}
