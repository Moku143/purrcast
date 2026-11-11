"""capy-face: the stage-8 head (the head every hatless stage shares) cut from capy-stand-7-none at sprite scale.
capy-inline-K@2x/@3x: capy-lock-K's figure from the top down to 74% of its height (the hem of the top), at text
height 40 / 60 px, width to keep its shape - the same cut the cats' inline pictures use."""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__)))
sys.path.insert(0, '.')
import sprite_kit as sk
from heads import head_mask

OUT = sys.argv[1]
im = Image.open(f'{OUT}/capy-stand-7-none.png').convert('RGBA')
a = np.asarray(im)
m = a[..., 3] > 0
ys, xs = np.nonzero(m)
f = dict(box=(0, 0, im.width, im.height), mask=ndimage.binary_fill_holes(m), img=im.convert('RGB'))
r = sk.measure(f)
rgb = a[..., :3].astype(int)
mw, mt, mc = r['mw'], r['mtop'], r['mc']
h, s_, v = sk._hsv(rgb.astype(np.uint8))
headcol = ((h > 0.02) & (h < 0.12) & (s_ > 0.30) & (v > 0.45))
# the jaw: going down the middle, past the muzzle and the fur, the dark line
x = int(mc); y = int(mt + 0.5 * mw)
dark = rgb.max(-1) < 90
while not dark[y, x]: y += 1           # muzzle's lower outline
while dark[y, x]: y += 1
while not dark[y, x]: y += 1           # fur under the muzzle -> jaw line
jaw_top = y
while dark[y, x]: y += 1
jaw_bot = y
fur = headcol.copy(); fur[jaw_top:, :] = False
lab, _ = ndimage.label(fur)
comp = ndimage.binary_fill_holes(lab == lab[int(mt - 0.35 * mw), x])
hm = ndimage.binary_dilation(comp, iterations=int(0.12 * mw)) & m
hm[jaw_bot + 2:, :] = False
hm &= headcol | dark | (rgb.sum(-1) > 600)   # fur, outline, and the light fringe; never cloth
hm = ndimage.binary_fill_holes(hm)
face = a.copy()
face[~hm] = 0
fb = Image.fromarray(face, 'RGBA')
bb = fb.getbbox()
fb.crop((bb[0] - 2, bb[1] - 2, bb[2] + 2, bb[3] + 2)).save(f'{OUT}/capy-face.png')
print('face', fb.crop(bb).size)

for k in range(15):
    lk = Image.open(f'{OUT}/capy-lock-{k}.png').convert('RGBA')
    b = lk.getbbox()
    cut = b[1] + round(0.74 * (b[3] - b[1]))
    c = lk.crop((b[0], b[1], b[2], cut))
    for sc, H in (('2x', 40), ('3x', 60)):
        w = max(1, round(c.width * H / c.height))
        c.resize((w, H), Image.LANCZOS).save(f'{OUT}/capy-inline-{k}@{sc}.png')
print('inline done')
