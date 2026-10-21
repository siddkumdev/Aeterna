"""Trees and forest clumps (W05, W06, W22). Original geometry; shape language from board #30 and #23.

Variant round:  blender --factory-startup -b -P assets/generators/make_trees.py -- <A|B|C|D>
  builds pine, round, cube tree and a forest clump of that style side by side and saves assets/blend/trees_<V>.blend.
Footprint rule: a single tree fits 1 x 1 cell (0.05 m); a clump is about 2 x 1 cells.
"""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import blender_common as bc  # noqa: E402


def sharp(o):
    o["sharp"] = True
    return o


def trunk(s, h, r=0.0065, col="wood_dark", ox=0.0, oy=0.0):
    return bc.cone("trunk", r * s, r * 0.8 * s, h * s, (ox, oy, h * s / 2), col, 6)


# ------------------------------------------------------------------ A: faceted stacked (benchmark language, rescaled)
def pine_A(s=1.0, ox=0.0, oy=0.0, dark=False):
    c1, c2 = ("leaf_dark", "leaf_green") if dark else ("leaf_green", "leaf_light")
    p = [trunk(s, 0.020, ox=ox, oy=oy)]
    for r, h, z, c in ((0.026, 0.036, 0.014, c1), (0.020, 0.034, 0.040, c2), (0.014, 0.034, 0.064, c1)):
        p.append(sharp(bc.cone("tier", r * s, 0.0, h * s, (ox, oy, (z + h / 2) * s), c, 7)))
    return p


def round_A(s=1.0, ox=0.0, oy=0.0, dark=False):
    c1, c2 = ("leaf_dark", "leaf_green") if dark else ("leaf_green", "leaf_light")
    return [trunk(s, 0.030, ox=ox, oy=oy),
            bc.blob("crown", 0.027 * s, (ox, oy, 0.057 * s), c1, 1, (1, 1, 0.92)),
            bc.blob("accent", 0.015 * s, (ox + 0.013 * s, oy, 0.072 * s), c2, 1, (1, 1, 0.9))]


def cube_A(s=1.0, ox=0.0, oy=0.0, dark=False):
    c1, c2 = ("leaf_dark", "leaf_green") if dark else ("leaf_green", "leaf_light")
    return [trunk(s, 0.030, ox=ox, oy=oy),
            bc.box("crown", (0.040 * s, 0.040 * s, 0.036 * s), (ox, oy, 0.046 * s), c1, 12),
            bc.box("accent", (0.020 * s, 0.020 * s, 0.008 * s), (ox + 0.012 * s, oy - 0.010 * s, 0.066 * s), c2, 12)]


# ------------------------------------------------------------------ B: soft stacked blobs (#30 green stacks and ovals)
def pine_B(s=1.0, ox=0.0, oy=0.0, dark=False):
    c1, c2 = ("leaf_dark", "leaf_green") if dark else ("leaf_green", "leaf_light")
    p = [trunk(s, 0.016, ox=ox, oy=oy)]
    for r, z, c in ((0.026, 0.026, c1), (0.020, 0.046, c2), (0.014, 0.064, c1)):
        p.append(bc.blob("tier", r * s, (ox, oy, z * s), c, 1, (1, 1, 0.62)))
    p.append(bc.cone("tip", 0.008 * s, 0.0, 0.016 * s, (ox, oy, 0.082 * s), c2, 6))
    return p


def round_B(s=1.0, ox=0.0, oy=0.0, dark=False):
    c1, c2 = ("leaf_dark", "leaf_green") if dark else ("leaf_green", "leaf_light")
    return [trunk(s, 0.026, ox=ox, oy=oy),
            bc.blob("crown", 0.020 * s, (ox, oy, 0.063 * s), c1, 1, (1, 1, 1.55)),
            bc.blob("side", 0.012 * s, (ox + 0.013 * s, oy, 0.046 * s), c2, 1, (1, 1, 1.2))]


def cube_B(s=1.0, ox=0.0, oy=0.0, dark=False):
    c1, c2 = ("leaf_dark", "leaf_green") if dark else ("leaf_green", "leaf_light")
    return [trunk(s, 0.020, ox=ox, oy=oy),
            bc.cone("stack", 0.024 * s, 0.024 * s, 0.026 * s, (ox, oy, 0.033 * s), c1, 8),
            bc.cone("stack", 0.018 * s, 0.018 * s, 0.024 * s, (ox, oy, 0.058 * s), c2, 8),
            bc.cone("stack", 0.012 * s, 0.012 * s, 0.020 * s, (ox, oy, 0.080 * s), c1, 8)]


