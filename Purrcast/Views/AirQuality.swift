import SwiftUI
import MapKit

/// 대기질 (Plus) on home, between 미세먼지 and 바람: the index (Korea: 통합대기환경지수) or the step (elsewhere), how it
/// compares with yesterday at this hour, and the map of the surroundings coloured by the air. Tap: the sheet.
struct AirHomeCard: View {
    @EnvironmentObject var model: AppModel
    let ink: Ink
    var open: () -> Void

    var body: some View {
        let m = model.airMap, d = m?.detail
        Button(action: { Haptic.soft(); open() }) {
            Card(ink: ink) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L("대기질")).font(.px(13)); Spacer()
                    Text(AirText.sourceLine(m, model: model)).font(.ui(11)).foregroundStyle(ink.sub).lineLimit(1)
                }
                if let d {
                    HStack(alignment: .center, spacing: 8) {
                        if let v = d.value { Text("\(v)").font(.px(26)).rolling("\(v)") }
                        AirGradeChip(grade: d.grade)
                        Spacer(minLength: 8)
                        Text(AirText.compare(d)).font(.ui(12)).foregroundStyle(ink.sub).multilineTextAlignment(.trailing).lineLimit(2)
                    }
                }
                AirMapView(place: model.currentPlace, map: m, height: 190)
                HStack(spacing: 4) {
                    Text(L("눌러서 자세히 보기")).font(.ui(11.5, .semibold))
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(ink.sub).frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .buttonStyle(.press(0.98))
        .accessibilityIdentifier("air-card")
    }
}

/// The step's word on its colour (as the 미세먼지 card's)
struct AirGradeChip: View {
    let grade: Int
    var size: CGFloat = 11
    var body: some View {
        let g = max(0, min(3, grade))
        Text(L(DustScale.words[g])).font(.px(size)).foregroundStyle(Color(hex: DustScale.onColors[g]))
            .padding(.horizontal, size * 0.64).padding(.vertical, size * 0.36).background(Color(hex: DustScale.colors[g]))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

/// The map with the value at the place and, under it, the four steps
struct AirMapView: View {
    let place: Place
    let map: AirMap?
    var height: CGFloat = 220
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                AirFieldMap(place: place, map: map)
                if let me = map?.me { AirHere(me: me) }
                if map == nil { ProgressView().tint(.gray) }
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
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
    }
}

/// The value at the place: Korea's index in a white disc (as Apple's map does), elsewhere the step's word
struct AirHere: View {
    let me: AirMap.Me
    var body: some View {
        VStack(spacing: 3) {
            Group {
                if let v = me.value {
                    Text("\(v)").font(.system(size: 17, weight: .bold)).monospacedDigit()
                        .frame(minWidth: 44, minHeight: 44)
                        .background(Circle().fill(.white))
                        .overlay(Circle().strokeBorder(Color(hex: DustScale.colors[me.grade]), lineWidth: 3))
                } else {
                    Text(L(DustScale.words[me.grade])).font(.system(size: 14, weight: .bold))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(.white))
                        .overlay(Capsule().strokeBorder(Color(hex: DustScale.colors[me.grade]), lineWidth: 3))
                }
            }
            .foregroundStyle(Color(hex: "#1E2A44"))
            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
            Text(L("나의 위치")).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color(hex: "#1E2A44"))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(.white.opacity(0.8)))
        }
        .offset(y: 12)   // the disc's middle on the place, its label under it
    }
}

