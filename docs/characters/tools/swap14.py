"""Swap figure 14 of a sheet for a single-figure image: scaled by `scale`, feet + body centre aligned to the old one.
Usage: python3 swap14.py sheet.png single.png scale out.png [--lock]"""
import sys
sys.path.insert(0,'.')
import numpy as np
from PIL import Image
from scipy import ndimage
from figs import figures, mask_of
sheet,single,scale,out=sys.argv[1],sys.argv[2],float(sys.argv[3]),sys.argv[4]
lock='--lock' in sys.argv
S=Image.open(sheet).convert('RGB'); sa=np.asarray(S).copy()
F=figures(sheet,lock)[14]
x0,y0,x1,y1=F['box']
# background colour around the old figure
ring=sa[max(0,y0-6):y0-2, x0:x1].reshape(-1,3)
bgc=np.median(ring,axis=0).astype(np.uint8)
# clear the old figure (its mask grown by 3px)
old=np.zeros(sa.shape[:2],bool); old[y0:y1,x0:x1]=ndimage.binary_dilation(F['mask'],iterations=3)
sa[old]=bgc
# cut the new figure
im=Image.open(single).convert('RGB'); a=np.asarray(im)
m=ndimage.binary_closing(mask_of(a,lock),iterations=2); lab,n=ndimage.label(m)
k=int(np.argmax(ndimage.sum(m,lab,range(1,n+1))))+1; mb=ndimage.binary_fill_holes(lab==k)
mb=ndimage.binary_dilation(mb,iterations=1)
ys,xs=np.nonzero(mb); bx=(xs.min(),ys.min(),xs.max()+1,ys.max()+1)
fig=im.crop(bx); msk=Image.fromarray((mb[bx[1]:bx[3],bx[0]:bx[2]]*255).astype(np.uint8))
W=int(fig.width*scale); H=int(fig.height*scale)
fig=fig.resize((W,H),Image.LANCZOS); msk=msk.resize((W,H),Image.LANCZOS)
mm=np.asarray(msk)>127
fys,fxs=np.nonzero(mm); feet=fys.max(); low=fys>feet-0.25*H; cx=int(np.median(fxs[low]))
px=x0+F['cx']-cx; py=y0+F['feet']-feet
out_img=Image.fromarray(sa)
out_img.paste(fig,(px,py),msk)
out_img.save(out)
print('placed at',px,py,'size',W,H,'old box',F['box'])
