# Promo reel: the pixel cat changes outfits as the temperature drops, then rain + umbrella, then the end card.
# usage: python3 make_video.py en|ko OUTDIR
import sys, os, math, subprocess
from PIL import Image, ImageDraw, ImageFont, ImageFilter

LANG, OUT = sys.argv[1], sys.argv[2]
REPO = '/home/claude/moku143/purrcast'
ASSETS = f'{REPO}/Shared/SharedAssets.xcassets'
FONT = f'{REPO}/Shared/Fonts/PurrcastPixel-Medium.ttf'
W, H, FPS = 1080, 1920, 30
BG = ["#FFC2A8", "#FFC2A8", "#FFD3B5", "#FFE8A3", "#F3F0B5", "#D9EFCF", "#D3E6F4", "#CDDCEF",
      "#CBD8EF", "#C8D4F0", "#C0CDED", "#B7C6EA", "#B3C1E8", "#AEBCE5", "#A9B6E2"]
NAVY, ORANGE, WHITE = (31, 42, 68), (214, 98, 30), (255, 255, 255)

T = {
    'en': dict(t1="What to wear today?", t2="Just look at your buddy.", rain="Rain 4–7PM · take an umbrella",
               name="Purrcast", sub="Pixel pets dress for the sky", free="Free on the App Store",
               gift1="Launch gift: a free Capybara", gift2="until Dec 13"),
    'ko': dict(t1="오늘 뭐 입지?", t2="고양이를 보면 알아요", rain="4~7시 비 · 우산 챙기세요",
               name="그르릉날씨", sub="픽셀 친구가 옷 입고 알려주는 날씨", free="앱스토어에서 무료",
               gift1="출시 기념: 카피바라 무료 선물", gift2="12월 13일까지"),
}[LANG]

def font(px): return ImageFont.truetype(FONT, px)
def hexrgb(h): h = h.lstrip('#'); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
def mix(a, b, t): return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))
def sprite(ch, lv, rain='none'):
    d = f'{ASSETS}/{ch}-stand-{lv}-{rain}.imageset'
    return Image.open(f'{d}/{ch}-stand-{lv}-{rain}.png').convert('RGBA')

def gradient(top, bottom):
    g = Image.new('RGB', (1, H))
    for y in range(H): g.putpixel((0, y), mix(top, bottom, y / (H - 1)))
    return g.resize((W, H))

def text_c(d, y, s, f, fill, shadow=None):
    w = d.textlength(s, font=f)
    x = (W - w) / 2
    if shadow: d.text((x + 4, y + 4), s, font=f, fill=shadow)
    d.text((x, y), s, font=f, fill=fill)

def ease_back(t):  # ease-out-back, 0..1
    c1, c3 = 1.70158, 2.70158
    return 1 + c3 * (t - 1) ** 3 + c1 * (t - 1) ** 2

# the outfit steps: (°C, level)
STEPS = [(36, 0), (30, 2), (25, 3), (19, 5), (17, 6), (10, 8), (4, 10), (-2, 12), (-12, 14)]
STEP = 0.85
FIRST = 1.3
RAIN = 2.0
END = 3.2
t_steps = [0] + [FIRST + i * STEP for i in range(1, len(STEPS))]
t_rain = FIRST + (len(STEPS) - 1) * STEP + STEP
t_end = t_rain + RAIN
DUR = t_end + END
SCALE = 2.0
SPW, SPH = int(480 * SCALE), int(560 * SCALE)
sprites = {lv: sprite('cat', lv).resize((SPW, SPH), Image.LANCZOS) for _, lv in STEPS}
USC = 1.7
umb = sprite('cat', 7, 'umbrella').resize((int(480 * USC), int(560 * USC)), Image.LANCZOS)
f_t1, f_t2, f_temp, f_f, f_bub = font(84), font(60), font(230), font(64), font(52)

def f2c(c): return round(c * 9 / 5 + 32)

