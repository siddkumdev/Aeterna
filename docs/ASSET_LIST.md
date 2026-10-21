# Endless Watch: asset list (tracker-aligned)

This merges two lists: Siddharth's tracker (`Endless Watch Assets.html`, 238 items, ids PF01 to S11) and the earlier `ASSET_LIST.md`, then applies every decision made since the tracker was written. Ids from the tracker are kept so the tracker's saved progress still lines up. No time estimates anywhere.

## Legend
Priority follows the tracker's own legend:
- **P0** = vertical slice, must exist.
- **P1** = should have.
- **P2** = cut candidate.

Change column (what happened to the tracker item):
- **KEEP** = unchanged.
- **EDIT** = same item, text or priority changed.
- **CHANGED** = the id now means something different because a decision replaced the old item.
- **REMOVED** = no longer in the game (kept in the list so nothing silently disappears).
- **NEW** = not in the tracker.
- Status tags: DONE (exists), BUILT (exists but needs rework), blank (not started).

## Decisions applied (why items changed)
1. **No wall portals.** Enemies come out of the forest ring (3 spawn points). Section M is rebuilt around table detection, the floating-board fallback and passthrough.
2. **Board on the real table** in passthrough; if no table is found it floats raised at a comfortable viewing height.
3. **Flat island, 12 x 12 cells.** No terraces or ramps. 1 cell = 5 cm, so the board is 0.6 m across.
4. **Everything grid-based; all buildings 2 x 2 cells.** Trees, props and characters fit 1 cell. Boss is 3 x 3.
5. **Palette atlas** is the colour method (answers PF03). No vertex colours, no procedural materials.
6. **Spells use cooldowns only. No mana, no spell meter.** The pool is 4 spells: Mend Vial, Fire Orb, Boulder Drop, Ward Rune.
7. **Tower roster is 4 + hut:** Fire Tower, Blast Brazier, Longbow Tower, friendly Airship (air only, max 2), plus the Watch Hut (Guard and Slinger troops). No per-tower tiers or upgrades.
8. **Flyers are countered by the Airship, the Fire Tower and the player's own hands** (answers D06). Verticality is flyers plus drop spells.
9. **#29 is a villager** (answers V09).
10. **Judges' first-run experience** is planned after the game is complete (U17).
11. Enemies attack the **6 houses**. A house that falls is shuttered (shown as damaged but standing, 2026-10-19). The night is lost at 3 or more shuttered.

---

