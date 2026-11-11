# Aeterna: where things stand

The handoff file. Read this first after a break or a compaction (skill `lean-context`), and update it before stopping. Keep it short: delete what no longer matters.

Last updated: 2026-11-11, at commit `6da9099` plus the lean-context tooling.

## On the headset
- Installed build: 2026-11-10, 14:45. Everything listed under "Untested on the Quest" is newer than it.
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
4. The ledger (our own gilded parchment, not a copy of any existing design; never blue): turn the left palm up and it unfolds above it. Pages: the god's status, the villagers, towers and spells, quests. Desktop/controllers: a key or button.
5. After the hourglass: gilded text, "Time has been rewound" + "Loop II" (the user wants the loop named).
6. Opening: title first, but alive (Veil shimmering, villagers asleep, one big gilded Wake seal), then the story animation. No quest markers or bubbles on the title or during the story.
7. Statue replaces the shrine: the little god, hooded, cupped hands holding the ember, on a plinth, clearly bigger than a thumb ("i should be bigger than a thumb"). make-asset: 4 variants, the user picks.
8. Move and resize the island: pinch the table rim with one hand to drag and turn; both hands on the rim to resize (about 0.6x to 2x).
9. Quest build: user exports, install game + OVR Metrics Tool, read the headset log for hands and passthrough.

## Still open after the plan
- Hand tracking quality; critic runs; approvals for hourglass v02 and trees; kite and lamb stand-ins; oak models not placed.
- `docs/QUEST_BUILD.md` passthrough manifest line; log decisions in `art/decisions.md` / `docs/VFX_NOTES.md`; update `docs/STORY.md` (statue, thumb line) and `docs/GAME_SPEC.md` (day timer, sell, quests).

## Decisions to remember (the user, 2026-11-10 unless dated)
- For the redesign batch: "Ask me questions dont make assumptions". Ask open design choices together, in one go.
- UI: a floating arc in front of the player. Mirror: pinch the handle, glass faces the eyes.
- First run: the story told piece by piece as an in-game animation on the island.
- Hands look: the user will judge it in the headset.
- Performance: OVR Metrics Tool.
