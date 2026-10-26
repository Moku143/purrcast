import SwiftUI

/// 지역: the places you follow (current location first), search to add more. Free: one more place; Plus: no limit.
struct PlacesView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var searching = false
    @State private var showPaywall = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if searching { searchBar } else { SheetHeader(title: L("지역")) { dismiss() } }
            if !searching { searchBox }
            if searching { results.transition(.opacity.combined(with: .move(edge: .bottom))) } else { list.transition(.opacity) }
        }
        .background(UI.bg)
        .animation(Motion.gentle, value: searching)
        .onChange(of: focused) { _, on in if on { searching = true } }
        .task { await model.refreshPreviews() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    // MARK: search field

    /// List mode: the grey "도시 · 동네 찾기" box; tapping it starts a search.
    private var searchBox: some View {
        Button { Haptic.soft(); searching = true; focused = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(hex: "#8A93AA"))
                Text(L("도시 · 동네 찾기")).font(.system(size: 15)).foregroundStyle(Color(hex: "#8A93AA"))
                Spacer()
            }
            .padding(.horizontal, 12).frame(height: 42).background(Color(hex: "#E3E7EF")).clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain).padding(.horizontal, 16).padding(.bottom, 10).accessibilityIdentifier("search")
    }

    /// Search mode: the field with a clear button, "취소" beside it.
    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(hex: "#8A93AA"))
                TextField(L("도시 · 동네 찾기"), text: $query).font(.system(size: 15)).focused($focused)
                    .submitLabel(.search).accessibilityIdentifier("search-field")
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 18, height: 18).background(Color(hex: "#B9C0CF")).clipShape(Circle())
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12).frame(height: 42).background(Color(hex: "#E3E7EF")).clipShape(RoundedRectangle(cornerRadius: 12))
            Button(L("취소")) { endSearch() }.font(.system(size: 15, weight: .semibold)).foregroundStyle(UI.accent)
        }
        .padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 12)
    }

    private func endSearch() {
        query = ""; focused = false; searching = false
    }

    // MARK: list

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

            addRow
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(.plain).scrollContentBackground(.hidden)
    }

    /// Room for more: "+ 지역 추가". At the free limit: the dashed "지역 더 추가하기" card that opens Plus.
    @ViewBuilder private var addRow: some View {
        if model.canAddPlace {
            Button { Haptic.soft(); searching = true; focused = true } label: {
                Text(L("+ 지역 추가")).font(.system(size: 15, weight: .bold)).foregroundStyle(UI.accent)
                    .frame(maxWidth: .infinity).frame(height: 50).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 20))
            }.buttonStyle(.press(0.98)).accessibilityIdentifier("add-place")
        } else {
            Button { Haptic.soft(); showPaywall = true } label: {
                HStack(spacing: 12) {
                    PixelIcon(name: "sparkle", size: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L("지역 더 추가하기")).font(.ui(15, .bold)).foregroundStyle(UI.ink)
                        Text(L("무료는 1곳 더")).font(.ui(12)).foregroundStyle(UI.sub)
                    }
                    Spacer()
                    PlusTag()
                }
                .padding(16)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4])).foregroundStyle(UI.ink.opacity(0.18)))
            }.buttonStyle(.press(0.98)).accessibilityIdentifier("add-place")
        }
    }

    private func card(_ p: Place, current: Bool) -> some View {
        let s: WeatherScene? = model.previews[p.id].map { AppModel.planView($0, plus: model.plus) }
        let lv: Int = max(0, min(9, s?.level ?? 4))
        return PlaceCard(place: p, scene: s, level: lv, current: current)
    }

    // MARK: search results

    private var results: some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        let found = Place.catalog.filter { q.isEmpty || $0.name.contains(q) || $0.short.contains(q) }
        return ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(found.enumerated()), id: \.element.id) { i, p in
                    if i > 0 { Rectangle().fill(UI.line).frame(height: 1).padding(.leading, 16) }
                    resultRow(p)
                }
                if found.isEmpty {
                    Text(L("찾는 지역이 없어요")).font(.ui(13)).foregroundStyle(UI.sub).padding(20)
                }
            }
            .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16).padding(.bottom, 30)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private func resultRow(_ p: Place) -> some View {
        let added = model.places.contains { $0.id == p.id }
        return Button {
            guard !added else { return }
            Haptic.tap()
            if model.canAddPlace { model.add(p); endSearch() } else { showPaywall = true }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin").font(.system(size: 14, weight: .semibold)).foregroundStyle(UI.sub).frame(width: 14)
                VStack(alignment: .leading, spacing: 3) {
                    Text(p.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(UI.ink)
                    Text(Self.country(of: p)).font(.ui(12)).foregroundStyle(UI.sub)
                }
                Spacer(minLength: 8)
                if p.region != "kr" {
                    Text(L("분 단위 비")).font(.ui(11, .bold)).foregroundStyle(Color(hex: "#1F7A3A"))
                        .padding(.horizontal, 8).padding(.vertical, 4).background(Color(hex: "#DDF3E3")).clipShape(Capsule())
                }
                if added {
                    Text(L("추가됨")).font(.ui(12, .bold)).foregroundStyle(Color(hex: "#8A93AA"))
                } else {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundStyle(UI.accent)
                        .frame(width: 28, height: 28).background(Color(hex: "#FFF1E6")).clipShape(Circle())
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.row)
        .accessibilityIdentifier("result-\(p.id)")
    }

    /// The country line under a search result, from the place's time zone (the catalog has no geocoder yet).
    static func country(of p: Place) -> String {
        switch p.timeZone {
        case "Asia/Seoul": return L("대한민국")
        case "Asia/Tokyo": return L("일본")
        case "America/New_York": return L("미국")
        case "Europe/London": return L("영국")
        case "Europe/Paris": return L("프랑스")
        case "Asia/Bangkok": return L("태국")
        default: return p.timeZone.split(separator: "/").first.map(String.init) ?? ""
        }
    }
}

/// One place in the list: character dressed for it, name, time · condition, bubble, temperature.
private struct PlaceCard: View {
    @EnvironmentObject var model: AppModel
    let place: Place
    let scene: WeatherScene?
    let level: Int
    let current: Bool

    private var night: Bool { scene?.time == "night" }
    private var ink: Color { night ? Color(hex: "#F3F5FF") : UI.ink }

    var body: some View {
        HStack(spacing: 10) {
            sprite
            info
            Spacer(minLength: 6)
            temps
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(minHeight: 104)
        .background(LinearGradient(colors: [Color(hex: Rules.background[level]), night ? Color(hex: "#2B3566") : Color.white],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(current ? UI.accent : Color.clear, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color(hex: "#1E2A44").opacity(0.10), radius: 8, y: 6)
        .animation(Motion.snappy, value: current)
    }

    private var rain: RainState { RainState(rawValue: scene?.rain ?? "none") ?? .none }

    private var sprite: some View {
        CharacterSprite(character: model.shownCharacter, level: level, rain: rain, width: 70, animate: false)
            .frame(width: 70, height: 82).clipped()
    }

    private var subtitle: String {
        var t = place.id == "here" && model.hereIsLive ? L("지금 위치") + " · " : ""
        if let s = scene { t += s.clock + " · " + s.cond }
        return t
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                if place.id == "here" && model.hereIsLive { Image(systemName: "location.fill").font(.ui(11)) }
                Text(place.name).font(.px(16))
            }
            Text(subtitle).font(.ui(12)).opacity(0.8)
            if let b = scene?.bubble {
                Text(b.text).font(.ui(11, .bold)).foregroundStyle(UI.ink)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.white.opacity(0.85)).clipShape(Capsule())
                    .padding(.top, 2)
            }
        }
    }

    private var temps: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(scene.map { model.deg($0.temp) } ?? "–").font(.px(36)).rolling(scene?.temp ?? 0)
            if let s = scene {
                Text(L("최고 %@ · 최저 %@", model.deg(s.hi), model.deg(s.lo))).font(.ui(12)).opacity(0.8)
            }
        }
    }
}
