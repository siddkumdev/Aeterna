"""Cozy trees (2026-11-10 story overhaul): fuller, rounder, layered canopies in three palette greens, visible roots.
Original geometry; shape language from board #30 (stacked soft blobs) and the Clash/Dorfromantik cosiness the grass already has.

Run (one asset, or all):
  blender --factory-startup -b -P assets/generators/make_trees_cozy.py -- <oak_old|oak_round|birch|pine_full|forest_clump_mix|ALL|FAMILY>

Pieces (every canopy lump is a flat-shaded icosphere; colours come only from the palette atlas):
  ew_world_tree_oak_old_v01       the village's big old oak (the kite tree), 2 x 2 cells, about 3 cells tall
  ew_world_tree_oak_round_v01     small round tree, 1 x 1 cell
  ew_world_tree_birch_v01         two white stems with dark bark marks, 1 x 1 cell
  ew_world_tree_pine_v04          fuller layered pine (rounded shelves, a soft tip), replaces pine_v03 once approved
  ew_world_forest_clump_mix_v03   forest-ring clump, about 2 x 1 cells (budget 1200)
Budgets: single trees 800 tris, clump 1200 (validate_asset.py).
Trunks stay at the origin (x, y); the origin is at the base (min z = 0).
"""
import math
import os
import random
import sys

import bpy

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import blender_common as bc  # noqa: E402

CELL = 0.05


# ------------------------------------------------------------------ helpers
def place(obj, loc=(0.0, 0.0, 0.0), rot=(0.0, 0.0, 0.0), scale=1.0):
    """Rotate (degrees), scale about the origin, then move; bake all of it into the mesh."""
    obj.rotation_euler = [math.radians(d) for d in rot]
    obj.scale = (scale, scale, scale)
    obj.location = loc
    bc.apply_transforms(obj)
    return obj


def lump(r, loc, col, squash=(1.0, 1.0, 1.0), sub=2, rot=(0.0, 0.0, 0.0), name="leaf"):
    """A canopy lump: icosphere, subdivisions 2 = 80 tris, 1 = 20 tris."""
    o = bc.blob(name, r, (0, 0, 0), col, sub, squash)
    return place(o, loc, rot)


def tone(dark):
    """(under, mid, top) leaf colours; the dark clump pine shifts everything one step darker."""
    return ("leaf_dark", "leaf_dark", "leaf_green") if dark else ("leaf_dark", "leaf_green", "leaf_light")


def finish(parts, name):
    """Join, flat shade, put the lowest point at z = 0 and leave x, y alone (the trunk stays at the origin)."""
    obj = bc.join(parts, name)
    obj.name = obj.data.name = name
    for p in obj.data.polygons:
        p.use_smooth = False
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    zmin = min(v.co.z for v in obj.data.vertices)
    for v in obj.data.vertices:
        v.co.z -= zmin
    obj.location = (0, 0, 0)
    return obj


def roots(count, r_out, size, z, col="wood_mid", phase=0.0):
    """Flared roots: low squashed lumps lying outward from the trunk foot, partly buried (z about 0)."""
    out = []
    for k in range(count):
        a = phase + k * 360.0 / count
        o = bc.blob("root", size, (0, 0, 0), col, 1, (2.1, 0.7, 0.62))
        out.append(place(o, (r_out * math.cos(math.radians(a)), r_out * math.sin(math.radians(a)), z), (0, 0, a)))
    return out


