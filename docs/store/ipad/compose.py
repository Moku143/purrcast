# The iPad App Store pictures (13-inch, 2064 x 2752): the iPhone pages' caption style over the real iPad screens.
# usage: python3 docs/store/ipad/compose.py RAW OUT [lang ...]
#   RAW: <lang>/<page>.png or padstore-<lang>-<page>.png (ScreenshotTests.test32PadStore on the iPad simulator)
#   OUT: <lang>/01.png ... 06.png
# Captions are the app's own (Localizable.strings, the keys StoreShotView uses), so every language matches the iPhone set.
import os, re, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
FONT = f'{REPO}/Shared/Fonts/PurrcastPixel-Medium.ttf'
ASSETS = f'{REPO}/Shared/SharedAssets.xcassets'
W, H = 2064, 2752
LANGS = ["ko", "en", "ja", "es", "fr", "de", "pt-BR", "it", "id", "ru", "zh-Hans", "zh-Hant"]
YELLOW, NAVY, SHADOW = (255, 216, 77), (30, 42, 68), (26, 34, 64)

# (page, raw screen or None, caption keys, background, light caption, Plus)
PAGES = [
    ("home", "home", ("오늘 뭐 입지?", "캐릭터를 보면 알아요"), ["#546D9D", "#8DB6EC", "#5C8ED6"], True, False),
    ("outfits", None, ("체감온도에 맞춰", "옷을 갈아입어요"), ["#FFD9BF", "#B7C6EA"], False, False),
    ("days", "days", ("열흘 뒤 날씨까지", "미리 볼 수 있어요"), ["#576E9E", "#8FB2E8", "#6185CF"], True, False),
    ("day", "day", ("언제, 얼마나", "비가 오는지"), ["#516FA0", "#7FAEE6", "#4C7CC6"], True, True),
    ("calendar", "calendar", ("매일의 날씨와 옷차림이", "달력에 쌓여요"), ["#587099", "#9CC3E8", "#6C93D4"], True, True),
    ("air", "air", ("미세먼지도", "한눈에"), ["#5E6D9E", "#94A6DD", "#6878BE"], True, True),
]
BG_LEVEL = ["#FFC2A8", "#FFC2A8", "#FFD3B5", "#FFE8A3", "#F3F0B5", "#D9EFCF", "#D3E6F4", "#CDDCEF",
            "#CBD8EF", "#C8D4F0", "#C0CDED", "#B7C6EA", "#B3C1E8", "#AEBCE5", "#A9B6E2"]


def strings(lang):
    out = {}
    for line in open(f'{REPO}/Shared/Localization/{lang}.lproj/Localizable.strings', encoding='utf8'):
        m = re.match(r'\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";', line)
        if m: out[m.group(1)] = m.group(2).replace('\\"', '"').replace('\\n', '\n')
    return out


def hexrgb(h): h = h.lstrip('#'); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def background(stops):
    c = [hexrgb(x) for x in stops]
    g = Image.new('RGB', (1, H))
    for y in range(H):
        t = y / (H - 1)
        if len(c) == 3:      # the dusk top holds behind the caption, then the page's own sky
            if t <= 0.19: col = c[0]
            elif t <= 0.42: k = (t - 0.19) / 0.23; col = tuple(round(c[0][i] + (c[1][i] - c[0][i]) * k) for i in range(3))
            else: k = (t - 0.42) / 0.58; col = tuple(round(c[1][i] + (c[2][i] - c[1][i]) * k) for i in range(3))
        else:
            col = tuple(round(c[0][i] + (c[1][i] - c[0][i]) * t) for i in range(3))
        g.putpixel((0, y), col)
    return g.resize((W, H))


def fit(d, text, px, maxw):
    while px > 40 and d.textlength(text, font=ImageFont.truetype(FONT, px)) > maxw: px -= 4
    return ImageFont.truetype(FONT, px)


