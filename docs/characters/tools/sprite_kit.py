"""Sprite kit: find the 15 figures on a generated sheet, measure them, flag the odd ones, and rebuild them at one
fixed scale so every stage of every sheet has the same head size, eye line and feet line.

Why: an image model drawing 15 figures on one sheet never keeps them the same size (one row comes out ~10% smaller,
eyes drift). Instead of asking it again and again, every figure is measured on its muzzle (the one part no hat,
hood or scarf ever covers) and rescaled so all muzzles are the same width, feet on one line, body centred.

Measures (mw = muzzle width of that figure):
  eyes   centre x from the muzzle centre, centre y above the muzzle top, length       -> standard +/-0.66, 0.12, 0.30
  body   feet line below the muzzle top                                                 -> same on all 15 (+/-6%)

Commands
  python3 sprite_kit.py check  SHEET [--lock]                       table + flags + SHEET-check.png with guide lines
  python3 sprite_kit.py build  SHEET OUTDIR NAME KIND [--lock] [--mw 100]
        writes OUTDIR/NAME-stand-{0..14}-KIND.png (or NAME-lock-{0..14}.png with --lock), 480x560 RGBA,
        feet on y=555, body centred on x=240, every muzzle exactly --mw px wide; plus OUTDIR/NAME-KIND-sheet.png
  python3 sprite_kit.py fit    SHEET... [--lock-last]                biggest --mw that keeps every figure of every
                                                                      sheet inside 480x560 (use one value for all)
  python3 sprite_kit.py compose OUT SHEET:0-9 SHEET2:10,11 ... [--lock]
        one clean sheet from the stages that passed on different generations (stages 0-based); check/build it after.
        Regenerating only the failed cells shakes the others by ~7%, so keep each stage from the take that got it right.
Needs numpy, scipy, Pillow. Sheets: 15 figures in 3 rows of 5, plain light background (or navy with --lock).
"""
import sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

CANVAS = (480, 560)
FEET_Y = 555
STD = dict(eye_dx=0.66, eye_dy=0.12, eye_len=0.30)


# ---------- finding figures ----------------------------------------------------------------------------------------

def _hsv(a):
    a = a.astype(float) / 255
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx, mn = a.max(-1), a.min(-1)
    d = mx - mn + 1e-9
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6
    s = np.where(mx > 0, d / (mx + 1e-9), 0)
    return h, s, mx


def _figure_mask(arr, lock):
    a = arr.astype(int)
    if lock:
        m = a.sum(-1) > 330
    else:
        # background = the commonest light colour of the sheet
        flat = a.reshape(-1, 3)
        light = flat[flat.sum(1) > 600]
        bg = np.median(light, axis=0)
        m = np.abs(a - bg).sum(-1) > 40
    m = ndimage.binary_closing(m, iterations=2)
    return m


def figures(path, lock=False):
    im = Image.open(path).convert('RGB')
    arr = np.asarray(im)
    m = _figure_mask(arr, lock)
    lab, n = ndimage.label(m)
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    H, W = m.shape
    blobs = []
    for idx in np.argsort(sizes)[::-1]:
        sl = ndimage.find_objects((lab == idx + 1).astype(np.int8))[0]
        y0, y1, x0, x1 = sl[0].start, sl[0].stop, sl[1].start, sl[1].stop
        # skip frames / lines along the edges of a screen capture
        if (x1 - x0) > 0.5 * W or (y1 - y0) > 0.6 * H or (x1 - x0) < 0.04 * W or (y1 - y0) < 0.08 * H:
            continue
        blobs.append((y0, y1, x0, x1, idx + 1))
        if len(blobs) == 15:
            break
    if len(blobs) != 15:
        raise SystemExit(f'{path}: found {len(blobs)} figures, expected 15')
    blobs.sort(key=lambda b: (b[0] + b[1]) / 2)
    out = []
    for r in range(3):
        row = sorted(blobs[r * 5:(r + 1) * 5], key=lambda b: (b[2] + b[3]) / 2)
        for y0, y1, x0, x1, li in row:
            mask = ndimage.binary_fill_holes(lab[y0:y1, x0:x1] == li)
            out.append(dict(box=(x0, y0, x1, y1), mask=mask, img=im.crop((x0, y0, x1, y1))))
    return out


# ---------- measuring ----------------------------------------------------------------------------------------------

