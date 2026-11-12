"""The capybara's head, cut at full resolution from a single-figure picture with a blue top (base-A): everything of
the figure above the first row of clothes under the muzzle. Used for the face picture and the sun icons.
Usage: face_hi.py PICTURE OUT.png"""
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_singles as bs  # noqa: E402
import sprite_kit as sk  # noqa: E402


def head(path):
    a, m, top, feet = bs.figure(path)
    r = sk.measure({'img': Image.fromarray(a.astype(np.uint8)), 'mask': m}, ref_col=bs.MUZ)
    x, y = int(r['mc']), int(r['mbot'])

    def headcol(c):
        h, s, v = sk._hsv(np.array([[c]], np.uint8))
        return c.max() < 90 or (0.02 < h[0, 0] < 0.12 and s[0, 0] > 0.3)
    while headcol(a[y, x]):
        y += 1
    hm = m.copy()
    hm[y:] = False
    h, s, v = sk._hsv(a.astype(np.uint8))
    hc = (a.max(-1) < 90) | ((h > 0.02) & (h < 0.12) & (s > 0.3))
    hm &= hc                                    # no clothes beside the jaw
    hm = ndimage.binary_opening(hm, iterations=2)
    lab, _ = ndimage.label(hm)
    hm = ndimage.binary_fill_holes(lab == lab[int(r['mtop']), x])
    # only the head's own outline: as thick as at the top of the head, around the fur (not the shoulders' lines)
    col = np.nonzero(m[:, x])[0]
    t0 = col.min()
    while a[t0, x].max() >= 90:              # the soft edge above the outline
        t0 += 1
    th = 0
    while a[t0 + th, x].max() < 90:
        th += 1
    furr = ndimage.binary_fill_holes(hm & ~(a.max(-1) < 90))
    hm &= ndimage.binary_dilation(furr, iterations=th + 3)
    print('outline', th)
    rgba = np.dstack([a, np.where(hm, 255, 0)]).astype(np.uint8)
    im = Image.fromarray(rgba)
    return im.crop(im.getbbox())


if __name__ == '__main__':
    im = head(sys.argv[1])
    im.save(sys.argv[2])
    print(sys.argv[2], im.size)
