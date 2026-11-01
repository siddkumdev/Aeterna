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


def chain(name, pts, radii, col, segs=10, ball_tip=None):
    """A bendy tube through points (horn, antenna, tail): cones plus a ball at each joint."""
    out = []
    for i in range(len(pts) - 1):
        out.append(seg(name, pts[i], pts[i + 1], radii[i], radii[i + 1], col, segs))
        if i > 0:
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
            item=None, extras=())


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
        P.append(bc.blob("sparkle", r * 0.06, (s * ex + r * 0.04, y - r * 0.06, hz + ez + r * 0.10), "bone", 1))
        cy = ell_y(rx, ry, rz, s * rx * 0.66, -rz * 0.36)
        P.append(bc.blob("cheek", r * 0.11, (s * rx * 0.66, cy + r * 0.01, hz - rz * 0.36), c["cheeks"], 1, (1.0, 0.35, 0.7)))
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
    if "sprout" in c["extras"]:  # a little leaf sprout on top
        top = V((0, r * 0.12, hz + r * 1.16))
        P += chain("stem", [top, top + V(0, 0, r * 0.28), top + V(r * 0.05, -r * 0.03, r * 0.50)], [r * 0.05, r * 0.04, r * 0.03], "leaf_green", 6)
        for s_ in (-1, 1):
            P.append(bc.blob("leaf", r * 0.25, top + V(s_ * r * 0.22, -r * 0.03, r * 0.52), "leaf_light", 1, (1.0, 0.25, 0.6)))
    # hair
    hc, hs = c["hair"], c["hair_style"]
    if hc and hs in ("bob", "buns", "long", "spiky", "fluff", "tails"):
        P.append(bc.blob("hair_cap", r * 1.07, (0, r * 0.20, hz + r * 0.24), hc, 2, (sx, sy * 1.02, sz * 0.98)))
        for i, fx in enumerate((-0.50, 0.0, 0.50)):
            fz = hz + rz * 0.60 - (0.06 if i == 1 else 0.0) * r
            fy = ell_y(rx, ry, rz, fx * rx, fz - hz) - r * 0.015
            P.append(bc.blob("fringe", r * 0.26, (fx * rx, fy, fz), hc, 1, (1.1, 0.55, 0.9)))
    if hc and hs in ("bob", "long", "tails"):
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
    if hs in ("long", "bob"):
        drop = r * (1.5 if hs == "long" else 0.85)
        out.append(bc.blob("hair_back", r * 0.9, (0, ry * 0.78, hz - rz * 0.25 - drop * 0.25), hc, 2, (1.05 * sx, 0.55, 0.85 + drop / r * 0.45)))
    if hs == "tails":
        for s in (-1, 1):
            out += chain("tail", [(s * rx * 0.95, r * 0.2, hz + rz * 0.1), (s * rx * 1.25, r * 0.25, hz - rz * 0.5),
                                  (s * rx * 1.2, r * 0.3, hz - rz * 1.2)], [r * 0.30, r * 0.26, r * 0.06], hc, 8)
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


def ears_parts(c, hz):
    """Separate moving ears: returns {side: (parts, pivot)}; pivot at the ear base."""
    r, sx, sy, sz, rx, ry, rz = head_geom(c)
    kind = c["ears"]
    col = c["ear_col"] or c["skin"]
    inn = c["ear_in"] or "flower_pink"
    res = {}
    if kind not in ("cat", "fox", "bunny"):
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
        else:  # bunny: long rounded ears that flop a little
            b = V((s * rx * 0.40, r * 0.1, hz + rz * 0.88))
            pts = [b, b + V(s * r * 0.15, 0, r * 0.7), b + V(s * r * 0.30, r * 0.05, r * 1.35), b + V(s * r * 0.55, r * 0.15, r * 1.75)]
            parts = chain("ear", pts, [r * 0.24, r * 0.26, r * 0.22, r * 0.12], col, 10)
            parts.append(bc.blob("ear_in", r * 0.12, b + V(s * r * 0.30, -r * 0.20, r * 1.05), inn, 1, (0.6, 0.4, 2.4)))
            res[s] = (parts, b)
    return res


