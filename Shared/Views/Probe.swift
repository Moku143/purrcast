import SwiftUI

/// Where each part of a widget / watch screen lands, for the design canvas's hand-editable copies (the layout kit
/// test). Does nothing unless a test sets `sink`; frames are in the "probe" coordinate space of the rendered view.
enum Probe {
    static var sink: ((String, CGRect) -> Void)? = nil
}

extension View {
    @ViewBuilder func probe(_ name: String) -> some View {
        if let sink = Probe.sink {
            background(GeometryReader { g in
                let _ = sink(name, g.frame(in: .named("probe")))
                Color.clear
            })
        } else {
            self
        }
    }
}
