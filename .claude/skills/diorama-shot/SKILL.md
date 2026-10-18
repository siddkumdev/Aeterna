---
name: diorama-shot
description: Render the real Endless Watch assets together on the 12 x 12 board (player's seated view, top-down, a close-up of each asset) in all five lighting presets, with the whole board's triangle and draw-call totals against the Quest budget. Use after an asset version is built (before showing Siddharth), when asked how assets look together, or to check the board budget.
---

# diorama-shot

Checks what single-asset sheets cannot: do the assets look right **together**, at the right scale, from where the player actually sits, in every time of day, and does the board stay inside its budget.

## Rules (Siddharth, 2026-10-17)
- **Real assets only.** Only exported game assets are placed; no benchmark models, no grey blocks.
- **Mock layout until the real one exists.** `assets/diorama/layout_mock.json` is a labelled placeholder, NOT a gameplay decision. The real board layout (paths, 6 houses, 3 forest spawns; asset list G13) is Siddharth's call. When he decides it, write `assets/diorama/layout_<name>.json` and use that.
- **Views:** player's seated view (~50 cm from the board centre, eyes ~40 cm above the table), top-down, one close-up per asset; **all 5 lighting presets**.
- **Budget:** the whole-board budget is a proposed starting guess, to tune on a real Quest: 150,000 triangles and 100 material slots (draw-call estimate) for the board's models; hands and VFX are extra. Constants live in `tools/render_diorama.py`.

## Steps
1. Make sure each asset to show is exported (`assets/export/<category>/*.glb`).
2. Add or update its entry in the layout file's `placements`:
   `{"label": "...", "asset": "assets/export/<category>/<name>.glb", "cell": [col, row], "footprint": [w, h], "rot": 0}`
   Cells are 0-11 from the board's front-left corner (column = right, row = away from the player). Keep footprints on whole cells and inside the board. When an asset gets a new version, point the entry at the new .glb.
3. Render: `python tools/render_diorama.py` (or `python tools/render_diorama.py assets/diorama/layout_<name>.json`).
   - Output: `assets/previews/diorama/<layout name>/diorama.png` (rows = presets; columns = player view, top-down, close-ups) plus every single render and `stats.json`.
   - Faster check: `EW_PRESETS=day python tools/render_diorama.py ...`
4. Look at it yourself:
   - scale between assets (2 x 2 buildings the same footprint, heights sensible);
   - can each tower be told apart from the player's seat and from above;
   - colours that clash or vanish in a preset (night especially);
   - anything over budget (the header turns red and says OVER).
5. Optionally run the art-critic agent on `diorama.png` for consistency across assets.
6. Send `diorama.png` to Siddharth with the triangle/draw-call totals and anything you noticed. Glowing balls and flame clusters are preview stand-ins for VFX, say so.

## Notes
- The board in these shots is a plain review stage (grass slab with a cell grid), not the island asset.
- Stand-ins come from `tools/ew_render.py` (`__orb_anchor` -> glowing ball, `__fire_anchor` -> flame cluster); effect sizes travel in the anchor's `ew_size` glTF extra.
- Renders are Blender EEVEE as a guide; the game's final look comes from Godot.
