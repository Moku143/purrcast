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
