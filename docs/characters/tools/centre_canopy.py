"""Move each umbrella canopy sideways so its tip knob sits exactly above the shaft, without redrawing anything.

For each umbrella:
  * canopy rows = from above the knob down to the last row of the rim's own outline;
  * head rows   = rows where the figure (head, ears, hat) starts - anything below the rim that is not the shaft.
  Rows that hold only canopy + background + the hidden shaft are shifted as whole row segments (canopy, outline and
  soft edge move together, pixel for pixel). If the head reaches into the canopy rows, those rows keep the figure as it
  is and only the canopy's own pixels (coral and the dark outline touching it) are moved, drawn in front.
  The shaft stays where the paw holds it: in the rim rows the moved gap in the rim outline is closed with the rim's own
  pixels from beside it, and the real shaft is put back where it enters the canopy.
Usage: centre_canopy.py IN OUT"""
import sys
import os
import numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sprite_kit as sk


def shift_rows(block, dx, fill):
    new = np.empty_like(block); new[:] = fill
    if dx > 0:
        new[:, dx:] = block[:, :-dx]
    elif dx < 0:
        new[:, :dx] = block[:, -dx:]
    else:
        new = block.copy()
    return new


def main(src, dst):
    a = np.asarray(Image.open(src).convert('RGB')).astype(int)
    H, W = a.shape[:2]
    flat = a.reshape(-1, 3)
    bgc = np.median(flat[flat.sum(1) > 600], axis=0)
    h, s, v = sk._hsv(a.astype(np.uint8))
    coral = ((h < 0.045) | (h > 0.95)) & (s > 0.30) & (v > 0.35)
    dark = a.max(-1) < 110
    grey = (s < 0.12) & (v > 0.50) & (v < 0.93)
    offbg = np.abs(a - bgc).sum(-1) > 30
    lab, n = ndimage.label(coral)
    sizes = ndimage.sum(coral, lab, range(1, n + 1))
    big = [i + 1 for i in np.argsort(sizes)[::-1] if sizes[i] > 0.25 * sizes.max()]
    out = a.copy()
    for c in sorted(big, key=lambda c: np.nonzero(lab == c)[1].mean()):
        cm = lab == c
        ys, xs = np.nonzero(cm)
        top, rim = ys.min(), ys.max()
        x0, x1 = xs.min(), xs.max()
        knob = np.zeros_like(cm)
        for k in range(1, n + 1):
            if k == c:
                continue
            ky, kx_ = np.nonzero(lab == k)
            if ky.max() <= top + 4 and ky.min() >= top - 40 and abs(kx_.mean() - (x0 + x1) / 2) < 0.25 * (x1 - x0):
                knob |= lab == k
        kx = np.nonzero(knob)[1].mean() if knob.any() else (x0 + x1) / 2
        ktop = np.nonzero(knob)[0].min() if knob.any() else top
        band = grey[rim + 8:rim + 70, x0:x1 + 1] & offbg[rim + 8:rim + 70, x0:x1 + 1]
        cols = band.sum(0)
        good = np.nonzero(cols >= 0.6 * cols.max())[0]
        sx0, sx1 = good.min() + x0, good.max() + x0
        sx = (sx0 + sx1) / 2
        dx = int(round(sx - kx))
        if dx == 0:
            continue
        L, R = max(0, x0 - 30), min(W, x1 + 31)
        # last row of the rim outline (measured at a rim column away from the shaft and the head)
        cx_ = int(x0 + 0.12 * (x1 - x0))
        rb = int(np.nonzero(cm[:, max(0, cx_ - 8):cx_ + 8].any(1))[0].max())
        while rb + 1 < H and rb < rim + 14 and dark[rb + 1, cx_ - 8:cx_ + 8].any():
            rb += 1
        # first row of the figure below the canopy: off-background pixels that are not the shaft
        shaftcols = np.zeros(W, bool); shaftcols[max(0, sx0 - 3):sx1 + 4] = True
        fig_rows = [y for y in range(top, min(H, rim + 60))
                    if (offbg[y, L:R] & ~shaftcols[L:R] & ~ndimage.binary_dilation(cm, iterations=2)[y, L:R]
                        & ~knob[y, L:R] & ~(ndimage.binary_dilation(cm, iterations=9)[y, L:R] & (dark[y, L:R] | (s[y, L:R] < 0.3)))).sum() > 3]
        head_top = min(fig_rows) if fig_rows else rb + 1
        y0 = max(0, ktop - 12)
        yc = rb
        # the canopy's own pixels: coral + knob, and its dark outline and soft edge around it - never fur/hat colours
        body = ndimage.binary_fill_holes(ndimage.binary_closing(cm | knob, iterations=3))
        # the figure: what is left outside the canopy that hangs together with the figure below the rim
        white = (s < 0.07) & (v > 0.95)                  # the sticker fringe: pure white, not cream cloth
        rest = offbg & ~white & ~ndimage.binary_dilation(body, iterations=3)
        rest[:, max(0, sx0 - 4):sx1 + 5] = False          # cut the shaft so the canopy is not joined to the paw
        labr, _ = ndimage.label(rest)
        below = np.unique(labr[min(H - 1, rb + 25):min(H, rb + 60), L:R])
        figure = np.isin(labr, below[below > 0])
        figcol = figure & ~dark
        d_c = ndimage.distance_transform_edt(~body)
        d_f = ndimage.distance_transform_edt(~figcol)
        soft = offbg & (s < 0.35) & (v < 0.88)
        fringe = offbg & (s < 0.15) & (v >= 0.85)
        own = body | ((d_c <= 10) & offbg & ~figure)
        own[:y0] = False; own[yc + 1:] = False
        oy, ox = np.nonzero(own)
        colours = a[oy, ox].copy()
        out[oy, ox] = bgc
        tx = ox + dx; ok = (tx >= 0) & (tx < W)
        out[oy[ok], tx[ok]] = colours[ok]
        head_top = yc + 1
        # the light sticker fringe around the old and the new canopy: background (never figure pixels)
        nb = np.zeros_like(body); by, bx = np.nonzero(body); tb = bx + dx; okb = (tb >= 0) & (tb < W)
        nb[by[okb], tb[okb]] = True
        zone = ndimage.binary_dilation(body | nb, iterations=14)
        zone[:y0] = False; zone[yc + 4:] = False
        oh, os_, ov = sk._hsv(np.clip(out, 0, 255).astype(np.uint8))
        light = zone & (((os_ < 0.07) & (ov > 0.95)) | ((os_ < 0.18) & (ov >= 0.80) & ~figure))
        out[light] = bgc
        # and whatever is a touch lighter than the background (the bluish-white halo) in the canopy rows
        blk = out[y0:yc + 7, L:R]
        bh, bs, bv = sk._hsv(np.clip(blk, 0, 255).astype(np.uint8))
        warm = ndimage.binary_dilation(bs >= 0.25, iterations=2)
        halo = (blk.sum(-1) > bgc.sum() + 8) & (bs < 0.10) & ~warm
        blk[halo] = bgc
        out[y0:yc + 7, L:R] = blk
        # the shaft: close the moved gap in the rim with the rim's pixels beside it, put the real shaft back
        gy0, gy1 = max(y0, rim - 12), yc
        g0, g1 = int(sx0 + dx) - 2, int(sx1 + dx) + 3
        for y in range(gy0, gy1 + 1):
            seg = out[y, g0:g1]
            hs = sk._hsv(np.clip(seg, 0, 255).astype(np.uint8)[None])
            gs = (hs[1][0] < 0.12) & (hs[2][0] < 0.93) & (np.abs(seg - bgc).sum(-1) > 30)
            if gs.any() and not (g0 <= sx0 and sx1 < g1):
                left, right = out[y, g0 - 1], out[y, g1]
                out[y, g0:g1][gs] = left if np.abs(left - bgc).sum() > 30 else right
        for y in range(max(y0, rim - 2), yc + 1):
            out[y, sx0 - 2:sx1 + 3] = a[y, sx0 - 2:sx1 + 3]
        print(f'canopy x {x0}-{x1}: knob {kx:.1f} -> shaft {sx:.1f}  shift {dx:+d}px; rows {y0}-{yc}')
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(dst)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
