import SwiftUI

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255, g = Double((v >> 8) & 0xFF) / 255, b = Double(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
    static func mix(_ a: String, _ b: String, _ t: Double) -> Color {
        func h(_ x: String) -> [Double] { let s = x.dropFirst(); return stride(from: 0, to: 6, by: 2).map { i in
            let st = s.index(s.startIndex, offsetBy: i); return Double(UInt8(s[st..<s.index(st, offsetBy: 2)], radix: 16) ?? 0) / 255 } }
        let A = h(a), B = h(b)
        return Color(red: A[0] + (B[0] - A[0]) * t, green: A[1] + (B[1] - A[1]) * t, blue: A[2] + (B[2] - A[2]) * t)
    }
}

/// Day / night ink set, as on the canvas.
struct Ink {
    let night: Bool
    var ink: Color { night ? Color(hex: "#F3F5FF") : Color(hex: "#1A2440") }
    var sub: Color { night ? Color(hex: "#BAC2E0") : Color(hex: "#46516E") }
    var blue: Color { night ? Color(hex: "#9CC0FF") : Color(hex: "#1F5BD0") }
    var line: Color { night ? Color.white.opacity(0.10) : Color(hex: "#1E2A44").opacity(0.08) }
    var track: Color { night ? Color.white.opacity(0.16) : Color(hex: "#1E2A44").opacity(0.12) }
    var card: Color { night ? Color.white.opacity(0.09) : Color.white.opacity(0.62) }
    var cardBorder: Color { night ? Color.white.opacity(0.14) : Color.white.opacity(0.8) }
    var btn: Color { night ? Color.white.opacity(0.16) : Color.white.opacity(0.6) }
    var faint: Color { night ? Color.white.opacity(0.28) : Color(hex: "#1E2A44").opacity(0.28) }
    var hot: Color { night ? Color(hex: "#FFB08A") : Color(hex: "#C2452D") }
}

extension Font {
    /// Galmuri11 Bold, the pixel face used for numbers and headings
    static func px(_ size: CGFloat) -> Font { .custom("Galmuri11-Bold", size: size) }
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
}

/// Pixel icons from the kit (icon-<name>), drawn with nearest-neighbour scaling.
struct PixelIcon: View {
    let name: String
    var size: CGFloat = 24
    var body: some View {
        Image("icon-\(name)")
            .interpolation(.none)
            .resizable()
            .frame(width: size, height: size)
    }
}

/// Frosted card as on the home screen
struct Card<Content: View>: View {
    let ink: Ink
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(EdgeInsets(top: 16, leading: 16, bottom: 14, trailing: 16))
            .background(ink.card)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(ink.cardBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color(hex: "#1E2A44").opacity(ink.night ? 0.22 : 0.08), radius: 9, y: 6)
    }
}
