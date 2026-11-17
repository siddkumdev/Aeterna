"""Skotos, the Warden: a forgotten god of the Dark Wood. Variant round E08 (Siddharth 2026-11-17: tree vibe, "Groot-like" wood-growth attacks).
Bark and leaves from the green-brown palette colours; the glow is Warden purple with ember-red accents and is NOT geometry: dark sockets plus
`__<name>_anchor` empties (eyes, chest knot, palms, base roots). Refs in art/moodboard/skotos/ are style and shape language only.

Run one:  blender --factory-startup -b -P assets/generators/make_skotos.py -- <A|B|C|D>   (saves assets/blend/skotos_<a-d>.blend)
  A  robed antler druid    layered bark-and-leaf robe, branch antlers, carved mask, root-trunk base, arms raised
  B  stilt-legged root spirit  tiny body on very long root legs, leafy hood with horns, long gnarled arms
  C  hulking moss treant   broad mossy shoulders, stump head, big knotted fists, bark_front plate that can split
  D  hooded bark wraith    hood of bark plates, ember eyes deep inside, hanging-root cloak, tendrils trailing into the ground
Boss footprint 3 x 3 cells (0.15 m), height ~5 cells (0.25 m), origin at base centre, budget 6000 tris.
Parts: head, arm_l, arm_r (+ leg_l/leg_r on B/C, antlers, mantle, bark_front where useful for phase changes).
Anchors: eye_l/eye_r (head), chest_knot (root), hand_l/hand_r (arms), roots (base), rune_1.. where a body has runes.
"""
import math
import mathutils
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_characters as mc  # noqa: E402

bc, V, seg, chain, flat, place = mc.bc, mc.V, mc.seg, mc.chain, mc.flat, mc.place
PI = math.pi
BARK = ("wood_dark", "wood_mid")
LEAF = ("leaf_dark", "leaf_green")
SOCK = "ink"


def nb(o):
    o["no_bevel"] = True
    return o


def blob(r, loc, col, sub=1, sq=(1, 1, 1)):
    return nb(bc.blob("b", r, loc, col, sub, sq))


def cyl(r0, r1, h, z0, col, x=0.0, y=0.0, segs=8, rot=0.0):
    return nb(bc.cone("c", r0, r1, h, (x, y, z0 + h / 2), col, segs, rot))


def orient(o, base, d):
    """Blob built along +Z with length L: rotate so Z follows d and put its base at `base`."""
    d = V(d)
    L = d.length
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    o.location = V(base) + d / 2
    bc.apply_transforms(o)
    return nb(o)


def leaf(base, d, W, col):
    L = V(d).length
    return orient(bc.blob("leaf", L / 2, (0, 0, 0), col, 1, (W / L, 0.28 * W / L, 1.0)), base, d)


def spike(base, tip, r, col, segs=5):
    return seg("spike", base, tip, r, 0.0002, col, segs)


def socket(loc, r, sq=(1, 0.55, 1.35), col=SOCK):
    return blob(r, loc, col, 1, sq)


def hand(pos, d, r, col, claws=3, claw_col="wood_light"):
    """Knotted hand: palm ball, fingers along d (a twig-claw fan), a dark palm socket on its front (-Y) face."""
    p, d = V(pos), V(d).normalized()
    P = [blob(r, p, col, 1)]
    side = d.cross(V(0, 0, 1))
    if side.length < 0.2:
        side = V(1, 0, 0)
    side.normalize()
    for i in range(claws):
        f = (i - (claws - 1) / 2) * 0.55
        tip = p + (d + side * f).normalized() * r * 2.6
        P += chain("fing", [p + d * r * 0.5, p + (d + side * f * 0.6).normalized() * r * 1.5, tip],
                   [r * 0.34, r * 0.26, 0.0002], claw_col, 5, joints=False)
    P.append(socket(p + V(0, -r * 0.7, 0), r * 0.5, (1, 0.5, 1)))
    return P


def arm_chain(pts, radii, col, tw=0.15):
    """Gnarled limb: a bendy tube with a few bark knots."""
    P = chain("arm", pts, radii, col, 6)
    for i in range(1, len(pts) - 1):
        P.append(blob(radii[i] * 1.35, pts[i], BARK[i % 2], 1, (1, 1, 0.8)))
    return P


def eyes(hx, hy, hz, dx, r=0.0042, col=SOCK):
    return [socket((-dx, hy, hz), r), socket((dx, hy, hz), r)]


def roots(n, r0, z0, reach, rr=0.006, cols=BARK, phase=0.0, droop=True):
    """Buttress roots flaring out of the base along the ground."""
    P = []
    for i in range(n):
        a = math.radians(i * 360 / n + phase)
        c, s_ = math.cos(a), math.sin(a)
        w = math.sin(i * 2.3) * 0.2
        pts = [V((c * r0, s_ * r0, z0)),
               V((c * (r0 + (reach - r0) * 0.45) - s_ * 0.006 * w * 5, s_ * (r0 + (reach - r0) * 0.45) + c * 0.006 * w * 5, z0 * 0.45)),
               V((c * reach, s_ * reach, 0.0012))]
        P += chain("root", pts, [rr, rr * 0.65, 0.0012], cols[i % 2], 6)
    return P


def bark_plate(name, ang_deg, rad, z, w, h, d, col, lean=0.0):
    """Upright bark plate standing on a ring (face toward the centre axis)."""
    o = nb(bc.box(name, (w, d, h), (0, 0, 0), col))
    o.rotation_euler = (math.radians(lean), 0, 0)
    bc.apply_transforms(o)
    o.rotation_euler = (0, 0, math.radians(ang_deg + 90))
    bc.apply_transforms(o)
    a = math.radians(ang_deg)
    o.location = (math.cos(a) * rad, math.sin(a) * rad, z)
    bc.apply_transforms(o)
    return o


def antlers(hz, spread, h, col="wood_light", thick=0.0032, extra=True, base_y=0.0):
    """Two branching antlers rising from the head (left = +X). Returns parts."""
    P = []
    for sx in (-1, 1):
        pts = [V((sx * spread * 0.25, base_y, hz)), V((sx * spread * 0.55, base_y, hz + h * 0.4)),
               V((sx * spread * 0.95, base_y, hz + h * 0.72)), V((sx * spread * 0.80, base_y, hz + h))]
        P += chain("antler", pts, [thick, thick * 0.8, thick * 0.55, 0.0003], col, 5)
        if extra:
            for t, k in ((0.4, 0.9), (0.72, 0.7)):
                b = pts[1] if t < 0.5 else pts[2]
                tip = b + V((sx * spread * 0.45 * k, -0.004, h * 0.32 * k))
                P += chain("tine", [b, tip], [thick * 0.6, 0.0003], col, 4, joints=False)
                tip2 = b + V((sx * spread * 0.1, 0.012, h * 0.30 * k))
                P += chain("tine", [b, tip2], [thick * 0.5, 0.0003], col, 4, joints=False)
    return P


# ---------------------------------------------------------------- A: robed antler druid
def variant_a():
    sh = 0.158
    body = []
    # root-trunk base melting into the robe hem
    body += [cyl(0.052, 0.040, 0.050, 0.0, "wood_dark", segs=10), cyl(0.040, 0.030, 0.040, 0.046, "wood_mid", segs=10)]
    body += roots(8, 0.040, 0.026, 0.074, 0.0075)
    # layered robe: stacked tapered tiers, each hemmed with hanging leaves
    for z0, h, rb, rt, col in ((0.040, 0.034, 0.046, 0.039, "leaf_dark"), (0.070, 0.034, 0.041, 0.034, "leaf_green"),
                               (0.100, 0.036, 0.036, 0.029, "leaf_dark"), (0.132, 0.030, 0.030, 0.026, "leaf_green")):
        body.append(cyl(rb, rt, h, z0, col, segs=10))
        n = 12
        for i in range(n):
            a = math.radians(i * 360 / n + (z0 * 900))
            r = rb + 0.0015
            body.append(leaf((math.cos(a) * r, math.sin(a) * r, z0 + 0.004),
                             (math.cos(a) * 0.003, math.sin(a) * 0.003, -0.015), 0.0085, LEAF[(i + int(z0 * 100)) % 2]))
    # front panel (tabard) and bark belt
    body.append(nb(bc.box("tab", (0.014, 0.003, 0.062), (0, -0.0385, 0.105), "leaf_light")))
    body.append(cyl(0.031, 0.031, 0.006, 0.116, "wood_light", segs=10))
    # chest knot: a carved ring with a dark socket (glow anchor)
    body.append(blob(0.0095, (0, -0.0275, 0.145), "wood_light", 1, (1, 0.35, 1)))
    body.append(socket((0, -0.0305, 0.145), 0.0058, (1, 0.45, 1.1)))
    # shoulders: bark pauldrons with spikes, collar of leaves
    for sx in (-1, 1):
        body.append(blob(0.014, (sx * 0.034, 0.0, sh), "wood_mid", 1, (1.2, 1.0, 0.8)))
        for k in range(3):
            body.append(spike((sx * (0.032 + 0.006 * k), 0.0, sh + 0.008), (sx * (0.040 + 0.010 * k), 0.0, sh + 0.024 + 0.003 * k), 0.0035, "wood_light"))
    body.append(cyl(0.030, 0.022, 0.012, 0.150, "leaf_dark", segs=8))
    # roots anchor row of rune cuts down the front (dark sockets)
    for i, z in enumerate((0.088, 0.072)):
        body.append(socket((0, -0.040, z), 0.0030, (1, 0.5, 1.6)))
    # head: carved wood mask, brow, two eye sockets, antler crown
    hz = 0.192
    head = [blob(0.0155, (0, 0, hz), "wood_light", 2, (0.88, 0.8, 1.2)),
            nb(bc.box("brow", (0.020, 0.005, 0.0032), (0, -0.0120, hz + 0.0058), "wood_dark")),
            blob(0.0075, (0, -0.0125, hz - 0.011), "wood_mid", 1, (0.9, 0.7, 1.4))]  # nose / chin ridge
    head += eyes(0, -0.0128, hz + 0.0008, 0.0063, 0.0040)
    head += [cyl(0.011, 0.014, 0.014, hz - 0.0135, "leaf_dark", segs=8)]
    head += [leaf((0, 0.006, hz + 0.014), (0, 0.012, 0.012), 0.008, "leaf_green")]
    head += antlers(hz + 0.010, 0.040, 0.050)
    ants = [p for p in head if p.name.startswith(("antler", "tine"))]
    head = [p for p in head if p not in ants]
    # arms raised, casting; wide leaf sleeves
    groups = [("", body, (0, 0, 0), ""), ("head", head, (0, 0, 0.176), ""), ("antlers", ants, (0, 0, hz + 0.010), "head")]
    hp = {}
    for name, sx in (("arm_l", 1), ("arm_r", -1)):
        shp = V((sx * 0.040, 0.0, sh))
        pts = [shp, V((sx * 0.060, -0.004, sh + 0.012)), V((sx * 0.066, -0.014, sh + 0.036)), V((sx * 0.058, -0.022, sh + 0.056))]
        P = arm_chain(pts, [0.0075, 0.0058, 0.0046, 0.0040], "wood_mid")
        for i in range(5):
            t = i / 4
            b = shp + (pts[2] - shp) * (0.15 + 0.7 * t)
            P.append(leaf(tuple(b), (sx * 0.004, -0.001, -0.022 + 0.004 * t), 0.0095, LEAF[i % 2]))
        d = V((sx * -0.2, -0.45, 0.85))
        P += hand(tuple(pts[-1] + d.normalized() * 0.005), d, 0.0070, "wood_mid")
        hp[name] = pts[-1] + d.normalized() * 0.005
        groups.append((name, P, tuple(shp), ""))
    obj = bc.assemble("ew_boss_skotos_a_v01", groups)
    bc.anchor(obj, "eye_l_anchor", (0.0063, -0.0160, hz + 0.0008), "head", 0.006)
    bc.anchor(obj, "eye_r_anchor", (-0.0063, -0.0160, hz + 0.0008), "head", 0.006)
    bc.anchor(obj, "chest_knot_anchor", (0, -0.0325, 0.145), "", 0.010)
    bc.anchor(obj, "rune_1_anchor", (0, -0.0415, 0.088), "", 0.006)
    bc.anchor(obj, "hand_l_anchor", tuple(hp["arm_l"] + V((0, -0.005, 0.0))), "arm_l", 0.012)
    bc.anchor(obj, "hand_r_anchor", tuple(hp["arm_r"] + V((0, -0.005, 0.0))), "arm_r", 0.012)
    bc.anchor(obj, "roots_anchor", (0, 0, 0.002), "", 0.040)
    return obj


