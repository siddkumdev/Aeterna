"""The Warden, round 4: undead mythic creature bosses with three phases (Durva 2026-11-02: "only the wyrm; the build needs to look better;
try a bigger budget; undead or lich, newer concepts, more colours, better detail, more accuracy"). Uses boss_kit.py (smooth skin, scales,
spine, ribs, anatomical skull) and palette B (tools/palette_b.py). Budget: 12000 per boss until tested on a Quest.

Run one:  blender --factory-startup -b -P assets/generators/make_boss4.py -- <key>     (saves assets/blend/boss_<key>.blend)
  lich_wyrm   the living aurora wyrm of round 3, now undead: P1 scaled rainbow serpent; P2 the skin sheds, spine and ribs show; P3 spirit-flame crown
Parts tagged with the custom property ew_phase (1, 2 or 3) are meant to show from that phase on (P1 parts hide in P2: ew_phase_until = 1).
Godot reads these as glTF extras; nothing animates them yet.
"""
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import boss_kit as bk  # noqa: E402
import make_boss3 as b3  # noqa: E402  (crystal_anchors, scale_about, grad)

mc = bk.mc
bc, V, seg, chain, flat, place = bk.bc, bk.V, bk.seg, bk.chain, bk.flat, bk.place
PI = math.pi

AURORA = ["jade_deep", "jade_light", "ghost_green", "aqua_light", "saffron", "marigold", "marigold_deep", "ember", "coral_deep", "rose_deep", "candy_pink", "warden_orchid"]
AURORA_LIGHT = ["jade_light", "ghost_mint", "aqua_light", "lemon", "gold_bright", "saffron", "marigold", "coral_deep", "candy_pink", "peach", "warden_lilac", "warden_glow"]
SPIRIT = ["ghost_green", "ghost_mint", "spirit_teal", "lime_neon", "lemon", "marigold", "candy_pink", "warden_lilac"]


def stop(cols, t):
    return cols[max(0, min(len(cols) - 1, int(t * len(cols))))]


def shift(objs, v):
    for o in objs:
        for vert in o.data.vertices:
            vert.co = vert.co + v
    return objs


def tag(obj, suffix, phase, until=None):
    o = bpy.data.objects[obj.name + "__" + suffix]
    o["ew_phase"] = phase
    if until:
        o["ew_phase_until"] = until


