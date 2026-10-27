# Purrcast Pixel (the app's pixel font)

**Now in the app (Oct 2026):** `Shared/Fonts/PurrcastPixel-Medium.ttf` — Purrcast Pixel Medium, MGalmuri10 Regular
(Monad ABXY, after Galmuri by Lee Minseo) with its upright strokes made half a pixel heavier, SIL OFL 1.1. Korean,
English and Japanese on one 10-px grid. Its notice and the licence text ship next to it (`Shared/Fonts/FONT-NOTICE.txt`,
`OFL.txt`) and show in the app under 설정 › 오픈소스 라이선스. Only a ✓ (U+2713) was added to it here.
`check.py` checks this file.

The rest of this page describes the earlier bold font and the candidates built while choosing (A, B, C, D, A2); the
scripts still build them into `out/`.

Earlier: `Shared/Fonts/PurrcastPixel-Bold.ttf` was the only pixel face the app shipped (iPhone, widgets, watch).
It was built from three free fonts on one 12-px grid:

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
