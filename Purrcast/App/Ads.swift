import SwiftUI
import UIKit
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform

/// Ads for Free (AdMob). Plus sees none.
///
/// Where: two cards on home (under 시간별 and under 10일), one in the day sheet (under the summary), a banner pinned
/// under home · 지역 · 설정, and a full-screen ad as the day sheet or 지역 opens (every 2nd opening, a minute apart at
/// least). Each comes with our own "광고 없애기 · Plus ›" line outside the ad. The widgets, the watch, notifications
/// and the Live Activity never carry ads (App Review 2.5.18), nor does the Plus page.
///
/// Asking: Europe/UK get Google's consent form (UMP, the law) when home first opens; everyone then gets Apple's
/// tracking prompt once, a second after home first shows, with no screen of our own before it. Ads load either way.
///
/// How many of each comes from the server (`/v1/ads`), so it can be turned down without an app update.
@MainActor
final class Ads: ObservableObject {
    static let shared = Ads()

    enum Unit {
        case banner, interstitial, homeNative, dayNative
        var id: String {
            if Ads.sampleUnits {
                switch self {
                case .banner: return "ca-app-pub-3940256099942544/2435281174"
                case .interstitial: return "ca-app-pub-3940256099942544/4411468910"
                case .homeNative, .dayNative: return "ca-app-pub-3940256099942544/3986624511"
                }
            }
            switch self {
            case .banner: return "ca-app-pub-3820798685245860/3467140040"
            case .interstitial: return "ca-app-pub-3820798685245860/2686530518"
            case .homeNative: return "ca-app-pub-3820798685245860/7873288919"
            case .dayNative: return "ca-app-pub-3820798685245860/5247125574"
            }
        }
    }

