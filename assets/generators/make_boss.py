"""The Warden, concept 1: "the Hollow Warden" (Durva 2026-11-01: "otherworldly, not based on existing animals").

Run:  blender --factory-startup -b -P assets/generators/make_boss.py   (saves assets/blend/boss_warden.blend)

A tall levitating ritual guardian, not a creature: a ragged robe with no legs, a tall bone mask with three eye slits,
a halo of broken stone arches, four detached hands, and the shattered barrier ring behind it (the barrier it once kept).
Colours: warden purples (warden_deep, warden_dark; purple is the Warden's colour), bone, stone, gold chain. No blue, no animal shapes.
Size: footprint 3 x 3 cells (0.15 m), height about 5 cells (0.25 m). Budget 6000.
Parts: root (robe, shoulders, sigil, tatters), head (mask, crown), halo (spins), hand_ul/ur/ll/lr (float and gesture), ring (barrier shards).
Anchors: crystal_anchor_1..3 (the three shield crystals, ring at 2 cells), eye_anchor_1..3 (mask slits), sigil_anchor (chest seal),
summon_anchor_l / _r (between the upper hands: Grunt summons).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_characters as mc  # noqa: E402

bc, V, seg, chain, flat = mc.bc, mc.V, mc.seg, mc.chain, mc.flat
NAME = "ew_boss_warden_v01"


def hand(side, centre, up=False):
    """A big bone hand: cuff, palm, four long fingers and a thumb; fingers curl up for the raised hands."""
    s = side
    c = V(centre)
    P = [bc.cone("cuff", 0.0105, 0.0090, 0.0090, c + V((s * 0.0, 0.0, 0.0)), "warden_deep", 12),
         bc.blob("palm", 0.0120, c + V((0, -0.0060, 0.0075)), "bone", 2, (1.0, 0.55, 1.0))]
    for i, dx in enumerate((-0.0060, -0.0020, 0.0020, 0.0060)):
        L = 0.0150 - abs(dx) * 0.6
        base = c + V((dx, -0.0075, 0.0100))
        pts = [base, base + V((dx * 0.1, -0.0040, L * 0.55 if up else L * 0.60)), base + V((dx * 0.2, -0.0070, L * (0.95 if up else 0.85)))]
        P += chain("finger", pts, [0.0017, 0.0014, 0.0007], "bone", 6)
    thumb = [c + V((s * 0.0090, -0.0050, 0.0060)), c + V((s * 0.0130, -0.0070, 0.0100)), c + V((s * 0.0148, -0.0090, 0.0140))]
    P += chain("thumb", thumb, [0.0020, 0.0016, 0.0008], "bone", 6)
    return P


def build():
    root = []
    # robe: a tall cone, no legs, ragged hem touching the ground
    root += [bc.cone("robe", 0.0600, 0.0200, 0.1350, (0, 0, 0.0675), "warden_deep", 16),
             bc.cone("robe_dark", 0.0620, 0.0560, 0.0120, (0, 0, 0.0060), "warden_dark", 16),
             bc.cone("sash", 0.0300, 0.0285, 0.0100, (0, 0, 0.0780), "shell_gold", 16)]
    for i in range(10):  # tattered hem: ribbons hanging off the robe
        a = math.radians(i * 36 + 10)
        x0, y0 = math.cos(a) * 0.052, math.sin(a) * 0.052
        pts = [V((x0, y0, 0.030)), V((x0 * 1.10, y0 * 1.10, 0.016)), V((x0 * 1.18, y0 * 1.18, 0.0035))]
        root += chain("tatter", pts, [0.0050, 0.0036, 0.0006], "warden_dark" if i % 2 else "warden_deep", 5)
    # shoulders and collar
    root += [bc.blob("shoulders", 0.0260, (0, 0, 0.1420), "warden_dark", 2, (2.1, 0.95, 0.62)),
             bc.cone("collar", 0.0230, 0.0160, 0.0120, (0, 0, 0.1560), "warden_deep", 12)]
    # sigil seal on the chest: gold ring of ticks and a dark diamond
    for i in range(10):
        a = math.radians(i * 36)
        root.append(bc.box("tick", (0.0030, 0.0020, 0.0070), (math.sin(a) * 0.0150, -0.0262, 0.1030 + math.cos(a) * 0.0150), "shell_gold", rot_z_deg=0))
    root.append(mc.place(bc.cone("sigil_disc", 0.0120, 0.0120, 0.0030, (0, 0, 0), "warden_dark", 12), (90, 0, 0), (0, -0.0262, 0.1030)))
    root.append(bc.box("sigil_core", (0.0090, 0.0030, 0.0090), (0, -0.0285, 0.1030), "crystal_purple"))
    # chains of office crossing the chest
    for s in (-1, 1):
        root += chain("chain", [V((s * 0.0300, -0.0120, 0.1400)), V((s * 0.0160, -0.0270, 0.1180)), V((0, -0.0290, 0.1040))], [0.0016] * 3, "shell_gold", 6)
    groups = [("", root, (0, 0, 0), "")]

    # head: tall bone mask, three vertical eye slits, crack, side horns of bone
    head = [bc.blob("mask", 0.0290, (0, -0.0020, 0.1960), "bone", 3, (0.78, 0.62, 1.30)),
            bc.blob("hood", 0.0310, (0, 0.0100, 0.2010), "warden_dark", 2, (0.98, 0.85, 1.20))]
    for dx, h in ((-0.0105, 0.0100), (0.0, 0.0140), (0.0105, 0.0100)):
        head.append(bc.box("slit", (0.0040, 0.0040, h), (dx, -0.0275, 0.2020), "warden_dark"))
    head.append(bc.box("crack", (0.0016, 0.0030, 0.0160), (0.0050, -0.0285, 0.2250), "warden_dark"))
    head.append(bc.box("brow", (0.0300, 0.0030, 0.0040), (0, -0.0270, 0.2140), "warden_deep"))
    for s in (-1, 1):  # swept bone horns
        head += chain("horn", [V((s * 0.0170, 0.0, 0.2150)), V((s * 0.0300, 0.0040, 0.2300)), V((s * 0.0360, 0.0080, 0.2500)), V((s * 0.0330, 0.0100, 0.2680))],
                      [0.0060, 0.0048, 0.0032, 0.0004], "bone", 8)
    groups.append(("head", head, (0, 0, 0.1600), ""))

    # halo: floating broken stone arches ring above the head (spins)
    halo = []
    for i in range(7):
        a = math.radians(i * 51.4)
        r = 0.0400
        pts = [V((math.cos(a - 0.20) * r, math.sin(a - 0.20) * r, 0.2720)), V((math.cos(a) * r * 1.04, math.sin(a) * r * 1.04, 0.2760)), V((math.cos(a + 0.20) * r, math.sin(a + 0.20) * r, 0.2720))]
        halo += chain("arch", pts, [0.0040, 0.0046, 0.0040], "stone" if i % 2 else "stone_dark", 6)
    groups.append(("halo", halo, (0, 0, 0.2720), "head"))

    # four floating hands (upper pair raised, lower pair open)
    groups.append(("hand_ur", hand(-1, (-0.0780, -0.0200, 0.1900), up=True), (-0.0780, -0.0200, 0.1900), ""))
    groups.append(("hand_ul", hand(1, (0.0780, -0.0200, 0.1900), up=True), (0.0780, -0.0200, 0.1900), ""))
    groups.append(("hand_lr", hand(-1, (-0.0900, -0.0400, 0.0900)), (-0.0900, -0.0400, 0.0900), ""))
    groups.append(("hand_ll", hand(1, (0.0900, -0.0400, 0.0900)), (0.0900, -0.0400, 0.0900), ""))

    # the broken barrier: a big vertical ring of shards behind the Warden, with gaps (spins slowly)
    ring = []
    for i in range(16):
        if i in (3, 4, 10):
            continue
        a = math.radians(i * 22.5)
        x, z = math.cos(a) * 0.0900, 0.1700 + math.sin(a) * 0.0900
        sh = bc.box("shard", (0.0120, 0.0060, 0.0300), (0, 0, 0), "warden_deep" if i % 2 else "stone")
        sh.rotation_euler = (0, math.radians(90) - a, 0)
        bc.apply_transforms(sh)
        sh.location = (x, 0.0500, z)
        bc.apply_transforms(sh)
        ring.append(sh)
    groups.append(("ring", ring, (0, 0.0500, 0.1700), ""))

    obj = bc.assemble(NAME, groups)
    for i in range(3):  # shield crystals sit on a ring at 2 cells (0.10 m) from the centre
        a = math.radians(i * 120 + 90)
        bc.anchor(obj, "crystal_anchor_%d" % (i + 1), (math.cos(a) * 0.1000, math.sin(a) * 0.1000, 0.1300), "", 0.008)
    for i, dx in enumerate((-0.0105, 0.0, 0.0105)):
        bc.anchor(obj, "eye_anchor_%d" % (i + 1), (dx, -0.0300, 0.2020), "head", 0.004)
    bc.anchor(obj, "sigil_anchor", (0, -0.0300, 0.1030), "", 0.006)
    bc.anchor(obj, "summon_anchor_l", (0.0780, -0.0500, 0.2150), "hand_ul", 0.006)
    bc.anchor(obj, "summon_anchor_r", (-0.0780, -0.0500, 0.2150), "hand_ur", 0.006)
    mc.smooth(obj)
    return obj


if __name__ == "__main__":
    bc.clear_scene()
    obj = build()
    print("TRIS boss", mc.tri_count(obj))
    bc.save_blend(obj, "boss_warden")
