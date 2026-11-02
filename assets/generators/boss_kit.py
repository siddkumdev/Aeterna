"""Construction kit for the creature bosses (Durva 2026-11-02: "the build needs to look better ... more accuracy").

Replaces the stacked-cone-and-ball look with:
  skin()        a continuous smooth swept tube along any curve, flat-bellied, coloured in chunks (gradient)
  scales()      overlapping scale plates on the skin, oriented along the body
  vertebrae() / ribs()   an exposed spine and wrapping rib cage that follow the same curve
  skull()       an anatomical skull: cranium, brow, sockets, snout, cheekbones, teeth, canines; jaw separate (hinged part)
All parts are plain meshes painted from palette A or palette B (tools/palette_b.py); the caller groups them with bc.assemble().
"""
import math
import os
import sys

import bmesh
import mathutils

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_characters as mc  # noqa: E402

bc, V, seg, chain, flat, place = mc.bc, mc.V, mc.seg, mc.chain, mc.flat, mc.place
PI = math.pi
Z = mathutils.Vector((0, 0, 1))


def frames(pts):
    """Tangent / up-ish normal / binormal per point. Normal follows world up (so bellies stay down) and falls back to parallel transport on vertical runs."""
    n = len(pts)
    T = [((pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)])).normalized() for i in range(n)]
    N, B = [], []
    prev = None
    for i in range(n):
        up = Z - T[i] * Z.dot(T[i])
        if up.length < 0.35 and prev is not None:
            up = prev - T[i] * prev.dot(T[i])
        elif up.length < 0.35:
            up = V((1, 0, 0)) - T[i] * V((1, 0, 0)).dot(T[i])
        up.normalize()
        if prev is not None and up.dot(prev) < 0:
            up = -up
        N.append(up)
        B.append(T[i].cross(up).normalized())
        prev = up
    return T, N, B