## PF Pipeline and art foundation
| ID | Pri | Kind | Asset | Notes | Budget | Change |
|---|---|---|---|---|---|---|
| PF01 | P0 | doc | Art bible | Not written yet. Style rules, shape language, bevel (4 mm, 1 segment), do/don't list. Written from the benchmark trio, approved by Siddharth. | | KEEP |
| PF02 | P0 | data | Master palette (`palette.json`) | APPROVED: 19 colours, strips for night, dusk, golden hour. Still missing: bright-day and dawn palettes. Open: which strip is dawn vs golden hour (#18). Time-of-day mapping is undecided. | | EDIT, partly DONE |
| PF03 | P0 | shader | Shared material kit | RESOLVED: palette atlas, one shared `ew_palette` material. Still to build in Godot: toon shading, emissive window mask. | | EDIT, partly DONE |
| PF04 | P0 | tool | `blender_common.py` | DONE. | | DONE |
| PF05 | P0 | tool | `render_preview.py` + `make_sheet.py` | DONE (front, side, top, 3/4, wire, silhouette). | | DONE |
| PF06 | P0 | tool | `validate_asset.py` | DONE. Budgets by category from CLAUDE.md. | | DONE |
| PF07 | P0 | model | Benchmark trio | BUILT: house 428 tris, tower 1172, pine 224, round tree 300. Style sign-off by Siddharth is not recorded. Must be rescaled to grid footprints (PF13). | house/tower 1-2k, tree 200-500 | BUILT |
| PF08 | P0 | doc | `ASSETS.md` source and license log | Exists, 4 rows. Grows with every asset. | | DONE, ongoing |
| PF09 | P1 | tool | Godot import template | Scene template per asset: footprint collision, shadow flags, naming. Atlas needs nearest filtering and no mipmaps. | | KEEP |
| PF10 | P0 | shader | Fake contact shadow | Blob shadow instead of real-time shadows. Also under flyers so height reads (see E17). | | KEEP |
| PF11 | P1 | shader | Cheap rim-light toon shader | Single pass, no outline pass unless the budget allows. | | KEEP |
| PF12 | P0 | tool | Frame-time and counts overlay | Draw calls, triangles, objects, frame ms. Needed with no headset. | | KEEP |
| PF13 | P0 | tool | Rescale benchmark assets to the grid | House to 2 x 2 cells, trees to 1 x 1. Tower base reused for the Fire Tower. | | NEW |
| PF14 | P0 | tool | Hands-first placement spike | DONE: grid board, tower placer with green/red ghost, hand/controller input, 24 headless checks passing, hand pinch verified in the Meta XR Simulator. | | NEW, DONE |

## W World and environment
| ID | Pri | Kind | Asset | Notes | Budget | Change |
|---|---|---|---|---|---|---|
| W01 | P0 | model | Island base | 12 x 12 cells (0.6 m), flat grass top, bevelled rim, stone-strata sides. DONE: ew_world_island_v01 (variant L) approved by Siddharth 2026-10-20, 2564 tris (budget raised to 4000). Underside later (W02). | 4k | DONE |
| W02 | P1 | model | Island underside / floating skirt | Rocky underside, shown only in the floating-board fallback (no table found) and when the board is tilted or spun. | 500-1k | EDIT |
| W03 | P0 | shader | Placement grid overlay | CHANGED from "build plot pads". Placement is free on grid cells, so a grid shader that lights up only while placing replaces fixed pads. Valid/invalid states live in D12. | | CHANGED |
| W04 | P0 | model | Path tiles | Straight, corner, T-junction, end-at-village (the "portal mouth" end is gone). 1 x 1 each. BUILT 2026-10-21: ew_world_path_{straight,corner,t,end}_v02 (variant M = calmer round-3 look, 543-676 tris, APPROVED by Siddharth 2026-10-21) plus cosmetic village pieces ew_world_path_{cross,doorstep,plaza,stones}_v01 (264-1182 tris, APPROVED by Siddharth 2026-10-21). | 4 x ~100 | DONE |
| W05 | P0 | model | Trees: pine family | CHANGED 2026-10-21 (Siddharth): every tree is a variant of the pine, no round or cube trees. BUILT: pine_v02, pine_young, pine_layered (awaiting approval). | 200-500 each | EDIT |
| W06 | P1 | model | Trees: corrupted, tall pine | Birch dropped (all trees are pines). BUILT: pine_corrupted (twisted, dark; hints at the forest turning, supports Foggy Night) and pine_tall (awaiting approval). | 200-500 each | KEEP |
| W07 | P1 | model | Bushes (x2) | 1 x 1. | 100-300 | KEEP |
| W08 | P1 | model | Rocks (x3) | 1 x 1. | 100-300 | KEEP |
| W09 | P2 | model | Stump and log | 1 x 1. | 100-200 | KEEP |
| W10 | P2 | model | Fence set | Straight, corner, gate. Lowered from P1: not required by any mechanic. | 100-200 each | EDIT |
| W11 | P1 | model | Lantern post | Warm emissive glow at night. 1 x 1. | 200-400 | KEEP |
| W12 | P2 | model | Flowers (x3) and mushrooms (x2) | Mushrooms tie to the Splitter. | 50-200 | KEEP |
| W13 | P2 | model | Village props set | Well, haystack, barrels and crates, bench, flower pot, garden patch, hanging lantern. BUILT 2026-10-21 (batch 1, 23 props: barrel, barrel_stack, crate_stack, sacks, bench, table_stool, flower_pots, haystack, well, clothesline, market_stall, fences x3, signpost, notice_board, stone_wall, footbridge, bucket, clay_pots, pumpkins, basket, tools_leaning; 56-456 tris; v02 APPROVED by Siddharth 2026-10-21; v03 of fences, signpost, haystack, flower_pots, footbridge APPROVED by Siddharth 2026-10-21). Camp/woodwork group (campfire, log pile, stump, fireplace) on hold. | 200-500 each | EDIT |
| W14 | P2 | model | Signpost, bridge, pond or river tile | Cut candidate. Open: is river/pond wanted at all? | 300-800 | KEEP |
| W15 | P1 | model | Campfire | Village glow at night. 1 x 1. | 200-400 | KEEP |
| W16 | P2 | model | Village green / plaza tile | Lowered: the whole board is already grass. Cut candidate. | ~300 | EDIT |
| W17 | | model | Elevated terrain pieces | REMOVED: flat island decided. | | REMOVED |
| W18 | P0 | shader | Board lighting presets (4) | Dawn, day, dusk, night colour/intensity sets for the board only; passthrough shows the real room. Needs the missing bright-day and dawn palettes (PF02). | | EDIT |
| W19 | P2 | model | Sun, moon, stars | Only useful for the floating fallback and title. Cut candidate. | <200 | EDIT |
| W20 | P2 | model | Low-poly clouds (x3) | Airspace dressing around the flyers. | 100-300 | KEEP |
| W21 | P1 | vfx | Fireflies and ambient motes | Night, low overdraw. | | EDIT |
| W22 | P0 | model | Forest ring backdrop | Dense low-detail treeline at the island edge. This is where enemies come from. BUILT as 3 tree-line clumps (2 x 1 cells; mix, dark, low; 520-1176 tris), placed procedurally in Godot (awaiting approval). | ~1k | KEEP |
| W23 | P1 | vfx | Forest spawn marker | NEW: subtle glow or disturbed trees at each of the 3 spawn points (replaces the portals). 1 x 1. | <200 | NEW |
| W24 | P1 | model | Village bell post | NEW: pinch to end the day early. 1 x 1. | 200-400 | NEW |

## V Village and villagers
| ID | Pri | Kind | Asset | Notes | Budget | Change |
|---|---|---|---|---|---|---|
| V01 | P0 | model | House, terracotta roof: Dormer Cottage | 2 x 2. Cream walls, steep roof with a front dormer, door canopy, swing shutters (moodboard #4). Intact + broken (half collapsed) states via moving parts and _broken pose markers. DONE: ew_village_cottage_v05 APPROVED by Siddharth 2026-10-19 (1700 tris, half-collapsed broken state that reads broken from all sides) | 1-2k | CHANGED |
| V02 | P0 | model | House, teal roof: Log Cabin | 2 x 2. Log walls, big A-frame roof, porch on posts, roll-up shutters (moodboard #5). Intact + broken states. DONE: ew_village_cabin_v05 APPROVED by Siddharth 2026-10-19 (1964 tris, half-collapsed broken state that reads broken from all sides) | 1-2k | CHANGED |
| V03 | P1 | model | House, orange roof: Timber Townhouse | 2 x 2. Two storeys, half-timbered, jettied upper floor, teal flap shutters. Intact + broken states. DONE: ew_village_townhouse_v05 APPROVED by Siddharth 2026-10-19 (1796 tris, half-collapsed broken state that reads broken from all sides) | 1-2k | CHANGED |
| V04 | P2 | model | House D (cabin) | The spec has 6 houses in 3 roof colours, so a 4th design is a cut candidate. | 1-2k | EDIT |
| V05 | P2 | model | Village hall / heart | Cut candidate; conflicts with "all buildings uniform 2 x 2". Decide if a landmark is wanted. | ~2k | EDIT |
| V06 | P2 | model | Bakery | Cut candidate: the baker lives in a normal house (outfit and apron carry the identity). | 1-2k | EDIT |
| V07 | P2 | model | Market stall | Cut candidate (Market Day coin outcome could use it). | 500-1k | KEEP |
| V08 | P0 | model | Villager base body | Parts: head, torso, arms, legs, hands. Fits 1 cell. Tween-animated, no rig. | 1-2k | KEEP |
| V09 | P1 | model | Villager variants (x5) | Five villagers incl. the baker; swappable hair/hat/apron. RESOLVED: #29 is a villager and sets the proportions. | 1-2k each | EDIT |
| V10 | P0 | anim | Villager animation set | Idle, walk, wave, cheer, hide (run into house), point at request. Hide and idle first. | | EDIT |
| V11 | P2 | model | Animals (chicken, cat, dog) | | 300-600 | KEEP |
| V12 | P0 | model | Help request: blocked chimney | Rubble prop plus smoke puff. At least one request needed for the trust loop. | 300-600 | KEEP |
| V13 | P1 | model | Help request: stuck bird | Parts-based bird with perch, carryable. | 300-600 | KEEP |
| V14 | P1 | model | Help request: stuck cart | Renamed from "broken wheel" to match the spec. | 300-600 | EDIT |
| V15 | P1 | model | Help request: lost lantern | Carryable. Raised from P2: it is one of the 4 request kinds. The "sprout" idea is dropped. | 300-600 | EDIT |
| V16 | P0 | ui | Help-request marker | Floating "!" readable from a distance. | | KEEP |
| V17 | P0 | model | Trust token and collect animation | Heart or star flying into the meter. | <200 | KEEP |
| V18 | | ui | Dialogue bubble mesh | MERGED into U06. | | REMOVED |
| V19 | P2 | ui | Emote set | Heart, ?, !, zzz. | | KEEP |

## D Defense: towers, huts, troops
Roster changed: 4 towers plus the hut, no tiers.
| ID | Pri | Kind | Asset | Notes | Budget | Change |
|---|---|---|---|---|---|---|
| D01 | P0 | model | Fire Tower | 2 x 2. Base, rotating head, and an anchor for the flame-orb VFX ball that powers the tower (the orb is VFX, X26). Long range, single target, no AoE. DONE: ew_defense_fire_tower_v07 APPROVED by Siddharth 2026-10-18 (v06 look, parts split: head, coals, window) (rim prongs, chunky merlons, one lit window). | 1-2k | CHANGED, DONE |
| D02 | | model | Archer tower tiers 2 and 3 | REMOVED: no per-tower upgrades. | | REMOVED |
| D03 | P0 | model | Blast Brazier (magic-bomb tower; rename open) | 2 x 2. 'Tipping Cauldron': rune stone base, turntable head, cauldron that tips to lob magic bombs (black/orange/red). Short range, 1-cell AoE, low damage. DONE: ew_defense_bomb_tower_v06 APPROVED by Siddharth 2026-10-18 (v05 look, parts split: head, cauldron, ladle, bombs 1-3) (plain bombs; brew, rune and fuse glow are VFX). | 1-2k | CHANGED, DONE |
| D04 | P1 | model | Wind Crossbow Tower (was Longbow; name open) | 2 x 2. Low stone keep, railed timber deck, big crossbow on a turntable (__swivel). Pale-green wind VFX on the bolt. Lower damage, longer range, piercing. | 1-2k | DONE: ew_defense_crossbow_tower_v03 APPROVED by Siddharth 2026-10-18 (parts: swivel, string, bolt, prod) |
| D05 | P1 | model | Airship (friendly) | 2 x 2. Moored balloon ship (ref1 shape): bone balloon with diamond net and red band, wide round dark hull, stern cabin, deck cannon turret (360 deg) firing a flaming cannonball; tethered to a stone-capped stake on a plank landing pad (ref2). Air targets only. Max 2. | 1-2k | DONE: ew_defense_airship_v01 APPROVED by Siddharth 2026-10-19 (parts: ship, flag, turret, barrel, tether). Open: barrel elevation limits (clear at every heading from +15 to +30 deg) |
| D06 | | model | Anti-air option | RESOLVED: the Airship (D05) handles flyers; hands and Fire Tower help. | | REMOVED |
| D07 | P0 | model | Watch Hut (Guard spawner) | 2 x 2. Spawns Guards only (one spawning building per troop type, Siddharth 2026-10-19). Closed/spawning door states. Designed after the Guard character is final. | 1-2k | CHANGED |
| D08 | P0 | model | Troop: Guard | Melee, fits 1 cell. | 1-2k | EDIT |
| D09 | P1 | model | Troop: Slinger | Ranged, unlocked in loop 2. | 1-2k | EDIT |
| D10 | P0 | anim | Troop animation set | Idle, walk, attack, hit, die, spawn via part tweens. | | KEEP |
| D11 | P0 | model | Rally flag and rally ring | Planted by point and pinch. Flag <200 tris, ring is a ground marker. | <200 | EDIT |
| D12 | P0 | shader | Placement ghost and range ring | Translucent material, green valid, red invalid, per-type ghost silhouettes. Basic version exists in code. | | EDIT, BUILT |
| D13 | P0 | anim | Build pop animation | Scale bounce, scaffold and dust ring. | | KEEP |
| D14 | P2 | vfx | Sell / remove effect | Only if tower selling is accepted (open). Upgrade effect is gone. | | EDIT |
| D15 | P0 | model | Projectile: fireball | For the Fire Tower. Replaces the arrow. | <100 | CHANGED |
| D16 | P1 | model | Projectile: Longbow bolt | Piercing. | <100 | CHANGED |
| D17 | | vfx | Heal pulse orb | REMOVED as a tower effect; healing is the Mend Vial (see I05, X03). | | REMOVED |
| D18 | P1 | anim | Tower firing animations | Fire Tower recoil, Longbow draw and release, Brazier flame flare, Airship propeller and gun. | | EDIT |
| D19 | | model | Damaged / destroyed tower state | REMOVED: enemies attack houses, not towers. House damage is the shuttered state (V01). | | REMOVED |
| D20 | P1 | model | Airship projectile | NEW. | <100 | NEW |
| D21 | P1 | model | Slinger spawning building (name open) | 2 x 2. Spawns Slingers (one spawning building per troop type, Siddharth 2026-10-19). Cost and unlock open. Designed after the Slinger character is final. | 1-2k | NEW |

## E Enemies
Types and sizes: Grunt, Scout, Tunneler, Splitter, Wisp (the only flyer), Fog variant, boss "the Warden" (placeholder name). Faceted skeleton family (#24-27), no jewels, parts-based, tween-animated.
| ID | Pri | Kind | Asset | Notes | Budget | Change |
|---|---|---|---|---|---|---|
| E01 | P0 | model | Grunt | 1 cell. Faceted skeleton. | 1-2k | EDIT |
| E02 | P1 | model | Scout | 1 cell. Small, fast, hooded. | 1-2k | KEEP |
| E03 | P0 | model | Flyer A: Wisp | Small. Headline vertical feature; silhouette must differ from ground enemies and read against a room. Raised: flyers are in the spec. | 800-1.5k | EDIT |
| E04 | | model | Flyer B | REMOVED: flyers are creatures and the second flyer is cut (Siddharth, 2026-10-17). | | REMOVED |
| E05 | P1 | model | Tunneler and burrow mound | 1 cell. Pops up mid-village. | 1-2k | KEEP |
| E06 | P1 | model | Splitter and mini splits | Mushroom-shaped (#15). 1 cell plus 2 small spawn pieces. | 1-2k | KEEP |
| E07 | P1 | model | Fog variant | Loop 2. Ghostly Grunt; mostly a shader variant of E01. Hides from Foresight. | 1-2k | EDIT |
| E08 | P1 | model | Boss: the Warden | 3 x 3, height 5. Phases 1-3 (+ phase 4 in loop 2), enrage state, death. | 4-6k | EDIT |
| E09 | P1 | model | Warden crystal shield (x3) | Replaces generic phase attachments. Idle shimmer, hit, shatter. | +500 each | CHANGED |
| E10 | P1 | vfx | Boss attack telegraphs | Ground rings and beams. | | KEEP |
| E11 | P0 | model | Boss placeholder | Scaled Grunt so the loop is testable. | reuse | KEEP |
| E12 | P0 | anim | Enemy animation sets | Spawn (rise), move, attack, hit, death per type. Grunt and Wisp first. | | KEEP |
| E13 | P0 | shader | Hit-flash material | Shared by enemies and troops. | | KEEP |
| E14 | P2 | vfx | Burning status visual | CHANGED: no freeze or slow in the current spec; only burning from the Fire Orb remains. | | CHANGED |
| E15 | | shader | Per-enemy jewel accent colours | REMOVED: jewel concept cut (2026-10-17). | | REMOVED |
| E16 | P0 | vfx | Spawn and death effect | Dark smoke poof; spawn is rising from the forest. | | EDIT |
| E17 | P0 | shader | Flyer ground shadow | Blob shadow on the island (PF10). | | KEEP |
| E18 | P1 | vfx | Flyer path telegraph | Arc from the forest to the village, shown by Foresight tiers. | | EDIT |

## M Table, passthrough and room
Rebuilt. Old M01-M04 (wall rift portal, portal animation, forest-edge portal, boss portal) are REMOVED.
| ID | Pri | Kind | Asset | Notes | Budget | Change |
|---|---|---|---|---|---|---|
| M01 | P0 | tool | Table detection and board placement | CHANGED. Place the board on the detected table. Core Godot 4.7 spatial-entity settings may suffice; the OpenXR Vendors plugin might be needed (ask before downloading). UNVERIFIED in the simulator. | | CHANGED |
| M02 | P0 | tool | Floating-board fallback | CHANGED. If no table is found, the board floats raised at a comfortable viewing angle, with the underside (W02). | | CHANGED |
| M03 | | model | Forest-edge ground portal | REMOVED: replaced by the spawn marker W23. | | REMOVED |
| M04 | | model | Boss portal | REMOVED: the Warden comes out of the forest. | | REMOVED |
| M05 | P1 | ui | Direction warning indicator | Peripheral glow or arrow for flyers or threats outside the narrow field of view. | | KEEP |
| M06 | P1 | shader | Table detection feedback | CHANGED from wall detection: highlight the detected surface during setup. | | CHANGED |
| M07 | P1 | ui | Manual board placement fallback | CHANGED: point and pinch to place the board if detection is poor. Needed because there is no headset to test detection. | | CHANGED |
| M08 | P0 | shader | Passthrough blend and island edge feather | Raised: the whole concept is passthrough. Blend mode and feathered island edge. | | EDIT |
| M09 | P1 | ui | Room-scan prompt | "Look at your table" hint visuals. | | EDIT |
| M10 | P1 | vfx | Flyer entry arc | Guide from the forest to the village. | | EDIT |
| M11 | P1 | ui | Board adjust gesture | NEW: grab to move or turn the board, comfortable height for the fallback. | | NEW |

## I Hand objects and spells
Spells are cooldown-only and fit in a 4-spell pool.
| ID | Pri | Kind | Asset | Notes | Budget | Change |
|---|---|---|---|---|---|---|
| I01 | P1 | model | Fate Coin | Model, flick physics, 6 glyph faces (one per outcome). | <300 | EDIT |
| I02 | P1 | vfx | Coin result effect | Landing glow with glyph, by outcome. | | KEEP |
| I03 | P0 | model | Crystal Lens | Hand-held lens (handle plus crystal, glowing) for Foresight. | <500 | EDIT |
| I04 | P0 | shader | Foresight blur-to-sharp lens shader | Sharper each loop; cheap, no full-screen post effects. | | KEEP |
| I05 | P1 | model | Mend Vial | One bottle, liquid shader, tilt to pour. Cooldown 20 s. | <400 | CHANGED |
| I06 | P1 | model | Fire Orb | Thrown. Cooldown 8 s. | <200 | KEEP |
| I07 | P0 | model | Boulder Drop | Falls under toy gravity (0.25 g); release height decides timing and impact. Cooldown 15 s. The chosen vertical feature. | <300 | KEEP |
| I08 | | model | Drop spell: falling star or flask | REMOVED: the pool is 4 spells. | | REMOVED |
| I09 | | vfx | Freeze / time-stop orb | REMOVED: no such spell. | | REMOVED |
| I10 | P1 | vfx | Ward Rune | Fingertip rune trail and shield dome (VFX only, no model). Cooldown 25 s. Raised: it is one of the 4 spells. | | EDIT |
| I11 | | vfx | Heal orb | MERGED into I05 and X03. | | REMOVED |
| I12 | | vfx | Rune trace trail and glyphs | MERGED into I10. | | REMOVED |
| I13 | P0 | ui | Palm-up build menu wheel | Radial wheel frame (#37). A second tab shows the spell objects. | | EDIT |
| I14 | P0 | ui | Build cards (x5) | Fire Tower, Blast Brazier, Longbow Tower, Airship, Watch Hut, with cost. | | EDIT |
| I15 | P0 | ui | Card states | Hover, grab, drop, invalid. | | KEEP |
| I16 | P1 | model | Hand visuals | RESOLVED: stylised toy-glove hands in 3 tone options (white cream, brown cream, dark brown cream), teal cuff. | | EDIT |
| I17 | P1 | ui | Pinch, poke and grab cursors | Basic versions exist in code. | | KEEP |
| I18 | P1 | ui | Spell tab / shelf on the palm menu | CHANGED from "spell shelf/quiver showing the limited pool". Spells are unlimited with cooldowns, so this shows what is ready. | | CHANGED |
| I19 | P2 | vfx | Gesture feedback micro-effects | | | KEEP |
| I20 | P1 | ui | Wrist pause button | NEW. | | NEW |
| I21 | P2 | model | Belt dock for the lens | NEW, visual anchor. | | NEW |

## F Foresight visuals
Tiers: vague, types, paths, timing, rewrite. The tier list may still change with the spec.
| ID | Pri | Kind | Asset | Notes | Budget | Change |
|---|---|---|---|---|---|---|
| F01 | P0 | shader | Tier 1 silhouette shader | Vague direction and shapes. | | KEEP |
| F02 | P1 | ui | Tier 2 enemy-type icons (x6) | Grunt, Scout, Wisp, Tunneler, Splitter, Fog. | | EDIT |
| F03 | P1 | vfx | Tier 3 path ribbons | Animated flowing line, forest to village. | | KEEP |
| F04 | P1 | ui | Tier 4 timing markers | Wave timeline. | | KEEP |
| F05 | P2 | ui | Tier 5 rewrite interaction UI | Cut candidate. The old text said "close a portal"; portals are gone, so this needs a new definition from Siddharth. | | EDIT |
| F06 | P1 | vfx | Drop-spell landing marker | Predicted landing spot (#37, #38, #41). | | KEEP |
| F07 | P0 | shader | Foresight vision overlay | Lens look, cheap. | | KEEP |
| F08 | P0 | vfx | Tier-upgrade reveal at regression | Loop 2 must look visibly different. The demo-video shot. | | KEEP |
| F09 | P2 | ui | Hidden-enemy indicator | "?" for the Fog variant that Foresight cannot see. | | KEEP |

## U User interface
Front arc only, hands-only, comfortable in a narrow field of view.
| ID | Pri | Kind | Asset | Notes | Budget | Change |
|---|---|---|---|---|---|---|
| U01 | P0 | ui | Trust meter | | | KEEP |
| U02 | | ui | Spell meter | REMOVED: no mana. | | REMOVED |
| U03 | P0 | ui | Ability pick: 3 cards | A win shows 3 cards and the player keeps 1. | | EDIT |
| U04 | P1 | ui | Ability icons (14) | Proposed pool of 14: 11 tower/troop cards, 3 overall. | | KEEP |
| U05 | P1 | ui | Dawn summary panel | Houses saved, trust earned. | | EDIT |
| U06 | P1 | ui | Dialogue bubble frame | 9-slice, plus the bubble mesh and shader (merged from V18). | | EDIT |
| U07 | P0 | ui | Tutorial hints (x6) | Wordless looping gesture ghosts. | | KEEP |
| U08 | P0 | ui | Title screen | The diorama as the title. Hands-only start. | | KEEP |
| U09 | P0 | ui | Pause and quit | Hands-only; wrist button (I20). | | KEEP |
| U10 | P1 | ui | Day/night dial | Time-of-day mapping is undecided. | | KEEP |
| U11 | P1 | ui | Loop counter / hourglass | | | KEEP |
| U12 | P1 | ui | Icon set (~20) | Towers, spells, statuses, requests. | | KEEP |
| U13 | P0 | data | Font | One open-licensed font. Open: does "no external assets" cover an OFL font? | | KEEP |
| U14 | P2 | ui | Credits and legal panel | | | KEEP |
| U15 | P0 | ui | Floating panel base | Cream rounded card (#41). | | KEEP |
| U16 | P0 | doc | Field-of-view layout guide | Essentials inside about 96 x 90 degrees (Quest 3S). | | KEEP |
| U17 | P0 | doc | First-five-minutes flow | Judges open into a fast tutorial. Planned after the game is complete. | | EDIT |
| U18 | P0 | ui | Spell cooldown rings (x4) | NEW: replaces the spell meter. Mend, Fire Orb, Boulder, Ward. | | NEW |
| U19 | P1 | ui | Fate Coin result banner and 6 glyph icons | NEW. | | NEW |
| U22 | P1 | ui | Hand tone picker | NEW: choose one of the 3 hand tones on first start and in settings. | | NEW |
| U21 | P1 | ui | Card rarity frames (x3) | NEW: Common, Rare, Legendary frames for the ability cards. | | NEW |
| U20 | P1 | ui | Villager request and speech icons | NEW: chimney, bird, lantern, cart, heart, question, exclamation. Shares art with V16. | | NEW |

## X Visual effects
Low overdraw on Quest. Hard-edged toon shapes with glow (#31, #33, #36).
| ID | Pri | Kind | Asset | Notes | Budget | Change |
|---|---|---|---|---|---|---|
| X01 | P0 | vfx | Hit spark | | | KEEP |
| X02 | P0 | vfx | Projectile trails | Fireball, bolt, Airship shot. | | EDIT |
| X03 | P1 | vfx | Mend heal sparkles and pour stream | | | EDIT |
| X04 | P1 | vfx | Fire | Fire Orb flame and explosion, Brazier flame. | | EDIT |
| X05 | P1 | vfx | Ward shield dome | CHANGED from freeze/time-stop. | | CHANGED |
| X06 | P0 | vfx | Build pop and dust | | | KEEP |
| X07 | P1 | vfx | Forest spawn glow | CHANGED from portal glow. | | CHANGED |
| X08 | P1 | vfx | Trust sparkle | | | KEEP |
| X09 | P2 | vfx | Rain and fog | Only if the Gentle Rain / Foggy Night coin outcomes need world effects (open). | | KEEP |
| X10 | P1 | shader | Time-rewind: world swirl and desaturation | Signature moment. Do not move the camera, for comfort. | | KEEP |
| X11 | P1 | model | Time-rewind: hourglass or clock hero model | | <1k | KEEP |
| X12 | P1 | vfx | Time-rewind: particle swirl | | | KEEP |
| X13 | P0 | vfx | Drop-spell impact | Ring, dust, debris. | | KEEP |
| X14 | P1 | vfx | Boss phase transition | | | KEEP |
| X15 | P1 | vfx | Boss death | | | KEEP |
| X16 | P1 | vfx | Day/night transition | | | KEEP |
| X17 | P1 | vfx | Flyer death feather puff | | | KEEP |
| X18 | P2 | vfx | Unlock sparkle | | | KEEP |
| X19 | P1 | vfx | House damage and chimney smoke | CHANGED from tower damage smoke. | | CHANGED |
| X20 | P0 | data | Particle caps config | Maximum particles and overdraw limits. | | KEEP |
| X21 | P0 | vfx | Brazier pulse ring | NEW: shows the 1-cell AoE. | | NEW |
| X22 | P1 | vfx | Longbow pierce flash | NEW. | | NEW |
| X23 | P1 | vfx | Enemy-specific effects | NEW: Splitter pop, Tunneler dirt burst, Wisp trail, troop poof. | | NEW |
| X25 | P1 | vfx | Card rarity reveal | NEW: escalating glow per rarity; Legendary gets the biggest moment. | | NEW |
| X26 | P0 | vfx | Fire Tower flame orb (VFX ball) | NEW: the orb itself is VFX (shader ball + embers): idle bob and pulse, charge-up glow, fireball launch burst. | | NEW |
| X27 | P1 | vfx | Idle, charge-up and attack effects for the other active towers | NEW: Blast Brazier, Longbow Tower, Airship; towers feel alive mostly through VFX. | | NEW |
| X28 | P0 | vfx | Bomb tower brew | NEW: weird fire/lava-mix surface in the cauldron; bubbles and surges when it lobs a bomb. | | NEW |
| X29 | P1 | vfx | Bomb tower rune band | NEW: ember swirl: sparks drift out of the 8 carved slots and circle the base (chosen). | | NEW |
| X30 | P1 | vfx | Magic bomb fuse | NEW: spitting fuse sparks on displayed and thrown bombs, ember trail in flight, blast on impact. | | NEW |
| X24 | P1 | vfx | House break and repair | CHANGED (2026-10-19): dust puff as the house parts tumble into the broken pose; the dawn repair plays it backwards with a sparkle. At __dust_anchor. | | CHANGED |

## A Audio
Music from MIDI rendered with a free soundfont, SFX synthesised, no voice recording. Siddharth judges every track. Log each licence.
| ID | Pri | Kind | Asset | Notes | Change |
|---|---|---|---|---|---|
| A01 | P1 | audio | Music: title | Seamless loop. | KEEP |
| A02 | P0 | audio | Music: day | Cozy loop. | KEEP |
| A03 | P0 | audio | Music: night / raid | Tense but cozy loop. | KEEP |
| A04 | P1 | audio | Music: boss | | KEEP |
| A05 | P1 | audio | Music: rewind sting | | KEEP |
| A06 | P1 | audio | Music: dawn reward jingle | | KEEP |
| A07 | P2 | audio | Music: ability pick theme | | KEEP |
| A08 | P0 | audio | SFX: pinch, grab, release (x3) | | KEEP |
| A09 | P0 | audio | SFX: menu open and close | | KEEP |
| A10 | P0 | audio | SFX: tower place thunk | | KEEP |
| A11 | P0 | audio | SFX: invalid placement | | KEEP |
| A12 | P0 | audio | SFX: build pop | | KEEP |
| A13 | P1 | audio | SFX: coin flick and catch | | KEEP |
| A14 | P1 | audio | SFX: coin results (x3) | Six outcomes; sounds can be shared by good/bad. | EDIT |
| A15 | P0 | audio | SFX: fireball launch and impact | Was "arrow shot and hit". | CHANGED |
| A16 | P0 | audio | SFX: troop melee hit | | KEEP |
| A17 | P0 | audio | SFX: enemy death (x3) | | KEEP |
| A18 | P1 | audio | SFX: enemy spawn | Rustle from the forest. | EDIT |
| A19 | P0 | audio | SFX: flyer wings and screech | Loop and one-shot. | KEEP |
| A20 | P1 | audio | SFX: tunneler pop-up | | KEEP |
| A21 | P1 | audio | SFX: splitter split | | KEEP |
| A22 | P1 | audio | SFX: boss roar and phase | | KEEP |
| A23 | P1 | audio | SFX: house hit, shutter close | CHANGED from "tower damaged and destroyed". | CHANGED |
| A24 | P0 | audio | SFX: throw whoosh | | KEEP |
| A25 | P0 | audio | SFX: boulder fall whistle and impact | Pitch can hint at height. | KEEP |
| A26 | P1 | audio | SFX: fire | | KEEP |
| A27 | P1 | audio | SFX: heal chime | | KEEP |
| A28 | P1 | audio | SFX: ward rune hum and shield | CHANGED from "freeze". | CHANGED |
| A29 | P1 | audio | SFX: potion pour | | KEEP |
| A30 | P1 | audio | SFX: forest spawn rumble | CHANGED from "portal open hum"; spatial, at the spawn points. | CHANGED |
| A31 | | audio | SFX: portal close | REMOVED. | REMOVED |
| A32 | P1 | audio | SFX: villager blips (x5) | Gibberish. | EDIT |
| A33 | P0 | audio | SFX: trust gain chime | | KEEP |
| A34 | P1 | audio | SFX: help done jingle | | KEEP |
| A35 | P1 | audio | SFX: door close | Raised: pairs with the shuttered state. | EDIT |
| A36 | P0 | audio | SFX: Foresight sharpen whisper | | KEEP |
| A37 | P1 | audio | SFX: rewind whoosh | | KEEP |
| A38 | P1 | audio | SFX: dawn bell | | KEEP |
| A39 | P0 | audio | Ambience: day bed | | KEEP |
| A40 | P1 | audio | Ambience: night bed | | KEEP |
| A41 | P2 | audio | Ambience: rain and fog | | KEEP |
| A42 | P0 | tool | Spatial audio setup and loudness pass | 3D positioning for spawn points and flyers. | EDIT |
| A43 | P1 | audio | SFX per tower | NEW: bolt shot and pierce, brazier pulse, Airship engine and shot. | NEW |
| A44 | | audio | SFX: Sky Barge | REMOVED with E04. | REMOVED |
| A45 | P1 | audio | SFX: village bell | NEW: pairs with W24. | NEW |
| A46 | P1 | audio | SFX: UI hover, cancel, cooldown ready | NEW. | NEW |
| A47 | P1 | audio | SFX: rarity reveal stings (x3) | NEW: Common, Rare, Legendary. | NEW |

## T Text and story
English only, or English subtitles.
| ID | Pri | Kind | Asset | Notes | Change |
|---|---|---|---|---|---|
| T01 | P0 | text | Villager dialogue, loop 1 | Five villagers. | EDIT |
| T02 | P1 | text | Villager dialogue, loops 2 and 3 | They slowly remember the loop (the baker: "Haven't we met?"). | KEEP |
| T03 | P1 | text | Ability descriptions (14, with Common/Rare/Legendary values) | | KEEP |
| T04 | P0 | text | Tutorial hint text | Six hints, wordless where possible. | KEEP |
| T05 | P1 | text | Fate Coin outcomes (6) | For example Market Day, Foggy Night, Gentle Rain. | EDIT |
| T06 | P1 | text | Boss reveal and ending beat | Why the forest turned. Story may still change. | KEEP |
| T07 | P2 | text | Return hook line | A villager hints at tomorrow when the player quits. | KEEP |
| T08 | P2 | text | Title and credits text | | KEEP |
| T09 | P1 | text | Tower, hut and spell descriptions | NEW. | NEW |

## G Game data
Design decisions and core logic. Siddharth specifies, Claude writes the code, nothing is invented without a spec.
| ID | Pri | Kind | Asset | Notes | Change |
|---|---|---|---|---|---|
| G01 | P0 | data | Tower stats table | Four towers plus hut, no tiers. Proposed numbers are in `GAME_SPEC.md`. | EDIT |
| G02 | P0 | data | Enemy stats | Six types, Fog variant and the boss (was "five enemies"). | EDIT |
| G03 | P0 | data | Wave generator rules | Seeded procedural waves: threat budget per night, enemy costs, guard rails (GAME_SPEC 6a). Boss night hand-authored. | CHANGED |
| G04 | P0 | data | Ability pool and rarity table | Proposed 14 cards with Common/Rare/Legendary values and roll odds in GAME_SPEC section 15. Open: Siddharth's approval. | KEEP |
| G05 | P0 | data | Foresight tier definitions per loop | | KEEP |
| G06 | P1 | data | Fate Coin outcome effects | Six outcomes. | EDIT |
| G07 | P0 | data | Trust economy costs and rewards | Tower costs (Fire 60, Brazier 50, Longbow 55, Airship 70, Hut 70) are proposals. | EDIT |
| G08 | P0 | data | Spell stats | Cooldown and damage by release height, no cost. | EDIT |
| G09 | P0 | data | Flyer behaviour parameters | Speed, altitude, arrival. | KEEP |
| G10 | P0 | data | Loop 2 difficulty scaling | | KEEP |
| G11 | P1 | data | Save system | Loop number and unlocks. | KEEP |
| G12 | P1 | data | Adaptive quality tiers | Render scale and effect thresholds. Still needed: no headset. | KEEP |
| G13 | P0 | data | Board layout | NEW: path routes, 6 house positions, 3 forest spawn points, tree cells. | NEW |
| G14 | P1 | data | Time-of-day mapping | NEW: open decision (which palette strip is which part of the day). | NEW |
| G15 | P1 | data | Tower cap and selling rule | NEW: open decision (proposed cap 8 towers + 2 huts, max 2 Airships). | NEW |

## S Submission
Due 2026-11-18, 12:00 PM PT. No changes after the deadline.
| ID | Pri | Kind | Asset | Notes | Change |
|---|---|---|---|---|---|
| S01 | P0 | video | Demo video storyboard | Under 3 minutes. Show the time-loop twist, the board on a real table in passthrough, and a vertical moment (flyer or drop spell). | EDIT |
| S02 | P0 | video | Gameplay capture plan | No headset: simulator footage if allowed (check the rules); otherwise a teammate with a Quest. | EDIT |
| S03 | P1 | video | Video edit and captions | | KEEP |
| S04 | P1 | video | Screenshots (x5) | | KEEP |
| S05 | P1 | video | Key art and cover image | | KEEP |
| S06 | P1 | doc | App icon and metadata | Check the Meta dashboard requirements. | KEEP |
| S07 | P0 | text | Devpost description | Inspiration, how it was built, future plans, target launch date. | KEEP |
| S08 | P0 | tool | APK on the "Competition" release channel | Upload early to verify the process. Name must match exactly. Needs the OpenXR Vendors plugin and an Android export. | EDIT |
| S09 | P0 | doc | Ownership and licence proof | From `ASSETS.md`. | KEEP |
| S10 | P1 | doc | Content rating and policy checklist | | KEEP |
| S11 | P2 | doc | How-to-play card | | KEEP |

---

## Open questions that change this list
1. Selling towers and the tower cap (G15, D14).
2. Do the Foggy Night and Gentle Rain coin outcomes need world effects (X09)?
3. Hand visuals: stylised hands, or the platform hand mesh with a tint (I16)?
4. River and pond decoration (W14): wanted at all?
5. Village hall / landmark (V05) against "all buildings uniform 2 x 2".
6. Tier 5 "rewrite" now that portals are gone (F05).
7. Time-of-day mapping and the missing bright-day and dawn palettes (PF02, G14, W18).
8. OFL font vs "no external assets" (U13).
9. Table detection: does core Godot suffice, or is the OpenXR Vendors plugin needed (M01, S08)? Ask before downloading.
10. Is simulator footage accepted for the demo video (S02)?
