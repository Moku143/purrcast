"""capy-face: the stage-8 head (the head every hatless stage shares) cut from capy-stand-7-none at sprite scale.
capy-inline-K@2x/@3x: capy-lock-K's figure from the top down to 74% of its height (the hem of the top), at text
height 40 / 60 px, width to keep its shape - the same cut the cats' inline pictures use."""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0, __import__('os').path.dirname(__file__))
sys.path.insert(0, '.')
import sprite_kit as sk
from heads import head_mask

OUT = sys.argv[1]
SHEET = sys.argv[2]          # the composed standing sheet the sprites were built from
MW = float(sys.argv[3]) if len(sys.argv) > 3 else 105
import clean_outline as co
figs, rows, _ = sk.check(SHEET, verbose=False)
f, r = figs[7], rows[7]
hm, jaw, ot = head_mask(f, r)
fa = np.asarray(f['img'].convert('RGBA')).copy()
fa[..., 3] = np.where(hm & f['mask'], 255, 0)
im = Image.fromarray(fa, 'RGBA'); im = im.crop(im.getbbox())
k = MW / r['mw']
im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
pad = Image.new('RGBA', (im.width + 16, im.height + 16), (0, 0, 0, 0)); pad.alpha_composite(im, (8, 8))
o, _ = co.clean(np.asarray(pad))
face = Image.fromarray(o, 'RGBA'); face = face.crop(face.getbbox())
face.save(f'{OUT}/capy-face.png')
print('face', face.size)

for k in range(15):
    lk = Image.open(f'{OUT}/capy-lock-{k}.png').convert('RGBA')
    b = lk.getbbox()
    cut = b[1] + round(0.74 * (b[3] - b[1]))
    c = lk.crop((b[0], b[1], b[2], cut))
    for sc, H in (('2x', 40), ('3x', 60)):
        w = max(1, round(c.width * H / c.height))
        c.resize((w, H), Image.LANCZOS).save(f'{OUT}/capy-inline-{k}@{sc}.png')
print('inline done')
