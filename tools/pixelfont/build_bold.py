"""Candidate D: the bold font (A) with its Hangul redrawn so every stroke is 2 px where the cell allows.

A (Galmuri11 Bold) keeps the 11 × 11 Hangul box of the thin design, so in busy syllables something has to give — the
small ㅇ under ㅏ ㅣ (챙 딩 앙), ㅍ beside ㅐ (패), ㄶ (많 않), the ㅇ over ㅜ (우). D gives Hangul a 12-wide, 12-tall box
(cell 13 × 12) and builds each syllable from Galmuri11 Regular by rule:
  1. strokes running up and down → 2 px wide (see strokes.widen; ㅃ beside a vowel shares its middle stroke);
  2. strokes running across → 2 px tall, the same way turned on its side;
  3. every syllable is made 12 rows tall by doubling a row: the hole of a ㅇ (rounder) or a row of plain stems;
  4. a short dash on top that stayed 1 px (ㅊ ㅎ) becomes a 2-px block, as in the bold design.
Syllables with three layers of strokes across (를 좋 들 릉) still cannot fit 2 px everywhere; there the strokes that did
not fit stay 1 px.
Latin, numbers and Japanese stay as in A. Symbols A made from Galmuri11 Regular (− ≤ ≥ ‘ ’ “ ” …) go through 1 and 2.
    python3 tools/pixelfont/build_bold.py  → tools/pixelfont/out/PurrcastPixel-D.ttf
"""
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from build import polygons, raster, draw, PX, SRC_R, SRC_B, ROOT
from build_medium import share_middle
from strokes import best, transpose, stretch, components
from fontTools.ttLib import TTFont

HERE = pathlib.Path(__file__).resolve().parent
BASE = ROOT / 'Shared/Fonts/PurrcastPixel-Bold.ttf'
OUT = HERE / 'out/PurrcastPixel-D.ttf'
TOP = 11          # Hangul rows 0..11


def across(lit):
    """Input pixels that belong to a stroke running across (a horizontal run of 2+)."""
    return {(c, r) for c, r in lit if (c - 1, r) in lit or (c + 1, r) in lit}


def bold(lit, last_col, bottom=0, top=TOP, hangul=True):
    """Returns (pixels, strokes left at 1 px)."""
    sm = share_middle(lit) if hangul else None
    srcs = [lit] + ([sm] if sm else [])
    cols, tx, o1 = best(lit, 0, last_col, srcs)
    h = set().union(*(across(s) for s in srcs))
    mask = {(r, c) for (c, r) in cols if o1[(c, r)] in h}
    rows, ty, _ = best(transpose(cols), bottom, top, mask=mask, finish=False, prefer=-1)
    out = transpose(rows)
    if hangul:
        st = stretch(out, top - bottom + 1, bottom)
        if st is not None: out = st
        out = dash_blocks(out)
    return out, tx + ty


def dash_blocks(px):
    """A lone 1-row dash of 3–6 px (the top of ㅊ ㅎ that found no room for a second row) → a 2-px block at its middle."""
    comp = components(px); parts = {}
    for p, k in comp.items(): parts.setdefault(k, []).append(p)
    out = set(px)
    for ps in parts.values():
        rs = {r for _, r in ps}
        if len(rs) != 1 or not 3 <= len(ps) <= 6: continue
        cs = sorted(c for c, _ in ps); r = rs.pop()
        mid = (cs[0] + cs[-1]) // 2
        out.difference_update(ps); out.update({(mid, r), (mid + 1, r)})
    return out


def is_ja(cp):
    return 0x3000 <= cp <= 0x30FF or 0x3400 <= cp <= 0x9FFF or 0xFF00 <= cp <= 0xFFEF or 0x31F0 <= cp <= 0x31FF


def main():
    F, R, B = TTFont(BASE), TTFont(SRC_R), TTFont(SRC_B)
    fmap, rmap, bmap = F.getBestCmap(), R.getBestCmap(), B.getBestCmap()
    rgs = R.getGlyphSet(); glyf, hmtx = F['glyf'], F['hmtx']
    done, thin, n_h, n_s = set(), 0, 0, 0
    for cp, name in sorted(fmap.items()):
        if name in done or cp not in rmap or cp == 0x2713: continue
        hangul = 0xAC00 <= cp <= 0xD7A3 or 0x3131 <= cp <= 0x318E
        leftover = cp not in bmap and not is_ja(cp)
        if not (hangul or leftover): continue
        done.add(name)
        src = rmap[cp]; cells = round(R['hmtx'][src][0] / PX)
        lit = raster(polygons(rgs, src))
        if not lit: continue
        if hangul:
            px, t = bold(lit, cells - 1)
            n_h += 1; thin += bool(t)
        else:
            px, t = bold(lit, cells - 1, bottom=-2, top=10, hangul=False)
            n_s += 1
        glyf[name] = draw(px)
        hmtx[name] = ((cells + 1) * PX, min(c for c, _ in px) * PX)
    for rec in F['name'].names:
        if rec.nameID in (1, 16): rec.string = 'Purrcast Pixel D'
        elif rec.nameID == 4: rec.string = 'Purrcast Pixel D Bold'
        elif rec.nameID in (3, 6): rec.string = 'PurrcastPixelD-Bold'
    OUT.parent.mkdir(exist_ok=True)
    F.save(OUT)
    print(f'{OUT.name}: {n_h} Hangul ({thin} with a 1-px stroke left), {n_s} symbols, {OUT.stat().st_size // 1024} KB')


if __name__ == '__main__':
    main()
