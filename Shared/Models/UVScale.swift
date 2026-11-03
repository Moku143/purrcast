import CoreGraphics
import Foundation

/// The UV index in its five bands (WHO: 0–2 낮음 · 3–5 보통 · 6–7 높음 · 8–10 매우 높음 · 11+ 위험): the word, its colours on the scale bar and how wide each band is drawn
enum UVScale {
    static let bands: [(hi: Int, word: String, color: String, onColor: String, flex: CGFloat)] = [
        (2, "낮음", "#4CAF50", "#FFFFFF", 3), (5, "보통", "#F2C230", "#1E2A44", 3), (7, "높음", "#F28C28", "#1E2A44", 2),
        (10, "매우 높음", "#E2453C", "#FFFFFF", 3), (99, "위험", "#8E44AD", "#FFFFFF", 1),
    ]
    static func band(_ uv: Int) -> (hi: Int, word: String, color: String, onColor: String, flex: CGFloat) { bands.first { uv <= $0.hi } ?? bands[4] }
}