def measure(f, lock=False, ref_col=None):
    a = np.asarray(f['img']).astype(int)
    m = f['mask']
    H, W = m.shape
    inner = ndimage.binary_erosion(m, iterations=3)
    dark = (a.sum(-1) < (260 if lock else 240)) & inner
    lab, n = ndimage.label(dark)
    blobs = []
    for k in range(1, n + 1):
        ys, xs = np.nonzero(lab == k)
        w, h = xs.max() - xs.min() + 1, ys.max() - ys.min() + 1
        blobs.append(dict(x=(xs.min() + xs.max()) / 2, y=(ys.min() + ys.max()) / 2, w=w, h=h, n=len(ys),
                          x0=xs.min(), x1=xs.max(), y0=ys.min(), y1=ys.max()))
    # nostrils: a pair of small round dots on one row, inside a muzzle-shaped patch of one colour
    dots = [b for b in blobs if 0.6 <= b['w'] / max(1, b['h']) <= 1.7 and b['n'] >= 4 and b['y'] < 0.75 * H
            and b['w'] < 0.12 * W]
    pairs = []
    for i in range(len(dots)):
        for j in range(i + 1, len(dots)):
            p, q = dots[i], dots[j]
            if abs(p['y'] - q['y']) > max(2, 0.4 * p['h']) or abs(p['n'] - q['n']) > 0.6 * max(p['n'], q['n']):
                continue
            sep = abs(p['x'] - q['x'])
            if 0.06 * W < sep < 0.4 * W:
                pairs.append((p, q))
    pairs.sort(key=lambda pq: pq[0]['y'])  # highest first: the muzzle sits above any print on the clothes
    found = []
    for p, q in pairs:
        nx, ny = (p['x'] + q['x']) / 2, (p['y'] + q['y']) / 2
        seed = (min(int(round(ny + max(p['h'], q['h']) * 1.5)), H - 1), int(round(nx)))
        col = a[seed]
        same = (np.abs(a - col).sum(-1) < 45) & m
        # the muzzle sits within a few nostril gaps of the nostrils; never let the fill leak into fur or clothes
        sep = abs(p['x'] - q['x'])
        box = np.zeros_like(same)
        box[max(0, int(ny - 1.6 * sep)):int(ny + 2.2 * sep), max(0, int(nx - 2.2 * sep)):int(nx + 2.2 * sep)] = True
        same &= box
        lab2, _ = ndimage.label(same)
        if not lab2[seed]:
            continue
        mz = ndimage.binary_fill_holes(lab2 == lab2[seed])
        ys, xs = np.nonzero(mz)
        mw_ = xs.max() - xs.min() + 1
        mh_ = ys.max() - ys.min() + 1
        # a capybara muzzle: nostrils ~40% of its width apart, about 0.5-0.95 as tall as wide
        if mz.sum() >= 20 and 0.25 <= sep / mw_ <= 0.65 and 0.45 <= mh_ / mw_ <= 0.95:
            found.append((p, q, mz, np.median(a[mz], axis=0)))
    if not found:
        return None
    if ref_col is not None:
        found.sort(key=lambda c: np.abs(c[3] - ref_col).sum())
    p, q, mz, mcol = found[0]
    ys, xs = np.nonzero(mz)
    mx0, mx1, my0, my1 = xs.min(), xs.max(), ys.min(), ys.max()
    mw = mx1 - mx0 + 1
    mc = (mx0 + mx1) / 2
    # eyes: thin horizontal dark lines above the muzzle, one each side
    eyes = []
    for b in blobs:
        if (b['w'] >= 2.0 * b['h'] and my0 - 0.5 * mw < b['y'] < my0 + 2 and 0.12 * mw < b['w'] < 0.6 * mw
                and 0.3 * mw < abs(b['x'] - mc) < 1.0 * mw):
            eyes.append(b)
    left = [e for e in eyes if e['x'] < mc]
    right = [e for e in eyes if e['x'] > mc]
    pick = lambda es: max(es, key=lambda e: e['y']) if es else None  # noqa: E731  (lowest = nearest the muzzle)
    el, er = pick(left), pick(right)
    feet = np.nonzero(m.any(1))[0].max()
    low = np.nonzero(m[max(0, feet - int(0.12 * H)):feet + 1])
    cx = np.median(low[1]) if len(low[1]) else W / 2
    r = dict(mw=mw, mc=mc, mtop=my0, mbot=my1, feet=feet, cx=cx, col=mcol, ncand=len(found),
             body=(feet - my0) / mw, nostril_sep=abs(p['x'] - q['x']) / mw)
    for side, e in (('L', el), ('R', er)):
        if e:
            r['eye' + side] = (abs(e['x'] - mc) / mw, (my0 - e['y']) / mw, e['w'] / mw)
    return r


