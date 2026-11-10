# Character sprite prompts (GPT Image)

How the characters (cat · abys · brit · …) were drawn, so the next one comes out the same way.
Keep this file up to date whenever a prompt changes. Every single picture asked for goes into `log.md` with its exact
prompt, settings and result.

## Where and how

- **Tool:** Higgsfield → `generate_image` / `generate_image_batch`
- **Model:** `gpt_image_2_5` (the cat's lock-screen and the Abyssinian's 10 sheets came out right with it)
- **Settings:** `aspect_ratio 16:9`, `quality xhigh`, `resolution 4k` (≈ 7 credits a sheet; `high`/`2k` ≈ 2.75,
  `medium`/`1k` ≈ 0.5 — fine for design candidates, not for the final sheets)
- **One sheet = one pose, 10 outfits**, 2 rows × 5. Smaller sheets keep the figures big and let one bad sheet be
  redrawn alone.
- **ChatGPT works too** (no Higgsfield credits): the same prompts with the same reference pictures attached, in a
  new chat per sheet. Claude can drive it in the user's Chrome (chatgpt.com, logged in) and bring the picture back.
  It may not give 4K; a clear 2 × 5 sheet is enough.
- The reference pictures as files: `Shared/SharedAssets.xcassets/cat-stand-*` (single sprites); the full sheets
  live in Higgsfield (ids below).

### Reference pictures (Higgsfield media ids, in the account)

| id | what |
|---|---|
| `3e89afe9-592f-4db5-a52f-0d30cfea3024` | orange cat · 10 outfits, standing, empty-handed (the style reference for every new character) |
| `c942d835-36e9-42cc-95f3-b1b0b4d877e1` | orange cat · backpack with the folded umbrella, and the open umbrella |
| `415c91b2-2efb-4a50-bac7-04fd4197c569` | orange cat · walking, frames A and B |
| `c5c57f56-3e85-410c-b331-4814499066e6` | orange cat · lock-screen (white on navy) |
| `261e89a8-5eb1-4514-bbf8-5e68b3d8d619` | Abyssinian · 10 outfits, standing (an example of step 1's output) |

## The 10 outfits (same order for every character and every sheet)

Coldest last. A new character gets the **same kind** of outfit in each slot, in its own colours and details.

Row 1: (0) tank top, holding a small handheld fan · (1) plain tank top · (2) short-sleeved T-shirt · (3) button-up
shirt with a necktie · (4) crew-neck sweatshirt
Row 2: (5) cable-knit sweater · (6) trench coat with a belt · (7) duffle coat with toggles and a striped scarf ·
(8) puffer jacket with earmuffs and a scarf · (9) long puffer coat with a fur-trimmed hood (ears inside), scarf and
mittens

## The pixel paragraph (put it in every prompt)

```
RENDERING - the most important part. GENUINE low-resolution pixel art on a coarse pixel grid, about 64 pixels wide
per figure, shown enlarged with hard square pixels exactly like the attached cat: big clearly visible square pixels,
NO anti-aliasing, NO soft edges, NO blur, NO gradients, NO airbrush shading, NO fur texture; flat colour fills only,
3 to 4 tones per material (base, one shadow, one highlight); one solid dark-navy outline, 1 pixel thick on the grid,
around the whole figure and the clothes; small details simplified into a few pixels each.
```

Always end with: `Plain flat light grey-blue background (#EEF1F6), no text, no labels, no numbers, no shadows. Output 16:9.`

## Steps

`{CHAR}` = the character's one-line description, written the same way in every step (for example
"the grey Abyssinian cat from the first reference image").

### 0 · design candidates (cheap: medium / 1k)

Reference: orange cat wardrobe (`3e89afe9…`).

```
Character design candidates for a NEW character: 6 different takes on a {ANIMAL}, laid out in 2 rows of 3. Use the
attached orange cat sprite sheet ONLY for the pixel-art technique, the figure size, the upright front-facing pose and
the clothing style. Do NOT reuse the cat's face, ears, eyes or markings: this is a {ANIMAL} and must read as a
{ANIMAL} at a glance.

All 6 candidates share the {ANIMAL} look: {FEATURES}. Every candidate wears the same plain denim-blue crew-neck
sweatshirt with a small white star on the chest, arms down at the sides, standing upright facing the viewer, feet
flat on one baseline.

The 6 variations: (1) … (6) …

{PIXEL PARAGRAPH}

Each figure centred in its own cell with plenty of empty space around it, all the same height. {BACKGROUND LINE}
```