# ------------------------------------------------------------------ the pieces (each returns parts, trunk at 0,0)
def oak_old():
    p = [bc.cone("trunk", 0.0095, 0.0060, 0.064, (0, 0, 0.032), "wood_mid", 8, 11)]
    p += roots(4, 0.0105, 0.0058, 0.0022, phase=20.0)
    p.append(place(bc.cone("branch", 0.0030, 0.0018, 0.034, (0, 0, 0), "wood_mid", 6), (0.009, 0.0, 0.078), (0, 36, 0)))
    p.append(place(bc.cone("branch", 0.0030, 0.0018, 0.032, (0, 0, 0), "wood_mid", 6), (-0.008, 0.003, 0.076), (0, -34, 0)))
    # canopy: three dark under-lumps, three green mid lumps turned 60 degrees, one light crown, three small light accents
    for k in range(3):
        a = math.radians(k * 120 + 15)
        p.append(lump(0.027, (0.029 * math.cos(a), 0.029 * math.sin(a), 0.084), "leaf_dark", (1, 1, 0.74), 2, (0, 0, k * 40)))
    for k in range(3):
        a = math.radians(k * 120 + 75)
        p.append(lump(0.026, (0.020 * math.cos(a), 0.020 * math.sin(a), 0.108), "leaf_green", (1, 1, 0.78), 2, (0, 0, 20 + k * 40)))
    p.append(lump(0.025, (0.0, 0.0, 0.132), "leaf_light", (1, 1, 0.8), 2, (0, 0, 10)))
    for a, rr, z in ((40, 0.036, 0.100), (170, 0.034, 0.118), (290, 0.030, 0.124)):
        p.append(lump(0.0085, (rr * math.cos(math.radians(a)), rr * math.sin(math.radians(a)), z), "leaf_light", (1, 1, 0.85), 1))
    return p


def oak_round(dark=False):
    under, mid, top = tone(dark)
    p = [bc.cone("trunk", 0.0050, 0.0034, 0.032, (0, 0, 0.016), "wood_mid", 6, 8)]
    p += roots(3, 0.0058, 0.0034, 0.0014, phase=35.0)
    p.append(lump(0.022, (0.0, 0.0, 0.046), under, (1, 1, 0.72), 2, (0, 0, 15)))
    p.append(lump(0.021, (0.006, -0.004, 0.062), mid, (1, 1, 0.78), 2, (0, 0, 35)))
    p.append(lump(0.016, (-0.004, 0.004, 0.077), top, (1, 1, 0.82), 2))
    for a, rr, z in ((60, 0.021, 0.052), (200, 0.019, 0.070)):
        p.append(lump(0.0065, (rr * math.cos(math.radians(a)), rr * math.sin(math.radians(a)), z), top, (1, 1, 0.85), 1))
    return p


def birch_stem(x, y, h, seed):
    """One white stem with dark bark marks standing on the ground at x, y."""
    rnd = random.Random(seed)
    out = []
    stem = bc.cone("stem", 0.0038, 0.0026, h, (0, 0, h / 2), "wall_cream", 6, 8)
    out.append(place(stem, (x, y, 0), (0, 0, 0)))
    for k in range(4):  # dark bark marks wrapped part way round, 1 mm proud of the stem
        z = h * (0.16 + 0.2 * k) + rnd.uniform(-0.003, 0.003)
        t = 0.0038 + (0.0026 - 0.0038) * (z / h)
        a = rnd.uniform(0, 360)
        mark = bc.box("mark", (0.0022, 0.0042, 0.0026), (0, 0, 0), "wood_dark")
        out.append(place(mark, (x + (t + 0.0003) * math.cos(math.radians(a)), y + (t + 0.0003) * math.sin(math.radians(a)), z), (0, 0, a)))
    return out


def birch(stems=2, dark=False):
    top = "leaf_green" if dark else "leaf_light"
    p = birch_stem(-0.004, 0.0, 0.078, 5)
    p.append(lump(0.0165, (-0.004, 0.0, 0.093), "leaf_green", (0.9, 0.9, 1.45), 2, (0, 0, 20)))
    p.append(lump(0.0115, (0.001, 0.005, 0.108), top, (0.9, 0.9, 1.4), 2, (0, 0, 40)))
    if stems >= 2:
        p += birch_stem(0.007, 0.003, 0.058, 9)
        p.append(lump(0.0135, (0.007, 0.003, 0.071), "leaf_yellow" if not dark else "leaf_green", (0.9, 0.9, 1.35), 1, (0, 0, 15)))
    return p


