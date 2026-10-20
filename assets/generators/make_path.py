"""W04 Path tiles: straight, corner, T-junction and end-at-village, 1 x 1 cell (0.05 m), about 8 mm high so the
tile covers the grass rosettes on the island (their tips stay under 6 mm). Run:
    blender --factory-startup -b -P assets/generators/make_path.py -- A      (variants A-D, saved as path_<V>.blend)

Joins: every tile meets the next one at the middle of the cell edge with the same width (W = 0.032 m, so grass
borders both sides), so tiles join seamlessly in any order. Only the long sides between the joins are ragged
(Siddharth 2026-10-20: ragged edge). Origin at the base centre, +Y up on export; arms: straight = +x/-x,
corner = +x/+y, T = +x/-x/+y, end = +x (with an apron at -x, next to the house).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import blender_common as bc  # noqa: E402
import bmesh  # noqa: E402
import bpy  # noqa: E402

H = 0.025            # half a cell
W = 0.016            # half the path width at the joins
Z_SIDE = 0.0065      # vertical wall height
Z_TOP = 0.008        # top of the tile
INSET = 0.0012       # the top chamfers in by this much
AMP = 0.0022         # raggedness of the long sides


def rag(a, b, rnd, n=4, amp=AMP):
    """Points from a (included) towards b (excluded), pushed sideways; zero push at both ends."""
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    L = math.hypot(dx, dy)
    nx, ny = dy / L, -dx / L
    pts = []
    for i in range(n):
        t = i / n
        k = 0.0 if i == 0 else rnd.uniform(-amp, amp) * math.sin(math.pi * t) ** 0.5
        pts.append((ax + dx * t + nx * k, ay + dy * t + ny * k))
    return pts


def outline(kind, rnd):
    w = W
    if kind == "straight":
        segs = [((-H, -w), (H, -w), 1), ((H, -w), (H, w), 0), ((H, w), (-H, w), 1), ((-H, w), (-H, -w), 0)]
    elif kind == "corner":
        segs = [((-w, -w), (H, -w), 1), ((H, -w), (H, w), 0), ((H, w), (w, w), 1), ((w, w), (w, H), 1),
                ((w, H), (-w, H), 0), ((-w, H), (-w, -w), 1)]
    elif kind == "t":
        segs = [((-H, -w), (H, -w), 1), ((H, -w), (H, w), 0), ((H, w), (w, w), 1), ((w, w), (w, H), 1),
                ((w, H), (-w, H), 0), ((-w, H), (-w, w), 1), ((-w, w), (-H, w), 1), ((-H, w), (-H, -w), 0)]
    elif kind == "end":
        a = 0.022
        segs = [((-0.020, -a), (-0.002, -a), 1), ((-0.002, -a), (-0.002, -w), 0), ((-0.002, -w), (H, -w), 1),
                ((H, -w), (H, w), 0), ((H, w), (-0.002, w), 1), ((-0.002, w), (-0.002, a), 0),
                ((-0.002, a), (-0.020, a), 1), ((-0.020, a), (-0.024, a - 0.004), 0),
                ((-0.024, a - 0.004), (-0.024, -a + 0.004), 0), ((-0.024, -a + 0.004), (-0.020, -a), 0)]
    else:
        raise ValueError(kind)
    pts = []
    for p, q, ragged in segs:
        pts += rag(p, q, rnd, 4 if ragged else 1, AMP if ragged else 0.0)
    return pts


def inset_pts(pts, d):
    out = []
    n = len(pts)
    for i in range(n):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        tx, ty = p2[0] - p0[0], p2[1] - p0[1]
        L = math.hypot(tx, ty) or 1
        nx, ny = -ty / L, tx / L   # left normal of a CCW polygon points inward
        out.append((p1[0] + nx * d, p1[1] + ny * d))
    return out


def prism(name, pts, col, z_side=Z_SIDE, z_top=Z_TOP, inset=INSET):
    """Slab with vertical walls up to Z_SIDE, then a small chamfer to a flat top at Z_TOP."""
    top = inset_pts(pts, inset)
    bm = bmesh.new()
    rb = [bm.verts.new((x, y, 0.0)) for x, y in pts]
    rs = [bm.verts.new((x, y, z_side)) for x, y in pts]
    rt = [bm.verts.new((x, y, z_top)) for x, y in top]
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([rb[i], rb[j], rs[j], rs[i]])
        bm.faces.new([rs[i], rs[j], rt[j], rt[i]])
    bm.faces.new(rt)
    bm.faces.new(list(reversed(rb)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="EAR_CLIP")
    o = bc._new_obj(name, bm)
    bc.paint(o, col)
    o["no_bevel"] = True
    return o


def poly_has(pts, x, y):
    c = False
    n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            c = not c
    return c


def inside_ok(pts, x, y, m):
    """Inside the outline by at least m, ignoring the straight join edges on the cell border."""
    if not poly_has(pts, x, y):
        return False
    n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        if (abs(x1 - H) < 1e-9 and abs(x2 - H) < 1e-9) or (abs(x1 + H) < 1e-9 and abs(x2 + H) < 1e-9) \
                or (abs(y1 - H) < 1e-9 and abs(y2 - H) < 1e-9) or (abs(y1 + H) < 1e-9 and abs(y2 + H) < 1e-9):
            continue
        dx, dy = x2 - x1, y2 - y1
        t = max(0.0, min(1.0, ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy)))
        if math.hypot(x - x1 - t * dx, y - y1 - t * dy) < m:
            return False
    return True


def small(name, r, rt, h, x, y, z, col, segs, rot):
    o = bc.cone(name, r, rt, h, (x, y, z + h / 2), col, segs, rot)
    o["no_bevel"] = True
    return o


def tuft(x, y, rnd, cols=("leaf_light", "leaf_green")):
    """Three tiny grass blades leaning out at the path's edge."""
    parts = []
    for i in range(3):
        a = math.radians(i * 120 + rnd.uniform(0, 50))
        o = bc.cone("tuft", 0.0016, 0.0, rnd.uniform(0.0035, 0.0055), (0, 0, 0.002), rnd.choice(cols), 3)
        o["no_bevel"] = True
        o.rotation_euler = (0, math.radians(25), a)
        bpy.context.view_layer.update()
        bpy.ops.object.select_all(action="DESELECT")  # stale selection would bake other tiles' locations
        bc.apply_transforms(o)
        bpy.ops.object.select_all(action="DESELECT")  # stale selection would make assemble() join other tiles
        for v in o.data.vertices:
            v.co.x += x + 0.0016 * math.cos(a)
            v.co.y += y + 0.0016 * math.sin(a)
            v.co.z += Z_TOP - 0.002
        parts.append(o)
    return parts


