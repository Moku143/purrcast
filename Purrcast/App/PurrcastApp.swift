import SwiftUI

@main
struct PurrcastApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var purchases = Purchases()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(purchases)
                .preferredColorScheme(.light)
                .task {
                    WatchBridge.shared.start()
                    await purchases.load()
                    syncPlan()
                    await model.refresh(force: true)
                }
                .onChange(of: phase) { _, p in
                    // back from the background: new day / old data → fetch; a lapsed subscription → back to Free
                    guard p == .active else { return }
                    Task {
                        await purchases.refresh()
                        syncPlan()
                        await model.refresh()
                    }
                }
                .onChange(of: purchases.active) { _, _ in syncPlan() }
                .onChange(of: purchases.expires) { _, _ in syncPlan() }
        }
    }

    /// StoreKit decides the plan; the debug launch flag (debug builds only) can force it on.
    private func syncPlan() {
        model.plus = purchases.active || model.debugPlus
        model.plusUntil = purchases.active ? purchases.expires : nil
    }
}

/// Sheets and full-screen pages reachable from home.
enum Route: String, Identifiable {
    case character, paywall, settings, places, sources, widgets
    var id: String { rawValue }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @State private var route: Route?
    @State private var day: Int?

    var body: some View {
        Group {
            if model.onboarded {
                HomeView(route: $route, day: $day)
            } else {
                OnboardingView()
            }
        }
        .sheet(item: $route) { r in
            switch r {
            case .character: CharacterSheet(route: $route).presentationDetents([.medium, .large])
            case .paywall: PaywallView()
            case .settings: SettingsView(route: $route)
            case .places: PlacesView()
            case .sources: NavigationStack { SourcesView() }
            case .widgets: NavigationStack { WidgetGalleryView() }
            }
        }
        .sheet(item: Binding(get: { day.map { DayIndex(value: $0) } }, set: { day = $0?.value })) { d in
            DayDetailView(start: d.value).presentationDetents([.large])
        }
        .onAppear(perform: openFromLaunchArguments)
    }

    /// UI tests open a page directly: -open character|paywall|settings|places|sources|widgets|day (debug builds only)
    private func openFromLaunchArguments() {
        #if DEBUG
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-open"), i + 1 < a.count else { return }
        if a[i + 1] == "day" { day = 1 } else { route = Route(rawValue: a[i + 1]) }
        #endif
    }
}

struct DayIndex: Identifiable { let value: Int; var id: Int { value } }
