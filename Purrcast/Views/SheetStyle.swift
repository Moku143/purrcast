import SwiftUI
import UIKit

/// Colours for the sheets (settings, places, character, paywall), from the canvas — each with its dark-mode twin
/// (설정 → 화면 → 화면 모드).
enum UI {
    static let bg = Color(light: 0xF2F4F8, dark: 0x0E121D)
    static let row = Color(light: 0xFFFFFF, dark: 0x1A1F2C)
    static let ink = Color(light: 0x1A2440, dark: 0xEDF0F8)
    static let sub = Color(light: 0x6B7591, dark: 0x9EA7BF)
    static let faint = Color(light: 0xA3AABD, dark: 0x5F6880)
    static let line = Color(light: 0x1E2A44, 0.08, dark: 0xFFFFFF, 0.09)
    static let accent = Color(hex: "#EE7A3B")
    static let accentSoft = Color(light: 0xFFE9DC, dark: 0x3A2517)
    static let plus = Color(hex: "#EE7A3B")
    /// The accent as text: darker on the light sheet (4.5:1), lighter on the dark one
    static let accentText = Color(light: 0xBD4D10, dark: 0xFF9F66)
    /// Text on an ink-filled shape (today's date, a chosen chip)
    static let onInk = Color(light: 0xFFFFFF, dark: 0x12172A)
    /// Search fields, grey chips and the empty days of the calendar
    static let field = Color(light: 0xE6E9F0, dark: 0x262C3C)
    /// The warm (Plus) panels: their top and bottom and edge, and the plain warm fill
    static let warmTop = Color(light: 0xFFE3CC, dark: 0x3B2A1D)
    static let warmBottom = Color(light: 0xFFF4EA, dark: 0x271F19)
    static let warmLine = Color(light: 0xFFD1AE, dark: 0x5B3B24)
    static let warm = Color(light: 0xFFF4E8, dark: 0x2A2019)
    /// Body text a notch darker than `sub` (notes, licences), and the grey of hints
    static let body = Color(light: 0x33405E, dark: 0xC3C9DA)
    static let muted = Color(light: 0x5F6983, dark: 0xA2AAC0)
    static let hint = Color(light: 0x8A93AA, dark: 0x7C859D)
    /// The warm panel's brown words
    static let warmInk = Color(light: 0x6B4A33, dark: 0xE6C6AC)
    /// A card's shadow: barely there on the dark sheet
    static let shadow = Color(light: 0x1E2A44, 1, dark: 0x000000, 1)
}

extension UI {
    /// A card in the outfit's colour (the chosen character, a place): as it is in light mode, deepened toward the
    /// night's navy in dark mode so the light words on it read
    static func outfit(_ level: Int, dark: Bool) -> Color {
        let bg = Rules.background[Rules.clamp(level)]
        return dark ? Color.mix(bg, "#0B0F24", 0.62) : Color(hex: bg)
    }
}

/// 설정 → 화면 → 화면 모드: follow the phone, or always light or dark
enum Appearance: String, CaseIterable {
    case auto, light, dark
    var title: String { switch self { case .auto: return L("자동"); case .light: return L("라이트"); case .dark: return L("다크") } }
    var style: UIUserInterfaceStyle { switch self { case .auto: return .unspecified; case .light: return .light; case .dark: return .dark } }
    /// Every window of the app in this mode (sheets included)
    @MainActor func apply() {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for w in scene.windows { w.overrideUserInterfaceStyle = style }
        }
    }
}

extension Color {
    /// One colour for light mode and another for dark (hex as 0xRRGGBB, with an opacity each)
    init(light: UInt32, _ la: Double = 1, dark: UInt32, _ da: Double = 1) {
        func ui(_ v: UInt32, _ a: Double) -> UIColor {
            UIColor(red: CGFloat(v >> 16 & 255) / 255, green: CGFloat(v >> 8 & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: a)
        }
        let l = ui(light, la), d = ui(dark, da)
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? d : l })
    }
}

extension View {
    /// A small button label's tap area grown to at least 44 × 44 pt around it, nothing moved: an invisible square laid
    /// over the label takes the taps (the label keeps its own size in the layout). For the inside of a Button's label.
    func tapArea() -> some View {
        overlay { Color.clear.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) }
    }
}

