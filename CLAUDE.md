# Aeterna: project conventions

@AGENTS.md

Conventions only. Architecture, algorithms and art decisions are NOT recorded here: gameplay comes from the team prompt by prompt, art decisions live in `art/art_bible.md` and `art/decisions.md`.

## Team
Two people work on this repo, each with their own Claude Code on the same setup: Siddharth and his teammate. "The user" below is whichever of them you are working with; earlier logs saying "Siddharth" record his decisions and still stand. Skills and the art critic were written when he worked alone: read "Siddharth" / "he" there as the user you are working with, except historical decisions; approvals may come from either of them.

## Working agreement
- The user specifies what to build; Claude writes the code (including core game logic). Do not invent gameplay rules; ask when a spec is missing.
- After finishing a task, give the exact command to verify it yourself.
- Write complete reports (they are sometimes on mobile with no terminal). Verify claims before stating them; label inferences.
- No AI-generated or third-party assets. Every asset is built from scratch (Blender scripts) and logged in `assets/ASSETS.md`.
- Moodboard references are for style and shape language only. Never copy a specific third-party design, character or logo. The moodboard holds third-party images, so the repo must stay private.
- Approvals (decided 2026-10-18): an asset is done only on explicit approval by EITHER Siddharth or his teammate. Log who approved: `approved by <name> (date)`.
- Never estimate how long a task takes (no hours/days/effort sizes, in chat or docs). Describe order, dependencies and priority; the deadline 2026-11-18 12:00 PM PT may be cited as a date.
- Magic is black / orange / red (ink bodies, fire_red / lantern_glow / fire_yellow glows), never blue. Blue is only Foresight (Crystal Lens), purple is the Warden. Exception: the wind crossbow tower's wind is pale green, whiter than heal_green, drawn as streaks. See `art/art_bible.md` section 6.
- VFX: log every effect anyone mentions in `docs/VFX_NOTES.md` (effect, their words, anchor, asset-list id). Models get dark sockets plus `__<name>_anchor` empties, never glowing geometry for magic. Build VFX in Godot only after all towers and major assets are modelled.
- Reminders to raise at the right moment: (1) DONE 2026-10-22: community Godot skills reviewed; `godot-gdscript-patterns` (wshobson, MIT) and `godot-development` (omer-metin, Apache-2.0) installed in `.claude/skills/` with a project note on top; fenixnix/Godot-Skills (Godot 3) and struktured-labs/godot-mcp (Linux-only, duplicates our tools) skipped; (2) before the first villager/troop/enemy, build a "character kit" skill (shared body kit, swappable parts, tween animations, pose sheet).

## Sharing (git)
- Private GitHub repo. Binaries (`.blend`, `.glb`, `.png`, `.jpg`) go through Git LFS (`.gitattributes`). Ignored: `local.env`, `_work/`, `*.blend1`, `godot/.godot/`.
- Claim an asset in the tracker (owner) before working on it; one owner per asset at a time.
- Work on `main`; no new branches unless really needed (Siddharth, 2026-10-19), e.g. a risky experiment that could break `main`, and only after asking. Pull before starting, push when done. Unapproved assets are fine on `main`: their status in `ASSETS.md` says "awaiting approval".
- Never hand-edit `.blend` or `.glb`: change the generator and regenerate (binaries cannot be merged). Shared logs (`ASSETS.md`, `decisions.md`, `VFX_NOTES.md`, `ASSET_LIST.md`) are append-a-row files; on a merge conflict keep both rows.
- After every addition or change, commit and push (skill: `github-sync`; standing instruction from Siddharth, 2026-10-19). Everything goes on `main`. Never force-push.
- Never credit Claude in git: no `Co-Authored-By: Claude` trailer and no "Generated with Claude Code" line in commits or PRs (Siddharth, 2026-10-19).

