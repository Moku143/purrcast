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

## The 15 stages (what the app actually uses — same order for every character)

The app dresses each character by temperature in **15 stages (0 hottest … 14 coldest)**; the old 10-outfit list
above this line's history was retired when the app moved to 15. One sheet = one pose, 15 outfits, **3 rows × 5**,
numbered left-to-right, top-to-bottom. A new character gets the same **kind** of outfit in each stage, but in its own
colours, patterns and props — the outfits must be as cute and varied as the existing characters' (patterns, shorts or
pants on the warm slots, hats, layering, a small prop or two). Each character's own 15-outfit list is recorded in its
section below and in `log.md`.

| stage | temp | kind |
|---|---|---|
| 0 | 35°+ | sleeveless top + sun hat + a cooling prop (ice pop, lollipop, fan…) |
| 1 | 33–34° | sleeveless top + a small heat prop (water bottle, folding fan, towel…) |
| 2 | 28–32° | short-sleeve tee with a small chest print, shorts |
| 3 | 23–27° | patterned summer shirt (gingham, hawaiian, leaf…) + shorts |
| 4 | 20–22° | button-up shirt + necktie or bow tie |
| 5 | 18–19° | sweatshirt or hoodie with a small print |
| 6 | 16–17° | knitwear (argyle sweater, knit vest, cardigan…) |
| 7 | 12–15° | light jacket (blazer, denim or corduroy jacket, field jacket…) |
| 8 | 9–11° | heavier jacket (quilted, peacoat, trench…) |
| 9 | 6–8° | cozy mid-layer (chester coat + scarf, fleece…) |
| 10 | 3–5° | wool coat (tartan, check, duffle…) + scarf |
| 11 | 0–2° | short puffer + scarf (gloves optional) |
| 12 | −4–−1° | puffer + a hat (deerstalker, trapper, bobble beanie…) + scarf |
| 13 | −9–−5° | long puffer + head cover (balaclava, hood up…) |
| 14 | −10°− | long puffer with fur-trimmed hood up + mittens + scarf (breath puff optional) |

## The consistency rule (put it in every non-standing sheet's prompt)

모든 시트는 서 있는 컬러 시트(step 1)를 그대로 따른다 — 눈 가림·크기 포함. Every later sheet (bag, umbrella,
lock, walk, …) copies the standing colour sheet figure by figure: same outfits, hats, scarves, props, prints and
details, nothing added, removed, resized or redesigned; the SAME body size and position in the cell; and the SAME eye
coverage — a stage whose hat/balaclava/hood hides the eyes in the colour sheet hides them in every sheet (the two
dots on the muzzle are NOSTRILS, not eyes). Before calling a step done, put the sheets side by side stage by stage
and check outfit, eye coverage and size yourself.

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

### 5 · 6 · walking, frame A and frame B — 안 씀 (앱에서 빠짐, 커밋 24c05e4f; the app only uses face, stand(none·bag·umbrella), lock, inline)

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

### 7 · 8 · walking with the backpack — 안 씀 (앱에서 빠짐)

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

### 9 · 10 · walking with the open umbrella — 안 씀 (앱에서 빠짐)

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
Step 0 features, v2 — the wording that finally read as a capybara (v1's "big blocky barrel-shaped head…" read as a
bear; the fix was the brick metaphor, proportions and three NOTs): "the head is a long rectangular brick, clearly
LONGER than it is tall, with a completely FLAT straight top; the muzzle is very long, deep and squared-off, taking up
the entire lower two-thirds of the head and reaching far forward, ending in a broad flat blunt front like a brick,
NOT a round bear snout and NOT a pig disc; the nose is two small dark nostrils sitting on TOP of the blunt front end
of the muzzle; the ears are TINY, short and rounded, barely sticking up, set far back on top of the head; the eyes
are small, calm and half-closed, placed very HIGH on the head and far apart, close to the sides; a serene, sleepy,
gentle expression; a chunky rectangular body with short thick legs and NO tail. … NOT a bear and NOT a pig" (full
prompt in `log.md`).
`capy/0-candidates-v1.png` (bear-ish) → `capy/0-candidates-v2.png` (good). Still to fix in step 1: feet came out
white (capybara feet are DARK brown), and ears on some candidates a touch too round.
Candidates: (1) classic warm brown · (2) lighter caramel with a cream muzzle · (3) reddish chestnut · (4) classic
brown with a small orange yuzu on the head · (5) baby: rounder, bigger head, shorter muzzle · (6) darker
chocolate-brown, slightly fluffier. Lock screen hint: "blocky head and long flat muzzle, small round ears, no tail".

#### capy — the 15 outfits · v2 (2026-11-11, round era; checked stage-by-stage against cat·abys·brit so no
same-stage kind repeats; relaxed onsen/yuzu/cucumber theme)

What the other three wear per stage (for the no-repeat check): 0 hats = straw(cat)·panama(brit)·sun cap(abys), props
= fan·lollipop·ice bar · 1 fan(cat)·folding fan(abys)·water bottle(brit) · 8 trench(cat)·peacoat(abys)·quilted(brit)
· 9 light puffer(cat)·fleece(abys)·chester+scarf(brit) · 10 duffle(cat)·check coat(abys)·tartan coat(brit) ·
11 mouton+earmuffs(cat)·short puffer(abys·brit) · 12 hats = beanie(cat)·trapper(abys)·deerstalker(brit) ·
13 fur hood(cat)·hood up(abys)·balaclava(brit) · 14 muzzle-scarf(cat)·fur hood(abys)·cossack hat(brit).

(0) cream sleeveless tank with a small yuzu print + woven straw sun hat + glass of iced yuzu juice with a straw ·
(1) sage-green sleeveless tank with thin cream stripes + holding a slice of watermelon · (2) white tee with ONE small
orange yuzu + light-denim shorts · (3) white camp shirt with a green banana-leaf pattern + beige shorts ·
(4) pale-yellow button-up + moss-green knit tie · (5) terracotta sweatshirt with a small white duck ·
(6) sky-blue and cream striped knit sweater · (7) cream varsity jacket with coral-pink sleeves and a small orange
yuzu patch · (8) bright sunny-yellow windbreaker with sky-blue colour-block shoulders and a white zip ·
(9) raspberry-pink quilted jacket with a cream collar · (10) navy padded hanten robe-coat with a tiny white wave
pattern + mustard scarf · (11) camel duffle coat with toggle buttons + forest-green scarf ·
(12) burnt-orange SHORT puffer + red-and-cream striped bobble beanie slipped down so the eyes just barely peek out +
brown scarf · (13) ice-blue HIP-LENGTH puffer + white knitted earflap hat with braided tassels, slipped down, eyes
just peeking + plum scarf · (14) deep-green ANKLE-LENGTH puffer + a puffy quilted hat with a FUR TRIM, slipped down,
eyes just peeking + red-and-cream striped scarf + red mittens

v4 changes (owner, 16:05): 1 cucumber → watermelon slice · 12-14 eye coverage softened (the hat has slipped down so
the eyes just barely peek out, a sleepy dopey look - not fully masked) · 14 = fur-trimmed padded hat · 12/13/14 made
clearly different from each other (hat shape, colour, coat length, scarf) · 6-9 redesigned bright and eye-catching.

Eye coverage rule (owner): on 12-14 the eyes are hidden NATURALLY - the hat brim / hood edge comes down just over the
eyes; never a mask covering the whole face.
