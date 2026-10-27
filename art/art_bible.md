# Aeterna art bible

**Status: v1 (2026-10-17).** Siddharth approved all general rules on 2026-10-17. The bible is locked only after the first real assets are reviewed with him, because some calls need a near-finished build (section 12). Tags: **[Decided]** = Siddharth's decision or approval; **[Open]** = needs real assets to decide.

Source order when rules disagree: this file (once approved) > `art/decisions.md` > `.claude/skills/endless-watch-art-style` > moodboard.

---

## 1. The look in one paragraph
A cozy toy diorama on a real table: chunky, faceted low-poly pieces with soft bevelled edges, flat shading, a warm cream/terracotta/teal village against a deep green forest, lit by warm golden light with cool teal-navy shadows. Dark things that threaten it are faceted, angular and dark, never gory. It should read as something you want to pick up and set down, not as a war game.

## 2. Pillars
1. **Toy-like and handleable.** Everything is chunky enough to pinch. No thin spires. Siddharth wants **more detail than the v01 benchmark** (see 12.2), so detail goes into readable forms (shapes, trim, props on the model), within the triangle budgets, not into texture. **[Decided]** (detail level set by Fire Tower v01, 12.2)
2. **Reads at a glance, from above.** The player looks down at a 0.6 m board. Silhouette and colour carry meaning, texture does not. **[Decided]**
3. **Cozy first, threat second.** Village is warm and saturated; threats are cool and dark. **[Decided]** (cozy, not Clash Royale / BTD6)
4. **One colour source.** Every colour comes from the palette atlas. **[Decided]**
5. **Cheap on Quest.** Budgets and flat shading come before detail. **[Decided]**

## 3. Scale and grid **[Decided]**
- 1 cell = 5 cm = 0.05 m. Board = 24 x 24 cells = 1.2 m (was 12 x 12 = 0.6 m until 2026-10-22).
- Buildings (houses, towers, huts, friendly Airship) are all **2 x 2 cells** footprint. Height about 3 to 4 cells is a guideline, not a hard rule (Siddharth, 2026-10-18): a squat tower is fine when its role suits it.
- Trees, props, villagers, troops, most enemies fit **1 x 1 cell**. Boss 3 x 3 and 5 cells tall.
- Models are authored in metres (glTF), so N cells = N x 0.05 m. Origin at the base centre, +Y up, transforms applied.
- Keep a visible margin: a 1-cell model fills about 80 to 90 per cent of its cell so neighbours do not merge. **[Decided]**

## 4. Shape language
**Villagers' things (houses, props, friendly towers): round and stable.** **[Decided]**
- Wide bases, tapering upward, chunky proportions (the benchmark tower is the reference: octagonal, banded, wider at the bottom).
- Steep gable roofs, overhanging eaves, big simple chimneys, doors and windows as bold blocks.
- **No wider plinth under houses** (Decided: dropped). The v01 house plinth is removed when the house is redone.

