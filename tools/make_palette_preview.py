"""Render a swatch sheet of art/palette.json for review.

Usage: python tools/make_palette_preview.py [out.png]
Default output: art/palette_preview.png.
tools/palette_change.py calls main(out, palette_path, marks) to draw a proposal: marks = {name: ("new"|"changed"|"retired", old_hex)}.
Proposed changes are outlined in red with a tag; a changed colour shows its old hex as an inset. Needs Pillow (system Python, not Blender).
The lighting row is a rough 2D approximation (base colour x light colour), not a render.
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CORE_COUNT = 19  # first 19 materials are the approved core palette

SW, SH, GAP, PAD = 96, 48, 10, 24


def font(size):
    for name in ("segoeui.ttf", "arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def rgb(hx):
    hx = hx.lstrip("#")
    return tuple(int(hx[i:i + 2], 16) for i in (0, 2, 4))


def mul(a, b, k=1.0):
    return tuple(min(255, int(x * y / 255 * k)) for x, y in zip(a, b))


def main(out, palette_path=None, marks=None):
    pal = json.load(open(palette_path or os.path.join(ROOT, "art", "palette.json"), encoding="utf-8"))
    mats = list(pal["materials"].items())
    f_h, f_l, f_s = font(18), font(13), font(11)
    marks = dict(marks or {})
    for k in pal.get("retired", []):
        marks.setdefault(k, ("retired", None))

    sections = []  # (title, [(hex, label)], note)
    if marks:
        title = ("PROPOSED CHANGES (red outline; not applied until Siddharth says OK)" if palette_path
                 else "Retired colours (kept in the atlas so nothing shifts; do not use)")
        sections.append((title,
                         [(pal["materials"][k], k) for k in marks]))
    sections.append(("Core materials", [(v, k) for k, v in mats[:CORE_COUNT]]))
    new = dict(mats[CORE_COUNT:])
    groups = [
        ("Paths (dirt or stone, Siddharth picks later)", ["path_dirt", "path_stone"]),
        ("Enemies: Wisp glow, Fog variant", ["wisp_glow", "fog"]),
        ("Player hand tones (cuff stays roof_teal)", ["wall_cream", "hand_brown", "hand_dark_brown"]),
        ("Villager skin and hair", ["skin_light", "skin_mid", "skin_dark", "hair_dark", "hair_brown", "hair_blonde"]),
        ("Effects, placement ghost, rarity", ["fire_red", "fire_yellow", "heal_green", "ghost_valid", "ghost_invalid", "rarity_gold"]),
    ]
    used = set()
    for title, keys in groups:
        sections.append((title, [(new[k], k) for k in keys if k in new]))
        used.update(keys)
    rest = [(v, k) for k, v in new.items() if k not in used]
    if rest:
        sections.append(("Other new materials", rest))
    for name, strip in pal["time_of_day"].items():
        tag = "derived" if name.endswith("_derived") else "from the board"
        sections.append(("Time of day: %s (%s)" % (name, tag), [(h, h) for h in strip]))

    per_row = 12
    height = PAD
    for _, sw in sections:
        rows = (len(sw) + per_row - 1) // per_row
        height += 28 + rows * (SH + 34)
    height += 40 + 170 + 40 + 130 + PAD
    width = PAD * 2 + per_row * (SW + GAP)
    img = Image.new("RGB", (width, height), (250, 248, 242))
    dr = ImageDraw.Draw(img)

    y = PAD
    for title, sw in sections:
        dr.text((PAD, y), title, fill=(30, 30, 30), font=f_h)
        y += 28
        for i, (hx, label) in enumerate(sw):
            x = PAD + (i % per_row) * (SW + GAP)
            yy = y + (i // per_row) * (SH + 34)
            dr.rectangle([x, yy, x + SW, yy + SH], fill=rgb(hx), outline=(200, 200, 200))
            tag = ""
            if label in marks:
                kind, old = marks[label]
                if kind == "changed" and old:
                    dr.rectangle([x + 4, yy + 4, x + 30, yy + SH - 4], fill=rgb(old), outline=(255, 255, 255))
                if kind == "retired":
                    dr.line([(x, yy), (x + SW, yy + SH)], fill=(90, 90, 90), width=3)
                dr.rectangle([x - 2, yy - 2, x + SW + 2, yy + SH + 2], outline=(200, 0, 0) if kind != "retired" else (90, 90, 90), width=3)
                tag = {"new": " NEW", "changed": " was " + (old or ""), "retired": " RETIRED"}[kind]
            dr.text((x, yy + SH + 3), hx + tag, fill=(180, 0, 0) if tag and "RETIRED" not in tag else (60, 60, 60), font=f_s)
            if label != hx:
                dr.text((x, yy + SH + 17), label, fill=(110, 110, 110), font=f_s)
        y += ((len(sw) + per_row - 1) // per_row) * (SH + 34)

    # Lighting presets: a cream wall with a terracotta roof, lit side x key*energy, shadow side x ambient.
    dr.text((PAD, y), "Lighting presets (rough 2D approximation; board only)", fill=(30, 30, 30), font=f_h)
    y += 32
    wall, roof, grass = rgb(pal["materials"]["wall_cream"]), rgb(pal["materials"]["roof_terracotta"]), rgb(pal["materials"]["grass"])
    x = PAD
    for name, L in pal["lighting"].items():
        if name.startswith("_"):
            continue
        k, a, r, e = rgb(L["key"]), rgb(L["ambient"]), rgb(L["rim"]), L["energy"]
        lit = lambda c: tuple(min(255, int(s + t)) for s, t in zip(mul(c, k, e * 1.15), mul(c, a, 0.35)))
        shade = lambda c: mul(c, a, 0.9)
        dr.rectangle([x, y, x + 150, y + 130], fill=mul((40, 40, 40), a, 2.0))
        dr.rectangle([x + 10, y + 95, x + 140, y + 125], fill=lit(grass))
        dr.polygon([(x + 30, y + 55), (x + 75, y + 70), (x + 75, y + 110), (x + 30, y + 95)], fill=lit(wall))
        dr.polygon([(x + 75, y + 70), (x + 120, y + 55), (x + 120, y + 95), (x + 75, y + 110)], fill=shade(wall))
        dr.polygon([(x + 25, y + 57), (x + 60, y + 20), (x + 78, y + 72)], fill=lit(roof))
        dr.polygon([(x + 60, y + 20), (x + 105, y + 15), (x + 125, y + 57), (x + 78, y + 72)], fill=shade(roof))
        dr.line([(x + 60, y + 20), (x + 78, y + 72)], fill=r, width=2)
        dr.text((x, y + 136), "%s  (energy %.2f)" % (name, e), fill=(60, 60, 60), font=f_l)
        x += 170
    y += 170

    # Hand tone options: a simple glove shape in each tone with the teal cuff.
    dr.text((PAD, y), "Hand tone options (toy-glove hands, teal cuff)", fill=(30, 30, 30), font=f_h)
    y += 32
    cuff = rgb(pal["materials"]["roof_teal"])
    x = PAD
    for label, key in (("white cream", "wall_cream"), ("brown cream", "hand_brown"), ("dark brown cream", "hand_dark_brown")):
        c = rgb(pal["materials"][key])
        dr.rectangle([x, y, x + 150, y + 100], fill=(70, 74, 80))
        dr.rounded_rectangle([x + 45, y + 30, x + 105, y + 75], radius=12, fill=c)
        for i in range(4):
            dr.rounded_rectangle([x + 47 + i * 15, y + 8, x + 58 + i * 15, y + 36], radius=5, fill=c)
        dr.rounded_rectangle([x + 28, y + 42, x + 50, y + 56], radius=6, fill=c)
        dr.rectangle([x + 50, y + 75, x + 100, y + 92], fill=cuff)
        dr.text((x, y + 104), label, fill=(60, 60, 60), font=f_l)
        x += 170
    img.save(out)
    print("wrote", out)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "art", "palette_preview.png"))
