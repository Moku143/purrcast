import SwiftUI
import WatchConnectivity
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Apple Watch app (Plus). The phone sends the latest forecast over WatchConnectivity; the watch keeps it in its
/// App Group so the complications see it too. Pages: now · next hours · 10 days.
@main
struct PurrcastWatchApp: App {
    @StateObject private var link = WatchLink()
    var body: some Scene {
        WindowGroup { WatchRoot().environmentObject(link) }
    }
}

final class WatchLink: NSObject, ObservableObject, WCSessionDelegate {
    @Published var snap: WeatherSnapshot
    /// The page the app opens on (screenshots only; 0 = now).
    var startPage = 0

    override init() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        #else
        let args: [String] = []
        #endif
        // screenshots: -lang ko|en|ja pins the language, -page 0|1|2 opens a page, -locked shows the free screen
        if let i = args.firstIndex(of: "-lang"), i + 1 < args.count, let l = Lang(rawValue: args[i + 1]) { Lang.current = l }
        if let i = args.firstIndex(of: "-page"), i + 1 < args.count { startPage = Int(args[i + 1]) ?? 0 }
        if let i = args.firstIndex(of: "-scene"), i + 1 < args.count {
            // screenshots: a fixed example, Plus on
            var s = SceneLibrary.scene(args[i + 1]); s.place = Place.here.name
            let c = args.firstIndex(of: "-char").flatMap { $0 + 1 < args.count ? PurrCharacter(rawValue: args[$0 + 1]) : nil } ?? .cat
            snap = WeatherSnapshot(scene: s, character: c, plus: !args.contains("-locked"), characterName: c.defaultName, placeShort: Place.here.short, saved: Date())
        } else {
            snap = SharedStore.load() ?? .waiting
        }
        super.init()
        if WCSession.isSupported() { WCSession.default.delegate = self; WCSession.default.activate() }
    }

    private func take(_ ctx: [String: Any]) {
        guard let data = ctx["snapshot"] as? Data, let s = try? JSONDecoder().decode(WeatherSnapshot.self, from: data) else { return }
        if let l = s.lang { Lang.picked = Lang(rawValue: l) }   // the phone's 설정 → 언어 (complications read it from the group too)
        SharedStore.save(s)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        DispatchQueue.main.async { self.snap = s }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        take(session.receivedApplicationContext)
    }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { take(applicationContext) }
}

struct WatchRoot: View {
    @EnvironmentObject var link: WatchLink
    @State private var page: Int?
    var body: some View {
        if link.snap.plusActive {
            TabView(selection: Binding(get: { page ?? link.startPage }, set: { page = $0 })) {
                WatchNowWalking(snap: link.snap).tag(0)
                WatchHours(snap: link.snap).tag(1)
                WatchDays(snap: link.snap).tag(2)
            }
            .tabViewStyle(.verticalPage)
        } else {
            WatchLocked()
        }
    }
}

