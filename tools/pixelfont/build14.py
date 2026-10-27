"""Candidate B: one pixel rule for every script — Galmuri14 (Lee Minseo, SIL OFL 1.1: Hangul, Latin, kana, kanji on one
14-px grid) with every vertical stroke made 2 px and every horizontal stroke left at 1 px (a lit pixel also lights the
one to its right unless that would close a one-pixel gap). Nothing is squeezed: 우's ㅇ gets 7 rows instead of 4.
    python3 tools/pixelfont/build14.py  → Shared/Fonts/PurrcastPixel14-Bold.ttf
"""
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from build import polygons, raster, embolden, draw, check_glyph, PX
from fontTools.ttLib import TTFont

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SRC = HERE / 'src/Galmuri14.ttf'
OUT = HERE / 'out/PurrcastPixel14-Bold.ttf'   # a candidate: not in the app until chosen

def main():
    f = TTFont(SRC)
    gs = f.getGlyphSet(); glyf, hmtx = f['glyf'], f['hmtx']
    cmap = f.getBestCmap()
    done = set()
    for cp, name in sorted(cmap.items()):
        if name in done: continue
        done.add(name)
        adv = hmtx[name][0]
        cells = round(adv / PX)
        lit = raster(polygons(gs, name))
        if not lit: continue
        wide = cells >= 12                      # full-width: keep the right margin
        bold = embolden(lit, cells - 2 if wide else cells - 1 + 1)
        glyf[name] = draw(bold)
        new_adv = adv if wide else adv + PX
        hmtx[name] = (new_adv, min(c for c, _ in bold) * PX)
    if 0x2713 not in cmap:
        g, a = check_glyph(); glyf['uni2713'] = g; hmtx['uni2713'] = (a, 0)
        order = f.getGlyphOrder()
        if 'uni2713' not in order: order.append('uni2713')
        for t in f['cmap'].tables:
            if t.isUnicode(): t.cmap[0x2713] = 'uni2713'
    for rec in f['name'].names:
        if rec.nameID in (1, 16): rec.string = 'Purrcast Pixel 14'
        elif rec.nameID in (2, 17): rec.string = 'Bold'
        elif rec.nameID == 4: rec.string = 'Purrcast Pixel 14 Bold'
        elif rec.nameID in (3, 6): rec.string = 'PurrcastPixel14-Bold'
    f['name'].setName('Galmuri14: Copyright (c) 2019-2025 Lee Minseo (quiple@quiple.dev), SIL Open Font License 1.1. '
                      'Made bold (vertical strokes 2 px) as Purrcast Pixel 14 for Purrcast (2026).', 0, 3, 1, 0x409)
    f['OS/2'].usWeightClass = 700
    f.save(OUT)
    print(f'{OUT.name}: {len(done)} glyphs, {OUT.stat().st_size // 1024} KB')

if __name__ == '__main__':
    main()