### 1 · wardrobe, standing, empty-handed

References: the chosen candidate cropped alone (first), orange cat wardrobe (second).

```
Wardrobe sprite sheet for a NEW character: {CHAR}, drawn 10 times in 10 outfits, in EXACTLY the same pixel-art sprite
style, pose, proportions, size and 2-rows-of-5 layout as the orange cat sheet in the second reference image.
Character (identical in all 10): {DETAILED LOOK: coat colour and markings, ears, eyes, muzzle, body, tail}.
{PIXEL PARAGRAPH}
Every figure stands upright facing the viewer, feet flat on the same baseline, arms down at the sides, same head size
and same height as each other, each centred in its own cell, plenty of empty space around each figure.
{BACKGROUND LINE}
The 10 outfits, in this order, plain with no letters or logos: {the 10 outfits above, in this character's colours}.
```

Lesson (British Shorthair): "use the reference ONLY for the technique, size, pose and layout — do NOT reuse the
cat's face, head shape or markings" is what stops the model from just recolouring the orange cat. Spell out ear
shape explicitly ("STANDING STRAIGHT UP on top of the head") or it drifts to folded ears.

### 2 · backpack with the folded umbrella

References: step 1 (first), orange cat bag/umbrella (`c942d835…`, second).

```
Redraw the first reference image ({CHAR} in 10 outfits, 2 rows of 5) EXACTLY: same character, same 10 outfits in the
same order and same cells, same pose facing the viewer, same size, same crisp pixel-art style with the dark navy
outline, same plain flat light grey-blue background (#EEF1F6), no text. Add ONLY one thing to every figure, the same
way the orange cat carries it in the first two figures of the second reference image: a small navy-blue backpack
worn on the back, its rounded side visible behind the body on the viewer's right next to the tail, with a FOLDED
mustard-yellow umbrella sticking out of the backpack so that its curved J-shaped navy handle shows above the backpack
at shoulder height. Arms still down at the sides, nothing held in the paws except the small fan of figure (0), which
stays in its paw. The backpack and folded umbrella look identical on all 10 figures.
```

### 3 · open umbrella

References: step 1, orange cat bag/umbrella.

```
Redraw the first reference image ({CHAR} in 10 outfits, 2 rows of 5) with the same character, same 10 outfits in the
same order and same cells, same crisp pixel-art style with the dark navy outline, plain flat light grey-blue
background (#EEF1F6), no text. Every figure now holds an OPEN umbrella exactly the way the orange cat does in the last
two figures of the second reference image: the straight navy handle held in the right paw on the viewer's LEFT side,
the shaft going straight up, and a wide open umbrella canopy above the head covering the ears. The umbrella is
MUSTARD-YELLOW with a navy tip and navy rib lines, identical on all 10 figures. Figure (0) holds the umbrella instead
of the fan (no fan). Make every figure a little smaller than in the first reference so the WHOLE umbrella canopy fits
inside its cell with clear empty space above it: nothing may touch or cross the top edge of a cell or of the image.
All 10 figures the same size, feet on the same baseline in each row.
```

### 4 · lock screen (white on navy)

References: step 1, orange cat lock-screen (`c5c57f56…`).

```
Lock-screen version of {CHAR} in its same 10 outfits (same order, same 2 rows of 5 layout, same pose, empty-handed;
outfit 0 keeps its small fan), redrawn in EXACTLY the monochrome style of the second reference image (the orange
cat's lock-screen set): pure white figures with light lavender-grey and mid-grey pixel shading for fur markings,
outfit details and folds, no other colours, no dark outline, crisp hard-edged pixels, drawn on a flat dark navy
background (#20264A). {What keeps this character recognisable in white only}. Every outfit must stay recognisable
from its shape and grey details alone. All figures the same size, feet on the same baseline in each row, centred in
their cells, no text.
```

### 5 · 6 · walking, frame A and frame B (one sheet each)

References: step 1, orange cat walk (`415c91b2…`).

```
Redraw the first reference image ({CHAR} in its 10 outfits, 2 rows of 5) with the SAME layout, SAME cells, SAME
order, SAME 10 outfits (designs and colours exactly as in the first reference), SAME size and SAME crisp pixel-art
style with the dark navy outline, on the same plain flat light grey-blue background (#EEF1F6), no text. The only
change: every figure is now WALKING, in the exact walking pose of walk frame A of the orange cat in the second
reference image (its FIRST column): body turned three-quarters toward the viewer's RIGHT, head facing right-forward,
LEFT leg stepping forward and RIGHT leg behind, right arm swung forward and left arm back, tail out behind on the
left. Empty-handed; outfit (0) still holds its small handheld fan. All 10 figures in the same walking pose, same
size, feet on the same baseline in each row, each centred in its cell.
```

