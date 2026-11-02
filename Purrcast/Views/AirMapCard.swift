import SwiftUI
import MapKit

/// 대기질 지도 (Plus), under the 미세먼지 chart: Apple's map of the place's surroundings, coloured by the air — the
/// stations' (Korea: 통합대기환경지수) or grid points' (elsewhere: PM2.5 / PM10) steps, filled in between — with the value
/// at the place in the middle, the four steps under it and where the numbers come from.
struct AirMapCard: View {
    @EnvironmentObject var model: AppModel
    let place: Place
    var night = false
    @State private var map: AirMap?
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                PixelIcon(name: "globe", size: 14)
                Text(L("대기질 지도")).font(.px(13))
                Spacer()
                Text(map?.kind == "pm" ? L("미세먼지 · 초미세먼지 기준") : L("통합대기환경지수")).font(.px(10)).opacity(0.7)
            }
            ZStack {
                AirFieldMap(place: place, map: map)
                if let me = map?.me { here(me) }
                if map == nil && !failed { ProgressView().tint(.gray) }
                if failed { Text(L("지금은 지도를 불러오지 못했어요")).font(.ui(12)).foregroundStyle(Color(hex: "#5B6680")) }
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
            legend
            Text(source).font(.ui(10.5)).opacity(0.6)
        }
        .task(id: place.id) {
            failed = false
            do { map = try await model.provider.airMap(for: place) } catch { failed = true }
        }
    }

    /// The value at the place: Korea's index in a white disc (as Apple's map does), elsewhere the step's word
    private func here(_ me: AirMap.Me) -> some View {
        VStack(spacing: 3) {
            Group {
                if let v = me.value {
                    Text("\(v)").font(.system(size: 17, weight: .bold)).monospacedDigit()
                        .frame(minWidth: 44, minHeight: 44)
                        .background(Circle().fill(.white))
                } else {
                    Text(L(DustScale.words[me.grade])).font(.system(size: 14, weight: .bold))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(.white))
                }
            }
            .foregroundStyle(Color(hex: "#1E2A44"))
            .overlay { Group { if me.value != nil { Circle().strokeBorder(Color(hex: DustScale.colors[me.grade]), lineWidth: 3) } else { Capsule().strokeBorder(Color(hex: DustScale.colors[me.grade]), lineWidth: 3) } } }
            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
            Text(L("나의 위치")).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color(hex: "#1E2A44"))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(.white.opacity(0.8)))
        }
        .offset(y: 12)   // the disc's middle on the place, its label under it
    }

    private var legend: some View {
        HStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { i in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: DustScale.colors[i])).frame(width: 10, height: 10)
                    Text(L(DustScale.words[i])).font(.ui(11)).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// "에어코리아 · 18시 기준" / "OpenWeather · 18시 기준"
    private var source: String {
        let who = map?.kind == "pm" ? "OpenWeather" : L("에어코리아")
        guard let at = map?.at, !at.isEmpty else { return who }
        var hour: Int?
        if map?.kind == "pm" {
            let f = ISO8601DateFormatter()
            if let d = f.date(from: at) {
                var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: place.timeZone) ?? .current
                hour = cal.component(.hour, from: d)
            }
        } else if let r = at.range(of: #" (\d{2}):"#, options: .regularExpression) {
            hour = Int(at[r].dropFirst().prefix(2)).map { $0 % 24 }
        }
        guard let h = hour else { return who }
        return "\(who) · " + L("%@ 기준", HourLabel.word(h, clock12: model.clock12))
    }
}

/// The map itself: MapKit around the place (looked at, not moved), with the air drawn over it as one image.
private struct AirFieldMap: UIViewRepresentable {
    let place: Place
    let map: AirMap?
    static let span = MKCoordinateSpan(latitudeDelta: 0.42, longitudeDelta: 0.5)

