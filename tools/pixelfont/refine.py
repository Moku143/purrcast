"""Candidate A2: the bold font (A) as it is, with the strokes it had to leave at 1 px made 2 px wherever the cell
allows — the Hangul box gets one more row (12 rows, same width), so the small ㅇ under ㅏ ㅣ (챙 딩 앙) and over ㅜ (우)
gets a 2-px top and bottom, ㅍ beside ㅐ (패) and the ㅎ of ㄶ (많 않) get 2-px sides.
Upright strokes are only changed if every thin one in the syllable fits; strokes across are only changed in ㅇ (the bold
design's own balance stays elsewhere: 를 들 릉 keep thin bars throughout, the ㄹ drawn as a stair). Every syllable then
gets the extra row: through the hole of a ㅇ, else through plain stems, else between parts.
"""
from strokes import widen, transpose, stretch


def thin_runs(lit):
    """Pixels of upright strokes that are 1 px wide there (something above or below, nothing left or right)."""
    return {(c, r) for c, r in lit if ((c, r + 1) in lit or (c, r - 1) in lit) and (c - 1, r) not in lit and (c + 1, r) not in lit}


def _all_or_nothing(lit, first, last, mask, **kw):
    for move_first in (True, False):
        for order in (1, -1):
            out, t, _ = widen(lit, first, last, order, move_first, mask=mask, finish=False, thin_min=1, **kw)
            if t == 0: return out
    return None


def rings(px):
    """The ㅇ drawn with 1-px top and bottom: (a, b, top row, bottom row, hole rows). A stem may touch it at the top or
    bottom (중 웅), nothing else."""
    found = []
    for s, r in sorted(px, key=lambda p: (-p[1], p[0])):
        if (s - 1, r) in px: continue
        e = s
        while (e + 1, r) in px: e += 1
        if e - s < 2: continue
        a, b = s - 1, e + 1
        span = range(a - 1, b + 2)
        above = {x for x in range(a - 1, b + 2) if (x, r + 1) in px}
        if len(above) > 2 or (above and not above <= set(range(s + 1, e))): continue
        k, rr = 0, r - 1
        while {x for x in span if (x, rr) in px} == {a, a + 1, b - 1, b}: k += 1; rr -= 1
        if k < 2 or {x for x in span if (x, rr) in px} != set(range(s, e + 1)): continue
        below = {x for x in range(a - 1, b + 2) if (x, rr - 1) in px}
        if len(below) > 4 or (below and not below <= set(range(s, e + 1))): continue      # ㅛ has two legs
        found.append((a, b, r, rr, k))
    return found


def bold_rings(px, top=11):
    """Every ㅇ drawn with 1-px top and bottom gets a 2-px top and bottom — all of them or none, so a syllable never
    mixes a bold ㅇ with a thin one. A hole of 3+ rows just shrinks; a hole of 2 needs one more row in the box, so a
    hole row is doubled:  ..#######.. / .#########. / .##.....##. / .#########. / ..#######.."""
    found = rings(px)
    if not found: return px
    if sum(1 for f in found if f[4] == 2) > top - max(y for _, y in px): return px
    px = set(px)
    for a, b, r, bottom, k in sorted(found, key=lambda f: -f[2]):      # top ring first, so rows below keep their place
        if k == 2:
            hole = r - 1
            px = {(x, y + 1 if y > hole else y) for x, y in px} | {(x, hole + 1) for x, y in px if y == hole}
            r += 1
        px |= {(x, r - 1) for x in range(a, b + 1)} | {(x, bottom + 1) for x in range(a, b + 1)}
    return px


def long_thin_bars(px):
    """Bars across of 5+ px that are 1 px tall along most of their length (ㅡ in 릉, the top of ㄷ in 동): a bold ㅇ next
    to them would make the syllable uneven, so it stays as the bold design drew it."""
    for c, r in px:
        if (c - 1, r) in px: continue
        e = c
        while (e + 1, r) in px: e += 1
        if e - c < 4: continue
        alone = sum(1 for x in range(c, e + 1) if (x, r + 1) not in px and (x, r - 1) not in px)
        if alone * 5 >= (e - c + 1) * 4: return True
    return False


def refine(lit, last=11, top=11, keep_overhang=False):
    """lit: an A glyph. Returns (pixels, what changed)."""
    did = ''
    tv = thin_runs(lit)
    if tv:
        out = _all_or_nothing(lit, 0, last, tv, min_run=1, keep_overhang=keep_overhang)
        if out is not None: lit = out; did += 'x'
    ringed = bold_rings(lit, top)
    if ringed != lit and not long_thin_bars(ringed): lit = ringed; did += 'o'
    st = stretch(lit, top + 1, 0)
    if st is not None: lit = st
    else: did += '!'
    return lit, did
