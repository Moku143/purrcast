# Purrcast Pixel (the app's pixel font)

`Shared/Fonts/PurrcastPixel-Bold.ttf` is the only pixel face the app ships (iPhone, widgets, watch).
It is built from three free fonts on one 12-px grid:

| Part | Source | Licence |
|---|---|---|
| Hangul, Latin, numbers, most symbols | Galmuri11 Bold — Lee Minseo | SIL OFL 1.1 |
| Japanese kana, kanji (JIS X 0208), CJK punctuation | PixelMplus12 Bold — itouhiro, after M+ BITMAP FONTS | M+ FONT LICENSE (`src/LICENSE-MPLUS.txt`) |
| A few symbols neither has (− ≤ ≥ 〜 …) | Galmuri11 Regular, made bold by rule | SIL OFL 1.1 |
| ✓ | drawn in `build.py` | — |

Galmuri11 Bold has no Japanese at all, so before this Japanese headings fell back to the system font.

```
python3 tools/pixelfont/build.py   # rebuild the font from src/
python3 tools/pixelfont/check.py   # every character the app can show in ko / en / ja must be in it (exit 1 if not)
```

`check.py` reads every value of the three `Localizable.strings`, the example scenes, the server's word lists
and the Swift sources, and also checks all 11,172 Hangul syllables and all of JIS X 0208 (place names, warning texts).
Previewing with Pillow at 12 px is misleading (FreeType's auto-hinter merges rows); preview at 48 px — iOS does not hint.

## Candidate C — medium weight

`build_medium.py` builds `out/PurrcastPixel-Medium.ttf`: Galmuri11 Regular with every stroke running up or down made 2 px
and every stroke running across kept at 1 px, so busy syllables (릉 음 습 챙) weigh the same as simple ones and ㅐ ㅔ keep
both stems at 2 px. The Hangul cell is one pixel wider (13 px). Japanese comes from PixelMplus12 Bold, which already
follows the same rule. Not used by the app yet.
