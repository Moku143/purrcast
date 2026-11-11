"""Crop each chosen figure's face, scale to one muzzle width (60px -> x5), and draw the standard eye boxes
(x +/-0.52..0.83 mw, centre 0.10 mw above the muzzle top) so eye drift is visible."""
import sys
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, __import__('os').path.dirname(__file__))
import sprite_kit as sk

def run(out, specs, Z=5, MW=60):
    tiles = []
    for spec in specs:
        path, sel = spec.rsplit(':', 1)
        figs, rows, _ = sk.check(path, verbose=False)
        for s in sk._stages(sel):
            f, r = figs[s], rows[s]
            k = MW / r['mw']
            mc, mt = r['mc'] * k, r['mtop'] * k
            im = f['img'].resize((round(f['img'].width * k), round(f['img'].height * k)), Image.LANCZOS)
            box = (round(mc - 1.4 * MW), round(mt - 1.0 * MW), round(mc + 1.4 * MW), round(mt + 1.0 * MW))
            c = Image.new('RGB', (box[2] - box[0], box[3] - box[1]), (238, 241, 246))
            c.paste(im, (-box[0], -box[1]))
            c = c.resize((c.width * Z, c.height * Z), Image.NEAREST)
            d = ImageDraw.Draw(c)
            ox, oy = -box[0], -box[1]
            ey = (mt - 0.10 * MW + oy) * Z
            for sg in (-1, 1):
                xa, xb = mc + sg * 0.52 * MW + ox, mc + sg * 0.83 * MW + ox
                d.rectangle([min(xa, xb) * Z, ey - 0.06 * MW * Z, max(xa, xb) * Z, ey + 0.06 * MW * Z], outline=(0, 200, 255), width=2)
            d.line([(0, (mt + oy) * Z), (c.width, (mt + oy) * Z)], fill=(255, 0, 200), width=2)
            d.text((6, 6), f'#{s+1} {path.split("/")[-1][:18]}', fill=(0, 0, 0))
            tiles.append(c)
    W = sum(t.width for t in tiles)
    sheet = Image.new('RGB', (W, max(t.height for t in tiles)), 'white')
    x = 0
    for t in tiles:
        sheet.paste(t, (x, 0)); x += t.width
    sheet.save(out)

run(sys.argv[1], sys.argv[2:])
