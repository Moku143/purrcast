"""Copy a finished character's app pictures into the asset catalogs, the same way the cats' are laid out.
  SRC holds NAME-stand-{0..14}-{none,bag,umbrella}.png, NAME-lock-{0..14}.png, NAME-inline-{0..14}@2x/@3x.png,
  NAME-face.png; optional icons dir with AppIcon-sun-blue-NAME.png, AppIcon-sun-peach-NAME.png, AppIcon-rain-NAME.png
  and iconpick-*.png. Also writes the character's anchors (head top, umbrella top, head centre) into anchors.json.
Usage: install_sprites.py NAME SRC [ICONS]"""
import sys
import os
import json
import shutil
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
SHARED = os.path.join(ROOT, 'Shared', 'SharedAssets.xcassets')
APP = os.path.join(ROOT, 'Purrcast', 'Resources', 'Assets.xcassets')
INFO = {"version": 1, "author": "xcode"}


def imageset(cat, name, src, template=False):
    d = os.path.join(cat, name + '.imageset'); os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):
        os.remove(os.path.join(d, f))
    if isinstance(src, dict):          # {scale: path}
        imgs = []
        for sc, p in src.items():
            fn = f'{name}@{sc}.png'; shutil.copy(p, os.path.join(d, fn))
            imgs.append({"idiom": "universal", "filename": fn, "scale": sc})
    else:
        fn = name + '.png'; shutil.copy(src, os.path.join(d, fn))
        imgs = [{"idiom": "universal", "filename": fn}]
    c = {"images": imgs, "info": INFO}
    if template:
        c["properties"] = {"template-rendering-intent": "template"}
    json.dump(c, open(os.path.join(d, 'Contents.json'), 'w'), indent=1)


def appicon(name, src):
    d = os.path.join(APP, name + '.appiconset'); os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):
        os.remove(os.path.join(d, f))
    Image.open(src).convert('RGB').resize((1024, 1024), Image.LANCZOS).save(os.path.join(d, 'icon-1024.png'))
    json.dump({"images": [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
               "info": {"author": "xcode", "version": 1}}, open(os.path.join(d, 'Contents.json'), 'w'), indent=1)


def anchors(name, src):
    head_top, umb_top, head_cx, box = [], [], [], []
    for k in range(15):
        a = np.asarray(Image.open(os.path.join(src, f'{name}-stand-{k}-none.png')).convert('RGBA'))[..., 3] > 0
        u = np.asarray(Image.open(os.path.join(src, f'{name}-stand-{k}-umbrella.png')).convert('RGBA'))[..., 3] > 0
        ys = np.nonzero(a.any(1))[0]
        top = int(ys.min())
        band = a[top:top + 120]; bx = np.nonzero(band.any(0))[0]
        head_top.append(top); umb_top.append(int(np.nonzero(u.any(1))[0].min()))
        head_cx.append(round(float(bx.min() + bx.max()) / 2 * 2) / 2)
        yy, xx = np.nonzero(a)
        box.append([int(xx.min()), int(xx.max()), int(yy.min()), int(yy.max())])
    p = os.path.join(ROOT, 'Shared', 'Data', 'anchors.json')
    d = json.load(open(p))
    d[name] = {"head_top": head_top, "umb_top": umb_top, "head_cx": head_cx, "box": box}
    open(p, 'w').write(json.dumps(d))
    return d[name]


if __name__ == '__main__':
    name, src = sys.argv[1], sys.argv[2]
    icons = sys.argv[3] if len(sys.argv) > 3 else None
    for k in range(15):
        for kind in ('none', 'bag', 'umbrella'):
            imageset(SHARED, f'{name}-stand-{k}-{kind}', os.path.join(src, f'{name}-stand-{k}-{kind}.png'))
        imageset(SHARED, f'{name}-lock-{k}', os.path.join(src, f'{name}-lock-{k}.png'))
        imageset(SHARED, f'{name}-inline-{k}', {s: os.path.join(src, f'{name}-inline-{k}@{s}.png') for s in ('2x', '3x')}, template=True)
    imageset(SHARED, f'{name}-face', os.path.join(src, f'{name}-face.png'))
    print('anchors', anchors(name, src))
    if icons:
        for kind in ('sun-blue', 'sun-peach', 'rain'):
            p = os.path.join(icons, f'AppIcon-{kind}-{name}.png')
            if os.path.exists(p):
                appicon(f'AppIcon-{kind}-{name}', p)
                imageset(APP, f'iconpick-{kind}-{name}', os.path.join(icons, f'iconpick-{kind}-{name}.png'))
                print('icon', kind)