    /// What the server can turn down (`/v1/ads`); a missing field keeps its default
    struct Config: Decodable, Equatable {
        var on = true
        var homeCards = 2               // 0 · 1 (under 시간별) · 2 (and under 10일)
        var dayCard = true
        var banner = true
        var every = 2                   // the n-th opening of the day sheet or 지역 shows a full-screen ad; 0 = never
        var gap: Double = 60            // seconds between two full-screen ads at least
        init() {}
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: K.self)
            on = try c.decodeIfPresent(Bool.self, forKey: .on) ?? true
            homeCards = try c.decodeIfPresent(Int.self, forKey: .homeCards) ?? 2
            dayCard = try c.decodeIfPresent(Bool.self, forKey: .dayCard) ?? true
            banner = try c.decodeIfPresent(Bool.self, forKey: .banner) ?? true
            every = try c.decodeIfPresent(Int.self, forKey: .interstitialEvery) ?? 2
            gap = try c.decodeIfPresent(Double.self, forKey: .interstitialGap) ?? 60
        }
        private enum K: String, CodingKey { case on, homeCards, dayCard, banner, interstitialEvery, interstitialGap }
    }

    /// Debug builds show no ads unless asked: `-adsDemo` draws stand-ins (no SDK; the layout pictures), `-adsLive`
    /// loads Google's sample ads. The UI tests pass neither.
    static let demo: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-adsDemo")
        #else
        return false
        #endif
    }()
    private static let live: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-adsLive")
        #else
        return true
        #endif
    }()
    /// Google's sample units in debug and TestFlight builds, so a tap while testing never counts against the account;
    /// the build sent to App Review (and so the App Store) loads ours.
    static let sampleUnits: Bool = {
        #if DEBUG
        return true
        #elseif STORE_SUBMISSION
        return false
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }()

    @Published private(set) var config = Config()
    /// Not Plus (`PurrcastApp.syncPlan`)
    @Published private(set) var free = false
    /// Consent settled and the SDK started
    @Published private(set) var ready = false
    /// Europe/UK: 설정 shows a row to change the consent
    @Published private(set) var privacyOptions = false
    @Published private(set) var home: [Int: NativeAd] = [:]
    @Published private(set) var day: NativeAd?

    /// Ads show now
    var on: Bool { Features.adsInFree && free && config.on && (ready || Self.demo) }

    private var started = false
    private var interstitial: InterstitialAd?
    private var loadingFull = false
    private let watcher = FullScreenWatcher()
    private var opens = 0
    private var lastFull = Date.distantPast
    private var homeLoaded = Date.distantPast
    private var fetches: [NativeFetch] = []

    /// The plan or the first-run pages changed. Starts once, on home, for Free.
    func update(plus: Bool, onboarded: Bool) {
        free = !plus
        guard Features.adsInFree, free, onboarded, !started, Self.live || Self.demo else { return }
        started = true
        if !Self.demo { Task { await start() } }
    }

    private func start() async {
        await loadConfig()
        await gatherConsent()
        privacyOptions = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        #if !DEBUG
        // Apple's prompt alone, once, a second after home shows (the app must be active for it to appear; if it was
        // not, the next launch asks)
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
        #endif
        guard ConsentInformation.shared.canRequestAds else { return }
        MobileAds.shared.start()
        ready = true
        loadInterstitial()
        loadHome()
        loadDay()
    }

    /// Google's consent form where the law asks for it (Europe/UK); elsewhere nothing shows
    private func gatherConsent() async {
        let asked: Bool = await withCheckedContinuation { done in
            ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { error in done.resume(returning: error == nil) }
        }
        if asked { try? await ConsentForm.loadAndPresentIfRequired(from: nil) }
    }

    /// 설정 › 광고 개인정보 설정 (Europe/UK)
    func showPrivacyOptions() {
        Task { try? await ConsentForm.presentPrivacyOptionsForm(from: Self.top()) }
    }

    private func loadConfig() async {
        guard let base = WeatherSource.serverURL else { return }
        var r = URLRequest(url: base.appendingPathComponent("v1/ads"))
        r.timeoutInterval = 5
        guard let (data, resp) = try? await URLSession.shared.data(for: r), (resp as? HTTPURLResponse)?.statusCode == 200,
              let c = try? JSONDecoder().decode(Config.self, from: data) else { return }
        config = c
    }

    // MARK: full screen

    fileprivate func loadInterstitial() {
        guard ready, config.every > 0, interstitial == nil, !loadingFull else { return }
        loadingFull = true
        Task {
            let ad = try? await InterstitialAd.load(with: Unit.interstitial.id, request: Request())
            ad?.fullScreenContentDelegate = watcher
            interstitial = ad
            loadingFull = false
        }
    }

    /// The day sheet or 지역 opened: every n-th time, a minute apart at least, a full-screen ad once the sheet is up
    func screenOpened() {
        guard on, !Self.demo, config.every > 0 else { return }
        opens += 1
        guard opens % config.every == 0, Date().timeIntervalSince(lastFull) >= config.gap, let ad = interstitial else { return }
        interstitial = nil
        lastFull = Date()
        Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            ad.present(from: Self.top())
        }
    }

    // MARK: cards

    private func loadHome() {
        guard ready else { return }
        homeLoaded = Date()
        for i in 0..<min(2, config.homeCards) { fetch(.homeNative) { [weak self] ad in self?.home[i] = ad } }
    }

    private func loadDay() {
        guard ready, config.dayCard else { return }
        fetch(.dayNative) { [weak self] ad in self?.day = ad }
    }

    /// Back in the app after a while: fresh cards on home
    func foreground() {
        if ready, Date().timeIntervalSince(homeLoaded) > 180 { loadHome() }
    }

    /// The day sheet closed: its next opening gets a fresh card
    func dayClosed() { loadDay() }

    private func fetch(_ unit: Unit, _ done: @escaping (NativeAd) -> Void) {
        let f = NativeFetch(unit: unit.id)
        f.done = { [weak self, weak f] ad in
            if let ad { done(ad) }
            self?.fetches.removeAll { $0 === f }
        }
        fetches.append(f)
        f.start()
    }

    // MARK: helpers

    /// The view controller on top (a sheet when one is up), for the full-screen ad and the consent forms
    static func top() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var vc = (scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)?.keyWindow?.rootViewController
        while let p = vc?.presentedViewController, !p.isBeingDismissed { vc = p }
        return vc
    }

    static var screenWidth: CGFloat {
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen.bounds.width }.first ?? 390
    }
}

/// One native ad on its way (the loader must be kept until it answers)
private final class NativeFetch: NSObject, NativeAdLoaderDelegate {
    private let unit: String
    private var loader: AdLoader?
    var done: ((NativeAd?) -> Void)?
    init(unit: String) { self.unit = unit }
    func start() {
        let l = AdLoader(adUnitID: unit, rootViewController: nil, adTypes: [.native], options: nil)
        l.delegate = self
        loader = l
        l.load(Request())
    }
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) { done?(nativeAd); done = nil }
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) { done?(nil); done = nil }
}

/// A full-screen ad closed (or could not show): load the next
private final class FullScreenWatcher: NSObject, FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) { Task { @MainActor in Ads.shared.loadInterstitial() } }
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in Ads.shared.loadInterstitial() }
    }
}

// MARK: - views