def ants_parts(c, hz):
    r, sx, sy, sz, rx, ry, rz = head_geom(c)
    col, tipc = c["ants"]
    res = {}
    for s in (-1, 1):
        b = V((s * rx * 0.28, -r * 0.20, hz + rz * 0.90))
        pts = [b, b + V(s * r * 0.15, -r * 0.18, r * 0.65), b + V(s * r * 0.50, -r * 0.45, r * 1.10), b + V(s * r * 0.95, -r * 0.50, r * 1.28)]
        res[s] = (chain("ant", pts, [r * 0.07, r * 0.06, r * 0.05, r * 0.04], col, 6, ball_tip=(r * 0.16, tipc)), b)
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
    if c["scarf"]:
        root.append(bc.cone("scarf", br * 1.05, br * 0.95, bh * 0.20, (0, 0, neck - bh * 0.06), c["scarf"], 12))
    if c["body"] != "robe":
        for s in (-1, 1):
            root += [seg("leg", (s * br * 0.55, 0, 0.002), (s * br * 0.55, 0, lh), 0.0026, 0.0028, c["skin"], 8),
                     bc.box("boot", (0.0058, 0.0085, 0.0034), (s * br * 0.55, -0.0012, 0.0017), c["boots"])]
    else:
        for s in (-1, 1):
            root.append(bc.box("boot", (0.0058, 0.0085, 0.0034), (s * br * 0.55, -0.0014, 0.0017), c["boots"]))
    for s in (-1, 1):  # stub shoulders so the sleeves meet the body
        pass

    head = build_head(c, hz)
    if c["horns"]:
        head += horns(c, hz)
    if c["hat"] and c["hat"][0] == "helm":
        pass
    groups = [("", root, (0, 0, 0), ""), ("head", head, (0, 0, neck), "")]
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
    if c["ears"] in ("cat", "fox", "bunny"):
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


ITEM_TILT = {"staff": (18, -24, 0), "spear": (8, -14, 0), "bow": (0, -12, 0), "club": (24, -34, 0), "dipper": (14, -22, 0)}


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
                    ants=("ink", "fire_yellow"), wings=("insect", "bone", None), extras=()),
    # villager girl: cat with a leaf sprout, striped tail, soft ears
    "cat_girl": dict(cat="village", skin="skin_light", hair="hair_brown", hair_style="bob", top="roof_orange",
                     bottom="wall_cream", scarf="leaf_light", boots="hair_brown", extras=("sprout",), ears="cat", ear_col="hair_brown",
                     ear_in="flower_pink", tail=("cat", "hair_brown", "wall_cream"), body="dress", cheeks="flower_pink"),
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
                           hat=("helm", "roof_teal", "wall_cream"), wings=("case", "roof_teal", "wall_cream"),
                           shield=("wall_cream", "roof_teal"), item="spear", smile=False),
    # archer (ours): antlered leaf hood, bow, green and gold
    "antler_archer": dict(cat="village", skin="skin_mid", hair="hair_dark", hair_style="bob", top="wood_mid",
                          bottom="wood_light", scarf="leaf_yellow", boots="wood_dark", horns=("antler", "bone"), extras=("quiver",),
                          hat=("hood", "leaf_green", "leaf_light"), item="bow"),
    # goblin (enemy): mushroom-cap hat, tusks, huge ears, club
    "shroom_goblin": dict(cat="enemy", skin="leaf_light", hair=None, top="wood_mid", bottom="wood_dark",
                          boots="wood_dark", cheeks="leaf_green", ears="goblin", extras=("tusks",),
                          hat=("shroom", "roof_terracotta", "wall_cream"), item="club", head_r=0.0150,
                          squash=(1.08, 0.97, 0.9), smile=False),
}


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    key = argv[0] if argv else "bee_kid"
    bc.clear_scene()
    cat = CHARACTERS[key].get("cat", "village")
    obj = build("ew_%s_%s_v01" % (cat, key), key)
    print("TRIS", key, tri_count(obj))
    bc.save_blend(obj, "char_" + key)
