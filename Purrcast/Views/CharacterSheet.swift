import SwiftUI

/// 캐릭터: pick who forecasts. The cat is free; the others need Plus (tapping one on Free opens the Plus page).
/// The chosen one's name can be changed in place (pencil → field → ✓); the widgets and the watch follow the choice.
/// The fourth tile is the empty "곧 와요" slot for the next character.
struct CharacterSheet: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var purchases: Purchases
    @Binding var route: Route?
    @Environment(\.dismiss) private var dismiss
    @State private var editing: PurrCharacter?
    @State private var draft = ""
    @FocusState private var nameFocused: Bool

    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private static let maxName = 8

    /// The tiles wear today's outfit (the home scene's level), like the design.
    private var level: Int { Rules.clamp(model.scene.level) }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: L("캐릭터"), trailing: L("닫기")) { dismiss() }
            ScrollView {
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(PurrCharacter.allCases) { c in tile(c) }
                    soonTile
                }
                .padding(.horizontal, 20)
                .reveal(0)

                if !model.plus { plusBanner.reveal(1) }
                if !Voice.choices.isEmpty { voiceSection.reveal(2) }
                Text(L("위젯 · 애플워치도 같이 바뀌어요")).font(.ui(12.5)).foregroundStyle(UI.sub)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(UI.bg)
        .onChange(of: draft) { _, v in if v.count > Self.maxName { draft = String(v.prefix(Self.maxName)) } }
    }

    // MARK: tiles

    private func tile(_ c: PurrCharacter) -> some View {
        let selected = model.shownCharacter == c
        let locked = c.isPlus && !model.plus
        return VStack(spacing: 0) {
            Button { pick(c) } label: {
                CharacterSprite(character: c, level: level, rain: .none, width: 104, animate: selected)
                    .frame(height: 112).clipped()
                    .scaleEffect(selected ? 1 : 0.94, anchor: .bottom)
                    .saturation(locked ? 0.6 : 1)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.press(0.97))
            .accessibilityIdentifier("pick-\(c.rawValue)")
            nameRow(c, selected: selected)
                .frame(height: 30).padding(.horizontal, 6).padding(.top, 6).padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity).frame(height: 170)
        .background(selected ? Color(hex: Rules.background[level]) : Color.white)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? UI.accent : Color.white, lineWidth: 3))
        .overlay(alignment: .topTrailing) { badge(selected: selected, locked: locked) }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color(hex: "#1E2A44").opacity(selected ? 0 : 0.06), radius: 6, y: 2)
        .animation(Motion.snappy, value: selected)
    }

    @ViewBuilder private func badge(selected: Bool, locked: Bool) -> some View {
        if selected {
            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                .frame(width: 24, height: 24).background(UI.accent).clipShape(Circle()).padding(7)
                .transition(.scale(scale: 0.3).combined(with: .opacity))
        } else if locked {
            PlusTag().padding(8).transition(.opacity)
        }
    }

    /// The name under the sprite: tap it to rename (when chosen) or to pick; the pencil renames; editing shows a field and ✓.
    @ViewBuilder private func nameRow(_ c: PurrCharacter, selected: Bool) -> some View {
        if editing == c {
            HStack(spacing: 4) {
                TextField(L("이름"), text: $draft).font(.px(15)).foregroundStyle(UI.ink).multilineTextAlignment(.center)
                    .focused($nameFocused).submitLabel(.done).onSubmit { saveName() }
                    .frame(width: 104, height: 30).background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(UI.accent, lineWidth: 2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("name-field")
                Button { saveName() } label: {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 30, height: 30).background(UI.accent).clipShape(Circle())
                }
                .buttonStyle(.plain).accessibilityIdentifier("name-save").accessibilityLabel(L("저장"))
            }
        } else {
            HStack(spacing: 4) {
                Button { if selected { beginRename(c) } else { pick(c) } } label: {
                    Text(model.name(of: c)).font(.px(15)).foregroundStyle(UI.ink).lineLimit(1).minimumScaleFactor(0.7)
                }
                .buttonStyle(.plain)
                if selected {
                    Button { beginRename(c) } label: {
                        Image(systemName: "pencil").font(.system(size: 12, weight: .bold)).foregroundStyle(UI.sub)
                            .frame(width: 24, height: 24).background(Color.white.opacity(0.7)).clipShape(Circle())
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("rename").accessibilityLabel(L("이름 바꾸기"))
                }
            }
        }
    }

    /// The empty slot for the next character.
    private var soonTile: some View {
        VStack(spacing: 10) {
            Text("?").font(.px(28)).foregroundStyle(UI.ink.opacity(0.28))
                .frame(width: 76, height: 76).background(UI.ink.opacity(0.09)).clipShape(Circle())
            VStack(spacing: 4) {
                Text(L("곧 와요")).font(.ui(12, .semibold)).foregroundStyle(Color(hex: "#8A93AA"))
                Text(L("추후 업데이트로 추가 예정")).font(.ui(10.5)).foregroundStyle(Color(hex: "#8A93AA"))
            }
        }
        .frame(maxWidth: .infinity).frame(height: 170)
        .background(Color(hex: "#E8EBF2"))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4])).foregroundStyle(UI.ink.opacity(0.15)))
        .overlay(alignment: .topTrailing) { if !model.plus { PlusTag().padding(8) } }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityIdentifier("pick-soon")
    }

    // MARK: 말투 (Plus)

    /// How the character talks: its own by default (고양이 존댓말 · 브리티시숏헤어 격식 · 아비시니안 반말), or one picked here.
    /// English has one tone, so this is hidden there; Japanese offers 丁寧 · タメ口. On Free it shows the sample and opens Plus.
    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                PixelIcon(name: "music", size: 20)
                Text(L("말투")).font(.px(15)).foregroundStyle(UI.ink)
                Spacer()
                if !model.plus { PlusTag() }
            }
            if model.plus {
                ScrollView(.horizontal, showsIndicators: false) {
                    Pills(options: [("", L("캐릭터 기본"))] + Voice.choices.map { ($0.rawValue, $0.name) }, value: $model.voiceChoice)
                }
                .accessibilityIdentifier("voice-pills")
            }
            // what the character sounds like now, in its bubble style
            Text(model.say(L("비 예보예요. 우산 챙기세요.")))
                .font(.ui(13)).foregroundStyle(UI.ink)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(UI.bg).clipShape(RoundedRectangle(cornerRadius: 12))
                .id(model.voiceChoice).transition(.opacity)
            if !model.plus {
                Text(L("Plus에서 고를 수 있어요")).font(.ui(12)).foregroundStyle(UI.sub)
            }
        }
        .padding(16)
        .background(UI.row).clipShape(RoundedRectangle(cornerRadius: 18))
        .contentShape(Rectangle())
        .onTapGesture { if !model.plus { Haptic.soft(); open(.paywall) } }
        .animation(Motion.snappy, value: model.voiceChoice)
        .padding(.horizontal, 20).padding(.top, 16)
        .accessibilityIdentifier("voice")
    }

    private var plusBanner: some View {
        Button { open(.paywall) } label: {
            HStack(spacing: 12) {
                PixelIcon(name: "sparkle", size: 24)
                Text(L("캐릭터 바꾸기는 Plus")).font(.ui(15, .bold)).foregroundStyle(UI.ink)
                Spacer()
                if let t = purchases.trialText(Purchases.yearly) { PlusTag(text: t) }
            }
            .padding(.horizontal, 16).frame(height: 56)
            .background(LinearGradient(colors: [Color(hex: "#FFE3CC"), Color(hex: "#FFF4EA")], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#FFD1AE"), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.press(0.98)).padding(.horizontal, 20).padding(.top, 16)
        .accessibilityIdentifier("go-plus")
    }

    // MARK: actions

    private func pick(_ c: PurrCharacter) {
        if editing != nil { saveName() }
        if c.isPlus && !model.plus { Haptic.soft(); open(.paywall); return }
        Haptic.success()
        withAnimation(Motion.bouncy) { model.character = c }
    }

    private func beginRename(_ c: PurrCharacter) {
        Haptic.soft()
        draft = model.name(of: c)
        withAnimation(Motion.snappy) { editing = c }
        nameFocused = true
    }

    private func saveName() {
        guard let c = editing else { return }
        model.rename(c, to: draft)
        nameFocused = false
        withAnimation(Motion.snappy) { editing = nil }
    }

    private func open(_ r: Route) {
        // swap this sheet for the other one
        route = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { route = r }
    }
}
