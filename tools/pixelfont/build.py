"""Builds Shared/Fonts/PurrcastPixel-Bold.ttf, the app's one pixel face for Korean, English and Japanese:
  · Galmuri11 Bold (Lee Minseo, SIL OFL 1.1) — Hangul, Latin, numbers, symbols, as is;
  · PixelMplus12 Bold (itouhiro, after M+ BITMAP FONTS, M+ FONT LICENSE) — kana, kanji and CJK punctuation, which
    Galmuri11 Bold does not have (Japanese headings fell back to the system font). Same 12-px em, so the pixels line up;
  · Galmuri11 Regular, made bold by rule, for the few symbols neither has (− ≤ ≥ 〜 …) — every lit pixel also lights the
    one to its right unless that would close a one-pixel gap;
  · a drawn ✓.
Renamed "Purrcast Pixel" so it is not mistaken for either original; both licences allow modification.
    python3 tools/pixelfont/build.py   (needs fontTools; reads tools/pixelfont/src/Galmuri11.ttf + Galmuri11-Bold.ttf)
"""
import pathlib
from fontTools.ttLib import TTFont
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.ttGlyphPen import TTGlyphPen

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SRC_R, SRC_B = HERE / 'src/Galmuri11.ttf', HERE / 'src/Galmuri11-Bold.ttf'
SRC_J = HERE / 'src/PixelMplus12-Bold.ttf'   # M+ FONT LICENSE (src/LICENSE-MPLUS.txt): a 12-px bold Japanese pixel font
OUT = ROOT / 'Shared/Fonts/PurrcastPixel-Bold.ttf'
PX = 100                      # one pixel in font units (1200 upm, 11 px design + 1 px gap)
Y0, Y1 = -300, 1300           # rows to scan


def polygons(glyphset, name):
    pen = RecordingPen(); glyphset[name].draw(pen)
    polys, cur = [], []
    for op, args in pen.value:
        if op == 'moveTo': cur = [args[0]]
        elif op == 'lineTo': cur.append(args[0])
        elif op in ('closePath', 'endPath'):
            if cur: polys.append(cur)
            cur = []
        else: raise ValueError(f'{name}: curve in a pixel font ({op})')
    return polys


