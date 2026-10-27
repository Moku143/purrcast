import SwiftUI

/// "‹ 설정" on the left (back to settings), "완료" on the right — for pages opened from settings.
struct BackToSettings: View {
    @Binding var route: Route?
    var dismiss: () -> Void

    var body: some View {
        HStack {
            Button {
                Haptic.soft(); route = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { route = .settings }
            } label: {
                HStack(spacing: 4) { Image(systemName: "chevron.left").font(.ui(13, .bold)); Text(L("설정")) }
            }
            .font(.system(size: 15, weight: .semibold)).foregroundStyle(UI.accent).buttonStyle(.press(0.94))
            .accessibilityIdentifier("back-settings")
            Spacer()
            Button(L("완료")) { Haptic.soft(); dismiss() }.font(.system(size: 15, weight: .semibold)).foregroundStyle(UI.accent)
                .buttonStyle(.press(0.94)).accessibilityIdentifier("sheet-close")
        }
        .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 14)
    }
}

/// 언어 · Language: the device's language or one of the three. The app, widgets, watch and notifications follow;
/// the page itself changes language as soon as one is picked.
struct LanguageView: View {
    @EnvironmentObject var model: AppModel
    @Binding var route: Route?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            BackToSettings(route: $route) { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        PixelIcon(name: "globe", size: 30)
                        Text(L("언어 · Language")).font(.px(24)).foregroundStyle(UI.ink)
                    }
                    Text(L("앱 · 위젯 · 워치 · 알림이 같이 바뀌어요")).font(.ui(13)).foregroundStyle(UI.sub)
                    RowGroup {
                        option("", title: L("기기 설정"), subtitle: Lang.deviceLanguage.nativeName)
                        ForEach(Lang.allCases, id: \.self) { l in
                            RowDivider()
                            option(l.rawValue, title: l.nativeName, subtitle: nil)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
        }
        .background(UI.bg)
    }

    private func option(_ value: String, title: String, subtitle: String?) -> some View {
        Button {
            guard model.language != value else { return }
            Haptic.select()
            model.language = value
        } label: {
            SettingRow(title: title, subtitle: subtitle) {
                if model.language == value {
                    Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(UI.accent)
                }
            }
        }
        .buttonStyle(.row)
        .accessibilityIdentifier("lang-\(value.isEmpty ? "device" : value)")
    }
}

/// 오픈소스 라이선스: the pixel font's notice and the full SIL Open Font License, as the licence asks
/// (both files ship next to the font in Shared/Fonts).
struct LicensesView: View {
    @Binding var route: Route?
    @Environment(\.dismiss) private var dismiss

    private static func text(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt"),
              let s = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            BackToSettings(route: $route) { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(L("오픈소스 라이선스")).font(.px(24)).foregroundStyle(UI.ink)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Purrcast Pixel Medium").font(.ui(15, .bold))
                        Text(L("MGalmuri10 기반 · SIL OFL 1.1")).font(.ui(12.5)).foregroundStyle(UI.sub)
                        Text(Self.text("FONT-NOTICE")).font(.system(size: 12, design: .monospaced)).foregroundStyle(Color(hex: "#33405E"))
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 14))
                    Text(Self.text("OFL")).font(.system(size: 11, design: .monospaced)).foregroundStyle(Color(hex: "#33405E"))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .foregroundStyle(UI.ink)
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
        }
        .background(UI.bg)
    }
}
