"""capy-lock-K (370x480, white with alpha like the cats' lock pictures) made straight from capy-stand-K-none:
dark outlines, eyes and nostrils -> clear; fur -> white; muzzle -> light grey; feet -> mid grey; clothes and props ->
grey by brightness; the light sticker fringe outside the outline -> clear. Size and place per stage = the cats' average
(lock height / stand height, centre x, feet line)."""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

A = __import__('os').path.join(__import__('os').path.dirname(__file__), '../../../Shared/SharedAssets.xcassets')
SRC, OUT = sys.argv[1], sys.argv[2]
FUR_COLOURED_COAT = {11}
THIN = 1.6               # inner lines below the head stay at most ~3 px wide   # capy stage 11: camel duffle the same colour as the fur, sleeves included


def hsv(a):
    a = a.astype(float) / 255
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx, mn = a.max(-1), a.min(-1)
    d = mx - mn + 1e-9
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6
    return h, np.where(mx > 0, d / (mx + 1e-9), 0), mx


def bbox(p):
    return Image.open(p).convert('RGBA').getbbox()


for k in range(15):
    sc, cx, bot = [], [], []
    for n in ('cat', 'abys', 'brit'):
        s = bbox(f'{A}/{n}-stand-{k}-none.imageset/{n}-stand-{k}-none.png')
        l = bbox(f'{A}/{n}-lock-{k}.imageset/{n}-lock-{k}.png')
        sc.append((l[3] - l[1]) / (s[3] - s[1])); cx.append((l[0] + l[2]) / 2); bot.append(l[3])
    scale, cxm, botm = float(np.mean(sc)), float(np.mean(cx)), float(np.mean(bot))

    im = Image.open(f'{SRC}/capy-stand-{k}-none.png').convert('RGBA')
    a = np.asarray(im).astype(int)
    m = a[..., 3] > 0
    rgb = a[..., :3]
    lum = (0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]) / 255
    h, s, v = hsv(rgb.astype(np.uint8))
    dark = rgb.max(-1) < 60                       # the near-black outline, eyes, nostrils (not navy cloth)
    soft = (rgb.max(-1) < 170) & (s < 0.45)        # the outline's soft grey edge
    for _ in range(3):
        dark = dark | (ndimage.binary_dilation(dark, iterations=1) & soft)
    furc = (h > 0.045) & (h < 0.10) & (s > 0.45) & (s < 0.75) & (v > 0.80) & (v < 0.98)
    # fur = fur-coloured parts of the head, the hands and the legs; a big fur-coloured patch on the body is cloth
    labf, nf = ndimage.label(furc)
    fur = np.zeros_like(furc)
    for c in range(1, nf + 1):
        reg = labf == c
        cy = np.nonzero(reg)[0].mean()
        n_ = reg.sum()
        if n_ < 150:
            continue                                  # specks in cloth texture
        cx_ = np.nonzero(reg)[1].mean()
        ys_ = np.nonzero(reg)[0]
        side_ok = abs(cx_ - 240) > 85 and k not in FUR_COLOURED_COAT
        if ys_.max() < 362 or ys_.min() > 485 or side_ok:
            fur |= reg
    muzzle = (h > 0.035) & (h < 0.09) & (s > 0.55) & (v > 0.62) & (v <= 0.85)
    feet = (h > 0.02) & (h < 0.10) & (s > 0.35) & (v > 0.25) & (v <= 0.62)
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    muzzle &= (yy > 236) & (yy < 350) & (np.abs(xx - 240) < 70)
    feet &= yy > 495
    alpha = np.clip(40 + 175 * lum, 0, 215)        # clothes, props
    alpha[feet] = 150
    alpha[muzzle] = 200
    alpha[fur] = 255
    alpha[dark] = 0
    # below the head the clothes' inner lines are drawn thick (waist band, collar gaps, buttons): as clear they read as
    # black blobs on the lock screen. Keep a thin line (like the cats'), the rest takes the nearest cloth's grey.
    mzr = muzzle & (yy < 360)
    chin = (int(np.nonzero(mzr.any(1))[0].max()) + 14) if mzr.any() else 345
    inner = ndimage.binary_erosion(m, iterations=10)
    dist, (iy, ix) = ndimage.distance_transform_edt(dark, return_indices=True)
    thick = dark & inner & (dist > THIN) & (yy > chin)
    alpha[thick] = alpha[iy[thick], ix[thick]]
    # a small dark blob (a button) is a solid mid grey with its edge
    labt, nt = ndimage.label(thick)
    for i in range(1, nt + 1):
        c = labt == i
        if c.sum() < 400:
            alpha[ndimage.binary_dilation(c, iterations=3) & dark & inner] = 140
    # small near-black bits of cloth (buttons, holes between toggles) read as black too: a mid grey
    low = (alpha > 0) & (alpha < 115) & (yy > chin) & ~dark
    labl, nl_ = ndimage.label(low | (dark & (yy > chin) & inner & (dist > 0.5)))
    if nl_:
        szl = ndimage.sum(np.ones_like(alpha), labl, range(1, nl_ + 1))
        small = np.isin(labl, [i + 1 for i, z in enumerate(szl) if z < 500]) & (yy > chin) & inner
        alpha[small] = 140
    # keep only what lies inside the outer dark outline (drops the light sticker fringe and specks around it)
    inside = ndimage.binary_fill_holes(ndimage.binary_closing(rgb.max(-1) < 90, iterations=2) | ndimage.binary_erosion(m, iterations=4))
    inside &= m
    lab, nl = ndimage.label(inside)
    if nl > 1:
        keep = np.argmax(ndimage.sum(inside, lab, range(1, nl + 1))) + 1
        sizes = ndimage.sum(inside, lab, range(1, nl + 1))
        inside = np.isin(lab, [i + 1 for i, z in enumerate(sizes) if z > 400])
    # the thin light sticker fringe on the very edge, outside the dark outline
    band = m & ~ndimage.binary_erosion(m, iterations=7)
    cand = band & ~(rgb.max(-1) < 120)
    labb, nb = ndimage.label(cand)
    edge_touch = np.unique(labb[ndimage.binary_dilation(~m, iterations=1) & cand])
    inside &= ~np.isin(labb, edge_touch[edge_touch > 0])
    alpha[~inside] = 0
    # the whole muzzle (inside its own outline) is one light grey
    mz = ndimage.binary_fill_holes(ndimage.binary_closing(muzzle, iterations=3))
    labm, nm = ndimage.label(mz)
    if nm:
        big = np.argmax(ndimage.sum(mz, labm, range(1, nm + 1))) + 1
        mz = labm == big
        alpha[mz & ~dark] = 200
    # little light specks inside the muzzle are highlights, not fur
    zone = (yy > 236) & (yy < 350) & (np.abs(xx - 240) < 70)
    hi = (alpha > 225) & zone
    labh, nh = ndimage.label(hi)
    if nh:
        sz = ndimage.sum(hi, labh, range(1, nh + 1))
        alpha[np.isin(labh, [i + 1 for i, z in enumerate(sz) if z < 200])] = 200
    # whatever is left outside the outermost outline ring (a thin edge line) goes too
    core = ndimage.binary_fill_holes(alpha > 0)
    lab2, n2 = ndimage.label(alpha > 0)
    if n2 > 1:
        sizes = ndimage.sum(alpha > 0, lab2, range(1, n2 + 1))
        alpha[np.isin(lab2, [i + 1 for i, z in enumerate(sizes) if z < 300])] = 0
    thin = (alpha > 0) & ~ndimage.binary_opening(alpha > 0, iterations=2)
    alpha[thin & ~ndimage.binary_erosion(m, iterations=10)] = 0
    # tidy the rim: pixels next to the clear outline take the median of their neighbours (no grey specks on the edge)
    zero = alpha == 0
    rim = ~zero & ndimage.binary_dilation(zero, iterations=10)
    med = ndimage.median_filter(np.where(zero, np.nan, alpha), size=7, mode='nearest') if False else None
    al = alpha.astype(float).copy(); al[zero] = np.nan
    from numpy.lib.stride_tricks import sliding_window_view as sw
    padded = np.pad(al, 3, constant_values=np.nan)
    win = sw(padded, (7, 7))
    ys_, xs_ = np.nonzero(rim)
    if len(ys_):
        vals = np.nan_to_num(np.nanmedian(win[ys_, xs_].reshape(len(ys_), -1), axis=1), nan=0)
        near = ndimage.binary_dilation(zero, iterations=3)[ys_, xs_]
        # right at the rim: always the neighbours' median; a little further in: only lone darker specks on fur
        take = near | ((vals >= 230) & (alpha[ys_, xs_] < vals - 40))
        alpha[ys_[take], xs_[take]] = vals[take]
    out = np.zeros(a.shape, np.uint8)
    out[..., :3] = 255
    out[..., 3] = alpha.astype(np.uint8)
    fig = Image.fromarray(out, 'RGBA')
    # the cats' ratio is (lock picture, outline already gone) / (standing sprite with its outline): size what is left
    # after the outline to scale x the standing height, and stand its bottom on the cats' line (the outline under
    # the feet would otherwise lift it ~7 px and shrink it ~3%)
    stand_h = im.getbbox()[3] - im.getbbox()[1]
    fig = fig.crop(fig.getbbox())
    scale = scale * stand_h / fig.height
    scale = min(scale, (botm - 2) / fig.height, 366 / fig.width)
    fig = fig.resize((max(1, round(fig.width * scale)), max(1, round(fig.height * scale))), Image.LANCZOS)
    canvas = Image.new('RGBA', (370, 480), (255, 255, 255, 0))
    x = round(cxm - fig.width / 2)
    y = round(botm - fig.height)
    x = min(max(x, 0), 370 - fig.width)
    canvas.alpha_composite(fig, (x, max(0, y))) if y >= 0 else canvas.alpha_composite(fig.crop((0, -y, fig.width, fig.height)), (x, 0))
    canvas.save(f'{OUT}/capy-lock-{k}.png')
    print(k, f'scale {scale:.3f} size {fig.size} at ({x},{y})')
