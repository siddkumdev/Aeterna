"""Variant sheet for the island underside (W02). System Python (needs Pillow).

    python tools/make_underside_sheet.py OUT.png A=assets/blend/island_underside_A.blend B=...

Columns = variants; rows = side view (day), from below (day), side view at night (glow stand-ins).
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

import ew_env  # noqa: E402
BLENDER = ew_env.require("BLENDER_EXE")
HERE = os.path.dirname(os.path.abspath(__file__))
ROOM_GREY = (128, 126, 122)
W, H = 520, 380
ROWS = ["side", "close", "below", "night"]


def font(size):
    for n in ("segoeuib.ttf", "arialbd.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(n, size)
        except OSError:
            pass
    return ImageFont.load_default()


def main(out, pairs):
    variants = [p.split("=", 1) for p in pairs]
    sheet = Image.new("RGB", (W * len(variants), H * len(ROWS) + 50), "white")
    dr = ImageDraw.Draw(sheet)
    for i, (label, blend) in enumerate(variants):
        tmp = tempfile.mkdtemp(prefix="ew_under_")
        r = subprocess.run([BLENDER, "--factory-startup", "-b", os.path.abspath(blend), "-P",
                            os.path.join(HERE, "render_underside_inner.py"), "--", tmp], capture_output=True, text=True)
        if r.returncode != 0:
            sys.exit("blender failed on %s:\n%s%s" % (blend, r.stdout[-1500:], r.stderr[-1500:]))
        for j, row in enumerate(ROWS):
            im = Image.open(os.path.join(tmp, row + ".png")).convert("RGBA")
            bg = Image.new("RGBA", im.size, ROOM_GREY + (255,))
            bg.alpha_composite(im)
            sheet.paste(bg.convert("RGB"), (i * W, 50 + j * H))
        dr.text((i * W + 10, 8), label, fill=(20, 20, 20), font=font(30))
    for j, row in enumerate(ROWS):
        dr.text((4, 50 + j * H + 4), row, fill=(255, 255, 255), font=font(14))
    sheet.save(out)
    print(out)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2:])
