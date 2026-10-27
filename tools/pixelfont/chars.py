"""Every character the app can draw, per language, for the pixel-font coverage check.
   python3 tools/pixelfont/chars.py  → prints counts; import `inventory()` for {lang: set(chars)}."""
import json, re, pathlib, string

ROOT = pathlib.Path(__file__).resolve().parents[2]

# punctuation and symbols the code builds strings with (separators, units, arrows, quotes)
COMMON = set(string.printable.strip()) | set(' ·°~–—…‘’“”×✓›‹←→↑↓%')
JA_EXTRA = set('〜％！？、。「」『』・：（）　ー') | set('大雨洪水暴風雪波浪高潮雷融濃霧乾燥なだれ低温霜着氷注意報警特別解除発表継続土砂災害竜巻記録的短時間情報')
JA_DATES = set('年月日曜火水木金土午前後時分秒今明昨週') 

def strings_file(lang):
    p = ROOT / f'Shared/Localization/{lang}.lproj/Localizable.strings'
    vals = re.findall(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";', p.read_text(), re.M)
    return ''.join(v for _, v in vals)

def json_strings(path):
    out = []
    def walk(x):
        if isinstance(x, str): out.append(x)
        elif isinstance(x, list): [walk(i) for i in x]
        elif isinstance(x, dict): [walk(v) for v in x.values()]
    walk(json.loads(path.read_text()))
    return ''.join(out)

def inventory():
    ko = set(strings_file('ko')) | set(json_strings(ROOT / 'Shared/Data/scenes.json'))
    en = set(strings_file('en')) | set(json_strings(ROOT / 'Shared/Data/scenes.en.json'))
    ja = set(strings_file('ja')) | set(json_strings(ROOT / 'Shared/Data/scenes.ja.json'))
    # server words (all three languages live in one file) and the Swift sources (Korean literals, symbols)
    server = (ROOT / 'server/src/i18n.js').read_text() + (ROOT / 'server/src/rules.js').read_text()
    swift = ''.join(p.read_text() for p in ROOT.glob('**/*.swift') if '.build' not in p.parts)
    hangul = lambda s: {c for c in s if '가' <= c <= '힣' or 'ㄱ' <= c <= 'ㆎ'}
    cjk = lambda s: {c for c in s if '　' <= c <= 'ヿ' or '一' <= c <= '鿿' or '＀' <= c <= '￯'}
    nonascii = lambda s: {c for c in s if ord(c) > 0x7e and not c.isspace()}
    ko |= hangul(server) | hangul(swift) | {c for c in nonascii(swift) if not ('　' <= c <= '鿿')}
    ja |= cjk(server) | JA_EXTRA | JA_DATES
    # every language shows Korean place names in Korea and numbers / Latin everywhere
    for s in (ko, en, ja): s |= COMMON
    ja |= {c for c in nonascii(server) if not ('가' <= c <= '힣')}
    en |= {c for c in nonascii(server) if c < 'ᄀ'}
    drop = lambda s: {c for c in s if not c.isspace() and c not in '\\\n\t' and ord(c) >= 0x20 and not (0xfe00 <= ord(c) <= 0xfe0f)}
    return {'ko': drop(ko), 'en': drop(en), 'ja': drop(ja)}

if __name__ == '__main__':
    inv = inventory()
    for k, v in inv.items(): print(k, len(v))
