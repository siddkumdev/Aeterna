"""Sheep for the live story's flock (9 adults, no lambs; sykeriin 2026-11-17). Built at game (table) size like the
cat (~1 cell long) and scaled up to life size in the story. Cream wool, dark face and legs, palette colours only.
Assembled via bc.assemble() into separate moving parts (no rig):
    root (wool body + tail at z = 0)  __head (graze bob, pivot at the neck)  __leg_fl __leg_fr __leg_bl __leg_br (walk,
    pivot at the hip)
Front is -Y (glTF +Z), the sheep's left is +X (_l), right is -X (_r), +Z is up in Blender (+Y in glTF).
Budget 1,000 tris per sheep (sykeriin 2026-11-17: 9 sheep stay under 10k).

Run one variant: blender --factory-startup -b -P assets/generators/make_sheep.py -- A  (A-D)
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "tools"))
sys.path.insert(0, HERE)
import blender_common as bc  # noqa: E402
import bpy  # noqa: E402
from make_cat import K, bl, bx, cy, seg_tube  # noqa: E402

WOOL, FACE, HOOF = "wall_cream", "hair_charcoal", "ink"


def face(hx, hy, hz, hr, ear_droop=35, topknot=1.0, muzzle=(0.9, 1.25, 0.95), sub=1):
    """Dark sheep head centred at (hx, hy, hz) mm: long muzzle, pale eyes, droopy ears, woolly topknot."""
    p = [bl("skull", hr, (hx, hy, hz), FACE, muzzle, sub=sub)]
    for sx in (-1, 1):
        p.append(bl("eye", hr * 0.24, (hx + sx * hr * 0.62, hy - hr * 0.35, hz + hr * 0.30), "bone", (1, 1, 1), sub=1))
        p.append(bl("pupil", hr * 0.13, (hx + sx * hr * 0.70, hy - hr * 0.52, hz + hr * 0.32), HOOF, (1, 1, 1), sub=1))
        p.append(bx("ear", (hr * 1.1, hr * 0.45, hr * 0.22), (hx + sx * hr * 1.15, hy + hr * 0.15, hz + hr * 0.25),
                    FACE, ry=sx * ear_droop, rz=sx * -10))
    if topknot:
        p.append(bl("topknot", hr * 0.62 * topknot, (hx, hy + hr * 0.25, hz + hr * 0.95), WOOL, (1.2, 1.0, 0.8), sub=1))
    return p


def leg(name, x, y, top, length, r=1.7):
    """Dark leg hanging from its hip at (x, y, top) down to the ground, with a black hoof."""
    return [cy(name, r, r * 0.85, length, (x, y, top - length / 2), FACE, 6),
            bx(name + "_hoof", (r * 2.1, r * 2.4, 1.6), (x, y - 0.2, 0.8), HOOF)]


def legs(xs, yf, yb, top, length, r=1.7):
    """Four leg groups for bc.assemble (pivot at each hip)."""
    out = []
    for suf, x, y in (("leg_fl", xs, yf), ("leg_fr", -xs, yf), ("leg_bl", xs, yb), ("leg_br", -xs, yb)):
        out.append((suf, leg(suf, x, y, top, length, r), (x * K, y * K, top * K), ""))
    return out


def curls(centre, rx, ry, rz, n_ring, ring_z, r, col=WOOL):
    """A ring of chunky wool curls on an ellipsoid body (fewer, bigger curls: the old 140 tiny ones shimmered)."""
    import math
    cx, cyy, cz = centre
    out = []
    for i in range(n_ring):
        a = (i + 0.5) / n_ring * 2 * math.pi
        out.append(bl("curl", r, (cx + math.cos(a) * rx, cyy + math.sin(a) * ry, cz + ring_z * rz), col, (1, 1, 0.85), sub=1))
    return out


def variant_A():
    """Cloud puff: round body made of big curls, short legs, big topknot."""
    body_c = (0, 1.0, 10.8)
    root = [bl("core", 8.6, body_c, WOOL, (1.0, 1.32, 0.88), sub=2)]
    root += curls(body_c, 6.4, 8.6, 7.5, 7, 0.35, 4.2)
    root += [bl("crown", 4.6, (0, -2.5, 17.3), WOOL, (1, 1, 0.8), sub=1), bl("crown", 4.6, (0, 4.5, 17.1), WOOL, (1, 1, 0.8), sub=1),
             bl("tail", 2.4, (0, 12.4, 12.3), WOOL, (1, 1, 1.2), sub=1)]
    head = [bl("ruff", 4.4, (0, -9.6, 12.4), WOOL, (1.15, 0.9, 1.0), sub=1)] + face(0, -14.6, 12.6, 5.8, ear_droop=30, topknot=1.2)
    return [("", root, (0, 0, 0), None), ("head", head, (0, -9.0 * K, 12.0 * K), "")] + legs(4.6, -5.5, 6.5, 6.4, 6.0, 2.5)


def variant_B():
    """Toy loaf: blocky body of stacked wool slabs, square muzzle, sturdy legs (wooden farm-toy look)."""
    root = [bx("slab_lo", (14.5, 22.0, 6.5), (0, 1.0, 11.5), WOOL),
            bx("slab_hi", (12.5, 20.0, 5.5), (0, 1.0, 17.0), WOOL),
            bx("slab_top", (9.0, 15.0, 2.6), (0, 1.5, 20.6), WOOL),
            bx("slab_side_l", (2.0, 18.0, 8.0), (7.6, 1.0, 14.0), WOOL),
            bx("slab_side_r", (2.0, 18.0, 8.0), (-7.6, 1.0, 14.0), WOOL),
            bx("tail", (3.0, 2.6, 4.0), (0, 12.6, 15.5), WOOL, rx=-20)]
    head = [bx("skull", (7.0, 8.0, 7.0), (0, -13.6, 17.4), FACE, rx=12),
            bx("muzzle", (5.4, 3.6, 4.6), (0, -17.6, 15.6), FACE, rx=12)]
    for sx in (-1, 1):
        head += [bx("eye", (1.6, 0.8, 1.6), (sx * 2.0, -17.7, 19.4), "bone", rx=12),
                 bx("pupil", (0.8, 0.5, 0.9), (sx * 2.1, -18.15, 19.3), HOOF, rx=12),
                 bx("ear", (4.6, 1.8, 1.0), (sx * 5.0, -12.6, 19.0), FACE, ry=sx * 30)]
    head.append(bx("topknot", (5.0, 4.4, 2.6), (0, -12.8, 21.6), WOOL, rx=12))
    return [("", root, (0, 0, 0), None), ("head", head, (0, -9.5 * K, 16.0 * K), "")] + legs(4.8, -6.0, 7.0, 9.0, 8.8, 2.0)


def variant_C():
    """Ram: slimmer oval fleece, dark neck, chunky curled horns about the size of the head."""
    body_c = (0, 1.0, 13.0)
    root = [bl("core", 8.0, body_c, WOOL, (0.92, 1.42, 0.82), sub=2)]
    root += curls(body_c, 5.6, 9.4, 6.6, 6, 0.45, 3.6)
    root += [bl("tail", 2.2, (0, 13.0, 13.2), WOOL, (1, 1, 1.5), sub=1)]
    hx, hy, hz = 0, -15.4, 17.6
    head = [bl("neck", 3.4, (0, -10.4, 15.6), FACE, (1.0, 1.3, 1.0), sub=1)] +         face(hx, hy, hz, 5.4, ear_droop=25, topknot=0.0, muzzle=(0.85, 1.35, 0.95))
    for sx in (-1, 1):  # chunky ram curls, about head-sized, sweeping back and down past the ears
        # roots sunk in the skull; the curl swings out sideways and forward, clear of the fleece (critic v02)
        head += seg_tube("horn", [(sx * 2.2, hy + 0.8, hz + 3.0), (sx * 6.4, hy + 1.4, hz + 4.6), (sx * 9.2, hy + 0.4, hz + 1.6),
                                  (sx * 8.8, hy - 1.8, hz - 1.4), (sx * 6.8, hy - 2.6, hz + 0.0)],
                         [2.6, 2.4, 2.1, 1.7, 1.2], "bone", 6)
    return [("", root, (0, 0, 0), None), ("head", head, (0, -9.5 * K, 15.0 * K), "")] + legs(4.0, -6.0, 7.5, 9.0, 8.6, 2.1)


def variant_D():
    """Shepherd's flock sheep: cloud body with a maroon collar and brass bell, and a terracotta flock mark on the rump."""
    body_c = (0, 1.0, 10.8)
    root = [bl("core", 8.6, body_c, WOOL, (1.0, 1.32, 0.88), sub=2)]
    root += curls(body_c, 6.4, 8.6, 7.5, 6, 0.3, 4.4)
    root += [bl("tail", 2.4, (0, 12.4, 12.3), WOOL, (1, 1, 1.2), sub=1),
             # dye mark sunk into the rump wool (only its top shows), not a disc on top
             bl("mark", 4.0, (0, 6.5, 15.6), "roof_terracotta", (1.25, 1.0, 0.7), sub=1)]
    head = [bl("ruff", 4.4, (0, -9.6, 12.4), WOOL, (1.15, 0.9, 1.0), sub=1)] + face(0, -14.6, 12.6, 5.8, ear_droop=30, topknot=0.9)
    head += [cy("collar", 4.4, 4.2, 2.2, (0, -11.6, 11.0), "cloth_maroon", 10, rx=60),
             bl("bell", 2.7, (0, -14.2, 7.4), "shell_gold", (1, 1, 1.15), sub=2)]
    return [("", root, (0, 0, 0), None), ("head", head, (0, -9.0 * K, 12.0 * K), "")] + legs(4.6, -5.5, 6.5, 6.4, 6.0, 2.5)


