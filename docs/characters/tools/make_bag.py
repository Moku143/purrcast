"""capy-stand-K-bag: the cat's own folded umbrella (cat-stand-2-bag, lifted out), recoloured (moss-green folded
canopy, coral J handle) and put behind the capybara's right shoulder at one fixed place for all 15 stages; its exposed
edges get the same dark outline."""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

A = __import__('os').path.join(__import__('os').path.dirname(__file__), '../../../Shared/SharedAssets.xcassets')
SRC, OUT = sys.argv[1], sys.argv[2]
DX = int(sys.argv[3]) if len(sys.argv) > 3 else 16
OUTLINE = (16, 16, 28)
GREEN = [(58, 92, 44), (92, 136, 64), (140, 182, 98)]
CORAL = [(176, 58, 50), (242, 107, 91), (252, 168, 156)]

a = np.asarray(Image.open(f'{A}/cat-stand-2-none.imageset/cat-stand-2-none.png').convert('RGBA')).astype(int)
b = np.asarray(Image.open(f'{A}/cat-stand-2-bag.imageset/cat-stand-2-bag.png').convert('RGBA')).astype(int)
d = (np.abs(a - b).sum(-1) > 30) & (b[..., 3] > 0)
lab, n = ndimage.label(ndimage.binary_closing(d, iterations=1))
m = (lab == np.argmax(ndimage.sum(d, lab, range(1, n + 1))) + 1) & d
ys, xs = np.nonzero(m)
px = b[ys, xs].copy()
dark = px[:, :3].sum(-1) < 140
v = px[:, :3].max(-1)
q1, q2 = np.percentile(v[~dark], [33, 75])
lv = np.where(v < q1, 0, np.where(v < q2, 1, 2))
y_hook = ys.min() + 0.27 * (ys.max() - ys.min())
for i in np.nonzero(~dark)[0]:
    px[i, :3] = (CORAL if ys[i] < y_hook else GREEN)[lv[i]]
px[dark, :3] = OUTLINE

for k in range(15):
    capy = np.asarray(Image.open(f'{SRC}/capy-stand-{k}-none.png').convert('RGBA')).astype(int)
    fig = capy[..., 3] > 0
    core = ndimage.binary_erosion(fig, iterations=2)          # the figure without its thin light fringe
    out = capy.copy()
    tx = xs + DX
    ok = (tx >= 0) & (tx < out.shape[1])
    U = np.zeros(fig.shape, bool)
    yy, xx, pp = ys[ok], tx[ok], px[ok]
    put = ~core[yy, xx]
    out[yy[put], xx[put]] = pp[put]
    U[yy[put], xx[put]] = True
    # outline where the umbrella meets empty background or the figure's light fringe
    edge = U & ~ndimage.binary_erosion(U, iterations=1)
    nb = ndimage.binary_dilation(~U & ~core, iterations=1)
    out[edge & nb] = OUTLINE + (255,)
    Image.fromarray(out.astype(np.uint8), 'RGBA').save(f'{OUT}/capy-stand-{k}-bag.png')
