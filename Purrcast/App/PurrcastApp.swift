import SwiftUI
import UserNotifications
import BackgroundTasks

@main
struct PurrcastApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var purchases = Purchases()
    @Environment(\.scenePhase) private var phase

    init() {
        // before launch ends, so the tap that opened the app reaches it too
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        NightRefresh.register()
    }

    /// -narrow (debug): the page in a 320 × 693-pt box — the width of a 6.1-inch phone with Display Zoom on — so the
    /// screenshots show that nothing is cut off there
    @ViewBuilder private func root() -> some View {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-storeShot"), i + 1 < args.count, let n = Int(args[i + 1]) {
            // the App Store pictures: full screen, no status bar or home indicator of the simulator's own
            StoreShotView(page: n).statusBarHidden(true).persistentSystemOverlays(.hidden)
        } else if let i = args.firstIndex(of: "-watchFace"), i + 1 < args.count {
            WatchFaceShot(kind: args[i + 1]).statusBarHidden(true).persistentSystemOverlays(.hidden)
        } else if args.contains("-narrow") {
            RootView().frame(width: 320, height: 693).clipped()
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black)
        } else if args.contains("-narrowCal") {
            // the 날씨 달력 alone in the 320-pt box: a sheet would escape the -narrow frame, so it opens bare
            CalendarSheet().frame(width: 320, height: 693).clipped()
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black)
        } else { RootView() }
        #else
        RootView()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            root()
                .environmentObject(model)
                .environmentObject(purchases)
                .onAppear { model.appearance.apply() }      // 화면 모드: every window, sheets included
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
                    await CloudLog.shared.sync(model: model, force: true)    // 날씨 기록 ⇄ the person's iCloud
                }
                .onChange(of: phase) { _, p in
                    // going away: ask for a best-effort wake near midnight, so the day closes with where the phone is
                    if p == .background { NightRefresh.schedule() }
                    // back from the background: new day / old data → fetch; a lapsed subscription → back to Free
                    guard p == .active else { return }
                    Task {
                        await purchases.refresh()
                        syncPlan()
                        AppIcon.follow(model.shownCharacter)
                        await model.refresh()
                        await CloudLog.shared.sync(model: model)
                    }
                }
                // the sun-face icon is the character shown; a Plus character's umbrella icon goes back to the
                // app's own icon when Plus ends
                .onChange(of: model.shownCharacter) { _, c in AppIcon.follow(c) }
                .onChange(of: model.plus) { _, p in AppIcon.dropPlusIcon(plus: p) }
                .onChange(of: purchases.active) { _, _ in syncPlan() }
                .onChange(of: purchases.expires) { _, _ in syncPlan() }
                .onChange(of: purchases.willRenew) { _, _ in syncPlan() }      // the widgets' allowance follows auto-renew
                .onChange(of: purchases.testUntil) { _, _ in syncPlan() }
                .onChange(of: purchases.testBuild) { _, _ in syncPlan() }
        }
    }

    /// StoreKit decides the plan; a TestFlight test trial or the debug launch flag (debug builds only) can turn it on.
    private func syncPlan() {
        model.plus = purchases.active || purchases.testActive || model.debugPlus
        model.plusUntil = Purchases.widgetPlusUntil(active: purchases.active, expires: purchases.expires, willRenew: purchases.willRenew,
                                                    testUntil: purchases.testActive ? purchases.testUntil : nil)
    }
}

/// Sheets and full-screen pages reachable from home.
enum Route: String, Identifiable {
    case character, paywall, settings, places, sources, widgets, language, licenses, appIcon, widgetLab, liveLab, air, skyLab, alertLab, calendar, radar
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
                OnboardingView().environment(\.colorScheme, .light).transition(.move(edge: .leading).combined(with: .opacity))
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
            case .air: AirQualitySheet().presentationCornerRadius(28)
            case .radar: RadarSheet().presentationCornerRadius(28)
            case .calendar: CalendarSheet().presentationCornerRadius(28)
            case .skyLab: SkyLabView()                 // every sky by air (UI tests only)
            case .alertLab: AlertLabView()             // every warning's bubble and line (UI tests only)
            }
        }
        .sheet(item: Binding(get: { day.map { DayIndex(value: $0) } }, set: { day = $0?.value })) { d in
            DayDetailView(start: d.value).presentationDetents([.large]).presentationCornerRadius(28)
        }
        .onAppear(perform: openFromLaunchArguments)
        // a 월간 리포트 tapped: the 날씨 달력 at its month
        .onReceive(NotificationRouter.shared.$calendarMonth) { m in
            guard let m, model.onboarded else { return }
            model.calendarMonth = m.isEmpty ? nil : m
            NotificationRouter.shared.calendarMonth = nil
            day = nil
            route = .calendar
        }
    }

    /// UI tests open a page directly: -open character|paywall|settings|places|sources|widgets|language|licenses|day|today (debug builds only)
    private func openFromLaunchArguments() {
        #if DEBUG
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-open"), i + 1 < a.count else { return }
        if a[i + 1] == "day" { day = 1 } else if a[i + 1] == "today" { day = 0 }
        else if a[i + 1].hasPrefix("day"), let n = Int(a[i + 1].dropFirst(3)) { day = n }      // -open day5: the sixth day
        else { route = Route(rawValue: a[i + 1]) }
        #endif
    }
}

struct DayIndex: Identifiable { let value: Int; var id: Int { value } }
