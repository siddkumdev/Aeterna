"""The god's shrine (docs/STORY.md): the heart of the island, where Maren prays every dawn and the hourglass rises.
Cozy, small and weathered, never grim: a stone plinth, four little pillars, a carved wooden gable roof with a gold
sun on the front, a candle niche in the back wall, an offering bowl on a pedestal (honeycakes go here), a little moss
and a few flowers. Footprint 2 x 2 cells (0.1 m), about 0.11 m tall. Origin at the base centre. The front faces -Y.
Parts: root = the shrine; __cracks = thin dark cracks (Godot shows more of them each loop: hidden at loop 1).
Anchors: __candle_anchor (the flame), __offering_anchor (honeycakes), __sigil_anchor (the sun on the gable),
__rewind_anchor (where the hourglass rises from, above the roof).
Colours from the palette atlas only; glow is Godot's job (dark sockets, no glowing geometry).
Run: blender --factory-startup -b -P assets/generators/make_shrine.py -- <A|B>      (a look-at variant file)
     blender --factory-startup -b -P assets/generators/make_shrine.py -- FINAL <A|B> v01   (blend + glb)
Variant A: gabled roof (the default). Variant B: the same with a round gold sun-disc crown instead of the front sun.
"""
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "tools"))
sys.path.insert(0, HERE)
import blender_common as bc  # noqa: E402
import make_village_props as vp  # noqa: E402  (cyl, tbox, tcyl, nb)

STONE, STONE_D, WOOD_D, WOOD_M, WOOD_L = "stone", "stone_dark", "wood_dark", "wood_mid", "wood_light"
ROOF, GOLD, SUN, WAX, DARK = "roof_orange", "shell_gold", "fire_yellow", "wall_cream", "ink"
MOSS, FLOWER = "leaf_green", "flower_pink"
P = 0.036  # pillar offset from the centre


def plinth():
    return [vp.tbox("plinth", (0.100, 0.100, 0.008), (0, 0, 0.004), STONE_D),
            vp.tbox("step", (0.088, 0.088, 0.006), (0, 0, 0.011), STONE),
            vp.tbox("front_step", (0.034, 0.010, 0.0045), (0, -0.0470, 0.00225 + 0.004), STONE)]


def pillars():
    out = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * P, sy * P
            out += [vp.tbox("base", (0.014, 0.014, 0.004), (x, y, 0.016), STONE_D),
                    vp.cyl("pillar", 0.0050, 0.040, (x, y, 0.018), STONE, 6),
                    vp.tbox("capital", (0.015, 0.015, 0.004), (x, y, 0.060), STONE_D)]
    return out


def back_wall():
    out = [vp.tbox("wall", (0.072, 0.007, 0.046), (0, P, 0.014 + 0.023), STONE_D),
           vp.tbox("niche", (0.019, 0.004, 0.026), (0, P - 0.0035, 0.030), DARK),     # the dark socket the candle stands in
           vp.tbox("niche_top", (0.024, 0.006, 0.004), (0, P - 0.0010, 0.0445), STONE),
           vp.tbox("candle", (0.0050, 0.0050, 0.012), (0, P - 0.0035, 0.0235), WAX)]  # wax
    out += [vp.tbox("wick", (0.0012, 0.0012, 0.0030), (0, P - 0.0035, 0.0310), DARK)]
    return out


def roof(variant):
    z = 0.0645
    out = [vp.tbox("beam", (0.088, 0.088, 0.004), (0, 0, z + 0.002), WOOD_D)]  # the tie beam on the capitals
    out.append(bc.gable("roof", 0.104, 0.098, 0.030, (0, 0, z + 0.004), ROOF))
    out.append(vp.tbox("ridge", (0.004, 0.102, 0.004), (0, 0, z + 0.0345), WOOD_D))
    for sy in (-1, 1):  # carved bargeboards: a thin dark board along each rake at the front and back
        out.append(vp.tbox("barge", (0.0035, 0.0035, 0.0345), (-0.026, sy * 0.0495, z + 0.0200), WOOD_M, 0, 59, 0))
        out.append(vp.tbox("barge", (0.0035, 0.0035, 0.0345), (0.026, sy * 0.0495, z + 0.0200), WOOD_M, 0, -59, 0))
    if variant == "B":
        out += [vp.nb(vp.tcyl("crown", 0.012, 0.004, (0, 0, z + 0.0405), GOLD, 12, 0, 0, 0)),
                vp.nb(vp.tcyl("crown_core", 0.006, 0.006, (0, 0, z + 0.0425), SUN, 8, 0, 0, 0))]
    return out