# ------------------------------------------------------------------ C: layered slabs / shingles (#23 tall pines)
def pine_C(s=1.0, ox=0.0, oy=0.0, dark=False):
    cols = ("leaf_dark", "leaf_green", "leaf_light") if not dark else ("leaf_dark", "leaf_dark", "leaf_green")
    p = [trunk(s, 0.030, r=0.0085, col="wood_mid", ox=ox, oy=oy)]
    for k, (r, z) in enumerate(((0.028, 0.018), (0.024, 0.036), (0.020, 0.054), (0.016, 0.072), (0.011, 0.090))):
        p.append(bc.cone("tier", r * s, r * 0.35 * s, 0.024 * s, (ox, oy, (z + 0.012) * s), cols[k % 3], 6, 30 * (k % 2)))
    p.append(bc.cone("tip", 0.007 * s, 0.0, 0.014 * s, (ox, oy, 0.110 * s), cols[2], 6))
    return p


def round_C(s=1.0, ox=0.0, oy=0.0, dark=False):
    c1, c2 = ("leaf_dark", "leaf_green") if dark else ("leaf_green", "leaf_light")
    return [trunk(s, 0.024, ox=ox, oy=oy),
            bc.blob("crown", 0.026 * s, (ox, oy, 0.050 * s), c1, 1, (1, 1, 0.5)),
            bc.blob("crown", 0.020 * s, (ox + 0.004 * s, oy, 0.066 * s), c2, 1, (1, 1, 0.5)),
            bc.blob("crown", 0.013 * s, (ox, oy + 0.004 * s, 0.078 * s), c1, 1, (1, 1, 0.55))]


def cube_C(s=1.0, ox=0.0, oy=0.0, dark=False):
    c1, c2 = ("leaf_dark", "leaf_green") if dark else ("leaf_green", "leaf_light")
    return [trunk(s, 0.024, ox=ox, oy=oy),
            bc.box("slab", (0.040 * s, 0.040 * s, 0.014 * s), (ox, oy, 0.033 * s), c1, 0),
            bc.box("slab", (0.032 * s, 0.032 * s, 0.014 * s), (ox, oy, 0.047 * s), c2, 22),
            bc.box("slab", (0.024 * s, 0.024 * s, 0.014 * s), (ox, oy, 0.061 * s), c1, 44),
            bc.box("slab", (0.014 * s, 0.014 * s, 0.012 * s), (ox, oy, 0.074 * s), c2, 66)]


# ------------------------------------------------------------------ D: bold toy (fat trunks, few big shapes)
def pine_D(s=1.0, ox=0.0, oy=0.0, dark=False):
    c1, c2 = ("leaf_dark", "leaf_green") if dark else ("leaf_green", "leaf_light")
    return [trunk(s, 0.020, r=0.0095, ox=ox, oy=oy),
            sharp(bc.cone("tier", 0.027 * s, 0.0, 0.050 * s, (ox, oy, 0.040 * s), c1, 8)),
            sharp(bc.cone("tier", 0.019 * s, 0.0, 0.046 * s, (ox, oy, 0.067 * s), c2, 8))]


def round_D(s=1.0, ox=0.0, oy=0.0, dark=False):
    c1, c2 = ("leaf_dark", "leaf_green") if dark else ("leaf_green", "leaf_light")
    return [trunk(s, 0.026, r=0.0095, ox=ox, oy=oy),
            bc.blob("crown", 0.027 * s, (ox, oy, 0.056 * s), c1, 2, (1, 1, 0.9)),
            bc.blob("accent", 0.014 * s, (ox + 0.014 * s, oy, 0.070 * s), c2, 1)]


def cube_D(s=1.0, ox=0.0, oy=0.0, dark=False):
    c1, c2 = ("leaf_dark", "leaf_green") if dark else ("leaf_green", "leaf_light")
    return [trunk(s, 0.026, r=0.0095, ox=ox, oy=oy),
            bc.box("crown", (0.044 * s, 0.044 * s, 0.040 * s), (ox, oy, 0.046 * s), c1, 0),
            bc.box("tuft", (0.022 * s, 0.022 * s, 0.008 * s), (ox + 0.012 * s, oy - 0.010 * s, 0.068 * s), c2, 0)]


STYLES = {"A": (pine_A, round_A, cube_A), "B": (pine_B, round_B, cube_B),
          "C": (pine_C, round_C, cube_C), "D": (pine_D, round_D, cube_D)}


