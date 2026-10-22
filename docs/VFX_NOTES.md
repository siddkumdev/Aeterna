# VFX notes (running log)

Every visual effect Siddharth has asked for or approved, in one place. **When:** VFX are built in Godot only after all towers and major assets are modelled (Siddharth, 2026-10-17). Until then this file collects the requirements; add to it every time he mentions an effect.

Rules that apply to all VFX:
- Active towers lean on VFX to feel alive: an idle effect, a visible charge-up before attacking, and an attack effect (Siddharth, 2026-10-17).
- Glowing parts are VFX, not geometry. Models only provide the dark sockets and openings, plus empty `__<name>_anchor` objects where Godot attaches the effect. In Godot these arrive as `Marker3D` nodes in the group `ew_vfx_anchor`, with the effect size in metres as metadata `ew_size` (godot-import skill).
- Magic is black, orange and red, never blue. Blue is for Foresight only; purple is the Warden's. Exception: the wind crossbow's wind magic is pale green (Siddharth, 2026-10-18).
- Quest budget: low overdraw, particle caps (asset list X20). Hard-edged toon shapes with glow (moodboard #31, #33, #44, #46, #47). Rings and shockwaves must read from above.
- Nothing moves the player's view.

## Fire Tower (`ew_defense_fire_tower_v07`; parts __head, __coals, __window for per-tower glow pulse/flicker; `__pulse_anchor` at ground centre)
| Effect | What Siddharth asked for | Anchor | Asset list |
|---|---|---|---|
| Flame orb | (Critic idea 2026-10-18, for when VFX are built: hover the orb lower, half sunk into the bowl, to tie it to the coals and weaken the lighthouse-lamp read. Siddharth to decide.) The orb that powers the tower is a VFX ball, not a model. It floats above the bowl, bobs and pulses, glows brighter as it charges, then spits the fireball; the attack animation is built around it. | `__orb_anchor` (child of `__head`) | X26 |
| Fireball | Projectile and impact. | from `__orb_anchor` | X02, X01 |

## Bomb tower, "Tipping Cauldron" (`ew_defense_bomb_tower_v06`, spec name Blast Brazier, rename open)
| Effect | What Siddharth asked for | Anchor | Asset list |
|---|---|---|---|
| Brew | "A weird fire/lava mixture" filling the cauldron mouth; surges when the cauldron tips to lob a bomb. Stays at the rim; raising it above the rim was rejected (2026-10-18). | `__brew_anchor` (child of `__cauldron`) | X28 |
| Rune band | **Ember swirl** (chosen 2026-10-17): sparks drift out of the 8 carved slots and circle the base. | `__rune_anchor_1..8` | X29 |
| Bombs | The bomb models stay, but they need VFX: fuse sparks on the displayed bombs (since v04 the bomb models have no glow of their own, so the fuse VFX is their only light), and on thrown bombs an ember trail and an impact blast. | `__fuse_anchor_1..3` (each a child of its `__bomb_N` part), `__bomb_anchor` | X30 |
| AoE blast | Blast ring covering the 1-cell radius where the bomb lands; reads from above. | landing point; `__pulse_anchor` for the range ring | X13-style |

## Airship (D05, `ew_defense_airship_v01`, approved)
| Effect | What Siddharth asked for | Anchor | Asset list |
|---|---|---|---|
| Flaming cannonball | "A mix between a cannonball and a fireball" (2026-10-19): a dark cannonball wrapped in fire (orange/red), trail in flight, burst on hitting a flyer. | `__muzzle_anchor` (child of `__barrel`) | D20, X02, X27 |
| Cannon smoke + muzzle flash | Puff of smoke and a flash at the muzzle on each shot (2026-10-19). | `__muzzle_anchor` | X27 |
| Burner flame | Small flame at the balloon's mouth; flares as the cannon charges a shot (2026-10-19). | `__burner_anchor` | X27 |
| Balloon bob, flag flutter | Idle animation (tweens on parts, not VFX), picked 2026-10-19. | parts `__ship`, `__flag` | D18 |
| Tether follows the bob | Not VFX: when `__ship` bobs, re-aim `__tether` (pivot at the stake top) at `__tether_anchor`; the rope has a fixed length, so keep the bob under ~4 mm or stretch it along its own direction (art critic, 2026-10-19). | `__tether_anchor` | D18 |

## Other towers
- Watch Hut: not designed yet. Same idle / charge-up / attack rule (asset list X27).

## Wind crossbow tower (D04, `ew_defense_crossbow_tower_v03`; name open)
| Effect | What Siddharth asked for | Anchor | Asset list |
|---|---|---|---|
| Wind magic | The crossbow is powered by wind magic in PALE GREEN (2026-10-18), kept clearly WHITER than heal_green and drawn as STREAKS, not sparkles, so it never reads as healing (Siddharth, 2026-10-18). Pure VFX on the bolt: wind swirls around the loaded bolt (idle/charge), the shot leaves a gust trail, the pierce flash on hits. No wind parts on the model. | `__bolt_anchor` (child of `__bolt`, so it moves with the bolt) | X22, X27 |

## World and other effects already on the asset list
See section X of `docs/ASSET_LIST.md` (hit sparks, build pop, trust sparkle, time rewind, boss effects, rarity reveal, shutter close and more). Those come from the spec, not from Siddharth's VFX comments; move an item here when he adds direction to it.

## Village houses (V01-V03: ew_village_cottage_v05, ew_village_cabin_v05, ew_village_townhouse_v05; v05 approved by Siddharth 2026-10-19)
| Effect | What Siddharth asked for | Anchor | Asset list |
|---|---|---|---|
| Chimney smoke | Chimney socket for smoke (2026-10-19); smoke stops when the house is broken. Also the blocked-chimney help request (rubble pulled out of the socket). | `__smoke_anchor`, `__rubble_anchor` (children of `__chimney`) | X19, V12 |
| Lit windows | Lit when standing, dark when broken (2026-10-19). Not VFX: the `__windows` glow part is switched off (extra `ew_broken = off`), dark glass sits behind it. | part `__windows` | V01-V03 |
| Break: dust puff | "a animation to transition" into the broken state (2026-10-19): HALF COLLAPSED (v02): the roof side and the knocked-out wall corner drop and shrink into the dust (they become the rubble), the chimney top tumbles into the breach, the door swings to hang off its top hinge, rubble heaps and snapped rafters grow from 0. v03: the chimney cap breaks off on its own (__chimney_cap carries __smoke_anchor and __rubble_anchor) and a missing/slipped tile appears on the standing slope (__roof_hole). v04: the standing slope gets a real hole (its filling piece falls with __roof_fall) so the house reads broken from all sides. Parts tween to their `<part>_broken` markers. Later: rising dust/smoke so a broken house reads from straight above (Siddharth, 2026-10-19). | `__dust_anchor` | X24 |
| Repair at dawn | Same animation played backwards, like a rewind (2026-10-19), with a small sparkle. | `__dust_anchor` | X24 |
| Lost lantern returned | The lantern hangs from the hook by the door (help request). | `__lantern_anchor` | V15 |
| Rally ring | The rally point's ring is a Godot shader/particle ring, NOT a model (Siddharth 2026-10-21: "Flag plus glow ring (VFX)"); it can pulse and show where troops hold. Warm colours (orange/cream), not blue. | flag `__ring_anchor` (size 0.06 m) | D11 |
| Flag sway | The cloth is its own part (`__cloth`, pivot at the pole) so Godot can sway it with a tween. Not VFX, an animation. | part `__cloth` | D11 |
| Fireball flames and trail | Fireball = dark core model wrapped in fire (orange/red), trail in flight, impact burst (Siddharth 2026-10-21: dark core with VFX sockets). | `__fire_anchor` on the fireball core | D15, X02 |
| Wind bolt streaks | Pale-green wind streaks around the crossbow bolt, kept whiter than heal_green (2026-10-18 rule); pierce flash on hit. | `__wind_anchor` on the bolt | D16, X22 |
| Cannonball fire | Airship cannonball: dark iron ball wrapped in fire (orange/red), trail, burst on a flyer (2026-10-19 notes, 2026-10-21 dark-core decision). | `__fire_anchor` on the cannonball | D20, X02 |

## Crystal Lens (I03, variant B picked 2026-10-21; glass is the separate part `__glass`, one whole glass, cracks drawn by the shader)
| Effect | What Siddharth asked for | Anchor | Asset list |
|---|---|---|---|
| Purple binding magic | "The cracked mirror pieces should be held together with some purple magic VFX" (Siddharth 2026-10-21). Purple threads/glow along the cracks between the shards. NOTE: purple is otherwise the Warden's colour and he chose "no Warden link in the model"; this is his explicit exception for the lens VFX (flagged to him 2026-10-21). | along the cracks of `__glass`; centre `__lens_anchor` | I03, I04 |
| Cracks heal as Foresight grows | "As the foresight skill evolves the cracks reduce" (Siddharth 2026-10-21): fewer/narrower cracks at each Foresight tier, so the lens looks more whole as Foresight sharpens. Godot work. DECIDED 2026-10-21: shader only; the model has one whole glass and the Foresight lens shader (I04) draws the cracks and fades them per tier. | `__glass` | I03, I04 |

## Rewind hourglass (X11, `ew_vfx_rewind_hourglass_v01`; parts __glass, __sand_top, __sand_bottom)
| Effect | What Siddharth asked for | Anchor | Asset list |
|---|---|---|---|
| Rewind sequence | Rises over the board only for the rewind, flips, the sand runs upward, then it fades (Siddharth 2026-10-22). Crystal-blue sand (same crystal as Foresight). Glass needs a transparent material. | root flips; __sand_top / __sand_bottom scale; `__stream_anchor` (upward sand stream at the neck); `__glow_anchor` (centre glow). Note: __sand_bottom pivots on the glass floor (Z0 + 3 mm), so scaling it grows the pile from the floor. | X10, X11, X12 |
| Board rewinds like a video | While the hourglass plays, the board itself rewinds like a video played backwards: the loop's events run in reverse (enemies walk back into the forest, shuttered houses rebuild, towers sink back into the ground) before the new loop starts (Siddharth 2026-10-22: "rewind the time like how one rewinds a video"). Implementation idea (Claude, not decided): record positions/states each night and play them back fast in reverse, with a rewind tint/scanline shader. | whole board; hourglass root | X10, X11 |
