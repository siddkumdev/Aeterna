"""The Warden: three wild concepts (Durva 2026-11-02: "ethereal, out of this world, doesn't have to be person-like, way wilder").

Run one:  blender --factory-startup -b -P assets/generators/make_boss.py -- <key>      (saves assets/blend/boss_<key>.blend)
  unraveling   A. THE UNRAVELING: a broken stone ring that is a tear in reality, a giant slit eye inside, rune rings, orbiting monoliths, ribbon tentacles
  choir_spire  B. THE CHOIR SPIRE: a stepped purple spire crowned by a huge mask and halo, three rings of masks circle it, a gold bell swings
  night_bloom  C. THE NIGHT BLOOM: a giant flower of three petal layers around a dark eye-core, gold stamens, thorn vines, orbiting seed pods
(The first humanoid concept "Hollow Warden" was rejected as too basic and is replaced.)
Not animals. Colours: warden_deep / warden_dark (the Warden's purples), bone, stone, gold. Footprint 3 x 3 cells (0.15 m), height about 0.2 m,
budget 6000. Every concept has: crystal_anchor_1..3 (the three shield crystals on a ring at 2 cells), eye_anchor, summon_anchor.
Round 1 of the Warden (the old make_boss.py output boss_warden) stays in assets/blend for comparison only.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_characters as mc  # noqa: E402
import make_enemies2 as me  # noqa: E402

bc, V, seg, chain, flat, place, ring3d = mc.bc, mc.V, mc.seg, mc.chain, mc.flat, mc.place, me.ring3d


def mask(R, col="bone", slit="warden_dark", sub=2):
    """A small mask facing -Y, built at the origin: face ellipsoid, two slits, a brow."""
    P = [bc.blob("mask", R, (0, 0, 0), col, sub, (0.80, 0.50, 1.10)),
         bc.box("slit", (R * 0.22, R * 0.16, R * 0.30), (-R * 0.28, -R * 0.46, R * 0.18), slit),
         bc.box("slit", (R * 0.22, R * 0.16, R * 0.30), (R * 0.28, -R * 0.46, R * 0.18), slit),
         bc.box("brow", (R * 1.1, R * 0.12, R * 0.10), (0, -R * 0.42, R * 0.42), "warden_deep")]
    return P


def tentacle(start, end, sway, radii, col, segs=5, n=5):
    pts = []
    for i in range(n):
        t = i / (n - 1)
        x = start[0] + (end[0] - start[0]) * t + math.sin(t * 5 + sway) * 0.006 * (1 - t)
        y = start[1] + (end[1] - start[1]) * t + math.cos(t * 4 + sway) * 0.006 * (1 - t)
        z = start[2] + (end[2] - start[2]) * t
        pts.append(V((x, y, z)))
    rads = [radii[0] + (radii[1] - radii[0]) * i / (n - 1) for i in range(n)]
    return chain("tentacle", pts, rads, col, segs)


def crystal_anchors(obj, z):
    for i in range(3):
        a = math.radians(i * 120 + 90)
        bc.anchor(obj, "crystal_anchor_%d" % (i + 1), (math.cos(a) * 0.1000, math.sin(a) * 0.1000, z), "", 0.008)


# ----------------------------------------------------------------------------- A. THE UNRAVELING
def unraveling():
    cx, cz, R = 0.0, 0.135, 0.066
    root = []
    for i in range(14):  # broken stone ring: 14 arch blocks, three missing
        if i in (3, 4, 10):
            continue
        a = i * 360 / 14
        ar = math.radians(a)
        root.append(place(bc.box("arch", (0.0200, 0.0150, 0.0170), (0, 0, 0), "stone" if i % 2 else "stone_dark"), (0, -(a + 90), 0),
                          (cx + math.cos(ar) * R, 0, cz + math.sin(ar) * R)))
    root.append(place(bc.cone("void", 0.0600, 0.0600, 0.0040, (0, 0, 0), "warden_dark", 20), (90, 0, 0), (cx, 0.0060, cz)))
    for s in (-1, 1):  # swept bone horns up from the ring top
        root += chain("horn", [V((s * 0.0200, 0.0, cz + R + 0.004)), V((s * 0.0330, 0.0, cz + R + 0.018)), V((s * 0.0380, 0.0, cz + R + 0.038)), V((s * 0.0300, 0.0, cz + R + 0.052))],
                      [0.0070, 0.0058, 0.0040, 0.0004], "bone", 8)
    for i in range(10):  # ribbon tentacles pouring down from the lower arc to the ground
        a = math.radians(205 + i * 14)
        start = (cx + math.cos(a) * R, 0.0, cz + math.sin(a) * R)
        end = ((i - 4.5) * 0.0145, -0.012 + 0.010 * math.sin(i * 1.3), 0.0006)
        root += tentacle(start, end, i, (0.0050, 0.0008), "warden_deep" if i % 3 else ("shell_gold" if i % 2 else "warden_dark"), 5, 6)
    groups = [("", root, (0, 0, 0), "")]
    # the eye
    eye = [bc.blob("eyeball", 0.0220, (cx, -0.0090, cz), "bone", 3, (1.35, 0.45, 0.90)),
           bc.blob("iris", 0.0125, (cx, -0.0155, cz), "warden_deep", 2, (1.0, 0.40, 1.0)),
           bc.box("pupil", (0.0040, 0.0030, 0.0200), (cx, -0.0200, cz), "ink")]
    groups.append(("eye", eye, (cx, -0.0090, cz), ""))
    groups.append(("lid_top", [bc.blob("lid", 0.0240, (cx, -0.0120, cz + 0.0170), "warden_dark", 2, (1.40, 0.50, 0.45))], (cx, -0.0090, cz), ""))
    groups.append(("lid_bottom", [bc.blob("lid", 0.0240, (cx, -0.0120, cz - 0.0170), "warden_dark", 2, (1.40, 0.50, 0.45))], (cx, -0.0090, cz), ""))
    for nm, rad, col, tube in (("ring_a", 0.0500, "shell_gold", 0.0016), ("ring_b", 0.0400, "warden_deep", 0.0018), ("ring_c", 0.0300, "crystal_purple", 0.0014)):
        pts = ring3d((cx, -0.0030, cz), rad, tube, 20, col, "xz")
        for k in range(12):  # rune ticks on each ring
            a = math.radians(k * 30)
            pts.append(bc.box("rune", (0.0030, 0.0030, 0.0040), (cx + math.cos(a) * rad, -0.0030, cz + math.sin(a) * rad), "shell_gold" if col != "shell_gold" else "warden_dark"))
        groups.append((nm, pts, (cx, -0.0030, cz), ""))
    mono = []  # orbiting monoliths
    for i in range(7):
        a = math.radians(i * 360 / 7)
        mono.append(place(bc.box("monolith", (0.0070, 0.0060, 0.0220), (0, 0, 0), "stone" if i % 2 else "warden_deep"), (0, 0, math.degrees(a)),
                          (math.cos(a) * 0.0880, math.sin(a) * 0.0880, 0.0900 + 0.020 * math.sin(i * 1.9))))
    groups.append(("orbit", mono, (0, 0, 0.1100), ""))
    obj = bc.assemble("ew_boss_unraveling_v01", groups)
    crystal_anchors(obj, 0.135)
    bc.anchor(obj, "eye_anchor", (cx, -0.0210, cz), "eye", 0.006)
    bc.anchor(obj, "summon_anchor", (0, -0.0300, 0.0300), "", 0.008)
    return obj


# ----------------------------------------------------------------------------- B. THE CHOIR SPIRE
def choir_spire():
    root = [bc.cone("plinth", 0.0700, 0.0600, 0.0100, (0, 0, 0.0050), "stone_dark", 20)]
    for i in range(16):
        a = math.radians(i * 22.5)
        root.append(bc.box("tick", (0.0040, 0.0030, 0.0040), (math.cos(a) * 0.0650, math.sin(a) * 0.0650, 0.0105), "shell_gold", rot_z_deg=math.degrees(a)))
    z = 0.0100
    for rb, rt, h, col in ((0.0520, 0.0400, 0.0400, "warden_deep"), (0.0400, 0.0300, 0.0350, "warden_dark"), (0.0300, 0.0220, 0.0350, "warden_deep"),
                           (0.0220, 0.0150, 0.0300, "warden_dark"), (0.0150, 0.0085, 0.0280, "warden_deep")):
        root.append(bc.cone("tier", rb, rt, h, (0, 0, z + h / 2), col, 16))
        root.append(bc.cone("band", rt * 1.10, rt * 1.10, 0.0030, (0, 0, z + h), "shell_gold", 16))
        z += h
    top = z  # about 0.178
    # glowing runes carved down the front of the spire
    for k in range(5):
        root.append(bc.box("rune", (0.0030, 0.0020, 0.0100 - k * 0.0012), (0, -(0.0470 - k * 0.0072), 0.0420 + k * 0.0290), "crystal_purple"))
    groups = [("", root, (0, 0, 0), "")]
    head = [place(m, (0, 0, 0), (0, 0, 0)) for m in mask(0.0240)]
    for m in head:
        m.location = (m.location.x, m.location.y, m.location.z + top + 0.0290)
        bc.apply_transforms(m)
    for s in (-1, 1):  # crown of bone spikes
        head += chain("spike", [V((s * 0.0120, 0.0020, top + 0.0420)), V((s * 0.0210, 0.0030, top + 0.0560)), V((s * 0.0230, 0.0040, top + 0.0720))], [0.0042, 0.0030, 0.0003], "bone", 6)
    head.append(seg("spike", V((0, 0.0030, top + 0.0500)), V((0, 0.0040, top + 0.0800)), 0.0042, 0.0003, "bone", 6))
    groups.append(("head", head, (0, 0, top + 0.0290), ""))
    groups.append(("halo", ring3d((0, 0.0150, top + 0.0420), 0.0300, 0.0018, 16, "shell_gold", "xz") +
                   [bc.box("jewel", (0.0040, 0.0030, 0.0040), (math.cos(math.radians(k * 45)) * 0.0300, 0.0150, top + 0.0420 + math.sin(math.radians(k * 45)) * 0.0300), "crystal_purple") for k in range(8)],
                   (0, 0.0150, top + 0.0420), "head"))
    for idx, (zr, R, n, mr) in enumerate(((0.0600, 0.0780, 8, 0.0065), (0.1080, 0.0640, 7, 0.0062), (0.1500, 0.0500, 6, 0.0058))):
        ring = []
        for i in range(n):
            a = 360.0 * i / n + idx * 20
            ar = math.radians(a)
            for m in mask(mr, sub=1):
                place(m, (0, 0, a + 90), (math.cos(ar) * R, math.sin(ar) * R, zr))
                ring.append(m)
        ring += ring3d((0, 0, zr - 0.0070), R, 0.0010, 24, "shell_gold", "xy")
        groups.append(("choir_%d" % (idx + 1), ring, (0, 0, zr), ""))
    bell = chain("chain", [V((0.0440, 0, 0.1400)), V((0.0560, 0, 0.1320)), V((0.0660, 0, 0.1180))], [0.0014] * 3, "shell_gold", 5)
    bell += [bc.cone("bell", 0.0150, 0.0060, 0.0210, (0.0680, 0, 0.1040), "shell_gold", 12), bc.cone("lip", 0.0165, 0.0160, 0.0030, (0.0680, 0, 0.0920), "shell_copper", 12),
             bc.blob("clapper", 0.0045, (0.0680, 0, 0.0880), "warden_dark", 1)]
    groups.append(("bell", bell, (0.0440, 0, 0.1400), ""))
    obj = bc.assemble("ew_boss_choir_spire_v01", groups)
    crystal_anchors(obj, 0.1100)
    bc.anchor(obj, "eye_anchor", (0, -0.0140, top + 0.0340), "head", 0.006)
    bc.anchor(obj, "sigil_anchor", (0, -0.0450, 0.0900), "", 0.006)
    bc.anchor(obj, "summon_anchor", (0, -0.0800, 0.0200), "", 0.008)
    return obj


# ----------------------------------------------------------------------------- C. THE NIGHT BLOOM
def night_bloom():
    base = V((0, 0, 0.0780))
    root = [bc.blob("core", 0.0230, (0, 0, 0.0950), "warden_dark", 3, (1.0, 1.0, 0.95)),
            bc.blob("iris", 0.0105, (0, -0.0205, 0.0950), "shell_gold", 2, (1.0, 0.35, 1.0)),
            bc.box("pupil", (0.0030, 0.0030, 0.0150), (0, -0.0232, 0.0950), "ink")]
    for i in range(12):  # thorn vines down to the ground
        a = math.radians(i * 360 / 12 + 8)
        start = V((math.cos(a) * 0.0150, math.sin(a) * 0.0150, 0.0700))
        end = V((math.cos(a) * (0.0500 + 0.030 * ((i * 7) % 3) / 2), math.sin(a) * (0.0500 + 0.030 * ((i * 7) % 3) / 2), 0.0006))
        pts = [start, start + V((math.cos(a) * 0.0100, math.sin(a) * 0.0100, -0.0160)), start + V((math.cos(a) * 0.0220, math.sin(a) * 0.0220, -0.0300)), end]
        root += chain("vine", pts, [0.0048, 0.0038, 0.0028, 0.0006], "warden_dark" if i % 2 else "warden_deep", 5)
        root.append(seg("thorn", pts[1], pts[1] + V((math.cos(a + 0.8) * 0.0060, math.sin(a + 0.8) * 0.0060, 0.0040)), 0.0020, 0.0002, "bone", 4))
    groups = [("", root, (0, 0, 0), "")]
    for nm, n, Rr, t, cols, phase in (("petals_outer", 8, 0.0520, 78, ("warden_deep", "cloth_maroon"), 0), ("petals_mid", 7, 0.0400, 52, ("warden_dark", "warden_deep"), 20), ("petals_inner", 6, 0.0300, 26, ("cloth_maroon", "warden_dark"), 40)):
        P = []
        for i in range(n):
            phi = 360.0 * i / n + phase
            tr, pr = math.radians(t), math.radians(phi)
            d = V((math.sin(tr) * math.sin(pr), -math.sin(tr) * math.cos(pr), math.cos(tr)))
            c0 = base + d * Rr * 0.95
            petal = place(bc.blob("petal", Rr, (0, 0, 0), cols[i % 2], 2, (0.50, 0.12, 1.0)), (t, 0, phi), tuple(c0))
            P.append(petal)
            tip = base + d * Rr * 1.9
            P.append(seg("tip", base + d * Rr * 1.55, tip, 0.0045, 0.0002, "shell_gold", 5))
        groups.append((nm, P, tuple(base), ""))
    stam = []
    for i in range(10):
        a = math.radians(i * 36)
        pts = [V((math.cos(a) * 0.0100, math.sin(a) * 0.0100, 0.1080)), V((math.cos(a) * 0.0170, math.sin(a) * 0.0170, 0.1300)), V((math.cos(a) * 0.0200, math.sin(a) * 0.0200, 0.1500))]
        stam += chain("stamen", pts, [0.0012, 0.0010, 0.0007], "shell_gold", 4, ball_tip=(0.0032, "crystal_purple" if i % 2 else "shell_gold"))
    groups.append(("stamens", stam, (0, 0, 0.1080), ""))
    seeds = []
    for i in range(6):
        a = math.radians(i * 60)
        p = (math.cos(a) * 0.0980, math.sin(a) * 0.0980, 0.0700 + 0.0200 * math.sin(i * 2.1))
        seeds.append(bc.blob("pod", 0.0085, p, "warden_deep", 2, (1.0, 1.0, 1.25)))
        seeds.append(place(bc.box("socket", (0.0034, 0.0030, 0.0060), (0, 0, 0), "ink"), (0, 0, math.degrees(a) + 90), (math.cos(a) * 0.0880, math.sin(a) * 0.0880, p[2])))
        seeds.append(seg("stem", V(p), V((p[0] * 0.55, p[1] * 0.55, p[2] - 0.0120)), 0.0014, 0.0009, "warden_dark", 4))
    groups.append(("seeds", seeds, (0, 0, 0.0900), ""))
    obj = bc.assemble("ew_boss_night_bloom_v01", groups)
    crystal_anchors(obj, 0.1000)
    bc.anchor(obj, "eye_anchor", (0, -0.0235, 0.0950), "", 0.006)
    bc.anchor(obj, "bloom_anchor", (0, 0, 0.1200), "", 0.010)
    bc.anchor(obj, "summon_anchor", (0, -0.0600, 0.0200), "", 0.008)
    return obj


BOSSES = {"unraveling": unraveling, "choir_spire": choir_spire, "night_bloom": night_bloom}

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    key = argv[0] if argv else "unraveling"
    bc.clear_scene()
    obj = BOSSES[key]()
    mc.smooth(obj)
    print("TRIS", key, mc.tri_count(obj))
    bc.save_blend(obj, "boss_" + key)