**Threats (enemies): angular and tall-narrow.** **[Decided, per #24, #25, #27]**
- Faceted skeleton and creature shapes, sharper angles than the village. No jewel accents (cut, 2026-10-17).
- Proportions follow the villager chibi reference (#29) loosely: big head, small body, so enemies stay cute-spooky, not scary.
**Flyers are creatures, not machines.** **[Decided]** The enemy flyers follow the creature references on the moodboard (#42, the dark creature sheet), not an airship. Silhouette clearly different from ground enemies and readable from below and above. The Wisp stays small and bright. The old "Sky Barge" (a dark mirror of the friendly Airship) and any second flyer are **cut**. #43 (airships) is the reference for the **friendly** Airship tower only.

**Nature:** simple stacked or blob volumes (pine = 3 tiers, round tree = one crown plus a lighter accent), per #30 and #23. No leaf cards, no alpha textures. **[Decided]**

**Rule of three:** each asset has one big shape, one medium shape and one small accent. More than that adds triangles without adding read. **[Decided]**

## 5. Surface treatment
- **Flat shading, no smoothed normals.** Facets are the style. **[Decided]**
- **Bevel:** 4 mm (`bevel_width_m` 0.004), 1 segment, applied per part, width limited to a quarter of the thinnest side so thin parts do not collapse. Catches light on every edge. **[Decided]** (palette.json style block)
- **No textures other than the palette atlas.** No normal maps, no painted detail, no procedural materials. **[Decided]**
- **Shading:** toon look in Godot: stepped light, warm rim light, cool shadow, outline pass to be tried and kept only if Siddharth likes it and the frame budget allows (12.6, PF11). **[Decided; outline Open]**
- **Shadows:** fake blob contact shadows, no real-time shadows. Needed under flyers so height reads. **[Decided]** (PF10)
- **Emissive:** only for windows, lanterns, fire, magic and the Wisp's glow. Windows lit when a house is standing, dark when it is broken (0 HP).

## 6. Colour **[Decided: palette approved]**
Source of truth: `art/palette.json`, built into `art/palette_atlas.png` (8 x 8 grid, 64 swatch capacity, 19 used). Add a colour to `palette.json` first, then regenerate.

| Role | Colours |
|---|---|
| Village walls and wood | wall_cream F4E4B8, wood_light C6924C, wood_dark 5B2920 |
| Roofs (3 house variants) | roof_terracotta B04F31, roof_orange E09B4E, roof_teal 2F8F8A |
| Stone | stone 8C9096, stone_dark 5B4F50 |
| Ground and foliage | grass 7FA84A, leaf_green 5D8548, leaf_light 8DB85A, leaf_dark 224A2F, leaf_yellow DACF5C |
| Water | water 406988 |
| Bone and enemy base | bone EFE3C4, ink 111C30 |
| Foresight, Warden, glow | crystal_blue 3FB7D9 (Foresight only), crystal_purple 9C3EB0 (Warden), lantern_glow F6A45D |

Time-of-day strips: night_21, dusk_22 and golden_hour_18 come from the board; dawn_derived and day_derived are derived (6a). Mapping in 12.1.

Review sheet: `art/palette_preview.png` (regenerate with `python tools/make_palette_preview.py`). The v1 sheet is kept as `art/palette_preview_v1.png`.

### 6a. Palette additions, v1 **[Decided]**
All are appended to `materials` in `palette.json` (appending keeps every existing model's UVs valid). 37 of 64 atlas slots used.

| Group | Colours | Used for |
|---|---|---|
| Paths | path_dirt 9C7A50, path_stone C2B49A | both kept until Siddharth picks dirt or stone bricks |
| Enemies | wisp_glow FF5FA8, fog C9C6DA | the Wisp's glow (7b); the Fog variant |
| Player hands | hand_brown C8A07A, hand_dark_brown 7E5A3E (+ wall_cream) | the three hand tone options (7c) |
| Villagers | skin_light F2C9A0, skin_mid C98E62, skin_dark 8A5A3C, hair_dark 2B2220, hair_brown 6B4228, hair_blonde E2C26B | the 5 villagers and troops; a mix of skin tones |
| Effects | fire_red E8452C, fire_yellow FFD45A, heal_green 7FE08A | fireballs, Brazier, Fire Orb; Mend Vial |
| Placement ghost | ghost_valid 5FD068, ghost_invalid E5484D | translucent ghost and grid cells |
| Rarity | rarity_gold F2B630 | Legendary frame (7d) |
| Meadow flowers (2026-10-27) | flower_pink EE8FA8, flower_yellow F6D65C (white = wall_cream, orange = roof_orange) | tiny flowers in the lush grass; never blue (Foresight) or purple (Warden) |

**Lighting presets (board only)**, stored in `palette.json` under `lighting`: each has a key light colour, an ambient (shadow) colour, a rim colour and an energy.

| Preset | Key | Ambient | Rim | Energy | Mood |
|---|---|---|---|---|---|
| dawn | FFD9B0 | 7E86B8 | F8CDB4 | 0.70 | soft peach, cool shadows; the loop restarts |
| day | FFEBC8 | 9DBBD0 | FFE7A3 | 0.80 | clean warm light; building and requests |
| golden_hour | FFC56E | 5E6A55 | F6A45D | 0.85 | late day, warm and long |
| dusk | F0B396 | 56359D | DA8990 | 0.55 | pink key, purple shadow; the forest stirs |
| night | 8FB0D8 | 203C52 | 406988 | 0.35 | moonlight; windows and lanterns carry the scene |

The sheet shows a rough 2D approximation; the real test is a Godot render (step 3).

**Colour meaning (so the player learns it without text):** **[Decided]**
- Warm cream, terracotta, orange, teal = village, friendly, yours.
- Dark ink, stone_dark and bone = threat.
- Green leaf tones = nature, passable, neutral.
- Lantern glow orange = something alive or lit (windows, bell, request marker).
- **Magic is NOT blue** (Siddharth, 2026-10-17): magic (bombs, conjuring, runes, spell glows) has a black, orange and red vibe: ink bodies with fire_red / lantern_glow glows and fire_yellow sparks. Crystal blue = Foresight (the Crystal Lens) only. Crystal purple = the Warden.
- Placement ghost: green valid, red invalid (translucent).

**Passthrough rule:** the board sits in a real room, so keep the island's saturation and value away from typical room greys and whites, and keep a darker rim so the board edge always separates from the table. **[Decided]**

## 7. Characters
**Villagers (5):** chibi proportions from #29, faceted, warm clothing from the village palette, swappable hair/hat/apron parts. Fit 1 cell. No skinned rig: separate parts, animated with tweens in Godot (idle bounce, walk, wave, cheer, hide, point). **[Decided]**

**Troops (Guard, Slinger):** same body kit as the villagers but in teal/cream guard colours with a simple helmet. Reads as "ours". **[Decided]**

**Enemies:**
- Faceted skeleton or creature body in bone and ink tones. **No jewel accents** (Siddharth cut the jewel concept, 2026-10-17). **[Decided]**
- Enemy roster (types come from #10, #13, #14, #15, #36, #42 as ideas only, redrawn in our style): Grunt, Scout, Wisp (the only flyer), Tunneler, Splitter, Fog variant, and the boss "the Warden" (name is a placeholder).
- The Fog variant is a translucent, desaturated Grunt (shader variant).
- Boss: 3 x 3, 5 cells tall, three crystals as a shield (crystal_purple), phases shown by crystals and material changes.

### 7a. Telling enemy types apart **[Decided]**
No jewels and no per-type accent colour, so each type must read by **shape, size and movement**:
| Enemy | Read by |
|---|---|
| Grunt | the baseline: medium skeleton, steady walk |
| Scout | small and hooded, fast skittering run |
| Wisp | the only flyer: in the air, glowing, with a shadow below |
| Tunneler | hunched digger with big claws; travels as a moving dirt mound |
| Splitter | mushroom cap shape; splits into two small ones |
| Fog variant | a see-through, pale Grunt |
| Warden (boss) | 3 x 3 and 5 cells tall, with 3 purple shield crystals (a boss mechanic, not decoration) |
The Foresight icons (7f) use the same shapes.

### 7b. The Wisp **[Decided]**
- A creature, not a machine (per #42): a small round faceted body that glows softly in wisp_glow (its own glow, not a jewel), two simple wing or fin shapes that flap with tweens, a short tail.
- Bright core, dark body (ink), so it reads from below and above and against a real room.
- Small: about half a cell across, with a hit sphere 2x its visual size (spec section 10).
- A blob shadow on the board directly underneath, always, so the player can judge its height.

### 7c. Player hands **[Decided]**
- Stylised "toy glove" hands: chunky and faceted, with a roof_teal cuff at the wrist.
- **Three tone options for diversity** (Siddharth): white cream (wall_cream F4E4B8), brown cream (hand_brown C8A07A), dark brown cream (hand_dark_brown 7E5A3E). The player picks one in the settings (and on first start); the cuff stays teal for all.
- Driven by the tracked hand joints (a separate part per finger segment, no skinned rig).
- Feedback through the hands: fingertips glow lantern_glow while pinching (crystal_blue only while holding the Crystal Lens), and a short pulse on a successful grab or placement.
- Readable over passthrough, and never hiding what the hand holds (turn slightly translucent where it overlaps a held object, if needed).

### 7d. Ability card rarity frames **[Decided]**

| Rarity | Frame | Reveal |
|---|---|---|
| Common | wood_light frame on a wall_cream card | small sparkle |
| Rare | roof_teal frame with a wall_cream inner border | brighter sparkle and a soft teal glow |
| Legendary | rarity_gold frame with a lantern_glow edge light | big gold burst, light rays, its own sound sting |

Card art: the ability icon in the middle, the tower or troop it affects in a small badge. Legendary cards also show their bonus behaviour as a second icon.

### 7e. Animation style (tweens, no rigs) **[Decided]**
- **Bouncy, toy-like:** squash and stretch on landing, spawning and placing (build "pop": scale 0 to 1.15 to 1.0).
- **Short and snappy:** actions are quick; idle loops are slow and small (a gentle bob or breathing scale).
- **Overshoot, then settle:** ease-out-back for things appearing, ease-in for things disappearing.
- **Villagers** hop as they walk; **enemies** waddle or skitter; the **Wisp** bobs in the air; **towers** recoil when they fire.
- **Death:** a quick shrink with a dark smoke poof. No ragdoll, no gore.
- **Comfort:** nothing moves the player's view; big events (rewind, boss phase) happen on the board, not around the player.

### 7f. Foresight look **[Decided]**
- Seen only through the Crystal Lens, tinted crystal_blue.
- **Tier 1 (loop 1):** soft, blurry, glowing blue blobs at the forest edge showing where enemies will come from and roughly how many.
- **Tier 2 (loop 2):** the blobs sharpen into enemy-type icons (by shape, see 7a) with a count.
- **Later tiers:** flowing path ribbons from the spawn point to the village, then timing markers.
- Hidden enemies (Fog variant) show as a "?" so the player knows something is there.
- Cheap: a material on the icons inside the lens, no full-screen effect.

## 8. Buildings and towers
All 2 x 2 cells. **[Decided]**

**Tower and hut designs are NOT predefined. [Decided]** The towers (Fire Tower, Blast Brazier, Longbow Tower, Airship) and the Watch Hut are where the player's attention goes most, so Siddharth iterates on each one individually, one piece at a time, from first blockout to final. This bible does not fix their shapes or colours in advance.

What does apply to every tower and hut:
- the general rules in this file (grid size, bevel, flat shading, palette atlas, budgets);
- a base plus a separate rotating or moving part where the tower needs one (parts animated in Godot, no rigs);
- cap and accent colours are whatever matches that piece, because looks come first **[Decided]**;
- each preview sheet includes a silhouette view (the model filled solid black) as a check that it is still easy to tell apart from the others at a glance; it is a check, not a target shape.

Houses: same approach (redone from the v01 benchmark with Siddharth), with the decided points: 3 roof colours on 3 different shapes (cottage, log cabin, townhouse), intact and broken ("half collapsed") states, no plinth.

## 9. Environment
- **Island:** flat 12 x 12 grass top, bevelled rim, stone-strata sides, rounded corners. Underside appears only in the floating fallback. **[Decided flat; Proposed details]**
- **Paths:** tiles (straight, corner, T, end at village) that are either **dirt or stone bricks**, clearly different from grass. **Undecided:** Siddharth will pick once the buildings and other assets exist, so the path material is chosen last and must be a cheap swap (a different atlas swatch, not a different model).
- **Forest ring:** dense low-detail treeline around the island edge, fogged. It is the spawn area, so the dark leaf_dark tones concentrate here.
- **Props:** rocks, bushes, fences, lantern posts, bell post, campfire. 1 x 1, below the tree detail level.
- **Lighting presets (board only):** dawn, day, dusk, night as colour and intensity sets. Warm key from one side, cool fill. No dynamic sky; passthrough supplies the background. **[Decided]**

## 10. UI and VFX
**UI (hands only, front arc, #37, #38, #41 for style only):** rounded cream panels (#41), warm wood frames, big round icons, no small text. Essentials stay inside about 96 x 90 degrees. One open-licensed (OFL) font, licence logged (12.7). Cards for build and ability choices; cooldown rings for spells. **[Decided]**

**VFX (#31, #33, #44, #46, #47):** hard-edged flat shapes with glow, few layers, low overdraw. Rings and shockwaves must read from above. **Active towers lean on VFX to feel alive (Siddharth, 2026-10-17):** each attacking tower has an idle effect (embers, glow pulse, flicker), a visible charge-up before it attacks, and an attack effect, so its animation is mostly carried by VFX on a few moving parts. Example: the Fire Tower's floating flame orb bobs and pulses, glows brighter as it charges, then spits the fireball. Stays within the particle caps (X20). **Glowing parts are VFX, not geometry** (Siddharth, bomb tower mark-up): brews, runes, fuses and orbs are effects on empty anchors; the model only provides the dark sockets or openings they sit in. Colour code: gold, orange and red over black for friendly damage and magic, crystal blue for Foresight only, purple for the Warden, green for healing. **[Decided]**

## 11. Budgets and technical rules **[Decided, from CLAUDE.md; tune on a real Quest]**
- Triangles: props 800, houses and towers 2000, enemies and villagers 2000, boss 6000. (Benchmark: house 428, tower 1172, pine 224, round tree 300.)
- Names `ew_<category>_<name>_v<NN>`; one `.glb` per asset in `assets/export/<category>/`; one generator `assets/generators/make_<name>.py`.
- At most 2 materials per asset, one shared `ew_palette`. No leftover modifiers, no skinned rigs.
- Validate with `tools/validate_asset.py` and review with `tools/make_sheet.py` before showing Siddharth.

## 12. Answers and what is still open
1. **Time of day: derived by Claude for now, final call once there is a near-finished build.** Provisional mapping (**Proposed, changeable**): `night_21` = night, `dusk_22` purple half = dusk, `golden_hour_18` = day/late afternoon. **Dawn** is derived from the peach-pink half of the `dusk_22` strip (FBE2A0, F0B396, DA8990) lifted lighter, and **bright day** is derived from the village colours with a lighter, cooler sky tint. Both new palettes still have to be built (PF02).
2. **Detail level: decided.** The benchmark trio was a pipeline test. Siddharth judged the Fire Tower v01 detail level (masonry blocks, timber framing, corbels, door frame and step, sills, small story props like a firewood stack) as about right (2026-10-17). New assets match that level.
3. **House plinth: dropped.**
4. **Tower cap colour: whatever matches the tower or building.** Aesthetics are the top priority, so colour is chosen per piece, not by a fixed rule.
5. **Enemy jewels: cut** (Siddharth, 2026-10-17). Enemy types are told apart by shape, size and movement (7a).
6. **Outline: try it.** Build the toon rim light first and test an outline pass; keep it only if Siddharth likes it and the frame budget allows.
7. **Font: yes, an open-licensed (OFL) font is acceptable.** Log its licence in `assets/ASSETS.md`.
8. **Hand visuals: stylised hands in our palette.** **[Decided]** Cozy look beats the platform mesh; needs a hand model driven by the tracked joints (I16).
9. **Second flyer: cut.** **[Decided]** The Wisp is the only flyer. Spec and asset list updated.

## 13. Next steps
1. Step 3 (on hold until Siddharth says go): build the first real tower or hut with him and render it under each lighting preset, to settle the Open items in 12.
2. Lock this file after that review.
