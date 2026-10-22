"""Time-rewind hourglass (X11): hero prop that rises over the board only for the rewind, flips, the sand runs upward,
then it fades (Siddharth 2026-10-22). References art/moodboard/hourglass_refs_2026-10-22/ (style and shape only):
4 = cartoon hourglass set, 5 = baroque scroll frame, 6 = rugged pillars, 7 = palace hourglass, 8 = banded bulbs.
Gold frame like the Crystal Lens, crystal_blue sand (the same crystal powers Foresight and the rewind).
About 16 cm tall over the 60 cm board. Origin at the base centre.
Parts: root = frame; __glass (Godot gives it a transparent material); __sand_top and __sand_bottom (Godot scales them
so the sand runs upward); the whole root flips. Anchors: __stream_anchor (falling-sand stream at the neck),
__glow_anchor (centre, rewind glow).
Run: blender --factory-startup -b -P assets/generators/make_hourglass.py -- <A|B|C|D>
"""
import math
import os
import sys

import bmesh
import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "tools"))
sys.path.insert(0, HERE)
import blender_common as bc  # noqa: E402
import make_village_props as vp  # noqa: E402  (cyl, tcyl, tbox, tilted, nb)

GOLD, SAND, GLASS, DARK = "rarity_gold", "crystal_blue", "fog", "wood_dark"
Z0 = 0.014           # top of the base cap = bottom of the glass
GH = 0.130           # glass height
# glass profile (radius, height above Z0), bottom to top; waist at GH / 2
PROFILE = [(0.022, 0.000), (0.033, 0.012), (0.036, 0.028), (0.030, 0.045), (0.014, 0.058), (0.006, 0.065),
           (0.014, 0.072), (0.030, 0.085), (0.036, 0.102), (0.033, 0.118), (0.022, 0.130)]


def glass_r(z):
    """Glass radius at height z above Z0 (linear in the profile)."""
    for (r1, z1), (r2, z2) in zip(PROFILE, PROFILE[1:]):
        if z1 <= z <= z2:
            return r1 + (r2 - r1) * (z - z1) / (z2 - z1)
    return PROFILE[-1][0]


