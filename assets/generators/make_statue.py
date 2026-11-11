"""The statue of the small god, replacing the shrine (the user, 2026-11-11: "rebuild the shrine, i kinda hate it, it should just be a statue,
not a whole place"; "the little god: hooded, cupped hands holding the ember, plinth, but it should be bigger than a thumb").
A carved stone figure in a hooded robe, both hands cupped in front holding a small bowl of ember (a dark socket: the flame is Godot's), on a plinth.
Footprint 2 x 2 cells (0.1 m) like the shrine so the island layout does not change; the figure is about 0.11 m tall on a 0.02 m plinth (a thumb is ~0.02 m wide).
Origin at the base centre, front faces -Y. Parts: root = the statue; __cracks = thin dark cracks (Godot shows more each loop; hidden at loop 1).
Anchors (same names the game already uses for the shrine): __candle_anchor (the ember in the hands), __offering_anchor (honeycakes on the plinth),
__sigil_anchor (the brow), __rewind_anchor (where the hourglass rises from, above the head).
Run: blender --factory-startup -b -P assets/generators/make_statue.py -- <A|B|C|D>           (a look-at variant file)
     blender --factory-startup -b -P assets/generators/make_statue.py -- FINAL <A|B|C|D> v01 (blend + glb)
  A  the standing pilgrim: straight hooded robe, hands cupped at the chest, round plinth with moss
  B  the seated god: cross-legged on a low stepped plinth, hands cupped in the lap, wide and cosy
  C  the lantern bearer: a longer flared robe with drooping sleeves, a small gold sun-disc behind the hood
  D  the steps: a taller carved pedestal with three steps and a small bowl for honeycakes, the little god on top
Colours from the palette atlas only; glow is Godot's job (dark sockets, no glowing geometry).
"""
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "tools"))
sys.path.insert(0, HERE)
import blender_common as bc  # noqa: E402

STONE, STONE_D, MOSS, FLOWER = "stone", "stone_dark", "leaf_green", "flower_yellow"
ROBE, ROBE_D, TRIM, SKIN = "cloth_mustard", "cloth_maroon", "shell_gold", "skin_light"
PI = math.pi


def moss_and_flowers():
    out = []
    for (x, y, r) in ((-0.040, -0.038, 0.0060), (0.041, -0.035, 0.0050), (-0.039, 0.037, 0.0056), (0.040, 0.038, 0.0048)):
        out.append(bc.blob("moss", r, (x, y, 0.0150), MOSS, 0, (1.3, 1.3, 0.55)))
    for (x, y) in ((-0.042, -0.031), (0.043, -0.040), (0.032, 0.043)):
        out.append(bc.blob("flower", 0.0024, (x, y, 0.0185), FLOWER, 0, (1, 1, 1)))
    return out


