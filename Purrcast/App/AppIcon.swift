import SwiftUI
import UIKit
import ObjectiveC

/// The home-screen icon, picked in 설정 › 앱 아이콘. The app's own icon is the cat's face as the sun on a sky-blue sky;
/// that sun face comes on sky blue or peach and follows the character shown (AppIcon-sun-<sky>-<character>).
/// The others are fixed: the cat-ear cloud in every weather, and each character under its umbrella in the rain.
/// They are alternate icons in the asset catalog (AppIcon-<id>, listed in project.yml); `iconpick-<id>` is each
/// one's small picture for the picker.
enum AppIcon {
    struct Choice: Identifiable, Hashable {
        let id: String
        let title: String
        /// a Plus character's icon (아비시니안 · 브리티시숏헤어)
        var plus = false
        /// the sun faces: the icon is the shown character's
        var follows: Bool { id.hasPrefix("sun-") }
        /// nil = the app's own icon
        func iconName(_ c: PurrCharacter) -> String? {
            let full = follows ? "\(id)-\(c.rawValue)" : id
            return full == AppIcon.primary ? nil : "AppIcon-\(full)"
        }
        func preview(_ c: PurrCharacter) -> String { follows ? "iconpick-\(id)-\(c.rawValue)" : "iconpick-\(id)" }
    }

    /// the app's own icon (AppIcon in the catalog)
    static let primary = "sun-blue-cat"

    static var sun: [Choice] { [Choice(id: "sun-blue", title: L("하늘빛")), Choice(id: "sun-peach", title: L("살구빛"))] }

    static var weather: [Choice] {
        [Choice(id: "partly", title: L("구름 조금")), Choice(id: "clear", title: L("맑음")), Choice(id: "cloudy", title: L("흐림")),
         Choice(id: "rain", title: L("비")), Choice(id: "thunder", title: L("천둥번개")), Choice(id: "snow", title: L("눈")),
         Choice(id: "night", title: L("맑은 밤")), Choice(id: "fog", title: L("안개")), Choice(id: "rainbow", title: L("무지개")),
         Choice(id: "wind", title: L("바람")), Choice(id: "heavyrain", title: L("폭우")), Choice(id: "sleet", title: L("진눈깨비")),
         Choice(id: "heat", title: L("폭염")), Choice(id: "cold", title: L("한파")), Choice(id: "dust", title: L("황사")),
         Choice(id: "cloudynight", title: L("흐린 밤"))]
    }

    static var characters: [Choice] {
        PurrCharacter.allCases.map { Choice(id: "rain-\($0.rawValue)", title: $0.defaultName, plus: $0.isPlus) }
    }

    /// The choice behind an icon name (a sun face of any character → its sky's choice).
    static func choice(of name: String?) -> String {
        guard let n = name, n.hasPrefix("AppIcon-") else { return "sun-blue" }
        let id = String(n.dropFirst("AppIcon-".count))
        for s in ["sun-peach", "sun-blue"] where id.hasPrefix(s + "-") { return s }
        return id
    }

    /// The icon on the home screen now (its choice's id).
    @MainActor static var current: String { choice(of: UIApplication.shared.alternateIconName) }

    /// The small picture of the icon on the home screen now.
    @MainActor static func currentPreview(_ c: PurrCharacter) -> String {
        let id = current
        return id.hasPrefix("sun-") ? "iconpick-\(id)-\(c.rawValue)" : "iconpick-\(id)"
    }

    /// iOS shows its own short note when the icon changes; nothing else is needed.
    @MainActor static func set(_ c: Choice, character: PurrCharacter, done: @escaping (Bool) -> Void = { _ in }) {
        let app = UIApplication.shared
        let want = c.iconName(character)
        guard app.supportsAlternateIcons, app.alternateIconName != want else { return done(false) }
        app.setAlternateIconName(want) { err in DispatchQueue.main.async { done(err == nil) } }
    }

    /// A sun-face icon follows the character shown (a Plus character goes back to the cat when Plus ends).
    @MainActor static func follow(_ c: PurrCharacter) {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-scene") || args.contains("-reset") { return }      // screenshots and UI tests keep the icon
        let app = UIApplication.shared
        guard app.supportsAlternateIcons, app.applicationState == .active,
              let ch = sun.first(where: { $0.id == current }) else { return }
        let want = ch.iconName(c)
        guard app.alternateIconName != want else { return }
        QuietIconNote.arm()                                   // the character changed; iOS's own note is not needed
        app.setAlternateIconName(want) { _ in }
    }

