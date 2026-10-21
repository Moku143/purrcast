import SwiftUI

/// 캐릭터: pick who forecasts. The cat is free; the others need Plus (tapping one on Free opens the Plus page).
/// The chosen one's name can be changed (pencil); the widgets and the watch follow the choice.
struct CharacterSheet: View {
    @EnvironmentObject var model: AppModel
    @Binding var route: Route?
    @Environment(\.dismiss) private var dismiss
    @State private var renaming: PurrCharacter?
    @State private var draft = ""

    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "캐릭터", trailing: "닫기") { dismiss() }
            ScrollView {
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(PurrCharacter.allCases) { c in tile(c) }
                    comingSoon
                }
                .padding(.horizontal, 16)

                if !model.plus {
                    Button { open(.paywall) } label: {
                        HStack(spacing: 10) {
                            PixelIcon(name: "sparkle", size: 22)
                            Text("캐릭터 바꾸기는 Plus").font(.system(size: 15, weight: .semibold)).foregroundStyle(UI.ink)
                            Spacer()
                            PlusTag(text: "3일 무료")
                        }
                        .padding(14).background(UI.accentSoft).clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain).padding(.horizontal, 16).padding(.top, 14)
                }
                Text("위젯 · 애플워치도 같이 바뀌어요").font(.system(size: 12)).foregroundStyle(UI.sub)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 24)
            }
        }
        .background(UI.bg)
        .alert("이름 바꾸기", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("이름", text: $draft)
            Button("저장") { if let c = renaming { model.rename(c, to: draft) }; renaming = nil }
            Button("취소", role: .cancel) { renaming = nil }
        } message: { Text("8글자까지 쓸 수 있어요") }
    }

    private func tile(_ c: PurrCharacter) -> some View {
        let selected = model.shownCharacter == c
        let locked = c.isPlus && !model.plus
        return Button {
            if locked { open(.paywall) } else { model.character = c }
        } label: {
            VStack(spacing: 8) {
                CharacterSprite(character: c, level: 4, rain: .none, width: 104, animate: selected)
                    .frame(height: 112).clipped()
                HStack(spacing: 6) {
                    Text(model.name(of: c)).font(.px(15)).foregroundStyle(UI.ink).lineLimit(1).minimumScaleFactor(0.7)
                    if selected {
                        Button { draft = model.name(of: c); renaming = c } label: {
                            Image(systemName: "pencil").font(.system(size: 13, weight: .bold)).foregroundStyle(UI.sub)
                        }.buttonStyle(.plain).accessibilityIdentifier("rename").accessibilityLabel("이름 바꾸기")
                    }
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(selected ? UI.accentSoft : Color.white)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? UI.accent : Color.clear, lineWidth: 3))
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(UI.accent).padding(8)
                } else if c.isPlus {
                    PlusTag().padding(10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pick-\(c.rawValue)")
    }

    private var comingSoon: some View {
        VStack(spacing: 10) {
            Circle().fill(UI.bg).frame(width: 64, height: 64)
                .overlay(Text("?").font(.px(28)).foregroundStyle(UI.faint))
            Text("곧 와요").font(.system(size: 12)).foregroundStyle(UI.faint)
        }
        .frame(maxWidth: .infinity, minHeight: 168)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(UI.faint, style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
    }

    private func open(_ r: Route) {
        // swap this sheet for the other one
        route = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { route = r }
    }
}
