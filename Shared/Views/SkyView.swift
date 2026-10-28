import SwiftUI

// The weather layer from the design (Sky component): a colour wash plus little pixel rectangles —
// sun glow, clouds, rain, snow, wind streaks, dust, heat shimmer, frost, stars, lightning and fog patches —
// each with one of a dozen stepped motions. The rectangles live in Shared/Data/sky.json (exported from the
// design), so the app draws exactly the same weather. One tile is 358 x 170 pt; the app scales it to the width.

struct SkyItem: Decodable {
    var t: String?          // static | cloud | img | nil (particle)
    var x: Double, y: Double, w: Double, h: Double
    var c: String?          // css colour
    var a: String           // motion
    var d: Double           // duration (s)
    var dl: Double          // delay (s, negative = already running)
    var k: Double?          // cloud scale
    var src: String?        // fog image
    var fd: Double?, fdl: Double?   // fog fade duration / delay
}

struct SkyLayerData: Decodable { var tint: String?; var items: [SkyItem] }

enum Sky {
    static let unit = 4.0 / 3.0
    static let tile = CGSize(width: 358, height: 170)

    static let data: [String: SkyLayerData] = {
        guard let url = Bundle.main.url(forResource: "sky", withExtension: "json"),
              let d = try? Data(contentsOf: url),
              var all = try? JSONDecoder().decode([String: SkyLayerData].self, from: d) else { return [:] }
        // derived layers, as in the design
        func ev(_ a: [SkyItem]) -> [SkyItem] { a.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element } }
        func od(_ a: [SkyItem]) -> [SkyItem] { a.enumerated().filter { $0.offset % 2 == 1 }.map { $0.element } }
        let rain = all["rain"]?.items ?? [], snow = all["snow"]?.items ?? [], frost = all["frost"]?.items ?? [], dust = all["dust"]?.items ?? []
        all["drizzle"] = SkyLayerData(tint: "rgba(84,104,150,0.14)", items: ev(rain).map { var i = $0; i.h = 4; i.c = "rgba(238,245,255,0.75)"; i.d *= 1.35; return i })
        all["freezing"] = SkyLayerData(tint: "rgba(170,200,240,0.28)", items: rain.map { var i = $0; i.c = "rgba(225,242,255,0.98)"; return i } + frost.filter { $0.t == "static" })
        all["sleet"] = SkyLayerData(tint: "rgba(120,138,178,0.22)", items: ev(rain) + od(snow).map { var i = $0; i.w = 3; i.h = 3; return i })
        all["flurries"] = SkyLayerData(tint: "rgba(225,235,255,0.10)", items: ev(snow))
        all["heavysnow"] = SkyLayerData(tint: "rgba(232,240,255,0.32)", items: snow + snow.map { var i = $0; i.x = (i.x + 17).truncatingRemainder(dividingBy: 268); i.w = 3; i.h = 3; i.d *= 0.85; i.dl -= 1.3; return i })
        all["hail"] = SkyLayerData(tint: "rgba(96,112,150,0.30)", items: ev(rain).map { var i = $0; i.w = 3; i.h = 3; i.c = "rgba(245,250,255,0.98)"; i.d *= 0.9; return i })
        // clearer weather (review of the widget matrix): clouds spread evenly over the width so a still frame always
        // shows them, more and bigger clouds when overcast, thicker and more rain, bigger snow
        func clouds(_ n: Int, ks: [Double], ys: [Double], c: String, d: Double) -> [SkyItem] {
            (0..<n).map { i in SkyItem(t: "cloud", x: -40, y: ys[i % ys.count], w: 36, h: 13, c: c, a: "cloud", d: d,
                                        dl: -Double(i) / Double(n) * d - 0.37 * d, k: ks[i % ks.count]) }
        }
        let sunGlow = (all["partly"]?.items ?? []).filter { $0.t == "static" }
        all["partly"] = SkyLayerData(tint: nil, items: sunGlow + clouds(3, ks: [1.6, 1.2, 1.8], ys: [6, 40, 22], c: "rgba(255,255,255,0.96)", d: 26))
        all["overcast"] = SkyLayerData(tint: "rgba(96,106,132,0.34)",
                                       items: clouds(8, ks: [2.4, 1.8, 2.8, 2.0], ys: [-4, 30, 8, 46, 18, 60, 0, 36], c: "rgba(226,231,242,0.97)", d: 30))
        func thick(_ a: [SkyItem], h: Double, double: Bool) -> [SkyItem] {
            a.flatMap { i -> [SkyItem] in
                var a = i; a.w = 2; a.h = h
                guard double else { return [a] }
                var b = a; b.x = (b.x + 13).truncatingRemainder(dividingBy: 268); b.dl -= b.d * 0.5
                return [a, b]
            }
        }
        for k in ["rain", "heavy", "storm"] {
            guard var l = all[k] else { continue }
            l.items = thick(l.items.filter { $0.a == "fall" }, h: k == "rain" ? 9 : 12, double: k == "rain") + l.items.filter { $0.a != "fall" }
            all[k] = l
        }
        // snow: twice the flakes in three sizes (3 · 4 · 5 px, the big ones drawn as a cross), a stronger grey-blue
        // wash so a snow day looks like one; heavy snow, flurries and sleet are built from this bigger snow
        if var s = all["snow"] {
            let base = s.items
            s.items = base + base.map { var i = $0; i.x = (i.x + 21).truncatingRemainder(dividingBy: 268); i.dl -= i.d * 0.5; return i }
            s.items = s.items.enumerated().map { n, it in var i = it; let sz = [3.0, 4, 3, 5, 4, 3][n % 6]; i.w = sz; i.h = sz; i.c = "rgba(255,255,255,0.98)"; i.d *= [1.0, 1.15, 0.95, 1.3, 1.1, 1.0][n % 6]; return i }
            s.tint = "rgba(196,208,232,0.40)"
            all["snow"] = s
            let big = s.items
            all["flurries"] = SkyLayerData(tint: "rgba(210,220,240,0.22)", items: ev(big))
            all["heavysnow"] = SkyLayerData(tint: "rgba(176,190,218,0.52)",
                                            items: big + ev(big).map { var i = $0; i.x = (i.x + 9).truncatingRemainder(dividingBy: 268); i.w = max(4, i.w); i.h = i.w; i.d *= 0.8; i.dl -= 1.7; return i })
            // sleet: thick rain streaks and big wet flakes together, a darker wash than snow
            let streaks = (all["rain"]?.items ?? []).filter { $0.a == "fall" }
            all["sleet"] = SkyLayerData(tint: "rgba(126,142,180,0.40)", items: ev(streaks) + od(big).map { var i = $0; i.w = max(4, i.w); i.h = i.w; i.c = "rgba(236,243,255,0.96)"; return i })
        }
        // wind: thicker, longer gusts over the whole height, spread in time so a still frame catches several
        if let w = all["wind"] {
            let leaves = w.items.filter { $0.a != "wind" }
            let ys: [Double] = [8, 22, 36, 50, 64, 78, 92, 106, 120, 15, 43, 71, 99, 113]
            var gusts: [SkyItem] = []
            for (i, y) in ys.enumerated() {
                let len = [40.0, 64, 52, 76, 46, 60][i % 6], d = 1.4 + Double(i % 4) * 0.12
                let dl = -Double(i) / Double(ys.count) * d
                gusts.append(SkyItem(t: nil, x: 0, y: y, w: len, h: 2, c: "rgba(255,255,255,0.9)", a: "wind", d: d, dl: dl))
                gusts.append(SkyItem(t: nil, x: len * 0.45, y: y - 3, w: len * 0.3, h: 1.5, c: "rgba(255,255,255,0.9)", a: "wind", d: d, dl: dl))
            }
            all["wind"] = SkyLayerData(tint: "rgba(150,170,210,0.12)", items: gusts + leaves + leaves.map { var i = $0; i.y += 30; i.dl -= 0.9; return i })
        }
        // fog: patches all the way down (also behind the character) and a stronger white veil
        if let f = all["fog"] {
            let low = f.items.map { var i = $0; i.y += 60; i.x -= 30; i.dl -= 3; i.fdl = (i.fdl ?? 0) - 2.5; return i }
            all["fog"] = SkyLayerData(tint: "rgba(238,241,247,0.40)", items: f.items + low)
        }
        all["haze"] = SkyLayerData(tint: "rgba(196,192,176,0.40)", items: ev(dust).map { var i = $0; i.c = "rgba(140,138,128,0.45)"; return i })
        return all
    }()

    /// How much falls, from the amount: the drawn layers are "보통 비" (3 mm/h) and "눈" (1 cm/h) at 1.0;
    /// a drizzle shows a quarter of the streaks, a downpour nearly three times as many. Each step of the
    /// amount (0.3 · 1 · 3 · 6 · 12 · 25 · 40 mm, 0.3 · 1 · 2 · 4 · 8 cm) should look different.
    static func density(precip p: String, mm: Double) -> Double {
        let snowy = p.contains("snow") || p == "flurries"
        let t: [(Double, Double)] = snowy ? [(0, 0.3), (0.5, 0.5), (1, 1.0), (2, 1.4), (4, 2.0), (8, 2.6)]
                                          : [(0, 0.25), (1, 0.55), (3, 1.0), (6, 1.4), (12, 1.8), (25, 2.3), (40, 2.8)]
        if mm <= 0 { return 1 }                       // no amount known: the layer as drawn
        var prev = t[0]
        for q in t.dropFirst() {
            if mm <= q.0 { return prev.1 + (q.1 - prev.1) * (mm - prev.0) / (q.0 - prev.0) }
            prev = q
        }
        return t.last!.1
    }

    /// Thin or thicken the falling things of one layer to `f` (1.0 = as drawn): fewer streaks for a drizzle,
    /// duplicated and shifted ones for a downpour; rain streaks also get shorter or longer.
    static func scaled(_ items: [SkyItem], by f: Double) -> [SkyItem] {
        guard abs(f - 1) > 0.05 else { return items }
        let falling = items.filter { $0.a == "fall" || $0.a == "snow" }, rest = items.filter { !($0.a == "fall" || $0.a == "snow") }
        var out: [SkyItem]
        if f < 1 {
            let keep = max(1, Int((Double(falling.count) * f).rounded()))
            out = falling.enumerated().filter { ($0.offset * keep) / falling.count != (($0.offset + 1) * keep) / falling.count }.map { $0.element }
        } else {
            let extra = Int((Double(falling.count) * (f - 1)).rounded())
            out = falling + (0..<extra).map { i in var it = falling[i % falling.count]; it.x = (it.x + 7 + Double(i / falling.count) * 11).truncatingRemainder(dividingBy: 268); it.dl -= it.d * 0.37; return it }
        }
        out = out.map { var it = $0
            if it.a == "fall" {
                it.h = max(4, min(16, it.h * (0.6 + 0.4 * f)))
                it.c = Sky.withAlpha(it.c, factor: min(1.3, 0.7 + 0.3 * f))      // a drizzle is faint, a downpour solid
            } else if it.a == "snow" && f < 0.8 {
                it.w = max(2, it.w - 1); it.h = it.w                               // light snow: smaller flakes
            }
            return it }
        return out + rest
    }

    /// Clouds for a cloud amount (0–100 %): how many, how big and how far down they reach — a few small ones near
    /// the top at 20 %, a layer of big ones down past the temperature at 100 %. White on a fair day, light grey when
    /// it is overcast, dark (먹구름) when rain is on its way (`gloom` 1 maybe · 2 later today) or falling.
    static func cloudItems(pct: Int, night: Bool, gloom: Int, wet: Bool) -> [SkyItem] {
        // (from %, clouds, sizes, lowest top in sky units — the tile is 127 units tall)
        let steps: [(min: Int, n: Int, ks: [Double], bottom: Double)] = [
            (90, 12, [2.6, 3.0, 2.2, 2.8], 104), (75, 10, [2.3, 2.7, 2.0, 2.5], 96), (60, 8, [2.0, 2.4, 1.8, 2.2], 88),
            (45, 6, [1.7, 2.0, 1.5, 1.9], 76), (30, 4, [1.5, 1.8, 1.3], 62), (15, 2, [1.3, 1.6], 44), (0, 0, [1], 0)]
        guard let st = steps.first(where: { pct >= $0.min }), st.n > 0 else { return [] }
        let fair = pct >= 75 ? ["rgba(226,231,242,0.97)", "rgba(214,220,234,0.97)"] : ["rgba(255,255,255,0.96)", "rgba(244,247,252,0.96)"]
        let dark = ["rgba(150,158,182,0.97)", "rgba(128,136,162,0.97)", "rgba(170,178,200,0.97)"]
        let nightC = ["#525C86", "#4A5480", "#5C6690"], nightDark = ["#3A4166", "#333A5C", "#434B72"]
        return (0..<st.n).map { i in
            let row = Double((i * 7) % st.n) / Double(max(1, st.n - 1))     // heights shuffled so neighbours differ
            let y = -6 + row * (st.bottom + 6)
            let k = st.ks[i % st.ks.count] * (1 - 0.18 * row)                 // the lower ones a little smaller
            let d = 30 + Double(i % 3) * 6                                    // three speeds: a little depth
            let gloomy = wet || gloom >= 2 || (gloom == 1 && i % 3 == 0)
            let c = night ? (gloomy ? nightDark[i % 3] : nightC[i % 3]) : (gloomy ? dark[i % 3] : fair[i % 2])
            return SkyItem(t: "cloud", x: -40, y: y, w: 36, h: 13, c: c, a: "cloud", d: d, dl: -Double(i) / Double(st.n) * d - 0.37 * d, k: k)
        }
    }

    /// "rgba(58,92,168,0.55)" with its alpha times `factor` (other colours as they are).
    static func withAlpha(_ c: String?, factor: Double) -> String? {
        guard let c, c.hasPrefix("rgba(") else { return c }
        let n = c.dropFirst(5).dropLast().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard n.count == 4, let a = Double(n[3]) else { return c }
        return "rgba(\(n[0]),\(n[1]),\(n[2]),\(String(format: "%.2f", min(1, a * factor))))"
    }

    /// Stack the layers for one forecast (the design's "layered mode"). `mm`: this hour's amount (mm/h, cm/h for snow);
    /// `clouds`: cloud amount in % (nil: from `cover`); `fog`: 0–3 how thick; `gloom`: rain on its way (1 maybe, 2 later today).
    static func compose(time: String, cover: String, precip p: String, thunder: Bool, aux: [String], mm: Double = 0,
                        clouds: Int? = nil, fog: Int = 0, gloom: Int = 0) -> (tints: [String], items: [SkyItem]) {
        var tints: [String] = [], list: [SkyItem] = []
        let f = density(precip: p, mm: mm)
        func add(_ key: String, tint: Bool = true, only: ((SkyItem) -> Bool)? = nil, half: Bool = false, keep: Int = 0) {
            guard let d = data[key] else { return }
            if let t = d.tint, tint { tints.append(t) }
            var its = d.items
            if let only { its = its.filter(only) }
            if half { its = its.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element } }
            if keep > 0 { its = its.enumerated().filter { $0.offset % keep == 0 }.map { $0.element } }
            list += its
        }
        let night = time == "night"
        let precip = ["drizzle", "rain", "heavy", "freezing", "sleet", "flurries", "snow", "heavysnow", "hail"].contains(p) ? p : "none"
        let wet = precip != "none"
        let sunny = cover == "clear" && ["drizzle", "rain", "flurries", "snow"].contains(precip)
        let pct = clouds ?? (cover == "clear" ? 10 : cover == "partly" ? 50 : 90)
        if night { add("night", only: { _ in pct < 75 && !wet }) }
        if cover == "clear" && !night { add("clear") }
        if cover == "partly" && !night { add("partly", only: { $0.t == "static" }) }     // the sun glow; clouds below
        if cover == "overcast" && !wet, let t = data["overcast"]?.tint { tints.append(t) }
        list += cloudItems(pct: pct, night: night, gloom: gloom, wet: wet)
        if gloom > 0 && !wet { tints.append(gloom >= 2 ? "rgba(60,70,104,0.16)" : "rgba(60,70,104,0.08)") }   // it darkens before rain
        let before = list.count
        if thunder && (precip == "rain" || precip == "heavy") && !sunny { add("storm") }
        else {
            if wet { if sunny { add(precip, tint: false, half: true) } else { add(precip) } }
            if thunder { add("storm", tint: false, only: { $0.a == "flash" }) }
        }
        if wet { list = Array(list[..<before]) + scaled(Array(list[before...]), by: f) }
        // fog by how thick it is (mist · fog · thick fog), drawn whether or not it is the bubble's subject
        let fogL = max(fog, aux.contains("fog") ? 2 : 0)
        if fogL > 0, let fl = data["fog"] {
            let lv = wet ? max(1, fogL - 1) : fogL
            var its = fl.items
            if lv == 1 { its = its.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element } }
            if lv == 3 { its += fl.items.map { var i = $0; i.y += 28; i.x += 40; i.dl -= 5; i.fdl = (i.fdl ?? 0) - 1.7; return i } }
            let a = [0, 0.20, 0.38, 0.58][lv]
            tints.append(night ? "rgba(176,184,210,\(a * 0.7))" : "rgba(238,241,247,\(a))")
            list += its
        }
        let pri = ["dust", "wind", "haze", "heat", "frost"]
        var ax: [String] = []
        for a in aux where pri.contains(a) && !ax.contains(a) { ax.append(a) }
        if ax.contains("heat") { ax.removeAll { $0 == "frost" } }
        if fogL > 0 || ax.contains("dust") { ax.removeAll { $0 == "haze" } }
        ax.sort { pri.firstIndex(of: $0)! < pri.firstIndex(of: $1)! }
        for (k, a) in ax.prefix(2).enumerated() {
            let only: ((SkyItem) -> Bool)? = (a == "heat" && night) ? { $0.t != "static" } : nil
            if wet { add(a, tint: false, only: only, keep: k > 0 ? 4 : 2) }
            else if k > 0 { add(a, tint: false, only: only, keep: 2) }
            else { add(a, only: only) }
        }
        if !night && (precip == "rain" || precip == "drizzle") && !(thunder && !sunny) {
            let blue = wet ? Sky.withAlpha("rgba(58,92,168,0.55)", factor: min(1.3, 0.7 + 0.3 * f)) : "rgba(58,92,168,0.55)"
            list = list.map { var i = $0; if i.a == "fall" { i.c = blue }; return i }
        }
        if !night {
            list = list.map { var i = $0; if i.a == "wind" && i.h <= 2 { i.c = "rgba(88,108,158,0.55)" }; return i }
        }
        if night {
            list = list.map { var i = $0; if i.a == "wind" { i.c = "rgba(196,206,240,0.6)" }; return i }
        }
        return (tints, list)
    }

    /// Offset (pt) and opacity of a moving item at time `t`, from the design's keyframes (stepped like CSS steps()).
    /// `span`: how many tiles tall the fall is (rain and snow cross the whole stacked sky in one go, top to bottom,
    /// at the same speed — the period grows with the distance).
    static func motion(_ it: SkyItem, at t: Double, span: Double = 1) -> (dx: Double, dy: Double, alpha: Double) {
        let steps: [String: Double] = ["fall": 165, "snow": 72, "wind": 375, "leaf": 322, "fog": 44, "fogpatch": 32, "drift": 8, "cloud": 315, "rise": 60]
        guard it.d > 0 else { return (0, 0, 1) }
        let falling = it.a == "fall" || it.a == "snow"
        let d = falling ? it.d * span : it.d
        var p = ((t - it.dl) / d).truncatingRemainder(dividingBy: 1); if p < 0 { p += 1 }
        let raw = p
        if let n = steps[it.a] { let n2 = falling ? n * span : n; p = (p * n2).rounded(.down) / n2 }
        func lerp(_ a: Double, _ b: Double, _ f: Double) -> Double { a + (b - a) * f }
        func there(_ a: (Double, Double), _ m: (Double, Double), _ b: (Double, Double)) -> (Double, Double) {
            p < 0.5 ? (lerp(a.0, m.0, p * 2), lerp(a.1, m.1, p * 2)) : (lerp(m.0, b.0, (p - 0.5) * 2), lerp(m.1, b.1, (p - 0.5) * 2))
        }
        switch it.a {
        case "fall": return (lerp(0, -29.33 * span, p), lerp(-20, 220 * span - 20, p), 1)
        case "snow": let v = there((0, -10.67), (8, 96 * span - 10.67), (0, 192 * span - 10.67)); return (v.0, v.1, 1)
        case "wind": return (lerp(-80, 420, p), 0, 1)
        case "leaf": return (lerp(-29.33, 400, p), lerp(0, 40, p), 1)
        case "cloud": return (lerp(0, 420, p), 0, 1)
        case "fog": let v = there((-29.33, 0), (29.33, 0), (-29.33, 0)); return (v.0, 0, 1)
        case "fogpatch":
            let v = there((-21.33, 0), (21.33, 0), (-21.33, 0))
            var f = 1.0
            if let fd = it.fd, fd > 0 {   // ease-in-out fade .12 → 1 → .12
                var q = ((t - (it.fdl ?? 0)) / fd).truncatingRemainder(dividingBy: 1); if q < 0 { q += 1 }
                f = 0.12 + 0.88 * (0.5 - 0.5 * cos(q * 2 * .pi))
            }
            return (v.0, 0, f)
        case "drift": let v = there((0, 0), (10.67, -6.67), (0, 0)); return (v.0, v.1, 1)
        case "rise":
            let a = p < 0.3 ? lerp(0, 0.6, p / 0.3) : lerp(0.6, 0, (p - 0.3) / 0.7)
            return (0, lerp(20, -60, p), a)
        case "twinkle": return (0, 0, raw < 0.25 ? 0.25 : (raw < 0.5 ? 0.6 : (raw < 0.75 ? 1 : 0.6)))
        case "flash":
            let pts: [(Double, Double)] = [(0, 0), (0.86, 0), (0.88, 0.85), (0.90, 0), (0.92, 0.6), (0.94, 0), (1, 0)]
            for i in 1..<pts.count where raw <= pts[i].0 {
                let (x0, y0) = pts[i - 1], (x1, y1) = pts[i]
                return (0, 0, y0 + (y1 - y0) * (raw - x0) / max(0.0001, x1 - x0))
            }
            return (0, 0, 0)
        default: return (0, 0, 1)
        }
    }

    /// The layers for a forecast.
    static func compose(_ s: WeatherScene) -> (tints: [String], items: [SkyItem]) {
        compose(time: s.time, cover: s.cover, precip: s.precip, thunder: s.thunder == "on", aux: [s.aux], mm: s.hours.first?.mm ?? 0,
                clouds: s.clouds, fog: s.fog, gloom: s.gloom)
    }

    /// "rgba(255,236,150,0.16)" / "#525C86" → Color
    static func color(_ s: String?) -> Color {
        guard let s else { return .clear }
        if s.hasPrefix("#") { return Color(hex: s) }
        let nums = s.drop { $0 != "(" }.dropFirst().prefix { $0 != ")" }.split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)) ?? 0 }
        guard nums.count >= 3 else { return .clear }
        return Color(red: nums[0] / 255, green: nums[1] / 255, blue: nums[2] / 255, opacity: nums.count > 3 ? nums[3] : 1)
    }
}

