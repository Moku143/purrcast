"""Umbrella sprites for a character from a 3-figure picture where only the viewer-left arm was redrawn (raised, the
paw holding a stick at the chest).

Each figure is lined up with its finished standing sprite (scale and place from the muzzle and the feet, then a small
search on the unchanged right half). The standing sprite stays as it is; only the changed left arm/side is taken from
the picture, its colours snapped to the sprite's own. The umbrella is the cats' shared canopy in the character's
colour (canopy layer PNG, knob centred at Sprite.umbrellaTipX = 195.5), its shaft straight down from the knob:
behind the head, in front of the body below the chin, the paw over it.

Usage: umb_build.py PICTURE T SPRITE_DIR CANOPY.png OUT_DIR [--debug DIR] [--paw K:R,G,B]
       umb_build.py PICTURE K SPRITE_DIR CANOPY.png OUT_DIR --single --front   (one figure = stage K; the shaft
       runs straight down from the knob in front of the face, the paw over it)
  T = 1..5: the picture holds stages 3(T-1) .. 3(T-1)+2."""
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sprite_kit as sk  # noqa: E402

MUZ = np.array([204, 111, 70])     # m13 capybara (the m5 one was 205,125,76 / fur 241,165,100)
FUR = (237, 143, 79)
TIP_X = 195.5
SHAFT = [(14, 12, 22), (14, 12, 22), (111, 116, 134), (150, 156, 174), (197, 200, 214), (227, 228, 235),
         (227, 228, 235), (197, 200, 214), (150, 156, 174), (120, 125, 144), (14, 12, 22), (14, 12, 22)]
SX0 = int(TIP_X - len(SHAFT) / 2 + 0.5)       # 190: the 12 shaft columns 190..201 centre on 195.5
PAW_Y = 378                                    # the guide circle's centre (sprite y)
PAW_R = 21


def as_fig(rgba):
    return {'img': Image.fromarray(rgba[..., :3]), 'mask': rgba[..., 3] > 0}


def warp(img, mask, s, ox, oy):
    """picture crop -> sprite frame: sprite (x, y) reads picture (s*x + ox, s*y + oy)."""
    data = (s, 0, ox, 0, s, oy)
    a = img.transform((480, 560), Image.AFFINE, data, resample=Image.BICUBIC, fillcolor=(255, 255, 255))
    m = Image.fromarray((mask * 255).astype(np.uint8)).transform((480, 560), Image.AFFINE, data,
                                                                 resample=Image.BILINEAR, fillcolor=0)
    return np.asarray(a).astype(int), np.asarray(m) > 127


def align(fig, orig):
    ro = sk.measure(as_fig(orig), ref_col=MUZ)
    rr = sk.measure(fig, ref_col=MUZ)
    if not ro or not rr:
        raise SystemExit('muzzle not found')
    s0 = (rr['feet'] - rr['mtop']) / (ro['feet'] - ro['mtop'])
    om = orig[..., 3] > 0
    stable = om.copy()
    stable[:, :int(ro['mc']) + 8] = False            # the right half never changes
    stable[ro['feet'] - 6:] = False
    ys, xs = np.nonzero(stable)
    sel = slice(None, None, 3)
    ys, xs = ys[sel], xs[sel]
    oc = orig[ys, xs, :3].astype(int)
    best = None
    for s in s0 * np.linspace(0.97, 1.03, 13):
        for dx in np.arange(-4, 4.5, 1):
            for dy in np.arange(-4, 4.5, 1):
                ox = rr['mc'] - s * ro['mc'] + dx
                oy = rr['mtop'] - s * ro['mtop'] + dy
                px = np.clip(np.round(s * xs + ox).astype(int), 0, fig['mask'].shape[1] - 1)
                py = np.clip(np.round(s * ys + oy).astype(int), 0, fig['mask'].shape[0] - 1)
                pc = np.asarray(fig['img']).astype(int)[py, px]
                e = np.abs(pc - oc).sum(-1).mean()
                if best is None or e < best[0]:
                    best = (e, s, ox, oy)
    return best, ro