/// The first page with the walk from the design: when the outfit changes — new weather while the app is open, or
/// since it was last looked at — the bubble fades, the cat turns and walks out to the left, the sky and numbers
/// change with nobody on screen, and the cat walks back in wearing the new outfit; then the bubble pops.
/// Holds still with Reduce Motion or wrist down (the new weather just shows).
struct WatchNowWalking: View {
    let snap: WeatherSnapshot
    @State private var shown: WeatherSnapshot?
    @State private var target: WeatherSnapshot?
    @State private var gen = 0
    @State private var catX: CGFloat = 0
    @State private var walk: WalkDirection?
    @State private var bubbleOn = true
    @State private var playing = false
    /// The weather the page last showed (the "from" picture when the app opens on a new outfit).
    @AppStorage("watch.lastShown") private var lastShown = Data()
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.isLuminanceReduced) private var dimmed

    private static let offstage: CGFloat = 104     // the cat (80 pt, 15 pt in from the left) fully past the edge

    var body: some View {
        ZStack {
            if let s = shown {
                WatchNow(snap: s, catX: catX, walk: walk, bubbleOn: bubbleOn)
                    .id(gen)
                    .transition(.opacity)
            }
        }
        .onAppear { arrive(snap, opening: true) }
        .onChange(of: key(snap)) { _, _ in arrive(snap, opening: false) }
    }

    private func outfit(_ s: WeatherSnapshot) -> String { "\(s.shownCharacter.rawValue)-\(s.scene.level)-\(s.scene.rain)" }
    private func key(_ s: WeatherSnapshot) -> String { "\(s.saved.timeIntervalSince1970)|\(outfit(s))|\(s.scene.temp)|\(s.placeShort)" }

    private func arrive(_ new: WeatherSnapshot, opening: Bool) {
        target = new
        if playing { return }                              // the walk in progress picks up the newest at its end
        var from = shown
        if from == nil, opening { from = try? JSONDecoder().decode(WeatherSnapshot.self, from: lastShown) }
        #if DEBUG
        // screenshots: -walkFrom <scene> pretends the page last showed that example weather
        let args = ProcessInfo.processInfo.arguments
        if opening, let i = args.firstIndex(of: "-walkFrom"), i + 1 < args.count {
            var s = SceneLibrary.scene(args[i + 1]); s.place = new.scene.place
            from = WeatherSnapshot(scene: s, character: new.character, plus: true, characterName: new.characterName,
                                   placeShort: new.placeShort, saved: new.saved.addingTimeInterval(-3600))
        }
        #endif
        guard let old = from, outfit(old) != outfit(new), !reduce, !dimmed else {
            shown = new; remember(new); return
        }
        shown = old
        Task { await play(after: opening ? 0.6 : 0) }
    }

    @MainActor private func play(after delay: Double) async {
        playing = true
        if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }      // a beat to see the old outfit first
        withAnimation(.easeOut(duration: 0.2)) { bubbleOn = false }
        try? await Task.sleep(for: .milliseconds(300))
        walk = .left
        withAnimation(.linear(duration: 1.0)) { catX = -Self.offstage }
        try? await Task.sleep(for: .seconds(1.0))
        withAnimation(.easeInOut(duration: 0.4)) { shown = target; gen += 1 }
        try? await Task.sleep(for: .milliseconds(400))
        walk = .right
        withAnimation(.linear(duration: 1.0)) { catX = 0 }
        try? await Task.sleep(for: .seconds(1.0))
        walk = nil
        try? await Task.sleep(for: .milliseconds(100))
        withAnimation(Motion.bouncy) { bubbleOn = true }
        if let s = shown { remember(s) }
        playing = false
        if let t = target, let s = shown, key(t) != key(s) { arrive(t, opening: false) }   // newer weather came in meanwhile
    }

    private func remember(_ s: WeatherSnapshot) {
        if let d = try? JSONEncoder().encode(s) { lastShown = d }
    }
}

struct WatchHours: View {
    let snap: WeatherSnapshot
    var body: some View {
        let s = snap.scene
        List {
            ForEach(Array(s.hours.prefix(8).enumerated()), id: \.offset) { _, h in
                HStack(spacing: 8) {
                    Text(snap.hourLabel(h.label)).font(.px(snap.clock12 ? 10 : 13)).frame(width: 46, alignment: .leading)
                    PixelIcon(name: h.icon, size: 20)
                    Spacer()
                    if h.chance >= 10 { Text("\(h.chance)%").font(.px(11)).foregroundStyle(Color(hex: "#9CC0FF")) }
                    Text(snap.deg(h.temp)).font(.px(15))
                }
            }
        }
        .navigationTitle(L("시간별"))
    }
}

struct WatchDays: View {
    let snap: WeatherSnapshot
    var body: some View {
        List {
            ForEach(Array(snap.scene.days.enumerated()), id: \.offset) { _, d in
                HStack(spacing: 8) {
                    Text(d.name).font(.px(13)).frame(width: 34, alignment: .leading)
                    PixelIcon(name: d.icon, size: 20)
                    Spacer()
                    Text(snap.deg(d.lo)).font(.px(12)).opacity(0.7)
                    Text(snap.deg(d.hi)).font(.px(14))
                }
            }
        }
        .navigationTitle(L("10일"))
    }
}

struct WatchLocked: View {
    var body: some View {
        VStack(spacing: 8) {
            CharacterSprite(character: .cat, level: 4, rain: .none, width: 70, animate: false).frame(height: 80)
            Text(L("애플워치는 Plus에서\n쓸 수 있어요")).font(.px(13)).multilineTextAlignment(.center)
            Text(L("아이폰에서 %@를 열어 주세요", Brand.name)).font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }
}
