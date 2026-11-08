import SwiftUI
import MapKit
import ImageIO

// MARK: frames → pictures on the map

/// The radar frames drawn onto the map: each frame warped from its own projection onto MapKit's (Mercator) over the
/// whole radar box, in the app's colours, with the rain level of every pixel kept for reading the rain at a place.
@MainActor
final class RadarFrames: ObservableObject {
    /// The box every frame covers (Korea and its seas)
    nonisolated static let north = 39.8, south = 32.4, west = 123.6, east = 132.4
    nonisolated static var box: MKMapRect {
        let nw = MKMapPoint(CLLocationCoordinate2D(latitude: north, longitude: west))
        let se = MKMapPoint(CLLocationCoordinate2D(latitude: south, longitude: east))
        return MKMapRect(x: nw.x, y: nw.y, width: se.x - nw.x, height: se.y - nw.y)
    }
    nonisolated static let width = 440

    @Published private(set) var images: [CGImage?] = []
    @Published private(set) var ready = false
    private(set) var levels: [[UInt8]] = []
    private(set) var map: RadarMap?
    let height: Int

    init() {
        let b = Self.box
        height = Int((Double(Self.width) * b.height / b.width).rounded())
    }

    /// Draws the frames of `m` (the pictures fetched as needed); the same map again does nothing
    func load(_ m: RadarMap) async {
        guard m != map else { return }
        map = m
        let w = Self.width, h = height, box = Self.box
        let frames = m.frames, proj = m.proj, scale = m.scale
        let out = await Task.detached(priority: .userInitiated) { () -> [(CGImage?, [UInt8])] in
            // each frame's source: the example's grid, or the server's picture
            var sources: [RadarSource?] = []
            await withTaskGroup(of: (Int, RadarSource?).self) { g in
                for (i, f) in frames.enumerated() {
                    g.addTask {
                        if let grid = f.grid { return (i, RadarSource(grid: grid)) }
                        guard let s = f.url, let u = URL(string: s), let r = try? await URLSession.shared.data(from: u) else { return (i, nil) }
                        return (i, RadarSource(png: r.0, scale: scale))
                    }
                }
                var got = [RadarSource?](repeating: nil, count: frames.count)
                for await (i, s) in g { got[i] = s }
                sources = got
            }
            // where every map pixel falls in the source (the same for every frame of one size)
            var lookups: [String: [Int32]] = [:]
            return sources.map { src in
                guard let src else { return (nil, []) }
                let key = "\(src.cols)x\(src.rows)"
                let lut = lookups[key] ?? Self.lookup(proj, cols: src.cols, rows: src.rows, w: w, h: h, box: box)
                lookups[key] = lut
                return Self.draw(src, lut: lut, w: w, h: h)
            }
        }.value
        images = out.map(\.0)
        levels = out.map(\.1)
        ready = true
    }

    /// The rain level (0…5) at a place in frame `i`
    func level(at c: CLLocationCoordinate2D, frame i: Int) -> Int {
        guard i >= 0, i < levels.count, !levels[i].isEmpty else { return 0 }
        let b = Self.box, p = MKMapPoint(c)
        let x = Int((p.x - b.minX) / b.width * Double(Self.width)), y = Int((p.y - b.minY) / b.height * Double(height))
        guard x >= 0, y >= 0, x < Self.width, y < height else { return 0 }
        // the strongest within ~2 px: the dot sits on a pixel edge as often as not
        var best = 0
        for dy in -2...2 { for dx in -2...2 {
            let xx = x + dx, yy = y + dy
            guard xx >= 0, yy >= 0, xx < Self.width, yy < height else { continue }
            best = max(best, Int(levels[i][yy * Self.width + xx]))
        } }
        return best
    }


    /// For each map pixel, the source pixel under it (-1: outside the source)
    nonisolated static func lookup(_ proj: RadarMap.Proj, cols: Int, rows: Int, w: Int, h: Int, box: MKMapRect) -> [Int32] {
        var lut = [Int32](repeating: -1, count: w * h)
        for j in 0..<h {
            for i in 0..<w {
                let p = MKMapPoint(x: box.minX + (Double(i) + 0.5) / Double(w) * box.width, y: box.minY + (Double(j) + 0.5) / Double(h) * box.height)
                let c = p.coordinate
                let (u, v) = proj.unit(lat: c.latitude, lon: c.longitude)
                let x = Int(u * Double(cols)), y = Int(v * Double(rows))
                if x >= 0, y >= 0, x < cols, y < rows { lut[j * w + i] = Int32(y * cols + x) }
            }
        }
        return lut
    }