# ---------------------------------------------------------------- B: stilt-legged root spirit
def variant_b():
    bz = 0.150
    body = []
    # small torso: a knotted barrel with a chest knot
    body += [blob(0.0230, (0, 0, bz), "wood_dark", 2, (0.95, 0.8, 1.15)), blob(0.016, (0, 0, bz - 0.020), "wood_mid", 1, (1, 0.9, 0.9))]
    body.append(blob(0.0085, (0, -0.0165, bz + 0.002), "wood_light", 1, (1, 0.35, 1)))
    body.append(socket((0, -0.0192, bz + 0.002), 0.0052, (1, 0.45, 1.1)))
    body.append(socket((0, -0.0185, bz - 0.014), 0.0030, (1, 0.5, 1.5)))
    # leafy mantle (separate part, becomes the phase-change cloak): a ring of big leaves over the shoulders
    mantle = []
    n = 10
    for i in range(n):
        a = math.radians(i * 360 / n)
        c, s_ = math.cos(a), math.sin(a)
        mantle.append(leaf((c * 0.016, s_ * 0.016, bz + 0.020), (c * 0.020, s_ * 0.020, -0.020), 0.013, LEAF[i % 2]))
    for i in range(7):
        a = math.radians(i * 360 / 7 + 20)
        c, s_ = math.cos(a), math.sin(a)
        mantle.append(leaf((c * 0.010, s_ * 0.010, bz + 0.024), (c * 0.014, s_ * 0.014, 0.014), 0.010, LEAF[(i + 1) % 2]))
    # head: small round bark face under a hood, horns
    hz = bz + 0.050
    head = [blob(0.0150, (0, 0, hz), "wood_light", 2, (0.9, 0.82, 1.05)),
            nb(bc.box("brow", (0.019, 0.005, 0.003), (0, -0.0118, hz + 0.0060), "wood_dark"))]
    head += eyes(0, -0.0120, hz + 0.0002, 0.0058, 0.0040)
    head += [cyl(0.013, 0.021, 0.014, hz - 0.003, "leaf_dark", y=0.006, segs=8)]  # hood back
    for i in range(6):
        a = math.radians(200 + i * 28)
        head.append(leaf((math.cos(a) * 0.012, 0.004 + math.sin(a) * 0.004, hz + 0.003), (math.cos(a) * 0.018, 0.012, 0.010 - 0.012 * (i % 2)), 0.009, LEAF[i % 2]))
    hornp = []
    for sx in (-1, 1):
        pts = [V((sx * 0.012, 0.0, hz + 0.012)), V((sx * 0.026, 0.0, hz + 0.022)), V((sx * 0.034, -0.002, hz + 0.040)), V((sx * 0.028, -0.004, hz + 0.052))]
        hornp += chain("horn", pts, [0.0045, 0.0036, 0.0026, 0.0003], "bone", 6)
    groups = [("", body, (0, 0, 0), ""), ("mantle", mantle, (0, 0, bz + 0.016), ""), ("head", head, (0, 0, bz + 0.030), ""),
              ("horns", hornp, (0, 0, hz + 0.012), "head")]
    # very long thin root legs: hip -> knee (out) -> shin -> splayed root foot
    for name, sx in (("leg_l", 1), ("leg_r", -1)):
        hip = V((sx * 0.014, 0.0, bz - 0.020))
        knee = V((sx * 0.050, -0.010, 0.075))
        foot = V((sx * 0.046, -0.004, 0.006))
        P = chain("leg", [hip, V((sx * 0.032, -0.006, 0.112)), knee, V((sx * 0.049, -0.007, 0.036)), foot],
                  [0.0075, 0.0056, 0.0046, 0.0036, 0.0030], "wood_dark", 6)
        P.append(blob(0.0068, knee, "wood_mid", 1, (1, 1, 1)))
        for k in range(3):
            a = math.radians(-80 + 70 * k)
            tip = foot + V((math.cos(a) * 0.016 * sx * 0.4 + sx * 0.008, math.sin(a) * 0.020 - 0.004, 0.0))
            tip.z = 0.0010
            P += chain("toe", [foot + V((0, 0, 0.002)), tip], [0.0032, 0.0008], "wood_mid", 5, joints=False)
        groups.append((name, P, tuple(hip), ""))
    hp = {}
    # long gnarled arms hanging nearly to the ground, big knotted hands
    for name, sx in (("arm_l", 1), ("arm_r", -1)):
        shp = V((sx * 0.024, 0.0, bz + 0.012))
        pts = [shp, V((sx * 0.050, -0.006, bz - 0.004)), V((sx * 0.066, -0.014, bz - 0.036)), V((sx * 0.068, -0.026, bz - 0.070)), V((sx * 0.060, -0.034, 0.045))]
        P = arm_chain(pts, [0.0060, 0.0050, 0.0042, 0.0038, 0.0045], "wood_dark")
        for i in range(2):
            P.append(leaf(tuple(pts[1 + i]), (sx * 0.006, 0.0, -0.016), 0.0085, LEAF[i]))
        d = V((sx * -0.1, -0.5, -0.8))
        P += hand(tuple(pts[-1]), d, 0.0075, "wood_mid", 4)
        hp[name] = pts[-1]
        groups.append((name, P, tuple(shp), ""))
    # stilt-foot roots spreading from between the legs (what bursts the ground)
    obj = bc.assemble("ew_boss_skotos_b_v01", groups)
    bc.anchor(obj, "eye_l_anchor", (0.0058, -0.0146, hz + 0.0002), "head", 0.006)
    bc.anchor(obj, "eye_r_anchor", (-0.0058, -0.0146, hz + 0.0002), "head", 0.006)
    bc.anchor(obj, "chest_knot_anchor", (0, -0.0185, bz + 0.002), "", 0.009)
    bc.anchor(obj, "hand_l_anchor", tuple(hp["arm_l"] + V((0, -0.005, 0))), "arm_l", 0.012)
    bc.anchor(obj, "hand_r_anchor", tuple(hp["arm_r"] + V((0, -0.005, 0))), "arm_r", 0.012)
    bc.anchor(obj, "roots_anchor", (0, 0, 0.002), "", 0.040)
    return obj


# ---------------------------------------------------------------- C: hulking moss treant
def variant_c():
    body = []
    # stump legs with root toes
    legs = {}
    for name, sx in (("leg_l", 1), ("leg_r", -1)):
        P = [cyl(0.026, 0.021, 0.066, 0.0, "wood_dark", x=sx * 0.033, segs=9), blob(0.020, (sx * 0.033, 0, 0.070), "wood_mid", 1)]
        for k in range(4):
            a = math.radians(-125 + k * 36)
            P += chain("toe", [V((sx * 0.033 + math.cos(a) * 0.020, math.sin(a) * 0.020, 0.016)),
                               V((sx * 0.033 + math.cos(a) * 0.036, math.sin(a) * 0.036, 0.0015))], [0.0065, 0.0012], "wood_mid", 5, joints=False)
        legs[name] = P
    # torso: huge trunk barrel with bark ridges
    body += [blob(0.052, (0, 0, 0.108), "wood_dark", 2, (1.1, 0.80, 1.0)), blob(0.040, (0, 0.002, 0.082), "wood_mid", 1, (1.1, 0.9, 0.8))]
    for i in range(9):
        a = math.radians(-100 + i * 25)
        body.append(spike((math.cos(a) * 0.050, math.sin(a) * 0.038, 0.078 + 0.002 * (i % 2)),
                          (math.cos(a) * 0.052, math.sin(a) * 0.040, 0.138 + 0.004 * (i % 3)), 0.0040, "wood_mid", 4))
    # chest knot: a great knot-hole socket ringed by bark
    body += [blob(0.0155, (0, -0.0385, 0.112), "wood_light", 1, (1, 0.35, 1.1)), socket((0, -0.0425, 0.112), 0.0095, (1, 0.45, 1.15))]
    body += [socket((-0.020, -0.0405, 0.086), 0.0040, (1, 0.5, 1.5)), socket((0.020, -0.0405, 0.090), 0.0040, (1, 0.5, 1.5))]
    # mossy shoulders: flat mounds with tufts
    for sx in (-1, 1):
        body.append(blob(0.028, (sx * 0.050, 0.0, 0.150), "leaf_green", 2, (1.15, 1.0, 0.7)))
        body.append(blob(0.020, (sx * 0.055, 0.0, 0.158), "leaf_light", 1, (1.0, 0.9, 0.6)))
        for k in range(5):
            a = math.radians(k * 72 + (30 if sx > 0 else 0))
            body.append(leaf((sx * 0.050 + math.cos(a) * 0.016, math.sin(a) * 0.016, 0.158),
                             (math.cos(a) * 0.004, math.sin(a) * 0.004, 0.018), 0.008, LEAF[(k + (sx > 0)) % 2]))
    # moss hanging from the chest and back
    for i in range(8):
        a = math.radians(-150 + i * 40)
        body.append(leaf((math.cos(a) * 0.045, math.sin(a) * 0.036, 0.150), (math.cos(a) * 0.004, math.sin(a) * 0.004, -0.026), 0.009, LEAF[i % 2]))
    body += roots(7, 0.050, 0.020, 0.074, 0.0070, phase=10)
    # bark_front: split-able chest plate with a seam (phase 3 opens it)
    bf = [nb(bc.box("bf", (0.034, 0.005, 0.036), (-0.0, -0.0395, 0.108), "wood_mid")),
          nb(bc.box("bfseam", (0.0030, 0.003, 0.036), (0, -0.0425, 0.108), "wood_dark"))]
    # stump head: sawn-off trunk with a ring top, face cut in, branches with leaf clumps
    hz = 0.178
    head = [cyl(0.026, 0.022, 0.030, hz - 0.012, "wood_light", segs=10), cyl(0.0225, 0.0225, 0.003, hz + 0.018, "wood_mid", segs=10),
            cyl(0.0105, 0.0105, 0.0015, hz + 0.0205, "wood_light", segs=10)]
    head += [nb(bc.box("brow", (0.030, 0.006, 0.004), (0, -0.0225, hz + 0.0070), "wood_dark"))]
    head += [socket((-0.0090, -0.0225, hz + 0.0000), 0.0052, (1, 0.5, 1.3)), socket((0.0090, -0.0225, hz + 0.0000), 0.0052, (1, 0.5, 1.3)),
             socket((0, -0.0225, hz - 0.0095), 0.0042, (1.6, 0.5, 0.8))]
    for sx, h in ((-1, 0.040), (1, 0.034), (0, 0.045)):
        b = V((sx * 0.012, 0.0, hz + 0.020))
        tip = b + V((sx * 0.016, 0.0, h))
        head += chain("branch", [b, b + V((sx * 0.006, 0, h * 0.5)), tip], [0.0050, 0.0036, 0.0003], "wood_dark", 6)
        head.append(blob(0.010, tuple(tip - V((0, 0, 0.004))), LEAF[abs(sx)], 1, (1, 1, 0.8)))
    groups = [("", body, (0, 0, 0), ""), ("bark_front", bf, (0, -0.040, 0.108), ""), ("head", head, (0, 0, 0.162), "")]
    groups.append(("leg_l", legs["leg_l"], (0.033, 0, 0.075), ""))
    groups.append(("leg_r", legs["leg_r"], (-0.033, 0, 0.075), ""))
    hp = {}
    # heavy arms: thick upper arm, hanging forearm, big knotted fist
    for name, sx in (("arm_l", 1), ("arm_r", -1)):
        shp = V((sx * 0.052, 0.0, 0.146))
        pts = [shp, V((sx * 0.058, -0.006, 0.120)), V((sx * 0.056, -0.020, 0.092)), V((sx * 0.051, -0.030, 0.070))]
        P = arm_chain(pts, [0.016, 0.014, 0.0125, 0.012], "wood_dark")
        fist = pts[-1] + V((0, -0.004, -0.010))
        P.append(blob(0.0175, tuple(fist), "wood_mid", 2, (1, 1, 1.0)))
        for k in range(4):
            P.append(blob(0.0062, (fist.x + (k - 1.5) * 0.0095, fist.y - 0.014, fist.z + 0.006 - 0.001 * (k % 2)), "wood_light", 1))
        P.append(socket((fist.x, fist.y - 0.0105, fist.z - 0.002), 0.0058, (1, 0.5, 1)))
        for k in range(3):
            P.append(spike((fist.x + (k - 1) * 0.011, fist.y - 0.002, fist.z - 0.014), (fist.x + (k - 1) * 0.013, fist.y - 0.004, fist.z - 0.030), 0.0042, "wood_light", 4))
        hp[name] = fist
        groups.append((name, P, tuple(shp), ""))
    obj = bc.assemble("ew_boss_skotos_c_v01", groups)
    bc.anchor(obj, "eye_l_anchor", (0.0090, -0.0255, hz), "head", 0.007)
    bc.anchor(obj, "eye_r_anchor", (-0.0090, -0.0255, hz), "head", 0.007)
    bc.anchor(obj, "chest_knot_anchor", (0, -0.0445, 0.112), "", 0.012)
    bc.anchor(obj, "hand_l_anchor", tuple(hp["arm_l"] + V((0, -0.012, 0))), "arm_l", 0.014)
    bc.anchor(obj, "hand_r_anchor", tuple(hp["arm_r"] + V((0, -0.012, 0))), "arm_r", 0.014)
    bc.anchor(obj, "roots_anchor", (0, 0, 0.002), "", 0.040)
    return obj


# ---------------------------------------------------------------- D: hooded bark wraith
def variant_d():
    body = []
    # cloak: tall narrow cone core, ringed by hanging root curtains and bark shoulder plates
    body += [cyl(0.045, 0.030, 0.070, 0.0, "wood_dark", segs=10), cyl(0.030, 0.020, 0.080, 0.068, "wood_dark", segs=10)]
    for i in range(10):
        a = math.radians(i * 360 / 10)
        c, s_ = math.cos(a), math.sin(a)
        top = V((c * 0.026, s_ * 0.026, 0.150))
        mid = V((c * 0.040, s_ * 0.040, 0.085 + 0.006 * (i % 3)))
        low = V((c * 0.052 + s_ * 0.004, s_ * 0.052 - c * 0.004, 0.022))
        end = V((c * 0.062, s_ * 0.062, 0.002))
        body += chain("hang", [top, mid, low, end], [0.0085, 0.0075, 0.0058, 0.0010], BARK[i % 2], 5)
    # layered bark plates down the front of the cloak
    for i, (z, w) in enumerate(((0.130, 0.020), (0.105, 0.026), (0.080, 0.030), (0.055, 0.034))):
        body.append(nb(bc.box("plate", (w, 0.004, 0.020), (0, -(0.0245 + 0.0035 * (0.15 - z) / 0.03), z), BARK[i % 2])))
    body += [socket((0, -0.0300, 0.116), 0.0042, (1, 0.45, 1.2))]  # chest knot
    body += [socket((0, -0.040, 0.075), 0.0030, (1, 0.5, 1.6))]  # rune
    # shoulders: bark pauldron plates stepped like a beetle shell
    for sx in (-1, 1):
        for k in range(3):
            body.append(blob(0.013 - 0.002 * k, (sx * (0.027 + 0.004 * k), 0.0 + 0.002 * k, 0.152 - 0.005 * k), BARK[k % 2], 1, (1.3, 1.0, 0.6)))
    for i in range(9):
        a = math.radians(i * 40)
        body.append(leaf((math.cos(a) * 0.020, math.sin(a) * 0.020, 0.166), (math.cos(a) * 0.016, math.sin(a) * 0.016, -0.014), 0.012, LEAF[i % 2]))
    # trailing smoke-like tendrils snaking along the ground (roots_anchor sits among them)
    for i in range(9):
        a = math.radians(i * 40 + 12)
        c, s_ = math.cos(a), math.sin(a)
        R0, R1 = 0.045, 0.072
        pts = [V((c * R0, s_ * R0, 0.012)), V((c * (R0 + 0.010) + s_ * 0.008, s_ * (R0 + 0.010) - c * 0.008, 0.006)),
               V((c * (R1 - 0.008) - s_ * 0.008, s_ * (R1 - 0.008) + c * 0.008, 0.006)), V((c * R1, s_ * R1, 0.0030))]
        body += chain("tendril", pts, [0.0080, 0.0060, 0.0040, 0.0008], "leaf_dark" if i % 2 else "wood_dark", 5)
    # hood: bark plates ring around a dark hollow with ember eyes deep inside
    hz = 0.204
    body.append(cyl(0.020, 0.014, 0.040, 0.150, "wood_dark", segs=8))
    head = [blob(0.0150, (0, 0.004, hz), "ink", 2, (1.0, 0.9, 1.15))]
    for i in range(9):  # plates on the back and sides, leaving the front open
        ang = -25 + i * 28
        h = 0.030 + 0.004 * (i % 2)
        head.append(bark_plate("hoodp", ang, 0.0185, hz + 0.001, 0.0125, h, 0.0030, BARK[i % 2], lean=-6))
    for sx in (-1, 1):  # front rim plates framing the opening
        head.append(bark_plate("rim", -90 + sx * 52, 0.0175, hz + 0.003, 0.0105, 0.036, 0.0030, "wood_light", lean=0))
    head.append(nb(bc.box("peak", (0.026, 0.006, 0.0035), (0, -0.0170, hz + 0.0190), "wood_mid")))
    head.append(spike((0, 0.002, hz + 0.020), (0, 0.016, hz + 0.044), 0.0085, "wood_dark", 6))  # drooping hood tip
    head += [socket((-0.0058, -0.0135, hz + 0.0020), 0.0048), socket((0.0058, -0.0135, hz + 0.0020), 0.0048), blob(0.0120, (0, -0.0100, hz - 0.0010), "wood_dark", 1, (1.0, 0.5, 1.2))]  # eye sockets, set deep
    head += [leaf((0.014, -0.012, hz + 0.014), (0.010, -0.002, 0.014), 0.007, "leaf_green"), leaf((-0.014, -0.012, hz + 0.014), (-0.010, -0.002, 0.014), 0.007, "leaf_dark")]
    cloak = []
    for i in range(8):  # mantle: stringy root fringe over the shoulders (phase part)
        a = math.radians(i * 45 + 8)
        c, s_ = math.cos(a), math.sin(a)
        cloak += chain("fringe", [V((c * 0.020, s_ * 0.020, 0.160)), V((c * 0.034, s_ * 0.034, 0.150)), V((c * 0.040, s_ * 0.040, 0.136))],
                       [0.0042, 0.0034, 0.0005], LEAF[i % 2], 5, joints=False)
    groups = [("", body, (0, 0, 0), ""), ("mantle", cloak, (0, 0, 0.150), ""), ("head", head, (0, 0, 0.188), "")]
    hp = {}
    for name, sx in (("arm_l", 1), ("arm_r", -1)):
        shp = V((sx * 0.032, 0.0, 0.146))
        pts = [shp, V((sx * 0.046, -0.010, 0.130)), V((sx * 0.050, -0.026, 0.118)), V((sx * 0.046, -0.044, 0.112))]
        P = arm_chain(pts, [0.0080, 0.0068, 0.0058, 0.0050], "wood_dark")
        P.append(leaf(tuple(pts[0] + V((sx * 0.004, 0, 0))), (sx * 0.010, -0.002, -0.034), 0.014, "leaf_dark"))  # sleeve rag
        d = V((sx * -0.1, -1, -0.15))
        P += hand(tuple(pts[-1] + d.normalized() * 0.004), d, 0.0085, "wood_mid", 4)
        hp[name] = pts[-1] + d.normalized() * 0.004
        groups.append((name, P, tuple(shp), ""))
    obj = bc.assemble("ew_boss_skotos_d_v01", groups)
    bc.anchor(obj, "eye_l_anchor", (0.0058, -0.0150, hz + 0.0020), "head", 0.006)
    bc.anchor(obj, "eye_r_anchor", (-0.0058, -0.0150, hz + 0.0020), "head", 0.006)
    bc.anchor(obj, "chest_knot_anchor", (0, -0.0325, 0.116), "", 0.008)
    bc.anchor(obj, "rune_1_anchor", (0, -0.0415, 0.075), "", 0.006)
    bc.anchor(obj, "hand_l_anchor", tuple(hp["arm_l"] + V((0, -0.005, 0))), "arm_l", 0.012)
    bc.anchor(obj, "hand_r_anchor", tuple(hp["arm_r"] + V((0, -0.005, 0))), "arm_r", 0.012)
    bc.anchor(obj, "roots_anchor", (0, 0, 0.002), "", 0.045)
    return obj



