# Aeterna: where things stand

The handoff file. Read this first after a break or a compaction (skill `lean-context`), and update it before stopping. Keep it short: delete what no longer matters.

Last updated: 2026-11-11, at the statue commit (boss forms, elites, statue done; code-critic pass pending).

## Two sessions
- Cross-session messaging (ListAgents / SendMessage) is on. Siddharth-side or second session: none was running on 2026-11-11. This session's name: `aeterna-first-five-minutes-overhaul`. Before editing a file the other session may hold, ListAgents and message it; say which plan step you are taking.

## On the headset
- Installed build: 2026-11-11, 15:36 (commit 946ce27: puppet-theatre opening, book ledger, hands). Everything listed under "Untested on the Quest" is newer than it.
- OVR Metrics Tool: not installed. The user downloads it (needs a Meta sign-in) and gives the file name; it goes on with the next game install.

## Done (in `main`)
- Quest export and install pipeline (`docs/QUEST_BUILD.md`, skill `quest-build`).
- Story: Skotos, 12 villagers, five loops of lines, dawn prayers, two endings as a choice (`docs/STORY.md`, `godot/data/thoughts.json`).
- Rules: Faith (was Trust), 5 days per loop, night 5 always falls.
- Physical cards on a tray (towers, spells, abilities, endings); unavailable cards greyed (Siddharth).
- Tap a villager for a thought; compact speech bubbles (Siddharth).
- Kindness tasks reskinned: kite, lost lamb, festival lantern, stuck cart.
- Shrine at the centre, hourglass v02 and the rewind, Veil dome, new trees, grass seated, look-through lens.
- Title screen, intro as a living diorama, first-day hints (`godot/scripts/ui/launcher.gd`).
- Wizard sounds (Siddharth).

## Untested on the Quest
- Passthrough (may still need the blocked vendor plugin).
- God hands: the last build showed only the ember orb. Cause unknown, the log was never read.
- UI rig floating in front of the player; mirror held upright facing the eyes.

