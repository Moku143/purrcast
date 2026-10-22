import Foundation

/// The app's name as the person sees it: 그르릉날씨 on Korean devices, Purrcast elsewhere
/// (matches the home-screen name from InfoPlist.strings).
enum Brand {
    static var isKorean: Bool { (Bundle.main.preferredLocalizations.first ?? "en").hasPrefix("ko") }
    static var name: String { isKorean ? "그르릉날씨" : "Purrcast" }
    static var plus: String { "\(name) Plus" }
}