def figure(z0, scale=1.0, seated=False, long_robe=False, sleeves=False):
    """The little god standing (or sitting) with its base at z0. Returns (parts, ember_z, brow_z, head_top)."""
    s = scale
    P = []
    if seated:  # a folded-legs mound with the robe spread round it
        P.append(bc.cone("robe", 0.034 * s, 0.020 * s, 0.032 * s, (0, 0, z0 + 0.016 * s), ROBE, 14))
        P.append(bc.cone("hem", 0.036 * s, 0.036 * s, 0.004 * s, (0, 0, z0 + 0.002 * s), TRIM, 14))
        body_top = z0 + 0.034 * s
        P.append(bc.cone("torso", 0.020 * s, 0.015 * s, 0.026 * s, (0, 0, body_top + 0.010 * s), ROBE, 12))
        body_top += 0.026 * s
    else:
        h = 0.060 * s if not long_robe else 0.072 * s
        r0 = 0.026 * s if not long_robe else 0.034 * s
        P.append(bc.cone("robe", r0, 0.014 * s, h, (0, 0, z0 + h / 2), ROBE, 14))
        P.append(bc.cone("hem", r0 * 1.04, r0 * 1.04, 0.004 * s, (0, 0, z0 + 0.002 * s), TRIM, 14))
        P.append(bc.cone("belt", 0.0175 * s, 0.0175 * s, 0.003 * s, (0, 0, z0 + h * 0.62), TRIM, 12))
        body_top = z0 + h
    # the hood: a rounded cowl with a peak, the face a dark opening (two tiny stone eyes, no glow)
    hz = body_top + 0.012 * s
    P.append(bc.blob("cowl", 0.0165 * s, (0, 0, hz), ROBE_D, 2, (1.0, 0.95, 1.15)))
    P.append(bc.cone("peak", 0.011 * s, 0.0008 * s, 0.014 * s, (0, 0.004 * s, hz + 0.018 * s), ROBE_D, 8))
    P.append(bc.blob("face", 0.0105 * s, (0, -0.0128 * s, hz - 0.001 * s), "ink", 1, (0.95, 0.60, 1.1)))
    P.append(bc.box("brow", (0.014 * s, 0.002 * s, 0.002 * s), (0, -0.0140 * s, hz + 0.0065 * s), TRIM))
    P.append(bc.blob("shoulders", 0.016 * s, (0, 0, body_top - 0.003 * s), ROBE_D, 1, (1.5, 0.8, 0.5)))
    # two cupped hands: forearms come forward from the shoulders, the palms meet under a small ember bowl
    ez = (z0 + 0.034 * s) if seated else body_top - 0.016 * s
    for sx in (-1, 1):
        P.append(bc.blob("sleeve", 0.0075 * s, (sx * 0.0150 * s, -0.0080 * s, ez + 0.002 * s), ROBE_D, 1, (0.9, 1.4, 0.9)))
        P.append(bc.blob("hand", 0.0062 * s, (sx * 0.0048 * s, -0.0190 * s, ez + 0.0005 * s), SKIN, 1, (1.0, 1.1, 0.7)))
        if sleeves:  # long sleeves drooping from the forearms
            P.append(bc.cone("drape", 0.0070 * s, 0.0040 * s, 0.020 * s, (sx * 0.0200 * s, -0.0050 * s, ez - 0.010 * s), ROBE_D, 6))
    P.append(bc.cone("bowl", 0.0090 * s, 0.0050 * s, 0.0050 * s, (0, -0.0190 * s, ez + 0.0050 * s), STONE_D, 10))
    P.append(bc.cone("bowlsocket", 0.0060 * s, 0.0060 * s, 0.0016 * s, (0, -0.0190 * s, ez + 0.0078 * s), "ink", 10))
    return P, ez + 0.0090 * s, hz + 0.0065 * s, hz + 0.032 * s


def cracks(top):
    out = []
    for (x, y, h, rot) in ((-0.022, -0.036, 0.016, 12.0), (0.030, -0.026, 0.012, -20.0), (0.004, -0.040, 0.010, 6.0)):
        out.append(bc.box("crack", (0.0012, 0.0010, h), (x, y, top), "ink", rot))
    return out


def variant_a():
    body = [bc.cone("plinth", 0.046, 0.040, 0.014, (0, 0, 0.007), STONE, 16), bc.cone("plinth_top", 0.036, 0.034, 0.006, (0, 0, 0.017), STONE_D, 16)]
    body += moss_and_flowers()
    fig, ez, bz, top = figure(0.020, 1.0)
    return body + fig, ez, bz, top, 0.0200, 0.010


def variant_b():
    body = [bc.cone("step1", 0.048, 0.044, 0.010, (0, 0, 0.005), STONE, 16), bc.cone("step2", 0.040, 0.036, 0.008, (0, 0, 0.014), STONE_D, 16),
            bc.cone("cushion", 0.034, 0.030, 0.006, (0, 0, 0.021), ROBE_D, 14)]
    body += moss_and_flowers()
    fig, ez, bz, top = figure(0.024, 1.25, seated=True)
    return body + fig, ez, bz, top, 0.0245, 0.010


def variant_c():
    body = [bc.cone("plinth", 0.044, 0.038, 0.016, (0, 0, 0.008), STONE, 6), bc.cone("plinth_top", 0.034, 0.032, 0.005, (0, 0, 0.0185), STONE_D, 6)]
    body += moss_and_flowers()
    fig, ez, bz, top = figure(0.021, 1.0, long_robe=True, sleeves=True)
    # a small gold sun-disc behind the hood, on a thin stone stalk
    z = top - 0.012
    fig += [bc.cone("stalk", 0.0022, 0.0022, 0.026, (0, 0.016, top - 0.026), STONE_D, 6),
            place_disc("sun", 0.021, (0, 0.019, z), TRIM), place_disc("sunrim", 0.026, (0, 0.0205, z), ROBE_D)]
    for k in range(10):
        a = 2 * PI * k / 10
        fig.append(bc.box("ray", (0.0030, 0.0020, 0.0070), (math.cos(a) * 0.0280, 0.0180, z + math.sin(a) * 0.0280), TRIM, 0.0))
    return body + fig, ez, bz, top + 0.014, 0.0210, 0.010


