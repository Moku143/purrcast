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
            "sunset": sunsetTile(s) ?? "", "issued": s.isPlus ? L("%@ 업데이트", s.updated) : L("%@ 기준", s.updated),
            "lockTemp": snap.deg(s.temp), "lockLine": LockText.line(s),
            "lockTail": "\(Compact.tail(s, deg: snap.deg)) · \(snap.deg(s.lo))~\(snap.deg(s.hi))",
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