def lich_wyrm():
    N = 72
    pts, rx, rz = [], [], []
    P0, P1, P2, P3 = (0, 0.042, 0.110), (0, 0.068, 0.165), (0, 0.034, 0.222), (0, -0.030, 0.206)
    for i in range(N):
        t = i / (N - 1)
        if t < 0.82:
            u = t / 0.82
            th = 2 * PI * 3.0 * u + PI / 2
            R = 0.062 - 0.020 * u
            p = V((math.cos(th) * R, math.sin(th) * R, 0.0060 + 0.104 * u ** 1.05))
            r = 0.0032 + 0.0092 * (u ** 0.75)
        else:
            v = (t - 0.82) / 0.18
            p = b3.bez(P0, P1, P2, P3, v)
            r = 0.0124 - 0.0030 * v
        pts.append(p)
        rx.append(r)
        rz.append(r * 1.10)
    H = pts[-1]
    groups = []
    # ---- root: spine bones + a tail spike in the ground (always present)
    root = bk.vertebrae(pts, rx, bk.frames(pts), every=2, size=1.25)
    root.append(seg("tailbone", pts[0], V((pts[0].x, pts[0].y, 0.0)), 0.0030, 0.0003, "bone", 5))
    # the spectral core: a dark column the ribs wrap around once the skin is gone
    core, _ = bk.skin("core", pts, [r * 0.58 for r in rx], [r * 0.58 for r in rx],
                      lambda i, n: stop(["warden_midnight", "grave_teal", "jade_deep", "spirit_teal", "warden_plum", "warden_midnight"], i / n), sides=8, per=3, belly=0.0)
    root += core
    groups.append(("", root, (0, 0, 0), ""))
    # ---- P1 skin and scales (hide in P2)
    skin_objs, fr = bk.skin("skin", pts, rx, rz, lambda i, n: stop(AURORA, i / n), sides=12, per=2, belly=0.7)
    groups.append(("skin", skin_objs, (0, 0, 0), ""))
    sc = bk.scales(pts, rx, rz, fr, lambda i, j: stop(AURORA_LIGHT if (i + j) % 2 else AURORA, i / N), every=1, angles=(-75, -40, -5, 30, 65), size=1.0)
    groups.append(("scales", sc, (0, 0, 0), ""))
    belly = bk.scales(pts, rx, rz, fr, lambda i, j: stop(AURORA_LIGHT, i / N), every=1, angles=(125, 155, 180, 205, 235), size=0.9, name="scute")
    groups.append(("belly_scutes", belly, (0, 0, 0), ""))
    # ---- P2 ribs (appear when the skin is shed) and dorsal bone fins
    rb = bk.ribs(pts, rx, rz, fr, every=3, col="bone_warm", reach=1.20, tube=0.0017, sweep=0.0006)
    groups.append(("ribs", rb, (0, 0, 0), ""))
    # ---- head: skull pitched down at the top of the neck
    R = 0.0170
    PITCH = 26
    cr, jw = bk.skull(R, base_col="bone_warm", shade="bone_aged", socket="obsidian", eye="ghost_green")
    head = [place(o, (PITCH, 0, 0), tuple(H)) for o in cr]
    for s in (-1, 1):  # antler crown of ribs and gold tines
        main = [V((s * R * 0.50, R * 0.10, R * 0.70)), V((s * R * 1.10, R * 0.80, R * 1.35)), V((s * R * 1.70, R * 1.90, R * 1.55)), V((s * R * 1.95, R * 3.10, R * 1.10)), V((s * R * 1.75, R * 3.90, R * 0.40))]
        antler = chain("antler", main, [R * 0.30, R * 0.26, R * 0.20, R * 0.13, R * 0.02], "bone_aged", 6, joints=False)
        for k, (a, b) in enumerate(((1, V((s * R * 1.4, R * 0.7, R * 2.3))), (2, V((s * R * 2.5, R * 1.7, R * 2.5))), (3, V((s * R * 2.9, R * 3.0, R * 2.0))))):
            antler += chain("tine", [main[a], b], [R * 0.13, R * 0.015], "gold_bright" if k % 2 else "marigold", 5, joints=False)
        head += [place(o, (PITCH, 0, 0), tuple(H)) for o in antler]
    # frill spokes
    c0 = V((0, R * 0.60, R * 0.10))
    spokes = []
    for k in range(11):
        a = math.radians(-125 + k * 25)
        L = R * (2.5 if k % 2 == 0 else 1.8)
        spokes.append(V((math.sin(a) * L, R * 0.60 + R * 0.5 * abs(math.sin(a)), R * 0.10 + math.cos(a) * L)))
    for k in range(11):
        head.append(place(seg("spoke", c0, spokes[k], R * 0.11, R * 0.04, "bone_aged", 5), (PITCH, 0, 0), tuple(H)))
    groups.append(("head", head, tuple(H), ""))
    web = [place(flat("web", [tuple(c0), tuple(spokes[k]), tuple(spokes[k + 1])], 0.0010, stop(AURORA[::-1], k / 10)), (PITCH, 0, 0), tuple(H)) for k in range(10)]
    groups.append(("frill_web", web, tuple(H + V((0, 0.010, 0.004))), "head"))
    hinge = V((0, -R * 0.15, -R * 0.55))
    jaw_objs = shift(jw, -hinge)
    hw = V(H) + mc.mathutils.Euler((math.radians(PITCH), 0, 0)).to_matrix() @ hinge
    jaw_objs = [place(o, (PITCH + 24, 0, 0), tuple(hw)) for o in jaw_objs]
    jaw_objs.append(place(seg("tongue", V((0, -R * 0.4, 0)), V((0, -R * 2.0, -R * 0.2)), R * 0.10, R * 0.03, "ember", 4), (PITCH + 24, 0, 0), tuple(hw)))
    groups.append(("jaw", jaw_objs, tuple(hw), "head"))
    # ---- P3 spirit flames along the back and neck, and a bone-shard crown
    fl = []
    for k in range(30):
        i = 4 + k * 2
        if i >= N - 2:
            break
        p, nrm = pts[i], fr[1][i]
        side = -1 if k % 2 else 1
        bdir = fr[2][i] * side
        fl += chain("flame", [p + nrm * rx[i] * 0.9, p + nrm * rx[i] * 1.6 + bdir * 0.004 + V((0, 0, 0.006)), p + nrm * rx[i] * 2.4 + bdir * 0.009 + V((0, 0, 0.014))],
                    [0.0030, 0.0022, 0.0003], stop(SPIRIT, (k % 8) / 8), 4)
    groups.append(("flames", fl, tuple(pts[40]), ""))
    shards = []
    for k in range(18):
        a = 2 * PI * k / 18
        p = V((math.cos(a) * 0.1030, math.sin(a) * 0.1030, 0.0650 + 0.0450 * math.sin(k * 1.9)))
        shards.append(seg("shard", p + V((0, 0, -0.0080)), p + V((0, 0, 0.0100)), 0.0034, 0.0002, "bone_warm" if k % 2 else "ghost_mint", 4))
        shards.append(seg("shard", p + V((0, 0, -0.0080)), p + V((0, 0, -0.0150)), 0.0024, 0.0002, "bone_aged", 4))
    groups.append(("shards", shards, (0, 0, 0.0900), ""))
    obj = bc.assemble("ew_boss_lich_wyrm_v01", groups)
    for suffix, ph, until in (("skin", 1, 1), ("scales", 1, 1), ("belly_scutes", 1, 1), ("frill_web", 1, 1), ("ribs", 2, None), ("flames", 3, None), ("shards", 2, None)):
        tag(obj, suffix, ph, until)
    b3.crystal_anchors(obj, 0.1000)
    bc.anchor(obj, "eye_anchor", tuple(V(H) + V((0.0080, -0.0200, 0.0080))), "head", 0.005)
    bc.anchor(obj, "mouth_anchor", tuple(hw + V((0, -0.0300, -0.0200))), "jaw", 0.007)
    bc.anchor(obj, "phylactery_anchor", tuple(V(pts[52]) + V((0, 0, rx[52]))), "", 0.007)
    bc.anchor(obj, "summon_anchor", (0, -0.0950, 0.0150), "", 0.008)
    return obj



def lin(a, b, n):
    return [a + (b - a) * i / (n - 1) for i in range(n)]