def pine_full(young=False, dark=False):
    """Fuller layered pine: wide flat rounded shelves (squashed icospheres) in under / mid / top tones, a soft tip."""
    under, mid, top = tone(dark)
    p = [bc.cone("trunk", 0.0075, 0.0045, 0.036, (0, 0, 0.018), "wood_mid", 6, 8)]
    if young:
        tiers = ((0.024, 0.026, under), (0.018, 0.043, mid), (0.012, 0.058, top))
        tip_z = 0.066
    else:
        tiers = ((0.031, 0.030, under), (0.026, 0.050, mid), (0.021, 0.069, top), (0.016, 0.086, mid), (0.011, 0.101, top))
        tip_z = 0.112
    for k, (r, z, c) in enumerate(tiers):
        p.append(lump(r, (0.0, 0.0, z), c, (1.0, 1.0, 0.58), 2, (0, 0, 22 * k), name="tier"))
    p.append(bc.cone("tip", 0.0055, 0.0, 0.016, (0, 0, tip_z + 0.006), top, 6))
    return p


def bush(r, loc, col):
    return lump(r, loc, col, (1.0, 1.0, 0.75), 1, name="bush")


def transform_group(parts, scale, ox, oy, rot_z=0.0):
    for o in parts:
        place(o, (ox, oy, 0.0), (0, 0, rot_z), scale)  # scaling about the tree's own origin (its foot)
    return parts


def clump_mix():
    """Forest-ring clump, about 2 x 1 cells: a full pine, a young pine, a one-stem birch and two bushes."""
    p = []
    p += transform_group(pine_full(), 1.12, -0.030, 0.004)
    p += transform_group(pine_full(young=True, dark=True), 1.0, 0.031, 0.006, 40)
    p += transform_group(birch(stems=1), 0.9, 0.013, -0.017)
    p.append(bush(0.012, (0.016, -0.012, 0.006), "leaf_green"))
    p.append(bush(0.010, (-0.046, -0.010, 0.005), "leaf_dark"))
    return p


# name, builder, footprint, placement hint, blend short name
FINAL = {
    "oak_old": ("ew_world_tree_oak_old_v01", oak_old, "2x2", "village_landmark", "tree_oak_old"),
    "oak_round": ("ew_world_tree_oak_round_v01", oak_round, "1x1", "scatter", "tree_oak_round"),
    "birch": ("ew_world_tree_birch_v01", birch, "1x1", "scatter", "tree_birch"),
    "pine_full": ("ew_world_tree_pine_v04", pine_full, "1x1", "scatter", "tree_pine_cozy"),
    "forest_clump_mix": ("ew_world_forest_clump_mix_v03", clump_mix, "2x1", "forest_ring", "forest_clump_mix_v03"),
}


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def stats(obj):
    vs = obj.data.vertices
    h = max(v.co.z for v in vs)
    w = max(v.co.x for v in vs) - min(v.co.x for v in vs)
    d = max(v.co.y for v in vs) - min(v.co.y for v in vs)
    return "%d tris, %.1f cells tall, %.1f x %.1f cells wide" % (tris(obj), h / CELL, w / CELL, d / CELL)


def build_final(short):
    name, builder, foot, hint, blend = FINAL[short]
    bc.clear_scene()
    obj = finish(builder(), name)
    obj["ew_footprint"], obj["ew_front"], obj["ew_place"] = foot, "-Y", hint
    print("%s: %s" % (name, stats(obj)))
    bc.save_blend(obj, blend)
    print("EXPORT", bc.export_glb(obj, "world"))


def build_family():
    """One row for the preview sheet: every piece side by side (not exported)."""
    bc.clear_scene()
    x = 0.0
    last = None
    for short, (name, builder, foot, hint, blend) in FINAL.items():
        obj = finish(builder(), name)
        wide = foot in ("2x1", "2x2")
        x += 0.07 if wide else 0.045
        obj.location.x = x
        x += 0.07 if wide else 0.045
        last = obj
    bc.save_blend(last, "trees_cozy_family")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["ALL"]
    if args[0] == "FAMILY":
        build_family()
    elif args[0] == "ALL":
        for s in FINAL:
            build_final(s)
        build_family()
    else:
        build_final(args[0])