def clump(style):
    """Forest-ring clump, about 2 x 1 cells: 3 pines (one tall), a round tree and two low bushes."""
    pine, rnd, cube = STYLES[style]
    p = []
    p += pine(1.25, -0.030, 0.004)
    p += pine(1.00, 0.002, -0.008, dark=True)
    p += pine(1.10, 0.030, 0.006)
    p += rnd(0.80, -0.012, 0.014, dark=True)
    p.append(bc.blob("bush", 0.010, (0.017, -0.012, 0.007), "leaf_dark", 1, (1, 1, 0.7)))
    p.append(bc.blob("bush", 0.008, (-0.040, -0.011, 0.006), "leaf_green", 1, (1, 1, 0.7)))
    return p


TALL = 1.35  # vertical stretch: trees must stand a little above the 2.4-2.8 cell houses (forest ring)


def finish(parts, name):
    """Small bevel (1.6 mm; the 4 mm house bevel would blob a 5 cm tree). Pointed tips (top radius 0) stay sharp."""
    for p in parts:
        zs = [v.co for v in p.data.vertices]
        if not (p.name.startswith("tip") or p.get("sharp")):
            bc.bevel(p, 0.0016, 1)
    obj = bc.join(parts, name)
    obj.name = obj.data.name = name
    obj.scale.z = TALL
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.select_all(action="DESELECT")
    for pl in obj.data.polygons:
        pl.use_smooth = False
    bc.origin_to_base(obj)
    return obj


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def build_set(style):
    bc.clear_scene()
    pine, rnd, cube = STYLES[style]
    items = [("pine", pine(), 0.0), ("round", rnd(), 0.075), ("cube", cube(), 0.15), ("clump", clump(style), 0.26)]
    for short, parts, x in items:
        obj = finish(parts, "ew_world_tree_%s_%s" % (short, style))
        obj.location.x = x
        h = max(v.co.z for v in obj.data.vertices)
        print("%s %s: %d tris, %.1f cells tall" % (style, short, tris(obj), h / 0.05))
    bc.save_blend(obj, "trees_" + style)


# ------------------------------------------------------------------ FINAL: the pine family (Siddharth 2026-10-21: A and C, every tree a pine)
def pine_layered(s=1.0, ox=0.0, oy=0.0, dark=False, tiers=4, slim=1.0):
    """C-style layered pine (shingle tiers, alternating dark/mid/light). tiers 4 = layered, 5 = tall."""
    cols = ("leaf_dark", "leaf_green", "leaf_light") if not dark else ("leaf_dark", "leaf_dark", "leaf_green")
    spec = ((0.028, 0.018), (0.024, 0.036), (0.020, 0.054), (0.016, 0.072), (0.011, 0.090))
    if tiers == 4:
        spec = ((0.028, 0.016), (0.023, 0.034), (0.018, 0.052), (0.013, 0.070))
    p = [trunk(s, 0.030 if tiers == 5 else 0.024, r=0.0085, col="wood_mid", ox=ox, oy=oy)]
    for k, (r, z) in enumerate(spec):
        p.append(bc.cone("tier", r * slim * s, r * 0.35 * slim * s, 0.024 * s, (ox, oy, (z + 0.012) * s), cols[k % 3], 6, 30 * (k % 2)))
    ztop = spec[-1][1] + 0.024
    p.append(bc.cone("tip", 0.007 * s, 0.0, 0.014 * s, (ox, oy, (ztop + 0.002) * s), cols[2], 6))
    return p


def pine_young(s=1.0, ox=0.0, oy=0.0, dark=False):
    """Sapling: two light tiers on a thin trunk."""
    p = [trunk(s, 0.014, r=0.0050, ox=ox, oy=oy)]
    for r, h, z, c in ((0.022, 0.030, 0.010, "leaf_light"), (0.015, 0.028, 0.030, "leaf_green")):
        p.append(sharp(bc.cone("tier", r * s, 0.0, h * s, (ox, oy, (z + h / 2) * s), c, 7)))
    return p


