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

## Open (the user's latest requests, newest first)
1. Declutter: "!" markers, HUD text, overlapping bubbles, task bubbles during the intro narration.
2. Complete UI rework, including the sell flow ("selling the towers isnt cool").
3. Tiny (kindness) tasks: make them better and explain them to the player.
4. Startup experience: still judged bad after the diorama version.
5. Hand tracking quality.
6. Critic runs (code, player, art) on the overhaul; approvals for shrine, hourglass v02, trees.
7. Stand-ins to model: kite, lamb. Oak models not placed.
8. `docs/QUEST_BUILD.md`: add the passthrough manifest line. Log shrine-blocks-centre, UI rig and passthrough in `art/decisions.md` / `docs/VFX_NOTES.md`.

## Decisions to remember (the user, 2026-11-10 unless dated)
- For the redesign batch: "Ask me questions dont make assumptions". Ask open design choices together, in one go.
- UI: a floating arc in front of the player. Mirror: pinch the handle, glass faces the eyes.
- First run: the story told piece by piece as an in-game animation on the island.
- Hands look: the user will judge it in the headset.
- Performance: OVR Metrics Tool.
