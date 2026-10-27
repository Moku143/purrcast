"""Candidate C, medium weight on the same 12-px grid: every script follows one rule — vertical strokes 2 px,
horizontal strokes 1 px — so busy syllables (릉 음 습 챙) weigh the same as simple ones (가 고), and Korean, English and
Japanese match (PixelMplus12 Bold already draws Japanese this way).
  · Hangul, Latin, symbols: Galmuri11 Regular (1-px design, room between strokes) with each lit pixel also lighting the one
    to its right — except where the pixel after that belongs to a stroke running up or down (that 1-px gap stays).
    Diagonals (ㅅ ㅈ A) therefore close up instead of splitting.
  · Japanese: PixelMplus12 Bold, as in the bold font.
  · ✓, M, W and ° drawn here; dots in . · … ! ? become 2×2.
    python3 tools/pixelfont/build_medium.py  → tools/pixelfont/out/PurrcastPixel-Medium.ttf
"""
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from build import polygons, raster, draw, PX, SRC_R, SRC_J
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen

HERE = pathlib.Path(__file__).resolve().parent
STATS = {}
OUT = HERE / 'out/PurrcastPixel-Medium.ttf'

def components(lit):
    comp, n = {}, 0
    for p in sorted(lit):
        if p in comp: continue
        stack = [p]; comp[p] = n
        while stack:
            c, r = stack.pop()
            for dc in (-1, 0, 1):
                for dr in (-1, 0, 1):
                    q = (c + dc, r + dr)
                    if q in lit and q not in comp: comp[q] = n; stack.append(q)
        n += 1
    return comp


def medium(lit, last, stats=None):
    """Vertical strokes 2 px, horizontal strokes 1 px.
    1. Each stroke running up or down (2+ pixels), longest first, gets a second column: to its right if that keeps a 1-px
       gap and does not swallow a short tick, else — for a stem with a tick on its right (ㅏ ㅐ) — its part moves one
       pixel right and the stroke grows left, else it grows left, else the parts to its right move over. The cell is one
       pixel wider than the thin design, so that ㅐ ㅔ fit with both stems 2 px. Tried in both orders for strokes of the
       same length (ㄲ beside ㅐ); the version with fewer 1-px strokes left wins. Still stuck and the cell has room:
       the glyph widens at that column (ㅆ's shared leg, ㅐ touching ㅅ in 새). ㅃ beside a vowel shares its middle
       stroke (see share_middle).
    2. Every other pixel (diagonals, the ends of bars) lights the one to its right, unless that closes a 1-px gap to a
       stroke running up or down.
    3. A one-pixel tick left over beside a 2-px stem gets a second row, as in the bold design."""
    best = None
    for src in (lit, share_middle(lit)):
        if src is None: continue
        for order in (1, -1):
            res = _medium(src, last, order)
            if best is None or res[1] < best[1]: best = res
            if best[1] == 0: break
        if best[1] == 0: break
    if stats is not None and best[1]: stats['thin'] = stats.get('thin', 0) + 1
    return best[0]


def share_middle(lit):
    """ㅃ beside a vowel has four strokes in seven pixels — no room for four 2-px strokes. As in the bold design the two
    middle ones become one shared stroke (#.#.#.# → #..#..#), which then grows like the others. None if no such ㅃ."""
    runs = {}
    for c, r in lit:
        if (c, r + 1) in lit: continue
        rows = []; rr = r
        while (c, rr) in lit: rows.append(rr); rr -= 1
        if len(rows) >= 3: runs.setdefault(c, []).append(set(rows))
    for a in sorted(runs):
        for rows in runs[a]:
            sets = [next((s for s in runs.get(a + 2 * i, []) if len(s & rows) >= len(rows) - 1), None) for i in range(4)]
            if any(s is None for s in sets): continue
            out = set(lit)
            span = set.union(*sets)
            for r in span:
                if (a + 1, r) in lit or (a + 5, r) in lit:        # a bar: one bar across both
                    out.update((x, r) for x in range(a, a + 7))
                else:
                    out.discard((a + 2, r)); out.discard((a + 4, r)); out.add((a + 3, r))
            return out
    return None


