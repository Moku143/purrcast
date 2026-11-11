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
