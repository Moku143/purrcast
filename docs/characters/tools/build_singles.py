"""App standing sprites from single-figure pictures that were all edited from ONE base picture (same scale in every
picture). One scale for all of them, taken from the base: the base figure's height (ear tips to feet) becomes the
cats' mean hatless height (406 px). Each figure: feet on y=555, muzzle centre on x=HX (the cats' head centre).
Edges: the background around the figure is replaced by the outline colour before the downscale, so no light fringe;
the alpha is a smooth downscale of the mask, then cut at half.
Usage: build_singles.py BASE.png OUT_DIR NAME KIND PIC0 PIC1 ... (PICk -> NAME-stand-k-KIND.png)"""
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sprite_kit as sk  # noqa: E402

CANVAS = (480, 560)
FEET_Y = 555
HX = 247.0
CAT_H = 406.0
OUTLINE = np.array([14, 12, 22])
MUZ = np.array([185, 98, 68])


def figure(path):
    a = np.asarray(Image.open(path).convert('RGB')).astype(int)
    flat = a.reshape(-1, 3)
    bg = np.median(flat[flat.sum(1) > 600], axis=0)
    d = np.abs(a - bg).sum(-1)
    m = ndimage.binary_closing(d > 40, iterations=2)
    lab, n = ndimage.label(m)
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    m = lab == (int(np.argmax(sizes)) + 1)
    m = ndimage.binary_fill_holes(m)
    # background showing through between an arm and the body (closed in by the outline): see-through again
    holes = m & (d < 25)
    holes = ndimage.binary_opening(holes, iterations=3)   # thin light lines in the drawing (stripe edges) stay
    hl, hn = ndimage.label(holes)
    for i in range(1, hn + 1):
        c = hl == i
        if c.sum() > 150:
            m &= ~c
    ys, xs = np.nonzero(m)
    return a, m, int(ys.min()), int(ys.max())


def muzzle_cx(a, m):
    f = {'img': Image.fromarray(a.astype(np.uint8)), 'mask': m}
    r = sk.measure(f, ref_col=MUZ)
    if r:
        return float(r['mc'])
    ys, xs = np.nonzero(m)
    return float(np.median(xs))


def build(path, s, out):
    a, m, top, feet = figure(path)
    cx = muzzle_cx(a, m)
    rgb = a.copy()
    rgb[~m] = OUTLINE
    H, W = m.shape
    nw, nh = round(W * s), round(H * s)
    img = Image.fromarray(rgb.astype(np.uint8)).resize((nw, nh), Image.LANCZOS)
    al = Image.fromarray((m * 255).astype(np.uint8)).resize((nw, nh), Image.LANCZOS)
    al = np.asarray(al)
    rgba = np.dstack([np.asarray(img), np.where(al >= 128, 255, 0)]).astype(np.uint8)
    canvas = Image.new('RGBA', CANVAS, (0, 0, 0, 0))
    ox = int(round(HX - cx * s))
    oy = int(round(FEET_Y - feet * s))
    canvas.paste(Image.fromarray(rgba, 'RGBA'), (ox, oy), Image.fromarray(rgba, 'RGBA'))
    canvas.save(out)
    bb = canvas.getbbox()
    return dict(top=bb[1], x0=bb[0], x1=bb[2], ox=ox, oy=oy, cx=round(cx * s + ox, 1))


if __name__ == '__main__':
    base, out, name, kind = sys.argv[1:5]
    pics = sys.argv[5:]
    _, _, t, f = figure(base)
    s = CAT_H / (f - t)
    os.makedirs(out, exist_ok=True)
    print('scale', round(s, 4), 'base height', f - t)
    for k, p in enumerate(pics):
        info = build(p, s, os.path.join(out, f'{name}-stand-{k}-{kind}.png'))
        if info['x0'] < 0 or info['top'] < 0 or info['x1'] > CANVAS[0]:
            print('warning: outside the canvas', k, info)
        print(k, info)
