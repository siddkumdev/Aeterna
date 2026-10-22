---
name: palette-change
description: Add, tweak or retire Aeterna palette colours safely - propose, show Siddharth a highlighted swatch sheet (and a before/after diorama when an existing colour changes), apply only after his OK, then rebuild the atlas and re-export affected assets. Use whenever a new colour is needed, a colour looks wrong, or a colour should stop being used.
---

# palette-change

Every model's colour comes from `art/palette.json` through the 8 x 8 atlas `art/palette_atlas.png`; a colour's atlas cell = its position in `materials`. Rules (Siddharth, 2026-10-17):
- **Add** = append at the end. Never reorder or delete (that would repaint every built model).
- **Tweak** an existing hex = allowed, but only after he sees a **before/after** of the built assets that use it, and says OK. Affected assets are then re-exported.
- **Retire** = the colour keeps its slot and hex, is listed under `"retired"`, and `validate_asset.py` warns if an asset uses it.
- Colour rules still apply: magic is black/orange/red, never blue (blue = Foresight only, purple = the Warden); time-of-day strips and lighting presets are separate (`time_of_day`, `lighting`), not atlas colours.
- Max 64 colours. Check before proposing: `python tools/palette_change.py usage` (colours per exported asset, plus unused ones; reuse an existing colour if one fits).

## Steps
1. **Ask first.** What is the colour for, which asset needs it, any reference? If an existing colour might do, say so.
2. Write a proposal file in the scratchpad (not in the repo):
   `{"reason": "...", "add": {"name": "RRGGBB"}, "edit": {"name": "RRGGBB"}, "retire": ["name"]}` (any of the three may be empty). Names lower_snake_case.
3. `python tools/palette_change.py propose <proposal.json>`
   - Validates (hex, names, 64 limit) and touches nothing real.
   - Writes `art/palette_preview_proposed.png`: changes outlined in red, a tweaked colour shows its old hex as an inset.
   - Lists built assets using a changed/retired colour (scanned from the newest exported `.glb` of each asset).
   - If an existing colour changes, renders the diorama with the proposed palette: `assets/previews/diorama/layout_mock_proposed/diorama.png` (AFTER). BEFORE is `assets/previews/diorama/layout_mock/diorama.png`; re-render it first with `python tools/render_diorama.py` if it is stale. Affected assets that are not on the diorama layout: say so (render them with the lighting strip if needed).
4. Look at the sheet (and before/after) yourself, then send them to Siddharth (SendUserFile) with: each change, why, the assets it touches, and the question "OK to apply?".
5. **Only after he says OK**: `python tools/palette_change.py apply`
   - Updates `art/palette.json` (adds an approval note with the date to `_status`; backup `art/palette_backup_<time>.json`), rebuilds `art/palette_atlas.png` and `art/palette_preview.png`, deletes the proposal files, prints the assets to re-export.
   If he says no or changes it: edit the proposal and propose again. To drop it, delete `art/palette_proposed*.json/png` and `art/palette_preview_proposed.png`.
6. After a tweak: re-run each affected asset's generator (same version: a palette tweak is not a design change; note it in its `ASSETS.md` row), validate, re-render its sheet/lighting strip, then `python tools/sync_to_godot.py --check` (copies the new atlas into Godot) and the diorama.
7. Log: `art/decisions.md` (what changed and why), the art bible section 6a if it lists palette additions, and run **tracker-sync** if `ASSETS.md` changed.

## Notes
- The atlas written by `palette_change.py` is pixel-identical to the one Blender generators write (checked 2026-10-17); either may rebuild it. `python tools/palette_change.py atlas` rebuilds it alone.
- Proposed-palette renders use env `EW_PALETTE_JSON` (read by `blender_common`); its atlas goes beside the proposal, never over `art/palette_atlas.png`.
- In Godot every model shares one atlas, so a palette change shows there after a sync even before re-export; the Blender previews and `.glb` files keep the old colours until re-exported.
