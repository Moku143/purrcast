import SwiftUI

/// 지역: the places you follow (current location first), search to add more. Free: one more place; Plus: no limit.
/// Search: the bundled index first (PlaceIndex: countries, their regions, Korea down to 읍면동, in ko / en / ja),
/// then Apple Maps for everything else (AppleSearch). Nothing is listed until something is typed.
struct PlacesView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apple = AppleSearch()
    @State private var query = ""
    @State private var searching = false
    @State private var showPaywall = false
    @State private var found = PlaceResults()
    @State private var indexDone = false          // the index finished loading (or could not)
    @State private var resolving: String?         // the Apple Maps row being looked up
    @State private var appleFailed = false
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
        .onChange(of: query) { _, q in runSearch(q) }
        .task { await model.refreshPreviews() }
        .task { await loadIndex() }
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
        appleFailed = false; resolving = nil
        apple.update("")
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
        let lv: Int = Rules.clamp(s?.level ?? 5)
        return PlaceCard(place: p, scene: s, level: lv, current: current)
    }

    // MARK: search results

    private func loadIndex() async {
        await PlaceIndex.shared.load()
        indexDone = true
        found = PlaceIndex.shared.search(query)
    }

    /// Every keystroke: the index at once (precomputed keys), Apple Maps once typing pauses.
    private func runSearch(_ q: String) {
        found = PlaceIndex.shared.search(q)
        appleFailed = false
        apple.update(q)
    }

    /// One line of the result list. Cards are drawn line by line (rounded top on the first line, bottom on the last)
    /// so the list stays lazy when a country lists two hundred regions.
    private struct Item: Identifiable {
        enum Content {
            case note(String)
            case label(String)
            case row(PlaceRow, head: Bool)
            case apple(AppleSearch.Row)
        }
        let id: String
        let content: Content
        var first = false
        var last = false
        var indent = false
    }

    private var results: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(items) { item in itemView(item) }
            }
            .padding(.horizontal, 16).padding(.bottom, 30)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    /// Empty field: one hint line. Then: exact countries / 시도 / 시군구 with everything under them, the other
    /// matches, and Apple Maps for the rest.
    private var items: [Item] {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            return [Item(id: "hint", content: .note(L("도시 · 동네 · 나라 이름으로 찾아보세요")))]
        }
        var out: [Item] = []
        if !indexDone { out.append(Item(id: "loading", content: .note(L("지역 목록을 불러오는 중…")))) }
        for g in found.groups { out += Self.boxed(groupItems(g)) }
        out += Self.boxed(found.rows.map { (r: PlaceRow) -> Item in Item(id: "f:" + r.id, content: .row(r, head: false)) })
        out += appleItems
        if indexDone && found.isEmpty && apple.rows.isEmpty && !apple.busy {
            out.append(Item(id: "none", content: .note(L("찾는 지역이 없어요"))))
        }
        return out
    }

    private func groupItems(_ g: PlaceResults.Group) -> [Item] {
        var lines = [Item(id: "g:" + g.id, content: .row(g.head, head: true))]
        for r in g.children {
            lines.append(Item(id: "g:" + g.id + ":" + r.id, content: .row(r, head: false), indent: true))
        }
        return lines
    }

    private var appleItems: [Item] {
        var out: [Item] = []
        if !apple.rows.isEmpty {
            out.append(Item(id: "apple-label", content: .label(L("다른 곳 (Apple 지도)"))))
            out += Self.boxed(apple.rows.map { (r: AppleSearch.Row) -> Item in Item(id: "a:" + r.id, content: .apple(r)) })
        }
        if appleFailed { out.append(Item(id: "apple-failed", content: .note(L("위치를 찾지 못했어요. 다시 시도해 주세요.")))) }
        return out
    }

    /// Marks the first and the last line of a card.
    private static func boxed(_ lines: [Item]) -> [Item] {
        var c = lines
        guard !c.isEmpty else { return c }
        c[0].first = true
        c[c.count - 1].last = true
        return c
    }

    @ViewBuilder private func itemView(_ item: Item) -> some View {
        switch item.content {
        case .note(let text):
            Text(text).font(.ui(13)).foregroundStyle(UI.sub)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4).padding(.vertical, 12)
        case .label(let text):
            Text(text).font(.ui(12, .bold)).foregroundStyle(UI.sub)
                .padding(.horizontal, 4).padding(.top, 18).padding(.bottom, 2)
        case .row(let r, let head):
            framed(item) { placeRow(r, head: head, indent: item.indent) }
        case .apple(let r):
            framed(item) { appleRow(r) }
        }
    }

    /// A line of a white card: rounded where the card starts / ends, a hairline between lines.
    private func framed<C: View>(_ item: Item, @ViewBuilder _ content: () -> C) -> some View {
        let r: CGFloat = item.first ? 14 : 0, b: CGFloat = item.last ? 14 : 0
        let shape = UnevenRoundedRectangle(topLeadingRadius: r, bottomLeadingRadius: b, bottomTrailingRadius: b, topTrailingRadius: r)
        return content()
            .background(Color.white)
            .clipShape(shape)
            .overlay(alignment: .top) {
                if !item.first { Rectangle().fill(UI.line).frame(height: 1).padding(.leading, 16) }
            }
            .padding(.top, item.first ? 10 : 0)
    }

    private func isAdded(_ r: PlaceRow) -> Bool {
        guard let p = r.place else { return false }
        return model.places.contains { $0.id == p.id }
    }

    private func placeRow(_ r: PlaceRow, head: Bool, indent: Bool) -> some View {
        let added = isAdded(r)
        return Button { tap(r, added: added) } label: { placeLabel(r, head: head, added: added, indent: indent) }
            .buttonStyle(.row)
            .accessibilityIdentifier("result-\(r.id)")
    }

    private func placeLabel(_ r: PlaceRow, head: Bool, added: Bool, indent: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: r.kind == .country ? "globe" : "mappin")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(UI.sub).frame(width: 14)
            VStack(alignment: .leading, spacing: 3) {
                Text(r.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(UI.ink)
                Text(r.subtitle).font(.ui(12)).foregroundStyle(UI.sub)
            }
            Spacer(minLength: 8)
            if Self.minuteRain(r) { minuteChip }
            trailing(r, head: head, added: added)
        }
        .padding(.leading, indent ? 30 : 16).padding(.trailing, 16).padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    /// Countries where Apple has next-hour (minute-by-minute) rain: support.apple.com/105038 — Australia, Ireland,
    /// Japan, the United Kingdom, the United States. Korea has 기상청's six hours instead.
    static let minuteRainCountries: Set<String> = ["AU", "IE", "JP", "GB", "US"]

    private static func minuteRain(_ r: PlaceRow) -> Bool {
        guard let p = r.place else { return false }
        if p.region == "jp" { return true }
        guard p.id.hasPrefix("rg:") else { return false }
        return minuteRainCountries.contains(String(p.id.dropFirst(3).prefix(2)))
    }

    private var minuteChip: some View {
        Text(L("분 단위 비")).font(.ui(11, .bold)).foregroundStyle(Color(hex: "#1F7A3A"))
            .padding(.horizontal, 8).padding(.vertical, 4).background(Color(hex: "#DDF3E3")).clipShape(Capsule())
    }

    private var plusBadge: some View {
        Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundStyle(UI.accent)
            .frame(width: 28, height: 28).background(Color(hex: "#FFF1E6")).clipShape(Circle())
    }

    /// "추가됨", the + to add, or for a country a chevron (tapping lists its regions).
    @ViewBuilder private func trailing(_ r: PlaceRow, head: Bool, added: Bool) -> some View {
        if r.place == nil {
            if !head {
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(UI.faint)
            }
        } else if added {
            Text(L("추가됨")).font(.ui(12, .bold)).foregroundStyle(Color(hex: "#8A93AA"))
        } else {
            plusBadge
        }
    }

    /// A place: add it (free plan: up to the limit, then Plus). A country: search its name, which lists its regions.
    private func tap(_ r: PlaceRow, added: Bool) {
        guard let p = r.place else {
            Haptic.soft()
            query = r.title
            return
        }
        guard !added else { return }
        Haptic.tap()
        if model.canAddPlace { model.add(p); endSearch() } else { showPaywall = true }
    }

    private func appleRow(_ r: AppleSearch.Row) -> some View {
        Button { pick(r) } label: {
            HStack(spacing: 12) {
                Image(systemName: "map").font(.system(size: 14, weight: .semibold)).foregroundStyle(UI.sub).frame(width: 14)
                VStack(alignment: .leading, spacing: 3) {
                    Text(r.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(UI.ink)
                    if !r.subtitle.isEmpty { Text(r.subtitle).font(.ui(12)).foregroundStyle(UI.sub) }
                }
                Spacer(minLength: 8)
                if resolving == r.id { ProgressView().controlSize(.small) } else { plusBadge }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.row)
        .accessibilityIdentifier("apple-result")
    }

    /// An Apple Maps row: look up its coordinate, time zone and country, then add it like any other place.
    private func pick(_ r: AppleSearch.Row) {
        guard resolving == nil else { return }
        Haptic.tap()
        guard model.canAddPlace else { showPaywall = true; return }
        resolving = r.id
        appleFailed = false
        Task {
            let p = await apple.place(for: r)
            resolving = nil
            guard let p else { appleFailed = true; return }
            model.add(p)
            endSearch()
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
