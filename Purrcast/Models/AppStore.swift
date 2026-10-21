import SwiftUI
import Combine

/// App-wide state: the scene on show, plan, character, names, units.
final class AppStore: ObservableObject {
    @Published var sceneKey: String = "clear"
    @Published var plus: Bool = false
    @Published var character: PurrCharacter = .cat
    @Published var names: [PurrCharacter: String] = [:]
    @Published var unitF: Bool = false
    @Published var clock12: Bool = false

    /// Free plan always shows the cat.
    var shownCharacter: PurrCharacter { plus ? character : .cat }
    func name(of c: PurrCharacter) -> String { names[c] ?? c.defaultName }

    var scene: WeatherScene {
        var s = SceneLibrary.scene(sceneKey)
        if !plus && (s.minutes != nil || s.next6 != nil) {
            // free: no minute data, stored forecast only; the bubble says the hour window instead
            s.minutes = nil; s.next6 = nil; s.plus = false; s.updated = "06:00"
            if var b = s.bubble { b.text = hourWindow(s.hours) + " 비!"; s.bubble = b }
        } else if plus { s.plus = true }
        return s
    }

    /// "16~18시" from the hourly rows with rain
    func hourWindow(_ hours: [WeatherScene.HourRow]) -> String {
        let r = hours.enumerated().filter { i, h in i > 0 && (h.mm > 0 || h.icon == "raincloud") }.map { $0.element.label.replacingOccurrences(of: "시", with: "") }
        guard let f = r.first, let l = r.last else { return "" }
        return r.count == 1 ? f + "시쯤" : f + "~" + l + "시"
    }

    init() {
        // launch arguments let UI tests pick a scene / plan / character
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-scene"), i + 1 < args.count { sceneKey = args[i + 1] }
        if args.contains("-plus") { plus = true }
        if let i = args.firstIndex(of: "-char"), i + 1 < args.count, let c = PurrCharacter(rawValue: args[i + 1]) { character = c }
    }
}