HEAD = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'capy', 'umb', 'phead.png')


def head_sil(orig, ro):
    """The head's outline: the shared pixel head (every hatless stage wears it, the hat stages the same shape) put on
    the sprite muzzle on muzzle, plus everything above the eye line (ears, hats)."""
    ph = np.asarray(Image.open(HEAD).convert('RGBA'))
    rh = sk.measure(as_fig(ph), ref_col=MUZ)
    dx, dy = int(round(ro['mc'] - rh['mc'])), int(ro['mtop'] - rh['mtop'])
    m = np.zeros(orig.shape[:2], bool)
    ys, xs = np.nonzero(ph[..., 3] > 0)
    ys, xs = ys + dy, xs + dx
    ok = (ys >= 0) & (ys < m.shape[0]) & (xs >= 0) & (xs < m.shape[1])
    m[ys[ok], xs[ok]] = True
    top = orig[..., 3] > 0
    top[int(ro['mtop'] - 0.25 * ro['mw']):] = False
    return ndimage.binary_fill_holes(m | top)


def palette(orig, n=28):
    px = orig[orig[..., 3] > 0][:, :3].astype(float)
    from scipy.cluster.vq import kmeans2
    np.random.seed(1)
    c, _ = kmeans2(px[::7], n, minit='++', seed=1)
    return np.vstack([c, np.array(SHAFT, float)])


def snap(rgb, pal):
    d = ((rgb[:, None, :].astype(float) - pal[None]) ** 2).sum(-1)
    return pal[d.argmin(1)].round().astype(np.uint8)


def shaft_rows(out, y0, y1, x0=SX0):
    for y in range(max(0, y0), min(560, y1)):
        for j, c in enumerate(SHAFT):
            out[y, x0 + j] = (*c, 255)


def chin_row(orig, ro):
    """The first row of clothes under the head, straight down from the muzzle's middle."""
    rgb = orig[..., :3].astype(int)
    x = int(ro['mc'])
    dark = lambda c: c.max() < 90  # noqa: E731
    y = int(ro['mbot'])
    while y < 540 and not dark(rgb[y, x]):     # the muzzle's brown lower edge, the fur under it
        y += 1
    while y < 540 and dark(rgb[y, x]):         # the jaw line
        y += 1
    return y