    /// The frame in the app's colours (light rain lighter), and its levels
    nonisolated static func draw(_ s: RadarSource, lut: [Int32], w: Int, h: Int) -> (CGImage?, [UInt8]) {
        let cols: [(UInt8, UInt8, UInt8)] = RadarMap.colors.map { hex in
            let v = Int(hex.dropFirst(), radix: 16) ?? 0
            return (UInt8(v >> 16 & 255), UInt8(v >> 8 & 255), UInt8(v & 255))
        }
        var px = [UInt8](repeating: 0, count: w * h * 4), lv = [UInt8](repeating: 0, count: w * h)
        for i in 0..<(w * h) {
            let k = lut[i]
            guard k >= 0 else { continue }
            let l = Int(s.lv[Int(k)])
            guard l > 0 else { continue }
            lv[i] = UInt8(l)
            let c = cols[min(l, cols.count) - 1], a = l == 1 ? 0.55 : 0.78
            px[i * 4] = UInt8(Double(c.0) * a); px[i * 4 + 1] = UInt8(Double(c.1) * a); px[i * 4 + 2] = UInt8(Double(c.2) * a)
            px[i * 4 + 3] = UInt8(255 * a)
        }
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return (nil, lv) }
        return (ctx.makeImage(), lv)
    }
}


/// One frame's rain levels in its own pixels
struct RadarSource: Sendable {
    let cols: Int, rows: Int
    let lv: [UInt8]

    init(grid g: RadarMap.Grid) {
        cols = g.cols; rows = g.rows
        lv = g.v.map { UInt8(RadarMap.level($0)) }
    }

    /// A picture: each pixel's colour read back to a rain rate through the source's scale (nearest colour; clear
    /// or white pixels are no rain); without a scale every coloured pixel counts as rain
    init?(png: Data, scale: [RadarMap.Step]) {
        guard let src = CGImageSourceCreateWithData(png as CFData, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        let w = img.width, h = img.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        let steps: [(Int, Int, Int, UInt8)] = scale.compactMap { s in
            let hex = s.rgb.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            guard hex.count == 6, let v = Int(hex, radix: 16) else { return nil }
            return (v >> 16 & 255, v >> 8 & 255, v & 255, UInt8(RadarMap.level(s.mm)))
        }
        var out = [UInt8](repeating: 0, count: w * h)
        for i in 0..<(w * h) {
            let a = Int(px[i * 4 + 3])
            guard a > 40 else { continue }
            let r = Int(px[i * 4]) * 255 / a, g = Int(px[i * 4 + 1]) * 255 / a, b = Int(px[i * 4 + 2]) * 255 / a
            if r > 235 && g > 235 && b > 235 { continue }
            if steps.isEmpty { out[i] = 2; continue }
            var best = 0, bestD = Int.max
            for (k, s) in steps.enumerated() {
                let d = (s.0 - r) * (s.0 - r) + (s.1 - g) * (s.1 - g) + (s.2 - b) * (s.2 - b)
                if d < bestD { bestD = d; best = k }
            }
            out[i] = bestD < 60 * 60 * 3 ? steps[best].3 : 0
        }
        cols = w; rows = h; lv = out
    }
}

// MARK: words

@MainActor
enum RadarText {
    /// "16:50" / "오후 4:50" from "2026-11-08 16:50"
    static func time(_ t: String, clock12: Bool) -> String {
        guard t.count >= 16, let h = Int(t.dropFirst(11).prefix(2)), let m = Int(t.dropFirst(14).prefix(2)) else { return t }
        return HourLabel.clock(h * 60 + m, clock12: clock12)
    }
    static func word(_ level: Int) -> String { level <= 0 ? L("비 없음") : L(RadarMap.words[min(level, 5) - 1]) }
    /// The newest observed frame (the last that is not a forecast)
    static func now(_ m: RadarMap) -> Int { m.frames.lastIndex(where: { !$0.fc }) ?? max(0, m.frames.count - 1) }

