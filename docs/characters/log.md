# Generation log

Every picture asked for, with the exact prompt, so any of them can be drawn again. Newest at the bottom.
Results live next to this file (`{char}/…`); Higgsfield keeps the originals under the job id.

Format: date · character · step · tool/model · settings · references · job id · result · verdict — then the prompt.

---

## 2026-11-11 · capy · step 0 (design candidates) · v1

- Higgsfield · `gpt_image_2_5` · 16:9 · medium · 1k · 0.5 credits
- references: `3e89afe9-592f-4db5-a52f-0d30cfea3024` (orange cat wardrobe)
- job `edd9a8a4-6874-48af-81a9-40ea4416f2af` → `capy/0-candidates-v1.png`
- verdict: style right; reads a little like a bear (round ears, short muzzle) → v2 with a longer, flatter muzzle

```
Character design candidates for a NEW character: 6 different takes on a CAPYBARA, laid out in 2 rows of 3. Use the attached orange cat sprite sheet ONLY for the pixel-art technique, the figure size, the upright front-facing pose and the clothing style. Do NOT reuse the cat's face, ears, eyes or markings: this is a capybara and must read as a capybara at a glance.

All 6 candidates share the capybara look: a big blocky barrel-shaped head with a long, flat-topped, squarish muzzle; small round ears set high on the head; small calm half-closed eyes set high and wide apart; two large dark nostrils at the front of the muzzle; a calm, sleepy, gentle expression; a chunky round body with short thick legs and no visible tail. Every candidate wears the same plain denim-blue crew-neck sweatshirt with a small white star on the chest, arms down at the sides, standing upright facing the viewer, feet flat on one baseline.

The 6 variations: (1) classic warm brown coat; (2) lighter caramel coat with a cream muzzle; (3) reddish chestnut coat; (4) classic brown with a small orange yuzu fruit balanced on top of the head; (5) baby capybara: rounder body, bigger head, shorter muzzle, extra cute; (6) darker chocolate-brown coat with slightly fluffier fur.

RENDERING - the most important part. GENUINE low-resolution pixel art on a coarse pixel grid, about 64 pixels wide per figure, shown enlarged with hard square pixels exactly like the attached cat: big clearly visible square pixels, NO anti-aliasing, NO soft edges, NO blur, NO gradients, NO airbrush shading, NO fur texture; flat colour fills only, 3 to 4 tones per material (base, one shadow, one highlight); one solid dark-navy outline, 1 pixel thick on the grid, around the whole figure and the clothes; small details simplified into a few pixels each.

Each figure centred in its own cell with plenty of empty space around it, all the same height. Plain flat light grey-blue background (#EEF1F6), no text, no labels, no numbers, no shadows. Output 16:9.
```

## 2026-11-11 · capy · step 0 (design candidates) · v2

- Higgsfield · `gpt_image_2_5` · 16:9 · medium · 1k · 0.5 credits
- references: `3e89afe9-592f-4db5-a52f-0d30cfea3024` (orange cat wardrobe)
- job `21f13c33-39e6-44db-89f9-f8ace71cb871` → `capy/0-candidates-v2.png`
- verdict: reads as a capybara now — deep squared muzzle on the lower half of the head, nostrils high on the blunt
  front, flat head top, small far-back ears, high half-closed eyes. Ears on (1)(3)(6) still a touch round/bear-ish;
  feet came out white (capybara feet are dark) — fix in step 1, not worth another candidate run.

```
Character design candidates for a NEW character: 6 different takes on a CAPYBARA, laid out in 2 rows of 3. Use the attached orange cat sprite sheet ONLY for the pixel-art technique, the figure size, the upright front-facing pose and the clothing style. Do NOT reuse the cat's face, ears, eyes or markings: this is a capybara and must read as a capybara at a glance.

All 6 candidates share the capybara look, which is NOT a bear and NOT a pig: the head is a long rectangular brick, clearly LONGER than it is tall, with a completely FLAT straight top; the muzzle is very long, deep and squared-off, taking up the entire lower two-thirds of the head and reaching far forward, ending in a broad flat blunt front like a brick, NOT a round bear snout and NOT a pig disc; the nose is two small dark nostrils sitting on TOP of the blunt front end of the muzzle; the ears are TINY, short and rounded, barely sticking up, set far back on top of the head; the eyes are small, calm and half-closed, placed very HIGH on the head and far apart, close to the sides; a serene, sleepy, gentle expression; a chunky rectangular body with short thick legs and NO tail. Every candidate wears the same plain denim-blue crew-neck sweatshirt with a small white star on the chest, arms down at the sides, standing upright facing the viewer, feet flat on one baseline.

The 6 variations: (1) classic warm brown coat; (2) lighter caramel coat with a cream muzzle; (3) reddish chestnut coat; (4) classic brown with a small orange yuzu fruit balanced on top of the head; (5) baby capybara: rounder body, bigger head, slightly shorter (but still long and squared) muzzle, extra cute; (6) darker chocolate-brown coat with slightly fluffier fur.

RENDERING - the most important part. GENUINE low-resolution pixel art on a coarse pixel grid, about 64 pixels wide per figure, shown enlarged with hard square pixels exactly like the attached cat: big clearly visible square pixels, NO anti-aliasing, NO soft edges, NO blur, NO gradients, NO airbrush shading, NO fur texture; flat colour fills only, 3 to 4 tones per material (base, one shadow, one highlight); one solid dark-navy outline, 1 pixel thick on the grid, around the whole figure and the clothes; small details simplified into a few pixels each.

Each figure centred in its own cell with plenty of empty space around it, all the same height. Plain flat light grey-blue background (#EEF1F6), no text, no labels, no numbers, no shadows. Output 16:9.
```

## 2026-11-11 · capy · step 1 (wardrobe, standing, empty-handed) · v1

- ChatGPT (chatgpt.com, no credits) · chat "Capybara Wardrobe Sprite Sheet" · model: default GPT-5 image
- references: (1st) candidate 1 cropped from `capy/0-candidates-v2.png`, (2nd) orange cat wardrobe
  (`3e89afe9-592f-4db5-a52f-0d30cfea3024`, full sheet)
- result: `capy/1-wardrobe-v1.png` — NOTE: this file is a screen capture (1078×609); the full-resolution original
  (1672×941 PNG) lives in the user's ChatGPT library in that chat — download it from there before cutting assets.
- verdict: good. 10/10 outfits correct and in order; brick muzzle, tiny far-back ears, high half-closed eyes, DARK
  brown feet (the two step-0 fixes worked), no tail, consistent character across all cells. Outfit (9)'s scarf is
  mostly hidden by the hood/coat — acceptable.
- prompt changes vs step-0 v2: added "the feet and paws are DARK chocolate brown, clearly darker than the body coat,
  never white" and "TINY flat rounded nubs set far BACK on top of the head, barely sticking up - NOT round bear ears".
- capy outfit colours (keep for every later sheet): (0) mint-green tank + fan · (1) white tank · (2) coral-red tee ·
  (3) light-blue shirt, navy necktie · (4) denim-blue sweatshirt, small white star · (5) cream cable-knit ·
  (6) sand-beige trench · (7) forest-green duffle, mustard-and-navy striped scarf · (8) navy puffer, earmuffs, red
  scarf · (9) long olive puffer, fur-trimmed hood up, scarf, mittens

```
Wardrobe sprite sheet for a NEW character: the warm brown capybara from the first reference image, drawn 10 times in 10 outfits, in EXACTLY the same pixel-art sprite style, pose, proportions, size and 2-rows-of-5 layout as the orange cat sheet in the second reference image. Use the cat sheet ONLY for the technique, figure size, pose and layout - do NOT reuse the cat's face, head shape or markings: this is a capybara. Character (identical in all 10): a capybara with a warm brown coat (base brown, one darker shadow tone, one lighter tan highlight); the head is a long rectangular brick, clearly LONGER than it is tall, with a completely FLAT straight top; a very long, deep, squared-off muzzle in slightly darker brown taking up the entire lower two-thirds of the head and reaching far forward, ending in a broad flat blunt front like a brick; two small dark nostrils sitting on TOP of the blunt front end of the muzzle; the ears are TINY flat rounded nubs set far BACK on top of the head, barely sticking up - NOT round bear ears; small calm half-closed dark eyes placed very HIGH on the head and far apart, close to the sides; a serene, sleepy, gentle expression; a chunky rectangular body with short thick legs; the feet and paws are DARK chocolate brown, clearly darker than the body coat, never white; NO tail. RENDERING - the most important part. GENUINE low-resolution pixel art on a coarse pixel grid, about 64 pixels wide per figure, shown enlarged with hard square pixels exactly like the cat sheet: big clearly visible square pixels, NO anti-aliasing, NO soft edges, NO blur, NO gradients, NO airbrush shading, NO fur texture; flat colour fills only, 3 to 4 tones per material (base, one shadow, one highlight); one solid dark-navy outline, 1 pixel thick on the grid, around the whole figure and the clothes; small details simplified into a few pixels each. Every figure stands upright facing the viewer, feet flat on the same baseline, arms down at the sides, same head size and same height as each other, each centred in its own cell, plenty of empty space around each figure. Plain flat light grey-blue background (#EEF1F6), no text, no labels, no numbers, no shadows. Output 16:9. The 10 outfits, in this order, plain with no letters or logos: (0) mint-green tank top, holding a small handheld fan in one paw; (1) plain white tank top; (2) coral-red short-sleeved T-shirt; (3) light-blue button-up shirt with a navy necktie; (4) denim-blue crew-neck sweatshirt with a small white star on the chest; (5) cream cable-knit sweater; (6) sand-beige trench coat with a belt; (7) forest-green duffle coat with toggles and a mustard-and-navy striped scarf; (8) navy puffer jacket with earmuffs and a red scarf; (9) long olive puffer coat with a fur-trimmed hood worn up (ears inside the hood), a scarf and mittens.
```