/// "광고 없애기 · Plus ›": ours, outside the ad, to the Plus page
struct RemoveAdsLink: View {
    let action: () -> Void
    var body: some View {
        Button { Haptic.soft(); action() } label: {
            Text(L("광고 없애기 · Plus ›")).font(.ui(12, .semibold)).foregroundStyle(UI.accent)
                .padding(.vertical, 4).padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("remove-ads")
    }
}

/// A native ad drawn like the app's own cards, with our link under it. Nothing (no gap) until an ad has come.
struct AdCard: View {
    enum Slot { case home(Int), day }
    let slot: Slot
    let ink: Ink
    let plus: () -> Void
    @ObservedObject private var ads = Ads.shared

    private var ad: NativeAd? {
        switch slot {
        case .home(let i): return ads.home[i]
        case .day: return ads.day
        }
    }
    private var allowed: Bool {
        switch slot {
        case .home(let i): return ads.config.homeCards > i
        case .day: return ads.config.dayCard
        }
    }

    var body: some View {
        if ads.on, allowed, Ads.demo || ad != nil {
            VStack(alignment: .trailing, spacing: 4) {
                Group {
                    if let ad { NativeBox(ad: ad, night: ink.night) } else { DemoNative(ink: ink) }
                }
                .frame(height: NativeLayout.height)
                .background(ink.card)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(ink.cardBorder, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: Color(hex: "#1E2A44").opacity(ink.night ? 0.22 : 0.08), radius: 9, y: 6)
                RemoveAdsLink(action: plus)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("ad-card")
        }
    }
}

/// The banner pinned under a page, with our link above it. Takes no room until an ad has come.
struct AdBanner: View {
    let plus: () -> Void
    @ObservedObject private var ads = Ads.shared
    @State private var loaded = false

    var body: some View {
        if ads.on, ads.config.banner {
            let size = largeAnchoredAdaptiveBanner(width: Ads.screenWidth)
            let shown = loaded || Ads.demo
            VStack(spacing: 0) {
                if shown { RemoveAdsLink(action: plus).frame(maxWidth: .infinity, alignment: .trailing).padding(.horizontal, 10) }
                Group {
                    if Ads.demo { DemoBanner() } else { BannerBox(size: size) { loaded = true } }
                }
                .frame(width: size.size.width, height: shown ? (Ads.demo ? 62 : size.size.height) : 1)
            }
            .frame(maxWidth: .infinity)
            .background { if shown { Rectangle().fill(.bar).ignoresSafeArea() } }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("ad-banner")
        }
    }
}

private struct BannerBox: UIViewRepresentable {
    let size: AdSize
    let loaded: () -> Void
    func makeUIView(context: Context) -> BannerView {
        let b = BannerView(adSize: size)
        b.adUnitID = Ads.Unit.banner.id
        b.delegate = context.coordinator
        b.load(Request())
        return b
    }
    func updateUIView(_ uiView: BannerView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(loaded: loaded) }
    final class Coordinator: NSObject, BannerViewDelegate {
        let loaded: () -> Void
        init(loaded: @escaping () -> Void) { self.loaded = loaded }
        func bannerViewDidReceiveAd(_ bannerView: BannerView) { DispatchQueue.main.async { self.loaded() } }
    }
}

private struct NativeBox: UIViewRepresentable {
    let ad: NativeAd
    let night: Bool
    func makeUIView(context: Context) -> NativeAdView { NativeLayout.make(night: night) }
    func updateUIView(_ v: NativeAdView, context: Context) { NativeLayout.fill(v, ad: ad, night: night) }
}

/// The native ad's own views (Google's NativeAdView needs UIKit ones it can register)
enum NativeLayout {
    static let height: CGFloat = 176

