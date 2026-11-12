"""capy-lock-K from lock-screen pictures the image model drew (white figure on dark navy, like the cats' lock sets):
the navy becomes clear and every pixel's brightness above the navy becomes its alpha on pure white, so dark-navy eye
lines and nostrils are clear and the greys keep their shading, exactly how the cats' lock pictures look on the lock
screen. Size and place per stage as the cats (lock height / standing height, centre x, foot line), from the
character's own standing sprite.
Usage: lock_from_pictures.py STAND_DIR OUT_DIR PIC0 PIC1 ... (PICk -> capy-lock-k.png)"""
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

A = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../../Shared/SharedAssets.xcassets')


def lum(a):
    return 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]


def bbox(p):
    return Image.open(p).convert('RGBA').getbbox()


def convert(pic):
    a = np.asarray(Image.open(pic).convert('RGB')).astype(float)
    # the navy = the commonest dark colour along the picture's border
    border = np.concatenate([a[:8].reshape(-1, 3), a[-8:].reshape(-1, 3), a[:, :8].reshape(-1, 3), a[:, -8:].reshape(-1, 3)])
    navy = np.median(border, axis=0)
    d = np.abs(a - navy).sum(-1)
    fig = ndimage.binary_closing(d > 45, iterations=3)
    lab, n = ndimage.label(fig)
    sizes = ndimage.sum(fig, lab, range(1, n + 1))
    fig = ndimage.binary_fill_holes(lab == (int(np.argmax(sizes)) + 1))
    ln = lum(navy[None, None])[0, 0]
    al = np.clip((lum(a) - ln) / (255 - ln), 0, 1) * 255
    al[~fig] = 0
    out = np.zeros(a.shape[:2] + (4,), np.uint8)
    out[..., :3] = 255
    out[..., 3] = al.round().astype(np.uint8)
    im = Image.fromarray(out, 'RGBA')
    return im.crop(Image.fromarray(fig.astype(np.uint8) * 255).getbbox())


if __name__ == '__main__':
    sdir, out = sys.argv[1:3]
    os.makedirs(out, exist_ok=True)
    for k, pic in enumerate(sys.argv[3:]):
        sc, cx, bot = [], [], []
        for n in ('cat', 'abys', 'brit'):
            s = bbox(f'{A}/{n}-stand-{k}-none.imageset/{n}-stand-{k}-none.png')
            l = bbox(f'{A}/{n}-lock-{k}.imageset/{n}-lock-{k}.png')
            sc.append((l[3] - l[1]) / (s[3] - s[1])); cx.append((l[0] + l[2]) / 2); bot.append(l[3])
        sb = bbox(f'{sdir}/capy-stand-{k}-none.png')
        target_h = float(np.mean(sc)) * (sb[3] - sb[1])
        fig = convert(pic)
        s = min(target_h / fig.height, (np.mean(bot) - 2) / fig.height, 366 / fig.width)
        fig = fig.resize((max(1, round(fig.width * s)), max(1, round(fig.height * s))), Image.LANCZOS)
        canvas = Image.new('RGBA', (370, 480), (255, 255, 255, 0))
        x = min(max(round(np.mean(cx) - fig.width / 2), 0), 370 - fig.width)
        y = max(0, round(np.mean(bot) - fig.height))
        canvas.alpha_composite(fig, (x, y))
        canvas.save(f'{out}/capy-lock-{k}.png')
        print(k, 'size', fig.size, 'at', (x, y))
