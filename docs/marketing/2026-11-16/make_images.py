# Feed images (1080x1350): the launch-gift post (en, ko) and the app-intro carousel (cover + store frames).
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

REPO = '/home/claude/moku143/purrcast'
HERE = os.path.dirname(os.path.abspath(__file__))
FONT = f'{REPO}/Shared/Fonts/PurrcastPixel-Medium.ttf'
ASSETS = f'{REPO}/Shared/SharedAssets.xcassets'
W, H = 1080, 1350
NAVY, ORANGE, WHITE = (31, 42, 68), (214, 98, 30), (255, 255, 255)
def font(px): return ImageFont.truetype(FONT, px)
def text_c(d, y, s, f, fill):
    d.text(((W - d.textlength(s, font=f)) / 2, y), s, font=f, fill=fill)
def sprite(ch, lv, rain='none'):
    return Image.open(f'{ASSETS}/{ch}-stand-{lv}-{rain}.imageset/{ch}-stand-{lv}-{rain}.png').convert('RGBA')
def gradient(top, bottom):
    g = Image.new('RGB', (1, H))
    for y in range(H): g.putpixel((0, y), tuple(round(top[i] + (bottom[i] - top[i]) * y / (H - 1)) for i in range(3)))
    return g.resize((W, H))

os.makedirs(f'{HERE}/out', exist_ok=True)

# 1) launch gift
G = {
    'en': dict(k="LAUNCH GIFT", big="Free Capybara", l1="Open Purrcast by Dec 13", l2="and tap Get. It's yours to keep."),
    'ko': dict(k="출시 기념 선물", big="카피바라 무료", l1="12월 13일까지 앱을 열고", l2="'받기'를 누르면 계속 내 거예요"),
}
bg = Image.open(f'{REPO}/docs/store/in-app-event/details-1080x1920.png').convert('RGB').crop((0, 170, 1080, 170 + H))
for lang, t in G.items():
    img = bg.copy(); d = ImageDraw.Draw(img)
    text_c(d, 70, t['k'], font(56), ORANGE)
    text_c(d, 145, t['big'], font(120), NAVY)
    d.rounded_rectangle([80, 1035, W - 80, 1275], 44, fill=WHITE, outline=ORANGE, width=6)
    text_c(d, 1080, t['l1'], font(58), NAVY)
    text_c(d, 1170, t['l2'], font(50), (80, 90, 120))
    img.save(f'{HERE}/out/gift-{lang}.png')

# 2) intro carousel: cover, then store frames on a soft fill of themselves
cover = gradient((214, 230, 248), (160, 184, 230)); d = ImageDraw.Draw(cover)
icon = Image.open(f'{REPO}/Purrcast/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png').convert('RGBA').resize((260, 260), Image.LANCZOS)
m = Image.new('L', (260, 260), 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, 259, 259], 58, fill=255); icon.putalpha(m)
cover.paste(icon, ((W - 260) // 2, 90), icon)
text_c(d, 390, "Purrcast", font(120), NAVY)
text_c(d, 540, "Pixel pets that dress", font(64), (60, 70, 100))
text_c(d, 620, "for your weather", font(64), (60, 70, 100))
for k, (ch, lv) in enumerate([('cat', 0), ('abys', 5), ('brit', 9), ('capy', 13)]):
    s = sprite(ch, lv).resize((336, 392), Image.LANCZOS)
    cover.paste(s, (-24 + k * 258, 740), s)
pw = d.textlength("Free on the App Store", font=font(56)) + 90
d.rounded_rectangle([(W - pw) / 2, 1180, (W + pw) / 2, 1290], 55, fill=NAVY)
text_c(d, 1204, "Free on the App Store", font(56), WHITE)
cover.save(f'{HERE}/out/intro-1.png')
for n, f in enumerate(['01', '02', '05', '03'], start=2):
    fr = Image.open(f'{HERE}/frames/en/{f}.png').convert('RGB')
    fill = fr.resize((W, int(W * fr.height / fr.width))).crop((0, 0, W, H)).filter(ImageFilter.GaussianBlur(40))
    fill = Image.blend(fill, Image.new('RGB', (W, H), (255, 255, 255)), 0.25)
    ph = fr.resize((int(fr.width * (H - 60) / fr.height), H - 60), Image.LANCZOS)
    mk = Image.new('L', ph.size, 0); ImageDraw.Draw(mk).rounded_rectangle([0, 0, ph.width - 1, ph.height - 1], 36, fill=255)
    fill.paste(ph, ((W - ph.width) // 2, 30), mk)
    fill.save(f'{HERE}/out/intro-{n}.png')
print(sorted(os.listdir(f'{HERE}/out')))
