"""Render a .blend headless and assemble a contact sheet. Runs in system Python (needs Pillow).

    python tools/make_sheet.py assets/blend/house.blend assets/previews/house

Writes OUT_DIR/*.png (individual views) and OUT_DIR/sheet.png (labelled contact sheet).
Blender location: BLENDER_EXE in local.env (see tools/ew_env.py).
"""
import os
import subprocess
import sys

from PIL import Image, ImageDraw

import ew_env  # noqa: E402  (local.env paths)
BLENDER = ew_env.require("BLENDER_EXE")
HERE = os.path.dirname(os.path.abspath(__file__))
VIEWS = ["front", "side", "top", "three_quarter", "wire", "silhouette"]


def main(blend, out):
    out, blend = os.path.abspath(out), os.path.abspath(blend)
    os.makedirs(out, exist_ok=True)
    r = subprocess.run([BLENDER, "--factory-startup", "-b", blend, "-P", os.path.join(HERE, "render_preview.py"), "--", out],
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit("blender failed:\n" + r.stdout[-2000:] + r.stderr[-2000:])
    tiles = []
    for v in VIEWS:
        im = Image.open(os.path.join(out, v + ".png")).convert("RGB").resize((384, 384))
        ImageDraw.Draw(im).text((8, 6), v, fill=(200, 0, 0))
        tiles.append(im)
    sheet = Image.new("RGB", (384 * 3, 384 * 2), "white")
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % 3) * 384, (i // 3) * 384))
    sheet.save(os.path.join(out, "sheet.png"))
    print(os.path.join(out, "sheet.png"))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
