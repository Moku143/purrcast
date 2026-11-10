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
    /// This period is the free trial / comes from an offer code (쿠폰)
    @Published private(set) var inTrial = false
    @Published private(set) var onCoupon = false
    /// An offer code redeemed while already subscribed (in the trial, say) waits for the next renewal: it starts
    /// when this period ends, as long as auto-renew stays on (App Store: "11월 10일부터 1년 동안 무료 프로모션으로 갱신")
    @Published private(set) var couponNext = false
    @Published private(set) var trialEligible = true
    @Published private(set) var loaded = false
    @Published var busy = false
    @Published var message: String?

    /// TestFlight and debug builds only (the developer and testers): Plus with no time limit and no purchase, on
    /// from the first launch. 설정 turns it off (to see the free app, and that everything Plus goes away); the Plus
    /// page turns it back on. An App Store build (production environment) never has it.
    @Published private(set) var testBuild = false
    @Published private(set) var testUntil: Date? = SharedStore.defaults.object(forKey: "testPlusUntil") as? Date
    /// Screenshots and UI tests (-scene) set the plan themselves (-plus): a test trial left from another run
    /// (the unit tests start one in the same simulator) does not count there
    private static let planPinned = ProcessInfo.processInfo.arguments.contains("-scene")
    var testActive: Bool { testBuild && !Self.planPinned && (testUntil.map { $0 > Date() } ?? false) }
    /// The store has nothing to sell here, but this is a test build: offer the test Plus.
    var offersTestTrial: Bool { testBuild && loaded && products.isEmpty }
    /// turned off in 설정 on purpose: stays off until the Plus page turns it on again
    private var testOff: Bool { SharedStore.defaults.bool(forKey: "testPlusOff") }
    private static let unlimited = Date(timeIntervalSince1970: 4_102_444_800)    // 2100-01-01: no time limit

    private var updates: Task<Void, Never>?

    init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result { await t.finish() }
                await self?.refresh()
                // a new transaction can also spend the intro trial (an offer code among them):
                // the Plus page's "3일 무료" must follow
                await self?.refreshTrialEligibility()
            }
        }
    }

    /// Entitlements first (works offline from the local receipt), then the product list.
    func load() async {
        testBuild = await Self.isTestEnvironment()
        // developers and testers: Plus on, without a time limit (not in screenshots and UI tests, which set the plan)
        let args = ProcessInfo.processInfo.arguments
        if testBuild, !testOff, !args.contains("-scene"), !args.contains("-reset"), (testUntil ?? .distantPast) < Self.unlimited {
            startTestTrial()
        }
        await refresh()
        await loadProducts()
        await refresh()     // again with the product list: auto-renew is read through it (the first pass is offline-safe)
        loaded = true
    }

    /// The subscriptions and their prices from the App Store (offline at launch: none until asked again)
    func loadProducts() async {
        if let p = try? await Product.products(for: Self.ids) {
            products = p.sorted { $0.id == Self.yearly && $1.id != Self.yearly }
        }
        await refreshTrialEligibility()
    }

    /// Whether this account can still take the intro trial — read again after every new transaction, since a
    /// purchase or a redeemed offer code spends it.
    func refreshTrialEligibility() async {
        guard let sub = products.first?.subscription else { return }
        trialEligible = await sub.isEligibleForIntroOffer
    }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    /// TestFlight / Xcode → true; the App Store → false. The build sent to App Review (TestFlight's `submission: yes`)
    /// is never a test build: App Review's purchases run in the sandbox too, and must see the real Plus page.
    private static func isTestEnvironment() async -> Bool {
        #if DEBUG
        return true
        #elseif STORE_SUBMISSION
        return false
        #else
        if case .verified(let t)? = try? await AppTransaction.shared { return t.environment != .production }
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }

    func startTestTrial() {
        guard testBuild else { return }
        testUntil = Self.unlimited
        SharedStore.defaults.set(testUntil, forKey: "testPlusUntil")
        SharedStore.defaults.set(false, forKey: "testPlusOff")
    }

    func endTestTrial() {
        testUntil = nil
        SharedStore.defaults.removeObject(forKey: "testPlusUntil")
        SharedStore.defaults.set(true, forKey: "testPlusOff")
    }

    /// Store price ("₩18,000"), or nil until the products are loaded.
    func price(_ id: String) -> String? { product(id)?.displayPrice }

    /// "연" / "월"
    func periodWord(_ id: String) -> String {
        guard let p = product(id)?.subscription?.subscriptionPeriod else { return id == Self.yearly ? L("연") : L("월") }
        switch p.unit { case .year: return L("연"); case .month: return p.value == 1 ? L("월") : L("%d개월", p.value); case .week: return L("주"); default: return L("일") }
    }

    /// "3일 무료" when this person can still get the trial, else nil.
    func trialText(_ id: String) -> String? {
        guard trialEligible, let o = product(id)?.subscription?.introductoryOffer, o.paymentMode == .freeTrial else { return nil }
        let n = o.period.value
        switch o.period.unit { case .day: return L("%d일 무료", n); case .week: return L("%d일 무료", n * 7); case .month: return L("%d개월 무료", n); default: return L("무료 체험") }
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
        var on = false, until: Date?, which: String?, offer: StoreKit.Transaction.OfferType?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, Self.ids.contains(t.productID), t.revocationDate == nil else { continue }
            if let e = t.expirationDate, e < Date() { continue }
            on = true; which = t.productID
            if let e = t.expirationDate, until == nil || e > until! { until = e; offer = Self.offerType(t) }
        }
        var renew = true, next = false
        if on, let id = which, let statuses = try? await product(id)?.subscription?.status {
            for s in statuses where s.state == .subscribed || s.state == .inGracePeriod || s.state == .inBillingRetryPeriod {
                if case .verified(let info) = s.renewalInfo {
                    renew = info.willAutoRenew
                    if let o = info.offerType, o == .code { next = true }
                }
            }
        }
        active = on; expires = until; activeProduct = which; willRenew = renew
        inTrial = on && offer == .introductory; onCoupon = on && offer == .code; couponNext = on && next
    }

    private static func offerType(_ t: StoreKit.Transaction) -> StoreKit.Transaction.OfferType? {
        if #available(iOS 17.2, *) { return t.offer?.type }
        return t.offerType
    }

    /// How long past the paid period's end the widgets and the watch keep Plus when it renews by itself: they cannot
    /// ask the App Store, so a renewal at night must not turn them to Free before the app has opened and seen it
    /// (the App Store charges a renewal within the 24 hours before the period ends)
    nonisolated static let widgetAllowance: TimeInterval = 86400

    /// The end of Plus handed to the widgets and the watch: the paid period's end, a day more when auto-renew is on;
    /// nil (no limit) for an active plan without an end. Not active (expired, revoked or refunded): the TestFlight test
    /// Plus's end, if that is on, else nil — the snapshot's plan is Free then anyway.
    nonisolated static func widgetPlusUntil(active: Bool, expires: Date?, willRenew: Bool, testUntil: Date?) -> Date? {
        guard active else { return testUntil }
        guard let e = expires else { return nil }
        return willRenew ? e.addingTimeInterval(widgetAllowance) : e
    }

    /// Where the plan stands, with no renewal wording (the Plus page says how renewal works):
    /// "연간 · 2026년 11월 11일 무료 체험 종료" · "… 무료 체험 종료 · 이후 쿠폰 적용" (a code redeemed during the trial
    /// starts when it ends) · "연간 · 2027년 11월 10일까지 쿠폰 적용" · "월간 · 2026년 12월 11일까지"
    var statusLine: String? {
        if !active, testActive { return L("테스트 Plus · 기간 제한 없음") }
        guard active else { return nil }
        let kind = activeProduct == Self.monthly ? L("월간") : L("연간")
        guard let e = expires else { return kind }
        let f = DateFormatter(); f.locale = Lang.current.locale; f.dateFormat = L("yyyy년 M월 d일")
        let day = f.string(from: e)
        if inTrial { return willRenew && couponNext ? L("%@ · %@ 무료 체험 종료 · 이후 쿠폰 적용", kind, day) : L("%@ · %@ 무료 체험 종료", kind, day) }
        if onCoupon { return L("%@ · %@까지 쿠폰 적용", kind, day) }
        return L("%@ · %@까지", kind, day)
    }

    /// true when the purchase went through
    func buy(_ id: String) async -> Bool {
        guard !busy else { return false }
        guard let p = product(id) else {
            message = L("지금은 결제할 수 없어요. 잠시 뒤 다시 해 주세요.")
            return false
        }
        busy = true; defer { busy = false }
        do {
            switch try await p.purchase() {
            case .success(let v):
                if case .verified(let t) = v { await t.finish(); await refresh(); return true }
                message = L("결제를 확인하지 못했어요.")
            case .pending: message = L("승인을 기다리고 있어요. 승인되면 Plus가 켜져요.")
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = L("결제에 실패했어요.") }
        return false
    }

    func restore() async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        do {
            try await AppStore.sync()
            await refresh()
            message = active ? L("Plus를 되찾았어요.") : L("이 Apple 계정에는 복원할 구독이 없어요.")
        } catch {
            message = L("복원하지 못했어요. 잠시 뒤 다시 해 주세요.")
        }
    }
}