def build(fig, orig, canopy, dbg=None, name='', paw_col=FUR, front=False):
    (err, s, ox, oy), ro = align(fig, orig)
    A, am = warp(fig['img'], fig['mask'], s, ox, oy)
    om = orig[..., 3] > 0
    mc, mtop, feet = int(ro['mc']), int(ro['mtop']), int(ro['feet'])
    # what the arm changed: pixels new to the figure, pixels gone (the hanging arm), and a clearly different colour
    # only in the box the raised arm can reach; the head, the hats and the right half keep the sprite's pixels
    if front:
        hm = np.zeros(orig.shape[:2], bool)
        hm[:chin_row(orig, ro)] = True
        hm &= orig[..., 3] > 0
    else:
        hm = head_sil(orig, ro)
    D = np.abs(A - orig[..., :3].astype(int)).sum(-1)
    yy, xx = np.mgrid[:560, :480]
    head = ndimage.binary_dilation(hm, iterations=3)
    # the raised arm may come up beside the head: anything that is not head, from the eye line down
    reach = (xx < TIP_X + PAW_R + 14) & (yy > mtop) & (yy < feet - 30) & ~head
    changed = ((am & ~om) | (om & ~am) | ((D > 90) & am & om)) & reach
    changed = ndimage.binary_opening(changed, iterations=1)
    region = ndimage.binary_dilation(changed, iterations=4) & reach
    lab, n = ndimage.label(region)
    keep = np.zeros_like(region)
    near_paw = (xx - TIP_X) ** 2 + (yy - PAW_Y) ** 2 < (PAW_R + 18) ** 2
    for i in range(1, n + 1):
        c = lab == i
        if c.sum() > 150 or (c & near_paw).any():
            keep |= c
    keep = ndimage.binary_fill_holes(keep) & reach
    out = orig.copy()
    if front:
        # just outside the taken region: sprite pixels the picture does not have there (the old shoulder's outline)
        rim = ndimage.binary_dilation(keep, iterations=8) & ~keep & reach & om & ~am & (xx < TIP_X)
        out[rim] = 0
    pal = palette(orig)
    take = keep & am
    out[keep & ~am] = 0
    out[take, :3] = snap(A[take][:, :3], pal)
    out[take, 3] = 255
    # the picture's own stick: tall runs of grey (and the dark lines beside them) near the shaft's place -> the
    # colour next to it on the same row; the straight shaft is drawn over that spot below
    rgb = out[..., :3].astype(int)
    band = (np.abs(xx - TIP_X) < 26) & take
    g = (rgb.max(-1) - rgb.min(-1) < 45) & (rgb.max(-1) > 95) & (rgb.max(-1) < 238) & band
    runs = np.zeros_like(g)
    for x in np.nonzero(g.any(0))[0]:
        lab1, n1 = ndimage.label(g[:, x])
        for i in range(1, n1 + 1):
            ys = np.nonzero(lab1 == i)[0]
            if len(ys) >= 18:
                runs[ys, x] = True
    # the stick's columns (where a tall grey run is): every grey or dark bit in them goes, also the short ends the
    # paw cut off, and the dark lines just beside them
    cols = np.nonzero(runs.any(0))[0]
    # below the chin the shaft goes where the picture's paw holds it (its stick's middle); behind the head it moves
    # back under the knob, which nobody sees
    cnt = runs.sum(0)
    core = np.nonzero(cnt >= 0.5 * cnt.max())[0] if len(cols) else []
    cxm = float((core * cnt[core]).sum() / cnt[core].sum()) if len(core) else TIP_X
    lx0 = int(round(cxm - (len(SHAFT) - 1) / 2)) if len(cols) else SX0
    lx0 = SX0 if abs(lx0 - SX0) > 20 or front else lx0   # in front of the face it must be one straight line
    stick = np.zeros_like(runs)
    if len(cols):
        c0, c1 = cols.min() - 3, cols.max() + 4
        greyish = (rgb.max(-1) - rgb.min(-1) < 45) & (rgb.max(-1) > 95) & (rgb.max(-1) < 238)
        stick[:, c0:c1] = greyish[:, c0:c1]      # the dark edges are under the new shaft; the paw keeps its outline
        stick &= take & ~ndimage.binary_dilation(ndimage.binary_opening(
            (np.abs(rgb - np.array(FUR)).sum(-1) < 75), iterations=1), iterations=2)
        stick[:, c0:c1] &= (yy[:, c0:c1] > mtop)
    for y in np.unique(np.nonzero(stick)[0]):
        xs = np.nonzero(stick[y])[0]
        x0, x1 = xs.min() - 1, xs.max() + 1
        for x in xs:
            src = x0 if (x - x0) <= (x1 - x) else x1
            if 0 <= src < 480 and out[y, src, 3] > 0:
                out[y, x] = out[y, src]
    # the paw: the picture's fur and outline around the guide circle, put back over the front shaft
    rgb = out[..., :3].astype(int)
    fur = (np.abs(rgb - np.array(paw_col)).sum(-1) < 75) & take
    fur = ndimage.binary_opening(fur, iterations=1)
    flab, fn = ndimage.label(fur)
    hit = np.unique(flab[near_paw & fur])
    fur = np.isin(flab, hit[hit > 0])          # the whole paw/arm fur that reaches the guide circle
    paw = ndimage.binary_fill_holes(fur | (ndimage.binary_dilation(fur, iterations=3) & (rgb.max(-1) < 90))) & take
    paw = ndimage.binary_fill_holes(ndimage.binary_closing(paw, iterations=2)) & take
    # the stick showed through between the fingers in the picture: inside the paw those grey bits become fur
    gpaw = paw & (rgb.max(-1) - rgb.min(-1) < 45) & (rgb.max(-1) > 95)
    if fur.any():
        out[gpaw, :3] = np.median(out[fur][:, :3], axis=0).astype(np.uint8)
    # layers: canopy, the shaft behind the head, the figure, the shaft in front below the chin, the paw
    L = np.asarray(canopy.convert('RGBA')).copy()
    if front:
        front0 = 118                  # from the canopy straight down, in front of the face (like the cats)
    else:
        hc = np.nonzero(hm[:, min(SX0, lx0):max(SX0, lx0) + len(SHAFT)].any(1))[0]
        front0 = int(hc.max()) + 1 if len(hc) else int(ro['mbot']) + 40
        shaft_rows(L, 118, front0 - 30)  # behind everything; only the part between canopy and head shows
        shaft_rows(L, front0 - 30, 470, lx0)
    fig_l = Image.fromarray(out, 'RGBA')
    base = Image.fromarray(L, 'RGBA')
    base.alpha_composite(fig_l)
    B = np.asarray(base).copy()
    on = paw[:, lx0:lx0 + len(SHAFT)].any(1)
    end = (int(np.nonzero(on)[0].max()) + 22) if on.any() else PAW_Y + 44
    end = min(end, feet - 40)
    shaft_rows(B, front0, end, lx0)
    for j in range(len(SHAFT)):                 # a dark end cap
        B[end, lx0 + j] = (14, 12, 22, 255)
    if front and len(cols):
        # the fist: rows near the guide circle where the picture's own stick is hidden (the fist is in front of it);
        # in those rows the picture's pixels go back over the drawn shaft, whatever the paw's colour (fur, mitten)
        gA = (A.max(-1) - A.min(-1) < 45) & (A.max(-1) > 95) & am
        c0, c1 = cols.min(), cols.max() + 1
        rows = [y for y in range(PAW_Y - 60, PAW_Y + 60)
                if gA[y, c0:c1].mean() < 0.3 and take[y, SX0:SX0 + len(SHAFT)].all()]
        if rows:
            lab_r, nr = ndimage.label(np.isin(np.arange(560), rows))
            best = max(range(1, nr + 1), key=lambda i: (lab_r == i).sum())
            ry = np.nonzero(lab_r == best)[0]
            fist = np.zeros(paw.shape, bool)
            fist[ry.min():ry.max() + 1, SX0 - 1:SX0 + len(SHAFT) + 1] = True
            fist &= take
            paw = fist
            # the shaft ends inside the fist (owner: a handle sticking out under the paw looked unnatural)
            end = int(ry.min() + 0.6 * (ry.max() - ry.min()))
            B2 = np.asarray(base).copy()
            shaft_rows(B2, front0, end, lx0)
            B = B2
            # under the fist the picture's stick left its two dark edge lines: fill its columns from the sides
            x0s, x1s = min(c0, SX0) - 3, max(c1, SX0 + len(SHAFT)) + 3
            for y in range(ry.max() + 1, min(ry.max() + 90, feet - 20)):
                seg = B[y, x0s:x1s, :3].astype(int)
                bad = (seg.max(-1) < 130) | ((seg.max(-1) - seg.min(-1) < 60) & (seg.max(-1) > 95) & (seg.max(-1) < 245))
                if not bad.any() or not take[y, x0s:x1s].any():
                    continue
                L_, R_ = B[y, x0s - 2].copy(), B[y, x1s + 1].copy()
                for i in np.nonzero(bad)[0]:
                    B[y, x0s + i] = L_ if i < (x1s - x0s) / 2 else R_
    B[paw] = out[paw]
    if front:
        # a fist drawn darker brown than the fur (some edits did that): flat fur like the other stages' paws
        yy_, xx_ = np.mgrid[:560, :480]
        pc = np.nonzero(paw)
        if len(pc[0]):
            cy_, cx_ = pc[0].mean(), pc[1].mean()
            near = ((yy_ - cy_) ** 2 + (xx_ - cx_) ** 2 < 34 ** 2) & keep
            h_, s_, v_ = sk._hsv(B[..., :3].astype(np.uint8))
            brown = near & (h_ > 0.01) & (h_ < 0.12) & (s_ > 0.3) & (v_ > 0.3) & (v_ < 0.78)
            if brown.sum() > 120:
                B[brown, :3] = FUR
        # thin outline hooks where the drawn arm meets the sprite's shoulder
        fm = B[..., 3] > 0
        thin = fm & ~ndimage.binary_opening(fm, iterations=2) & keep & ~(np.abs(xx_ - TIP_X) < 8)
        B[thin] = 0
    from drop_fringe import drop
    res = Image.fromarray(drop(B)[0], 'RGBA')
    if dbg:
        os.makedirs(dbg, exist_ok=True)
        v = Image.new('RGBA', (480 * 3, 560), (238, 241, 246, 255))
        v.alpha_composite(Image.fromarray(orig, 'RGBA'), (0, 0))
        ar = np.zeros((560, 480, 4), np.uint8); ar[..., :3] = A; ar[..., 3] = am * 255
        v.alpha_composite(Image.fromarray(ar, 'RGBA'), (480, 0))
        v.alpha_composite(res, (960, 0))
        vv = np.asarray(v).copy()
        vv[np.nonzero(keep)[0], np.nonzero(keep)[1] + 480] = (vv[np.nonzero(keep)[0], np.nonzero(keep)[1] + 480] * 0.5 + np.array([0, 255, 0, 255]) * 0.5).astype(np.uint8)
        Image.fromarray(vv).save(f'{dbg}/{name}-debug.png')
    pawc = np.nonzero(paw)
    info = dict(err=round(float(err), 1), s=round(float(s), 4), front0=front0, stick=int(stick.sum()), shaft_x=lx0 + 5.5,
                paw_cx=round(float(pawc[1].mean()), 1) if len(pawc[1]) else None,
                paw_cy=round(float(pawc[0].mean()), 1) if len(pawc[0]) else None, region=int(keep.sum()))
    return res, info


