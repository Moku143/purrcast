import SwiftUI

/// The three pixel characters. The cat is free; the others come with Plus.
enum PurrCharacter: String, CaseIterable, Codable, Identifiable {
    case cat, abys, brit
    var id: String { rawValue }
    var defaultName: String {
        switch self { case .cat: return L("고양이"); case .abys: return L("아비시니안"); case .brit: return L("브리티시숏헤어") }
    }
    var isPlus: Bool { self != .cat }
    /// How each one talks by default: 고양이 존댓말 · 브리티시숏헤어 격식 · 아비시니안 반말
    var defaultVoice: Voice { self == .brit ? .formal : self == .abys ? .casual : .polite }
    var faceImage: String { "\(rawValue)-face" }
    func stand(level: Int, rain: RainState) -> String { "\(rawValue)-stand-\(level)-\(rain.spriteKey)" }
    func walk(level: Int, rain: RainState, frame: Int) -> String { "\(rawValue)-walk-\(level)-\(rain.spriteKey)-\(frame % 2 == 0 ? "A" : "B")" }
    func lock(level: Int) -> String { "\(rawValue)-lock-\(level)" }

    /// Where the head top / umbrella top / head centre sit on the 480x560 sprite, per outfit (Resources/Data/anchors.json).
    var anchors: Anchors { Anchors.all[rawValue] ?? Anchors.fallback }
}

struct Anchors: Decodable {
    var head_top: [Int]
    var umb_top: [Int]
    var head_cx: [Double]
    static let fallback = Anchors(head_top: Array(repeating: 140, count: 10), umb_top: Array(repeating: 17, count: 10), head_cx: Array(repeating: 244, count: 10))
    static let all: [String: Anchors] = {
        guard let url = Bundle.main.url(forResource: "anchors", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: Anchors].self, from: data)) ?? [:]
    }()
}

/// Sprite canvas geometry shared by every character.
enum Sprite {
    static let width: CGFloat = 480
    static let height: CGFloat = 560
    static let feetY: CGFloat = 554
}

enum RainState: String, Codable {
    case none, think, bag, umbrella
    /// "think" shows a thought bubble; the character itself stays empty-handed
    var spriteKey: String { self == .umbrella ? "umbrella" : (self == .bag ? "bag" : "none") }
}

enum Mood: String { case normal, happy, cold }
