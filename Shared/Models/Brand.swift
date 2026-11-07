import Foundation

/// The app's name as the person sees it: each language's own word for a cat's purr and its weather — 그르릉날씨,
/// ゴロゴロ天気, 呼噜天气, Schnurrwetter… — Purrcast in English and Indonesian (matches the home-screen name from
/// InfoPlist.strings and the store name).
enum Brand {
    static var isKorean: Bool { Lang.current == .ko }
    static var name: String {
        switch Lang.current {
        case .ko: return "그르릉날씨"
        case .ja: return "ゴロゴロ天気"
        case .zhHans: return "呼噜天气"
        case .zhHant: return "呼嚕天氣"
        case .de: return "Schnurrwetter"
        case .fr: return "Ronron Météo"
        case .es: return "Ronroneo"
        case .pt: return "Ronrom Clima"
        case .it: return "Fusa Meteo"
        case .ru: return "Мурпогода"
        case .en, .id: return "Purrcast"
        }
    }
    static var plus: String { "\(name) Plus" }
}
