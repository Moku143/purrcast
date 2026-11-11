"""Remove only the light 'sticker' fringe some image-model drawings leave outside the dark outline of an app sprite
(RGBA). Nothing is redrawn: light pixels on the very edge that lie outside the outline become transparent, and stray
specks off the figure go too. Usage: drop_fringe.py DIR_OR_PNG ..."""
import sys
import os
import numpy as np
from PIL import Image
from scipy import ndimage


def drop(a):
    a = a.copy()
    m = a[..., 3] > 0
    rgb = a[..., :3].astype(int)
    light = m & (rgb.min(-1) > 170) & ((rgb.max(-1) - rgb.min(-1)) < 40)      # whitish, not cloth colours
    band = m & ~ndimage.binary_erosion(m, iterations=6)
    cand = light & band
    lab, _ = ndimage.label(cand)
    touch = np.unique(lab[ndimage.binary_dilation(~m, iterations=1) & cand])
    fr = np.isin(lab, touch[touch > 0])
    # a light region that is wide (a white shirt reaching the edge without outline) is cloth, keep it
    for t in touch[touch > 0]:
        reg = lab == t
        if ndimage.binary_erosion(reg, iterations=3).any():
            fr &= ~reg
    a[fr, 3] = 0
    m = a[..., 3] > 0
    lab, n = ndimage.label(m)
    if n > 1:
        sizes = ndimage.sum(m, lab, range(1, n + 1))
        small = np.isin(lab, [i + 1 for i, z in enumerate(sizes) if z < 60])
        a[small, 3] = 0
    return a, int(fr.sum())


if __name__ == '__main__':
    files = []
    for p in sys.argv[1:]:
        files += [os.path.join(p, f) for f in sorted(os.listdir(p)) if f.endswith('.png')] if os.path.isdir(p) else [p]
    for p in files:
        a, n = drop(np.asarray(Image.open(p).convert('RGBA')))
        Image.fromarray(a, 'RGBA').save(p)
        print(os.path.basename(p), 'fringe px', n)
