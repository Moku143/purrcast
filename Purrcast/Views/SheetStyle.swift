import SwiftUI

/// Colours for the light sheets (settings, places, character, paywall), from the canvas.
enum UI {
    static let bg = Color(hex: "#F2F4F8")
    static let row = Color.white
    static let ink = Color(hex: "#1A2440")
    static let sub = Color(hex: "#6B7591")
    static let faint = Color(hex: "#A3AABD")
    static let line = Color(hex: "#1E2A44").opacity(0.08)
    static let accent = Color(hex: "#EE7A3B")
    static let accentSoft = Color(hex: "#FFE9DC")
    static let plus = Color(hex: "#EE7A3B")
}

/// Big pixel title on the left, one text button on the right ("완료" / "닫기").
struct SheetHeader: View {
    let title: String
    var trailing = "완료"
    var action: () -> Void
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.px(24)).foregroundStyle(UI.ink)
            Spacer()
            Button(trailing) { Haptic.soft(); action() }.font(.system(size: 15, weight: .semibold)).foregroundStyle(UI.accent)
                .buttonStyle(.press(0.94)).accessibilityIdentifier("sheet-close")
        }
        .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 10)
    }
}

/// Small orange "Plus" tag
struct PlusTag: View {
    var text = "Plus"
    var body: some View {
        Text(text).font(.ui(11, .bold)).foregroundStyle(.white)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(UI.plus).clipShape(Capsule())
    }
}

/// Section label above a group of rows
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.ui(13, .medium)).foregroundStyle(UI.sub)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 6)
    }
}

/// White rounded group of rows with hairlines between them
struct RowGroup<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(UI.row)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
    }
}

struct RowDivider: View {
    var body: some View { Rectangle().fill(UI.line).frame(height: 1).padding(.leading, 52) }
}

/// One settings row: pixel icon, title (+ subtitle), trailing content
struct SettingRow<Trailing: View>: View {
    var icon: String?
    let title: String
    var subtitle: String?
    var plus = false
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(spacing: 12) {
            if let icon { PixelIcon(name: icon, size: 22) }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(.system(size: 16, weight: .medium)).foregroundStyle(UI.ink)
                    if plus { PlusTag() }
                }
                if let subtitle { Text(subtitle).font(.ui(12)).foregroundStyle(UI.sub) }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 14).frame(minHeight: 54)
    }
}

/// Segmented pill used for units (°C / °F etc.)
struct Pills<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var value: T
    @Namespace private var ns
    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { o in
                Button { Haptic.select(); withAnimation(Motion.snappy) { value = o.0 } } label: {
                    Text(o.1).font(.ui(13, .semibold))
                        .foregroundStyle(value == o.0 ? UI.ink : UI.sub)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background {
                            // the white pill slides between options
                            if value == o.0 {
                                RoundedRectangle(cornerRadius: 8).fill(Color.white)
                                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                                    .matchedGeometryEffect(id: "pill", in: ns)
                            }
                        }
                }.buttonStyle(.plain)
            }
        }
        .padding(3).background(UI.bg).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// Big orange call to action
struct PrimaryButton: View {
    let title: String
    var busy = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title).font(.px(17)).opacity(busy ? 0 : 1)
                if busy { ProgressView().tint(.white) }
            }
            .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 54)
            .background(UI.accent).clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: UI.accent.opacity(0.35), radius: 10, y: 6)
            .animation(Motion.snappy, value: busy)
        }.buttonStyle(.press(0.97))
        .simultaneousGesture(TapGesture().onEnded { Haptic.tap() })
    }
}
