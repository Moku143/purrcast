import SwiftUI

/// The watch app's first page (also rendered on the phone for the widget matrix and the Plus page).
/// Laid out like the small (2×2) home-screen widget: place and weather icon on the top row — in the watch's clock
/// row, left of the time — the character standing at the bottom left with its bubble clear above the head, and on
/// the right the temperature, sunset / sunrise, feels-like and chance of rain.
struct WatchNow: View {
    let snap: WeatherSnapshot
    /// How far down the top row sits: level with the watch's clock (the system draws the time at the top right).
    var headerTop: CGFloat = 11
    #if os(watchOS)
    @Environment(\.isLuminanceReduced) private var dimmed     // always-on (wrist down): hold still to save battery
    #else
    var dimmed = true                                         // previews on the phone (widget matrix): one still frame
    #endif
    var body: some View {
        let s = snap.scene, ink = Ink(night: s.isNight), lv = Rules.clamp(s.level)
        let rain = RainState(rawValue: s.rain) ?? .none
        GeometryReader { g in
            // placed on the layout board on the 46-mm screen (208 × 248); smaller watches keep the margins and
            // shrink the character and the words
            let k = min(1, max(0.82, g.size.width / 208))
            let catW = 84 * k, catH = catW * Sprite.height / Sprite.width
            ZStack(alignment: .topLeading) {
                WidgetBackground(level: lv, night: s.isNight, scene: s, animate: !dimmed)
                HStack(spacing: 4) {
                    Text(snap.placeShort).font(.px(12)).lineLimit(1).minimumScaleFactor(0.7).probe("place")
                    PixelIcon(name: s.hours.first?.icon ?? "cloud", size: 14).probe("icon")
                }
                .frame(maxWidth: 112, alignment: .leading)
                .padding(.top, headerTop).padding(.leading, 16)
                // the temperature high on the right, under the clock
                // four characters ("-12°") a size smaller, so a warning bubble beside it still clears it
                Text(snap.deg(s.temp)).font(.px((snap.deg(s.temp).count >= 4 ? 46 : 52) * k)).lineLimit(1).rolling(s.temp).probe("temp")
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 64 * k).padding(.trailing, 12)
                // the character at the bottom left; its bubble rides on it (above the head, or above the umbrella)
                ZStack(alignment: .bottom) {
                    CharacterSprite(character: snap.shownCharacter, level: lv, rain: rain, width: catW, animate: !dimmed).probe("cat")
                        .frame(width: catW, height: catH, alignment: .bottom)
                    if let b = s.bubble {
                        BubbleView(kind: b.kind, tone: b.tone, icon: b.icon, text: Compact.bubbleWord(s, max: 5), fontSize: 9.5 * k).fixedSize().probe("bubble")
                            .scaleEffect(0.66, anchor: .bottom)
                            .padding(.bottom, bubbleBottom(snap.shownCharacter, rain, level: lv, spriteHeight: catH))
                    }
                }
                .frame(width: catW + 6, height: catH + 60, alignment: .bottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 16.5).padding(.bottom, 14.5)
                // sunset · feels · rain at the bottom right
                // close together, down by the rain chance; the sunset row a little higher
                VStack(alignment: .trailing, spacing: 1.2 * k) {
                    if let t = sunsetTile(s) { HStack(spacing: 3) { PixelIcon(name: "sunset", size: 14 * k).probe("sunsetIcon"); Text(t).font(.px(12 * k)).probe("sunsetText") }.padding(.bottom, 2.5 * k) }
                    Text(L("체감 %@", snap.deg(s.feels))).font(.px(12 * k)).probe("feels")
                    Text(L("강수 %d%%", s.hours.prefix(6).map { $0.chance }.max() ?? 0)).font(.px(12 * k)).probe("chance")
                }
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 20).padding(.bottom, 23.5)
            }
            .foregroundStyle(ink.ink)
        }
        .ignoresSafeArea()
    }
}
