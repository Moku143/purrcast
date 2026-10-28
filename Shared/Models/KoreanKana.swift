import Foundation

/// Korean place names written for Japanese readers: Hangul read out in katakana the way Japanese guidebooks do
/// ("서울 구로구 오류동" → "ソウル クロ区 オリュドン"). Apple's geocoder answers Korean addresses in Hangul even when
/// asked for Japanese, and the search index only has romanized names below the 시도, so the app makes its own.
///
/// Reading rules (enough for place names): the sound changes Korean makes between syllables — a final consonant
/// carried over to a following vowel (관악 クァナク), nasal and ㄹ assimilation (종로 チョンノ, 신림 シルリム, 왕십리
/// ワンシムニ) — then ㄱ ㄷ ㅂ ㅈ voiced inside a word after a vowel or ㄴ ㄹ ㅁ ㅇ (대구 テグ, 영등포 ヨンドゥンポ).
/// Administrative words keep their kanji: 구 区 · 시 市 · 군 郡 ("마포구" → "マポ区"); 동 읍 면 are read ("ドン").
enum KoreanKana {
    /// A place name, word by word: "구로구 오류동" → "クロ区 オリュドン". Words without Hangul stay as they are.
    static func place(_ s: String) -> String {
        s.split(separator: " ", omittingEmptySubsequences: true).map { w -> String in
            let word = String(w)
            guard hasHangul(word) else { return word }
            if let p = provinces[word] { return p }                       // 대구 is a city, not "대" + 구
            if word.count > 1, let last = word.last, let suffix = suffixes[last] {
                return read(String(word.dropLast())) + suffix
            }
            return read(word)
        }.joined(separator: " ")
    }

    /// A 시도 as Japanese writes it, from its full or short Korean name ("서울특별시" · "서울" → "ソウル", "경기도" → "京畿道").
    /// nil for names it does not know.
    static func province(_ s: String) -> String? {
        var key = s.trimmingCharacters(in: .whitespaces)
        if let j = provinces[key] { return j }
        for suffix in ["특별자치시", "특별자치도", "특별시", "광역시", "도"] where key.hasSuffix(suffix) && key.count > suffix.count {
            key = String(key.dropLast(suffix.count))
            break
        }
        return provinces[key]
    }

