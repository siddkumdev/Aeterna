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


VARIANTS = {"A": variant_a, "B": variant_b, "C": variant_c, "D": variant_d}
SEEDS = {"A": 3, "B": 5, "C": 7, "D": 9}


def build(v, name="ew_world_island_v01"):
    parts = VARIANTS[v]()
    fit([p for p in parts if p.name.startswith("rock")], 0.0005, shift=True)
    parts += fit(top_dressing(SEEDS[v]))
    return bc.assemble(name, [("", parts, (0, 0, 0), None)])


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    v = args[0] if args else "A"
    bc.clear_scene()
    obj = build(v)
    print("BLEND", bc.save_blend(obj, "island_" + v))
