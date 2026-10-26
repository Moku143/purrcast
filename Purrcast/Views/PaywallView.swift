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
        if Features.adsInFree { f.append(Feature(art: "ads", title: "광고 없이", note: "화면 사이 광고가 사라져요.", check: "광고 제거")) }
        f += [
            Feature(art: "fresh", title: "새 예보마다 업데이트", note: "무료는 아침 예보 하나, Plus는 새 예보가 나올 때마다.", check: "새 예보마다"),
            Feature(art: "rain", title: "가까운 비", note: "앞으로 6시간, 언제 얼마나 오는지.", check: "가까운 비"),
            Feature(art: "watch", title: "애플워치", note: "워치 앱 · 컴플리케이션", check: "애플워치"),
            Feature(art: "places", title: "지역 여러 곳", note: "무료는 1곳 더, Plus는 제한 없이.", check: "지역 여러 곳"),
            Feature(art: "chars", title: "캐릭터 바꾸기", note: "아비시니안 · 브리티시숏헤어 · 추후 업데이트로 추가 예정", check: "캐릭터"),
        ]
        return f
    }

    var body: some View {
        let features = Self.features
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)) }
                        .foregroundStyle(UI.sub).accessibilityIdentifier("sheet-close").accessibilityLabel("닫기")
                    Spacer()
                    Button("구독 복원") { Task { await purchases.restore() } }.font(.system(size: 14)).foregroundStyle(UI.sub)
                        .disabled(purchases.busy)
                }
                .padding(.top, 18)

                HStack(spacing: 12) {
                    Image(PurrCharacter.cat.faceImage).resizable().scaledToFit().frame(width: 46, height: 46).reveal(0, rise: 8)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(Brand.plus).font(.px(26)).foregroundStyle(UI.ink)
                        Text("옆으로 넘겨 보세요").font(.ui(13)).foregroundStyle(UI.sub)
                    }
                }
                .padding(.top, 14)

                TabView(selection: $page) {
                    ForEach(Array(features.enumerated()), id: \.offset) { i, f in
                        VStack(alignment: .leading, spacing: 10) {
                            featureArt(f.art)
                            Text(f.title).font(.px(19)).foregroundStyle(UI.ink)
                            Text(f.note).font(.system(size: 14)).foregroundStyle(UI.sub)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 270)
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
                    planCard(Purchases.yearly, title: "연간",
                             note: [purchases.yearlyPerMonth().map { "월 \($0) 꼴" }, purchases.yearlySaving().map { "\($0)% 할인" }].compactMap { $0 }.joined(separator: " · "),
                             badge: "가장 많이 골라요")
                    planCard(Purchases.monthly, title: "월간", note: "매달 결제", badge: nil)
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
                    Link("이용약관(EULA)", destination: Legal.terms)
                    Text("·")
                    Link("개인정보 처리방침", destination: Legal.privacy)
                }
                .font(.ui(12)).foregroundStyle(UI.sub).frame(maxWidth: .infinity).padding(.top, 6).padding(.bottom, 30)
            }
            .padding(.horizontal, 20)
        }
        .background(LinearGradient(colors: [Color(hex: "#FFF6E3"), Color(hex: "#FFF0E6")], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .alert(purchases.message ?? "", isPresented: Binding(get: { purchases.message != nil }, set: { if !$0 { purchases.message = nil } })) {
            Button("확인", role: .cancel) {}
        }
        .task { if !purchases.loaded { await purchases.load() } }
    }

    private var buttonTitle: String {
        if model.plus { return "Plus 쓰는 중" }
        if purchases.product(pick) == nil { return purchases.loaded ? "지금은 구독할 수 없어요" : "가격 불러오는 중…" }
        if let t = purchases.trialText(pick) { return "\(t)로 시작하기" }
        return "\(purchases.periodWord(pick)) \(purchases.price(pick) ?? "") 구독하기"
    }

    /// The auto-renew terms, with the real price and period of the selected plan.
    private var disclosure: String {
        guard let price = purchases.price(pick) else { return "구독은 App Store 계정으로 결제되고, App Store 설정에서 언제든 해지할 수 있어요." }
        let per = purchases.periodWord(pick)
        let lead = purchases.trialText(pick).map { "\($0) 체험이 끝나면 " } ?? ""
        return "\(lead)\(per) \(price)이 App Store 계정으로 결제되고, 기간이 끝나기 24시간 전까지 해지하지 않으면 같은 금액으로 자동 갱신돼요. 해지는 App Store 계정 설정에서 언제든 할 수 있어요."
    }

    private func planCard(_ id: String, title: String, note: String, badge: String?) -> some View {
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
        .accessibilityIdentifier("plan-\(title)")
    }

    /// Small picture per feature, drawn from app parts (no screenshots, so it stays language-neutral).
    @ViewBuilder private func featureArt(_ key: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.7))
            switch key {
            case "ads":
                HStack(spacing: 18) {
                    miniPhone(ad: true)
                    Image(systemName: "arrow.right").foregroundStyle(UI.faint)
                    miniPhone(ad: false)
                }
            case "fresh":
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(0..<6, id: \.self) { k in
                        RoundedRectangle(cornerRadius: 3).fill(k == 1 ? UI.faint : UI.accent).frame(width: 14, height: k == 1 ? 18 : 70)
                    }
                }
            case "rain":
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array([0, 0, 1, 3, 5, 4, 2, 1, 0, 0, 0, 0].enumerated()), id: \.offset) { _, v in
                        RoundedRectangle(cornerRadius: 2).fill(v > 0 ? Color(hex: "#1F5BD0") : UI.line).frame(width: 12, height: CGFloat(max(3, v * 16)))
                    }
                }
            case "watch":
                RoundedRectangle(cornerRadius: 26).fill(Color(hex: "#1B1F2E")).frame(width: 104, height: 124)
                    .overlay(CharacterSprite(character: .cat, level: 4, rain: .none, width: 70, animate: false).offset(y: 6))
            case "places":
                VStack(spacing: 8) {
                    ForEach([("서울", 18), ("도쿄", 19), ("뉴욕", 12)], id: \.0) { n, t in
                        HStack { Text(n).font(.px(14)); Spacer(); Text("\(t)°").font(.px(16)) }
                            .foregroundStyle(UI.ink).padding(.horizontal, 14).frame(width: 190, height: 34)
                            .background(UI.bg).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            default:
                HStack(spacing: -6) {
                    ForEach(PurrCharacter.allCases) { c in CharacterSprite(character: c, level: 2, rain: .none, width: 86, animate: false) }
                }.offset(y: 8)
            }
        }
        .frame(height: 170)
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