def sun():
    """The gold sun on the front gable (variant A): a disc, a core and 8 rays, facing -Y."""
    y = -0.0505
    z = 0.0645 + 0.0145
    out = [vp.nb(vp.tcyl("sun", 0.0062, 0.0025, (0, y, z), GOLD, 10, 90, 0, 0)),
           vp.nb(vp.tcyl("sun_core", 0.0034, 0.0034, (0, y - 0.0008, z), SUN, 8, 90, 0, 0))]
    for k in range(8):
        a = math.radians(45 * k)
        out.append(vp.tbox("sun_ray", (0.0016, 0.0022, 0.0042), (0.0085 * math.sin(a), y, z + 0.0085 * math.cos(a)), GOLD, 0, -45 * k, 0))
    return out


def offering():
    y = -0.018
    return [vp.cyl("pedestal", 0.0065, 0.012, (0, y, 0.014), STONE, 8),
            vp.cyl("bowl", 0.0125, 0.0050, (0, y, 0.026), WOOD_M, 10),
            vp.cyl("bowl_in", 0.0095, 0.0012, (0, y, 0.0306), DARK, 10)]


def garden():
    out = []
    for (x, y, r) in ((-0.043, -0.040, 0.0062), (0.044, -0.037, 0.0052), (-0.041, 0.040, 0.0058), (0.042, 0.041, 0.0050)):
        out.append(vp.nb(bc.blob("moss", r, (x, y, 0.0150), MOSS, 0, (1.3, 1.3, 0.55))))
    for (x, y) in ((-0.045, -0.034), (0.046, -0.043), (0.034, 0.046)):
        out.append(vp.nb(bc.blob("flower", 0.0024, (x, y, 0.0185), FLOWER, 0, (1, 1, 1))))
    return out


def cracks():
    """Hairline cracks: a zig-zag on the front step and one up the front-left pillar. Godot shows them from loop 2."""
    out = [vp.tbox("crack", (0.0016, 0.0012, 0.012), (-0.010, -0.0516, 0.0120), DARK, 0, 0, 14),
           vp.tbox("crack", (0.0016, 0.0012, 0.010), (-0.004, -0.0516, 0.0070), DARK, 0, 0, -28),
           vp.tbox("crack", (0.0016, 0.0012, 0.009), (0.003, -0.0516, 0.0105), DARK, 0, 0, 22),
           vp.tbox("crack", (0.0014, 0.0014, 0.014), (-P - 0.0053, -P, 0.034), DARK, 0, 0, 0),
           vp.tbox("crack", (0.0014, 0.0014, 0.009), (-P - 0.0053, -P, 0.050), DARK, 0, 0, 0)]
    out[3].rotation_euler = (0, 0, 0)
    return [vp.nb(o) for o in out]


def tris(objs):
    return sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)


def build(variant, ver="v01"):
    bc.clear_scene()
    name = "ew_village_shrine_%s" % ver
    body = plinth() + pillars() + back_wall() + roof(variant) + offering() + garden() + (sun() if variant == "A" else [])
    root = bc.assemble(name, [("", body, (0, 0, 0), None), ("cracks", cracks(), (0, 0, 0), "", False)])
    bc.anchor(root, "candle_anchor", (0, P - 0.0035, 0.0335), size=0.008)
    bc.anchor(root, "offering_anchor", (0, -0.018, 0.0325), size=0.012)
    bc.anchor(root, "sigil_anchor", (0, -0.0515, 0.0790), size=0.012)
    bc.anchor(root, "rewind_anchor", (0, 0, 0.115), size=0.02)
    root["ew_place"] = "center"
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    zs = [(o.matrix_world @ v.co).z for o in objs for v in o.data.vertices]
    print("%s %s: %d tris, height %.0f mm" % (name, variant, tris(objs), (max(zs) - min(zs)) * 1000))
    return root


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if args and args[0] == "FINAL":
        obj = build(args[1], args[2])
        bc.save_blend(obj, "shrine")
        print("EXPORT", bc.export_glb(obj, "village"))
    else:
        obj = build(args[0] if args else "A")
        bc.save_blend(obj, "shrine_" + (args[0] if args else "A"))
