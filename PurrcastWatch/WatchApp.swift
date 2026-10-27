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

    override init() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        #else
        let args: [String] = []
        #endif
        if let i = args.firstIndex(of: "-scene"), i + 1 < args.count {
            // screenshots: a fixed example, Plus on
            var s = SceneLibrary.scene(args[i + 1]); s.place = Place.here.name
            let c = args.firstIndex(of: "-char").flatMap { $0 + 1 < args.count ? PurrCharacter(rawValue: args[$0 + 1]) : nil } ?? .cat
            snap = WeatherSnapshot(scene: s, character: c, plus: true, characterName: c.defaultName, placeShort: Place.here.short, saved: Date())
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
    var body: some View {
        if link.snap.plusActive {
            TabView {
                WatchNow(snap: link.snap)
                WatchHours(snap: link.snap)
                WatchDays(snap: link.snap)
            }
            .tabViewStyle(.verticalPage)
        } else {
            WatchLocked()
        }
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