## 2026-11-11 · capy · step 1 redone as the 15-stage outfit sheet · v1

- Why: the 10-outfit sheet (`capy/1-wardrobe-v1.png`) used the retired 10-outfit list and the outfits were too plain
  next to cat/abys/brit's 15-stage sets (no shorts, no hats, no patterns, no props). The app dresses by 15 stages.
  prompts.md now carries the 15-stage kind table and capy's own 15-outfit list (capybara props: yuzu, onsen towel, duck).
- ChatGPT (chatgpt.com, no credits) · chat "Pixel Art Outfit Sheet" · default GPT-5 image · 3 rows of 5
- references: (1st) `capy/1-wardrobe-v1.png` (character identity + style), (2nd) `abys-outfits-15-v2.png` (outfit
  variety/cuteness bar; prompt says to ignore its text and not copy its colours)
- character tweak in this run: ears even smaller and flatter ("barely raised flat nubs set far back")
- result: `capy/1-outfits-15-v1.png` — screen capture stitched from three row tiles (1202×677); the full-resolution
  original lives in the user's ChatGPT library in that chat — download before cutting assets.
- verdict: 15/15 outfits correct and in order, ears flatter, feet dark. Props all read well (straw hat, ice pop,
  neck towel, yuzu prints, duck print, bobble beanie, balaclava, fur hood, mittens, striped scarf).
- full prompt: see below.

```
Full 15-outfit sprite sheet for a pixel-art capybara character, 15 figures laid out in 3 rows of 5, in order left-to-right top-to-bottom. The FIRST reference image shows the capybara character and the exact pixel-art style to keep: same face, same head shape, same proportions, same crisp pixel style with the dark navy outline. Two small changes to the character: make the ears even SMALLER and FLATTER (barely raised flat nubs set far back on the head), and keep the feet dark chocolate brown. The SECOND reference image (a grey cat in 15 outfits) shows the LEVEL OF CUTENESS, VARIETY and DETAIL the outfits must reach - patterns, shorts, hats, layered clothes, small props - but do NOT copy the cat, its outfits' exact colours, or ANY of the text in it. IGNORE all text in the references; the output must contain NO text, NO labels, NO numbers. Character (identical in all 15): a warm brown capybara, head a long rectangular brick with a flat top, very long deep squared-off muzzle filling the lower two-thirds of the head and ending in a broad flat blunt front, two small dark nostrils on TOP of the blunt front, tiny flat ears set far back, small calm half-closed eyes set very high and wide, sleepy gentle expression, chunky body, short thick legs, dark chocolate-brown feet and paws, no tail. RENDERING - the most important part. GENUINE low-resolution pixel art on a coarse pixel grid, about 64 pixels wide per figure, shown enlarged with hard square pixels exactly like both references: big clearly visible square pixels, NO anti-aliasing, NO soft edges, NO blur, NO gradients, NO airbrush shading, NO fur texture; flat colour fills only, 3 to 4 tones per material; one solid dark-navy outline, 1 pixel thick on the grid, around the whole figure and the clothes; small details simplified into a few pixels each. Every figure stands upright facing the viewer, feet flat on the same baseline, arms down at the sides unless holding a prop, same head size and same height, each centred in its own cell with empty space around it. Plain flat light grey-blue background (#EEF1F6), no shadows. Output 16:9. The 15 outfits in this exact order (hottest to coldest), cute and detailed: (0) cream sleeveless tank with a small orange yuzu-fruit print + woven straw sun hat + holding a yuzu-yellow ice pop; (1) sage-green sleeveless tank + a small white onsen hand towel draped around the neck; (2) white short-sleeve tee with ONE small orange yuzu fruit printed on the chest + light-denim shorts; (3) white camp shirt with a green banana-leaf pattern + beige shorts; (4) pale-yellow button-up shirt + moss-green knit tie; (5) terracotta crew-neck sweatshirt with a small white duck printed on the chest; (6) moss-green cable-knit cardigan with small wooden buttons, worn open over a cream tee; (7) brown corduroy jacket, open, over a cream tee; (8) deep-teal quilted jacket with visible stitching squares; (9) oatmeal teddy-fleece zip-up jacket; (10) camel duffle coat with toggle buttons + mustard-yellow scarf; (11) burnt-orange short puffer jacket + cream scarf; (12) mustard-yellow puffer + forest-green bobble beanie + brown scarf; (13) navy long puffer coat + cream balaclava covering the head; (14) deep-green long puffer with a big fur-trimmed hood worn UP (ears inside) + red mittens + red-and-cream striped scarf.
```

## 2026-11-11 · capy · step 2 (umbrella bag + folded umbrella, 15 outfits) · v1

- ChatGPT (no credits) · chat "Redraw Capybara Outfits" · 3 rows of 5
- references: (1st) `capy/1-outfits-15-v1.png`, (2nd) `ref-cat-bag.png` (in-app cat with the umbrella bag)
- capy carry colours (fixed from here on): MOSS-GREEN umbrella bag on the viewer's right, CORAL-RED J handle;
  the open umbrella will be CORAL-RED (cat is blue, abys is yellow)
- result: `capy/2-bag-15-v1.png` (screen-capture stitch, 1078×606; original in the ChatGPT chat)
- verdict: 15/15 good — bag and handle identical and behind the body on every figure, outfits/props unchanged,
  (0) keeps the ice pop.

```
Redraw the first reference image (a pixel-art capybara in 15 outfits, 3 rows of 5) EXACTLY: same character, same 15 outfits in the same order and same cells, same upright pose facing the viewer, same size, same crisp pixel-art style with the dark navy outline, same plain flat light grey-blue background (#EEF1F6), no text, no labels, no numbers. Add ONLY one thing to every figure, carried the same way as the orange cat in the second reference image: a small MOSS-GREEN umbrella bag slung on the back, its rounded end visible behind the body on the viewer's RIGHT at waist-to-shoulder height, with a folded umbrella inside so that only the umbrella's curved J-shaped CORAL-RED handle sticks up out of the bag above the shoulder. The bag and folded umbrella are identical on all 15 figures and must not cover the outfit on the front of the body. Everything else stays exactly as in the first reference: arms down at the sides, figure (0) still holding its yuzu-yellow ice pop, every outfit's hat, scarf, print and colours unchanged.
```

## 2026-11-11 · capy · step 3 (open umbrella, 15 outfits) · v1

- ChatGPT (no credits) · chat "Redraw Pixel Art Umbrellas" · 3 rows of 5
- references: (1st) `capy/1-outfits-15-v1.png`, (2nd) `ref-cat-umb.png` (in-app cat holding the open umbrella)
- note: the message accidentally contained the prompt twice (a type retry landed twice); harmless, result correct
- result: `capy/3-umbrella-15-v1.png` (capture stitch, 1008×606; original in the ChatGPT chat)
- verdict: 15/15 good — CORAL-RED canopy with darker ribs centred over the head on every figure, canopy inside each
  cell, (0) holds the umbrella instead of the ice pop, outfits unchanged.

```
Redraw the first reference image (a pixel-art capybara in 15 outfits, 3 rows of 5) with the same character, same 15 outfits in the same order and same cells, same crisp pixel-art style with the dark navy outline, same plain flat light grey-blue background (#EEF1F6), no text, no labels, no numbers. Every figure now holds an OPEN umbrella exactly the way the orange cat does in the second reference image: one arm raised across the chest holding the straight grey shaft, the shaft going straight up beside the head on the viewer's LEFT, and a wide open umbrella canopy centred above the head, covering the ears. The umbrella is CORAL-RED with a darker red tip and darker red rib lines and a grey shaft, identical on all 15 figures. Figure (0) holds the umbrella instead of the ice pop (no ice pop anywhere). Make every figure a little smaller than in the first reference so the WHOLE umbrella canopy fits inside its cell with clear empty space above it: nothing may touch or cross the top edge of a cell or of the image. All 15 figures the same size, feet on the same baseline in each row, every outfit's hat, scarf, print and colours unchanged.
```