VARIANTS = {
    "A": ("Cloud puff: round body of big curls, short legs, big topknot", variant_A),
    "B": ("Toy loaf: blocky stacked wool slabs, square muzzle, sturdy legs", variant_B),
    "C": ("Ram: slimmer fleece, dark neck, chunky head-sized curled horns", variant_C),
    "D": ("Shepherd's sheep: cloud body, maroon collar and brass bell, flock mark", variant_D),
}


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["A"]
    L = args[0] if args[0] in VARIANTS else "A"
    bc.clear_scene()
    root = bc.assemble("ew_village_sheep_v01", VARIANTS[L][1](), bevel_min=0.004)
    root["ew_footprint"], root["ew_front"], root["ew_place"] = "1x1", "-Y", "ground"
    bpy.context.view_layer.update()
    objs = [root] + list(root.children_recursive)
    zs = [(o.matrix_world @ v.co).z for o in objs if o.type == "MESH" for v in o.data.vertices]
    if zs and abs(min(zs)) > 1e-4:
        shift = min(zs)
        for v in root.data.vertices:
            v.co.z -= shift
        for c in root.children:
            c.location.z -= shift
        bpy.context.view_layer.update()
    total = sum(tris(o) for o in objs if o.type == "MESH")
    print("SHEEP %s: %d tris total, %.1f x %.1f x %.1f mm" % (L, total, *(d * 1000 for d in root.dimensions)))
    for c in objs:
        if c.type == "MESH":
            print("  %s: %d tris" % (c.name, tris(c)))
    print("BLEND", bc.save_blend(root, "sheep_" + L))
