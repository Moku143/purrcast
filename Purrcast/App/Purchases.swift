import StoreKit
import SwiftUI

/// Purrcast Plus through StoreKit 2: one subscription group, yearly and monthly, with a free trial for new
/// subscribers (3 days in App Store Connect). Prices, trial length and eligibility always come from the store;
/// nothing is hard-coded except the wording around them.
@MainActor
final class Purchases: ObservableObject {
    static let yearly = "app.purrcast.plus.yearly"
    static let monthly = "app.purrcast.plus.monthly"
    static let ids = [yearly, monthly]

    @Published private(set) var products: [Product] = []
    @Published private(set) var active = false
    @Published private(set) var expires: Date?
    @Published private(set) var activeProduct: String?
    @Published private(set) var willRenew = true
    @Published private(set) var trialEligible = true
    @Published private(set) var loaded = false
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

    /// Entitlements first (works offline from the local receipt), then the product list.
    func load() async {
        await refresh()
        if let p = try? await Product.products(for: Self.ids) {
            products = p.sorted { $0.id == Self.yearly && $1.id != Self.yearly }
        }
        if let any = products.first, let sub = any.subscription {
            trialEligible = await sub.isEligibleForIntroOffer
        }
        loaded = true
    }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    /// Store price ("₩14,900"), or nil until the products are loaded.
    func price(_ id: String) -> String? { product(id)?.displayPrice }

    /// "연" / "월"
    func periodWord(_ id: String) -> String {
        guard let p = product(id)?.subscription?.subscriptionPeriod else { return id == Self.yearly ? "연" : "월" }
        switch p.unit { case .year: return "연"; case .month: return p.value == 1 ? "월" : "\(p.value)개월"; case .week: return "주"; default: return "일" }
    }

    /// "3일 무료" when this person can still get the trial, else nil.
    func trialText(_ id: String) -> String? {
        guard trialEligible, let o = product(id)?.subscription?.introductoryOffer, o.paymentMode == .freeTrial else { return nil }
        let n = o.period.value
        switch o.period.unit { case .day: return "\(n)일 무료"; case .week: return "\(n * 7)일 무료"; case .month: return "\(n)개월 무료"; default: return "무료 체험" }
    }

    /// Yearly price per month in the store's currency, e.g. "₩1,242".
    func yearlyPerMonth() -> String? {
        guard let y = product(Self.yearly) else { return nil }
        return (y.price / 12).formatted(y.priceFormatStyle)
    }

    /// Saving of yearly against 12 × monthly, e.g. 35.
    func yearlySaving() -> Int? {
        guard let y = product(Self.yearly), let m = product(Self.monthly), m.price > 0 else { return nil }
        let full = NSDecimalNumber(decimal: m.price * 12).doubleValue, yr = NSDecimalNumber(decimal: y.price).doubleValue
        let pct = Int(((1 - yr / full) * 100).rounded())
        return pct > 0 ? pct : nil
    }

    func refresh() async {
        var on = false, until: Date?, which: String?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, Self.ids.contains(t.productID), t.revocationDate == nil else { continue }
            if let e = t.expirationDate, e < Date() { continue }
            on = true; which = t.productID
            if let e = t.expirationDate, until == nil || e > until! { until = e }
        }
        var renew = true
        if on, let id = which, let statuses = try? await product(id)?.subscription?.status {
            for s in statuses where s.state == .subscribed || s.state == .inGracePeriod || s.state == .inBillingRetryPeriod {
                if case .verified(let info) = s.renewalInfo { renew = info.willAutoRenew }
            }
        }
        active = on; expires = until; activeProduct = which; willRenew = renew
    }

    /// "연간 · 2027년 10월 21일에 자동 갱신" / "월간 · 11월 21일에 끝나요"
    var statusLine: String? {
        guard active else { return nil }
        let kind = activeProduct == Self.monthly ? "월간" : "연간"
        guard let e = expires else { return kind }
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "yyyy년 M월 d일"
        return "\(kind) · " + f.string(from: e) + (willRenew ? "에 자동 갱신" : "에 끝나요")
    }

    /// true when the purchase went through
    func buy(_ id: String) async -> Bool {
        guard !busy else { return false }
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
            case .pending: message = "승인을 기다리고 있어요. 승인되면 Plus가 켜져요."
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = "결제에 실패했어요." }
        return false
    }

    func restore() async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        do {
            try await AppStore.sync()
            await refresh()
            message = active ? "Plus를 되찾았어요." : "이 Apple 계정에는 복원할 구독이 없어요."
        } catch {
            message = "복원하지 못했어요. 잠시 뒤 다시 해 주세요."
        }
    }
}