def check(path, lock=False, verbose=True):
    figs = figures(path, lock)
    rows = [measure(f, lock) for f in figs]
    # second pass: where a figure had several dot pairs, take the one whose muzzle colour matches the others
    sure = [r['col'] for r in rows if r and r['ncand'] == 1]
    if sure:
        ref = np.median(np.array(sure), axis=0)
        rows = [measure(f, lock, ref) for f in figs]
    bodies = [r['body'] for r in rows if r]
    med_body = float(np.median(bodies)) if bodies else 0
    mws = [r['mw'] for r in rows if r]
    med_mw = float(np.median(mws)) if mws else 0
    flags = []
    lines = [f'{"#":>2} {"muzzle":>6} {"vs med":>7} {"body":>5} {"eyeL dx/dy/len":>16} {"eyeR dx/dy/len":>16}  flags']
    for i, r in enumerate(rows):
        if not r:
            lines.append(f'{i + 1:>2}  muzzle/nostrils not found')
            flags.append((i + 1, 'not measured'))
            continue
        fl = []
        if abs(r['mw'] / med_mw - 1) > 0.05:
            fl.append(f'head {(r["mw"] / med_mw - 1) * 100:+.0f}%')
        if abs(r['body'] / med_body - 1) > 0.06:
            fl.append(f'body {(r["body"] / med_body - 1) * 100:+.0f}%')
        for side in 'LR':
            e = r.get('eye' + side)
            if not e:
                fl.append(f'eye{side} hidden')
                continue
            if abs(e[0] - STD['eye_dx']) > 0.06:
                fl.append(f'eye{side} x {e[0]:.2f}')
            if abs(e[1] - STD['eye_dy']) > 0.05:
                fl.append(f'eye{side} y {e[1]:.2f}')
            if abs(e[2] / STD['eye_len'] - 1) > 0.25:
                fl.append(f'eye{side} len {e[2]:.2f}')
        fmt = lambda e: '/'.join(f'{v:.2f}' for v in e) if e else '-'  # noqa: E731
        lines.append(f'{i + 1:>2} {r["mw"]:>6} {(r["mw"] / med_mw - 1) * 100:>+6.0f}% {r["body"]:>5.2f} '
                     f'{fmt(r.get("eyeL")):>16} {fmt(r.get("eyeR")):>16}  {", ".join(fl)}')
        if fl:
            flags.append((i + 1, ', '.join(fl)))
    if verbose:
        print(path)
        print('\n'.join(lines))
        print('flags:', flags if flags else 'none')
    return figs, rows, flags


# ---------- building normalised sprites ------------------------------------------------------------------------------

def place(f, r, mw_target, lock=False):
    s = mw_target / r['mw']
    img = f['img']
    W, H = img.size
    nw, nh = max(1, round(W * s)), max(1, round(H * s))
    big = img.resize((nw, nh), Image.LANCZOS if s < 1 else Image.NEAREST)
    mask = Image.fromarray((f['mask'] * 255).astype(np.uint8)).resize((nw, nh), Image.NEAREST)
    canvas = Image.new('RGBA', CANVAS, (0, 0, 0, 0))
    ox = round(CANVAS[0] / 2 - r['cx'] * s)
    oy = round(FEET_Y - r['feet'] * s)
    rgba = big.convert('RGBA')
    rgba.putalpha(mask)
    canvas.alpha_composite(rgba, (ox, oy)) if ox >= 0 and oy >= 0 else canvas.paste(rgba, (ox, oy), rgba)
    return canvas, (ox, oy, ox + nw, oy + nh)


