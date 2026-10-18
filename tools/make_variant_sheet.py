"""Render design variants side by side so Siddharth can pick and mix. System Python (needs Pillow).

    python tools/make_variant_sheet.py OUT.png A=assets/blend/x_A.blend B=assets/blend/x_B.blend ...

Each variant is rendered in the day and golden_hour lighting presets (same camera), on a grey
stand-in for the room. Labels are the letters to reply with ("B, but with C's roof").
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

import ew_env  # noqa: E402  (local.env paths)
BLENDER = ew_env.require("BLENDER_EXE")
HERE = os.path.dirname(os.path.abspath(__file__))
PRESETS = ["day", "golden_hour"]
ROOM_GREY = (128, 126, 122)
T = 300


def font(size):
    for n in ("segoeuib.ttf", "arialbd.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(n, size)
        except OSError:
            pass
    return ImageFont.load_default()


def render(blend, out):
    env = dict(os.environ, EW_PRESETS=",".join(PRESETS))
    r = subprocess.run([BLENDER, "--factory-startup", "-b", os.path.abspath(blend), "-P",
                        os.path.join(HERE, "render_lighting_inner.py"), "--", out], capture_output=True, text=True, env=env)
    if r.returncode != 0:
        sys.exit("blender failed on %s:\n%s%s" % (blend, r.stdout[-1500:], r.stderr[-1500:]))


def main(out, pairs):
    variants = [p.split("=", 1) for p in pairs]
    sheet = Image.new("RGB", (T * len(variants), T * len(PRESETS) + 50), "white")
    dr = ImageDraw.Draw(sheet)
    for i, (label, blend) in enumerate(variants):
        tmp = tempfile.mkdtemp(prefix="ew_var_")
        render(blend, tmp)
        for j, preset in enumerate(PRESETS):
            im = Image.open(os.path.join(tmp, "light_%s.png" % preset)).convert("RGBA")
            bg = Image.new("RGBA", im.size, ROOM_GREY + (255,))
            bg.alpha_composite(im)
            sheet.paste(bg.convert("RGB").resize((T, T)), (i * T, 50 + j * T))
        dr.text((i * T + 10, 8), label, fill=(20, 20, 20), font=font(30))
    for j, preset in enumerate(PRESETS):
        dr.text((4, 50 + j * T + 4), preset, fill=(255, 255, 255), font=font(14))
    sheet.save(out)
    print(out)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2:])
