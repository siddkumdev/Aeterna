"""Apples (quest "Apple tree", Siddharth 2026-11-16): shake the tree, apples fall, carry three into the basket.
VARIANT ROUND: four ideas A-D. Each blend holds the loose APPLE (the root) and an apple-bearing ROUND TREE (part `__tree`).

Run one variant:   blender --factory-startup -b -P assets/generators/make_apples.py -- A      (saves assets/blend/apples_A.blend)
Scale reference:   blender --factory-startup -b -P assets/generators/make_apples.py -- SCALE  (all four beside basket, clothesline, villager)

The tree is the existing ew_world_tree_oak_round_v01 (make_trees_cozy.oak_round(), canopy lumps copied below) with apples
attached on its canopy surface, so the finished model can simply be a second round tree, ew_world_tree_apple_vNN. The apple
sits 45 mm beside it only for the sheet; the finals are separate assets, each with its origin at its base.
Sizes: basket fruit is 3.6 mm in radius; the apple is 4.4 to 6 mm (a little oversized so it reads at tabletop distance).
Palette names only (fire_red, roof_orange, fire_yellow, leaf_light, leaf_green, wood_dark ...).
"""
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "tools"))
sys.path.insert(0, HERE)
import blender_common as bc  # noqa: E402
import make_trees_cozy as mt  # noqa: E402
import make_village_props as vp  # noqa: E402

K = 0.001
# the canopy lumps of oak_round(): (radius, centre, squash)  -- kept in step with make_trees_cozy.oak_round
LUMPS = [(0.022, (0.0, 0.0, 0.046), (1, 1, 0.72)), (0.021, (0.006, -0.004, 0.062), (1, 1, 0.78)), (0.016, (-0.004, 0.004, 0.077), (1, 1, 0.82))]


def nb(o):
    o["no_bevel"] = True
    return o


def blob(name, r, loc, col, squash=(1, 1, 1), sub=1, rz=0.0, rx=0.0, ry=0.0):
    o = nb(bc.blob(name, r * K, (0, 0, 0), col, sub, squash))
    return vp.tilted(o, tuple(l * K for l in loc), rx, ry, rz)


def bx(name, size, loc, col, rx=0.0, ry=0.0, rz=0.0):
    return nb(vp.tbox(name, tuple(s * K for s in size), tuple(l * K for l in loc), col, rx, ry, rz))


