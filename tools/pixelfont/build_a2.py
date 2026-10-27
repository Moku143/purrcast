"""Candidate A2 → tools/pixelfont/out/PurrcastPixel-A2.ttf (see refine.py). Everything but Hangul stays as in A,
except the symbols A made from Galmuri11 Regular (− ≤ ≥ ‘ ’ “ ” …), which get 2-px strokes both ways where they fit."""
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from build import polygons, raster, draw, PX, SRC_R, SRC_B, ROOT
from build_bold import bold, is_ja
from refine import refine
from fontTools.ttLib import TTFont

HERE = pathlib.Path(__file__).resolve().parent
BASE = HERE / 'out/PurrcastPixel-Bold.ttf'      # run build.py first
OUT = HERE / 'out/PurrcastPixel-A2.ttf'


def main():
    F, R, B = TTFont(BASE), TTFont(SRC_R), TTFont(SRC_B)
    fmap, rmap, bmap = F.getBestCmap(), R.getBestCmap(), B.getBestCmap()
    fgs, rgs = F.getGlyphSet(), R.getGlyphSet()
    glyf, hmtx = F['glyf'], F['hmtx']
    done, stats = set(), {}
    for cp, name in sorted(fmap.items()):
        if name in done: continue
        done.add(name)
        if 0xAC00 <= cp <= 0xD7A3 or 0x3131 <= cp <= 0x318E:
            lit = raster(polygons(fgs, name))
            if not lit: continue
            px, did = refine(lit, keep_overhang=True)     # a bar keeps an end free of stems (else ㅍ, ㄸ look like ㅁ)
            for ch in did: stats[ch] = stats.get(ch, 0) + 1
            glyf[name] = draw(px)
            if max(c for c, _ in px) >= 11:                                     # the few that needed a 12th column
                hmtx[name] = (13 * PX, hmtx[name][1]); stats['wide'] = stats.get('wide', 0) + 1
        elif cp in rmap and cp not in bmap and not is_ja(cp) and cp != 0x2713:
            src = rmap[cp]; cells = round(R['hmtx'][src][0] / PX)
            lit = raster(polygons(rgs, src))
            if not lit: continue
            px, _ = bold(lit, cells - 1, bottom=-2, top=10, hangul=False)
            glyf[name] = draw(px); hmtx[name] = ((cells + 1) * PX, min(c for c, _ in px) * PX)
            stats['sym'] = stats.get('sym', 0) + 1
    for rec in F['name'].names:
        if rec.nameID in (1, 16): rec.string = 'Purrcast Pixel A2'
        elif rec.nameID == 4: rec.string = 'Purrcast Pixel A2 Bold'
        elif rec.nameID in (3, 6): rec.string = 'PurrcastPixelA2-Bold'
    OUT.parent.mkdir(exist_ok=True)
    F.save(OUT)
    print(f'{OUT.name}: {stats}, {OUT.stat().st_size // 1024} KB')


if __name__ == '__main__':
    main()
