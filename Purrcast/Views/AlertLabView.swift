import SwiftUI

/// Every warning the home screen can show (UI tests: -open alertLab, -alertPage 1…8): the character with the
/// warning's bubble and the line under it, word for word as the server makes them (its `bubble` and `alertNote` with
/// sample amounts: 69mm · 6cm · 21 m/s · 36° · -14° …). Pages 1–5: every 기상청 특보; 6–8: alerts abroad, which come
/// from each country's own agency through Apple, so a few common ones stand in for all of them.
struct AlertLabView: View {
    @EnvironmentObject var model: AppModel
    struct Item { var name: String; var note: String; var icon: String; var level: Int; var rain: RainState = .none }
    static let koreaKo: [Item] = [
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
    static let abroadKo: [Item] = [
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
    static let koreaEn: [Item] = [
        .init(name: "Heavy Rain Advisory", note: "69mm today (Very heavy), rain 3–6PM, take an umbrella and a raincoat", icon: "raincloud", level: 5, rain: .umbrella),
        .init(name: "Heavy Rain Warning", note: "69mm today (Very heavy), rain 3–6PM, take an umbrella and a raincoat", icon: "raincloud", level: 5, rain: .umbrella),
        .init(name: "Heavy Snow Advisory", note: "6cm today, snow until around 6PM, watch your step", icon: "snowflake", level: 12),
        .init(name: "Heavy Snow Warning", note: "6cm today, snow until around 6PM, watch your step", icon: "snowflake", level: 12),
        .init(name: "Wind Advisory", note: "Gusts 21 m/s, watch out for flying objects and your umbrella", icon: "wind", level: 8),
        .init(name: "Wind Warning", note: "Gusts 21 m/s, watch out for flying objects and your umbrella", icon: "wind", level: 8),
        .init(name: "High Seas Advisory", note: "Gusts 17 m/s, watch out for flying objects and your umbrella", icon: "wind", level: 8),
        .init(name: "High Seas Warning", note: "Gusts 17 m/s, watch out for flying objects and your umbrella", icon: "wind", level: 8),
        .init(name: "Typhoon Advisory", note: "Strong wind and rain, gusts 26 m/s, best to stay in if you can", icon: "wind", level: 4, rain: .umbrella),
        .init(name: "Typhoon Warning", note: "Strong wind and rain, gusts 26 m/s, best to stay in if you can", icon: "wind", level: 4, rain: .umbrella),
        .init(name: "Heat Advisory", note: "High 36°, wear a hat and sunscreen and drink water often", icon: "thermo_hot", level: 0),
        .init(name: "Heat Warning", note: "High 36°, wear a hat and sunscreen and drink water often", icon: "thermo_hot", level: 0),
        .init(name: "Cold Wave Advisory", note: "Low -14°, take gloves, a scarf and a hand warmer", icon: "thermo_cold", level: 14),
        .init(name: "Cold Wave Warning", note: "Low -14°, take gloves, a scarf and a hand warmer", icon: "thermo_cold", level: 14),
        .init(name: "Dry Weather Advisory", note: "Humidity 25%, careful with fire", icon: "sun_strong", level: 7),
        .init(name: "Dry Weather Warning", note: "Humidity 25%, careful with fire", icon: "sun_strong", level: 7),
        .init(name: "Yellow Dust Warning", note: "Heavy yellow dust, take a mask", icon: "mask", level: 7),
    ]
    static let abroadEn: [Item] = [
        .init(name: "Winter Storm Warning", note: "18cm today, snow from 8PM, watch your step", icon: "snowflake", level: 13),
        .init(name: "Flood Watch", note: "42mm today (Heavy), rain until around 9PM, take an umbrella and a raincoat", icon: "raincloud", level: 6, rain: .umbrella),
        .init(name: "Hurricane Warning", note: "Strong wind and rain, gusts 33 m/s, best to stay in if you can", icon: "wind", level: 3, rain: .umbrella),
        .init(name: "High Wind Warning", note: "Gusts 24 m/s, watch out for flying objects and your umbrella", icon: "wind", level: 8),
        .init(name: "Excessive Heat Warning", note: "High 41°, wear a hat and sunscreen and drink water often", icon: "thermo_hot", level: 0),
        .init(name: "Extreme Cold Warning", note: "Low -27°, take gloves, a scarf and a hand warmer", icon: "thermo_cold", level: 14),
        .init(name: "Red Flag Warning", note: "Humidity 12%, careful with fire", icon: "sun_strong", level: 4),
        .init(name: "Air Quality Alert", note: "Poor air quality, take a mask", icon: "mask", level: 6),
        .init(name: "Dense Fog Advisory", note: "Take care when you go out", icon: "exclaim", level: 8),
        .init(name: "大雨警報", note: "85mm today (Very heavy), rain 3–6PM, take an umbrella and a raincoat", icon: "raincloud", level: 5, rain: .umbrella),
    ]
    static let koreaJa: [Item] = [
        .init(name: "大雨注意報", note: "今日 69mm (非常に多い)、15〜18時 雨の予報、傘とレインコートをお持ちください", icon: "raincloud", level: 5, rain: .umbrella),
        .init(name: "大雨警報", note: "今日 69mm (非常に多い)、15〜18時 雨の予報、傘とレインコートをお持ちください", icon: "raincloud", level: 5, rain: .umbrella),
        .init(name: "大雪注意報", note: "今日 6cm、18時ごろまで雪の予報、滑りやすいのでご注意ください", icon: "snowflake", level: 12),
        .init(name: "大雪警報", note: "今日 6cm、18時ごろまで雪の予報、滑りやすいのでご注意ください", icon: "snowflake", level: 12),
        .init(name: "強風注意報", note: "突風 21 m/s、飛ばされやすい物と傘にご注意ください", icon: "wind", level: 8),
        .init(name: "暴風警報", note: "突風 21 m/s、飛ばされやすい物と傘にご注意ください", icon: "wind", level: 8),
        .init(name: "波浪注意報", note: "突風 17 m/s、飛ばされやすい物と傘にご注意ください", icon: "wind", level: 8),
        .init(name: "波浪警報", note: "突風 17 m/s、飛ばされやすい物と傘にご注意ください", icon: "wind", level: 8),
        .init(name: "台風注意報", note: "強い雨風、突風 26 m/s、なるべく外出は控えたほうがいいです", icon: "wind", level: 4, rain: .umbrella),
        .init(name: "台風警報", note: "強い雨風、突風 26 m/s、なるべく外出は控えたほうがいいです", icon: "wind", level: 4, rain: .umbrella),
        .init(name: "高温注意報", note: "最高 36°、帽子と日焼け止めを使い、こまめに水分をとったほうがいいです", icon: "thermo_hot", level: 0),
        .init(name: "高温警報", note: "最高 36°、帽子と日焼け止めを使い、こまめに水分をとったほうがいいです", icon: "thermo_hot", level: 0),
        .init(name: "低温注意報", note: "朝 -14°、手袋・マフラー・カイロをお持ちください", icon: "thermo_cold", level: 14),
        .init(name: "低温警報", note: "朝 -14°、手袋・マフラー・カイロをお持ちください", icon: "thermo_cold", level: 14),
        .init(name: "乾燥注意報", note: "湿度 25%、火の元にご注意ください", icon: "sun_strong", level: 7),
        .init(name: "乾燥警報", note: "湿度 25%、火の元にご注意ください", icon: "sun_strong", level: 7),
        .init(name: "黄砂警報", note: "黄砂がひどいです、マスクをお持ちください", icon: "mask", level: 7),
    ]
    static let abroadJa: [Item] = [
        .init(name: "Winter Storm Warning", note: "今日 18cm、20時から 雪の予報、滑りやすいのでご注意ください", icon: "snowflake", level: 13),
        .init(name: "Flood Watch", note: "今日 42mm (多め)、21時ごろまで雨の予報、傘とレインコートをお持ちください", icon: "raincloud", level: 6, rain: .umbrella),
        .init(name: "Hurricane Warning", note: "強い雨風、突風 33 m/s、なるべく外出は控えたほうがいいです", icon: "wind", level: 3, rain: .umbrella),
        .init(name: "High Wind Warning", note: "突風 24 m/s、飛ばされやすい物と傘にご注意ください", icon: "wind", level: 8),
        .init(name: "Excessive Heat Warning", note: "最高 41°、帽子と日焼け止めを使い、こまめに水分をとったほうがいいです", icon: "thermo_hot", level: 0),
        .init(name: "Extreme Cold Warning", note: "朝 -27°、手袋・マフラー・カイロをお持ちください", icon: "thermo_cold", level: 14),
        .init(name: "Red Flag Warning", note: "湿度 12%、火の元にご注意ください", icon: "sun_strong", level: 4),
        .init(name: "Air Quality Alert", note: "PM2.5が多いです、マスクをお持ちください", icon: "mask", level: 6),
        .init(name: "Dense Fog Advisory", note: "外出の際はご注意ください", icon: "exclaim", level: 8),
        .init(name: "大雨警報", note: "今日 85mm (非常に多い)、15〜18時 雨の予報、傘とレインコートをお持ちください", icon: "raincloud", level: 5, rain: .umbrella),
    ]
    static let per = 4
    static var pages: [(title: String, items: [Item])] {
        func split(_ a: [Item], _ t: String) -> [(String, [Item])] {
            stride(from: 0, to: a.count, by: per).map { (t, Array(a[$0..<min(a.count, $0 + per)])) }
        }
        switch Lang.current {
        case .en: return split(koreaEn, "Korea (KMA)") + split(abroadEn, "Abroad (examples)")
        case .ja: return split(koreaJa, "韓国 (気象庁)") + split(abroadJa, "海外 (例)")
        default: return split(koreaKo, "기상청 특보") + split(abroadKo, "해외 특보 (예시)")
        }
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