def scene_frame(t):
    # which step
    i = max(k for k, ts in enumerate(t_steps) if t >= ts) if t < t_rain else None
    if i is not None:
        c, lv = STEPS[i]
        age = t - t_steps[i]
        prev_lv = STEPS[i - 1][1] if i > 0 else lv
        k = min(1, age / 0.3)
        top = mix(hexrgb(BG[prev_lv]), hexrgb(BG[lv]), k)
        img = gradient(mix(top, WHITE, 0.35), top)
        spr, sc, alpha = sprites[lv], 0.92 + 0.08 * ease_back(min(1, age / 0.35)) if i > 0 else 1, min(1, age / 0.18) if i > 0 else 1
        old = sprites[prev_lv] if i > 0 and age < 0.18 else None
        temp = f'{c}°'
        rain = False
    else:
        age = t - t_rain
        top = mix(hexrgb(BG[14]), (150, 165, 200), min(1, age / 0.4))
        img = gradient(mix(top, WHITE, 0.2), top)
        spr, sc, alpha, old = umb, 0.92 + 0.08 * ease_back(min(1, age / 0.35)), min(1, age / 0.18), (sprites[14] if age < 0.18 else None)
        c, temp, rain = 14, '14°', True
    d = ImageDraw.Draw(img)
    text_c(d, 210, T['t1'], f_t1, NAVY)
    text_c(d, 322, T['t2'], f_t2, ORANGE)
    # temperature
    if LANG == 'en':
        s1, s2 = temp + 'C', f'{f2c(c)}°F'
        w1 = d.textlength(s1, font=f_temp); w2 = d.textlength(s2, font=f_f)
        x = (W - (w1 + 30 + w2)) / 2
        d.text((x, 430), s1, font=f_temp, fill=NAVY)
        d.text((x + w1 + 30, 430 + 230 - 90), s2, font=f_f, fill=(90, 100, 130))
    else:
        text_c(d, 430, temp, f_temp, NAVY)
    # rain drops
    if rain:
        for k in range(70):
            x = (k * 197) % W
            y = ((k * 331) + (t - t_rain) * 1400) % (H + 100) - 100
            d.line([(x, y), (x - 6, y + 44)], fill=(255, 255, 255), width=5)
    # sprite with idle breathing
    breath = math.sin(t * 2 * math.pi / 2.8) * 4
    base_y = 520
    def paste(s, scale, a):
        bw, bh = s.size
        w, h = int(bw * scale), int(bh * scale)
        s2 = s.resize((w, h), Image.LANCZOS) if scale != 1 else s
        by = 690 if bw != SPW else base_y
        if a < 1:
            s2 = s2.copy(); s2.putalpha(s2.getchannel('A').point(lambda v: int(v * a)))
        img.paste(s2, ((W - w) // 2, int(by + bh - h + breath)), s2)
    if old is not None: paste(old, 1, 1 - alpha)
    paste(spr, sc, alpha)
    # bubble in the rain
    if rain and age > 0.3:
        bw = d.textlength(T['rain'], font=f_bub) + 70
        x0, y0 = (W - bw) / 2, 1665
        d.rounded_rectangle([x0, y0, x0 + bw, y0 + 100], 26, fill=WHITE, outline=NAVY, width=5)
        d.text((x0 + 35, y0 + 22), T['rain'], font=f_bub, fill=NAVY)
    return img

icon = Image.open(f'{REPO}/Purrcast/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png').convert('RGBA').resize((340, 340), Image.LANCZOS)
mask = Image.new('L', (340, 340), 0); ImageDraw.Draw(mask).rounded_rectangle([0, 0, 339, 339], 76, fill=255); icon.putalpha(mask)
friends = [sprite(ch, 4).resize((300, 350), Image.LANCZOS) for ch in ('cat', 'abys', 'brit', 'capy')]
f_name, f_sub, f_free, f_gift = font(120), font(52), font(64), font(54)

def end_frame(t):
    age = t - t_end
    img = gradient((205, 222, 245), (150, 175, 225))
    d = ImageDraw.Draw(img)
    a = min(1, age / 0.35)
    y_off = int((1 - ease_back(a)) * 40)
    img.paste(icon, ((W - 340) // 2, 190 + y_off), icon)
    text_c(d, 570, T['name'], f_name, NAVY)
    text_c(d, 725, T['sub'], f_sub, (60, 70, 100))
    # store pill
    pw = d.textlength(T['free'], font=f_free) + 100
    d.rounded_rectangle([(W - pw) / 2, 835, (W + pw) / 2, 955], 60, fill=NAVY)
    text_c(d, 860, T['free'], f_free, WHITE)
    # friends row
    for k, s in enumerate(friends):
        x = 40 + k * 250
        img.paste(s, (x - 25, 1010 + int(math.sin((t + k * 0.4) * 2.2) * 6)), s)
    # gift card
    if age > 0.6:
        d.rounded_rectangle([90, 1390, W - 90, 1630], 40, fill=WHITE, outline=ORANGE, width=6)
        text_c(d, 1430, T['gift1'], f_gift, ORANGE)
        text_c(d, 1520, T['gift2'], f_gift, NAVY)
    return img

os.makedirs(f'{OUT}/frames-{LANG}', exist_ok=True)
n = int(DUR * FPS)
for k in range(n):
    t = k / FPS
    im = scene_frame(t) if t < t_end else end_frame(t)
    im.save(f'{OUT}/frames-{LANG}/{k:04d}.png')
out = f'{OUT}/purrcast-reel-{LANG}.mp4'
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', str(FPS), '-i', f'{OUT}/frames-{LANG}/%04d.png',
                '-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo', '-shortest',
                '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '18', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '128k',
                '-movflags', '+faststart', out], check=True)
print(out, f'{DUR:.1f}s', n, 'frames')
