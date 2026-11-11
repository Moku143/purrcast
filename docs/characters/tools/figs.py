"""Find the 15 figures in a sheet as connected blobs (robust to uneven grids and stitch seams).

figures(path, lock=False) -> list of 15 dicts in reading order:
  box (x0,y0,x1,y1), feet (lowest row), cx (body centre from the lower third), img (RGB crop)
"""
import numpy as np
from PIL import Image
from scipy import ndimage


def mask_of(arr, lock=False):
    r, g, b = arr[..., 0].astype(int), arr[..., 1].astype(int), arr[..., 2].astype(int)
    if lock:
        return (r + g + b) > 330  # light figure on navy
    bg = np.array([236, 240, 245])
    d = np.abs(arr.astype(int) - bg).sum(-1)
    return d > 40


def figures(path, lock=False):
    im = Image.open(path).convert('RGB')
    arr = np.asarray(im)
    m = mask_of(arr, lock)
    m = ndimage.binary_closing(m, iterations=2)
    lab, n = ndimage.label(m)
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    order = np.argsort(sizes)[::-1][:15]
    blobs = []
    for idx in order:
        sl = ndimage.find_objects((lab == idx + 1).astype(int))[0]
        y0, y1, x0, x1 = sl[0].start, sl[0].stop, sl[1].start, sl[1].stop
        blobs.append((y0, y1, x0, x1, idx + 1))
    # reading order: cluster rows by vertical centre
    blobs.sort(key=lambda b: (b[0] + b[1]) / 2)
    rows = [blobs[i:i + 5] for i in range(0, 15, 5)]
    out = []
    for row in rows:
        for y0, y1, x0, x1, li in sorted(row, key=lambda b: (b[2] + b[3]) / 2):
            sub = (lab[y0:y1, x0:x1] == li)
            ys, xs = np.nonzero(sub)
            feet = ys.max()
            low = ys > feet - 0.25 * (y1 - y0)
            cx = int(np.median(xs[low]))
            out.append(dict(box=(x0, y0, x1, y1), feet=feet, cx=cx, mask=sub,
                            img=im.crop((x0, y0, x1, y1))))
    return out