def pine_corrupted(s=1.0, ox=0.0, oy=0.0, dark=True):
    """Twisted dead-looking pine: leaning, slightly rotated tiers in one dark family (leaf_dark with warm wood_dark dead tiers)."""
    p = [bc.cone("trunk", 0.0100 * s, 0.0070 * s, 0.050 * s, (ox, oy, 0.025 * s), "wood_dark", 6)]
    for k, (r, h, z, c, dx, rot) in enumerate(((0.028, 0.034, 0.016, "leaf_dark", 0.000, 0), (0.023, 0.032, 0.036, "wood_dark", 0.004, 22),
                                                (0.018, 0.030, 0.056, "leaf_dark", 0.009, 40), (0.012, 0.026, 0.074, "wood_dark", 0.015, 60))):
        p.append(sharp(bc.cone("tier", r * s, 0.0, h * s, (ox + dx * s, oy, (z + h / 2) * s), c, 5, rot)))
    return p


def clump_mix():
    p = pine_A(1.25, -0.030, 0.004) + pine_layered(1.0, 0.002, -0.006, tiers=4) + pine_A(1.05, 0.030, 0.006)
    p += pine_young(0.8, -0.012, 0.016) + [bc.blob("bush", 0.013, (0.014, -0.014, 0.008), "leaf_green", 1, (1, 1, 0.75))]
    p += [bc.blob("bush", 0.011, (-0.038, -0.012, 0.007), "leaf_dark", 1, (1, 1, 0.75))]
    return p


def clump_dark():
    """Dark spawn-side clump: leaf_dark tones concentrate here (art bible forest ring)."""
    p = pine_layered(1.25, -0.028, 0.004, dark=True, tiers=5, slim=0.82) + pine_A(1.1, 0.004, -0.007, dark=True)
    p += pine_layered(1.0, 0.030, 0.006, dark=True, tiers=4) + pine_corrupted(0.85, -0.008, 0.016)
    p += [bc.blob("bush", 0.012, (0.016, -0.014, 0.007), "leaf_dark", 1, (1, 1, 0.75))]
    return p


def clump_low():
    """Sparse edge clump: young pines and bushes, lets the ring thin out."""
    p = pine_young(1.2, -0.028, 0.002) + pine_A(0.9, 0.003, -0.006) + pine_young(1.0, 0.030, 0.008)
    p += [bc.blob("bush", 0.013, (-0.012, -0.014, 0.008), "leaf_green", 1, (1, 1, 0.75)),
          bc.blob("bush", 0.011, (0.020, -0.014, 0.007), "leaf_dark", 1, (1, 1, 0.75))]
    return p


FINAL = {  # short name: (version, parts builder, footprint, placement hint)
    "pine": ("v02", lambda: pine_A(), "1x1", "scatter"),
    "pine_young": ("v01", lambda: pine_young(), "1x1", "scatter"),
    "pine_layered": ("v01", lambda: pine_layered(tiers=4), "1x1", "forest_edge"),
    "pine_tall": ("v01", lambda: pine_layered(tiers=5, slim=0.82), "1x1", "forest_edge"),
    "pine_corrupted": ("v01", lambda: pine_corrupted(), "1x1", "forest_edge"),
    "forest_clump_mix": ("v01", clump_mix, "2x1", "forest_ring"),
    "forest_clump_dark": ("v01", clump_dark, "2x1", "forest_ring"),
    "forest_clump_low": ("v01", clump_low, "2x1", "forest_ring"),
}


def build_final(short):
    ver, builder, foot, hint = FINAL[short]
    bc.clear_scene()
    cat = "tree" if short.startswith("pine") else ""
    name = "ew_world_%s_%s" % (("tree_" + short) if cat else short, ver)
    obj = finish(builder(), name)
    obj["ew_footprint"], obj["ew_front"], obj["ew_place"] = foot, "-Y", hint
    h = max(v.co.z for v in obj.data.vertices)
    w = max(abs(v.co.x) for v in obj.data.vertices) * 2
    print("%s: %d tris, %.1f cells tall, %.1f cells wide" % (name, tris(obj), h / 0.05, w / 0.05))
    bc.save_blend(obj, "tree_" + short if cat else short)
    print("EXPORT", bc.export_glb(obj, "world"))


def build_family_set():
    """Preview row of every final piece (singles then clumps)."""
    bc.clear_scene()
    x = 0.0
    for short, (ver, builder, foot, hint) in FINAL.items():
        obj = finish(builder(), "ew_world_%s_%s" % (short, ver))
        wide = foot == "2x1"
        obj.location.x = x + (0.05 if wide else 0.0)
        x += 0.14 if wide else 0.075
    bc.save_blend(obj, "trees_family")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if args and args[0] == "FINAL":
        build_final(args[1])
    elif args and args[0] == "FAMILY":
        build_family_set()
    else:
        build_set(args[0] if args else "A")
