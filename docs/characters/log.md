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
