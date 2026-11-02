"""Enemy concepts, round 2 (Durva 2026-11-02: "they can be so much better"): otherworldly mobs, each with its own tail and weapon.

Run one:  blender --factory-startup -b -P assets/generators/make_enemies2.py -- <key>   (saves assets/blend/enemy_<key>.blend)

  Grunt    -> blightbark      corrupted tree-wraith: hollow chest, branch crown, thorn club, dragging root tail
  Scout    -> veilrunner      legless ribbon spirit: bone mask, curved blades, spinning rune rings, streaming veil
  Splitter -> sporebloom      twin-lobed bloom (it splits in two): spore flute, orbiting spores, root tail; sporebud = the small half
  Wisp     -> lantern_spirit  floating bone-cage lantern: flame plume, petal fins, hooked chain tail
  Tunneler -> mawdrill        segmented armoured burrower: spiral drill head, mandibles, spiked tail
Round 1 (make_enemies.py) stays for comparison. Magic glows are VFX: eyes are dark sockets with small red pupils; anchors mark effects.
Front is -Y. Parts (no rig): root plus arm_l/arm_r, head, tail, drill, jaws, rings, spores, veil, wing_l/_r where the creature has them.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_characters as mc  # noqa: E402

bc, V, seg, chain, flat, place = mc.bc, mc.V, mc.seg, mc.chain, mc.flat, mc.place


def ring3d(c, R, tube, n, col, plane="xy", segs=4):
    """A ring made of n short tubes. plane 'xy' = horizontal ring, 'xz' = vertical ring facing -Y."""
    out = []
    for i in range(n):
        a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
        if plane == "xy":
            p0, p1 = V((c[0] + math.cos(a0) * R, c[1] + math.sin(a0) * R, c[2])), V((c[0] + math.cos(a1) * R, c[1] + math.sin(a1) * R, c[2]))
        else:
            p0, p1 = V((c[0] + math.cos(a0) * R, c[1], c[2] + math.sin(a0) * R)), V((c[0] + math.cos(a1) * R, c[1], c[2] + math.sin(a1) * R))
        out.append(seg("ring", p0, p1, tube, tube, col, segs))
    return out


def eye_pair(z, y, dx, r, pupil="fire_red"):
    out = []
    for s in (-1, 1):
        out.append(bc.blob("eye", r, (s * dx, y, z), "ink", 1, (0.85, 0.5, 1.3)))
        out.append(bc.blob("pupil", r * 0.45, (s * dx, y - r * 0.30, z - r * 0.10), pupil, 1))
    return out


# ----------------------------------------------------------------------------- GRUNT: blightbark
def blightbark():
    r = [bc.cone("trunk", 0.0125, 0.0105, 0.027, (0, 0, 0.0215), "wood_dark", 10)]
    for i in range(8):  # curling bark plates
        a = math.radians(i * 45 + 12)
        r.append(bc.box("plate", (0.0050, 0.0020, 0.0115), (math.cos(a) * 0.0112, math.sin(a) * 0.0112, 0.0215 + 0.0030 * ((i % 3) - 1)),
                        "wood_mid" if i % 2 else "wood_dark", rot_z_deg=math.degrees(a) + 90))
    r += [bc.box("hollow", (0.0090, 0.0040, 0.0125), (0, -0.0108, 0.0225), "ink"),
          bc.box("rib", (0.0105, 0.0017, 0.0017), (0, -0.0129, 0.0262), "wood_mid"),
          bc.box("rib", (0.0105, 0.0017, 0.0017), (0, -0.0129, 0.0222), "wood_mid"),
          bc.box("rib", (0.0105, 0.0017, 0.0017), (0, -0.0129, 0.0182), "wood_mid")]
    for s in (-1, 1):  # thick root legs
        r += chain("leg", [V((s * 0.0060, 0, 0.0120)), V((s * 0.0092, -0.0030, 0.0062)), V((s * 0.0105, -0.0062, 0.0010))], [0.0046, 0.0037, 0.0025], "wood_dark", 8)
        r.append(bc.blob("toe", 0.0034, (s * 0.0105, -0.0066, 0.0014), "wood_mid", 1, (1.0, 1.3, 0.5)))
    for x, y, z, rr, col in ((-0.008, 0.002, 0.0345, 0.0042, "leaf_dark"), (0.007, -0.002, 0.0350, 0.0038, "leaf_green"), (0.0, 0.006, 0.0340, 0.0040, "leaf_dark")):
        r.append(bc.blob("moss", rr, (x, y, z), col, 1, (1, 1, 0.7)))
    head = [bc.blob("head", 0.0090, (0, -0.0020, 0.0420), "wood_dark", 2, (1.0, 0.95, 0.95)),
            bc.blob("nose", 0.0022, (0, -0.0105, 0.0405), "wood_mid", 1)]
    head += eye_pair(0.0432, -0.0083, 0.0034, 0.0028)
    for i, x in enumerate((-0.0034, 0.0, 0.0034)):
        head.append(bc.box("tooth", (0.0022, 0.0012, 0.0028 if i == 1 else 0.0020), (x, -0.0090, 0.0372), "bone"))
    for s in (-1, 1):  # antler crown with dead leaves
        head += chain("antler", [V((s * 0.0040, 0, 0.0498)), V((s * 0.0075, 0, 0.0570)), V((s * 0.0115, 0, 0.0640)), V((s * 0.0105, 0, 0.0700))], [0.0017, 0.0014, 0.0010, 0.0003], "wood_mid", 5)
        head += chain("tine", [V((s * 0.0075, 0, 0.0570)), V((s * 0.0140, -0.002, 0.0600))], [0.0012, 0.0003], "wood_mid", 5)
        head.append(bc.blob("leaf", 0.0022, (s * 0.0140, -0.002, 0.0600), "leaf_yellow", 1, (1.3, 0.3, 0.8)))
    groups = [("", r, (0, 0, 0), ""), ("head", head, (0, 0, 0.0345), "")]
    for s, nm in ((-1, "r"), (1, "l")):
        pts = [V((s * 0.0128, 0, 0.0300)), V((s * 0.0190, -0.0030, 0.0225)), V((s * 0.0215, -0.0070, 0.0135))]
        arm = chain("arm", pts, [0.0042, 0.0035, 0.0030], "wood_dark", 8)
        arm.append(bc.blob("fist", 0.0042, pts[-1], "wood_mid", 1))
        for dx, dy in ((0.0030, -0.0045), (0.0010, -0.0055), (-0.0010, -0.0042)):
            arm.append(seg("claw", pts[-1], pts[-1] + V((s * dx, dy, -0.0058)), 0.0014, 0.0002, "wood_mid", 4))
        if s == -1:  # root-ball club with thorns
            top = V((-0.0230, -0.0090, 0.0330))
            arm.append(seg("handle", pts[-1], top, 0.0016, 0.0020, "wood_mid", 6))
            arm.append(bc.blob("ball", 0.0062, top + V((0, 0, 0.0030)), "wood_mid", 2))
            for k in range(6):
                a = math.radians(k * 60)
                arm.append(seg("thorn", top + V((math.cos(a) * 0.005, math.sin(a) * 0.005, 0.0030)), top + V((math.cos(a) * 0.0105, math.sin(a) * 0.0105, 0.0042)), 0.0017, 0.0002, "bone", 4))
        groups.append(("arm_" + nm, arm, tuple(pts[0]), ""))
    tail = chain("tail", [V((0, 0.0100, 0.0140)), V((0, 0.0180, 0.0090)), V((0, 0.0260, 0.0050)), V((0, 0.0330, 0.0070))], [0.0042, 0.0034, 0.0024, 0.0010], "wood_dark", 8)
    tail.append(seg("thorn", V((0, 0.0330, 0.0070)), V((0, 0.0400, 0.0110)), 0.0018, 0.0002, "bone", 4))
    groups.append(("tail", tail, (0, 0.0100, 0.0140), ""))
    return groups, {"eye_anchor": (0, -0.0083, 0.0432), "ember_anchor": (0, -0.0120, 0.0225)}


# ----------------------------------------------------------------------------- SCOUT: veilrunner
def veilrunner():
    r = [bc.cone("core", 0.0075, 0.0030, 0.0270, (0, 0, 0.0250), "ink", 10)]
    for i in range(8):  # hanging cloth strips down to the ground
        a = math.radians(i * 45)
        r += chain("strip", [V((math.cos(a) * 0.0058, math.sin(a) * 0.0058, 0.0150)), V((math.cos(a) * 0.0090, math.sin(a) * 0.0090, 0.0075)),
                             V((math.cos(a) * 0.0104, math.sin(a) * 0.0104, 0.0005))], [0.0026, 0.0020, 0.0004], "ink" if i % 2 else "cloth_maroon", 4)
    head = [bc.blob("hood", 0.0088, (0, 0.0010, 0.0405), "ink", 2, (1.0, 0.95, 1.12)), bc.blob("mask", 0.0066, (0, -0.0066, 0.0400), "bone", 2, (0.9, 0.40, 1.15))]
    for s in (-1, 1):
        head.append(bc.box("slit", (0.0030, 0.0014, 0.0013 + 0.0004 * (s > 0)), (s * 0.0030, -0.0108, 0.0412 - 0.0004 * s), "ink"))
        head.append(bc.box("glint", (0.0015, 0.0010, 0.0007), (s * 0.0030, -0.0114, 0.0412 - 0.0004 * s), "lantern_glow"))
        head.append(bc.box("rune", (0.0014, 0.0010, 0.0034), (s * 0.0046, -0.0104, 0.0372), "roof_terracotta"))
        head += chain("crest", [V((s * 0.0030, 0.002, 0.0470)), V((s * 0.0050, 0.008, 0.0530)), V((s * 0.0048, 0.015, 0.0560))], [0.0030, 0.0020, 0.0003], "ink", 5)
    groups = [("", r, (0, 0, 0), ""), ("head", head, (0, 0, 0.0360), "")]
    rings = ring3d((0, 0, 0.0290), 0.0108, 0.0007, 14, "roof_orange") + ring3d((0, 0, 0.0215), 0.0098, 0.0007, 14, "fire_red")
    groups.append(("rings", rings, (0, 0, 0.0250), ""))
    for s, nm in ((-1, "r"), (1, "l")):  # blade arms
        pts = [V((s * 0.0072, 0, 0.0320)), V((s * 0.0105, -0.0040, 0.0262)), V((s * 0.0112, -0.0070, 0.0268))]
        arm = chain("arm", pts, [0.0020, 0.0017, 0.0015], "ink", 6)
        arm += chain("blade", [pts[-1], V((s * 0.0124, -0.0150, 0.0300)), V((s * 0.0108, -0.0230, 0.0370)), V((s * 0.0082, -0.0270, 0.0450))], [0.0014, 0.0016, 0.0011, 0.0002], "bone", 5)
        arm.append(bc.box("guard", (0.0050, 0.0012, 0.0012), (s * 0.0112, -0.0072, 0.0268), "shell_gold"))
        groups.append(("arm_" + nm, arm, tuple(pts[0]), ""))
    veil = []
    for off, col in ((-0.0045, "fire_red"), (-0.0022, "roof_orange"), (0.0, "cloth_maroon"), (0.0022, "ink"), (0.0045, "roof_terracotta")):
        veil += chain("veil", [V((off, 0.0060, 0.0350)), V((off, 0.0140, 0.0320)), V((off + 0.0018, 0.0230, 0.0275)), V((off - 0.0018, 0.0320, 0.0235)), V((off, 0.0410, 0.0190))],
                      [0.0017, 0.0016, 0.0014, 0.0011, 0.0003], col, 4)
    groups.append(("veil", veil, (0, 0.0060, 0.0350), ""))
    return groups, {"eye_anchor": (0, -0.0114, 0.0412), "rune_anchor": (0, 0, 0.0250)}


# ----------------------------------------------------------------------------- SPLITTER: sporebloom (+ sporebud)
def sporebloom(k=1.0):
    def S(v):
        return v * k
    r = [bc.cone("stalk", S(0.0078), S(0.0062), S(0.0180), (0, 0, S(0.0090)), "bone", 10),
         bc.cone("gills", S(0.0210), S(0.0075), S(0.0040), (0, 0, S(0.0200)), "flower_pink", 14)]
    for s in (-1, 1):
        r.append(bc.blob("lobe", S(0.0112), (S(s * 0.0086), 0, S(0.0290)), "cloth_maroon", 2, (1.0, 1.0, 0.88)))
        r.append(bc.blob("eye", S(0.0033), (S(s * 0.0086), S(-0.0104), S(0.0268)), "ink", 1, (0.85, 0.5, 1.3)))
        r.append(bc.blob("pupil", S(0.0015), (S(s * 0.0086), S(-0.0119), S(0.0263)), "fire_red", 1))
        for dx, dy, dz, rr in ((0.0040, 0.003, 0.0105, 0.0022), (-0.0030, -0.004, 0.0098, 0.0020), (0.0010, 0.0060, 0.0090, 0.0020), (0.0050, -0.0030, 0.0075, 0.0018)):
            r.append(bc.blob("spot", S(rr), (S(s * 0.0086 + dx), S(dy), S(0.0290 + dz)), "flower_pink", 1, (1, 1, 0.5)))
    r.append(bc.box("seam", (S(0.0016), S(0.0100), S(0.0170)), (0, 0, S(0.0300)), "wood_dark"))
    r.append(bc.box("mouth", (S(0.0040), S(0.0012), S(0.0011)), (0, S(-0.0120), S(0.0192)), "ink"))
    for a in (30, 110, 200, 290):  # splayed root feet
        a_ = math.radians(a)
        r += chain("foot", [V((S(math.cos(a_) * 0.0050), S(math.sin(a_) * 0.0050), S(0.0060))), V((S(math.cos(a_) * 0.0090), S(math.sin(a_) * 0.0090), S(0.0030))), V((S(math.cos(a_) * 0.0125), S(math.sin(a_) * 0.0125), S(0.0006)))],
                   [S(0.0030), S(0.0024), S(0.0012)], "wood_light", 5)
    groups = [("", r, (0, 0, 0), "")]
    if k > 0.9:
        for s, nm in ((-1, "r"), (1, "l")):
            pts = [V((s * 0.0075, 0, 0.0140)), V((s * 0.0120, -0.0030, 0.0110)), V((s * 0.0135, -0.0070, 0.0105))]
            arm = chain("arm", pts, [0.0022, 0.0019, 0.0017], "bone", 6)
            arm.append(bc.blob("hand", 0.0026, pts[-1], "bone", 1))
            if s == -1:  # spore flute with a dark bell
                arm += [seg("flute", pts[-1], pts[-1] + V((-0.0030, -0.0090, 0.0100)), 0.0014, 0.0050, "wood_light", 8),
                        bc.blob("bell", 0.0034, pts[-1] + V((-0.0030, -0.0092, 0.0104)), "ink", 1, (1, 0.5, 1))]
            groups.append(("arm_" + nm, arm, tuple(pts[0]), ""))
        tail = []
        for dx in (-0.004, 0.0, 0.004):
            tail += chain("tendril", [V((dx, 0.0075, 0.0100)), V((dx * 1.6, 0.0140, 0.0070)), V((dx * 2.2, 0.0210, 0.0090)), V((dx * 2.4, 0.0260, 0.0140))], [0.0024, 0.0020, 0.0014, 0.0003], "wood_light", 5)
        groups.append(("tail", tail, (0, 0.0075, 0.0100), ""))
        spores = []
        for i in range(8):
            a = math.radians(i * 45)
            spores.append(bc.blob("spore", 0.0017 + 0.0005 * (i % 3), (math.cos(a) * 0.0185, math.sin(a) * 0.0185, 0.0300 + 0.0045 * math.sin(i * 1.7)), "wall_cream" if i % 2 else "hair_lime", 1))
        groups.append(("spores", spores, (0, 0, 0.0300), ""))
    return groups, {"eye_anchor": (0, S(-0.0104), S(0.0268)), "spore_anchor": (S(-0.0150), S(-0.0150), S(0.0240))}


def sporebud():
    return sporebloom(0.55)


# ----------------------------------------------------------------------------- WISP: lantern_spirit
def lantern_spirit():
    r = []
    for i in range(6):  # bone cage bars
        a = math.radians(i * 60 + 30)
        r.append(seg("bar", V((math.cos(a) * 0.0090, math.sin(a) * 0.0090, 0.0200)), V((math.cos(a) * 0.0090, math.sin(a) * 0.0090, 0.0400)), 0.0011, 0.0011, "bone", 4))
    r += ring3d((0, 0, 0.0200), 0.0090, 0.0012, 12, "bone") + ring3d((0, 0, 0.0400), 0.0090, 0.0012, 12, "bone")
    r += [bc.cone("hollow", 0.0072, 0.0072, 0.0180, (0, 0, 0.0300), "ink", 10),
          bc.cone("base", 0.0090, 0.0030, 0.0060, (0, 0, 0.0170), "stone_dark", 10),
          bc.cone("cap", 0.0105, 0.0030, 0.0070, (0, 0, 0.0435), "stone_dark", 10),
          seg("rod", V((0, 0, 0.0145)), V((0, 0, 0.0006)), 0.0010, 0.0010, "bone", 4)]
    for s in (-1, 1):  # face on the front panel
        r.append(bc.blob("eye", 0.0030, (s * 0.0034, -0.0083, 0.0310), "ink", 1, (0.8, 0.5, 1.4)))
        r.append(bc.blob("spark", 0.0011, (s * 0.0030, -0.0100, 0.0322), "bone", 1))
        r.append(bc.blob("cheek", 0.0016, (s * 0.0056, -0.0082, 0.0270), "wisp_glow", 1, (1, 0.4, 0.8)))
    for i, (dx, h, lean) in enumerate(((0, 0.0150, 0), (-0.0042, 0.0105, -0.4), (0.0042, 0.0115, 0.4))):  # flame tongues
        r.append(seg("flame", V((dx, 0, 0.0470)), V((dx + lean * 0.004, 0, 0.0470 + h)), 0.0040, 0.0002, "wisp_glow", 6))
    r.append(bc.blob("heart", 0.0035, (0, 0, 0.0472), "flower_pink", 1))
    groups = [("", r, (0, 0, 0), "")]
    tail = chain("chain", [V((0, 0.0100, 0.0200)), V((0, 0.0170, 0.0150)), V((0, 0.0230, 0.0090)), V((0, 0.0270, 0.0035))], [0.0012] * 4, "stone", 5)
    for i, (y, z, rr) in enumerate(((0.0130, 0.0178, 0.0030), (0.0200, 0.0120, 0.0027), (0.0250, 0.0062, 0.0024))):
        tail.append(bc.blob("bead", rr, (0, y, z), "wisp_glow" if i % 2 == 0 else "bone", 1))
    tail += [seg("hook", V((0, 0.0270, 0.0035)), V((0, 0.0300, 0.0008)), 0.0014, 0.0003, "bone", 4), seg("hook", V((0, 0.0300, 0.0008)), V((0, 0.0330, 0.0030)), 0.0010, 0.0002, "bone", 4)]
    groups.append(("tail", tail, (0, 0.0100, 0.0200), ""))
    for s, nm in ((-1, "r"), (1, "l")):  # petal fins
        b = V((s * 0.0100, 0.0020, 0.0340))
        P = lambda u, v, s=s, b=b: (b.x + s * u, b.y + 0.5 * u, b.z + v)
        k = 0.0120
        w = [flat("fin", [P(0, 0), P(.5 * k, .9 * k), P(1.4 * k, 1.2 * k), P(1.7 * k, .4 * k), P(1.1 * k, -.4 * k), P(.3 * k, -.2 * k)], 0.0007, "wall_cream"),
             flat("fin_low", [P(0, -.1 * k), P(1.0 * k, -.5 * k), P(1.1 * k, -1.2 * k), P(.4 * k, -1.0 * k)], 0.0007, "flower_pink")]
        groups.append(("wing_" + nm, w, tuple(b), ""))
    return groups, {"eye_anchor": (0, -0.0090, 0.0310), "flame_anchor": (0, 0, 0.0480), "lantern_anchor": (0, 0, 0.0300)}


# ----------------------------------------------------------------------------- TUNNELER: mawdrill
def mawdrill():
    zc = 0.0170
    r = []
    for i, (y, rad, col) in enumerate(((0.0030, 0.0112, "stone"), (0.0150, 0.0100, "stone_dark"), (0.0270, 0.0088, "stone"))):  # armoured rings
        r.append(seg("ring", V((0, y - 0.0050, zc)), V((0, y + 0.0050, zc)), rad * 0.94, rad, col, 12))
        r.append(seg("band", V((0, y + 0.0050, zc)), V((0, y + 0.0070, zc)), rad * 1.04, rad * 1.04, "shell_copper", 12))
        for a in (-60, -20, 20, 60):  # dorsal spikes
            a_ = math.radians(a)
            r.append(seg("spike", V((math.sin(a_) * rad, y, zc + math.cos(a_) * rad)), V((math.sin(a_) * rad * 1.25, y, zc + math.cos(a_) * rad * 1.35)), 0.0019, 0.0002, "shell_gold", 4))
    r.append(bc.blob("tail_bulb", 0.0082, (0, 0.0395, zc - 0.0010), "stone_dark", 2, (1.0, 1.1, 0.95)))
    for k in range(5):
        a = math.radians(k * 72 + 20)
        r.append(seg("stinger", V((math.cos(a) * 0.0070, 0.0395, zc - 0.001 + math.sin(a) * 0.0070)), V((math.cos(a) * 0.0115, 0.0430, zc - 0.001 + math.sin(a) * 0.0115)), 0.0020, 0.0002, "shell_copper", 4))
    for y in (0.0020, 0.0160, 0.0280):  # claw legs
        for s in (-1, 1):
            r += [seg("leg", V((s * 0.0090, y, 0.0100)), V((s * 0.0128, y - 0.0020, 0.0030)), 0.0022, 0.0018, "stone_dark", 5),
                  seg("claw", V((s * 0.0128, y - 0.0020, 0.0030)), V((s * 0.0140, y - 0.0060, 0.0002)), 0.0018, 0.0002, "bone", 4)]
    for x, y, rr in ((-0.008, -0.010, 0.0060), (0.009, -0.006, 0.0052), (0.003, 0.030, 0.0056), (-0.010, 0.020, 0.0046)):
        r.append(bc.blob("mound", rr, (x, y, rr * 0.56), "dirt_dark", 1, (1, 1, 0.55)))
    for s in (-1, 1):
        r.append(bc.box("slit", (0.0010, 0.0034, 0.0014), (s * 0.0098, -0.0072, zc + 0.0048), "ink"))
        r.append(bc.box("glint", (0.0008, 0.0020, 0.0008), (s * 0.0102, -0.0078, zc + 0.0048), "fire_red"))
    r.append(seg("neck", V((0, -0.0070, zc)), V((0, -0.0040, zc)), 0.0090, 0.0100, "shell_copper", 12))
    groups = [("", r, (0, 0, 0), "")]
    drill = []
    cuts = [(-0.0070, -0.0160, 0.0092, 0.0070, "shell_copper"), (-0.0160, -0.0230, 0.0070, 0.0046, "stone"), (-0.0230, -0.0290, 0.0046, 0.0024, "shell_copper"), (-0.0290, -0.0340, 0.0024, 0.0002, "stone")]
    for y0, y1, r0, r1, col in cuts:
        drill.append(seg("cone", V((0, y0, zc)), V((0, y1, zc)), r0, r1, col, 10))
    for i in range(6):  # spiral flutes
        a = math.radians(i * 60)
        drill.append(seg("flute", V((math.cos(a) * 0.0088, -0.0074, zc + math.sin(a) * 0.0088)), V((math.cos(a + 1.4) * 0.0010, -0.0336, zc + math.sin(a + 1.4) * 0.0010)), 0.0010, 0.0003, "shell_gold", 4))
    groups.append(("drill", drill, (0, -0.0070, zc), ""))
    for s, nm in ((-1, "r"), (1, "l")):  # mandible jaws
        j = chain("jaw", [V((s * 0.0105, -0.0060, zc - 0.0030)), V((s * 0.0150, -0.0140, zc - 0.0040)), V((s * 0.0125, -0.0220, zc - 0.0030)), V((s * 0.0070, -0.0260, zc - 0.0020))], [0.0030, 0.0024, 0.0015, 0.0002], "bone", 5)
        groups.append(("jaw_" + nm, j, (s * 0.0105, -0.0060, zc - 0.0030), ""))
    return groups, {"eye_anchor": (0, -0.0078, zc + 0.0048), "drill_anchor": (0, -0.0340, zc), "dust_anchor": (0, -0.0100, 0.0010)}


ENEMIES = {"blightbark": (blightbark, "Grunt"), "veilrunner": (veilrunner, "Scout"), "sporebloom": (sporebloom, "Splitter"),
           "sporebud": (sporebud, "Splitter half"), "lantern_spirit": (lantern_spirit, "Wisp"), "mawdrill": (mawdrill, "Tunneler")}


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
    key = argv[0] if argv else "blightbark"
    bc.clear_scene()
    obj = build(key)
    print("TRIS", key, mc.tri_count(obj))
    bc.save_blend(obj, "enemy_" + key)
