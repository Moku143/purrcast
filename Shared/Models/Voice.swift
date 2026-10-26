import Foundation

/// How the character talks. The information never changes — only the endings do.
/// 존댓말 (polite, the default) · 격식 (formal, the butler) · 반말 (casual, the lively one).
/// Widgets, the watch and official alert names are words, so they have no voice.
enum Voice: String, CaseIterable, Codable {
    case polite, formal, casual

    var name: String { self == .polite ? "존댓말" : self == .formal ? "격식" : "반말" }
    var sample: String { self == .polite ? "비 예보예요. 우산을 챙겨 주세요." : self == .formal ? "비 예보입니다. 우산을 챙겨 주십시오." : "비 예보야. 우산 챙겨." }

    /// Known polite endings → (formal, casual). Matched on the last word of each sentence or " · " segment.
    private static let words: [String: (String, String)] = [
        "없어요": ("없습니다", "없어"), "있어요": ("있습니다", "있어"), "약해요": ("약합니다", "약해"), "강해요": ("강합니다", "강해"),
        "습해요": ("습합니다", "습해"), "끈적해요": ("끈적합니다", "끈적해"), "눅눅해요": ("눅눅합니다", "눅눅해"), "꿉꿉해요": ("꿉꿉합니다", "꿉꿉해"),
        "건조해요": ("건조합니다", "건조해"), "보송해요": ("보송합니다", "보송해"), "적당해요": ("적당합니다", "적당해"), "필요해요": ("필요합니다", "필요해"),
        "비슷해요": ("비슷합니다", "비슷해"), "낮아요": ("낮습니다", "낮아"), "높아요": ("높습니다", "높아"), "커요": ("큽니다", "커"),
        "추워요": ("춥습니다", "추워"), "더워요": ("덥습니다", "더워"), "어려워요": ("어렵습니다", "어려워"), "고여요": ("고입니다", "고여"),
        "줄여요": ("줄이십시오", "줄여"), "피해요": ("피하십시오", "피해"), "좋아요": ("좋습니다", "좋아"), "괜찮아요": ("괜찮습니다", "괜찮아"),
        "짙어요": ("짙습니다", "짙어"), "챙겨요": ("챙기십시오", "챙겨"), "챙기세요": ("챙기십시오", "챙겨"), "세요": ("셉니다", "세"),
        "보세요": ("보십시오", "봐"), "주세요": ("주십시오", "줘"), "않아요": ("않습니다", "않아"), "내려요": ("내립니다", "내려"),
        "그쳐요": ("그칩니다", "그쳐"), "와요": ("옵니다", "와"), "해요": ("합니다", "해"), "돼요": ("됩니다", "돼"), "여요": ("입니다", "여"),
    ]
    /// Whole phrases that read better than a word swap.
    private static let phrases: [String: (String, String)] = [
        "챙겨 주세요": ("챙겨 주십시오", "챙겨"), "확인해 보세요": ("확인해 보십시오", "확인해 봐"), "우산 챙기세요": ("우산 챙기십시오", "우산 챙겨"),
        "바람 세요": ("바람이 셉니다", "바람 세"), "안개 짙어요": ("안개가 짙습니다", "안개 짙어"), "일교차 커요": ("일교차가 큽니다", "일교차 커"),
    ]

    /// The text in this voice. Polite text in, the same information out.
    func say(_ text: String) -> String {
        guard self != .polite, !text.isEmpty else { return text }
        // sentences end with . or !; tiles and notifications join clauses with " · "
        var out = ""
        var buf = ""
        func flush(_ sep: String) { out += convert(buf) + sep; buf = "" }
        var i = text.startIndex
        while i < text.endIndex {
            let c = text[i]
            if c == "." || c == "!" { flush(String(c)); i = text.index(after: i); continue }
            if text[i...].hasPrefix(" · ") { flush(" · "); i = text.index(i, offsetBy: 3); continue }
            buf.append(c); i = text.index(after: i)
        }
        if !buf.isEmpty { flush("") }
        return out
    }

    private func convert(_ clause: String) -> String {
        let t = clause.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return clause }
        let lead = String(clause.prefix(clause.count - clause.drop(while: { $0 == " " }).count))
        for (p, f) in Self.phrases where t.hasSuffix(p) {
            return lead + String(t.dropLast(p.count)) + (self == .formal ? f.0 : f.1)
        }
        let last = t.split(separator: " ").last.map(String.init) ?? t
        let head = String(t.dropLast(last.count))
        // "예요" / "이에요" after a noun: 입니다 · 야 / 이야
        if last.hasSuffix("이에요") { return lead + head + String(last.dropLast(3)) + (self == .formal ? "입니다" : "이야") }
        if last.hasSuffix("예요") { return lead + head + String(last.dropLast(2)) + (self == .formal ? "입니다" : "야") }
        for (w, f) in Self.words.sorted(by: { $0.key.count > $1.key.count }) where last.hasSuffix(w) {
            return lead + head + String(last.dropLast(w.count)) + (self == .formal ? f.0 : f.1)
        }
        // anything else that ends in 요 (어요 · 아요): drop it for 반말, leave formal as it is
        if self == .casual, last.hasSuffix("요"), last.count > 1 { return lead + head + String(last.dropLast()) }
        return clause
    }
}
