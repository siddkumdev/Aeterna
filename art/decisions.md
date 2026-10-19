# Art decisions log

Newest at the bottom. Record every decision Siddharth makes, with the board ids he referenced.

## Decided
- 2026-10-12: Everything built from scratch via Blender; no AI 3D generators, no external asset packs.
- 2026-10-14: Verticality via flyers (airspace) and drop spells. No dungeon.
- 2026-10-14: Moodboard `Meta Hackathon.bee` (34 images) read with bee-board-reader. Manual groups: #8 with towers, #43 as flyer/airship reference.
- 2026-10-14: New pins noted: #43 airships (flyers), #42 dark creature sheet (hidden/fog enemies), #44/#46/#47 impact + ring VFX (drop spells).

- 2026-10-14: Enemy DESIGN (look of the models) follows the 'design of the enemies' images #24, #25, #27 (+ #29 for faceted proportions): faceted low-poly, jewel accents. Enemy TYPES (which enemies exist) come from the 'types of enemies' images #10, #13, #14, #15, #36, #42 as roster ideas only, redrawn in the faceted style. Settles the cute-vs-spooky question.

- 2026-10-14: #29 (chibi girl) is the VILLAGER design reference: chibi proportions, faceted, warm clothing.
- 2026-10-14: Palette in art/palette.json approved as the overall level vibe (Siddharth could not judge exact hex values; see art/palette_preview.png).
- 2026-10-14: Colour method: PALETTE ATLAS (Siddharth's choice). One 128px swatch texture built from palette.json; models use UVs into it; one shared material. Changing a colour in palette.json recolours everything on regeneration.

- 2026-10-16: EVERYTHING IS GRID-BASED (Siddharth). 1 cell = 5 cm; board 12 x 12 cells; all gameplay measures and model footprints in whole cells. Benchmark assets will be rescaled to the footprints in docs/GAME_SPEC.md when asset building starts.

- 2026-10-16: ALL BUILDINGS ARE ONE UNIFORM SIZE (Siddharth): 2 x 2 cells footprint (cozy game, not a Clash Royale / BTD6 style size hierarchy). Houses, towers, huts and the friendly Airship all share it.

- 2026-10-16: NO REAL-WALL PORTALS (Siddharth). All enemies, flyers and the boss spawn from the forest on the map. Nothing depends on the player's room. The wall-portal idea came from the handoff's VR-fit analysis, not from him.

- 2026-10-16: PASSTHROUGH WITH THE BOARD ON THE REAL TABLE (Siddharth). If a table is detected the board sits on it; if not, it floats raised at a comfortable viewing angle. Enemies ignore the room. Detection must never be required for the game to run.

- 2026-10-17 (art bible draft 2, Siddharth's comments): ENEMY FLYERS ARE CREATURES, not airships (ref #42; #43 is for the friendly Airship only); the Sky Barge enemy airship is dropped, a second flyer would be a creature. Spec and asset list need a follow-up.
- 2026-10-17: Path material (dirt or stone bricks) is undecided; Siddharth picks after seeing buildings and assets.
- 2026-10-17: House plinth dropped. Tower cap and accent colours: whatever matches the building (aesthetics first).
- 2026-10-17: Benchmark trio is NOT the target look; Siddharth wants somewhat more detail and will decide the look once real asset building starts. Style not locked.
- 2026-10-17: Time of day mapping derived by Claude for now (provisional); final once a near-finished build exists. Enemy jewel colours (orange Grunt, purple caster, blue tank, green nature) fine for now, subject to change.
- 2026-10-17: Outline pass: try it, keep only if Siddharth likes it. An open-licensed (OFL) font is acceptable.
- 2026-10-17: SECOND FLYER CUT (Siddharth). The Wisp is the only flyer; no Sky Barge. GAME_SPEC and asset list updated.
- 2026-10-17: HAND VISUALS: stylised hands in our palette (Siddharth).
- 2026-10-17: TOWER AND HUT DESIGNS ARE NOT PREDEFINED (Siddharth). Each main tower and the Watch Hut is iterated individually with him, because that is where the player's attention is. The art bible gives general rules only.
- 2026-10-17: ART BIBLE v1: Siddharth approved all general rules (pillars, cell margin, shape language, rule of three, blob shadows, colour meaning, passthrough rule, troop colours, lighting approach, UI and VFX style). New v1 sections 6a and 7a-7f and the palette additions are Proposed. Step 3 (first real tower/hut) on hold until he says go.
- 2026-10-17: JEWEL CONCEPT CUT (Siddharth). Enemies have no jewel accents; this reverses the jewel part of the 2026-10-14 enemy-design entry. Types read by shape, size and movement. The Wisp keeps a soft glow of its own (wisp_glow).
- 2026-10-17: PLAYER HANDS: toy-glove hands with three tone options for diversity: white cream, brown cream, dark brown cream (Siddharth). Teal cuff.
- 2026-10-17: Siddharth approved the rest of art bible v1: palette additions and lighting presets, the Wisp, rarity frames, animation style, Foresight look.
- 2026-10-17: Art bible 7a approved: enemy types read by shape, size and movement. Every written rule in the art bible is now Decided; only the items that need real assets stay Open.
- 2026-10-17: DETAIL LEVEL: Fire Tower v01 is 'about right' (Siddharth). It is the real game asset (first iteration), not a benchmark. New assets match its detail level.
- 2026-10-17: Day and golden-hour lighting must move toward Siddharth's warm sunlit reference image (golden key light, teal-blue shadows, golden grass); retuned in palette.json, awaiting his verdict. The reference is for lighting mood only.
- 2026-10-17: FIRE TOWER v02 (Siddharth's sketch): the flames become a floating FLAME ORB that powers the tower; the attack animation is built around it (charge, then spit the fireball).
- 2026-10-17: ACTIVE TOWERS USE VFX AS MUCH AS POSSIBLE so they feel alive (idle, charge-up, attack effects), within Quest particle caps.
- 2026-10-17: FIRE TOWER v03: the flame orb is a VFX BALL, not a model (Siddharth). The model carries only an empty `__orb_anchor` where Godot spawns the orb effect; the bowl keeps glowing coals.
- 2026-10-17: AoE TOWER USES MAGIC BOMBS (Siddharth) instead of fire pulses. Role and stats unchanged. Bomb magic first coloured crystal_blue, rejected the same day (see next entry). Variants A-D (cauldron, rune mortar, wizard's workshop, crystal conjurer) in assets/previews/bomb_tower/variants_v01.png. The earlier fire variants (blast_brazier A-D) are superseded. Open: rename 'Blast Brazier' to fit bombs.
- 2026-10-17: MAGIC IS NOT BLUE (Siddharth): magic looks black, orange and red. Blue is for Foresight only. Hands glow warm when pinching.
- 2026-10-17: AoE TOWER DESIGN = E 'Tipping Cauldron' (Siddharth, from A-H): B's rune stone base and turntable carrying A's cauldron between wooden cheeks; the cauldron tips on its axle to lob each magic bomb. Built as ew_defense_bomb_tower_v01.
- 2026-10-17: BOMB TOWER v02 (Siddharth's mark-up): glowing bits become VFX, not geometry. The cauldron brew is a weird fire/lava-mix VFX; the red rune cubes are replaced by carved dark slots that a rune VFX lights up (exact rune effect open); the bombs keep their models and get fuse VFX. General rule: prefer VFX over glowing geometry on active towers.
- 2026-10-17: Bomb tower rune band VFX = EMBER SWIRL (sparks drift out of the slots and circle the base). VFX are built AFTER all towers and major assets are modelled; every VFX request is logged in docs/VFX_NOTES.md.

- 2026-10-17: GODOT IMPORT (Siddharth): every model shares ONE palette material plus ONE glow material in Godot (godot/assets/palette/). The glow material is unshaded (exact palette colour, full brightness) as a default; brightness/bloom to be tuned later on a headset. The old benchmark models moved to godot/assets/_old; the spike shows the Fire Tower v03 and bomb tower v02.
- 2026-10-17: PALETTE CHANGE RULES (Siddharth): new colours are appended only; an existing colour's hex may be tweaked only after a before/after of the built assets using it and his OK (affected assets are then re-exported); unwanted colours are RETIRED (kept in the atlas slot, listed under 'retired', validator warns). Proposals are shown as a highlighted swatch sheet plus a diorama with the proposed palette. Tool: tools/palette_change.py, skill palette-change.
- 2026-10-18: HEIGHT 3-4 CELLS IS A GUIDELINE, NOT A HARD RULE (Siddharth). The bomb tower (about 1.5 cells) and Fire Tower (2.6 cells without the orb VFX) stay as they are.
- 2026-10-18: First art-critic review of the real towers (both FAIL). Siddharth: fix the bugs only. Fire Tower v04 and bomb tower v03 fix contact/floating bugs; the critic's design suggestions wait for Siddharth (Fire Tower: coals, rim teeth, merlons, lighthouse read; bomb tower: glowing bomb bands, dark values at night, brew visible from behind).
- 2026-10-18: CRITIC SUGGESTIONS, SIDDHARTH'S PICKS (before/after: assets/previews/<tower>/before_after_suggestions.png). Fire Tower v05: YES rim prongs, chunkier merlons, one lit window (shuttered side window); NO coal lumps (flat glowing coal disc stays). Bomb tower v04: YES plain bombs (no glowing band or spark on the model; fuse VFX lights them); NO lighter turntable/rim (dark values stay); NO brew raised above the rim (brew VFX stays at the rim).
- 2026-10-18: FIRE TOWER v06 AND BOMB TOWER v05 APPROVED (Siddharth: "approve them after the critic"). Both passed the art critic; the construction bugs it found (masonry z-fighting on both, bomb fuses inside the top bomb) were fixed before approval. These are the first two finished towers.
- 2026-10-18: D04 IS A WIND CROSSBOW, NOT A LONGBOW (Siddharth). A big mounted crossbow (horizontal prod on a stock, plain wooden bolt on top) on a turning mount, powered by WIND MAGIC in PALE GREEN (his pick, knowing heal_green is close: keep the wind paler and airier than heal_green so the two still read apart). Wind is pure VFX on the bolt (no vanes or vents on the model). Name: decide later ("Longbow Tower" no longer fits). The longbow variants (assets/previews/longbow_tower/variants_v01.png) are superseded.

## Open (ask Siddharth)
- Time-of-day mapping for #18, #21, #22; bright-day and dawn palettes missing.
- Flat vs elevated island; flyer roster; ability pool size.

## Benchmark trio v01 (2026-10-14), awaiting Siddharth's feedback
- Built: house, archer tower, pine, round tree. Sheet: assets/previews/benchmark_trio_v01.png (three-quarter views), per-asset sheets in assets/previews/<name>/sheet.png.
- Added palette colour leaf_light (8DB85A) so foliage does not sink into a dim room (critic note). Bevel segments set to 1 (triangle budget).
- Open from critic: tower cap colour (teal vs terracotta, faction look); house plinth wider than walls (diorama-tile look) - keep?

- 2026-10-18, D04 wind crossbow: from variants_v01 Siddharth liked A (lookout perch), B (bolt deck) and D (crossbow keep); C dropped. Mixes E-H in variants_v02 (critic v01 fixes applied: bow 1.3x and chunkier, swivel touches the stock, squared shafts so it does not echo the octagonal Fire Tower).

- 2026-10-18, D04 wind crossbow: Siddharth picked variant G (low keep + railed timber deck + crate + crossbow turntable). Built as ew_defense_crossbow_tower_v01.
- 2026-10-18, D04 wind crossbow v02 (Siddharth): option (a) dark-wood bow (wood_dark prod, small roof_terracotta tip caps kept); dark crate (wood_dark) with a light band; wind VFX stays pale green but clearly whiter than heal_green, drawn as streaks rather than sparkles.
- 2026-10-18 (Siddharth): animation happens in Godot (tweens/AnimationPlayer on separate parts, no rigs). He asked to split every tower for animation/VFX: crossbow v03 gets __string, __bolt (carries the wind anchor), __prod under __swivel; Fire Tower v07 gets __window and __coals plus __pulse_anchor; bomb tower v06 gets __bomb_1..3 (fuse anchors ride on them) and __ladle. Geometry unchanged.
- 2026-10-18 (Siddharth): APPROVED ew_defense_crossbow_tower_v03 (D04), ew_defense_fire_tower_v07 (D01) and ew_defense_bomb_tower_v06 (D03). OK for the crossbow bolt tip to reach exactly the 2x2 edge when aimed straight along an axis.
- 2026-10-19, D05 Airship (Siddharth): main ship shaped like ref1 (netted round balloon over a curved boat hull, flag on top); tethered to the ground like ref2 (ground stake with a rope up to the hull). Refs in art/moodboard/refs_airship/ (shape ideas only).
- 2026-10-19, D05 Airship (Siddharth): it shoots a flaming cannonball (a mix of cannonball and fireball); a cannon TURRET on deck turns to aim (the ship itself stays moored, bobbing); colours to be chosen from the variants.
- 2026-10-19, D05 Airship (Siddharth): liked A, B and C from variants_v01; mixes E-H in variants_v02 (E = A + diamond net, F = B hull/cabin + A colours, G = C balloon + A hull + plank pad, H = B look on a rounder hull + stone pad).
- 2026-10-19, D05 Airship (Siddharth): likes G and H colours a lot and the landing pad; mixes I-L in variants_v03 (H shape in G colours; H on planks; G balloon in H colours on stone; colour blend). H hull widened per critic (W 0.056, rise 0.011).
- 2026-10-19, D05 Airship (Siddharth): liked G and K most; final = K ship (squat balloon with diamond net, wide round hull, stern cabin) in K colours (bone balloon, red band/trim/flag, dark hull) on G plank landing pad; suspension ropes hang from OUTSIDE the hull so the deck cannon turret turns a full 360 degrees.
- 2026-10-19, D05 Airship: built as ew_defense_airship_v01. Construction fixes from the art critic (not design changes): a dark load ring under the balloon band for the suspension ropes to hook onto (as in ref1), rope lugs follow the hull taper, turret base sunk into the sloped deck, degenerate barrel faces removed. Barrel elevation limits are open (clear at every heading from +15 to +30 deg).