def flower(c, R, n, petal, centre, facing="y", tag="flower"):
    """A flower: centre + n flattened petals; facing 'y' = faces -Y, 'z' = faces up."""
    c = V(c)
    P = [bc.blob(tag + "_c", R * 0.42, tuple(c), centre, 1)]
    for k in range(n):
        a = 2 * PI * k / n
        if facing == "y":
            q = c + V((math.cos(a) * R * 0.72, -R * 0.05, math.sin(a) * R * 0.72))
            sq = (1.0, 0.45, 1.0)
        else:
            q = c + V((math.cos(a) * R * 0.72, math.sin(a) * R * 0.72, -R * 0.05))
            sq = (1.0, 1.0, 0.45)
        P.append(bc.blob(tag, R * 0.50, tuple(q), petal[k % len(petal)] if isinstance(petal, (list, tuple)) else petal, 1, sq))
    return P


def mini_skull(p, R, col="bone_warm", facing=0.0):
    P = [bc.blob("skull", R, (0, 0, 0), col, 2, (0.90, 1.05, 0.85)), bc.box("jaw", (R * 0.8, R * 0.7, R * 0.35), (0, -R * 0.5, -R * 0.75), "bone_aged"),
         bc.box("eye", (R * 0.30, R * 0.25, R * 0.34), (-R * 0.36, -R * 0.82, R * 0.05), "obsidian"), bc.box("eye", (R * 0.30, R * 0.25, R * 0.34), (R * 0.36, -R * 0.82, R * 0.05), "obsidian")]
    for o in P:
        place(o, (0, 0, facing), tuple(p))
    return P


def hand(base, d, side=1, col="bone_warm", L=1.0):
    """A skeletal hand at `base` pointing along unit vector d: palm and five two-joint fingers."""
    base, d = V(base), V(d).normalized()
    ref = V((0, 0, 1)) if abs(d.z) < 0.9 else V((1, 0, 0))
    w = d.cross(ref).normalized()
    P = [bc.blob("palm", 0.0042 * L, tuple(base + d * 0.0030 * L), col, 1, (1, 1, 0.6))]
    for k in range(5):
        off = (k - 2) * 0.0019 * L
        f0 = base + d * 0.0060 * L + w * off
        f1 = f0 + d * (0.0050 if k not in (0, 4) else 0.0040) * L + w * off * 0.3
        f2 = f1 + d * (0.0045 if k not in (0, 4) else 0.0035) * L
        P += chain("finger", [f0, f1, f2], [0.0011 * L, 0.0009 * L, 0.0003], col, 4, joints=False)
    return P


def bone_arm(S, E, H, col="bone_warm", r=0.0036):
    P = chain("arm", [V(S), V(E), V(H)], [r, r * 0.85, r * 0.7], col, 6, joints=False)
    P += [bc.blob("elbow", r * 1.05, tuple(V(E)), "bone_aged", 1), bc.blob("shoulder", r * 1.3, tuple(V(S)), "bone_aged", 1)]
    return P