def _medium(lit, last, order):
    comp = components(lit)
    P = dict(comp)                       # pixel -> part
    G = {}                               # grown pixel -> part
    occ = lambda: set(P) | set(G)

    def stub(x, r, d, O):
        n, xx = 0, x
        while (xx, r) in O: n += 1; xx += d
        return n < 2

    def fits(c, rows, d, O):
        x = c + d
        if x < 0 or x > last: return False
        for r in rows:
            if (x, r) in O:
                if stub(x, r, d, O): return False
            elif (x + d, r) in O: return False
        return True

    def shift(parts):
        O = occ()
        mp = [(p, k) for p, k in P.items() if k in parts]; mg = [(p, k) for p, k in G.items() if k in parts]
        mine = {p for p, _ in mp} | {p for p, _ in mg}
        if not mine or max(c for c, _ in mine) + 1 > last: return None
        others = O - mine
        for c, r in mine:
            for dr in (-1, 0, 1):
                if (c + 1, r + dr) in others or (c + 2, r + dr) in others: return None
        for p, _ in mp: del P[p]
        for p, _ in mg: del G[p]
        for (c, r), k in mp: P[(c + 1, r)] = k
        for (c, r), k in mg: G[(c + 1, r)] = k
        return {p for p, _ in mp}

    def grow(c, rows, part, dirs):
        O = occ()
        for d in dirs:
            if fits(c, rows, d, O):
                for r in rows:
                    if (c + d, r) not in O: G[(c + d, r)] = part
                return True
        return False

    done, thin = set(), 0
    while True:
        runs = []
        for c, r in P:
            if (c, r) in done or (c, r + 1) in P: continue
            rows = []; rr = r
            while (c, rr) in P: rows.append(rr); rr -= 1
            if len(rows) >= 2: runs.append((c, rows))
        if not runs: break
        c, rows = min(runs, key=lambda x: (-len(x[1]), order * x[0], -x[1][0]))
        part = P[(c, rows[0])]
        mins = {}
        for (x, _), k in P.items(): mins[k] = min(mins.get(k, 99), x)
        right = {k for k, m in mins.items() if m > c}
        plan = [(None, 0, (1,))]
        if mins[part] == c: plan.append(({part} | right, 1, (-1, 1)))
        plan.append((None, 0, (-1,)))
        if right: plan.append((right, 0, (1, -1)))
        ok = False
        for block, dc, dirs in plan:
            if block is None:
                if grow(c, rows, part, dirs): ok = True; break
                continue
            saved = (dict(P), dict(G), set(done))
            moved = shift(block)
            if moved is not None:
                done.clear(); done.update((x + 1, y) if (x, y) in moved else (x, y) for x, y in saved[2])
                if grow(c + dc, rows, part, dirs): ok = True; c += dc; break
            P.clear(); P.update(saved[0]); G.clear(); G.update(saved[1]); done.clear(); done.update(saved[2])
        if not ok and max(x for x, _ in occ()) + 1 <= last:
            # still stuck (ㅆ's shared middle leg, ㅐ touching ㅅ in 새): widen the glyph at this column — everything to
            # its right moves one pixel over and the column is doubled, so bars that cross it stay joined
            col = [(y, k) for (x, y), k in list(P.items()) + list(G.items()) if x == c]
            P2 = {((x + 1 if x > c else x), y): k for (x, y), k in P.items()}
            G2 = {((x + 1 if x > c else x), y): k for (x, y), k in G.items()}
            for y, k in col: G2.setdefault((c + 1, y), k)
            moved = {(x, y) for x, y in done if x > c}
            done.difference_update(moved); done.update((x + 1, y) for x, y in moved)
            P.clear(); P.update(P2); G.clear(); G.update(G2); ok = True
        for r in rows: done.add((c, r))
        if not ok and len(rows) >= 3: thin += 1
    # 2. the rest
    O = occ(); vertical = lambda x, y: (x, y) in O and ((x, y + 1) in O or (x, y - 1) in O)
    out = set(O)
    singles = [p for p in P if not ((p[0], p[1] + 1) in P or (p[0], p[1] - 1) in P)]
    for c, r in singles:
        if c + 1 > last or (c + 1, r) in O: continue
        here_joins = (c + 1, r + 1) in O or (c + 1, r - 1) in O
        if vertical(c + 2, r) and not here_joins: continue
        out.add((c + 1, r))
    # 3. ticks
    vert = lambda x, y: (x, y + 1) in out and (x, y - 1) in out
    for x, r in sorted(out):
        right = ((x - 1, r) in out and (x - 2, r) in out and vert(x - 1, r) and vert(x - 2, r) and (x + 1, r) not in out)
        left = ((x + 1, r) in out and (x + 2, r) in out and vert(x + 1, r) and vert(x + 2, r) and (x - 1, r) not in out)
        if not (right or left) or (x, r + 1) in out or (x, r - 1) in out: continue
        nb = x + 1 if right else x - 1
        for y in (r - 1, r + 1):
            if (x, y) not in out and (nb, y) not in out and (x, y + (y - r)) not in out:
                out.add((x, y)); break
    return out, thin

