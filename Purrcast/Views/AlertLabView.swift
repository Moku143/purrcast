import SwiftUI

/// Every warning the home screen can show (UI tests: -open alertLab, -alertPage 1…6): the character with the
/// warning's bubble and the line under it, word for word as the server makes them (its `bubble` and `alertNote` with
/// sample amounts: 69mm · 6cm · 21 m/s · 36° · -14° …). Pages 1–4: every 기상청 특보; 5–6: alerts abroad, which come
/// from each country's own agency through Apple, so a few common ones stand in for all of them.
struct AlertLabView: View {
    @EnvironmentObject var model: AppModel
    struct Item { var name: String; var note: String; var icon: String; var level: Int; var rain: RainState = .none }
    static let korea: [Item] = [
        .init(name: "호우주의보", note: "오늘 69mm (매우 많음), 15~18시 비 예보, 우산·우비 챙기세요", icon: "raincloud", level: 5, rain: .umbrella),
        .init(name: "호우경보", note: "오늘 69mm (매우 많음), 15~18시 비 예보, 우산·우비 챙기세요", icon: "raincloud", level: 5, rain: .umbrella),
        .init(name: "대설주의보", note: "오늘 6cm, 18시까지 눈 예보, 미끄러우니 조심하세요", icon: "snowflake", level: 12),
        .init(name: "대설경보", note: "오늘 6cm, 18시까지 눈 예보, 미끄러우니 조심하세요", icon: "snowflake", level: 12),
        .init(name: "강풍주의보", note: "돌풍 21 m/s, 날리는 물건과 우산 조심하세요", icon: "wind", level: 8),
        .init(name: "강풍경보", note: "돌풍 21 m/s, 날리는 물건과 우산 조심하세요", icon: "wind", level: 8),
        .init(name: "풍랑주의보", note: "돌풍 17 m/s, 날리는 물건과 우산 조심하세요", icon: "wind", level: 8),
        .init(name: "풍랑경보", note: "돌풍 17 m/s, 날리는 물건과 우산 조심하세요", icon: "wind", level: 8),
        .init(name: "태풍주의보", note: "강한 비바람, 돌풍 26 m/s, 되도록 외출은 줄이는 게 좋아요", icon: "wind", level: 4, rain: .umbrella),
        .init(name: "태풍경보", note: "강한 비바람, 돌풍 26 m/s, 되도록 외출은 줄이는 게 좋아요", icon: "wind", level: 4, rain: .umbrella),
        .init(name: "폭염주의보", note: "낮 최고 36°, 모자·선크림을 챙기고 물을 자주 마시는 게 좋아요", icon: "thermo_hot", level: 0),
        .init(name: "폭염경보", note: "낮 최고 36°, 모자·선크림을 챙기고 물을 자주 마시는 게 좋아요", icon: "thermo_hot", level: 0),
        .init(name: "한파주의보", note: "아침 -14°, 장갑·목도리·핫팩 챙기세요", icon: "thermo_cold", level: 14),
        .init(name: "한파경보", note: "아침 -14°, 장갑·목도리·핫팩 챙기세요", icon: "thermo_cold", level: 14),
        .init(name: "건조주의보", note: "습도 25%, 불씨 조심하세요", icon: "sun_strong", level: 7),
        .init(name: "건조경보", note: "습도 25%, 불씨 조심하세요", icon: "sun_strong", level: 7),
        .init(name: "황사경보", note: "황사가 심해요, 마스크 챙기세요", icon: "mask", level: 7),
    ]
    static let abroad: [Item] = [
        .init(name: "Winter Storm Warning", note: "오늘 18cm, 20시부터 눈 예보, 미끄러우니 조심하세요", icon: "snowflake", level: 13),
        .init(name: "Flood Watch", note: "오늘 42mm (많음), 21시까지 비 예보, 우산·우비 챙기세요", icon: "raincloud", level: 6, rain: .umbrella),
        .init(name: "Hurricane Warning", note: "강한 비바람, 돌풍 33 m/s, 되도록 외출은 줄이는 게 좋아요", icon: "wind", level: 3, rain: .umbrella),
        .init(name: "High Wind Warning", note: "돌풍 24 m/s, 날리는 물건과 우산 조심하세요", icon: "wind", level: 8),
        .init(name: "Excessive Heat Warning", note: "낮 최고 41°, 모자·선크림을 챙기고 물을 자주 마시는 게 좋아요", icon: "thermo_hot", level: 0),
        .init(name: "Extreme Cold Warning", note: "아침 -27°, 장갑·목도리·핫팩 챙기세요", icon: "thermo_cold", level: 14),
        .init(name: "Red Flag Warning", note: "습도 12%, 불씨 조심하세요", icon: "sun_strong", level: 4),
        .init(name: "Air Quality Alert", note: "미세먼지가 심해요, 마스크 챙기세요", icon: "mask", level: 6),
        .init(name: "Dense Fog Advisory", note: "외출할 때 조심하세요", icon: "exclaim", level: 8),
        .init(name: "大雨警報", note: "오늘 85mm (매우 많음), 15~18시 비 예보, 우산·우비 챙기세요", icon: "raincloud", level: 5, rain: .umbrella),
    ]
    static let per = 5
    static var pages: [(title: String, items: [Item])] {
        func split(_ a: [Item], _ t: String) -> [(String, [Item])] {
            stride(from: 0, to: a.count, by: per).map { (t, Array(a[$0..<min(a.count, $0 + per)])) }
        }
        return split(korea, "기상청 특보") + split(abroad, "해외 특보 (예시)")
    }
    private var page: Int {
        let a = ProcessInfo.processInfo.arguments
        return a.firstIndex(of: "-alertPage").flatMap { $0 + 1 < a.count ? Int(a[$0 + 1]) : nil } ?? 1
    }

    var body: some View {
        let all = Self.pages, p = all[max(0, min(all.count - 1, page - 1))]
        VStack(alignment: .leading, spacing: 10) {
            Text("\(p.title) · \(page)/\(all.count)").font(.px(15)).foregroundStyle(Color(hex: "#1E2A44"))
            ForEach(p.items, id: \.name) { w in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .bottom, spacing: 6) {
                        CharacterSprite(character: .cat, level: w.level, rain: w.rain, width: 48, animate: false)
                        BubbleView(kind: "shout", tone: "coral", icon: w.icon, text: w.name, fontSize: 12).fixedSize()
                            .padding(.bottom, 18)
                        Spacer(minLength: 0)
                    }
                    AlertBanner(alert: WeatherScene.Alert(name: w.name, note: w.note))
                }
                .padding(8)
                .background(Color(hex: "#DCE6F4"), in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 12).padding(.top, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: "#EEF1F7"))
    }
}