def caption(img, l1, l2, light, plus, tr):
    d = ImageDraw.Draw(img)
    ink, hi = ((255, 255, 255), YELLOW) if light else (NAVY, (184, 58, 26))
    for i, (s, col) in enumerate([(l1, ink), (l2, hi)]):
        f = fit(d, s, 128, W - 240)
        x, y = (W - d.textlength(s, font=f)) / 2, 150 + i * 168
        if light: d.text((x, y + 9), s, font=f, fill=SHADOW)
        d.text((x, y), s, font=f, fill=col)
    if plus:
        s = tr.get("Plus 구독 기능", "Plus")
        f = ImageFont.truetype(FONT, 44)
        d.text(((W - d.textlength(s, font=f)) / 2, 500), s, font=f, fill=(255, 255, 255) if light else NAVY)


def screen(img, path):
    sc = Image.open(path).convert('RGB')
    w = 1640; h = round(sc.height * w / sc.width)
    sc = sc.resize((w, h), Image.LANCZOS)
    x, y = (W - w) // 2, 600
    m = Image.new('L', (w, h), 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], 64, fill=255)
    sh = Image.new('L', (W, H), 0); ImageDraw.Draw(sh).rounded_rectangle([x, y + 18, x + w, y + h + 18], 64, fill=120)
    img.paste((20, 28, 60), (0, 0), sh.filter(ImageFilter.GaussianBlur(28)))
    img.paste(sc, (x, y), m)
    ImageDraw.Draw(img).rounded_rectangle([x, y, x + w - 1, y + h - 1], 64, outline=(255, 255, 255), width=6)


def outfits(img):
    steps = [(0, 36), (2, 30), (3, 25), (5, 19), (6, 17), (8, 10), (10, 4), (12, -2), (14, -12)]
    d = ImageDraw.Draw(img); f = ImageFont.truetype(FONT, 84)
    tw, th, gap = 560, 640, 40
    x0, y0 = (W - (3 * tw + 2 * gap)) // 2, 640
    for k, (lv, t) in enumerate(steps):
        x, y = x0 + (k % 3) * (tw + gap), y0 + (k // 3) * (th + gap)
        tile = Image.new('RGBA', (tw, th), hexrgb(BG_LEVEL[lv]) + (225,))
        m = Image.new('L', (tw, th), 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, tw - 1, th - 1], 70, fill=255)
        img.paste(tile, (x, y), Image.composite(tile.getchannel('A'), Image.new('L', (tw, th), 0), m))
        sp = Image.open(f'{ASSETS}/cat-stand-{lv}-none.imageset/cat-stand-{lv}-none.png').convert('RGBA')
        sp = sp.resize((round(sp.width * 0.86), round(sp.height * 0.86)), Image.LANCZOS)
        img.paste(sp, (x + (tw - sp.width) // 2, y + 16), sp)      # feet above the temperature
        s = f'{t}°'
        d.text((x + (tw - d.textlength(s, font=f)) / 2, y + th - 118), s, font=f, fill=NAVY)


def find(raw, lang, name):
    for p in (f'{raw}/{lang}/{name}.png', f'{raw}/padstore-{lang}-{name}.png', f'{raw}/shots/padstore-{lang}-{name}.png'):
        if os.path.exists(p): return p
    return None


def main():
    raw, out = sys.argv[1], sys.argv[2]
    langs = sys.argv[3:] or LANGS
    for lang in langs:
        tr = strings(lang)
        os.makedirs(f'{out}/{lang}', exist_ok=True)
        for n, (page, src, (k1, k2), bg, light, plus) in enumerate(PAGES, start=1):
            img = background(bg)
            caption(img, tr.get(k1, k1), tr.get(k2, k2), light, plus, tr)
            if src is None:
                outfits(img)
            else:
                p = find(raw, lang, src)
                if not p: print(f'missing {lang}/{src}'); continue
                screen(img, p)
            img.save(f'{out}/{lang}/{n:02d}.png')
        print(lang, 'done')


if __name__ == '__main__':
    main()
