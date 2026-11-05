"""Creature characters, round 2 (Durva, 2026-11-01): villagers, wizard, witch, soldier, archer, goblin.

Run one:  blender --factory-startup -b -P assets/generators/make_characters.py -- <key>
  (saves assets/blend/char_<key>.blend; keys are listed in CHARACTERS)

Round 1 (make_character_kit.py) was rejected as too plain: round 2 gives every character its own animal or
insect trait (horns, antennae, wings, tails, fox/cat/deer ears) and bolder colours, and is a little smoother
(smooth shading on rounded forms, crisp edges only where the angle is sharp).
Shape language only from the user's pixel-art sheet; every design is original. Colours: art/palette.json names.

Front is -Y (glTF +Z). The character's RIGHT hand is on -X (suffix _r), left on +X (_l).
Moving parts (no rig; each pivots where Godot rotates it):
  root (body, legs, boots)  __head  __hair_back  __arm_l/_r (+hand)  __item (held, child of arm_r)
  __ear_l/_r  __ant_l/_r (antennae)  __wing_l/_r  __tail  __hat
"""
import math
import os
import sys

import bpy
import bmesh
import mathutils

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import blender_common as bc  # noqa: E402

_blob_orig = bc.blob


def _blob_nobevel(name, radius, loc, col, subdiv=1, squash=(1, 1, 1)):
    """Small 20-triangle balls (hair puffs, joints, fringe) are not bevelled: the bevel pass inflates each to ~200 triangles."""
    o = _blob_orig(name, radius, loc, col, subdiv, squash)
    if subdiv <= 1:
        o["no_bevel"] = True
    return o


bc.blob = _blob_nobevel

def V(*a):
    """Vector from V(x, y, z) or V((x, y, z))."""
    return mathutils.Vector(a[0] if len(a) == 1 else a)


# ---------------------------------------------------------------- geometry helpers
def seg(name, p0, p1, r0, r1, col, segs=10):
    """Cone/cylinder from p0 (radius r0) to p1 (radius r1), any direction."""
    p0, p1 = V(p0), V(p1)
    d = p1 - p0
    o = bc.cone(name, r0, max(r1, 0.00001), d.length, (0, 0, 0), col, segs)
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    o.location = (p0 + p1) / 2
    bc.apply_transforms(o)
    o["no_bevel"] = True
    return o


def chain(name, pts, radii, col, segs=10, ball_tip=None, joints=True):
    """A bendy tube through points (horn, antenna, tail): cones plus a ball at each joint."""
    out = []
    for i in range(len(pts) - 1):
        out.append(seg(name, pts[i], pts[i + 1], radii[i], radii[i + 1], col, segs))
        if i > 0 and joints:
            b = bc.blob(name + "_j", radii[i] * 1.02, pts[i], col, 1)
            b["no_bevel"] = True
            out.append(b)
    if ball_tip:
        b = bc.blob(name + "_tip", ball_tip[0], pts[-1], ball_tip[1], 1)
        b["no_bevel"] = True
        out.append(b)
    return out


