# Character pictures for marketing: the app's own sprites (480x560, transparent) + the "maybe" state
# (empty-handed + the thought bubble with an umbrella, drawn like the app's BubbleView over the head).
import json, os, shutil
from PIL import Image, ImageDraw
R='/home/claude/moku143/purrcast'; A=f'{R}/Shared/SharedAssets.xcassets'
anchors=json.load(open(f'{R}/Shared/Data/anchors.json'))
S=480/176                      # sprite px per point on the home screen (the sprite is drawn 176 pt wide)
INK=(0x1A,0x24,0x40,255); SKY=(0xD3,0xE6,0xF4,255)
icon=Image.open(f'{A}/icon-umbrella.imageset/umbrella@3x.png').convert('RGBA')
def spr(c,k,r): return Image.open(f'{A}/{c}-stand-{k}-{r}.imageset/{c}-stand-{k}-{r}.png').convert('RGBA')
def stepped(x0,y0,x1,y1,p):    # PixelBorder: corners cut in two steps of p
    s=2*p
    return [(x0+s,y0),(x1-s,y0),(x1-s,y0+p),(x1-p,y0+p),(x1-p,y0+s),(x1,y0+s),(x1,y1-s),(x1-p,y1-s),(x1-p,y1-p),(x1-s,y1-p),(x1-s,y1),
            (x0+s,y1),(x0+s,y1-p),(x0+p,y1-p),(x0+p,y1-s),(x0,y1-s),(x0,y0+s),(x0+p,y0+s),(x0+p,y0+p),(x0+s,y0+p)]
def bubble(img,tipx,tipy):
    d=ImageDraw.Draw(img); pt=lambda v: v*S
    bw,bh=pt(34),pt(30); th=pt(14)
    x0=tipx-bw/2; y1=tipy-th+pt(1); y0=y1-bh
    d.polygon([(round(x),round(y)) for x,y in stepped(x0,y0,x0+bw,y1,pt(2))],fill=INK)
    i=pt(1); d.polygon([(round(x),round(y)) for x,y in stepped(x0+i,y0+i,x0+bw-i,y1-i,pt(2))],fill=SKY)
    ic=icon.resize((round(pt(16)),round(pt(16))),Image.NEAREST); img.alpha_composite(ic,(round(x0+pt(9)),round(y0+pt(7))))
    for size,top in ((6,1),(4,9)):      # the thought tail: two little squares
        cx=tipx; ty=y1+pt(top)
        d.rectangle([round(cx-pt(size/2+1)),round(ty-pt(1)),round(cx+pt(size/2+1)),round(ty+pt(size+1))],fill=INK)
        d.rectangle([round(cx-pt(size/2-1)),round(ty+pt(1)),round(cx+pt(size/2-1)),round(ty+pt(size-1))],fill=SKY)
OUT='out'; TOP=40
for c,name in (('abys','abyssinian'),('brit','british-shorthair'),('capy','capybara')):
    base=f'{OUT}/purrcast-{name}'; os.makedirs(f'{base}/outfits',exist_ok=True); os.makedirs(f'{base}/rain',exist_ok=True)
    a=anchors[c]
    for k in range(15):
        spr(c,k,'none').save(f'{base}/outfits/{name}-{k:02d}.png')
        spr(c,k,'umbrella').save(f'{base}/rain/{name}-{k:02d}-rain-now-umbrella.png')
        spr(c,k,'bag').save(f'{base}/rain/{name}-{k:02d}-rain-later-bag.png')
        # 40 px of room on top for the bubble (a hat pushes it above the 480x560 canvas); the character itself is
        # the same picture as outfits/, on the same bottom line
        m=Image.new('RGBA',(480,560+TOP),(0,0,0,0)); m.alpha_composite(spr(c,k,'none'),(0,TOP)); bubble(m,a['head_cx'][k],TOP+a['head_top'][k]-4*S)
        m.save(f'{base}/rain/{name}-{k:02d}-rain-maybe-thought.png')
print('ok')
