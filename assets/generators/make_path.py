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
    set_sides(pts)
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
    if variant in "EFGH":
        return tile2(variant, kind, seed)
    if variant in "IJK":
        return tile3(variant, kind, seed)
    if variant == "L":
        return tile4(kind, seed)
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



# ---- round 2 (E-H): LOWER paths. Siddharth 2026-10-20: A-D 'feel so plastic, like glued on top and not an actual
# path; try a slightly lower path'. So: 2-3.5 mm tall instead of 8 mm, soft sloping flanks that sink into the
# grass (no vertical walls, no chamfer), several earth tones, stones sunk into the ground. Joins stay fixed at the
# cell border (outset and inset taper to zero there), so tiles still meet seamlessly.

SLOPE = 0.0042       # how far the flank spreads out past the outline at the bottom
SINK = -0.0008       # the flank starts below the grass (the island grass is a flat 6 mm layer, tips under 6 mm)


ACTIVE_SIDES = [(1, 0), (-1, 0), (0, 1), (0, -1)]   # the cell borders the current tile touches (set per outline)


def set_sides(pts):
    global ACTIVE_SIDES
    ACTIVE_SIDES = [sd for sd in ((1, 0), (-1, 0), (0, 1), (0, -1))
                    if any(abs(sd[0] * x + sd[1] * y - H) < 1e-9 for x, y in pts)]


def border_taper(x, y, full=0.009):
    """0 at a cell border the tile touches, 1 once `full` metres away from it (so the join profile is identical on
    both tiles). Only borders that carry a join count, not the lateral ones."""
    d = min([H - (sd[0] * x + sd[1] * y) for sd in ACTIVE_SIDES] or [1.0])
    return max(0.0, min(1.0, d / full))


def outset_pts(pts, d, taper=True):
    """Move each point out (d > 0) or in (d < 0) along its normal, tapering to zero at the cell border."""
    res = []
    n = len(pts)
    for i in range(n):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        tx, ty = p2[0] - p0[0], p2[1] - p0[1]
        L = math.hypot(tx, ty) or 1
        nx, ny = ty / L, -tx / L   # outward normal of a CCW polygon
        k = d * (border_taper(*p1) if taper else 1.0)
        res.append((p1[0] + nx * k, p1[1] + ny * k))
    return res


