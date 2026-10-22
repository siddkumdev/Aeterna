---
name: godot-import
description: Bring exported Aeterna .glb assets into the Godot project (godot/): copy, import headless with the shared palette + glow materials, turn VFX anchors into Marker3D nodes, tag moving parts, run the automatic check and render an in-engine preview. Use when an asset is exported and should appear in Godot, or to re-check what is already imported.
---

# godot-import

Decided with Siddharth (2026-10-17): **one shared material** for every model (plus one glow material), the skill does **import + check only** (tower behaviour scenes come later, when he specs them), the old benchmark models live in `godot/assets/_old/` (ignored by Godot, not deleted), glow brightness is a **default to tune later** on a headset.

## What happens to a model
| In Blender / .glb | In Godot |
|---|---|
| material `ew_palette` | `res://assets/palette/ew_palette.tres` (atlas, Nearest filter, matte) |
| material `ew_palette_glow` | `res://assets/palette/ew_palette_glow.tres` (unshaded: exact palette colour at full brightness in any light) |
| the atlas embedded in each .glb | discarded; every model uses the one `res://assets/palette/palette_atlas.png` (no mipmaps, lossless) |
| empty `..__<name>_anchor[_N]` with extra `ew_size` | `Marker3D` in group `ew_vfx_anchor`, metadata `ew_size` (meters) |
| mesh `..__<part>` (head, cauldron...) | metadata `ew_part` = `<part>`; origin still at its pivot, so rotating the node turns/tips it |

Done by `godot/tools/ew_post_import.gd`, which `tools/sync_to_godot.py` sets as the import script in each model's `.import` file. Files go to `godot/assets/<category>/` (category from the `ew_<category>_` name).

## Steps
1. The asset is exported (`assets/export/<category>/ew_<category>_<name>_vNN.glb`) and validated (make-asset workflow).
2. Sync, import and check:
   `python tools/sync_to_godot.py assets/export/<category>/<file>.glb [more.glb ...]`
   It prints, per model: footprint and height in cells, triangles vs budget, moving parts, VFX anchors with sizes; `0 FAIL` and exit code 0 means OK. FAIL reasons: origin not on the ground, over budget, a surface not using the shared materials, an anchor not converted or without `ew_size`, a height that suggests wrong scale/upside down.
   Re-check everything already in the project: `python tools/sync_to_godot.py --check`
3. In-engine preview (opens a window for a moment; the game's Mobile renderer, day-like light):
   `"<godot console exe>" --xr-mode off --resolution 1200x700 --path godot -s res://tools/preview_shot.gd -- C:/MetaHackathon/assets/previews/godot/<name>.png res://assets/<category>/<file>.glb ...`
   Orange balls = VFX anchor markers (preview only; big area effects are capped). Look at it: colours match the Blender renders, glowing bits keep their colour (not white), nothing blurry, model stands on the ground.
4. If the scene that uses it (e.g. `godot/scripts/spike_main.gd`) points at an older version, update the path (and the height from the check output), then run the logic self-test:
   `"<godot console exe>" --headless --xr-mode off --path godot -s res://scripts/selftest.gd` (must end `ALL PASSED`).
5. Report to Siddharth: the check output, the preview image (SendUserFile), anything that looked off, and the commands.

## Rules and pitfalls
- Always pass `--xr-mode off` for headless/tool runs: the Meta XR Simulator answers as the OpenXR runtime on this PC and a headless run otherwise opens it and hangs.
- Never delete in the Godot project; superseded files move to `godot/assets/_old/` (has a `.gdignore`).
- A new version is a new file (`_v04`); old versions can stay until nothing points at them.
- The `.import` file is written only when it does not exist yet. To change import settings for an existing model, edit its `.import` `[params]` and run `--check`.
- Glow and palette changes are made once in the two `.tres` files, never per model. A palette change (new `art/palette_atlas.png`) reaches Godot on the next sync.
- Budgets in `godot/tools/check_assets.gd` mirror `CLAUDE.md`; change both together, only with Siddharth's OK.
- Godot console exe: `GODOT_EXE` in each person's `local.env` (see `local.env.example`; checked by `python tools/doctor.py`).
