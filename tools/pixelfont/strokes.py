"""Stroke widening on a pixel grid, shared by the medium (C) and bold (D) candidates.

widen() makes every stroke that runs along one axis 2 px thick, by growing it sideways one pixel where that keeps a 1-px
gap to everything else, else moving its part over, else widening the glyph at that line — inside the room the cell
allows. It works on columns (strokes running up and down); for strokes running across, transpose first.
"""


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


def transpose(pixels):
    return {(r, c) for c, r in pixels}


def widen(lit, first, last, order=1, move_first=True, mask=None, min_run=2, finish=True, prefer=1, thin_min=3,
          keep_overhang=False):
    """lit: set of (c, r). Returns (pixels, thin, origin) — origin maps every output pixel to the input pixel it came
    from. mask: only input pixels in it may form strokes (None: all). finish: also smear the remaining single pixels
    (diagonals, bar ends) one to the right and give left-over 1-px ticks a second row (the column pass of a font).
    prefer: the side a stroke grows to first (+1 toward last, -1 toward first); parts always move toward last."""
    comp = components(lit)
    P = {p: (k, p) for p, k in comp.items()}     # position -> (part, origin), input pixels
    G = {}                                       # position -> (part, origin), grown pixels
    occ = lambda: set(P) | set(G)
    member = (lambda p: True) if mask is None else (lambda p: P[p][1] in mask)

    def stub(x, r, d, O):
        n, xx = 0, x
        while (xx, r) in O: n += 1; xx += d
        return n < 2

    def fits(c, rows, d, O):
        x = c + d
        if x < first or x > last: return False
        # a stem keeps the free ends of bars: never onto a left end, onto a right end only if the left one stays free
        # (ㅍ ㄸ would read as ㅁ); a ring's short side may close up (ㄶ's ㅎ)
        if keep_overhang and len(rows) >= 2:
            for r in (rows[0], rows[-1], rows[0] + 1, rows[-1] - 1):
                if (x, r) not in O or (x + d, r) in O: continue
                if d < 0: return False
                e = x
                while (e - 1, r) in O: e -= 1
                n, y = 1, r + 1
                while (e, y) in O: n += 1; y += 1
                y = r - 1
                while (e, y) in O: n += 1; y -= 1
                if n >= 4: return False
        for r in rows:
            if (x, r) in O:
                # a short tick halfway along (ㅏ) would be swallowed; the end of a bar at either end (ㅍ) is fine
                if stub(x, r, d, O) and r not in (rows[0], rows[-1]): return False
            elif (x + d, r) in O: return False
        return True

    def shift(parts):
        O = occ()
        mp = [(p, v) for p, v in P.items() if v[0] in parts]; mg = [(p, v) for p, v in G.items() if v[0] in parts]
        mine = {p for p, _ in mp} | {p for p, _ in mg}
        if not mine or max(c for c, _ in mine) + 1 > last: return None
        others = O - mine
        for c, r in mine:
            for dr in (-1, 0, 1):
                if (c + 1, r + dr) in others or (c + 2, r + dr) in others: return None
        for p, _ in mp: del P[p]
        for p, _ in mg: del G[p]
        for (c, r), v in mp: P[(c + 1, r)] = v
        for (c, r), v in mg: G[(c + 1, r)] = v
        return {p for p, _ in mp}

    def grow(c, rows, dirs):
        O = occ()
        for d in dirs:
            if fits(c, rows, d, O):
                for r in rows:
                    if (c + d, r) not in O: G[(c + d, r)] = P[(c, r)]
                return True
        return False

    done, thin = set(), 0
    while True:
        runs = []
        for c, r in P:
            if (c, r) in done or not member((c, r)) or ((c, r + 1) in P and member((c, r + 1))): continue
            rows = []; rr = r
            while (c, rr) in P and member((c, rr)): rows.append(rr); rr -= 1
            if len(rows) >= min_run: runs.append((c, rows))
            else: done.update((c, y) for y in rows)
        if not runs: break
        c, rows = min(runs, key=lambda x: (-len(x[1]), order * x[0], -x[1][0]))
        part = P[(c, rows[0])][0]
        mins = {}
        for (x, _), v in P.items(): mins[v[0]] = min(mins.get(v[0], 999), x)
        right = {k for k, m in mins.items() if m > c}
        plan = [(None, 0, (prefer,))]
        if move_first and mins[part] == c: plan.append(({part} | right, 1, (-1, 1)))
        plan.append((None, 0, (-prefer,)))
        if right: plan.append((right, 0, (prefer, -prefer)))
        ok = False
        for block, dc, dirs in plan:
            if block is None:
                if grow(c, rows, dirs): ok = True; break
                continue
            saved = (dict(P), dict(G), set(done))
            moved = shift(block)
            if moved is not None:
                done.clear(); done.update((x + 1, y) if (x, y) in moved else (x, y) for x, y in saved[2])
                if grow(c + dc, rows, dirs): ok = True; c += dc; break
            P.clear(); P.update(saved[0]); G.clear(); G.update(saved[1]); done.clear(); done.update(saved[2])
        if not ok and max(x for x, _ in occ()) + 1 <= last:
            # still stuck: widen the glyph at this line — everything past it moves one pixel over and the line is
            # doubled, so strokes that cross it stay joined
            line = [(y, v) for (x, y), v in list(P.items()) + list(G.items()) if x == c]
            P2 = {((x + 1 if x > c else x), y): v for (x, y), v in P.items()}
            G2 = {((x + 1 if x > c else x), y): v for (x, y), v in G.items()}
            for y, v in line: G2.setdefault((c + 1, y), v)
            moved = {(x, y) for x, y in done if x > c}
            done.difference_update(moved); done.update((x + 1, y) for x, y in moved)
            P.clear(); P.update(P2); G.clear(); G.update(G2); ok = True
        for r in rows: done.add((c, r))
        if not ok and len(rows) >= thin_min: thin += 1
    origin = {p: v[1] for p, v in P.items()}
    origin.update({p: v[1] for p, v in G.items()})
    if not finish:
        return set(origin), thin, origin
    # the rest: each single pixel also lights the one to its right, unless that closes a 1-px gap to an upright stroke
    O = set(origin); vertical = lambda x, y: (x, y) in O and ((x, y + 1) in O or (x, y - 1) in O)
    out = dict(origin)
    singles = [p for p in P if not ((p[0], p[1] + 1) in P or (p[0], p[1] - 1) in P)]
    for c, r in singles:
        if c + 1 > last or (c + 1, r) in O: continue
        here_joins = (c + 1, r + 1) in O or (c + 1, r - 1) in O
        if vertical(c + 2, r) and not here_joins: continue
        out[(c + 1, r)] = origin[(c, r)]
    # ticks left at one pixel beside a 2-px stem get a second row
    vert = lambda x, y: (x, y + 1) in out and (x, y - 1) in out
    for x, r in sorted(out):
        rt = ((x - 1, r) in out and (x - 2, r) in out and vert(x - 1, r) and vert(x - 2, r) and (x + 1, r) not in out)
        lt = ((x + 1, r) in out and (x + 2, r) in out and vert(x + 1, r) and vert(x + 2, r) and (x - 1, r) not in out)
        if not (rt or lt) or (x, r + 1) in out or (x, r - 1) in out: continue
        nb = x + 1 if rt else x - 1
        for y in (r - 1, r + 1):
            if (x, y) not in out and (nb, y) not in out and (x, y + (y - r)) not in out:
                out[(x, y)] = out[(x, r)]; break
    return set(out), thin, out