def mound(name, pts, col, z_top, slope=SLOPE, crown=0.0009):
    """Low earth mound: bottom ring below the grass, a rounded shoulder, a flat crown. No vertical walls."""
    rings = [(outset_pts(pts, slope), SINK), (outset_pts(pts, slope * 0.38), z_top * 0.55),
             (outset_pts(pts, -crown), z_top)]
    bm = bmesh.new()
    rv = [[bm.verts.new((x, y, z)) for x, y in r] for r, z in rings]
    n = len(pts)
    for a in range(len(rings) - 1):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new([rv[a][i], rv[a][j], rv[a + 1][j], rv[a + 1][i]])
    bm.faces.new(rv[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="EAR_CLIP")
    o = bc._new_obj(name, bm)
    bc.paint(o, col)
    o["no_bevel"] = True
    return o


def flat_patch(name, x, y, r, z, col, rnd, n=7):
    """Thin irregular polygon lying on the ground (a worn or dusty patch): n points, lifted 0.2 mm."""
    bm = bmesh.new()
    rot = rnd.uniform(0, 6.28)
    vs = [bm.verts.new((x + r * rnd.uniform(0.7, 1.15) * math.cos(rot + 6.2832 * k / n),
                        y + r * rnd.uniform(0.7, 1.15) * math.sin(rot + 6.2832 * k / n), z)) for k in range(n)]
    bm.faces.new(vs)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    o = bc._new_obj(name, bm)
    bc.paint(o, col)
    o["no_bevel"] = True
    return o


def rand_inside(pts, rnd, m, tries=200):
    for _ in range(tries):
        x, y = rnd.uniform(-H, H), rnd.uniform(-H, H)
        if inside_ok(pts, x, y, m) and abs(x) < H - 0.003 and abs(y) < H - 0.003:
            return x, y
    return None


def hump(x, y, r, h, col, rnd):
    """A low faceted grass hump (two stacked layers) for lips and edges."""
    ro = rnd.uniform(0, 60)
    a = bc.cone("lip", r, r * 0.75, h * 0.55, (x, y, h * 0.275 + SINK), col, 6, ro)
    b = bc.cone("lip", r * 0.75, r * 0.35, h * 0.55, (x, y, h * 0.55 + h * 0.275 + SINK), "leaf_light" if col != "leaf_light" else "grass", 6, ro + 30)
    a["no_bevel"] = b["no_bevel"] = True
    return [a, b]


def tile2(variant, kind, seed):
    rnd = random.Random(seed)
    pts = outline(kind, random.Random(1000 + len(kind)))
    parts = []
    if variant == "E":     # worn earth trail: low soft mound, several earth tones, dust and dark patches, flat pebbles
        parts.append(mound("path", pts, "path_dirt", 0.0030))
        for col, cnt, r in (("path_stone", 2, 0.0090), ("wood_dark", 2, 0.0060)):
            for _ in range(cnt):
                pt = rand_inside(pts, rnd, 0.0035)
                if pt:
                    parts.append(flat_patch("patch", pt[0], pt[1], r * rnd.uniform(0.8, 1.2), 0.0032 + 0.0002 * rnd.random(), col, rnd))
        for _ in range(3):
            pt = rand_inside(pts, rnd, 0.005)
            if pt:
                parts.append(small("pebble", 0.0034, 0.0022, 0.0012, pt[0], pt[1], 0.0026, rnd.choice(("stone", "path_stone")), 5, rnd.uniform(0, 70)))
        ep = edge_points(outset_pts(pts, SLOPE * 0.9), 0.012)
        for x, y in rnd.sample(ep, min(4, len(ep))):
            parts += hump(x, y, 0.0036, 0.0042, "leaf_green", rnd)
    elif variant == "F":   # stepping stones set in a low dirt bed
        parts.append(mound("path", pts, "path_dirt", 0.0020))
        n = 0
        placed = []
        for _ in range(240):
            if n >= (5 if kind != "straight" else 4):
                break
            pt = rand_inside(pts, rnd, 0.0065)
            if pt and all(math.dist(pt, q) > 0.0125 for q in placed):
                placed.append(pt)
                r = rnd.uniform(0.0058, 0.0072)
                parts.append(small("step", r, r * 0.82, 0.0022, pt[0], pt[1], 0.0014, rnd.choice(("path_stone", "path_stone", "stone")), 7, rnd.uniform(0, 60)))
                n += 1
        for _ in range(3):
            pt = rand_inside(pts, rnd, 0.004)
            if pt:
                parts.append(flat_patch("patch", pt[0], pt[1], 0.005, 0.0022, rnd.choice(("wood_dark", "wood_light")), rnd))
        ep = edge_points(outset_pts(pts, SLOPE * 0.9), 0.011)
        for x, y in rnd.sample(ep, min(5, len(ep))):
            parts += hump(x, y, 0.0036, 0.0042, rnd.choice(("leaf_green", "grass")), rnd)
    elif variant == "G":   # sunken trail: the floor is below the grass, grassy lips run along both sides
        parts.append(mound("path", pts, "path_dirt", 0.0010, slope=0.0030, crown=0.0006))
        for col, cnt, r in (("wood_dark", 3, 0.0045), ("path_stone", 3, 0.0055)):
            for _ in range(cnt):
                pt = rand_inside(pts, rnd, 0.004)
                if pt:
                    parts.append(flat_patch("patch", pt[0], pt[1], r, 0.0012, col, rnd))
        for x, y in edge_points(outset_pts(pts, 0.0040), 0.0075):
            r = rnd.uniform(0.0034, 0.0046)
            parts += hump(x, y, r, rnd.uniform(0.0040, 0.0056), rnd.choice(("leaf_green", "grass", "leaf_green")), rnd)
        for _ in range(3):
            pt = rand_inside(pts, rnd, 0.005)
            if pt:
                parts.append(small("pebble", 0.0030, 0.0018, 0.0012, pt[0], pt[1], 0.0008, rnd.choice(("stone", "path_stone")), 5, rnd.uniform(0, 70)))
    elif variant == "H":   # cobbles sunk in earth: round stones of several sizes, dirt showing between
        parts.append(mound("path", pts, "path_dirt", 0.0020))
        placed = []
        for _ in range(400):
            if len(placed) >= (9 if kind == "straight" else 11):
                break
            pt = rand_inside(pts, rnd, 0.0050)
            if not pt:
                continue
            r = rnd.uniform(0.0036, 0.0058)
            if all(math.dist(pt, (qx, qy)) > r + qr + 0.0012 for qx, qy, qr in placed):
                placed.append((pt[0], pt[1], r))
                parts.append(small("cobble", r, r * 0.7, rnd.uniform(0.0018, 0.0026), pt[0], pt[1], 0.0010,
                                   rnd.choice(("path_stone", "stone", "path_stone", "stone_dark")), 6, rnd.uniform(0, 60)))
        ep = edge_points(outset_pts(pts, SLOPE * 0.9), 0.012)
        for x, y in rnd.sample(ep, min(4, len(ep))):
            parts += hump(x, y, 0.0036, 0.0042, "leaf_green", rnd)
    return parts



# ---- round 3 (I-K): 'I want it to look like this' (Siddharth 2026-10-20, two top-down painted forest-trail
# screenshots). What the references have: a WIDE, winding trail that is almost flush with the ground, soft
# organic edges (long gentle meanders, not jitter), subtle large rounded cobble shapes painted into the earth
# (not 3D stones), a darker green grass skirt where grass meets the trail, and small clusters of chunky stones,
# flowers and tufts along the edge. Style and shape language only: nothing copied.

W3 = 0.0215          # half the trail width at the joins (the trail is 0.043 m wide, 86% of a cell)


def smooth_edge(a, b, rnd, n=8, amp=0.0036):
    """Like rag() but a long gentle meander (two slow waves) instead of jitter; zero at both ends."""
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    L = math.hypot(dx, dy)
    nx, ny = dy / L, -dx / L
    p1, p2 = rnd.uniform(0, 6.28), rnd.uniform(0, 6.28)
    f1, f2 = rnd.uniform(0.9, 1.4), rnd.uniform(2.0, 3.0)
    pts = []
    for i in range(n):
        t = i / n
        k = 0.0 if i == 0 else amp * (0.65 * math.sin(6.2832 * f1 * t + p1) + 0.35 * math.sin(6.2832 * f2 * t + p2)) * math.sin(math.pi * t) ** 0.6
        pts.append((ax + dx * t + nx * k, ay + dy * t + ny * k))
    return pts


def outline3(kind, rnd):
    w = W3
    n = 8
    if kind == "straight":
        segs = [((-H, -w), (H, -w), 1), ((H, -w), (H, w), 0), ((H, w), (-H, w), 1), ((-H, w), (-H, -w), 0)]
    elif kind == "corner":
        segs = [((-w, -w), (H, -w), 1), ((H, -w), (H, w), 0), ((H, w), (w, w), 1), ((w, w), (w, H), 1),
                ((w, H), (-w, H), 0), ((-w, H), (-w, -w), 1)]
    elif kind == "t":
        segs = [((-H, -w), (H, -w), 1), ((H, -w), (H, w), 0), ((H, w), (w, w), 1), ((w, w), (w, H), 1),
                ((w, H), (-w, H), 0), ((-w, H), (-w, w), 1), ((-w, w), (-H, w), 1), ((-H, w), (-H, -w), 0)]
    elif kind == "end":   # trail opens into a rounded apron at -x, in front of the house
        a = 0.0248
        segs = [((-0.017, -a), (-0.002, -a), 1), ((-0.002, -a), (-0.002, -w), 0), ((-0.002, -w), (H, -w), 1),
                ((H, -w), (H, w), 0), ((H, w), (-0.002, w), 1), ((-0.002, w), (-0.002, a), 0),
                ((-0.002, a), (-0.017, a), 1), ((-0.017, a), (-0.0235, 0.0185), 0),
                ((-0.0235, 0.0185), (-0.0235, -0.0185), 0), ((-0.0235, -0.0185), (-0.017, -a), 0)]
    else:
        raise ValueError(kind)
    pts = []
    for p, q, ragged in segs:
        if ragged:
            pts += smooth_edge(p, q, rnd, 4 if math.hypot(q[0] - p[0], q[1] - p[1]) < 0.02 else n)
        else:
            pts.append(p)
    set_sides(pts)
    return pts


def ring_flat(name, outer, inner, z, col):
    """Flat ragged ring between two same-length outlines (the darker grass skirt around the trail)."""
    bm = bmesh.new()
    vo = [bm.verts.new((x, y, z)) for x, y in outer]
    vi = [bm.verts.new((x, y, z)) for x, y in inner]
    n = len(outer)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([vi[i], vi[j], vo[j], vo[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    o = bc._new_obj(name, bm)
    bc.paint(o, col)
    o["no_bevel"] = True
    return o


def far_from_border(x, y, m=0.007):
    return abs(x) < H - m and abs(y) < H - m


def tile3(variant, kind, seed):
    rnd = random.Random(seed)
    pts = outline3(kind, random.Random(2000 + len(kind)))
    parts = [mound("path", pts, "path_dirt", 0.0016, slope=0.0030, crown=0.0006)]
    ztop = 0.0016
    # darker grass skirt hugging the trail (flat, 0.5 mm, pinches to nothing at the cell border)
    parts.append(ring_flat("skirt", outset_pts(pts, 0.0075), outset_pts(pts, 0.0020), 0.0005, "leaf_green"))
    # cobble shapes painted into the earth: big, rounded, low
    placed = []
    cob_cols = {"I": ("path_stone", "path_dirt", "path_dirt"), "J": ("path_stone", "path_stone", "stone", "path_dirt"),
                "K": ("path_dirt", "path_dirt", "path_stone")}[variant]
    want = {"I": 7, "J": 8, "K": 4}[variant]
    for _ in range(500):
        if len(placed) >= want:
            break
        pt = rand_inside(pts, rnd, 0.0055)
        if not pt:
            continue
        r = rnd.uniform(0.0050, 0.0075)
        if all(math.dist(pt, (qx, qy)) > r + qr + 0.0010 for qx, qy, qr in placed):
            placed.append((pt[0], pt[1], r))
            col = rnd.choice(cob_cols)
            if variant == "K":
                parts.append(flat_patch("worn", pt[0], pt[1], r, ztop + 0.0002 * rnd.random() + 0.0001, col, rnd, 8))
            else:
                h = rnd.uniform(0.0007, 0.0012) if col != "path_dirt" else 0.0004
                o = small("cobble", r, r * 0.86, h, pt[0], pt[1], ztop - 0.0004, col, 8, rnd.uniform(0, 45))
                parts.append(o)
    if variant == "K":   # sandy trail: a few scratch-like pebbles
        for _ in range(8):
            pt = rand_inside(pts, rnd, 0.004)
            if pt:
                parts.append(small("pebble", rnd.uniform(0.0016, 0.0024), 0.0010, 0.0010, pt[0], pt[1], ztop - 0.0003,
                                   rnd.choice(("path_stone", "stone", "path_stone")), 5, rnd.uniform(0, 70)))
    # edge dressing outside the trail: stone clusters, tufts, flowers (never near a cell border)
    ep = [p for p in edge_points(outset_pts(pts, 0.0012), 0.0095, 0.0016) if border_taper(*p, 0.008) >= 1.0]
    rnd.shuffle(ep)
    k = 0
    for x, y in ep[:3]:      # stone clusters of two or three
        for j in range(rnd.choice((2, 3))):
            r = rnd.uniform(0.0034, 0.0052)
            parts.append(small("edge_stone", r, r * 0.68, rnd.uniform(0.0028, 0.0046),
                               max(-0.0225, min(0.0225, x + rnd.uniform(-0.0035, 0.0035))), max(-0.0225, min(0.0225, y + rnd.uniform(-0.0035, 0.0035))), 0.0,
                               rnd.choice(("stone", "path_stone", "stone", "stone_dark")), 6, rnd.uniform(0, 60)))
    for x, y in ep[3:7]:     # grass tufts
        parts += hump(x, y, 0.0038, 0.0050, rnd.choice(("leaf_green", "leaf_light")), rnd)
    for x, y in ep[7:10]:    # tiny flowers
        parts.append(small("flower", 0.0020, 0.0008, 0.0042, x, y, 0.0, rnd.choice(("wall_cream", "leaf_yellow", "roof_terracotta")), 4, rnd.uniform(0, 70)))
    return parts



# ---- round 4 (L): variant I with the changes Siddharth asked for by saying yes to all of them (2026-10-20):
# base I, softer wider grass skirt, bigger edge clusters, corner tiles that turn in a smooth quarter circle
# (centre-line radius = half a cell), two proposed earth tones dirt_light / dirt_dark (palette proposal, not yet applied).

def arc_pts(cx, cy, r, a0, a1, rnd, n=10, amp=0.0022):
    """Points on an arc from angle a0 to a1 (degrees), radius wobbling gently, zero wobble at both ends."""
    p1, p2 = rnd.uniform(0, 6.28), rnd.uniform(0, 6.28)
    out = []
    for i in range(n):
        t = i / n
        k = 0.0 if i == 0 else amp * (0.65 * math.sin(6.2832 * 1.1 * t + p1) + 0.35 * math.sin(6.2832 * 2.4 * t + p2)) * math.sin(math.pi * t) ** 0.6
        a = math.radians(a0 + (a1 - a0) * t)
        out.append((cx + (r + k) * math.cos(a), cy + (r + k) * math.sin(a)))
    return out


def outline4(kind, rnd):
    if kind != "corner":
        return outline3(kind, rnd)
    w = W3
    pts = arc_pts(H, H, H + w, -90, -180, rnd, 12)          # outer edge: (H,-w) round to (-w,H)
    pts.append((-w, H))
    pts += arc_pts(H, H, H - w, 180, 270, rnd, 4, 0.0004)    # inner edge: (w,H) round to (H,w)
    pts.append((H, w))
    set_sides(pts)
    return pts


def tile4(kind, seed):
    rnd = random.Random(seed)
    pts = outline4(kind, random.Random(2000 + len(kind)))
    parts = [mound("path", pts, "dirt_light", 0.0016, slope=0.0032, crown=0.0006)]
    ztop = 0.0016
    parts.append(ring_flat("skirt", outset_pts(pts, 0.0110), outset_pts(pts, 0.0020), 0.0005, "leaf_green"))
    placed = []
    for _ in range(500):
        if len(placed) >= 6:
            break
        pt = rand_inside(pts, rnd, 0.0060)
        if not pt:
            continue
        r = rnd.uniform(0.0055, 0.0080)
        if all(math.dist(pt, (qx, qy)) > r + qr + 0.0012 for qx, qy, qr in placed):
            placed.append((pt[0], pt[1], r))
            col = rnd.choice(("path_stone", "dirt_dark", "dirt_dark", "path_dirt"))
            h = 0.0009 if col != "path_dirt" else 0.0004
            parts.append(small("cobble", r, r * 0.88, h, pt[0], pt[1], ztop - 0.0004, col, 8, rnd.uniform(0, 45)))
    ep = [p for p in edge_points(outset_pts(pts, 0.0012), 0.0105, 0.0016) if border_taper(*p, 0.008) >= 1.0]
    rnd.shuffle(ep)
    for x, y in ep[:3]:      # stone clusters: bigger, two or three stones
        for j in range(rnd.choice((2, 3))):
            r = rnd.uniform(0.0046, 0.0066)
            parts.append(small("edge_stone", r, r * 0.68, rnd.uniform(0.0038, 0.0058),
                               max(-0.0225, min(0.0225, x + rnd.uniform(-0.0035, 0.0035))),
                               max(-0.0225, min(0.0225, y + rnd.uniform(-0.0035, 0.0035))), 0.0,
                               rnd.choice(("stone", "path_stone", "stone", "stone_dark")), 6, rnd.uniform(0, 60)))
    for x, y in ep[3:6]:     # grass tufts: bigger
        parts += hump(x, y, 0.0052, 0.0066, rnd.choice(("leaf_green", "leaf_light")), rnd)
    for x, y in ep[6:9]:     # flowers: bigger
        parts.append(small("flower", 0.0028, 0.0010, 0.0060, x, y, 0.0, rnd.choice(("wall_cream", "leaf_yellow", "roof_terracotta")), 4, rnd.uniform(0, 70)))
    return parts


KINDS = ("straight", "corner", "t", "end")
SEED = {"A": 11, "B": 12, "C": 13, "D": 14, "E": 21, "F": 22, "G": 23, "H": 24, "I": 31, "J": 32, "K": 33, "L": 34}


def build(variant, kind):
    parts = tile(variant, kind, SEED[variant] + KINDS.index(kind))
    return bc.assemble("ew_world_path_%s_%s" % (kind, variant), [("", parts, (0, 0, 0), None)])


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    v = args[0] if args else "A"
    if v == "FINAL":   # variant L, chosen by Siddharth 2026-10-21 ('After'): ew_world_path_<kind>_v01, one blend + glb each
        kind = args[1]
        bc.clear_scene()
        parts = tile4(kind, SEED["L"] + KINDS.index(kind))
        obj = bc.assemble("ew_world_path_%s_v01" % kind, [("", parts, (0, 0, 0), None)])
        print("BLEND", bc.save_blend(obj, "path_" + kind))
        print("EXPORT", bc.export_glb(obj, "world"))
        sys.exit(0)
    bc.clear_scene()
    objs = []
    for i, k in enumerate(KINDS):
        o = build(v, k)
        o.location = (i * 0.07, 0, 0)
        objs.append(o)
    print("BLEND", bc.save_blend(objs[0], "path_" + v))
