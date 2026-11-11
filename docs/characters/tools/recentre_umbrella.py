"""Move each umbrella canopy sideways so its centre (and tip) sits exactly above the shaft.

Canopy = the coral components at or above the rim of the biggest coral blob, grown by 3px so its dark
outline and soft edge pixels come along. Pixels inside that area that belong to the figure (fur, hat,
pompom, the grey shaft) stay where they are. The canopy layer is lifted out, the hole filled with the
local background colour, and the layer is put back shifted, only onto background, so the figure stays in front.
Usage: python3 recentre.py in.png out.png
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, '.')
from figs import figures  # noqa: E402  (figs.py sits next to this file)


def hsv(a):
    a = a.astype(float) / 255
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx, mn = a.max(-1), a.min(-1)
    d = mx - mn + 1e-9
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6
    s = np.where(mx > 0, d / (mx + 1e-9), 0)
    return h, s, mx


def recentre(src, dst, verbose=True):
    im = Image.open(src).convert('RGB')
    a = np.asarray(im).copy()
    H, W = a.shape[:2]
    h, s, v = hsv(a)
    coral = ((h < 0.035) | (h > 0.95)) & (s > 0.40) & (v > 0.55)
    grey = (s < 0.12) & (v > 0.45) & (v < 0.92)
    body = ((((h > 0.045) & (h < 0.2)) & (s > 0.15)) | (((h > 0.22) & (h < 0.45)) & (s > 0.3))) & ~coral
    out = a.copy()
    report = []
    for i, f in enumerate(figures(src)):
        x0, y0, x1, y1 = f['box']
        pad = 8
        X0, Y0, X1, Y1 = max(0, x0 - pad), max(0, y0 - pad), min(W, x1 + pad), min(H, y1 + pad)
        cell = a[Y0:Y1, X0:X1]
        # local background: the commonest light colour around the figure
        flat = cell.reshape(-1, 3).astype(int)
        light = flat[flat.sum(1) > 650]
        bgc = np.median(light, axis=0).astype(np.uint8) if len(light) else np.array([236, 240, 245], np.uint8)
        isbg = np.abs(cell.astype(int) - bgc.astype(int)).sum(-1) < 16
        lab, n = ndimage.label(coral[Y0:Y1, X0:X1])
        if n == 0:
            report.append((i, 'no canopy'))
            continue
        sizes = ndimage.sum(lab > 0, lab, range(1, n + 1))
        big = int(np.argmax(sizes)) + 1
        rim = int(np.nonzero(lab == big)[0].max())
        can = np.zeros(lab.shape, bool)
        for k in range(1, n + 1):
            if np.nonzero(lab == k)[0].max() <= rim + 2:
                can |= lab == k
        cys, cxs = np.nonzero(can)
        low = cys >= rim - 6
        cl, cr = cxs[low].min(), cxs[low].max()
        # the tip knob: the topmost coral component, if it is small and above the dome
        top_y = cys.min()
        tops = [k for k in range(1, n + 1) if np.nonzero(lab == k)[0].min() <= top_y + 1]
        knob = min(tops, key=lambda k: (lab == k).sum())
        kys, kxs = np.nonzero(lab == knob)
        centre = kxs.mean() if (lab == knob).sum() < 0.1 * (lab == big).sum() else (cl + cr) / 2
        band = grey[Y0 + rim + 3:Y0 + rim + 22, X0:X1] & ~isbg[rim + 3:rim + 22]
        cols = band.sum(0)
        if cols.max() < 6:
            report.append((i, 'no shaft'))
            continue
        good = np.nonzero(cols >= 0.6 * cols.max())[0]
        sx = good.mean()
        dx = int(round(sx - centre))
        # rows above the figure's own top (ears/hat) hold only the canopy: shift those rows whole
        bodyc = body[Y0:Y1, X0:X1] & ~isbg
        bodyc[:cys.min(), :] = False
        bys_all = np.nonzero(bodyc[:rim + 4].any(1))[0]
        body_top = int(bys_all.min()) if len(bys_all) else rim + 4
        r0, r1 = max(0, int(cys.min()) - 4), min(rim + 3, body_top - 1)
        sub = out[Y0:Y1, X0:X1]
        for y in range(r0, r1 + 1):
            row = cell[y].copy()
            new = np.empty_like(row)
            new[:] = bgc
            if dx < 0:
                new[:dx] = row[-dx:]
            elif dx > 0:
                new[dx:] = row[:-dx]
            else:
                new = row
            # the shaft stays put below the rim
            if y > rim:
                for x in range(max(0, good.min() - 1), min(len(row), good.max() + 2)):
                    if grey[Y0 + y, X0 + x]:
                        new[x] = row[x]
            sub[y] = new
        region = ndimage.binary_dilation(can, iterations=6)
        region[:r1 + 1, :] = False
        region[rim + 4:, :] = False
        keep = (body[Y0:Y1, X0:X1] | grey[Y0:Y1, X0:X1]) & ~isbg & region
        # grey inside the canopy rows above the rim are rib highlights, not the shaft: only keep grey below rim-1
        keep_grey_rows = np.zeros_like(keep)
        keep_grey_rows[rim - 1:, :] = True
        shaft_cols = np.zeros_like(keep); shaft_cols[:, max(0, good.min() - 1):good.max() + 2] = True
        keep = (body[Y0:Y1, X0:X1] & region & ~isbg) | (grey[Y0:Y1, X0:X1] & region & keep_grey_rows & shaft_cols & ~isbg)
        layer = region & ~keep & ~isbg
        ys, xs = np.nonzero(layer)
        cols_rgb = cell[ys, xs].copy()
        sub[ys, xs] = bgc
        nx = xs + dx
        ok = (nx >= 0) & (nx < sub.shape[1])
        ys2, nx2, c2 = ys[ok], nx[ok], cols_rgb[ok]
        free = np.abs(sub[ys2, nx2].astype(int) - bgc.astype(int)).sum(-1) < 24
        sub[ys2[free], nx2[free]] = c2[free]
        # fill pin-holes left in the mixed rows: a background pixel with figure pixels on both sides
        sub = out[Y0:Y1, X0:X1]
        for _ in range(2):
            bgnow = np.abs(sub.astype(int) - bgc.astype(int)).sum(-1) < 16
            for y in range(max(0, r1 - 1), min(sub.shape[0], rim + 6)):
                for x in range(2, sub.shape[1] - 2):
                    if bgnow[y, x] and not isbg[y, x]:
                        l = [sub[y, x - k] for k in (1, 2) if not bgnow[y, x - k]]
                        r = [sub[y, x + k] for k in (1, 2) if not bgnow[y, x + k]]
                        u = [sub[y + k, x] for k in (-1, 1) if 0 <= y + k < sub.shape[0] and not bgnow[y + k, x]]
                        if (l and r) or (len(u) == 2):
                            nb = l + r + u
                            sub[y, x] = np.median(np.array(nb), axis=0)
        # stray light specks left behind around the canopy
        sub = out[Y0:Y1, X0:X1]
        sh, ss, sv = hsv(sub)
        near_body = ndimage.binary_dilation(body[Y0:Y1, X0:X1] & ~isbg, iterations=2)
        speck = (sub.astype(int).sum(-1) > 690) & (ss < 0.10) & ~near_body
        speck[rim + 8:, :] = False
        sub[speck] = bgc
        report.append((i, f'shift {dx:+d}px  centre {centre:.1f} -> shaft {sx:.1f}  width {cr - cl}  rows {r0}-{r1} whole, rim {rim}, body top {body_top}'))
    Image.fromarray(out).save(dst)
    if verbose:
        for r in report:
            print(*r)


if __name__ == '__main__':
    recentre(sys.argv[1], sys.argv[2])
