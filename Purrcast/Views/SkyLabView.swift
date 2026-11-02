import SwiftUI

/// The skies side by side (UI tests only): every sky — 맑음 · 흐림 · 비 · 눈 — clean, with bad 미세먼지 (grey haze) and on a
/// 황사 day (the sandy sky, only when 기상청 says 황사), by day (or by night with -skyNight), as the home screen and the
/// widgets draw them.
struct SkyLabView: View {
    private var night: Bool { ProcessInfo.processInfo.arguments.contains("-skyNight") }
    private let rows: [(key: String, cover: String, precip: String)] = [
        ("맑음", "clear", "none"), ("흐림", "overcast", "none"), ("비", "overcast", "rain"), ("눈", "overcast", "snow"),
    ]
    private let cols: [(key: String, air: Int)] = [("깨끗", 0), ("미세먼지", 1), ("황사", 2)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(night ? "밤 하늘 · 공기별" : "낮 하늘 · 공기별").font(.px(16)).foregroundStyle(Color(hex: "#1E2A44"))
            HStack(spacing: 8) {
                ForEach(cols, id: \.key) { c in Text(c.key).font(.ui(12, .semibold)).frame(maxWidth: .infinity) }
            }
            ForEach(rows, id: \.key) { r in
                HStack(spacing: 8) {
                    ForEach(cols, id: \.key) { c in
                        let s = scene(r.cover, r.precip, air: c.air)
                        WidgetBackground(level: night ? 4 : 7, night: night, scene: s, animate: false)
                            .frame(maxWidth: .infinity).frame(height: 158)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(alignment: .topLeading) {
                                Text("\(r.key) · \(c.key)").font(.ui(10.5, .semibold)).foregroundStyle(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 3).background(.black.opacity(0.35), in: Capsule()).padding(6)
                            }
                    }
                }
            }
        }
        .padding(.horizontal, 12).padding(.top, 8)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(hex: "#EEF1F7"))
    }

    /// air: 0 clean · 1 bad 미세먼지 (grey haze) · 2 황사 (기상청's 황사경보: the sandy sky)
    private func scene(_ cover: String, _ precip: String, air: Int) -> WeatherScene {
        var s = SceneLibrary.scene("clear")
        s.time = night ? "night" : "day"
        s.cover = cover; s.precip = precip; s.thunder = "off"; s.fog = 0; s.clouds = nil
        s.aux = air == 0 ? "none" : "dust"
        s.alert = air == 2 ? WeatherScene.Alert(name: "황사경보", note: "") : nil
        s.bubble = nil; s.dust = nil
        if precip != "none", !s.hours.isEmpty { s.hours[0].mm = precip == "snow" ? 1 : 2 }
        return s
    }
}
