"""Even, smooth outer outline for an app sprite (RGBA 480x560).

The image model draws the outer dark outline with uneven stair steps, lumps and a light 'sticker' fringe outside it.
This keeps everything inside as drawn and only redraws the rim:
  1. the figure = what lies inside the outer dark outline (the light fringe and stray specks outside are dropped),
  2. its silhouette is smoothed (blur + threshold) so the edge runs evenly,
  3. a dark band of one even width (the figure's own median outline width) is painted along that edge,
  4. light specks left on the seam under the jaw (head swap) are filled with the colour around them.
Usage: python3 clean_outline.py IN.png OUT.png [--jaw Y]   (or a directory: every *.png in it, in place)"""
import sys
import os
import numpy as np
from PIL import Image
from scipy import ndimage

OUTLINE = (16, 16, 28)


def figure_region(a):
    rgb = a[..., :3].astype(int)
    m = a[..., 3] > 0
    darkish = rgb.max(-1) < 110
    inside = ndimage.binary_fill_holes(ndimage.binary_closing(darkish, iterations=2) | ndimage.binary_erosion(m, iterations=4)) & m
    # the light fringe on the very edge, outside the dark outline
    band = m & ~ndimage.binary_erosion(m, iterations=7)
    cand = band & ~darkish
    lab, _ = ndimage.label(cand)
    touch = np.unique(lab[ndimage.binary_dilation(~m, iterations=1) & cand])
    inside &= ~np.isin(lab, touch[touch > 0])
    lab, n = ndimage.label(inside)
    if n > 1:
        sizes = ndimage.sum(inside, lab, range(1, n + 1))
        inside = np.isin(lab, [i + 1 for i, z in enumerate(sizes) if z > 400])
    return inside


def outline_width(region, rgb):
    dt = ndimage.distance_transform_edt(region)
    dark = rgb.max(-1) < 110
    for d in range(1, 20):
        ring = region & (dt > d - 1) & (dt <= d)
        if ring.sum() and dark[ring].mean() < 0.5:
            return max(3, d - 1)
    return 6


def clean(a, jaw=None, t=8, unit=4):
    a = a.copy()
    rgb = a[..., :3].astype(int)
    region = figure_region(a)
    # smooth silhouette
    soft = ndimage.gaussian_filter(region.astype(float), 2.2)
    S = ndimage.binary_fill_holes(soft > 0.5)
    if unit:
        # snap the silhouette to a regular pixel grid: even stair steps like hand-made pixel art
        H, W = S.shape
        gh, gw = -(-H // unit), -(-W // unit)
        pad = np.zeros((gh * unit, gw * unit)); pad[:H, :W] = soft
        g = pad.reshape(gh, unit, gw, unit).mean((1, 3)) > 0.5
        g = ndimage.binary_fill_holes(g)
        S = np.kron(g, np.ones((unit, unit), bool))[:H, :W]
    lab, n = ndimage.label(S)
    if n > 1:
        S = lab == (np.argmax(ndimage.sum(S, lab, range(1, n + 1))) + 1)
    if unit:
        k = max(1, round(t / unit))
        gb = g & ~ndimage.binary_erosion(g, iterations=k, border_value=0)
        band = np.kron(gb, np.ones((unit, unit), bool))[:S.shape[0], :S.shape[1]] & S
        dt = ndimage.distance_transform_edt(S)
        t = k * unit
    else:
        dt = ndimage.distance_transform_edt(S)
        band = S & (dt <= t)
    # colours inside: as drawn; where the smoothed edge grew over fringe/background, the nearest drawn colour
    valid = region & (a[..., 3] > 0)
    idx = ndimage.distance_transform_edt(~valid, return_distances=False, return_indices=True)
    out = np.zeros_like(a)
    fill = a[idx[0], idx[1]]
    out[S] = np.where(valid[S][:, None], a[S], fill[S])
    # thick lumps of the old outline just inside the new band: blend them into the band's even width by replacing
    # dark pixels that lie within t+3 of the edge AND are part of the old outer outline (connected to the old rim)
    old_dark = (rgb.max(-1) < 110) & region
    rim = old_dark & ~ndimage.binary_erosion(region, iterations=2)
    lab, _ = ndimage.label(old_dark)
    rim_lab = np.unique(lab[rim]); rim_lab = rim_lab[rim_lab > 0]
    outer_line = np.isin(lab, rim_lab)
    lump = outer_line & S & (dt > t) & (dt <= t + 3)
    # only where the old line is thicker than t there (its inner side is fur/cloth, not another line going inward)
    thick = ndimage.distance_transform_edt(old_dark) >= 1
    nondark = ~(rgb.max(-1) < 110) & region
    idx2 = ndimage.distance_transform_edt(~nondark, return_distances=False, return_indices=True)
    for _ in range(1):
        lump_ok = lump & thick & (ndimage.distance_transform_edt(~nondark) <= 3)
        out[lump_ok] = a[idx2[0][lump_ok], idx2[1][lump_ok]]
    # the old outline's soft (half-dark) inner edge just inside the new band: take the colour from further in
    ring = S & ~band & (dt <= t + 6) & ~ndimage.binary_erosion(region, iterations=16)
    mx = out[..., :3].astype(int).max(-1)
    deep = S & (dt > t + 6)
    if deep.any():
        idx4 = ndimage.distance_transform_edt(~deep, return_distances=False, return_indices=True)
        ref = out[idx4[0], idx4[1], :3].astype(int).max(-1)
        softp = ring & (mx >= 90) & (mx < ref - 35)
        out[softp] = out[idx4[0][softp], idx4[1][softp]]
    out[band, :3] = OUTLINE
    out[S, 3] = 255
    out[~S] = 0
    if jaw is not None:
        y0, y1 = max(0, jaw - 18), min(a.shape[0], jaw + 22)
        light = (out[..., :3].astype(int).sum(-1) > 560) & (out[..., :3].astype(int).min(-1) > 150) & S
        light[:y0] = False; light[y1:] = False
        lab, n = ndimage.label(light)
        if n:
            sizes = ndimage.sum(light, lab, range(1, n + 1))
            speck = np.isin(lab, [i + 1 for i, z in enumerate(sizes) if z < 60])
            okc = S & ~speck
            idx3 = ndimage.distance_transform_edt(~okc, return_distances=False, return_indices=True)
            out[speck] = out[idx3[0][speck], idx3[1][speck]]
    return out, t


if __name__ == '__main__':
    args = [x for x in sys.argv[1:] if not x.startswith('--')]
    jaw = None
    if '--jaw' in sys.argv:
        jaw = int(sys.argv[sys.argv.index('--jaw') + 1]); args = [x for x in args if x != str(jaw)]
    if os.path.isdir(args[0]):
        for fn in sorted(os.listdir(args[0])):
            if fn.endswith('.png'):
                p = os.path.join(args[0], fn)
                o, t = clean(np.asarray(Image.open(p).convert('RGBA')), jaw)
                Image.fromarray(o, 'RGBA').save(p)
                print(fn, 'outline', t)
    else:
        o, t = clean(np.asarray(Image.open(args[0]).convert('RGBA')), jaw)
        Image.fromarray(o, 'RGBA').save(args[1])
        print('outline', t)
