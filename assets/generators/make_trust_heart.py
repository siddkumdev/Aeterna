"""Trust heart (V17), second design round: a real heart outline lofted into a faceted gem (no blob lobes).
Original geometry. Run: blender --factory-startup -b -P assets/generators/make_trust_heart.py -- <A|B|C|D>
Final:                  ... -- FINAL <A-D> <vNN>
The heart faces -Y (front), stands upright, about 2 cm tall. The sparkle is VFX at __sparkle_anchor.
"""
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import blender_common as bc  # noqa: E402
import make_village_props as vp  # noqa: E402  (tcyl)


def outline(n, width, fat=1.0):
    """n points around a heart (classic parametric curve), centred on x = 0, bottom tip at z = 0, scaled to `width` wide."""
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x = 16 * math.sin(t) ** 3
        z = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x, z))
    minz = min(p[1] for p in pts)
    k = width / (max(p[0] for p in pts) - min(p[0] for p in pts))
    return [(x * k * fat, (z - minz) * k) for x, z in pts]


def loft(name, col, pts, rings, apex=None):
    """rings: list of (scale, y) from the back to the front; each ring is the outline scaled about the heart centre.
    The back is capped by a face; the front is a fan to `apex` (y) or a cap."""
    cx = 0.0
    cz = sum(p[1] for p in pts) / len(pts)
    bm = bmesh.new()
    layers = []
    for sc, y in rings:
        layers.append([bm.verts.new((cx + (x - cx) * sc, y, cz + (z - cz) * sc)) for x, z in pts])
    n = len(pts)
    for a, b in zip(layers, layers[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(list(reversed(layers[0])))
    if apex is None:
        bm.faces.new(layers[-1])
    else:
        c = bm.verts.new((cx, apex, cz))
        for i in range(n):
            bm.faces.new((layers[-1][i], layers[-1][(i + 1) % n], c))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = bc._new_obj(name, bm)
    bc.paint(obj, col)
    return obj


def lift(o, dz):
    for v in o.data.vertices:
        v.co.z += dz
    return o


def heart_A():
    """Gem heart: 12-point outline, flat back, front rises to a faceted point."""
    return [loft("heart", "fire_red", outline(12, 0.020), [(0.80, 0.0030), (1.0, 0.0006), (1.0, -0.0006)], apex=-0.0060)]


def heart_B():
    """Chunky low-poly heart: 10 points, thick, a flat front plate with chamfered edges."""
    return [loft("heart", "fire_red", outline(10, 0.021), [(0.80, 0.0038), (1.0, 0.0012), (1.0, -0.0012), (0.80, -0.0038)])]


def heart_C():
    """Soft heart: 16 points, three rings so the front bulges like a pillow, warm terracotta-red."""
    return [loft("heart", "roof_terracotta", outline(16, 0.020), [(0.72, 0.0034), (0.96, 0.0016), (1.0, 0.0), (0.92, -0.0020), (0.64, -0.0040)])]


def heart_D():
    """Slim tall heart: 12 points narrowed, flat face with a raised inner heart of the same colour (two steps)."""
    return [loft("heart", "fire_red", outline(12, 0.017, 1.0), [(0.84, 0.0030), (1.0, 0.0008), (1.0, -0.0008), (0.80, -0.0030)]),
            lift(loft("inner", "fire_red", outline(12, 0.017 * 0.55), [(0.84, -0.0028), (1.0, -0.0040), (0.80, -0.0058)]), 0.0042)]


BUILDERS = {"A": heart_A, "B": heart_B, "C": heart_C, "D": heart_D}


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def build(letter, ver="v01"):
    bc.clear_scene()
    name = "ew_village_trust_heart_%s" % ver
    obj = bc.finish(BUILDERS[letter](), name, do_bevel=False)
    vs = [v.co for v in obj.data.vertices]
    bc.anchor(obj, "sparkle_anchor", (0, 0, (min(c.z for c in vs) + max(c.z for c in vs)) / 2), size=0.026)
    obj["ew_footprint"], obj["ew_front"], obj["ew_place"] = "1x1", "-Y", "token"
    d = obj.dimensions
    print("%s %s: %d tris, %.1f x %.1f x %.1f mm" % (name, letter, tris(obj), d.x * 1000, d.y * 1000, d.z * 1000))
    return obj


def lift_all(parts, dz, dy=0.0):
    for o in parts:
        for v in o.data.vertices:
            v.co.z += dz
            v.co.y += dy
    return parts


def build_coin(ver="v01", heart_col="trust_blue"):
    """Trust coin (currency): gold coin, big chamfered heart (variant B shape) raised on the front. Heart colour trust_blue."""
    bc.clear_scene()
    name = "ew_village_trust_coin_%s" % ver
    coin = [vp.tcyl("coin", 0.0150, 0.0040, (0, 0, 0.0150), "rarity_gold", 12, 90, 0, 0),
            vp.tcyl("rim", 0.0158, 0.0030, (0, 0.0004, 0.0150), "wood_dark", 12, 90, 0, 0)]
    heart = [loft("heart", heart_col, outline(10, 0.0190), [(0.80, 0.0028), (1.0, 0.0009), (1.0, -0.0009), (0.80, -0.0028)])]
    lift_all(heart, 0.0058, -0.0048)
    obj = bc.finish(coin + heart, name, do_bevel=False)
    bc.anchor(obj, "sparkle_anchor", (0, 0, 0.0150), size=0.034)
    obj["ew_footprint"], obj["ew_front"], obj["ew_place"] = "1x1", "-Y", "token"
    d = obj.dimensions
    print("%s: %d tris, %.1f x %.1f x %.1f mm" % (name, tris(obj), d.x * 1000, d.y * 1000, d.z * 1000))
    return obj


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if args and args[0] == "COIN":
        obj = build_coin(args[1])
        bc.save_blend(obj, "help_trust_coin")
        if len(args) > 2 and args[2] == "EXPORT":
            print("EXPORT", bc.export_glb(obj, "village"))
    elif args and args[0] == "FINAL":
        obj = build(args[1], args[2])
        bc.save_blend(obj, "help_heart")
        print("EXPORT", bc.export_glb(obj, "village"))
    else:
        obj = build(args[0])
        bc.save_blend(obj, "heart2_" + args[0])
