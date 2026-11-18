"""Quest stand-in replacements (2026-11-18, Claude, Siddharth delegated overnight): quest mote, kite, rain cloud,
dry field (+ wet state), lamb, ghost hand. Two variants (A/B) each. Palette names only; units metres, authored in mm.
Front is -Y, +Z up in Blender (glTF +Y). Every item is built with bc.assemble() so moving parts are children.

  blender --factory-startup -b -P assets/generators/make_quest_items.py -- ALL            (all variants -> assets/blend/quest_<item>_<A|B>.blend)
  blender --factory-startup -b -P assets/generators/make_quest_items.py -- ONE mote A
  blender --factory-startup -b -P assets/generators/make_quest_items.py -- FINAL mote=A kite=B ...   (final + export, v01)

Items: mote, kite, cloud, field, field_wet, lamb, hand.
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
import quest_kit as qk  # noqa: E402
from make_cat import K, bl, bx, cy, nb, seg_tube  # noqa: E402


def gbl(name, r, loc, col, squash=(1, 1, 1), sub=1):
    o = bl(name, r, loc, col, squash, sub)
    bc.paint(o, col, glow=True)
    return o


def prism(name, pts, thick, col, y0=0.0):
    """Flat convex polygon (pts in the XZ plane, mm) extruded `thick` mm along Y, centred on y0."""
    bm = bmesh.new()
    h = thick * K / 2
    f = [bm.verts.new((x * K, y0 * K - h, z * K)) for x, z in pts]
    b = [bm.verts.new((x * K, y0 * K + h, z * K)) for x, z in pts]
    bm.faces.new(f)
    bm.faces.new(b[::-1])
    n = len(pts)
    for i in range(n):
        bm.faces.new((f[i], f[(i + 1) % n], b[(i + 1) % n], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = bc._new_obj(name, bm)
    bc.paint(o, col)
    return nb(o)


def rodmm(p0, p1, t, col):
    return qk.rod(tuple(c * K for c in p0), tuple(c * K for c in p1), t * K, col)


def spk(p0, p1, r, col, seg=4, r_top=0.0):
    return qk.spike(tuple(c * K for c in p0), tuple(c * K for c in p1), r * K, col, seg, r_top * K)


# ================================================================== 1 quest mote (UI marker, emissive allowed: lantern-glow = something alive)
def mote_A():
    """Flame-seed: a round gold seed with a flame tip curling up, a hot lantern-orange belly."""
    p = [gbl("seed", 4.6, (0, 0, 5.2), "fire_yellow", (1, 1, 1.05), 1),
         gbl("belly", 3.0, (0, -1.8, 3.6), "lantern_glow", (1, 0.8, 0.9), 0)]
    tip = spk((0, 0, 7.5), (0.6, 0, 15.5), 3.4, "fire_yellow", 5, 0.0)
    bc.paint(tip, "fire_yellow", glow=True)
    p.append(tip)
    return [("", p, (0, 0, 0), None)], [("glow_anchor", (0, 0, 6.0), "")]


def mote_B():
    """Lantern-spark: a four-point gold spark (diamond cross) round a small orange core."""
    p = [gbl("core", 2.6, (0, 0, 7.5), "lantern_glow", (1, 1, 1), 1)]
    for name, a, b in (("up", (0, 0, 7.5), (0, 0, 15.0)), ("dn", (0, 0, 7.5), (0, 0, 0.0)),
                       ("l", (0, 0, 7.5), (-7.5, 0, 7.5)), ("r", (0, 0, 7.5), (7.5, 0, 7.5)),
                       ("fr", (0, 0, 7.5), (0, -6.0, 7.5)), ("bk", (0, 0, 7.5), (0, 6.0, 7.5))):  # front/back arms: reads from above too
        s = spk(a, b, 3.0, "fire_yellow", 4, 0.0)
        bc.paint(s, "fire_yellow", glow=True)
        p.append(s)
    return [("", p, (0, 0, 0), None)], [("glow_anchor", (0, 0, 7.5), "")]


# ================================================================== 2 kite (diamond kite stuck in a tree; tail is a moving part)
def kite_tail(x0, z0, bows, drop=4.6, cols=("fire_red", "flower_pink", "wall_cream", "fire_red")):
    """String hanging down from (x0, z0) with small bow-tie ribbons; returns the parts (world mm)."""
    parts = []
    z = z0
    x = x0
    for i in range(bows):
        nz = z - drop
        nx = x0 + (1.1 if i % 2 == 0 else -1.1)
        parts.append(rodmm((x, 0, z), (nx, 0, nz), 1.0, "wood_dark"))
        c = cols[i % len(cols)]
        parts.append(prism("bow", [(nx, nz + 0.4), (nx + 4.6, nz + 3.0), (nx + 4.6, nz - 2.4)], 0.9, c, -0.1))
        parts.append(prism("bow", [(nx, nz + 0.4), (nx - 4.6, nz + 3.0), (nx - 4.6, nz - 2.4)], 0.9, c, -0.1))
        parts.append(bx("knot", (1.2, 1.0, 1.2), (nx, -0.1, nz + 0.4), "wood_dark"))
        z, x = nz, nx
    return parts


def kite_A():
    """Classic diamond: four triangles (pink / cream checker), cross spars, a ribbon tail of red, pink and cream bows."""
    cx, cz, hw, hh = 0.0, 26.0, 8.0, 10.5  # centre, half width, half height
    top, bot, lft, rgt = (cx, cz + hh), (cx, cz - hh), (cx - hw, cz), (cx + hw, cz)
    ctr = (cx, cz)
    body = [prism("tl", [ctr, lft, top], 1.0, "flower_pink"), prism("tr", [ctr, top, rgt], 1.0, "wall_cream"),
            prism("bl", [ctr, bot, lft], 1.0, "wall_cream"), prism("br", [ctr, rgt, bot], 1.0, "flower_pink"),
            rodmm((cx, -0.9, cz - hh), (cx, -0.9, cz + hh), 1.0, "wood_mid"), rodmm((cx - hw, -0.9, cz), (cx + hw, -0.9, cz), 1.0, "wood_mid"),
            bx("hub", (2.4, 1.0, 2.4), (cx, -0.9, cz), "fire_red", ry=45)]
    tail = kite_tail(cx, cz - hh, 6)
    return [("", body, (0, 0, 0), None), ("tail", tail, (cx * K, 0, (cz - hh) * K), "")], [("tie_anchor", (0, 0, cz + hh - 1.0), "")]


def kite_B():
    """Tall classic kite shape (wider at the shoulders): pink with a cream inset, red spine and a long tassel tail."""
    cx, cz = 0.0, 27.0
    top, sh_l, sh_r, bot = (cx, cz + 11.5), (cx - 8.5, cz + 3.0), (cx + 8.5, cz + 3.0), (cx, cz - 11.5)
    body = [prism("pink", [top, sh_l, bot, sh_r], 1.0, "flower_pink"),
            prism("inset", [(cx, cz + 7.2), (cx - 4.6, cz + 2.4), (cx, cz - 4.2), (cx + 4.6, cz + 2.4)], 0.6, "wall_cream", -0.55),
            rodmm((cx, -1.1, cz - 11.5), (cx, -1.1, cz + 11.5), 1.6, "fire_red"), rodmm((cx - 8.5, -1.1, cz + 3.0), (cx + 8.5, -1.1, cz + 3.0), 1.6, "fire_red")]
    tail = kite_tail(cx, cz - 11.5, 5, 5.2, ("flower_pink", "fire_red", "wall_cream"))
    tail.append(bl("tassel", 1.7, (0.0, 0.0, 27.0 - 11.5 - 5 * 5.2 - 1.2), "fire_red", (1, 0.5, 1.4), 0))
    return [("", body, (0, 0, 0), None), ("tail", tail, (cx * K, 0, (cz - 11.5) * K), "")], [("tie_anchor", (0, 0, cz + 10.5), "")]


# ================================================================== 3 rain cloud
def puffs(spec, col, sub=1):
    return [bl("puff", r, (x, y, z), col, sq, sub) for (x, y, z, r, sq) in spec]


def cloud_A():
    """Cream cumulus with a silver underbelly (reads as 'a cloud that has gathered rain')."""
    top = puffs([(0, 0, 14, 8.5, (1.1, 1, 0.8)), (-9, 1, 11, 6.6, (1, 1, 0.9)), (9.5, -1, 11, 7.0, (1, 1, 0.9)), (-3, -5, 10.5, 5.8, (1, 1, 0.9)),
                 (4, 5, 11, 5.8, (1, 1, 0.9)), (-15.5, 0, 8.5, 4.6, (1, 1, 0.9)), (16, 0, 8.5, 4.8, (1, 1, 0.9))], "wall_cream", 2)
    belly = [bx("base", (34.0, 17.0, 4.0), (0, 0, 5.0), "bone_shadow"), bx("base2", (28.0, 13.0, 2.4), (0, 0, 2.2), "wood_mid")]
    return [("", top + belly, (0, 0, 0), None)], [("rain_anchor", (0, 0, 3.0), "")]


def cloud_B():
    """Heavy grey rain cloud: darker ash-grey body with cream highlights on the shoulders, a flat dark base."""
    body = puffs([(0, 0, 13, 8.8, (1, 1, 0.85)), (-10, 1, 10, 6.8, (1, 1, 0.85)), (10, -1, 10, 7.2, (1, 1, 0.85)), (-4, -6, 9.5, 6.0, (1, 1, 0.85)),
                  (4.5, 5, 10, 6.0, (1, 1, 0.85))], "ash_grey")
    base = [bx("base", (30.0, 14.0, 4.0), (0, 0, 4.0), "stone")]
    hi = puffs([(-1, -3, 17.4, 4.4, (1, 1, 0.7)), (-9, -2, 14.2, 3.4, (1, 1, 0.7)), (8.5, -3, 14.4, 3.6, (1, 1, 0.7))], "wall_cream")
    return [("", body + base + hi, (0, 0, 0), None)], [("rain_anchor", (0, 0, 3.0), "")]


# ================================================================== 4 dry field and its watered state (2 x 2 cells = 100 x 100 mm)
ROW_Y = (-33.0, -11.0, 11.0, 33.0)
XS = (-33.0, -11.0, 11.0, 33.0)


def jit(i, j, k=0):
    return math.sin(i * 12.9898 + j * 78.233 + k * 3.17) * 0.5 + 0.0  # deterministic -0.5..0.5


def field_soil(wet):
    soil = "dirt_dark" if wet else "dirt_light"
    p = [bx("soil", (100.0, 100.0, 3.0), (0, 0, 1.5), soil), bx("rim", (100.0, 100.0, 1.2), (0, 0, 0.6), "dirt_dark")]
    for y in ROW_Y:
        p.append(bx("ridge", (92.0, 9.0, 3.2), (0, y, 4.6), "dirt_dark" if not wet else "wood_mid"))
    if False:  # cracks (dropped after critic: read as noise) between the rows: thin dark zigzags
        for yy, xs in ((-22.0, (-40, -24, -8, 12, 30)), (0.0, (-32, -14, 6, 24, 40)), (22.0, (-38, -20, 0, 20, 38))):
            for n, x in enumerate(xs):
                p.append(bx("crack", (14.0, 1.7, 0.8), (x, yy + (2.0 if n % 2 else -2.0), 3.3), "dirt_dark", rz=(35 if n % 2 else -35)))
    return p


def maize(wet, i, j):
    x, y = XS[j] + jit(i, j) * 5, ROW_Y[i] + jit(j, i, 1) * 2.0
    z0 = 6.0
    if wet:
        p = [spk((x, y, z0), (x, y, z0 + 28.0), 2.6, "leaf_green", 4, 1.2)]
        for k, sgn in enumerate((-1, 1)):
            p.append(spk((x, y, z0 + 9.0 + k * 6.0), (x + sgn * 13.0, y - 1.0, z0 + 14.0 + k * 6.5), 3.3, "leaf_light", 4, 0.0))
        p.append(spk((x, y, z0 + 27.0), (x, y - 1.0, z0 + 37.0), 2.8, "leaf_yellow", 4, 0.0))
        return p
    a = (i * 5 + j * 3) % 4 * math.pi / 2 + 0.5
    dx, dy = math.cos(a), math.sin(a)
    mid = (x + dx * 3.0, y + dy * 3.0, z0 + 26.0)
    return [spk((x, y, z0), mid, 3.0, "wood_light", 4, 2.0), spk(mid, (mid[0] + dx * 15.0, mid[1] + dy * 15.0, mid[2] - 9.0), 2.8, "leaf_yellow", 4, 0.0),
            spk((x, y, z0 + 7.0), (x - dy * 15.0, y + dx * 15.0, z0 + 1.0), 3.6, "leaf_yellow", 4, 0.0)]


def wheat(wet, i, j):
    x, y = XS[j] + jit(i, j) * 5, ROW_Y[i] + jit(j, i, 1) * 2.0
    z0 = 6.0
    p = []
    for k, ang in enumerate((-0.45, 0.5)):
        dx = math.sin(ang)
        if wet:
            p.append(spk((x, y, z0), (x + dx * 3.0, y, z0 + 12.0), 1.0, "leaf_green", 4, 0.5))
            p.append(spk((x + dx * 3.0, y, z0 + 11.0), (x + dx * 3.4, y, z0 + 16.5), 1.2, "leaf_yellow", 4, 0.0))
        else:
            p.append(spk((x, y, z0), (x + dx * 4.0, y, z0 + 8.5), 1.0, "path_dirt", 4, 0.6))
            p.append(spk((x + dx * 4.0, y, z0 + 8.5), (x + dx * 4.0 + (1 if dx >= 0 else -1) * 4.8, y, z0 + 5.6), 1.2, "leaf_yellow", 4, 0.0))
    return p


def field(variant, wet):
    parts = field_soil(wet)
    fn = maize if variant == "A" else wheat
    for i in range(4):
        for j in range(4):
            parts += fn(wet, i, j)
    return [("", parts, (0, 0, 0), None)], []


# ================================================================== 5 lamb (character-kit parts: head, leg_l, leg_r; ~1 cell, no rig)
WOOL, FACE, HOOF = "wall_cream", "hair_charcoal", "ink"


def lamb_legs(xs, yf, yb, top, length, r):
    out = []
    for suf, sx in (("leg_l", 1), ("leg_r", -1)):
        parts = []
        for y in (yf, yb):
            parts += [cy("leg", r, r * 0.85, length, (sx * xs, y, top - length / 2), FACE, 5),
                      bx("hoof", (r * 2.0, r * 2.2, 1.2), (sx * xs, y - 0.2, 0.7), HOOF)]
        out.append((suf, parts, (sx * xs * K, (yf + yb) / 2 * K, top * K), ""))
    return out


def lamb_head(hx, hy, hz, hr, ear_lift, bow):
    h = [bl("skull", hr, (hx, hy, hz), FACE, (0.95, 1.05, 1.0), 1)]
    for sx in (-1, 1):
        h.append(bl("eye", hr * 0.26, (hx + sx * hr * 0.55, hy - hr * 0.78, hz + hr * 0.25), "bone", (1, 1, 1), 0))
        h.append(bl("pupil", hr * 0.14, (hx + sx * hr * 0.58, hy - hr * 0.98, hz + hr * 0.25), HOOF, (1, 1, 1), 0))
        h.append(bx("ear", (hr * 0.8, hr * 0.45, hr * 0.26), (hx + sx * hr * 1.1, hy + hr * 0.2, hz + hr * 0.15 + ear_lift), FACE, ry=sx * (22 - ear_lift * 4), rz=sx * -12))
    h.append(bl("topknot", hr * 0.6, (hx, hy + hr * 0.2, hz + hr * 0.95), WOOL, (1.2, 1, 0.8), 0))
    h.append(bl("ruff", hr * 0.75, (hx, hy + hr * 0.95, hz - hr * 0.1), WOOL, (1.2, 0.8, 1.0), 0))
    if bow:
        h += [bx("bow", (hr * 0.55, hr * 0.3, hr * 0.5), (hx + hr * 0.5, hy + hr * 0.1, hz + hr * 1.05), "flower_pink", rz=30),
              bx("bow", (hr * 0.55, hr * 0.3, hr * 0.5), (hx + hr * 1.0, hy + hr * 0.1, hz + hr * 1.0), "flower_pink", rz=-30),
              bl("knot", hr * 0.22, (hx + hr * 0.75, hy + hr * 0.1, hz + hr * 1.05), "fire_red", (1, 1, 1), 0)]
    return h


def lamb_A():
    """Cloud-puff lamb: round woolly body of chunky curls, stubby legs, big dark head (the sheep's look, younger)."""
    c = (0, 1.0, 9.0)
    root = [bl("core", 6.6, c, WOOL, (1.0, 1.25, 0.9), 1)]
    for n in range(8):
        a = (n + 0.5) / 8 * 2 * math.pi
        root.append(bl("curl", 3.6, (c[0] + math.cos(a) * 5.2, c[1] + math.sin(a) * 6.6, c[2] + 0.5), WOOL, (1, 1, 0.9), 0))
    root += [bl("crown", 3.8, (0, -1.5, 14.0), WOOL, (1, 1, 0.8), 0), bl("crown", 3.8, (0, 4.5, 13.6), WOOL, (1, 1, 0.8), 0),
             bl("tail", 2.0, (0, 9.2, 10.5), WOOL, (1, 1, 1.2), 0)]
    head = lamb_head(0, -10.5, 11.0, 4.9, 0.0, True)
    return [("", root, (0, 0, 0), None), ("head", head, (0, -7.0 * K, 10.0 * K), "")] + lamb_legs(3.4, -4.0, 5.0, 5.6, 5.0, 1.6), []


def lamb_B():
    """Leggy foal-like lamb: slimmer fleece, long thin legs, oversized head with perky ears and a pink bow."""
    c = (0, 1.0, 11.5)
    root = [bl("core", 5.8, c, WOOL, (1.0, 1.35, 0.85), 1)]
    for n in range(7):
        a = (n + 0.5) / 7 * 2 * math.pi
        root.append(bl("curl", 3.2, (c[0] + math.cos(a) * 4.4, c[1] + math.sin(a) * 6.8, c[2] + 0.3), WOOL, (1, 1, 0.9), 0))
    root += [bl("crown", 3.4, (0, 0.0, 15.2), WOOL, (1, 1, 0.8), 0), bl("tail", 2.0, (0, 9.2, 12.8), WOOL, (1, 1, 1.4), 0)]
    head = lamb_head(0, -10.0, 14.5, 5.4, 1.2, True)
    head.append(bl("neck", 2.6, (0, -7.2, 12.8), WOOL, (1, 1.2, 1.2), 0))
    return [("", root, (0, 0, 0), None), ("head", head, (0, -6.5 * K, 13.0 * K), "")] + lamb_legs(3.0, -4.2, 5.4, 8.5, 8.0, 1.6), []


# ================================================================== 6 ghost hand (a gold glove in a pinch; origin = the pinch point, fingers point down)
def hand_common(tube):
    """tube(name, pts, radii, col) -> parts. Returns groups with palm (root), thumb, index, fingers. Origin = pinch point."""
    palm = [bx("palm", (14.0, 5.5, 9.0), (6.0, 3.0, 19.0), "fire_yellow"),
            bx("pad", (11.0, 1.2, 5.0), (6.0, 0.2, 19.0), "rarity_gold"),
            cy("wrist", 5.4, 5.4, 7.0, (6.0, 3.0, 23.0), "rarity_gold", 6),
            cy("cuff", 6.2, 5.8, 2.6, (6.0, 3.0, 26.8), "fire_red", 6)]
    thumb_pts = [(-1.0, 0.0, 17.0), (-6.4, -1.4, 11.0), (-3.4, -1.0, 5.4), (-1.0, -0.3, 1.9)]
    index_pts = [(1.5, 1.0, 14.5), (1.6, 0.4, 8.0), (1.0, -0.3, 1.9)]
    thumb = tube("thumb", thumb_pts, [3.0, 2.7, 2.3, 2.0], "fire_yellow")
    index = tube("index", index_pts, [2.7, 2.4, 2.0], "fire_yellow")
    fingers = []
    for x in (5.0, 8.6, 12.2):
        fingers += tube("finger", [(x, 1.0, 14.5), (x, -1.6, 11.0), (x, -2.4, 7.6)], [2.2, 2.1, 1.9], "rarity_gold")
    return [("", palm, (0, 0, 0), None), ("thumb", thumb, (-1.0 * K, 0, 17.0 * K), ""), ("index", index, (1.5 * K, 1.0 * K, 14.5 * K), ""),
            ("fingers", fingers, (8.6 * K, 1.0 * K, 14.5 * K), "")], [("pinch_anchor", (0, -0.3, 1.0), "")]


def hand_A():
    """Soft glove: round faceted finger tubes with ball joints (a cartoon work glove)."""
    return hand_common(lambda n, pts, rs, col: seg_tube(n, pts, rs, col, 6))


def hand_B():
    """Blocky mitten glove: square rods, chunky and readable from a distance."""
    def tube(n, pts, rs, col):
        out = []
        for i in range(len(pts) - 1):
            out.append(rodmm(pts[i], pts[i + 1], (rs[i] + rs[i + 1]) * 0.9, col))
        out.append(bl(n + "_tip", rs[-1] * 1.05, pts[-1], col, (1, 1, 1), 0))
        return out
    return hand_common(tube)


def hand2():
    """v02 (coordinator round 2): slimmer palm, index and thumb tips overlap and touch, three relaxed fingers: a readable pinch."""
    tube = lambda n, pts, rs, col: seg_tube(n, pts, rs, col, 6)
    palm = [bx("palm", (9.5, 4.0, 8.0), (5.5, 3.0, 19.5), "rarity_gold"),
            bx("pad", (8.0, 1.0, 5.0), (5.5, 0.6, 20.0), "fire_yellow"),
            cy("wrist", 3.8, 3.8, 6.0, (5.5, 3.0, 25.0), "rarity_gold", 6),
            cy("cuff", 4.9, 4.6, 2.4, (5.5, 3.0, 28.0), "fire_red", 6)]
    thumb = tube("thumb", [(0.0, 0.5, 18.0), (-5.0, -1.2, 12.5), (-3.6, -1.2, 6.2), (-0.2, -0.9, 2.0)], [2.8, 2.5, 2.2, 2.0], "fire_yellow")
    index = tube("index", [(2.2, 1.0, 15.5), (1.9, 0.0, 9.5), (0.7, -0.9, 2.0)], [2.4, 2.2, 2.0], "fire_yellow")
    fingers = []
    for x, ln, sp in ((5.0, 0.0, 0.0), (7.9, 0.0, 0.9), (10.5, 2.5, 1.8)):
        fingers += tube("finger", [(x, 1.0, 15.5), (x + sp * 0.5, -0.8, 9.5 + ln * 0.5), (x + sp, -2.4, 4.5 + ln)], [1.9, 1.8, 1.6], "fire_yellow")
    return [("", palm, (0, 0, 0), None), ("thumb", thumb, (0.0, 0.5 * K, 18.0 * K), ""), ("index", index, (2.2 * K, 1.0 * K, 15.5 * K), ""),
            ("fingers", fingers, (7.9 * K, 1.0 * K, 15.5 * K), "")], [("pinch_anchor", (0, -1.0, 1.0), "")]


ITEMS = {  # key: (short blend name, asset name, category, footprint, place, {letter: fn})
    "mote": ("ew_ui_quest_mote", "ui", "1x1", "marker", {"A": mote_A, "B": mote_B}),
    "kite": ("ew_village_kite", "village", "1x1", "prop", {"A": kite_A, "B": kite_B}),
    "cloud": ("ew_village_rain_cloud", "village", "1x1", "sky", {"A": cloud_A, "B": cloud_B}),
    "field": ("ew_village_dry_field", "village", "2x2", "ground", {"A": lambda: field("A", False), "B": lambda: field("B", False)}),
    "field_wet": ("ew_village_dry_field_wet", "village", "2x2", "ground", {"A": lambda: field("A", True), "B": lambda: field("B", True)}),
    "lamb": ("ew_village_lamb", "village", "1x1", "ground", {"A": lamb_A, "B": lamb_B}),
    "hand2": ("ew_ui_ghost_hand", "ui", "1x1", "marker", {"A": hand2}),
    "hand": ("ew_ui_ghost_hand", "ui", "1x1", "marker", {"A": hand_A, "B": hand_B}),
}


SCALE = {"lamb": 1.7}  # lamb: ~33 mm long, about the cat v02 size (stand-in was the bunny kid x0.8)


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def build(key, letter, ver="v01"):  # hand2 = ghost hand v02
    base, cat, foot, place, fns = ITEMS[key]
    bc.clear_scene()
    res = fns[letter]()
    groups, anchors = res[0], res[1]
    name = "%s_%s" % (base, ver)
    root = bc.assemble(name, groups, bevel_min=0.004)
    root["ew_footprint"], root["ew_front"], root["ew_place"] = foot, "-Y", place
    bpy.context.view_layer.update()
    objs = [root] + list(root.children_recursive)
    zs = [(o.matrix_world @ v.co).z for o in objs if o.type == "MESH" for v in o.data.vertices]
    shift = min(zs)
    if abs(shift) > 1e-5:  # lowest point exactly on the ground (origin at the base)
        for v in root.data.vertices:
            v.co.z -= shift
        for c in root.children:
            c.location.z -= shift
        bpy.context.view_layer.update()
    sc = SCALE.get(key, 1.0)
    if sc != 1.0:  # whole-model scale (lamb): parts' vertices and the child offsets, about the origin at the base
        for o in objs:
            if o.type == "MESH":
                for v in o.data.vertices:
                    v.co *= sc
        for c in root.children:
            c.location *= sc
        shift *= sc
        bpy.context.view_layer.update()
    for an, loc, parent in anchors:
        bc.anchor(root, an, (loc[0] * K, loc[1] * K, loc[2] * K - (shift if abs(shift) > 1e-5 else 0.0)), parent, size=0.008)
    total = sum(tris(o) for o in objs if o.type == "MESH")
    d = root.dimensions
    print("QUEST %s %s %s: %d tris, root %.1f x %.1f x %.1f mm, parts %s" % (name, letter, key, total, d.x * 1000, d.y * 1000, d.z * 1000,
                                                                          [c.name.split("__")[-1] for c in root.children if c.type == "MESH"]))
    return root


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["ALL"]
    if args[0] == "ALL":
        for key, spec in ITEMS.items():
            for letter in spec[4]:
                root = build(key, letter)
                bc.save_blend(root, "quest_%s_%s" % (key, letter))
    elif args[0] == "ONE":
        root = build(args[1], args[2])
        bc.save_blend(root, "quest_%s_%s" % (args[1], args[2]))
    elif args[0] == "FINAL":
        for kv in args[1:]:
            key, letter = kv.split("=")
            root = build(key, letter, "v02" if key == "hand2" else "v01")
            bc.save_blend(root, "quest_" + key)
            print("EXPORT", bc.export_glb(root, ITEMS[key][1]))
