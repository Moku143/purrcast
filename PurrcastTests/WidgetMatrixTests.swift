import XCTest
import SwiftUI
@testable import Purrcast

/// Renders every weather the server can send (Fixtures/matrix.json, from server/scripts/make-matrix.mjs) as the
/// home-screen widgets, lock-screen widgets and the watch screen — exactly the app's views, as one still frame,
/// like a real widget. Runs only in the "Widget matrix" workflow (MATRIX=1); the pictures land on the
/// widget-matrix branch.
@MainActor
final class WidgetMatrixTests: XCTestCase {
    struct Case: Decodable { let key: String; let group: String; let label: String; let scene: WeatherScene; let char: String }

    func testRenderMatrix() throws {
        guard ProcessInfo.processInfo.environment["MATRIX"] == "1" else { throw XCTSkip("run by the Widget matrix workflow") }
        // the fixtures' sentences are Korean: draw the app's own words in Korean too (the simulator runs in English)
        Lang.current = .ko
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "matrix", withExtension: "json"))
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: url))
        var index: [[String: String]] = []
        for c in cases {
            let snap = WeatherSnapshot(scene: c.scene, character: PurrCharacter(rawValue: c.char) ?? .cat, plus: true,
                                       characterName: "", placeShort: "서울", saved: Date())
            let r = ImageRenderer(content: MatrixRow(snap: snap))
            r.scale = 2
            guard let png = r.uiImage?.pngData() else { XCTFail("render failed: \(c.key)"); continue }
            let a = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
            a.name = "matrix-\(c.key)"; a.lifetime = .keepAlways
            add(a)
            let s = c.scene
            index.append(["key": c.key, "group": c.group, "label": c.label, "cond": s.cond, "bubble": s.bubble?.text ?? "",
                          "sky": "\(s.time) · \(s.cover) · \(s.precip)\(s.thunder == "on" ? " · thunder" : "") · \(s.aux)",
                          "outfit": "\(s.level)", "rain": s.rain, "temp": "\(s.temp)"])
        }
        let j = XCTAttachment(data: try JSONSerialization.data(withJSONObject: index), uniformTypeIdentifier: "public.json")
        j.name = "matrix-index"; j.lifetime = .keepAlways
        add(j)
    }

    /// The bottom-right list in each look (in its order · the shortest line on top · the left edges lined up), in
    /// four languages whose lines differ in length, on the small widget and the watch — for choosing by eye
    func testListLooks() throws {
        guard ProcessInfo.processInfo.environment["MATRIX"] == "1" else { throw XCTSkip("run by the Widget matrix workflow") }
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "matrix", withExtension: "json"))
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: url))
        let c = try XCTUnwrap(cases.first { $0.key == "day-partly-none-later-rain5" })
        let cold = try XCTUnwrap(cases.first { $0.key == "day-clear-none-frost" })
        defer { Lang.current = .ko }
        for mode in ["final"] {
            var rows: [UIImage] = []
            for lang in [Lang.ko, .ja, .en, .ru] {
                Lang.current = lang
                let snaps = [c, cold].map { k in
                    WeatherSnapshot(scene: k.scene, character: PurrCharacter(rawValue: k.char) ?? .cat, plus: true, characterName: "",
                                    placeShort: "서울", saved: Date(), clock12: lang.isLatinLike)
                }
                let r = ImageRenderer(content: HStack(alignment: .top, spacing: 16) {
                    ForEach(Array(snaps.enumerated()), id: \.offset) { _, snap in
                        SmallWidgetView(snap: snap).padding(16).frame(width: 170, height: 170)
                            .background(WidgetBackground(level: Rules.clamp(snap.scene.level), night: snap.scene.isNight, scene: snap.scene))
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        WatchAppScreen(snap: snap).frame(width: 198, height: 242).clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                    }
                })
                r.scale = 2
                if let img = r.uiImage { rows.append(img) }
            }
            let sheet = VStack(alignment: .leading, spacing: 16) { ForEach(Array(rows.enumerated()), id: \.offset) { _, img in Image(uiImage: img) } }
                .padding(16).background(Color(hex: "#DDE3EE"))
            let r = ImageRenderer(content: sheet)
            r.scale = 2
            let png = try XCTUnwrap(r.uiImage?.pngData())
            let a = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
            a.name = "list-\(mode)"; a.lifetime = .keepAlways
            add(a)
        }
    }

    /// The hourly 2×4 on the biggest, the 6.1", the mini and the SE iPhone (the last two: no icon, the temperature a
    /// size down), in Korean and English.
    func testHoursLooks() throws {
        guard ProcessInfo.processInfo.environment["MATRIX"] == "1" else { throw XCTSkip("run by the Widget matrix workflow") }
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "matrix", withExtension: "json"))
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: url))
        let c = try XCTUnwrap(cases.first { $0.key == "day-partly-none-later-rain5" })
        let cold = try XCTUnwrap(cases.first { $0.key == "day-clear-none-frost" })
        defer { Lang.current = .ko }
        let sizes: [CGSize] = [CGSize(width: 364, height: 170), CGSize(width: 338, height: 158), CGSize(width: 329, height: 155), CGSize(width: 321, height: 148)]
        var rows: [UIImage] = []
        for lang in [Lang.ko, .en] {
            Lang.current = lang
            for k in [c, cold] {
                let snap = WeatherSnapshot(scene: k.scene, character: PurrCharacter(rawValue: k.char) ?? .cat, plus: true, characterName: "",
                                           placeShort: "서울", saved: Date(), clock12: lang.isLatinLike)
                let r = ImageRenderer(content: HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(sizes.enumerated()), id: \.offset) { _, z in
                        HoursWidgetView(snap: snap).padding(16).frame(width: z.width, height: z.height)
                            .background(WidgetBackground(level: Rules.clamp(snap.scene.level), night: snap.scene.isNight, scene: snap.scene))
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                })
                r.scale = 2
                if let img = r.uiImage { rows.append(img) }
            }
        }
        let sheet = VStack(alignment: .leading, spacing: 12) { ForEach(Array(rows.enumerated()), id: \.offset) { _, img in Image(uiImage: img) } }
            .padding(16).background(Color(hex: "#DDE3EE"))
        let r = ImageRenderer(content: sheet)
        r.scale = 2
        let png = try XCTUnwrap(r.uiImage?.pngData())
        let a = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        a.name = "hours-final"; a.lifetime = .keepAlways
        add(a)
    }

    /// The 2×2 on the big (170), the 6.1" (158) and the SE (148) phones, the list where it was (13 from the edge) and
    /// a little to the right (SmallStack.trailing), in Korean, English and Russian.
    func testSmallSizes() throws {
        guard ProcessInfo.processInfo.environment["MATRIX"] == "1" else { throw XCTSkip("run by the Widget matrix workflow") }
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "matrix", withExtension: "json"))
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: url))
        let c = try XCTUnwrap(cases.first { $0.key == "day-overcast-rain" })
        let cold = try XCTUnwrap(cases.first { $0.key == "day-clear-none-frost" })
        let keep = SmallStack.trailing
        defer { Lang.current = .ko; SmallStack.trailing = keep }
        var rows: [UIImage] = []
        for lang in [Lang.ko, .en, .ru] {
            Lang.current = lang
            for k in [c, cold] {
                var s = k.scene
                if k.key == "day-clear-none-frost" { s.temp = -13; s.hi = -13; s.lo = -14; s.feels = -18 }
                let snap = WeatherSnapshot(scene: s, character: PurrCharacter(rawValue: k.char) ?? .cat, plus: true, characterName: "",
                                           placeShort: "성읍리", saved: Date(), clock12: lang.isLatinLike)
                var cells: [UIImage] = []
                for trailing in [CGFloat(13), keep] {
                    SmallStack.trailing = trailing
                    let r = ImageRenderer(content: HStack(alignment: .top, spacing: 10) {
                        ForEach([CGFloat(170), 158, 148], id: \.self) { w in
                            SmallWidgetView(snap: snap).padding(16).frame(width: w, height: w)
                                .background(WidgetBackground(level: Rules.clamp(s.level), night: s.isNight, scene: s))
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                    })
                    r.scale = 2
                    if let img = r.uiImage { cells.append(img) }
                }
                let pair = ImageRenderer(content: HStack(alignment: .top, spacing: 28) { ForEach(Array(cells.enumerated()), id: \.offset) { _, i in Image(uiImage: i) } })
                pair.scale = 1
                if let img = pair.uiImage { rows.append(img) }
            }
        }
        let sheet = VStack(alignment: .leading, spacing: 12) { ForEach(Array(rows.enumerated()), id: \.offset) { _, img in Image(uiImage: img) } }
            .padding(16).background(Color(hex: "#DDE3EE"))
        let r = ImageRenderer(content: sheet)
        r.scale = 1
        let png = try XCTUnwrap(r.uiImage?.pngData())
        let a = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        a.name = "small-sizes"; a.lifetime = .keepAlways
        add(a)
    }

    /// The bottom-right list never touches the character: every language, °C and °F, the coldest and the hottest
    /// numbers, every character, on the small widget, the hourly medium widget and the watch. Each line's left edge
    /// (from the views' probes) against the sprite's rightmost drawn pixel in that line's band; a line that would
    /// need more than the 0.8 shrink is cut off and counts too. The closest cases come out as pictures.
    func testListClearsTheCharacter() throws {
        guard ProcessInfo.processInfo.environment["MATRIX"] == "1" else { throw XCTSkip("run by the Widget matrix workflow") }
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "matrix", withExtension: "json"))
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: url))
        defer { Lang.current = .ko }
        // (case, temp, hi, lo, feels) in °C: the coldest and the hottest the list will meet
        let runs: [(String, Int, Int, Int, Int)] = [
            ("day-clear-none-frost", -22, -18, -27, -31), ("day-overcast-rain", -3, -1, -9, -8), ("night-clear-none", -22, -18, -27, -31),
            ("day-clear-none-heat", 40, 43, 31, 46), ("day-overcast-rain", 33, 36, 29, 38),
        ]
        // the sprite's drawn pixels, per asset: for each of its rows, the rightmost opaque column (−1: none)
        var masks: [String: (w: Int, h: Int, right: [Int])] = [:]
        func mask(_ name: String) -> (w: Int, h: Int, right: [Int])? {
            if let m = masks[name] { return m }
            guard let img = UIImage(named: name)?.cgImage else { return nil }
            let w = img.width, h = img.height
            var px = [UInt8](repeating: 0, count: w * h * 4)
            guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
            var right = [Int](repeating: -1, count: h)
            for y in 0..<h { for x in stride(from: w - 1, through: 0, by: -1) where px[(y * w + x) * 4 + 3] > 40 { right[y] = x; break } }
            let m = (w, h, right); masks[name] = m
            return m
        }
        var report: [[String: Any]] = [], closest: [(gap: Double, name: String, png: Data)] = []
        for lang in Lang.allCases {
            Lang.current = lang
            for unitF in [false, true] {
                for (key, temp, hi, lo, feels) in runs {
                    guard let c = cases.first(where: { $0.key == key }) else { continue }
                    for ch in PurrCharacter.allCases {
                        var s = c.scene
                        s.temp = temp; s.hi = hi; s.lo = lo; s.feels = feels
                        if !s.hours.isEmpty { s.hours[0].chance = 100 }      // "☂100%", the widest the chance gets
                        let snap = WeatherSnapshot(scene: s, character: ch, plus: true, characterName: "", placeShort: "서울", saved: Date(),
                                                   unitF: unitF, clock12: lang.isLatinLike)
                        let lv = Rules.clamp(s.level), rain = RainState(rawValue: s.rain) ?? .none
                        let bgv = WidgetBackground(level: lv, night: s.isNight, scene: s)
                        let surfaces: [(String, CGSize, AnyView, [String])] = [
                            ("small", CGSize(width: 170, height: 170), AnyView(SmallWidgetView(snap: snap).padding(16).frame(width: 170, height: 170).background(bgv)),
                             ["chance", "sunsetIcon", "feels", "hilo"]),
                            ("small-158", CGSize(width: 158, height: 158), AnyView(SmallWidgetView(snap: snap).padding(16).frame(width: 158, height: 158).background(bgv)),
                             ["chance", "sunsetIcon", "feels", "hilo"]),
                            ("small-148", CGSize(width: 148, height: 148), AnyView(SmallWidgetView(snap: snap).padding(16).frame(width: 148, height: 148).background(bgv)),
                             ["chance", "sunsetIcon", "feels", "hilo"]),
                            ("hours", CGSize(width: 364, height: 170), AnyView(HoursWidgetView(snap: snap).padding(16).frame(width: 364, height: 170).background(bgv)),
                             ["chance", "sunsetIcon", "feels", "hilo"]),
                            ("hours-se", CGSize(width: 321, height: 148), AnyView(HoursWidgetView(snap: snap).padding(16).frame(width: 321, height: 148).background(bgv)),
                             ["chance", "sunsetIcon", "feels", "hilo"]),
                            ("watch", CGSize(width: 198, height: 242), AnyView(WatchAppScreen(snap: snap).frame(width: 198, height: 242)),
                             ["chance", "sunsetIcon", "feels", "hilo"]),
                        ]
                        for (surface, size, view, lines) in surfaces {
                            var fr: [String: CGRect] = [:]
                            Probe.sink = { n, r in fr[n] = r }
                            let r = ImageRenderer(content: view.frame(width: size.width, height: size.height).coordinateSpace(name: "probe"))
                            r.scale = 2
                            let img = r.uiImage
                            Probe.sink = nil
                            guard let cat = fr["cat"], let m = mask(ch.stand(level: lv, rain: rain)) else { continue }
                            var worst = Double.infinity, worstLine = ""
                            for line in lines {
                                guard let f = fr[line] else { continue }
                                // the sprite's rightmost pixel within this line's height
                                var edge = -CGFloat.infinity
                                let y0 = max(0, Int(((f.minY - cat.minY) / cat.height * CGFloat(m.h)).rounded(.down)))
                                let y1 = min(m.h - 1, Int(((f.maxY - cat.minY) / cat.height * CGFloat(m.h)).rounded(.up)))
                                if y0 <= y1 { for y in y0...y1 where m.right[y] >= 0 { edge = max(edge, cat.minX + CGFloat(m.right[y] + 1) / CGFloat(m.w) * cat.width) } }
                                guard edge > -.infinity else { continue }
                                let gap = Double(f.minX - edge)
                                if gap < worst { worst = gap; worstLine = line }
                            }
                            // a line cut short: its words at full size, shrunk as far as the list allows, still wider than it got
                            let px = surface == "watch" ? 12 * min(1, max(0.82, size.width / 208)) : 9
                            let minScale: CGFloat = surface == "watch" ? 0.7 : 0.8
                            var cut: [String] = []
                            for (line, words) in [("hilo", L("최고 %@ 최저 %@", snap.deg(max(s.hi, s.temp)), snap.deg(min(s.lo, s.temp)))),
                                                  ("feels", L("체감 %@", snap.deg(s.feels)))] {
                                guard let f = fr[line] else { continue }
                                var ideal: CGFloat = 0
                                Probe.sink = { n, r in if n == "ideal" { ideal = r.width } }
                                _ = ImageRenderer(content: Text(words).font(.px(px)).fixedSize().probe("ideal").coordinateSpace(name: "probe")).uiImage
                                Probe.sink = nil
                                if surface == "watch" && line == "hilo" {     // the watch's thermometer line
                                    Probe.sink = { n, r in if n == "ideal" { ideal = r.width } }
                                    _ = ImageRenderer(content: HiLoLine(snap: snap, size: px, thermo: true, icon: px * 14 / 12).fixedSize().probe("ideal").coordinateSpace(name: "probe")).uiImage
                                    Probe.sink = nil
                                }
                                if surface == "small-148" && line == "hilo" {     // the SE's 2×2: the thermometer line too
                                    Probe.sink = { n, r in if n == "ideal" { ideal = r.width } }
                                    _ = ImageRenderer(content: HiLoLine(snap: snap, thermo: true).fixedSize().probe("ideal").coordinateSpace(name: "probe")).uiImage
                                    Probe.sink = nil
                                }
                                if ideal * minScale > f.width + 0.5 { cut.append(line) }
                            }
                            if !cut.isEmpty { worst = min(worst, -99); worstLine = "cut:" + cut.joined(separator: ",") }
                            let name = "\(lang.rawValue)-\(unitF ? "F" : "C")-\(key)-\(temp)-\(ch.rawValue)-\(surface)"
                            report.append(["name": name, "lang": lang.rawValue, "unit": unitF ? "F" : "C", "surface": surface, "char": ch.rawValue,
                                           "gap": worst.isFinite ? (worst * 10).rounded() / 10 : 999, "line": worstLine])
                            if worst.isFinite, let png = img?.pngData() {
                                closest.append((worst, name, png))
                                closest.sort { $0.gap < $1.gap }
                                if closest.count > 16 { closest.removeLast() }
                            }
                        }
                    }
                }
            }
        }
        let j = XCTAttachment(data: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted]), uniformTypeIdentifier: "public.json")
        j.name = "clearance-report"; j.lifetime = .keepAlways
        add(j)
        for (i, c) in closest.enumerated() {
            let a = XCTAttachment(data: c.png, uniformTypeIdentifier: "public.png")
            a.name = String(format: "clear-%02d_%@", i, c.name); a.lifetime = .keepAlways
            add(a)
        }
    }

    /// The design canvas's kit, for one weather (rain, umbrella open, a bubble): each surface's sky alone, the
    /// pieces that stay pictures (bubbles, lock-screen gauges), the whole surface for checking, and where every
    /// part lands (frames in points, from the views' own probes) with its words — so the canvas can rebuild the
    /// widgets and watch screens part by part, and moves made there can be carried back here exactly.
    func testLayoutKit() throws {
        guard ProcessInfo.processInfo.environment["MATRIX"] == "1" else { throw XCTSkip("run by the Widget matrix workflow") }
        Lang.current = .ko
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "matrix", withExtension: "json"))
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: url))
        let c = try XCTUnwrap(cases.first { $0.key == "day-overcast-rain" })
        let snap = WeatherSnapshot(scene: c.scene, character: PurrCharacter(rawValue: c.char) ?? .cat, plus: true,
                                   characterName: "", placeShort: "서울", saved: Date())
        let s = snap.scene, lv = Rules.clamp(s.level)
        var frames: [String: [String: [Double]]] = [:]

        func shoot<V: View>(_ name: String, _ w: CGFloat?, _ h: CGFloat?, probe: Bool = false, @ViewBuilder _ v: () -> V) {
            var f: [String: [Double]] = [:]
            if probe { Probe.sink = { n, r in f[n] = [r.minX, r.minY, r.width, r.height].map { (Double($0) * 100).rounded() / 100 } } }
            let r = ImageRenderer(content: v().frame(width: w, height: h).coordinateSpace(name: "probe")
                .environment(\.locale, Locale(identifier: "ko_KR")))
            r.scale = 3
            if let png = r.uiImage?.pngData() {
                let a = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
                a.name = "kit-\(name)"; a.lifetime = .keepAlways
                add(a)
            } else { XCTFail("render failed: \(name)") }
            Probe.sink = nil
            if probe { frames[name] = f }
        }
        let bg = { WidgetBackground(level: lv, night: s.isNight, scene: s) }
        let lockBG = LinearGradient(colors: [Color(hex: "#5B5FA8"), Color(hex: "#2E2F66")], startPoint: .top, endPoint: .bottom)

        // home screen (iOS keeps 16 pt between the widget's edge and its content)
        shoot("small", 170, 170, probe: true) { SmallWidgetView(snap: snap).padding(16).frame(width: 170, height: 170).background(bg()) }
        shoot("small-bg", 170, 170) { bg() }
        shoot("medium", 364, 170, probe: true) { MediumWidgetView(snap: snap).padding(16).frame(width: 364, height: 170).background(bg()) }
        shoot("medium-bg", 364, 170) { bg() }
        // lock screen: rectangular and the two circles, white over the wallpaper; the circles also alone (pictures)
        shoot("lockrect", 160, 66, probe: true) { LockRectangularView(snap: snap).foregroundStyle(.white).background(lockBG) }
        shoot("gauge", 64, 64) { LockCircularView(snap: snap).foregroundStyle(.white) }
        shoot("rain", 64, 64) { LockRainCircularView(snap: snap).foregroundStyle(.white) }
        // watch app (45 mm) and a watch face
        shoot("watch", 198, 242, probe: true) { WatchAppScreen(snap: snap) }
        shoot("watch-bg", 198, 242) { bg() }
        shoot("face", 198, 242, probe: true) { WatchFacePreview(snap: snap) }
        shoot("analog", 198, 242, probe: true) { WatchAnalogPreview(snap: snap) }
        shoot("face-gauge", 50, 50) { LockCircularView(snap: snap) }
        shoot("face-rain", 50, 50) { LockRainCircularView(snap: snap).foregroundStyle(.white) }
        // the bubbles exactly as each surface draws them (before the 0.85 scale)
        if let b = s.bubble {
            shoot("bubble-small", nil, nil) { BubbleView(kind: b.kind, tone: b.tone, icon: b.icon, text: Compact.bubbleWord(s, max: 5), fontSize: 9).fixedSize() }
            shoot("bubble-medium", nil, nil) { BubbleView(kind: b.kind, tone: b.tone, icon: b.icon, text: Compact.bubbleWord(s, max: 9), fontSize: 10).fixedSize() }
        }

        let chance = s.hours.prefix(6).map { $0.chance }.max() ?? 0
        let f = DateFormatter(); f.locale = Lang.current.locale; f.setLocalizedDateFormatFromTemplate("EEEd")
        var texts: [String: String] = [
            "place": snap.placeShort, "icon": s.hours.first?.icon ?? "cloud", "temp": snap.deg(s.temp),
            "feels": L("체감 %@", snap.deg(s.feels)), "chanceShort": L("강수 %d%%", chance), "chanceLong": L("강수확률 %d%%", chance),
            "sunset": sunsetTile(s, clock12: snap.clock12) ?? "", "issued": s.isPlus ? L("%@ 업데이트", s.updated) : L("%@ 기준", s.updated),
            "lockTemp": snap.deg(s.temp), "lockLine": Compact.head(s, weather: true),
            "lockTail": "\(Compact.tail(s, deg: snap.deg, weather: true)) · \(snap.deg(s.lo))~\(snap.deg(s.hi))",
            "inline": LockText.inline(snap), "clock": WatchClock.now(clock12: snap.clock12), "date": f.string(from: Date()),
            "char": snap.shownCharacter.rawValue, "level": "\(lv)", "rain": s.rain, "night": s.isNight ? "1" : "0",
            "sprite": snap.shownCharacter.stand(level: lv, rain: RainState(rawValue: s.rain) ?? .none),
            "lockSprite": snap.shownCharacter.lock(level: lv), "face": snap.shownCharacter.faceImage,
        ]
        for (i, h) in s.hours.dropFirst().prefix(5).enumerated() {
            texts["h\(i)label"] = snap.hourLabel(h.label); texts["h\(i)icon"] = h.icon; texts["h\(i)temp"] = snap.deg(h.temp)
            texts["h\(i)mm"] = h.mm > 0 ? (h.mm == h.mm.rounded() ? "\(Int(h.mm))mm" : String(format: "%.1fmm", h.mm)) : "–"
        }
        let kit: [String: Any] = ["key": c.key, "frames": frames, "texts": texts]
        let j = XCTAttachment(data: try JSONSerialization.data(withJSONObject: kit, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        j.name = "kit-layout"; j.lifetime = .keepAlways
        add(j)
    }
}