def calavera_lich():
    ROBE_BANDS = ["warden_midnight", "warden_plum", "warden_midnight", "marigold_deep"]
    groups = []
    # ---- root: a rib cage and spine on a ghostly core (always present) + pelvis
    tp = [V((0, 0, z)) for z in lin(0.118, 0.160, 8)]
    tr = [0.021 + 0.0025 * math.sin(i / 7 * PI) for i in range(8)]
    frt = bk.frames(tp)
    root = bk.vertebrae(tp, tr, frt, every=1, size=1.0)
    core, _ = bk.skin("core", tp, [r * 0.62 for r in tr], [r * 0.62 for r in tr], lambda i, n: stop(["warden_midnight", "grave_teal", "spirit_teal"], i / n), sides=10, per=3)
    root += core
    root += bk.ribs(tp, tr, tr, frt, every=1, col="bone_warm", reach=1.12, tube=0.0017, sweep=0.0)
    for k in range(4):  # neck vertebrae
        root.append(bc.blob("neckbone", 0.0045 - 0.0004 * k, (0, 0.0015, 0.1625 + k * 0.0060), "bone_warm", 1))
    root += [bc.blob("pelvis", 0.0150, (0, 0, 0.1000), "bone_aged", 2, (1.4, 0.8, 0.7)), seg("tailbone", V((0, 0, 0.0900)), V((0, 0, 0.0)), 0.0100, 0.0030, "bone_aged", 8)]
    for s in (-1, 1):  # bare leg bones reach the ground under the robe
        root += chain("leg", [V((s * 0.0130, 0, 0.0950)), V((s * 0.0160, -0.0020, 0.0500)), V((s * 0.0170, -0.0040, 0.0040))], [0.0050, 0.0040, 0.0034], "bone_warm", 6, joints=False)
        root.append(bc.blob("foot", 0.0070, (s * 0.0170, -0.0090, 0.0030), "bone_aged", 1, (0.9, 1.7, 0.5)))
    groups.append(("", root, (0, 0, 0), ""))
    # ---- P1 robe: tall flared skin, petal hem, flower pauldrons (hides in P2)
    robe = []
    # three layered tiers, each flaring out at its hem, with a bright trim chunk at the bottom of each
    for (z0, z1, rb, rt, base, trim, n_) in ((0.003, 0.058, 0.082, 0.054, "warden_plum", "marigold", 12), (0.048, 0.104, 0.066, 0.040, "warden_midnight", "candy_pink", 12), (0.094, 0.152, 0.046, 0.023, "obsidian", "turquoise", 12)):
        zs = lin(z0, z1, n_)
        rp = [V((0, 0, z)) for z in zs]
        rr = [rt + (rb - rt) * (1 - i / (n_ - 1)) ** 1.7 for i in range(n_)]
        tier, _ = bk.skin("robe", rp, rr, rr, lambda i, n, base=base, trim=trim: trim if i < 2 else base, sides=22, per=1, caps=(False, False))
        robe += tier
        for k in range(16):  # scalloped trim ruffle at the tier hem
            a = 2 * PI * k / 16
            robe.append(bc.blob("ruffle", 0.0062, (math.cos(a) * rb * 1.02, math.sin(a) * rb * 1.02, z0 + 0.0040), trim, 1, (1.3, 1.0, 0.6)))
    # embroidered vertical panels running down all three tiers (breaks up the tiered-cake look)
    prof = []
    for (z0, z1, rb, rt) in ((0.003, 0.058, 0.082, 0.054), (0.048, 0.104, 0.066, 0.040), (0.094, 0.152, 0.046, 0.023)):
        for i in range(9):
            f = i / 8.0
            prof.append((z0 + (z1 - z0) * f, rt + (rb - rt) * (1 - f) ** 1.7))
    prof.sort(key=lambda t: t[0])
    for pn in range(16):
        a = 2 * PI * pn / 16
        pp = [V((math.cos(a) * (rr_ + 0.0010), math.sin(a) * (rr_ + 0.0010), zz_)) for (zz_, rr_) in prof]
        robe += bk.skin("panel", pp, [0.0008] * len(pp), [0.0030] * len(pp), lambda i, n, pn=pn: stop(["marigold", "candy_pink", "turquoise", "gold_bright"], ((pn + (i // 6)) % 4) / 4), sides=4, per=6, caps=(False, False))[0]
    for s in (-1, 1):
        robe += flower((s * 0.0310, 0, 0.1560), 0.0120, 8, ["marigold", "saffron", "marigold_deep"], "ember", "y", "pauldron")
    groups.append(("robe", robe, (0, 0, 0), ""))
    # ---- head: sugar skull with flower-ringed sockets, forehead jewels and a marigold-and-candle crown
    R = 0.0240
    HC = V((0, -0.002, 0.1950))
    cr, jw = bk.skull(R, base_col="bone_warm", shade="bone_aged", socket="obsidian", eye="ghost_green")
    head = [place(o, (0, 0, 0), tuple(HC)) for o in cr]
    deco = []
    for s in (-1, 1):
        deco += flower(HC + V((s * R * 0.48, -R * 0.99, R * 0.08)), R * 0.62, 8, ["candy_pink", "marigold", "turquoise", "candy_pink"], "obsidian", "y", "eyeflower")
        deco += [bc.box("jewel", (R * 0.12, R * 0.10, R * 0.20), tuple(HC + V((s * R * 0.30, -R * 1.05, R * 0.70))), "turquoise"), bc.blob("cheekdot", R * 0.08, tuple(HC + V((s * R * 0.62, -R * 0.95, -R * 0.28))), "marigold", 1)]
        deco += chain("swirl", [HC + V((s * R * 0.66, -R * 0.92, -R * 0.10)), HC + V((s * R * 0.80, -R * 0.82, -R * 0.35)), HC + V((s * R * 0.60, -R * 0.88, -R * 0.52))], [R * 0.05] * 3, "rose_deep", 4, joints=False)
    deco += [bc.box("diamond", (R * 0.16, R * 0.10, R * 0.34), tuple(HC + V((0, -R * 1.00, R * 0.62))), "gold_bright"), bc.box("diamond", (R * 0.10, R * 0.10, R * 0.20), tuple(HC + V((0, -R * 1.00, R * 0.30))), "candy_pink")]
    for k in range(9):  # crown of blossoms
        a = math.radians(-100 + k * 25)
        deco += flower(HC + V((math.sin(a) * R * 1.05, -R * 0.15, R * 0.80 + math.cos(a) * R * 0.45)), R * 0.38, 5, ["marigold", "saffron", "ember"] if k % 2 else ["candy_pink", "peach", "rose_deep"], "gold_bright", "y", "crownflower")
    for k in range(7):  # a second, higher row of blossoms behind the first
        a = math.radians(-75 + k * 25)
        deco += flower(HC + V((math.sin(a) * R * 0.85, R * 0.30, R * 1.25 + math.cos(a) * R * 0.30)), R * 0.34, 5, ["saffron", "candy_pink", "marigold"], "gold_bright", "y", "crownflower2")
    for k, dx in enumerate((-0.0140, -0.0070, 0.0, 0.0070, 0.0140)):  # candles
        h = 0.020 + 0.006 * (2 - abs(k - 2))
        z0 = 0.2250 + 0.0020 * (2 - abs(k - 2))
        deco += [seg("candle", V((dx, 0.004, z0)), V((dx, 0.004, z0 + h)), 0.0025, 0.0024, "bone", 7), seg("flame", V((dx, 0.004, z0 + h)), V((dx, 0.004, z0 + h + 0.0070)), 0.0020, 0.0002, "ember", 5)]
    head += deco
    groups.append(("head", head, (0, 0.002, 0.1660), ""))
    hinge = V((0, -R * 0.15, -R * 0.55))
    jaw_o = shift(jw, -hinge)
    jaw_o = [place(o, (14, 0, 0), tuple(HC + hinge)) for o in jaw_o]
    jaw_o += [bc.blob("chinflower", R * 0.14, tuple(HC + V((0, -R * 1.72, -R * 0.62))), "marigold", 1)]
    groups.append(("jaw", jaw_o, tuple(HC + hinge), "head"))

    # ---- four skeletal arms with relics
    def arm(name, S, E, Hh, relic):
        P = bone_arm(S, E, Hh)
        d = V(Hh) - V(E)
        P += hand(V(Hh), d, 1)
        P += relic(V(Hh))
        groups.append((name, P, tuple(S), ""))

    def staff(h):
        P = [seg("shaft", h + V((0, 0, -0.050)), h + V((0, 0, 0.0450)), 0.0015, 0.0016, "wood_dark", 6)]
        P += mini_skull(h + V((0, 0, 0.0540)), 0.0070, "bone_warm", 0)
        P += flower(h + V((0, -0.0050, 0.0640)), 0.0050, 6, ["marigold", "candy_pink"], "gold_bright", "y", "topflower")
        return P

    def lantern(h):
        return [bc.cone("cage", 0.0070, 0.0060, 0.0110, tuple(h + V((0, 0, -0.0070))), "gold_dark", 6), bc.cone("glow", 0.0050, 0.0040, 0.0090, tuple(h + V((0, 0, -0.0070))), "ghost_mint", 6),
                bc.cone("cap", 0.0074, 0.0004, 0.0050, tuple(h + V((0, 0, -0.0005))), "gold_deep", 6)] + chain("handle", [h + V((-0.0040, 0, -0.0010)), h + V((0, 0, 0.0040)), h + V((0.0040, 0, -0.0010))], [0.0008] * 3, "gold_deep", 4, joints=False)

    def book(h):
        return [bc.box("book", (0.0150, 0.0050, 0.0200), tuple(h + V((0, -0.0060, 0.0020))), "blood_red"), bc.box("pages", (0.0135, 0.0042, 0.0185), tuple(h + V((0.0004, -0.0060, 0.0020))), "bone"),
                bc.box("clasp", (0.0030, 0.0056, 0.0050), tuple(h + V((0.0070, -0.0060, 0.0020))), "gold_bright"), bc.blob("sigil", 0.0030, tuple(h + V((0, -0.0090, 0.0020))), "warden_orchid", 1)]

    def jar(h):
        return [bc.blob("jar", 0.0090, tuple(h + V((0, -0.0050, 0.0080))), "jade_light", 2, (1, 1, 1.2)), bc.blob("soul", 0.0050, tuple(h + V((0, -0.0050, 0.0080))), "ghost_green", 1),
                bc.cone("lid", 0.0050, 0.0050, 0.0030, tuple(h + V((0, -0.0050, 0.0200))), "gold_bright", 8)]
    arm("arm_ur", (-0.0290, 0, 0.1560), (-0.0560, -0.0120, 0.1720), (-0.0680, -0.0280, 0.1500), staff)
    arm("arm_ul", (0.0290, 0, 0.1560), (0.0560, -0.0120, 0.1720), (0.0680, -0.0280, 0.1500), lantern)
    arm("arm_lr", (-0.0250, 0, 0.1400), (-0.0480, -0.0150, 0.1300), (-0.0560, -0.0380, 0.1230), book)
    arm("arm_ll", (0.0250, 0, 0.1400), (0.0480, -0.0150, 0.1300), (0.0560, -0.0380, 0.1230), jar)
    # ---- cape of aurora ribbons flowing back from the shoulders
    cape = []
    for k in range(16):
        x0 = (k - 7.5) * 0.0044
        pts = [V((x0, 0.012, 0.158)), V((x0 * 1.5, 0.026, 0.150)), V((x0 * 2.2, 0.044, 0.128)), V((x0 * 3.0, 0.064, 0.095)), V((x0 * 3.4, 0.082, 0.055)), V((x0 * 3.6, 0.092, 0.020))]
        cape += bk.skin("ribbon", pts, [0.0009] * 6, [0.0048] * 6, lambda i, n, k=k: stop(AURORA, ((k + i * 0.6) % 12) / 12), sides=4, per=5)[0]
    groups.append(("cape", cape, (0, 0.012, 0.158), ""))
    # ---- orbiting mini skulls with spirit flames
    orb = []
    for k in range(7):
        a = 2 * PI * k / 7
        zc = 0.0900 + 0.0300 * math.sin(k * 1.6)
        orb += mini_skull(V((math.cos(a) * 0.1020, math.sin(a) * 0.1020, zc)), 0.0058, "bone_warm", math.degrees(a) + 90)
        orb.append(seg("flame", V((math.cos(a) * 0.1020, math.sin(a) * 0.1020, zc + 0.0080)), V((math.cos(a) * 0.1020, math.sin(a) * 0.1020, zc + 0.0220)), 0.0030, 0.0002, stop(SPIRIT, k / 7), 4))
    groups.append(("orbit", orb, (0, 0, 0.1000), ""))
    # ---- P3 spirit flame crown behind the head
    fl = []
    for k in range(13):
        a = math.radians(-110 + k * 18)
        fl += chain("flame", [V((math.sin(a) * 0.0300, 0.012, 0.2000 + math.cos(a) * 0.0300)), V((math.sin(a) * 0.0480, 0.016, 0.2000 + math.cos(a) * 0.0500)), V((math.sin(a) * 0.0600, 0.020, 0.2000 + math.cos(a) * 0.0680))],
                    [0.0036, 0.0026, 0.0003], stop(SPIRIT, (k % 8) / 8), 4)
    groups.append(("flame_crown", fl, (0, 0.012, 0.2000), "head"))
    obj = bc.assemble("ew_boss_calavera_lich_v01", groups)
    for suffix, ph, until in (("robe", 1, 1), ("flame_crown", 3, None), ("orbit", 2, None)):
        tag(obj, suffix, ph, until)
    b3.crystal_anchors(obj, 0.1000, 0.1050)
    bc.anchor(obj, "eye_anchor", tuple(HC + V((0.0115, -0.0250, 0.0020))), "head", 0.005)
    bc.anchor(obj, "mouth_anchor", tuple(HC + V((0, -0.0400, -0.0300))), "jaw", 0.006)
    bc.anchor(obj, "phylactery_anchor", (0.0560, -0.0430, 0.1310), "arm_ll", 0.006)
    bc.anchor(obj, "staff_anchor", (-0.0680, -0.0330, 0.2150), "arm_ur", 0.007)
    bc.anchor(obj, "summon_anchor", (0, -0.0950, 0.0150), "", 0.008)
    return obj



def inside(pt, poly):
    x, y = pt
    c = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            c = not c
    return c


def moth_wing(s, b, a_deg, k, outline, layers, spots, vein_ends, name):
    """One patterned wing: a base polygon, concentric colour bands stacked toward the viewer, eye-spots, veins and trailing scallops."""
    a = math.radians(a_deg)

    def P(u, v, off=0.0):
        return (b.x + s * u * k * math.cos(a), b.y + u * k * math.sin(a) + off, b.z + v * k)
    parts = [flat(name, [P(*q) for q in outline], 0.0008, layers[0][0])]
    cu = sum(q[0] for q in outline) / len(outline)
    cv = sum(q[1] for q in outline) / len(outline)
    for li, (col, sc) in enumerate(layers[1:], 1):
        parts.append(flat(name + "_band", [P(cu + (q[0] - cu) * sc, cv + (q[1] - cv) * sc, -0.0009 * li) for q in outline], 0.0008, col))
    off0 = -0.0009 * len(layers)
    for (u, v, rr, cols) in spots:
        for j, c in enumerate(cols):
            parts.append(bc.blob(name + "_spot", rr * k * (1 - 0.32 * j), P(u, v, off0 - 0.0005 * j), c, 1, (1, 0.22, 1)))
    for (u, v) in vein_ends:
        parts.append(seg(name + "_vein", V(P(0.05, 0.0, off0)), V(P(u, v, off0)), 0.0007, 0.0004, "charcoal", 4))
    for i in range(len(outline) - 1):  # scalloped trailing edge
        q0, q1 = outline[i], outline[i + 1]
        m = ((q0[0] + q1[0]) / 2, (q0[1] + q1[1]) / 2)
        d = (m[0] - cu, m[1] - cv)
        ln = math.hypot(*d) or 1.0
        parts.append(seg(name + "_scallop", V(P(m[0], m[1], -0.0006)), V(P(m[0] + d[0] / ln * 0.28, m[1] + d[1] / ln * 0.28, -0.0006)), 0.0016, 0.0002, layers[1][0], 4))
    for ui in range(1, 14):  # overlapping scale plates over the whole wing surface
        for vi in range(-8, 10):
            u, v = ui * 0.24, vi * 0.24 + (0.12 if ui % 2 else 0.0)
            if inside((u, v), outline):
                col = layers[1 + (ui + vi) % (len(layers) - 1)][0]
                parts.append(seg(name + "_plate", V(P(u, v, off0 - 0.0004)), V(P(u + 0.13, v, off0 - 0.0017)), 0.0018, 0.0002, col, 4))
    for i in range(len(outline)):  # long fringe hairs along the rim
        q0, q1 = outline[i], outline[(i + 1) % len(outline)]
        for f in (0.2, 0.5, 0.8):
            m = (q0[0] + (q1[0] - q0[0]) * f, q0[1] + (q1[1] - q0[1]) * f)
            d = (m[0] - cu, m[1] - cv)
            ln = math.hypot(*d) or 1.0
            parts.append(seg(name + "_fringe", V(P(m[0], m[1], -0.0006)), V(P(m[0] + d[0] / ln * 0.24, m[1] + d[1] / ln * 0.24, -0.0006)), 0.0009, 0.0001, "bone_aged", 4))
    return parts


def death_moth():
    TH = V((0, 0.002, 0.075))
    TR = 0.026
    groups = []
    # ---- root: fuzzy thorax with a skull plate on its chest, six legs, tufts
    root = [bc.blob("thorax", TR, tuple(TH), "charcoal", 3, (0.95, 1.15, 1.0))]
    for k in range(230):  # fur tufts over the thorax
        ph = 2.399963 * k
        zz = 0.95 - 1.9 * k / 229.0
        rr_ = math.sqrt(max(0.0, 1 - zz * zz))
        u = V((math.cos(ph) * rr_, math.sin(ph) * rr_, zz))
        if u.y < -0.35 and abs(u.x) < 0.5 and zz > -0.1:
            continue  # keep the chest clear for the skull plate
        pos = TH + V((u.x * TR * 0.95, u.y * TR * 1.15 * 0.95, u.z * TR * 0.95))
        n_ = V((u.x, u.y * 1.0, u.z)).normalized()
        root.append(seg("fur", pos, pos + n_ * 0.0075, 0.0021, 0.0001, stop(["ash_grey", "bone_aged", "charcoal", "marigold_deep", "ash_grey", "bone_warm"], (k % 6) / 6), 4))
    sk = V((0, -0.0275, 0.0620))
    root += [place(bc.blob("skullplate", 0.0150, (0, 0, 0), "bone_warm", 2, (0.92, 0.38, 1.05)), (0, 0, 0), tuple(sk)),
             place(bc.blob("socket", 0.0036, (0, 0, 0), "obsidian", 1, (1, 0.5, 1.2)), (0, 0, 0), tuple(sk + V((-0.0046, -0.0040, 0.0020)))),
             place(bc.blob("socket", 0.0036, (0, 0, 0), "obsidian", 1, (1, 0.5, 1.2)), (0, 0, 0), tuple(sk + V((0.0046, -0.0040, 0.0020)))),
             bc.box("nose", (0.0020, 0.0014, 0.0030), tuple(sk + V((0, -0.0050, -0.0030))), "obsidian")]
    for k in range(6):
        root.append(bc.box("tooth", (0.0014, 0.0016, 0.0032), tuple(sk + V(((k - 2.5) * 0.0026, -0.0046, -0.0072))), "bone"))
    for (a0, a1, a2) in (((0.010, -0.014, 0.062), (0.024, -0.036, 0.030), (0.028, -0.046, 0.0004)), ((0.014, -0.002, 0.060), (0.036, 0.002, 0.028), (0.044, 0.008, 0.0004)), ((0.012, 0.016, 0.060), (0.032, 0.032, 0.030), (0.040, 0.046, 0.0004))):
        for s in (-1, 1):
            root += chain("leg", [V((s * a0[0], a0[1], a0[2])), V((s * a1[0], a1[1], a1[2])), V((s * a2[0], a2[1], a2[2]))], [0.0024, 0.0018, 0.0010], "charcoal", 5, joints=False)
            root.append(seg("claw", V((s * a2[0], a2[1], 0.0030)), V((s * a2[0], a2[1] - 0.0040, 0.0004)), 0.0012, 0.0002, "bone", 4))
    groups.append(("", root, (0, 0, 0), ""))
    # ---- abdomen: banded segments curving back and down
    ap = [b3.bez((0, 0.018, 0.072), (0, 0.040, 0.070), (0, 0.062, 0.050), (0, 0.072, 0.020), i / 15.0) for i in range(16)]
    ar = [0.027 * math.sin(min(1.0, (i + 2) / 8.0) * PI / 2) * (1 - i / 17.0) ** 0.7 + 0.0035 for i in range(16)]
    ab, _ = bk.skin("abdomen", ap, ar, ar, lambda i, n: stop(["charcoal", "marigold_deep", "charcoal", "ash_grey", "charcoal", "ember"], (i % 6) / 6) if i % 3 else "bone_aged", sides=12, per=2, belly=0.4)
    for i in range(1, 16):
        for ang in (-70, -25, 25, 70):
            th = math.radians(ang)
            ab.append(seg("tuft", ap[i] + V((math.sin(th) * ar[i], 0, math.cos(th) * ar[i])), ap[i] + V((math.sin(th) * (ar[i] + 0.0050), 0.0030, math.cos(th) * (ar[i] + 0.0050))), 0.0017, 0.0001, "bone_aged" if (i + ang) % 2 else "ash_grey", 4))
    groups.append(("abdomen", ab, (0, 0.018, 0.072), ""))
    # ---- head: big compound eyes, face fur, mouthparts, coiled proboscis
    HD = V((0, -0.0300, 0.1000))
    head = [bc.blob("head", 0.0115, tuple(HD), "charcoal", 3, (1.0, 0.9, 0.95))]
    for s in (-1, 1):
        head.append(bc.blob("eye", 0.0108, tuple(HD + V((s * 0.0090, -0.0050, 0.0030))), "ember", 3, (0.9, 0.85, 1.0)))
        head.append(bc.blob("pupil", 0.0050, tuple(HD + V((s * 0.0100, -0.0120, 0.0030))), "obsidian", 2, (0.9, 0.5, 1.0)))
        for k in range(16):
            a = 2 * PI * k / 16
            head.append(bc.blob("facet", 0.0013, tuple(HD + V((s * 0.0100 + math.cos(a) * 0.0072, -0.0108, 0.0030 + math.sin(a) * 0.0072))), "marigold", 1))
        head.append(seg("palp", HD + V((s * 0.0040, -0.0100, -0.0070)), HD + V((s * 0.0050, -0.0190, -0.0040)), 0.0026, 0.0006, "bone_aged", 5))
        head.append(seg("fang", HD + V((s * 0.0030, -0.0100, -0.0090)), HD + V((s * 0.0032, -0.0150, -0.0190)), 0.0018, 0.0002, "bone", 4))
    spiral = [HD + V((math.cos(t) * (0.0070 - 0.0013 * t / PI), -0.0130, -0.0090 + math.sin(t) * (0.0070 - 0.0013 * t / PI))) for t in [i * PI / 4 + PI * 1.5 for i in range(13)]]
    head += chain("proboscis", spiral, [0.0011] * 13, "marigold_deep", 4, joints=False)
    groups.append(("head", head, tuple(HD + V((0, 0.012, -0.004))), ""))
    for s, nm in ((-1, "r"), (1, "l")):  # feathered antennae
        pts = [HD + V((s * 0.0040, -0.0020, 0.0100)), HD + V((s * 0.0090, -0.0030, 0.0220)), HD + V((s * 0.0170, -0.0020, 0.0310)), HD + V((s * 0.0270, 0.0010, 0.0340)), HD + V((s * 0.0360, 0.0050, 0.0310))]
        ant = chain("antenna", pts, [0.0016, 0.0013, 0.0011, 0.0009, 0.0003], "bone_warm", 5, joints=False)
        for i in range(1, 5):
            for sg in (-1, 1):
                mid = (pts[i] + pts[i - 1]) / 2
                ant.append(seg("barb", mid, mid + V((sg * 0.0030, -sg * 0.0020, 0.0060 * (1 - i * 0.12))), 0.0010, 0.0001, "bone", 4))
        groups.append(("ant_" + nm, ant, tuple(pts[0]), "head"))
    # ---- four patterned wings
    fore = [(0, 0), (0.3, 1.0), (1.1, 1.8), (2.2, 2.0), (3.0, 1.4), (3.2, 0.5), (2.6, -0.3), (1.4, -0.5)]
    hind = [(0, 0.1), (0.8, 0.0), (1.8, -0.2), (2.5, -0.9), (2.4, -1.8), (1.6, -2.2), (0.6, -1.6), (0.1, -0.8)]
    for s, sx in ((-1, "r"), (1, "l")):
        bF, bH = V((s * 0.0120, 0.0040, 0.0950)), V((s * 0.0120, 0.0080, 0.0720))
        groups.append(("wing_f" + sx, moth_wing(s, bF, 26, 0.0235, fore, [("charcoal", 1.0), ("ash_grey", 0.86), ("marigold_deep", 0.68), ("ember", 0.48), ("obsidian", 0.30)],
                                                   [(2.0, 0.9, 0.34, ["bone_warm", "turquoise", "obsidian"]), (1.0, 1.2, 0.18, ["saffron", "candy_pink"])], [(1.2, 1.9), (2.4, 1.9), (3.0, 1.2), (3.1, 0.4), (2.5, -0.2)], "fwing"), tuple(bF), ""))
        groups.append(("wing_h" + sx, moth_wing(s, bH, 38, 0.0200, hind, [("marigold", 1.0), ("obsidian", 0.86), ("marigold_deep", 0.78), ("saffron", 0.58), ("candy_pink", 0.36)],
                                                   [(1.7, -1.1, 0.32, ["aqua_light", "turquoise", "obsidian"])], [(1.8, -0.2), (2.3, -0.9), (2.3, -1.7), (1.5, -2.1), (0.6, -1.5)], "hwing"), tuple(bH), ""))
    # ---- P3 spirit wings: big pale ghost wings behind
    gw = []
    for s in (-1, 1):
        b = V((s * 0.0140, 0.0200, 0.0900))
        P = lambda u, v, s=s, b=b: (b.x + s * u * 0.0330 * math.cos(0.5), b.y + 0.0100 + u * 0.0330 * math.sin(0.5), b.z + v * 0.0330)
        gw.append(flat("ghostwing", [P(0, 0), P(0.4, 1.4), P(1.5, 2.6), P(2.8, 2.7), P(3.6, 1.6), P(3.8, 0.2), P(3.0, -1.2), P(1.4, -1.6)], 0.0007, "ghost_mint"))
        gw.append(flat("ghostwing", [P(0.6, 0.0), P(1.0, 1.0), P(1.8, 1.8), P(2.8, 1.8), P(3.2, 0.8), P(2.8, -0.4), P(1.6, -0.7)], 0.0007, "warden_lilac"))
    groups.append(("ghost_wings", gw, tuple(V((0, 0.0200, 0.0820))), ""))
    dust = []
    for k in range(14):
        a = 2 * PI * k / 14
        p = V((math.cos(a) * 0.1000, math.sin(a) * 0.1000, 0.0500 + 0.0420 * math.sin(k * 1.8)))
        dust.append(seg("mote", p + V((0, 0, -0.0060)), p + V((0, 0, 0.0080)), 0.0030, 0.0002, stop(["marigold", "turquoise", "candy_pink", "ghost_green", "saffron", "warden_lilac"], (k % 6) / 6), 4))
        dust.append(seg("mote", p + V((0, 0, -0.0060)), p + V((0, 0, -0.0120)), 0.0022, 0.0002, "bone_aged", 4))
    groups.append(("dust", dust, (0, 0, 0.0700), ""))
    obj = bc.assemble("ew_boss_deathhead_moth_v01", groups)
    for suffix, ph, until in (("ghost_wings", 3, None), ("dust", 2, None)):
        tag(obj, suffix, ph, until)
    b3.crystal_anchors(obj, 0.0800, 0.1050)
    bc.anchor(obj, "eye_anchor", tuple(HD + V((0.0100, -0.0125, 0.0030))), "head", 0.005)
    bc.anchor(obj, "mouth_anchor", tuple(HD + V((0, -0.0200, -0.0120))), "head", 0.006)
    bc.anchor(obj, "skull_anchor", tuple(sk + V((0, -0.0070, 0))), "", 0.006)
    bc.anchor(obj, "dust_anchor", (0, 0.0100, 0.0820), "", 0.008)
    bc.anchor(obj, "summon_anchor", (0, -0.0950, 0.0150), "", 0.008)
    return obj


BOSSES = {"lich_wyrm": lich_wyrm, "calavera_lich": calavera_lich, "deathhead_moth": death_moth}

def keep_phase(root, phase):
    """Preview helper: delete the parts that are not visible in `phase` (the real asset keeps all of them, tagged ew_phase)."""
    for o in list(root.children_recursive):
        ph, until = o.get("ew_phase"), o.get("ew_phase_until")
        if ph is None:
            continue
        if ph > phase or (until is not None and phase > until):
            bpy.data.objects.remove(o, do_unlink=True)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    key = argv[0] if argv else "lich_wyrm"
    bc.clear_scene()
    obj = BOSSES[key]()
    mc.smooth(obj)
    print("TRIS", key, mc.tri_count(obj))
    ph = argv[1] if len(argv) > 1 and argv[1] in ("p1", "p2", "p3") else None
    if ph:  # phase preview: boss_<key>_p1.blend ... (not the real asset)
        keep_phase(obj, int(ph[1]))
        bc.save_blend(obj, "boss_%s_%s" % (key, ph))
    else:
        bc.save_blend(obj, "boss_" + key)
