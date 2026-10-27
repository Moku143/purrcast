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
                HStack(alignment: .firstTextBaseline) {
                    Text(dateText).font(.system(size: 15, weight: .semibold)).foregroundStyle(accent)
                    Spacer()
                    Text("10:09").font(.system(size: 44, weight: .semibold, design: .rounded)).foregroundStyle(.white)
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
