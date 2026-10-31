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
                .dynamicTypeSize(.large)        // the pixel layout is drawn to the point; the system text-size setting does not resize it
                .task {
                    #if DEBUG
                    let args = ProcessInfo.processInfo.arguments
                    if let i = args.firstIndex(of: "-iconTest"), i + 1 < args.count {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        AppIcon.test(quiet: args[i + 1] == "quiet")
                    }
                    #endif
                    WatchBridge.shared.start()
                    LiveActivities.shared.watch(model)
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
                        AppIcon.follow(model.shownCharacter)
                        await model.refresh()
                    }
                }
                // the sun-face icon is the character shown; a Plus character's umbrella icon goes back to the
                // app's own icon when Plus ends
                .onChange(of: model.shownCharacter) { _, c in AppIcon.follow(c) }
                .onChange(of: model.plus) { _, p in AppIcon.dropPlusIcon(plus: p) }
                .onChange(of: purchases.active) { _, _ in syncPlan() }
                .onChange(of: purchases.expires) { _, _ in syncPlan() }
                .onChange(of: purchases.testUntil) { _, _ in syncPlan() }
                .onChange(of: purchases.testBuild) { _, _ in syncPlan() }
        }
    }

    /// StoreKit decides the plan; a TestFlight test trial or the debug launch flag (debug builds only) can turn it on.
    private func syncPlan() {
        model.plus = purchases.active || purchases.testActive || model.debugPlus
        model.plusUntil = purchases.active ? purchases.expires : (purchases.testActive ? purchases.testUntil : nil)
    }
}

/// Sheets and full-screen pages reachable from home.
enum Route: String, Identifiable {
    case character, paywall, settings, places, sources, widgets, language, licenses, appIcon, widgetLab, liveLab
    var id: String { rawValue }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @State private var route: Route?
    @State private var day: Int?

    var body: some View {
        Group {
            if model.onboarded {
                HomeView(route: $route, day: $day).id(model.language).transition(.opacity)   // a new language rebuilds the page
            } else {
                OnboardingView().transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(Motion.gentle, value: model.onboarded)
        .sheet(item: $route) { r in
            switch r {
            case .character: CharacterSheet(route: $route).presentationDetents([.medium, .large]).presentationCornerRadius(28)
            case .paywall: PaywallView().presentationCornerRadius(28)
            case .settings: SettingsView(route: $route).presentationCornerRadius(28)
            case .places: PlacesView().presentationCornerRadius(28)
            case .sources: SourcesView(route: $route).presentationCornerRadius(28)
            case .widgets: NavigationStack { WidgetGalleryView() }.presentationCornerRadius(28)
            case .widgetLab: WidgetLabView()          // the layout board's widget page (UI tests only)
            case .liveLab: LiveLabView()              // the Live Activity's views at size (UI tests only)
            case .language: LanguageView(route: $route).presentationCornerRadius(28)
            case .licenses: LicensesView(route: $route).presentationCornerRadius(28)
            case .appIcon: AppIconView(route: $route).presentationCornerRadius(28)
            }
        }
        .sheet(item: Binding(get: { day.map { DayIndex(value: $0) } }, set: { day = $0?.value })) { d in
            DayDetailView(start: d.value).presentationDetents([.large]).presentationCornerRadius(28)
        }
        .onAppear(perform: openFromLaunchArguments)
    }

    /// UI tests open a page directly: -open character|paywall|settings|places|sources|widgets|language|licenses|day|today (debug builds only)
    private func openFromLaunchArguments() {
        #if DEBUG
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-open"), i + 1 < a.count else { return }
        if a[i + 1] == "day" { day = 1 } else if a[i + 1] == "today" { day = 0 } else { route = Route(rawValue: a[i + 1]) }
        #endif
    }
}

struct DayIndex: Identifiable { let value: Int; var id: Int { value } }