def skin(name, pts, rx, rz, colfn, sides=12, per=2, belly=0.0, caps=(True, True)):
    """Smooth tube through pts. rx[i] = radius along the up direction, rz[i] = radius sideways (pass equal for round).
    belly 0..1 flattens the underside. colfn(i, n) -> palette colour for the chunk starting at ring i. Returns chunk objects."""
    pts = [V(p) for p in pts]
    n = len(pts)
    T, N, B = frames(pts)
    rings = []
    for i in range(n):
        ring = []
        for k in range(sides):
            th = 2 * PI * k / sides
            c, s_ = math.cos(th), math.sin(th)
            ru = rx[i] * (1.0 - belly * 0.45 * max(0.0, -c))  # flatten the lower half
            ring.append(pts[i] + N[i] * (c * ru) + B[i] * (s_ * rz[i]))
        rings.append(ring)
    objs = []
    i0 = 0
    while i0 < n - 1:
        i1 = min(n - 1, i0 + per)
        bm = bmesh.new()
        vr = [[bm.verts.new(p) for p in rings[i]] for i in range(i0, i1 + 1)]
        for a in range(len(vr) - 1):
            for k in range(sides):
                bm.faces.new((vr[a][k], vr[a][(k + 1) % sides], vr[a + 1][(k + 1) % sides], vr[a + 1][k]))
        if caps[0] and i0 == 0:
            c0 = bm.verts.new(pts[0] - T[0] * rx[0] * 0.6)
            for k in range(sides):
                bm.faces.new((c0, vr[0][(k + 1) % sides], vr[0][k]))
        if caps[1] and i1 == n - 1:
            c1 = bm.verts.new(pts[-1] + T[-1] * rx[-1] * 0.6)
            for k in range(sides):
                bm.faces.new((c1, vr[-1][k], vr[-1][(k + 1) % sides]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        o = bc._new_obj(name, bm)
        bc.paint(o, colfn(i0, n))
        o["no_bevel"] = True
        objs.append(o)
        i0 = i1
    return objs, (T, N, B)


def scales(pts, rx, rz, fr, colfn, every=1, angles=(-70, -35, 0, 35, 70), size=1.0, name="scale"):
    """Overlapping pyramid plates on the dorsal side, leaning back along the body."""
    T, N, B = fr
    out = []
    for i in range(0, len(pts), every):
        for j, a in enumerate(angles):
            th = math.radians(a)
            c, s_ = math.cos(th), math.sin(th)
            d = (N[i] * c + B[i] * s_).normalized()
            base = V(pts[i]) + N[i] * (c * rx[i] * 0.98) + B[i] * (s_ * rz[i] * 0.98)
            L = (rx[i] + rz[i]) * 0.5 * 0.38 * size
            w = (rx[i] + rz[i]) * 0.5 * 0.34 * size
            tip = base + d * L * 0.55 - T[i] * L * 0.85
            out.append(seg(name, base + T[i] * w * 0.5, tip, w, 0.0002, colfn(i, j), 4))
    return out


def vertebrae(pts, rx, fr, every=1, col="bone_warm", spine_col="bone", size=1.0):
    """Exposed spine: a knuckle per ring with a neural spine on top."""
    T, N, B = fr
    out = []
    for i in range(0, len(pts), every):
        top = V(pts[i]) + N[i] * rx[i] * 0.55
        out.append(bc.blob("vertebra", rx[i] * 0.42 * size, tuple(top), col, 1, (0.9, 1.0, 1.0)))
        out.append(seg("neural", top, top + N[i] * rx[i] * 0.95 * size - T[i] * rx[i] * 0.3 * size, rx[i] * 0.22 * size, 0.0002, spine_col, 4))
    return out


def ribs(pts, rx, rz, fr, every=2, col="bone", reach=1.18, tube=0.0016, sweep=0.0):
    """Wrapping rib pairs: arcs from the spine down around both sides, slightly outside the skin."""
    T, N, B = fr
    out = []
    for i in range(0, len(pts), every):
        for s_ in (-1, 1):
            arc = []
            for k, a in enumerate((18, 50, 85, 120, 150)):
                th = math.radians(a)
                c, sn = math.cos(th), math.sin(th)
                arc.append(V(pts[i]) + N[i] * (c * rx[i] * reach) + B[i] * (s_ * sn * rz[i] * reach) - T[i] * (sweep * k))
            out += chain("rib", arc, [tube * (1.0 - 0.12 * k) * (rx[i] / 0.009) for k in range(5)], col, 4, joints=False)
    return out


def skull(R, base_col="bone_warm", shade="bone_aged", socket="obsidian", eye="ghost_green", teeth_col="bone", horns=None):
    """An anatomical skull built at the origin facing -Y; returns (cranium parts, jaw parts). R = cranium radius."""
    P = [bc.blob("cranium", R, (0, 0, 0), base_col, 3, (0.92, 1.12, 0.86)),
         bc.blob("maxilla", R * 0.62, (0, -R * 1.05, -R * 0.20), base_col, 3, (0.72, 1.35, 0.62)),
         bc.blob("nasal", R * 0.17, (0, -R * 1.78, R * 0.02), socket, 2, (1.2, 0.55, 1.5)),
         bc.blob("brow_l", R * 0.34, (-R * 0.50, -R * 0.62, R * 0.40), shade, 2, (1.3, 0.9, 0.55)),
         bc.blob("brow_r", R * 0.34, (R * 0.50, -R * 0.62, R * 0.40), shade, 2, (1.3, 0.9, 0.55)),
         bc.box("crest", (R * 0.16, R * 1.55, R * 0.20), (0, -R * 0.15, R * 0.88), shade)]
    for s in (-1, 1):
        P.append(bc.blob("socket", R * 0.30, (s * R * 0.48, -R * 0.78, R * 0.08), socket, 2, (1.0, 0.7, 1.15)))
        P.append(bc.blob("eyelight", R * 0.14, (s * R * 0.48, -R * 0.96, R * 0.06), eye, 1, (1.0, 0.6, 1.0)))
        P += chain("cheek", [V((s * R * 0.50, -R * 1.50, -R * 0.20)), V((s * R * 0.78, -R * 0.95, -R * 0.38)), V((s * R * 0.88, -R * 0.32, -R * 0.10))], [R * 0.11, R * 0.10, R * 0.08], shade, 6, joints=False)
        for k in range(7):  # upper teeth along the lip
            y = -R * (0.75 + k * 0.17)
            P.append(seg("tooth", V((s * R * (0.40 - 0.02 * k), y, -R * 0.55)), V((s * R * (0.40 - 0.02 * k), y, -R * (0.80 if k not in (0, 3) else 1.0))), R * 0.065, 0.0002, teeth_col, 4))
        P.append(seg("canine", V((s * R * 0.34, -R * 1.60, -R * 0.52)), V((s * R * 0.34, -R * 1.66, -R * 1.45)), R * 0.11, 0.0002, teeth_col, 5))
    if horns:
        P += horns
    J = [bc.blob("mandible", R * 0.58, (0, -R * 1.00, -R * 0.62), base_col, 3, (0.66, 1.25, 0.36)), bc.blob("chin", R * 0.22, (0, -R * 1.85, -R * 0.60), shade, 2, (0.9, 0.9, 1.3))]
    for s in (-1, 1):
        for k in range(6):
            y = -R * (0.70 + k * 0.17)
            J.append(seg("tooth", V((s * R * (0.34 - 0.015 * k), y, -R * 0.72)), V((s * R * (0.34 - 0.015 * k), y, -R * (0.48 if k % 2 else 0.40))), R * 0.055, 0.0002, teeth_col, 4))
        J.append(seg("fang", V((s * R * 0.28, -R * 1.60, -R * 0.70)), V((s * R * 0.28, -R * 1.66, R * 0.12)), R * 0.09, 0.0002, teeth_col, 5))
    return P, J
