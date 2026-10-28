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
        let s = snap.scene, ink = Ink(night: s.isNight), lv = max(0, min(9, s.level))
        let rain = RainState(rawValue: s.rain) ?? .none
        let catW: CGFloat = 80, catH = catW * Sprite.height / Sprite.width
        ZStack(alignment: .topLeading) {
            WidgetBackground(level: lv, night: s.isNight, scene: s, animate: !dimmed)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text(snap.placeShort).font(.px(12)).lineLimit(1).minimumScaleFactor(0.7).probe("place")
                    PixelIcon(name: s.hours.first?.icon ?? "cloud", size: 14).probe("icon")
                }
                .frame(maxWidth: 112, alignment: .leading)
                .padding(.top, headerTop).padding(.leading, 16)
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 0) {
                    ZStack(alignment: .bottom) {
                        CharacterSprite(character: snap.shownCharacter, level: lv, rain: rain, width: catW, animate: !dimmed).probe("cat")
                            .frame(width: catW, height: catH, alignment: .bottom)
                        if let b = s.bubble {
                            BubbleView(kind: b.kind, tone: b.tone, icon: b.icon, text: Compact.bubbleWord(s, max: 5), fontSize: 9).fixedSize().probe("bubble")
                                .scaleEffect(0.85, anchor: .bottom)
                                .padding(.bottom, bubbleBottom(snap.shownCharacter, rain, level: lv, spriteHeight: catH))
                        }
                    }
                    .frame(width: 90, height: 150, alignment: .bottom)
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(snap.deg(s.temp)).font(.px(34)).rolling(s.temp).probe("temp")
                        if let t = sunsetTile(s) { HStack(spacing: 2) { PixelIcon(name: "sunset", size: 12).probe("sunsetIcon"); Text(t).font(.px(10)).probe("sunsetText") } }
                        Text(L("체감 %@", snap.deg(s.feels))).font(.px(10)).probe("feels")
                        Text(L("강수 %d%%", s.hours.prefix(6).map { $0.chance }.max() ?? 0)).font(.px(10)).probe("chance")
                    }
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.bottom, 14)
                }
                .padding(.leading, 10).padding(.trailing, 14).padding(.bottom, 4)
            }
            .foregroundStyle(ink.ink)
        }
        .ignoresSafeArea()
    }
}
