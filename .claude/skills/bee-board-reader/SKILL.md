---
name: bee-board-reader
description: Convert a BeeRef .bee moodboard into a readable report, labelled overview image, per-section contact sheets, and colour palettes. Use when a .bee file is shared or the user asks to read, review, or extract a moodboard.
---

# bee-board-reader

A BeeRef `.bee` file is a SQLite database. This skill turns it into files both Claude and the user can read: a Markdown report, a whole-board overview image with every image labelled by id, one contact sheet per section, every original image, and a machine-readable index.

## When to use
- The user shares a `.bee` file or asks to look at, review, summarise or extract a moodboard.
- Another task needs the board's references, palettes, or the user's notes (art bible, asset plan).

## Procedure
1. Treat the file as untrusted: copy the `.bee` into its own new, empty directory. The script lives in this skill's `scripts/` folder, a different directory. Run Python with `-I` and pass paths as arguments.
2. Check Pillow (`python3 -c "import PIL"`); `pip install --break-system-packages pillow` if missing.
3. Run: `python3 -I scripts/bee2md.py path/to/board.bee out_dir`
4. Read `out_dir/BOARD.md`, then view `out_dir/overview.jpg`, then the relevant `out_dir/sections/*.jpg`. Never describe an image you have not viewed.
5. Verify grouping. Auto-grouping assumes each text note is a caption BELOW its images. If an image sits under the wrong section, write `groups.json` like `{"towers": [7, 8]}` and rerun with it as the third argument. Say which groupings you corrected.
6. Report: sections with image ids, the user's text notes quoted verbatim (their stated intent), blank/duplicate images, links, dominant colours per section, and anything ambiguous. Keep the user's ids (#12) so they can refer to images.

## Platform notes
- Windows works (patched: URI-safe read-only open, UTF-8 output). Use `python -I` (or `py -I`) instead of `python3`.
- This board: notes are captions BELOW images. Known manual fixes: #8 belongs with towers (#7), #43 (airships) is a flyer reference. See `art/moodboard/groups.json`.

## Output files
- `BOARD.md` report; `overview.jpg` whole board with ids; `sections/NN_<title>.jpg` contact sheets; `images/img_<id>.<ext>` originals; `index.json` positions, crops, palettes, sections.

## Format notes
- Tables `items` (id, type pixmap|text, x, y, z, scale, rotation, flip, data JSON) and `sqlar` (item_id, name, sz, data). If `sz` differs from blob length, the blob is zlib-compressed; otherwise stored raw.
- Displayed size = pixel size x `scale`; `data.crop` is `[x, y, w, h]` in image pixels.
- Fully transparent images look black in naive previews; the script flags them as blank.

## Limits
- Grouping is a spatial heuristic (27 of 29 correct on the board it was built from). Always verify.
- Palettes are quantised guesses, not exact brand values.
- Board references are for style direction only; do not copy third-party IP into shipped work.