def best(lit, first, last, variants=None, **kw):
    """Tries both orders for strokes of equal length and both ways of making room for a stem with a tick (move the
    part, or grow in place); the result with the fewest strokes left at 1 px wins (the first one on a tie)."""
    top = None
    for src in (variants or [lit]):
        for move_first in (True, False):
            for order in (1, -1):
                res = widen(src, first, last, order, move_first, **kw)
                if top is None or res[1] < top[1]: top = res
                if top[1] == 0: return top
    return top


def stretch(pixels, rows_wanted, bottom=0):
    """Makes a glyph rows_wanted tall by doubling rows: preferably a row through the hole of a ㅇ (it gets rounder),
    else a row crossed only by upright strokes (stems get longer), else an empty row between parts (more air).
    None if no row qualifies."""
    if not pixels: return pixels
    lo, hi = bottom, max(r for _, r in pixels)
    if hi - lo + 1 >= rows_wanted: return pixels
    rows = {}
    for c, r in pixels: rows.setdefault(r, set()).add(c)

    def hole(r):
        cs = rows.get(r, set())
        if len(cs) < 2: return False
        for c in range(min(cs) + 1, max(cs)):
            if c in cs or (c - 1) not in cs: continue
            if any((c, y) in pixels for y in range(r + 1, hi + 1)) and any((c, y) in pixels for y in range(lo, r)):
                e = c
                while e not in cs and e < max(cs): e += 1
                if e in cs and all((x, r + 1) in pixels or (x, r - 1) in pixels for x in (c - 1, e)): return True
        return False

    def upright(r):
        cs = rows.get(r, set())
        return bool(cs) and all((c, r + 1) in pixels and (c, r - 1) in pixels for c in cs)

    def gap(r):
        return not rows.get(r) and rows.get(r + 1) and rows.get(r - 1)

    mid = (lo + hi) / 2
    for test in (hole, upright, gap):
        cands = [r for r in range(lo + 1, hi) if test(r)]
        if cands:
            r0 = min(cands, key=lambda r: (abs(r - mid), -r))
            out = {(c, r + 1 if r > r0 else r) for c, r in pixels}
            out |= {(c, r0 + 1) for c in rows.get(r0, ())}
            return stretch(out, rows_wanted, bottom)
    return None
