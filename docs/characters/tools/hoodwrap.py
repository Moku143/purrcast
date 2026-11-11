"""Stage 14 single: put the eyes where every other stage has them (relative to the muzzle) and pull the hood's own
fur trim further in around the face, so it covers the outer half of each eye.

Standard eye geometry measured on stages 2-14 of the standing sheet, in muzzle widths (mw):
  centre x = muzzle centre +/- 0.62 mw, centre y = muzzle top - 0.10 mw, length 0.28 mw, thickness 0.09 mw.
The trim is not redrawn: on every row of the face opening, the band of trim next to the face (TRIM px wide) is
stretched sideways into the face by d px, so its scallops and dark inner edge simply move in.
Usage: python3 hoodwrap.py in.png out.png [cover]   cover = where the trim edge lands, in mw from the muzzle centre
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, '.')
from recentre import hsv  # noqa: E402

TRIM = 46


def main(src, dst, cover=0.62):
    im = Image.open(src).convert('RGB')
    a = np.asarray(im).astype(int)
    H, W = a.shape[:2]
    h, s, v = hsv(a.astype(np.uint8))
    warm = (h > 0.0) & (h < 0.11) & (s > 0.35) & (v > 0.45)
    muz = warm & (v < 0.88) & (v > 0.6)
    muz[int(0.6 * H):] = False
    lab, n = ndimage.label(muz)
    k = int(np.argmax(ndimage.sum(muz, lab, range(1, n + 1)))) + 1
    ys, xs = np.nonzero(lab == k)
    mx0, mx1, my0, my1 = xs.min(), xs.max(), ys.min(), ys.max()
    mw = mx1 - mx0
    mc = (mx0 + mx1) / 2
    lab2, _ = ndimage.label(warm)
    face = ndimage.binary_fill_holes(lab2 == lab2[(my0 + my1) // 2, int(mc)])
    skin = np.median(a[face & (v > 0.9)], axis=0)
    outline = np.array([12, 14, 27])
    out = a.copy()
    # 1. erase old eyes, draw eyes at the standard place
    old = face & (a.sum(-1) < 300)
    old[my0 - 2:, :] = False
    out[ndimage.binary_dilation(old, iterations=2) & face] = skin
    L, T = int(round(0.28 * mw)), max(3, int(round(0.09 * mw)))
    for sgn in (-1, 1):
        cx, cy = mc + sgn * 0.62 * mw, my0 - 0.10 * mw
        X0, Y0 = int(round(cx - L / 2)), int(round(cy - T / 2))
        for y in range(Y0, Y0 + T):
            for x in range(X0, X0 + L):
                dx, dy = min(x - X0, X0 + L - 1 - x), min(y - Y0, Y0 + T - 1 - y)
                if (dx == 0 and dy < 2) or (dx == 1 and dy == 0):
                    continue
                out[y, x] = outline
    # 2. pull the trim in, row by row
    eye_row = int(round(my0 - 0.10 * mw))
    fr = np.nonzero(face[eye_row])[0]
    d_eye_l = int(round((mc - cover * mw) - fr.min()))
    d_eye_r = int(round(fr.max() - (mc + cover * mw)))
    rows = np.nonzero(face.any(1))[0]
    src_img = out.copy()
    for y in rows:
        f = np.nonzero(face[y])[0]
        xl, xr = f.min(), f.max()
        # never cover the muzzle (keep 5px of cheek next to it)
        lim_l = mx0 - 5 if my0 - 2 <= y <= my1 + 2 else mc - 4
        lim_r = mx1 + 5 if my0 - 2 <= y <= my1 + 2 else mc + 4
        # taper the pull to nothing over the last rows above the scarf
        t = min(1.0, max(0.0, (rows.max() - y) / max(1, 0.35 * mw)))
        dl = int(max(0, min(d_eye_l * t, lim_l - xl)))
        dr = int(max(0, min(d_eye_r * t, xr - lim_r)))
        if dl > 0:
            s0, s1 = xl - TRIM, xl  # trim band left of the opening
            seg = src_img[y, s0:s1 + 1]
            newlen = (s1 - s0 + 1) + dl
            idx = np.clip((np.arange(newlen) * (len(seg) / newlen)).astype(int), 0, len(seg) - 1)
            out[y, s0:s0 + newlen] = seg[idx]
        if dr > 0:
            s0, s1 = xr, xr + TRIM
            seg = src_img[y, s0:s1 + 1]
            newlen = (s1 - s0 + 1) + dr
            idx = np.clip((np.arange(newlen) * (len(seg) / newlen)).astype(int), 0, len(seg) - 1)
            out[y, s1 - newlen + 1:s1 + 1] = seg[idx]
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(dst)
    print(f'mw {mw}; eyes {L}x{T} at +/-{0.62 * mw:.0f}px; pull at eye row L {d_eye_l} R {d_eye_r}px')


if __name__ == '__main__':
    args = sys.argv[1:]
    main(args[0], args[1], *(float(x) for x in args[2:3]))