def edge_points(pts, spacing, m_cell=0.004):
    """Evenly spaced points on the ragged long sides (not near the cell border)."""
    out = []
    n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        L = math.hypot(x2 - x1, y2 - y1)
        if L < 0.003:
            continue
        k = max(1, int(L / spacing))
        for s in range(k):
            t = (s + 0.5) / k
            out.append((x1 + (x2 - x1) * t, y1 + (y2 - y1) * t))
    return [(x, y) for x, y in out if abs(x) < H - m_cell and abs(y) < H - m_cell]


def tile(variant, kind, seed):
    rnd = random.Random(seed)
    pts = outline(kind, random.Random(1000 + len(kind)))  # same raggedness for every variant of one kind
    parts = []
    if variant == "A":     # packed dirt, pebbles, a few grass tufts at the edge
        parts.append(prism("path", pts, "path_dirt"))
        n = 0
        for _ in range(80):
            if n >= 5:
                break
            x, y = rnd.uniform(-H, H), rnd.uniform(-H, H)
            if inside_ok(pts, x, y, 0.004):
                parts.append(small("pebble", rnd.uniform(0.0025, 0.0038), 0.0016, 0.0016, x, y, Z_TOP - 0.0002,
                                   rnd.choice(("stone", "path_stone", "stone_dark")), 5, rnd.uniform(0, 70)))
                n += 1
        ep = edge_points(pts, 0.011)
        for x, y in rnd.sample(ep, min(3, len(ep))):
            parts += tuft(x, y, rnd)
    elif variant == "B":   # brick path: dark joints show as a rim, running-bond bricks on top
        parts.append(prism("path", pts, "stone_dark", Z_SIDE - 0.0004, Z_SIDE, 0.0006))
        bw, bh = 0.0125, 0.0068
        row = 0
        y = -H + bh / 2 + 0.0004
        while y < H:
            x = -H + (bw / 2 if row % 2 == 0 else 0.0)
            while x < H:
                if all(inside_ok(pts, x + sx * bw / 2, y + sy * bh / 2, 0.0013) for sx in (-1, 1) for sy in (-1, 1)):
                    o = bc.box("brick", (bw - 0.0010, bh - 0.0010, Z_TOP - Z_SIDE),
                               (x, y, Z_SIDE + (Z_TOP - Z_SIDE) / 2), rnd.choice(("path_stone", "path_stone", "stone")))
                    o["no_bevel"] = True
                    parts.append(o)
                x += bw
            y += bh
            row += 1
    elif variant == "C":   # dirt trail with a border of chunky edge stones
        parts.append(prism("path", pts, "path_dirt"))
        for x, y in edge_points(pts, 0.0085):
            r = rnd.uniform(0.0030, 0.0042)
            parts.append(small("edge_stone", r, r * 0.65, rnd.uniform(0.0022, 0.0034), x, y, Z_TOP - 0.0005,
                               rnd.choice(("stone", "stone", "path_stone", "stone_dark")), 5, rnd.uniform(0, 70)))
        n = 0
        for _ in range(60):
            if n >= 3:
                break
            x, y = rnd.uniform(-H, H), rnd.uniform(-H, H)
            if inside_ok(pts, x, y, 0.006):
                parts.append(small("pebble", 0.0026, 0.0014, 0.0014, x, y, Z_TOP - 0.0002, "path_stone", 5, rnd.uniform(0, 70)))
                n += 1
    elif variant == "D":   # flagstones: irregular six-sided stones on a dark bed
        parts.append(prism("path", pts, "stone_dark", Z_SIDE - 0.0004, Z_SIDE, 0.0006))
        gx = 0.0128
        i = 0
        y = -H + 0.003
        while y < H:
            x = -H + 0.003 + (0.0064 if i % 2 else 0.0)
            while x < H:
                jx, jy = x + rnd.uniform(-0.0012, 0.0012), y + rnd.uniform(-0.0012, 0.0012)
                if inside_ok(pts, jx, jy, 0.0024):
                    h = rnd.uniform(Z_TOP - Z_SIDE - 0.0003, Z_TOP - Z_SIDE + 0.0002)
                    o = bc.cone("flag", rnd.uniform(0.0066, 0.0072), rnd.uniform(0.0058, 0.0064), h,
                                (jx, jy, Z_SIDE + h / 2 - 0.0002), rnd.choice(("path_stone", "path_stone", "stone")), 6,
                                rnd.uniform(0, 60))
                    o["no_bevel"] = True
                    parts.append(o)
                x += gx
            y += gx * 0.9
            i += 1
    return parts


KINDS = ("straight", "corner", "t", "end")
SEED = {"A": 11, "B": 12, "C": 13, "D": 14}


def build(variant, kind):
    parts = tile(variant, kind, SEED[variant] + KINDS.index(kind))
    return bc.assemble("ew_world_path_%s_%s" % (kind, variant), [("", parts, (0, 0, 0), None)])


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    v = args[0] if args else "A"
    bc.clear_scene()
    objs = []
    for i, k in enumerate(KINDS):
        o = build(v, k)
        o.location = (i * 0.07, 0, 0)
        objs.append(o)
    print("BLEND", bc.save_blend(objs[0], "path_" + v))
