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

    var height: CGFloat { width * Sprite.height / Sprite.width }

    var body: some View {
        Image(character.stand(level: level, rain: rain))
            .resizable()
            .interpolation(.high)
            .frame(width: width, height: height)
            .offset(y: up ? -2 : 0)
            .onAppear {
                guard animate else { return }
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: true)) { up = true }
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
