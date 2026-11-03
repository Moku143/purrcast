"""Chinese for the app font: every Hanzi (and CJK punctuation / full-width form) the app font lacks, taken from
BoutiqueBitmap9x9 (src/boutique, free for any use, see its licence) and drawn the way the app font draws its own:
9 x 9 pixels on the 10-px grid, every pixel half a pixel wider to the right (the medium weight of Purrcast Pixel).
The app font's own glyphs (Hangul, Latin, Japanese kanji) are left exactly as they are.

    python3 tools/pixelfont/add_hanzi.py          # rewrites Shared/Fonts/PurrcastPixel-Medium.ttf in place
"""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.recordingPen import DecomposingRecordingPen
import sys

HERE = Path(__file__).parent
APP = HERE.parent.parent / 'Shared/Fonts/PurrcastPixel-Medium.ttf'
SRC = HERE / 'src/boutique/BoutiqueBitmap9x9.ttf'
PX = 100            # both fonts: 1000 units to the em, 10 px
WIDER = 50          # the app font's medium weight: each pixel half a pixel wider to the right
RANGES = [(0x3000, 0x303F), (0x3400, 0x4DBF), (0x4E00, 0x9FFF), (0xF900, 0xFAFF), (0xFE30, 0xFE4F), (0xFF00, 0xFFEF)]


def pixels(gs, name):
    """The glyph's lit pixels as (col, row), row 0 = the row on the baseline (Boutique draws 2 px lower)."""
    pen = DecomposingRecordingPen(gs); gs[name].draw(pen)
    polys, cur = [], []
    for op, pts in pen.value:
        if op == 'moveTo': cur = [pts[0]]
        elif op == 'lineTo': cur.append(pts[0])
        elif op in ('closePath', 'endPath'):
            if cur: polys.append(cur)
            cur = []
        else: raise ValueError(f'curve in {name}')
    lit = set()
    if not polys: return lit
    xs = [round(x / PX) for p in polys for x, _ in p]; ys = [round(y / PX) for p in polys for _, y in p]
    for c in range(min(xs), max(xs)):
        for r in range(min(ys), max(ys)):
            x, y = (c + 0.5) * PX, (r + 0.5) * PX
            # even-odd over all contours (the font's holes are separate contours)
            inside = False
            for p in polys:
                q = [(round(a / PX) * PX, round(b / PX) * PX) for a, b in p]
                for i in range(len(q)):
                    (x1, y1), (x2, y2) = q[i], q[i - 1]
                    if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1): inside = not inside
            if inside: lit.add((c, r + 2))
    return lit


def draw(lit):
    """Each row's runs of pixels as rectangles, the run's end half a pixel further right."""
    pen = TTGlyphPen(None)
    for r in sorted({r for _, r in lit}):
        cols = sorted(c for c, rr in lit if rr == r)
        start = prev = cols[0]
        for c in cols[1:] + [None]:
            if c is not None and c == prev + 1: prev = c; continue
            x0, x1, y0, y1 = start * PX, (prev + 1) * PX + WIDER, r * PX, (r + 1) * PX
            pen.moveTo((x0, y0)); pen.lineTo((x0, y1)); pen.lineTo((x1, y1)); pen.lineTo((x1, y0)); pen.closePath()
            if c is not None: start = prev = c
    return pen.glyph()


def main():
    app, src = TTFont(APP), TTFont(SRC)
    have, sgs, smap = app.getBestCmap(), src.getGlyphSet(), src.getBestCmap()
    glyf, hmtx, order = app['glyf'], app['hmtx'], app.getGlyphOrder()
    added = []
    for cp, sname in sorted(smap.items()):
        if cp in have or not any(a <= cp <= b for a, b in RANGES): continue
        lit = pixels(sgs, sname)
        name = f'uni{cp:04X}' if cp <= 0xFFFF else f'u{cp:05X}'
        glyf[name] = draw(lit) if lit else TTGlyphPen(None).glyph()
        adv = round(src['hmtx'][sname][0] / PX) * PX
        hmtx[name] = (adv, min((c for c, _ in lit), default=0) * PX)
        if name not in order: order.append(name)
        added.append((cp, name))
    app.setGlyphOrder(order); glyf.glyphOrder = order
    for t in app['cmap'].tables:
        if t.isUnicode():
            for cp, name in added:
                if t.format != 4 or cp <= 0xFFFF: t.cmap[cp] = name
    app['maxp'].numGlyphs = len(order)
    note = ('Chinese characters missing from MGalmuri10: BoutiqueBitmap9x9 (c) 2020-2026 Cen-cyun Liu (fancy type foundry), '
            'free for any use, redrawn at the medium weight.')
    rec = app['name'].getName(0, 3, 1, 0x409)
    base = rec.toUnicode() if rec else ''
    if 'BoutiqueBitmap9x9' not in base: app['name'].setName((base + ' ' + note).strip(), 0, 3, 1, 0x409)
    app.save(APP)
    print(f'added {len(added)} glyphs; {APP.stat().st_size // 1024} KB')


if __name__ == '__main__':
    sys.exit(main())