# ------------------------------------------------------------------ the four apples (mm, base at z = 0, centre of the apple at x, y)
def apple(kind, x=0.0, y=0.0, z0=0.0, s=1.0, leaf=True, sub=2, simple=False):
    """One apple whose lowest point is at z0 (tilt = (rx, ry) degrees for the ones hanging on the tree)."""
    p = []
    if kind == "A":      # classic: round red, short stem, one green leaf
        r = 4.4 * s
        p.append(blob("apple", r, (x, y, z0 + r * 0.92), "fire_red", (1, 1, 0.92), sub))
        top = z0 + r * 1.84
        p.append(bx("stem", (1.0, 1.0, 2.0 * s), (x, y, top - 0.2), "wood_dark"))
        if leaf:
            p.append(blob("leaf", 1.9 * s, (x + 1.9 * s, y, top + 0.1), "leaf_green", (1.0, 0.55, 0.28), 1, rz=-20))
    elif kind == "B":    # squat green-gold apple with a warm orange blush and two leaves
        r = 4.7 * s
        p.append(blob("apple", r, (x, y, z0 + r * 0.80), "leaf_yellow", (1.06, 1.06, 0.82), sub))
        if not simple:
            p.append(blob("blush", 3.1 * s, (x + 2.3 * s, y - 2.1 * s, z0 + r * 0.84), "roof_orange", (0.60, 0.88, 0.88), 1, rz=-35))
        top = z0 + r * 1.60
        p.append(bx("stem", (1.1, 1.1, 2.2 * s), (x, y, top - 0.2), "wood_mid"))
        if leaf:
            p.append(blob("leaf", 1.8 * s, (x - 1.9 * s, y + 0.3, top + 0.1), "leaf_green", (1.0, 0.55, 0.28), 1, rz=25))
            p.append(blob("leaf", 1.5 * s, (x + 1.7 * s, y - 0.3, top - 0.1), "leaf_dark", (1.0, 0.55, 0.28), 1, rz=-25))
    elif kind == "C":    # heart-shaped: two red cheeks and a rounded orange-red point, a bit taller than wide
        r = 3.1 * s
        h = z0 + r * 1.15
        if not simple:
            p.append(blob("cheek", r, (x - 1.9 * s, y, h + 1.4 * s), "fire_red", (1, 1.15, 1.0), 1))
            p.append(blob("cheek", r, (x + 1.9 * s, y, h + 1.4 * s), "fire_red", (1, 1.15, 1.0), 1))
        p.append(blob("belly", 3.5 * s, (x, y, h + 0.6 * s), "fire_red", (1.1, 1.15, 1.0), 1))
        p.append(blob("point", 2.6 * s, (x, y, h - 0.4 * s), "roof_orange", (1, 1, 0.9), 1))
        top = h + 1.4 * s + r * 0.9
        p.append(bx("stem", (1.0, 1.0, 2.2 * s), (x, y, top - 0.3), "wood_dark", 0, 12, 0))
        if leaf:
            p.append(blob("leaf", 1.9 * s, (x + 1.8 * s, y, top + 0.3), "leaf_green", (1.0, 0.55, 0.28), 1, rz=-20))
    else:                # D: oversized golden apple, tall stem and a big leaf (biggest and plainest)
        r = 6.0 * s
        p.append(blob("apple", r, (x, y, z0 + r * 0.95), "fire_yellow", (1, 1, 0.96), sub))
        if not simple:
            p.append(blob("blush", 3.0 * s, (x + 3.4 * s, y - 2.4 * s, z0 + r * 0.95), "roof_orange", (0.45, 0.9, 0.9), 1, rz=-35))
        top = z0 + r * 1.9
        p.append(bx("stem", (1.3, 1.3, 3.0 * s), (x, y, top - 0.3), "wood_dark"))
        if leaf:
            p.append(blob("leaf", 2.8 * s, (x + 2.6 * s, y, top + 0.6), "leaf_green", (1.0, 0.55, 0.28), 1, rz=-20))
    return p


# ------------------------------------------------------------------ the apple tree: oak_round() with apples on the canopy
def tree_parts(letter, cx, cy):
    """oak_round with its trunk at (cx, cy) mm, plus apples sitting on the canopy surface (positions from the lump ellipsoids)."""
    parts = [nb(o) for o in mt.oak_round()]   # as make_trees_cozy.finish: joined and flat shaded, not bevelled
    for o in parts:
        for v in o.data.vertices:
            v.co.x += cx * K
            v.co.y += cy * K
    zmin = min(v.co.z for o in parts for v in o.data.vertices)
    for o in parts:
        for v in o.data.vertices:
            v.co.z -= zmin
    # (lump index, azimuth deg from +X, elevation deg): the camera looks from the front-right, so most apples face about -55 deg
    spots = {"A": [(0, -100, 8), (0, -40, 14), (0, 15, 6), (1, -75, 22), (1, -15, 28), (1, -130, 30), (2, -50, 38)],
             "B": [(0, -60, 10), (0, -30, 12), (1, -50, 30), (1, -95, 26), (0, 20, 8), (2, -45, 40)],
             "C": [(0, -75, 6), (1, -45, 20), (1, 10, 24), (0, -125, 12), (2, -70, 34)],
             "D": [(0, -80, 10), (1, -40, 26), (0, -10, 8), (2, -60, 38)]}[letter]
    scale = {"A": 1.15, "B": 1.1, "C": 1.1, "D": 0.8}[letter]   # D's apples are big, so fewer and a bit smaller on the tree
    for (li, az, el) in spots:
        r, c, sq = LUMPS[li]
        a, e = math.radians(az), math.radians(el)
        px = c[0] * 1000 + cx + r * 1000 * sq[0] * math.cos(e) * math.cos(a) * 1.02
        py = c[1] * 1000 + cy + r * 1000 * sq[1] * math.cos(e) * math.sin(a) * 1.02
        pz = c[2] * 1000 - zmin * 1000 + r * 1000 * sq[2] * math.sin(e) * 1.02
        # hang the apple so its centre sits on the surface: z0 = centre height - body radius
        body = {"A": 4.4 * 0.92, "B": 4.7 * 0.80, "C": 3.1 * 1.15 + 1.4, "D": 6.0 * 0.95}[letter] * scale
        parts += apple(letter, px, py, pz - body, scale, leaf=False, sub=1, simple=True)
    return parts