    /// The card's line: rain here now, else when the forecast frames bring it, else none within the hour
    static func status(_ f: RadarFrames, place: Place, clock12: Bool) -> String {
        guard let m = f.map, f.ready else { return L("비 지도를 불러오는 중이에요") }
        let c = CLLocationCoordinate2D(latitude: place.lat, longitude: place.lon), n = now(m)
        let here = f.level(at: c, frame: n)
        if here > 0 { return L("지금 여기 %@", word(here)) }
        if let k = m.frames.indices.first(where: { $0 > n && f.level(at: c, frame: $0) > 0 }) {
            return L("%@쯤 비구름이 와요", time(m.frames[k].t, clock12: clock12))
        }
        return L("1시간 안에는 비구름이 없어요")
    }
}

// MARK: the map

/// The radar box as one overlay; its picture is the frame shown
final class RadarOverlay: NSObject, MKOverlay {
    let coordinate = CLLocationCoordinate2D(latitude: (RadarFrames.north + RadarFrames.south) / 2, longitude: (RadarFrames.west + RadarFrames.east) / 2)
    let boundingMapRect = RadarFrames.box
    var image: CGImage?
}

final class RadarRenderer: MKOverlayRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let o = overlay as? RadarOverlay, let img = o.image else { return }
        let r = rect(for: o.boundingMapRect)
        context.saveGState()
        context.interpolationQuality = .none          // square radar pixels, as the app's pixel art
        context.translateBy(x: r.minX, y: r.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(img, in: CGRect(x: 0, y: 0, width: r.width, height: r.height))
        context.restoreGState()
    }
}

/// MapKit around the place with the radar frame `index` over it; `interactive`: the sheet's map pans and zooms
struct RadarMapView: UIViewRepresentable {
    let place: Place
    @ObservedObject var frames: RadarFrames
    var index: Int
    var interactive = false
    var span = 1.6

    func makeUIView(context: Context) -> MKMapView {
        let v = MKMapView()
        v.isUserInteractionEnabled = interactive
        v.isRotateEnabled = false; v.isPitchEnabled = false
        v.pointOfInterestFilter = .excludingAll
        v.showsCompass = false
        v.preferredConfiguration = MKStandardMapConfiguration(emphasisStyle: .muted)
        v.delegate = context.coordinator
        let c = CLLocationCoordinate2D(latitude: place.lat, longitude: place.lon)
        v.setRegion(MKCoordinateRegion(center: c, span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span * 1.2)), animated: false)
        if interactive { v.cameraBoundary = MKMapView.CameraBoundary(mapRect: RadarFrames.box) }
        let pin = MKPointAnnotation(); pin.coordinate = c
        v.addAnnotation(pin)
        v.addOverlay(context.coordinator.overlay, level: .aboveRoads)
        return v
    }

    func updateUIView(_ v: MKMapView, context: Context) {
        let co = context.coordinator
        if co.place != place.id {
            co.place = place.id
            let c = CLLocationCoordinate2D(latitude: place.lat, longitude: place.lon)
            v.removeAnnotations(v.annotations)
            let pin = MKPointAnnotation(); pin.coordinate = c
            v.addAnnotation(pin)
            v.setRegion(MKCoordinateRegion(center: c, span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span * 1.2)), animated: false)
        }
        let img = index >= 0 && index < frames.images.count ? frames.images[index] : nil
        if co.overlay.image !== img {
            co.overlay.image = img
            (v.renderer(for: co.overlay) as? RadarRenderer)?.setNeedsDisplay()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator: NSObject, MKMapViewDelegate {
        let overlay = RadarOverlay()
        var place = ""
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            (overlay as? RadarOverlay).map { RadarRenderer(overlay: $0) } ?? MKOverlayRenderer(overlay: overlay)
        }
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let v = mapView.dequeueReusableAnnotationView(withIdentifier: "here") ?? MKAnnotationView(annotation: annotation, reuseIdentifier: "here")
            v.annotation = annotation
            v.image = Self.dot
            return v
        }
        /// The place: a dot in the app's ink with a white ring
        static let dot: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 18, height: 18)).image { _ in
            UIColor.white.setFill(); UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 18, height: 18)).fill()
            UIColor(Color(hex: "#3D6BFF")).setFill(); UIBezierPath(ovalIn: CGRect(x: 3.5, y: 3.5, width: 11, height: 11)).fill()
        }
    }
}

