"""Move each umbrella canopy sideways so its tip knob sits exactly above the shaft.

The rows that hold only the canopy (knob down to the bottom of the rim outline) are shifted as whole row segments,
so the canopy, its outline and its soft edge move together pixel for pixel - nothing is redrawn. Where those rows
also hold part of the figure (ears or hat under the rim) and around the shaft, the original pixels are put back on
top, so the figure and the shaft do not move. Usage: centre_canopy.py IN OUT"""
import sys
import os
import numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sprite_kit as sk


def main(src, dst):
    a = np.asarray(Image.open(src).convert('RGB')).astype(int)
    H, W = a.shape[:2]
    flat = a.reshape(-1, 3)
    bgc = np.median(flat[flat.sum(1) > 600], axis=0)
    h, s, v = sk._hsv(a.astype(np.uint8))
    coral = ((h < 0.045) | (h > 0.95)) & (s > 0.30) & (v > 0.35)
    dark = a.max(-1) < 110
    grey = (s < 0.12) & (v > 0.50) & (v < 0.93)
    offbg = np.abs(a - bgc).sum(-1) > 45
    figure = offbg & ~coral & ~dark & ~((s < 0.15) & (v > 0.85)) & ~grey     # fur, hat, ears, clothes
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
        sx = good.mean() + x0
        sw = good.max() - good.min() + 1
        dx = int(round(sx - kx))
        if dx == 0:
            continue
        # bottom of the rim outline: dark rows right under the coral
        rb = rim
        lx_ = int(x0 + 0.15 * (x1 - x0))       # a column of the rim away from the head
        while rb + 1 < H and rb < rim + 10 and dark[rb + 1, lx_ - 6:lx_ + 6].any():
            rb += 1
        y0, y1 = max(0, ktop - 12), min(H - 1, rb + 3)
        L, R = max(0, x0 - 24), min(W, x1 + 25)
        seg = a[y0:y1 + 1, L:R].copy()
        new = np.empty_like(seg); new[:] = bgc
        if dx > 0:
            new[:, dx:] = seg[:, :-dx]
        else:
            new[:, :dx] = seg[:, -dx:]
        # the figure (and its outline) inside these rows stays where it is, in front
        # the figure inside these rows: what is not canopy (coral, knob and the 7 px of outline/soft edge round them)
        # and is connected to the figure below the rows
        cbody = ndimage.binary_fill_holes(ndimage.binary_closing(cm | knob, iterations=3))[y0:y1 + 1, L:R]
        ob = offbg[y0:y1 + 1, L:R]
        can = ndimage.binary_dilation(cbody, iterations=7) & ob
        rest = offbg[y0:min(H, y1 + 40), L:R].copy()
        rest[:can.shape[0]] &= ~can
        labr, nr = ndimage.label(rest)
        below = np.unique(labr[can.shape[0]:])
        fig = np.isin(labr[:can.shape[0]], below[below > 0])
        stay = fig
        # the shaft below the coral stays too
        sh = np.zeros_like(stay)
        rr = rim - y0 - 1
        if rr < sh.shape[0]:
            c0, c1 = int(sx - L - sw / 2 - 4), int(sx - L + sw / 2 + 5)
            sh[max(0, rr):, max(0, c0):c1] = True
        stay |= sh & ~coral[y0:y1 + 1, L:R]
        new[stay] = seg[stay]
        # a moved copy of the shaft landing outside the canopy goes back to background
        if rr < sh.shape[0]:
            c0, c1 = int(sx + dx - L - sw / 2 - 4), int(sx + dx - L + sw / 2 + 5)
            ghost = np.zeros_like(stay); ghost[max(0, rr):, max(0, c0):c1] = True
            g2 = ghost & ~stay & ~coral[y0:y1 + 1, L:R] & (np.abs(new - bgc).sum(-1) > 0)
            g2 &= (sk._hsv(new.astype(np.uint8))[1] < 0.15) & ~(new.max(-1) < 110)
            new[g2] = bgc
        out[y0:y1 + 1, L:R] = new
        print(f'canopy x {x0}-{x1}: knob {kx:.1f} -> shaft {sx:.1f}  shift {dx:+d}px  rows {y0}-{y1}')
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(dst)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
