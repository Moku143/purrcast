"""The cats' shared umbrella canopy as a clean coral layer.
Every one of the 45 cat umbrella sprites shows the same canopy (x 0-391, knob centred at x 195.5) in the cat's own
colour. Each pixel is read as outline / a place between the canopy's dark and main colour, voted over all sprites
where it is not hidden by a head, filled by mirroring about x 195.5 where every sprite hides it, then painted in one colour (four steps between its dark and main shade, like the cats').
Usage: cat_canopy.py OUT.png [#F26B5B]"""
import numpy as np, glob, sys
from scipy import ndimage
from PIL import Image
A=__import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)),'../../../Shared/SharedAssets.xcassets')
PAL={'cat':((0,99,247),(0,67,186)),'abys':((252,214,96),(226,168,38)),'brit':((252,196,212),(238,127,159))}
def load(n,k,kind): return np.asarray(Image.open(glob.glob(f'{A}/{n}-stand-{k}-{kind}.imageset/*.png')[0]).convert('RGBA')).astype(float)
H,W=560,480
T=[[[] for _ in range(W)] for _ in range(H)]
O=np.zeros((H,W)); N=np.zeros((H,W)); G=np.zeros((H,W))
for n,(main,dark) in PAL.items():
    main=np.array(main,float); dark=np.array(dark,float); d=main-dark
    for k in range(15):
        u=load(n,k,'umbrella'); a=load(n,k,'none')
        cm=(u[...,3]>0)&(a[...,3]==0); cm[190:]=False
        rgb=u[...,:3]
        outline=rgb.max(-1)<90
        grey=(rgb.max(-1)-rgb.min(-1)<40)&(rgb.max(-1)>=90)
        t=((rgb-dark)@d)/(d@d)
        ys,xs=np.nonzero(cm)
        for y,x in zip(ys,xs):
            N[y,x]+=1
            if outline[y,x]: O[y,x]+=1
            elif grey[y,x]: G[y,x]+=1
            else: T[y][x].append(float(np.clip(t[y,x],-0.2,1.3)))
# class per pixel: -1 none, 0 outline, 1 colour (with t)
cls=np.full((H,W),-1); tv=np.zeros((H,W))
for y in range(H):
    for x in range(W):
        if N[y,x]==0: continue
        if O[y,x]>=max(len(T[y][x]),G[y,x]): cls[y,x]=0
        elif len(T[y][x])>=G[y,x] and T[y][x]: cls[y,x]=1; tv[y,x]=np.median(T[y][x])
        # grey (the cats' off-centre shaft) stays empty and is filled below
# the cats' shaft and its outline under the canopy: columns 168-184, below the front rim -> empty, refilled
for y in range(100,190):
    for x in range(166,186):
        if cls[y,x]==0 and (cls[y,x-6:x+7]==0).sum()<=4 and y>120: cls[y,x]=-2
cls[cls==-2]=-1
known=cls>=0
# mirror fill about 195.5
for y in range(H):
    for x in range(0,392):
        xm=391-x
        if cls[y,x]<0 and cls[y,xm]>=0:
            cls[y,x]=cls[y,xm]; tv[y,x]=tv[y,xm]
# remaining holes inside a row's span: nearest known pixel on the row
for y in range(H):
    xs=np.nonzero(cls[y]>=0)[0]
    if not len(xs): continue
    for x in range(xs.min(),xs.max()+1):
        if cls[y,x]<0:
            j=xs[np.argmin(np.abs(xs-x))]; cls[y,x]=cls[y,j]; tv[y,x]=tv[y,j]

print('pixels',(cls>=0).sum(),'outline',(cls==0).sum())
# lone outline specks inside the colour (left from a cat's shaft or a head edge): take the neighbours' colour
for _ in range(2):
    o = cls == 0
    nb = ndimage.convolve(o.astype(int), np.ones((3, 3), int), mode='constant') - o
    lone = o & (nb <= 2) & (ndimage.convolve((cls == 1).astype(int), np.ones((3, 3), int), mode='constant') >= 5)
    for y, x in zip(*np.nonzero(lone)):
        w = (cls[y - 1:y + 2, x - 1:x + 2] == 1)
        cls[y, x] = 1; tv[y, x] = np.median(tv[y - 1:y + 2, x - 1:x + 2][w])
# paint: four steps between the dark and the main colour, the outline the cats' dark
MAIN = tuple(int(sys.argv[2][i:i + 2], 16) for i in (1, 3, 5)) if len(sys.argv) > 2 else (242, 107, 91)
mix = lambda f: tuple(int(round(c * f)) for c in MAIN)  # noqa: E731
C = [(mix(0.76), -9, -0.1), (mix(0.875), -0.1, 0.35), (mix(0.94), 0.35, 0.85), (MAIN, 0.85, 9)]
out = np.zeros((H, W, 4), np.uint8)
out[cls == 0] = (14, 12, 22, 255)
for col, lo, hi in C:
    out[(cls == 1) & (tv >= lo) & (tv < hi)] = (*col, 255)
Image.fromarray(out, 'RGBA').save(sys.argv[1])
print('canopy', sys.argv[1], 'colours', [c[0] for c in C])
