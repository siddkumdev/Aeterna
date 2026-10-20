"""W01 Island base: the 12 x 12 cell board (0.6 m x 0.6 m, flat grass top). Run:
    blender --factory-startup -b -P assets/generators/make_island.py -- A      (variants A-D, saved as island_<V>.blend)

Shared rules (art_bible 14 + decisions): flat top at z = HEIGHT, bevelled rim, rounded corners, stone sides,
a darker rim so the board separates from a real table. The grass top spans exactly 12 x 12 cells; the sides
taper IN below it so the whole model stays inside 0.6 x 0.6.

Dressing ("rich", Siddharth 2026-10-20): patches are flat 1 mm discs laid over the whole top (they never poke
through path tiles or building bases); 3D accents (tufts, flowers, stones) stay in the outer ring, one cell
wide, where the forest backdrop stands, so towers and paths placed on the top do not clip them.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import blender_common as bc  # noqa: E402
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

HALF = 0.30          # half the board (6 cells)
HEIGHT = 0.09        # top of the grass above the base (0.07 looked thin from the player's seat)
RADIUS = 0.035       # corner radius of the top
GRASS_T = 0.006      # grass layer thickness
DIRT_T = 0.004       # dirt layer under it
LIP = 0.002          # the grass overhangs the dirt by this much
EDGE = 0.0485        # dressing stays inside this distance from the centre


def ring(half_w, half_d, r, segs=3):
    """Rounded-rectangle outline, counter-clockwise, as (x, y) points."""
    r = max(min(r, half_w - 1e-4, half_d - 1e-4), 1e-4)
    pts = []
    for cx, cy, a0 in ((half_w - r, half_d - r, 0), (-half_w + r, half_d - r, 90),
                       (-half_w + r, -half_d + r, 180), (half_w - r, -half_d + r, 270)):
        for k in range(segs + 1):
            a = math.radians(a0 + 90 * k / segs)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def slab(name, z0, z1, col, inset_top=0.0, inset_bot=None, r=RADIUS, segs=3, half=HALF):
    """Rounded-rectangle prism from z0 (bottom) to z1 (top); the outline shrinks by inset_top / inset_bot."""
    inset_bot = inset_top if inset_bot is None else inset_bot
    bm = bmesh.new()
    top = [bm.verts.new((x, y, z1)) for x, y in ring(half - inset_top, half - inset_top, r - inset_top, segs)]
    bot = [bm.verts.new((x, y, z0)) for x, y in ring(half - inset_bot, half - inset_bot, r - inset_bot, segs)]
    n = len(top)
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([bot[i], bot[j], top[j], top[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = bc._new_obj(name, bm)
    bc.paint(o, col)
    return o


def disc(name, x, y, rx, ry, z, h, col, rot=0.0, n=7, rnd=None):
    """Flat irregular patch (n-gon with jittered radii), h thick, bottom at z. Open underneath."""
    rnd = rnd or random
    bm = bmesh.new()
    top, bot = [], []
    for i in range(n):
        a = 2 * math.pi * i / n + math.radians(rot)
        k = rnd.uniform(0.78, 1.0)
        px, py = rx * k * math.cos(a), ry * k * math.sin(a)
        c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
        px, py = px * c - py * s, px * s + py * c  # rotate the ellipse
        top.append(bm.verts.new((x + px, y + py, z + h)))
        bot.append(bm.verts.new((x + px, y + py, z)))
    bm.faces.new(top)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([bot[i], bot[j], top[j], top[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = bc._new_obj(name, bm)
    bc.paint(o, col)
    o["no_bevel"] = True
    return o


def spike(name, x, y, r, h, col, segs=4, z=HEIGHT, rot=0.0):
    o = bc.cone(name, r, 0.0, h, (x, y, z + h / 2 - 0.0004), col, segs, rot)
    o["no_bevel"] = True
    return o


def nub(name, x, y, r, h, col, segs=5, z=HEIGHT, rot=0.0):
    """Small stone / bud: a short frustum."""
    o = bc.cone(name, r, r * 0.6, h, (x, y, z + h / 2 - 0.0004), col, segs, rot)
    o["no_bevel"] = True
    return o


def inside(x, y, margin=0.0):
    """Is (x, y) on the grass top (rounded corners cut off), `margin` in from the edge?"""
    m = HALF - margin
    if abs(x) > m or abs(y) > m:
        return False
    cx, cy = abs(x) - (m - RADIUS), abs(y) - (m - RADIUS)
    return not (cx > 0 and cy > 0 and cx * cx + cy * cy > RADIUS * RADIUS)


def edge_dist(x, y):
    return HALF - max(abs(x), abs(y))


def top_dressing(seed, flowers=("wall_cream", "roof_terracotta", "leaf_yellow"), n_patch=26, n_tuft=14, n_stone=6,
                 n_flower=10):
    """Patches over the whole top (flat), accents in the outer ring only."""
    rnd = random.Random(seed)
    parts = []
    z = HEIGHT
    # lighter and darker grass patches; darker and more of them toward the forest edge
    placed = []  # (x, y, radius): patches never overlap, since equal-height tops would z-fight

    def free(x, y, r):
        return all((x - px) ** 2 + (y - py) ** 2 > (r + pr + 0.002) ** 2 for px, py, pr in placed)

    k = 0
    tries = 0
    while k < n_patch and tries < 4000:
        tries += 1
        x, y = rnd.uniform(-EDGE * 6, EDGE * 6), rnd.uniform(-EDGE * 6, EDGE * 6)
        x, y = max(-0.288, min(0.288, x)), max(-0.288, min(0.288, y))
        rx, ry = rnd.uniform(0.016, 0.034), rnd.uniform(0.012, 0.026)
        if not inside(x, y, 0.014) or not free(x, y, max(rx, ry)):
            continue
        placed.append((x, y, max(rx, ry)))
        near = edge_dist(x, y) < 0.06
        col = rnd.choice(("leaf_green", "leaf_green", "leaf_light")) if near else rnd.choice(("leaf_light", "leaf_light", "leaf_green"))
        parts.append(disc("patch", x, y, rx, ry, z - 0.0001, 0.0011, col,
                          rnd.uniform(0, 180), 6, rnd))
        k += 1
    # a few worn dirt patches near the edge ring
    for _ in range(4):
        side = rnd.choice((-1, 1))
        x, y = (side * rnd.uniform(0.2, 0.275), rnd.uniform(-0.25, 0.25)) if rnd.random() < 0.5 else \
               (rnd.uniform(-0.25, 0.25), side * rnd.uniform(0.2, 0.275))
        rx, ry = rnd.uniform(0.012, 0.02), rnd.uniform(0.008, 0.014)
        if inside(x, y, 0.016) and free(x, y, max(rx, ry)):
            placed.append((x, y, max(rx, ry)))
            parts.append(disc("dirt", x, y, rx, ry, z - 0.0001, 0.0012,
                              "path_dirt", rnd.uniform(0, 180), 6, rnd))

    def ring_point(lo=0.010, hi=0.050):
        while True:
            x, y = rnd.uniform(-0.29, 0.29), rnd.uniform(-0.29, 0.29)
            if inside(x, y, 0.008) and lo < edge_dist(x, y) < hi:
                return x, y

    for _ in range(n_tuft):  # grass tufts: a cluster of three blades
        x, y = ring_point()
        for dx, dy, h in ((0, 0, 0.015), (0.0075, 0.004, 0.0105), (-0.0055, 0.0065, 0.0085)):
            parts.append(spike("tuft", x + dx, y + dy, 0.0055, h, rnd.choice(("leaf_green", "leaf_light")), 3,
                               rot=rnd.uniform(0, 90)))
    for _ in range(n_stone):
        x, y = ring_point()
        parts.append(nub("stone", x, y, rnd.uniform(0.007, 0.010), rnd.uniform(0.006, 0.010),
                         rnd.choice(("stone", "stone", "stone_dark")), 4, rot=rnd.uniform(0, 90)))
    for _ in range(n_flower):
        x, y = ring_point(0.012, 0.055)
        parts.append(nub("flower", x, y, 0.0045, 0.0065, rnd.choice(flowers), 3, rot=rnd.uniform(0, 90)))
    return parts


def base_layers():
    """Grass top + dirt layer, shared by every variant (z from HEIGHT - GRASS_T - DIRT_T up)."""
    zg0 = HEIGHT - GRASS_T
    zd0 = zg0 - DIRT_T
    grass = slab("grass", zg0, HEIGHT, "grass")
    dirt = slab("dirt_layer", zd0, zg0, "path_dirt", LIP, LIP, RADIUS)
    return [grass, dirt], zd0


def joints(z0, z1, half, count, col="stone_dark", thick=0.0022, out=0.0012, skip_corner=0.06):
    """Thin vertical joint lines (blocks, planks) on the four faces of a slab, `count` per side, inside the flat
    part of each face (corners are rounded, so none within skip_corner of a corner)."""
    parts = []
    span = half - skip_corner
    for k in range(count):
        t = -span + (k + 0.5) * (2 * span) / count
        for face in range(4):
            if face % 2 == 0:
                size, loc = (thick, out * 2, z1 - z0), (t, (half if face == 0 else -half), (z0 + z1) / 2)
            else:
                size, loc = (out * 2, thick, z1 - z0), ((half if face == 1 else -half), t, (z0 + z1) / 2)
            o = bc.box("joint", size, loc, col)
            o["no_bevel"] = True
            parts.append(o)
    return parts


# ---------------------------------------------------------------- variants
def variant_a():
    """A Strata slab (moodboard #2): a clean slab with layered stone strata that step in toward the base. Calm,
    cube-like silhouette; the darkest course is at the bottom so the rim separates from the table."""
    parts, zd0 = base_layers()
    spec = [("stone", 0.015, 0.004), ("path_stone", 0.013, 0.007), ("stone", 0.016, 0.010), ("stone_dark", 0.014, 0.014),
            ("stone", 0.012, 0.018)]
    z = zd0
    insets = [0.003] + [s[2] for s in spec]
    for i, (col, h, ins) in enumerate(spec):
        parts.append(slab("strata", z - h, z, col, insets[i], ins, RADIUS))
        z -= h
    parts.append(slab("foot", 0.0, z, "stone_dark", insets[-1], insets[-1] + 0.002, RADIUS))
    return parts


def variant_b():
    """B Cliff hem (moodboard #1): faceted boulders hang round the edge like a cliff, wide at the top and narrowing
    below, over a dark core; a few smaller boulders sit lower between them."""
    rnd = random.Random(11)
    parts, zd0 = base_layers()
    parts.append(slab("core", 0.0, zd0, "stone", 0.014, 0.028, RADIUS))
    cols = ("stone", "path_stone", "stone", "stone_dark")
    inner = HALF - 0.040
    n = 7
    ts = [-inner + (i + 0.5) * (2 * inner) / n for i in range(n)]
    big = []
    for t in ts:
        big += [(t, HALF - 0.038), (-t, -HALF + 0.038), (HALF - 0.038, -t), (-HALF + 0.038, t)]
    for cx, cy in ((1, 1), (-1, 1), (-1, -1), (1, -1)):  # bigger boulders that wrap the rounded corners
        big.append((cx * (HALF - 0.040), cy * (HALF - 0.040)))
    for i, (x, y) in enumerate(big):
        h = rnd.uniform(0.060, 0.078)
        o = bc.cone("rock", rnd.uniform(0.024, 0.030), rnd.uniform(0.038, 0.044), h, (x, y, zd0 - h / 2 + 0.002), cols[i % 4], 5,
                    rnd.uniform(0, 70))
        o["no_bevel"] = True
        parts.append(o)
    return parts


def variant_c():
    """C Block plinth (moodboard #2 base + #3 cobbles): grass on two courses of cut stone with carved joints and a
    stepped foot. Tidy, built, village-like."""
    parts, zd0 = base_layers()
    c1 = slab("course", zd0 - 0.026, zd0, "path_stone", 0.003, 0.003, RADIUS)
    c2 = slab("course", zd0 - 0.052, zd0 - 0.026, "stone", 0.006, 0.006, RADIUS)
    foot = slab("foot", 0.0, zd0 - 0.052, "stone_dark", 0.012, 0.018, RADIUS)
    parts += [c1, c2, foot]
    parts += joints(zd0 - 0.026, zd0, HALF - 0.003, 4)
    parts += joints(zd0 - 0.052, zd0 - 0.026, HALF - 0.006, 4)
    return parts


def variant_d():
    """D Toy tray: a chunky wooden fascia with plank lines and corner posts on a stone foot, like a tabletop game
    board. Warm wood rim that separates clearly from the real table."""
    parts, zd0 = base_layers()
    fas = slab("fascia", zd0 - 0.038, zd0, "wood_light", 0.003, 0.003, RADIUS)
    band = slab("band", zd0 - 0.046, zd0 - 0.038, "wood_dark", 0.003, 0.003, RADIUS)
    foot = slab("foot", 0.0, zd0 - 0.046, "stone_dark", 0.010, 0.014, RADIUS)
    parts += [fas, band, foot]
    parts += joints(zd0 - 0.038, zd0, HALF - 0.003, 5, "wood_dark", 0.0016, 0.0010)
    for cx, cy in ((1, 1), (-1, 1), (-1, -1), (1, -1)):
        post = bc.cone("post", 0.0135, 0.0135, 0.054, (cx * (HALF - RADIUS * 0.55), cy * (HALF - RADIUS * 0.55), zd0 - 0.025),
                       "wood_dark", 6, 30)
        post["no_bevel"] = True
        parts.append(post)
    return parts


# ---------------------------------------------------------------- round 2 (E-H): lush Clash-style grass
# Siddharth 2026-10-20 rejected A-D as too plain and sent two references (cube terraces with leafy grass, and a
# mobile arena with painted leaf clumps): the grass must look lush. Original shapes only; no leaf cards, so the
# leaf look is built from flat star-shaped clumps in several greens (laid in layers so nothing shares a height)
# plus low 3D ferns and bushes in the outer ring.
def perimeter(half, r, step, phase=0.0, segs=12):
    """Points along the rounded-rectangle outline every `step` metres, with outward normals."""
    pts = ring(half, half, r, segs)
    out = []
    n = len(pts)
    seg_len = [math.dist(pts[i], pts[(i + 1) % n]) for i in range(n)]
    total = sum(seg_len)
    t = phase * step
    while t < total:
        acc = 0.0
        for i in range(n):
            if acc + seg_len[i] >= t:
                f = (t - acc) / seg_len[i]
                a, b = pts[i], pts[(i + 1) % n]
                x, y = a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f
                nx, ny = (b[1] - a[1]), -(b[0] - a[0])
                ln = math.hypot(nx, ny) or 1.0
                out.append((x, y, nx / ln, ny / ln))
                break
            acc += seg_len[i]
        t += step
    return out


def star(name, x, y, R, z, col, rnd, n=5, rot=None, inner=0.5):
    """Flat leaf-clump polygon: an n-pointed star with jittered points, single face, no thickness (faces up)."""
    rot = rnd.uniform(0, 360) if rot is None else rot
    bm = bmesh.new()
    vs = []
    for i in range(2 * n):
        a = math.radians(rot) + math.pi * i / n
        rr = R * rnd.uniform(0.85, 1.05) if i % 2 == 0 else R * inner * rnd.uniform(0.9, 1.1)
        vs.append(bm.verts.new((x + rr * math.cos(a), y + rr * math.sin(a), z)))
    bm.faces.new(vs)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.z < 0:  # faces up
            f.normal_flip()
    o = bc._new_obj(name, bm)
    bc.paint(o, col)
    o["no_bevel"] = True
    return o


def frond(name, x, y, R, h, col, rnd, n=5):
    """Raised leaf rosette: n pointed leaves whose tips rise h above the ground and whose centre stays low, so each
    leaf has two facets that catch the light differently (faceted low-poly leaves, no leaf cards; 2n triangles)."""
    z0 = HEIGHT
    rot = rnd.uniform(0, 360)
    bm = bmesh.new()
    c = bm.verts.new((x, y, z0 + 0.0004))
    inner, tips = [], []
    for k in range(n):
        a_t = math.radians(rot + 360 * k / n)
        a_i = math.radians(rot + 360 * (k + 0.5) / n)
        tips.append(bm.verts.new((x + R * rnd.uniform(0.9, 1.05) * math.cos(a_t), y + R * math.sin(a_t) * rnd.uniform(0.9, 1.05), z0 + h * rnd.uniform(0.8, 1.15))))
        inner.append(bm.verts.new((x + 0.66 * R * math.cos(a_i), y + 0.66 * R * math.sin(a_i), z0 + 0.0014)))
    for k in range(n):
        bm.faces.new([c, inner[k - 1], tips[k]])
        bm.faces.new([c, tips[k], inner[k]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    o = bc._new_obj(name, bm)
    bc.paint(o, col)
    o["no_bevel"] = True
    return o


def _cone(name, rb, rt, h, x, y, z, col, segs):
    o = bc.cone(name, rb, rt, h, (x, y, z + h / 2 - 0.0004), col, segs, random.uniform(0, 60))
    o["no_bevel"] = True
    return o


def _lean_blade(name, x, y, r, h, ang, col):
    """A thin pyramid leaning outward 28 degrees from (x, y)."""
    o = bc.cone(name, r, 0.0, h, (0, 0, h / 2), col, 3)
    o["no_bevel"] = True
    o.rotation_euler = (0, math.radians(28), ang)
    bpy.context.view_layer.update()
    bc.apply_transforms(o)
    for v in o.data.vertices:
        v.co.x += x
        v.co.y += y
        v.co.z += HEIGHT - 0.0004
    return o


def lush_top(seed, n_big=5, n_frond=140, frond_r=(0.032, 0.050), frond_h=(0.0042, 0.0058), n_fern=9, n_bush=5, n_mush=4, n_stone=5, n_flower=6,
             bush_cols=("leaf_green", "leaf_light", "leaf_light"), accent="roof_orange"):
    """The lush top: big soft light/dark areas, leaf clumps everywhere, and ferns, bushes, mushrooms, stones and
    flowers in the outer ring (they never stand where towers and paths go)."""
    rnd = random.Random(seed)
    parts = []
    z0 = HEIGHT

    def spot(margin=0.014, lo=0.0, hi=1.0):
        while True:
            x, y = rnd.uniform(-0.29, 0.29), rnd.uniform(-0.29, 0.29)
            if inside(x, y, margin) and lo <= edge_dist(x, y) <= hi:
                return x, y

    # layer 1: big soft areas (light and dark), +0.4 mm; they do not overlap each other
    big = []
    k = tries = 0
    while k < n_big and tries < 3000:
        tries += 1
        x, y = spot(0.02)
        R = rnd.uniform(0.045, 0.07)
        if all(math.dist((x, y), (bx, by)) > R + br + 0.004 for bx, by, br in big):
            big.append((x, y, R))
            parts.append(star("area", x, y, R, z0 + 0.0004, "leaf_light", rnd, 6, inner=0.78))
            k += 1
    # raised leaf rosettes everywhere (they may overlap: different heights, no flat tops to z-fight). Darker and
    # yellower toward the rim, lighter in the middle. Their tips stay under 6 mm, below the path tiles
    # (to be modelled 8 mm high) so paths and building bases cover them.
    placed = []
    for _ in range(n_frond):
        x, y = spot(0.014)
        R = rnd.uniform(*frond_r)
        near = edge_dist(x, y) < 0.07
        col = rnd.choice(("leaf_green", "leaf_green", "leaf_light", "grass")) if near else             rnd.choice(("leaf_light", "leaf_light", "leaf_light", "grass", "grass", "leaf_green"))
        parts.append(frond("frond", x, y, R, rnd.uniform(*frond_h), col, rnd, 6))

    solid = []

    def ring_spot(lo=0.012, hi=0.052, clear=0.0):
        for _ in range(500):
            x, y = spot(0.010, lo, hi)
            if all(math.dist((x, y), (qx, qy)) > qr + clear for qx, qy, qr in solid):
                return x, y
        return spot(0.010, lo, hi)

    for _ in range(n_bush):  # bushes: two stacked facets, some with an autumn-orange top
        x, y = ring_spot(0.022, 0.058, 0.022)
        solid.append((x, y, 0.022))
        c = rnd.choice(bush_cols)
        parts.append(_cone("bush", 0.022, 0.017, 0.014, x, y, z0, c, 6))
        top = accent if accent and rnd.random() < 0.35 else c
        parts.append(_cone("bush", 0.017, 0.008, 0.014, x + rnd.uniform(-0.002, 0.002), y + rnd.uniform(-0.002, 0.002), z0 + 0.0135, top, 6))
    for _ in range(n_fern):  # ferns: four leaning blades
        x, y = ring_spot(0.012, 0.05, 0.008)
        solid.append((x, y, 0.008))
        for i in range(3):
            a = math.radians(i * 120 + rnd.uniform(0, 40))
            parts.append(_lean_blade("fern", x + 0.003 * math.cos(a), y + 0.003 * math.sin(a), 0.0035, 0.015, a,
                                     "leaf_light" if i % 2 else "leaf_green"))
    for _ in range(n_mush):  # mushrooms: cream stem, terracotta cap
        x, y = ring_spot(0.014, 0.055, 0.008)
        solid.append((x, y, 0.007))
        parts.append(_cone("stem", 0.0038, 0.0034, 0.009, x, y, z0, "wall_cream", 5))
        parts.append(_cone("cap", 0.0098, 0.0035, 0.007, x, y, z0 + 0.0085, "roof_terracotta", 6))
    for _ in range(n_stone):
        x, y = ring_spot(0.012, 0.054, 0.010)
        solid.append((x, y, 0.009))
        parts.append(_cone("stone", rnd.uniform(0.011, 0.016), rnd.uniform(0.006, 0.010), rnd.uniform(0.009, 0.014), x, y, z0,
                           rnd.choice(("stone", "stone", "stone_dark", "path_stone")), 5))
    for _ in range(n_flower):
        x, y = ring_spot(0.012, 0.055, 0.006)
        solid.append((x, y, 0.005))
        parts.append(_cone("flower", 0.0058, 0.0020, 0.009, x, y, z0, rnd.choice(("wall_cream", "wall_cream", "roof_orange")), 4))
    return parts


def fringe(zlip, count_step=0.07, drop=0.012, col="leaf_green"):
    """Grass blades hanging over the lip (tips down), every `count_step` m round the rim."""
    parts = []
    for x, y, nx, ny in perimeter(HALF - 0.004, RADIUS, count_step):
        o = bc.cone("fringe", 0.0, 0.0065, drop, (x, y, zlip - drop / 2 + 0.002), col, 3)
        o["no_bevel"] = True
        parts.append(o)
    return parts


def embed_rocks(zs, count, rnd, cols=("stone", "stone_dark", "stone"), inset=0.004):
    """Rocks half-buried in the earth sides at the given heights (round the rim, fitted inside the footprint)."""
    parts = []
    for x, y, nx, ny in perimeter(HALF - inset, RADIUS, 2.3 / count, 0.3):
        r = rnd.uniform(0.012, 0.019)
        o = bc.cone("rock", r, r * 0.65, rnd.uniform(0.008, 0.013), (x, y, rnd.choice(zs)), rnd.choice(cols), 4, rnd.uniform(0, 70))
        o["no_bevel"] = True
        parts.append(o)
    return parts


def earth_sides(zd0, tones=("path_dirt", "wood_light", "path_dirt"), heights=(0.020, 0.010, 0.020), foot="stone_dark", i0=0.003,
                step=0.003):
    """Brown earth under the grass: bands that step in a little, then a dark foot."""
    parts = []
    z = zd0
    ins = i0
    for col, h in zip(tones, heights):
        parts.append(slab("earth", z - h, z, col, ins, ins + step, RADIUS))
        z -= h
        ins += step
    parts.append(slab("foot", 0.0, z, foot, ins, ins + step, RADIUS))
    for o in parts:
        o["no_bevel"] = True  # the soft bevel on the grass lip stays; unbevelled earth bands save ~250 triangles
    return parts


def variant_e():
    """E Earth cube (ref 1): thick brown earth in three bands, stones peeking out of it, grass fringe over the lip."""
    rnd = random.Random(21)
    parts, zd0 = base_layers()
    parts += earth_sides(zd0, heights=(0.022, 0.010, 0.022))
    parts += embed_rocks([zd0 - 0.014, zd0 - 0.032, zd0 - 0.050], 12, rnd)
    return parts


def variant_f():
    """F Arena rim (ref 2): a ring of cut stone blocks under the grass lip like the arena border, earth below."""
    rnd = random.Random(22)
    parts, zd0 = base_layers()
    parts.append(slab("curb", zd0 - 0.020, zd0, "path_stone", 0.003, 0.003, RADIUS))
    parts[-1]["no_bevel"] = True
    parts += joints(zd0 - 0.020, zd0, HALF - 0.003, 6, "stone_dark", 0.0035, 0.0016)
    parts += earth_sides(zd0 - 0.020, ("path_dirt", "wood_light"), (0.026, 0.020), "stone_dark", 0.007, 0.003)
    parts += embed_rocks([zd0 - 0.010], 10, rnd, ("stone", "stone", "path_stone"), 0.0035)
    return parts


def variant_g():
    """G Mossy cliff: earth sides, longer fringe blades in two rows, big boulders bulging at the corners."""
    rnd = random.Random(23)
    parts, zd0 = base_layers()
    parts += earth_sides(zd0, ("path_dirt", "wood_light", "path_dirt"), (0.026, 0.010, 0.022), "stone_dark", 0.004, 0.004)
    for cx, cy in ((1, 1), (-1, 1), (-1, -1), (1, -1)):  # corner boulders
        for k, (dx, dz, r) in enumerate(((0, 0.040, 0.020), (0.022, 0.020, 0.016))):
            o = bc.cone("boulder", r, r * 0.7, 0.026, (cx * (HALF - 0.034 - dx), cy * (HALF - 0.034), dz),
                        "stone" if k == 0 else "path_stone", 5, 20 + 30 * k)
            o["no_bevel"] = True
            parts.append(o)
    parts += embed_rocks([zd0 - 0.020, zd0 - 0.040], 6, rnd)
    return parts


def variant_h():
    """H Ruin arch: earth sides with a small stone archway set into the front, rocks, a light fringe."""
    rnd = random.Random(24)
    parts, zd0 = base_layers()
    parts += earth_sides(zd0, heights=(0.024, 0.012, 0.020), i0=0.004)
    ay = -0.2915  # front of the posts sits at -0.2995, inside the 0.6 m footprint
    for sx in (-1, 1):  # arch: two posts, a lintel, a dark opening
        post = bc.box("arch", (0.011, 0.012, 0.040), (sx * 0.030, ay - 0.002, zd0 - 0.034), "stone")
        post["no_bevel"] = True
        parts.append(post)
    lintel = bc.box("arch", (0.072, 0.012, 0.011), (0, ay - 0.002, zd0 - 0.0095), "path_stone")
    lintel["no_bevel"] = True
    parts.append(lintel)
    door = bc.box("opening", (0.049, 0.002, 0.034), (0, -0.2972, zd0 - 0.035), "ink")
    door["no_bevel"] = True
    parts.append(door)
    parts += embed_rocks([zd0 - 0.016, zd0 - 0.034, zd0 - 0.050], 10, rnd)
    return parts


def fit(parts, margin=0.0008, shift=False):
    """Keep every part on the board: vertices outside the rounded 12 x 12 outline pull the part in, by shrinking it
    toward its centre in x/y (dressing) or sliding it inward (shift=True: the boulders of variant B).
    Critic v01: patches, boulders and a joint overshot 0.6 m by up to 8 mm."""
    for o in parts:
        for _ in range(40):
            vs = [v.co for v in o.data.vertices]
            bad = [v for v in vs if not inside(v.x, v.y, margin)]
            if not bad:
                break
            cx = sum(v.x for v in vs) / len(vs)
            cy = sum(v.y for v in vs) / len(vs)
            if shift:
                d = Vector((-cx, -cy)).normalized() * 0.001
                for v in o.data.vertices:
                    v.co.x += d.x
                    v.co.y += d.y
            else:
                for v in o.data.vertices:
                    v.co.x = cx + (v.co.x - cx) * 0.93
                    v.co.y = cy + (v.co.y - cy) * 0.93
    return parts


def variant_i():
    """I = E + G (Siddharth 2026-10-20: 'E and G I like the most'): E's three earth bands with stones in the sides, plus
    G's boulders at the four corners. No fringe blades (critic: they read as stray spikes)."""
    rnd = random.Random(21)
    parts, zd0 = base_layers()
    parts += earth_sides(zd0, heights=(0.022, 0.010, 0.022))
    parts += embed_rocks([zd0 - 0.014, zd0 - 0.032, zd0 - 0.050], 12, rnd)
    for cx, cy in ((1, 1), (-1, 1), (-1, -1), (1, -1)):  # corner boulders (G)
        for k, (dx, dz, r) in enumerate(((0, 0.040, 0.020), (0.022, 0.020, 0.016))):
            o = bc.cone("boulder", r, r * 0.7, 0.026, (cx * (HALF - 0.034 - dx), cy * (HALF - 0.034), dz),
                        "stone" if k == 0 else "path_stone", 5, 20 + 30 * k)
            o["no_bevel"] = True
            parts.append(o)
    return parts


VARIANTS = {"A": variant_a, "B": variant_b, "C": variant_c, "D": variant_d, "E": variant_e, "F": variant_f, "G": variant_g,
            "H": variant_h, "I": variant_i, "J": variant_i}
SEEDS = {"A": 3, "B": 5, "C": 7, "D": 9, "E": 31, "F": 32, "G": 33, "H": 34, "I": 35, "J": 35}
# J = I with fewer, bigger, taller tufts (to compare grass density)
LUSH_ARGS = {"J": dict(n_frond=62, frond_r=(0.045, 0.068), frond_h=(0.0065, 0.0090))}


def build(v, name="ew_world_island_v01"):
    parts = VARIANTS[v]()
    fit([p for p in parts if p.name.startswith(("rock", "boulder", "fringe"))], 0.0005, shift=True)
    parts += fit(lush_top(SEEDS[v], **LUSH_ARGS.get(v, {})) if v in "EFGHIJ" else top_dressing(SEEDS[v]))
    return bc.assemble(name, [("", parts, (0, 0, 0), None)])


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    v = args[0] if args else "A"
    bc.clear_scene()
    obj = build(v)
    print("BLEND", bc.save_blend(obj, "island_" + v))