    #if DEBUG
    /// UI tests (-iconTest quiet|loud): switch between two icons, with or without iOS's note.
    @MainActor static func test(quiet: Bool) {
        let app = UIApplication.shared
        let want: String? = app.alternateIconName == nil ? "AppIcon-sun-peach-cat" : nil
        if quiet { QuietIconNote.arm() }
        app.setAlternateIconName(want) { err in print("ICONTEST set \(want ?? "primary") quiet=\(quiet) error=\(String(describing: err))") }
    }
    #endif

    /// The Plus characters' umbrella icons go back to the app's own icon when Plus ends.
    @MainActor static func dropPlusIcon(plus: Bool) {
        guard !plus, characters.contains(where: { $0.plus && $0.id == current }) else { return }
        UIApplication.shared.setAlternateIconName(nil) { _ in }
    }
}

/// iOS puts up its own note ("아이콘이 변경되었습니다") each time an alternate icon is set. When the icon only follows
/// a character change that note is noise, so for a moment around such a change it is not shown: it is the one alert
/// iOS presents in the app with neither a title nor a message (the icon and its text are its own content); any other
/// alert shows as always. If a future iOS shows the note differently, it simply shows.
@MainActor enum QuietIconNote {
    private static var installed = false
    static var until = Date.distantPast
    static func arm() {
        install()
        until = Date().addingTimeInterval(3)
    }
    private static func install() {
        guard !installed else { return }
        installed = true
        let cls: AnyClass = UIViewController.self
        guard let original = class_getInstanceMethod(cls, #selector(UIViewController.present(_:animated:completion:))),
              let quiet = class_getInstanceMethod(cls, #selector(UIViewController.purr_present(_:animated:completion:))) else { return }
        method_exchangeImplementations(original, quiet)
    }
}

extension UIViewController {
    /// swapped with present(_:animated:completion:) by QuietIconNote: calling it calls the original
    @objc func purr_present(_ vc: UIViewController, animated: Bool, completion: (() -> Void)?) {
        if let a = vc as? UIAlertController, a.title == nil, a.message == nil, Date() < QuietIconNote.until {
            QuietIconNote.until = .distantPast
            completion?()
            return
        }
        purr_present(vc, animated: animated, completion: completion)
    }
}

/// 설정 › 앱 아이콘: every icon as a tile, the one in use ticked.
struct AppIconView: View {
    @EnvironmentObject var model: AppModel
    @Binding var route: Route?
    @Environment(\.dismiss) private var dismiss
    @State private var current = "sun-blue"

    private let cols = [GridItem(.adaptive(minimum: 74, maximum: 96), spacing: 14)]

    var body: some View {
        VStack(spacing: 0) {
            BackToSettings(route: $route) { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(L("앱 아이콘")).font(.px(24)).foregroundStyle(UI.ink)
                    Text(L("홈 화면에 보일 아이콘을 골라요")).font(.ui(13)).foregroundStyle(UI.sub)
                    label(L("해님 캐릭터"))
                    grid(AppIcon.sun)
                    Text(L("캐릭터를 바꾸면 아이콘도 같이 바뀌어요")).font(.ui(11.5)).foregroundStyle(UI.sub).padding(.top, -4)
                    label(L("날씨"))
                    grid(AppIcon.weather)
                    label(L("우산 쓴 캐릭터"))
                    grid(AppIcon.characters)
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
        }
        .background(UI.bg)
        .onAppear { current = AppIcon.current }
    }

    private func label(_ t: String) -> some View {
        Text(t).font(.ui(13, .medium)).foregroundStyle(UI.sub).padding(.top, 8)
    }

    private func grid(_ items: [AppIcon.Choice]) -> some View {
        LazyVGrid(columns: cols, alignment: .leading, spacing: 14) {
            ForEach(items) { c in tile(c) }
        }
    }

    private func tile(_ c: AppIcon.Choice) -> some View {
        let on = current == c.id
        let locked = c.plus && !model.plus
        return Button {
            Haptic.select()
            if locked {
                route = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { route = .paywall }
                return
            }
            AppIcon.set(c, character: model.shownCharacter) { ok in if ok { current = c.id } }
        } label: {
            VStack(spacing: 6) {
                Image(c.preview(model.shownCharacter)).resizable().interpolation(.high).aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(on ? UI.accent : Color.black.opacity(0.06), lineWidth: on ? 3 : 1))
                    .overlay(alignment: .topTrailing) {
                        if on {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white, UI.accent).offset(x: 6, y: -6)
                        } else if locked {
                            PlusTag().scaleEffect(0.8).offset(x: 6, y: -6)
                        }
                    }
                    .opacity(locked ? 0.55 : 1)
                Text(c.title).font(.ui(11.5)).foregroundStyle(on ? UI.ink : UI.sub).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.press(0.95))
        .accessibilityIdentifier("appicon-\(c.id)")
        .accessibilityLabel(Text(c.title))
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