/// Big pixel title on the left, one text button on the right ("완료" / "닫기").
struct SheetHeader: View {
    let title: String
    var trailing = L("완료")
    var action: () -> Void
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.px(24)).foregroundStyle(UI.ink)
            Spacer()
            Button { Haptic.soft(); action() } label: { Text(trailing).tapArea() }.font(.system(size: 15, weight: .semibold)).foregroundStyle(UI.accentText)  // darker than the accent for this text only: 4.5:1 on the sheet
                .buttonStyle(.press(0.94)).accessibilityIdentifier("sheet-close")
        }
        .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 10)
    }
}

/// Small orange "Plus" tag
struct PlusTag: View {
    var text = "Plus"
    var body: some View {
        Text(text).font(.ui(11, .bold)).foregroundStyle(.white)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(UI.plus).clipShape(Capsule())
    }
}

/// Section label above a group of rows
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.ui(13, .medium)).foregroundStyle(UI.sub)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 6)
    }
}

/// White rounded group of rows with hairlines between them
struct RowGroup<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(UI.row)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
    }
}

struct RowDivider: View {
    var body: some View { Rectangle().fill(UI.line).frame(height: 1).padding(.leading, 52) }
}

/// One settings row: pixel icon, title (+ subtitle), trailing content
struct SettingRow<Trailing: View>: View {
    var icon: String?
    /// An SF Symbol in place of a pixel icon (the location pin has no pixel version).
    var symbol: String?
    let title: String
    var subtitle: String?
    var plus = false
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(spacing: 12) {
            if let icon { PixelIcon(name: icon, size: 22) }
            else if let symbol { Image(systemName: symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(UI.ink).frame(width: 22, height: 22) }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(.system(size: 16, weight: .medium)).foregroundStyle(UI.ink)
                    if plus { PlusTag() }
                }
                if let subtitle { Text(subtitle).font(.ui(12)).foregroundStyle(UI.sub) }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 14).frame(minHeight: 54)
        .contentShape(Rectangle())
    }
}

/// The small grey "›" at the end of a row that opens something.
struct RowChevron: View {
    var body: some View { Image(systemName: "chevron.right").font(.ui(11, .bold)).foregroundStyle(UI.faint) }
}

/// Grey text + chevron at the end of a row ("2곳 ›", "22:00~07:00 ›").
struct RowValue: View {
    let text: String
    var chevron = true
    var body: some View {
        HStack(spacing: 4) {
            Text(text).font(.system(size: 14)).foregroundStyle(UI.sub)
            if chevron { RowChevron() }
        }
    }
}

/// Grey capsule tag ("한국", "전 세계", "추가됨")
struct GreyTag: View {
    let text: String
    var body: some View {
        Text(text).font(.ui(11, .bold)).foregroundStyle(UI.sub)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(UI.field).clipShape(Capsule())
    }
}

/// Segmented pill used for units (°C / °F etc.)
struct Pills<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var value: T
    @Namespace private var ns
    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { o in
                Button { Haptic.select(); withAnimation(Motion.snappy) { value = o.0 } } label: {
                    Text(o.1).font(.ui(13, .semibold))
                        .foregroundStyle(value == o.0 ? UI.ink : UI.sub)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .contentShape(Rectangle())      // the whole pill takes the tap, not only its letters
                        .background {
                            // the white pill slides between options
                            if value == o.0 {
                                RoundedRectangle(cornerRadius: 8).fill(UI.row)
                                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                                    .matchedGeometryEffect(id: "pill", in: ns)
                            }
                        }
                }.buttonStyle(.plain)
            }
        }
        .padding(3).background(UI.field.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// Big orange call to action
struct PrimaryButton: View {
    let title: String
    var busy = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title).font(.px(17)).opacity(busy ? 0 : 1)
                if busy { ProgressView().tint(.white) }
            }
            .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 54)
            .background(UI.accent).clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: UI.accent.opacity(0.35), radius: 10, y: 6)
            .animation(Motion.snappy, value: busy)
        }.buttonStyle(.press(0.97))
        .simultaneousGesture(TapGesture().onEnded { Haptic.tap() })
    }
}
