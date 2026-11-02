"""The Warden, round 2: three MAXIMALIST concepts (Durva 2026-11-02: "the boss designs suck, do better, more creative, maximalist and detailed").

Run one:  blender --factory-startup -b -P assets/generators/make_boss2.py -- <key>     (saves assets/blend/boss_<key>.blend)
  eclipse_empress      a six-armed regal giant: four-tier gown, spiked crown, spinning eclipse halo, six held relics
  wandering_cathedral  a walking gothic cathedral on four buttress legs: rose-window eye, twin spired towers, gargoyle masks, bells, lanterns
  hourglass_tyrant     a colossal clockwork hourglass (time loop!): clock-face mask, gear arms, pendulum, broken clock-face wings, orbiting hour markers
Dense and layered on purpose: the whole 6000-triangle boss budget is spent on one rich, readable silhouette (big smooth masses plus many
cheap 4-6 sided details). Not animals. Colours: warden_deep / warden_dark / crystal_purple (the Warden's purples), gold, bone, stone.
Footprint about 0.15 m (3 cells), height about 0.24 m. Anchors on each: crystal_anchor_1..3 (shield crystals on a ring at 2 cells),
eye_anchor, summon_anchor, plus concept-specific ones. Earlier boss rounds (make_boss.py) are kept for comparison.
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


def crystal_anchors(obj, z, r=0.1000):
    for i in range(3):
        a = math.radians(i * 120 + 90)
        bc.anchor(obj, "crystal_anchor_%d" % (i + 1), (math.cos(a) * r, math.sin(a) * r, z), "", 0.008)


def cubes(pts, size, col):
    return [bc.box("gem", size, p, col) for p in pts]


def gear(c, R, teeth, thick, col, hub_col="shell_gold", facing="y"):
    """A gear built at the origin then placed at c: disc, teeth, hub. facing 'y' = faces -Y (vertical), 'z' = faces up."""
    P = [bc.cone("gear", R, R, thick, (0, 0, 0), col, max(teeth, 10)), bc.cone("hub", R * 0.30, R * 0.30, thick * 1.5, (0, 0, 0), hub_col, 8)]
    for i in range(teeth):
        a = 2 * PI * i / teeth
        P.append(bc.box("tooth", (R * 0.30, R * 0.34, thick), (math.cos(a) * R * 1.04, math.sin(a) * R * 1.04, 0), col, rot_z_deg=math.degrees(a)))
    for i in range(4):  # spokes cut-outs read as darker bars
        a = i * PI / 2
        P.append(bc.box("spoke", (R * 0.62, R * 0.12, thick * 1.2), (math.cos(a) * R * 0.52, math.sin(a) * R * 0.52, 0), "warden_dark", rot_z_deg=math.degrees(a)))
    rot = (90, 0, 0) if facing == "y" else (0, 0, 0)
    for o in P:
        place(o, rot, c)
    return P


def mask_at(R, pos, face_deg=0.0, col="bone", sub=1):
    """A small mask facing -Y at face_deg, built then placed."""
    P = [bc.blob("mask", R, (0, 0, 0), col, sub, (0.80, 0.50, 1.10)),
         bc.box("slit", (R * 0.22, R * 0.16, R * 0.30), (-R * 0.28, -R * 0.46, R * 0.18), "warden_dark"),
         bc.box("slit", (R * 0.22, R * 0.16, R * 0.30), (R * 0.28, -R * 0.46, R * 0.18), "warden_dark"),
         bc.box("brow", (R * 1.1, R * 0.12, R * 0.10), (0, -R * 0.42, R * 0.42), "warden_deep")]
    for o in P:
        place(o, (0, 0, face_deg), pos)
    return P


# ============================================================================= 1. ECLIPSE EMPRESS
def eclipse_empress():
    root = []
    tiers = [(0.0, 0.030, 0.074, 0.060, "warden_deep"), (0.028, 0.058, 0.062, 0.048, "warden_dark"),
             (0.056, 0.086, 0.050, 0.038, "warden_deep"), (0.084, 0.112, 0.040, 0.028, "warden_dark")]
    for t, (z0, z1, rb, rt, col) in enumerate(tiers):
        root.append(bc.cone("tier", rb, rt, z1 - z0, (0, 0, (z0 + z1) / 2), col, 16))
        root.append(bc.cone("band", rb * 1.03, rb * 1.03, 0.0035, (0, 0, z0 + 0.0020), "shell_gold", 16))
        for k in range(12):  # scalloped hem points
            a = 2 * PI * k / 12 + t * 0.26
            tip_z = 0.0006 if z0 == 0.0 else z0 - 0.0035
            root.append(seg("hem", V((math.cos(a) * rb * 0.99, math.sin(a) * rb * 0.99, z0 + 0.0040)), V((math.cos(a) * rb * 1.07, math.sin(a) * rb * 1.07, tip_z)),
                            0.0042, 0.0002, "shell_gold" if k % 2 else "crystal_purple", 4))
    root += [bc.cone("torso", 0.0270, 0.0200, 0.0420, (0, 0, 0.1320), "warden_dark", 12)]
    for z in (0.118, 0.132, 0.146):
        root.append(bc.cone("corset", 0.0272 - (z - 0.118) * 0.20, 0.0272 - (z - 0.118) * 0.20, 0.0020, (0, 0, z), "shell_gold", 12))
    root += [bc.box("sigil", (0.0100, 0.0030, 0.0140), (0, -0.0225, 0.1330), "crystal_purple"), bc.box("sigil_gold", (0.0140, 0.0020, 0.0040), (0, -0.0232, 0.1330), "shell_gold"),
             bc.blob("shoulders", 0.0240, (0, 0, 0.1520), "warden_dark", 3, (2.0, 0.85, 0.50)),
             bc.cone("collar", 0.0210, 0.0120, 0.0100, (0, 0, 0.1600), "shell_gold", 12)]
    for s in (-1, 1):  # shoulder spikes
        root.append(seg("pauldron", V((s * 0.0390, 0, 0.1560)), V((s * 0.0520, 0, 0.1800)), 0.0070, 0.0003, "shell_gold", 5))
    groups = [("", root, (0, 0, 0), "")]

    # head: big mask with a third eye, circlet and a tall crown, hanging veil
    head = [bc.blob("mask", 0.0260, (0, 0, 0.1900), "bone", 3, (0.78, 0.62, 1.22)),
            bc.box("eye", (0.0080, 0.0030, 0.0040), (-0.0095, -0.0148, 0.1960), "warden_dark"), bc.box("eye", (0.0080, 0.0030, 0.0040), (0.0095, -0.0148, 0.1960), "warden_dark"),
            bc.box("gem", (0.0050, 0.0030, 0.0070), (0, -0.0160, 0.2110), "crystal_purple"), bc.box("brow", (0.0340, 0.0030, 0.0030), (0, -0.0155, 0.2020), "warden_deep"),
            bc.box("cheek", (0.0030, 0.0030, 0.0120), (-0.0120, -0.0158, 0.1820), "shell_gold"), bc.box("cheek", (0.0030, 0.0030, 0.0120), (0.0120, -0.0158, 0.1820), "shell_gold")]
    head += ring3d((0, 0, 0.2090), 0.0200, 0.0017, 14, "shell_gold", "xy")
    for k in range(9):
        a = 2 * PI * k / 9
        h = 0.0260 if k % 3 == 0 else 0.0170
        head.append(seg("crown", V((math.cos(a) * 0.0200, math.sin(a) * 0.0200, 0.2090)), V((math.cos(a) * 0.0235, math.sin(a) * 0.0235, 0.2090 + h)), 0.0030, 0.0002, "shell_gold", 5))
        if k % 3 == 0:
            head.append(bc.blob("jewel", 0.0027, (math.cos(a) * 0.0235, math.sin(a) * 0.0235, 0.2090 + h), "crystal_purple", 1))
    for dx in (-0.0200, -0.0070, 0.0070, 0.0200):  # long veil ribbons down the back
        head += chain("veil", [V((dx, 0.0180, 0.2000)), V((dx * 1.4, 0.0300, 0.1700)), V((dx * 1.6, 0.0400, 0.1250)), V((dx * 1.7, 0.0480, 0.0700))], [0.0034, 0.0036, 0.0034, 0.0006],
                      "warden_dark" if abs(dx) < 0.01 else "shell_gold", 4)
    groups.append(("head", head, (0, 0, 0.1700), ""))
    # eclipse halo (spins): dark disc, gold corona ring, rays, small moons
    halo = [place(bc.cone("disc", 0.0600, 0.0600, 0.0040, (0, 0, 0), "warden_dark", 20), (90, 0, 0), (0, 0.0240, 0.1950))]
    halo += ring3d((0, 0.0210, 0.1950), 0.0620, 0.0020, 24, "shell_gold", "xz")
    for k in range(20):
        a = 2 * PI * k / 20
        L = 0.0200 if k % 2 == 0 else 0.0120
        halo.append(seg("ray", V((math.cos(a) * 0.0640, 0.0210, 0.1950 + math.sin(a) * 0.0640)), V((math.cos(a) * (0.0640 + L), 0.0210, 0.1950 + math.sin(a) * (0.0640 + L))), 0.0034, 0.0002, "shell_gold" if k % 2 else "crystal_purple", 4))
    groups.append(("halo", halo, (0, 0.0220, 0.1950), "head"))

    # six arms holding six relics
    def arm(name, s, S, E, H, relic):
        pts = [V(S), V(E), V(H)]
        P = chain("arm", pts, [0.0050, 0.0042, 0.0036], "warden_deep", 6)
        P.append(bc.blob("hand", 0.0046, pts[-1], "bone", 1))
        for dx in (-0.0020, 0.0, 0.0020):
            P.append(seg("finger", pts[-1], pts[-1] + V((dx, -0.0050, 0.0070)), 0.0013, 0.0003, "bone", 4))
        P += relic(V(H) + V((0, -0.0040, 0.0090)))
        groups.append((name, P, tuple(S), ""))

    def sun(p):
        P = [bc.blob("sun", 0.0130, p + V((0, 0, 0.0100)), "fire_yellow", 2)]
        for k in range(10):
            a = 2 * PI * k / 10
            c0 = p + V((0, 0, 0.0100))
            P.append(seg("sunray", c0 + V((math.cos(a) * 0.0130, 0, math.sin(a) * 0.0130)), c0 + V((math.cos(a) * 0.0220, 0, math.sin(a) * 0.0220)), 0.0024, 0.0002, "fire_red", 4))
        return P

    def moon(p):
        pts = [(math.cos(math.radians(a)) * 0.0150, p.y, p.z + 0.0100 + math.sin(math.radians(a)) * 0.0150) for a in range(-110, 111, 22)]
        inner = [(math.cos(math.radians(a)) * 0.0100 + 0.0070, p.y, p.z + 0.0100 + math.sin(math.radians(a)) * 0.0100) for a in range(110, -111, -22)]
        return [flat("moon", [(p.x + q[0], q[1], q[2]) for q in pts + inner], 0.0040, "bone")]

    def hourglass(p):
        return [bc.cone("glass", 0.0070, 0.0010, 0.0090, p + V((0, 0, 0.0145)), "crystal_purple", 8), bc.cone("glass", 0.0010, 0.0070, 0.0090, p + V((0, 0, 0.0055)), "crystal_purple", 8),
                bc.cone("capt", 0.0085, 0.0085, 0.0014, p + V((0, 0, 0.0200)), "shell_gold", 8), bc.cone("capb", 0.0085, 0.0085, 0.0014, p + V((0, 0, 0.0000)), "shell_gold", 8)]

    def key(p):
        P = [seg("shaft", p + V((0, 0, -0.0060)), p + V((0, 0, 0.0220)), 0.0014, 0.0014, "shell_gold", 6)]
        P += ring3d((p.x, p.y, p.z + 0.0260), 0.0050, 0.0013, 8, "shell_gold", "xz")
        for k in range(3):
            P.append(bc.box("bit", (0.0050, 0.0016, 0.0016), (p.x + 0.0030, p.y, p.z - 0.0030 + k * 0.0030), "shell_gold"))
        return P

    def lantern(p):
        return [bc.box("cage", (0.0090, 0.0090, 0.0120), p + V((0, 0, 0.0080)), "shell_copper"), bc.cone("roof", 0.0080, 0.0005, 0.0070, p + V((0, 0, 0.0185)), "warden_dark", 4),
                bc.box("socket", (0.0060, 0.0060, 0.0080), p + V((0, 0, 0.0080)), "ink")]

    def blade(p):
        pts = [p + V((0, 0, -0.0050)), p + V((0.0020, -0.0050, 0.0140)), p + V((0.0000, -0.0100, 0.0300)), p + V((-0.0060, -0.0120, 0.0420))]
        return chain("blade", pts, [0.0018, 0.0034, 0.0026, 0.0003], "bone", 5) + [bc.box("guard", (0.0120, 0.0020, 0.0020), tuple(pts[0] + V((0, 0, 0.0050))), "shell_gold")]

    arm("arm_ur", -1, (-0.0230, 0, 0.1580), (-0.0480, -0.0060, 0.1750), (-0.0640, -0.0120, 0.1950), sun)
    arm("arm_ul", 1, (0.0230, 0, 0.1580), (0.0480, -0.0060, 0.1750), (0.0640, -0.0120, 0.1950), moon)
    arm("arm_mr", -1, (-0.0240, 0, 0.1500), (-0.0580, -0.0090, 0.1500), (-0.0780, -0.0200, 0.1500), hourglass)
    arm("arm_ml", 1, (0.0240, 0, 0.1500), (0.0580, -0.0090, 0.1500), (0.0780, -0.0200, 0.1500), key)
    arm("arm_lr", -1, (-0.0220, 0, 0.1420), (-0.0500, -0.0140, 0.1250), (-0.0680, -0.0260, 0.1050), lantern)
    arm("arm_ll", 1, (0.0220, 0, 0.1420), (0.0500, -0.0140, 0.1250), (0.0680, -0.0260, 0.1050), blade)

    orbit = []
    for k in range(8):  # floating crystal shards
        a = 2 * PI * k / 8
        p = V((math.cos(a) * 0.1080, math.sin(a) * 0.1080, 0.0900 + 0.0300 * math.sin(k * 1.7)))
        orbit.append(seg("shard", p + V((0, 0, -0.0090)), p + V((0, 0, 0.0090)), 0.0042, 0.0002, "crystal_purple", 4))
        orbit.append(seg("shard", p + V((0, 0, -0.0090)), p + V((0, 0, -0.0160)), 0.0030, 0.0002, "warden_deep", 4))
    groups.append(("orbit", orbit, (0, 0, 0.1000), ""))
    obj = bc.assemble("ew_boss_eclipse_empress_v01", groups)
    crystal_anchors(obj, 0.1100)
    bc.anchor(obj, "eye_anchor", (0, -0.0170, 0.2110), "head", 0.005)
    bc.anchor(obj, "sigil_anchor", (0, -0.0250, 0.1330), "", 0.006)
    bc.anchor(obj, "sun_anchor", (-0.0640, -0.0160, 0.2040), "arm_ur", 0.008)
    bc.anchor(obj, "summon_anchor", (0, -0.0900, 0.0200), "", 0.008)
    return obj


# ============================================================================= 2. WANDERING CATHEDRAL
def wandering_cathedral():
    root = []
    root += [bc.box("nave", (0.0560, 0.0960, 0.0500), (0, 0.0040, 0.0880), "stone"),
             bc.box("aisle", (0.0180, 0.0900, 0.0300), (-0.0370, 0.0040, 0.0780), "stone_dark"), bc.box("aisle", (0.0180, 0.0900, 0.0300), (0.0370, 0.0040, 0.0780), "stone_dark"),
             bc.gable("roof", 0.0620, 0.1000, 0.0300, (0, 0.0040, 0.1130), "warden_deep"), bc.box("ridge", (0.0034, 0.1000, 0.0034), (0, 0.0040, 0.1445), "shell_gold"),
             bc.cone("apse", 0.0280, 0.0230, 0.0500, (0, 0.0560, 0.0880), "stone", 10), bc.cone("apse_roof", 0.0300, 0.0020, 0.0220, (0, 0.0560, 0.1220), "warden_deep", 10)]
    for s in (-1, 1):  # gothic windows down both sides
        for k in range(6):
            y = -0.0360 + k * 0.0145
            root.append(bc.box("window", (0.0016, 0.0070, 0.0200), (s * 0.0288, y, 0.0920), "crystal_purple"))
            root.append(seg("arch", V((s * 0.0288, y, 0.1020)), V((s * 0.0288, y, 0.1120)), 0.0036, 0.0002, "crystal_purple", 4))
            root.append(bc.box("sill", (0.0030, 0.0090, 0.0020), (s * 0.0292, y, 0.0815), "shell_gold"))
    # rose window: the eye
    root += ring3d((0, -0.0462, 0.1230), 0.0125, 0.0013, 18, "shell_gold", "xz") + ring3d((0, -0.0462, 0.1230), 0.0080, 0.0010, 12, "shell_gold", "xz")
    for k in range(10):
        a = 2 * PI * k / 10
        root.append(seg("spoke", V((0, -0.0462, 0.1230)), V((math.cos(a) * 0.0125, -0.0462, 0.1230 + math.sin(a) * 0.0125)), 0.0012, 0.0010, "shell_gold", 4))
    root += [bc.blob("iris", 0.0072, (0, -0.0468, 0.1230), "warden_deep", 2, (1.0, 0.30, 1.0)), bc.box("pupil", (0.0030, 0.0030, 0.0120), (0, -0.0480, 0.1230), "ink")]
    for k in range(3):  # lancets under the rose
        root.append(bc.box("lancet", (0.0050, 0.0016, 0.0200), (-0.0120 + k * 0.0120, -0.0452, 0.0900), "crystal_purple"))
        root.append(seg("lancet_top", V((-0.0120 + k * 0.0120, -0.0452, 0.1000)), V((-0.0120 + k * 0.0120, -0.0452, 0.1070)), 0.0030, 0.0002, "crystal_purple", 4))
    root += [bc.box("portal", (0.0130, 0.0030, 0.0220), (0, -0.0462, 0.0740), "ink"), seg("portal_top", V((0, -0.0462, 0.0850)), V((0, -0.0462, 0.0940)), 0.0066, 0.0003, "ink", 4)]
    for s in (-1, 1):  # twin spired towers
        tx, ty = s * 0.0300, -0.0460
        root += [bc.box("tower", (0.0210, 0.0210, 0.0950), (tx, ty, 0.1105), "stone"), bc.box("belfry", (0.0240, 0.0240, 0.0060), (tx, ty, 0.1600), "stone_dark"),
                 seg("spire", V((tx, ty, 0.1630)), V((tx, ty, 0.2250)), 0.0130, 0.0004, "warden_deep", 8), bc.blob("finial", 0.0034, (tx, ty, 0.2270), "shell_gold", 1)]
        for z in (0.1750, 0.1930):
            root.append(seg("spire_band", V((tx, ty, z)), V((tx, ty, z + 0.0020)), 0.0130 * (1 - (z - 0.163) / 0.062) + 0.0008, 0.0130 * (1 - (z - 0.163) / 0.062) + 0.0008, "shell_gold", 8))
        for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
            root.append(seg("pinnacle", V((tx + dx * 0.0100, ty + dy * 0.0100, 0.1630)), V((tx + dx * 0.0100, ty + dy * 0.0100, 0.1800)), 0.0030, 0.0002, "stone", 4))
        for k in range(4):
            root.append(bc.box("belfry_arch", (0.0050, 0.0016, 0.0150), (tx + (-0.0105 if k < 2 else 0.0105) * (1 if k % 2 else 0) , ty - 0.0107 if k % 2 == 0 else ty, 0.1500), "ink"))
        root.append(bc.box("tower_window", (0.0040, 0.0016, 0.0140), (tx, ty - 0.0108, 0.1150), "crystal_purple"))
    # gargoyle masks on the tower fronts and nave corners
    for s in (-1, 1):
        for z in (0.1000, 0.1400):
            root += mask_at(0.0072, (s * 0.0300, -0.0600, z), 0, "bone")
        root += mask_at(0.0066, (s * 0.0340, -0.0100, 0.1100), s * -90, "stone")
        root += mask_at(0.0066, (s * 0.0340, 0.0400, 0.1100), s * -90, "stone")
    for k in range(8):  # rubble and dust where it stands
        a = 2 * PI * k / 8 + 0.3
        rr = 0.0420 + 0.0100 * (k % 3)
        root.append(bc.blob("rubble", 0.0070 - 0.0006 * (k % 3), (math.cos(a) * rr, math.sin(a) * rr, 0.0036), "path_stone" if k % 2 else "dirt_dark", 1, (1.2, 1.0, 0.55)))
    # four buttress legs
    for ix, s in enumerate((-1, 1)):
        for iy, ysg in enumerate((-1, 1)):
            att = V((s * 0.0300, ysg * 0.0300, 0.0700))
            pts = [att, att + V((s * 0.0150, ysg * 0.0050, 0.0020)), att + V((s * 0.0300, ysg * 0.0140, -0.0220)), V((s * 0.0640, ysg * 0.0500, 0.0030))]
            leg = chain("leg", pts, [0.0092, 0.0080, 0.0072, 0.0090], "stone_dark", 8)
            leg.append(bc.cone("foot", 0.0120, 0.0090, 0.0050, (pts[-1].x, pts[-1].y, 0.0025), "stone", 8))
            for t in (-1, 0, 1):
                leg.append(seg("claw", V((pts[-1].x, pts[-1].y, 0.0030)), V((pts[-1].x + s * 0.0100 * (1 - 0.3 * abs(t)), pts[-1].y + t * 0.0090 + ysg * 0.0040, 0.0006)), 0.0030, 0.0002, "bone", 4))
            leg.append(seg("rib", pts[1], pts[1] + V((s * 0.0000, -ysg * 0.0160, 0.0230)), 0.0030, 0.0020, "shell_gold", 5))
            groups_leg = ("leg_%s%s" % ("r" if s < 0 else "l", "f" if ysg < 0 else "b"), leg, tuple(att), "")
            root_legs.append(groups_leg) if False else None
            LEGS.append(groups_leg)
    groups = [("", root, (0, 0, 0), "")] + LEGS
    del LEGS[:]
    spire = [seg("needle", V((0, 0.0040, 0.1445)), V((0, 0.0040, 0.2300)), 0.0110, 0.0004, "warden_dark", 8), bc.blob("orb", 0.0050, (0, 0.0040, 0.2320), "shell_gold", 2)]
    for z in (0.1650, 0.1850, 0.2050):
        spire.append(seg("band", V((0, 0.0040, z)), V((0, 0.0040, z + 0.0020)), 0.0100 - (z - 0.1445) * 0.1, 0.0100 - (z - 0.1445) * 0.1, "shell_gold", 8))
    spire.append(flat("vane", [(0, 0.0040, 0.2380), (0.0160, 0.0040, 0.2400), (0.0200, 0.0040, 0.2440), (0.0160, 0.0040, 0.2460), (0, 0.0040, 0.2440)], 0.0015, "shell_gold"))
    groups.append(("spire", spire, (0, 0.0040, 0.1445), ""))
    for i, (bx, bz, br_) in enumerate(((-0.0560, 0.1420, 0.0090), (0.0560, 0.1420, 0.0090), (-0.0200, 0.1100, 0.0060), (0.0000, 0.1100, 0.0060), (0.0200, 0.1100, 0.0060))):  # bells
        by = -0.0460 if i < 2 else 0.0620
        groups.append(("bell_%d" % (i + 1), [seg("rope", V((bx, by, bz + br_ * 1.8)), V((bx, by, bz + br_ * 1.0)), 0.0010, 0.0010, "shell_gold", 4),
                                             bc.cone("bell", br_ * 1.4, br_ * 0.5, br_ * 2.0, (bx, by, bz), "shell_gold", 10),
                                             bc.cone("lip", br_ * 1.6, br_ * 1.5, br_ * 0.3, (bx, by, bz - br_ * 1.0), "shell_copper", 10), bc.blob("clapper", br_ * 0.4, (bx, by, bz - br_ * 1.3), "warden_dark", 1)],
                       (bx, by, bz + br_ * 1.8), ""))
    lan = []
    for s in (-1, 1):
        for ysg in (-1, 1):
            p0 = V((s * 0.0380, ysg * 0.0280, 0.0900))
            lan += chain("chain", [p0, p0 + V((s * 0.0080, 0, -0.0150)), p0 + V((s * 0.0140, 0, -0.0300))], [0.0010] * 3, "shell_gold", 4)
            q = p0 + V((s * 0.0140, 0, -0.0300))
            lan += [bc.box("lamp", (0.0070, 0.0070, 0.0090), q + V((0, 0, -0.0050)), "shell_copper"), bc.box("lamp_socket", (0.0044, 0.0044, 0.0060), q + V((0, 0, -0.0050)), "ink"),
                    bc.cone("lamp_roof", 0.0060, 0.0003, 0.0050, q + V((0, 0, 0.0010)), "warden_dark", 4)]
    groups.append(("lanterns", lan, (0, 0, 0.0900), ""))
    shards = []
    for k in range(8):
        a = 2 * PI * k / 8
        p = V((math.cos(a) * 0.0960, math.sin(a) * 0.0960, 0.1000 + 0.0350 * math.sin(k * 2.3)))
        shards.append(seg("shard", p + V((0, 0, -0.0100)), p + V((0, 0, 0.0120)), 0.0050, 0.0003, "crystal_purple" if k % 2 else "warden_deep", 5))
        shards.append(seg("shard", p + V((0, 0, -0.0100)), p + V((0, 0, -0.0200)), 0.0036, 0.0003, "shell_gold", 5))
    groups.append(("orbit", shards, (0, 0, 0.1000), ""))
    ring = []
    for k in range(14):  # the broken barrier behind the cathedral
        if k in (2, 3, 9):
            continue
        a = math.radians(k * 360 / 14)
        ring.append(place(bc.box("shard", (0.0120, 0.0060, 0.0300), (0, 0, 0), "warden_deep" if k % 2 else "stone"), (0, -(math.degrees(a) + 90), 0), (math.cos(a) * 0.0760, 0.0900, 0.1250 + math.sin(a) * 0.0760)))
    groups.append(("ring", ring, (0, 0.0900, 0.1250), ""))
    obj = bc.assemble("ew_boss_wandering_cathedral_v01", groups)
    crystal_anchors(obj, 0.1200, 0.1050)
    bc.anchor(obj, "eye_anchor", (0, -0.0490, 0.1230), "", 0.006)
    bc.anchor(obj, "summon_anchor", (0, -0.0700, 0.0300), "", 0.008)
    bc.anchor(obj, "bell_anchor", (0, -0.0460, 0.1420), "", 0.006)
    return obj


LEGS = []


# ============================================================================= 3. HOURGLASS TYRANT
def hourglass_tyrant():
    root = [bc.cone("plinth", 0.0780, 0.0700, 0.0120, (0, 0, 0.0060), "stone_dark", 24), bc.cone("plinth_gold", 0.0700, 0.0640, 0.0040, (0, 0, 0.0140), "shell_gold", 24)]
    for k in range(24):
        a = 2 * PI * k / 24
        root.append(bc.box("tooth", (0.0050, 0.0042, 0.0070), (math.cos(a) * 0.0790, math.sin(a) * 0.0790, 0.0060), "stone", rot_z_deg=math.degrees(a)))
    for k in range(12):  # hour ticks on the plinth
        a = 2 * PI * k / 12
        root.append(bc.box("hour", (0.0090 if k % 3 == 0 else 0.0060, 0.0030, 0.0020), (math.cos(a) * 0.0600, math.sin(a) * 0.0600, 0.0170), "bone" if k % 3 else "shell_gold", rot_z_deg=math.degrees(a)))
    root += [bc.blob("lower", 0.0440, (0, 0, 0.0680), "warden_deep", 3, (1.0, 1.0, 1.15)), bc.cone("neck", 0.0150, 0.0150, 0.0420, (0, 0, 0.1200), "shell_gold", 12),
             bc.blob("upper", 0.0400, (0, 0, 0.1750), "warden_dark", 3, (1.0, 1.0, 1.15)), bc.cone("cap", 0.0620, 0.0480, 0.0090, (0, 0, 0.2200), "shell_gold", 16),
             bc.cone("cap_top", 0.0480, 0.0120, 0.0160, (0, 0, 0.2330), "warden_deep", 16)]
    for k in range(4):  # four twisted pillars
        a = math.radians(45 + k * 90)
        root.append(seg("pillar", V((math.cos(a) * 0.0580, math.sin(a) * 0.0580, 0.0150)), V((math.cos(a) * 0.0520, math.sin(a) * 0.0520, 0.2200)), 0.0042, 0.0034, "shell_gold", 8))
        for z in (0.0600, 0.1100, 0.1600):
            root.append(bc.blob("knot", 0.0050, (math.cos(a) * 0.0560, math.sin(a) * 0.0560, z), "shell_gold", 1))
        root.append(seg("finial", V((math.cos(a) * 0.0520, math.sin(a) * 0.0520, 0.2250)), V((math.cos(a) * 0.0520, math.sin(a) * 0.0520, 0.2480)), 0.0040, 0.0002, "shell_gold", 5))
    for k in range(8):  # crown spikes on the cap
        a = 2 * PI * k / 8
        root.append(seg("spike", V((math.cos(a) * 0.0380, math.sin(a) * 0.0380, 0.2400)), V((math.cos(a) * 0.0300, math.sin(a) * 0.0300, 0.2400 + (0.0300 if k % 2 else 0.0200))), 0.0040, 0.0002, "bone", 5))
    for ring_z, rr in ((0.0450, 0.0430), (0.1550, 0.0390)):  # gold latitude bands on the bulbs
        root += ring3d((0, 0, ring_z), rr, 0.0017, 14, "shell_gold", "xy")
    root += [bc.blob("sand_pile", 0.0300, (0, 0, 0.0220), "shell_gold", 2, (1.0, 1.0, 0.45)), bc.cone("sand_fall", 0.0042, 0.0042, 0.0800, (0, 0, 0.0850), "fire_yellow", 8)]
    for k in range(5):  # sand windows
        a = math.radians(-60 + k * 30)
        root.append(bc.blob("window", 0.0060, (math.sin(a) * 0.0410, -math.cos(a) * 0.0410, 0.0640), "fire_yellow", 1, (1.0, 0.35, 1.5)))
    groups = [("", root, (0, 0, 0), "")]
    # clock face on the upper bulb: the face (hands turn)
    cf = V((0, -0.0390, 0.1780))
    face = [place(bc.cone("face", 0.0250, 0.0250, 0.0030, (0, 0, 0), "bone", 20), (90, 0, 0), tuple(cf)), place(bc.cone("rim", 0.0275, 0.0275, 0.0024, (0, 0, 0), "shell_gold", 20), (90, 0, 0), tuple(cf + V((0, 0.0014, 0))))]
    for k in range(12):
        a = 2 * PI * k / 12
        face.append(bc.box("tick", (0.0030, 0.0020, 0.0050 if k % 3 == 0 else 0.0030), (cf.x + math.sin(a) * 0.0205, cf.y - 0.0020, cf.z + math.cos(a) * 0.0205), "warden_dark" if k % 3 else "crystal_purple"))
    face += [bc.box("brow", (0.0400, 0.0030, 0.0040), (0, -0.0430, 0.1960), "warden_deep"), bc.blob("pupil", 0.0036, (cf.x, cf.y - 0.0030, cf.z), "ink", 1)]
    groups.append(("face", face, tuple(cf), ""))
    groups.append(("hand_min", [seg("min", V((cf.x, cf.y - 0.0030, cf.z)), V((cf.x + 0.0060, cf.y - 0.0030, cf.z + 0.0210)), 0.0020, 0.0006, "warden_dark", 4)], tuple(cf), "face"))
    groups.append(("hand_hour", [seg("hr", V((cf.x, cf.y - 0.0030, cf.z)), V((cf.x - 0.0120, cf.y - 0.0030, cf.z + 0.0110)), 0.0026, 0.0008, "warden_deep", 4)], tuple(cf), "face"))
    # clock-hand blade arms (long spade-ended hands)
    for s, nm in ((-1, "r"), (1, "l")):
        sh = V((s * 0.0420, -0.0100, 0.1200))
        pts = [sh, sh + V((s * 0.0200, -0.0140, 0.0020)), sh + V((s * 0.0380, -0.0260, 0.0200)), sh + V((s * 0.0420, -0.0380, 0.0420))]
        P = chain("arm", pts, [0.0050, 0.0044, 0.0036, 0.0014], "shell_gold", 6)
        P.append(flat("blade", [(pts[-1].x, pts[-1].y, pts[-1].z), (pts[-1].x + s * 0.0060, pts[-1].y - 0.0050, pts[-1].z + 0.0200), (pts[-1].x + s * 0.0020, pts[-1].y - 0.0080, pts[-1].z + 0.0380), (pts[-1].x - s * 0.0040, pts[-1].y - 0.0050, pts[-1].z + 0.0200)], 0.0030, "warden_deep", "x"))
        P += gear((sh.x + s * 0.0100, sh.y - 0.0060, sh.z + 0.0080), 0.0100, 10, 0.0030, "shell_copper")
        groups.append(("arm_" + nm, P, tuple(sh), ""))
    # gears on the bulbs (turning)
    for i, (gx, gy, gz, gr, n) in enumerate(((-0.0310, -0.0330, 0.0620, 0.0210, 14), (0.0330, -0.0300, 0.0480, 0.0160, 11), (0.0000, 0.0420, 0.0700, 0.0240, 16))):
        facing = "y"
        groups.append(("gear_%d" % (i + 1), gear((gx, gy, gz), gr, n, 0.0040, "shell_copper" if i != 1 else "shell_gold"), (gx, gy, gz), ""))
    # pendulum swinging in front of the lower bulb
    pend = chain("rod", [V((0, -0.0500, 0.1000)), V((0, -0.0560, 0.0600)), V((0, -0.0600, 0.0300))], [0.0016] * 3, "shell_gold", 5)
    pend += [place(bc.cone("bob", 0.0140, 0.0140, 0.0040, (0, 0, 0), "shell_gold", 16), (90, 0, 0), (0, -0.0610, 0.0220)),
             place(bc.cone("bob_core", 0.0080, 0.0080, 0.0050, (0, 0, 0), "crystal_purple", 12), (90, 0, 0), (0, -0.0640, 0.0220))]
    groups.append(("pendulum", pend, (0, -0.0500, 0.1000), ""))
    # broken clock-face wings
    for s, nm in ((-1, "r"), (1, "l")):
        b = V((s * 0.0300, 0.0420, 0.1500))
        P = []
        for a0, a1, R_, col in ((10, 150, 0.0560, "bone"), (170, 330, 0.0500, "warden_deep")):
            pts = [(b.x + s * math.cos(math.radians(a)) * R_, b.y + 0.0080 + (math.cos(math.radians(a)) * R_) * 0.0, b.z + math.sin(math.radians(a)) * R_ - (0.030 if a0 > 100 else 0)) for a in range(a0, a1 + 1, 20)]
            P.append(flat("wingpiece", [(b.x, b.y + 0.0080, b.z)] + pts, 0.0030, col))
        for k in range(8):
            a = math.radians(20 + k * 17)
            P.append(bc.box("tick", (0.0030, 0.0020, 0.0040), (b.x + s * math.cos(a) * 0.0490, b.y + 0.0070, b.z + math.sin(a) * 0.0490), "warden_dark"))
        P += [seg("hand", V((b.x, b.y + 0.0060, b.z)), V((b.x + s * 0.0330, b.y + 0.0060, b.z + 0.0300)), 0.0018, 0.0006, "shell_gold", 4)]
        groups.append(("wing_" + nm, P, tuple(b), ""))
    hours = []
    for k in range(12):  # orbiting hour markers
        a = 2 * PI * k / 12
        p = V((math.cos(a) * 0.0950, math.sin(a) * 0.0950, 0.1100 + 0.0200 * math.sin(k * 1.5)))
        hours.append(seg("marker", p + V((0, 0, -0.0070)), p + V((0, 0, 0.0070)), 0.0034, 0.0002, "shell_gold" if k % 3 else "crystal_purple", 4))
        hours.append(seg("marker", p + V((0, 0, -0.0070)), p + V((0, 0, -0.0130)), 0.0028, 0.0002, "shell_gold" if k % 3 else "crystal_purple", 4))
    groups.append(("hours", hours, (0, 0, 0.1100), ""))
    obj = bc.assemble("ew_boss_hourglass_tyrant_v01", groups)
    crystal_anchors(obj, 0.1250, 0.1050)
    bc.anchor(obj, "eye_anchor", (0, -0.0430, 0.1780), "face", 0.005)
    bc.anchor(obj, "sand_anchor", (0, 0, 0.1200), "", 0.006)
    bc.anchor(obj, "summon_anchor", (0, -0.0900, 0.0200), "", 0.008)
    return obj


BOSSES = {"eclipse_empress": eclipse_empress, "wandering_cathedral": wandering_cathedral, "hourglass_tyrant": hourglass_tyrant}

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    key = argv[0] if argv else "eclipse_empress"
    bc.clear_scene()
    obj = BOSSES[key]()
    mc.smooth(obj)
    print("TRIS", key, mc.tri_count(obj))
    bc.save_blend(obj, "boss_" + key)
