import SwiftUI
#if canImport(ActivityKit)

/// The layout board's Live Activity page (UI tests: -open liveLab): the lock-screen card and the Dynamic Island's
/// expanded and compact forms at their real sizes on a 393-pt-wide iPhone, for the rain-on-the-way and raining states.
struct LiveLabView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let a = RainActivityAttributes(place: model.currentPlace.short, character: model.shownCharacter.rawValue, level: model.scene.level)
        let now = Int(Date().timeIntervalSince1970)
        let soon = RainActivityAttributes.ContentState(title: L("%@쯤 비 예보", HourLabel.word(18, clock12: model.clock12)), sub: "1mm · " + L("우산 챙기세요"), icon: "umbrella_closed", what: "rain", falling: false, mm: 1, start: now + 2 * 3600, end: now + 3 * 3600, endHour: 19)
        let falling = RainActivityAttributes.ContentState(title: L("지금 비 · %@", "1mm"), sub: L("%d시까지 비 예보", 19), icon: "umbrella", what: "rain", falling: true, mm: 1, start: now, end: now + 3600, endHour: 19)
        ScrollView {
            VStack(spacing: 18) {
                label(L("잠금 화면"))
                lockCard(a, soon).accessibilityIdentifier("lab-live-lock")
                lockCard(a, falling).accessibilityIdentifier("lab-live-lock-raining")
                label(L("다이내믹 아일랜드"))
                island(a, soon).accessibilityIdentifier("lab-live-island")
                compact(a, falling).accessibilityIdentifier("lab-live-compact")
            }
            .padding(.vertical, 24).frame(maxWidth: .infinity)
        }
        .background(Color(hex: "#2B3355"))
    }

    private func label(_ t: String) -> some View {
        Text(t).font(.ui(12, .semibold)).foregroundStyle(Color.white.opacity(0.7)).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24)
    }

    /// 357 × ~108 pt, the system's Live Activity card on the lock screen
    private func lockCard(_ a: RainActivityAttributes, _ s: RainActivityAttributes.ContentState) -> some View {
        RainLockView(a: a, s: s)
            .frame(width: 357)
            .background(Color(hex: "#1A2046"))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    /// The island expanded (371 × ~130 pt): the same three regions the widget lays out
    private func island(_ a: RainActivityAttributes, _ s: RainActivityAttributes.ContentState) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                RainCat(a: a, s: s, width: 48).padding(.leading, 4)
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.title).font(.px(17)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                    Text(a.place.isEmpty ? s.sub : "\(a.place) · \(s.sub)").font(.ui(12)).foregroundStyle(Color(hex: "#C9D0F0")).lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            RainBar(s: s).padding(.horizontal, 4).padding(.top, 2)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(width: 371)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
    }

    /// The compact island (≈ 126 × 37 pt): the cat on the left of the camera, a few words on the right
    private func compact(_ a: RainActivityAttributes, _ s: RainActivityAttributes.ContentState) -> some View {
        HStack(spacing: 0) {
            RainCat(a: a, s: s, width: 22).padding(.leading, 10)
            Spacer(minLength: 0)
            Circle().fill(Color(hex: "#0A0A0A")).frame(width: 24, height: 24)   // the camera
            Spacer(minLength: 0)
            Text(RainLiveWords.short(s)).font(.px(12)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7).padding(.trailing, 12)
        }
        .frame(width: 160, height: 37)
        .background(Color.black)
        .clipShape(Capsule())
    }
}
#endif
