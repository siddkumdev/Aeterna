---
name: endless-watch-art-style
description: Style rules for every Endless Watch 3D asset. Load before modelling, texturing, or reviewing any asset so shapes, palette and budgets stay consistent.
---

# Endless Watch art style

Authoritative sources, in order: `art/art_bible.md` (locked, Siddharth-approved; may not exist yet) > `art/decisions.md` > this file (draft) > the moodboard (`art/moodboard/board_*/BOARD.md`).

## Draft style (pending approval via the benchmark trio)
- Chunky faceted low-poly with soft rounded bevels (`bevel_width_m`/`segments` in `art/palette.json`). Flat shading, no smooth normals.
- Cone/blob trees (#30), tapered banded towers with tiers (#7, #8), steep terracotta/orange/teal roofs (#3, #4, #5), cream walls.
- Warm golden rim light against deep teal/navy shadows; lanterns as warm accents (#21).
- Enemy DESIGN follows #24, #25, #27 (+ #29 proportions): faceted low-poly (decided); jewel accents were CUT on 2026-10-17, types read by shape, size and movement. Enemy TYPES come from #10, #13, #14, #15, #36, #42 as roster ideas only; redraw them in the faceted style, never copy their ink-line or chibi rendering.
- Flyers (#43 airships, #42 dark creatures): distinct silhouette from ground enemies, readable from below and above.
- VFX: hard-edged flat shapes with glow (#31, #33, #44, #46, #47); rings/shockwaves must read from above.
- Flatter detail tier: aim for #1, #3, #30, #24-27. Use #2/#4/#5 only for composition/mood, never detail level.

## Hard rules
- Colours only from `art/palette.json` (add a named colour there first, with Siddharth's OK).
- Triangle budgets and naming per `CLAUDE.md`. No skinned rigs. No procedural materials.
- Original geometry only. Never reproduce a specific tower, character or logo from the board; take shape language only.
- Diorama is about 0.6 m across; keep reachable content below eye level and large enough for hand interaction.