# ================================================================ ROUND 2 (E-H): boss rules lifted (size, footprint, budget, colour) -- Siddharth 2026-11-17
# Built in CELLS (1 cell = 0.05 m) through the K wrappers below. Dark bark / near-black body so a glow pops; the glow (assumed Warden
# PURPLE with ember-red sparks, sickly green is the alternative) is NOT geometry: sockets sit in pale carved rims, anchors carry the VFX.
K = 0.05
DARK = ("wood_dark", "stone_dark")
MOSS = ("leaf_dark", "leaf_green")


def pv(t):
    return tuple(c * K for c in t)


def B(r, loc, col, sub=1, sq=(1, 1, 1)):
    return blob(r * K, pv(loc), col, sub, sq)


def C(r0, r1, h, z0, col, x=0.0, y=0.0, segs=8):
    return cyl(r0 * K, r1 * K, h * K, z0 * K, col, x * K, y * K, segs)


def S(p0, p1, r0, r1, col, segs=5):
    return seg("s", pv(p0), pv(p1), r0 * K, max(r1, 0.05) * K, col, segs)


def CH(pts, rad, col, segs=6, joints=True):
    return chain("ch", [V(pv(p)) for p in pts], [max(r, 0.05) * K for r in rad], col, segs, joints=joints)


def LF(base, d, W, col):
    return leaf(pv(base), pv(d), W * K, col)


def BX(size, loc, col):
    return nb(bc.box("bx", tuple(v * K for v in size), pv(loc), col))


def BP(ang, rad, z, w, h, d, col, lean=0.0, dy=0.0):
    o = bark_plate("bp", ang, rad * K, z * K, w * K, h * K, d * K, col, lean)
    if dy:
        o.location.y += dy * K
        bc.apply_transforms(o)
    return o


def EYE(x, y, z, r):
    """Pale carved rim + ink socket: reads at table scale; the glow anchor sits at the socket."""
    return [B(r * 1.5, (x, y, z), "wood_light", 1, (1.0, 0.45, 0.85)), B(r, (x, y - r * 0.55, z), "ink", 1, (1.0, 0.5, 1.0))]


def LIMB(pts, rad, col):
    P = CH(pts, rad, col, 7)
    for i in range(1, len(pts) - 1):
        P.append(B(rad[i] * 1.3, pts[i], DARK[i % 2], 1, (1, 1, 0.85)))
    return P


def FIST(pos, r, col="wood_mid"):
    x, y, z = pos
    P = [B(r, pos, col, 2)]
    for k in range(4):
        P.append(B(r * 0.42, (x + (k - 1.5) * r * 0.55, y - r * 0.82, z + r * 0.35), "wood_light", 1))
    for k in range(3):
        P.append(S((x + (k - 1) * r * 0.55, y - r * 0.1, z - r * 0.7), (x + (k - 1) * r * 0.7, y - r * 0.3, max(z - r * 1.9, 0.5)), r * 0.26, 0.05, "wood_light", 4))
    P += [B(r * 0.62, (x, y - r * 0.78, z - r * 0.1), "wood_light", 1, (1, 0.4, 0.9)), B(r * 0.42, (x, y - r * 0.98, z - r * 0.1), "ink", 1, (1, 0.5, 1))]
    return P


def ROOTS(n, r0, z0, reach, rr, phase=0.0, col=DARK):
    P = []
    for i in range(n):
        a = math.radians(i * 360 / n + phase)
        c, s_ = math.cos(a), math.sin(a)
        wob = 0.5 * math.sin(i * 2.3)
        mid = r0 + (reach - r0) * 0.5
        P += CH([(c * r0, s_ * r0, z0), (c * mid - s_ * wob, s_ * mid + c * wob, z0 * 0.5), (c * reach, s_ * reach, 0.5)], [rr, rr * 0.7, 0.15], col[i % 2], 6)
    return P


def HOOD(hz, R, h, n, dy=0.0):
    """Hood of chunky bark plates round the back and sides (front -Y stays open), dark hollow inside, framing rim plates."""
    P = [B(R * 0.80, (0, R * 0.12 + dy, hz), "ink", 2, (1.0, 0.95, 1.2))]
    for i in range(n):
        ang = -35 + i * (250.0 / (n - 1))
        P.append(BP(ang, R, hz, R * 0.72, h * (1 + 0.06 * (i % 2)), R * 0.20, DARK[i % 2], -5, dy))
    for sx in (-1, 1):
        P.append(BP(-90 + sx * 50, R * 0.95, hz + 0.2, R * 0.55, h * 1.03, R * 0.20, "wood_mid", 0, dy))
    P.append(BX((R * 1.5, R * 0.45, R * 0.22), (0, -R * 0.98 + dy, hz + h * 0.52), "wood_mid"))
    return P


def CROWN(z0, span, h, n, thick, col="wood_mid", thorns=False, y0=0.0):
    """Branching antler crown wider than the shoulders."""
    P = []
    for i in range(n):
        t = (i + 0.5) / n * 2 - 1
        x1 = span * t
        pts = [(t * 1.5, y0, z0), (x1 * 0.55, y0 - 0.4, z0 + h * 0.45), (x1 * 0.95, y0, z0 + h * 0.8), (x1 * 0.85 + t * 1.2, y0 + 0.2, z0 + h)]
        P += CH(pts, [thick, thick * 0.8, thick * 0.55, 0.2], col, 5)
        for a, b in ((1, 0.55), (2, 0.45)):
            base = V(pts[a])
            for sgn in (-1, 1):
                tip = base + V((sgn * 1.6 + t * 1.0, -0.8 * sgn, h * 0.28 * b + 1.5))
                P += CH([tuple(base), tuple(tip)], [thick * 0.55, 0.15], col, 4, joints=False)
        if thorns:
            for a in range(1, 3):
                b0 = V(pts[a])
                P.append(S(tuple(b0), tuple(b0 + V((0, -1.8, 0.9))), thick * 0.45, 0.05, "bone", 4))
    return P


def CLOAK(n, rt, rb, thick, ztop, jag=2.0):
    """Root curtain: thick hanging roots from the shoulders to the ground at the back and sides (front stays open)."""
    P = []
    for i in range(n):
        a = math.radians(50 + (i + 0.5) * 260.0 / n)
        c, s_ = math.cos(a), math.sin(a)
        zb = (jag if i % 2 else 0) + 0.3
        P += CH([(c * rt, s_ * rt, ztop), (c * (rt + rb) * 0.5, s_ * (rt + rb) * 0.5, (ztop + zb) * 0.55), (c * rb, s_ * rb, max(zb, 0.4))],
                [thick, thick * 0.85, 0.3], DARK[i % 2], 5)
    return P


def TENDRILS(n, r0, r1, rr, z0=1.2, arc=360.0, start=0.0, cols=("wood_dark", "leaf_dark")):
    P = []
    for i in range(n):
        a = math.radians(start + (i + 0.5) * arc / n)
        c, s_ = math.cos(a), math.sin(a)
        d = r1 - r0
        pts = [(c * r0, s_ * r0, z0), (c * (r0 + d * 0.35) + s_ * 0.9, s_ * (r0 + d * 0.35) - c * 0.9, 0.9),
               (c * (r0 + d * 0.7) - s_ * 0.9, s_ * (r0 + d * 0.7) + c * 0.9, 0.6), (c * r1, s_ * r1, 0.35)]
        P += CH(pts, [rr, rr * 0.75, rr * 0.5, 0.15], cols[i % 2], 5)
    return P


def anchors(obj, hz, head_y, eye_dx, chest, hands, rootr=3.0):
    bc.anchor(obj, "eye_l_anchor", pv((eye_dx, head_y, hz)), "head", 0.9 * K)
    bc.anchor(obj, "eye_r_anchor", pv((-eye_dx, head_y, hz)), "head", 0.9 * K)
    bc.anchor(obj, "chest_knot_anchor", pv(chest), "", 1.5 * K)
    bc.anchor(obj, "hand_l_anchor", pv(hands[0]), "arm_l", 1.8 * K)
    bc.anchor(obj, "hand_r_anchor", pv(hands[1]), "arm_r", 1.8 * K)
    bc.anchor(obj, "roots_anchor", pv((0, 0, 0.2)), "", rootr * K)


def stump_leg(x, y, h, r):
    P = [C(r, r * 0.8, h, 0.0, "wood_dark", x, y, 9), B(r * 0.85, (x, y, h), "wood_mid", 1)]
    for k in range(4):
        a = math.radians(-135 + k * 30)
        P += CH([(x + math.cos(a) * r * 0.8, y + math.sin(a) * r * 0.8, r * 0.7), (x + math.cos(a) * r * 1.9, y + math.sin(a) * r * 1.9, 0.4)],
                [r * 0.30, 0.15], "wood_mid", 5, joints=False)
    return P


def arm_pair(groups, hp, spec):
    for nm, sx in (("arm_l", 1), ("arm_r", -1)):
        sh, pts, rad, fist, fr, hand = spec(sx, nm)
        groups.append((nm, LIMB(pts, rad, "wood_dark") + FIST(fist, fr), pv(sh), ""))
        hp[nm] = hand


# ---------------------------------------------------------------- E: towering hooded treant
def variant_e():
    global K
    K = 0.036
    body = [C(7.0, 5.0, 1.6, 0.0, "wood_dark", segs=10)] + ROOTS(7, 4.5, 2.0, 9.0, 1.2, 10)
    body += [B(4.6, (0, 0.5, 7.4), "wood_dark", 2, (1.12, 0.82, 1.15)), B(3.6, (0, 0.5, 4.8), "stone_dark", 1, (1.1, 0.9, 0.9))]
    for i in range(5):
        a = math.radians(-100 + i * 50)
        body.append(S((math.cos(a) * 4.6, math.sin(a) * 3.4 + 0.5, 6.2), (math.cos(a) * 5.0, math.sin(a) * 3.6 + 0.5, 10.0 + (i % 3) * 0.8), 0.55, 0.05, "stone_dark", 4))
    body += [B(1.5, (0, -3.0, 7.6), "wood_light", 1, (1, 0.35, 1.1)), B(1.0, (0, -3.35, 7.6), "ink", 1, (1, 0.5, 1.15))]
    bf = [BX((5.0, 0.7, 5.0), (0, -3.55, 7.4), "wood_mid"), BX((0.35, 0.5, 5.0), (0, -3.95, 7.4), "ink")]
    for sx in (-1, 1):  # dead-branch pauldrons
        body.append(B(2.3, (sx * 4.9, 0.3, 10.2), "wood_dark", 1, (1.3, 1.0, 0.75)))
        for k in range(3):
            body.append(S((sx * (4.4 + k * 0.8), 0.3, 10.8), (sx * (6.2 + k * 1.2), 0.3, 13.0 + k * 0.8), 0.55, 0.05, "wood_light", 4))
    hz = 11.4
    head = HOOD(hz, 3.6, 5.8, 9) + EYE(1.4, -2.4, hz + 0.2, 0.85) + EYE(-1.4, -2.4, hz + 0.2, 0.85)
    crown = CROWN(hz + 3.4, 10.5, 5.5, 4, 0.8, "wood_dark")
    cloak = CLOAK(9, 3.2, 6.6, 1.1, 10.0)
    groups = [("", body, (0, 0, 0), ""), ("bark_front", bf, pv((0, -3.5, 7.4)), ""), ("head", head, pv((0, 0, 9.8)), ""),
              ("crown", crown, pv((0, 0, hz + 3.4)), "head"), ("cloak", cloak, pv((0, 1.0, 10.0)), ""),
              ("leg_l", stump_leg(2.6, 0, 3.4, 2.0), pv((2.6, 0, 3.6)), ""), ("leg_r", stump_leg(-2.6, 0, 3.4, 2.0), pv((-2.6, 0, 3.6)), "")]
    hp = {}
    arm_pair(groups, hp, lambda sx, nm: ((sx * 4.6, 0.3, 9.6), [(sx * 4.6, 0.3, 9.6), (sx * 6.6, -0.4, 8.0), (sx * 7.0, -1.6, 5.8), (sx * 6.2, -2.4, 4.2)],
                                         [1.9, 1.7, 1.55, 1.5], (sx * 6.0, -2.6, 2.6), 2.1, (sx * 6.0, -4.0, 2.6)))
    obj = bc.assemble("ew_boss_skotos_e_v01", groups)
    anchors(obj, hz, -2.95, 1.4, (0, -3.7, 7.6), (hp["arm_l"], hp["arm_r"]), 5.0)
    bc.anchor(obj, "crown_anchor", pv((0, 0, hz + 6.0)), "head", 2.0 * K)
    return obj