    static func hasHangul(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) }
    }

    /// Hangul read out in katakana; anything else is kept. Digits keep the word going ("역삼1동" → "ヨクサム1ドン").
    static func read(_ s: String) -> String {
        var out = ""
        var run: [(l: Int, v: Int, t: Int)] = []
        var afterDigit = false
        func flush() {
            if !run.isEmpty { out += syllables(run, voicedStart: afterDigit) }
            run = []
        }
        for u in s.unicodeScalars {
            let v = Int(u.value)
            if (0xAC00...0xD7A3).contains(v) {
                let i = v - 0xAC00
                run.append((l: i / 588, v: (i % 588) / 28, t: i % 28))
            } else {
                flush()
                out.unicodeScalars.append(u)
                afterDigit = ("0"..."9").contains(Character(u))
            }
        }
        flush()
        return out
    }

    // MARK: the reading

    /// Initial consonants: ㄱ ㄲ ㄴ ㄷ ㄸ ㄹ ㅁ ㅂ ㅃ ㅅ ㅆ ㅇ ㅈ ㅉ ㅊ ㅋ ㅌ ㅍ ㅎ
    private enum L { static let g = 0, kk = 1, n = 2, d = 3, r = 5, m = 6, b = 7, s = 9, ss = 10, ng = 11, j = 12, ch = 14, k = 15, t = 16, p = 17 }
    /// Final consonants by sound: ㄱ-like, ㄴ, ㄷ-like (ㅅ ㅆ ㅈ ㅊ ㅌ ㅎ), ㄹ, ㅁ, ㅂ-like, ㅇ.
    private static let finalK: Set<Int> = [1, 2, 3, 9, 24]
    private static let finalN: Set<Int> = [4, 5, 6]
    private static let finalT: Set<Int> = [7, 19, 20, 22, 23, 25, 27]
    private static let finalL: Set<Int> = [8, 11, 12, 13, 15]
    private static let finalM: Set<Int> = [10, 16]
    private static let finalP: Set<Int> = [14, 17, 18, 26]
    private static let finalNG = 21
    /// A single final consonant that moves over to a following vowel, as the initial it becomes.
    private static let carried: [Int: Int] = [1: L.g, 2: L.kk, 4: L.n, 7: L.d, 8: L.r, 16: L.m, 17: L.b, 19: L.s, 20: L.ss,
                                              22: L.j, 23: L.ch, 24: L.k, 25: L.t, 26: L.p]

    private static func syllables(_ input: [(l: Int, v: Int, t: Int)], voicedStart: Bool) -> String {
        var syl = input
        var carriedIn = Array(repeating: false, count: syl.count)
        // sound changes at each syllable boundary
        for i in 0..<(syl.count - 1) {
            let t = syl[i].t, next = syl[i + 1]
            if next.l == L.ng, let c = carried[t], !(c == L.n || c == L.m) || !isW(next.v) {
                syl[i].t = 0; syl[i + 1].l = c; carriedIn[i + 1] = true          // 관악 → 과낙
                continue
            }
            switch next.l {
            case L.n, L.m:
                if finalK.contains(t) { syl[i].t = finalNG }                     // 국민 → 궁민
                else if finalP.contains(t) { syl[i].t = 16 }                     // 십만 → 심만
                else if finalT.contains(t) { syl[i].t = 4 }                      // 옛날 → 옌날
                else if finalL.contains(t) && next.l == L.n { syl[i + 1].l = L.r } // 설날 → 설랄
            case L.r:
                if finalN.contains(t) { syl[i].t = 8 }                           // 신라 → 실라
                else if t == finalNG || finalM.contains(t) { syl[i + 1].l = L.n } // 종로 → 종노
                else if finalK.contains(t) { syl[i].t = finalNG; syl[i + 1].l = L.n } // 독립 → 동닙
                else if finalP.contains(t) { syl[i].t = 16; syl[i + 1].l = L.n }  // 십리 → 심니
            default:
                break
            }
        }
        var out = ""
        for (i, s) in syl.enumerated() {
            let voiced: Bool
            if carriedIn[i] { voiced = true }
            else if i == 0 { voiced = voicedStart }
            else {
                let pt = syl[i - 1].t
                voiced = pt == 0 || finalN.contains(pt) || finalL.contains(pt) || finalM.contains(pt) || pt == finalNG
            }
            out += kana(initial: s.l, vowel: s.v, voiced: voiced)
            out += finals[s.t]
        }
        return out
    }

    private static func isW(_ v: Int) -> Bool { [9, 10, 11, 14, 15, 16].contains(v) }

    /// The katakana row of an initial consonant ("" for ㅇ).
    private static func row(_ l: Int, voiced: Bool) -> String {
        switch l {
        case 0: return voiced ? "g" : "k"
        case 1, 15: return "k"
        case 2: return "n"
        case 3: return voiced ? "d" : "t"
        case 4, 16: return "t"
        case 5: return "r"
        case 6: return "m"
        case 7: return voiced ? "b" : "p"
        case 8, 17: return "p"
        case 9, 10: return "s"
        case 12: return voiced ? "j" : "ch"
        case 13, 14: return "ch"
        case 18: return "h"
        default: return ""
        }
    }

    /// Vowels ㅏ ㅐ ㅑ ㅒ ㅓ ㅔ ㅕ ㅖ ㅗ ㅘ ㅙ ㅚ ㅛ ㅜ ㅝ ㅞ ㅟ ㅠ ㅡ ㅢ ㅣ as (glide, a·i·u·e·o).
    private static let vowels: [(glide: Character, base: Int)] = [
        ("-", 0), ("-", 3), ("y", 0), ("y", 3), ("-", 4), ("-", 3), ("y", 4), ("y", 3), ("-", 4), ("w", 0), ("w", 3),
        ("w", 3), ("y", 4), ("-", 2), ("w", 4), ("w", 3), ("w", 1), ("y", 2), ("-", 2), ("i", 1), ("-", 1),
    ]

    private static let plain: [String: [String]] = [
        "": ["ア", "イ", "ウ", "エ", "オ"], "k": ["カ", "キ", "ク", "ケ", "コ"], "g": ["ガ", "ギ", "グ", "ゲ", "ゴ"],
        "s": ["サ", "シ", "ス", "セ", "ソ"], "ch": ["チャ", "チ", "チュ", "チェ", "チョ"], "j": ["ジャ", "ジ", "ジュ", "ジェ", "ジョ"],
        "t": ["タ", "ティ", "トゥ", "テ", "ト"], "d": ["ダ", "ディ", "ドゥ", "デ", "ド"], "n": ["ナ", "ニ", "ヌ", "ネ", "ノ"],
        "h": ["ハ", "ヒ", "フ", "ヘ", "ホ"], "p": ["パ", "ピ", "プ", "ペ", "ポ"], "b": ["バ", "ビ", "ブ", "ベ", "ボ"],
        "m": ["マ", "ミ", "ム", "メ", "モ"], "r": ["ラ", "リ", "ル", "レ", "ロ"],
    ]
    private static let smallY = ["ャ", "", "ュ", "ェ", "ョ"]
    private static let smallW = ["ァ", "ィ", "", "ェ", "ォ"]

    private static func kana(initial l: Int, vowel v: Int, voiced: Bool) -> String {
        let r = row(l, voiced: voiced)
        let (glide, base) = vowels[v]
        let p = plain[r] ?? plain[""]!
        switch glide {
        case "i":                                   // ㅢ: 의 ウィ, 희 ヒ
            return r.isEmpty ? "ウィ" : p[1]
        case "y":
            if r.isEmpty { return ["ヤ", "イ", "ユ", "イェ", "ヨ"][base] }
            if base == 3 || r == "ch" || r == "j" || r == "t" || r == "d" { return p[base] }   // 계 ケ, 져 ジョ
            if r == "s" { return ["シャ", "シ", "シュ", "シェ", "ショ"][base] }
            return base == 1 ? p[1] : p[1] + smallY[base]                       // 경 キョン, 류 リュ
        case "w":
            if r.isEmpty { return ["ワ", "ウィ", "ウ", "ウェ", "ウォ"][base] }
            if r == "h" { return ["ファ", "フィ", "フ", "フェ", "フォ"][base] }
            let u = (r == "t" || r == "d") ? p[4] : p[2]                         // 관 クァン, 퇴 トェ
            return base == 2 ? u : u + smallW[base]
        default:
            return p[base]
        }
    }

    private static let finals: [String] = [
        "", "ク", "ク", "ク", "ン", "ン", "ン", "ッ", "ル", "ク", "ム", "ル", "ル", "ル", "プ", "ル",
        "ム", "プ", "プ", "ッ", "ッ", "ン", "ッ", "ッ", "ク", "ッ", "プ", "",
    ]

    /// 구 区 · 시 市 · 군 郡 at the end of a word.
    private static let suffixes: [Character: String] = ["구": "区", "시": "市", "군": "郡"]

    /// 시도 as the search index writes them in Japanese (places.json), by full and short Korean names — including the
    /// forms `LocationService.shortCity` leaves ("충청북도" → "충청북").
    private static let provinces: [String: String] = [
        "서울": "ソウル", "부산": "釜山", "대구": "大邱", "인천": "仁川", "광주": "光州", "대전": "大田", "울산": "蔚山",
        "세종": "世宗", "경기": "京畿道", "강원": "江原道", "충북": "忠清北道", "충청북": "忠清北道", "충남": "忠清南道",
        "충청남": "忠清南道", "전북": "全羅北道", "전라북": "全羅北道", "전남": "全羅南道", "전라남": "全羅南道",
        "경북": "慶尚北道", "경상북": "慶尚北道", "경남": "慶尚南道", "경상남": "慶尚南道", "제주": "済州道",
        "전남광주": "全南光州", "전남광주통합": "全南光州",
    ]
}