if __name__ == '__main__':
    pic, t, sdir, can, odir = sys.argv[1:6]
    dbg = sys.argv[sys.argv.index('--debug') + 1] if '--debug' in sys.argv else None
    t = int(t)
    # --paw K:R,G,B  the colour of stage K's paw when it is not fur (a mitten)
    PAW = {}
    for i, a in enumerate(sys.argv):
        if a == '--paw':
            k_, c_ = sys.argv[i + 1].split(':')
            PAW[int(k_)] = tuple(int(v) for v in c_.split(','))
    canopy = Image.open(can)
    front = '--front' in sys.argv
    if '--single' in sys.argv:            # one picture = stage t
        k = t
        orig = np.asarray(Image.open(f'{sdir}/capy-stand-{k}-none.png').convert('RGBA')).copy()
        f = sk.figures(pic, n=1)[0]
        os.makedirs(odir, exist_ok=True)
        im, info = build(f, orig, canopy, dbg, f'capy-{k}', PAW.get(k, FUR), front)
        im.save(f'{odir}/capy-stand-{k}-umbrella.png')
        print(k, info)
        sys.exit(0)
    figs = sk.figures(pic, n=3)
    os.makedirs(odir, exist_ok=True)
    for i, f in enumerate(figs):
        k = 3 * (t - 1) + i
        orig = np.asarray(Image.open(f'{sdir}/capy-stand-{k}-none.png').convert('RGBA')).copy()
        im, info = build(f, orig, canopy, dbg, f'capy-{k}', PAW.get(k, FUR))
        im.save(f'{odir}/capy-stand-{k}-umbrella.png')
        print(k, info)
