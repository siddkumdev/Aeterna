"""Laundry (quest "Laundry line", Siddharth 2026-11-16): three garments the wind blew off the existing clothesline.
The player picks each one off the grass and pinches it back on the line. VARIANT ROUND: four ideas A-D.

Run one variant:   blender --factory-startup -b -P assets/generators/make_laundry.py -- A      (saves assets/blend/laundry_A.blend)
Scale reference:   blender --factory-startup -b -P assets/generators/make_laundry.py -- SCALE  (all four beside basket, clothesline, villager)

Each variant is ONE root (the shirt) with the sock and the sheet as separate parts, only so the sheet and validator see all
three at once. The finals will be three separate assets (ew_village_laundry_shirt / _sock / _sheet), each its own origin at its
base; here the garments sit in a row (shirt x = -22 mm, sock 0, sheet +22 mm). All garments lie on the grass, +Y up, front -Y.
Sizes in mm in the code (1 cell = 50 mm): shirt about 20 wide, sock about 10 x 14, sheet about 15 x 12; the clothesline's
hanging cloths are 10 x 15, so these match it. Colours from the palette atlas only.
"""
import math
import os
import sys

import bpy
import mathutils

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "tools"))
sys.path.insert(0, HERE)
import blender_common as bc  # noqa: E402
import make_village_props as vp  # noqa: E402

K = 0.001


def bx(name, size, loc, col, rx=0.0, ry=0.0, rz=0.0):
    """Box, everything in mm; loc = centre."""
    return vp.tbox(name, tuple(s * K for s in size), tuple(l * K for l in loc), col, rx, ry, rz)


def bl(name, r, loc, col, squash=(1, 1, 1), sub=1, rz=0.0, rx=0.0, ry=0.0):
    o = bc.blob(name, r * K, (0, 0, 0), col, sub, squash)
    o["no_bevel"] = True
    return vp.tilted(o, tuple(l * K for l in loc), rx, ry, rz)


def move(parts, dx, dy, dz=0.0):
    for o in parts:
        for v in o.data.vertices:
            v.co.x += dx * K
            v.co.y += dy * K
            v.co.z += dz * K
    return parts


def turn(parts, rx=0.0, ry=0.0, rz=0.0):
    """Rotate a finished garment about its own centre (degrees) and put it back on the ground (min z = 0)."""
    m = mathutils.Euler((math.radians(rx), math.radians(ry), math.radians(rz)), "XYZ").to_matrix()
    for o in parts:
        for v in o.data.vertices:
            v.co = m @ v.co
    zmin = min(v.co.z for o in parts for v in o.data.vertices)
    for o in parts:
        for v in o.data.vertices:
            v.co.z -= zmin
    return parts


def peg(x, y, z, rz=0.0):
    """A wooden clothes peg standing on a garment: two legs, a dark spring bead."""
    return [bx("peg", (1.3, 1.5, 5.4), (x - 0.9, y, z + 2.7), "wood_light", 0, 0, rz),
            bx("peg", (1.3, 1.5, 5.4), (x + 0.9, y, z + 2.7), "wood_light", 0, 0, rz),
            bx("peg_spring", (3.4, 1.7, 1.1), (x, y, z + 3.2), "wood_dark", 0, 0, rz)]


# ------------------------------------------------------------------ A: flat pressed laundry, sharp stripes (calm, boxy, like the props)
def shirt_A():
    t = 1.6
    p = [bx("shirt", (9.0, 11.0, t), (0, 0, t / 2), "cloth_coral"),
         bx("sleeve", (5.8, 4.0, t), (-6.9, 4.0, t / 2), "cloth_coral", 0, 0, 38),
         bx("sleeve", (5.8, 4.0, t), (6.9, 4.0, t / 2), "cloth_coral", 0, 0, -38),
         bx("neck", (3.4, 2.0, t + 0.5), (0, 5.0, (t + 0.5) / 2), "cloth_maroon"),
         bx("hem", (9.0, 1.6, t + 0.35), (0, -4.7, (t + 0.35) / 2), "wall_cream")]
    return p


def sock_A():
    t = 1.6
    return [bx("sock", (4.6, 9.5, t), (0, 2.0, t / 2), "cloth_mustard"),
            bx("sock", (8.4, 4.6, t), (1.9, -3.6, t / 2), "cloth_mustard"),
            bx("cuff", (4.6, 2.4, t + 0.4), (0, 5.4, (t + 0.4) / 2), "wall_cream"),
            bx("toe", (2.4, 4.6, t + 0.4), (5.0, -3.6, (t + 0.4) / 2), "cloth_coral")]


def sheet_A():
    t = 1.4
    return [bx("sheet", (15.0, 12.0, t), (0, 0, t / 2), "wall_cream"),
            bx("fold", (15.0, 6.0, t), (0.4, -3.0, t * 1.5), "wall_cream", 0, 0, 2),
            bx("stripe", (15.0, 1.5, t + 0.35), (0.4, -5.5, t * 1.5 + 0.18), "roof_teal", 0, 0, 2),
            bx("stripe", (15.0, 1.5, t + 0.35), (0, 5.0, t / 2 + 0.18), "roof_teal")]


