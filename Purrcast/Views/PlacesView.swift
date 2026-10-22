import SwiftUI

/// 지역: the places you follow (current location first), search to add more. Free: one more place; Plus: no limit.
struct PlacesView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var searching = false
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "지역") { dismiss() }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(UI.faint)
                TextField("도시 · 동네 찾기", text: $query, onEditingChanged: { searching = $0 || !query.isEmpty })
                    .font(.system(size: 15)).accessibilityIdentifier("search")
                if searching {
                    Button("취소") { query = ""; searching = false; hideKeyboard() }.font(.system(size: 14)).foregroundStyle(UI.accent)
                }
            }
            .padding(.horizontal, 12).frame(height: 42).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16).padding(.bottom, 10)

            if searching { results.transition(.opacity.combined(with: .move(edge: .bottom))) } else { list.transition(.opacity) }
        }
        .background(UI.bg)
        .animation(Motion.gentle, value: searching)
        .task { await model.refreshPreviews() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private var list: some View {
        List {
            ForEach(Array(model.places.enumerated()), id: \.element.id) { i, p in
                Button { Haptic.tap(); model.currentIndex = i; dismiss() } label: { card(p, current: i == model.currentIndex) }
                    .buttonStyle(.press(0.98))
                    .reveal(i)
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    .deleteDisabled(p.id == "here")
            }
            .onDelete { model.remove(at: $0) }

            VStack(spacing: 8) {
                Button {
                    if model.canAddPlace { searching = true } else { showPaywall = true }
                } label: {
                    Text("+ 지역 추가").font(.system(size: 15, weight: .semibold)).foregroundStyle(UI.accent)
                        .frame(maxWidth: .infinity).frame(height: 48).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.press(0.98)).accessibilityIdentifier("add-place")
                if !model.plus {
                    HStack(spacing: 6) { Text("무료는 1곳 더").font(.system(size: 12)).foregroundStyle(UI.sub); PlusTag(text: "Plus는 제한 없이") }
                }
            }
            .listRowBackground(Color.clear).listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(.plain).scrollContentBackground(.hidden)
    }

    private func card(_ p: Place, current: Bool) -> some View {
        let s: WeatherScene? = model.previews[p.id].map { AppModel.planView($0, plus: model.plus) }
        let lv: Int = max(0, min(9, s?.level ?? 4))
        return PlaceCard(place: p, scene: s, level: lv, current: current)
    }

    private var results: some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        let found = Place.catalog.filter { q.isEmpty || $0.name.contains(q) || $0.short.contains(q) }
        return List(found) { p in
            let added = model.places.contains { $0.id == p.id }
            Button {
                guard !added else { return }
                if model.canAddPlace { model.add(p); query = ""; searching = false; hideKeyboard() } else { showPaywall = true }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name).font(.system(size: 16, weight: .medium)).foregroundStyle(UI.ink)
                        Text(p.region == "kr" ? "한국 · 다음 6시간 비" : (p.region == "jp" ? "분 단위 비" : "시간별 예보")).font(.system(size: 12)).foregroundStyle(UI.sub)
                    }
                    Spacer()
                    if added { Image(systemName: "checkmark").foregroundStyle(UI.accent) } else { Image(systemName: "plus.circle.fill").foregroundStyle(UI.accent) }
                }
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// One place in the list: character dressed for it, name, time · condition, bubble, temperature.
private struct PlaceCard: View {
    @EnvironmentObject var model: AppModel
    let place: Place
    let scene: WeatherScene?
    let level: Int
    let current: Bool

    var body: some View {
        HStack(spacing: 10) {
            sprite
            info
            Spacer()
            temps
        }
        .foregroundStyle(UI.ink)
        .padding(12)
        .background(Color(hex: Rules.background[level]).opacity(0.75))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(current ? UI.accent : Color.clear, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .animation(Motion.snappy, value: current)
    }

    private var rain: RainState { RainState(rawValue: scene?.rain ?? "none") ?? .none }

    private var sprite: some View {
        CharacterSprite(character: model.shownCharacter, level: level, rain: rain, width: 70, animate: false)
            .frame(width: 70, height: 82).clipped()
    }

    private var subtitle: String {
        var t = place.id == "here" && model.hereIsLive ? "지금 위치 · " : ""
        if let s = scene { t += s.clock + " · " + s.cond }
        return t
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if place.id == "here" && model.hereIsLive { Image(systemName: "location.fill").font(.system(size: 11)) }
                Text(place.name).font(.px(16))
            }
            Text(subtitle).font(.system(size: 12)).foregroundStyle(UI.sub)
            if let b = scene?.bubble {
                Text(b.text).font(.px(11))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.white.opacity(0.85)).clipShape(Capsule())
            }
        }
    }

    private var temps: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(scene.map { model.deg($0.temp) } ?? "–").font(.px(30))
            if let s = scene {
                Text("최고 \(model.deg(s.hi)) · 최저 \(model.deg(s.lo))").font(.system(size: 11)).foregroundStyle(UI.sub)
            }
        }
    }
}
