"""Put one shared head on built app sprites (480x560 RGBA, all muzzles the same width).

  hatless stages : the sprite's own head (fur + outline, ears, eyes, muzzle) is removed and HEAD is put in its place,
                   its muzzle column on the sprite's muzzle column and its jaw on the sprite's jaw; where the old head
                   covered more than the new one, the clothes below grow up into the gap (with their outline).
  hat stages     : only the face inside the hat opening is replaced - HEAD is put behind the hat, muzzle on muzzle
                   (centre and top), and shows only where the sprite had face fur / muzzle; so the hat keeps covering
                   exactly what it covered.
Usage: put_head.py HEAD.png SPRITE_DIR NAME KIND [--hats 0,12,13,14] [--skip 0,12,13,14]  (skip = leave as drawn)"""
import sys
import os
import numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sprite_kit as sk
from heads import head_mask

OUTLINE = np.array([16, 16, 28])


def fig_of(rgba):
    a = np.asarray(rgba)
    m = a[..., 3] > 0
    return dict(box=(0, 0, a.shape[1], a.shape[0]), mask=m, img=Image.fromarray(a[..., :3])), a


def jaw_line(rgb, r):
    """bottom row of the dark jaw line under the muzzle, at the muzzle column"""
    x = int(r['mc']); dark = rgb.max(-1) < 90
    y = int(r['mtop'] + 0.5 * r['mw'])
    H = rgb.shape[0]
    while y < H - 1 and not dark[y, x]: y += 1      # muzzle's lower outline
    while y < H - 1 and dark[y, x]: y += 1
    while y < H - 1 and not dark[y, x]: y += 1      # fur under the muzzle -> jaw line
    while y < H - 1 and dark[y + 1, x]: y += 1
    return y


def head_anchor(head_rgba):
    """muzzle centre x, muzzle top y, jaw bottom y of the head picture"""
    f, a = fig_of(head_rgba)
    bg = np.zeros_like(a); bg[..., :3] = (238, 241, 246); bg[..., 3] = 255
    comp = Image.alpha_composite(Image.fromarray(bg), head_rgba)
    f['img'] = comp.convert('RGB')
    r = sk.measure(f)
    m = f['mask']
    jaw = np.nonzero(m[:, int(r['mc'])])[0].max()
    return r, jaw