# ---------------------------------------------------------------- F: hunched colossus on one fist
def variant_f():
    global K
    K = 0.046
    body = [B(4.2, (0, 2.0, 4.6), "wood_dark", 2, (1.2, 1.0, 0.9)), B(4.8, (0, -0.2, 7.4), "wood_dark", 2, (1.2, 0.95, 1.0)),
            B(4.0, (0, 3.2, 8.4), "stone_dark", 2, (1.2, 1.0, 0.8))]
    for i in range(6):  # dead branches jutting from the hump
        x = -3.6 + i * 1.45
        body.append(S((x, 3.2, 9.5), (x * 1.5, 5.0 + (i % 2), 13.0 + (i % 3) * 1.2), 0.65, 0.05, "wood_light", 4))
        body.append(S((x * 1.2, 4.2, 11.0), (x * 1.9, 3.0, 12.6 + (i % 2)), 0.35, 0.05, "wood_light", 4))
    # split-open chest: dark rift between two plates
    body += [B(2.4, (0, -4.0, 7.2), "ink", 1, (1.0, 0.35, 1.6)), B(1.7, (0, -3.7, 7.2), "wood_light", 1, (1, 0.3, 1.5)), B(1.2, (0, -4.15, 7.2), "ink", 1, (0.9, 0.5, 1.5))]
    for sx in (-1, 1):  # moss shoulders with dead branches (no mushroom blobs)
        body.append(B(2.8, (sx * 5.2, -0.6, 10.2), "leaf_dark", 2, (1.3, 1.1, 0.65)))
        body.append(B(2.0, (sx * 5.4, -0.8, 10.8), "leaf_green", 1, (1.2, 1.0, 0.5)))
        body.append(S((sx * 5.0, -0.6, 11.2), (sx * 7.6, 0.6, 14.4), 0.55, 0.05, "wood_light", 4))
        body.append(S((sx * 5.8, -0.6, 11.0), (sx * 8.0, -1.8, 13.4), 0.4, 0.05, "wood_light", 4))
    for i in range(6):
        body.append(LF((-4.5 + i * 1.8, 0.6, 10.6), (0.4, -0.2, -3.0), 1.3, MOSS[i % 2]))
    body += ROOTS(5, 4.5, 2.4, 8.5, 1.1, 20)
    body += TENDRILS(6, 4.0, 11.0, 0.8, 1.6, 120, 50)  # dragging behind (+Y)
    bfl = [BX((2.4, 0.7, 5.0), (-1.6, -3.7, 7.2), "wood_mid")]
    bfr = [BX((2.4, 0.7, 5.0), (1.6, -3.7, 7.2), "wood_mid")]
    hz, hy = 9.2, -3.4
    head = HOOD(hz, 3.5, 5.2, 8, hy) + EYE(1.35, hy - 2.1, hz + 0.2, 0.8) + EYE(-1.35, hy - 2.1, hz + 0.2, 0.8)
    groups = [("", body, (0, 0, 0), ""), ("bark_front_l", bfl, pv((-3.0, -3.7, 7.2)), ""), ("bark_front_r", bfr, pv((3.0, -3.7, 7.2)), ""),
              ("head", head, pv((0, -2.0, 8.0)), ""),
              ("leg_l", stump_leg(3.0, 3.2, 3.2, 2.2), pv((3.0, 3.2, 3.4)), ""), ("leg_r", stump_leg(-3.0, 3.2, 3.2, 2.2), pv((-3.0, 3.2, 3.4)), "")]
    hp = {}
    # left arm planted on the ground (the gorilla fist), right arm hanging low
    sh = (5.0, -0.8, 9.2)
    groups.append(("arm_l", LIMB([sh, (7.4, -3.0, 6.6), (7.2, -6.0, 3.6), (6.6, -7.6, 2.4)], [2.4, 2.2, 2.0, 1.9], "wood_dark") + FIST((6.6, -8.0, 3.4), 2.9), pv(sh), ""))
    hp["arm_l"] = (6.6, -10.0, 3.2)
    sh = (-5.0, -0.8, 9.2)
    groups.append(("arm_r", LIMB([sh, (-7.6, -2.0, 7.0), (-8.0, -4.0, 4.6), (-7.2, -5.0, 3.0)], [2.2, 2.0, 1.85, 1.7], "wood_dark") + FIST((-7.0, -5.4, 2.7), 2.4), pv(sh), ""))
    hp["arm_r"] = (-7.0, -7.2, 2.7)
    obj = bc.assemble("ew_boss_skotos_f_v01", groups)
    anchors(obj, hz, hy - 2.7, 1.35, (0, -4.4, 7.2), (hp["arm_l"], hp["arm_r"]), 5.0)
    return obj


# ---------------------------------------------------------------- G: wraith-king
def variant_g():
    global K
    K = 0.04
    body = [C(9.0, 6.0, 3.0, 0.0, "wood_dark", segs=12), C(6.0, 3.6, 5.0, 3.0, "stone_dark", segs=12), C(3.6, 2.8, 3.0, 8.0, "wood_dark", segs=12)]
    for i in range(10):  # throne skirt: ring of arching roots round the hem
        a = math.radians(i * 36 + 8)
        c, s_ = math.cos(a), math.sin(a)
        body += CH([(c * 6.0, s_ * 6.0, 3.0), (c * 9.5, s_ * 9.5, 4.2), (c * 12.0, s_ * 12.0, 0.4)], [1.3, 1.1, 0.25], DARK[i % 2], 6)
    for i in range(9):  # bark plates down the front and sides of the skirt
        body.append(BP(-90 + (i - 4) * 28, 5.5 - 0.6 * (i % 2), 5.0, 3.4, 6.6 + (i % 2) * 1.2, 0.7, DARK[i % 2] if i % 3 else "wood_mid", 0))
    body += [B(1.4, (0, -3.2, 8.8), "wood_light", 1, (1, 0.35, 1.1)), B(0.95, (0, -3.5, 8.8), "ink", 1, (1, 0.5, 1.15))]
    bf = [BX((4.0, 0.8, 4.0), (0, -3.55, 6.0), "wood_mid"), BX((0.3, 0.5, 4.0), (0, -4.0, 6.0), "ink")]
    for sx in (-1, 1):
        body.append(B(2.6, (sx * 3.8, 0.0, 11.0), "wood_dark", 1, (1.2, 1.0, 0.8)))
    body += TENDRILS(8, 8.5, 14.0, 0.9, 1.0, 360, 0)
    cloak = CLOAK(10, 3.4, 8.4, 0.9, 11.2, 3.0)
    hz = 14.0
    head = HOOD(hz, 3.9, 6.2, 9)
    # carved bark mask inside the hood (pale rims round the sockets)
    head += [B(2.8, (0, -0.4, hz), "wood_light", 2, (0.9, 0.7, 1.2)), BX((4.4, 0.9, 0.7), (0, -2.3, hz + 1.3), "wood_dark"), B(1.1, (0, -2.4, hz - 0.6), "wood_mid", 1, (0.7, 0.7, 1.3))]
    head += [B(1.8, (1.3, -2.2, hz + 0.2), "bone", 1, (1.0, 0.4, 0.85)), B(1.8, (-1.3, -2.2, hz + 0.2), "bone", 1, (1.0, 0.4, 0.85)),
             B(1.15, (1.3, -2.8, hz + 0.2), "ink", 1, (1.0, 0.5, 1.1)), B(1.15, (-1.3, -2.8, hz + 0.2), "ink", 1, (1.0, 0.5, 1.1)),
             B(1.0, (0, -2.5, hz - 2.0), "ink", 1, (1.8, 0.5, 0.45))]
    crown = CROWN(hz + 3.8, 8.0, 6.5, 5, 0.75, thorns=True, col="wood_light")
    groups = [("", body, (0, 0, 0), ""), ("bark_front", bf, pv((0, -3.5, 6.0)), ""), ("cloak", cloak, pv((0, 1.0, 11.2)), ""),
              ("head", head, pv((0, 0, 12.0)), ""), ("crown", crown, pv((0, 0, hz + 3.8)), "head")]
    hp = {}
    arm_pair(groups, hp, lambda sx, nm: ((sx * 4.2, 0.0, 11.0), [(sx * 4.2, 0.0, 11.0), (sx * 6.4, -1.4, 9.8), (sx * 6.6, -3.6, 8.6), (sx * 5.6, -5.4, 8.0)],
                                         [2.0, 1.8, 1.7, 1.6], (sx * 5.4, -6.2, 7.6), 2.2, (sx * 5.4, -8.2, 7.6)))
    obj = bc.assemble("ew_boss_skotos_g_v01", groups)
    anchors(obj, hz + 0.2, -3.3, 1.3, (0, -3.7, 8.8), (hp["arm_l"], hp["arm_r"]), 6.0)
    return obj


# ---------------------------------------------------------------- H: ancient walking tree
def variant_h():
    global K
    K = 0.04
    body = [C(9.0, 6.0, 2.0, 0.0, "wood_dark", segs=12), C(6.0, 5.0, 4.0, 2.0, "wood_dark", segs=12), C(5.6, 4.8, 6.0, 6.0, "wood_dark", segs=12),
            C(4.8, 4.0, 5.0, 11.0, "stone_dark", segs=12), C(4.0, 3.2, 3.0, 15.8, "wood_dark", segs=12)]
    for i in range(7):  # bark ridges up the trunk
        a = math.radians(i * 51 + 5)
        r = 5.6 - 0.4 * (i % 2)
        body.append(S((math.cos(a) * r, math.sin(a) * r, 5.5), (math.cos(a) * (r - 0.6), math.sin(a) * (r - 0.6), 17.0 + (i % 3)), 0.55, 0.05, "stone_dark", 4))
    body += ROOTS(5, 5.0, 3.0, 11.0, 1.5, 12)
    body += [B(1.5, (0, -5.0, 9.0), "wood_light", 1, (1, 0.35, 1.1)), B(1.0, (0, -5.35, 9.0), "ink", 1, (1, 0.5, 1.15))]
    cloak = CLOAK(9, 4.6, 6.4, 1.0, 17.0, 3.5)
    fz = 14.0  # the carved face boss on the trunk
    head = [B(3.8, (0, -3.2, fz), "stone_dark", 2, (1.0, 0.6, 1.15)), BX((7.0, 1.0, 1.0), (0, -5.4, fz + 2.2), "wood_dark"), B(0.9, (0, -5.3, fz - 0.4), "wood_mid", 1, (0.8, 0.8, 1.4))]
    head += EYE(2.2, -5.0, fz + 0.8, 1.15) + EYE(-2.2, -5.0, fz + 0.8, 1.15)
    head += [B(1.7, (0, -4.7, fz - 2.2), "wood_light", 1, (2.0, 0.35, 0.8)), B(1.2, (0, -5.0, fz - 2.2), "ink", 1, (2.0, 0.5, 0.55))]
    crown = CROWN(18.0, 12.0, 8.0, 6, 1.0, "wood_dark") + CROWN(18.0, 8.0, 6.0, 3, 0.8, "wood_mid", y0=1.0)
    for i in range(6):
        crown.append(LF((-9 + i * 3.6, 0, 22 + (i % 2)), (0.5, 0, -2.5), 1.4, MOSS[i % 2]))
    bf = [BX((4.4, 0.8, 4.4), (0, -5.0, 9.0), "wood_mid"), BX((0.3, 0.5, 4.4), (0, -5.5, 9.0), "ink")]
    groups = [("", body, (0, 0, 0), ""), ("bark_front", bf, pv((0, -5.0, 9.0)), ""), ("cloak", cloak, pv((0, 1.0, 17.0)), ""),
              ("head", head, pv((0, -3.0, fz)), ""), ("crown", crown, pv((0, 0, 18.0)), ""),
              ("leg_l", stump_leg(3.4, -0.5, 4.2, 2.6), pv((3.4, -0.5, 4.4)), ""), ("leg_r", stump_leg(-3.4, -0.5, 4.2, 2.6), pv((-3.4, -0.5, 4.4)), "")]
    hp = {}
    arm_pair(groups, hp, lambda sx, nm: ((sx * 5.0, 0.0, 15.0), [(sx * 5.0, 0.0, 15.0), (sx * 8.4, -1.2, 14.0), (sx * 9.6, -2.6, 10.6), (sx * 8.6, -3.8, 7.4)],
                                         [2.4, 2.1, 1.9, 1.8], (sx * 8.2, -4.4, 5.4), 2.5, (sx * 8.2, -6.4, 5.4)))
    obj = bc.assemble("ew_boss_skotos_h_v01", groups)
    anchors(obj, fz + 0.8, -5.75, 2.2, (0, -5.5, 9.0), (hp["arm_l"], hp["arm_r"]), 6.0)
    return obj


# ================================================================ ROUND 3 (I-L): the wraith-king (G) developed. Siddharth 2026-11-17: "No spikiness"; G is the base.
# NO spikes anywhere: rounded roots, soft branch curves, rounded knuckles, smooth bark plates (squashed ellipsoids). Near-black body,
# pale carved mask (big) and crown as the only light accents. Glow assumed Warden PURPLE (+ ember red); it is NOT geometry: sockets + anchors.
# K = metres per design unit, per variant (1 unit = 0.0225 m -> ~24 units = ~11 cells).
RB = ("ink", "stone_dark")
RB2 = ("warden_dark", "wood_dark")


def rCH(pts, rad, col, segs=8):
    """Soft rounded limb/branch: bendy tube with a ball end (no points)."""
    return chain("rch", [V(pv(p)) for p in pts], [r * K for r in rad], col, segs, ball_tip=(rad[-1] * K, col))


def rPL(ang, rad, z, w, h, d, col, dy=0.0, lean=0.0):
    """Smooth bark plate: a squashed ellipsoid standing on a ring, facing the centre axis."""
    o = bc.blob("pl", 1.0, (0, 0, 0), col, 2, (w / 2 * K, d / 2 * K, h / 2 * K))
    nb(o)
    bc.rotate(o, (lean, 0, ang + 90))
    a = math.radians(ang)
    o.location = (math.cos(a) * rad * K, math.sin(a) * rad * K + dy * K, z * K)
    bc.apply_transforms(o)
    return o


def rMASK(cx, y, z, w, h):
    """Big pale carved mask: bone plate, heavy rounded dark brow, two very large deep ink sockets, nose and mouth. Returns parts + socket pos."""
    yf = y - w * 0.175
    P = [B(w * 0.5, (cx, y, z), "bone", 2, (1.0, 0.35, h / w)),
         B(w * 0.5, (cx, yf - w * 0.03, z + h * 0.31), "wood_dark", 2, (1.0, 0.24, 0.22)),
         B(w * 0.23, (cx - w * 0.24, yf - w * 0.02, z + h * 0.05), "ink", 2, (1.0, 0.55, 1.25)),
         B(w * 0.23, (cx + w * 0.24, yf - w * 0.02, z + h * 0.05), "ink", 2, (1.0, 0.55, 1.25)),
         B(w * 0.10, (cx, yf - w * 0.03, z - h * 0.12), "wood_light", 1, (0.8, 0.8, 1.6)),
         B(w * 0.22, (cx, yf, z - h * 0.33), "ink", 1, (1.5, 0.45, 0.4))]
    return P, w * 0.24, yf - w * 0.12, z + h * 0.05


def rLIMB(pts, rad, col="ink"):
    P = chain("rl", [V(pv(p)) for p in pts], [r * K for r in rad], col, 8, joints=True)
    for i in range(1, len(pts) - 1):
        P.append(B(rad[i] * 1.2, pts[i], RB[i % 2], 2, (1, 1, 0.9)))
    return P


