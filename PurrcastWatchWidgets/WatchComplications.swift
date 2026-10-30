import WidgetKit
import SwiftUI

// Watch complications, in colour (watchOS tints them itself when the person picks one colour for the face):
// - 그르릉날씨: the big slot (modular face, Smart Stack), today's range gauge, a corner, one line
// - 기온 · 비 올 확률 · 체감온도 · 일몰 · 일출 · 미세먼지: one per corner of an analog face (icon in the corner, number along the rim),
//   or a circle
// - 고양이: the whole cat in today's outfit, no plate (an analog face's lower sub-dial, or small in a corner)
// Data: what the watch app saved from the phone.

struct WatchEntry: TimelineEntry { let date: Date; let snap: WeatherSnapshot }

struct WatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchEntry { WatchEntry(date: Date(), snap: .sample) }
    func getSnapshot(in context: Context, completion: @escaping (WatchEntry) -> Void) {
        completion(WatchEntry(date: Date(), snap: SharedStore.load() ?? (context.isPreview ? .sample : .waiting)))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchEntry>) -> Void) {
        let e = WatchEntry(date: Date(), snap: SharedStore.load() ?? .waiting)
        completion(Timeline(entries: [e], policy: .after(Date().addingTimeInterval(1800))))
    }
}

/// Free watches show "Plus" in every slot.
private struct PlusGate<Content: View>: View {
    let snap: WeatherSnapshot
    @ViewBuilder var content: Content
    var body: some View {
        if snap.plusActive { content } else { Text("Plus").font(.system(size: 12, weight: .bold)) }
    }
}

/// A pixel picture that keeps its shading on a one-colour face (shades of the tint, not a flat silhouette) where
/// watchOS allows it (11+).
@ViewBuilder private func art(_ name: String, size: CGFloat? = nil, pixel: Bool = true) -> some View {
    let img = Image(name).interpolation(pixel ? .none : .high).resizable()
    if #available(watchOS 11.0, *) {
        img.widgetAccentedRenderingMode(.accentedDesaturated).scaledToFit().frame(width: size, height: size)
    } else {
        img.scaledToFit().frame(width: size, height: size)
    }
}

// MARK: 그르릉날씨 (summary)

struct SummaryComplication: View {
    @Environment(\.widgetFamily) var family
    @Environment(\.showsWidgetContainerBackground) var onPlate     // true in the Smart Stack, false on a face
    let entry: WatchEntry
    var body: some View {
        let snap = entry.snap, f = WatchFacts(snap: snap)
        PlusGate(snap: snap) {
            switch family {
            case .accessoryRectangular: WatchSummary(snap: snap, plate: onPlate)
            case .accessoryCorner:
                art(PixelIcon.asset(f.icon), size: 24)
                    .widgetLabel { Text(f.temp).foregroundStyle(.white) }
            case .accessoryInline: Text(LockText.inline(snap))
            default: WatchTempGauge(snap: snap)
            }
        }
    }
}

struct SummaryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PurrcastWatch", provider: WatchProvider()) { e in
            SummaryComplication(entry: e).containerBackground(for: .widget) { WatchSummaryPlate(snap: e.snap) }
        }
        .configurationDisplayName(Brand.name)
        .description(L("옷차림으로 보는 지금 날씨"))
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

// MARK: one number per corner

enum WatchPiece: String { case temp, rain, feels, sun, dust }

struct PieceComplication: View {
    @Environment(\.widgetFamily) var family
    let piece: WatchPiece
    let entry: WatchEntry
    var body: some View {
        let snap = entry.snap, f = WatchFacts(snap: snap)
        let (icon, text, color): (String, String, Color) = {
            switch piece {
            case .temp: return (f.icon, f.temp, .white)
            case .rain: return (f.rainIcon, "\(f.chance)%", Color(hex: "#8EC5FF"))
            case .feels: return (f.feelsIcon, f.feels, TempColor.of(f.s.feels))
            case .sun: return (f.sun.icon, f.sun.time, Color(hex: "#FFD59A"))
            case .dust:
                guard let d = snap.scene.dust else { return ("pm10", "–", .white) }
                return (DustFacts.icon(d), L(DustScale.words[max(0, min(3, d.grade))]), Color(hex: DustScale.colors[max(0, min(3, d.grade))]))
            }
        }()
        PlusGate(snap: snap) {
            if family == .accessoryCorner {
                art(PixelIcon.asset(icon), size: 24)
                    .widgetLabel { Text(text).foregroundStyle(color) }
            } else {
                switch piece {
                case .temp: WatchTempGauge(snap: snap)
                case .rain: WatchRainRing(snap: snap)
                case .feels: WatchFeelsDisc(snap: snap)
                case .sun: WatchSunDisc(snap: snap)
                case .dust: WatchDustDisc(snap: snap)
                }
            }
        }
    }
}

/// One widget per piece, so each corner can hold a different one (a Widget needs a plain init()).
private func pieceConfiguration(_ piece: WatchPiece) -> some WidgetConfiguration {
    let (name, note): (String, String) = {
        switch piece {
        case .temp: return (L("기온"), L("지금 기온과 날씨"))
        case .rain: return (L("비 올 확률"), L("앞으로 6시간 비 올 확률"))
        case .feels: return (L("체감온도"), L("체감온도를 색으로"))
        case .sun: return (L("일몰 · 일출"), L("다음 일몰이나 일출 시각"))
        case .dust: return (L("미세먼지"), L("미세먼지 · 초미세먼지 등급과 수치"))
        }
    }()
    return StaticConfiguration(kind: "PurrcastWatch-\(piece.rawValue)", provider: WatchProvider()) { e in
        PieceComplication(piece: piece, entry: e).containerBackground(for: .widget) { Color.clear }
    }
    .configurationDisplayName(name)
    .description(note)
    .supportedFamilies([.accessoryCorner, .accessoryCircular])
}

struct TempWidget: Widget { var body: some WidgetConfiguration { pieceConfiguration(.temp) } }
struct RainWidget: Widget { var body: some WidgetConfiguration { pieceConfiguration(.rain) } }
struct FeelsWidget: Widget { var body: some WidgetConfiguration { pieceConfiguration(.feels) } }
struct SunWidget: Widget { var body: some WidgetConfiguration { pieceConfiguration(.sun) } }
struct DustPieceWidget: Widget { var body: some WidgetConfiguration { pieceConfiguration(.dust) } }

// MARK: 고양이

struct CatComplication: View {
    @Environment(\.widgetFamily) var family
    let entry: WatchEntry
    var body: some View {
        let snap = entry.snap, f = WatchFacts(snap: snap)
        PlusGate(snap: snap) {
            // the whole cat in today's outfit everywhere — small in a corner (the temperature along the rim), no plate
            if family == .accessoryCorner {
                art(f.sprite, pixel: false)
                    .widgetLabel { Text(f.temp).foregroundStyle(.white) }
            } else {
                art(f.sprite, pixel: false)
            }
        }
    }
}

struct CatWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PurrcastWatch-cat", provider: WatchProvider()) { e in
            CatComplication(entry: e).containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName(L("고양이"))
        .description(L("고양이와 오늘 날씨"))
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}

@main
struct PurrcastWatchBundle: WidgetBundle {
    var body: some Widget {
        SummaryWidget()
        CatWidget()
        TempWidget()
        RainWidget()
        FeelsWidget()
        SunWidget()
        DustPieceWidget()
    }
}
