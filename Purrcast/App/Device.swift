import UIKit

/// What kind of device the app runs on.
enum Device {
    /// iPad: no Apple Watch pairs with it and it has no Live Activities, so the pages that offer those leave them out.
    /// (Debug: -pad shows the iPad wording on a phone, for the screenshot tests.)
    static let isPad: Bool = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-pad") { return true }
        #endif
        return UIDevice.current.userInterfaceIdiom == .pad
    }()
}

/// The page's column in a big window (iPad): the hero and the cards stay a phone-like column in the middle, the sky
/// behind them spans the window. Phones (440 pt at most) and slim Split View windows fill their width as before.
enum Column {
    /// Windows up to this wide are laid out edge to edge, as on a phone
    static let phoneUpTo: CGFloat = 536
    static let maxWidth: CGFloat = 600
    static func wide(_ window: CGFloat) -> Bool { window > phoneUpTo }
    /// The column: the window itself on a phone; 536…600 pt with a margin on each side in a bigger window
    static func width(in window: CGFloat) -> CGFloat { min(window, max(phoneUpTo, min(window - 64, maxWidth))) }
}
