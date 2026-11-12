"""AppIcon-sun-{blue,peach}-NAME + iconpick-sun-*: the Abyssinian's sun icon with its face painted out (the sun disc is
one flat yellow) and the new character's head put in the middle of the disc, as wide as the face it replaces
(or --w px).
Usage: make_sun_icon.py NAME HEAD.png OUT_DIR [--w 360]"""
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
APP = os.path.join(ROOT, 'Purrcast', 'Resources', 'Assets.xcassets')
SUN = np.array([255, 205, 60])
OUTLINE = np.array([14, 12, 22])


def shrink(head, w):
    a = np.asarray(head.convert('RGBA')).copy()
    m = a[..., 3] > 127
    a[~m, :3] = OUTLINE                      # the soft edge mixes with the outline, not with a light colour
    h = round(head.height * w / head.width)
    rgb = Image.fromarray(a[..., :3]).resize((w, h), Image.LANCZOS)
    al = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).resize((w, h), Image.LANCZOS))
    return Image.fromarray(np.dstack([np.asarray(rgb), np.where(al >= 128, 255, 0)]).astype(np.uint8), 'RGBA')


if __name__ == '__main__':
    name, headp, out = sys.argv[1:4]
    os.makedirs(out, exist_ok=True)
    head = Image.open(headp)
    for v in ('blue', 'peach'):
        a = np.asarray(Image.open(f'{APP}/AppIcon-sun-{v}-abys.appiconset/icon-1024.png').convert('RGB')).astype(int)
        yellow = np.abs(a - SUN).sum(-1) < 30
        disc = ndimage.binary_fill_holes(ndimage.binary_closing(yellow, iterations=3))
        lab, n = ndimage.label(disc)
        disc = lab == (np.argmax(ndimage.sum(disc, lab, range(1, n + 1))) + 1)
        face = disc & ~yellow
        ys, xs = np.nonzero(face)
        fw = xs.max() - xs.min()
        dy, dx = np.nonzero(disc)
        cx, cy = (dx.min() + dx.max()) / 2, (dy.min() + dy.max()) / 2
        b = a.copy()
        b[face] = SUN
        w = int(sys.argv[sys.argv.index('--w') + 1]) if '--w' in sys.argv else int(fw)
        hd = shrink(head, w)
        icon = Image.fromarray(b.astype(np.uint8)).convert('RGBA')
        icon.alpha_composite(hd, (int(round(cx - hd.width / 2)), int(round(cy - hd.height / 2))))
        icon = icon.convert('RGB')
        icon.save(f'{out}/AppIcon-sun-{v}-{name}.png')
        icon.resize((240, 240), Image.LANCZOS).save(f'{out}/iconpick-sun-{v}-{name}.png')
        print(v, 'old face width', fw, 'head', hd.size, 'disc centre', (cx, cy))
