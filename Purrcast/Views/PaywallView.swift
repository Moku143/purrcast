import SwiftUI

/// Purrcast Plus: what you get (swipeable), yearly / monthly, 3-day free trial.
struct PaywallView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var purchases: Purchases
    @Environment(\.dismiss) private var dismiss
    @State private var pick = Purchases.yearly
    @State private var page = 0

    private let features: [(icon: String, title: String, note: String)] = [
        ("sparkle", "광고 없이", "화면 사이 광고가 사라져요."),
        ("daynight", "새 예보마다 업데이트", "무료는 하루 1번, Plus는 새 예보가 나올 때마다."),
        ("umbrella", "가까운 비", "비 올 시각까지 · 한국은 다음 6시간"),
        ("star", "애플워치", "워치 앱 · 워치 페이스 · 컴플리케이션"),
        ("heart", "지역 여러 곳", "무료는 1곳 더, Plus는 제한 없이."),
        ("fish", "캐릭터 바꾸기", "아비시니안 · 브리티시숏헤어, 더 나와요."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)) }
                        .foregroundStyle(UI.sub).accessibilityIdentifier("sheet-close")
                    Spacer()
                    Button("구독 복원") { Task { await purchases.restore() } }.font(.system(size: 14)).foregroundStyle(UI.sub)
                }
                .padding(.top, 18)

                HStack(spacing: 12) {
                    Image(PurrCharacter.cat.faceImage).resizable().scaledToFit().frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Purrcast Plus").font(.px(26)).foregroundStyle(UI.ink)
                        Text("옆으로 넘겨 보세요").font(.system(size: 13)).foregroundStyle(UI.sub)
                    }
                }
                .padding(.top, 14)

                TabView(selection: $page) {
                    ForEach(Array(features.enumerated()), id: \.offset) { i, f in
                        VStack(alignment: .leading, spacing: 10) {
                            featureArt(i)
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

                HStack(spacing: 6) {
                    ForEach(0..<features.count, id: \.self) { i in
                        Capsule().fill(i == page ? UI.accent : UI.faint.opacity(0.5)).frame(width: i == page ? 18 : 6, height: 6)
                    }
                }.frame(maxWidth: .infinity)

                FlowChecks(items: ["광고 제거", "새 예보마다", "가까운 비", "애플워치", "지역 여러 곳", "캐릭터"]).padding(.top, 16)

                HStack(spacing: 10) {
                    planCard(Purchases.yearly, title: "연간", note: "월 1,242원 꼴 · 35% 할인", badge: "가장 많이 골라요")
                    planCard(Purchases.monthly, title: "월간", note: "매달 결제", badge: nil)
                }
                .padding(.top, 22)

                PrimaryButton(title: model.plus ? "Plus 쓰는 중" : "3일 무료로 시작하기", busy: purchases.busy) {
                    guard !model.plus else { dismiss(); return }
                    Task { if await purchases.buy(pick) { dismiss() } }
                }
                .padding(.top, 14)
                .accessibilityIdentifier("subscribe")

                Text("3일 뒤 \(pick == Purchases.yearly ? "연" : "월") \(purchases.price(pick)) · 언제든 해지할 수 있어요")
                    .font(.system(size: 12)).foregroundStyle(UI.sub).frame(maxWidth: .infinity).padding(.top, 10)
                HStack(spacing: 6) {
                    Link("이용약관", destination: Legal.terms)
                    Text("·")
                    Link("개인정보 처리방침", destination: Legal.privacy)
                }
                .font(.system(size: 12)).foregroundStyle(UI.sub).frame(maxWidth: .infinity).padding(.top, 4).padding(.bottom, 30)
            }
            .padding(.horizontal, 20)
        }
        .background(LinearGradient(colors: [Color(hex: "#FFF6E3"), Color(hex: "#FFF0E6")], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .alert(purchases.message ?? "", isPresented: Binding(get: { purchases.message != nil }, set: { if !$0 { purchases.message = nil } })) {
            Button("확인", role: .cancel) {}
        }
    }

    private func planCard(_ id: String, title: String, note: String, badge: String?) -> some View {
        let on = pick == id
        return Button { pick = id } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(UI.sub)
                Text(purchases.price(id)).font(.px(20)).foregroundStyle(UI.ink)
                Text(note).font(.system(size: 11)).foregroundStyle(UI.sub)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(14).padding(.top, 6)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(on ? UI.accent : UI.line, lineWidth: on ? 2.5 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .top) {
                if let badge { PlusTag(text: badge).offset(y: -10) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("plan-\(title)")
    }

    /// Small picture per feature, drawn from app parts (no screenshots, so it stays language-neutral).
    @ViewBuilder private func featureArt(_ i: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.7))
            switch i {
            case 0:
                HStack(spacing: 18) {
                    miniPhone(ad: true)
                    Image(systemName: "arrow.right").foregroundStyle(UI.faint)
                    miniPhone(ad: false)
                }
            case 1:
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(0..<6, id: \.self) { k in
                        RoundedRectangle(cornerRadius: 3).fill(k == 1 ? UI.faint : UI.accent).frame(width: 14, height: k == 1 ? 18 : 70)
                    }
                }
            case 2:
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array([0, 0, 1, 3, 5, 4, 2, 1, 0, 0, 0, 0].enumerated()), id: \.offset) { _, v in
                        RoundedRectangle(cornerRadius: 2).fill(v > 0 ? Color(hex: "#1F5BD0") : UI.line).frame(width: 12, height: CGFloat(max(3, v * 16)))
                    }
                }
            case 3:
                RoundedRectangle(cornerRadius: 26).fill(Color(hex: "#1B1F2E")).frame(width: 104, height: 124)
                    .overlay(CharacterSprite(character: .cat, level: 4, rain: .none, width: 70, animate: false).offset(y: 6))
            case 4:
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
                    .overlay(ad && k == 1 ? Text("Ad").font(.system(size: 9, weight: .bold)).foregroundStyle(UI.accent) : nil)
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
                        Text("✓ " + t).font(.system(size: 12, weight: .medium)).foregroundStyle(UI.ink)
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
    /// support address for 문의하기 (set before release; the row is hidden while nil)
    static let support: URL? = nil
}
