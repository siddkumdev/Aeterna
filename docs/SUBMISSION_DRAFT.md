# Aeterna: submission draft (NOTHING PUBLISHED)

Draft written 2026-11-18 by Claude for Siddharth to edit. Every line marked TODO needs your input. Nothing here has been posted, uploaded or sent.

Deadline: 2026-11-18 12:00 PM PT = 2026-11-19 01:30 IST. Your plan: submit before 20:00 IST on 2026-11-18.

## Checklist (the last job)
1. Final Quest build exported and installed once on the headset (skill `quest-build`, `docs/QUEST_BUILD.md`). TODO: the latest overnight work (b179bfd, 62848da) has NOT been felt on the headset, only desktop, self-test (843 checks, 0 failures) and critics.
2. APK uploaded to the Competition channel. TODO: you do this.
3. Video. TODO: record it; capture list below.
4. Devpost text: below.
5. Licence proof: no AI or third-party assets; sound effects are free-licence recordings credited in `docs/AUDIO_CREDITS.md` (CC BY rows must also appear on a credits screen or the store page). TODO: confirm the credits screen exists or paste the credits on Devpost.
6. Do not push `art/moodboard/skotos/` (third-party references, repo stays private).

## Title and tagline
**Aeterna**: a seated mixed-reality tabletop tower defence on a tiny island, where a village that keeps being rewound learns to defend itself. (TODO: your tagline.)

## Inspiration (draft)
A tabletop you can lean over, a village you come to know, and a Veil that keeps cracking: you guard the island with your bare hands, and each fallen night rewinds time with a little more faith carried over. TODO: your own words on why.

## What it does (draft, from the repo)
- Seated Quest 3 game, hand tracking, passthrough tabletop island (24 x 24 cells, 1.2 m).
- Place towers and cast spells from physical cards on a tray; pinch and drag with your hands.
- Villagers ask for small kindnesses by day (three a day); nights bring waves from the forest.
- Loop structure: loop 1 is three nights and a scripted fall; later loops are longer and random; the ending is offered at each dawn from loop 3, and Faith carries over each rewind.
- Skotos, the boss: several phases, heartwood knots, and in later loops a fourth phase, the Grove, that strangles towers.
- Story told in the Hades style: reactive villager lines between loops, an opening cutscene, a giant story Skotos.

## How we built it (draft)
- Godot 4.7.2 with OpenXR; Meta Quest 3 target with an adaptive quality governor (PerfTier) and a cheap fake bloom for night windows.
- Every 3D asset built from scratch with Blender generator scripts and one shared palette atlas; no AI-generated or third-party models.
- Sound: real recordings only, cut and layered, with licences logged.
- Tested with the Meta XR Simulator and a desktop replay driver fed from a real 20-minute Quest input recording.
- Two people, Siddharth (design, gameplay, environment, towers) and Durva (characters, audio, UI), with Claude Code writing the code under their direction. TODO: confirm how you want AI assistance described.

## Challenges (draft)
Keeping a heavy scene at headset frame rate (GPU bound on Quest), making pinch input forgiving, and keeping the board readable under a lit Veil dome.

## What is next (draft)
TODO: your plans and target launch date (Devpost asks for it).

## Video capture list (suggested order)
1. Opening: night title, the Wake, the first dawn.
2. Placing a tower from the tray (hand pinch, close).
3. A villager request being completed.
4. A night wave and a spell.
5. Veil cracking, then Skotos phases, then the Grove strangling a tower.
6. The rewind with the hourglass.
7. Credits.

## Known rough spots to be honest about
- Not felt on a headset since 2026-11-17 15:35 IST build.
- Veil dome lattice may hide the board a little from the seat; player-critic flagged it (unconfirmed, needs the simulator or headset).
- Skotos v02 and the quest props are awaiting Siddharth's approval.
