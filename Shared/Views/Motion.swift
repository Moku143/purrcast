import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// One motion language for the whole app: a few springs, a press feel, staggered reveals, haptics.
/// Everything here respects Reduce Motion (the system setting) by falling back to short fades.
enum Motion {
    /// Taps, toggles, selection rings
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.78)
    /// Content changes: numbers, cards, sky
    static let gentle = Animation.spring(response: 0.55, dampingFraction: 0.86)
    /// Characters and bubbles popping in
    static let bouncy = Animation.spring(response: 0.48, dampingFraction: 0.62)
    /// Button press-down / release
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.7)
    /// Long cross-fades (background colour, sky)
    static let fade = Animation.easeInOut(duration: 0.7)

    static var reduced: Bool {
        #if canImport(UIKit) && !os(watchOS)
        return UIAccessibility.isReduceMotionEnabled
        #else
        return false
        #endif
    }
}

/// Light, physical press: the button shrinks a little and dims while the finger is down.
struct PressStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var dim: Double = 0.9
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? dim : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

/// For rows and list cells: no scaling, just a soft highlight.
struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.primary.opacity(configuration.isPressed ? 0.06 : 0))
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressStyle {
    static var press: PressStyle { PressStyle() }
    static func press(_ scale: CGFloat) -> PressStyle { PressStyle(scale: scale) }
}
extension ButtonStyle where Self == RowPressStyle {
    static var row: RowPressStyle { RowPressStyle() }
}

/// Fade + rise on first appearance, staggered by `index` so a column of cards arrives one after another.
struct Reveal: ViewModifier {
    let index: Int
    var rise: CGFloat = 16
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduce
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduce ? 0 : rise)
            .onAppear {
                guard !shown else { return }
                if reduce { withAnimation(.easeOut(duration: 0.2)) { shown = true } }
                else { withAnimation(Motion.gentle.delay(0.05 * Double(index))) { shown = true } }
            }
    }
}

extension View {
    func reveal(_ index: Int = 0, rise: CGFloat = 16) -> some View { modifier(Reveal(index: index, rise: rise)) }

    /// Cards in a scroll view: slightly smaller and dimmer while they are still off the edge, full size once in view.
    @ViewBuilder func settleInScroll() -> some View {
        if #available(iOS 17.0, watchOS 10.0, *) {
            self.scrollTransition(.interactive, axis: .vertical) { content, phase in
                content.opacity(phase.isIdentity ? 1 : 0.6).scaleEffect(phase.isIdentity ? 1 : 0.97)
            }
        } else { self }
    }

    /// Animated number: digits roll instead of snapping (e.g. the big temperature when the forecast changes).
    func rolling<V: Equatable>(_ value: V) -> some View {
        self.contentTransition(.numericText()).animation(Motion.gentle, value: value)
    }
}

/// Haptics for the phone (no-ops on the watch and in widgets).
enum Haptic {
    static func tap() {
        #if canImport(UIKit) && !os(watchOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
    static func select() {
        #if canImport(UIKit) && !os(watchOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
    static func success() {
        #if canImport(UIKit) && !os(watchOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
    static func soft() {
        #if canImport(UIKit) && !os(watchOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
        #endif
    }
}