def rFIST(pos, r):
    """Rounded knotted fist: no claws. Dark mass, mid-wood rounded knuckles, ink palm socket in a mid-wood rim."""
    x, y, z = pos
    P = [B(r, pos, "stone_dark", 2)]
    for k in range(3):
        P.append(B(r * 0.50, (x + (k - 1) * r * 0.68, y - r * 0.80, z + r * 0.32), "wood_dark", 2))
    P += [B(r * 0.60, (x, y - r * 0.78, z - r * 0.15), "wood_mid", 1, (1, 0.4, 0.9)), B(r * 0.40, (x, y - r * 0.98, z - r * 0.15), "ink", 1, (1, 0.5, 1))]
    return P


def rROOTS(n, r0, z0, reach, rr, phase=0.0, rise=0.0):
    """Broad rounded buttress roots (round ends, no tips)."""
    P = []
    for i in range(n):
        a = math.radians(i * 360 / n + phase)
        c, s_ = math.cos(a), math.sin(a)
        mid = r0 + (reach - r0) * 0.5
        P += rCH([(c * r0, s_ * r0, z0), (c * mid, s_ * mid, max(z0 * 0.7, rr * 1.05) + rise), (c * reach, s_ * reach, rr * 0.95)], [rr, rr * 0.9, rr * 0.8], RB[i % 2], 12)
    return P


def rHOOD(hz, R, h, n, dy=0.0, dome=False, rim=1.02):
    P = [B(R * 0.85, (0, R * 0.10 + dy, hz), "ink", 2, (1.0, 0.95, 1.2))]
    for i in range(n):
        ang = -30 + i * (240.0 / (n - 1))
        P.append(rPL(ang, R, hz, R * 0.95, h * (1 + 0.05 * (i % 2)), R * 0.42, RB2[i % 2] if i % 2 else "stone_dark", dy, -4))
    for sx in (-1, 1):
        P.append(rPL(-90 + sx * 55, R * 0.98, hz + 0.2 - h * (1.02 - rim) / 2, R * 0.62, h * rim, R * 0.48, "stone_dark", dy))
    if dome:
        P.append(B(R * 1.0, (0, R * 0.12 + dy, hz + h * 0.42), "stone_dark", 2, (1.0, 1.0, 1.15)))
    return P


def rBRANCH(base, tip, lift, thick, col, side=0.0):
    """One soft curved branch from base to tip, bowing upward by `lift`."""
    b, t = V(base), V(tip)
    m1 = b + (t - b) * 0.35 + V((side, 0, lift))
    m2 = b + (t - b) * 0.72 + V((side * 0.5, 0, lift * 0.6))
    return rCH([tuple(b), tuple(m1), tuple(m2), tuple(t)], [thick, thick * 0.92, thick * 0.85, thick * 0.8], col, 10)


def rCROWN(z0, span, h, n, thick, col="wood_mid"):
    """Fan of smooth curved antler-branches with rounded ends, each with one soft fork."""
    P = []
    for i in range(n):
        t = (i + 0.5) / n * 2 - 1
        base = (t * 2.0, 0, z0)
        tip = (span * t, 0.0, z0 + h * (0.55 + 0.45 * (1 - abs(t))))
        P += rBRANCH(base, tip, h * 0.18 * (1 if t >= 0 else 1), thick, col, side=t * 2.0)
        if i % 2 == 0:
            b = V(base) + (V(tip) - V(base)) * 0.5 + V((t * 1.5, 0, h * 0.12))
            P += rCH([tuple(b), tuple(b + V((t * 3.0 + (2.5 if t >= 0 else -2.5), -0.4, h * 0.30)))], [thick * 0.8, thick * 0.75], col, 10)
    return P


def rCLOAK(n, rt, rb, thick, ztop, jag=3.0, cols=RB2):
    """Thick hanging roots from the shoulders to the ground at the back and sides, rounded ends."""
    P = []
    for i in range(n):
        a = math.radians(50 + (i + 0.5) * 260.0 / n)
        c, s_ = math.cos(a), math.sin(a)
        zb = (jag if i % 2 else 0) + thick * 0.8
        P += rCH([(c * rt, s_ * rt, ztop), (c * (rt + rb) * 0.5, s_ * (rt + rb) * 0.5, (ztop + zb) * 0.55), (c * rb, s_ * rb, zb)], [thick, thick * 0.9, thick * 0.8], cols[i % 2], 8)
    return P


def rknot(x, y, z, r=1.9):
    return [B(r, (x, y, z), "wood_mid", 1, (1, 0.35, 1.1)), B(r * 0.68, (x, y - r * 0.32, z), "ink", 1, (1, 0.5, 1.15))]


def rleg(x, y, h, r):
    """Stump leg with rounded root toes."""
    P = [C(r, r * 0.85, h, 0.0, "stone_dark", x, y, 10), B(r * 0.88, (x, y, h), "ink", 1)]
    for k in range(3):
        a = math.radians(-120 + k * 40)
        P += rCH([(x + math.cos(a) * r * 0.8, y + math.sin(a) * r * 0.8, r * 0.9), (x + math.cos(a) * r * 1.9, y + math.sin(a) * r * 1.9, r * 0.5)], [r * 0.45, r * 0.45, r * 0.45], "wood_dark", 7)
    return P


def ranchors(obj, ey, hands, chest, rootr=7.0):
    bc.anchor(obj, "eye_l_anchor", pv((ey[0], ey[1], ey[2])), "head", 1.1 * K)
    bc.anchor(obj, "eye_r_anchor", pv((-ey[0], ey[1], ey[2])), "head", 1.1 * K)
    bc.anchor(obj, "chest_knot_anchor", pv(chest), "", 1.8 * K)
    bc.anchor(obj, "hand_l_anchor", pv(hands[0]), "arm_l", 2.2 * K)
    bc.anchor(obj, "hand_r_anchor", pv(hands[1]), "arm_r", 2.2 * K)
    bc.anchor(obj, "roots_anchor", pv((0, 0, 0.3)), "", rootr * K)


def rarm(groups, hp, nm, sh, pts, rad, fist, fr, hand):
    groups.append((nm, rLIMB(pts, rad) + rFIST(fist, fr), pv(sh), ""))
    hp[nm] = hand


def throne(plates=5, rise=0.0, rr=2.6):
    """The G base: wide skirt cones, ring of 5 broad arching rounded roots, smooth bark plates on the front."""
    body = [C(10.0, 7.0, 3.5, 0.0, "ink", segs=14), C(7.0, 4.4, 6.0, 3.5, "stone_dark", segs=14), C(4.4, 3.6, 3.0, 9.5, "ink", segs=14)]
    for i in range(5):
        a = math.radians(i * 72 + 18)
        c, s_ = math.cos(a), math.sin(a)
        body += rCH([(c * 6.5, s_ * 6.5, 3.8), (c * 10.8, s_ * 10.8, 5.6 + rise), (c * 13.8, s_ * 13.8, rr * 1.0)], [rr, rr * 0.95, rr * 0.85], RB[i % 2], 12)
    for i in range(plates):
        body.append(rPL(-90 + (i - (plates - 1) / 2) * 34, 6.4, 5.4, 5.2, 7.8, 1.8, RB2[i % 2] if i % 2 else "stone_dark"))
    return body


def hoodmask(hz, R, h, n, dome=False, w=8.6):
    head = rHOOD(hz, R, h, n, 0.0, dome)
    w = R * 2.0
    mk, ex, ey, ez = rMASK(0, -R * 0.52, hz, w, w)
    return head + mk, (ex, ey, ez)


# ---------------------------------------------------------------- I: smooth antler-branch crown, hanging-root cloak
def variant_i():
    global K
    K = 0.017
    body = throne() + rknot(0, -4.6, 10.8)
    for sx in (-1, 1):
        body.append(B(3.6, (sx * 5.0, 0.0, 12.8), "stone_dark", 2, (1.25, 1.0, 0.8)))
    bf = [rPL(-90, 5.4, 7.4, 5.4, 5.4, 1.4, "stone_dark"), B(0.5, (0, -5.0, 7.4), "ink", 1, (0.5, 0.5, 5.4))]
    cloak = rCLOAK(6, 4.4, 10.0, 2.2, 12.6)
    hz = 17.6
    head, ey = hoodmask(hz, 6.8, 9.6, 7)
    crown = rCROWN(hz + 5.0, 14.0, 7.0, 4, 3.0, "wood_mid")
    groups = [("", body, (0, 0, 0), ""), ("bark_front", bf, pv((0, -5.0, 7.4)), ""), ("cloak", cloak, pv((0, 1.0, 12.6)), ""),
              ("head", head, pv((0, 0, 13.6)), ""), ("crown", crown, pv((0, 0, hz + 5.0)), "head")]
    hp = {}
    for nm, sx in (("arm_l", 1), ("arm_r", -1)):
        rarm(groups, hp, nm, (sx * 5.6, 0.0, 12.6), [(sx * 5.6, 0.0, 12.6), (sx * 8.6, -1.6, 11.2), (sx * 8.8, -4.2, 9.8), (sx * 7.2, -6.2, 9.0)],
             [3.0, 2.8, 2.6, 2.5], (sx * 7.0, -7.0, 8.6), 3.2, (sx * 7.0, -9.2, 8.6))
    obj = bc.assemble("ew_boss_skotos_i_v01", groups)
    ranchors(obj, ey, (hp["arm_l"], hp["arm_r"]), (0, -5.8, 10.8))
    return obj


# ---------------------------------------------------------------- J: no crown; deep dome hood, heavy moss-and-bark mantle, arms resting on the throne roots
def variant_j():
    global K
    K = 0.0205
    body = throne(rise=0.6) + rknot(0, -4.8, 9.6)
    mantle = []
    for sx in (-1, 1):  # heavy shoulder mantle: bark mounds under moss, with moss lobes hanging
        mantle.append(B(5.4, (sx * 6.6, 0.4, 12.6), "stone_dark", 2, (1.3, 1.1, 0.75)))
        mantle.append(B(4.6, (sx * 6.9, 0.2, 14.0), "leaf_dark", 2, (1.35, 1.15, 0.6)))
        for k in range(3):
            mantle.append(B(1.9, (sx * (8.8 + k * 1.2), -1.6 + k * 1.8, 11.0 - k * 0.6), "leaf_dark" if k % 2 == 0 else "leaf_green", 2, (1, 0.7, 1.7)))
    mantle.append(B(5.8, (0, 3.0, 13.4), "leaf_dark", 2, (1.5, 0.9, 0.6)))
    cloak = rCLOAK(5, 4.6, 10.4, 2.4, 12.2)
    bf = [rPL(-90, 5.0, 7.2, 5.6, 5.6, 1.4, "stone_dark"), B(0.5, (0, -4.8, 7.2), "ink", 1, (0.5, 0.5, 5.6))]
    hz = 17.4
    head, ey = hoodmask(hz, 7.4, 11.0, 8, dome=True)
    groups = [("", body, (0, 0, 0), ""), ("bark_front", bf, pv((0, -4.9, 7.2)), ""), ("mantle", mantle, pv((0, 0.4, 12.4)), ""),
              ("cloak", cloak, pv((0, 1.0, 12.2)), ""), ("head", head, pv((0, 0, 13.2)), "")]
    hp = {}
    for nm, sx in (("arm_l", 1), ("arm_r", -1)):  # fists rest on the root arms of the throne
        rarm(groups, hp, nm, (sx * 6.2, 0.0, 12.2), [(sx * 6.2, 0.0, 12.2), (sx * 10.0, -1.0, 10.6), (sx * 11.6, -3.0, 8.0), (sx * 10.6, -5.2, 6.8)],
             [3.4, 3.1, 2.9, 2.8], (sx * 10.2, -6.0, 6.2), 3.4, (sx * 10.2, -8.4, 6.2))
    obj = bc.assemble("ew_boss_skotos_j_v01", groups)
    ranchors(obj, ey, (hp["arm_l"], hp["arm_r"]), (0, -5.6, 9.6))
    return obj


# ---------------------------------------------------------------- K: halo of intertwined branches behind the head; robe of bark scales
def variant_k():
    global K
    K = 0.017
    body = [C(10.0, 7.0, 3.5, 0.0, "ink", segs=14), C(7.0, 4.4, 6.0, 3.5, "stone_dark", segs=14), C(4.4, 3.6, 3.0, 9.5, "ink", segs=14)]
    for i in range(5):
        a = math.radians(i * 72 + 18)
        c, s_ = math.cos(a), math.sin(a)
        body += rCH([(c * 6.5, s_ * 6.5, 3.8), (c * 10.8, s_ * 10.8, 5.6), (c * 13.8, s_ * 13.8, 2.4)], [2.6, 2.5, 2.2], RB[i % 2], 12)
    robe = []  # layered bark scales: rings of overlapping rounded plates, lower rows wider
    for row, (z, r, n, w, h) in enumerate(((2.8, 9.6, 12, 5.6, 4.4), (5.6, 7.9, 11, 5.0, 4.2), (8.4, 6.0, 10, 4.2, 4.0), (11.0, 4.4, 8, 3.8, 3.6))):
        for i in range(n):
            ang = i * 360 / n + (180 / n if row % 2 else 0) + 90
            robe.append(rPL(ang, r, z, w, h, 1.4, RB2[(i + row) % 2] if (i + row) % 3 else "stone_dark", 0, -22))
    body += rknot(0, -4.8, 11.4)
    hz = 17.6
    head, ey = hoodmask(hz, 6.6, 9.4, 7)
    halo = []  # two intertwined branch rings behind the head (rounded, no points)
    for strand in (0, 1):
        pts = []
        for j in range(25):
            th = j / 24 * 2 * math.pi * 1.0
            rr = 12.5 + (1.2 if (j + strand) % 2 else -1.0)
            pts.append((math.cos(th + strand * 0.35) * rr, 4.0 + (0.9 if strand else -0.9), hz + 3.0 + math.sin(th + strand * 0.35) * rr * 0.96))
        # keep the ring above the shoulders: lift points that would dip below z = 13
        pts = [(x, y, max(z, 13.0)) for x, y, z in pts]
        halo += rCH(pts, [3.0] * 25, "wood_mid" if strand else "wood_dark", 10)
    bf = [rPL(-90, 5.0, 8.0, 5.0, 5.0, 1.3, "stone_dark"), B(0.5, (0, -4.9, 8.0), "ink", 1, (0.5, 0.5, 5.0))]
    groups = [("", body, (0, 0, 0), ""), ("robe", robe, pv((0, 0, 7.0)), ""), ("bark_front", bf, pv((0, -4.9, 8.0)), ""),
              ("head", head, pv((0, 0, 13.6)), ""), ("halo", halo, pv((0, 4.0, hz + 3.0)), "head")]
    hp = {}
    for nm, sx in (("arm_l", 1), ("arm_r", -1)):
        rarm(groups, hp, nm, (sx * 5.6, 0.0, 12.8), [(sx * 5.6, 0.0, 12.8), (sx * 8.6, -1.6, 11.4), (sx * 8.8, -4.4, 10.0), (sx * 7.2, -6.4, 9.2)],
             [3.0, 2.8, 2.6, 2.5], (sx * 7.0, -7.2, 8.8), 3.2, (sx * 7.0, -9.4, 8.8))
    obj = bc.assemble("ew_boss_skotos_k_v01", groups)
    ranchors(obj, ey, (hp["arm_l"], hp["arm_r"]), (0, -5.7, 11.4))
    bc.anchor(obj, "halo_anchor", pv((0, 4.0, hz + 3.0)), "head", 3.0 * K)
    return obj