## 2026-11-11 · capy · walking sheet — generated then DISCARDED

- A 15-figure walking frame A sheet was generated (ChatGPT chat "Redraw Walking Capybaras") right before the owner
  said walking is no longer used in the app (removed in 24c05e4f; the app uses face, stand(none·bag·umbrella), lock,
  inline only). Not saved, not an asset. prompts.md steps 5–10 are now marked 안 씀.

## 2026-11-11 · capy · step 3 redo (smooth dome umbrella) · v2

- Owner: v1 canopy edge was wrinkly. v2 copies the cat umbrella's SHAPE: wide smooth symmetrical dome, small round
  tip, clean EVEN scalloped bottom edge (equal arcs between rib tips, same horizontal line), colour still coral-red.
- ChatGPT (no credits) · chat "Redraw Pixel Art Grid" · refs: capy 15-outfit sheet + `ref-cat-umb.png`
- result: `capy/3-umbrella-15-v2.png` (capture stitch; original in the ChatGPT chat) — 15/15 smooth even domes,
  outfits unchanged, (0) without ice pop. v2 supersedes v1.
- the prompt = v1's with the canopy sentence replaced by: "THE CANOPY SHAPE IS THE MOST IMPORTANT PART and must copy
  the SHAPE of the cat's blue umbrella in the second reference exactly: a WIDE, SMOOTH, symmetrical round DOME like
  the top half of a circle, clearly wider than the body, with a small round tip on top, and a clean EVEN SCALLOPED
  bottom edge - a row of equal small arcs, one arc between each pair of rib tips, all the same size and on the same
  horizontal line, NOT jagged, NOT wrinkled, NOT crumpled, no random zigzag. Only the colour differs from the cat's:
  the canopy is CORAL-RED with darker coral-red panel seams, identical on all 15 figures."

## 2026-11-11 · capy · step 4 (lock screen, white on navy, 15 outfits) · v1

