"""Crystal Lens (I03): the hand-held Foresight lens. References art/moodboard/lens_refs_2026-10-21/ (style and shape only):
image 1 (gold hand mirror with cracked blue glass) is the base; images 2 (oval mirror) and 3 (crystal over a compass) feed variants.
Real hand size (held up to the eye), about 20 cm long. Stands upright: handle down from z = 0, glass faces -Y (front).
Parts: root = gold frame + handle; __glass = the crystal (Godot puts the Foresight lens shader on it, I04).
Anchors: __lens_anchor (glass centre, Foresight glow), __grip_anchor (where the hand holds it).
Colours: rarity_gold metal, crystal_blue glass and gems (blue = Foresight only; no purple, that is the Warden).
Run: blender --factory-startup -b -P assets/generators/make_crystal_lens.py -- <A|B|C|D>
"""
import math
import os
import random
import sys

import bmesh
import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "tools"))
sys.path.insert(0, HERE)
import blender_common as bc  # noqa: E402
import make_village_props as vp  # noqa: E402  (cyl, tcyl, tbox, nb)

GOLD, GLASS = "rarity_gold", "crystal_blue"


def ring(name, cz, rx_o, rz_o, rx_i, rz_i, depth, col, n=16):
    """Flat (elliptic) frame ring in the XZ plane centred at (0, 0, cz), thickness `depth` along Y."""
    bm = bmesh.new()
    lay = []
    for y in (-depth / 2, depth / 2):
        o = [bm.verts.new((rx_o * math.cos(2 * math.pi * i / n), y, cz + rz_o * math.sin(2 * math.pi * i / n))) for i in range(n)]
        q = [bm.verts.new((rx_i * math.cos(2 * math.pi * i / n), y, cz + rz_i * math.sin(2 * math.pi * i / n))) for i in range(n)]
        lay.append((o, q))
    (fo, fi), (bo, bi) = lay
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((fo[i], fo[j], fi[j], fi[i]))
        bm.faces.new((bo[i], bi[i], bi[j], bo[j]))
        bm.faces.new((fo[i], bo[i], bo[j], fo[j]))
        bm.faces.new((fi[i], fi[j], bi[j], bi[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = bc._new_obj(name, bm)
    bc.paint(obj, col)
    return vp.nb(obj)  # a bevel on a 20-sided ring costs hundreds of triangles


def slab(name, pts, cz, y0, t, col, tilt=(0.0, 0.0)):
    """Flat polygon (pts in XZ around (0, cz)) extruded from y0 to y0 + t, tilted a few degrees about its centroid."""
    bm = bmesh.new()
    mx = sum(p[0] for p in pts) / len(pts)
    mz = sum(p[1] for p in pts) / len(pts)
    ax, az = math.radians(tilt[0]), math.radians(tilt[1])
    layers = []
    for y in (y0, y0 + t):
        vs = []
        for x, z in pts:
            dy = (z - mz) * math.sin(ax) + (x - mx) * math.sin(az)
            vs.append(bm.verts.new((x, y + dy, cz + z)))
        layers.append(vs)
    a, b = layers
    n = len(pts)
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], b[i], b[j], a[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = bc._new_obj(name, bm)
    bc.paint(obj, col)
    return vp.nb(obj)


def shrink(pts, gap):
    """Pull a polygon toward its centroid by `gap` (metres), leaving open crack lines between shards (you see the room through them)."""
    mx = sum(p[0] for p in pts) / len(pts)
    mz = sum(p[1] for p in pts) / len(pts)
    out = []
    for x, z in pts:
        d = math.hypot(x - mx, z - mz) or 1.0
        k = max(d - gap, d * 0.6) / d
        out.append((mx + (x - mx) * k, mz + (z - mz) * k))
    return out


def cracked_glass(cz, rx, rz, inner, outer, seed, centre=(0.006, 0.004), r1=0.45, t=0.0030, gap=0.0011, tilt=5.0):
    """Glass split into shards: `inner` wedges round an off-centre impact point, `outer` pieces out to the rim."""
    rnd = random.Random(seed)
    cx, cz0 = centre
    rim = lambda a: (rx * math.cos(a), rz * math.sin(a))
    angs_i = sorted(2 * math.pi * (i + rnd.uniform(-0.25, 0.25)) / inner for i in range(inner))
    mid = [(cx + (rim(a)[0] - cx) * r1 * rnd.uniform(0.85, 1.15), cz0 + (rim(a)[1] - cz0) * r1 * rnd.uniform(0.85, 1.15)) for a in angs_i]
    parts = []
    for i in range(inner):
        j = (i + 1) % inner
        parts.append(slab("glass", shrink([(cx, cz0), mid[i], mid[j]], gap), cz, -0.0015, t, GLASS,
                          (rnd.uniform(-tilt, tilt), rnd.uniform(-tilt, tilt))))
    # outer pieces: from two neighbouring mid points out to the rim between their angles
    for i in range(inner):
        j = (i + 1) % inner
        a0, a1 = angs_i[i], angs_i[j] + (2 * math.pi if j == 0 else 0)
        cuts = [a0] + ([(a0 + a1) / 2 + rnd.uniform(-0.15, 0.15)] if (a1 - a0) > 0.9 and len(parts) < inner + outer else []) + [a1]
        for k in range(len(cuts) - 1):
            pa, pb = cuts[k], cuts[k + 1]
            arc = [rim(pa + (pb - pa) * s / 3) for s in range(4)]
            ma = mid[i] if k == 0 else ((mid[i][0] + mid[j][0]) / 2, (mid[i][1] + mid[j][1]) / 2)
            mb = mid[j] if k == len(cuts) - 2 else ((mid[i][0] + mid[j][0]) / 2, (mid[i][1] + mid[j][1]) / 2)
            poly = [ma] + arc + [mb] if ma != mb else [ma] + arc
            parts.append(slab("glass", shrink(poly, gap), cz, -0.0015, t, GLASS,
                              (rnd.uniform(-tilt, tilt), rnd.uniform(-tilt, tilt))))
    return parts


def faceted_glass(cz, rx, rz, n=12, bulge=0.0045, t=0.0030):
    """One whole glass: flat back, the front rises to a shallow faceted point (reads as cut crystal)."""
    bm = bmesh.new()
    back = [bm.verts.new((rx * math.cos(2 * math.pi * i / n), t / 2, cz + rz * math.sin(2 * math.pi * i / n))) for i in range(n)]
    edge = [bm.verts.new((rx * math.cos(2 * math.pi * i / n), -t / 2, cz + rz * math.sin(2 * math.pi * i / n))) for i in range(n)]
    tip = bm.verts.new((0, -t / 2 - bulge, cz))
    bm.faces.new(list(reversed(back)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((back[i], back[j], edge[j], edge[i]))
        bm.faces.new((edge[i], edge[j], tip))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = bc._new_obj("glass", bm)
    bc.paint(obj, GLASS)
    return vp.nb(obj)


def gem(loc, r=0.0042, squash=(1.0, 0.7, 1.25)):
    return vp.nb(bc.blob("gem", r, loc, GLASS, 0, squash))


def scroll(loc, r=0.0055, w=0.0060, col=GOLD):
    """A carved curl, read as a chunky disc facing front (axis along Y)."""
    return vp.nb(vp.tcyl("scroll", r, w, loc, col, 8, 90, 0, 0))


def turned_handle(length, r, col=GOLD):
    """Flared pommel, tapered shaft, collar. Returns (parts, top z)."""
    p = [vp.cyl("pommel", r * 1.25, length * 0.08, (0, 0, 0), col, 8, r * 1.55),
         vp.cyl("pommel", r * 1.55, length * 0.06, (0, 0, length * 0.08), col, 8, r * 0.9),
         vp.cyl("shaft", r * 0.9, length * 0.62, (0, 0, length * 0.14), col, 8, r * 0.75),
         vp.cyl("collar", r * 1.15, length * 0.07, (0, 0, length * 0.76), col, 8),
         vp.cyl("neck", r * 0.85, length * 0.17, (0, 0, length * 0.83), col, 8, r * 1.35)]
    return [vp.nb(o) for o in p], length  # unbevelled: the budget is 800 for the whole lens


# ------------------------------------------------------------------ variants
def lens_A():
    """Round hand mirror (image 1): carved crest with a gem, gem at the neck, turned handle, glass cracked into shards."""
    hp, top = turned_handle(0.100, 0.0090)
    R, Ri = 0.050, 0.041
    cz = top + R - 0.006
    frame = [ring("frame", cz, R, R, Ri, Ri, 0.011, GOLD, 16),
             ring("lip", cz, Ri + 0.0010, Ri + 0.0010, Ri - 0.0022, Ri - 0.0022, 0.0060, GOLD, 12)]
    crest = [scroll((-0.0090, 0, cz + R + 0.0010)), scroll((0.0090, 0, cz + R + 0.0010)),
             vp.cyl("crest", 0.0060, 0.0100, (0, 0, cz + R - 0.0030), GOLD, 4, 0.0025), gem((0, -0.0055, cz + R + 0.0030))]
    neck = [scroll((-0.0110, 0, top - 0.0030), 0.0060), scroll((0.0110, 0, top - 0.0030), 0.0060), gem((0, -0.0128, top - 0.0030))]
    glass = cracked_glass(cz, Ri, Ri, 5, 7, seed=3)
    return hp + frame + crest + neck, glass, (0, 0, cz), (0, 0, 0.050)


def lens_B():
    """Tall oval mirror (images 1 + 2): ornate crest on top, shorter thicker handle, a few big cracks."""
    hp, top = turned_handle(0.085, 0.0100)
    rx, rz, rxi, rzi = 0.042, 0.058, 0.034, 0.050
    cz = top + rz - 0.007
    frame = [ring("frame", cz, rx, rz, rxi, rzi, 0.011, GOLD, 16)]
    crest = [scroll((-0.0120, 0, cz + rz - 0.0010), 0.0065), scroll((0.0120, 0, cz + rz - 0.0010), 0.0065),
             vp.cyl("crest", 0.0070, 0.0140, (0, 0, cz + rz - 0.0020), GOLD, 6, 0.0020),
             gem((0, -0.0060, cz + rz + 0.0040), 0.0048)]
    side = [scroll((-rx - 0.0010, 0, cz), 0.0050), scroll((rx + 0.0010, 0, cz), 0.0050)]
    neck = [gem((0, -0.0140, top - 0.0030))]
    glass = cracked_glass(cz, rxi, rzi, 4, 5, seed=11, centre=(-0.008, -0.018), r1=0.55, tilt=4.0)
    return hp + frame + crest + side + neck, glass, (0, 0, cz), (0, 0, 0.042)


def lens_C():
    """Raw crystal in gold claws (images 1 + 3): a faceted crystal (flattened, you look through its face) held by four
    prongs above a round compass medallion on a turned handle."""
    hp, top = turned_handle(0.090, 0.0090)
    med_z = top + 0.004
    medal = [vp.tcyl("medal", 0.022, 0.008, (0, 0, med_z), GOLD, 12, 90, 0, 0),
             vp.tcyl("medal", 0.016, 0.0095, (0, 0, med_z), GOLD, 4, 90, 45, 0)]
    medal[1]["no_bevel"] = True
    # crystal: two irregular girdles flattened in Y, pointed top and bottom
    rnd = random.Random(7)
    bm = bmesh.new()
    cz = med_z + 0.064
    n = 7
    g = []
    for gz, gr in ((cz - 0.020, 0.030), (cz + 0.018, 0.026)):
        g.append([bm.verts.new((gr * rnd.uniform(0.85, 1.1) * math.cos(2 * math.pi * i / n + gz * 40),
                                0.40 * gr * rnd.uniform(0.85, 1.1) * math.sin(2 * math.pi * i / n + gz * 40),
                                gz + rnd.uniform(-0.004, 0.004))) for i in range(n)])
    bot, tp = bm.verts.new((0, 0, med_z + 0.008)), bm.verts.new((0.004, 0, cz + 0.062))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((g[0][j], g[0][i], bot))
        bm.faces.new((g[0][i], g[0][j], g[1][j], g[1][i]))
        bm.faces.new((g[1][i], g[1][j], tp))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    crystal = bc._new_obj("glass", bm)
    bc.paint(crystal, GLASS)
    vp.nb(crystal)
    claws = []
    for a in (40, 140, 220, 320):
        ar = math.radians(a)
        x, y = 0.020 * math.cos(ar), 0.009 * math.sin(ar)
        claws.append(vp.tbox("claw", (0.0045, 0.0045, 0.042), (x, y, med_z + 0.028), GOLD, -14 * math.sin(ar), 14 * math.cos(ar), 0))
    gems = [gem((0, -0.0060, med_z), 0.0040)]
    return hp + medal + claws + gems, [crystal], (0, 0, cz), (0, 0, 0.045)


def lens_D():
    """Compass mirror (images 1 + 3): round frame with compass points N, E, W and gems, whole faceted glass."""
    hp, top = turned_handle(0.100, 0.0090)
    R, Ri = 0.048, 0.039
    cz = top + R - 0.006
    frame = [ring("frame", cz, R, R, Ri, Ri, 0.011, GOLD, 16),
             ring("lip", cz, Ri + 0.0010, Ri + 0.0010, Ri - 0.0024, Ri - 0.0024, 0.0060, GOLD, 16)]
    pts = []
    for a, ln in ((90, 0.020), (0, 0.014), (180, 0.014)):
        ar = math.radians(a)
        c = vp.tcyl("point", 0.0075, ln, (0, 0, 0), GOLD, 4, 0, 90, 0, r_top=0.0005)
        c["no_bevel"] = True
        # cone axis now along +X (tip at +X); turn it to point outward at angle a in the XZ plane
        vp.tilted(c, ((R + ln / 2 - 0.0045) * math.cos(ar), 0, cz + (R + ln / 2 - 0.0045) * math.sin(ar)), 0, -a, 0)
        pts.append(c)
    for a in (45, 135):
        ar = math.radians(a)
        pts.append(gem((R * 0.95 * math.cos(ar), -0.0060, cz + R * 0.95 * math.sin(ar)), 0.0036))
    pts.append(gem((0, -0.0060, cz + R - 0.0010), 0.0045))
    neck = [scroll((-0.0105, 0, top - 0.0030), 0.0058), scroll((0.0105, 0, top - 0.0030), 0.0058)]
    glass = [faceted_glass(cz, Ri, Ri, 12)]
    return hp + frame + pts + neck, glass, (0, 0, cz), (0, 0, 0.050)


VARIANTS = {"A": lens_A, "B": lens_B, "C": lens_C, "D": lens_D}


def tris(objs):
    return sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)


def build(letter, ver="v01"):
    bc.clear_scene()
    name = "ew_foresight_crystal_lens_%s" % ver
    body, glass, lens_c, grip = VARIANTS[letter]()
    root = bc.assemble(name, [("", body, (0, 0, 0), None), ("glass", glass, lens_c, "", False)])
    bc.anchor(root, "lens_anchor", lens_c, size=0.08)
    bc.anchor(root, "grip_anchor", grip, size=0.03)
    root["ew_place"] = "held"
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    zs = [(o.matrix_world @ v.co).z for o in objs for v in o.data.vertices]
    print("%s %s: %d tris, height %.0f mm" % (name, letter, tris(objs), (max(zs) - min(zs)) * 1000))
    return root


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if args and args[0] == "FINAL":
        obj = build(args[1], args[2])
        bc.save_blend(obj, "crystal_lens")
        print("EXPORT", bc.export_glb(obj, "foresight"))
    else:
        obj = build(args[0])
        bc.save_blend(obj, "crystal_lens_" + args[0])
