"""Same capybara, same colours, other face/body proportions - to choose a base before redoing the 15 outfits.
The head is rebuilt as clean pixel art from the original stage-8 head (pixel_head, narrowed by AX before the cells are
cut, sized by MW); the body (stage SPRITE's clothes) is scaled by BX x BY from the feet; the head sits on it as
before (same neck overlap, centred on the body).
Usage: proportion_variants.py SPRITE.png OUT_DIR"""
import os
import sys
import json
import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sprite_kit as sk  # noqa: E402
from pixel_head import pixel_head  # noqa: E402
import umb_build as ub  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
SHEET = os.path.join(HERE, '..', 'capy', 'm3-stand-15-v3.png')
FUR, MUZ = [241, 165, 100], [205, 125, 76]

VARIANTS = [
    # name, head width, head size (muzzle px), body width, body height
    ('1', 0.90, 105, 0.90, 1.00),
    ('2', 0.90, 105, 0.80, 1.00),
    ('3', 0.80, 105, 0.90, 1.00),
    ('4', 0.80, 105, 0.80, 1.00),
    ('5', 0.72, 105, 0.85, 1.00),
    ('6', 0.72, 105, 0.75, 1.00),
    ('7', 0.82, 95, 0.82, 1.08),
    ('8', 0.82, 118, 0.85, 0.88),
]


def parts(sprite):
    a = np.asarray(Image.open(sprite).convert('RGBA')).copy()
    ro = sk.measure(ub.as_fig(a), ref_col=np.array(MUZ))
    hm = ub.head_sil(a, ro)
    body = a.copy()
    body[ndimage.binary_dilation(hm, iterations=1)] = 0
    head_bottom = int(np.nonzero(hm.any(1))[0].max())
    # bits of the old head's outline left beside it (the new head may be narrower): nothing of the body is that high,
    # and nothing that small is clothes
    body[:head_bottom - 30] = 0
    # the body's outline used to run into the head's: thin hooks left at the neck go
    bm = body[..., 3] > 0
    band = np.zeros_like(bm); band[:head_bottom + 12] = True
    thin = bm & band & ~ndimage.binary_opening(bm, iterations=3)
    body[thin] = 0
    lab, n = ndimage.label(body[..., 3] > 0)
    for i in range(1, n + 1):
        if (lab == i).sum() < 300:
            body[lab == i] = 0
    return a, body, ro, head_bottom


def variant(body_full, ro, head_bottom, ax, mw, bx, by):
    m = body_full[..., 3] > 0
    ys = np.nonzero(m.any(1))[0]
    feet = int(ys.max())
    low = np.nonzero(m[feet - 40:feet + 1])[1]
    cx = float(np.median(low))
    b = Image.fromarray(body_full)
    bw, bh = round(480 * bx), round(560 * by)
    bs = np.asarray(b.resize((bw, bh), Image.LANCZOS)).copy()
    bs[..., 3] = np.where(bs[..., 3] > 127, 255, 0)
    canvas = np.zeros((760, 640, 4), np.uint8)
    ox = int(round(320 - cx * bx))
    oy = int(round(700 - feet * by))
    sub = canvas[oy:oy + bh, ox:ox + bw]
    hh, ww = min(sub.shape[0], bh), min(sub.shape[1], bw)
    put = bs[:hh, :ww]
    canvas[oy:oy + hh, ox:ox + ww][put[..., 3] > 0] = put[put[..., 3] > 0]
    neck_y = oy + head_bottom * by          # where the old head ended, on the scaled body
    head, _ = pixel_head(SHEET, 7, mw, 4, 2, fur_rgb=FUR, muz_rgb=MUZ, ax=ax)
    h = np.asarray(head.convert('RGBA')).copy()
    near = (np.abs(h[..., :3].astype(int) - np.array(FUR)).sum(-1) < 45) & (h[..., 3] > 0)
    h[near, :3] = FUR                        # a lighter fur shade the cells picked up under the eyes -> fur
    hb = Image.fromarray(h).getbbox()
    h = h[hb[1]:hb[3], hb[0]:hb[2]]
    hy = int(round(neck_y - h.shape[0]))
    hx = int(round(320 + (ro['mc'] - cx) * bx - h.shape[1] / 2))
    reg = canvas[hy:hy + h.shape[0], hx:hx + h.shape[1]]
    on = h[..., 3] > 0
    reg[on] = h[on]
    return Image.fromarray(canvas)


if __name__ == '__main__':
    sprite, out = sys.argv[1:3]
    os.makedirs(out, exist_ok=True)
    a, body, ro, hb = parts(sprite)
    info = {}
    for name, ax, mw, bx, by in VARIANTS:
        im = variant(body, ro, hb, ax, mw, bx, by)
        im.save(f'{out}/variant-{name}.png')
        m = np.asarray(im)[..., 3] > 0
        ys, xs = np.nonzero(m)
        H = ys.max() - ys.min()
        info[name] = dict(ax=ax, mw=mw, bx=bx, by=by, height=int(H))
        print(name, info[name])
    json.dump(info, open(f'{out}/variants.json', 'w'))