# ---------------------------------------------------------------- L: leafy canopy crown, mossy cloak, branches growing from the shoulders
def variant_l():
    global K
    K = 0.0165
    body = throne() + rknot(0, -4.6, 10.8)
    cloak = []  # mossy cloak: thick hanging roots plus layered moss lobes
    cloak += rCLOAK(5, 4.4, 10.0, 2.2, 12.6, 3.0)
    for i in range(7):
        a = math.radians(60 + i * 40)
        cloak.append(B(2.6, (math.cos(a) * 6.8, math.sin(a) * 6.8, 9.5 - (i % 2) * 2.0), "leaf_dark" if i % 2 else "leaf_green", 2, (1.1, 1.1, 1.6)))
    bf = [rPL(-90, 5.4, 7.4, 5.4, 5.4, 1.4, "stone_dark"), B(0.5, (0, -5.0, 7.4), "ink", 1, (0.5, 0.5, 5.4))]
    hz = 17.6
    head, ey = hoodmask(hz, 6.8, 9.6, 7)
    canopy = []  # rounded leaf clusters on soft stems
    for i, (x, y, z, r) in enumerate(((0, 0, 31.0, 5.2), (-6.8, 0.4, 28.6, 4.2), (6.8, 0.4, 28.6, 4.2), (-11.0, 0, 25.4, 3.6), (11.0, 0, 25.4, 3.6), (-3.0, 3.0, 28.0, 3.8), (3.2, 3.0, 28.0, 3.8))):
        canopy.append(B(r, (x, y, z), "leaf_dark" if i % 2 == 0 else "leaf_green", 2, (1.1, 1.0, 0.75)))
        canopy.append(B(r * 0.55, (x * 1.05, y - 1.4, z + r * 0.45), "leaf_light", 1, (1.0, 0.9, 0.6)))
    for x, z1 in ((-3.4, 28.4), (3.4, 28.4), (-7.5, 25.2), (7.5, 25.2), (0, 29.0)):
        canopy += rCH([(x * 0.3, 0, hz + 4.8), (x * 0.7, 0, (hz + 4.8 + z1) / 2), (x, 0, z1 - 1.8)], [1.5, 1.3, 1.1], "wood_dark", 7)
    groups = [("", body, (0, 0, 0), ""), ("bark_front", bf, pv((0, -5.0, 7.4)), ""), ("cloak", cloak, pv((0, 1.0, 12.6)), ""),
              ("head", head, pv((0, 0, 13.6)), ""), ("canopy", canopy, pv((0, 0, hz + 4.8)), "head")]
    shb = []  # branches growing from the shoulders like smooth tree arms, ending in leaf balls
    for sx in (-1, 1):
        shb += rBRANCH((sx * 6.2, 2.0, 13.2), (sx * 13.4, 1.0, 22.4), 5.0, 2.2, "wood_dark", side=sx * 1.5)
        shb.append(B(3.2, (sx * 13.6, 1.0, 23.4), "leaf_dark", 2, (1.1, 1.0, 0.8)))
        shb += rBRANCH((sx * 9.0, 1.6, 17.0), (sx * 14.8, 0.6, 15.8), 2.0, 1.6, "wood_dark", side=sx * 0.5)
        shb.append(B(2.4, (sx * 15.2, 0.6, 16.2), "leaf_green", 2, (1.1, 1.0, 0.8)))
    groups.append(("branches", shb, pv((0, 1.5, 13.0)), ""))
    hp = {}
    for nm, sx in (("arm_l", 1), ("arm_r", -1)):
        rarm(groups, hp, nm, (sx * 5.6, 0.0, 12.6), [(sx * 5.6, 0.0, 12.6), (sx * 8.6, -1.6, 11.2), (sx * 8.8, -4.2, 9.8), (sx * 7.2, -6.2, 9.0)],
             [3.0, 2.8, 2.6, 2.5], (sx * 7.0, -7.0, 8.6), 3.2, (sx * 7.0, -9.2, 8.6))
    obj = bc.assemble("ew_boss_skotos_l_v01", groups)
    ranchors(obj, ey, (hp["arm_l"], hp["arm_r"]), (0, -5.8, 10.8))
    bc.anchor(obj, "canopy_anchor", pv((0, 0, 29.0)), "head", 4.0 * K)
    return obj


# ================================================================ ROUND 4 (M-P): boss AURA, learning from Durva's bosses (not copying): near-black tiered upright body with
# a few accents, a huge radial shape behind the head much wider than the body, a small bright face high up, bands/floating bits.
# No spikes, no claws, no thorns: rounded leaves, rounded branch ends. Glow assumed Warden PURPLE (+ ember red); it is NOT geometry:
# dark ink bands/sockets plus anchors. K per variant (units -> metres); ~28 units tall = ~10 cells.
def rLEAF(cx, y, cz, ang, r0, L, W, col, thick=1.0):
    """Rounded leaf (squashed ellipsoid) in the XZ plane, pointing at `ang` degrees from straight up toward +X, starting r0 from the centre."""
    o = bc.blob("lf", 1.0, (0, 0, 0), col, 2, (W / 2 * K, thick * 0.5 * K, L / 2 * K))
    nb(o)
    bc.rotate(o, (0, ang, 0))
    a = math.radians(ang)
    o.location = ((cx + math.sin(a) * (r0 + L / 2)) * K, y * K, (cz + math.cos(a) * (r0 + L / 2)) * K)
    bc.apply_transforms(o)
    return o


def rFAN(cx, y, cz, a0, a1, n, r0, L, W, cols, layers=2, shrink=0.72):
    """Radial fan of rounded leaves, 2 layers (outer long, inner short, offset)."""
    P = []
    for ly in range(layers):
        for i in range(n):
            ang = a0 + (a1 - a0) * (i + (0.5 if ly % 2 else 0.0)) / (n - 1 + (0 if ly == 0 else 0))
            if ang > a1 + 0.1:
                continue
            P.append(rLEAF(cx, y + ly * 0.9, cz, ang, r0, L * (shrink ** ly) * (1 + 0.08 * (i % 2)), W * (shrink ** (ly * 0.3)), cols[(i + ly) % len(cols)]))
    return P


TIER_LOBES = 14


def rTIER(z0, h, rb, rt, col, band=True, lobes=None):
    lobes = TIER_LOBES if lobes is None else lobes
    P = [C(rb, rt, h, z0, col, segs=14)]
    for i in range(lobes):  # scalloped rounded rim
        a = math.radians(i * 360 / lobes)
        P.append(B(1.7, (math.cos(a) * rb, math.sin(a) * rb, z0 + (1.9 if lobes < 12 else 1.4)), "stone_dark", 2 if lobes < 12 else 1, (1.2, 1.2, 0.85)))
    if band:  # dark socket groove (the glow band anchor sits here)
        t = 0.62
        r = rb + (rt - rb) * t + 0.25
        P.append(C(r, r, 1.5, z0 + h * t, "warden_deep", segs=14))
    return P


def tiers(spec):
    """spec: list of (z0, h, rb, rt, col)."""
    P = []
    for z0, h, rb, rt, col in spec:
        P += rTIER(z0, h, rb, rt, col)
    return P


def rORB(x, y, z, r, col="warden_deep"):
    return [B(r, (x, y, z), col, 2), B(r * 0.5, (x, y - r * 0.85, z), "ink", 1, (1, 0.5, 1))]


TIER_COLS = ("ink", "warden_dark")


# ---------------------------------------------------------------- M: bloom-tree
def variant_m():
    global K
    K = 0.0132
    spec = [(0.0, 6.5, 10.0, 8.2, "warden_dark"), (6.5, 6.5, 8.2, 6.6, "ink"), (13.0, 6.0, 6.6, 5.2, "warden_dark"), (19.0, 5.0, 5.2, 4.0, "ink")]
    body = tiers(spec) + rROOTS(4, 8.0, 2.8, 13.5, 2.4, 45)
    body += rknot(0, -6.6, 15.5, 1.9)
    bf = [rPL(-90, 6.4, 14.5, 4.8, 5.4, 1.3, "wood_dark")]
    hz = 25.0
    head = rHOOD(hz, 3.8, 6.2, 7)
    mk, ex, ey, ez = rMASK(0, -2.0, hz, 8.6, 8.6)
    head += mk
    fan = rFAN(0, 6.0, hz - 0.5, -140, 140, 15, 4.5, 11.0, 4.6, ("leaf_dark", "ink", "warden_deep", "leaf_dark"), 2, 0.7)
    mantle = [B(4.2, (sx * 5.2, 0.0, 20.8), "wood_dark", 2, (1.2, 1.0, 0.8)) for sx in (-1, 1)]
    groups = [("", body, (0, 0, 0), ""), ("bark_front", bf, pv((0, -6.4, 14.5)), ""), ("head", head, pv((0, 0, 22.0)), ""),
              ("fan", fan, pv((0, 6.0, hz - 0.5)), "head"), ("mantle", mantle, pv((0, 0, 20.8)), "")]
    hp = {}
    for nm, sx in (("arm_l", 1), ("arm_r", -1)):
        rarm(groups, hp, nm, (sx * 5.4, 0.0, 20.8), [(sx * 5.4, 0.0, 20.8), (sx * 9.2, -1.6, 19.0), (sx * 11.0, -3.6, 16.0), (sx * 10.6, -5.6, 13.6)],
             [2.4, 2.2, 2.1, 2.0], (sx * 10.4, -6.4, 12.2), 2.6, (sx * 10.4, -8.4, 12.2))
    obj = bc.assemble("ew_boss_skotos_m_v01", groups)
    ranchors(obj, (ex, ey, ez), (hp["arm_l"], hp["arm_r"]), (0, -7.4, 15.5), 9.0)
    for i, z in enumerate((4.0, 10.5, 16.4)):
        bc.anchor(obj, "band_%d_anchor" % (i + 1), pv((0, -(10.0 - 0.28 * 1.0 * (i + 1) * 0 - i * 1.9) * 0.85, z)), "", 2.0 * K)
    bc.anchor(obj, "fan_anchor", pv((0, 6.0, hz - 0.5)), "head", 4.0 * K)
    return obj


# ---------------------------------------------------------------- N: antler halo
def variant_n():
    global K
    K = 0.0122
    spec = [(0.0, 8.0, 8.6, 6.8, "warden_dark"), (8.0, 9.0, 6.8, 5.4, "ink"), (17.0, 5.0, 5.4, 4.2, "warden_dark")]
    body = tiers(spec) + rROOTS(4, 7.0, 2.6, 12.0, 2.3, 30) + rknot(0, -6.0, 14.0, 1.9)
    cloak = rCLOAK(7, 4.6, 9.0, 2.0, 21.0, 3.5)
    bf = [rPL(-90, 5.6, 13.0, 4.6, 5.2, 1.3, "wood_dark")]
    hz = 25.0
    head = rHOOD(hz, 3.9, 6.4, 7)
    mk, ex, ey, ez = rMASK(0, -2.0, hz, 7.4, 7.4)
    head += mk
    halo = []  # vast ring of smooth curved antler-branches behind the head, plus an inner twisted ring
    for i in range(6):
        ang = math.radians(i * 60 + 12)
        c, s_ = math.sin(ang), math.cos(ang)
        side = 0.20
        pts = [(c * 5.5, 6.0, hz + s_ * 5.5), (math.sin(ang + side) * 10.5, 6.5, hz + math.cos(ang + side) * 10.5), (math.sin(ang + side * 1.8) * 15.0, 6.0, hz + math.cos(ang + side * 1.8) * 15.0), (math.sin(ang + side * 2.3) * 18.5, 6.0, hz + math.cos(ang + side * 2.3) * 18.5)]
        halo += rCH(pts, [3.0, 2.7, 2.4, 2.2], "wood_dark", 10)
        
    ring = []
    for j in range(31):
        th = j / 30 * 2 * math.pi
        ring.append((math.sin(th) * 8.6, 7.4 + (0.9 if j % 2 else -0.4), hz + math.cos(th) * 8.6))
    halo += rCH(ring, [1.8] * 31, "wood_dark", 9)
    orbs = []
    for i, (x, y, z) in enumerate(((-13.5, -3.0, 21.0), (13.5, -3.0, 21.0), (-15.5, 1.0, 14.0), (15.5, 1.0, 14.0), (-9.0, -9.0, 27.0), (9.0, -9.0, 27.0))):
        orbs += rORB(x, y, z, 3.0 if i < 4 else 2.4, "warden_deep")
    groups = [("", body, (0, 0, 0), ""), ("bark_front", bf, pv((0, -5.6, 13.0)), ""), ("cloak", cloak, pv((0, 1.0, 21.0)), ""),
              ("head", head, pv((0, 0, 22.0)), ""), ("halo", halo, pv((0, 6.0, hz)), "head"), ("orbs", orbs, pv((0, 0, 20.0)), "")]
    hp = {}
    for nm, sx in (("arm_l", 1), ("arm_r", -1)):
        rarm(groups, hp, nm, (sx * 4.8, 0.0, 19.8), [(sx * 4.8, 0.0, 19.8), (sx * 8.4, -1.6, 18.2), (sx * 9.4, -3.8, 15.6), (sx * 8.4, -5.6, 13.6)],
             [2.4, 2.2, 2.1, 2.0], (sx * 8.2, -6.4, 12.4), 2.7, (sx * 8.2, -8.4, 12.4))
    obj = bc.assemble("ew_boss_skotos_n_v01", groups)
    ranchors(obj, (ex, ey, ez), (hp["arm_l"], hp["arm_r"]), (0, -6.8, 14.0), 9.0)
    bc.anchor(obj, "halo_anchor", pv((0, 6.0, hz)), "head", 4.0 * K)
    for i, (x, y, z) in enumerate(((-13.5, -3.0, 21.0), (13.5, -3.0, 21.0), (-15.5, 1.0, 14.0), (15.5, 1.0, 14.0), (-9.0, -9.0, 27.0), (9.0, -9.0, 27.0))):
        bc.anchor(obj, "orb_%d_anchor" % (i + 1), pv((x, y, z)), "orbs", 2.0 * K)
    return obj