## The plan (decided with the user 2026-11-11; do in this order, each step shot, tested, pushed)
1. DONE Plugins off for this project (`.claude/settings.local.json`, git-ignored). Kept: code-review, pyright-lsp, skill-creator, i-have-adhd.
2. DONE Declutter and controls: no Sell / Start night / Speed slabs and no HUD text in the played game. Day ends by itself after `GameConfig.DAY_LENGTH` (180 s) with a sun on an arc; tray hourglass = fast (day x10; night shows "2x", runs x4; Tab on desktop); sell = pinch and hold a built tower (`crush_start/step/cancel`; desktop: hold the mouse on it); faith on a wax seal on the tray; one fading toast line. Not done: the dusk bell (Siddharth removed the bells on 2026-11-08; ask before bringing one back). The red "!" go in step 3.
3. DONE Quests: `Game._plan_quests` deals 4 kinds a day from a shuffled deck of 8 (chimney/kite, bird/lamb, lantern, cart, rain, warm, lights, prayer), posted one by one at `GameConfig.QUEST_TIMES` of the day (`_tick_quests`); day 1 of loop 1 starts with the prayer. Gold mote over the asker, no "!". Ghost hand (`scripts/ui/ghost_hand.gd`) plays once per kind. `HelpRequest.info()` feeds the ledger. Tests use `force_quests([...])`. Shot tool: `godot/tools/quest_shot.gd`. Stand-ins from primitives: cloud, dry field, ghost hand (to model later).
4. DONE The ledger: `scripts/ui/ledger.gd` + `ledger_page.gd` (four tabbed pages drawn like the cards), data from `Game.ledger_data()`. Headset: left palm up for 0.3 s (`palm_pose`, `ledger_from_palm`; hand-joint palm first, left grip pose as fallback), B/Y or menu button latches it open. Desktop: L, then , and . turn pages; tabs can be clicked or poked. Shot tool: `godot/tools/ledger_shot.gd`. UNVERIFIED on the Quest: the palm normal's sign (OpenXR says the palm joint's +Y leaves the back of the hand).
5. DONE Rewind words: `scripts/ui/title_card.gd` (`TitleCard.show_over`), "TIME HAS BEEN REWOUND / Loop II", shown by `Game.show_rewind_words` 3.4 s after `_rewind`.
6. DONE Opening: night title with the gilded name, a breathing Wake plaque and a small Tale plaque (the placeholder Hands plaque is gone); Wake plays 8 beats as gilded words over the island (dawn, people wake, faith into the Veil, Skotos, crack, shatter, hourglass, dawn) then "THE FIRST DAWN". No quests or bubbles until awake.
7. DONE Statue replaces the shrine: the hooded little god, A+C picked by the user (`make_statue.py` variant M, `ew_village_statue_v01`, `village_dresser._shrine`, embers light in `Game._setup_shrine`). Awaiting approval. The node is still called "Shrine".
8. DONE (untested on the Quest) Move and resize: pinch the table rim (`Game.on_rim`, `rim_transform`, `_tick_rim`). One hand drags and turns with the wrist; two hands turn and resize within `GameConfig.BOARD_SCALE` (0.6 to 2.0). Headset hands only.
10. DONE Boss: the Warden is the Eclipse Bloom (`assets/generators/make_boss9.py`, forms a-d) = 4 phases, one body each (a summons, b crystals, c enrage, d final stand with healing vines; `Warden`, `Enemy.BOSS_FORMS`, effects in `scripts/vfx/boss_vfx.gd`, shot `godot/tools/boss_shot.gd`). Not built: vines slowing tower fire, `hit_pulse` wiring, the 15k-triangle budget untested on a Quest.
11. DONE Elites: Cinder Mammoth / Gravemaw Bear / Furnace Orc walk one a night from night 3 (`GameConfig.ELITES`, `Game.night_plan`); only embers on `flame_anchor` so far, stand-in numbers.
12. DONE (untested on the Quest) 2026-11-11 fixes after the user's headset test: ledger is a physical book (`ledger.gd`, `ledger_page.gd`: 3 spreads, a leaf turns, tap the right page forward / left back; opens ONLY by the left tracked palm held 1 s in front of you, once, no follow); tray placed once beside you (not following) and hidden on the title; title plaques float in front of the headset; big day countdown (`Game._tick_clock`); hurrying the day needs a 1 s hold; the rim needs a 0.6 s hold (RIM_WIDTH 0.05); hands smoother (no glove padding, grace through tracking blinks); `GameConfig.DRAWN_PINCH_TOUCH=false` returns the old touch point. Still open: read the headset log once the headset is awake (hands, the story/Wake plaque).
9. Quest build: user exports, install game + OVR Metrics Tool, read the headset log for hands and passthrough.

## Still open after the plan
- The boss (Warden / Skotos) has no body (the user, 2026-11-11): find out why and give it one.
- HOLD (agreed with Siddharth's session 2026-11-11): no pushes to game.gd, launcher.gd, game_config.gd, game_selftest.gd until that session has rebased and pushed its hand-touch commit d6d2831; pull before touching them again.
- Hand tracking quality; critic runs; approvals for hourglass v02 and trees; kite and lamb stand-ins; oak models not placed.
- `docs/QUEST_BUILD.md` passthrough manifest line; log decisions in `art/decisions.md` / `docs/VFX_NOTES.md`; update `docs/STORY.md` (statue, thumb line) and `docs/GAME_SPEC.md` (day timer, sell, quests).

## Decisions to remember (the user, 2026-11-10 unless dated)
- For the redesign batch: "Ask me questions dont make assumptions". Ask open design choices together, in one go.
- UI: a floating arc in front of the player. Mirror: pinch the handle, glass faces the eyes.
- First run: the story told piece by piece as an in-game animation on the island.
- Hands look: the user will judge it in the headset.
- Performance: OVR Metrics Tool.