/// One weather, side by side: home small · home medium · lock screen · watch app · modular face · analog face.
private struct MatrixRow: View {
    let snap: WeatherSnapshot
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            widget(170, 170) { SmallWidgetView(snap: snap) }
            widget(364, 170) { MediumWidgetView(snap: snap) }
            // lock screen (iOS shows these in one colour over the wallpaper)
            VStack(spacing: 10) {
                Text(LockText.inline(snap)).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                LockRectangularView(snap: snap).frame(width: 160, height: 66)
                HStack(spacing: 12) {
                    LockCircularView(snap: snap).frame(width: 64, height: 64)
                    LockRainCircularView(snap: snap).frame(width: 64, height: 64)
                }
            }
            .foregroundStyle(.white).padding(12).frame(width: 220, height: 170)
            .background(LinearGradient(colors: [Color(hex: "#5B5FA8"), Color(hex: "#2E2F66")], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            // watch app (45 mm screen, with the clock) and a watch face with the complications, still frames
            watch { WatchAppScreen(snap: snap) }
            watch { WatchFacePreview(snap: snap) }
            watch { WatchAnalogPreview(snap: snap) }
        }
        .padding(16).background(Color(hex: "#EEF1F6"))
        .environment(\.locale, Locale(identifier: "ko_KR"))
    }
    private func watch<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        c().frame(width: 198, height: 242).clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .padding(8).background(Color(hex: "#15161C")).clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
    }
    private func widget<C: View>(_ w: CGFloat, _ h: CGFloat, @ViewBuilder _ c: () -> C) -> some View {
        c().padding(16).frame(width: w, height: h)      // iOS keeps 16 pt around a widget's content
            .background(WidgetBackground(level: snap.scene.level, night: snap.scene.isNight, scene: snap.scene))
            .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}