/// The 대기질 sheet: the step and the index, how it compares with yesterday, the bar, the map, what it means for
/// health, the pollutant behind it and every pollutant.
struct AirQualitySheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let m = model.airMap, d = m?.detail
        VStack(spacing: 0) {
            SheetHeader(title: L("대기질"), trailing: L("닫기")) { dismiss() }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if let d {
                        // the step, the index and the scale it is on
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .center, spacing: 10) {
                                if let v = d.value { Text("\(v)").font(.px(34)) }
                                AirGradeChip(grade: d.grade, size: 14)
                                Spacer()
                            }
                            Text(m?.kind == "pm" ? L("기준: 미세먼지 · 초미세먼지 (WHO)") : L("기준: 통합대기환경지수 (한국)")).font(.ui(12)).foregroundStyle(UI.sub)
                            Text(AirText.summary(d, kind: m?.kind ?? "cai")).font(.ui(15)).foregroundStyle(UI.ink).fixedSize(horizontal: false, vertical: true)
                            AirLevelBar(level: d.level).padding(.top, 2)
                        }
                        .sheetCard()
                    }
                    AirMapView(place: model.currentPlace, map: m, height: 260).sheetCard()
                    if let d {
                        section(L("건강 정보")) { Text(AirText.health(d.grade)).font(.ui(14)).foregroundStyle(UI.ink).fixedSize(horizontal: false, vertical: true) }
                        if let k = d.main {
                            section(L("주요 오염 물질"), sub: AirText.name(k)) {
                                Text(AirText.about(k)).font(.ui(14)).foregroundStyle(UI.ink).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if !d.items.isEmpty {
                            Text(L("오염 물질 세부사항")).font(.px(15)).foregroundStyle(UI.ink).padding(.top, 6)
                            VStack(spacing: 0) {
                                ForEach(Array(d.items.enumerated()), id: \.offset) { i, it in
                                    HStack(spacing: 12) {
                                        Text(AirText.symbol(it.key)).font(.ui(13, .semibold)).foregroundStyle(UI.sub).frame(width: 46, alignment: .leading)
                                        Text(AirText.name(it.key)).font(.ui(14, .semibold)).foregroundStyle(UI.ink)
                                        Spacer()
                                        Text(AirText.amount(it)).font(.ui(14)).monospacedDigit().foregroundStyle(UI.ink)
                                    }
                                    .padding(.vertical, 13)
                                    if i < d.items.count - 1 { Rectangle().fill(UI.line).frame(height: 1) }
                                }
                            }
                            .padding(.horizontal, 16)
                            .background(UI.row, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    Text(AirText.sourceLine(m, model: model)).font(.ui(11)).foregroundStyle(UI.sub).padding(.top, 4)
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
        }
        .background(UI.bg)
        .task { await model.loadAirMap() }
    }

    private func section<C: View>(_ title: String, sub: String? = nil, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.px(15)).foregroundStyle(UI.ink)
            if let sub { Text(sub).font(.ui(12)).foregroundStyle(UI.sub) }
            c().frame(maxWidth: .infinity, alignment: .leading).sheetCard()
        }
        .padding(.top, 6)
    }
}

