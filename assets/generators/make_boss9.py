"""The Warden, round 9: THE ECLIPSE BLOOM (the user, 2026-11-11: "eclipse empress + unravelling + night bloom, use those 3 together to create a new boss").
A forgotten god of the Dark Wood: the Empress's regal body and six relics, the Night Bloom's petals, thorn vines and stamens, the Unravelling's
broken stone ring, watching eye, bone horns and ribbons. Purples and gold only (the Warden's colours); no blue, fire only as anchors for the VFX.

Run one:  blender --factory-startup -b -P assets/generators/make_boss9.py -- <A|B|C|D>   (saves assets/blend/boss_eclipse_bloom_<key>_v01.blend)
  A  empress-led     her gown blooms at the hem, the broken ring and eye are her halo, ribbons pour from the ring
  B  bloom-led       a huge night bloom with the empress rising from its heart, thorn vines, eclipse corona behind her
  C  unravelling-led a giant broken ring around her with the eye over her crown, the gown hem unravels into ribbons, petals as a fan
  D  corona-flower   the halo IS the flower: petals radiate round the dark disc, ring shards orbit, ribbons and vines below
Budget 6000 triangles for a boss (CLAUDE.md); anchors: crystal_anchor_1..3, eye_anchor, sigil_anchor, bloom_anchor, halo_anchor, summon_anchor,
ribbon_anchor_1..3 (the VFX are built in Godot on these).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_characters as mc  # noqa: E402
import make_enemies2 as me  # noqa: E402

bc, V, seg, chain, flat, place, ring3d = mc.bc, mc.V, mc.seg, mc.chain, mc.flat, mc.place, me.ring3d
PI = math.pi


def ribbon(start, end, sway, radii, col, n=6):
    pts = []
    for i in range(n):
        t = i / (n - 1)
        pts.append(V((start[0] + (end[0] - start[0]) * t + math.sin(t * 5 + sway) * 0.006 * (1 - t),
                      start[1] + (end[1] - start[1]) * t + math.cos(t * 4 + sway) * 0.006 * (1 - t),
                      start[2] + (end[2] - start[2]) * t)))
    rads = [radii[0] + (radii[1] - radii[0]) * i / (n - 1) for i in range(n)]
    return chain("ribbon", pts, rads, col, 5)


def petals(base, tilt, n, R, cols, phase, tip=True, width=0.50):
    P = []
    b = V(base)
    for i in range(n):
        phi = 360.0 * i / n + phase
        tr, pr = math.radians(tilt), math.radians(phi)
        d = V((math.sin(tr) * math.sin(pr), -math.sin(tr) * math.cos(pr), math.cos(tr)))
        P.append(place(bc.blob("petal", R, (0, 0, 0), cols[i % 2], 2, (width, 0.12, 1.0)), (tilt, 0, phi), tuple(b + d * R * 0.95)))
        if tip:
            P.append(seg("tip", b + d * R * 1.55, b + d * R * 1.9, 0.0045, 0.0002, "shell_gold", 5))
    return P


def vines(n, r0, z0, reach, cols=("warden_dark", "warden_deep")):
    P = []
    for i in range(n):
        a = math.radians(i * 360 / n + 8)
        start = V((math.cos(a) * r0, math.sin(a) * r0, z0))
        rr = reach + 0.025 * ((i * 7) % 3) / 2
        pts = [start, start + V((math.cos(a) * 0.010, math.sin(a) * 0.010, -z0 * 0.25)), start + V((math.cos(a) * 0.022, math.sin(a) * 0.022, -z0 * 0.55)),
               V((math.cos(a) * rr, math.sin(a) * rr, 0.0006))]
        P += chain("vine", pts, [0.0048, 0.0038, 0.0028, 0.0006], cols[i % 2], 5)
        P.append(seg("thorn", pts[1], pts[1] + V((math.cos(a + 0.8) * 0.0060, math.sin(a + 0.8) * 0.0060, 0.0040)), 0.0020, 0.0002, "bone", 4))
    return P


def gown(tiers_n, hem_ribbons=False):
    tiers = [(0.0, 0.030, 0.074, 0.060, "warden_deep"), (0.028, 0.058, 0.062, 0.048, "warden_dark"),
             (0.056, 0.086, 0.050, 0.038, "warden_deep"), (0.084, 0.112, 0.040, 0.028, "warden_dark")][4 - tiers_n:] if tiers_n < 4 else None
    if tiers is None:
        tiers = [(0.0, 0.030, 0.074, 0.060, "warden_deep"), (0.028, 0.058, 0.062, 0.048, "warden_dark"),
                 (0.056, 0.086, 0.050, 0.038, "warden_deep"), (0.084, 0.112, 0.040, 0.028, "warden_dark")]
    P = []
    for t, (z0, z1, rb, rt, col) in enumerate(tiers):
        P.append(bc.cone("tier", rb, rt, z1 - z0, (0, 0, (z0 + z1) / 2), col, 16))
        P.append(bc.cone("band", rb * 1.03, rb * 1.03, 0.0035, (0, 0, z0 + 0.0020), "shell_gold", 16))
        if hem_ribbons and t == 0:
            continue
        for k in range(12):
            a = 2 * PI * k / 12 + t * 0.26
            tip_z = 0.0006 if z0 == 0.0 else z0 - 0.0035
            P.append(seg("hem", V((math.cos(a) * rb * 0.99, math.sin(a) * rb * 0.99, z0 + 0.0040)), V((math.cos(a) * rb * 1.07, math.sin(a) * rb * 1.07, tip_z)),
                         0.0042, 0.0002, "shell_gold" if k % 2 else "crystal_purple", 4))
    return P


def torso(z):
    """Torso, corset, collar and pauldrons with the shoulders at z + 0.052 (the empress's shoulders are 0.152 over the ground)."""
    P = [bc.cone("torso", 0.0270, 0.0200, 0.0420, (0, 0, z + 0.0320), "warden_dark", 12)]
    for k, dz in enumerate((0.018, 0.032, 0.046)):
        P.append(bc.cone("corset", 0.0272 - k * 0.0040, 0.0272 - k * 0.0040, 0.0020, (0, 0, z + dz), "shell_gold", 12))
    P += [bc.box("sigil", (0.0100, 0.0030, 0.0140), (0, -0.0225, z + 0.0330), "crystal_purple"), bc.box("sigil_gold", (0.0140, 0.0020, 0.0040), (0, -0.0232, z + 0.0330), "shell_gold"),
          bc.blob("shoulders", 0.0240, (0, 0, z + 0.0520), "warden_dark", 3, (2.0, 0.85, 0.50)),
          bc.cone("collar", 0.0210, 0.0120, 0.0100, (0, 0, z + 0.0600), "shell_gold", 12)]
    for s in (-1, 1):
        P.append(seg("pauldron", V((s * 0.0390, 0, z + 0.0560)), V((s * 0.0520, 0, z + 0.0800)), 0.0070, 0.0003, "shell_gold", 5))
    return P


def head(z, stamen_crown=False, third_eye=True):
    """The mask, circlet and crown, centred 0.09 over z (z = the shoulders' base)."""
    h = z + 0.090
    P = [bc.blob("mask", 0.0260, (0, 0, h), "bone", 3, (0.78, 0.62, 1.22)),
         bc.box("eye", (0.0080, 0.0030, 0.0040), (-0.0095, -0.0148, h + 0.0060), "warden_dark"), bc.box("eye", (0.0080, 0.0030, 0.0040), (0.0095, -0.0148, h + 0.0060), "warden_dark"),
         bc.box("brow", (0.0340, 0.0030, 0.0030), (0, -0.0155, h + 0.0120), "warden_deep"),
         bc.box("cheek", (0.0030, 0.0030, 0.0120), (-0.0120, -0.0158, h - 0.0080), "shell_gold"), bc.box("cheek", (0.0030, 0.0030, 0.0120), (0.0120, -0.0158, h - 0.0080), "shell_gold")]
    if third_eye:
        P.append(bc.box("gem", (0.0050, 0.0030, 0.0070), (0, -0.0160, h + 0.0210), "crystal_purple"))
    P += ring3d((0, 0, h + 0.0190), 0.0200, 0.0017, 14, "shell_gold", "xy")
    for k in range(9):
        a = 2 * PI * k / 9
        ln = 0.0260 if k % 3 == 0 else 0.0170
        P.append(seg("crown", V((math.cos(a) * 0.0200, math.sin(a) * 0.0200, h + 0.0190)), V((math.cos(a) * 0.0235, math.sin(a) * 0.0235, h + 0.0190 + ln)), 0.0030, 0.0002, "shell_gold", 5))
        if k % 3 == 0:
            P.append(bc.blob("jewel", 0.0027, (math.cos(a) * 0.0235, math.sin(a) * 0.0235, h + 0.0190 + ln), "crystal_purple", 1))
    if stamen_crown:  # the Bloom's stamens rise from the crown
        for i in range(8):
            a = math.radians(i * 45)
            pts = [V((math.cos(a) * 0.0140, math.sin(a) * 0.0140, h + 0.0200)), V((math.cos(a) * 0.0200, math.sin(a) * 0.0200, h + 0.0420)), V((math.cos(a) * 0.0240, math.sin(a) * 0.0240, h + 0.0620))]
            P += chain("stamen", pts, [0.0012, 0.0010, 0.0007], "shell_gold", 4, ball_tip=(0.0032, "crystal_purple" if i % 2 else "shell_gold"))
    for dx in (-0.0200, -0.0070, 0.0070, 0.0200):
        P += chain("veil", [V((dx, 0.0180, h + 0.0100)), V((dx * 1.4, 0.0300, h - 0.0200)), V((dx * 1.6, 0.0400, h - 0.0650)), V((dx * 1.7, 0.0480, h - 0.1200))], [0.0034, 0.0036, 0.0034, 0.0006],
                   "warden_dark" if abs(dx) < 0.01 else "shell_gold", 4)
    return P


def arms(z, groups):
    """Six arms with relics (sun, moon, hourglass, key, lantern, blade), shoulders at z + 0.052 over the ground."""
    def arm(name, S, E, H, relic):
        S = (S[0], S[1], S[2] + z)
        E = (E[0], E[1], E[2] + z)
        H = (H[0], H[1], H[2] + z)
        pts = [V(S), V(E), V(H)]
        P = chain("arm", pts, [0.0050, 0.0042, 0.0036], "warden_deep", 6)
        P.append(bc.blob("hand", 0.0046, pts[-1], "bone", 1))
        for dx in (-0.0020, 0.0, 0.0020):
            P.append(seg("finger", pts[-1], pts[-1] + V((dx, -0.0050, 0.0070)), 0.0013, 0.0003, "bone", 4))
        P += relic(V(H) + V((0, -0.0040, 0.0090)))
        groups.append((name, P, tuple(S), ""))

    def sun(p):
        c0 = p + V((0, 0, 0.0100))
        P = [bc.blob("sun", 0.0130, c0, "fire_yellow", 2)]
        for k in range(10):
            a = 2 * PI * k / 10
            P.append(seg("sunray", c0 + V((math.cos(a) * 0.0130, 0, math.sin(a) * 0.0130)), c0 + V((math.cos(a) * 0.0220, 0, math.sin(a) * 0.0220)), 0.0024, 0.0002, "fire_red", 4))
        return P

    def moon(p):
        pts = [(math.cos(math.radians(a)) * 0.0150, p.y, p.z + 0.0100 + math.sin(math.radians(a)) * 0.0150) for a in range(-110, 111, 22)]
        inner = [(math.cos(math.radians(a)) * 0.0100 + 0.0070, p.y, p.z + 0.0100 + math.sin(math.radians(a)) * 0.0100) for a in range(110, -111, -22)]
        return [flat("moon", [(p.x + q[0], q[1], q[2]) for q in pts + inner], 0.0040, "bone")]

    def hourglass(p):
        return [bc.cone("glass", 0.0070, 0.0010, 0.0090, p + V((0, 0, 0.0145)), "crystal_purple", 8), bc.cone("glass", 0.0010, 0.0070, 0.0090, p + V((0, 0, 0.0055)), "crystal_purple", 8),
                bc.cone("capt", 0.0085, 0.0085, 0.0014, p + V((0, 0, 0.0200)), "shell_gold", 8), bc.cone("capb", 0.0085, 0.0085, 0.0014, p, "shell_gold", 8)]

    def key(p):
        P = [seg("shaft", p + V((0, 0, -0.0060)), p + V((0, 0, 0.0220)), 0.0014, 0.0014, "shell_gold", 6)]
        P += ring3d((p.x, p.y, p.z + 0.0260), 0.0050, 0.0013, 8, "shell_gold", "xz")
        return P

    def lantern(p):
        return [bc.box("cage", (0.0090, 0.0090, 0.0120), p + V((0, 0, 0.0080)), "shell_copper"), bc.cone("roof", 0.0080, 0.0005, 0.0070, p + V((0, 0, 0.0185)), "warden_dark", 4),
                bc.box("socket", (0.0060, 0.0060, 0.0080), p + V((0, 0, 0.0080)), "ink")]

    def blade(p):
        pts = [p + V((0, 0, -0.0050)), p + V((0.0020, -0.0050, 0.0140)), p + V((0.0000, -0.0100, 0.0300)), p + V((-0.0060, -0.0120, 0.0420))]
        return chain("blade", pts, [0.0018, 0.0034, 0.0026, 0.0003], "bone", 5) + [bc.box("guard", (0.0120, 0.0020, 0.0020), tuple(pts[0] + V((0, 0, 0.0050))), "shell_gold")]

    arm("arm_ur", (-0.0230, 0, 0.0060), (-0.0480, -0.0060, 0.0230), (-0.0640, -0.0120, 0.0430), sun)
    arm("arm_ul", (0.0230, 0, 0.0060), (0.0480, -0.0060, 0.0230), (0.0640, -0.0120, 0.0430), moon)
    arm("arm_mr", (-0.0240, 0, -0.0020), (-0.0580, -0.0090, -0.0020), (-0.0780, -0.0200, -0.0020), hourglass)
    arm("arm_ml", (0.0240, 0, -0.0020), (0.0580, -0.0090, -0.0020), (0.0780, -0.0200, -0.0020), key)
    arm("arm_lr", (-0.0220, 0, -0.0100), (-0.0500, -0.0140, -0.0270), (-0.0680, -0.0260, -0.0470), lantern)
    arm("arm_ll", (0.0220, 0, -0.0100), (0.0500, -0.0140, -0.0270), (0.0680, -0.0260, -0.0470), blade)


def broken_ring(cx, cz, R, missing, stones=14):
    P = []
    for i in range(stones):
        if i in missing:
            continue
        a = i * 360 / stones
        ar = math.radians(a)
        P.append(place(bc.box("arch", (0.0200, 0.0150, 0.0170), (0, 0, 0), "stone" if i % 2 else "stone_dark"), (0, -(a + 90), 0), (cx + math.cos(ar) * R, 0, cz + math.sin(ar) * R)))
    return P


def runes(cx, cy, cz, rads):
    G = []
    for nm, rad, col, tube in zip(("ring_a", "ring_b"), rads, ("shell_gold", "crystal_purple"), (0.0016, 0.0014)):
        pts = ring3d((cx, cy, cz), rad, tube, 20, col, "xz")
        for k in range(12):
            a = math.radians(k * 30)
            pts.append(bc.box("rune", (0.0030, 0.0030, 0.0040), (cx + math.cos(a) * rad, cy, cz + math.sin(a) * rad), "shell_gold" if col != "shell_gold" else "warden_dark"))
        G.append((nm, pts, (cx, cy, cz), ""))
    return G


def eye(cx, cy, cz, R=0.0200):
    E = [bc.blob("eyeball", R, (cx, cy, cz), "bone", 3, (1.35, 0.45, 0.90)), bc.blob("iris", R * 0.57, (cx, cy - 0.0060, cz), "warden_deep", 2, (1.0, 0.40, 1.0)),
         bc.box("pupil", (0.0036, 0.0030, R * 0.9), (cx, cy - 0.0105, cz), "ink")]
    return [("eye", E, (cx, cy, cz), ""), ("lid_top", [bc.blob("lid", R * 1.1, (cx, cy - 0.0030, cz + R * 0.77), "warden_dark", 2, (1.40, 0.50, 0.45))], (cx, cy, cz), ""),
            ("lid_bottom", [bc.blob("lid", R * 1.1, (cx, cy - 0.0030, cz - R * 0.77), "warden_dark", 2, (1.40, 0.50, 0.45))], (cx, cy, cz), "")]


def horns(cz, R, s0=0.020):
    P = []
    for s in (-1, 1):
        P += chain("horn", [V((s * s0, 0.0, cz + R + 0.004)), V((s * 0.0330, 0.0, cz + R + 0.018)), V((s * 0.0380, 0.0, cz + R + 0.038)), V((s * 0.0300, 0.0, cz + R + 0.052))],
                   [0.0070, 0.0058, 0.0040, 0.0004], "bone", 8)
    return P


def orbit(kind, rad=0.1080, n=8, z=0.0900):
    P = []
    for k in range(n):
        a = 2 * PI * k / n
        p = V((math.cos(a) * rad, math.sin(a) * rad, z + 0.0300 * math.sin(k * 1.7)))
        if kind == "shard" or k % 2 == 0:
            P.append(seg("shard", p + V((0, 0, -0.0090)), p + V((0, 0, 0.0090)), 0.0042, 0.0002, "crystal_purple", 4))
            P.append(seg("shard", p + V((0, 0, -0.0090)), p + V((0, 0, -0.0160)), 0.0030, 0.0002, "warden_deep", 4))
        else:
            P.append(bc.blob("pod", 0.0085, tuple(p), "warden_deep", 2, (1.0, 1.0, 1.25)))
            P.append(place(bc.box("socket", (0.0034, 0.0030, 0.0060), (0, 0, 0), "ink"), (0, 0, math.degrees(a) + 90), (math.cos(a) * (rad - 0.010), math.sin(a) * (rad - 0.010), p.z)))
    return P


def disc_halo(cz, R=0.0600, y=0.0240, rays=20, petal_rays=False):
    H = [place(bc.cone("disc", R, R, 0.0040, (0, 0, 0), "warden_dark", 20), (90, 0, 0), (0, y, cz))]
    H += ring3d((0, y - 0.0030, cz), R * 1.03, 0.0020, 24, "shell_gold", "xz")
    for k in range(rays):
        a = 2 * PI * k / rays
        L = 0.0200 if k % 2 == 0 else 0.0120
        s0 = V((math.cos(a) * R * 1.06, y - 0.0030, cz + math.sin(a) * R * 1.06))
        s1 = V((math.cos(a) * (R * 1.06 + L), y - 0.0030, cz + math.sin(a) * (R * 1.06 + L)))
        H.append(seg("ray", s0, s1, 0.0034, 0.0002, "shell_gold" if k % 2 else "crystal_purple", 4))
    return H


def petal_halo(cz, R=0.0600, y=0.0240, n=14):
    """Petals fanned flat behind the head in two layers, round the dark disc: the eclipse corona drawn as a flower."""
    H = [place(bc.cone("disc", R, R, 0.0040, (0, 0, 0), "warden_dark", 20), (90, 0, 0), (0, y, cz))]
    H += ring3d((0, y - 0.0030, cz), R * 1.03, 0.0020, 24, "shell_gold", "xz")
    for layer, (cnt, L, off, cols) in enumerate(((n, 0.0420, 0.0, ("warden_deep", "cloth_maroon")), (n, 0.0300, PI / n, ("warden_dark", "warden_deep")))):
        for k in range(cnt):
            a = 2 * PI * k / cnt + off
            c = V((math.cos(a) * (R + L * 0.55), y - 0.0020 - layer * 0.0020, cz + math.sin(a) * (R + L * 0.55)))
            H.append(place(bc.blob("petal", L, (0, 0, 0), cols[k % 2], 2, (1.0, 0.10, 0.34)), (0, 0, 0), tuple(c)))
            H[-1].rotation_euler = (0, -a, 0)
            H.append(seg("tip", V((math.cos(a) * (R + L * 1.2), y - 0.0030, cz + math.sin(a) * (R + L * 1.2))), V((math.cos(a) * (R + L * 1.6), y - 0.0030, cz + math.sin(a) * (R + L * 1.6))), 0.0034, 0.0002, "shell_gold", 4))
    return H


def crystal_anchors(obj, z):
    for i in range(3):
        a = math.radians(i * 120 + 90)
        bc.anchor(obj, "crystal_anchor_%d" % (i + 1), (math.cos(a) * 0.1000, math.sin(a) * 0.1000, z), "", 0.008)


def finish(obj, shoulder_z, halo_c, ring_c=None):
    crystal_anchors(obj, 0.1000)
    h = shoulder_z + 0.0900
    bc.anchor(obj, "eye_anchor", (0, -0.0170, h + 0.0210), "head", 0.005)
    bc.anchor(obj, "sigil_anchor", (0, -0.0250, shoulder_z - 0.0190), "", 0.006)
    bc.anchor(obj, "bloom_anchor", (0, 0, 0.0300), "", 0.010)
    bc.anchor(obj, "halo_anchor", halo_c, "", 0.010)
    bc.anchor(obj, "summon_anchor", (0, -0.0900, 0.0200), "", 0.008)
    for i in range(3):
        a = math.radians(-60 + i * 60)
        bc.anchor(obj, "ribbon_anchor_%d" % (i + 1), (math.cos(a) * 0.0500 * 0.0 + (i - 1) * 0.030, 0.030, 0.0150), "", 0.006)


# ============================================================================= the four variants
def variant_a():
    """Empress-led: a full gown whose hem blooms into petals; the broken ring with the eye is her halo; ribbons pour from the ring's lower arc."""
    sz = 0.1000  # shoulders' base over the ground (the empress's torso starts 0.100)
    root = gown(4) + torso(sz) + vines(8, 0.060, 0.030, 0.100)
    root += petals((0, 0, 0.012), 80, 8, 0.0600, ("warden_deep", "cloth_maroon"), 0)
    root += petals((0, 0, 0.030), 62, 7, 0.0460, ("warden_dark", "warden_deep"), 20, tip=False)
    cz, R = 0.1950, 0.0620
    ring = broken_ring(0, cz, R, (3, 4, 10))
    ring.append(place(bc.cone("void", 0.0560, 0.0560, 0.0040, (0, 0, 0), "warden_dark", 20), (90, 0, 0), (0, 0.0300, cz)))
    ring += [place(x, (0, 0, 0), x.location) for x in ()]
    for x in ring:
        x.location.y += 0.0290
    root += ring + horns(cz, R)
    for i in range(10):
        a = math.radians(205 + i * 14)
        root += ribbon((math.cos(a) * R, 0.0290, cz + math.sin(a) * R), ((i - 4.5) * 0.0160, 0.0500, 0.0006), i, (0.0050, 0.0008), "warden_deep" if i % 3 else ("shell_gold" if i % 2 else "warden_dark"))
    groups = [("", root, (0, 0, 0), "")]
    groups.append(("head", head(sz, stamen_crown=True), (0, 0, sz + 0.0700), ""))
    groups += eye(0, 0.0330, cz, 0.0190)
    groups += [(n, p, c, "") for n, p, c, _ in runes(0, 0.0300, cz, (0.0500, 0.0400))]
    arms(sz, groups)
    groups.append(("orbit", orbit("pod", 0.1100, 8, 0.0900), (0, 0, 0.1000), ""))
    obj = bc.assemble("ew_boss_eclipse_bloom_a_v01", groups)
    finish(obj, sz, (0, 0.0300, cz))
    return obj


def variant_b():
    """Bloom-led: a huge night bloom; the empress rises from its heart; thorn vines; the eclipse corona behind her."""
    sz = 0.0700
    root = gown(2, False)[:0]
    root += [bc.cone("calyx", 0.0460, 0.0300, 0.0420, (0, 0, 0.0210), "warden_dark", 14), bc.cone("calyxband", 0.0470, 0.0470, 0.0035, (0, 0, 0.0040), "shell_gold", 14)]
    root += torso(sz) + vines(12, 0.015, 0.0700, 0.0700)
    base = (0, 0, 0.0500)
    groups = [("", root, (0, 0, 0), "")]
    for nm, n, Rr, t, cols, ph in (("petals_outer", 8, 0.0700, 80, ("warden_deep", "cloth_maroon"), 0), ("petals_mid", 7, 0.0560, 56, ("warden_dark", "warden_deep"), 20),
                                   ("petals_inner", 6, 0.0420, 30, ("cloth_maroon", "warden_dark"), 40)):
        groups.append((nm, petals(base, t, n, Rr, cols, ph), base, ""))
    groups.append(("head", head(sz, stamen_crown=True), (0, 0, sz + 0.0700), ""))
    cz = 0.1700
    groups.append(("halo", disc_halo(cz, 0.0600, 0.0300, 22), (0, 0.0300, cz), "head"))
    arms(sz, groups)
    groups.append(("orbit", orbit("pod", 0.1100, 8, 0.0700), (0, 0, 0.0900), ""))
    obj = bc.assemble("ew_boss_eclipse_bloom_b_v01", groups)
    finish(obj, sz, (0, 0.0300, cz))
    return obj


def variant_c():
    """Unravelling-led: a giant broken ring round her, the watching eye over her crown, the gown hem unravelling into ribbons, petals as a fan behind."""
    sz = 0.1000
    root = gown(4, hem_ribbons=True) + torso(sz)
    for i in range(14):
        a = math.radians(i * 360 / 14)
        root += ribbon((math.cos(a) * 0.0740, math.sin(a) * 0.0740, 0.0300), (math.cos(a) * (0.0900 + 0.020 * (i % 3) / 2), math.sin(a) * (0.0900 + 0.020 * (i % 3) / 2), 0.0006), i, (0.0050, 0.0008),
                       "warden_deep" if i % 3 else ("shell_gold" if i % 2 else "warden_dark"))
    cz, R = 0.1500, 0.0950
    ring = broken_ring(0, cz, R, (2, 3, 9))
    for x in ring:
        x.location.y += 0.0400
    root += ring + horns(cz, R, 0.0260)
    groups = [("", root, (0, 0, 0), "")]
    groups.append(("head", head(sz), (0, 0, sz + 0.0700), ""))
    groups += eye(0, 0.0280, 0.2650, 0.0220)
    groups.append(("fan", petals((0, 0.0400, cz), 90, 11, 0.0680, ("warden_deep", "cloth_maroon"), 0, tip=False), (0, 0.0400, cz), ""))
    groups += [(n, p, c, "") for n, p, c, _ in runes(0, 0.0420, cz, (0.0800, 0.0680))]
    arms(sz, groups)
    groups.append(("orbit", orbit("shard", 0.1200, 9, 0.0900), (0, 0, 0.1000), ""))
    obj = bc.assemble("ew_boss_eclipse_bloom_c_v01", groups)
    finish(obj, sz, (0, 0.0400, cz))
    return obj


def variant_d():
    """Corona-flower: the halo IS the flower, petals round the dark disc; ring shards orbit; ribbons and vines below."""
    sz = 0.1000
    root = gown(4) + torso(sz) + vines(10, 0.062, 0.030, 0.110)
    for i in range(8):
        a = math.radians(-70 + i * 20)
        root += ribbon((math.cos(a) * 0.0650, math.sin(a) * 0.0650 * 0.0 - 0.0100, 0.0300), (math.cos(a) * 0.1000, -0.0600 - 0.010 * (i % 2), 0.0006), i, (0.0050, 0.0008), "warden_deep" if i % 2 else "shell_gold")
    groups = [("", root, (0, 0, 0), "")]
    groups.append(("head", head(sz, stamen_crown=True), (0, 0, sz + 0.0700), ""))
    cz = 0.1950
    groups.append(("halo", petal_halo(cz, 0.0620, 0.0300, 14), (0, 0.0300, cz), "head"))
    groups += eye(0, 0.0270, cz, 0.0210)
    arms(sz, groups)
    shards = broken_ring(0, 0, 0.0900, (1, 2, 5, 6, 9), 12)
    for x in shards:
        x.location.z += 0.1000
        x.scale = (0.8, 0.8, 0.8)
    groups.append(("orbit", shards + orbit("shard", 0.1100, 6, 0.0900), (0, 0, 0.1000), ""))
    obj = bc.assemble("ew_boss_eclipse_bloom_d_v01", groups)
    finish(obj, sz, (0, 0.0300, cz))
    return obj


VARIANTS = {"A": variant_a, "B": variant_b, "C": variant_c, "D": variant_d}

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    key = (argv[0] if argv else "A").upper()
    bc.clear_scene()
    obj = VARIANTS[key]()
    mc.smooth(obj)
    print("TRIS", key, mc.tri_count(obj))
    bc.save_blend(obj, "boss_eclipse_bloom_%s_v01" % key.lower())
