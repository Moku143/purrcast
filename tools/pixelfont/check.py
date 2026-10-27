"""Every character the app can draw in ko / en / ja must be in the pixel font (Shared/Fonts/PurrcastPixel-Medium.ttf).
   python3 tools/pixelfont/check.py   → exit 1 and a list when anything is missing."""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from chars import inventory, ROOT
from fontTools.ttLib import TTFont

cmap = TTFont(ROOT / 'Shared/Fonts/PurrcastPixel-Medium.ttf').getBestCmap()
# Japanese a person may meet beyond our own words: JIS X 0208 (place names, Apple's warning texts, dates)
jis = set()
for b1 in range(0xA1, 0xF5):
    for b2 in range(0xA1, 0xFF):
        try: jis.add(bytes([b1, b2]).decode('euc_jp'))
        except UnicodeDecodeError: pass
bad = 0
for lang, chars in inventory().items():
    miss = sorted(c for c in chars if ord(c) not in cmap)
    print(f'{lang}: {len(chars)} characters, missing {len(miss)} {"".join(miss)}')
    bad += len(miss)
hangul = [chr(c) for c in range(0xAC00, 0xD7A4) if c not in cmap]
jmiss = sorted(c for c in jis if ord(c) not in cmap)
print(f'Hangul syllables missing: {len(hangul)} · JIS X 0208 missing: {len(jmiss)} {"".join(jmiss[:80])}')
sys.exit(1 if bad or hangul else 0)
