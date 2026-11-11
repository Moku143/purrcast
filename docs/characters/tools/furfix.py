import sys; sys.path.insert(0,'.')
import numpy as np
from PIL import Image
from recentre import hsv
src,dst=sys.argv[1],sys.argv[2]
a=np.asarray(Image.open(src).convert('RGB')).astype(float)
h,s,v=hsv(a.astype(np.uint8))
warm=(h>0.02)&(h<0.11)&(s>0.35)&(v>0.45); bright=warm&(v>0.85)
a[...,0]=np.where(warm,a[...,0]*0.94,a[...,0]); a[...,1]=np.where(bright,a[...,1]+3,a[...,1]); a[...,2]=np.where(bright,a[...,2]+5,a[...,2])
Image.fromarray(np.clip(a,0,255).astype(np.uint8)).save(dst)
