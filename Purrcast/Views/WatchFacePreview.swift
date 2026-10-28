import SwiftUI

/// A watch face as it looks with the Purrcast complications on it (Plus page): date and time, the rectangular
/// complication (character silhouette, temperature, condition), and three circular ones (today's range gauge,
/// chance of rain, the character's face). Drawn with the same views the complications use.
struct WatchFacePreview: View {
    let snap: WeatherSnapshot
    private let accent = Color(hex: "#FF9F43")

    private var dateText: String {
        let f = DateFormatter(); f.locale = Lang.current.locale
        f.setLocalizedDateFormatFromTemplate("EEEd")
        return f.string(from: Date())
    }

    var body: some View {
        ZStack {
            Color.black
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(dateText).font(.system(size: 14, weight: .semibold)).foregroundStyle(accent)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    Text(WatchClock.now(clock12: snap.clock12)).font(.system(size: 36, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                        .lineLimit(1).fixedSize()
                }
                LockRectangularView(snap: snap)
                    .foregroundStyle(.white)
                    .frame(height: 56)
                HStack(spacing: 0) {
                    LockCircularView(snap: snap).frame(width: 50, height: 50)
                    Spacer(minLength: 0)
                    LockRainCircularView(snap: snap).foregroundStyle(.white).frame(width: 50, height: 50)
                    Spacer(minLength: 0)
                    ZStack {
                        AccessoryWidgetBackgroundCompat()
                        Image(snap.shownCharacter.faceImage).resizable().interpolation(.none).scaledToFit().frame(width: 32, height: 32)
                    }
                    .frame(width: 50, height: 50)
                }
            }
            .padding(.horizontal, 12).padding(.top, 14).padding(.bottom, 12)
        }
    }
}

/// The time the pictures show: now, as the watch would (12- or 24-hour).
enum WatchClock {
    static func now(clock12: Bool) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = clock12 ? "h:mm" : "HH:mm"
        return f.string(from: Date())
    }
}

/// The watch app's first page next to a watch face with the complications, each in an Apple Watch case — the Plus
/// page and the first-run page show the person's own place and weather in them. `scale` sets the size (0.57 →
/// 122-pt cases).
struct WatchPairPreview: View {
    let snap: WeatherSnapshot
    var scale: CGFloat = 0.57
    var body: some View {
        HStack(spacing: 16 * scale / 0.57) {
            WatchCase(scale: scale) { WatchAppScreen(snap: snap) }
            WatchCase(scale: scale) { WatchFacePreview(snap: snap) }
        }
    }
}

/// An Apple Watch: dark case, crown and side button, the screen drawn at the watch's own size (184 × 224) and scaled.
struct WatchCase<Content: View>: View {
    var scale: CGFloat
    @ViewBuilder var content: Content
    var body: some View {
        let k = scale / 0.57
        ZStack {
            RoundedRectangle(cornerRadius: 36 * k, style: .continuous).fill(Color(hex: "#111114"))
                .frame(width: 122 * k, height: 146 * k)
                .shadow(color: .black.opacity(0.25), radius: 8 * k, y: 5 * k)
            content.frame(width: 184, height: 224)
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                .scaleEffect(scale)
                .frame(width: 184 * scale, height: 224 * scale)
        }
        .overlay(alignment: .trailing) {
            VStack(spacing: 10 * k) {
                Capsule().fill(Color(hex: "#3A3A40")).frame(width: 5 * k, height: 20 * k)    // crown
                Capsule().fill(Color(hex: "#2A2A30")).frame(width: 4 * k, height: 26 * k)    // side button
            }.offset(x: 4 * k, y: -6 * k)
        }
        .accessibilityHidden(true)
    }
}

/// The watch app's first page as the watch shows it: the sky to the edges, the place in the clock's row, the time
/// at the top right.
struct WatchAppScreen: View {
    let snap: WeatherSnapshot
    var body: some View {
        ZStack(alignment: .topTrailing) {
            WatchNow(snap: snap)
            Text(WatchClock.now(clock12: snap.clock12)).font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
                .shadow(color: .black.opacity(0.25), radius: 1.5)
                .padding(.top, 9).padding(.trailing, 22)
        }
    }
}