private extension View {
    func sheetCard() -> some View {
        padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(UI.row, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// The four steps as one bar, a ring where the air is now
struct AirLevelBar: View {
    let level: Double
    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack(alignment: .leading) {
                HStack(spacing: 3) { ForEach(0..<4, id: \.self) { i in Capsule().fill(Color(hex: DustScale.colors[i])) } }.frame(height: 6)
                Circle().fill(.white).overlay(Circle().stroke(Color(hex: "#1E2A44"), lineWidth: 2.5)).frame(width: 15, height: 15)
                    .offset(x: max(0, min(w - 15, w * level / 4 - 7.5)))
            }
            .frame(height: 15)
        }
        .frame(height: 15)
    }
}

/// The words of the 대기질 card and sheet
enum AirText {
    static func name(_ k: String) -> String {
        switch k {
        case "pm10": return L("10㎛ 이하 미세먼지"); case "pm25": return L("2.5㎛ 이하 초미세먼지"); case "o3": return L("오존")
        case "no2": return L("이산화질소"); case "so2": return L("아황산가스"); case "co": return L("일산화탄소")
        default: return k
        }
    }
    static func symbol(_ k: String) -> String {
        ["pm10": "PM10", "pm25": "PM2.5", "o3": "O₃", "no2": "NO₂", "so2": "SO₂", "co": "CO"][k] ?? k.uppercased()
    }
    static func about(_ k: String) -> String {
        switch k {
        case "pm10": return L("지름 10㎛ 이하의 먼지예요. 흙먼지, 공사장, 황사, 꽃가루 같은 데서 많이 생겨요.")
        case "pm25": return L("지름 2.5㎛ 이하의 아주 작은 먼지예요. 자동차·공장 배출가스와 난방에서 많이 생기고, 폐 깊숙이 들어갈 수 있어요.")
        case "o3": return L("햇빛이 강한 날 배출가스가 햇빛과 만나 생겨요. 여름 오후에 높고, 눈과 목이 따가울 수 있어요.")
        case "no2": return L("자동차와 발전소처럼 연료를 태우는 곳에서 나와요. 차가 많은 큰길 근처에서 높아요.")
        case "so2": return L("석탄이나 석유처럼 황이 든 연료를 태울 때 나와요.")
        case "co": return L("연료가 덜 탈 때 나오는 기체예요. 주로 자동차 배출가스에서 나와요.")
        default: return ""
        }
    }
    static func health(_ g: Int) -> String {
        [L("누구나 바깥 활동하기 좋은 공기예요."),
         L("대부분 괜찮아요. 호흡기나 심장 질환이 있다면 오래 밖에 있을 땐 조심하세요."),
         L("어린이, 어르신, 호흡기 질환이 있는 분은 바깥 활동을 줄이세요. 나갈 땐 마스크를 챙기면 좋아요."),
         L("모두 바깥 활동을 줄이세요. 나갈 땐 마스크를 꼭 쓰세요.")][max(0, min(3, g))]
    }
    /// "어제 이맘때보다 나빠요" / "좋아요" / "비슷해요" (a quarter of a step either way counts as the same)
    static func compare(_ d: AirMap.Detail) -> String {
        guard let y = d.yday else { return "" }
        let diff = d.level - y.level
        return abs(diff) < 0.25 ? L("어제 이맘때와 비슷해요") : diff > 0 ? L("어제 이맘때보다 나빠요") : L("어제 이맘때보다 좋아요")
    }
    static func summary(_ d: AirMap.Detail, kind: String) -> String {
        let step = L(DustScale.words[max(0, min(3, d.grade))])
        let now = d.value.map { L("지금 대기질 지수는 %d, %@이에요.", $0, step) } ?? L("지금 대기질은 %@이에요.", step)
        let c = compare(d)
        return c.isEmpty ? now : now + " " + c + "."
    }
    static func amount(_ it: AirMap.Detail.Item) -> String {
        let v = it.value
        let n = v >= 100 || v == v.rounded() ? String(Int(v.rounded())) : String(format: "%.1f", v)
        return n + (it.unit == "㎍/㎥" ? "µg/m³" : it.unit)   // the one-glyph ㎍ / ㎥ read squeezed
    }
    /// "에어코리아 · 철산동 · 18시 기준" / "OpenWeather · 18시 기준"
    @MainActor static func sourceLine(_ m: AirMap?, model: AppModel) -> String {
        let who = m?.kind == "pm" ? "OpenWeather" : L("에어코리아")
        var parts = [who]
        if let st = m?.detail?.station, !st.isEmpty { parts.append(st) }
        if let h = hour(m?.detail?.at.isEmpty == false ? m?.detail?.at : m?.at, kind: m?.kind, tz: model.currentPlace.timeZone) {
            parts.append(L("%@ 기준", HourLabel.word(h, clock12: model.clock12)))
        }
        return parts.joined(separator: " · ")
    }
    private static func hour(_ at: String?, kind: String?, tz: String) -> Int? {
        guard let at, !at.isEmpty else { return nil }
        if kind == "pm" {
            guard let d = ISO8601DateFormatter().date(from: at) else { return nil }
            var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: tz) ?? .current
            return cal.component(.hour, from: d)
        }
        guard let r = at.range(of: #" (\d{2}):"#, options: .regularExpression) else { return nil }
        return Int(at[r].dropFirst().prefix(2)).map { $0 % 24 }
    }
}

/// The map itself: MapKit around the place (looked at, not moved), with the air drawn over it as one image.
struct AirFieldMap: UIViewRepresentable {
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