def lathe(name, rings, col, n=12, z0=Z0, cap_bottom=True, cap_top=True):
    """Solid of revolution about Z from (radius, z) rings, bottom to top."""
    bm = bmesh.new()
    lay = [[bm.verts.new((r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n), z0 + z)) for i in range(n)]
           for r, z in rings]
    for a, b in zip(lay, lay[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_bottom:
        bm.faces.new(list(reversed(lay[0])))
    if cap_top:
        bm.faces.new(lay[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = bc._new_obj(name, bm)
    bc.paint(obj, col)
    return vp.nb(obj)


def glass():
    return [lathe("glass", PROFILE, GLASS, 12)]


def sand():
    bottom = lathe("sand", [(0.023, 0.003), (0.031, 0.018), (0.018, 0.030), (0.004, 0.036)], SAND, 10)
    top = lathe("sand", [(0.005, 0.067), (0.012, 0.074), (0.026, 0.086), (0.029, 0.094)], SAND, 10)
    return top, bottom


def bar(name, p1, p2, ang, w, d, col):
    """Box from (r1, z1) to (r2, z2) in the radial plane at angle `ang` (deg); w across, d radial thickness."""
    (r1, z1), (r2, z2) = p1, p2
    ln = math.hypot(r2 - r1, z2 - z1)
    tilt = math.degrees(math.atan2(r2 - r1, z2 - z1))
    a = math.radians(ang)
    rm, zm = (r1 + r2) / 2, (z1 + z2) / 2
    return vp.tbox(name, (d, w, ln + 0.002), (rm * math.cos(a), rm * math.sin(a), zm), col, 0, tilt, ang)


def caps(r, h, col=GOLD, seg=12, trim=None):
    """Bottom and top caps; `trim` = colour of a thin band around each cap."""
    p = [vp.cyl("cap", r, h, (0, 0, 0), col, seg), vp.cyl("cap", r, h, (0, 0, Z0 + GH), col, seg)]
    if trim:
        p += [vp.cyl("trim", r + 0.0012, h * 0.35, (0, 0, h * 0.32), trim, seg),
              vp.cyl("trim", r + 0.0012, h * 0.35, (0, 0, Z0 + GH + h * 0.32), trim, seg)]
    return p


# ------------------------------------------------------------------ variants
def hg_A():
    """Chunky toy (ref 4): thick rounded double caps, three beaded posts, knob on top."""
    p = caps(0.046, Z0) + [vp.cyl("lip", 0.040, 0.004, (0, 0, Z0 - 0.001), GOLD, 12),
                           vp.cyl("lip", 0.040, 0.004, (0, 0, Z0 + GH - 0.003), GOLD, 12),
                           vp.cyl("knob", 0.010, 0.006, (0, 0, Z0 * 2 + GH), GOLD, 8, 0.006)]
    for a in (90, 210, 330):
        x, y = 0.041 * math.cos(math.radians(a)), 0.041 * math.sin(math.radians(a))
        p += [vp.cyl("post", 0.0042, GH, (x, y, Z0), GOLD, 6),
              vp.nb(bc.blob("bead", 0.0072, (x, y, Z0 + GH / 2), GOLD, 1, (1, 1, 1.25))),
              vp.cyl("collar", 0.0062, 0.006, (x, y, Z0 + 0.010), GOLD, 6), vp.cyl("collar", 0.0062, 0.006, (x, y, Z0 + GH - 0.016), GOLD, 6)]
    return p


def hg_B():
    """Baroque (ref 5): moulded caps with a dark band, four S-bars that hug the glass waist, curls at the corners and waist."""
    p = caps(0.047, Z0, GOLD, 12, DARK)
    zs = [0.004, 0.030, 0.065, 0.100, 0.126]
    for a in (45, 135, 225, 315):
        pts = [(glass_r(z) + 0.0100, Z0 + z) for z in zs]  # 10 mm off the glass so the straight bars clear its shoulders
        pts[0], pts[-1] = (0.040, Z0), (0.040, Z0 + GH)
        for p1, p2 in zip(pts, pts[1:]):
            p.append(bar("sbar", p1, p2, a, 0.0070, 0.0040, GOLD))
        ar = math.radians(a)
        for z, r in ((Z0 + 0.016, 0.043), (Z0 + GH - 0.016, 0.043)):
            p.append(vp.nb(vp.tcyl("curl", 0.0058, 0.0050, (r * math.cos(ar), r * math.sin(ar), z), GOLD, 6, 90, 0, a + 90)))
    return p


def hg_C():
    """Rugged pillars (ref 6): square chunky caps, two thick posts that bow outward, bracket blocks."""
    p = [vp.tbox("cap", (0.090, 0.060, Z0), (0, 0, Z0 / 2), GOLD), vp.tbox("cap", (0.090, 0.060, Z0), (0, 0, Z0 + GH + Z0 / 2), GOLD),
         vp.tbox("plinth", (0.076, 0.050, 0.004), (0, 0, Z0 + 0.002), GOLD), vp.tbox("plinth", (0.076, 0.050, 0.004), (0, 0, Z0 + GH - 0.002), GOLD)]
    for a in (0, 180):
        pts = [(0.040, Z0), (0.045, Z0 + 0.040), (0.047, Z0 + GH / 2), (0.045, Z0 + GH - 0.040), (0.040, Z0 + GH)]
        for p1, p2 in zip(pts, pts[1:]):
            p.append(bar("post", p1, p2, a, 0.014, 0.010, GOLD))
        s = 1 if a == 0 else -1
        p += [vp.tbox("bracket", (0.006, 0.018, 0.006), (s * 0.048, 0, Z0 + 0.030), GOLD),
              vp.tbox("bracket", (0.006, 0.018, 0.006), (s * 0.048, 0, Z0 + GH - 0.030), GOLD)]
    return p


def hg_D():
    """Palace (refs 7 + 8): wide stepped caps, four slim posts with blue diamond insets, gold bands on the glass shoulders,
    a blue gem on the front of the base."""
    p = caps(0.046, Z0) + [vp.cyl("step", 0.040, 0.005, (0, 0, Z0 * 2 + GH), GOLD, 12),
                           vp.cyl("step", 0.050, 0.004, (0, 0, 0), GOLD, 12)]
    for a in (45, 135, 225, 315):
        ar = math.radians(a)
        x, y = 0.042 * math.cos(ar), 0.042 * math.sin(ar)
        p.append(vp.cyl("post", 0.0034, GH, (x, y, Z0), GOLD, 6))
        for z in (Z0 + GH - 0.034,):
            p.append(vp.nb(bc.blob("inset", 0.0060, (x * 1.10, y * 1.10, z), SAND, 0, (0.7, 0.7, 1.4))))
    for z in (0.030, 0.100):
        r = glass_r(z) + 0.0015
        p.append(lathe("band", [(r, z - 0.0025), (r + 0.0022, z - 0.0025), (r + 0.0022, z + 0.0025), (r, z + 0.0025), (r, z - 0.0025)],
                       GOLD, 12, cap_bottom=False, cap_top=False))  # a closed ring, not a plate
    p.append(vp.nb(bc.blob("gem", 0.0050, (0, -0.047, Z0 / 2), SAND, 0, (1, 0.7, 1.2))))
    return p


def hg_E():
    """A, symmetric (Siddharth 2026-10-22, critic idea): no top knob, so the prop reads the same after the flip."""
    keep = []
    for o in hg_A():
        if o.name.startswith("knob"):
            bpy.data.objects.remove(o, do_unlink=True)
        else:
            keep.append(o)
    return keep


def hg_F():
    """D, symmetric with no extra blue (Siddharth 2026-10-22, critic ideas): the same wide step on both caps, dark diamond
    insets above and below on every post (wood_dark, not blue: the sand is the only blue), no front gem."""
    p = caps(0.046, Z0) + [vp.cyl("step", 0.050, 0.004, (0, 0, 0), GOLD, 12),
                           vp.cyl("step", 0.050, 0.004, (0, 0, Z0 * 2 + GH - 0.004), GOLD, 12)]
    for a in (45, 135, 225, 315):
        ar = math.radians(a)
        x, y = 0.042 * math.cos(ar), 0.042 * math.sin(ar)
        p.append(vp.cyl("post", 0.0034, GH, (x, y, Z0), GOLD, 6))
        for z in (Z0 + 0.034, Z0 + GH - 0.034):
            p.append(vp.tbox("inset", (0.0060, 0.0060, 0.0060), (x * 1.06, y * 1.06, z), DARK, 45, 0, a))  # turned about the outward axis: the diamond faces out
    for z in (0.030, 0.100):
        r = glass_r(z) + 0.0015
        p.append(lathe("band", [(r, z - 0.0025), (r + 0.0045, z - 0.0025), (r + 0.0045, z + 0.0025), (r, z + 0.0025), (r, z - 0.0025)],
                       GOLD, 12, cap_bottom=False, cap_top=False))  # 4.5 mm deep so the ring reaches into the posts
    return p


VARIANTS = {"A": hg_A, "B": hg_B, "C": hg_C, "D": hg_D, "E": hg_E, "F": hg_F}


def tris(objs):
    return sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)


def build(letter, ver="v01"):
    bc.clear_scene()
    name = "ew_vfx_rewind_hourglass_%s" % ver
    frame = VARIANTS[letter]()
    top, bottom = sand()
    neck = (0, 0, Z0 + GH / 2)
    root = bc.assemble(name, [("", frame, (0, 0, 0), None, False),  # unbevelled: 1k budget for the whole hourglass
                              ("glass", glass(), neck, "", False),
                              ("sand_top", [top], (0, 0, Z0 + 0.067), "", False),
                              ("sand_bottom", [bottom], (0, 0, Z0 + 0.003), "", False)])
    bc.anchor(root, "stream_anchor", neck, size=0.012)
    bc.anchor(root, "glow_anchor", neck, size=0.16)
    root["ew_place"] = "board_event"
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    zs = [(o.matrix_world @ v.co).z for o in objs for v in o.data.vertices]
    print("%s %s: %d tris, height %.0f mm" % (name, letter, tris(objs), (max(zs) - min(zs)) * 1000))
    return root


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if args and args[0] == "FINAL":
        obj = build(args[1], args[2])
        bc.save_blend(obj, "rewind_hourglass")
        print("EXPORT", bc.export_glb(obj, "vfx"))
    else:
        obj = build(args[0])
        bc.save_blend(obj, "rewind_hourglass_" + args[0])