    func makeUIView(context: Context) -> MKMapView {
        let v = MKMapView()
        v.isUserInteractionEnabled = false   // a picture in the sheet: the sheet's own scroll gets every drag
        v.pointOfInterestFilter = .excludingAll
        v.showsCompass = false
        v.preferredConfiguration = MKStandardMapConfiguration(emphasisStyle: .muted)
        v.delegate = context.coordinator
        v.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: place.lat, longitude: place.lon), span: Self.span), animated: false)
        return v
    }

    func updateUIView(_ v: MKMapView, context: Context) {
        let key = "\(place.id)|\(map?.at ?? "")|\(map?.points.count ?? 0)"
        guard context.coordinator.drawn != key else { return }
        context.coordinator.drawn = key
        v.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: place.lat, longitude: place.lon), span: Self.span), animated: false)
        v.removeOverlays(v.overlays)
        guard let map, !map.points.isEmpty else { return }
        v.addOverlay(AirField(map: map, center: CLLocationCoordinate2D(latitude: place.lat, longitude: place.lon)), level: .aboveRoads)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator: NSObject, MKMapViewDelegate {
        var drawn = ""
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            (overlay as? AirField).map { AirFieldRenderer(overlay: $0) } ?? MKOverlayRenderer(overlay: overlay)
        }
    }
}

/// The air over the box around the place, as an image: every cell the nearby points' levels mixed by distance
/// (closer counts more), coloured by step — each step's own colour, turning into the next only near its edge.
private final class AirField: NSObject, MKOverlay {
    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect
    let image: CGImage?

    init(map: AirMap, center: CLLocationCoordinate2D) {
        coordinate = center
        let dLat = 0.5, dLon = 0.62
        let nw = MKMapPoint(CLLocationCoordinate2D(latitude: center.latitude + dLat, longitude: center.longitude - dLon))
        let se = MKMapPoint(CLLocationCoordinate2D(latitude: center.latitude - dLat, longitude: center.longitude + dLon))
        boundingMapRect = MKMapRect(x: nw.x, y: nw.y, width: se.x - nw.x, height: se.y - nw.y)
        image = Self.render(map, nw: nw, se: se)
    }

    private static func render(_ map: AirMap, nw: MKMapPoint, se: MKMapPoint) -> CGImage? {
        let n = 96
        let pts = map.points.map { (MKMapPoint(CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)), $0.level) }
        let cols = DustScale.colors.map { UIColor(Color(hex: $0)) }.map { c -> (CGFloat, CGFloat, CGFloat) in
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            c.getRed(&r, green: &g, blue: &b, alpha: &a); return (r, g, b)
        }
        var px = [UInt8](repeating: 0, count: n * n * 4)
        let w = se.x - nw.x, h = se.y - nw.y
        let reach = w * 0.35   // farther than this from every point: faded out (no data there)
        for j in 0..<n {
            for i in 0..<n {
                let x = nw.x + (Double(i) + 0.5) / Double(n) * w, y = nw.y + (Double(j) + 0.5) / Double(n) * h
                var sw = 0.0, sv = 0.0, near = Double.infinity
                for (p, lv) in pts {
                    let d2 = (p.x - x) * (p.x - x) + (p.y - y) * (p.y - y)
                    near = min(near, d2)
                    let wt = 1 / max(d2, 1e-6)
                    sw += wt; sv += wt * lv
                }
                let lv = sv / max(sw, 1e-12)
                let k = min(3, Int(lv)), f = lv - Double(k)
                let t = k < 3 ? max(0, min(1, (f - 0.6) / 0.4)) : 0
                let a = cols[k], b = cols[min(3, k + 1)]
                let fade = max(0, min(1, 1.6 - sqrt(near) / reach))
                let o = (j * n + i) * 4
                let alpha = 0.55 * fade
                px[o] = UInt8(((a.0 + (b.0 - a.0) * t) * alpha * 255).rounded())
                px[o + 1] = UInt8(((a.1 + (b.1 - a.1) * t) * alpha * 255).rounded())
                px[o + 2] = UInt8(((a.2 + (b.2 - a.2) * t) * alpha * 255).rounded())
                px[o + 3] = UInt8((alpha * 255).rounded())
            }
        }
        guard let ctx = CGContext(data: &px, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        return ctx.makeImage()
    }
}

private final class AirFieldRenderer: MKOverlayRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let f = overlay as? AirField, let img = f.image else { return }
        let r = rect(for: f.boundingMapRect)
        context.saveGState()
        context.interpolationQuality = .high
        // CGContext draws images bottom-up: flip within the overlay's rect
        context.translateBy(x: r.minX, y: r.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(img, in: CGRect(x: 0, y: 0, width: r.width, height: r.height))
        context.restoreGState()
    }
}