# Drawn here: letters whose strokes the rule cannot fit (rows top to bottom, cap height 11) and the degree sign,
# which would close into a blob.
DRAWN = {
    'M': """
##......##
###....###
###....###
##.#..#.##
##.#..#.##
##..##..##
##..##..##
##......##
##......##
##......##
##......##""",
    'W': """
##......##
##......##
##......##
##......##
##..##..##
##..##..##
##.#..#.##
##.#..#.##
###....###
###....###
##......##""",
    '°': """
.##.
#..#
#..#
.##.
.
.
.
.
.
.
.""",
}
DOTS = set('.,:;·…!?‥・¡¿')   # a lone pixel here becomes a 2×2 dot


def drawn(ch):
    rows = DRAWN[ch].strip('\n').split('\n')
    return {(c, 10 - i) for i, row in enumerate(rows) for c, x in enumerate(row) if x == '#'}


def dots(lit):
    out = set(lit)
    for c, r in lit:
        if any((c + dc, r + dr) in lit for dc in (-1, 0, 1) for dr in (-1, 0, 1) if dc or dr): continue
        out.update({(c + 1, r), (c, r + 1), (c + 1, r + 1)})
    return out


CHECK = """
.......#.
......##.
.....##..
#...##...
##.##....
.###.....
..#......
"""

def main():
    R, J = TTFont(SRC_R), TTFont(SRC_J)
    rgs, jgs = R.getGlyphSet(), J.getGlyphSet()
    rmap, jmap = R.getBestCmap(), J.getBestCmap()
    glyf, hmtx = R['glyf'], R['hmtx']
    done = set()
    jpx = J['head'].unitsPerEm / 12; jyoff = -jpx * 0.4
    for cp, name in sorted(rmap.items()):
        if name in done: continue
        done.add(name)
        is_ja = (0x3000 <= cp <= 0x30FF or 0x3400 <= cp <= 0x9FFF or 0xFF00 <= cp <= 0xFFEF) and cp in jmap
        if is_ja:
            src = jmap[cp]
            lit = {(c, r + 1) for c, r in raster(polygons(jgs, src), jpx, jyoff)}
            glyf[name] = draw(lit) if lit else TTGlyphPen(None).glyph()
            adv = round(jgs[src].width / jpx) * PX
            hmtx[name] = (adv, min((c for c, _ in lit), default=0) * PX)
            continue
        adv = hmtx[name][0]; cells = round(adv / PX)
        lit = raster(polygons(rgs, name))
        if not lit: continue
        ch = chr(cp)
        if ch in DRAWN: new = drawn(ch)
        elif ch in DOTS: new = medium(dots(lit), cells - 1, STATS)
        else: new = medium(lit, cells - 1, STATS)
        glyf[name] = draw(new)
        hmtx[name] = (adv + PX, min(c for c, _ in new) * PX)
        if any(c > cells - 1 for c, _ in new): print("over", name)
    # ✓
    rows = CHECK.strip('\n').split('\n')
    lit = {(c, len(rows) - i) for i, row in enumerate(rows) for c, ch in enumerate(row) if ch == '#'}
    glyf['uni2713'] = draw(lit); hmtx['uni2713'] = (1000, 0)
    order = R.getGlyphOrder()
    if 'uni2713' not in order: order.append('uni2713')
    for t in R['cmap'].tables:
        if t.isUnicode(): t.cmap[0x2713] = 'uni2713'
    for rec in R['name'].names:
        if rec.nameID in (1, 16): rec.string = 'Purrcast Pixel'
        elif rec.nameID in (2, 17): rec.string = 'Medium'
        elif rec.nameID == 4: rec.string = 'Purrcast Pixel Medium'
        elif rec.nameID in (3, 6): rec.string = 'PurrcastPixel-Medium'
    R['name'].setName('Galmuri11: Copyright (c) 2019-2025 Lee Minseo (quiple@quiple.dev), SIL Open Font License 1.1. '
                      'Japanese glyphs: PixelMplus12 (c) 2013 itouhiro, M+ FONTS (c) 2002-2013 M+ FONTS PROJECT, M+ FONT LICENSE. '
                      'Made medium (vertical strokes 2 px) as Purrcast Pixel for Purrcast (2026).', 0, 3, 1, 0x409)
    R['OS/2'].usWeightClass = 500
    OUT.parent.mkdir(exist_ok=True)
    R.save(OUT)
    print(f'{OUT.name}: {len(done)} glyphs, {OUT.stat().st_size // 1024} KB')

if __name__ == '__main__':
    main()
