import SwiftUI

/// Purrcast Plus: what you get (swipeable), yearly / monthly, free trial when eligible.
/// Prices, period and trial come from the App Store; the auto-renew terms sit right under the button (3.1.2).
struct PaywallView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var purchases: Purchases
    @Environment(\.dismiss) private var dismiss
    @State private var pick = Purchases.yearly
    @State private var page = 0

    struct Feature { let art: String; let title: String; let note: String; let check: String }
    static var features: [Feature] {
        var f: [Feature] = []
        if Features.adsInFree { f.append(Feature(art: "ads", title: L("광고 없이"), note: L("화면 사이 광고가 사라져요."), check: L("광고 제거"))) }
        f += [
            Feature(art: "fresh", title: L("새 예보마다 업데이트"), note: L("무료는 하루 1번, Plus는 새 예보가 나올 때마다."), check: L("새 예보마다")),
            Feature(art: "rain", title: L("가까운 비"), note: L("비 올 시각까지 · 한국은 다음 6시간"), check: L("가까운 비")),
            Feature(art: "watch", title: L("애플워치"), note: L("워치 앱 · 워치 페이스 · 컴플리케이션"), check: L("애플워치")),
            Feature(art: "places", title: L("지역 여러 곳"), note: L("무료는 1곳 더, Plus는 제한 없이."), check: L("지역 여러 곳")),
            Feature(art: "chars", title: L("캐릭터 바꾸기"), note: L("아비시니안 · 브리티시숏헤어 · 추후 업데이트로 추가 예정"), check: L("캐릭터")),
        ]
        return f
    }

    var body: some View {
        let features = Self.features
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)) }
                        .foregroundStyle(UI.sub).accessibilityIdentifier("sheet-close").accessibilityLabel(L("닫기"))
                    Spacer()
                    Button(L("구독 복원")) { Task { await purchases.restore() } }.font(.system(size: 14)).foregroundStyle(UI.sub)
                        .disabled(purchases.busy)
                }
                .padding(.top, 18)

                HStack(spacing: 12) {
                    Image(PurrCharacter.cat.faceImage).resizable().scaledToFit().frame(width: 40, height: 40)
                        .frame(width: 56, height: 56).background(Color(hex: "#D9EFCF")).clipShape(Circle()).reveal(0, rise: 8)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Brand.plus).font(.px(24)).foregroundStyle(UI.ink)
                        Text(L("옆으로 넘겨 보세요")).font(.ui(13)).foregroundStyle(UI.sub)
                    }
                }
                .padding(.top, 14)

                TabView(selection: $page) {
                    ForEach(Array(features.enumerated()), id: \.offset) { i, f in
                        VStack(alignment: .leading, spacing: 10) {
                            featureArt(f.art)
                            Text(f.title).font(.ui(17, .bold)).foregroundStyle(UI.ink).padding(.horizontal, 4)
                            Text(f.note).font(.ui(13)).lineSpacing(3).foregroundStyle(Color(hex: "#33405E")).padding(.horizontal, 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 290)
                .padding(.top, 14)
                .reveal(1)
                .onChange(of: page) { _, _ in Haptic.soft() }

                HStack(spacing: 6) {
                    ForEach(0..<features.count, id: \.self) { i in
                        Capsule().fill(i == page ? UI.accent : UI.faint.opacity(0.5)).frame(width: i == page ? 18 : 6, height: 6)
                    }
                }.frame(maxWidth: .infinity).animation(Motion.snappy, value: page)

                FlowChecks(items: features.map { $0.check }).padding(.top, 16).reveal(2)

                HStack(spacing: 10) {
                    planCard(Purchases.yearly, key: "연간", title: L("연간"),
                             note: [purchases.yearlyPerMonth().map { L("월 %@ 꼴", $0) }, purchases.yearlySaving().map { L("%d%% 할인", $0) }].compactMap { $0 }.joined(separator: " · "),
                             badge: L("가장 많이 골라요"))
                    planCard(Purchases.monthly, key: "월간", title: L("월간"), note: L("매달 결제"), badge: nil)
                }
                .padding(.top, 22)
                .reveal(3)

                PrimaryButton(title: buttonTitle, busy: purchases.busy) {
                    guard !model.plus else { dismiss(); return }
                    Task { if await purchases.buy(pick) { dismiss() } }
                }
                .disabled(!model.plus && purchases.product(pick) == nil)
                .opacity(!model.plus && purchases.product(pick) == nil ? 0.5 : 1)
                .padding(.top, 14)
                .reveal(4)
                .accessibilityIdentifier("subscribe")

                Text(disclosure)
                    .font(.ui(11)).foregroundStyle(UI.sub).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).padding(.top, 10)
                HStack(spacing: 6) {
                    Link(destination: Legal.terms) { Text(L("이용약관")).underline() }
                    Text("·")
                    Link(destination: Legal.privacy) { Text(L("개인정보 처리방침")).underline() }
                }
                .font(.ui(11.5)).foregroundStyle(UI.sub).frame(maxWidth: .infinity).padding(.top, 6).padding(.bottom, 30)
            }
            .padding(.horizontal, 20)
        }
        .background(LinearGradient(stops: [.init(color: Color(hex: "#FFE8A3"), location: 0), .init(color: Color(hex: "#FFF6EC"), location: 0.4), .init(color: Color(hex: "#F6F7FB"), location: 1)],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .alert(purchases.message ?? "", isPresented: Binding(get: { purchases.message != nil }, set: { if !$0 { purchases.message = nil } })) {
            Button(L("확인"), role: .cancel) {}
        }
        .task { if !purchases.loaded { await purchases.load() } }
    }

    private var buttonTitle: String {
        if model.plus { return L("Plus 쓰는 중") }
        if purchases.product(pick) == nil { return purchases.loaded ? L("지금은 구독할 수 없어요") : L("가격 불러오는 중…") }
        if let t = purchases.trialText(pick) { return L("%@로 시작하기", t) }
        return L("%@ %@ 구독하기", purchases.periodWord(pick), purchases.price(pick) ?? "")
    }

    /// The auto-renew terms, with the real price and period of the selected plan.
    private var disclosure: String {
        guard let price = purchases.price(pick) else { return L("구독은 App Store 계정으로 결제되고, App Store 설정에서 언제든 해지할 수 있어요.") }
        let per = purchases.periodWord(pick)
        let lead = purchases.trialText(pick).map { L("%@ 체험이 끝나면 ", $0) } ?? ""
        return lead + L("%@ %@이 App Store 계정으로 결제되고, 기간이 끝나기 24시간 전까지 해지하지 않으면 같은 금액으로 자동 갱신돼요. 해지는 App Store 계정 설정에서 언제든 할 수 있어요.", per, price)
    }

    /// `key` is the Korean plan word, kept for the accessibility identifier ("plan-연간") the UI tests use.
    private func planCard(_ id: String, key: String, title: String, note: String, badge: String?) -> some View {
        let on = pick == id
        return Button { Haptic.select(); withAnimation(Motion.snappy) { pick = id } } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.ui(13, .medium)).foregroundStyle(UI.sub)
                Text(purchases.price(id) ?? "–").font(.px(20)).foregroundStyle(UI.ink)
                Text(note).font(.ui(11)).foregroundStyle(UI.sub)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(14).padding(.top, 6)
            .background(on ? UI.accentSoft.opacity(0.55) : Color.white)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(on ? UI.accent : UI.line, lineWidth: on ? 2.5 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .scaleEffect(on ? 1 : 0.97)
            .overlay(alignment: .top) {
                if let badge { PlusTag(text: badge).offset(y: -10) }
            }
        }
        .buttonStyle(.press(0.96))
        .accessibilityIdentifier("plan-\(key)")
    }

    /// Small picture per feature, drawn from app parts (no screenshots, so it stays language-neutral).
    @ViewBuilder private func featureArt(_ key: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18).fill(artBackground(key))
            switch key {
            case "ads": adsArt
            case "fresh": freshArt
            case "rain": rainArt
            case "watch": watchArt
            case "places": placesArt
            default: charsArt
            }
        }
        .frame(height: 196)
    }

    private func artBackground(_ key: String) -> Color {
        switch key {
        case "fresh": return .white
        case "rain": return Color(hex: "#EEF4FF")
        case "watch": return Color(hex: "#E9ECF3")
        default: return Color(hex: "#F4F6FA")
        }
    }

    /// Free: a phone with an ad slot → Plus: the same phone without it
    private var adsArt: some View {
        HStack(spacing: 18) {
            VStack(spacing: 6) {
                miniPhone(ad: true)
                Text("Free").font(.ui(11, .bold)).foregroundStyle(UI.sub)
            }
            Image(systemName: "arrow.right").font(.system(size: 20)).foregroundStyle(UI.faint)
            VStack(spacing: 6) {
                miniPhone(ad: false)
                Text("Plus").font(.ui(11, .bold)).foregroundStyle(UI.accent)
            }
        }
    }

    /// Two day-lines: Free gets one forecast a day, Plus one at every new run
    private var freshArt: some View {
        VStack(alignment: .leading, spacing: 18) {
            timeline(label: "Free", color: UI.sub, track: Color(hex: "#E6E9F0"), dots: [0.25])
            timeline(label: "Plus", color: UI.accent, track: Color(hex: "#FFE3CC"), dots: [0.08, 0.21, 0.25, 0.33, 0.46, 0.58, 0.71, 0.83, 0.96])
            axis(["0", "6", "12", "18", "24"])
        }
        .padding(.horizontal, 20)
    }

    /// "0  6  12  18  24" spread across the width
    private func axis(_ labels: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(labels.enumerated()), id: \.offset) { i, t in
                Text(t)
                if i < labels.count - 1 { Spacer() }
            }
        }
        .font(.ui(10.5)).foregroundStyle(Color(hex: "#8A93AA"))
    }

    private func timeline(label: String, color: Color, track: Color, dots: [CGFloat]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.ui(12, .bold)).foregroundStyle(color)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(track)
                    ForEach(Array(dots.enumerated()), id: \.offset) { _, x in
                        Circle().fill(color).frame(width: 12, height: 12).offset(x: g.size.width * x - 6, y: 1)
                    }
                }
            }
            .frame(height: 14)
        }
    }

    /// Minute-by-minute rain: a bubble with the start time, then the bars and a 0–60 min axis
    private var rainArt: some View {
        let bars: [CGFloat] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 14, 22, 30, 38, 46, 54, 60, 66, 70, 72, 74, 74, 72, 70, 66, 60, 54, 48, 42, 36, 30, 24, 18, 12, 8, 6, 4, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        return ZStack(alignment: .topLeading) {
            HStack(spacing: 4) {
                PixelIcon(name: "umbrella_closed", size: 14)
                Text(L("%@쯤 비 예정", "15:50")).font(.px(11)).foregroundStyle(UI.ink)
            }
            .padding(.horizontal, 10).padding(.vertical, 6).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.leading, 18).padding(.top, 16)
            VStack(spacing: 6) {
                Spacer()
                HStack(alignment: .bottom, spacing: 1.5) {
                    ForEach(Array(bars.enumerated()), id: \.offset) { _, h in
                        RoundedRectangle(cornerRadius: 1).fill(h > 0 ? Color(hex: "#1F5BD0") : Color(hex: "#DDE2EC")).frame(height: max(2, h))
                    }
                }
                .frame(height: 92)
                axis(["0", "15", "30", "45", "60 min"])
            }
            .padding(.horizontal, 18).padding(.bottom, 14)
        }
    }

    /// Two watches: the app and a face with the character on it
    private var watchArt: some View {
        HStack(spacing: 10) {
            miniWatch { CharacterSprite(character: .cat, level: 4, rain: .bag, width: 64, animate: false) }
            miniWatch {
                VStack(spacing: 2) {
                    Text("10:09").font(.px(18)).foregroundStyle(.white)
                    CharacterSprite(character: .cat, level: 4, rain: .none, width: 48, animate: false)
                }
            }
        }
    }

    private func miniWatch<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        RoundedRectangle(cornerRadius: 30).fill(Color(hex: "#111114")).frame(width: 113, height: 132)
            .overlay {
                RoundedRectangle(cornerRadius: 22).fill(Color(hex: "#1B1F2E")).padding(8)
                    .overlay(c())
            }
    }

    /// Three place cards fanned out: Seoul, Tokyo, New York (night)
    private var placesArt: some View {
        let rows: [(String, Int, Int, Bool, CGFloat)] = [(L("서울"), 18, 4, false, -56), (L("도쿄"), 19, 4, false, 0), (L("뉴욕"), 12, 5, true, 56)]
        return ZStack {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                HStack(spacing: 8) {
                    CharacterSprite(character: .cat, level: r.2, rain: r.3 ? .none : .bag, width: 44, animate: false).frame(width: 44, height: 52).clipped()
                    Text(r.0).font(.px(13))
                    Spacer()
                    Text("\(r.1)°").font(.px(24))
                }
                .foregroundStyle(r.3 ? Color(hex: "#F3F5FF") : UI.ink)
                .padding(.horizontal, 10).frame(width: 220, height: 64)
                .background(LinearGradient(colors: [Color(hex: Rules.background[r.2]), r.3 ? Color(hex: "#2B3566") : .white], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color(hex: "#1E2A44").opacity(0.12), radius: 7, y: 6)
                .offset(x: CGFloat(i - 1) * 16, y: r.4)
            }
        }
    }

    /// The three characters as tiles, the first one chosen
    private var charsArt: some View {
        HStack(spacing: 12) {
            ForEach(Array(PurrCharacter.allCases.enumerated()), id: \.offset) { i, c in
                CharacterSprite(character: c, level: 4, rain: .none, width: 72, animate: false)
                    .frame(width: 92, height: 132)
                    .background(i == 0 ? Color(hex: "#D9EFCF") : Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(i == 0 ? UI.accent : Color.white, lineWidth: 3))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color(hex: "#1E2A44").opacity(i == 0 ? 0 : 0.06), radius: 5, y: 2)
            }
        }
    }

    private func miniPhone(ad: Bool) -> some View {
        VStack(spacing: 6) {
            Text("18°").font(.px(14)).foregroundStyle(UI.ink).frame(maxWidth: .infinity, alignment: .trailing)
            ForEach(0..<3, id: \.self) { k in
                RoundedRectangle(cornerRadius: 4)
                    .fill(ad && k == 1 ? UI.accentSoft : Color.white)
                    .overlay(ad && k == 1 ? Text("Ad").font(.ui(9, .bold)).foregroundStyle(UI.accent) : nil)
                    .frame(height: 18)
            }
        }
        .padding(8).frame(width: 74, height: 112).background(Color(hex: "#D9EFCF")).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// "✓ 광고 제거  ✓ 새 예보마다 …" wrapped in lines
struct FlowChecks: View {
    let items: [String]
    var body: some View {
        let rows = stride(from: 0, to: items.count, by: 3).map { Array(items[$0..<min($0 + 3, items.count)]) }
        VStack(spacing: 8) {
            ForEach(rows, id: \.self) { r in
                HStack(spacing: 8) {
                    ForEach(r, id: \.self) { t in
                        Text("✓ " + t).font(.ui(12, .medium)).foregroundStyle(UI.ink)
                            .padding(.horizontal, 10).padding(.vertical, 6).background(Color.white.opacity(0.8)).clipShape(Capsule())
                    }
                }
            }
        }.frame(maxWidth: .infinity)
    }
}

/// Legal pages. Hosted with the store listing; the URLs are filled in before review.
enum Legal {
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacy = URL(string: "https://moku143.github.io/purrcast/privacy.html")!
    /// 문의하기 · FAQ (docs/support.html on GitHub Pages)
    static let support: URL? = URL(string: "mailto:oo0785@daum.net?subject=%EA%B7%B8%EB%A5%B4%EB%A6%89%EB%82%A0%EC%94%A8%20%EB%AC%B8%EC%9D%98")
}