/// The five colours and their words
struct RadarLegend: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<RadarMap.colors.count, id: \.self) { i in
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: RadarMap.colors[i])).frame(width: 10, height: 10)
                    Text(L(RadarMap.words[i])).font(.ui(10.5)).lineLimit(1).minimumScaleFactor(0.7)
                }
            }
        }
        .foregroundStyle(UI.sub)
    }
}

// MARK: home card

/// 비 지도 on home (Korea): the newest radar frame around the place and what it means here. Plus taps open the
/// sheet; free shows the example's rain under a Plus tag and opens the Plus page.
struct RadarHomeCard: View {
    @EnvironmentObject var model: AppModel
    let ink: Ink
    var open: () -> Void
    @StateObject private var frames = RadarFrames()

    var body: some View {
        let m = model.radar, plus = model.plus
        Button(action: { Haptic.soft(); open() }) {
            Card(ink: ink) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L("비 지도")).font(.px(13))
                    if !plus { PlusTag() }
                    Spacer()
                    if let m, plus { Text(L("기상청 레이더 · %@", RadarText.time(m.at, clock12: model.clock12))).font(.ui(11)).foregroundStyle(ink.sub).lineLimit(1) }
                }
                ZStack {
                    RadarMapView(place: model.currentPlace, frames: frames, index: m.map(RadarText.now) ?? 0)
                    if !frames.ready { ProgressView().tint(.gray) }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
                HStack(spacing: 4) {
                    Text(plus ? RadarText.status(frames, place: model.currentPlace, clock12: model.clock12) : L("Plus에서 비구름의 움직임을 볼 수 있어요"))
                        .font(.ui(12.5, .semibold)).foregroundStyle(ink.ink).lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 6)
                    Text(L("눌러서 크게 보기")).font(.ui(11.5, .semibold)).foregroundStyle(ink.sub)
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(ink.sub)
                }
            }
        }
        .buttonStyle(.press(0.98))
        .accessibilityIdentifier("radar-card")
        .task(id: "\(m?.at ?? "")|\(plus)") {
            // free: the example's rain, so the card shows what Plus brings
            let shown = plus ? m : RadarMap.sample(lat: model.currentPlace.lat, lon: model.currentPlace.lon)
            if let shown { await frames.load(shown) }
        }
    }
}

// MARK: sheet

