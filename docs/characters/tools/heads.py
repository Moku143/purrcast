"""Give every hatless stage the same head: stage SRC's head (ears, fur, eyes, muzzle, outline) is cut out and put on
each target figure in place of its own, centred on the muzzle column and resting on the target's own jaw line.
Usage: python3 heads.py SHEET OUT SRC TARGETS   (0-based; SHEET = a composed sheet, all muzzles one width)"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0, __import__('os').path.dirname(__file__))
import sprite_kit as sk

BG = np.array([238, 241, 246])


def head_mask(f, r):
    a = np.asarray(f['img'].convert('RGB')).astype(int)
    m = f['mask']
    mw, mt, mc = r['mw'], r['mtop'], r['mc']
    h, s, v = sk._hsv(a.astype(np.uint8))
    furlike = (h > 0.02) & (h < 0.12) & (s > 0.30) & (v > 0.45)   # fur and muzzle browns
    lab, _ = ndimage.label(furlike)
    seed = lab[int(mt - 0.35 * mw), int(mc)]
    comp = lab == seed
    comp = ndimage.binary_fill_holes(comp)              # eyes, nostrils
    ys = np.nonzero(comp[:, int(mc)])[0]
    jaw = ys.max()                                       # last fur row above the jaw line
    ot = max(2, int(round(0.10 * mw)))
    light = a.sum(-1) > 650                                    # the thin white sticker fringe outside the outline
    headcol = furlike | (a.sum(-1) < 330) | light              # head colours: fur, muzzle, dark outline/eyes, fringe
    ring = ndimage.binary_dilation(comp, iterations=ot + 3) & headcol
    ring &= ~(light & ~ndimage.binary_dilation(comp, iterations=ot + 3))
    # below the jaw only the dark jaw line belongs to the head, never the collar under it
    below = np.zeros_like(ring); below[jaw + 1:, :] = True
    ring &= ~(below & ~(a.sum(-1) < 330))
    ring[jaw + ot + 2:, :] = False
    head = ring
    # ears: everything of the figure above the eye line belongs to the head (no hat on these stages)
    top = m.copy(); top[int(mt - 0.25 * mw):, :] = False
    head |= top
    head = ndimage.binary_fill_holes(head)
    return head, jaw, ot


def main(src_sheet, out, src, targets):
    figs, rows, _ = sk.check(src_sheet, verbose=False)
    im = Image.open(src_sheet).convert('RGB')
    A = np.asarray(im).astype(int).copy()
    fs, rs = figs[src], rows[src]
    hs, jaw_s, ot = head_mask(fs, rs)
    a_s = np.asarray(fs['img'].convert('RGB')).astype(int)
    for t in targets:
        f, r = figs[t], rows[t]
        x0, y0, x1, y1 = f['box']
        ht, jaw_t, _ = head_mask(f, r)
        sub = A[y0:y1, x0:x1]
        # 1. remove the target's own head (and the soft edge of its outline), never its clothes
        at = sub.copy()
        hh, ss_, vv = sk._hsv(np.clip(at, 0, 255).astype(np.uint8))
        headcol_t = ((hh > 0.02) & (hh < 0.12) & (ss_ > 0.30) & (vv > 0.45)) | (at.sum(-1) < 560)
        gone = ndimage.binary_dilation(ht, iterations=2) & headcol_t
        gone[jaw_t + 6:, :] = False
        fringe = ndimage.binary_dilation(ht, iterations=9) & (at.sum(-1) > 600) & ~f['mask'] | (ndimage.binary_dilation(ht, iterations=9) & (at.sum(-1) > 600) & (np.abs(at - BG).sum(-1) < 60))
        fringe[jaw_t - 2:, :] = False
        gone |= fringe
        sub[gone] = BG
        # 2. place the source head: muzzle column on muzzle column, jaw on jaw
        dx = int(round(r['mc'] - rs['mc']))
        dy = int(jaw_t - jaw_s)
        ys, xs = np.nonzero(hs)
        ty, tx = ys + dy, xs + dx
        # the head may reach above/beside the target's box: write into the full sheet
        gy, gx = ty + y0, tx + x0
        ok = (gy >= 0) & (gy < A.shape[0]) & (gx >= 0) & (gx < A.shape[1])
        A[gy[ok], gx[ok]] = a_s[ys[ok], xs[ok]]
        # 3. where the old head hid the top of the clothes and the new head does not cover it, grow the clothes up
        newhead = np.zeros_like(ht)
        inb = (ty >= 0) & (ty < ht.shape[0]) & (tx >= 0) & (tx < ht.shape[1])
        newhead[ty[inb], tx[inb]] = True
        hole = gone & ~newhead & f['mask']
        mw = r['mw']
        sub = A[y0:y1, x0:x1]
        for yy, xx in sorted(zip(*np.nonzero(hole)), key=lambda t: -t[0]):
            if yy < jaw_t - 0.45 * mw:
                continue
            for k in range(1, int(0.3 * mw)):
                if yy + k >= sub.shape[0]:
                    break
                p = sub[yy + k, xx]
                if np.abs(p - BG).sum() > 40 and not hole[yy + k, xx]:
                    sub[yy, xx] = p
                    break
        print(f'stage {t}: head from {src}, shift ({dx},{dy}), jaw {jaw_t}')
    Image.fromarray(A.astype(np.uint8)).save(out)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], int(sys.argv[3]), [int(x) for x in sys.argv[4].split(',')])
