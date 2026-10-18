"""Render an asset under every lighting preset and assemble a labelled strip. System Python (needs Pillow).

    python tools/render_lighting.py assets/blend/fire_tower.blend assets/previews/fire_tower

Writes OUT_DIR/light_<preset>.png and OUT_DIR/lighting.png. Each render is composited onto a
neutral grey to stand in for a passthrough room. A guide only: the game's look comes from Godot.
"""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw

import ew_env  # noqa: E402  (local.env paths)
BLENDER = ew_env.require("BLENDER_EXE")
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ROOM_GREY = (128, 126, 122)


def main(blend, out):
    out, blend = os.path.abspath(out), os.path.abspath(blend)
    os.makedirs(out, exist_ok=True)
    r = subprocess.run([BLENDER, "--factory-startup", "-b", blend, "-P", os.path.join(HERE, "render_lighting_inner.py"), "--", out],
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit("blender failed:\n" + r.stdout[-2000:] + r.stderr[-2000:])
    engine = next((l.split()[1] for l in r.stdout.splitlines() if l.startswith("ENGINE")), "?")
    presets = [k for k in json.load(open(os.path.join(ROOT, "art", "palette.json"), encoding="utf-8"))["lighting"] if not k.startswith("_")]
    tiles = []
    for name in presets:
        im = Image.open(os.path.join(out, "light_%s.png" % name)).convert("RGBA")
        bg = Image.new("RGBA", im.size, ROOM_GREY + (255,))
        bg.alpha_composite(im)
        t = bg.convert("RGB").resize((320, 320))
        ImageDraw.Draw(t).text((8, 6), name, fill=(255, 255, 255))
        tiles.append(t)
    strip = Image.new("RGB", (320 * len(tiles), 340), "white")
    for i, t in enumerate(tiles):
        strip.paste(t, (i * 320, 0))
    ImageDraw.Draw(strip).text((8, 324), "engine: %s; grey background stands in for the room (passthrough)" % engine, fill=(60, 60, 60))
    strip.save(os.path.join(out, "lighting.png"))
    print(os.path.join(out, "lighting.png"), engine)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
