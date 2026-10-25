# M1 feature list (frozen 2026-10-25)

M1 = the full game, bare bones: every feature below works with stand-ins (primitive shapes, no final art, audio or VFX). Decided with Siddharth on 2026-10-25. The list is **frozen**: new ideas go to M2 or later unless Siddharth says otherwise. Numbers are stand-ins, retuned in M3 (balance).

Verify any time (Godot console exe from `local.env` as `GODOT_EXE`):
`"$GODOT_EXE" --headless --xr-mode off --path godot -s res://tests/game_selftest.gd` (189 checks passed at the last run).

## Built (works today, covered by `godot/tests/game_selftest.gd`)
| # | Feature | Notes |
|---|---|---|
| 1 | Board 24 x 24 cells, village of 6 houses, forest ring, 3 spawn edges | flat island, procedural forest |
| 2 | Run structure: 5 loops x (5 nights + boss night) | later loops: enemy HP x(1 + 0.4 x loop), +1 group per night |
| 3 | Day / dusk / night / dawn loop, hourglass rewind (resets trust, towers, damage; keeps cards) | the video-style rewind is M2 |
| 4 | Wave generator (seeded threat budget, 3 groups, guard rails) | |
| 5 | Enemies: Grunt, Scout, Splitter (+ Splitlings), Wisp (flyer), Tunneler (underground), Fog variant | |
| 6 | Pathfinding with towers and houses as obstacles; a build that would wall off every house is refused | |
| 7 | Towers: Fire, Blast Brazier, Longbow (piercing), Airship (air only); no cap; sell at day (full refund same day, half later) | |
| 8 | Economy: 200 start trust, dawn +5 per house, night-clear 10 x night number, request rewards 10-25 | |
| 9 | Dawn repair: damage carries over, +10 HP per house per dawn; a shuttered house reopens with HP | |
| 10 | Villager help requests: 4 per day (chimney, bird, lantern, cart), grab by hand, placeholder villagers | far too frequent: M3 |
| 11 | Foresight: Crystal Lens, 3 tiers over the 5 loops, tier-3 "close a path" rewrite | |
| 12 | Spells (night only): Fire Orb, Boulder Drop, Storm Cloud, Rage, Root Ward; ground and air | stand-in numbers |
| 13 | Ability cards: 11-card pool, 70/25/5 rarity, 3 offered after a boss win (keep 1), 1 Common after a loss | |
| 14 | Input: VR hands (grab/pinch), desktop mouse hand, signs + number keys, speed keys (x2; debug x5/x10/x50), easy reach in desktop and the simulator | |

## To build before M1 closes
| # | Feature | Notes |
|---|---|---|
| 15 | Simple 3-phase boss (the Warden) | Siddharth said yes 2026-10-25; details are being decided with him; loop 2+ 4th phase decided separately |
| 16 | A full 5-loop run played by a person on desktop and in the Meta XR Simulator | the VR grab code has only been tested headless with fake hands |

## Cut for M1 (not built, stays in the spec as history)
| Feature | Why |
|---|---|
| Troops, Watch Hut, Slinger building, rally flag, 3 troop cards | Siddharth 2026-10-25: "4 towers are enough for a cozy game" |
| Fate Coin | parked 2026-10-23, cut for M1 2026-10-25 |
| Hand swat on Wisps | skipped 2026-10-25 |
| Mend Vial spell | replaced by Storm Cloud and Rage |
| Tower cap | removed |

## Moved to M2 (juice and feel)
Hands-only menus (palm wheel), villager memory lines (Hades-style), the wordless tutorial, the video-style rewind, all VFX, real models, animation, audio, UI design, 72 fps on Quest.

## Moved to M3 (balance)
Trust and request frequency tuned together, loops 3-5 scaling, spell numbers, boss numbers, difficulty curve across both loops, comfort.
