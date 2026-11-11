"""Guide picture for the image model: a red vertical line through each umbrella's shaft, drawn up through the canopy
to above the tip knob, so the model can move the canopy until its knob sits on the line. Usage: shaft_guide.py IN OUT"""
import sys
import os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sprite_kit as sk

a = np.asarray(Image.open(sys.argv[1]).convert('RGB')).astype(int)
h, s, v = sk._hsv(a.astype(np.uint8))
flat = a.reshape(-1, 3); bgc = np.median(flat[flat.sum(1) > 600], axis=0)
offbg = np.abs(a - bgc).sum(-1) > 30
coral = ((h < 0.045) | (h > 0.95)) & (s > 0.30) & (v > 0.35)
grey = (s < 0.12) & (v > 0.50) & (v < 0.93)
lab, n = ndimage.label(coral)
sizes = ndimage.sum(coral, lab, range(1, n + 1))
im = Image.fromarray(a.astype(np.uint8)); d = ImageDraw.Draw(im)
for c in [i + 1 for i in np.argsort(sizes)[::-1] if sizes[i] > 0.25 * sizes.max()]:
    ys, xs = np.nonzero(lab == c); top, rim, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    band = grey[rim + 8:rim + 70, x0:x1 + 1] & offbg[rim + 8:rim + 70, x0:x1 + 1]
    cols = band.sum(0); good = np.nonzero(cols >= 0.6 * cols.max())[0]
    sx = good.mean() + x0
    d.line([(sx, max(0, top - 45)), (sx, rim + 60)], fill=(230, 0, 0), width=4)
    print(f'shaft at x {sx:.0f}, canopy centre {(x0 + x1) / 2:.0f}')
im.save(sys.argv[2])
