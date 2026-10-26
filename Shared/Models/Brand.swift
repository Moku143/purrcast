import Foundation

/// The app's name as the person sees it: 그르릉날씨 on Korean devices, ゴロゴロ天気 on Japanese ones, Purrcast elsewhere
/// (matches the home-screen name from InfoPlist.strings).
enum Brand {
    static var isKorean: Bool { Lang.current == .ko }
    static var name: String {
        switch Lang.current {
        case .ko: return "그르릉날씨"
        case .ja: return "ゴロゴロ天気"
        case .en: return "Purrcast"
        }
    }
    static var plus: String { "\(name) Plus" }
}
