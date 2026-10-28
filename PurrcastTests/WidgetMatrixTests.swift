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
}

/// One weather, side by side: home small · home medium · lock screen · watch.
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
            // watch app (45 mm screen), still frame
            WatchNow(snap: snap).safeAreaPadding(EdgeInsets(top: 22, leading: 10, bottom: 14, trailing: 10)).frame(width: 198, height: 242).clipShape(RoundedRectangle(cornerRadius: 36))
                .padding(8).background(Color(hex: "#15161C")).clipShape(RoundedRectangle(cornerRadius: 44))
        }
        .padding(16).background(Color(hex: "#EEF1F6"))
        .environment(\.locale, Locale(identifier: "ko_KR"))
    }
    private func widget<C: View>(_ w: CGFloat, _ h: CGFloat, @ViewBuilder _ c: () -> C) -> some View {
        c().padding(14).frame(width: w, height: h)
            .background(WidgetBackground(level: snap.scene.level, night: snap.scene.isNight, scene: snap.scene))
            .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}