Frame B: "walk frame B … (its SECOND column) … RIGHT leg stepping forward and LEFT leg behind, left arm swung forward
and right arm back".

### 7 · 8 · walking with the backpack (frame A, frame B)

References: step 5 (or 6), step 2.

```
Redraw the first reference image EXACTLY ({CHAR} walking to the right in its 10 outfits, 2 rows of 5: same layout,
same cells, same order, same outfits, same walking pose, same size, same crisp pixel-art style with the dark navy
outline, same plain flat light grey-blue background #EEF1F6, no text). Add ONLY the navy-blue backpack with the
folded umbrella from the second reference image to every figure: the backpack worn on the back, seen behind the body
on the viewer's LEFT side (it faces right, so its back is on the left), with the folded umbrella's curved navy handle
sticking up out of the backpack at shoulder height. Identical backpack and umbrella on all 10 figures. Outfit (0)
still holds its small fan.
```

### 9 · 10 · walking with the open umbrella (frame A, frame B)

References: step 5 (or 6), step 3 — and for the second of the pair, the first one's result instead of step 3, so
both hold the umbrella in the **same paw**.

```
Redraw the first reference image ({CHAR} walking to the right in its 10 outfits, 2 rows of 5: same layout, same
cells, same order, same outfits, same walking legs, same crisp pixel-art style with the dark navy outline, same plain
flat light grey-blue background #EEF1F6, no text). Every figure now walks holding the OPEN mustard-yellow umbrella
EXACTLY the way the figures in the second reference image hold it: the straight navy handle held in the paw on the
viewer's LEFT side of the body (the back paw), the shaft going straight up on the viewer's left of the head, the
wide canopy above the head covering the ears, same umbrella size and position as in the second reference. Outfit (0)
holds the umbrella instead of its fan. The figures are the same size as in the second reference so the whole canopy
fits inside each cell with clear empty space above it; nothing may touch the top edge of a cell or of the image.
Feet on the same baseline in each row.
```

## After drawing (done in code)

Cut each cell, transparent background, same head size, feet on one baseline, one palette per character (from
step 1), check all 10 cells are there and no umbrella is cut off; a cut-off canopy is patched from a neighbouring
outfit. The face icon is cut from step 1. Assets: `{char}-stand-{0…9}-{none|bag|umb}`, `{char}-walk…`,
`{char}-lock-{0…9}`, `{char}-face`, `{char}-inline-…` in `Shared/SharedAssets.xcassets`.

## Characters

### cat — orange tabby (the original)

### abys — Abyssinian
"Abyssinian cat with a soft blue-grey ticked coat with fine darker grey pixel flecks, warm beige chest and muzzle,
very large upright pointed ears with darker tips and pink insides, green eyes with a white highlight, slender face,
long grey tail with a darker tip visible on the right side of the body."

### brit — British Shorthair
"a very round, wide, chubby head with full round cheeks; EARS: two small triangular ears STANDING STRAIGHT UP on top
of the head, with slightly rounded tips and pink inner ears; big round copper-amber eyes; a short broad muzzle with a
small pink nose and a cream chin; warm sandy-tan coat with faint caramel tabby stripes; a stocky, chunky body with
short thick legs and a short thick tail." (Too gold / no stripes / folded ears were the three misses.)

### capy — capybara (in progress, 2026-11-11)
Step 0 features: "a big blocky barrel-shaped head with a long, flat-topped, squarish muzzle; small round ears set high
on the head; small calm half-closed eyes set high and wide apart; two large dark nostrils at the front of the muzzle;
a calm, sleepy, gentle expression; a chunky round body with short thick legs and no visible tail."
First run (medium / 1k, 0.5 credits): `capy/0-candidates-v1.png` — reads a little like a bear (round ears, short
muzzle); next run: longer, flatter, more rectangular muzzle reaching further forward, tiny ears, eyes high on the
sides of the head.
Candidates: (1) classic warm brown · (2) lighter caramel with a cream muzzle · (3) reddish chestnut · (4) classic
brown with a small orange yuzu on the head · (5) baby: rounder, bigger head, shorter muzzle · (6) darker
chocolate-brown, slightly fluffier. Lock screen hint: "blocky head and long flat muzzle, small round ears, no tail".