/// 비 지도: the map to pan and zoom, the hour before and the hour ahead under a play button and a slider
struct RadarSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var frames = RadarFrames()
    @State private var index = 0
    @State private var playing = false
    @State private var placed = false

    var body: some View {
        let m = model.radar
        VStack(spacing: 0) {
            SheetHeader(title: L("비 지도"), trailing: L("닫기")) { dismiss() }
            ZStack(alignment: .topLeading) {
                RadarMapView(place: model.currentPlace, frames: frames, index: index, interactive: true, span: 2.4)
                if let m, index < m.frames.count {
                    let f = m.frames[index]
                    Text(RadarText.time(f.t, clock12: model.clock12) + " · " + (f.fc ? L("예측") : L("관측")))
                        .font(.px(12)).foregroundStyle(f.fc ? Color.white : UI.ink)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(f.fc ? Color(hex: "#3D6BFF") : Color.white.opacity(0.92)))
                        .padding(12)
                }
                if !frames.ready || m == nil {
                    Group {
                        if model.radarFailed && m == nil { Text(L("비 지도를 불러오지 못했어요")).font(.ui(13)).foregroundStyle(UI.sub) }
                        else { ProgressView().tint(.gray) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
            controls(m)
        }
        .background(UI.bg)
        .task { await model.loadRadar(force: true) }
        .task(id: m?.at ?? "") {
            guard let m else { return }
            await frames.load(m)
            if !placed { index = RadarText.now(m); placed = true }
        }
        .task(id: playing) {
            // a frame every 0.6 s; after the last a short rest, then from the start again
            while playing, let n = model.radar?.frames.count, n > 1 {
                try? await Task.sleep(nanoseconds: index == n - 1 ? 1_400_000_000 : 600_000_000)
                guard playing else { break }
                index = (index + 1) % n
            }
        }
    }

    @ViewBuilder private func controls(_ m: RadarMap?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button { Haptic.soft(); playing.toggle() } label: {
                    Image(systemName: playing ? "pause.fill" : "play.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 48, height: 48).background(Circle().fill(Color(hex: "#3D6BFF")))
                }
                .buttonStyle(.press(0.92))
                .accessibilityLabel(playing ? L("멈춤") : L("재생"))
                VStack(alignment: .leading, spacing: 3) {
                    if let m, index < m.frames.count {
                        let f = m.frames[index], c = CLLocationCoordinate2D(latitude: model.currentPlace.lat, longitude: model.currentPlace.lon)
                        Text(RadarText.time(f.t, clock12: model.clock12) + (index == RadarText.now(m) ? " · " + L("지금") : ""))
                            .font(.px(15)).foregroundStyle(UI.ink)
                        Text(L("여기: %@", RadarText.word(frames.level(at: c, frame: index)))).font(.ui(12.5)).foregroundStyle(UI.sub)
                    }
                }
                Spacer()
            }
            if let m, m.frames.count > 1 {
                timeline(m)
            }
            RadarLegend()
            Text(L("기상청 레이더 · 초단기 강수예측 (공공누리 제1유형)")).font(.ui(10.5)).foregroundStyle(UI.faint)
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 24)
    }

    /// The frames as dots on a line, the observed ones solid, the forecast hollow; "지금" under the newest observation
    private func timeline(_ m: RadarMap) -> some View {
        let n = m.frames.count, now = RadarText.now(m)
        return VStack(spacing: 6) {
            GeometryReader { g in
                let step = (g.size.width - 16) / CGFloat(max(1, n - 1))
                ZStack(alignment: .leading) {
                    Rectangle().fill(UI.line).frame(height: 2).padding(.horizontal, 8)
                    ForEach(0..<n, id: \.self) { i in
                        Circle()
                            .strokeBorder(m.frames[i].fc ? Color(hex: "#3D6BFF") : UI.ink, lineWidth: 2)
                            .background(Circle().fill(m.frames[i].fc ? Color.white : UI.ink))
                            .frame(width: i == index ? 16 : 8, height: i == index ? 16 : 8)
                            .position(x: 8 + CGFloat(i) * step, y: 12)
                    }
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    playing = false
                    let i = Int(((v.location.x - 8) / step).rounded())
                    let k = max(0, min(n - 1, i))
                    if k != index { index = k; Haptic.select() }
                })
            }
            .frame(height: 24)
            HStack {
                Text(RadarText.time(m.frames[0].t, clock12: model.clock12))
                Spacer()
                Text(L("지금")).foregroundStyle(UI.ink)
                Spacer()
                Text(RadarText.time(m.frames[n - 1].t, clock12: model.clock12))
            }
            .font(.ui(11)).foregroundStyle(UI.sub)
            .accessibilityHidden(true)
            .opacity(now == n - 1 ? 0 : 1)
        }
        .accessibilityElement()
        .accessibilityLabel(L("비 지도 시간"))
        .accessibilityValue(RadarText.time(m.frames[min(index, n - 1)].t, clock12: model.clock12))
        .accessibilityAdjustableAction { d in
            playing = false
            index = d == .increment ? min(n - 1, index + 1) : max(0, index - 1)
        }
    }
}

/// The Plus page's picture: the example's rain over the map around the place (as the card shows it)
struct RadarPaywallArt: View {
    let place: Place
    @StateObject private var frames = RadarFrames()
    var body: some View {
        RadarMapView(place: place, frames: frames, index: 6, span: 1.8)
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .task { await frames.load(RadarMap.sample(lat: place.lat, lon: place.lon)) }
    }
}
