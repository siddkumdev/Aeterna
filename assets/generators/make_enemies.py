"""Enemy concepts, round 1 (Durva 2026-11-01): new looks for the existing roster, otherworldly tiny mobs, not animals.

Run one:  blender --factory-startup -b -P assets/generators/make_enemies.py -- <key>   (saves assets/blend/enemy_<key>.blend)

  Grunt    -> stumpling   (walking tree stump: moss, root legs, branch arms)
  Scout    -> shade       (hooded cloak, bone mask, trailing scarf tails; fast and thin)
  Splitter -> sporecap    (spotted cap on a stem; sporelet = the small half it splits into)
  Wisp     -> lantern_wisp (floating teardrop spirit with petal wings; flyer)
  Tunneler -> drillstone  (stone shell, copper drill nose, claws)
Only the roster slot is from the spec; the creatures are original. The Fog variant stays a shader tint of the Grunt.
Front is -Y. Parts (no rig): root, arm_l / arm_r (shoulder pivots), plus tail / wings / drill where the creature has them.
Magic glows are VFX: eyes are dark sockets with small red-orange pupils; anchors mark where effects attach.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_characters as mc  # noqa: E402

bc, V, seg, chain, flat = mc.bc, mc.V, mc.seg, mc.chain, mc.flat


def eyes(z, y, dx, r, col="ink", pupil="fire_red"):
    out = []
    for s in (-1, 1):
        out.append(bc.blob("eye", r, (s * dx, y, z), col, 1, (0.85, 0.5, 1.3)))
        out.append(bc.blob("pupil", r * 0.42, (s * dx, y - r * 0.28, z - r * 0.1), pupil, 1))
    return out


def arm(side, shoulder, elbow, hand, col, hand_col=None, r=0.0028):
    s = side
    pts = [V((s * shoulder[0], shoulder[1], shoulder[2])), V((s * elbow[0], elbow[1], elbow[2])), V((s * hand[0], hand[1], hand[2]))]
    parts = chain("arm", pts, [r * 1.15, r, r * 0.85], col, 8)
    parts.append(bc.blob("fist", r * 1.25, pts[-1], hand_col or col, 1))
    return parts, tuple(pts[0])


def stumpling():
    root = []
    root += [bc.cone("trunk", 0.0140, 0.0122, 0.027, (0, 0, 0.0215), "wood_dark", 12),
             bc.cone("cut", 0.0124, 0.0124, 0.0024, (0, 0, 0.0362), "wood_light", 12),
             bc.cone("ring", 0.0082, 0.0082, 0.0026, (0, 0, 0.0364), "wood_mid", 12),
             bc.cone("core", 0.0036, 0.0036, 0.0028, (0, 0, 0.0365), "wood_light", 10)]
    for dx in (-1, 1):  # root legs
        root += chain("root", [V((dx * 0.0060, 0.000, 0.0100)), V((dx * 0.0090, -0.0030, 0.0055)), V((dx * 0.0100, -0.0058, 0.0008))],
                      [0.0030, 0.0024, 0.0016], "wood_dark", 8)
        root.append(bc.blob("toe", 0.0030, (dx * 0.0100, -0.0058, 0.0014), "wood_mid", 1, (1.0, 1.2, 0.5)))
    for x, y, rr, col in ((-0.006, 0.002, 0.0040, "leaf_green"), (0.003, -0.003, 0.0045, "leaf_light"), (0.007, 0.004, 0.0036, "leaf_green"), (-0.002, 0.006, 0.0034, "leaf_dark")):
        root.append(bc.blob("moss", rr, (x, y, 0.0385), col, 1, (1, 1, 0.7)))
    root += chain("sprout", [V((0.001, -0.001, 0.0385)), V((0.001, -0.001, 0.0455)), V((0.0035, -0.001, 0.0480))], [0.0008, 0.0007, 0.0005], "leaf_green", 5)
    root.append(bc.blob("leaf", 0.0035, (0.0060, -0.001, 0.0485), "leaf_light", 1, (1.2, 0.3, 0.7)))
    root.append(bc.blob("knot_nose", 0.0026, (0, -0.0125, 0.0230), "wood_mid", 1))
    root += eyes(0.0265, -0.0118, 0.0054, 0.0034)
    for i, x in enumerate((-0.0036, 0.0, 0.0036)):  # jagged mouth
        root.append(bc.box("tooth", (0.0026, 0.0014, 0.0026 if i == 1 else 0.0020), (x, -0.0122, 0.0155), "ink"))
    groups = [("", root, (0, 0, 0), "")]
    for s, nm in ((-1, "r"), (1, "l")):
        p, pv = arm(s, (0.0132, 0, 0.0285), (0.0185, -0.0020, 0.0200), (0.0205, -0.0050, 0.0120), "wood_dark", "wood_mid", 0.0030)
        p += [seg("twig", V((s * 0.0205, -0.0050, 0.0120)), V((s * 0.0235, -0.0070, 0.0140)), 0.0010, 0.0003, "wood_dark", 5),
              seg("twig", V((s * 0.0205, -0.0050, 0.0120)), V((s * 0.0222, -0.0085, 0.0095)), 0.0010, 0.0003, "wood_dark", 5)]
        groups.append(("arm_" + nm, p, pv, ""))
    return groups, {"eye_anchor": (0, -0.0125, 0.0265)}


def shade():
    root = []
    root += [bc.cone("cloak", 0.0120, 0.0040, 0.0230, (0, 0, 0.0150), "ink", 12)]
    for i in range(6):  # ragged hem points
        a = math.radians(i * 60 + 15)
        root.append(seg("rag", V((math.cos(a) * 0.0100, math.sin(a) * 0.0100, 0.0060)), V((math.cos(a) * 0.0130, math.sin(a) * 0.0130, 0.0004)), 0.0030, 0.0, "ink", 4))
    root += [bc.blob("hood", 0.0100, (0, 0.0006, 0.0300), "ink", 2, (1.0, 0.95, 1.08)),
             bc.blob("mask", 0.0070, (0, -0.0072, 0.0290), "bone", 2, (0.95, 0.42, 1.1))]
    for s in (-1, 1):
        root.append(seg("hood_point", V((s * 0.0050, 0, 0.0380)), V((s * 0.0080, 0.0006, 0.0470)), 0.0030, 0.0, "ink", 4))
        root.append(bc.box("slit", (0.0030, 0.0014, 0.0014), (s * 0.0030, -0.0106, 0.0304), "ink"))
        root.append(bc.box("glint", (0.0016, 0.0010, 0.0008), (s * 0.0030, -0.0112, 0.0304), "lantern_glow"))
        root.append(bc.box("stripe", (0.0016, 0.0010, 0.0036), (s * 0.0048, -0.0102, 0.0262), "roof_terracotta"))
    for s in (-1, 1):  # thin skittering legs
        root += chain("leg", [V((s * 0.0036, 0, 0.0090)), V((s * 0.0060, -0.0030, 0.0050)), V((s * 0.0062, -0.0062, 0.0006))], [0.0014, 0.0011, 0.0008], "ink", 6)
        root.append(bc.blob("toe", 0.0012, (s * 0.0062, -0.0062, 0.0006), "bone", 1, (1, 1.5, 0.6)))
    groups = [("", root, (0, 0, 0), "")]
    tail = []  # trailing scarf tails
    for off, col in ((-0.0020, "fire_red"), (0.0020, "roof_orange")):
        tail += chain("scarf", [V((off, 0.0070, 0.0250)), V((off, 0.0110, 0.0230)), V((off + 0.001, 0.0160, 0.0240)), V((off, 0.0205, 0.0205))], [0.0013, 0.0012, 0.0011, 0.0005], col, 6)
    groups.append(("scarf", tail, (0, 0.0070, 0.0250), ""))
    for s, nm in ((-1, "r"), (1, "l")):
        p, pv = arm(s, (0.0090, 0, 0.0215), (0.0120, -0.0030, 0.0165), (0.0130, -0.0070, 0.0140), "ink", "bone", 0.0018)
        p += [seg("claw", V((s * 0.0130, -0.0070, 0.0140)), V((s * 0.0136, -0.0100, 0.0125)), 0.0009, 0.0002, "bone", 4),
              seg("claw", V((s * 0.0130, -0.0070, 0.0140)), V((s * 0.0112, -0.0100, 0.0128)), 0.0009, 0.0002, "bone", 4)]
        groups.append(("arm_" + nm, p, pv, ""))
    return groups, {"eye_anchor": (0, -0.0112, 0.0304)}


def sporecap(k=1.0):
    def S(v):
        return v * k
    root = [bc.cone("stem", S(0.0095), S(0.0075), S(0.0200), (0, 0, S(0.0110)), "wall_cream", 12),
            bc.blob("cap", S(0.0175), (0, 0, S(0.0255)), "roof_terracotta", 2, (1.0, 1.0, 0.62)),
            bc.cone("gills", S(0.0160), S(0.0070), S(0.0030), (0, 0, S(0.0205)), "wood_light", 14)]
    for x, y, rr in ((0.0075, -0.005, 0.0034), (-0.0070, -0.0070, 0.0030), (0.0010, -0.0120, 0.0030), (-0.0040, 0.0060, 0.0036), (0.0095, 0.0050, 0.0026)):
        z = 0.0255 + 0.0108 * (1 - (x * x + y * y) / (0.0165 ** 2))
        root.append(bc.blob("dot", S(rr), (S(x), S(y), S(z)), "wall_cream", 1, (1, 1, 0.45)))
    for s in (-1, 1):
        root.append(bc.blob("eye", S(0.0022), (S(s * 0.0034), S(-0.0080), S(0.0150)), "ink", 1, (0.85, 0.5, 1.4)))
        root.append(bc.blob("cheek", S(0.0016), (S(s * 0.0058), S(-0.0074), S(0.0122)), "flower_pink", 1, (1, 0.4, 0.8)))
        root.append(bc.blob("foot", S(0.0036), (S(s * 0.0042), S(-0.0016), S(0.0012)), "wood_light", 1, (1, 1.3, 0.5)))
    root.append(bc.box("mouth", (S(0.0030), S(0.0012), S(0.0010)), (0, S(-0.0090), S(0.0116)), "ink"))
    groups = [("", root, (0, 0, 0), "")]
    for s, nm in ((-1, "r"), (1, "l")):
        arm_ = [bc.blob("arm", S(0.0028), (S(s * 0.0098), 0, S(0.0130)), "wall_cream", 1, (1.4, 0.9, 0.9))]
        groups.append(("arm_" + nm, arm_, (S(s * 0.0090), 0, S(0.0135)), ""))
    return groups, {"eye_anchor": (0, S(-0.0082), S(0.0150))}


def sporelet():
    return sporecap(0.55)


def lantern_wisp():
    root = [bc.blob("body", 0.0120, (0, 0, 0.0300), "wisp_glow", 2, (1.0, 1.0, 1.12)),
            bc.blob("belly", 0.0078, (0, -0.0040, 0.0275), "flower_pink", 2, (1.0, 0.7, 1.0))]
    root += chain("tail", [V((0, 0.0040, 0.0210)), V((0, 0.0075, 0.0150)), V((0, 0.0090, 0.0095)), V((0, 0.0070, 0.0040)), V((0, 0.0050, 0.0003))],
                  [0.0075, 0.0052, 0.0034, 0.0020, 0.0004], "wisp_glow", 8)
    root += chain("curl", [V((0, 0.0010, 0.0410)), V((0, 0.0020, 0.0470)), V((0.0020, 0.0010, 0.0510)), V((0.0042, -0.0010, 0.0500))], [0.0020, 0.0016, 0.0012, 0.0005], "wisp_glow", 6)
    for s in (-1, 1):
        root.append(bc.blob("eye", 0.0030, (s * 0.0046, -0.0108, 0.0310), "ink", 1, (0.8, 0.5, 1.4)))
        root.append(bc.blob("spark", 0.0010, (s * 0.0042, -0.0126, 0.0322), "bone", 1))
        root.append(bc.blob("cheek", 0.0020, (s * 0.0082, -0.0090, 0.0262), "cloth_coral", 1, (1, 0.4, 0.8)))
    root.append(bc.box("mouth", (0.0018, 0.0010, 0.0012), (0, -0.0118, 0.0250), "ink"))
    groups = [("", root, (0, 0, 0), "")]
    for s, nm in ((-1, "r"), (1, "l")):  # petal wings, flat
        b = V((s * 0.0105, 0.0040, 0.0320))
        P = lambda u, v, s=s, b=b: (b.x + s * u, b.y + 0.4 * u, b.z + v)
        k = 0.0100
        w = [flat("petal", [P(0, 0), P(.5 * k, .8 * k), P(1.3 * k, 1.1 * k), P(1.6 * k, .4 * k), P(1.0 * k, -.3 * k), P(.3 * k, -.2 * k)], 0.0007, "wall_cream"),
             flat("petal_low", [P(0, -.1 * k), P(.9 * k, -.4 * k), P(1.0 * k, -1.0 * k), P(.4 * k, -.9 * k)], 0.0007, "flower_pink")]
        groups.append(("wing_" + nm, w, tuple(b), ""))
    for s, nm in ((-1, "r"), (1, "l")):
        groups.append(("arm_" + nm, [bc.blob("arm", 0.0030, (s * 0.0118, -0.0020, 0.0230), "wisp_glow", 1, (1.3, 1.0, 0.9))], (s * 0.0105, 0, 0.0245), ""))
    return groups, {"eye_anchor": (0, -0.0110, 0.0310), "glow_anchor": (0, 0, 0.0300)}


def drillstone():
    root = [bc.blob("shell", 0.0135, (0, 0.0020, 0.0165), "stone", 2, (1.0, 1.0, 0.82)),
            bc.cone("band", 0.0130, 0.0126, 0.0024, (0, 0.0020, 0.0100), "stone_dark", 12)]
    for a, z in ((40, 0.0225), (140, 0.0225), (230, 0.0210), (320, 0.0210), (90, 0.0270)):
        rr = 0.0124 if z < 0.025 else 0.0040
        root.append(bc.blob("plate", 0.0036, (math.cos(math.radians(a)) * rr * 0.9, 0.002 + math.sin(math.radians(a)) * rr * 0.9, z + 0.0020), "stone_dark", 1, (1, 1, 0.7)))
    zc = 0.0150
    parts = [((0, -0.0110), (0, -0.0160), 0.0078, 0.0058, "shell_copper"), ((0, -0.0160), (0, -0.0205), 0.0058, 0.0038, "stone"),
             ((0, -0.0205), (0, -0.0240), 0.0038, 0.0020, "shell_copper"), ((0, -0.0240), (0, -0.0270), 0.0020, 0.0002, "stone")]
    for (a0, b0, r0, r1, col) in [(p[0], p[1], p[2], p[3], p[4]) for p in parts]:
        root.append(seg("drill", V((a0[0], a0[1], zc)), V((b0[0], b0[1], zc)), r0, r1, col, 8))
    for s in (-1, 1):
        root.append(bc.box("slit", (0.0034, 0.0014, 0.0014), (s * 0.0052, -0.0112, 0.0225), "ink"))
        root.append(bc.box("glint", (0.0018, 0.0010, 0.0008), (s * 0.0052, -0.0118, 0.0225), "fire_red"))
        root.append(bc.box("foot", (0.0050, 0.0080, 0.0030), (s * 0.0062, -0.0020, 0.0015), "stone_dark"))
    for x, y, rr in ((-0.012, -0.006, 0.0030), (0.013, -0.002, 0.0026), (0.005, 0.014, 0.0030)):
        root.append(bc.blob("rubble", rr, (x, y, rr * 0.5), "path_stone", 1, (1, 1, 0.6)))
    groups = [("", root, (0, 0, 0), "")]
    drill = []
    groups.append(("drill", [], (0, -0.0110, zc), "")) if False else None
    for s, nm in ((-1, "r"), (1, "l")):
        p, pv = arm(s, (0.0125, 0.0010, 0.0185), (0.0170, -0.0030, 0.0140), (0.0175, -0.0075, 0.0105), "shell_copper", "shell_copper", 0.0030)
        p += [seg("claw", V((s * 0.0175, -0.0075, 0.0105)), V((s * 0.0185, -0.0110, 0.0090)), 0.0014, 0.0002, "bone", 5),
              seg("claw", V((s * 0.0175, -0.0075, 0.0105)), V((s * 0.0158, -0.0108, 0.0092)), 0.0014, 0.0002, "bone", 5)]
        groups.append(("arm_" + nm, p, pv, ""))
    return groups, {"eye_anchor": (0, -0.0115, 0.0225), "drill_anchor": (0, -0.0270, zc)}


ENEMIES = {"stumpling": (stumpling, "Grunt"), "shade": (shade, "Scout"), "sporecap": (sporecap, "Splitter"),
           "sporelet": (sporelet, "Splitter half"), "lantern_wisp": (lantern_wisp, "Wisp"), "drillstone": (drillstone, "Tunneler")}


def build(key):
    fn, _role = ENEMIES[key]
    groups, anchors = fn()
    obj = bc.assemble("ew_enemy_%s_v01" % key, groups)
    for nm, loc in anchors.items():
        bc.anchor(obj, nm, loc, "", 0.003)
    mc.smooth(obj)
    return obj


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    key = argv[0] if argv else "stumpling"
    bc.clear_scene()
    obj = build(key)
    print("TRIS", key, mc.tri_count(obj))
    bc.save_blend(obj, "enemy_" + key)