# ---------------------------------------------------------------- O: canopy god
def variant_o():
    global K
    K = 0.0135
    body = [C(9.0, 6.4, 5.0, 0.0, "warden_dark", segs=14), C(6.4, 5.4, 7.0, 5.0, "ink", segs=14), C(5.4, 4.8, 6.0, 12.0, "warden_dark", segs=14), C(4.8, 4.0, 4.0, 18.0, "ink", segs=14)]
    body += rROOTS(5, 6.0, 3.2, 12.8, 2.6, 18)  # roots flaring at the hem like a skirt
    for i in range(3):  # big bark knots, not stripes
        a = math.radians(40 + i * 110)
        body.append(B(2.3, (math.cos(a) * 5.4, math.sin(a) * 5.4, 9.0 + i * 3.5), "wood_dark", 2))
    body += rknot(0, -5.6, 14.0, 2.0)
    body.append(C(5.7, 5.7, 1.4, 12.8, "ink", segs=14))  # dark band
    bf = [rPL(-90, 5.2, 13.0, 4.6, 5.0, 1.3, "wood_dark")]
    hz = 24.2
    head = rHOOD(hz, 3.6, 5.8, 7)
    mk, ex, ey, ez = rMASK(0, -1.9, hz, 8.4, 8.4)
    head += mk
    canopy = []  # broad dark leaf canopy, a tree crown seen from below: radial rosette in the horizontal plane
    zc = 35.0
    for layer, (R0, L, W, zz, cols) in enumerate(((5.0, 13.5, 6.0, zc, ("leaf_dark", "warden_dark")), (3.5, 10.0, 5.4, zc + 1.4, ("warden_dark", "leaf_dark")), (0.5, 5.0, 4.2, zc + 2.6, ("leaf_dark", "warden_deep")))):
        n = 12 - layer * 2
        for i in range(n):
            ang = (i + 0.5 * (layer % 2)) * 360 / n
            o = bc.blob("cl", 1.0, (0, 0, 0), cols[i % 2], 2, (L / 2 * K, W / 2 * K, 0.9 * K))
            nb(o)
            bc.rotate(o, (0, 0, ang))
            a = math.radians(ang)
            o.location = (math.cos(a) * (R0 + L / 2) * K, math.sin(a) * (R0 + L / 2) * K + 1.0 * K, zz * K)
            bc.apply_transforms(o)
            canopy.append(o)
    canopy.append(B(4.0, (0, 1.0, zc + 2.2), "leaf_dark", 2, (1, 1, 0.7)))
    for x in (-1, 1):
        canopy += rCH([(x * 2.0, 0, hz + 3.0), (x * 3.4, 0.5, 30.0), (x * 3.8, 1.0, zc)], [2.2, 2.0, 1.9], "wood_dark", 9)
    groups = [("", body, (0, 0, 0), ""), ("bark_front", bf, pv((0, -5.2, 13.0)), ""), ("head", head, pv((0, 0, 21.4)), ""),
              ("canopy", canopy, pv((0, 1.0, zc)), "head")]
    hp = {}
    for nm, sx in (("arm_l", 1), ("arm_r", -1)):  # arms raised toward the canopy
        rarm(groups, hp, nm, (sx * 4.6, 0.0, 19.6), [(sx * 4.6, 0.0, 19.6), (sx * 8.6, -1.2, 20.4), (sx * 11.0, -2.0, 23.4), (sx * 11.4, -2.6, 26.6)],
             [2.5, 2.3, 2.1, 2.0], (sx * 11.2, -2.8, 28.2), 2.7, (sx * 11.2, -4.8, 28.2))
    obj = bc.assemble("ew_boss_skotos_o_v01", groups)
    ranchors(obj, (ex, ey, ez), (hp["arm_l"], hp["arm_r"]), (0, -6.6, 14.0), 9.0)
    bc.anchor(obj, "canopy_anchor", pv((0, 1.0, zc + 2.0)), "head", 5.0 * K)
    return obj


# ---------------------------------------------------------------- P: hooded giant
def variant_p():
    global K
    K = 0.0132
    body = [C(10.0, 7.0, 6.0, 0.0, "warden_dark", segs=14), C(7.0, 5.4, 8.0, 6.0, "ink", segs=14), C(5.4, 4.6, 6.0, 14.0, "warden_dark", segs=14)]
    body += rROOTS(4, 8.0, 2.8, 13.0, 2.4, 45)
    body.append(C(5.9, 5.9, 1.8, 15.0, "ink", segs=14))  # chest band (glow band anchor)
    body += rknot(0, -5.8, 15.8, 2.0)
    for i in range(5):
        body.append(rPL(-90 + (i - 2) * 30, 6.8, 7.0, 4.4, 7.6, 1.5, "wood_dark" if i % 2 else "ink"))
    cloak = rCLOAK(9, 5.0, 10.2, 2.1, 20.0, 3.5)
    bf = [rPL(-90, 5.6, 13.0, 4.6, 5.0, 1.3, "wood_dark")]
    hz = 26.0
    head = rHOOD(hz, 5.6, 11.0, 8, 0.0, False)
    head.append(B(5.4, (0, 0.8, hz + 5.6), "ink", 2, (1.0, 1.0, 0.55)))  # rounded hood top
    mk, ex, ey, ez = rMASK(0, -2.6, hz, 9.0, 9.0)  # bright mask set inside the deep hood
    head += mk
    fan = []  # rounded branch fan behind the shoulders
    for i in range(7):
        t = (i + 0.5) / 7 * 2 - 1
        ang = t * 62
        base = (math.sin(math.radians(ang)) * 4.0, 5.0, 20.0)
        tip = (math.sin(math.radians(ang)) * 17.0, 5.5, 20.0 + math.cos(math.radians(ang)) * 14.0)
        fan += rBRANCH(base, tip, 3.0, 2.2, "wood_dark" if i % 2 else "ink", side=t * 2.0)
        fan.append(B(2.8, (tip[0], tip[1], tip[2] + 0.5), "leaf_dark" if i % 2 else "ink", 2, (1.1, 0.8, 1.0)))
    groups = [("", body, (0, 0, 0), ""), ("bark_front", bf, pv((0, -5.6, 13.0)), ""), ("cloak", cloak, pv((0, 1.0, 20.0)), ""),
              ("head", head, pv((0, 0, 22.0)), ""), ("fan", fan, pv((0, 5.0, 20.0)), "")]
    hp = {}
    for nm, sx in (("arm_l", 1), ("arm_r", -1)):
        rarm(groups, hp, nm, (sx * 5.2, 0.0, 19.6), [(sx * 5.2, 0.0, 19.6), (sx * 8.6, -1.6, 17.8), (sx * 9.8, -3.8, 14.8), (sx * 8.6, -5.8, 12.6)],
             [2.6, 2.4, 2.2, 2.1], (sx * 8.4, -6.6, 11.4), 2.8, (sx * 8.4, -8.6, 11.4))
    obj = bc.assemble("ew_boss_skotos_p_v01", groups)
    ranchors(obj, (ex, ey, ez), (hp["arm_l"], hp["arm_r"]), (0, -7.0, 15.8), 9.0)
    bc.anchor(obj, "band_1_anchor", pv((0, -6.4, 15.9)), "", 2.5 * K)
    bc.anchor(obj, "fan_anchor", pv((0, 5.0, 20.0)), "", 4.0 * K)
    return obj


# ================================================================ ROUND 5 (Q-T): the M + P family. Siddharth 2026-11-17/18: "I like M and P, more variants."
# No spikes; near-black body; pale carved face tilted up slightly so it reads from the high table camera; glow = dark sockets / ink groove
# bands + anchors only (assumed Warden PURPLE + ember red). Broad oak-like rounded leaves (lobed ellipsoids), not feathers.
def rOAK(cx, y, cz, ang, r0, L, W, col):
    """Oak-like rounded leaf: a thick ellipsoid with two pairs of rounded lobes. Points `ang` degrees from straight up toward +X in the XZ plane."""
    a = math.radians(ang)
    d = V((math.sin(a), 0, math.cos(a)))
    n = V((math.cos(a), 0, -math.sin(a)))
    c0 = V((cx, y, cz)) + d * (r0 + L / 2)
    P = [rLEAF(cx, y, cz, ang, r0, L, W * 0.62, col)]
    for t, k in ((-0.18, 0.9), (0.22, 1.0)):
        for sgn in (-1, 1):
            p = c0 + d * (L * t) + n * (sgn * W * 0.30)
            P.append(B(W * 0.30 * k, tuple(p), col, 1, (1.0, 0.45, 1.15)))
    return P


def rOAKFAN(cx, y, cz, a0, a1, n, r0, L, W, cols, layers=2, shrink=0.72):
    P = []
    for ly in range(layers):
        cnt = n - ly * 3
        for i in range(cnt):
            ang = a0 + (a1 - a0) * (i + 0.5 * (ly % 2)) / max(cnt - 1 + 0.5 * (ly % 2), 1)
            P += rOAK(cx, y + ly * 1.0, cz, ang, r0 + ly * 0.5, L * (shrink ** ly) * (1 + 0.07 * (i % 2)), W * (shrink ** (ly * 0.3)), cols[(i + ly) % len(cols)])
    return P


def tilt_parts(parts, pivot, deg):
    m = mathutils.Matrix.Translation(V(pv(pivot))) @ mathutils.Matrix.Rotation(math.radians(deg), 4, "X") @ mathutils.Matrix.Translation(-V(pv(pivot)))
    for o in parts:
        o.data.transform(m)
        o.data.update()
    return m


def rFACE(cx, y, z, w, tilt=-14, mouth=False):
    """Whole carved face: bone plate, heavy brow, cheek plates, big deep sockets, nose ridge, (optional small mouth). Tilted up so the high camera sees it.
    Returns parts, (eye_dx, eye_y, eye_z) of the socket anchors."""
    yf = y - w * 0.16
    P = [B(w * 0.5, (cx, y, z), "bone", 2, (1.0, 0.32, 1.1)),
         B(w * 0.5, (cx, yf - w * 0.04, z + w * 0.31), "stone_dark", 2, (1.04, 0.26, 0.24)),
         B(w * 0.17, (cx - w * 0.31, yf - w * 0.02, z - w * 0.14), "wood_light", 1, (1.0, 0.5, 0.9)),
         B(w * 0.17, (cx + w * 0.31, yf - w * 0.02, z - w * 0.14), "wood_light", 1, (1.0, 0.5, 0.9)),
         B(w * 0.24, (cx - w * 0.24, yf - w * 0.03, z + w * 0.06), "ink", 2, (1.0, 0.55, 1.25)),
         B(w * 0.24, (cx + w * 0.24, yf - w * 0.03, z + w * 0.06), "ink", 2, (1.0, 0.55, 1.25)),
         B(w * 0.09, (cx, yf - w * 0.03, z - w * 0.08), "wood_light", 1, (0.7, 0.7, 1.6))]
    if mouth:
        P.append(B(w * 0.12, (cx, yf - w * 0.01, z - w * 0.32), "ink", 1, (1.5, 0.45, 0.4)))
    m = tilt_parts(P, (cx, y, z), tilt)
    e = m @ V(pv((cx + w * 0.24, yf - w * 0.09, z + w * 0.06)))
    return P, (e.x / K - cx, e.y / K, e.z / K)


def mtiers(top=4):
    spec = [(0.0, 6.5, 10.0, 8.2, "warden_dark"), (6.5, 6.5, 8.2, 6.6, "ink"), (13.0, 6.0, 6.6, 5.2, "warden_dark"), (19.0, 5.0, 5.2, 4.0, "ink")]
    return tiers(spec[:top])


def arms_down(groups, hp, z0, spread=1.0, fr=2.7):
    for nm, sx in (("arm_l", 1), ("arm_r", -1)):
        rarm(groups, hp, nm, (sx * 5.4, 0.0, z0), [(sx * 5.4, 0.0, z0), (sx * 9.2 * spread, -1.6, z0 - 1.8), (sx * 11.0 * spread, -3.6, z0 - 4.8), (sx * 10.6 * spread, -5.6, z0 - 7.2)],
             [2.4, 2.2, 2.1, 2.0], (sx * 10.4 * spread, -6.4, z0 - 8.6), fr, (sx * 10.4 * spread, -8.4, z0 - 8.6))


# ---------------------------------------------------------------- Q: M's tiers + leaf fan, P's tall hood with the mask deep inside
def variant_q():
    global K
    K = 0.0116
    body = mtiers(4) + rROOTS(4, 8.0, 2.8, 13.5, 2.4, 45) + rknot(0, -6.6, 15.5, 1.9)
    bf = [rPL(-90, 6.4, 14.5, 4.8, 5.4, 1.3, "wood_dark")]
    hz = 28.0
    head = rHOOD(hz, 5.6, 11.0, 8, 0.0, False, 0.8)
    head.append(B(5.2, (0, 0.8, hz + 5.8), "ink", 2, (1.0, 1.0, 0.55)))
    face, ey = rFACE(0, -3.2, hz, 11.0)
    head += face
    fan = rOAKFAN(0, 7.0, hz - 2.0, -100, 100, 12, 3.0, 13.0, 6.4, ("leaf_dark", "leaf_green", "leaf_dark", "warden_deep"), 3, 0.78)
    mantle = [B(4.2, (sx * 5.2, 0.0, 22.0), "ink", 2, (1.2, 1.0, 0.8)) for sx in (-1, 1)]
    groups = [("", body, (0, 0, 0), ""), ("bark_front", bf, pv((0, -6.4, 14.5)), ""), ("head", head, pv((0, 0, 24.0)), ""),
              ("fan", fan, pv((0, 7.0, hz)), "head"), ("mantle", mantle, pv((0, 0, 22.0)), "")]
    hp = {}
    arms_down(groups, hp, 21.5)
    obj = bc.assemble("ew_boss_skotos_q_v01", groups)
    ranchors(obj, ey, (hp["arm_l"], hp["arm_r"]), (0, -7.4, 15.5), 9.0)
    for i, z in enumerate((4.0, 10.5, 16.4)):
        bc.anchor(obj, "band_%d_anchor" % (i + 1), pv((0, -(9.4 - i * 1.7), z)), "", 2.0 * K)
    bc.anchor(obj, "fan_anchor", pv((0, 7.0, hz)), "head", 4.0 * K)
    return obj


# ---------------------------------------------------------------- R: P's hooded giant + huge oak-leaf fan, root cloak to the ground
def variant_r():
    global K
    K = 0.0114
    body = [C(10.0, 7.0, 6.0, 0.0, "warden_dark", segs=14), C(7.0, 5.4, 8.0, 6.0, "ink", segs=14), C(5.4, 4.6, 6.0, 14.0, "warden_dark", segs=14)]
    body += rROOTS(4, 8.0, 2.8, 13.0, 2.4, 45) + rknot(0, -5.8, 15.8, 2.0)
    for i in range(5):
        body.append(rPL(-90 + (i - 2) * 30, 6.8, 7.0, 4.4, 7.6, 1.5, "wood_dark" if i % 2 else "ink"))
    cloak = rCLOAK(10, 5.0, 11.0, 2.3, 21.0, 3.5)
    bf = [rPL(-90, 5.6, 13.0, 4.6, 5.0, 1.3, "wood_dark")]
    hz = 27.0
    head = rHOOD(hz, 5.8, 11.4, 8, 0.0, False, 0.8)
    head.append(B(5.4, (0, 0.8, hz + 5.8), "ink", 2, (1.0, 1.0, 0.55)))
    face, ey = rFACE(0, -3.4, hz, 11.0)
    head += face
    fan = rOAKFAN(0, 7.5, hz - 1.0, -150, 150, 16, 3.0, 15.0, 6.8, ("leaf_dark", "leaf_green", "leaf_dark", "warden_deep"), 3, 0.8)
    groups = [("", body, (0, 0, 0), ""), ("bark_front", bf, pv((0, -5.6, 13.0)), ""), ("cloak", cloak, pv((0, 1.0, 21.0)), ""),
              ("head", head, pv((0, 0, 23.0)), ""), ("fan", fan, pv((0, 7.5, hz - 1.0)), "head")]
    hp = {}
    arms_down(groups, hp, 20.4)
    obj = bc.assemble("ew_boss_skotos_r_v01", groups)
    ranchors(obj, ey, (hp["arm_l"], hp["arm_r"]), (0, -7.0, 15.8), 9.0)
    bc.anchor(obj, "fan_anchor", pv((0, 7.5, hz - 1.0)), "head", 4.0 * K)
    return obj