# ------------------------------------------------------------------ B: crumpled soft heaps (lumpy, as if tossed on the grass)
def shirt_B():
    return [bl("shirt", 5.3, (0, 0, 1.9), "cloth_coral", (1.05, 1.25, 0.40), 2),
            bl("sleeve", 2.8, (-6.2, 3.6, 1.4), "cloth_coral", (1.6, 0.8, 0.55), 1, 32),
            bl("sleeve", 2.8, (6.2, 3.2, 1.4), "cloth_coral", (1.6, 0.8, 0.55), 1, -50),
            bl("fold", 3.0, (-1.0, -1.5, 3.0), "cloth_coral", (1.3, 0.8, 0.5), 1, 20),
            bl("neck", 1.9, (0, 5.2, 2.2), "cloth_maroon", (1.2, 0.8, 0.4), 1),
            bl("hem", 3.2, (0.5, -4.8, 1.6), "wall_cream", (1.5, 0.4, 0.5), 1)]


def sock_B():
    return [bl("sock", 2.7, (0, 3.0, 1.9), "cloth_mustard", (0.9, 1.7, 0.75), 1, 8),
            bl("sock", 2.9, (1.2, -1.2, 1.9), "cloth_mustard", (1.1, 1.2, 0.75), 1),
            bl("sock", 2.6, (3.8, -3.4, 1.8), "cloth_mustard", (1.6, 1.0, 0.75), 1, -20),
            bl("cuff", 2.8, (0, 6.4, 2.0), "wall_cream", (1.0, 0.7, 0.75), 1),
            bl("toe", 1.9, (6.0, -3.8, 1.7), "cloth_coral", (1.0, 1.0, 0.8), 1)]


def sheet_B():
    return [bl("sheet", 6.4, (0, 0, 1.8), "wall_cream", (1.2, 1.0, 0.36), 2),
            bl("sheet", 4.6, (-2.4, 1.8, 3.2), "wall_cream", (1.1, 1.0, 0.45), 1, 25),
            bl("sheet", 4.2, (3.2, -1.2, 3.0), "wall_cream", (1.2, 1.0, 0.45), 1, -20),
            bl("stripe", 3.2, (-1.0, -5.0, 1.5), "roof_teal", (2.4, 0.4, 0.5), 1),
            bl("flap", 2.6, (6.0, 3.6, 1.2), "wall_cream", (1.4, 0.9, 0.4), 1, 30)]


# ------------------------------------------------------------------ C: wind-caught: lifted corners, flapping sleeve, limp sock (shows the wind)
def shirt_C():
    t = 1.6
    p = [bx("shirt", (9.0, 11.0, t), (0, 0, t / 2), "cloth_rose"),
         bx("stripe", (9.0, 1.4, t + 0.35), (0, 1.8, (t + 0.35) / 2), "wall_cream"),
         bx("stripe", (9.0, 1.4, t + 0.35), (0, -2.0, (t + 0.35) / 2), "wall_cream"),
         bx("sleeve", (5.8, 4.0, t), (-6.9, 4.0, t / 2), "cloth_rose", 0, 0, 38),
         bx("sleeve", (5.6, 4.0, t), (4.5 + 2.8 * 0.84, 5.5 + 2.8 * 0.22, t / 2 + 2.8 * 0.5), "cloth_rose", 0, -30, 15),   # one sleeve flung up from the shoulder
         bx("neck", (3.4, 2.0, t + 0.5), (0, 5.0, (t + 0.5) / 2), "wall_cream")]
    return turn(p, 0, 0, 0)


def sock_C():
    t = 1.6
    p = [bx("sock", (4.6, 8.0, t), (0, -1.0, t / 2), "cloth_olive", 0, 0, 0),
         bx("sock", (4.6, 7.0, t), (0.8, 5.0, t / 2 + 2.6), "cloth_olive", 40, 0, 14),   # leg lifted off the grass
         bx("cuff", (4.6, 2.4, t + 0.4), (1.4, 8.0, t / 2 + 5.0), "wall_cream", 40, 0, 14),
         bx("toe", (4.8, 3.4, t + 0.4), (0, -4.4, (t + 0.4) / 2), "cloth_coral")]
    return turn(p, 0, 0, 0)


def sheet_C():
    """Three contiguous slabs rising like a rippled sheet: flat, then lifted 14 degrees, then 30 degrees."""
    t, L = 1.4, 4.4
    p, y, z = [], -6.6, 0.0
    for i, th in enumerate((0, 14, 30)):
        c, s_ = math.cos(math.radians(th)), math.sin(math.radians(th))
        cy, cz = y + L / 2 * c, z + L / 2 * s_ + t / 2 * c
        p.append(bx("sheet", (15.0, L, t), (0, cy, cz), "hair_mint", th, 0, 0))
        if i in (0, 2):  # cream stripe near the slab's outer end
            ay = (L / 2 - 0.7) * (-1 if i == 0 else 1)
            p.append(bx("stripe", (15.0, 1.2, t + 0.35), (0, cy + ay * c, cz + ay * s_ + 0.05), "wall_cream", th, 0, 0))
        y, z = y + L * c, z + L * s_
    return turn(p, 0, 6, 0)


