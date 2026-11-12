"""Lock-screen picture (white on navy): remove a white rim the model drew round the figure where the black outline used
to be. A pixel goes (becomes navy) when it is near-white, lies within R px of the background, and the figure just
inside it (R+6 px further in, along the inward direction) is grey - so white parts that reach the edge (a fur ring,
mittens, boots) stay.
Usage: drop_white_rim.py IN.png OUT.png [R=22]"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

src, dst = sys.argv[1], sys.argv[2]
R = int(sys.argv[3]) if len(sys.argv) > 3 else 22
a = np.asarray(Image.open(src).convert('RGB')).astype(int)
border = np.concatenate([a[:8].reshape(-1, 3), a[-8:].reshape(-1, 3), a[:, :8].reshape(-1, 3), a[:, -8:].reshape(-1, 3)])
navy = np.median(border, axis=0)
fig = ndimage.binary_closing(np.abs(a - navy).sum(-1) > 45, iterations=2)
fig = ndimage.binary_fill_holes(fig)
lum = 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
dist = ndimage.distance_transform_edt(fig)
gy, gx = np.gradient(ndimage.gaussian_filter(dist, 3))
n = np.hypot(gx, gy) + 1e-6
ys, xs = np.nonzero(fig & (dist <= R) & (lum > 225))
iy = np.clip(np.round(ys + gy[ys, xs] / n[ys, xs] * (R + 6 - dist[ys, xs])).astype(int), 0, a.shape[0] - 1)
ix = np.clip(np.round(xs + gx[ys, xs] / n[ys, xs] * (R + 6 - dist[ys, xs])).astype(int), 0, a.shape[1] - 1)
inner = ndimage.uniform_filter(lum, 5)[iy, ix]
cut = inner < 215
out = a.copy()
C = np.zeros(fig.shape, bool)
C[ys[cut], xs[cut]] = True
# the rim's soft edges on both sides (darker towards the navy, lighter towards the coat): pixels next to the cut,
# in the rim band, that differ from the coat just inside them
by, bx = np.nonzero(fig & (dist <= R + 4))
jy = np.clip(np.round(by + gy[by, bx] / n[by, bx] * (R + 6 - dist[by, bx])).astype(int), 0, a.shape[0] - 1)
jx = np.clip(np.round(bx + gx[by, bx] / n[by, bx] * (R + 6 - dist[by, bx])).astype(int), 0, a.shape[1] - 1)
inn = ndimage.uniform_filter(lum, 5)[jy, jx]
soft = np.zeros(fig.shape, bool)
soft[by, bx] = (inn < 215) & (np.abs(lum[by, bx] - inn) > 25)
C |= ndimage.binary_dilation(C, iterations=3) & soft     # only right next to the white (a light sole stays)
# white bits left on the edge (corners where the inward look hit the fur ring)
rest = fig & ~C & (dist <= R + 4) & (lum > 235)
lab, k = ndimage.label(rest)
for i in range(1, k + 1):
    c = lab == i
    if c.sum() < 900 and (ndimage.binary_dilation(c, iterations=2) & C).any():
        C |= c
# thin lines left outside the new edge (the rim's outer soft edge): not part of the opened main figure
nf = fig & ~C
op = ndimage.binary_opening(nf, iterations=3)
lab, k = ndimage.label(op)
main = lab == (np.argmax(ndimage.sum(op, lab, range(1, k + 1))) + 1)
main = ndimage.binary_dilation(main, iterations=3) & nf
C |= nf & ~main & (dist <= R + 8)
# a cut with kept figure further out (a gash inside a white scarf stripe that reaches the edge) is put back
for _ in range(2):
    cy, cx = np.nonzero(C)
    keepfig = fig & ~C
    back = np.zeros(len(cy), bool)
    for step in range(3, R + 6, 2):
        oy = np.clip(np.round(cy - gy[cy, cx] / n[cy, cx] * step).astype(int), 0, a.shape[0] - 1)
        ox = np.clip(np.round(cx - gx[cy, cx] / n[cy, cx] * step).astype(int), 0, a.shape[1] - 1)
        back |= keepfig[oy, ox] & (step < dist[cy, cx] + 2)
    C[cy[back], cx[back]] = False
# lone white specks left in the navy
nf = fig & ~C
lab, k = ndimage.label(nf)
sz = ndimage.sum(nf, lab, range(1, k + 1))
C |= np.isin(lab, [i + 1 for i, z in enumerate(sz) if z < 200])
out[C] = navy
Image.fromarray(out.astype(np.uint8)).save(dst)
print('removed', int(cut.sum()), 'px of', len(ys))
