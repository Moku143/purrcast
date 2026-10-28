import Combine
import MapKit

/// "다른 곳 (Apple 지도)": Apple Maps suggestions for what the bundled index does not have (cities, neighbourhoods
/// worldwide). Typing is debounced; picking a row looks up its coordinate, time zone and country.
/// When Apple Maps fails the rows just stay empty: the index results work on their own.
@MainActor
final class AppleSearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    struct Row: Identifiable, Hashable {
        let id: String
        let title: String
        let subtitle: String
    }

    @Published private(set) var rows: [Row] = []
    /// From a change of the text until Apple Maps answered (or failed).
    @Published private(set) var busy = false

    static let limit = 8
    private static let pause: UInt64 = 300_000_000   // ns between the last keystroke and the request

    private let completer = MKLocalSearchCompleter()
    private var completions: [String: MKLocalSearchCompletion] = [:]
    private var text = ""
    private var pending: Task<Void, Never>?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    /// The search text changed: ask Apple Maps once typing pauses.
    func update(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q != text else { return }
        text = q
        pending?.cancel()
        guard !q.isEmpty else {
            completer.cancel()
            completer.queryFragment = ""
            rows = []; completions = [:]; busy = false
            return
        }
        busy = true
        pending = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.pause)
            guard !Task.isCancelled else { return }
            self?.ask(q)
        }
    }

    private func ask(_ q: String) {
        guard q == text else { return }
        if completer.queryFragment == q { busy = false; return }   // same words as the last answer: it still stands
        completer.queryFragment = q
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in self.take(self.completer.results) }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.rows = []; self.completions = [:]; self.busy = false
        }
    }

    private func take(_ results: [MKLocalSearchCompletion]) {
        busy = false
        guard !text.isEmpty else { rows = []; completions = [:]; return }
        var list: [Row] = []
        var map: [String: MKLocalSearchCompletion] = [:]
        for c in results where !c.title.isEmpty {
            let id = c.title + "|" + c.subtitle
            guard map[id] == nil else { continue }
            map[id] = c
            list.append(Row(id: id, title: c.title, subtitle: c.subtitle))
            if list.count == Self.limit { break }
        }
        rows = list
        completions = map
    }

    /// The place for a picked row (MKLocalSearch on the completion): coordinate, Apple's time zone, the country's
    /// region. nil when the lookup fails.
    func place(for row: Row) async -> Place? {
        guard let c = completions[row.id] else { return nil }
        let search = MKLocalSearch(request: MKLocalSearch.Request(completion: c))
        guard let response = try? await search.start(), let item = response.mapItems.first else { return nil }
        let mark = item.placemark
        let cc = mark.isoCountryCode ?? ""
        let p = PlaceIndex.shared.mapKitPlace(name: row.title, short: Self.shortName(row.title, korean: cc == "KR"),
                                              lat: mark.coordinate.latitude, lon: mark.coordinate.longitude,
                                              country: cc, timeZone: item.timeZone)
        // Korean addresses come in Hangul: keep that for the server, and read it in katakana in Japanese
        return AppModel.koreanNamed(p, Lang.current)
    }

    /// Widgets get the first part of the title ("Shibuya, Tokyo" → "Shibuya"); a Korean address its last word
    /// ("서울특별시 강남구 역삼동" → "역삼동").
    nonisolated static func shortName(_ title: String, korean: Bool) -> String {
        let first = title.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? title
        guard korean, let last = first.split(separator: " ").last else { return first }
        return String(last)
    }
}