# ------------------------------------------------------------------ D: pegged, in the three colours of the clothesline's hanging cloths (cream, terracotta, leaf green)
def shirt_D():
    t = 1.6
    p = [bx("shirt", (9.0, 11.0, t), (0, 0, t / 2), "roof_terracotta"),
         bx("sleeve", (5.8, 4.0, t), (-6.9, 4.0, t / 2), "roof_terracotta", 0, 0, 38),
         bx("sleeve", (5.8, 4.0, t), (6.9, 4.0, t / 2), "roof_terracotta", 0, 0, -38),
         bx("collar", (4.4, 2.4, t + 0.5), (0, 4.9, (t + 0.5) / 2), "wall_cream"),
         bx("pocket", (2.8, 2.6, t + 0.35), (-2.0, -1.0, (t + 0.35) / 2), "wall_cream")]
    return p + peg(0, 5.8, t)


def sock_D():
    t = 1.6
    p = [bx("sock", (4.6, 9.5, t), (0, 2.0, t / 2), "leaf_light"),
         bx("sock", (8.4, 4.6, t), (1.9, -3.6, t / 2), "leaf_light"),
         bx("cuff", (4.6, 2.4, t + 0.4), (0, 5.4, (t + 0.4) / 2), "wall_cream")]
    return p + peg(0, 5.4, t + 0.4)


def sheet_D():
    t = 1.4
    p = [bx("sheet", (15.0, 12.0, t), (0, 0, t / 2), "wall_cream"),
         bx("border", (15.0, 1.5, t + 0.35), (0, -5.2, t / 2 + 0.18), "roof_terracotta"),
         bx("border", (15.0, 1.5, t + 0.35), (0, 5.2, t / 2 + 0.18), "roof_terracotta")]
    return p + peg(-3.6, 5.2, t + 0.35) + peg(3.6, 5.2, t + 0.35)


VARIANTS = {
    "A": ("Flat pressed laundry: boxy coral shirt, mustard sock, cream sheet with teal stripes", (shirt_A, sock_A, sheet_A)),
    "B": ("Crumpled soft heaps: lumpy tossed cloth, sleeves and sock bent", (shirt_B, sock_B, sheet_B)),
    "C": ("Wind-caught: lifted sleeve, limp sock leg, stepped wavy sheet, rose / olive / mint", (shirt_C, sock_C, sheet_C)),
    "D": ("Pegged: peg on each garment as a pinch handle, the clothesline's own colours", (shirt_D, sock_D, sheet_D)),
}
LAYOUT = (-22.0, 0.0, 22.0)  # x of shirt, sock, sheet (mm)


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def make(letter, x_off=0.0, y_off=0.0, ver="v01"):
    """Build one variant into the scene; returns the root. x_off, y_off (mm) place the whole set (SCALE mode)."""
    parts = []
    for (fn, dx) in zip(VARIANTS[letter][1], LAYOUT):
        parts.append((move(fn(), dx + x_off, y_off), dx + x_off))
    # asymmetric garments (shirt, sock) are built around their own centre, so the pivot is the centre at ground level
    name = "ew_village_laundry_%s" % ver
    groups = [("", parts[0][0], (parts[0][1] * K, y_off * K, 0), None),
              ("sock", parts[1][0], (parts[1][1] * K, y_off * K, 0), ""),
              ("sheet", parts[2][0], (parts[2][1] * K, y_off * K, 0), "")]
    # the root pivot must sit at world 0: assemble puts the root's mesh relative to its pivot, so shift it back
    root = bc.assemble(name, [(g[0], g[1], (0, 0, 0) if g[0] == "" else g[2], g[3]) for g in groups], bevel_min=0.00135)
    return root


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["A"]
    bc.clear_scene()
    if args[0] == "SCALE":
        import prop_scale_ref as sr
        for i, L in enumerate(VARIANTS):
            make(L, x_off=0.0, y_off=-i * 24.0, ver="v%02d" % (i + 1)).name = "ew_village_laundry_%s_v01" % L
        sr.add_refs(0.040, 0.0)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(bc.ROOT, "assets", "blend", "laundry_scale.blend"))
    else:
        root = make(args[0])
        root["ew_footprint"], root["ew_front"], root["ew_place"] = "1x1", "-Y", "free"
        total = sum(tris(o) for o in [root] + list(root.children_recursive) if o.type == "MESH")
        print("LAUNDRY %s: %d tris (shirt %d, sock %d, sheet %d)" % (args[0], total, tris(root), *[tris(c) for c in root.children]))
        print("BLEND", bc.save_blend(root, "laundry_" + args[0]))
