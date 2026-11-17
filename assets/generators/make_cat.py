"""Chunky ginger cat for quest 'Save the cat' (pinch the cat off a roof and set it down by its owner).
Toy-like like the villagers (~1 cell long, ~30-42 mm tall), flat-shaded, palette colours only.
Assembled via bc.assemble() into separate moving parts (no rig):
    root (body + hind legs + paws at z = 0)  __head  __tail  __leg_l  __leg_r
Front is -Y (glTF +Z), cat's left is +X (_l), right is -X (_r), +Z is up in Blender (+Y in glTF).

Run one variant: blender --factory-startup -b -P assets/generators/make_cat.py -- A  (A-D)
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "tools"))
sys.path.insert(0, HERE)
import blender_common as bc  # noqa: E402
import bmesh  # noqa: E402
import bpy  # noqa: E402
import make_village_props as vp  # noqa: E402
from mathutils import Vector  # noqa: E402

K = 0.001


def nb(o):
    o["no_bevel"] = True
    return o


def bx(name, size, loc, col, rx=0.0, ry=0.0, rz=0.0):
    return nb(vp.tbox(name, tuple(s * K for s in size), tuple(l * K for l in loc), col, rx, ry, rz))


def bl(name, r, loc, col, squash=(1, 1, 1), sub=1, rx=0.0, ry=0.0, rz=0.0):
    o = nb(bc.blob(name, r * K, (0, 0, 0), col, sub, squash))
    return vp.tilted(o, tuple(l * K for l in loc), rx, ry, rz)


def cy(name, r0, r1, h, loc, col, seg=8, rx=0.0, ry=0.0, rz=0.0):
    return nb(vp.tcyl(name, r0 * K, h * K, tuple(l * K for l in loc), col, seg, rx, ry, rz, r1 * K))


def seg_tube(name, pts_mm, radii_mm, col, seg=8, tip_col=None):
    """Chunky faceted cat tail / limb tube from a list of 3D points (mm) and radii (mm)."""
    parts = []
    for i in range(len(pts_mm) - 1):
        p0, p1 = Vector([c * K for c in pts_mm[i]]), Vector([c * K for c in pts_mm[i + 1]])
        d = p1 - p0
        o = bc.cone(name, radii_mm[i] * K, max(radii_mm[i + 1], 0.4) * K, d.length, (0, 0, 0), col, seg)
        o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        o.location = (p0 + p1) / 2.0
        bc.apply_transforms(o)
        parts.append(nb(o))
        if i > 0:
            parts.append(nb(bc.blob(name + "_j", radii_mm[i] * 1.03 * K, tuple(p0), col, 1)))
    if tip_col:
        parts.append(nb(bc.blob(name + "_tip", max(radii_mm[-1], 1.2) * K, tuple(c * K for c in pts_mm[-1]), tip_col, 1)))
    return parts


def ear_cone(name, bx_mm, by_mm, bz_mm, tip_dx, tip_dy, tip_dz, r_mm, col, inn="flower_pink"):
    """Pointed pyramid/cone cat ear plus smaller inner pink ear liner facing -Y."""
    p0 = Vector((bx_mm * K, by_mm * K, bz_mm * K))
    p1 = Vector(((bx_mm + tip_dx) * K, (by_mm + tip_dy) * K, (bz_mm + tip_dz) * K))
    d = p1 - p0
    outer = bc.cone(name, r_mm * K, 0.25 * K, d.length, (0, 0, 0), col, 4, 45.0)
    outer.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    outer.location = (p0 + p1) / 2.0
    bc.apply_transforms(outer)
    nb(outer)
    ip0 = p0 + Vector((0, -0.75 * r_mm * 0.45 * K, 0.8 * K))
    ip1 = p1 + Vector((-0.25 * tip_dx * K, -0.9 * K, -1.6 * K))
    id_v = ip1 - ip0
    inner = bc.cone(name + "_in", r_mm * 0.56 * K, 0.18 * K, id_v.length, (0, 0, 0), inn, 4, 45.0)
    inner.rotation_euler = id_v.to_track_quat("Z", "Y").to_euler()
    inner.location = (ip0 + ip1) / 2.0
    bc.apply_transforms(inner)
    nb(inner)
    return [outer, inner]


def cat_face(cx, cy_f, cz, hr, main_col, cheek_col="wall_cream", ear_size=4.0, stripe_col="roof_terracotta", tuft=False):
    """Chubby toy cat head around (cx, cy_f, cz) mm: sub-1 skull, cheeks, nose, ink eyes, ears, tabby brow ticks."""
    p = [bl("skull", hr, (cx, cy_f, cz), main_col, (1.14, 0.96, 0.90), sub=2)]
    # wide cheeks and puff muzzle on -Y front
    mz_y = cy_f - hr * 0.82
    p.append(bl("cheek_l", hr * 0.34, (cx + hr * 0.30, mz_y, cz - hr * 0.20), cheek_col, (1.1, 0.85, 0.85), sub=1))
    p.append(bl("cheek_r", hr * 0.34, (cx - hr * 0.30, mz_y, cz - hr * 0.20), cheek_col, (1.1, 0.85, 0.85), sub=1))
    p.append(bl("nose", hr * 0.16, (cx, mz_y - hr * 0.14, cz - hr * 0.04), "flower_pink", (1.2, 0.9, 0.8), sub=1))
    # chunky expressive ink eyes
    ey = cy_f - hr * 0.80
    for sx in (-1, 1):
        p.append(bl("eye", hr * 0.17, (cx + sx * hr * 0.42, ey, cz + hr * 0.14), "ink", (0.85, 0.6, 1.15), sub=1))
    # tabby markings on brow & cheeks
    p.append(bx("brow_c", (1.4, 2.8, 1.1), (cx, cy_f - hr * 0.45, cz + hr * 0.72), stripe_col, rx=22))
    for sx in (-1, 1):
        p.append(bx("brow_s", (1.2, 2.4, 1.0), (cx + sx * hr * 0.28, cy_f - hr * 0.42, cz + hr * 0.68), stripe_col, rx=20, rz=sx * 16))
        p.append(bx("whisk", (2.2, 0.7, 0.7), (cx + sx * hr * 0.56, mz_y - 0.15, cz - hr * 0.20), stripe_col, rz=sx * 10))
    # pointed triangular cat ears
    for sx in (-1, 1):
        p += ear_cone("ear", cx + sx * hr * 0.56, cy_f - hr * 0.05, cz + hr * 0.68,
                      sx * ear_size * 0.65, -0.8, ear_size * 1.45, ear_size, main_col)
        if tuft:
            p.append(bl("ear_tuft", 1.3, (cx + sx * (hr * 0.56 + ear_size * 0.62), cy_f - hr * 0.05 - 0.7, cz + hr * 0.68 + ear_size * 1.40), "wood_dark", (0.8, 0.8, 1.4), sub=1))
    return p


def paw(name, px, py, pr=2.6, col="wall_cream"):
    """Plump paw sitting cleanly at z = 0."""
    return [bl(name, pr, (px, py, pr * 0.68), col, (1.05, 1.25, 0.68), sub=1)]


# ------------------------------------------------------------------ Variants A-D
def variant_A():
    """Polite seated ginger tabby with cream chest bib, mittens, teal collar & brass bell, curled side tail."""
    root = [
        bl("torso", 10.5, (0, 2.0, 10.2), "hair_ginger", (0.98, 1.12, 1.08), sub=2, rx=16),
        bl("haunch_l", 5.8, (6.2, 7.0, 5.4), "hair_ginger", (0.85, 1.15, 0.95), sub=1),
        bl("haunch_r", 5.8, (-6.2, 7.0, 5.4), "hair_ginger", (0.85, 1.15, 0.95), sub=1),
        bl("bib", 6.2, (0, -4.6, 11.4), "wall_cream", (0.95, 0.68, 1.15), sub=1),
        bx("stripe_bk1", (6.5, 2.6, 2.2), (0, 6.4, 15.4), "roof_terracotta", rx=-15),
        bx("stripe_bk2", (5.8, 2.4, 2.0), (0, 9.2, 11.6), "roof_terracotta", rx=-35),
        # collar & bell
        cy("collar", 6.8, 6.2, 2.8, (0, -1.6, 19.6), "roof_teal", 10, rx=18),
        bl("bell", 2.2, (0, -7.8, 18.2), "shell_gold", (1.0, 1.0, 1.0), sub=1),
    ] + paw("hpaw_l", 6.5, 4.0, 2.8, "wall_cream") + paw("hpaw_r", -6.5, 4.0, 2.8, "wall_cream")
    head = cat_face(0.0, -3.0, 27.6, 9.8, "hair_ginger", "wall_cream", 4.2, "roof_terracotta")
    leg_l = [cy("arm_l", 2.8, 2.3, 12.2, (4.2, -5.8, 7.6), "hair_ginger", 8, rx=-10)] + paw("fpaw_l", 4.2, -7.2, 2.6, "wall_cream")
    leg_r = [cy("arm_r", 2.8, 2.3, 12.2, (-4.2, -5.8, 7.6), "hair_ginger", 8, rx=-10)] + paw("fpaw_r", -4.2, -7.2, 2.6, "wall_cream")
    tail = seg_tube("tail", [(0, 11.5, 4.8), (5.5, 16.0, 5.8), (11.2, 14.5, 9.8), (12.8, 9.5, 15.0)], [3.0, 2.8, 2.5, 2.1], "hair_ginger", 8, "wall_cream")
    return [("", root, (0, 0, 0), None),
            ("head", head, (0.0, -2.5 * K, 21.0 * K), ""),
            ("leg_l", leg_l, (4.2 * K, -4.6 * K, 13.5 * K), ""),
            ("leg_r", leg_r, (-4.2 * K, -4.6 * K, 13.5 * K), ""),
            ("tail", tail, (0.0, 11.5 * K, 4.8 * K), "")]


def variant_B():
    """Playful pouncing kitten: low chest crouch in front, high playful rump, wide ears, upright S-tail."""
    root = [
        bl("torso", 10.0, (0, 3.5, 11.6), "hair_ginger", (0.94, 1.48, 0.96), sub=2, rx=-20),
        bl("rump", 8.2, (0, 12.0, 14.2), "hair_ginger", (1.02, 0.95, 1.02), sub=1),
        bx("bstripe1", (7.4, 2.4, 2.2), (0, 3.0, 19.6), "wood_dark", rx=-15),
        bx("bstripe2", (7.6, 2.4, 2.2), (0, 8.8, 21.2), "wood_dark", rx=-22),
        cy("hleg_l", 3.4, 2.5, 12.2, (5.8, 12.6, 7.2), "roof_orange", 8, rx=10),
        cy("hleg_r", 3.4, 2.5, 12.2, (-5.8, 12.6, 7.2), "roof_orange", 8, rx=10),
    ] + paw("hpaw_l", 6.0, 13.0, 2.8, "wall_cream") + paw("hpaw_r", -6.0, 13.0, 2.8, "wall_cream")
    head = cat_face(0.0, -10.0, 15.6, 9.6, "hair_ginger", "wall_cream", 4.6, "wood_dark")
    leg_l = [cy("arm_l", 2.7, 2.2, 9.4, (4.8, -11.5, 4.5), "roof_orange", 8, rx=-42)] + paw("fpaw_l", 5.2, -16.8, 2.6, "wall_cream")
    leg_r = [cy("arm_r", 2.7, 2.2, 9.4, (-4.8, -11.5, 4.5), "roof_orange", 8, rx=-42)] + paw("fpaw_r", -5.2, -16.8, 2.6, "wall_cream")
    tail = seg_tube("tail", [(0, 18.8, 17.0), (0, 22.8, 23.0), (2.2, 22.0, 29.8), (-1.4, 18.6, 33.8)], [2.8, 2.6, 2.3, 1.8], "roof_orange", 8, "wall_cream")
    return [("", root, (0, 0, 0), None),
            ("head", head, (0.0, -7.2 * K, 11.2 * K), ""),
            ("leg_l", leg_l, (4.8 * K, -8.0 * K, 7.5 * K), ""),
            ("leg_r", leg_r, (-4.8 * K, -8.0 * K, 7.5 * K), ""),
            ("tail", tail, (0.0, 18.8 * K, 17.0 * K), "")]


def variant_C():
    """Chonky marmalade barrel cat: wide cozy body, white tuxedo bib & slippers, thick striped bush tail."""
    root = [
        bl("torso", 13.0, (0, 3.0, 12.2), "roof_orange", (1.06, 1.24, 0.92), sub=2, rx=6),
        bl("belly_bib", 7.6, (0, -8.2, 10.4), "wall_cream", (0.95, 0.65, 1.05), sub=1),
        bx("saddle1", (11.5, 3.4, 2.4), (0, 0.5, 22.6), "roof_terracotta"),
        bx("saddle2", (12.0, 3.4, 2.4), (0, 6.0, 22.4), "roof_terracotta"),
        cy("hleg_l", 3.9, 3.1, 8.0, (8.2, 8.8, 4.6), "roof_orange", 8),
        cy("hleg_r", 3.9, 3.1, 8.0, (-8.2, 8.8, 4.6), "roof_orange", 8),
    ] + paw("hpaw_l", 8.2, 7.8, 3.2, "wall_cream") + paw("hpaw_r", -8.2, 7.8, 3.2, "wall_cream")
    head = cat_face(0.0, -7.6, 23.8, 10.6, "roof_orange", "wall_cream", 3.8, "roof_terracotta")
    leg_l = [cy("arm_l", 3.3, 2.8, 9.0, (6.4, -7.4, 5.2), "roof_orange", 8)] + paw("fpaw_l", 6.4, -9.2, 3.0, "wall_cream")
    leg_r = [cy("arm_r", 3.3, 2.8, 9.0, (-6.4, -7.4, 5.2), "roof_orange", 8)] + paw("fpaw_r", -6.4, -9.2, 3.0, "wall_cream")
    tail = seg_tube("tail", [(0, 15.6, 9.0), (0, 22.0, 11.4), (0, 25.0, 17.5), (0, 22.5, 24.5)], [4.2, 4.6, 4.2, 3.2], "hair_ginger", 8, "wall_cream")
    tail.append(bl("tail_ring", 4.6, (0, 24.4, 15.4), "roof_terracotta", (0.95, 0.95, 0.55), sub=1))
    return [("", root, (0, 0, 0), None),
            ("head", head, (0.0, -5.0 * K, 18.0 * K), ""),
            ("leg_l", leg_l, (6.4 * K, -7.0 * K, 9.8 * K), ""),
            ("leg_r", leg_r, (-6.4 * K, -7.0 * K, 9.8 * K), ""),
            ("tail", tail, (0.0, 15.6 * K, 9.0 * K), "")]


def variant_D():
    """Arched rooftop tabby: tall perched stance, curved arched spine with tufts, lynx ear tips, red bandana."""
    root = [
        bl("torso", 9.8, (0, 4.0, 16.5), "hair_ginger", (0.84, 1.38, 1.12), sub=2, rx=10),
        bl("crest1", 3.2, (0, 2.0, 25.8), "roof_terracotta", (0.7, 1.4, 1.1), sub=1),
        bl("crest2", 3.0, (0, 8.5, 25.2), "roof_terracotta", (0.7, 1.4, 1.1), sub=1),
        bx("bandana", (10.2, 4.2, 4.4), (0, -5.8, 15.6), "fire_red", rx=24),
        bx("bandana_pt", (5.6, 2.2, 5.2), (0, -7.4, 12.6), "fire_red", rx=15, rz=45),
        cy("hleg_l", 2.9, 2.2, 13.0, (5.2, 11.2, 6.8), "hair_ginger", 8),
        cy("hleg_r", 2.9, 2.2, 13.0, (-5.2, 11.2, 6.8), "hair_ginger", 8),
    ] + paw("hpaw_l", 5.2, 10.2, 2.6, "wall_cream") + paw("hpaw_r", -5.2, 10.2, 2.6, "wall_cream")
    head = cat_face(0.0, -7.2, 24.4, 9.2, "hair_ginger", "wall_cream", 4.4, "wood_dark", tuft=True)
    leg_l = [cy("arm_l", 2.7, 2.1, 13.0, (4.8, -5.2, 6.8), "hair_ginger", 8)] + paw("fpaw_l", 4.8, -6.2, 2.6, "wall_cream")
    leg_r = [cy("arm_r", 2.7, 2.1, 13.0, (-4.8, -5.2, 6.8), "hair_ginger", 8)] + paw("fpaw_r", -4.8, -6.2, 2.6, "wall_cream")
    tail = seg_tube("tail", [(0, 14.5, 16.5), (0, 17.5, 24.0), (0, 17.5, 32.5), (0, 15.2, 38.0)], [3.2, 3.8, 3.6, 2.4], "roof_terracotta", 8, "hair_ginger")
    return [("", root, (0, 0, 0), None),
            ("head", head, (0.0, -5.2 * K, 19.0 * K), ""),
            ("leg_l", leg_l, (4.8 * K, -5.2 * K, 13.0 * K), ""),
            ("leg_r", leg_r, (-4.8 * K, -5.2 * K, 13.0 * K), ""),
            ("tail", tail, (0.0, 14.5 * K, 16.5 * K), "")]


VARIANTS = {
    "A": ("Seated ginger loaf: white bib and mittens, teal collar with brass bell, curled tail", variant_A),
    "B": ("Playful pounce kitten: low chest crouch, high rump, wide ears, upright S-tail", variant_B),
    "C": ("Chonky marmalade barrel: wide belly, tuxedo bib, ringed fat tail", variant_C),
    "D": ("Arched rooftop cat: perched tall legs, arched spine, lynx ear tufts, red bandana", variant_D),
}


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["A"]
    L = "A" if args[0] == "FINAL" else (args[0] if args[0] in VARIANTS else "A")
    bc.clear_scene()
    groups = VARIANTS[L][1]()
    V2 = "V02" in sys.argv   # 2026-11-18 fix G: same design x1.7 (hard to see and pinch at 21 mm)
    VER = "v02" if V2 else "v01"
    root = bc.assemble("ew_village_cat_" + VER, groups, bevel_min=0.004)
    root["ew_footprint"], root["ew_front"], root["ew_place"] = "1x1", "-Y", "roof"
    bpy.context.view_layer.update()
    # verify whole assembly min z = 0 across true world vertices
    objs = [root] + list(root.children_recursive)
    zs = [(o.matrix_world @ v.co).z for o in objs if o.type == "MESH" for v in o.data.vertices]
    if zs and abs(min(zs)) > 1e-4:
        shift = min(zs)
        for v in root.data.vertices:
            v.co.z -= shift
        for c in root.children:
            c.location.z -= shift
        bpy.context.view_layer.update()
    if V2:
        S = 1.7
        for o in objs:
            if o.type == "MESH":
                for v in o.data.vertices:
                    v.co *= S
            if o is not root:
                o.location *= S
        bpy.context.view_layer.update()
    total = sum(tris(o) for o in objs if o.type == "MESH")
    print("CAT %s: %d tris total, %.1f x %.1f x %.1f mm" % (L, total, *(d * 1000 for d in root.dimensions)))
    for c in [root] + list(root.children):
        if c.type == "MESH":
            print("  %s: %d tris" % (c.name, tris(c)))
    if "FINAL" in sys.argv:   # variant A as the real asset: blend `cat` (not cat_A), exported to assets/export/village
        print("BLEND", bc.save_blend(root, "cat_v02" if V2 else "cat"))
        print("EXPORT", bc.export_glb(root, "village"))
    else:
        print("BLEND", bc.save_blend(root, "cat_" + L))
