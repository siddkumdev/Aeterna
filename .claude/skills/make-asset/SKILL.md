---
name: make-asset
description: The asset-building workflow for Endless Watch. Takes ANY 3D asset (towers, huts, houses, enemies, villagers, props) from questions to Siddharth, through design variants he picks and mixes, to the real Blender model with moving parts and VFX anchors, renders, critic review, validation, export and logging, until Siddharth approves it. Use whenever asked to design, model, build or revise an asset ("asset building").
---

# make-asset: the asset-building workflow

Built from how the Fire Tower and the bomb tower were made (2026-10-17). Siddharth decides the design; Claude proposes, builds and checks. **Never assume a design choice: ask.**

## 0. Load context (every time)
Read before doing anything:
- `art/art_bible.md`, `art/decisions.md` (newest entries win), `art/palette.json`.
- `docs/GAME_SPEC.md` for the asset's role and stats; `docs/ASSET_LIST.md` for its id, priority, budget and notes.
- `docs/VFX_NOTES.md` (effects already requested).
- Standing rules from Siddharth: magic is black/orange/red, never blue (blue = Foresight only, purple = Warden); glowing parts are VFX, not geometry; VFX are built in Godot only after all towers and major assets exist; no time estimates; no AI-generated or third-party assets.

## 1. Ask first (no assumptions)
Before writing any geometry, message Siddharth with:
1. The asset's role and stats in plain words (from the spec), so he remembers what it does.
2. Questions, not guesses. Always ask:
   - Does he have pictures, a sketch or ideas? (Pinterest pins, screenshots, a phone doodle with arrows, a photo of a toy; one short label per picture saying what to take from it.)
   - Anything he already knows he wants or does not want (theme, e.g. "magic bombs", materials, mood)?
   - Any open spec question that changes the look (e.g. the asset's name, moving parts, what it shoots).
3. Wait for his answer. If he has no references, go to step 2 with the moodboard as the source. If a spec gap appears later, stop and ask again.

## 2. Variant round (pick and mix)
1. Write `assets/generators/make_<short>.py` with a `VARIANTS` dict of **4 clearly different ideas (A-D)**, each tied to the asset's role (how it looks AND how it would attack/behave). Use `tools/blender_common.py` helpers, palette names only.
2. Build each: `blender --factory-startup -b -P assets/generators/make_<short>.py -- A` (saves `assets/blend/<short>_A.blend`; variants are not exported).
3. Validate each (`python tools/validate_asset.py assets/blend/<short>_A.blend`).
4. Render the sheet: `python tools/make_variant_sheet.py assets/previews/<short>/variants_vNN.png A=assets/blend/<short>_A.blend B=... C=... D=...` (day + golden hour, grey room background).
5. Look at it yourself, then run the **art-critic** agent on it (every round). Fix blocking issues (things reading as the wrong object, hidden features, z-fighting, collapsed points) and re-render.
6. Send the sheet (SendUserFile) plus a table: letter, idea, how it attacks/behaves. Ask him to pick or mix ("B, but with C's roof") or mark up a screenshot.
7. If he mixes, make the next letters (E-H, I-L...) as combinations and repeat. Keep earlier sheets; number them `variants_v01`, `v02`...

## 3. Build the chosen design as the real asset
Add `build_final()` (or a dedicated `build()`) and export:
- **Name** `ew_<category>_<short>_vNN`; root object origin at the base centre.
- **Grid**: buildings 2 x 2 cells (0.10 m) filled ~85%; trees, props, characters 1 x 1; heights in whole-ish cells (towers ~3-4 cells). Low and wide vs tall must separate tower types at a glance.
- **Detail level** = Fire Tower v01 ("about right": masonry blocks, trim, frames, sills, one or two story props), within the triangle budget in CLAUDE.md.
- **Moving parts** via `bc.assemble()`: root + `__head` (turns to aim) + any part that animates (`__cauldron` tips, etc.), each pivot at its rotation point. No rigs.
- **VFX anchors** via `bc.anchor()`: every glow, fire, brew, rune, fuse or orb is an empty `__<name>_anchor` (numbered when repeated). The model only provides the dark socket or opening it sits in. Log each one in `docs/VFX_NOTES.md`.
- Pitfalls learned:
  - Pointed cones lose their tip to the bevel clamp: set `obj["no_bevel"] = True`.
  - Two tops at the same height z-fight (flicker): offset one slightly.
  - The review camera looks from the front-right; put signature features where it can see them (the bomb tower's side cauldron was hidden at the back).
  - A solid cone used as a flame stand-in reads as a roof; previews use flame-tongue clusters.
  - Workbench previews do not show emission; judge glow in the lighting strip.
  - Check which way a tilt goes (rotation about X with a positive angle tips the top toward -Y, the front).

## 4. Check and render every version
1. Generate: `"<BLENDER_EXE from local.env>" --factory-startup -b -P assets/generators/make_<short>.py`
2. Validate: `python tools/validate_asset.py assets/blend/<short>.blend` must print OK (counts all parts against the budget).
3. Sheet: `python tools/make_sheet.py assets/blend/<short>.blend assets/previews/<short>/final_vNN`
4. Lighting strip: `python tools/render_lighting.py assets/blend/<short>.blend assets/previews/<short>/final_vNN` (5 presets; preview-only stand-ins appear at `__orb_anchor` / `__fire_anchor`).
5. Look at both yourself, then run the **art-critic** agent (every round). Apply its fixes before sending.
6. Once exported, add/update the asset in the diorama layout and run the **diorama-shot** skill to check it next to the other real assets and against the board budget.
7. Bring it into Godot with the **godot-import** skill (`python tools/sync_to_godot.py <glb>`, must print 0 FAIL).

## 5. Show Siddharth
Send **the lighting strip and the 6-view sheet** (SendUserFile). In the message:
- what changed and why (one line per change), triangle count vs budget, the parts that move, the VFX anchors;
- anything that looks rough, said plainly;
- the questions you need answered (numbered);
- the commands to regenerate, validate and render it himself.
He may answer with text or a marked-up screenshot. Read every mark-up note; if unsure what a mark means, ask.

## 6. Revise
Every change round makes a **new version** (`_v01` -> `_v02`), keeping old exports and preview folders for comparison. Then repeat steps 4-5.

## 7. Log (every version)
- `assets/ASSETS.md`: one row per version (name, tracker `id`, generator, version, tris, status, notes on parts and anchors).
- `art/decisions.md`: each choice he makes (picked variant, colour rules, VFX direction).
- `docs/VFX_NOTES.md`: every effect he mentions.
- `docs/ASSET_LIST.md`: the asset's row reflects the chosen design.
- Then run the **tracker-sync** skill (every round): regenerates and republishes the live tracker and moves the item's status forward.
- Then run the **github-sync** skill (every round): commit and push to `main`.
- New durable preferences go to memory.

## 8. Done
An asset is done **only when Siddharth or his teammate explicitly approves it** (either may approve, decided 2026-10-18). Then set its `ASSETS.md` status to "approved by <name> (date)" and mark it BUILT/approved in the asset list. Until then its status is "awaiting Siddharth".