def flat(name, pts3, thick, col, normal_axis="y"):
    """A thin flat shape (wing, star): polygon points 3D, extruded `thick` along normal_axis."""
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts3]
    f = bm.faces.new(vs)
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    off = {"y": (0, thick, 0), "x": (thick, 0, 0), "z": (0, 0, thick)}[normal_axis]
    bmesh.ops.translate(bm, vec=off, verts=[v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = bc._new_obj(name, bm)
    bc.paint(o, col)
    o["no_bevel"] = True
    return o


def ell_y(rx, ry, rz, x, z):
    t = 1 - (x / rx) ** 2 - (z / rz) ** 2
    return -ry * math.sqrt(max(t, 0.0))


# ---------------------------------------------------------------- the body kit (doll proportions, per-character overrides)
BASE = dict(head_r=0.0140, squash=(1.06, 0.96, 0.92), leg=0.0085, body_h=0.0125, body_r=0.0058, body="cone",
            hands="mitten", arm_len=0.0095, skin="skin_light", hair=None, hair_style=None, top="roof_teal",
            bottom="wall_cream", boots="wood_dark", scarf=None, eyes="ink", cheeks="flower_pink",
            ears="round", ear_col=None, ear_in=None, horns=None, ants=None, wings=None, tail=None, hat=None,
            item=None, extras=(), beard=None, spider=None, crown=False, apron=None, overalls=None, mane=False)



def place(o, rot, loc):
    """Rotate a part built at the origin (degrees), then move it to loc."""
    bc.rotate(o, rot)
    o.location = loc
    bc.apply_transforms(o)
    return o


def beard_parts(c, hz):
    r, sx, sy, sz, rx, ry, rz = head_geom(c)
    col = c["beard"]
    P = []
    for x, z, rr in ((0, -0.58, 0.42), (-0.40, -0.52, 0.32), (0.40, -0.52, 0.32), (0, -0.92, 0.38)):
        y = ell_y(rx, ry, rz, x * rx, z * rz) - r * 0.06
        P.append(bc.blob("beard", r * rr, (x * rx, y, hz + z * rz), col, 1, (1.0, 0.85, 1.0)))
    P.append(bc.blob("stache", r * 0.30, (0, ell_y(rx, ry, rz, 0, -rz * 0.36) - r * 0.10, hz - rz * 0.36), col, 1, (2.6, 0.6, 0.7)))
    return P


def glasses_parts(c, hz):
    r, sx, sy, sz, rx, ry, rz = head_geom(c)
    ex, ez = rx * 0.44, -rz * 0.14
    y = ell_y(rx, ry, rz, ex, ez) - r * 0.14
    P = []
    for s_ in (-1, 1):
        cx, cz = s_ * ex, hz + ez
        pts = [(cx + math.cos(math.radians(a)) * r * 0.31, y, cz + math.sin(math.radians(a)) * r * 0.36) for a in range(0, 360, 45)]
        for i in range(8):
            P.append(seg("rim", pts[i], pts[(i + 1) % 8], r * 0.035, r * 0.035, "wood_dark", 4))
    P.append(seg("bridge", (-ex + r * 0.31, y, hz + ez + r * 0.04), (ex - r * 0.31, y, hz + ez + r * 0.04), r * 0.03, r * 0.03, "wood_dark", 4))
    return P


def crown_parts(c, hz):
    r, sx, sy, sz, rx, ry, rz = head_geom(c)
    P = []
    cols = ("flower_pink", "flower_yellow", "wall_cream", "flower_pink", "flower_yellow", "wall_cream", "flower_pink", "flower_yellow")
    for i in range(5):
        a = math.radians(i * 72 + 22)
        P.append(bc.blob("flower", r * 0.17, (math.cos(a) * rx * 0.84, math.sin(a) * ry * 0.80 + r * 0.04, hz + rz * 0.62), cols[i], 1, (1, 1, 0.8)))
    return P


def mane_parts(c, hz):
    r, sx, sy, sz, rx, ry, rz = head_geom(c)
    col = c["hair"] or "hair_brown"
    return [bc.blob("mane", r * (0.30 - 0.02 * i), (0, ry * (0.10 + 0.20 * i), hz + rz * (0.98 - 0.22 * i)), col, 1, (0.8, 1.0, 1.0)) for i in range(5)]


def spider_legs(c, neck, br):
    col = c["spider"]
    P = []
    for s_ in (-1, 1):
        for j in range(4):
            b = V((s_ * br * 0.45, br * 0.9 + 0.0006 * j, neck - 0.0030 - 0.0016 * j))
            f = 1.0 + 0.16 * j
            pts = [b, b + V((s_ * 0.0050 * f, 0.0040 + 0.0008 * j, 0.0100)), b + V((s_ * 0.0150 * f, 0.0045 + 0.0010 * j, 0.0135)),
                   b + V((s_ * 0.0235 * f, 0.0040 + 0.0012 * j, 0.0030 - 0.0014 * j)), b + V((s_ * 0.0270 * f, 0.0035 + 0.0012 * j, -0.0090 - 0.0018 * j))]
            P += chain("sleg", pts, [0.0017, 0.0015, 0.0013, 0.0010, 0.0003], col, 4, joints=False)
    return P


def web_parts(c, neck):
    """A vertical spider web behind the tailor: 10 spokes and 3 rings, plus a thread that dangles."""
    cx, cy, cz, R = 0.0, 0.0215, neck + 0.0090, 0.0340
    P = []
    for i in range(8):
        a = math.radians(i * 45)
        P.append(seg("spoke", (cx, cy, cz), (cx + math.cos(a) * R, cy, cz + math.sin(a) * R), 0.00045, 0.00035, "bone", 4))
    for rr in (0.5, 1.0):
        for i in range(8):
            a0, a1 = math.radians(i * 45), math.radians((i + 1) * 45)
            sag = 0.93 if rr < 1.0 else 1.0
            P.append(seg("ring", (cx + math.cos(a0) * R * rr, cy, cz + math.sin(a0) * R * rr), (cx + math.cos(a1) * R * rr * sag, cy, cz + math.sin(a1) * R * rr * sag), 0.00040, 0.00040, "bone", 4))
    P.append(seg("thread", (cx, cy, cz + R), (cx + 0.0010, cy - 0.0010, cz + R + 0.0120), 0.00035, 0.00035, "bone", 4))
    return P, V((cx, cy, cz))


def horiz(hx, hz_, half, rad, col, endcol=None, name="roll"):
    """A horizontal cylinder (scroll, rolling pin) across the hand."""
    P = [seg(name, (hx - half, 0, hz_), (hx + half, 0, hz_), rad, rad, col, 10)]
    if endcol:
        for s_ in (-1, 1):
            P.append(seg(name + "_end", (hx + s_ * half, 0, hz_), (hx + s_ * (half + 0.0016), 0, hz_), rad * 0.55, rad * 0.55, endcol, 8))
    return P



def head_geom(c):
    r = c["head_r"]
    sx, sy, sz = c["squash"]
    return r, sx, sy, sz, r * sx, r * sy, r * sz


def build_head(c, hz):
    r, sx, sy, sz, rx, ry, rz = head_geom(c)
    P = [bc.blob("skull", r, (0, 0, hz), c["skin"], 2, (sx, sy, sz))]
    ex, ez = rx * 0.44, -rz * 0.14
    for s in (-1, 1):
        y = ell_y(rx, ry, rz, ex, ez)
        P.append(bc.blob("eye", r * 0.21, (s * ex, y + r * 0.03, hz + ez), c["eyes"], 1, (0.85, 0.5, 1.3)))
        P.append(bc.box("sparkle", (r * 0.09, r * 0.05, r * 0.09), (s * ex + r * 0.04, y - r * 0.06, hz + ez + r * 0.10), "bone", rot_z_deg=45))
        cy = ell_y(rx, ry, rz, s * rx * 0.66, -rz * 0.36)
        P.append(place(bc.cone("cheek", r * 0.12, r * 0.12, r * 0.035, (0, 0, 0), c["cheeks"], 6), (90, 0, 0), (s * rx * 0.66, cy + r * 0.0, hz - rz * 0.36)))
    if c["ears"] == "round":
        for s in (-1, 1):
            P.append(bc.blob("ear", r * 0.20, (s * rx * 0.98, 0, hz - rz * 0.08), c["skin"], 1, (0.55, 0.8, 1.0)))
    elif c["ears"] == "goblin":
        for s in (-1, 1):
            P += chain("gear", [(s * rx * 0.9, r * 0.05, hz + rz * 0.05), (s * rx * 1.5, r * 0.15, hz + rz * 0.30),
                                (s * rx * 2.15, r * 0.20, hz + rz * 0.62)], [r * 0.30, r * 0.20, r * 0.02], c["skin"], 5)
    # mouth: a tiny smile line for the friendlier characters (a cheek-level ink sliver)
    if c.get("smile", True):
        my = ell_y(rx, ry, rz, 0, -rz * 0.50)
        P.append(bc.box("smile", (r * 0.20, r * 0.04, r * 0.05), (0, my - r * 0.005, hz - rz * 0.50), "wood_dark"))
    for tusk in c["extras"]:
        if tusk == "tusks":
            for s in (-1, 1):
                ty = ell_y(rx, ry, rz, s * rx * 0.22, -rz * 0.55)
                t = seg("tusk", (s * rx * 0.22, ty, hz - rz * 0.50), (s * rx * 0.26, ty - r * 0.12, hz - rz * 0.20),
                        r * 0.075, 0.0, "bone", 5)
                P.append(t)
    if c["beard"]:
        P += beard_parts(c, hz)
    if "glasses" in c["extras"]:
        P += glasses_parts(c, hz)
    if c["crown"]:
        P += crown_parts(c, hz)
    if c["mane"]:
        P += mane_parts(c, hz)
    if "eyes4" in c["extras"]:  # spider: a second pair of small eyes above the first
        for s_ in (-1, 1):
            yy = ell_y(rx, ry, rz, s_ * rx * 0.30, rz * 0.20)
            P.append(bc.blob("eye2", r * 0.09, (s_ * rx * 0.30, yy + r * 0.02, hz + rz * 0.20), c["eyes"], 1, (0.9, 0.6, 1.1)))
    if "sprout" in c["extras"]:  # a little leaf sprout on top
        top = V((0, r * 0.12, hz + r * 1.16))
        P += chain("stem", [top, top + V(0, 0, r * 0.28), top + V(r * 0.05, -r * 0.03, r * 0.50)], [r * 0.05, r * 0.04, r * 0.03], "leaf_green", 6)
        for s_ in (-1, 1):
            P.append(bc.blob("leaf", r * 0.25, top + V(s_ * r * 0.22, -r * 0.03, r * 0.52), "leaf_light", 1, (1.0, 0.25, 0.6)))
    # hair
    hc, hs = c["hair"], c["hair_style"]
    capped = bool(c["hat"]) and c["hat"][0] in ("hard", "clerkcap", "helm", "hood")
    if hc and hs in ("bob", "buns", "long", "spiky", "fluff", "tails", "flow") and not capped:
        P.append(bc.blob("hair_cap", r * 1.07, (0, r * 0.20, hz + r * 0.24), hc, 2, (sx, sy * 1.02, sz * 0.98)))
        for i, fx in enumerate((-0.50, 0.0, 0.50)):
            fz = hz + rz * 0.60 - (0.06 if i == 1 else 0.0) * r
            fy = ell_y(rx, ry, rz, fx * rx, fz - hz) - r * 0.015
            P.append(bc.blob("fringe", r * 0.26, (fx * rx, fy, fz), hc, 1, (1.1, 0.55, 0.9)))
    if hc and hs in ("bob", "long", "tails", "flow"):
        for s in (-1, 1):
            P.append(bc.blob("lock", r * 0.28, (s * rx * 0.92, r * 0.12, hz - rz * 0.14), hc, 1, (0.7, 1.0, 1.7)))
    if hc and hs == "buns":
        for s in (-1, 1):
            P.append(bc.blob("bun", r * 0.34, (s * rx * 0.72, r * 0.05, hz + rz * 1.05), hc, 2))
    if hc and hs == "fluff":  # soft puffy tufts all round (bee / moth)
        for a in range(0, 360, 60):
            x, y = math.cos(math.radians(a)), math.sin(math.radians(a))
            P.append(bc.blob("puff", r * 0.30, (x * rx * 0.92, y * ry * 0.55 + r * 0.25, hz + rz * 0.72), hc, 1))
    if hc and hs == "spiky":
        for i in range(6):
            a = math.radians(i * 60 + 20)
            top = (rx * 0.5 * math.cos(a), ry * 0.5 * math.sin(a) + r * 0.2, hz + rz * 0.92)
            P.append(seg("spike", top, (top[0] * 1.35, top[1] * 1.35, top[2] + r * 0.50), r * 0.20, 0.0, hc, 5))
    if hc and hs == "tails":  # twin tails live in hair_back's group
        pass
    return P


def hair_back(c, hz):
    r, sx, sy, sz, rx, ry, rz = head_geom(c)
    hc, hs = c["hair"], c["hair_style"]
    out = []
    if not hc:
        return out
    if hs == "flow":  # very long hair down the back, nearly to the floor
        out.append(bc.blob("hair_back", r * 0.95, (0, ry * 0.80, hz - rz * 0.40), hc, 2, (1.15 * sx, 0.45, 1.65)))
        for s_ in (-1, 1):  # long locks falling down both sides, to the hip
            out += chain("lock", [V((s_ * rx * 0.90, -r * 0.05, hz - rz * 0.1)), V((s_ * rx * 1.12, 0.0, hz - rz * 0.85)),
                                  V((s_ * rx * 1.20, 0.0, hz - rz * 1.7)), V((s_ * rx * 1.05, 0.0, 0.0065))], [r * 0.30, r * 0.28, r * 0.22, r * 0.04], hc, 6)
    if hs in ("long", "bob"):
        drop = r * (1.5 if hs == "long" else 0.85)
        out.append(bc.blob("hair_back", r * 0.9, (0, ry * 0.78, hz - rz * 0.25 - drop * 0.25), hc, 2, (1.05 * sx, 0.55, 0.85 + drop / r * 0.45)))
    if hs == "tails":
        for s in (-1, 1):
            out += chain("tail", [(s * rx * 0.95, r * 0.2, hz + rz * 0.1), (s * rx * 1.25, r * 0.25, hz - rz * 0.6),
                                  (s * rx * 1.35, r * 0.3, hz - rz * 1.3), (s * rx * 1.15, r * 0.3, hz - rz * 2.0)], [r * 0.30, r * 0.28, r * 0.24, r * 0.05], hc, 8)
    return out


def hand(c, s, x, z):
    out = [bc.blob("hand", 0.0031, (x, 0, z), c["skin"], 1)]
    return out


# ---------------------------------------------------------------- creature features
def horns(c, hz):
    """Returns parts attached to the head."""
    r, sx, sy, sz, rx, ry, rz = head_geom(c)
    kind, col = c["horns"]
    out = []
    for s in (-1, 1):
        if kind == "ram":  # sideways curl
            base = V((s * rx * 0.55, -r * 0.05, hz + rz * 0.88))
            offs = [(0, 0), (0.32, 0.26), (0.66, 0.34), (0.98, 0.20), (1.12, -0.06), (0.98, -0.28)]
            rad = [0.20, 0.17, 0.14, 0.10, 0.06, 0.02]
            pts = [base + V((s * o[0] * r * 0.95, 0, o[1] * r * 0.95)) for o in offs]
            out += chain("horn", pts, [q * r for q in rad], col, 10)
        elif kind == "ram_s":  # shorter curl, fewer joints (cheaper): the village head
            base = V((s * rx * 0.55, -r * 0.05, hz + rz * 0.88))
            offs = [(0, 0), (0.42, 0.32), (0.92, 0.24), (1.02, -0.14)]
            rad = [0.20, 0.15, 0.09, 0.02]
            pts = [base + V((s * o[0] * r * 0.95, 0, o[1] * r * 0.95)) for o in offs]
            out += chain("horn", pts, [q * r for q in rad], col, 10)
        elif kind == "devil":
            base = V((s * rx * 0.50, -r * 0.1, hz + rz * 0.86))
            pts = [base, base + V((s * r * 0.20, 0.0, r * 0.45)), base + V((s * r * 0.30, r * 0.05, r * 0.92))]
            out += chain("horn", pts, [r * 0.17, r * 0.11, r * 0.01], col, 8)
        elif kind == "antler":
            base = V((s * rx * 0.45, r * 0.0, hz + rz * 0.88))
            tr = [base, base + V((s * r * 0.20, 0, r * 0.70)), base + V((s * r * 0.40, 0, r * 1.30))]
            out += chain("antler", tr, [r * 0.13, r * 0.10, r * 0.03], col, 6)
            out += chain("tine", [tr[1], tr[1] + V((s * r * 0.34, -r * 0.1, r * 0.34))], [r * 0.07, r * 0.015], col, 6)
            out += chain("tine", [tr[0] + V(s * r * 0.08, 0, r * 0.22), tr[0] + V(s * r * 0.52, 0.0, r * 0.62)], [r * 0.065, r * 0.015], col, 6)
    if kind == "beetle":  # one big forward horn with a prong
        base = V((0, -rx * 0.55, hz + rz * 0.85))
        pts = [base, base + V(0, -r * 0.35, r * 0.40), base + V(0, -r * 0.55, r * 0.95), base + V(0, -r * 0.42, r * 1.45)]
        out += chain("horn", pts, [r * 0.30, r * 0.25, r * 0.17, r * 0.03], col, 10)
        out += chain("prong", [pts[2], pts[2] + V(0, -r * 0.40, r * 0.18)], [r * 0.08, r * 0.015], col, 6)
    return out


EAR_PART_KINDS = ("cat", "fox", "bunny", "horse", "tuft", "mouse")


def ears_parts(c, hz):
    """Separate moving ears: returns {side: (parts, pivot)}; pivot at the ear base."""
    r, sx, sy, sz, rx, ry, rz = head_geom(c)
    kind = c["ears"]
    col = c["ear_col"] or c["skin"]
    inn = c["ear_in"] or "flower_pink"
    res = {}
    if kind not in EAR_PART_KINDS:
        return res
    for s in (-1, 1):
        if kind in ("cat", "fox"):
            hatted = bool(c["hat"])
            b = V((s * rx * (0.80 if hatted else 0.58), r * 0.05, hz + rz * (0.92 if hatted else 0.80)))
            tip = b + V(s * r * 0.30, -r * 0.05, r * ((1.15 if hatted else 0.78) if kind == "fox" else 0.62))
            outer = seg("ear", b, tip, r * (0.46 if hatted else 0.38), 0.0, col, 4)
            innerb = b + V(0, -r * 0.14, r * 0.02)
            inner = seg("ear_in", innerb, tip + V(0, -r * 0.14, -r * 0.1), r * (0.29 if c["hat"] else 0.23), 0.0, inn, 4)
            res[s] = ([outer, inner], b)
        elif kind == "horse":
            hatted = bool(c["hat"])
            b = V((s * rx * (0.66 if hatted else 0.52), r * 0.05, hz + rz * 0.84))
            tip = b + V(s * r * 0.40, 0, r * 1.05)
            res[s] = ([seg("ear", b, tip, r * 0.27, 0.0, col, 5), seg("ear_in", b + V(0, -r * 0.1, 0), tip + V(0, -r * 0.1, -r * 0.05), r * 0.15, 0.0, inn, 5)], b)
        elif kind == "tuft":  # owl feather tufts
            b = V((s * rx * 0.45, -r * 0.05, hz + rz * 0.86))
            res[s] = ([seg("tuft", b, b + V(s * r * 0.30, 0, r * 0.95), r * 0.22, 0.0, col, 5),
                       seg("tuft2", b + V(s * r * 0.10, 0, 0), b + V(s * r * 0.64, 0, r * 0.74), r * 0.16, 0.0, inn, 5)], b)
        elif kind == "mouse":  # big round forward-facing ears
            b = V((s * rx * 0.66, r * 0.05, hz + rz * 0.80))
            res[s] = ([bc.blob("ear", r * 0.46, b + V(s * r * 0.22, 0, r * 0.30), col, 2, (1.0, 0.32, 1.0)),
                       bc.blob("ear_in", r * 0.30, b + V(s * r * 0.22, -r * 0.08, r * 0.30), inn, 1, (1.0, 0.30, 1.0))], b)
        else:  # bunny: tall oval ears with a pink inside, tilted a little outward
            b = V((s * rx * 0.42, r * 0.10, hz + rz * 0.80))
            outer = place(bc.blob("ear", r * 0.30, (0, 0, 0), col, 2, (0.62, 0.26, 3.0)), (0, s * 12, 0), b + V((s * r * 0.20, 0, r * 1.30)))
            inner = place(bc.blob("ear_in", r * 0.20, (0, 0, 0), inn, 2, (0.50, 0.16, 2.55)), (0, s * 12, 0), b + V((s * r * 0.20, -r * 0.12, r * 1.24)))
            res[s] = ([outer, inner], b)
    return res


def ants_parts(c, hz):
    r, sx, sy, sz, rx, ry, rz = head_geom(c)
    col, tipc = c["ants"]
    res = {}
    for s in (-1, 1):
        b = V((s * rx * 0.28, -r * 0.20, hz + rz * 0.90))
        pts = [b, b + V(s * r * 0.15, -r * 0.18, r * 0.65), b + V(s * r * 0.50, -r * 0.45, r * 1.10), b + V(s * r * 0.95, -r * 0.50, r * 1.28)]
        res[s] = (chain("ant", pts, [r * 0.07, r * 0.06, r * 0.05, r * 0.04], col, 4, ball_tip=(r * 0.16, tipc)), b)
    return res


def wings_parts(c, neck, br):
    """Flat butterfly / insect / beetle-case wings, one set per side; pivot at the shoulder blade."""
    kind, c1, c2 = c["wings"]
    res = {}
    for s in (-1, 1):
        b = V((s * br * 0.35, br * 1.0, neck - 0.0030))
        a = math.radians(28)
        P = lambda u, v: (b.x + s * u * math.cos(a), b.y + u * math.sin(a), b.z + v)
        k = 0.0105
        if kind == "butterfly":
            up = flat("wing_up", [P(0, 0), P(.55 * k, .75 * k), P(1.25 * k, 1.05 * k), P(1.85 * k, .55 * k), P(1.55 * k, -.15 * k), P(.5 * k, -.2 * k)], 0.0007, c1)
            lo = flat("wing_lo", [P(0, -.1 * k), P(.9 * k, -.2 * k), P(1.15 * k, -.85 * k), P(.65 * k, -1.2 * k), P(.1 * k, -.7 * k)], 0.0007, c1)
            sp = bc.blob("spot", 0.0016, (P(1.25 * k, .55 * k)[0], b.y + 1.25 * k * math.sin(a) + 0.0006, b.z + .55 * k), c2, 1, (1, 0.35, 1))
            sp2 = bc.blob("spot", 0.0012, (P(.8 * k, -.65 * k)[0], b.y + .8 * k * math.sin(a) + 0.0006, b.z - .65 * k), c2, 1, (1, 0.35, 1))
            res[s] = ([up, lo, sp, sp2], b)
        elif kind == "insect":  # two slim pale wings
            up = flat("wing_up", [P(0, 0), P(.5 * k, .6 * k), P(1.5 * k, 1.1 * k), P(1.6 * k, .6 * k), P(.9 * k, 0)], 0.0006, c1)
            lo = flat("wing_lo", [P(0, -.05 * k), P(.9 * k, -.05 * k), P(1.1 * k, -.5 * k), P(.4 * k, -.55 * k)], 0.0006, c1)
            res[s] = ([up, lo], b)
        elif kind == "bigfly":  # large swallowtail butterfly wings with a spot on each
            k = 0.0215
            up = flat("wing_up", [P(0, 0), P(.7 * k, .9 * k), P(1.7 * k, 1.4 * k), P(2.3 * k, .8 * k), P(2.0 * k, -.2 * k), P(.6 * k, -.25 * k)], 0.0007, c1)
            lo = flat("wing_lo", [P(0, -.1 * k), P(1.2 * k, -.3 * k), P(1.55 * k, -1.0 * k), P(1.15 * k, -1.9 * k), P(.65 * k, -1.2 * k), P(.15 * k, -.7 * k)], 0.0007, c1)
            sp = [bc.blob("spot", 0.0052, (P(1.55 * k, .6 * k)[0], b.y + 1.55 * k * math.sin(a) + 0.0006, b.z + .6 * k), c2, 1, (1, 0.3, 1)),
                  bc.blob("spot", 0.0038, (P(.85 * k, -.75 * k)[0], b.y + .85 * k * math.sin(a) + 0.0006, b.z - .75 * k), c2, 1, (1, 0.3, 1))]
            res[s] = ([up, lo] + sp, b)
        elif kind == "jewel":  # a GIANT beetle shell: two huge wing-cases swung open, big pale wings behind
            bb = V((s * br * 0.35, br * 1.0, neck - 0.0035))
            case = place(bc.blob("case", 0.0125, (0, 0, 0), c1, 2, (0.62, 0.50, 1.85)), (0, s * 30, 0), bb + V((s * 0.0105, 0.0040, 0.0150)))
            stripe = place(bc.blob("stripe", 0.0042, (0, 0, 0), c2, 1, (0.22, 0.30, 2.4)), (0, s * 30, 0), bb + V((s * 0.0105, 0.0070, 0.0152)))
            rim = place(bc.blob("rim", 0.0042, (0, 0, 0), c2, 1, (0.55, 0.32, 0.45)), (0, s * 30, 0), bb + V((s * 0.0030, 0.0030, -0.0030)))
            k2 = 0.0150
            P2 = lambda u, v: (bb.x + s * u * math.cos(math.radians(40)), bb.y + 0.0010 + u * math.sin(math.radians(40)), bb.z + v)
            inner = flat("wing_in", [P2(0, 0), P2(.6 * k2, .9 * k2), P2(1.6 * k2, 1.2 * k2), P2(1.7 * k2, .5 * k2), P2(.8 * k2, -.1 * k2)], 0.0006, "bone")
            res[s] = ([case, stripe, rim, inner], bb)
        elif kind == "shell":  # closed giant domed shell on the back (the soldier's carapace)
            bb = V((s * br * 0.05, br * 1.15, neck - 0.0050))
            half = place(bc.blob("shell", 0.0130, (0, 0, 0), c1, 2, (0.62, 0.62, 1.25)), (0, s * 6, 0), bb + V((s * 0.0070, 0.0080, 0.0040)))
            ridge = place(bc.blob("ridge", 0.0050, (0, 0, 0), c2, 1, (0.24, 0.30, 2.5)), (0, s * 6, 0), bb + V((s * 0.0070, 0.0140, 0.0045)))
            res[s] = ([half, ridge], bb)
        elif kind == "moth":  # broad flat moth wings: big forewings, round hindwings, eye spots
            k = 0.0115
            up = flat("wing_up", [P(0, 0), P(.5 * k, 1.0 * k), P(1.5 * k, 1.55 * k), P(2.4 * k, 1.1 * k), P(2.7 * k, .1 * k), P(1.7 * k, -.3 * k)], 0.0007, c1)
            lo = flat("wing_lo", [P(0, -.1 * k), P(1.4 * k, -.25 * k), P(1.9 * k, -.95 * k), P(1.2 * k, -1.55 * k), P(.3 * k, -1.0 * k)], 0.0007, c1)
            edge = flat("wing_edge", [P(1.5 * k, 1.55 * k), P(2.4 * k, 1.1 * k), P(2.7 * k, .1 * k), P(2.45 * k, .05 * k), P(2.15 * k, .95 * k), P(1.45 * k, 1.30 * k)], 0.0009, c2)
            sp = [bc.blob("eye_spot", 0.0030, (P(1.55 * k, .55 * k)[0], b.y + 1.55 * k * math.sin(a) + 0.0007, b.z + .55 * k), c2, 2, (1, 0.25, 1)),
                  bc.blob("eye_spot", 0.0022, (P(1.15 * k, -.80 * k)[0], b.y + 1.15 * k * math.sin(a) + 0.0007, b.z - .8 * k), c2, 2, (1, 0.25, 1))]
            res[s] = ([up, lo, edge] + sp, b)
        elif kind == "case":  # beetle wing-cases, closed on the back like a short cape
            bb = V((s * br * 0.55, br * 1.0, neck - 0.0045))
            case = bc.blob("case", 0.0050, bb, c1, 2, (0.62, 0.42, 1.55))
            stripe = bc.blob("stripe", 0.0025, bb + V(0, 0.0014, 0), c2, 1, (0.2, 0.3, 1.5))
            res[s] = ([case, stripe], bb)
    return res


def tail_parts(c, lh, bh, br):
    kind, c1, c2 = c["tail"]
    b = V((0, br * 1.15, lh + bh * 0.28))
    if kind == "fox":
        pts = [b, b + V(0, 0.004, 0.001), b + V(0, 0.0085, 0.005), b + V(0, 0.011, 0.0105)]
        rads = [0.0026, 0.0042, 0.0050, 0.0036]
        parts = chain("tail", pts, rads, c1, 10)
        parts.append(bc.blob("tip", 0.0034, pts[-1] + V(0, 0.001, 0.003), c2, 2))
    elif kind == "cat":
        pts = [b, b + V(0, 0.004, 0.001), b + V(0, 0.0075, 0.0055), b + V(0, 0.0075, 0.011), b + V(0, 0.0045, 0.0145)]
        parts = chain("tail", pts, [0.0018, 0.0016, 0.0015, 0.0014, 0.0011], c1, 8)
        parts.append(bc.blob("tip", 0.0016, pts[-1], c2, 1))
    elif kind == "horse":
        pts = [b, b + V(0, 0.0030, -0.0010), b + V(0, 0.0045, -0.0060), b + V(0, 0.0036, -0.0115)]
        parts = chain("tail", pts, [0.0018, 0.0026, 0.0034, 0.0030], c1, 8)
        parts.append(bc.blob("tuft", 0.0034, pts[-1] + V(0, 0, -0.002), c2, 1, (0.8, 0.8, 1.4)))
    elif kind == "stinger":  # bee abdomen with stripes and a stinger
        pts = [b + V(0, 0.0020, 0.0000), b + V(0, 0.0075, 0.0010)]
        parts = [bc.blob("abdomen", 0.0062, b + V(0, 0.0075, 0.0015), c1, 1, (0.9, 1.25, 0.95))]
        for dy in (0.0050, 0.0085):
            parts.append(bc.blob("stripe", 0.0050, b + V(0, dy, 0.0017), c2, 1, (0.99, 0.28, 0.93)))
        parts.append(seg("sting", b + V(0, 0.0128, 0.0015), b + V(0, 0.0178, 0.0030), 0.0014, 0.0001, c2, 5))
    elif kind == "bulb":  # ant / spider abdomen: a big round bulb with a pale marking
        parts = [bc.blob("abdomen", 0.0090, b + V(0, 0.0085, 0.0010), c1, 2, (1.0, 1.1, 0.95)),
                 bc.blob("mark", 0.0030, b + V(0, 0.0105, 0.0098), c2, 1, (1.0, 0.8, 0.35))]
    elif kind == "puff":  # cotton or wool puff
        parts = [bc.blob("puff", 0.0046, b + V(0, 0.0045, 0.0005), c1, 1), bc.blob("puff2", 0.0030, b + V(0, 0.0070, 0.0020), c2, 1)]
    elif kind == "fan":  # owl tail feathers, fanned out and down
        parts = []
        for i in range(5):
            a = math.radians(-40 + i * 20)
            parts.append(seg("feather", b, b + V(math.sin(a) * 0.0070, 0.0080, -math.cos(a) * 0.0090 + 0.0020), 0.0018, 0.0003, c1 if i % 2 == 0 else c2, 5))
    elif kind == "deer":  # short white flag tail
        parts = [bc.blob("flag", 0.0040, b + V(0, 0.0035, 0.0010), c1, 2, (0.8, 1.0, 1.35)), bc.blob("under", 0.0030, b + V(0, 0.0050, -0.0010), c2, 1, (0.8, 0.9, 1.3))]
    elif kind == "leaf":  # leafy sprig tail
        parts = [bc.blob("leaf", 0.0050, b + V(0.0020, 0.0050, 0.0030), c1, 1, (1.4, 0.25, 0.7)), bc.blob("leaf", 0.0050, b + V(-0.0020, 0.0060, 0.0050), c2, 1, (1.4, 0.25, 0.7)),
                 seg("stem", b, b + V(0, 0.0045, 0.0020), 0.0009, 0.0007, c1, 5)]
    elif kind == "goblin":  # thin tail with a spade tip
        pts = [b, b + V(0, 0.0040, -0.0010), b + V(0, 0.0075, 0.0010), b + V(0, 0.0095, 0.0045)]
        parts = chain("tail", pts, [0.0017, 0.0014, 0.0012, 0.0010], c1, 6)
        parts.append(bc.blob("spade", 0.0030, pts[-1] + V(0, 0.0005, 0.0020), c2, 1, (0.7, 0.4, 1.3)))
    else:  # imp: thin with an arrow tip
        pts = [b, b + V(0, 0.0045, -0.0005), b + V(0, 0.0085, 0.0035), b + V(0, 0.0095, 0.0085)]
        parts = chain("tail", pts, [0.0014, 0.0012, 0.0011, 0.0010], c1, 8)
        parts.append(seg("arrow", pts[-1], pts[-1] + V(0, -0.0006, 0.0050), 0.0030, 0.0, c2, 4))
    return parts, b


def hat_parts(c, hz):
    r, sx, sy, sz, rx, ry, rz = head_geom(c)
    kind, c1, c2 = c["hat"]
    top = V((0, 0, hz + rz * 0.80))
    if kind in ("witch", "wizard"):
        tall = 1.9 if kind == "wizard" else 1.5
        brim = 1.18 if kind == "wizard" else 1.35
        p = [bc.cone("brim", r * brim, r * brim * 0.92, r * 0.10, top + V(0, 0, r * 0.05), c1, 12),
             bc.cone("band", r * 0.80, r * 0.76, r * 0.20, top + V(0, 0, r * 0.19), c2, 12)]
        z0 = top.z + r * 0.12
        pts = [V(0, 0, z0), V(0, r * 0.05, z0 + r * tall * 0.45), V(0, r * 0.22, z0 + r * tall * 0.85), V(0, r * 0.62, z0 + r * tall * 1.10)]
        p += chain("cone", pts, [r * 0.72, r * 0.48, r * 0.26, 0.00005], c1, 12)
        return p
    if kind == "straw":
        p = [bc.cone("brim", r * 1.36, r * 1.26, r * 0.07, top + V(0, 0, r * 0.05), c1, 14),
             bc.cone("crown", r * 0.82, r * 0.74, r * 0.46, top + V(0, 0, r * 0.30), c1, 14),
             bc.cone("band", r * 0.84, r * 0.82, r * 0.14, top + V(0, 0, r * 0.18), c2, 14)]
        return p
    if kind == "hard":  # hard hat: dome, brim peak and a ridge
        p = [bc.blob("dome", r * 1.04, (0, r * 0.08, hz + r * 0.22), c1, 2, (sx * 1.0, sy * 1.04, sz * 0.90)),
             bc.box("peak", (r * 1.0, r * 0.55, r * 0.07), (0, -ry * 0.88, hz + rz * 0.46), c1),
             bc.box("ridge", (r * 0.20, r * 1.7, r * 0.10), (0, r * 0.05, hz + rz * 1.06), c2)]
        return p
    if kind == "chef":  # tall puffy chef hat
        p = [bc.cone("band", r * 0.86, r * 0.84, r * 0.34, top + V(0, 0, r * 0.12), c1, 14)]
        for x_, y_, z_, rr in ((0, 0, 0.62, 0.62), (-0.42, 0.0, 0.56, 0.42), (0.42, 0.0, 0.56, 0.42), (0, -0.4, 0.55, 0.38), (0, 0.4, 0.55, 0.38)):
            p.append(bc.blob("puff", r * rr, top + V(x_ * r, y_ * r, z_ * r + r * 0.25), c1, 2))
        return p
    if kind == "clerkcap":  # flat newsboy cap with a visor
        p = [bc.blob("cap", r * 1.06, (0, r * 0.06, hz + r * 0.28), c1, 2, (sx, sy * 1.02, sz * 0.62)),
             bc.box("visor", (r * 1.3, r * 0.62, r * 0.07), (0, -ry * 0.92, hz + rz * 0.52), c2)]
        return p
    if kind == "mini":  # small tilted witch hat set back on the head, between the horns
        b = top + V(0, r * 0.22, r * 0.0)
        p = [bc.cone("brim", r * 0.62, r * 0.56, r * 0.07, b + V(0, 0, r * 0.05), c1, 10),
             bc.cone("band", r * 0.40, r * 0.38, r * 0.12, b + V(0, 0, r * 0.14), c2, 10)]
        pts = [b + V(0, 0, r * 0.12), b + V(0, r * 0.03, r * 0.50), b + V(0, r * 0.18, r * 0.86), b + V(0, r * 0.44, r * 1.02)]
        p += chain("cone", pts, [r * 0.36, r * 0.25, r * 0.13, 0.00005], c1, 10)
        return p
    if kind == "helm":  # teal dome with cheek guards (the beetle horn is added by horns())
        p = [bc.blob("dome", r * 1.04, (0, r * 0.06, hz + r * 0.20), c1, 2, (sx * 1.0, sy * 1.04, sz * 0.92)),
             bc.cone("rim", rx * 1.04, rx * 1.04, r * 0.13, (0, r * 0.04, hz + rz * 0.38), c2, 12)]
        for s in (-1, 1):
            p.append(bc.blob("cheek_guard", r * 0.28, (s * rx * 0.98, r * 0.02, hz - rz * 0.05), c1, 1, (0.55, 0.8, 1.5)))
        return p
    if kind == "hood":  # leafy hood over the back of the head
        p = [bc.blob("hood", r * 1.12, (0, r * 0.22, hz + r * 0.18), c1, 2, (sx * 1.02, sy * 1.06, sz * 0.98)),
             bc.blob("hood_tip", r * 0.30, (0, r * 1.20, hz - r * 0.35), c1, 1, (0.6, 1.6, 0.6))]
        for i in range(5):  # leaf crown
            a = math.radians(-60 + i * 30)
            p.append(seg("leaf", (math.sin(a) * rx * 0.55, -ry * 0.55, hz + rz * 0.75), (math.sin(a) * rx * 0.75, -ry * 0.75, hz + rz * 1.12), r * 0.15, 0.0, c2, 4))
        return p
    if kind == "shroom":  # mushroom cap hat
        p = [bc.blob("cap", r * 1.08, (0, r * 0.05, hz + rz * 0.95), c1, 2, (1.02, 1.0, 0.58))]
        for sx_, sy_, sr in ((0.6, -0.4, 0.22), (-0.5, -0.5, 0.18), (0.1, -0.85, 0.16), (-0.1, 0.5, 0.20), (0.7, 0.35, 0.14)):
            p.append(bc.blob("dot", r * sr, (sx_ * r * 0.82, sy_ * r * 0.82, hz + rz * 0.78 + r * 0.52 * (1 - 0.3 * (sx_ ** 2 + sy_ ** 2))), c2, 1, (1, 1, 0.5)))
        return p
    return []


def item_parts(c, hx, hz_):
    kind = c["item"]
    p = []
    if kind == "staff":
        p += [seg("shaft", (hx, 0, hz_ - 0.014), (hx, 0, hz_ + 0.038), 0.0011, 0.0013, "wood_light", 8)]
        for dz in (0.0, 0.0030):  # curled top: two prongs holding a dark socket
            pass
        p += [bc.blob("socket", 0.0034, (hx, 0, hz_ + 0.0425), "ink", 1),
              seg("prong", (hx + 0.0022, 0, hz_ + 0.036), (hx + 0.0034, 0, hz_ + 0.0465), 0.0009, 0.0004, "wood_dark", 6),
              seg("prong", (hx - 0.0022, 0, hz_ + 0.036), (hx - 0.0034, 0, hz_ + 0.0465), 0.0009, 0.0004, "wood_dark", 6)]
    elif kind == "spear":
        p += [seg("shaft", (hx, 0, hz_ - 0.016), (hx, 0, hz_ + 0.030), 0.0011, 0.0011, "wood_light", 8),
              seg("blade", (hx, 0, hz_ + 0.029), (hx, 0, hz_ + 0.0405), 0.0026, 0.0, "stone", 4),
              bc.blob("tassel", 0.0016, (hx, 0, hz_ + 0.0275), "fire_red", 1)]
    elif kind == "bow":
        pts = [V(hx, 0, hz_ - 0.013), V(hx - 0.0026, -0.0042, hz_ - 0.0065), V(hx - 0.0034, -0.0050, hz_), V(hx - 0.0026, -0.0042, hz_ + 0.0065), V(hx, 0, hz_ + 0.013)]
        p += chain("limb", pts, [0.0006, 0.0011, 0.0014, 0.0011, 0.0006], "wood_mid", 6)
        p += [seg("string", pts[0], pts[-1], 0.00035, 0.00035, "bone", 4)]
    elif kind == "pitchfork":
        p += [seg("shaft", (hx, 0, hz_ - 0.016), (hx, 0, hz_ + 0.028), 0.0010, 0.0011, "wood_light", 8),
              bc.box("bar", (0.0072, 0.0016, 0.0014), (hx, 0, hz_ + 0.0275), "stone_dark")]
        for dx in (-0.0030, 0.0, 0.0030):
            p.append(seg("tine", (hx + dx, 0, hz_ + 0.0275), (hx + dx, 0, hz_ + 0.0385), 0.0007, 0.0002, "stone", 4))
    elif kind == "hammer":
        p += [seg("shaft", (hx, 0, hz_ - 0.005), (hx, 0, hz_ + 0.017), 0.0011, 0.0012, "wood_light", 8),
              bc.box("head", (0.0080, 0.0038, 0.0044), (hx, 0, hz_ + 0.0185), "stone_dark"),
              bc.box("face", (0.0016, 0.0040, 0.0046), (hx + 0.0045, 0, hz_ + 0.0185), "shell_copper")]
    elif kind == "scroll":
        p += horiz(hx, hz_ + 0.003, 0.0048, 0.0034, "bone", "wood_dark", "scroll")
        p.append(bc.box("seal", (0.0016, 0.0016, 0.0016), (hx, -0.0036, hz_ + 0.003), "fire_red"))
    elif kind == "rolling_pin":
        p += horiz(hx, hz_ + 0.003, 0.0052, 0.0030, "wood_light", "wood_dark", "pin")
    elif kind == "needle":  # long needle with a thread spool: the tailor's tool
        p += [seg("needle", (hx, 0, hz_ - 0.008), (hx, 0, hz_ + 0.030), 0.0006, 0.0003, "stone", 6),
              bc.blob("eye", 0.0016, (hx, 0, hz_ - 0.0095), "stone", 1, (1, 0.4, 1.3)),
              seg("spool", (hx + 0.0045, 0, hz_ - 0.0012), (hx + 0.0045, 0, hz_ + 0.0050), 0.0028, 0.0028, "cloth_rose", 8)]
    elif kind == "ribbon":  # dancer: two trailing ribbons
        for dx, sgn in ((0.0010, 1), (-0.0010, -1)):
            pts = [V(hx + dx, 0, hz_ + 0.002), V(hx + dx + sgn * 0.0040, -0.0030, hz_ + 0.0100), V(hx + dx - sgn * 0.0020, -0.0060, hz_ + 0.0170), V(hx + dx + sgn * 0.0050, -0.0040, hz_ + 0.0240), V(hx + dx, -0.0010, hz_ + 0.0300)]
            p += chain("ribbon", pts, [0.0011, 0.0010, 0.0010, 0.0009, 0.0006], c["top"] if sgn > 0 else c["bottom"], 6)
    elif kind == "cane":  # village head: crook cane with a gold knob
        p += [seg("shaft", (hx, 0, hz_ - 0.016), (hx, 0, hz_ + 0.024), 0.0011, 0.0012, "wood_dark", 8)]
        p += chain("crook", [V(hx, 0, hz_ + 0.024), V(hx, 0, hz_ + 0.0285), V(hx + 0.0018, 0, hz_ + 0.0315), V(hx + 0.0045, 0, hz_ + 0.0305), V(hx + 0.0058, 0, hz_ + 0.0268)], [0.0012] * 5, "wood_dark", 6)
        p.append(bc.blob("knob", 0.0022, (hx + 0.0060, 0, hz_ + 0.0255), "shell_gold", 1))
    elif kind == "carrot":  # bunny kid's carrot club
        p += [seg("carrot", (hx, 0, hz_ - 0.004), (hx, 0, hz_ + 0.020), 0.0036, 0.0003, "roof_orange", 8),
              seg("leaf", (hx, 0, hz_ - 0.004), (hx - 0.0014, 0, hz_ - 0.0105), 0.0012, 0.0002, "leaf_green", 5),
              seg("leaf", (hx, 0, hz_ - 0.004), (hx + 0.0016, 0, hz_ - 0.0100), 0.0012, 0.0002, "leaf_light", 5)]
    elif kind == "yarn_staff":  # cat girl: staff with a ball of yarn
        p += [seg("shaft", (hx, 0, hz_ - 0.014), (hx, 0, hz_ + 0.030), 0.0010, 0.0012, "wood_light", 8),
              bc.blob("yarn", 0.0042, (hx, 0, hz_ + 0.0345), "cloth_coral", 2),
              seg("strand", (hx, 0, hz_ + 0.0345), (hx + 0.0040, -0.0010, hz_ + 0.0220), 0.0004, 0.0004, "cloth_coral", 4)]
    elif kind == "sprig":  # sprout kid's twig sword
        p += [seg("twig", (hx, 0, hz_ - 0.004), (hx, 0, hz_ + 0.024), 0.0013, 0.0004, "wood_mid", 6),
              bc.blob("leaf", 0.0030, (hx + 0.0025, 0, hz_ + 0.0150), "leaf_light", 1, (1.4, 0.3, 0.8)),
              bc.blob("leaf", 0.0030, (hx - 0.0025, 0, hz_ + 0.0200), "leaf_green", 1, (1.4, 0.3, 0.8))]
    elif kind == "dipper":  # bee kid's honey dipper: short shaft, ridged golden knob
        p += [seg("shaft", (hx, 0, hz_ - 0.004), (hx, 0, hz_ + 0.014), 0.0010, 0.0011, "wood_light", 8)]
        for i, (rr, col) in enumerate(((0.0030, "fire_yellow"), (0.0036, "lantern_glow"), (0.0031, "fire_yellow"), (0.0024, "lantern_glow"))):
            p.append(bc.cone("ridge", rr, rr * 0.92, 0.0016, (hx, 0, hz_ + 0.0150 + i * 0.0017), col, 10))
    elif kind == "club":
        p += [seg("shaft", (hx, 0, hz_ - 0.004), (hx, 0, hz_ + 0.012), 0.0012, 0.0022, "wood_mid", 7),
              bc.blob("knob", 0.0034, (hx, 0, hz_ + 0.0145), "wood_mid", 1)]
    return p


def shield_parts(c, hx, hz_):
    col, rim = c["shield"]
    return [bc.cone("shield", 0.0072, 0.0072, 0.0014, (0, 0, 0), col, 12),
            bc.cone("rim", 0.0078, 0.0078, 0.0010, (0, 0, 0), rim, 12),
            bc.blob("boss", 0.0020, (0, 0, 0), rim, 1)]


# ---------------------------------------------------------------- assemble one character
def build(name, key):
    c = {**BASE, **CHARACTERS[key]}
    lh, bh, br = c["leg"], c["body_h"], c["body_r"]
    neck = lh + bh
    r, sx, sy, sz, rx, ry, rz = head_geom(c)
    hz = neck + rz * 0.80
    root = []
    if c["body"] == "robe":  # long robe down to the boots
        root += [bc.cone("robe", br * 1.70, br * 0.90, bh + lh * 0.55, (0, 0, lh * 0.45 + (bh + lh * 0.55) / 2), c["top"], 12),
                 bc.cone("hem", br * 1.78, br * 1.70, 0.0016, (0, 0, lh * 0.45 + 0.0008), c["bottom"], 12)]
    elif c["body"] == "gown":  # elegant flowing gown: fitted bodice, long skirt, petal layers at the hem
        waist = lh + bh * 0.52
        root += [bc.cone("bodice", br * 1.22, br * 1.00, bh * 0.62, (0, 0, waist + bh * 0.31), c["top"], 12),
                 bc.cone("sash", br * 1.30, br * 1.30, bh * 0.10, (0, 0, waist), c["bottom"], 12),
                 bc.cone("skirt", br * 3.3, br * 1.12, waist - 0.0030, (0, 0, 0.0030 + (waist - 0.0030) / 2), c["bottom"], 16)]
        for i in range(6):
            a = math.radians(i * 60)
            tip = V((math.cos(a) * br * 3.1, math.sin(a) * br * 3.1, 0.0040))
            root.append(bc.blob("petal", br * 1.55, (math.cos(a) * br * 3.05, math.sin(a) * br * 3.05, 0.0060), c["top"] if i % 2 else c["bottom"], 1, (1.0, 1.0, 0.62)))
    elif c["body"] == "dress":
        root += [bc.cone("torso", br * 1.45, br * 0.9, bh, (0, 0, lh + bh / 2), c["top"], 12),
                 bc.cone("skirt", br * 1.95, br * 1.35, bh * 0.50, (0, 0, lh + bh * 0.25), c["bottom"], 12)]
    else:
        root += [bc.cone("torso", br * 1.25, br * 0.9, bh, (0, 0, lh + bh / 2), c["top"], 12),
                 bc.cone("hem", br * 1.30, br * 1.22, bh * 0.20, (0, 0, lh + bh * 0.10), c["bottom"], 12)]
    if "quiver" in c["extras"]:  # arrows on the back, tipped over the left shoulder
        q0, q1 = V(br * 0.55, br * 1.25, neck - 0.0085), V(br * 0.95, br * 1.55, neck + 0.0012)
        root.append(seg("quiver", q0, q1, 0.0030, 0.0036, "wood_mid", 8))
        for dx in (-0.0009, 0.0006, 0.0021):
            a0 = q1 + V(dx, 0, -0.001)
            root.append(seg("arrow", a0, a0 + V(0.0009, 0.0004, 0.0062), 0.00045, 0.00045, "bone", 4))
            root.append(bc.blob("fletch", 0.0013, a0 + V(0.0009, 0.0004, 0.0062), "leaf_light", 1, (0.7, 0.7, 1.3)))
    if c["apron"]:  # baker's apron
        root.append(bc.box("apron", (br * 1.55, 0.0013, bh * 0.82), (0, -br * 1.02, lh + bh * 0.48), c["apron"]))
        root.append(bc.box("apron_top", (br * 0.9, 0.0013, bh * 0.28), (0, -br * 0.86, lh + bh * 0.90), c["apron"]))
    if c["overalls"]:  # bib and two straps
        root.append(bc.box("bib", (br * 1.2, 0.0013, bh * 0.50), (0, -br * 0.98, lh + bh * 0.66), c["overalls"]))
        for s_ in (-1, 1):
            root.append(bc.box("strap", (br * 0.28, br * 1.5, 0.0013), (s_ * br * 0.60, -br * 0.15, neck - 0.0006), c["overalls"]))
    if "chain" in c["extras"]:  # gold chain of office
        for i in range(6):
            a = math.radians(-60 + i * 24)
            lp = V((math.sin(a) * br * 1.15, -math.cos(a) * br * 1.02, neck - 0.0016 - 0.0006 * abs(i - 3)))
            root.append(seg("link", lp + V((0, 0, 0.0011)), lp - V((0, 0, 0.0011)), 0.0010, 0.0010, "shell_gold", 6))
        root.append(bc.box("medal", (0.0040, 0.0014, 0.0040), (0, -br * 1.06, neck - 0.0040), "shell_gold"))
    if "toolbelt" in c["extras"]:
        root.append(bc.cone("belt", br * 1.34, br * 1.30, bh * 0.14, (0, 0, lh + bh * 0.30), "wood_dark", 12))
        for s_ in (-1, 1):
            root.append(bc.box("pouch", (br * 0.55, br * 0.35, bh * 0.28), (s_ * br * 1.0, -br * 0.55, lh + bh * 0.24), "wood_mid"))
    if "tutu" in c["extras"]:  # layered frilly skirt
        for i, (rr, col, dz) in enumerate(((2.9, c["bottom"], 0.0), (2.5, c["top"], 0.0013), (2.1, c["bottom"], 0.0026))):
            root.append(bc.cone("tutu", br * rr, br * rr * 0.80, 0.0012, (0, 0, lh + bh * 0.28 + dz), col, 14))
    if c["scarf"]:
        root.append(bc.cone("scarf", br * 1.05, br * 0.95, bh * 0.20, (0, 0, neck - bh * 0.06), c["scarf"], 12))
    leg_groups = []  # legs and boots are parts (same geometry), so Godot can step them or keep them still for a hop
    if c["body"] not in ("robe", "gown"):
        for s, side in ((-1, "r"), (1, "l")):
            leg_groups.append(("leg_" + side, [seg("leg", (s * br * 0.55, 0, 0.002), (s * br * 0.55, 0, lh), 0.0026, 0.0028, c["skin"], 8),
                                               bc.box("boot", (0.0058, 0.0085, 0.0034), (s * br * 0.55, -0.0012, 0.0017), c["boots"])], (s * br * 0.55, 0, lh), ""))
    else:
        for s, side in ((-1, "r"), (1, "l")):
            leg_groups.append(("leg_" + side, [bc.box("boot", (0.0058, 0.0085, 0.0034), (s * br * 0.55, -0.0014, 0.0017), c["boots"])], (s * br * 0.55, 0, 0.0034), ""))
    for s in (-1, 1):  # stub shoulders so the sleeves meet the body
        pass

    head = build_head(c, hz)
    if c["horns"]:
        head += horns(c, hz)
    if c["hat"] and c["hat"][0] == "helm":
        pass
    groups = [("", root, (0, 0, 0), ""), ("head", head, (0, 0, neck), "")] + leg_groups
    hb = hair_back(c, hz)
    if hb:
        groups.append(("hair_back", hb, (0, ry * 0.7, hz), "head"))
    # arms (character's right = -X)
    ssx, ssz = br * 1.15 + 0.0012, neck - 0.0030
    al = c["arm_len"]
    hpos = {}
    for s, side in ((-1, "r"), (1, "l")):
        sleeve = seg("sleeve", (s * ssx, 0, ssz), (s * ssx, 0, ssz - al * 0.62), 0.0032, 0.0034, c["top"], 10)
        hz_ = ssz - al * 0.62 - 0.0014
        hpos[side] = (s * ssx, hz_)
        groups.append(("arm_" + side, [sleeve] + hand(c, s, s * ssx, hz_), (s * ssx, 0, ssz), ""))
    tilt = ITEM_TILT.get(c["item"], (0, 0, 0))
    if c["item"]:  # built upright at the hand, then tipped outward and forward so it clears the big head
        hx, hzz = hpos["r"]
        ip = item_parts(c, 0, 0)
        for p_ in ip:
            bc.rotate(p_, tilt)
            p_.location = (hx, 0, hzz)
            bc.apply_transforms(p_)
        groups.append(("item", ip, (hx, 0, hzz), "arm_r"))
    if c.get("shield"):
        hx, hzz = hpos["l"]
        sh = shield_parts(c, hx, hzz)
        o = V((hx + 0.0042, -0.0022, hzz + 0.0012))
        for p_ in sh:
            p_.location = o
            bc.apply_transforms(p_)
        for p_ in sh:
            p_.rotation_euler = (math.radians(90), 0, math.radians(-90))
            bc.apply_transforms(p_)  # rotate about world origin: re-place below
        # simpler: rebuild shield flat against the left arm, facing outward (+X)
        for p_ in sh:
            bpy.data.objects.remove(p_, do_unlink=True)
        sh = [bc.cone("shield", 0.0070, 0.0070, 0.0014, (0, 0, 0), c["shield"][0], 12),
              bc.cone("rim", 0.0076, 0.0076, 0.0010, (0, 0, 0), c["shield"][1], 12),
              bc.blob("boss", 0.0020, (0, 0, 0), c["shield"][1], 1)]
        for i, p_ in enumerate(sh):
            bc.rotate(p_, (0, 90, 0))
            p_.location = (hx + 0.0040 + (0.0007 if i == 2 else 0.0), -0.0010, hzz + 0.0035)
            bc.apply_transforms(p_)
        groups[[g[0] for g in groups].index("arm_l")][1].extend(sh)
    if c["ears"] in EAR_PART_KINDS:
        for s, (pp, b) in ears_parts(c, hz).items():
            groups.append(("ear_" + ("r" if s < 0 else "l"), pp, tuple(b), "head"))
    if c["ants"]:
        for s, (pp, b) in ants_parts(c, hz).items():
            groups.append(("ant_" + ("r" if s < 0 else "l"), pp, tuple(b), "head"))
    if c["wings"]:
        for s, (pp, b) in wings_parts(c, neck, br).items():
            groups.append(("wing_" + ("r" if s < 0 else "l"), pp, tuple(b), ""))
    if c["tail"]:
        pp, b = tail_parts(c, lh, bh, br)
        groups.append(("tail", pp, tuple(b), ""))
    if c["spider"]:
        groups.append(("spider", spider_legs(c, neck, br), (0, br * 0.9, neck - 0.004), ""))
        wp, wpv = web_parts(c, neck)
        groups.append(("web", wp, tuple(wpv), ""))
    if c["hat"]:
        hp = hat_parts(c, hz)
        if c["hat"][0] == "helm":
            groups[1][1].extend(hp)  # helmet fixed to the head
        else:
            groups.append(("hat", hp, (0, 0, hz + rz * 0.80), "head"))
    obj = bc.assemble(name, groups)
    if c["item"] == "staff":
        hx, hzz = hpos["r"]
        tip = V(hx, 0, hzz) + mathutils.Euler([math.radians(t) for t in tilt]).to_matrix() @ V(0, 0, 0.0425)
        bc.anchor(obj, "staff_tip_anchor", tuple(tip), "item", 0.004)
    if c["hands_energy"] if "hands_energy" in c else False:
        bc.anchor(obj, "energy_anchor", (hpos["l"][0], 0, hpos["l"][1]), "arm_l", 0.003)
    smooth(obj)
    return obj


ITEM_TILT = {"staff": (18, -24, 0), "spear": (8, -14, 0), "bow": (0, -12, 0), "club": (24, -34, 0), "dipper": (14, -22, 0), "pitchfork": (10, -16, 0), "hammer": (14, -22, 0), "scroll": (0, 0, 0), "rolling_pin": (0, 0, 0), "needle": (12, -18, 0), "ribbon": (0, 0, 0), "cane": (6, -12, 0), "carrot": (10, -18, 0), "yarn_staff": (18, -24, 0), "sprig": (12, -20, 0)}


def smooth(root, angle_deg=38):
    """A little smoother: smooth shading on gentle curves, crisp edges where the angle is sharp."""
    for o in [root] + list(root.children_recursive):
        if o.type != "MESH":
            continue
        for p in o.data.polygons:
            p.use_smooth = True
        m = o.modifiers.new("es", "EDGE_SPLIT")
        m.use_edge_angle = True
        m.use_edge_sharp = False
        m.split_angle = math.radians(angle_deg)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=m.name)


def tri_count(root):
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in [root] + list(root.children_recursive) if o.type == "MESH")