- ChatGPT (no credits) · chat "Capybara Lock Screen Design" · 3 rows of 5
- references: (1st) `capy/1-outfits-15-v1.png`, (2nd) `cat-04-lock-screen.png` (cat's monochrome lock set)
- result: `capy/4-lock-15-v1.png` (capture stitch, 1078×606; original in the ChatGPT chat)
- verdict: 15/15 good — white figures on #20264A, muzzle shaded lavender-grey so the brick head reads, every outfit
  recognisable from shape/grey alone (straw hat, towel, tie, duck print, beanie, balaclava, fur hood…), no outline.

```
Lock-screen version of the capybara in the first reference image, in its same 15 outfits (same order, same 3 rows of 5 layout, same upright pose, empty-handed except figure (0) which keeps its ice pop), redrawn in EXACTLY the monochrome style of the second reference image (the orange cat's lock-screen set): pure WHITE figures with light lavender-grey and mid-grey pixel shading for the fur, outfit details and folds, no other colours, NO dark outline, crisp hard-edged pixels, on a flat dark navy background (#20264A). What keeps this capybara recognisable in white: the long rectangular brick-shaped head with its flat top, the big squared-off muzzle filling the lower two-thirds of the head shaded in light lavender-grey so it reads against the white head, the two dark-grey nostrils on top of the blunt muzzle front, the tiny flat ears set far back, the small half-closed grey eyes set high and wide, the chunky body with short thick legs, and NO tail. Every outfit must stay recognisable from its shape and grey shading alone (hat, scarf, hood, prints as grey pixels). All 15 figures the same size, feet on the same baseline in each row, centred in their cells, no text, no labels, no numbers. Output 16:9.
```

## 2026-11-11 · capy · step 3 redo 2 (shaft-to-tip geometry) · v3 — FINAL for step 3

- Owner: in v2 the shaft ended under the canopy's side while the canopy sat centred on the head. v3 copies the cat's
  geometry: the shaft runs from the paw STRAIGHT UP to the tip at the canopy's TOP CENTRE, canopy symmetrical around
  the shaft, so the canopy sits slightly toward the holding paw. Dome/scallop/colour as v2.
- ChatGPT (no credits) · chat "Redraw Capybara Umbrellas" · refs: capy 15-outfit sheet + `ref-cat-umb.png`
- result: `capy/3-umbrella-15-v3.png` — 15/15 correct geometry; supersedes v1 and v2.
- the prompt = v2's with the geometry sentence replaced by: "THE GEOMETRY IS THE MOST IMPORTANT PART: the straight
  grey shaft starts in the raised paw, goes STRAIGHT UP, and ends at the small round tip at the very TOP CENTRE of
  the canopy - the shaft and the tip are on the SAME vertical line, and the canopy is left-right SYMMETRICAL AROUND
  THE SHAFT. Because the paw holding it is at the side of the body, the whole canopy sits slightly toward that side,
  NOT centred over the head - copy the cat picture."

## 2026-11-11 · capy · consistency pass (owner's side-by-side review) — lock v2 + umbrella v4, both FINAL

Owner found, comparing the four sheets stage by stage: lock v1 showed eyes on 12/13/14 (colour sheet hides them —
the two dots on the muzzle are NOSTRILS, eyes sit higher and are covered by beanie/balaclava/fur hood); lock v1's
yuzu prints read as apples on 0/2, 9 lost its zip, 14's mittens/striped scarf drifted; umbrella v3's bodies were
drawn smaller than the standing/bag sheets. prompts.md now carries the consistency rule (모든 시트는 서 있는 컬러
시트를 그대로 따른다 — 눈 가림·크기 포함) to go into every non-standing prompt.

- lock v2 · ChatGPT chat "Convert Capybara Lock Screen" · refs: capy colour sheet + `cat-04-lock-screen.png` ·
  "THIS IS A COLOUR CONVERSION ONLY … figures (12), (13) and (14) have their EYES COMPLETELY HIDDEN … the only dark
  dots on the face are the two NOSTRILS" plus explicit yuzu-not-apple / zip / striped-scarf-and-mittens clauses.
  → `capy/4-lock-15-v2.png`. Supersedes v1.
- umbrella v4 · ChatGPT chat "Umbrella Pixel Art Redraw" · refs: capy colour sheet + `ref-cat-umb.png` ·
  v3's geometry sentence kept, "make smaller" removed and replaced with "CRITICAL SIZE RULE: every figure's BODY
  stays EXACTLY the same size and position as in the first reference - the umbrella is simply added above", plus the
  eye-coverage clause. → `capy/3-umbrella-15-v4.png`. Supersedes v1–v3.
- verification: built per-stage 4-way grids (standing · bag · umbrella v4 · lock v2) for all 15 stages and checked
  them myself — outfits/hats/props/prints identical, eye coverage identical (12/13/14 hidden in all four), umbrella
  bodies now at standing size (a stage or two reads ~5% smaller; correctable at asset-cut time).

## 2026-11-11 · capy · standing sheet v2 (muzzle separated from the neck) — awaiting owner confirmation

- Owner: the muzzle and the neck feel glued together; separate them a little.
- ChatGPT (no credits) · chat "Redraw Pixel Art Capybara" · ref: `capy/1-outfits-15-v1.png`
- the ONLY change clause: "make the muzzle slightly SHORTER vertically, so its bottom edge ends a little ABOVE the
  chin line and a clearly visible band of the lighter warm-brown head fur (2-3 pixels tall on the sprite grid) shows
  between the bottom of the dark muzzle and the collar of the clothes. The muzzle must no longer touch the collar
  anywhere."
- result: `capy/1-outfits-15-v2.png` — all 15 keep outfits/props/eye coverage; muzzle now clears the collar.
- NOT yet the base: once the owner confirms v2, bag/umbrella/lock get regenerated from it. Known issue to fix in that
  pass: umbrella v4 bodies are ~25% shorter than standing (same feet line, lower head, squashed torso at 1/5/11) —
  next umbrella run must keep the body at identical height/proportions (more headroom per cell, e.g. squarer output),
  or fall back to compositing the umbrella + raised arm onto the standing art.

## 2026-11-11 · capy · standing sheet v3 (muzzle halfway v1↔v2 + neck shadow) — awaiting confirmation

- Owner on v2: muzzle got too small, and with no neck boundary the head looks glued to the body. v3: muzzle size
  halfway between v1 and v2 (length and height), chin fur band kept, plus "one thin row of slightly darker warm-brown
  shadow pixels under the chin, where the head meets the body … just a subtle shadow line, not an outline".
- ChatGPT (no credits) · chat "Redraw Capybara Sheet" · refs: v1 (first) + v2 (second), prompt asks for halfway
- result: `capy/1-outfits-15-v3.png`; comparison `capy/1-outfits-v123-compare.png` (stages 1·2·7, rows v1/v2/v3)
- bag/umbrella/lock regeneration still on hold until the owner confirms the base.

## 2026-11-11 · capy · standing sheet v4 (clean navy jaw line) — awaiting confirmation

- Owner on v3: the chin band + shadow row read as a double chin. v4: shadow band REMOVED; the head now closes with
  ONE 1-pixel dark-navy jaw line (same colour as the other outlines) and the collar starts immediately below it;
  muzzle stays v3-sized with 1-2px of plain chin fur above the jaw line.
- ChatGPT (no credits) · chat "Redraw Pixel Art" · ref: `capy/1-outfits-15-v3.png`
- result: `capy/1-outfits-15-v4.png`; magnified comparison `capy/1-outfits-v34-compare.png` (stages 1·2·4, top v3 /
  bottom v4). Checked myself: no double chin, single navy boundary, chin gap kept (thinner at stage 2's centre),
  outfits/eye coverage unchanged.

## 2026-11-11 · capy · RESTART from step 0 (round & soft direction) · candidates v3 — awaiting pick

- Owner on standing v4: the face got too angular. Restart the character from step 0; keep everything made so far as
  history only. New direction: no "brick" language — round, soft, cute like the three cats; head = a bread loaf with
  fully rounded corners; muzzle = a rounded block sticking out slightly. Learned constraints carried over: tiny
  non-bear ears, dark chocolate feet, no tail, muzzle never touches the collar, one clean 1px navy jaw line (no
  double chin).
- ChatGPT (no credits) · chat "Capybara Character Designs" · ref: orange cat wardrobe sheet (`cat-wardrobe.png`)
- result: `capy/0-candidates-v3.png` (6 candidates, same pose + denim-blue star sweatshirt on all);
  comparison with the in-app cats: `capy/0-candidates-v3-vs-cats.png` (cat · abys · brit · candidates 1–6)
- the brick-era sheets (`1-outfits-15-v1..v4`, `2-bag-15-v1`, `3-umbrella-15-v1..v4`, `4-lock-15-v1..v2`) stay in the
  repo as history; they are no longer the base. Next steps wait until the owner picks a candidate.

```
Character design candidates for a NEW character: 6 different takes on a CAPYBARA, laid out in 2 rows of 3. Use the attached orange cat sprite sheet ONLY for the pixel-art technique, the figure size, the upright front-facing pose and the clothing style - and treat the cat as the bar for how ROUND, SOFT and CUTE the new character must feel. Do NOT reuse the cat's face, ears, eyes or markings: this is a capybara and must read as a capybara at a glance. All 6 candidates share the same capybara look - round and soft, nothing angular, no sharp corners anywhere: the head is shaped like a loaf of bread with fully ROUNDED corners and a soft gently-curved top, a little wider than it is tall; the muzzle is a large ROUNDED block with soft round corners that sticks out slightly forward and covers the lower middle of the face, but ALWAYS leaves a strip of lighter head fur below and beside it - the muzzle never reaches the clothing collar; two small dark nostrils sit high on the front of the muzzle; the eyes are small, calm and half-closed, set high and wide apart; the ears are TINY soft rounded nubs set far back on top of the head, NOT round bear ears; a serene, sleepy, gentle, huggable expression; a chubby round body with short thick legs; the feet and paws are DARK chocolate brown, clearly darker than the coat; NO tail; the bottom of the head closes with ONE clean 1-pixel dark-navy jaw line (the same colour as the other outlines) with the clothing collar immediately below it - no shadow band under the chin, no double-chin. Every candidate wears the same plain denim-blue crew-neck sweatshirt with a small white star on the chest, arms down at the sides, standing upright facing the viewer, feet flat on one baseline. The 6 variations: (1) classic warm brown coat; (2) lighter caramel coat with a cream muzzle; (3) reddish chestnut coat; (4) classic warm brown with a small orange yuzu fruit resting on top of the head; (5) baby capybara: rounder, bigger head, extra cute; (6) darker chocolate-brown coat, slightly fluffier. RENDERING - the most important part. GENUINE low-resolution pixel art on a coarse pixel grid, about 64 pixels wide per figure, shown enlarged with hard square pixels exactly like the attached cat: big clearly visible square pixels, NO anti-aliasing, NO soft edges, NO blur, NO gradients, NO airbrush shading, NO fur texture; flat colour fills only, 3 to 4 tones per material (base, one shadow, one highlight); one solid dark-navy outline, 1 pixel thick on the grid, around the whole figure and the clothes; small details simplified into a few pixels each. Each figure centred in its own cell with plenty of empty space around it, all the same height. Plain flat light grey-blue background (#EEF1F6), no text, no labels, no numbers, no shadows. Output 16:9.
```

## 2026-11-11 · capy · step 0 candidates v4 (uniform head colour) — awaiting pick

- Owner on v3: the head reads as two halves (dark top, light cheeks). v4: whole head in ONE fur colour = the body's,
  tiny shadow/highlight only; only the muzzle keeps its own slightly different tone. Everything else as v3.
- ChatGPT (no credits) · chat "Redraw Capybara Variants" · ref: `capy/0-candidates-v3.png`
- result: `capy/0-candidates-v4.png`. Note: candidates (2) and (5) came back with open dot eyes (v3's (2) had
  half-closed lines) — the rest keep half-closed eyes; mention when picking.

## 2026-11-11 · capy · ROUND ERA step 1: 15-outfit standing sheet v1 (from candidate 4, yuzu removed) — awaiting confirmation

- Owner picked candidate (4) of `0-candidates-v4.png`, minus the yuzu on the head. Same 15-outfit list as before,
  eyes covered by beanie/balaclava/hood on 12–14, all learned rules kept (uniform head colour, tiny ears, dark feet,
  muzzle clear of the collar, single 1px navy jaw line).
- ChatGPT (no credits) · chat "Generate sprite sheet" · refs: (1st) candidate 4 cropped (`ref-cand4.png`), (2nd)
  `abys-outfits-15-v2.png` (variety bar; ignore text)
- prompt = the previous 15-outfit prompt with the character paragraph swapped for the round candidate-4 description
  + "REMOVE the small yuzu fruit from the top of the head", and the 12/13/14 outfit lines now say the hat/balaclava/
  hood is pulled down so it COVERS THE EYES (only muzzle and nostrils show).
- result: `capy/1r-outfits-15-v1.png` (round era files use the `1r-` prefix; the brick era keeps `1-…4-`).
- checked: 15/15 outfits in order, eyes covered on 12/13/14, no yuzu on any head, uniform head colour, shorts on 2/3,
  duck print on 5, zip on 9, striped scarf + mittens on 14.

## 2026-11-11 · capy · round era step 1 v2: capy-only outfit list + natural eye coverage — awaiting confirmation

- Owner on v1: (a) eyes looked force-masked on 12-14 — cover them NATURALLY (brim/hood edge just over the eyes, face
  not masked); (b) outfits echoed the cats' (straw hat+ice pop, beanie+puffer, duffle+scarf, fur hood). Checked all
  three cats stage by stage (cat from `cat-states-15.png`, abys/brit from their 15 sheets — the per-stage table now
  sits in prompts.md) and rewrote capy's 15 so no same-stage kind repeats; theme: relaxed onsen/yuzu/cucumber.
  New kinds: 0 head towel + yuzu juice · 1 cucumber · 8 teddy fleece (swapped with 9 quilted) · 10 navy hanten robe ·
  11 mustard fringed poncho · 12 sherpa bucket hat · 13 plum puffer + knitted hooded scarf · 14 oversized cream
  bobble beanie + striped scarf + red mittens.
- ChatGPT (no credits) · chat "Pixel Art Sprite Sheet" · refs: `ref-cand4.png` + `abys-outfits-15-v2.png`
- result: `capy/1r-outfits-15-v2.png`; 4-character stage-by-stage comparisons `capy/compare-4way-0-4.png`,
  `compare-4way-5-9.png`, `compare-4way-10-14.png` (columns: cat · abys · brit · capy).
- checked: 15/15 correct; eyes on 12-14 hidden by brim/hood edge with the muzzle fully visible; no same-stage kind
  clash (closest call: abys 13 wears its puffer's hood up while capy 13 wears a separate knitted hooded scarf).
- prompt: v1's with the outfit list replaced by the new 15 and the eye-coverage clause reworded to "hidden NATURALLY:
  the hat brim or hood edge comes down just over the eyes so they cannot be seen, but the face is NOT masked - the
  muzzle and nostrils stay fully visible" (full text in the chat; outfit list in prompts.md).

## 2026-11-11 · capy · round era step 1 v3 (owner's five fixes) — awaiting confirmation

- Owner on v2 (resent after a garbled message): (1) straw hat back at stage 0; (2) cuter details overall (patterns,
  colour combos, small props); (3) add a windbreaker; (4) stage 14 = padded (quilted) hood; (5) 11 poncho and
  12 bucket hat unrecognisable → replace with instantly readable items; recognisable-and-cute beats unique, only
  identical cat combos avoided.
- v3 list (also in prompts.md): 0 straw hat + yuzu juice · 1 striped sage tank + cucumber · 7 corduroy + cream sherpa
  collar · 8 mint-lavender WINDBREAKER (new) · 9 teal quilted + mustard collar · 10 hanten + white wave pattern ·
  11 camel DUFFLE + forest-green scarf · 12 red/cream striped BOBBLE BEANIE (over the eyes) · 13 hooded scarf ·
  14 padded quilted hood up + striped scarf + mittens.
- ChatGPT (no credits) · chat "Pixel Art Sprite Sheet" (second of that name) · refs: `ref-cand4.png` +
  `abys-outfits-15-v2.png` · prompt = v2's with the outfit list above and "The outfits must be CUTE and instantly
  recognisable, with lovely little details" added.
- result: `capy/1r-outfits-15-v3.png` — checked: all five fixes landed, 15/15 in order, eyes on 12-14 hidden
  naturally by brim/hood edge, muzzle visible.

## 2026-11-11 · capy · round era step 1 v4 — awaiting confirmation

- Owner on v3: 1 cucumber out → watermelon slice; 12-14 eye coverage softened to "hat slipped down, eyes just barely
  peek out, sleepy dopey look"; 14 = puffy quilted hat WITH FUR TRIM; 12/13/14 strongly differentiated (hat shape,
  colour, coat length, scarf: orange short puffer+striped bobble beanie / ice-blue hip puffer+white earflap hat+plum
  scarf / deep-green ankle puffer+fur-trim padded hat+striped scarf+mittens); 6-9 redesigned bright & eye-catching
  (sky-blue striped knit · cream/coral varsity with yuzu patch · yellow/sky windbreaker · raspberry quilted).
- ChatGPT (no credits) · chat "Pixel Art Outfit Sheet" (second of that name) · refs: `ref-cand4.png` +
  `abys-outfits-15-v2.png` · full prompt in the chat, list in prompts.md (v4 block).
- result: `capy/1r-outfits-15-v4.png` — checked: all five fixes in, 15/15 in order, eyes peeking on 12/13 and
  nearly hidden on 14, three winter outfits clearly distinct, 6-9 bright.

## 2026-11-11 · capy · round era step 1 v5 — CONFIRMED STANDING SHEET

- Owner approved v4 except: on 12/13/14 the eyes were still fully hidden (the two dots are nostrils). v5's only
  change: "a pair of HALF-CLOSED SLEEPY EYES … peeks out in the narrow gap between the hat's bottom edge and the top
  of the muzzle". ChatGPT chat "Redraw Winter Capybara" · ref: v4 sheet.
- result: `capy/1r-outfits-15-v5.png` — THE base sheet for every later capy sheet (옷·눈 모양·크기 그대로 따를 것).
- Owner also pre-approved the pipeline: bag → umbrella → lock, each following this sheet exactly; umbrella coral-red,
  shaft straight from paw to top tip, canopy symmetric around the shaft, smooth even scallop, body height/proportions
  identical to standing (verify by overlay).

## 2026-11-11 · capy · round era step 2 (umbrella bag) · v1

- ChatGPT (no credits) · chat "Redraw Capybara Outfits" (second of that name) · refs: confirmed standing sheet
  `1r-outfits-15-v5.png` + `ref-cat-bag.png` · moss-green bag, coral J handle (capy carry colours)
- result: `capy/2r-bag-15-v1.png` — 15/15: bag identical behind the viewer-right shoulder, outfits/props unchanged,
  (0) juice and (1) watermelon kept, peeking eyes on 12-14 kept.

## 2026-11-11 · capy · round era step 3 (open umbrella) · v1

- ChatGPT (no credits) · chat "Redraw Umbrella Capybaras" · refs: `1r-outfits-15-v5.png` + `ref-cat-umb.png`
- prompt: the proven geometry + size clauses (shaft paw→top-centre tip, canopy symmetric around the shaft, smooth
  even scallop, coral-red; "CRITICAL SIZE RULE: body stays exactly the standing sheet's size - the umbrella is simply
  added above"). (0) umbrella replaces the juice, (1) the watermelon.
- result: `capy/3r-umbrella-15-v1.png` — visual check: 15/15 outfits correct, geometry right, peeking eyes kept.
- size verification: my pixel measurements on the originals were inconclusive (grid/palette noise); the owner now
  measures every sheet by overlaying it on the standing sheet and reports exact failing stages. Owner confirmed the
  BAG sheet is within 3% at all 15 stages (earlier 7% was their measurement artifact) → bag v1 stands.

## 2026-11-11 · capy · round era step 3 v2 (umbrella fixed) + step 4 (lock screen)

- Umbrella v2 · owner's overlay findings on v1: all 15 uniformly ~0.75× (fine, fixed at cut time), but the shaft sat
  ~10% of the canopy width to the LEFT of the canopy centre and ended under the canopy, and stages 5·6 bodies were
  ~5% taller. v2 prompt adds: "the small round tip sits at the very top of the canopy DIRECTLY ABOVE THE SHAFT …
  the same amount of canopy on the left of the shaft as on the right. The shaft must NOT be off to one side … shaft
  and tip form one continuous vertical line through the canopy's centre" and "especially figures (5) and (6), whose
  bodies must NOT be stretched taller". ChatGPT chat "Redraw Umbrella Pixel Art" · refs: v5 standing + ref-cat-umb.
  → `capy/3r-umbrella-15-v2.png` (supersedes v1). Visual check: shaft→tip continuous and centred on all 15.
- Lock screen v1 · ChatGPT chat "Capybara Lock Screen Redraw" · refs: v5 standing + `cat-04-lock-screen.png` ·
  strict colour-conversion prompt incl. "the hats sit slipped down with the HALF-CLOSED EYES PEEKING OUT just under
  the hat edge". (A first send attempt silently failed on a stuck tab; resent via a fresh composer.)
  → `capy/4r-lock-15-v1.png` — white on #20264A, all 15 outfits readable in grey (duck, stripes, windbreaker panels,
  quilting, wave hanten + tie, duffle toggles, striped beanie, earflap hat, fur-trim hat), eyes peeking on 12-14.
- Both await the owner's overlay check; originals in the ChatGPT chats named above.

## 2026-11-11 · capy · standing v6 — 12-14 faces rebuilt like figure 11's

- Owner: on 12-14 the two "nostrils" were actually the close-set eye lines (real muzzle hidden by the scarf). v6:
  faces built exactly like (11)'s — wide-apart half-closed eyes just under the hat edge, full normal muzzle with
  small round nostrils, scarf wrapped BELOW the muzzle. ChatGPT chat "Redraw Capybara Faces" · ref: v5.
- → `capy/1r-outfits-15-v6.png` — checked: 12/13/14 faces correct, 0-11 unchanged. NEW base sheet.
- Mishap logged: one wasted generation (chat "Redraw Capybara Lock Screen") — a stuck tab's composer still held the
  old lock prompt and the v6 text got appended, producing a navy lock sheet with the face fix; discarded.
- Owner's umbrella v2 verdict: size/height PASS; shaft still 3-6% of canopy width left of the tip → next umbrella run
  must put the tip EXACTLY above the shaft. Lock v1: size PASS; stage 14 scarf came out checked, must be STRIPED.

## 2026-11-11 · capy · 2단계 가방 시트 (v6 기준 재생성) · v2

- ChatGPT 이미지 생성 (브라우저, 크레딧 0) · 채팅 "Redraw Capybara Outfits" (`https://chatgpt.com/c/6af4209a-2da8-83ee-b05d-908cb3c5579d`)
- references: `1r-outfits-15-v6.png` (확정 서 있는 시트), `ref-cat-bag.png` (주황 고양이 가방 시트)
- 결과 → `capy/2r-bag-15-v2.png` (화면 캡처 3행 이어붙임; 원본은 위 채팅에서 다운로드)
- verdict: 15칸 모두 이끼색 가방 + 코랄 J손잡이, (0) 유자주스·(1) 수박 유지, 12–14 얼굴 v6 그대로(눈 양옆·주둥이 보임·목도리 아래) — 사용자 겹침 검사 대기

```
Redraw the first reference image (a pixel-art capybara in 15 outfits, 3 rows of 5) EXACTLY: same character, same 15 outfits in the same order and same cells, same upright pose facing the viewer, same size, same faces (on the last three figures the wide-apart half-closed eyes peek out under the hats, the full muzzle with small nostrils shows, the scarf sits below the muzzle), same crisp pixel-art style with the dark navy outline, same plain flat light grey-blue background (#EEF1F6), no text, no labels, no numbers. Add ONLY one thing to every figure, carried the same way as the orange cat in the second reference image: a small MOSS-GREEN umbrella bag slung on the back, its rounded end visible behind the body on the viewer's RIGHT at waist-to-shoulder height, with a folded umbrella inside so that only the umbrella's curved J-shaped CORAL-RED handle sticks up out of the bag above the shoulder. The bag and folded umbrella are identical on all 15 figures and must not cover the outfit on the front of the body. Everything else stays exactly as in the first reference: arms down at the sides, figure (0) still holding its glass of yuzu juice and figure (1) its slice of watermelon, every outfit's hat, scarf, print and colours unchanged.
```

## 2026-11-11 · capy · 3단계 우산 시트 (v6 기준 재생성, 꼭지 정중앙) · v3

- ChatGPT 이미지 생성 (브라우저, 크레딧 0) · 채팅 "Redraw Umbrella Capybaras" (`https://chatgpt.com/c/6af4228e-6328-83ee-b8e7-519c9dd5554f`)
- references: `1r-outfits-15-v6.png`, `ref-cat-umb.png`
- 결과 → `capy/3r-umbrella-15-v3.png` (v2 대체; 원본은 위 채팅에서 다운로드)
- verdict: 시각 확인 — 15칸 모두 막대→꼭지 수직 일직선, 덮개 막대 중심 대칭, 고른 스칼록, 12–14 얼굴 v6 유지, (0)·(1) 소품 제거 — 사용자 겹침 검사 대기

```
Redraw the first reference image (a pixel-art capybara in 15 outfits, 3 rows of 5) EXACTLY: same character, same 15 outfits in the same order and same cells, same upright pose facing the viewer, same faces (on the last three figures the wide-apart half-closed eyes peek out under the hats, the full muzzle with small nostrils shows, the scarf sits below the muzzle), same crisp pixel-art style with the dark navy outline, same plain flat light grey-blue background (#EEF1F6), no text, no labels, no numbers. CRITICAL SIZE RULE: every body stays exactly the first reference's size and proportions - the umbrella is simply added above; especially figures (5) and (6) must NOT be stretched taller. Add ONLY one thing to every figure, held the same way as the cat in the second reference image: an open CORAL-RED umbrella held overhead in one raised paw. Umbrella geometry, identical on all 15 figures: the straight shaft runs from the paw in ONE CONTINUOUS VERTICAL LINE up through the canopy to the small round tip at the very top of the canopy; the tip sits EXACTLY directly above the shaft, ZERO horizontal offset, shaft and tip forming one single straight vertical line; the canopy is a wide smooth symmetric dome centred on that line, the same amount of canopy on the left of the shaft as on the right, with a smooth even scalloped bottom edge. On figures (0) and (1) the umbrella replaces the glass of yuzu juice and the slice of watermelon - those props are gone. Everything else stays exactly as in the first reference: every outfit's hat, scarf, print and colours unchanged.
```

## 2026-11-11 · capy · 사용자 검사 결과 (가방 v2 · 우산 v3) — 17:14

- 가방 v2: **통과** (15단계 모두 머리·키 비율 2% 안쪽).
- 우산 v3: 몸 비율 통과(칸 대비 0.87배로 일정). 막대는 여전히 15개 모두 꼭지보다 덮개 폭의 약 6~7% 왼쪽.
  ChatGPT가 3번 연속 못 맞춰서 **우산은 더 생성하지 않음** — 덮개+꼭지를 막대 위로 수평 이동하는 후처리는
  사용자가 처리 (에셋 재단 시에도 같은 방식). 우산 v3 = 최종 원본.

## 2026-11-11 · capy · 4단계 잠금화면 (v6 기준 재생성, 14 줄무늬 목도리) · v2

- ChatGPT 이미지 생성 (브라우저, 크레딧 0) · 채팅 "Convert Capybara Colors" (`https://chatgpt.com/c/6af42386-9e24-83ec-ad1e-e02f49c18ccb`)
- references: `1r-outfits-15-v6.png`, `cat-04-lock-screen.png`
- 결과 → `capy/4r-lock-15-v2.png` (v1 대체; 원본은 위 채팅에서 다운로드)
- verdict: 시각 확인 — 흰색/라벤더그레이 on #20264A, 12–14 얼굴 v6 그대로(눈 양옆·주둥이 보임), (14) 목도리 줄무늬(체크 아님),
  (0) 주스·(1) 수박 유지, 유자 프린트·지퍼 유지 — 사용자 겹침 검사 대기

```
THIS IS A COLOUR CONVERSION ONLY. Redraw the capybara of the first reference image (15 outfits, 3 rows of 5) in EXACTLY the monochrome lock-screen style of the second reference image (the orange cat's lock-screen set): pure WHITE figures with light lavender-grey and mid-grey pixel shading for the fur, outfit details and folds, no other colours, NO dark outline, crisp hard-edged pixels, on a flat dark navy background (#20264A). Nothing else changes: same 15 outfits in the same order and cells, same pose, same size, same props - figure (0) keeps its glass of yuzu juice and figure (1) its slice of watermelon, drawn in greys. FACES, copied from the first reference: the rounded muzzle is shaded light lavender-grey so it reads against the white head, with its two small round nostrils in dark grey; the half-closed eyes are two short dark-grey lines set high and WIDE APART; on figures (12), (13) and (14) those wide-apart eyes peek out just under the hat edge, the full muzzle with its small nostrils is completely visible, and the scarf sits BELOW the muzzle, around the neck. Outfit details that must stay exact: the yuzu prints on figures (0) and (2) are YUZU fruits (a round citrus with a leaf), not apples; figure (9)'s quilted jacket keeps its front ZIP line; figure (14) keeps its red mittens (drawn grey) and its scarf is STRIPED - alternating light and dark bands across the scarf - NOT checked, NOT plaid, NOT a grid pattern. Every outfit must stay recognisable from its shape and grey shading alone. All 15 figures the same size, feet on the same baseline in each row, centred in their cells, no text, no labels, no numbers.
```

## 2026-11-11 · capy · umbrella v3 canopy re-centred in post (overlay check by the other session)

- ChatGPT missed the shaft-under-tip rule three times (v1 −10%, v2 −3…6%, v3 −6…7% of canopy width). Instead of a
  fourth run, the canopy (with its outline and soft edge) is moved sideways so the tip knob sits exactly above the
  shaft: `tools/recentre_umbrella.py in.png out.png` (uses `tools/figs.py` to find the 15 figures as blobs). Shifts
  on v3 were −5…−7 px each; the figure stays in front of the moved canopy.
- result: `capy/3r-umbrella-15-v3-centred.png` (preview made from the capture). Apply the same script to the
  full-resolution original before cutting the umbrella assets.
- overlay checks against standing v6 (feet + body centre aligned): bag v2 PASS (head/height within 2%), umbrella v3
  body PASS (uniform 0.87× of the standing figure — rescale once when cutting), lock v2 PASS (silhouettes and
  heights within ~3%; 14 scarf striped).

## 2026-11-11 · capy · 14단계 단독 — 패딩 후드 (주인 의견 반영) · 서 있기 v1

- 주인(17:23): 14단계는 뜨개 모자가 머리에 따로 얹혀 있고 귀가 밖에 나와 있음 → 초록 롱패딩에 **붙은 패딩 후드**를
  쓴 모습으로(후드가 어깨까지 이어짐, 귀는 후드 안, 후드 털 테두리가 눈을 반쯤 가림, 눈은 양옆 넓은 자리,
  주둥이·콧구멍 평소 크기). 줄무늬 목도리·빨간 장갑 유지. **나머지 14개는 재생성 금지** — 14단계 한 마리만
  단독으로 4종(서기·가방·우산·잠금) 생성, 사용자가 기존 시트에 끼워 넣음.
- ChatGPT (크레딧 0) · 채팅 "Redraw Hooded Capybara" (`https://chatgpt.com/c/6af42619-bd0c-83ec-bfb4-a80b57c8021c`)
- reference: `1r-outfits-15-v6.png` · 3회 생성(1차: 눈 완전 가림, 2차: 여전히 가림, 3차 채택)
- 결과 → `capy/stage14-stand-v1.png` (원본은 위 채팅에서 다운로드)
- verdict: 후드가 코트와 한 몸으로 연결, 귀 안 보임, 크림 털 테두리, 반감긴 눈 두 줄이 털 테두리 바로 아래 양옆에
  보일 듯 말 듯, 주둥이·콧구멍 정상, 줄무늬 목도리·빨간 장갑 유지 — 사용자 겹침 검사 대기

```
(1차) From the attached reference sheet (a pixel-art capybara in 15 outfits, 3 rows of 5), redraw ONLY the very last figure - bottom-right corner, figure (14), the one in the deep-green ANKLE-LENGTH puffer coat - as ONE single large figure, centred on a plain flat light grey-blue background (#EEF1F6), same crisp pixel-art style with the dark navy outline, same upright pose facing the viewer, same body shape and proportions as in the sheet. Make ONE change to its head wear: REMOVE the separate quilted hat that sits on top of the head. Instead, the deep-green puffer coat has its own attached padded HOOD, worn UP over the head: the hood is part of the coat, made of the same deep-green quilted puffer material with the same segment lines, and it connects seamlessly into the coat's shoulders with no gap - one continuous garment. The ears are INSIDE the hood, not visible. The hood's face opening is edged all around with a cream-coloured FUR TRIM, and this fur-trimmed edge comes down LOW over the face so it HALF-COVERS the eyes: the two half-closed eyes stay in their usual wide-apart positions near the sides of the head, each eye half hidden under the fur trim and half visible, a sleepy peeking look. The big rounded lighter-tone MUZZLE with its two small round nostrils stays fully visible at its normal size, below the eyes. Keep exactly as in the reference: the red-and-cream STRIPED scarf (alternating bands, not checked) wrapped around the neck BELOW the muzzle, the red mittens, the dark chocolate feet. No text, no labels, no numbers.

(2차 수정 — 눈이 완전히 가려져서) Perfect - keep this exact image, with ONE small fix: the eyes are currently completely hidden under the fur trim. Show them HALF-visible: the two half-closed eyes (short dark horizontal lines) sit WIDE APART near the left and right sides of the head, between the fur trim and the muzzle; the fur-trimmed hood edge covers only the TOP half of each eye, so the lower half of each dark eye line clearly peeks out below the fur. Everything else stays exactly the same...

(3차 수정 — 그래도 가려져서, 채택본) The eyes are still invisible. Fix it this way: lift the cream fur trim a little HIGHER on the face, so that between the fur trim and the muzzle there is a clearly visible band of orange-brown face fur. In that band, draw the TWO EYES as short dark horizontal lines (half-closed sleepy eyes), set WIDE APART near the left and right edges of the face, with the top of each eye line touching the bottom edge of the fur trim. The eyes must be clearly visible dark pixels. Everything else stays exactly the same: attached deep-green padded hood, cream fur trim, muzzle with two small round nostrils, red-and-cream striped scarf, red mittens, same pose, same size, same background.
```

## 2026-11-11 · capy · 14단계 서 있기 v1 후처리 (주인: "눈이 작아졌잖아")

- 단독 그림의 눈 줄이 다른 단계보다 짧고 얇았음(주둥이 폭 대비 0.25·0.06 vs 다른 단계 0.30·0.09) → 눈 줄을 같은
  비율(원본 기준 33×10px, 진한 남색 #0C0E1B)로 다시 그림. 털색도 다른 단계보다 붉게 나와서(R 251 vs 237) 따뜻한
  색 픽셀의 R을 0.94배, 밝은 털은 G+3·B+5로 맞춤 → 털 (237,149,80), 주둥이 (207,108,61).
- 결과: `capy/stage14-stand-v1-fixed.png`. 시트에 끼울 때 배율 0.31(주둥이 폭 기준), 발·몸 중심 맞춤:
  `tools/swap14.py sheet single 0.31 out` (잠금화면은 `--lock`).
- 가방·우산·잠금화면 14단계도 같은 눈 크기·털색으로 맞출 것(안 맞으면 같은 후처리).

## 2026-11-11 · capy · 14단계 서 있기 v2 (주인: "눈 위치는 그대로, 모자가 더 안쪽으로 감싸야지")

- v1-fixed는 눈 줄을 늘리면서 눈이 바깥(얼굴 가장자리)으로 간 것처럼 보였음. 다른 단계의 눈 자리(주둥이 중심
  ±0.62 mw, 주둥이 위 0.10 mw, 길이 0.28 mw, 두께 0.09 mw — mw=주둥이 폭)에 눈을 다시 그리고, 후드 털 테두리를
  행마다 안쪽으로 늘려(테두리 그림은 그대로, 가로로만 당김) 안쪽 끝이 주둥이 중심 ±0.80 mw에 오게 함 → 눈 바깥쪽
  절반이 털에 가려짐. 털색은 furfix(R×0.94, 밝은 털 G+3·B+5).
- `tools/hoodwrap.py stage14-stand-v1.png out.png 0.80` → `tools/furfix.py` → `capy/stage14-stand-v2.png`.
  시트 배율 0.31(`tools/swap14.py`). 가방·우산·잠금 14단계 단독 그림에도 같은 순서로 적용.

## 2026-11-11 · capy · 14단계 단독 가방·우산 (생성 직후 중단됨) + 잡음 2건

- 주인 결정(17:48, 사용자 전달)으로 **14단계 단독 작업 전면 중단**: 13~15번 얼굴이 1~12번보다 ~10% 작고 눈 자리도
  달라, 4장 전부 처음부터 다시 뽑기로. 사용자가 (1) 마스터 프롬프트 템플릿(서기·가방·우산·잠금, 동물·옷 칸만 교체)과
  (2) 자동 검사·크기 맞춤 도구를 만들어 푸시하면, 그 템플릿 그대로 서기부터 재생성 예정. 그때까지 생성 중단.
- 중단 전에 생성돼 있던 것(기록용으로만 보존, 사용 안 함):
  - `capy/stage14-bag-v1.png` · 채팅 "Redraw Hooded Capybara Outfit" (`https://chatgpt.com/c/6af4288c-a098-83ee-896b-dc46ae303d32`)
    · refs: stage14-stand-v1 + ref-cat-bag · 1차는 가방이 통째로 빠져 2차 수정으로 채택 (이끼색 가방+코랄 J손잡이 OK)
  - `capy/stage14-umbrella-v1.png` · 채팅 "Redraw Capybara Umbrella" (`https://chatgpt.com/c/6af429c1-9f58-83e8-a90c-866f81ebbda5`)
    · refs: stage14-stand-v1-fixed + ref-cat-umb · 1차는 접힌 우산+가방으로 잘못 나와 2차 수정으로 채택 (펼친 우산, 꼭지 정중앙 OK)
- 잡음: (a) 잠금 변환용 새 채팅(`…/c/6af42b00-9b5c-83e8-8bbc-2bd881203d11`)에서 작성기에 남아 있던 이전 우산 초안이
  대신 전송돼 컬러 우산 중복 1장 생성(폐기). 같은 채팅에서 잠금 프롬프트를 이어 보냈으나 생성 완료 전에 중단 지시가
  와서 결과 미수거(폐기). — 작성기 초안은 지우고 **보내기 직전에 내용 재확인**까지 해야 함.

## 2026-11-11 · capy · 전면 재생성 결정 + MASTER TEMPLATE v2 + sprite_kit

- 주인(17:46): 13~15번이 1~12번보다 작고 눈 자리가 다름 → 4장 전부 처음부터 다시. 앞으로 동물·옷만 바꿔 계속
  추가할 수 있게 프롬프트를 한 번에 확실히 정하기로.
- 측정(`tools/sprite_kit.py check`): 서기 v6에서 13·14·15번 주둥이 폭이 중앙값보다 −9·−12·−9%, 11·12번은 몸(주둥이
  위~발)이 +8·+12%. 가방·우산·잠금도 같은 경향.
- prompts.md 맨 위에 ★ MASTER TEMPLATE v2: 파이프라인, 슬롯({ANIMAL}{LOOK}{OUTFIT 0..14}{CARRY}{LOCK HINT}),
  고정 문단(FACE·SIZE·PIXEL·BACKGROUND), 프롬프트 S·B·U·L, capy 슬롯 값.
- `tools/sprite_kit.py`: check(주둥이 기준 머리 크기·몸 길이·눈 자리 표 + 경고), fit(4장 공통 주둥이 폭),
  build(15개를 480×560, 발 y=555, 주둥이 폭 동일하게 앱용 PNG로). 생성 크기 차이는 build가 없앰.

## 2026-11-11 · capy · ★ 마스터 템플릿 v2 — 프롬프트 S (서기 15벌) · v1~v5

- ChatGPT (크레딧 0) · 채팅 "Wardrobe Sprite Sheet Design" (`https://chatgpt.com/c/6af4445f-6a84-83ec-8b53-a1271b5214e0`)
- 프롬프트 S를 템플릿 그대로 조립(고정 문단 FACE·SIZE·PIXEL·BACKGROUND 원문 그대로 + capy 슬롯 값).
  references: (1) `ref-cand4.png` (후보 4 단독, 유자 없음) · (2) `1r-outfits-15-v6.png`
- 생성 경과 (매번 sprite_kit check):
  - v1 `capy/m2-stand-15-v1.png` → flags: #11 body+8%, #12 body+8%, #15 눈 가림
  - v2 `…-v2.png` (11·12·15 지목 수정) → #11 body+9%, #15 눈 가림
  - v3 `…-v3.png` (10·14 지목 수정) → #8 head+7%, #13·#14 눈 가림 (15는 통과)
  - v4 `…-v4.png` (7·12·13 지목 수정) → 5개 플래그로 악화 (#1·#11 head+7%, #12 body+7%, #13 head-7%+눈, #15 head-7%)
  - v5 `…-v5.png` (두 번째 그림으로 되돌려 10·14만 수정) → 고배율 재캡처 기준
    flags: #13 head-8%+눈, #14 head-9%+눈, #5·#10·#15 측정 불가(캡처에 UI 겹침)
- 소견: ChatGPT가 지목 수정할 때마다 다른 칸이 ±7% 흔들려 5회에서 중단. 저배율 캡처(주둥이 ~28px)에서는
  플래그가 부풀려짐 — 100% 배율 재캡처로 상당수 해소. v5 고배율 눈 확인: 12·13·14 모두 눈 두 줄이 모자 아래
  양옆에 보임(체커는 모자 그림자 간섭으로 "hidden"으로 읽는 것으로 보임). 오른쪽 열(5·10·15)은 라이트박스
  UI 버튼이 겹쳐 측정 불가 — 원본 다운로드 후 재검사 필요.
- 프롬프트 전문은 prompts.md 템플릿 + capy 슬롯과 동일(지목 수정 4건은 채팅에 있음). 원본은 위 채팅에서 다운로드.

## 2026-11-11 · capy · 서기 v5-clean 재캡처 + v6 (13·14·15 수정)

- 사용자 판정(19:57): head ±%는 무시(build가 주둥이 폭으로 보정), 중요한 건 body와 눈 자리.
  **1~12번(단계 0~11)은 v5로 확정** — 칸 단위로 섞어 써도 됨.
- v5-clean: 라이트박스 100%에서 마우스·버튼·하단 바 없이 3행 분할 캡처 후 이어붙임
  → `capy/m2-stand-15-v5-clean.png` (c124fce2). check: 1~12 전부 통과 (#13·#14는 모자에 눈이 안 가려진 상태,
  #15는 귀가 후드 밖+콧구멍이 줄로 — 아래 v6에서 수정).
- v6: 같은 채팅("Wardrobe Sprite Sheet Design")에서 13·14·15번만 지목 편집 —
  "모자/후드 테두리가 양쪽 눈 줄의 바깥쪽 절반만 덮고 눈 자리·크기는 1~12번과 동일;
  15번은 귀를 후드 안에(후드 옆이 볼을 감싸 목도리 뒤 패딩 깃으로), 콧구멍은 점 두 개로."
  → `capy/m2-stand-15-v6.png` (같은 방식 클린 캡처).
  check: 1~12 전부 통과(v5와 동일 수준) · 13·14·15는 눈 바깥쪽이 모자에 덮여 체커가 eye hidden으로 읽음
  (의도된 상태; head -7~8%는 모자가 머리 윤곽을 덮은 탓). 시각 확인: 13·14 챙이 눈 바깥 절반을 덮고 안쪽이 보임,
  15 귀 없음·털 테두리·콧구멍 점 2개.
- 사용자 검사 대기 — 통과 시 B(가방) 진행.

## 2026-11-11 · capy · 서기 v7 — 가이드 그림으로 13·14·15 눈/모자 아치 수정

- 사용자 검사(20:07): v6 1~12 통과. 13~15 실패 — 눈이 주둥이 폭의 0.10만큼 내려가 주둥이 윗선에 붙었고,
  모자가 눈을 하나도 안 덮음 (증거 `capy/m2-stand-15-v6-eyecheck.png`, 가이드 `capy/guide-hat-edge.png`).
- 같은 채팅에 가이드 첨부 + 지목 편집: "눈을 먼저 (11)번과 같은 높이(주둥이 위 틈 하나)·간격·길이로 그리고,
  모자/후드 가장자리를 빨간 선처럼 아치로 — 가운데(이마)는 눈 위, 양옆은 볼을 따라 내려와 각 눈의 가운데를
  지나 바깥 절반만 덮기. 눈 내리지 말기. 빨간 선은 그리지 말기. (14) 귀는 후드 안·콧구멍 점 2개 유지."
- 캡처: 하단 바를 드래그로 위로 치운 뒤 3행 아래 여백까지 포함해 캡처 (v5-clean·v6의 발끝 잘림 수정)
  → `capy/m2-stand-15-v7.png`
- check: 1~12 전부 통과 (body 2.79~3.07, 눈 dx 0.64~0.69 dy 0.09~0.11) · 13~15 eye hidden은 바깥 절반이
  덮인 의도된 상태, head -7%는 모자 탓(무시 대상). 시각 확인: 13~15 눈이 주둥이 위 틈을 두고 (11)과 같은
  높이, 챙/털 테두리가 아치로 내려와 바깥쪽을 덮음. 사용자 검사 대기.

## 2026-11-11 20:20 · capy · 서기 v7 검사 + 주인 결정 (11번·15번 옷, 눈 덮기)

- v7 (`m2-stand-15-v7.png`, 발끝 여백 포함): 1~12 통과. 13~15 눈 높이는 이제 1~12와 같음
  (`m2-stand-15-v7-eyecheck.png`, 파란 상자 = 표준 눈 자리). 하지만 모자가 눈을 거의 안 덮음.
- 주인이 고양이들과 비교(`compare-cats-capy-11-15.png`, 위 3줄 고양이 앱 그림 / 아래 카피바라):
  - 15번(단계 14) "패딩 이상함": 털모자를 머리에 얹은 것처럼 보이고 패딩이 짧음 → **고양이처럼**: 패딩과 같은 초록
    큰 둥근 후드가 머리 전체를 감쌈(코트와 한 몸), 크림 털 링이 얼굴 둘레, 귀는 후드 안, 무릎까지 긴 패딩,
    빨강·크림 줄무늬 목도리, 빨간 벙어리장갑, **입김 없음**.
  - 11번(단계 10) "트임에 목도리, 안 따뜻해 보임" → 주인 "알아서" → **남색 더블 피코트(목까지 단추 잠금) + 겨자색 목도리**
    (고양이들 11번 = 단추 잠긴 울코트 + 목도리와 같은 계열, 12번 낙타색 더플과도 구분됨).
  - 13~15 눈: **바깥 절반 덮기** 유지(주인 선택).
- prompts.md capy `{OUTFIT}` 슬롯 (10)·(14) 갱신.
- tools: `sprite_kit.py compose`(칸별로 통과한 것만 모아 한 장), `faceguide.py`(표준 눈 상자 그려 비교).

## 2026-11-11 · capy · 서기 v8 — 11번 피코트 · 15번 고양이식 후드 · 13~15 눈 바깥 절반 덮기

- 같은 채팅, 가이드(`guide-hat-edge.png`) 재첨부 + (10)·(12)·(13)·(14) 지목 편집 (1-based 11·13·14·15):
  (A) (10) 한텐 → 남색 더블 피코트, 단추 두 줄로 목까지 잠김, 앞 트임 없음 + 겨자 목도리.
  (B) (14) 털모자 얹은 모양 폐기 → 패딩과 같은 초록의 크고 둥근 후드가 머리 전체를 감쌈(코트와 한 몸,
  어깨에서 이어짐), 크림 털 링이 얼굴 둘레, 귀는 후드 안, 무릎길이 패딩, 줄무늬 목도리, 빨간 벙어리장갑, 입김 없음.
  (C) (12)(13)(14) 눈은 그대로 두고 챙/털 링 양옆을 눈 위로 내려 바깥 절반은 모자 뒤로, 안쪽 절반만 보이게.
- 캡처: 하단 편집 바를 핸들 드래그로 치워 가며 3행 발끝 아래 여백까지 → `capy/m2-stand-15-v8.png`
- check: 1~12 전부 통과 · 13~15 eye hidden = 바깥 절반 덮임(의도) · 13 body -6%는 경계선(검사 때 확인 요).
  시각 확인: (10) 단추 잠긴 피코트 ✓ · (14) 후드 일체·털 링·귀 없음 ✓ · 13~15 눈 안쪽 절반만 보임 ✓.

## 2026-11-11 · capy · 서기 v9 — 13~15 눈 덮기 강화 + 13번 키 보정

- 사용자(20:57): v8 1~12 확정(그 칸들을 사용). 남은 것: 13~15 눈 덮기가 약함(가장자리가 눈 끝에 닿기만 함) ·
  13번이 6% 짧음.
- 같은 채팅, (12)(13)(14) 지목 편집: "모자/털 링 양옆 가장자리를 눈 길이의 절반만큼 더 안쪽으로 — 보이는 눈
  가로줄이 (11)번 눈의 절반 길이(바깥 절반은 모자 뒤로), 눈 안쪽 끝 자리·높이는 그대로. (12)는 다리·몸 길이를
  (11)과 동일하게."
- 같은 방식 클린 캡처 → `capy/m2-stand-15-v9.png`
- check: 13 body 2.69로 중앙값 수준(키 보정됨) · 13~15 eye hidden = 바깥 절반 덮임(의도) · 시각 확인: 보이는
  눈이 짧은 안쪽 토막만 남음. 1~12는 어차피 v8 확정분 사용(이번 판 1·3·8·10의 eyeL x 0.60 미세 플래그 무관).
- 사용자 검사 대기 — 통과 시 B(가방).
