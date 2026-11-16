import Foundation
import CoreGraphics

/// The cards under the forecast on home, in the order the person set (long press a card, then drag it).
/// Ids: next (가까운 비), hourly, daily (10일), tile0… (강수확률 · 자외선 · 일출/일몰 · 습도), dust, air (대기질), wind,
/// cmp (예보 비교), week (이번 주 기록). Tiles take half a row, two to a row, and are never left alone beside a gap:
/// a tile trades places with another tile, and moves among the whole cards together with the tile beside it.
enum HomeLayout {
    /// The order out of the box (the prototype's)
    static func defaults(tiles: Int) -> [String] {
        let t = (0..<tiles).map { "tile\($0)" }
        return ["next", "hourly", "daily", "radar"] + t.prefix(2) + ["dust", "air", "wind", "cmp"] + t.dropFirst(2) + ["week"]
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
        return paired(out)
    }

    /// Tiles two by two in the order they come, each pair where its first tile is (only the last of an odd number
    /// can be alone)
    static func paired(_ ids: [String]) -> [String] {
        let tiles = ids.filter(isHalf)
        var pairOf: [String: [String]] = [:]
        for i in stride(from: 0, to: tiles.count, by: 2) { pairOf[tiles[i]] = Array(tiles[i..<min(i + 2, tiles.count)]) }
        var out: [String] = []
        for id in ids {
            if !isHalf(id) { out.append(id) } else if let p = pairOf[id] { out += p }
        }
        return out
    }

    /// About how tall each row is (points on a phone-wide card), for sharing rows out among columns
    static func height(_ row: [String], free: Bool) -> CGFloat {
        let ad: CGFloat = free ? 190 : 0       // the ad card under 시간별 and under 10일
        switch row.first ?? "" {
        case "next": return 330
        case "hourly": return 250 + ad
        case "daily": return 500 + ad
        case "dust": return 260
        case "air", "radar": return 400
        case "wind": return 210
        case "cmp": return 330
        case "week": return 250
        default: return 140                    // two tiles side by side
        }
    }

    /// The rows in `count` columns (a big window): each row, in order, goes to the column that is shortest so far,
    /// so the columns end at about the same height and the order still reads left to right, top to bottom
    static func columns(_ rows: [[String]], count: Int, free: Bool) -> [[[String]]] {
        var cols = Array(repeating: [[String]](), count: max(1, count)), h = Array(repeating: CGFloat(0), count: max(1, count))
        for row in rows {
            let c = h.indices.min { h[$0] < h[$1] || (h[$0] == h[$1] && $0 < $1) }!
            cols[c].append(row); h[c] += height(row, free: free) + 16
        }
        return cols
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

    /// `id` dragged over `target`: two tiles trade places; otherwise what moves (a whole card, or a tile with the tile
    /// beside it) goes past what it is over (a whole card, or a pair of tiles) — after it going down, before it going up
    static func move(_ id: String, to target: String, in given: [String]) -> [String] {
        let ids = paired(given)
        guard id != target, let from = ids.firstIndex(of: id), let to = ids.firstIndex(of: target) else { return ids }
        if isHalf(id) && isHalf(target) {
            var o = ids
            o.swapAt(from, to)
            return o
        }
        let pairs = rows(ids)
        func block(_ x: String) -> [String] { isHalf(x) ? (pairs.first { $0.contains(x) } ?? [x]) : [x] }
        let moving = block(id), over = block(target)
        guard moving != over, let head = over.first, let tail = over.last else { return ids }
        var o = ids.filter { !moving.contains($0) }
        guard let first = o.firstIndex(of: head), let last = o.firstIndex(of: tail) else { return ids }
        o.insert(contentsOf: moving, at: from < to ? last + 1 : first)
        return o
    }
}
