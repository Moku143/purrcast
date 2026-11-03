import Foundation

/// The cards under the forecast on home, in the order the person set (long press a card, then drag it).
/// Ids: next (가까운 비), hourly, daily (10일), tile0… (강수확률 · 자외선 · 일출/일몰 · 습도), dust, air (대기질), wind,
/// cmp (예보 비교), week (이번 주 기록). Tiles take half a row, the rest a whole one.
enum HomeLayout {
    /// The order out of the box (the prototype's)
    static func defaults(tiles: Int) -> [String] {
        let t = (0..<tiles).map { "tile\($0)" }
        return ["next", "hourly", "daily"] + t.prefix(2) + ["dust", "air", "wind", "cmp"] + t.dropFirst(2) + ["week"]
    }

    static func isHalf(_ id: String) -> Bool { id.hasPrefix("tile") }

    /// The cards shown, in the saved order; a card the order has never seen (a new one, or one that was not there when
    /// it was saved) goes in after the card it follows by default
    static func order(saved: [String], present: [String], tiles: Int) -> [String] {
        let defaults = Self.defaults(tiles: tiles).filter { present.contains($0) }
        guard !saved.isEmpty else { return defaults }
        var out = saved.filter { present.contains($0) }
        out = out.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        for (i, id) in defaults.enumerated() where !out.contains(id) {
            if let before = defaults[..<i].reversed().first(where: { out.contains($0) }), let j = out.firstIndex(of: before) {
                out.insert(id, at: j + 1)
            } else { out.insert(id, at: 0) }
        }
        return out
    }

    /// Rows: a whole card alone, tiles two by two in the order they come; a tile with no tile after it keeps its half
    static func rows(_ ids: [String]) -> [[String]] {
        var rows: [[String]] = [], half: String?
        for id in ids {
            if isHalf(id) {
                if let h = half { rows.append([h, id]); half = nil } else { half = id }
            } else {
                if let h = half { rows.append([h]); half = nil }
                rows.append([id])
            }
        }
        if let h = half { rows.append([h]) }
        return rows
    }

    /// `id` moved to where `target` is
    static func move(_ id: String, to target: String, in ids: [String]) -> [String] {
        guard id != target, let from = ids.firstIndex(of: id), let to = ids.firstIndex(of: target) else { return ids }
        var o = ids
        o.remove(at: from)
        o.insert(id, at: to)
        return o
    }
}
