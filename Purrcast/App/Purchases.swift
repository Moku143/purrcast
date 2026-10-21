import StoreKit
import SwiftUI

/// Purrcast Plus through StoreKit 2: one subscription group, yearly (14,900원) and monthly (1,900원),
/// both with a 3-day free trial for new subscribers. Products live in App Store Connect; for local runs the
/// scheme uses Purrcast.storekit.
@MainActor
final class Purchases: ObservableObject {
    static let yearly = "app.purrcast.plus.yearly"
    static let monthly = "app.purrcast.plus.monthly"
    static let ids = [yearly, monthly]

    @Published private(set) var products: [Product] = []
    @Published private(set) var active = false
    @Published private(set) var renewal: String?      // "연간 · 다음 결제 2027년 10월 21일"
    @Published var busy = false
    @Published var message: String?

    private var updates: Task<Void, Never>?

    init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result { await t.finish() }
                await self?.refresh()
            }
        }
    }

    func load() async {
        if let p = try? await Product.products(for: Self.ids) {
            products = p.sorted { $0.id == Self.yearly && $1.id != Self.yearly }
        }
        await refresh()
    }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    /// Shown price: from the store when loaded, otherwise the planned Korean price.
    func price(_ id: String) -> String {
        if let p = product(id) { return p.displayPrice }
        return id == Self.yearly ? "14,900원" : "1,900원"
    }

    func refresh() async {
        var on = false, info: String?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, Self.ids.contains(t.productID), t.revocationDate == nil else { continue }
            on = true
            if let exp = t.expirationDate {
                let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "yyyy년 M월 d일"
                info = (t.productID == Self.yearly ? "연간" : "월간") + " · 다음 결제 " + f.string(from: exp)
            }
        }
        active = on; renewal = info
    }

    /// true when the purchase went through
    func buy(_ id: String) async -> Bool {
        guard let p = product(id) else {
            message = "지금은 결제할 수 없어요. 잠시 뒤 다시 해 주세요."
            return false
        }
        busy = true; defer { busy = false }
        do {
            switch try await p.purchase() {
            case .success(let v):
                if case .verified(let t) = v { await t.finish(); await refresh(); return true }
                message = "결제를 확인하지 못했어요."
            case .pending: message = "승인을 기다리고 있어요."
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = "결제에 실패했어요." }
        return false
    }

    func restore() async {
        busy = true; defer { busy = false }
        try? await AppStore.sync()
        await refresh()
        message = active ? "Plus를 되찾았어요." : "복원할 구독이 없어요."
    }
}