    static func make(night: Bool) -> NativeAdView {
        let v = NativeAdView()
        v.backgroundColor = .clear

        let badge = InsetLabel()
        badge.text = L("광고")
        badge.font = .systemFont(ofSize: 11, weight: .bold)
        badge.textColor = UIColor(red: 0.16, green: 0.12, blue: 0, alpha: 1)
        badge.backgroundColor = UIColor(red: 1, green: 0.8, blue: 0, alpha: 1)
        badge.layer.cornerRadius = 5
        badge.clipsToBounds = true
        badge.setContentHuggingPriority(.required, for: .horizontal)

        let advertiser = UILabel()
        advertiser.font = .systemFont(ofSize: 12, weight: .semibold)
        advertiser.lineBreakMode = .byTruncatingTail

        let top = UIStackView(arrangedSubviews: [badge, advertiser, UIView()])
        top.axis = .horizontal; top.spacing = 6; top.alignment = .center

        let media = MediaView()
        media.contentMode = .scaleAspectFill
        media.clipsToBounds = true
        media.layer.cornerRadius = 12
        media.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([media.widthAnchor.constraint(equalToConstant: 120), media.heightAnchor.constraint(equalToConstant: 120)])

        let headline = UILabel()
        headline.font = .systemFont(ofSize: 15, weight: .bold)
        headline.numberOfLines = 2
        let body = UILabel()
        body.font = .systemFont(ofSize: 12.5)
        body.numberOfLines = 2

        // a label drawn as a button: the whole ad view takes the tap
        let cta = InsetLabel(inset: UIEdgeInsets(top: 7, left: 14, bottom: 7, right: 14))
        cta.font = .systemFont(ofSize: 13, weight: .bold)
        cta.textColor = .white
        cta.backgroundColor = UIColor(red: 0.04, green: 0.52, blue: 1, alpha: 1)
        cta.layer.cornerRadius = 15
        cta.clipsToBounds = true

        let right = UIStackView(arrangedSubviews: [headline, body, cta])
        right.axis = .vertical; right.spacing = 6; right.alignment = .leading
        let row = UIStackView(arrangedSubviews: [media, right])
        row.axis = .horizontal; row.spacing = 12; row.alignment = .center
        let all = UIStackView(arrangedSubviews: [top, row])
        all.axis = .vertical; all.spacing = 8
        all.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(all)
        NSLayoutConstraint.activate([
            all.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 14),
            all.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -14),
            all.centerYAnchor.constraint(equalTo: v.centerYAnchor),
        ])

        v.headlineView = headline
        v.bodyView = body
        v.mediaView = media
        v.callToActionView = cta
        v.advertiserView = advertiser
        paint(v, night: night)
        return v
    }

    static func fill(_ v: NativeAdView, ad: NativeAd, night: Bool) {
        paint(v, night: night)
        (v.headlineView as? UILabel)?.text = ad.headline
        (v.bodyView as? UILabel)?.text = ad.body
        v.bodyView?.isHidden = ad.body == nil
        (v.advertiserView as? UILabel)?.text = ad.advertiser ?? ad.store ?? ""
        v.mediaView?.mediaContent = ad.mediaContent
        (v.callToActionView as? UILabel)?.text = ad.callToAction
        v.callToActionView?.isHidden = ad.callToAction == nil
        v.nativeAd = ad
    }

    private static func paint(_ v: NativeAdView, night: Bool) {
        let ink = Ink(night: night)
        (v.headlineView as? UILabel)?.textColor = UIColor(ink.ink)
        (v.bodyView as? UILabel)?.textColor = UIColor(ink.sub)
        (v.advertiserView as? UILabel)?.textColor = UIColor(ink.sub)
    }
}

private final class InsetLabel: UILabel {
    private let inset: UIEdgeInsets
    init(inset: UIEdgeInsets = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)) {
        self.inset = inset
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: inset)) }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + inset.left + inset.right, height: s.height + inset.top + inset.bottom)
    }
}

// MARK: stand-ins (-adsDemo, debug only: the layout pictures without the SDK)

private struct DemoNative: View {
    let ink: Ink
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(L("광고")).font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: "#291F00"))
                    .padding(.horizontal, 6).padding(.vertical, 2).background(Color(hex: "#FFCC00")).clipShape(RoundedRectangle(cornerRadius: 5))
                Text("Test Advertiser").font(.system(size: 12, weight: .semibold)).foregroundStyle(ink.sub)
            }
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.35)).frame(width: 120, height: 120)
                    .overlay(Image(systemName: "photo").font(.system(size: 30)).foregroundStyle(.white.opacity(0.8)))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Test ad headline").font(.system(size: 15, weight: .bold)).foregroundStyle(ink.ink)
                    Text("Test ad description").font(.system(size: 12.5)).foregroundStyle(ink.sub)
                    Text("Install").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7).background(Color(hex: "#0A84FF")).clipShape(Capsule())
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
    }
}

private struct DemoBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Text(L("광고")).font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: "#291F00"))
                .padding(.horizontal, 5).padding(.vertical, 1).background(Color(hex: "#FFCC00")).clipShape(RoundedRectangle(cornerRadius: 4))
            RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.35)).frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Test banner").font(.system(size: 14, weight: .bold))
                Text("Test ad description").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Text("Open").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 7).background(Color(hex: "#0A84FF")).clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .foregroundStyle(Color.black)
    }
}
