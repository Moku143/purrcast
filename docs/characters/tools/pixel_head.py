"""Clean pixel-art version of one head with its exact shape: the head of SHEET's stage STAGE is cut out, scaled to the
sprite scale (muzzle MW px), cut into U x U cells; every cell takes the commonest of a few flat colours found in
that head (k-means), the silhouette loses one-cell bumps, and the outer outline is redrawn exactly K cells wide.
Nothing is moved - the shape, the eyes, the muzzle stay where they are; only the edges become regular pixel steps.
Usage: pixel_head.py SHEET STAGE OUT.png [--mw 105] [--u 4] [--k 2]"""
import sys
import os
import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.cluster.vq import kmeans2
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sprite_kit as sk
from heads import head_mask


def opt(name, default):
    return type(default)(sys.argv[sys.argv.index(name) + 1]) if name in sys.argv else default


def pixel_head(sheet, stage, mw_t=105.0, u=4, k=2, ncol=7, fur_rgb=None, muz_rgb=None):
    figs, rows, _ = sk.check(sheet, verbose=False)
    f, r = figs[stage], rows[stage]
    hm, jaw, _ = head_mask(f, r)
    hm = ndimage.binary_fill_holes(hm & f['mask'])
    a = np.asarray(f['img'].convert('RGB')).astype(int)
    rgba = np.zeros(a.shape[:2] + (4,), np.uint8); rgba[..., :3] = a; rgba[..., 3] = np.where(hm, 255, 0)
    im = Image.fromarray(rgba, 'RGBA')
    bb = im.getbbox(); im = im.crop(bb)
    s = mw_t / r['mw']
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    A = np.asarray(im).astype(float)
    Hh, Ww = A.shape[:2]
    gh, gw = -(-Hh // u) + 2, -(-Ww // u) + 2
    pad = np.zeros((gh * u, gw * u, 4)); pad[u:u + Hh, u:u + Ww] = A
    on = pad[..., 3] > 127
    px = pad[on][:, :3]
    rng = np.random.default_rng(3)
    cent, _ = kmeans2(px[rng.choice(len(px), min(40000, len(px)), replace=False)], ncol, minit='++', seed=3)
    lab = np.full(on.shape, -1)
    d = ((pad[..., :3][..., None, :] - cent[None, None]) ** 2).sum(-1)
    lab[on] = d.argmin(-1)[on]
    # cells: commonest label (transparent = -1)
    L = lab.reshape(gh, u, gw, u).transpose(0, 2, 1, 3).reshape(gh, gw, u * u)
    cell = np.zeros((gh, gw), int)
    for y in range(gh):
        for x in range(gw):
            v = L[y, x]
            cell[y, x] = np.bincount(v + 1, minlength=ncol + 1).argmax() - 1
    S = cell >= 0
    S = ndimage.binary_opening(ndimage.binary_closing(S, iterations=1), iterations=1)
    S = ndimage.binary_fill_holes(S)
    labS, nS = ndimage.label(S)
    if nS > 1:
        S = labS == (np.argmax(ndimage.sum(S, labS, range(1, nS + 1))) + 1)
    # inside cells without a colour (holes) take the commonest neighbour colour
    idx = ndimage.distance_transform_edt(cell < 0, return_distances=False, return_indices=True)
    cell = np.where((cell < 0) & S, cell[idx[0], idx[1]], cell)
    darkest = int(np.argmin(cent.sum(1)))
    # outline exactly k cells wide (chessboard distance from outside)
    dist = ndimage.distance_transform_cdt(S, metric='chessboard')
    ring = S & (dist <= k)
    cell[ring] = darkest
    # lone cells (one cell differing from all 4 neighbours) take the neighbours' colour, except the darkest (eyes,
    # nostrils) and the cells next to the outline
    for _ in range(2):
        c2 = cell.copy()
        for y in range(1, gh - 1):
            for x in range(1, gw - 1):
                if not S[y, x] or ring[y, x] or cell[y, x] == darkest:
                    continue
                nb = [cell[y - 1, x], cell[y + 1, x], cell[y, x - 1], cell[y, x + 1]]
                if cell[y, x] not in nb:
                    c2[y, x] = max(set(nb), key=nb.count)
        cell = c2
    # --- tidy the face parts -------------------------------------------------------------------------------------
    cs = cent.astype(float) / 255
    sat = (cs.max(1) - cs.min(1)) / (cs.max(1) + 1e-9)
    greyish = [i for i in range(ncol) if sat[i] < 0.25 and i != darkest]
    counts = np.bincount(cell[S & ~ring], minlength=ncol)
    fur = int(np.argmax(counts))
    # anti-alias greys inside: commonest coloured neighbour
    for _ in range(3):
        g = S & np.isin(cell, greyish)
        if not g.any():
            break
        ok = S & ~np.isin(cell, greyish)
        idx = ndimage.distance_transform_edt(~ok, return_distances=False, return_indices=True)
        cell[g] = cell[idx[0][g], idx[1][g]]
    # muzzle: the coloured cluster (not fur, not darkest) with most cells in the middle of the face
    hh, ww = cell.shape
    yy, xx = np.mgrid[0:hh, 0:ww]
    cy, cx = np.nonzero(S)
    mid = (np.abs(xx - cx.mean()) < 0.25 * (cx.max() - cx.min())) & (yy > cy.min() + 0.45 * (cy.max() - cy.min()))
    cand = [i for i in range(ncol) if i not in (fur, darkest) and i not in greyish]
    muz = max(cand, key=lambda i: (mid & (cell == i)).sum())
    browns = [i for i in cand if i != muz and cent[i].sum() < cent[muz].sum()]
    M = S & ~ring & mid & np.isin(cell, [muz, darkest] + browns)
    M = ndimage.binary_closing(M, iterations=1)
    M = ndimage.binary_fill_holes(M)
    lm, nm = ndimage.label(M)
    if nm:
        M = lm == (np.argmax(ndimage.sum(M, lm, range(1, nm + 1))) + 1)
        M = ndimage.binary_opening(M, iterations=1)
    # nostrils: the dark cells inside the muzzle -> two 2x2 dots at their centres
    dk = M & (cell == darkest)
    ld, nd = ndimage.label(dk)
    nos = sorted(range(1, nd + 1), key=lambda i: -(ld == i).sum())[:2]
    cents = [np.array(np.nonzero(ld == i)).mean(1) for i in nos]
    edge = M & ~ndimage.binary_erosion(M)
    mline = np.clip(cent[muz] * 0.72, 0, 255)
    cent = np.vstack([cent, mline]); MLINE = len(cent) - 1
    cell[M] = muz
    cell[edge] = MLINE
    # (nostrils are drawn after scaling up, as small round dots)
    # eyes: dark bars a little above the muzzle, away from the outline -> exact bars 2 cells tall.
    # Every other dark cell inside the outline ring (thick bits of the old outline) becomes fur.
    mtop = np.nonzero(M.any(1))[0].min()
    inner = S & ~ring & ~ndimage.binary_dilation(M, iterations=1) & (cell == darkest)
    band = np.zeros_like(inner); band[max(0, mtop - 7):mtop + 1] = True
    far = dist > k + 1
    ey = inner & band & far
    cell[inner] = fur
    le, ne = ndimage.label(ey)
    comps = sorted(range(1, ne + 1), key=lambda i: -(le == i).sum())[:2]
    mcx = np.nonzero(M)[1].mean()
    bars = []
    for i in comps:
        ys_, xs_ = np.nonzero(le == i)
        bars.append((ys_.mean(), abs(xs_.min() - mcx), abs(xs_.max() - mcx), xs_.mean() < mcx))
    if len(bars) == 2:
        ymid = int(round(np.mean([b_[0] for b_ in bars]) - 0.5))
        inner_ = int(round(np.mean([min(b_[1], b_[2]) for b_ in bars])))
        outer_ = int(round(np.mean([max(b_[1], b_[2]) for b_ in bars])))
        c0 = int(round(mcx))
        cell[ymid:ymid + 2, c0 + inner_:c0 + outer_ + 1] = darkest
        cell[ymid:ymid + 2, c0 - outer_:c0 - inner_ + 1] = darkest
    # soft-edge colours just inside the outline ring: fur
    nearring = S & ~ring & ndimage.binary_dilation(ring, iterations=2)
    soft_ = nearring & ~np.isin(cell, [fur, darkest, muz, MLINE]) & ~M
    cell[soft_] = fur
    # ears: everything above the head's top line that is not fur or outline becomes one inner-ear patch
    top_line = None
    colx = int(round(np.nonzero(M)[1].mean()))
    col = np.nonzero(S[:, colx])[0]
    if len(col):
        top_line = col.min() + k + 1          # first fur row under the outline in the middle of the head
        eyerow = np.nonzero(((cell == darkest) & ~ring & ~M).any(1))[0]
        upper = S & ~ring & (yy < (eyerow.min() - 1 if len(eyerow) else top_line + 4))
        cell[upper & ~np.isin(cell, [fur, darkest])] = fur
        cell[upper & (cell == darkest)] = fur
        wcols = np.nonzero(S.any(0))[0]
        side = np.abs(xx - colx) > 0.22 * (wcols.max() - wcols.min())
        earzone = S & ~ring & (yy <= top_line + 2) & side
        le_, ne_ = ndimage.label(earzone)
        for i in range(1, ne_ + 1):
            e = le_ == i
            if e.sum() < 6:
                continue
            ys_, xs_ = np.nonzero(e)
            patch = ndimage.binary_erosion(e, iterations=1)
            patch[:ys_.min() + 1] = False
            cell[patch] = muz
    # nothing but fur right around the eye bars
    eyes_ = (cell == darkest) & ~ring & ~M
    around = ndimage.binary_dilation(eyes_, iterations=1) & ~eyes_ & S & ~ring & ~M
    cell[around] = fur
    # last pass: single stray cells inside the fur
    for y in range(1, gh - 1):
        for x in range(1, gw - 1):
            if S[y, x] and not ring[y, x] and cell[y, x] != fur and cell[y, x] != darkest and not M[y, x]:
                if all(cell[y + dy_, x + dx_] == fur for dy_, dx_ in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    cell[y, x] = fur
    if fur_rgb is not None:
        cent[fur] = fur_rgb
    if muz_rgb is not None:
        sh = np.array(muz_rgb) - cent[muz]
        cent[muz] = muz_rgb
        cent[MLINE] = np.clip(np.array(muz_rgb) * 0.72, 0, 255)
    out = np.zeros((gh, gw, 4), np.uint8)
    out[S, :3] = np.clip(cent[cell[S]], 0, 255).astype(np.uint8)
    out[S, 3] = 255
    big = Image.fromarray(out, 'RGBA').resize((gw * u, gh * u), Image.NEAREST)
    # nostrils: two round dots, mirrored about the muzzle centre, at the height the drawing has them
    if len(cents) == 2:
        from PIL import ImageDraw
        d_ = ImageDraw.Draw(big)
        ny = (np.mean([c_[0] for c_ in cents]) + 0.5) * u
        half = abs(cents[0][1] - cents[1][1]) / 2 * u
        mx_ = (np.nonzero(M)[1].mean() + 0.5) * u
        rx, ry = 0.06 * mw_t, 0.05 * mw_t
        col = tuple(int(v) for v in np.clip(cent[darkest], 0, 255)) + (255,)
        for sx_ in (mx_ - half, mx_ + half):
            d_.ellipse([sx_ - rx, ny - ry, sx_ + rx, ny + ry], fill=col)
    # position info: where the muzzle centre and the jaw are in this picture
    return big, dict(scale=s, ox=bb[0], oy=bb[1], pad=u, cent=cent)


if __name__ == '__main__':
    sheet, stage, outp = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    fur = [int(v) for v in opt('--fur', '').split(',')] if '--fur' in sys.argv else None
    muz = [int(v) for v in opt('--muzzle', '').split(',')] if '--muzzle' in sys.argv else None
    img, info = pixel_head(sheet, stage, opt('--mw', 105.0), opt('--u', 4), opt('--k', 2), fur_rgb=fur, muz_rgb=muz)
    img.save(outp)
    print(outp, img.size, 'palette', np.round(info['cent']).astype(int).tolist())
