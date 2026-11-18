# Aeterna

**A seated mixed-reality tower defence for Meta Quest 3.** Your table becomes a small floating island. You are its very small god, and the village on it falls every few nights. Each time it falls, you turn the hourglass and the village starts again, keeping a little of its Faith.

You play with your bare hands. Pinch cards off a wooden tray to build towers, drop spells onto the board at night, help villagers by day, and lean over the island the way you would over a board game.

> Built with Godot 4.7.2 and OpenXR for the Meta Quest 3 (hand tracking, passthrough). We made every 3D model ourselves from Blender scripts, with no AI-generated or third-party models.

---

## Contents
- [The game](#the-game)
- [How it plays](#how-it-plays)
- [Getting started](#getting-started)
- [Running it](#running-it)
- [How the art is made](#how-the-art-is-made)
- [Repository layout](#repository-layout)
- [Working on the project](#working-on-the-project)
- [Status and known rough spots](#status-and-known-rough-spots)
- [Credits](#credits)

---

## The game

You are a forgotten-sized god with one power: the **Veil**, a dome of warm light woven from your villagers' **Faith**. Skotos, the Warden, is an older god of the Dark Wood whose people stopped praying to him. He has cursed the Veil so it fails every night.

- **By day**, twelve villagers go about their lives. They wave when they need a hand: a lost lamb, a kite in a tree, laundry blown away, a cat stuck somewhere. Helping them raises Faith, and Faith pays for defences.
- **By night**, creatures come out of the forest. Your towers fight on their own. You fight with spells.
- **The last night of every loop always falls.** You turn the hourglass, time rewinds, and the village lives the days again. They remember a little more each time, and so do you.
- From the third loop on, the statue at the centre of the village offers an **ending** at each dawn. You can take it or keep looping.

The tone is cozy rather than grim: warm, plain, a little funny, then quietly sad. The whole story, cast and lines are in [`docs/STORY.md`](docs/STORY.md).

## How it plays

### The board
- A 24 x 24 grid on a 1.2 m island. One cell is 5 cm.
- Everything snaps to whole cells, and every gameplay number (range, speed, radius) is measured in cells.
- You play seated. The island sits on your real table in passthrough, and you can spin it by its rim.

### Towers (day, from the card tray)
| Tower | Role | Range | Cost |
|---|---|---|---|
| **Wizard Tower** | A wizard throws fireballs at one target, with a small splash. The reliable heavy hitter. | 5 cells | 60 Faith |
| **Guard Tower** | Sends out 3 Guards who hold a ring round it, chase whatever comes close, then walk back. | 2-cell sight | 70 Faith |
| **Longbow Tower** | A weaker bolt that pierces every enemy in a line. Best on long straight approaches. | 6 cells | 55 Faith |
| **Airship** | A small friendly airship moored over its cell. The only tower that hits flyers properly. | 4 cells | 35 Faith |

### Spells (night, cooldown only, no mana)
| Spell | How you cast it | What it does |
|---|---|---|
| **Fire Orb** | Grab it and throw or drop it over the board | Burst of fire damage in a 1-cell radius |
| **Boulder Drop** | Grab it and let go above the board | The higher you drop it, the harder and wider it hits, and the later it lands |
| **Storm Cloud** | Release a dark cloud over the board | Hangs there and strikes nearby enemies, chaining between them |
| **Rage** | Release over the board | Towers inside a red ring shoot 50% faster |
| **Root Ward** | Drop the potion on a house | Roots grow round the house and soak up damage |

Every spell hits both ground and air. Magic in Aeterna is black, orange and red, never blue.

### Enemies
Grunts, fast Scouts that rush houses, flying Wisps, Tunnelers that surface in the middle of the village, and Splitters that burst into smaller ones. Then there's **Skotos** himself. He fights in several phases, and in later loops he adds a fourth phase, *the Grove*, which grows wood over your towers and strangles them.

### Loops
- **Loop 1** is three nights: a tutorial night, a night on your own, and the night that falls.
- **Every later loop** lasts a random 1 to 8 nights (most often in the middle). Its last night is always the fall.
- Faith carries over at each rewind: a share of what you had, plus a bonus for each villager and each kindness.

### Hands
- **Pinch** (thumb to index) picks things up: cards, spells, quest items, the tray's brass handle.
- **Tap** a villager to hear what they're thinking.
- **Look through the Crystal Lens** on the tray to read hidden lore and see what's coming.

The design reference is [`docs/GAME_SPEC.md`](docs/GAME_SPEC.md). Some of its numbers are stand-ins. The live values are in [`godot/scripts/game/game_config.gd`](godot/scripts/game/game_config.gd).

---

## Getting started

Windows 11 is the main platform. The full guide is [`docs/SETUP.md`](docs/SETUP.md).

| Tool | Version | Needed for |
|---|---|---|
| Git for Windows + Git LFS | recent | everything (models, images and sounds live in LFS) |
| Python | 3.10+ with Pillow | the tools in `tools/` |
| Godot | **4.7.2 stable**, win64 (keep the `_console.exe` next to the editor) | running and building the game |
| Blender | 4.5 LTS | regenerating 3D assets |
| Meta XR Simulator | 207.1 | playing in VR without a headset |

```bash
git lfs install
git clone <repo url> aeterna
cd aeterna
cp local.env.example local.env      # then set BLENDER_EXE, GODOT_EXE, META_XR_SIM_JSON for your machine
python tools/doctor.py              # fix anything marked FIX until it says "All good."
python tools/sync_to_godot.py --check   # imports the models; must end with 0 FAIL
```

`local.env` is git-ignored, so each person keeps their own machine paths in it.

## Running it

**On the desktop (mouse and keys, no VR):**
```powershell
powershell -File godot\run_desktop.ps1
```

**In VR through the Meta XR Simulator (no headset):**
```powershell
powershell -File godot\run_sim.ps1
```
The script selects the simulator for that one process only. Never run the simulator's own "activate" script, because it changes a system-wide setting. Simulator keys: `1`-`4` hand poses (`3` = pinch), left mouse = pinch, `[` `]` switch the driven hand, `WASD` / `R` / `F` move.

**On a Quest 3:** double-click `quest_build.bat` in the repo root. It exports the APK, installs it over USB and saves the headset log to `_work/quest_log.txt`. The one-time setup (Android export templates, the OpenXR Vendors plugin, manifest entries, JDK and SDK paths) is in [`docs/QUEST_BUILD.md`](docs/QUEST_BUILD.md). On the headset, open it from Library > Unknown Sources > Aeterna.

**Self-test (game logic, headless):**
```bash
python tools/selftest.py
```
It prints only the failures and the total. The current suite has about 870 checks.

**Headset-free VR play test:** `godot/tools/vr_play.gd` replays a real recorded Quest session through a simulated human hand and head, then plays the tutorial, the tray and the rewind cutscene, logging pass/fail and taking screenshots. Usage is in [`docs/HANDOFF.md`](docs/HANDOFF.md) section 4.

---

## How the art is made

Every 3D asset is **code**. Each model has one Blender generator script, and nobody edits a `.blend` or `.glb` by hand.

```
assets/generators/make_<name>.py  ──Blender──▶  assets/blend/<asset>.blend
                                              ├─▶ assets/export/<category>/<asset>.glb ──▶ godot/assets/
                                              └─▶ assets/previews/<asset>/ (sheets, lighting strips)
```

- **One palette.** Colour comes only from a shared atlas (`art/palette_atlas.png`, generated from `art/palette.json`). Models point their UVs at swatch cells, so the whole game shares two materials: `ew_palette` and the emissive `ew_palette_glow`.
- **No skinned rigs.** Characters are separate parts parented to a root and animated in Godot (`CharacterRig`).
- **Magic is drawn as VFX in Godot.** Models have dark sockets and `__<name>_anchor` empties, never glowing geometry.
- **Naming:** `ew_<category>_<name>_v<NN>`. Every round is a new version, and the old ones are kept for comparison.
- **Budgets** (triangles): props 800, houses and towers 2000, characters 2000, boss 6000.
- **Checks:** `tools/validate_asset.py` must print OK. `tools/greyscale_check.py` checks readability by value, not hue.
- Style rules are in [`art/art_bible.md`](art/art_bible.md), and every art decision is logged in [`art/decisions.md`](art/decisions.md).

Useful commands:
```bash
blender -b -P assets/generators/make_<name>.py                         # build one asset headless
python tools/make_sheet.py assets/blend/<asset>.blend assets/previews/<asset>
python tools/validate_asset.py assets/blend/<asset>.blend
python tools/render_lighting.py assets/blend/<asset>.blend assets/previews/<asset>
python tools/sync_to_godot.py assets/export/<category>/<file>.glb      # bring into Godot
```

**Sound.** Sound effects are real recordings under CC0, CC BY or a royalty-free licence, then cut and layered. Each one is logged with its source, author and licence in [`docs/AUDIO_CREDITS.md`](docs/AUDIO_CREDITS.md), and music in [`docs/MUSIC_CREDITS.md`](docs/MUSIC_CREDITS.md). No AI-generated sounds are used.

---

## Repository layout

```
art/            art bible, palette (json + atlas), decision log, moodboard (style reference only)
assets/
  generators/   one Blender script per model (the source of truth)
  blend/        generated .blend files (LFS)
  export/       generated .glb files (LFS)
  previews/     turntable sheets, lighting strips, dioramas
  ASSETS.md     log of every asset: version, triangles, who approved it
docs/           game spec, story, setup, Quest build, VFX notes, audio direction, credits, STATUS
godot/          the Godot project
  scripts/game/   rules, board, towers, enemies, hands, quests (game.gd is the hub)
  scripts/story/  the opening story world and cutscenes
  scripts/ui/     card tray, ledger, launcher and tutorial, title card
  scripts/vfx/    spell and boss effects
  scripts/audio/  music director and sound
  shaders/        Veil dome, grass, outlines, hurt cracks
  data/           villager thoughts and story lines (thoughts.json)
  tests/          the self-test suite
  tools/          shot scripts, perf probes, the VR play bot
tools/          Python pipeline: doctor, render, validate, sync, palette, perf, recordings
quest_data/     recordings and perf logs from real headset sessions
.claude/        shared skills and review agents for the team's Claude Code setup
```

---

## Working on the project

There are two of us, working on `main`. The rules both of us follow (and both of our coding agents load) are in [`CLAUDE.md`](CLAUDE.md) and [`AGENTS.md`](AGENTS.md). The short version:

- **Pull before you start, push when you're done.** Everything goes on `main`, and nobody force-pushes.
- **Claim an asset** in the tracker before working on it. One owner at a time.
- **Change the generator, then regenerate.** Binaries can't be merged.
- **Logs are append-a-row** (`ASSETS.md`, `decisions.md`, `VFX_NOTES.md`, `ASSET_LIST.md`). On a conflict, keep both rows.
- **An asset is done** only when either of us approves it, and the approval is logged with a name and date.
- **No AI-generated or third-party models.** Moodboard images are for style only, which is why this repo stays private.
- Where things stand right now is always in [`docs/STATUS.md`](docs/STATUS.md).

---

## Status and known rough spots

This is the **competition build**, frozen for the deadline on 2026-11-18. To be upfront about it:

- The last round of fixes (single-handle tray, zoom removed, 13-step tutorial, the big hourglass in the rewind, softer shadows against shimmer, the Veil fading near your eyes) passes the self-test and the scripted VR bot. **None of it has been tried on a headset yet.**
- The bot can't judge blur, shimmer, comfort or frame rate. Those need a real Quest.
- Waving villagers still shift a few centimetres while you reach for them. The quest slip can look large over the village.
- Skotos v02 and the quest props are awaiting approval.
- Some balance numbers are still stand-ins (marked `~` in `game_config.gd`).

## Credits

Made by **Siddharth** (design, gameplay, environment, towers) and **Durva** (characters, audio, UI).

Sound effect and music credits: [`docs/AUDIO_CREDITS.md`](docs/AUDIO_CREDITS.md), [`docs/MUSIC_CREDITS.md`](docs/MUSIC_CREDITS.md).

This is a private repository. All 3D models, code and writing belong to the team. Third-party sounds stay under their own licences as logged.