def raster(polys, px=PX, yoff=0.0):
    """Lit pixels {(col, row)} by sampling pixel centres with the nonzero rule (one scanline per row).
    `px` is the pixel size of the source font in its units, `yoff` where its pixel rows start."""
    if not polys: return set()
    edges = [(a, b) for p in polys for a, b in zip(p, p[1:] + p[:1]) if a[1] != b[1]]
    ys = [y for p in polys for _, y in p]
    lit = set()
    for k in range(int((min(ys) - yoff) // px) - 1, int((max(ys) - yoff) // px) + 2):
        cy = yoff + (k + 0.5) * px
        cross = sorted((x1 + (cy - y1) * (x2 - x1) / (y2 - y1), 1 if y2 > y1 else -1)
                       for (x1, y1), (x2, y2) in edges if (y1 <= cy) != (y2 <= cy))
        wind = 0
        for (xa, d), nxt in zip(cross, cross[1:] + [(None, 0)]):
            wind += d
            if wind and nxt[0] is not None:
                for c in range(int(round(xa / px)), int(round(nxt[0] / px))):
                    lit.add((c, k))
    return lit


def embolden(lit, last_col):
    out = set(lit)
    for c, r in lit:
        if c + 1 <= last_col and (c + 1, r) not in lit and (c + 2, r) not in lit:
            out.add((c + 1, r))
    return out


def draw(lit):
    """Pixels → rectangles (row runs, merged downwards), clockwise contours."""
    runs = {}
    for r in sorted({r for _, r in lit}):
        cols = sorted(c for c, rr in lit if rr == r)
        start = prev = None
        for c in cols + [None]:
            if c is not None and prev is not None and c == prev + 1: prev = c; continue
            if start is not None: runs.setdefault(r, []).append((start, prev))
            start = prev = c
    rects, open_ = [], {}
    for r in sorted(runs):
        nxt = {}
        for run in runs[r]:
            if run in open_ and open_[run][3] == r - 1: x0, x1, r0, _ = open_[run]; nxt[run] = (x0, x1, r0, r)
            else: nxt[run] = (run[0], run[1], r, r)
        for run, rect in open_.items():
            if run not in nxt or nxt[run][2] != rect[2]: rects.append(rect)
        open_ = nxt
    rects += open_.values()
    pen = TTGlyphPen(None)
    for x0, x1, r0, r1 in rects:
        X0, X1, Y0_, Y1_ = x0 * PX, (x1 + 1) * PX, r0 * PX, (r1 + 1) * PX
        pen.moveTo((X0, Y0_)); pen.lineTo((X0, Y1_)); pen.lineTo((X1, Y1_)); pen.lineTo((X1, Y0_)); pen.closePath()
    return pen.glyph()


# ✓ in the same weight as the bold Latin (2-px strokes), 10 px wide; rows counted from the baseline
CHECK = """
.......##.
......##..
.....##...
##..##....
.####.....
..##......
"""


def check_glyph():
    rows = [r for r in CHECK.strip('\n').split('\n')]
    lit = {(c, len(rows) - 1 - i + 1) for i, row in enumerate(rows) for c, ch in enumerate(row) if ch == '#'}
    return draw(lit), 1000


# Hangul vowels drawn with two vertical strokes: ㅐ ㅒ ㅔ ㅖ ㅙ ㅞ (medial indices). Galmuri11 Bold draws the inner stroke
# 1 px and the outer one 2 px (…#.##..), so 예 · 애 · 게 looked uneven next to the 2-px consonants. The glyph has two empty
# columns on the right, so: the outer stroke moves one pixel right and the inner stroke becomes 2 px (…##.##.).
TWO_STROKE = {1, 3, 5, 7, 10, 15}
INNER, OUTER = 6, 8          # the columns Galmuri11 Bold uses for them


def even_vowel(lit):
    """The vowel's own rows: the run from the top where the outer stroke (cols 8–9) is lit and col 10 is free."""
    rows = sorted({r for _, r in lit}, reverse=True)
    run, started = [], False
    for r in rows:
        on = (OUTER, r) in lit and (OUTER + 1, r) in lit and (OUTER + 2, r) not in lit
        if on: run.append(r); started = True
        elif started: break
    if len(run) < 4: return None                     # not the expected shape: leave the glyph alone
    out = {p for p in lit if p[1] not in run}
    for r in run:
        row = {c for c, rr in lit if rr == r}
        new = {c for c in row if c < INNER}           # the consonant and the ticks left of the inner stroke
        if INNER in row: new |= {INNER, INNER + 1}    # inner stroke, now 2 px
        if INNER + 1 in row: new |= {INNER + 1, INNER + 2}   # a tick between the strokes (ㅐ ㅒ) still joins them
        new |= {OUTER + 1, OUTER + 2}                 # outer stroke, one pixel right
        out |= {(c, r) for c in new}
    return out


def main():
    R, B, J = TTFont(SRC_R), TTFont(SRC_B), TTFont(SRC_J)
    rmap, bmap, jmap = R.getBestCmap(), B.getBestCmap(), J.getBestCmap()
    rgs, jgs = R.getGlyphSet(), J.getGlyphSet()
    order = B.getGlyphOrder()
    glyf, hmtx = B['glyf'], B['hmtx']

    # 0. even strokes in ㅐ ㅒ ㅔ ㅖ ㅙ ㅞ syllables
    bgs = B.getGlyphSet()
    evened = 0
    for cp in range(0xAC00, 0xD7A4):
        if ((cp - 0xAC00) // 28) % 21 not in TWO_STROKE or cp not in bmap: continue
        name = bmap[cp]
        lit = even_vowel(raster(polygons(bgs, name)))
        if lit is None: continue
        glyf[name] = draw(lit); evened += 1
    print(f'evened the vowel strokes of {evened} Hangul syllables')
    added, src_count = {}, {'PixelMplus12 Bold': 0, 'Galmuri11 Regular (bolded)': 0}
    jpx = J['head'].unitsPerEm / 12            # PixelMplus12: 12 px per em
    jyoff = -jpx * 0.4                         # its pixel rows start 0.4 px under the baseline (… -117, -33, 50 …)

    def put(cp, lit, adv):
        name = f'uni{cp:04X}' if cp <= 0xFFFF else f'u{cp:05X}'
        glyf[name] = draw(lit) if lit else TTGlyphPen(None).glyph()
        hmtx[name] = (adv, min((c for c, _ in lit), default=0) * PX)
        if name not in order: order.append(name)
        added[cp] = name

    # 1. Japanese (kana, kanji, CJK punctuation, full-width forms) from a pixel font drawn bold by hand.
    #    Its rows sit one pixel lower than Galmuri's (descender row −1 ↔ Galmuri row 0), so move them up a row.
    for cp in sorted(set(jmap) - set(bmap)):
        if not (0x3000 <= cp <= 0x30FF or 0x3400 <= cp <= 0x9FFF or 0xFF00 <= cp <= 0xFFEF or 0x31F0 <= cp <= 0x31FF): continue
        src = jmap[cp]
        lit = {(c, r + 1) for c, r in raster(polygons(jgs, src), jpx, jyoff)}
        put(cp, lit, round(jgs[src].width / jpx) * PX)
        src_count['PixelMplus12 Bold'] += 1
    # 2. Anything else Galmuri11 Regular has (symbols such as − ≤ ≥ 〜, the rare kanji PixelMplus lacks): bold it by rule
    for cp in sorted(set(rmap) - set(bmap) - set(added)):
        src = rmap[cp]
        adv = R['hmtx'][src][0]
        lit = raster(polygons(rgs, src))
        wide = adv >= 1000
        put(cp, embolden(lit, adv // PX - 2 if wide else adv // PX - 1), adv if wide else adv + PX)
        src_count['Galmuri11 Regular (bolded)'] += 1
    g, adv = check_glyph()
    glyf['uni2713'] = g; hmtx['uni2713'] = (adv, 0); added[0x2713] = 'uni2713'
    if 'uni2713' not in order: order.append('uni2713')
    order = list(dict.fromkeys(order)); B.setGlyphOrder(order); glyf.glyphOrder = order
    for t in B['cmap'].tables:
        if t.isUnicode():
            for cp, name in added.items():
                if cp <= 0xFFFF or t.format == 12: t.cmap[cp] = name
    # tell the system the font covers Japanese too
    for k in ('ulUnicodeRange1', 'ulUnicodeRange2', 'ulUnicodeRange3', 'ulUnicodeRange4', 'ulCodePageRange1', 'ulCodePageRange2'):
        if hasattr(R['OS/2'], k): setattr(B['OS/2'], k, getattr(B['OS/2'], k) | getattr(R['OS/2'], k))
    if B['post'].formatType == 2.0: B['post'].extraNames = []; B['post'].mapping = {}
    for rec in B['name'].names:
        if rec.nameID == 1: rec.string = 'Purrcast Pixel'
        elif rec.nameID == 2: rec.string = 'Bold'
        elif rec.nameID == 3: rec.string = 'PurrcastPixel-Bold'
        elif rec.nameID == 4: rec.string = 'Purrcast Pixel Bold'
        elif rec.nameID == 6: rec.string = 'PurrcastPixel-Bold'
        elif rec.nameID in (16, 17): rec.string = 'Purrcast Pixel' if rec.nameID == 16 else 'Bold'
        elif rec.nameID == 0 and 'Galmuri' not in str(rec): pass
    B['name'].setName('Galmuri11: Copyright (c) 2019-2025 Lee Minseo (quiple@quiple.dev), SIL Open Font License 1.1. '
                      'Japanese glyphs: PixelMplus12 (c) 2013 itouhiro, M+ FONTS (c) 2002-2013 M+ FONTS PROJECT, M+ FONT LICENSE. '
                      'Combined as Purrcast Pixel for Purrcast (2026).', 0, 3, 1, 0x409)
    B['OS/2'].usWeightClass = 700
    B['head'].macStyle |= 1
    B['OS/2'].fsSelection = (B['OS/2'].fsSelection | 0x20) & ~0x40
    OUT.parent.mkdir(parents=True, exist_ok=True)
    B.save(OUT)
    print(f'{OUT.relative_to(ROOT)}: {len(added)} glyphs added {src_count}, {len(B.getGlyphOrder())} glyphs, {OUT.stat().st_size // 1024} KB')


if __name__ == '__main__':
    main()
