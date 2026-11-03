"""Greyscale readability check (Dorfromantik lesson: "readability through value, then add atmosphere through hue").

    python tools/greyscale_check.py image  <render.png> [<render2.png> ...]   side-by-side colour | grey, plus value statistics
    python tools/greyscale_check.py palette [--b] [--all] [--close 5]          neighbour pairs that look alike in grey (--all: every colour and close pair)

Image mode writes <name>_grey.png next to each input (colour on the left, greyscale on the right) and prints the spread of
lightness (L*, 0 black to 100 white). A flat picture (narrow spread) means shapes will merge once colour is ignored.
Palette mode checks the NEIGHBOURS list (colours that touch in the scene) against a minimum lightness gap; --all also lists every colour and
every pair closer than --close. Two colours alike in grey must not be the only thing separating two neighbouring things.
Needs Pillow. Reads art/palette.json. Changes nothing else.
"""
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PALETTE = os.path.join(HERE, "..", "art", "palette.json")
# Colours that touch in the diorama and must stay apart in value (edit as the game grows). Min L* gap 12.
NEIGHBOURS = [
    ("roof_terracotta", "grass"), ("roof_orange", "grass"), ("roof_teal", "grass"), ("roof_terracotta", "leaf_green"),
    ("wall_cream", "path_dirt"), ("wall_cream", "path_stone"), ("wall_cream", "grass"), ("stone", "grass"), ("stone", "path_dirt"),
    ("stone_dark", "leaf_dark"), ("ink", "leaf_dark"), ("bone", "grass"), ("bone", "path_dirt"), ("wood_dark", "leaf_dark"),
    ("wood_light", "grass"), ("water", "grass"), ("fog", "grass"), ("fire_red", "grass"), ("lantern_glow", "wall_cream"),
]
MIN_GAP = 12.0


def _lin(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lightness(rgb):
    """CIE L* of an sRGB colour (0..100)."""
    y = 0.2126 * _lin(rgb[0]) + 0.7152 * _lin(rgb[1]) + 0.0722 * _lin(rgb[2])
    return 116.0 * (y ** (1 / 3)) - 16.0 if y > 0.008856 else 903.3 * y


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def image_mode(paths):
    for path in paths:
        im = Image.open(path).convert("RGB")
        pix = list(im.get_flattened_data()) if hasattr(im, "get_flattened_data") else list(im.getdata())
        ls = sorted(lightness(p) for p in pix[:: max(1, len(pix) // 40000)])  # a sample is plenty
        n = len(ls)
        lo, mid, hi = ls[int(n * 0.05)], ls[n // 2], ls[int(n * 0.95)]
        third = [sum(1 for v in ls if v < 33.3) / n, sum(1 for v in ls if 33.3 <= v < 66.6) / n, sum(1 for v in ls if v >= 66.6) / n]
        grey = Image.new("RGB", im.size)
        grey.putdata([(int(lightness(p) * 2.55),) * 3 for p in pix])
        out = Image.new("RGB", (im.width * 2, im.height))
        out.paste(im, (0, 0))
        out.paste(grey, (im.width, 0))
        dest = os.path.splitext(path)[0] + "_grey.png"
        out.save(dest)
        spread = hi - lo
        verdict = "OK" if spread >= 40 else ("FLAT: shapes may merge without colour" if spread < 25 else "so-so")
        print("%s\n  L* 5%%=%.0f median=%.0f 95%%=%.0f  spread=%.0f  dark/mid/light=%.0f%%/%.0f%%/%.0f%%  -> %s\n  wrote %s"
              % (path, lo, mid, hi, spread, third[0] * 100, third[1] * 100, third[2] * 100, verdict, dest))


def palette_mode(use_b, close, show_all):
    data = json.load(open(PALETTE))
    mats = data["materials_b" if use_b else "materials"]
    rows = sorted(((lightness(hex_rgb(h)), n, h) for n, h in mats.items()), key=lambda r: r[0])
    if show_all:
        for l, n, h in rows:
            print("%5.1f  %-18s %s %s" % (l, n, h, "#" * int(l / 4)))
    print("Neighbour pairs (things that touch in the diorama), minimum gap %.0f L*:" % MIN_GAP)
    bad = 0
    for a, b in NEIGHBOURS:
        if a in mats and b in mats:
            gap = abs(lightness(hex_rgb(mats[a])) - lightness(hex_rgb(mats[b])))
            bad += gap < MIN_GAP
            print("  %-16s vs %-16s gap %5.1f  %s" % (a, b, gap, "ok" if gap >= MIN_GAP else "TOO ALIKE IN GREY"))
    print("%d neighbour pair(s) too alike." % bad)
    if not show_all:
        print("(--all also lists every colour and every pair closer than --close; it is long.)")
        return
    print("\nPairs closer than %.1f L* (alike in greyscale):" % close)
    found = 0
    for i in range(len(rows)):
        for j in range(i + 1, len(rows)):
            if rows[j][0] - rows[i][0] >= close:
                break
            print("  %.1f apart: %s (%s) and %s (%s)" % (rows[j][0] - rows[i][0], rows[i][1], rows[i][2], rows[j][1], rows[j][2]))
            found += 1
    print("%d pair(s). Only a problem when the two touch in a scene and nothing else (shape, outline, light) separates them." % found)


def main(argv):
    if len(argv) >= 2 and argv[0] == "image":
        image_mode(argv[1:])
    elif argv and argv[0] == "palette":
        close = float(argv[argv.index("--close") + 1]) if "--close" in argv else 5.0
        palette_mode("--b" in argv, close, "--all" in argv)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
