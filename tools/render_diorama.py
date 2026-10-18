"""Diorama shot: real assets placed on the 12 x 12 board, rendered in every lighting preset from the
player's seat, top-down, and close to each asset, with the board's triangle total vs a budget.
System Python (needs Pillow).

    python tools/render_diorama.py [LAYOUT.json] [OUT_DIR]

Defaults: assets/diorama/layout_mock.json -> assets/previews/diorama/<layout name>/.
Writes the individual renders, stats.json and diorama.png (one row per preset).
Set EW_PRESETS=day,night to render fewer presets.
"""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

import ew_env  # noqa: E402  (local.env paths)
BLENDER = ew_env.require("BLENDER_EXE")
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ROOM_GREY = (128, 126, 122)

# Whole-board budget: a STARTING GUESS (2026-10-17), to tune on a real Quest. Covers the board's
# static and moving models (towers, houses, trees, props, enemies, villagers); hands and VFX extra.
BUDGET_TRIS = 150_000
BUDGET_SLOTS = 100  # material slots ~ draw calls before Godot batches anything


def font(size, bold=False):
    for n in (("segoeuib.ttf", "arialbd.ttf") if bold else ("segoeui.ttf", "arial.ttf")):
        try:
            return ImageFont.truetype(n, size)
        except OSError:
            pass
    return ImageFont.load_default()


def tile(path, size):
    im = Image.open(path).convert("RGBA")
    bg = Image.new("RGBA", im.size, ROOM_GREY + (255,))
    bg.alpha_composite(im)
    im = bg.convert("RGB")
    im.thumbnail(size)
    return im


def main(layout, out):
    layout, out = os.path.abspath(layout), os.path.abspath(out)
    os.makedirs(out, exist_ok=True)
    r = subprocess.run([BLENDER, "--factory-startup", "-b", "-P", os.path.join(HERE, "render_diorama_inner.py"),
                        "--", layout, out], capture_output=True, text=True)
    if r.returncode != 0 or not os.path.exists(os.path.join(out, "stats.json")):
        sys.exit("blender failed:\n" + r.stdout[-2500:] + r.stderr[-1500:])
    missing = [l for l in r.stdout.splitlines() if l.startswith("MISSING")]
    st = json.load(open(os.path.join(out, "stats.json")))
    lay = json.load(open(layout, encoding="utf-8"))
    pal = json.load(open(os.environ.get("EW_PALETTE_JSON") or os.path.join(ROOT, "art", "palette.json"), encoding="utf-8"))
    only = [p for p in os.environ.get("EW_PRESETS", "").split(",") if p]
    presets = [k for k in pal["lighting"] if not k.startswith("_") and (not only or k in only)]
    n_close = len(st["assets"])

    PW, PH, TS, CS = 480, 320, 320, 240
    cols_w = PW + TS + CS * n_close
    head = 96
    sheet = Image.new("RGB", (cols_w, head + PH * len(presets)), "white")
    dr = ImageDraw.Draw(sheet)
    mock = "MOCK layout (not a gameplay decision)" if "mock" in os.path.basename(layout).lower() or "MOCK" in lay.get("_status", "") else os.path.basename(layout)
    over_t = st["tris"] > BUDGET_TRIS
    over_s = st["material_slots"] > BUDGET_SLOTS
    if os.environ.get("EW_PALETTE_JSON"):
        mock += "   |   PROPOSED PALETTE (not applied)"
    dr.text((10, 6), "Diorama shot - %s" % mock, fill=(20, 20, 20), font=font(22, True))
    dr.text((10, 38), "Board triangles: %s / %s budget%s     material slots (draw-call estimate): %d / %d%s     mesh objects: %d"
            % (f"{st['tris']:,}", f"{BUDGET_TRIS:,}", "  OVER" if over_t else "", st["material_slots"], BUDGET_SLOTS,
               "  OVER" if over_s else "", st["mesh_objects"]), fill=(180, 0, 0) if (over_t or over_s) else (40, 40, 40), font=font(15))
    dr.text((10, 62), "Real assets: " + ", ".join("%s (%s tris)" % (a["label"], f"{a['tris']:,}") for a in st["assets"])
            + ("   |   glowing balls/flames = VFX stand-ins" if st["vfx_standins"] else "")
            + ("   |   missing: " + ", ".join(m.split(" ", 1)[1] for m in missing) if missing else ""),
            fill=(70, 70, 70), font=font(13))
    for row, preset in enumerate(presets):
        y = head + row * PH
        x = 0
        sheet.paste(tile(os.path.join(out, "player_%s.png" % preset), (PW, PH)), (x, y)); x += PW
        sheet.paste(tile(os.path.join(out, "top_%s.png" % preset), (TS, PH)), (x, y)); x += TS
        for i in range(n_close):
            sheet.paste(tile(os.path.join(out, "close_%d_%s.png" % (i, preset)), (CS, PH)), (x, y + (PH - CS) // 2)); x += CS
        dr.text((6, y + 4), preset, fill=(255, 255, 255), font=font(15, True))
    dr.text((PW + 6, head + 4), "top-down", fill=(255, 255, 255), font=font(13))
    for i, a in enumerate(st["assets"]):
        dr.text((PW + TS + i * CS + 6, head + (PH - CS) // 2 + 4), a["label"], fill=(255, 255, 255), font=font(13))
    path = os.path.join(out, "diorama.png")
    sheet.save(path)
    print(path)
    print("tris %d / %d, slots %d / %d, engine %s" % (st["tris"], BUDGET_TRIS, st["material_slots"], BUDGET_SLOTS, st["engine"]))


if __name__ == "__main__":
    lay = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets", "diorama", "layout_mock.json")
    name = os.path.splitext(os.path.basename(lay))[0]
    main(lay, sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "assets", "previews", "diorama", name))
