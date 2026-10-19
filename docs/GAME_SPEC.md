# Endless Watch: game spec (PROPOSED draft by Claude, Siddharth edits)

Status: every item below is PROPOSED, not decided. Numbers are starting values to tune in play, not facts. Item numbers match `docs/DESIGN_SPECS_TODO.md`. Edit anything; whatever you change becomes DECIDED and I build from it.

Revision 2 (Siddharth's feedback applied): no moving towers, no mana (cooldowns only), new 4-tower roster, flat island confirmed, ability choice confirmed.

**Everything is grid-based (Siddharth's rule).** The unit of measure is the CELL. 1 cell = 5 cm in the real world; the board is 12 x 12 cells. All gameplay distances, ranges, radii, speeds, heights and model footprints below are in cells (or cells per second). Real-world units (cm, m/s) appear only where they describe the player's body or hand input, and are marked "real".

### Grid and footprints (Siddharth: all buildings are one uniform size)
| Thing | Footprint (cells) | Height (cells) |
|---|---|---|
| Every building: house, Fire Tower, Blast Brazier, Longbow Tower, Watch Hut | 2 x 2 | 3-4 (same footprint; silhouettes differ by shape and colour, not size) |
| Airship (friendly tower) | 2 x 2 (moored over its footprint) | floats 2 above board, about 3 tall |
| Tree | 1 x 1 | 2-3 |
| Villager, troop, ground enemy | fits in 1 cell | 1 |
| Boss (not a building) | 3 x 3 | 5 |
Space check: 6 houses + 8 towers + 2 huts = 16 buildings x 4 cells = 64 of 144 cells, leaving 80 for paths, forest edge and open space. The tower cap (8 + 2 huts) can be lowered if the board feels crowded.
Existing benchmark assets (house about 3 x 2.6 cells, tower about 2.6 cells wide) will be rescaled to the 2 x 2 footprint when asset building starts.

---

## A. Core rules

### 1. Board
- **Size:** 12 x 12 cells island, centred in front of the player.
- **Placement (Siddharth's decision):** passthrough on, and the board sits on the player's real table when one is found, at the table's surface height. The room is otherwise ignored by gameplay.
- **No table found (fallback):** the board floats at a comfortable seated height and viewing angle instead: centre 9-11 cells (real 45-55 cm) from the eyes and 3-5 cells below eye level, flat or tilted slightly toward the player (tilt angle tunable). Same rules, same grid.
- **Both cases must work in every room:** the fallback is the safe default, so the game never depends on detection succeeding.
- **Terrain:** FLAT for the competition build (cheapest, most comfortable). Elevation is a later option.
- **Grid:** 12 x 12 cells; towers, huts and houses snap to whole cells (large ghost preview). Villagers, troops and enemies move continuously but their speeds, ranges and positions are measured in cells.
- **Layout:** village in the centre ring (6 houses), forest ring around the edge, river optional (decoration).
- **Paths:** 3 ground paths from 3 forest spawn points, all in the front 180 degrees so the player never turns to see ground enemies, converging on the village.
- **Spawning:** everything comes from the forest on the map. Ground enemies and the boss emerge at the 3 forest spawn points (optionally with a small glowing rift at the tree line, purely visual). Flyers rise out of the tree line above a spawn point. NO real-wall portals: nothing depends on the player's room. (Siddharth's decision; the earlier wall-portal idea came from the handoff's VR-fit analysis and is dropped.)

### 2. What enemies attack
- **Goal:** the 6 village houses. Ground enemies walk their path toward the nearest house.
- **En route:** they attack any tower, hut or troop that blocks them or is in melee range; ranged enemies target the nearest of those.
- **House state:** a house at 0 HP becomes "shuttered" (not destroyed; visibly closed up) and is repaired free in the next day. Cozy, no permanent loss.
- **Losing a night:** 3 or more of 6 houses shuttered.

### 3. Night rules
- A night is a fixed number of enemy groups (see 6). It ends when all groups are spawned and every enemy is defeated, or the night is lost.
- **Win:** all enemies defeated with 4+ houses standing. Reward at dawn.
- **Doing nothing:** enemies shutter 3 houses, the night is lost, and the time loop triggers with a reduced reward.
- **Passive combat:** towers and troops fight on their own; the player's inputs are placement, rally point, spells and swatting flyers.

### 4. Tower placement
- Placed on grid cells, one tower per cell, large preview ghost, snap on release. Throw the ghost off the island to cancel before placing.
- **Once placed, a tower stays.** No moving. (Selling/refunding is not in this draft; see open questions.)
- **Cap:** 8 towers + 2 huts on the board; at most 2 Airships. The cap is a pacing lever, tunable.
- **Upgrades:** none per tower in the competition build; progression comes from loop unlocks (see 15).

### 5. Economy (trust)
- Start: 100 trust per loop (loop 1 night 1).
- **Day income:** helping villagers (see 18), about 4-6 requests per day at 10-25 trust each.
- **Dawn income:** +5 trust per standing house.
- **Costs:** Fire Tower 60, Blast Brazier 50, Longbow Tower 55, Airship 70, Watch Hut 70.
- **Spells cost no resource**; they are limited only by cooldowns (see 11). Trust is the only currency.
- Fate Coin can modify income (see 17).

### 6. Loop structure (competition build)
- **Loop 1:** 5 nights, then a boss night (night 6). Night count is fixed; what spawns each night is generated (see 6a).
- **Day:** about 4-5 requests to complete; the player can end the day early by ringing the village bell (pinch the bell).
- **Between phases:** short dusk (the forest stirs, villagers hide) and dawn (summary) beats, no input needed.
- Loop 2 repeats the structure with the changes in 16 (vertical slice may stop after loop 2).

### 6a. Wave generation (Siddharth: "somewhat procedurally generated"; rules below are PROPOSED)
What is fixed: the number of loops (2, loop 3 only if built), 5 nights + 1 boss night per loop, and when each enemy type first appears. What is generated: which enemies come each night, how many, from which of the 3 spawn points, and when.
- **Seed:** each run gets a random seed; the generator is deterministic from it, so a run can be replayed and bugs reproduced.
- **Threat budget per night:** each enemy costs threat points (proposal: Grunt 1, Scout 1, Wisp 2, Splitter 3, Tunneler 3, Fog variant 3). Night n of loop 1 gets a budget that grows each night (proposal: 6, 9, 12, 16, 20). Loop 2 budgets are 40% higher (whether this replaces or adds to the "+40% enemy HP" idea in 16 is deferred; Siddharth will decide later).
- **Spending the budget:** the generator buys enemies only from the types unlocked so far, splits them into 3 groups, gives each group a spawn point and a start time inside the night. Group sizes grow through the night.
- **Guard rails (so it stays fair and cozy):**
  - a new enemy type always appears first in a small group, alone, so the player can learn it;
  - no more than about half a night's budget from one spawn point;
  - no two "hard" types (Tunneler, Splitter, Fog) in the same group in loop 1;
  - flyers never more than 1/3 of the budget;
  - the boss night is hand-authored, not generated (phases stay as in 9).
- **Fits Foresight:** because waves differ each run, the Crystal Lens is how the player learns what is coming, which gives Foresight a real job.
- **Deferred (Siddharth will decide later):** in loop 2, should the waves be the SAME as loop 1 (same seed, the player "remembers" them, matching the time-loop story) with extra enemies added, or freshly generated?

---

## B. Rosters

### 7. Towers (4)
All towers are autonomous. Only the Airship attacks air; the other three attack ground only.
| Tower | Role | Range | Damage | Cost | Notes |
|---|---|---|---|---|---|
| Fire Tower | shoots a fireball at one target; good range, **no AoE** | 5 cells | 14 per fireball, 1 shot per 1.5 s | 60 | the reliable heavy hitter |
| Blast Brazier | **good AoE, short range, lower damage** | 2 cells | 4 per pulse to all within 1 cell, 1 pulse per second | 50 | holds a choke point near the village |
| Longbow Tower | like the Fire Tower but weaker, **longer range, piercing** | 6 cells | 4 per bolt, hits every enemy in a line, 1 shot per 1.2 s | 55 | best on straight paths |
| Airship | **air attacks only**; a small friendly airship moored over its cell | 4 cells | 6 per shot, 1 shot per second | 70 | max 2; floats 2 cells above the board |
- No Barricade, Light Tower or Healing Shrine in this roster. Healing is done by the Mend Vial spell instead.
- The friendly Airship uses the airship shape language of #43 in village colours (cream and teal). Enemy flyers are creatures, not airships.

### 8. Hut and troops
- **DECIDED (Siddharth, 2026-10-19): one spawning building per troop type**, not one hut for all troops. The Watch Hut spawns Guards only; Slingers get their own building. OPEN: the Slinger building's name, cost and look; whether it unlocks in loop 2 with the Slinger. Spawning buildings are designed only after the troop characters are final.
- **Watch Hut** (cost 70): spawns a Guard every 8 s, up to 3 alive per hut.
- **Guard:** melee, 30 HP, 4 damage per hit.
- **Slinger:** ranged (2 cells), 2 damage per shot, 15 HP; unlocked in loop 2 (via loop unlock). ~~spawned alternately with Guards~~ (superseded 2026-10-19: spawned by its own building).
- **Rally point:** point at the board with the index finger and pinch to plant one flag; all troops hold near it. Moving the flag is allowed any time. Troops fight on their own otherwise.

### 9. Enemies (5 + boss) and Foresight reveal
Speed in cells per second, HP in points. Looks follow the faceted skeleton family (#24-27), no jewel accents; types come from #10, #13-15, #36, #42.
| Enemy | Behaviour | Speed | HP | Revealed at Foresight tier |
|---|---|---|---|---|
| Grunt | walks path, melee | 0.4 | 20 | 1 (silhouette) |
| Scout | fast, ignores towers, rushes houses | 0.8 | 10 | 2 (type) |
| Flyer (Wisp, see 10) | straight line over walls | 1.2 | 8 | 1 (direction of its spawn point) |
| Tunneler | goes underground, pops up mid-village | 0.4 | 30 | 3 (path) |
| Splitter (mushroom, #15) | splits into 2 small on death | 0.4 | 25 (+2 x 8) | 2 (type) |
| Fog variant (loop 2+) | hidden from Foresight, only seen when it reaches the board | 0.4 | 25 | never |
- **Boss (placeholder name "the Warden"):** 3 phases. P1 summons Grunt groups. P2 shielded by 3 crystals that must be destroyed (drop spells are ideal). P3 enrages, adds flyers rising from the tree line. Loop 2 adds a 4th phase.

### 10. Flyers
- **One type:** the Wisp (small, fast, 8 HP), a creature. The Sky Barge enemy airship and any second flyer are cut (Siddharth, 2026-10-17).
- **Entry:** rise out of the tree line above a forest spawn point, then fly at a height of 3-5 cells above the board straight toward their target.
- **Defeating them:** the Airship tower attacks air. Hands: swat a Wisp (hand speed above a low threshold passing through its hit sphere); thrown Fire Orbs can hit flyers directly; Boulder Drop and ground towers cannot hit air.
- **Forgiveness:** hit sphere is 2x the visual radius; 100 ms magnetism toward the hand; swat damage works at any real hand speed above 0.5 m/s.
- **Introduction:** Wisps from night 2 of loop 1.

---

## C. Hand interactions

### 11. Spells and potions (4)
Cooldown only; no mana or resource cost.
| Spell | Gesture | Cooldown | Effect |
|---|---|---|---|
| Mend Vial | grab vial, tilt to pour over an area | 20 s | heals 30 over 3 s within a 2-cell radius |
| Fire Orb | grab, throw in an arc | 8 s | 12 damage within a 1-cell radius on impact; can hit flyers directly |
| Boulder Drop | grab, release above the board (drop spell) | 15 s | damage and radius scale with release height (see 12); ground only |
| Ward Rune | trace a circle with a fingertip over a house | 25 s | absorbs 40 damage for 8 s |
- Each spell object sits on the palm menu with a cooldown ring; it can be grabbed again when the ring completes.

### 12. Drop-spell rule
- A dropped spell is released at height h (clamped 1-8 cells above the board) and falls with toy gravity (0.25 g) so timing is readable.
- Fall time: t = sqrt(2h / (0.25 g)). For the physics only, convert: 1 cell = 0.05 m. Example: h = 8 cells (0.40 m) gives about 0.57 s.
- Damage multiplier: 1 + h / 8 cells. Radius multiplier: 1 + 0.5 * h / 8 cells (base radius in cells as given per spell).
- Higher drops hit harder and wider but arrive later, so the player must lead a moving enemy.
- Foresight tier 3+ can show a landing marker (designed from the UI cluster #37/#38/#41).

### 13. Foresight gesture
- **Primary:** grab a crystal lens (always on the player's belt-side) and hold it up to look through toward the forest edge. Gaze-aimed.
- **Optional:** cup a hand like a spyglass if hand detection proves reliable.
- **Tier visuals:** tier 1 blurry silhouettes + the compass direction of each group; tier 2 adds type icons + counts; tier 3 adds exact path ribbons; tier 4 adds timing markers; tier 5 (late) "rewrite": close one forest spawn point or swap one enemy type.
- Holding the lens costs nothing, but one hand is occupied while looking.

### 14. Menus and interaction (hands only)
- **Build menu:** turn the left palm up to open a radial wheel (#37) with the tower and hut cards; pinch-grab a card to pull the 3D model out; drag onto the board, preview ghost snaps to the grid, release to place, throw off the island to cancel.
- **Spells:** a second tab of the same wheel (or a row of 4 objects on the palm, each with a cooldown ring).
- **Rally flag:** point and pinch on the board (see 8).
- **Board movement:** rotate only (two-hand grab, rotate about the vertical axis, snaps to 90 degrees); no pan or zoom, since the whole board is 12 cells wide.
- **Title, pause, quit:** a wrist button (look at the wrist, pinch) opens a pause card; large pinch targets only. Quit needs a held pinch to confirm. Nothing requires a controller.

---

## D. Progression

### 15. Time loop
- **Resets:** night/day counter, trust, spell cooldowns, towers and huts, village damage.
- **Persists:** chosen abilities, Foresight tier, tower/troop unlocks, villager memories, loop count.
- **Beating the boss:** the game shows 3 ability cards drawn from the pool; keep 1. (Confirmed by Siddharth.)
- **Losing a night:** shows 1 card; keep it (no choice).
- **Run length: FIXED RUN (Siddharth, for the hackathon).** A run is loop 1 and loop 2 (loop 3 only if built), then it ends. So a player earns about 1 to 3 cards per run; the pool of 14 is sized for variety across replays, not to be collected in one run.
- **Ability cards with rarity, PROPOSED (revision 4).** Siddharth's direction: most cards are tower/troop upgrades (towers have no tiers, so these ARE the upgrades), a few are overall upgrades, and each card rolls a rarity that scales its effect.
- **Rarity roll:** each of the 3 offered cards rolls its own rarity: Common 70%, Rare 25%, Legendary 5%. (Odds confirmed by Siddharth.) Rarity shows on the card frame and with a reveal effect.
- **Duplicates:** a card you already own can be offered again only at a higher rarity than the one you hold; taking it upgrades your copy (it does not stack on top).
- **Losing a night:** still 1 card, no choice, always Common.
- **Legendary bonus:** a Legendary card gets the Legendary numbers AND a new behaviour (last column), so it feels different, not just bigger. Legendary bonuses MAY break a tower's normal role (e.g. Longbow hitting flyers, Airship hitting ground); that is the point of a Legendary (confirmed by Siddharth). Each bonus is visible on the board (an effect or animation) so the player sees what changed.
- **Pool (14): 11 tower/troop cards, 3 overall.** Values are Common / Rare / Legendary.

| # | Card | Applies to | Common | Rare | Legendary | Legendary bonus |
|---|---|---|---|---|---|---|
| 1 | Ember Shot | Fire Tower | burn 2 dmg/s for 3 s | 3 dmg/s | 4 dmg/s | an enemy that dies while burning passes its burn to the nearest enemy within 1 cell |
| 2 | Quick Fuse | Fire Tower | fires 15% faster | 25% | 40% | every 5th fireball is double size and deals double damage |
| 3 | Bellows | Blast Brazier | pulses 15% faster | 25% | 40% | every 3rd pulse knocks ground enemies back 1 cell |
| 4 | Hot Coals | Blast Brazier | 5 dmg per pulse (base 4) | 6 | 8 | each pulse leaves a burning patch for 2 s (2 dmg/s) |
| 5 | Heavy Bolts | Longbow Tower | 5 dmg per bolt (base 4) | 6 | 8 | bolts slow every enemy they pierce by 30% for 2 s |
| 6 | Long Draw | Longbow Tower | range 7 cells (base 6) | 8 | 9 | bolts can also hit flyers |
| 7 | Long Mooring | Airship | range 5 cells (base 4) | 6 | 7 | the Airship can also shoot ground enemies at half damage |
| 8 | Twin Cannons | Airship | fires 15% faster | 25% | 40% | each volley fires at two different targets |
| 9 | Shield Wall | Guards | +25% HP | +50% | +100% | enemies within 1 cell of a Guard must fight it before moving on |
| 10 | Sharp Stones | Slingers | +25% damage | +50% | +100% | each stone bounces to a second enemy within 1 cell |
| 11 | Friendly Faces | Watch Hut | 4 troops per hut (base 3) | 4, respawn 25% faster | 5, respawn 50% faster | troops standing near the rally flag heal 2 HP/s |
| 12 | Quick Hands | all spells | cooldowns 15% shorter | 25% | 40% | each spell cast has a 25% chance to come back off cooldown instantly |
| 13 | Sturdy Homes | houses | +25% HP | +50% | +100% | once per night, the first house that would be shuttered holds at 1 HP instead |
| 14 | Deep Pockets | trust | +30 starting trust | +50 | +80 | +5 trust after every night in which no house was shuttered |

- Sharp Stones is only offered once Slingers are unlocked (loop 2).
- Dropped: Far Sight (Foresight already sharpens each loop), Thunder Drop (spell, not tower/troop).
- A larger pool comes later.

### 16. Loop 2 difficulty (what the video must show)
- **Both** more and new: +40% enemy HP, one extra group per night, Tunnelers from night 2, the Fog variant, and the boss gains a 4th phase.
- **Visible upgrade for the demo:** Foresight goes from blurry silhouettes (loop 1) to type icons with counts (loop 2), and the villagers' first memory lines appear.

### 17. Fate Coin
Flicked each morning with the thumb; the landed face shows a glyph. Outcomes (starting weights equal):
| Glyph | Name | Effect for that day/night |
|---|---|---|
| 1 | Market Day | trust from requests x2 |
| 2 | Lucky Find | +60 trust immediately |
| 3 | Gentle Rain | spell cooldowns 40% shorter, flyers slowed 30% |
| 4 | Foggy Night | Foresight drops one tier; +50% dawn trust |
| 5 | Full Moon | towers +20% damage, enemies +20% HP |
| 6 | Restless Night | +1 enemy group; houses heal 10 HP at dawn |
Two good, two neutral-mixed, two risky, so the player always plans around the coin.

### 18. Villagers
- **Cast for the slice:** 5 villagers sharing one part-based design (reference #29 for proportions).
- **Help requests (4 kinds):** Blocked chimney (grab and pull out the rubble), Stuck bird (grab and move it), Lost lantern (carry it back to its house), Stuck cart (push it clear). Rewards: 10-25 trust.
- **Memory dialogue (wordless icon bubbles + short subtitle):** loop 1 none; loop 2 the baker says "Haven't we met?" and two other villagers show small recognition; loop 3 (if built) someone helps on purpose for free.

---

## E. Story and presentation

### 19. Boss and reveal
- **Boss:** "the Warden", the forest's old guardian, grown from the cracked Heartwood crystal.
- **Why the forest turned:** the village's ancestors took a piece of the Heartwood; the Warden's grief corrupts the forest.
- **Time loop:** the same crystal powers the player's Foresight and the rewind.
- **Reveal:** loop 1 it is just a monster; loop 2 its crystal matches the player's lens; later loops hint at making peace. (Fully optional beyond loop 2.)
- **Title:** Endless Watch is a working title, not final (Siddharth).

### 20. First minutes, wordless tutorial (in order)
1. Flick the Fate Coin. 2. Raise the lens and look at the forest edge (silhouettes). 3. Palm-up menu, pull a tower, place it on the glowing grid. 4. Help one villager (grab the stuck bird). 5. Dusk: the forest stirs and the first enemies appear at the tree line. 6. Night: cast a spell and swat a Wisp. 7. Dawn summary. About 6 icon hints, no spoken words.

### 21. Demo-video beats (in order)
1. Real room, island appears on the table. 2. Lens reveals the incoming raid. 3. Hands place towers. 4. A flyer rises from the tree line and crosses the board, hand swat. 5. Drop spell lands. 6. Boss defeated and the rewind sequence. 7. Loop 2 with visibly sharper Foresight. 8. Title card.

### 22. Audio mood words
- Dawn: soft, hopeful, music-box. Day: warm, plucky, marimba and gentle strings. Dusk: amber, hushed, low cello. Night: tense but cozy, soft drums and glow-chimes. Boss: big drums, no choir. Rewind: reversed shimmer, rising.

---

### 24. First-time judge experience (PLAN AFTER THE GAME IS COMPLETE)
- Judges open the game cold and move fast, so a fast first-run path will be needed (a skippable or compressed tutorial and an early, visible hook).
- This is deliberately not designed yet. Revisit once the core game exists, and keep these constraints in mind meanwhile: the time-loop twist must be reachable quickly, and nothing should require a controller.

## F. Comfort

### 23. Seated rules
- Everything the player must touch is within 9 cells (real 45 cm) of their torso and below eye level.
- Board centre 9-11 cells (real 45-55 cm) from the eyes (always true for the floating fallback; for a real table, if it is farther than that the board still sits on it, so interaction must not require reaching beyond arm length, see A1). Flyer reach zone is within 10 cells and no higher than 4 cells above the board, so no reaching above the head or behind.
- Essential UI stays within 30 degrees of the view centre (FoV-aware for the narrower glasses).
- Every gesture has a one-handed alternative and no gesture needs a controller.

---

## Open questions to settle first
1. Selling or refunding towers: none in this draft. Want it back, or no?
2. Tower cap (8 towers + 2 huts, max 2 Airships): keep?
3. Which remaining items do you want to change before the first playable?