## Platform and tooling
- Windows 11, Blender 4.5, Godot 4.7.2 stable (console build for headless runs), Python 3.10+ with Pillow, Meta XR Simulator 207.1, Git + Git LFS. Machine paths live in each person's git-ignored `local.env` (copy `local.env.example`; keys `BLENDER_EXE`, `GODOT_EXE`, `META_XR_SIM_JSON`), loaded by `tools/ew_env.py`. Check a machine with `python tools/doctor.py`; new machine: `docs/SETUP.md`.
- Godot project in `godot/`; models in `godot/assets/<category>/`, shared materials in `godot/assets/palette/`. OpenXR Vendors plugin not installed yet.
- Godot XR must-haves (verified in the simulator): `xr/openxr/extensions/hand_tracking` AND `hand_interaction_profile` both on. Without the interaction profile a pinch never reaches the game. Pinch/grasp arrive as `trigger_click`/`grip_click` through the default action map. Simulator keys: 1-4 hand poses (3 = pinch), left mouse = pinch, `[` `]` cycle the driven input, WASD/R/F move.
- Headset: none confirmed. Test with the Meta XR Simulator, selected per process via env `XR_RUNTIME_JSON` (never edit the registry, never run its activate script without asking). Launch: `powershell -File godot\run_sim.ps1` (reads `local.env`).
- Untrusted files (downloads, shared `.bee`): own empty directory, run Python with `python -I`, pass paths as arguments.

## Layout
```
art/        moodboard/  art_bible.md  palette.json  decisions.md
assets/     generators/  blend/  export/  previews/  ASSETS.md
tools/      blender_common.py  render_preview.py  make_sheet.py  validate_asset.py
docs/       design docs (copy of the design PDF goes here)
.claude/    skills/  agents/
_work/      scratch input (git-ignored)
```

## Asset conventions
- Name: `ew_<category>_<name>_v<NN>` (categories: world, village, defense, enemy, portal, vr, foresight, ui, vfx).
- Grid-based everything (decided): 1 cell = 5 cm = 0.05 m; the board is 24 x 24 cells = 1.2 m (was 12 x 12 until 2026-10-22; the island v01 model is still 12 x 12 and is stretched in Godot until a 24 x 24 island exists). Gameplay measures (ranges, radii, speeds, heights, footprints) are in cells, models are sized to whole-cell footprints (see `docs/GAME_SPEC.md`). Blender/glTF units stay meters, so a footprint of N cells = N x 0.05 m.
- +Y up on export (glTF), origin at the base of the model, transforms applied, no leftover modifiers.
- Export `.glb` to `assets/export/<category>/`. One generator per asset: `assets/generators/make_<name>.py` with `build(params, seed)`, reading `art/palette.json`.
- No skinned rigs: characters are separate parts animated in Godot.
- Moving parts (decided): one root object `ew_..._vNN` (origin at base) plus children `ew_..._vNN__<part>` parented to it, origin at the part's pivot. Built with `blender_common.assemble()`; budget counts all parts. Emissive bits (fire, lit windows) use the second shared material `ew_palette_glow` (same atlas).
- Avoid procedural materials (they vanish on export). Colour comes ONLY from the palette atlas: `art/palette_atlas.png`, generated from `art/palette.json` (decided). Every model uses UVs pointing at swatch cells and the shared `ew_palette` material.
- Starting triangle budgets (tune on a real Quest): props 800, houses/towers 2000, enemies/villagers 2000, boss 6000.

## Commands
- Preview: `python tools/make_sheet.py assets/blend/<asset>.blend assets/previews/<asset>`
- Validate: `python tools/validate_asset.py assets/blend/<asset>.blend`
- Lighting presets: `python tools/render_lighting.py assets/blend/<asset>.blend assets/previews/<asset>`
- Palette sheet: `python tools/make_palette_preview.py`
- Palette change (add / tweak / retire a colour; propose, the user OKs, apply): `python tools/palette_change.py usage|propose <file>|apply` (skill: palette-change)
- Diorama shot (real assets on the board, all presets, board budget): `python tools/render_diorama.py` (skill: diorama-shot; layout in `assets/diorama/layout_mock.json`, a MOCK)
- Variant sheet: `python tools/make_variant_sheet.py <out.png> A=<a.blend> B=<b.blend> ...`
- Asset-building workflow: the `make-asset` skill (ask the user first, variants, build, critic, show, version, log, done only on approval by Siddharth or his teammate).
- Bring into Godot (copy, import, shared materials, anchors, check): `python tools/sync_to_godot.py assets/export/<category>/<file>.glb` (skill: godot-import; `--check` re-checks all). Headless Godot runs always need `--xr-mode off`.
- GitHub sync (commit + push after every change, on `main`, no Claude credit): skill `github-sync`.
- Tracker sync (regenerate + republish the live asset tracker, move built items' status forward): `python tools/sync_tracker.py` then the tracker-sync skill steps.
- Generate headless: `blender -b -P assets/generators/make_<name>.py` (Blender = `BLENDER_EXE` from `local.env`)
- Machine check: `python tools/doctor.py`
