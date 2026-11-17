"""W-story ground: the life-size land the live story stands on (sykeriin 2026-11-17: the story rebuilt from game
models only, ground first; same layout as the old story land, flat-shaded palette patches + tufts, dirt path in the
mesh). Run:
    blender --factory-startup -b -P assets/generators/make_story_ground.py -- A      (variants A-D -> story_ground_<V>.blend)

Layout comes from StoryWorld.height() in godot/scripts/story/story_world.gd (ported below, Godot x/z): flat where you
stand (origin) and in the village (Godot (0, 0, -28)), rolling hills around, the edge bends down into a cliff past
96 m. Godot (x, y, z) = Blender (x, z, -y) after the +Y-up export, so heights are sampled at height(x, -y).
Colour is per face from the palette atlas (one material, one draw call); tufts and flowers only near you and the path.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import blender_common as bc  # noqa: E402
import bmesh  # noqa: E402

VILLAGE = (0.0, -28.0)   # Godot x, z
RINGS, SEGS, R_MAX = 56, 96, 125.0


def height(x, z):
    """Same as StoryWorld.height (Godot x, z)."""
    r = math.hypot(x, z)
    b = 0.9 * math.sin(x * 0.045 + 1.3) * math.cos(z * 0.05 - 0.4) + 0.45 * math.sin(x * 0.11 - z * 0.09 + 2.0) \
        + 0.18 * math.sin(x * 0.27 + z * 0.23 + 0.7)
    b += 1.6 * math.sin(x * 0.021 - 0.8) * math.sin(z * 0.017 + 0.3)

    def ss(a, b_, t):
        t = min(max((t - a) / (b_ - a), 0.0), 1.0)
        return t * t * (3 - 2 * t)
    flat = ss(4.0, 16.0, r) * ss(12.0, 24.0, math.hypot(x - VILLAGE[0], z - VILLAGE[1]))
    h = (b + 0.8) * flat * (1.0 + r * 0.025)
    if r > 96.0:
        h -= ((r - 96.0) / 14.0) ** 2 * 9.0
    return h


def path_dist(x, z):
    """Same as StoryWorld._path_dist: you -> village gate, with a gentle wiggle."""
    ax, az, bx, bz = 0.0, 1.5, VILLAGE[0], VILLAGE[1] + 5.0
    abx, abz = bx - ax, bz - az
    t = min(max(((x - ax) * abx + (z - az) * abz) / (abx * abx + abz * abz), 0.0), 1.0)
    return math.hypot(x - (ax + abx * t) - math.sin(z * 0.35) * 0.8, z - (az + abz * t))


def gz(bx, by):
    """Blender (x, y) -> Godot (x, z)."""
    return bx, -by


def swatch_uv(name):
    names = bc.atlas_names()
    i = names.index(name)
    size = bc.ATLAS_COLS * bc.ATLAS_CELL
    return (((i % bc.ATLAS_COLS) + 0.5) * bc.ATLAS_CELL / size, 1.0 - ((i // bc.ATLAS_COLS) + 0.5) * bc.ATLAS_CELL / size)


class Mesh:
    """One bmesh, faces coloured per face by palette name."""
    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def face(self, pts, col):
        f = self.bm.faces.new([self.bm.verts.new(p) for p in pts])
        u = swatch_uv(col)
        for lp in f.loops:
            lp[self.uv].uv = u
        return f

    def blade(self, x, y, z, r, h, lean, ang, col):
        """Three-sided leaning spike (a grass blade / tuft spine)."""
        tip = (x + math.cos(ang) * lean, y + math.sin(ang) * lean, z + h)
        base = [(x + r * math.cos(ang + k * 2.094), y + r * math.sin(ang + k * 2.094), z - 0.02) for k in range(3)]
        for k in range(3):
            self.face([base[k], base[(k + 1) % 3], tip], col)

    def flower(self, x, y, z, col, rnd):
        self.blade(x, y, z, 0.012, 0.22, 0.02, rnd.uniform(0, 6.3), "leaf_green")
        c = (x, y, z + 0.22)
        pts = [(x + 0.06 * math.cos(a), y + 0.06 * math.sin(a), z + 0.22) for a in [k * 1.2566 for k in range(5)]]
        for k in range(5):
            self.face([c, pts[k], pts[(k + 1) % 5]], col)

    def rock(self, x, y, z, s, col, rnd):
        top = (x, y, z + s * 0.7)
        ring = [(x + s * math.cos(a) * rnd.uniform(0.7, 1.1), y + s * math.sin(a) * rnd.uniform(0.7, 1.1), z - 0.05)
                for a in [k * 1.2566 + rnd.uniform(-0.2, 0.2) for k in range(5)]]
        mid = [((p[0] * 0.8 + x * 0.2), (p[1] * 0.8 + y * 0.2), z + s * 0.4) for p in ring]
        for k in range(5):
            j = (k + 1) % 5
            self.face([ring[k], ring[j], mid[j], mid[k]], col)
            self.face([mid[k], mid[j], top], col)

    def finish(self, name):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        o = bc._new_obj(name, self.bm)
        mat = bc.atlas_material()
        o.data.materials.append(mat)
        for p in o.data.polygons:
            p.use_smooth = False
        return o


def terrain(m, colour_of):
    """Polar grid (dense under your feet, coarse at the horizon); colour_of(gx, gz, h, r, slope) -> palette name."""
    pts = []
    for j in range(RINGS + 1):
        r = R_MAX * (j / RINGS) ** 1.75
        row = []
        for i in range(SEGS):
            a = math.tau * (i + 0.5 * (j % 2)) / SEGS
            bx, by = math.cos(a) * r, math.sin(a) * r
            x, z = gz(bx, by)
            row.append((bx, by, height(x, z) if r < 124.0 else -40.0))
        pts.append(row)
    for j in range(RINGS):
        for i in range(SEGS):
            a, b = pts[j][i], pts[j][(i + 1) % SEGS]
            c, d = pts[j + 1][(i + 1) % SEGS], pts[j + 1][i]
            for tri in ((a, b, c), (a, c, d)):
                cx = sum(p[0] for p in tri) / 3
                cy = sum(p[1] for p in tri) / 3
                cz = sum(p[2] for p in tri) / 3
                span = max(math.hypot(tri[k][0] - tri[k - 1][0], tri[k][1] - tri[k - 1][1]) for k in range(3)) + 1e-6
                slope = (max(p[2] for p in tri) - min(p[2] for p in tri)) / span
                x, z = gz(cx, cy)
                m.face(tri, colour_of(x, z, cz, math.hypot(cx, cy), slope))


def path_ribbon(m, rnd, col="path_dirt", half=1.15):
    """The dirt path as its own smooth strip 3 cm above the grass (per-face colouring gave sawtooth edges)."""
    ax, az, bx, bz = 0.0, 1.5, VILLAGE[0], VILLAGE[1] + 5.0
    n = 60
    rows = []
    for k in range(n + 1):
        t = k / n
        z = az + (bz - az) * t
        x = ax + (bx - ax) * t + math.sin(z * 0.35) * 0.8
        w = half * (1.0 + 0.08 * math.sin(z * 0.45 + 1.0))  # smooth width wave (critic v02: notched edges)
        row = []
        for side in (-1.0, -0.5, 0.0, 0.5, 1.0):
            px = x + side * w
            row.append((px, -z, height(px, z) + 0.03))
        rows.append(row)
    for k in range(n):
        for i in range(4):
            m.face([rows[k][i], rows[k][i + 1], rows[k + 1][i + 1], rows[k + 1][i]], col)


def noise(x, z, f, k=0.0):
    return math.sin(x * f + 1.7 + k) * math.cos(z * f * 1.3 - 0.6 + k) + 0.5 * math.sin((x + z) * f * 2.1 + 2.0 * k)


def cliff(r, h, slope, tones):
    """Cliff faces past the rim; tones are strata from the top down."""
    if r < 99.0 and slope < 0.9:
        return None
    band = int(max(-h, 0.0) / 3.0)
    return tones[min(band, len(tones) - 1)]


def scatter(m, rnd, n, near, fn):
    """n points within `near` m of you or the path, not on the path itself; fn(bx, by, z, rnd)."""
    k = 0
    while k < n:
        bx, by = rnd.uniform(-near, near), rnd.uniform(-near * 2.2, near)
        x, z = gz(bx, by)
        r = math.hypot(x, z)
        pd = path_dist(x, z)
        if pd < (2.6 if near > 20.0 else 1.1) or (r > near and pd > 5.0) or r < 0.6:
            continue
        if math.hypot(x - VILLAGE[0], z - VILLAGE[1]) < 13.0:  # village houses stand there
            continue
        fn(bx, by, height(x, z), rnd)
        k += 1


def tuft(m, cols, size=1.0):
    def f(bx, by, z, rnd):
        for _ in range(3):
            m.blade(bx + rnd.uniform(-0.08, 0.08), by + rnd.uniform(-0.08, 0.08), z, 0.035 * size,
                    rnd.uniform(0.25, 0.45) * size, rnd.uniform(0.04, 0.12), rnd.uniform(0, 6.3), rnd.choice(cols))
    return f


def draped(px, pz, lift):
    """Height for an overlay vertex: the highest ground within 1.8 m, so terrain bulging between the overlay's
    vertices cannot poke through (critic v02 saw holes on slopes)."""
    h = max(height(px + dx, pz + dz) for dx, dz in ((0, 0), (1.8, 0), (-1.8, 0), (0, 1.8), (0, -1.8)))
    return h + lift


def _clear_of_path(x, z, rad):
    return path_dist(x, z) > rad + 1.6 and math.hypot(x, z) > rad * 0.5 + 2.0


def patch(m, x, z, rad, col, rnd, layer=0):
    """A smooth colour patch draped on the ground (Godot x, z; radius in m), lifted a little more when bigger so the
    terrain between its samples never pokes through. Per-face colouring of the terrain gave sawtooth edges (critic v01)."""
    lift = 0.03 + layer * 0.02
    ph = [rnd.uniform(0, 6.3) for _ in range(3)]
    n = 18
    rings = []
    for f in (0.0, 0.4, 0.75, 1.0):
        ring = []
        for k in range(n):
            a = math.tau * k / n
            w = 1.0 + 0.18 * math.sin(2 * a + ph[0]) + 0.1 * math.sin(3 * a + ph[1]) + 0.06 * math.sin(5 * a + ph[2])
            px, pz = x + math.cos(a) * rad * w * f * 1.0, z + math.sin(a) * rad * w * f * 0.8
            ring.append((px, -pz, draped(px, pz, lift)))
        rings.append(ring)
    for k in range(n):
        j = (k + 1) % n
        m.face([rings[0][k], rings[1][k], rings[1][j]], col)
        for r in (1, 2):
            m.face([rings[r][k], rings[r + 1][k], rings[r + 1][j], rings[r][j]], col)


def strip(m, x, z, length, width, ang, col, layer=0):
    """A draped rectangle (a field strip), 8 x 3 segments, along angle ang."""
    lift = 0.03 + layer * 0.02
    PLACED.append((x, z, max(length, width) * 0.5))
    ca, sa = math.cos(ang), math.sin(ang)
    grid = []
    for a in range(9):
        row = []
        for b in range(4):
            u, v = (a / 8 - 0.5) * length, (b / 3 - 0.5) * width
            px, pz = x + ca * u - sa * v, z + sa * u + ca * v
            row.append((px, -pz, draped(px, pz, lift)))
        grid.append(row)
    for a in range(8):
        for b in range(3):
            m.face([grid[a][b], grid[a][b + 1], grid[a + 1][b + 1], grid[a + 1][b]], col)


PLACED = []  # (x, z, rad) of every patch/strip so far: overlapping overlays z-fight (critic v02 speckles)


def _free(x, z, rad):
    return all(math.hypot(x - px, z - pz) > (rad + pr) * 1.3 + 1.0 for px, pz, pr in PLACED)


def scatter_patches(m, rnd, n, rad_range, colours, where=lambda x, z: True, reach=90.0, layer=0):
    k = tries = 0
    while k < n and tries < n * 200:
        tries += 1
        x, z = rnd.uniform(-reach, reach), rnd.uniform(-reach, reach)
        rad = rnd.uniform(*rad_range)
        if math.hypot(x, z) + rad > 88.0 or math.hypot(x, z) - rad < 7.0 or not _clear_of_path(x, z, rad) or not where(x, z) or not _free(x, z, rad):
            continue
        PLACED.append((x, z, rad))
        patch(m, x, z, rad, rnd.choice(colours), rnd, layer)
        k += 1


# ------------------------------------------------------------------ variants
def variant_a():
    """Meadow patches: three greens in soft blotches, dirt path, many tufts and flowers near you, stone cliff."""
    m, rnd = Mesh(), random.Random(11)

    def col(x, z, h, r, s):
        c = cliff(r, h, s, ("stone", "stone_dark", "stone"))
        if c:
            return c
        return "grass"
    terrain(m, col)
    path_ribbon(m, rnd)
    scatter_patches(m, rnd, 45, (3.0, 11.0), ("leaf_light", "leaf_green"))
    scatter(m, rnd, 210, 14.0, tuft(m, ("leaf_green", "leaf_light", "grass")))
    scatter(m, rnd, 50, 12.0, lambda bx, by, z, r: m.flower(bx, by, z, r.choice(("flower_pink", "flower_yellow", "wall_cream")), r))
    return m.finish("ew_world_story_ground_v01")


def variant_b():
    """Field and wild: a light mown meadow around you and the village, darker wild grass further out."""
    m, rnd = Mesh(), random.Random(12)

    def col(x, z, h, r, s):
        c = cliff(r, h, s, ("stone_dark", "stone", "stone_dark"))
        if c:
            return c
        return "leaf_green"
    terrain(m, col)
    path_ribbon(m, rnd)
    near = lambda x, z: min(math.hypot(x, z), math.hypot(x - VILLAGE[0], z - VILLAGE[1])) < 20.0
    scatter_patches(m, rnd, 26, (5.0, 10.0), ("leaf_light",), near, 45.0)
    scatter_patches(m, rnd, 14, (3.0, 9.0), ("leaf_dark",), lambda x, z: not near(x, z) and math.hypot(x, z) > 30.0, layer=1)
    scatter(m, rnd, 220, 14.0, tuft(m, ("grass", "leaf_light")))
    scatter(m, rnd, 30, 10.0, lambda bx, by, z, r: m.flower(bx, by, z, r.choice(("flower_yellow", "wall_cream")), r))
    return m.finish("ew_world_story_ground_v01")


def variant_c():
    """Farm patchwork: strip fields around the village (hay, green, light), dirt yard by the houses."""
    m, rnd = Mesh(), random.Random(13)

    def col(x, z, h, r, s):
        c = cliff(r, h, s, ("path_dirt", "stone", "stone_dark"))
        if c:
            return c
        return "grass"
    terrain(m, col)
    path_ribbon(m, rnd)
    for side in (-1, 1):  # two blocks of field strips either side of the village, clear of the path
        for k in range(4):
            strip(m, VILLAGE[0] + side * (24.0 + k * 6.5), VILLAGE[1] - 4.0, 30.0, 5.5, math.pi / 2 + side * 0.15,
                  ("leaf_yellow", "leaf_light", "leaf_yellow", "leaf_green")[k])
    scatter_patches(m, rnd, 20, (4.0, 10.0), ("leaf_green",), lambda x, z: abs(x) > 50.0 or z > 0.0)
    scatter(m, rnd, 200, 14.0, tuft(m, ("leaf_green", "grass")))
    scatter(m, rnd, 25, 10.0, lambda bx, by, z, r: m.flower(bx, by, z, r.choice(("flower_pink", "roof_orange")), r))
    return m.finish("ew_world_story_ground_v01")


def variant_d():
    """Rocky highland: grass darker in the hollows and lighter on the crests, boulders, earth-then-stone cliff."""
    m, rnd = Mesh(), random.Random(14)

    def col(x, z, h, r, s):
        c = cliff(r, h, s, ("path_dirt", "dirt_dark", "stone", "stone_dark"))
        if c:
            return c
        return "leaf_green"
    terrain(m, col)
    path_ribbon(m, rnd)
    crest = lambda x, z: height(x, z) / (1.0 + math.hypot(x, z) * 0.025) > 1.3
    hollow = lambda x, z: height(x, z) / (1.0 + math.hypot(x, z) * 0.025) < 0.5 and math.hypot(x, z) > 30.0
    scatter_patches(m, rnd, 30, (4.0, 10.0), ("leaf_light", "grass"), crest)
    scatter_patches(m, rnd, 10, (3.0, 7.0), ("leaf_dark",), hollow, layer=1)
    scatter(m, rnd, 140, 14.0, tuft(m, ("leaf_green", "leaf_dark"), 1.2))
    scatter(m, rnd, 16, 40.0, lambda bx, by, z, r: m.rock(bx, by, z, r.uniform(0.7, 1.4), r.choice(("stone", "stone_dark")), r))
    return m.finish("ew_world_story_ground_v01")


VARIANTS = {"A": variant_a, "B": variant_b, "C": variant_c, "D": variant_d}

if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    v = args[0] if args else "A"
    bc.clear_scene()
    obj = VARIANTS[v]()
    print("BLEND", bc.save_blend(obj, "story_ground_" + v))