# ---------------------------------------------------------------- the round 2 cast
CHARACTERS = {
    # kid villager: bee. Striped, fluffy, tiny wings, ball-tip antennae.
    "bee_kid": dict(cat="village", head_r=0.0148, squash=(1.08, 0.97, 0.94), leg=0.0070, body_h=0.0110, body="cone",
                    skin="skin_mid", hair="flower_yellow", hair_style="fluff", top="fire_yellow", bottom="ink", item="dipper",
                    scarf="ink", boots="ink", cheeks="flower_pink",
                    ants=("ink", "fire_yellow"), wings=("insect", "bone", None), extras=(), tail=("stinger", "fire_yellow", "ink")),
    # villager girl: cat with a leaf sprout, striped tail, soft ears
    "cat_girl": dict(cat="village", skin="skin_light", hair="hair_brown", hair_style="bob", top="roof_orange",
                     bottom="wall_cream", scarf="leaf_light", boots="hair_brown", extras=("sprout",), ears="cat", ear_col="hair_brown",
                     ear_in="flower_pink", tail=("cat", "hair_brown", "wall_cream"), body="dress", cheeks="flower_pink", item="yarn_staff"),
    # wizard: fox, tall hat, big bushy tail, staff with a dark socket (VFX anchor)
    "fox_wizard": dict(cat="village", skin="skin_light", hair="roof_orange", hair_style="bob", top="roof_terracotta",
                       bottom="ink", scarf="wall_cream", boots="ink", ears="fox", ear_col="roof_orange",
                       ear_in="wall_cream", tail=("fox", "roof_orange", "wall_cream"), body="robe",
                       hat=("wizard", "ink", "fire_red"), item="staff", hands_energy=True),
    # witch: curled horns, mini hat, imp tail, black / orange / red
    "horn_witch": dict(cat="village", skin="skin_light", hair="fire_red", hair_style="bob", top="ink", item="staff",
                       bottom="roof_terracotta", scarf="lantern_glow", boots="ink", cheeks="fire_red",
                       horns=("ram", "bone"), tail=("imp", "ink", "fire_red"), body="dress",
                       hat=("mini", "ink", "lantern_glow"), hands_energy=True, eyes="ink"),
    # soldier (ours): beetle-horn helmet, wing-case cape, shield and spear in teal and cream
    "beetle_soldier": dict(cat="village", skin="skin_mid", hair=None, top="roof_teal", bottom="wall_cream",
                           scarf="wall_cream", boots="wood_dark", horns=("beetle", "wood_mid"),
                           hat=("helm", "roof_teal", "wall_cream"), wings=("shell", "roof_teal", "wall_cream"),
                           shield=("wall_cream", "roof_teal"), item="spear", smile=False, tail=("goblin", "roof_teal", "wall_cream")),
    # archer (ours): antlered leaf hood, bow, green and gold
    "antler_archer": dict(cat="village", skin="skin_mid", hair="hair_dark", hair_style="bob", top="wood_mid",
                          bottom="wood_light", scarf="leaf_yellow", boots="wood_dark", horns=("antler", "bone"), extras=("quiver",), tail=("deer", "wood_light", "wall_cream"),
                          hat=("hood", "leaf_green", "leaf_light"), item="bow"),
    # goblin (enemy): mushroom-cap hat, tusks, huge ears, club
    "shroom_goblin": dict(cat="enemy", skin="leaf_light", hair=None, top="wood_mid", bottom="wood_dark",
                          boots="wood_dark", cheeks="leaf_green", ears="goblin", extras=("tusks",), tail=("goblin", "leaf_light", "leaf_dark"),
                          hat=("shroom", "roof_terracotta", "wall_cream"), item="club", head_r=0.0150,
                          squash=(1.08, 0.97, 0.9), smile=False),

    # ---------------- round 3: the village (Durva 2026-11-01: "all of them, a whole world")
    # village head: grey ram horns, cloud beard, chain of office, crook cane, long plum-red robe
    "elder_ram": dict(cat="village", head_r=0.0146, skin="skin_pale", hair="hair_silver", hair_style="bob",
                         beard="hair_silver", horns=("ram_s", "bone"), top="cloth_maroon", bottom="shell_gold",
                         boots="wood_dark", body="robe", extras=("chain",), item="cane", cheeks="flower_pink", tail=("puff", "wall_cream", "hair_silver")),
    # clerk: owl feather tufts, round glasses, newsboy cap, a scroll with a red seal, olive waistcoat
    "clerk_owl": dict(cat="village", skin="skin_tan", hair="hair_charcoal", hair_style="bob", top="cloth_olive",
                      bottom="wall_cream", scarf="cloth_maroon", boots="wood_dark", ears="tuft", ear_col="wood_mid",
                      ear_in="bone", hat=("clerkcap", "wood_mid", "wood_dark"), extras=("glasses",), item="scroll", tail=("fan", "wood_mid", "bone")),
    # farmer: horse ears and a braided mane, straw hat, overalls, pitchfork, long tail
    "farmer_horse": dict(cat="village", skin="skin_deep", hair="hair_ginger", hair_style="bob", mane=True,
                         top="cloth_mustard", bottom="wood_mid", overalls="cloth_olive", boots="wood_dark",
                         ears="horse", ear_col="hair_ginger", ear_in="flower_pink", tail=("horse", "hair_ginger", "wall_cream"),
                         hat=("straw", "leaf_yellow", "cloth_coral"), item="pitchfork"),
    # builder: ant antennae, yellow hard hat, tool belt, hammer
    "builder_ant": dict(cat="village", skin="skin_tan", hair="hair_charcoal", hair_style="bob", top="cloth_coral",
                        bottom="cloth_olive", boots="wood_dark", ants=("ink", "fire_red"), tail=("bulb", "ink", "fire_red"),
                        hat=("hard", "fire_yellow", "roof_orange"), extras=("toolbelt",), item="hammer", squash=(1.06, 0.96, 0.92)),
    # dancer: big butterfly wings, mint-and-coral ribbons, flower crown, tutu, antennae
    "dancer_butterfly": dict(cat="village", skin="skin_aqua", hair="hair_coral", hair_style="flow", top="cloth_rose",
                             bottom="hair_mint", boots="cloth_coral", body="gown", ants=("hair_charcoal", "hair_coral"),
                             wings=("bigfly", "hair_mint", "cloth_rose"), crown=True, item="ribbon",
                             cheeks="cloth_coral", head_r=0.0146),
    # baker: round mouse ears, tall chef hat, apron, rolling pin, thin tail
    "baker_mouse": dict(cat="village", skin="skin_light", hair="hair_ginger", hair_style="buns", top="cloth_coral",
                        bottom="wall_cream", apron="wall_cream", boots="wood_dark", ears="mouse", ear_col="wall_cream",
                        ear_in="flower_pink", tail=("cat", "flower_pink", "flower_pink"), hat=("chef", "wall_cream", "wall_cream"),
                        item="rolling_pin"),
    # tailor: spider legs from the back, four eyes, long dark hair, needle and spool
    "tailor_spider": dict(cat="village", skin="skin_pale", hair="hair_charcoal", hair_style="long", top="cloth_maroon",
                          bottom="ink", scarf="cloth_rose", boots="ink", body="dress", spider="ink",
                          extras=("eyes4",), item="needle", cheeks="cloth_rose", tail=("bulb", "ink", "cloth_rose")),
    # jewel beetle captain (rare): gold-and-jade shell wings swung open, horned helmet, shield, spear
    "jewel_captain": dict(cat="village", skin="skin_deep", hair=None, top="shell_jade", bottom="shell_gold",
                          scarf="shell_gold", boots="shell_copper", horns=("beetle", "shell_copper"),
                          hat=("helm", "shell_jade", "shell_gold"), wings=("jewel", "shell_jade", "shell_gold"),
                          shield=("shell_gold", "shell_jade"), item="spear", smile=False),
    # moth ranger (rare archer): fuzzy cream moth wings, feathered antennae, silver hair, bow
    "moth_ranger": dict(cat="village", skin="skin_tan", hair="hair_silver", hair_style="bob", top="cloth_olive",
                        bottom="wood_light", scarf="cloth_rose", boots="wood_dark", ants=("bone", "cloth_rose"),
                        wings=("moth", "wall_cream", "hair_charcoal"), item="bow", extras=("quiver",)),
    # kids: small, big-headed
    "kid_bunny": dict(cat="village", head_r=0.0156, squash=(1.06, 0.97, 0.94), leg=0.0058, body_h=0.0092, body_r=0.0050,
                      arm_len=0.0076, skin="skin_pale", hair="hair_mint", hair_style="bob", top="cloth_coral",
                      bottom="wall_cream", boots="hair_mint", ears="bunny", ear_col="wall_cream", ear_in="flower_pink", tail=("puff", "wall_cream", "flower_pink"), item="carrot"),
    "kid_sprout": dict(cat="village", head_r=0.0156, squash=(1.06, 0.97, 0.94), leg=0.0058, body_h=0.0092, body_r=0.0050,
                       arm_len=0.0076, skin="skin_aqua", hair="hair_lime", hair_style="fluff", top="cloth_olive",
                       bottom="wood_light", boots="wood_dark", extras=("sprout",), tail=("leaf", "leaf_light", "leaf_green"), item="sprig"),
}


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    key = argv[0] if argv else "bee_kid"
    bc.clear_scene()
    cat = CHARACTERS[key].get("cat", "village")
    obj = build("ew_%s_%s_v01" % (cat, key), key)
    print("TRIS", key, tri_count(obj))
    bc.save_blend(obj, "char_" + key)
