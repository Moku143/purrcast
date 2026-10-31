import SwiftUI

/// Speech / thought / shout bubble in the pixel style: hard-edged rounded box, 2 px dark outline, a tail at the bottom centre.
struct BubbleView: View {
    let kind: String      // speech | thought | shout
    let tone: String      // white | sun | sky | coral | mint | night
    let icon: String      // icon name or "none"
    let text: String
    var fontSize: CGFloat = 13
    /// In the app the bubble pops in and floats a little; widgets and the watch draw it still.
    var live = false
    /// Where the tail points, measured from the bubble's left edge (nil: the middle). The home page passes the
    /// character's head: a long line then keeps its box on the screen and only the tail moves over to the head.
    var tailX: CGFloat? = nil
    @State private var shown = false
    @State private var bob = false
    @Environment(\.accessibilityReduceMotion) private var reduce

    private var fill: Color {
        switch tone {
        case "sun": return Color(hex: "#FFE8A3")
        case "sky": return Color(hex: "#D3E6F4")
        case "coral": return Color(hex: "#FFB4A0")
        case "mint": return Color(hex: "#CDEFD9")
        case "night": return Color(hex: "#2B3566")
        default: return .white
        }
    }
    private var inkColor: Color { tone == "night" ? Color(hex: "#F3F5FF") : Color(hex: "#1A2440") }
    private let outline = Color(hex: "#1A2440")
    private let px: CGFloat = 2

    var body: some View {
        // the box and the tail line up on the tail's point: the box's `tailX` (clamped inside the box) over the tail's middle
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                if icon != "none" { PixelIcon(name: icon, size: 16) }
                if !text.isEmpty {
                    // one line when the width allows (widgets and the watch fix the size); a long line from the
                    // server wraps to two inside the width it is given instead of growing past it
                    Text(text).font(.px(fontSize)).foregroundStyle(inkColor).lineLimit(3).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 9).padding(.vertical, 7)
            .background(fill)
            .overlay(PixelBorder(px: px).stroke(outline, lineWidth: px))
            .clipShape(PixelBorder(px: px))
            .alignmentGuide(.leading) { d in tailX.map { min(max($0, 12), d.width - 12) } ?? d.width / 2 }
            Tail(kind: kind, fill: fill, outline: outline)
                .frame(width: 14, height: kind == "thought" ? 14 : 8)
                .alignmentGuide(.leading) { d in d.width / 2 }
        }
        .overlay(alignment: .top) {
            if kind == "shout" { BurstLines(color: outline).frame(width: 60, height: 20).offset(y: -22) }
        }
        .scaleEffect(live && !shown && !reduce ? 0.4 : 1, anchor: .bottom)
        .opacity(live && !shown ? 0 : 1)
        .offset(y: live && bob ? -2 : 0)
        .onAppear {
            guard live else { return }
            withAnimation(reduce ? .easeOut(duration: 0.2) : Motion.bouncy.delay(0.25)) { shown = true }
            guard !reduce else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(0.6)) { bob = true }
        }
    }
}

/// Rounded-by-steps rectangle (the pixel look): corners cut by one pixel step.
struct PixelBorder: Shape {
    var px: CGFloat
    func path(in r: CGRect) -> Path {
        let s = px * 2
        var p = Path()
        p.move(to: CGPoint(x: r.minX + s, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - s, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX - s, y: r.minY + px)); p.addLine(to: CGPoint(x: r.maxX - px, y: r.minY + px))
        p.addLine(to: CGPoint(x: r.maxX - px, y: r.minY + s)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY + s)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - s))
        p.addLine(to: CGPoint(x: r.maxX - px, y: r.maxY - s)); p.addLine(to: CGPoint(x: r.maxX - px, y: r.maxY - px)); p.addLine(to: CGPoint(x: r.maxX - s, y: r.maxY - px))
        p.addLine(to: CGPoint(x: r.maxX - s, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX + s, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX + s, y: r.maxY - px))
        p.addLine(to: CGPoint(x: r.minX + px, y: r.maxY - px)); p.addLine(to: CGPoint(x: r.minX + px, y: r.maxY - s)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY - s))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + s)); p.addLine(to: CGPoint(x: r.minX + px, y: r.minY + s)); p.addLine(to: CGPoint(x: r.minX + px, y: r.minY + px))
        p.addLine(to: CGPoint(x: r.minX + s, y: r.minY + px)); p.closeSubpath()
        return p
    }
}

private struct Tail: View {
    let kind: String; let fill: Color; let outline: Color
    var body: some View {
        if kind == "thought" {
            VStack(spacing: 2) {
                Rectangle().fill(fill).frame(width: 6, height: 6).overlay(Rectangle().stroke(outline, lineWidth: 2))
                Rectangle().fill(fill).frame(width: 4, height: 4).overlay(Rectangle().stroke(outline, lineWidth: 2))
            }
        } else {
            // a stepped triangle pointing down
            VStack(spacing: 0) {
                Rectangle().fill(fill).frame(width: 10, height: 2)
                Rectangle().fill(fill).frame(width: 6, height: 2)
                Rectangle().fill(fill).frame(width: 2, height: 2)
            }
            .background(alignment: .top) {
                VStack(spacing: 0) {
                    Rectangle().fill(outline).frame(width: 14, height: 2)
                    Rectangle().fill(outline).frame(width: 10, height: 2)
                    Rectangle().fill(outline).frame(width: 6, height: 2)
                    Rectangle().fill(outline).frame(width: 2, height: 2)
                }.offset(y: 2)
            }
            .offset(y: -2)
        }
    }
}

private struct BurstLines: View {
    let color: Color
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height)
            for a in [-50.0, -20.0, 20.0, 50.0] {
                let r = a * .pi / 180
                var p = Path()
                p.move(to: CGPoint(x: c.x + sin(r) * 24, y: c.y - cos(r) * 8))
                p.addLine(to: CGPoint(x: c.x + sin(r) * 32, y: c.y - cos(r) * 18))
                ctx.stroke(p, with: .color(color), lineWidth: 2)
            }
        }
    }
}
