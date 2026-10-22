import SwiftUI

/// One character on its 480x560 canvas, drawn `width` points wide, with the idle breathing.
struct CharacterSprite: View {
    let character: PurrCharacter
    let level: Int
    let rain: RainState
    var mood: Mood = .normal
    var width: CGFloat = 176
    var animate: Bool = true
    @State private var up = false
    @Environment(\.accessibilityReduceMotion) private var reduce

    var height: CGFloat { width * Sprite.height / Sprite.width }
    private var name: String { character.stand(level: level, rain: rain) }

    var body: some View {
        ZStack {
            // a new outfit (or umbrella) fades and springs in over the old one instead of snapping
            Image(name)
                .resizable()
                .interpolation(.high)
                .frame(width: width, height: height)
                .id(name)
                .transition(reduce ? .opacity : .scale(scale: 0.92, anchor: .bottom).combined(with: .opacity))
        }
        .animation(animate ? Motion.bouncy : nil, value: name)
        // idle breathing: a slow, soft rise and settle (ease in/out, not a linear bounce)
        .offset(y: up ? -2.5 : 0)
        .scaleEffect(x: up ? 0.995 : 1, y: up ? 1.008 : 1, anchor: .bottom)
        .onAppear {
            guard animate, !reduce else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { up = true }
        }
        .accessibilityLabel(Text(character.defaultName))
    }
}

/// Walking: frames A and B alternate every 0.15 s.
struct WalkingSprite: View {
    let character: PurrCharacter
    let level: Int
    let rain: RainState
    var width: CGFloat = 100
    var facingLeft = false
    @State private var frame = 0
    private let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()
    var body: some View {
        Image(character.walk(level: level, rain: rain, frame: frame))
            .resizable()
            .frame(width: width, height: width * Sprite.height / Sprite.width)
            .scaleEffect(x: facingLeft ? -1 : 1, y: 1)
            .onReceive(timer) { _ in frame += 1 }
    }
}
