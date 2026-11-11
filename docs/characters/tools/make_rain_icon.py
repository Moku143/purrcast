"""AppIcon-rain-NAME + iconpick-rain-NAME the way the cats' are made: the stage-8 umbrella sprite at 1.5x (nearest
neighbour) standing on the rainy sky, feet at y 939, the head's centre (anchors.json head_cx[8]) in the middle of the icon.
The sky is read back from the three cats' rain icons (identical outside each cat); the few pixels every cat hides and
the new character does not cover take the colour of the nearest sky pixel on the same row, skipping rain streaks
(it is dry under the umbrella).
Usage: make_rain_icon.py NAME UMBRELLA_SPRITE.png OUT_DIR"""
import json
import os
import sys
import glob
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
APP = os.path.join(ROOT, 'Purrcast', 'Resources', 'Assets.xcassets')
SHARED = os.path.join(ROOT, 'Shared', 'SharedAssets.xcassets')
OFF = {'cat': (146, 108), 'abys': (142, 110), 'brit': (136, 110)}   # where each cat's stage-8 sprite sits (fitted)
S = 1.5


def sprite_at(p, ox, oy):
    sp = Image.open(p).convert('RGBA')
    sp = sp.resize((round(sp.width * S), round(sp.height * S)), Image.NEAREST)
    a = np.zeros((1024, 1024, 4), np.uint8)
    h, w = min(sp.height, 1024 - oy), min(sp.width, 1024 - ox)
    a[oy:oy + h, ox:ox + w] = np.asarray(sp)[:h, :w]
    return a


def sky():
    bg = np.zeros((1024, 1024, 3), np.uint8)
    known = np.zeros((1024, 1024), bool)
    for n, (ox, oy) in OFF.items():
        ic = np.asarray(Image.open(f'{APP}/AppIcon-rain-{n}.appiconset/icon-1024.png').convert('RGB'))
        m = sprite_at(glob.glob(f'{SHARED}/{n}-stand-8-umbrella.imageset/*.png')[0], ox, oy)[..., 3] > 0
        free = ~ndimage.binary_dilation(m, iterations=3)
        new = free & ~known
        bg[new] = ic[new]
        known |= free
    return bg, known


if __name__ == '__main__':
    name, umb, out = sys.argv[1:4]
    bg, known = sky()
    a = np.asarray(Image.open(umb).convert('RGBA'))
    m = a[..., 3] > 0
    feet = np.nonzero(m.any(1))[0].max()
    hcx = json.load(open(os.path.join(ROOT, 'Shared', 'Data', 'anchors.json')))[name]['head_cx'][8]
    ox = int(round(512 - S * hcx))
    oy = int(round(939 - S * feet))
    fig = sprite_at(umb, ox, oy)
    cover = fig[..., 3] > 0
    # fill what is still unknown and shows: nearest known sky pixel on the row that is not a rain streak
    lum = bg.astype(int).sum(-1)
    for y in np.unique(np.nonzero(~known & ~cover)[0]):
        row_known = np.nonzero(known[y])[0]
        if not len(row_known):
            continue
        base = np.median(lum[y, row_known])
        good = row_known[lum[y, row_known] < base + 60]
        for x in np.nonzero(~known[y] & ~cover[y])[0]:
            j = good[np.argmin(np.abs(good - x))]
            bg[y, x] = bg[y, j]
    icon = Image.fromarray(bg, 'RGB').convert('RGBA')
    icon.alpha_composite(Image.fromarray(fig, 'RGBA'))
    icon = icon.convert('RGB')
    os.makedirs(out, exist_ok=True)
    icon.save(f'{out}/AppIcon-rain-{name}.png')
    icon.resize((240, 240), Image.LANCZOS).save(f'{out}/iconpick-rain-{name}.png')
    print('rain icon', name, 'sprite at', (ox, oy), 'filled', int((~known & ~cover).sum()), 'px')