def place_disc(name, r, loc, col):
    return bc.blob(name, r, loc, col, 1, (1.0, 0.14, 1.0))  # a flat disc facing -Y


def variant_d():
    body = [bc.cone("base", 0.048, 0.044, 0.008, (0, 0, 0.004), STONE, 12), bc.cone("step2", 0.040, 0.036, 0.008, (0, 0, 0.012), STONE_D, 12),
            bc.cone("step3", 0.032, 0.029, 0.008, (0, 0, 0.020), STONE, 12), bc.cone("column", 0.019, 0.016, 0.022, (0, 0, 0.035), STONE, 8),
            bc.cone("cap", 0.023, 0.023, 0.004, (0, 0, 0.048), STONE_D, 8)]
    for k in range(4):  # a ring of carved sun-ticks on the column
        a = PI / 4 + k * PI / 2
        body.append(bc.box("tick", (0.0030, 0.0030, 0.010), (math.cos(a) * 0.0175, math.sin(a) * 0.0175, 0.036), TRIM, math.degrees(a)))
    body += moss_and_flowers()
    fig, ez, bz, top = figure(0.050, 0.85)
    return body + fig, ez, bz, top, 0.0500, 0.012


def variant_m():
    """The pick (the user, 2026-11-11: "A+C"): A's round mossy plinth and straight pilgrim, C's long robe, drooping sleeves and gold sun-disc."""
    body = [bc.cone("plinth", 0.046, 0.040, 0.014, (0, 0, 0.007), STONE, 16), bc.cone("plinth_top", 0.036, 0.034, 0.006, (0, 0, 0.017), STONE_D, 16)]
    body += moss_and_flowers()
    fig, ez, bz, top = figure(0.020, 1.0, long_robe=True, sleeves=True)
    z = top - 0.012
    fig += [bc.cone("stalk", 0.0022, 0.0022, 0.026, (0, 0.016, top - 0.026), STONE_D, 6),
            place_disc("sun", 0.021, (0, 0.019, z), TRIM), place_disc("sunrim", 0.026, (0, 0.0205, z), ROBE_D)]
    for k in range(10):
        a = 2 * PI * k / 10
        fig.append(bc.box("ray", (0.0030, 0.0020, 0.0070), (math.cos(a) * 0.0280, 0.0180, z + math.sin(a) * 0.0280), TRIM, 0.0))
    return body + fig, ez, bz, top + 0.014, 0.0200, 0.010


VARIANTS = {"M": variant_m, "A": variant_a, "B": variant_b, "C": variant_c, "D": variant_d}


def tris(objs):
    return sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)


def build(variant, ver="v01"):
    bc.clear_scene()
    name = "ew_village_statue_%s" % ver
    parts, ember_z, brow_z, top, crack_z, _ = VARIANTS[variant]()
    root = bc.assemble(name, [("", parts, (0, 0, 0), None), ("cracks", cracks(crack_z + 0.004), (0, 0, 0), "", False)])
    bc.anchor(root, "candle_anchor", (0, -0.019, ember_z), size=0.008)
    bc.anchor(root, "offering_anchor", (0, -0.036, 0.0200), size=0.012)
    bc.anchor(root, "sigil_anchor", (0, -0.0145, brow_z), size=0.008)
    bc.anchor(root, "rewind_anchor", (0, 0, top + 0.030), size=0.02)
    root["ew_place"] = "center"
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    zs = [(o.matrix_world @ v.co).z for o in objs for v in o.data.vertices]
    print("%s %s: %d tris, height %.0f mm" % (name, variant, tris(objs), (max(zs) - min(zs)) * 1000))
    return root


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if args and args[0] == "FINAL":
        obj = build(args[1], args[2])
        bc.save_blend(obj, "statue")
        print("EXPORT", bc.export_glb(obj, "village"))
    else:
        k = (args[0] if args else "A").upper()
        obj = build(k, "v01")
        bc.save_blend(obj, "statue_" + k)
