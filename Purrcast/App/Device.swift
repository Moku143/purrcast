import SwiftUI

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

/// A phone-wide column in a big window (iPad): the first-run pages and the sheets keep their phone layout this wide.
enum Column {
    static let maxWidth: CGFloat = 600
}

extension View {
    /// iPad: a sheet as tall as a page sheet and as wide as the home page's column (the default there is a small box in
    /// the middle of the screen, which cut the day sheet, the Plus page and the settings short; a full page sheet
    /// stretched their phone layouts across the screen). A phone's sheets are unchanged.
    @ViewBuilder func pageSheet() -> some View {
        if #available(iOS 18.0, *) {
            frame(idealWidth: Column.maxWidth + 40).presentationSizing(.page.fitted(horizontal: true, vertical: false))
        } else { self }
    }
}

/// The home page in a big window (iPad): across the whole window, the hero drawn bigger, the cards in columns.
enum HomeWide {
    /// Windows this wide or wider (an iPad, or two thirds of one); narrower ones get the phone's page
    static let from: CGFloat = 700
    static let pad: CGFloat = 24
    static let gap: CGFloat = 16
    static func on(_ window: CGFloat) -> Bool { window >= from }
    /// The hero's sizes against the phone's design: 1 at 620 pt of page, up to 1.6 (a 13-inch iPad)
    static func heroScale(_ avail: CGFloat) -> CGFloat { min(1.6, max(1, avail / 620)) }
    /// Two columns of cards, three from 1100 pt (an iPad lying down)
    static func columns(_ width: CGFloat) -> Int { width >= 1100 ? 3 : 2 }
}