def main(head_path, d, name, kind, hats, skip=()):
    head = Image.open(head_path).convert('RGBA')
    hr, hjaw = head_anchor(head)
    H = np.asarray(head)
    for k in range(15):
        p = os.path.join(d, f'{name}-stand-{k}-{kind}.png')
        im = Image.open(p).convert('RGBA')
        f, a = fig_of(im)
        bgc = np.zeros_like(a); bgc[..., :3] = (238, 241, 246); bgc[..., 3] = 255
        f['img'] = Image.alpha_composite(Image.fromarray(bgc), im).convert('RGB')
        r = sk.measure(f, ref_col=hr['col'])      # the muzzle colour picks the nostril pair, never the eyes
        if not r:
            print(k, 'not measured, skipped'); continue
        out = a.copy()
        rgb = a[..., :3].astype(int)
        hh, ss, vv = sk._hsv(a[..., :3])
        if k in skip:
            print(k, 'left as drawn'); continue
        if k in hats:
            # face inside the opening: fur + muzzle colours connected to the muzzle, plus what lies inside them
            warm = (hh > 0.02) & (hh < 0.12) & (ss > 0.30) & (vv > 0.45) & f['mask']
            lab, _ = ndimage.label(warm)
            seed = lab[int(r['mtop'] + 0.3 * r['mw']), int(r['mc'])]
            face = ndimage.binary_fill_holes(lab == seed)
            # eye bits on the edge of the opening are part of the face too
            face = ndimage.binary_fill_holes(face | (ndimage.binary_dilation(face, iterations=2) & (rgb.max(-1) < 90)
                                                    & ~ndimage.binary_dilation(~face & f['mask'] & (rgb.max(-1) >= 90), iterations=1)))
            dx = int(round(r['mc'] - hr['mc'])); dy = int(round(r['mtop'] - hr['mtop']))
            ys, xs = np.nonzero(face)
            sy, sx = ys - dy, xs - dx
            ok = (sy >= 0) & (sy < H.shape[0]) & (sx >= 0) & (sx < H.shape[1])
            src = H[sy[ok], sx[ok]]
            vis = src[:, 3] > 0
            out[ys[ok][vis], xs[ok][vis]] = src[vis]
            print(k, f'hat stage: face replaced ({vis.sum()} px), shift {dx},{dy}')
        else:
            hm, jaw, _ = head_mask(f, r)
            hm = ndimage.binary_fill_holes(hm & f['mask'])
            # jaw bottom of the sprite's own head at the muzzle column
            sj = jaw_line(rgb, r)
            hm[sj + 3:] = False
            gone = ndimage.binary_dilation(hm, iterations=2) & f['mask']
            gone[sj + 3:] = False
            out[gone] = 0
            # muzzle on muzzle (centre and top), so eyes and muzzle sit at the same height on every stage
            dx = int(round(r['mc'] - hr['mc'])); dy = int(round(r['mtop'] - hr['mtop']))
            sj = max(sj, int(round(hjaw + dy)))
            ys, xs = np.nonzero(H[..., 3] > 0)
            ty, tx = ys + dy, xs + dx
            ok = (ty >= 0) & (ty < out.shape[0]) & (tx >= 0) & (tx < out.shape[1])
            out[ty[ok], tx[ok]] = H[ys[ok], xs[ok]]
            newhead = np.zeros(f['mask'].shape, bool); newhead[ty[ok], tx[ok]] = True
            # what is left of the old head outside the new one (its outline, cheeks) above the jaw: cleared
            # what is left of the old head above the jaw: its outline, fur and light fringe - not the clothes
            old = ndimage.binary_dilation(hm, iterations=16) & f['mask']
            old[sj - int(0.12 * r['mw']):] = False
            headish = (rgb.max(-1) < 110) | ((hh > 0.02) & (hh < 0.12) & (ss > 0.30) & (vv > 0.45)) \
                | ((rgb.min(-1) > 170) & ~ndimage.binary_erosion(f['mask'], iterations=4))
            rest = old & ~newhead & headish
            out[rest] = 0
            # gaps the old head leaves between the new jaw and the clothes: one flat clothes colour per gap (the
            # commonest colour just below it), with the outline where the gap meets the outside
            fig = out[..., 3] > 0
            closed = ndimage.binary_fill_holes(ndimage.binary_closing(fig, iterations=4))
            gap = closed & ~fig
            gap[:max(0, int(hjaw + dy) - int(0.5 * r['mw']))] = False
            gap &= f['mask'] | closed
            lg, ng = ndimage.label(gap)
            filled = np.zeros_like(gap)
            orgb = out[..., :3].astype(int)
            for i in range(1, ng + 1):
                reg = lg == i
                below = ndimage.binary_dilation(reg, iterations=6) & ~reg & fig & ~newhead & (orgb.max(-1) >= 110)
                ys_, xs_ = np.nonzero(reg)
                below[:ys_.min()] = False
                if below.sum() < 5:
                    continue
                cols = orgb[below]
                q = (cols // 12)
                keys, inv, cnt = np.unique(q, axis=0, return_inverse=True, return_counts=True)
                col = np.median(cols[inv.ravel() == np.argmax(cnt)], axis=0)
                out[reg, :3] = col.astype(np.uint8); out[reg, 3] = 255
                filled |= reg
            if filled.any():
                fig = out[..., 3] > 0
                edge = filled & ndimage.binary_dilation(~fig, iterations=7)
                out[edge, :3] = OUTLINE
            # tidy the seam under the jaw: small whitish or grey specks
            y0s, y1s = max(0, int(hjaw + dy) - 14), min(out.shape[0], int(hjaw + dy) + 26)
            orgb = out[..., :3].astype(int); fig = out[..., 3] > 0
            mx_, mn_ = orgb.max(-1), orgb.min(-1)
            speck = fig & (((mn_ > 190) & (mx_ - mn_ < 45)) | ((mx_ - mn_ < 40) & (mx_ > 90) & (mx_ < 200)))
            speck[:y0s] = False; speck[y1s:] = False
            speck &= ~newhead
            ls_, ns_ = ndimage.label(speck)
            if ns_:
                sizes = ndimage.sum(speck, ls_, range(1, ns_ + 1))
                small = np.isin(ls_, [i + 1 for i, z in enumerate(sizes) if z < 150])
                outside = ndimage.binary_dilation(~fig, iterations=1)
                lsm, nsm = ndimage.label(small)
                good = fig & ~small
                idx = ndimage.distance_transform_edt(~good, return_distances=False, return_indices=True)
                for i in range(1, nsm + 1):
                    reg = lsm == i
                    if (reg & outside).any():
                        out[reg, 3] = 0
                    else:
                        out[reg] = out[idx[0][reg], idx[1][reg]]
            print(k, f'head replaced, shift {dx},{dy}, filled {int(filled.sum())} px')
        Image.fromarray(out, 'RGBA').save(p)


if __name__ == '__main__':
    hats = [0, 12, 13, 14]
    if '--hats' in sys.argv:
        hats = [int(x) for x in sys.argv[sys.argv.index('--hats') + 1].split(',')]
    skip = []
    if '--skip' in sys.argv:
        skip = [int(x) for x in sys.argv[sys.argv.index('--skip') + 1].split(',')]
        hats = [h for h in hats if h not in skip]
    a = [x for x in sys.argv[1:] if not x.startswith('--') and not x.replace(',', '').isdigit()]
    main(a[0], a[1], a[2], a[3], hats, skip)
