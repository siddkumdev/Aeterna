"""Palette B: a SECOND palette atlas (colours 65 and up), added 2026-11-02 because palette A is full at 64 (8 x 8 cells).

    python tools/palette_b.py add <file.json>   append colours: {"name": "RRGGBB", ...}   (never reorders or deletes)
    python tools/palette_b.py atlas             rebuild art/palette_atlas_b.png from art/palette.json "materials_b"
    python tools/palette_b.py preview           write art/palette_b_preview.png (swatch sheet with names)
    python tools/palette_b.py list

Why a second atlas and not a bigger one: every built model has UVs that point into the 8 x 8 grid of palette A, so enlarging A would
repaint all of them. Models that need B colours use the shared material ew_palette_b (same layout, 8 x 8 cells of 16 px, own image
ew_palette_atlas_b); a model may use ew_palette and ew_palette_b together (2 materials, within the validator's 1-2).
Rules: colour rules from the art bible still apply (no blue = Foresight; purple only as Warden colours, named warden_*).
"""
import json
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAL = os.path.join(ROOT, "art", "palette.json")
ATLAS_B = os.path.join(ROOT, "art", "palette_atlas_b.png")
PREVIEW_B = os.path.join(ROOT, "art", "palette_b_preview.png")
COLS, CELL, MAX = 8, 16, 64  # must match tools/blender_common.py


def load():
    with open(PAL, encoding="utf-8") as f:
        return json.load(f)


def save(pal):
    with open(PAL, "w", encoding="utf-8", newline="\n") as f:
        json.dump(pal, f, indent=2)
        f.write("\n")


def make_atlas(pal):
    img = Image.new("RGB", (COLS * CELL, COLS * CELL), (0, 0, 0))
    for i, hx in enumerate(pal.get("materials_b", {}).values()):
        x, y = (i % COLS) * CELL, (i // COLS) * CELL
        img.paste(tuple(int(hx.lstrip("#")[k:k + 2], 16) for k in (0, 2, 4)), (x, y, x + CELL, y + CELL))
    img.save(ATLAS_B)
    print("wrote", ATLAS_B)


def preview(pal):
    mats = pal.get("materials_b", {})
    cols = 6
    rows = (len(mats) + cols - 1) // cols
    W, H = 210, 70
    img = Image.new("RGB", (cols * W + 20, rows * H + 60), (250, 248, 242))
    d = ImageDraw.Draw(img)
    try:
        f1, f2 = ImageFont.truetype("arial.ttf", 18), ImageFont.truetype("arial.ttf", 13)
    except OSError:
        f1 = f2 = ImageFont.load_default()
    d.text((10, 10), "PALETTE B (second atlas): %d of %d colours used" % (len(mats), MAX), fill=(20, 20, 20), font=f1)
    for i, (n, hx) in enumerate(mats.items()):
        x, y = 10 + (i % cols) * W, 46 + (i // cols) * H
        d.rectangle((x, y, x + 60, y + 52), fill="#" + hx.lstrip("#"), outline=(120, 120, 120))
        d.text((x + 66, y + 6), n, fill=(30, 30, 30), font=f2)
        d.text((x + 66, y + 26), hx.upper(), fill=(110, 110, 110), font=f2)
    img.save(PREVIEW_B)
    print("wrote", PREVIEW_B)


def add(path):
    pal = load()
    new = json.load(open(path, encoding="utf-8"))
    mats = pal.setdefault("materials_b", {})
    existing = set(pal["materials"]) | set(mats)
    errs = []
    for n, hx in new.items():
        if not re.fullmatch(r"[a-z][a-z0-9_]*", n):
            errs.append("bad name " + n)
        if not re.fullmatch(r"[0-9A-Fa-f]{6}", hx.lstrip("#")):
            errs.append("bad hex for %s: %s" % (n, hx))
        if n in existing:
            errs.append("duplicate name " + n)
    if len(mats) + len(new) > MAX:
        errs.append("palette B full: %d + %d > %d" % (len(mats), len(new), MAX))
    if errs:
        sys.exit("\n".join(errs))
    for n, hx in new.items():
        mats[n] = hx.lstrip("#").upper()
    save(pal)
    make_atlas(pal)
    preview(pal)
    print("added %d colours; palette B now %d / %d" % (len(new), len(mats), MAX))


if __name__ == "__main__":
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__)
    if a[0] == "add" and len(a) > 1:
        add(a[1])
    elif a[0] == "atlas":
        make_atlas(load())
    elif a[0] == "preview":
        preview(load())
    elif a[0] == "list":
        for i, (n, hx) in enumerate(load().get("materials_b", {}).items()):
            print(64 + i, n, hx)
    else:
        sys.exit(__doc__)
