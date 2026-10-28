import SwiftUI

/// The watch app's first page (also rendered on the phone for the widget matrix).
struct WatchNow: View {
    let snap: WeatherSnapshot
    #if os(watchOS)
    @Environment(\.isLuminanceReduced) private var dimmed     // always-on (wrist down): hold still to save battery
    #else
    var dimmed = true                                         // previews on the phone (widget matrix): one still frame
    #endif
    var body: some View {
        let s = snap.scene, ink = Ink(night: s.isNight), lv = max(0, min(9, s.level))
        let rain = RainState(rawValue: s.rain) ?? .none
        ZStack(alignment: .topLeading) {
            WidgetBackground(level: lv, night: s.isNight, scene: s, animate: !dimmed).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Text(snap.placeShort).font(.px(12)).opacity(0.85)
                Text(snap.deg(s.temp)).font(.px(46)).frame(maxWidth: .infinity, alignment: .trailing).rolling(s.temp)
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 2) {
                    ZStack(alignment: .bottom) {
                        CharacterSprite(character: snap.shownCharacter, level: lv, rain: rain, width: 74, animate: !dimmed, coat: s.raincoat)
                            .frame(width: 74, height: 86, alignment: .bottom)
                        if let b = s.bubble {
                            BubbleView(kind: b.kind, tone: b.tone, icon: b.icon, text: Compact.bubbleWord(s, max: 5), fontSize: 9).fixedSize()
                                .scaleEffect(0.85, anchor: .bottom)
                                .padding(.bottom, bubbleBottom(snap.shownCharacter, s.raincoat == .bare ? .none : rain, spriteHeight: 86))
                        }
                    }
                    .frame(width: 80, height: 86, alignment: .bottom)
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Compact.head(s)).font(.px(11))
                        Text(L("체감 %@", snap.deg(s.feels))).font(.px(10))
                        Text(L("최고 %@ 최저 %@", snap.deg(s.hi), snap.deg(s.lo))).font(.px(9))
                    }
                    .lineLimit(1).minimumScaleFactor(0.6)      // each on one line, even "최고 -13° 최저 -14°"
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(ink.ink)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