/// The colour wash for a forecast (stretched behind the whole screen).
struct SkyTint: View {
    let scene: WeatherScene
    var body: some View {
        let c = Sky.compose(scene)
        ZStack { ForEach(Array(c.tints.enumerated()), id: \.offset) { _, t in Sky.color(t) } }
    }
}

/// The moving pixels, as one or more stacked tiles scaled to `width`. `lower`: a second tile under the first
/// (no clouds / sun glow / frost frame, so nothing shows twice).
struct SkyParticles: View {
    let scene: WeatherScene
    var width: CGFloat
    var tiles: Int = 1
    var animate = true

    var body: some View {
        let c = Sky.compose(scene)
        let scale = width / Sky.tile.width
        let upper = c.items
        let lower = c.items.filter { $0.t != "cloud" && $0.t != "static" }
        let fogs = (0..<4).map { Image("sky-fog\($0)").interpolation(.none) }
        Group {
            if animate {
                TimelineView(.animation(minimumInterval: 1.0 / 24)) { tl in
                    canvas(upper: upper, lower: lower, fogs: fogs, scale: scale, t: tl.date.timeIntervalSinceReferenceDate)
                }
            } else {
                canvas(upper: upper, lower: lower, fogs: fogs, scale: scale, t: 3.0)   // widgets: one still frame
            }
        }
        .frame(width: width, height: Sky.tile.height * scale * CGFloat(tiles))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func canvas(upper: [SkyItem], lower: [SkyItem], fogs: [Image], scale: CGFloat, t: Double) -> some View {
        Canvas { ctx, _ in
            let resolved = fogs.map { ctx.resolve($0) }
            let falling = { (it: SkyItem) in it.a == "fall" || it.a == "snow" }
            let backdrop = { (it: SkyItem) in it.t == "static" || it.a == "twinkle" }
            // sun glow and stars first, then the clouds — allowed down past the first strip so a low cloud is
            // never cut straight across — then wind, fog, dust and the rest, strip by strip
            do {
                var g = ctx
                g.scaleBy(x: scale, y: scale)
                g.clip(to: Path(CGRect(origin: .zero, size: Sky.tile)))
                for it in upper where backdrop(it) { draw(it, in: &g, t: t, fogs: resolved) }
            }
            do {
                var g = ctx
                g.scaleBy(x: scale, y: scale)
                g.clip(to: Path(CGRect(x: 0, y: 0, width: Sky.tile.width, height: Sky.tile.height * CGFloat(tiles))))
                for it in upper where it.t == "cloud" { draw(it, in: &g, t: t, fogs: resolved) }
            }
            for tile in 0..<tiles {
                var g = ctx
                g.translateBy(x: 0, y: CGFloat(tile) * Sky.tile.height * scale)
                g.scaleBy(x: scale, y: scale)
                g.clip(to: Path(CGRect(origin: .zero, size: Sky.tile)))
                for it in (tile == 0 ? upper : lower) where !falling(it) && it.t != "cloud" && (tile > 0 || !backdrop(it)) { draw(it, in: &g, t: t, fogs: resolved) }
            }
            // rain and snow fall the whole height in one go, from the top edge to the bottom edge
            var g = ctx
            g.scaleBy(x: scale, y: scale)
            g.clip(to: Path(CGRect(x: 0, y: 0, width: Sky.tile.width, height: Sky.tile.height * CGFloat(tiles))))
            // (each streak is drawn `tiles` times, spread over its longer period, so the density per screen stays)
            for it in upper where falling(it) { for k in 0..<tiles { draw(it, in: &g, t: t + Double(k) * it.d, fogs: resolved, span: Double(tiles)) } }
        }
    }

    private func draw(_ it: SkyItem, in g: inout GraphicsContext, t: Double, fogs: [GraphicsContext.ResolvedImage], span: Double = 1) {
        let U = Sky.unit
        let m = Sky.motion(it, at: t, span: span)
        guard m.alpha > 0.01 else { return }
        g.opacity = m.alpha
        if it.t == "img", let src = it.src, let i = Int(src.dropFirst(3)), i < fogs.count {
            g.draw(fogs[i], in: CGRect(x: it.x * U + m.dx, y: it.y * U + m.dy, width: it.w * U, height: it.h * U))
        } else if it.t == "cloud" {
            let k = it.k ?? 1, col = Sky.color(it.c)
            for r in [[0.0, 6, 36, 7], [7, 1, 17, 6], [20, 4, 10, 3]] {
                g.fill(Path(CGRect(x: (it.x + r[0] * k) * U + m.dx, y: (it.y + r[1] * k) * U + m.dy, width: r[2] * k * U, height: r[3] * k * U)), with: .color(col))
            }
            // a darker base line so a white cloud reads on a pale sky
            g.fill(Path(CGRect(x: (it.x + 2 * k) * U + m.dx, y: (it.y + 13 * k) * U + m.dy, width: 32 * k * U, height: max(1.5, 1.2 * k) * U)),
                   with: .color(Color(red: 0.45, green: 0.5, blue: 0.62).opacity(0.28)))
        } else if it.a == "snow" {
            // a cool halo under each flake, so white snow reads on a pale winter sky too; big flakes get a cross shape
            let r = CGRect(x: it.x * U + m.dx, y: it.y * U + m.dy, width: it.w * U, height: it.h * U)
            g.fill(Path(r.insetBy(dx: -U * 0.75, dy: -U * 0.75)), with: .color(Color(red: 0.52, green: 0.6, blue: 0.78).opacity(0.32)))
            if it.w >= 5 {
                let a = U
                g.fill(Path(CGRect(x: r.minX + a, y: r.minY, width: r.width - 2 * a, height: r.height)), with: .color(Sky.color(it.c)))
                g.fill(Path(CGRect(x: r.minX, y: r.minY + a, width: r.width, height: r.height - 2 * a)), with: .color(Sky.color(it.c)))
            } else {
                g.fill(Path(r), with: .color(Sky.color(it.c)))
            }
        } else {
            g.fill(Path(CGRect(x: it.x * U + m.dx, y: it.y * U + m.dy, width: it.w * U, height: it.h * U)), with: .color(Sky.color(it.c)))
        }
        g.opacity = 1
    }
}

extension WeatherScene {
    /// Rain on its way, for the sky: 2 when it is due later today (umbrella packed), 1 when it may come, else 0.
    var gloom: Int { rain == "bag" ? 2 : rain == "think" ? 1 : 0 }
}