def build(path, outdir, name, kind, lock=False, mw_target=100):
    import os
    os.makedirs(outdir, exist_ok=True)
    figs, rows, flags = check(path, lock)
    tiles = []
    for i, (f, r) in enumerate(zip(figs, rows)):
        if not r:
            raise SystemExit(f'figure {i + 1} could not be measured; fix it before building')
        c, box = place(f, r, mw_target, lock)
        if box[1] < 0 or box[0] < 0 or box[2] > CANVAS[0]:
            print(f'warning: figure {i + 1} spills outside the canvas {box}')
        fn = f'{name}-lock-{i}.png' if lock else f'{name}-stand-{i}-{kind}.png'
        c.save(os.path.join(outdir, fn))
        tiles.append(c)
    sheet = Image.new('RGBA', (CANVAS[0] * 5, CANVAS[1] * 3), (32, 38, 74, 255) if lock else (238, 241, 246, 255))
    for i, t in enumerate(tiles):
        sheet.alpha_composite(t, ((i % 5) * CANVAS[0], (i // 5) * CANVAS[1]))
    d = ImageDraw.Draw(sheet)
    # guide lines: feet, muzzle top, eye line (identical on every figure after building)
    r0 = next(r for r in rows if r)
    mtop = FEET_Y - r0['body'] * mw_target
    for rr in range(3):
        for y, colr in ((FEET_Y, (255, 0, 0)), (FEET_Y - np.median([r['body'] for r in rows]) * mw_target, (0, 160, 255)),
                        (FEET_Y - np.median([r['body'] for r in rows]) * mw_target - STD['eye_dy'] * mw_target, (0, 200, 0))):
            d.line([(0, rr * CANVAS[1] + y), (sheet.width, rr * CANVAS[1] + y)], fill=colr, width=1)
    sheet.convert('RGB').save(os.path.join(outdir, f'{name}-{"lock" if lock else kind}-sheet.png'))
    return flags


def _stages(sel):
    out = []
    for part in sel.split(','):
        a, _, b = part.partition('-')
        out += list(range(int(a), int(b or a) + 1))
    return out


def compose(out, specs, lock=False):
    """Pick each stage from whichever generation got it right: specs like 'v5.png:0-9' 'v6.png:10,11,12-14'
    (0-based stages). Every pick is rescaled to the median muzzle width and pasted on a clean 5x3 sheet."""
    picks = {}
    for spec in specs:
        path, sel = spec.rsplit(':', 1)
        figs, rows, _ = check(path, lock, verbose=False)
        for s in _stages(sel):
            if not rows[s]:
                raise SystemExit(f'{path}: figure {s + 1} could not be measured')
            picks[s] = (figs[s], rows[s], path)
    missing = sorted(set(range(15)) - set(picks))
    if missing:
        raise SystemExit(f'no source for stages {missing}')
    mw = float(np.median([r['mw'] for _, r, _ in picks.values()]))
    tiles = []
    for s in range(15):
        f, r, path = picks[s]
        k = mw / r['mw']
        W, H = f['img'].size
        nw, nh = max(1, round(W * k)), max(1, round(H * k))
        img = f['img'].resize((nw, nh), Image.LANCZOS if k < 1 else Image.NEAREST).convert('RGBA')
        img.putalpha(Image.fromarray((f['mask'] * 255).astype(np.uint8)).resize((nw, nh), Image.NEAREST))
        tiles.append((img, r['feet'] * k, r['cx'] * k))
        print(f'stage {s:2d} (#{s + 1:2d}) <- {path}  x{k:.3f}')
    cw = max(t[0].width for t in tiles) + 40
    ch = max(t[0].height for t in tiles) + 40
    sheet = Image.new('RGBA', (cw * 5, ch * 3), (32, 38, 74, 255) if lock else (238, 241, 246, 255))
    for s, (img, feet, cx) in enumerate(tiles):
        x = (s % 5) * cw + round(cw / 2 - cx)
        y = (s // 5) * ch + round(ch - 20 - feet)
        sheet.alpha_composite(img, (x, y))
    sheet.convert('RGB').save(out)
    print(f'{out}: {sheet.width}x{sheet.height}, muzzle {mw:.0f}px')


def fit(paths, lock_last=False):
    need = []
    for k, p in enumerate(paths):
        lock = lock_last and k == len(paths) - 1
        figs, rows, _ = check(p, lock, verbose=False)
        for f, r in zip(figs, rows):
            if not r:
                continue
            W, H = f['img'].size
            # how big can the muzzle be so this figure fits the canvas (feet at FEET_Y, centred on cx)
            up = r['feet']  # px above the feet line
            half = max(r['cx'], W - r['cx'])
            need.append(min(FEET_Y / up, (CANVAS[0] / 2) / half) * r['mw'])
    print(f'largest muzzle width that fits every figure: {min(need):.0f}px')
    return min(need)


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    opts = {a for a in sys.argv[1:] if a.startswith('--')}
    lock = '--lock' in opts
    mw = 100
    for i, a in enumerate(sys.argv):
        if a == '--mw':
            mw = float(sys.argv[i + 1])
            args = [x for x in args if x != sys.argv[i + 1]]
    cmd = args[0]
    if cmd == 'check':
        check(args[1], lock)
    elif cmd == 'build':
        build(args[1], args[2], args[3], args[4] if len(args) > 4 else 'none', lock, mw)
    elif cmd == 'fit':
        fit(args[1:], '--lock-last' in opts)
    elif cmd == 'compose':
        compose(args[1], args[2:], lock)
    else:
        print(__doc__)