# ------------------------------------------------------------------ variants
VARIANTS = {
    "A": "Classic red apple, short stem and a leaf; the tree carries seven",
    "B": "Squat green-gold apple with an orange blush, two leaves; the tree carries six",
    "C": "Heart-shaped red apple with an orange-red point; the tree carries five",
    "D": "Oversized golden apple, tall stem and a big leaf; the tree carries four",
}
TREE_X = 34.0


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def make(letter, y_off=0.0, ver="v01"):
    ap = apple(letter, 0.0, y_off)
    tr = tree_parts(letter, TREE_X, y_off)
    name = "ew_village_apples_%s" % ver
    return bc.assemble(name, [("", ap, (0, y_off * K, 0), None), ("tree", tr, (TREE_X * K, y_off * K, 0), "")], bevel_min=0.0015)


LOOSE_SCALE = 2.0   # Siddharth 2026-11-16, variant A: the loose apple must be pickable, so it is bigger than the ones on the tree (r 4.4 -> 8.8 mm)


def build_final():
    """Variant A. Two exports: ew_village_apple_v01 (the loose, pickable apple) and ew_village_apple_tree_v01 (round oak with 7 red apples,
    origin at the trunk base). apples.blend = apple root + __tree part, PREVIEW ONLY, not exported."""
    bc.clear_scene()
    ap = bc.assemble("ew_village_apple_v01", [("", apple("A", 0.0, 0.0, 0.0, LOOSE_SCALE), (0, 0, 0), None)], bevel_min=0.0015)
    ap["ew_footprint"], ap["ew_front"], ap["ew_place"] = "1x1", "-Y", "free"
    bc.save_blend(ap, "apples_apple")
    print("EXPORT", bc.export_glb(ap, "village"), tris(ap), "tris")
    bc.clear_scene()
    tr = bc.assemble("ew_village_apple_tree_v01", [("", tree_parts("A", 0.0, 0.0), (0, 0, 0), None)], bevel_min=0.0015)
    tr["ew_footprint"], tr["ew_front"], tr["ew_place"] = "1x1", "-Y", "free"
    bc.save_blend(tr, "apples_tree")
    print("EXPORT", bc.export_glb(tr, "village"), tris(tr), "tris", ["%.1f" % (d * 1000) for d in tr.dimensions])
    bc.clear_scene()
    root = bc.assemble("ew_village_apple_v01", [("", apple("A", 0.0, 0.0, 0.0, LOOSE_SCALE), (0, 0, 0), None),
                                                  ("tree", tree_parts("A", TREE_X, 0.0), (TREE_X * K, 0, 0), "")], bevel_min=0.0015)
    root["ew_footprint"], root["ew_front"], root["ew_place"] = "1x1", "-Y", "free"
    print("PREVIEW", bc.save_blend(root, "apples"))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["A"]
    bc.clear_scene()
    if args[0] == "FINAL":
        build_final()
    elif args[0] == "SCALE":
        import prop_scale_ref as sr
        for i, L in enumerate(VARIANTS):   # the four loose apples in a row, tree A behind them, then the references
            bc.assemble("ew_village_apples_%s_v01" % L, [("", apple(L, i * 14.0, 0.0), (0, 0, 0), None)], bevel_min=0.0015)
        bc.assemble("ew_village_apples_tree_v01", [("", tree_parts("A", 85.0, 0.0), (0, 0, 0), None)], bevel_min=0.0015)
        sr.add_refs(0.120, 0.0)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(bc.ROOT, "assets", "blend", "apples_scale.blend"))
    else:
        root = make(args[0])
        root["ew_footprint"], root["ew_front"], root["ew_place"] = "1x1", "-Y", "free"
        tr = root.children[0]
        print("APPLES %s: %d tris total (apple %d, tree with apples %d); apple %.1f x %.1f x %.1f mm; tree %.1f mm tall" % (
            args[0], tris(root) + tris(tr), tris(root), tris(tr), *(d * 1000 for d in root.dimensions), tr.dimensions.z * 1000))
        print("BLEND", bc.save_blend(root, "apples_" + args[0]))