# ---------------------------------------------------------------- S: M + a huge fully readable carved face, broader oak fan, glowing-band tiers
def variant_s():
    global K
    K = 0.0116
    body = mtiers(4) + rROOTS(4, 8.0, 2.8, 13.5, 2.4, 45) + rknot(0, -6.6, 15.5, 1.9)
    bf = [rPL(-90, 6.4, 14.5, 4.8, 5.4, 1.3, "wood_dark")]
    hz = 27.0
    head = [B(5.4, (0, 1.4, hz), "ink", 2, (1.1, 0.95, 1.2))]  # dark skull behind the mask
    for sx in (-1, 1):  # bark side plates framing the face, no hood
        head.append(rPL(-90 + sx * 76, 6.2, hz, 4.6, 12.0, 2.6, "wood_dark" if sx > 0 else "ink"))
    head.append(B(5.4, (0, 0.4, hz + 7.4), "ink", 2, (1.1, 1.0, 0.5)))  # brow cap
    face, ey = rFACE(0, -2.4, hz, 12.6, tilt=-12, mouth=True)
    head += face
    fan = rOAKFAN(0, 7.5, hz, -145, 145, 15, 3.5, 14.0, 6.6, ("leaf_dark", "leaf_green", "leaf_dark", "warden_deep"), 3, 0.78)
    mantle = [B(4.4, (sx * 5.6, 0.0, 21.5), "ink", 2, (1.25, 1.0, 0.8)) for sx in (-1, 1)]
    groups = [("", body, (0, 0, 0), ""), ("bark_front", bf, pv((0, -6.4, 14.5)), ""), ("head", head, pv((0, 0, 23.5)), ""),
              ("fan", fan, pv((0, 7.5, hz)), "head"), ("mantle", mantle, pv((0, 0, 21.5)), "")]
    hp = {}
    arms_down(groups, hp, 21.0)
    obj = bc.assemble("ew_boss_skotos_s_v01", groups)
    ranchors(obj, ey, (hp["arm_l"], hp["arm_r"]), (0, -7.4, 15.5), 9.0)
    for i, z in enumerate((4.0, 10.5, 16.4, 21.8)):
        bc.anchor(obj, "band_%d_anchor" % (i + 1), pv((0, -(9.4 - i * 1.7), z)), "", 2.0 * K)
    bc.anchor(obj, "fan_anchor", pv((0, 7.5, hz)), "head", 4.0 * K)
    return obj


# ---------------------------------------------------------------- T: P's cloak and branch fan, M's tiers below the waist, arms raised casting
def variant_t():
    global K
    K = 0.0125
    body = mtiers(3) + rROOTS(4, 8.0, 2.8, 13.5, 2.4, 45)
    body.append(C(5.9, 5.1, 7.0, 18.0, "ink", segs=14))  # upper trunk / robe above the tiers
    body.append(C(5.6, 5.6, 1.8, 16.4, "warden_deep", segs=14))  # chest band (glow band anchor)
    body += rknot(0, -5.6, 21.0, 2.0)
    cloak = rCLOAK(9, 5.0, 10.6, 2.2, 24.0, 3.5)
    bf = [rPL(-90, 5.4, 20.0, 4.6, 5.0, 1.3, "wood_dark")]
    hz = 31.0
    head = rHOOD(hz, 5.4, 10.4, 8, 0.0, False, 0.8)
    head.append(B(5.0, (0, 0.8, hz + 5.4), "ink", 2, (1.0, 1.0, 0.55)))
    face, ey = rFACE(0, -3.0, hz, 10.8)
    head += face
    fan = []  # rounded branch fan behind the shoulders, evenly spread, ending in dark leaf balls
    for i in range(7):
        t = (i + 0.5) / 7 * 2 - 1
        ang = t * 64
        base = (math.sin(math.radians(ang)) * 4.0, 5.0, 24.0)
        tip = (math.sin(math.radians(ang)) * 18.0, 5.5, 24.0 + math.cos(math.radians(ang)) * 15.0)
        fan += rBRANCH(base, tip, 3.0, 2.4, "wood_dark" if i % 2 else "ink", side=0.0)
        fan.append(B(3.0, (tip[0], tip[1], tip[2] + 0.5), "leaf_dark" if i % 2 else "ink", 2, (1.1, 0.8, 1.0)))
    groups = [("", body, (0, 0, 0), ""), ("bark_front", bf, pv((0, -5.4, 20.0)), ""), ("cloak", cloak, pv((0, 1.0, 24.0)), ""),
              ("head", head, pv((0, 0, 27.0)), ""), ("fan", fan, pv((0, 5.0, 24.0)), "")]
    hp = {}
    for nm, sx in (("arm_l", 1), ("arm_r", -1)):  # raised, casting: forearms up, fists open toward the viewer
        rarm(groups, hp, nm, (sx * 5.4, 0.0, 24.0), [(sx * 5.4, 0.0, 24.0), (sx * 9.6, -1.4, 24.6), (sx * 12.2, -3.0, 28.0), (sx * 12.4, -4.2, 31.6)],
             [3.4, 3.1, 2.9, 2.8], (sx * 12.2, -4.6, 33.4), 3.6, (sx * 12.2, -7.0, 33.4))
    obj = bc.assemble("ew_boss_skotos_t_v01", groups)
    ranchors(obj, ey, (hp["arm_l"], hp["arm_r"]), (0, -6.8, 21.0), 9.0)
    bc.anchor(obj, "band_1_anchor", pv((0, -6.4, 17.3)), "", 2.5 * K)
    for i, z in enumerate((4.0, 10.5)):
        bc.anchor(obj, "band_%d_anchor" % (i + 2), pv((0, -(9.4 - i * 1.7), z)), "", 2.0 * K)
    bc.anchor(obj, "fan_anchor", pv((0, 5.0, 24.0)), "", 4.0 * K)
    return obj


# ================================================================ FINAL: Skotos v01 = variant S (Siddharth picked S, 2026-11-18), phase 1 form.
# Fix pass 2 (coordinator, 2026-11-18): ONE carved pale face plate (heavy brow bar, two almond sockets cut into the plate, nose ridge, thin mouth line, no cheeks),
# no rim studs, fists as larger rounded forms, plain rounded tapering buttress roots, warm bark rim on the tier edges and the fan edge, a few lifted fan leaves.
def rOAK_final(cx, y, cz, ang, r0, L, W, col, rim=False):
    a = math.radians(ang)
    d = V((math.sin(a), 0, math.cos(a)))
    n = V((math.cos(a), 0, -math.sin(a)))
    c0 = V((cx, y, cz)) + d * (r0 + L / 2)
    P = []
    if rim:  # warm bark edge: a slightly larger, thinner leaf behind the real one
        o = bc.blob("lfr", 1.0, (0, 0, 0), "wood_mid", 1, (W * 0.58 * K, 1.1 * K, L * 0.54 * K))
        nb(o)
        bc.rotate(o, (0, ang, 0))
        o.location = ((cx + math.sin(a) * (r0 + L / 2)) * K, (y + 1.3) * K, (cz + math.cos(a) * (r0 + L / 2)) * K)
        bc.apply_transforms(o)
        P.append(o)
    o = bc.blob("lf", 1.0, (0, 0, 0), col, 2, (W * 0.52 * K, 2.4 * K, L / 2 * K))
    nb(o)
    bc.rotate(o, (0, ang, 0))
    o.location = ((cx + math.sin(a) * (r0 + L / 2)) * K, y * K, (cz + math.cos(a) * (r0 + L / 2)) * K)
    bc.apply_transforms(o)
    P.append(o)
    for sgn in (-1, 1):  # one pair of round lobes
        p = c0 + d * (L * 0.08) + n * (sgn * W * 0.20)
        P.append(B(W * 0.32, tuple(p), col, 2, (1.0, 1.0, 1.1)))
    return P


def _tilted_ellipsoid(loc, r, sq, roll_deg, col, sub=2):
    """Blob with squash `sq`, rolled about Y (in the face plane) by roll_deg around its own centre, then placed at loc (design units)."""
    o = blob(r * K, (0, 0, 0), col, sub, sq)
    bc.rotate(o, (0, roll_deg, 0))
    o.location = pv(loc)
    bc.apply_transforms(o)
    return o


def rFACE_final(cx, y, z, w, tilt=-12):
    """ONE carved pale face plate: heavy brow bar, two deep almond sockets cut into the plate (inner ends low), small nose ridge, thin mouth line."""
    yf = y - w * 0.16
    P = [B(w * 0.5, (cx, y, z), "bone", 2, (1.0, 0.32, 1.1)),
         B(w * 0.5, (cx, yf - w * 0.045, z + w * 0.33), "wood_dark", 2, (0.98, 0.30, 0.20))]  # one heavy carved brow bar
    for sx in (-1, 1):
        P.append(_tilted_ellipsoid((cx + sx * w * 0.235, yf - w * 0.045, z + w * 0.075), w * 0.19, (1.5, 0.55, 0.78), -sx * 20, "ink"))  # almond socket
    P.append(B(w * 0.085, (cx, yf - w * 0.03, z - w * 0.07), "wood_light", 1, (0.7, 0.7, 1.7)))  # nose ridge
    P.append(B(w * 0.10, (cx, yf - w * 0.012, z - w * 0.33), "ink", 1, (2.4, 0.4, 0.12)))  # thin mouth line
    m = tilt_parts(P, (cx, y, z), tilt)
    e = m @ V(pv((cx + w * 0.235, yf - w * 0.10, z + w * 0.075)))
    return P, (e.x / K - cx, e.y / K, e.z / K)


def rFIST_final(pos, r):
    """Fist as a few larger rounded forms: dark palm mass, two big knuckle lumps, ink palm socket in a mid-wood rim."""
    x, y, z = pos
    P = [B(r * 1.12, pos, "stone_dark", 2), B(r * 0.75, (x, y - r * 0.7, z + r * 0.3), "stone_dark", 2, (1.3, 0.8, 0.8)),
         B(r * 0.42, (x, y - r * 1.0, z - r * 0.1), "ink", 1, (1, 0.5, 1))]
    return P


def buttress_roots(n, r0, L, wid, hgt, phase=45):
    """Plain rounded tapering buttress roots: flattened ellipsoids lying along the ground, buried into the base (no caps, no bolt shapes)."""
    P = []
    for i in range(n):
        ang = i * 360.0 / n + phase
        a = math.radians(ang)
        o = blob(1.0, (0, 0, 0), "ink", 2, (L / 2 * K, wid * K, hgt * K))
        bc.rotate(o, (0, 0, ang))
        o.location = (math.cos(a) * (r0 + L / 2 - 1.0) * K, math.sin(a) * (r0 + L / 2 - 1.0) * K, hgt * 1.02 * K)
        bc.apply_transforms(o)
        P.append(o)
    return P


def build_final():
    global K, TIER_LOBES
    K = 0.0112
    TIER_LOBES = 0
    spec = [(0.0, 6.5, 10.0, 8.2, "warden_dark"), (6.5, 6.5, 8.2, 6.6, "ink"), (13.0, 6.0, 6.6, 5.2, "warden_dark"), (19.0, 5.0, 5.2, 4.0, "ink")]
    body = tiers(spec)
    for z0, h, rb, rt, col in spec:  # warm bark rim along each tier's lower edge
        body.append(C(rb + 0.25, rb + 0.25, 1.0, z0 + 0.1, "wood_mid", segs=14))
    body += buttress_roots(4, 8.0, 10.0, 3.0, 2.6) + [B(1.7, (0, -6.7, 15.5), "ink", 1, (1.0, 0.35, 1.2))]
    bf = [rPL(-90, 6.4, 14.5, 4.8, 5.4, 1.3, "wood_dark")]
    hz = 27.0
    head = [B(5.4, (0, 1.4, hz), "ink", 2, (1.1, 0.95, 1.2))]
    for sx in (-1, 1):
        head.append(rPL(-90 + sx * 82, 7.0, hz - 1.5, 4.0, 6.5, 3.0, "wood_dark"))
    face, ey = rFACE_final(0, -2.4, hz, 13.4)
    head += face
    cols = ("leaf_dark", "ink", "leaf_dark", "leaf_green", "ink", "leaf_dark", "leaf_green", "warden_deep")
    fan = []
    for ly in range(2):
        cnt = 13 - ly * 3
        for i in range(cnt):
            ang = -145 + 290 * (i + 0.5 * (ly % 2)) / max(cnt - 1 + 0.5 * (ly % 2), 1)
            fan += rOAK_final(0, 5.2 + ly * 1.8 - 3.2 * (ang / 145.0) ** 2, hz, ang, 3.5 + ly * 0.5, 12.0 * (0.8 ** ly) * (1 + 0.07 * (i % 2)), 6.6 * (0.78 ** (ly * 0.3)), cols[(i * 3 + ly) % 8], rim=(ly == 0))
    mantle = [B(4.4, (sx * 5.6, 0.0, 21.5), "ink", 2, (1.25, 1.0, 0.8)) for sx in (-1, 1)]
    groups = [("", body, (0, 0, 0), ""), ("bark_front", bf, pv((0, -6.4, 14.5)), ""), ("head", head, pv((0, 0, 23.5)), ""),
              ("fan", fan, pv((0, 5.2, hz)), "head"), ("mantle", mantle, pv((0, 0, 21.5)), "")]
    hp = {}
    z0 = 21.0
    for nm, sx in (("arm_l", 1), ("arm_r", -1)):
        pts = [(sx * 5.4, 0.0, z0), (sx * 9.2, -1.6, z0 - 1.8), (sx * 11.0, -3.6, z0 - 4.8), (sx * 10.6, -5.6, z0 - 7.2)]
        groups.append((nm, rLIMB(pts, [2.4, 2.2, 2.1, 2.0], "warden_dark") + rFIST_final((sx * 10.4, -6.4, z0 - 8.6), 2.9), pv((sx * 5.4, 0.0, z0)), ""))
        hp[nm] = (sx * 10.4, -8.6, z0 - 8.6)
    obj = bc.assemble("ew_boss_skotos_v01", groups)
    ranchors(obj, ey, (hp["arm_l"], hp["arm_r"]), (0, -7.4, 15.5), 9.0)
    for i, z in enumerate((4.0, 10.5, 16.4, 21.8)):
        bc.anchor(obj, "band_%d_anchor" % (i + 1), pv((0, -(9.4 - i * 1.7), z)), "", 2.0 * K)
    bc.anchor(obj, "fan_anchor", pv((0, 5.2, hz)), "head", 4.0 * K)
    return obj


VARIANTS = {"A": variant_a, "B": variant_b, "C": variant_c, "D": variant_d, "E": variant_e, "F": variant_f, "G": variant_g, "H": variant_h, "I": variant_i, "J": variant_j, "K": variant_k, "L": variant_l, "M": variant_m, "N": variant_n, "O": variant_o, "P": variant_p, "Q": variant_q, "R": variant_r, "S": variant_s, "T": variant_t}

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    key = (argv[0] if argv else "A").upper()
    bc.clear_scene()
    obj = build_final() if key == "FINAL" else VARIANTS[key]()
    mc.smooth(obj)
    print("TRIS", key, mc.tri_count(obj))
    import mathutils
    bpy = mc.bpy
    bpy.context.view_layer.update()
    cs = [o.matrix_world @ mathutils.Vector(c) for o in [obj] + list(obj.children_recursive) if o.type == "MESH" for c in o.bound_box]
    print("BBOX min", [round(min(c[i] for c in cs), 4) for i in range(3)], "max", [round(max(c[i] for c in cs), 4) for i in range(3)])
    bc.save_blend(obj, "skotos" if key == "FINAL" else "skotos_%s" % key.lower())
    if key == "FINAL":
        print("EXPORT", bc.export_glb(obj, "boss"))
