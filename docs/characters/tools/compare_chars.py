"""One picture to check a new character against the cats at app size, straight from the asset catalogs:
per stage, a row each of standing / bag / umbrella (new character, then the three cats), the lock pictures on the
lock screen's dark grey, the clock-line pictures, and the faces.
Usage: compare_chars.py NAME OUT.png [STAGES e.g. 0,4,8,12]"""
import sys
import os
import glob
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
A = os.path.join(ROOT, 'Shared', 'SharedAssets.xcassets')
SKY = (226, 236, 248, 255)


def img(name):
    p = glob.glob(f'{A}/{name}.imageset/*.png')
    p = [q for q in p if '@3x' in q] or p
    return Image.open(sorted(p)[-1]).convert('RGBA')


name, out = sys.argv[1], sys.argv[2]
stages = [int(s) for s in sys.argv[3].split(',')] if len(sys.argv) > 3 else list(range(15))
chars = [name, 'cat', 'abys', 'brit']
W, H = 120, 140
cols = len(stages)
rows = 3 * len(chars)
sheet = Image.new('RGBA', (cols * W + 60, rows * H + 2 * 160 + 140), SKY)
d = ImageDraw.Draw(sheet)
y = 0
for kind in ('none', 'bag', 'umbrella'):
    for c in chars:
        d.text((4, y + 4), f'{c}\n{kind}', fill=(60, 70, 90, 255))
        for i, k in enumerate(stages):
            sp = img(f'{c}-stand-{k}-{kind}').resize((W, H), Image.LANCZOS)
            sheet.alpha_composite(sp, (60 + i * W, y))
        y += H
LW, LH = 74, 96
dark = Image.new('RGBA', (cols * W, 2 * LH + 20), (52, 56, 66, 255))
for j, c in enumerate([name, 'abys']):
    for i, k in enumerate(stages):
        lk = img(f'{c}-lock-{k}').resize((LW, LH), Image.LANCZOS)
        dark.alpha_composite(lk, (i * W + 20, 10 + j * LH))
sheet.alpha_composite(dark, (60, y)); y += dark.height + 10
for j, c in enumerate([name, 'abys']):
    for i, k in enumerate(stages):
        il = img(f'{c}-inline-{k}')
        t = Image.new('RGBA', il.size, (40, 44, 52, 255)); t.alpha_composite(il)
        sheet.alpha_composite(t, (60 + i * W + j * 56, y))
y += 70
for j, c in enumerate(chars):
    f = img(f'{c}-face'); f.thumbnail((110, 100))
    sheet.alpha_composite(f, (60 + j * 130, y))
sheet.save(out)
print(out, sheet.size)
