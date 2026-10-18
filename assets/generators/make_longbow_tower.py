"""Longbow Tower: design variants A-D (Siddharth, 2026-10-18: a GIANT LONGBOW, plain wooden bolts).

    blender --factory-startup -b -P assets/generators/make_longbow_tower.py -- A     (design variant A-D)

Role (GAME_SPEC): like the Fire Tower but weaker, longer range (6 cells), piercing: each bolt hits every
enemy in a line, 4 damage, one shot per 1.2 s. Footprint 2 x 2 cells, Fire Tower detail level.
Every variant carries the same idea: a tall curved wooden longbow standing upright, a plain wooden bolt
nocked on its string, pointing to the front (-Y). In the real asset the bow turns to aim (__head) and the
string and bolt draw back and release (Godot tween); the pierce flash is VFX.

Variants (shape ideas, original geometry; they differ in the base, so the towers separate at a glance):
    A  Lookout Perch    - slender timber-and-stone lookout, bow on a yoke at the very top (tall and thin)
    B  Bow Deck         - low wide timber deck on stone piers, bow on a turntable with a winch drum (low, open)
    C  Bow Gate         - two stone pillars hold the bow between them like a gate; stair to a small landing
    D  Windlass Keep    - square stone keep, bow on the roof with a big rope windlass behind it (mechanism)
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import blender_common as bc  # noqa: E402

NAME = "ew_defense_longbow_tower_v01"
R8 = 22.5


def place(objs, rot, loc):
    """Rotate parts built around the origin (degrees XYZ), then move them to loc."""
    for o in objs:
        bc.rotate(o, rot)
        o.location = loc
        bc.apply_transforms(o)
    return objs


def seg(name, a, b, w, d, col):
    """A box of width w (x) and depth d running from point a to point b in the Y-Z plane (x = a[0])."""
    ay, az, by_, bz = a[1], a[2], b[1], b[2]
    L = math.hypot(by_ - ay, bz - az)
    o = bc.box(name, (w, d, L), (0, 0, 0), col)
    bc.rotate(o, (math.degrees(math.atan2(-(by_ - ay), bz - az)), 0, 0))
    o.location = (a[0], (ay + by_) / 2, (az + bz) / 2)
    bc.apply_transforms(o)
    return o


def longbow(h=0.072, bulge=0.012, w=0.0042, draw=0.006):
    """Upright longbow built around its grip at the origin, shooting toward -Y.
    Limbs bulge forward (-Y), the string runs behind them (+Y) and is drawn back by `draw` at the nock,
    a plain wooden bolt sits on the string. Returns (parts, bolt_tip_point)."""
    n, hh = 8, h / 2
    pts = [(0, -bulge * (1 - (z / hh) ** 2), z) for z in [-hh + i * h / n for i in range(n + 1)]]
    parts = []
    for i in range(n):
        t = abs((pts[i][2] + pts[i + 1][2]) / 2) / hh            # 0 at the grip, 1 at the tips
        parts.append(seg("limb", pts[i], pts[i + 1], w * (1.15 - 0.45 * t), 0.0034, "wood_light"))
    parts.append(bc.box("grip", (w * 1.5, 0.0055, 0.012), (0, -bulge + 0.0005, 0), "wood_dark"))
    for z in (-hh, hh):  # horn tips
        parts.append(bc.box("tip", (w * 0.9, 0.004, 0.004), (0, 0, z + (0.0015 if z > 0 else -0.0015)), "roof_terracotta"))
    nock = (0, draw, 0)
    parts += [seg("string", (0, 0.0005, -hh), nock, 0.0012, 0.0012, "bone"),
              seg("string", nock, (0, 0.0005, hh), 0.0012, 0.0012, "bone")]
    # plain wooden bolt: shaft, iron head, fletching
    blen = 0.040
    tip_y = draw - blen
    parts += [
        seg("bolt", (0, draw, 0.0), (0, tip_y + 0.004, 0.0), 0.0022, 0.0022, "wood_light"),
        bc.cone("bolt_head", 0.0022, 0.0, 0.006, (0, 0, 0), "stone_dark", 4),
    ]
    head = parts[-1]
    head["no_bevel"] = True
    bc.rotate(head, (90, 0, 0))  # point toward -Y
    head.location = (0, tip_y + 0.001, 0)
    bc.apply_transforms(head)
    for sx in (-1, 1):
        parts.append(bc.box("fletch", (0.0005, 0.007, 0.0035), (sx * 0.0015, draw - 0.005, 0), "roof_terracotta"))
    return parts, (0, tip_y - 0.002, 0)


def mount_bow(parts_tip, rot_z, loc):
    parts, tip = parts_tip
    place(parts, (0, 0, rot_z), loc)
    return parts, (tip[0] + loc[0], tip[1] + loc[1], tip[2] + loc[2])


def variant_a():
    """Lookout Perch: slender, tall."""
    p = [
        bc.cone("footing", 0.036, 0.034, 0.008, (0, 0, 0.004), "stone_dark", 8, R8),
        bc.cone("stone", 0.029, 0.025, 0.040, (0, 0, 0.028), "stone", 8, R8),
        bc.cone("band", 0.027, 0.027, 0.005, (0, 0, 0.0505), "wood_dark", 8, R8),
    ]
    # open timber upper frame: 4 posts + braces + a small roofless deck
    for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        p.append(bc.box("post", (0.004, 0.004, 0.034), (sx * 0.017, sy * 0.017, 0.070), "wood_dark"))
    for a in (0, 90, 180, 270):
        br = bc.box("brace", (0.030, 0.003, 0.003), (0, 0, 0), "wood_light")
        place([br], (0, 35, a), (0.017 * math.cos(math.radians(a + 90)), 0.017 * math.sin(math.radians(a + 90)), 0.068))
        p.append(br)
    p += [bc.cone("deck", 0.030, 0.030, 0.004, (0, 0, 0.089), "wood_light", 8, R8),
          bc.cone("yoke_base", 0.008, 0.010, 0.006, (0, 0, 0.094), "wood_dark", 8, R8)]
    # door and a window slit
    p += [bc.box("door", (0.012, 0.004, 0.018), (0, -0.0285, 0.017), "wood_dark"),
          bc.box("slit", (0.003, 0.003, 0.010), (0.0265, 0, 0.034), "ink")]
    bow, tip = mount_bow(longbow(h=0.068), 0, (0, 0.002, 0.131))
    p += bow + [bc.box("yoke", (0.006, 0.006, 0.030), (0, 0.000, 0.110), "wood_dark")]
    return p, tip


def variant_b():
    """Bow Deck: low, wide, open timber."""
    p = [bc.box("pier", (0.016, 0.016, 0.014), (sx * 0.030, sy * 0.030, 0.007), "stone")
         for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1))]
    p += [bc.box("deck", (0.084, 0.084, 0.005), (0, 0, 0.0165), "wood_light")]
    for i in range(5):  # plank lines
        p.append(bc.box("plank_gap", (0.084, 0.0008, 0.0006), (0, -0.034 + i * 0.017, 0.0192), "wood_dark"))
    for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        p.append(bc.box("rail_post", (0.004, 0.004, 0.012), (sx * 0.039, sy * 0.039, 0.025), "wood_dark"))
    p += [bc.box("rail", (0.082, 0.003, 0.003), (0, sy * 0.039, 0.030), "wood_dark") for sy in (1,)]
    p += [bc.box("rail", (0.003, 0.082, 0.003), (sx * 0.039, 0, 0.030), "wood_dark") for sx in (-1, 1)]
    p += [bc.cone("turntable", 0.022, 0.022, 0.005, (0, 0, 0.0215), "wood_dark", 8, R8),
          bc.box("cradle", (0.010, 0.014, 0.014), (0, 0.002, 0.031), "wood_dark")]
    # winch drum behind the bow with rope coil
    drum = bc.cone("winch", 0.006, 0.006, 0.022, (0, 0, 0), "wood_light", 8)
    place([drum], (0, 90, 0), (0, 0.020, 0.030))
    p += [drum] + [bc.box("winch_post", (0.003, 0.004, 0.016), (sx * 0.013, 0.020, 0.027), "wood_dark") for sx in (-1, 1)]
    p += [bc.cone("rope", 0.0068, 0.0068, 0.010, (0, 0, 0), "bone", 8)]
    place([p[-1]], (0, 90, 0), (0, 0.020, 0.030))
    p += [bc.box("quiver", (0.010, 0.008, 0.014), (-0.028, -0.026, 0.026), "roof_terracotta")]
    p += [bc.box("bolt_spare", (0.0018, 0.0018, 0.020), (-0.028 + dx, -0.026, 0.038), "wood_light") for dx in (-0.002, 0.002)]
    bow, tip = mount_bow(longbow(h=0.076, bulge=0.013), 0, (0, 0.0, 0.076))
    return p + bow, tip


def variant_c():
    """Bow Gate: the bow stands between two stone pillars."""
    p = [bc.box("plinth", (0.084, 0.060, 0.008), (0, 0, 0.004), "stone_dark")]
    for sx in (-1, 1):
        p += [bc.box("pillar", (0.018, 0.022, 0.070), (sx * 0.030, 0.004, 0.043), "stone"),
              bc.box("pillar_cap", (0.022, 0.026, 0.005), (sx * 0.030, 0.004, 0.0805), "roof_terracotta")]
        for z in (0.020, 0.045):
            p.append(bc.box("block", (0.0185, 0.012, 0.006), (sx * 0.030, -0.006, z), "stone_dark"))
    p += [bc.box("lintel", (0.078, 0.010, 0.006), (0, 0.010, 0.086), "wood_dark")]
    # landing and steps at the back
    p += [bc.box("landing", (0.040, 0.020, 0.020), (0, 0.020, 0.018), "stone")]
    for i in range(3):
        p.append(bc.box("step", (0.020, 0.006, 0.006), (0, 0.033 + i * 0.000, 0.003 + i * 0.006), "stone_dark"))
    p += [bc.box("pin", (0.042, 0.004, 0.004), (0, 0.000, 0.050), "ink")]  # axle the bow pivots on
    bow, tip = mount_bow(longbow(h=0.070, bulge=0.012), 0, (0, 0.002, 0.050))
    return p + bow, tip


def variant_d():
    """Windlass Keep: square stone keep, windlass behind the bow."""
    p = [
        bc.box("footing", (0.082, 0.082, 0.008), (0, 0, 0.004), "stone_dark"),
        bc.box("keep", (0.070, 0.070, 0.044), (0, 0, 0.030), "stone"),
        bc.box("parapet_band", (0.076, 0.076, 0.004), (0, 0, 0.054), "wood_dark"),
    ]
    for i in range(4):  # corner merlons
        a = math.radians(45 + i * 90)
        p.append(bc.box("merlon", (0.012, 0.012, 0.010), (0.031 * math.cos(a) * 1.41, 0.031 * math.sin(a) * 1.41, 0.061), "stone"))
    p += [bc.box("door", (0.014, 0.004, 0.020), (0, -0.0365, 0.018), "wood_dark"),
          bc.box("door_frame", (0.020, 0.003, 0.025), (0, -0.0355, 0.0205), "stone_dark"),
          bc.box("window", (0.010, 0.003, 0.010), (0.0355, 0, 0.034), "ink"),
          bc.box("shutter", (0.004, 0.006, 0.010), (0.0365, -0.008, 0.034), "roof_orange")]
    for z in (0.016, 0.040):
        p.append(bc.box("block", (0.013, 0.004, 0.006), (-0.0355, 0.010, z), "stone_dark"))
    p += [bc.cone("turntable", 0.024, 0.024, 0.004, (0, 0, 0.058), "wood_dark", 8, R8)]
    # big windlass: drum between two A-frames behind the bow
    drum = bc.cone("windlass", 0.008, 0.008, 0.030, (0, 0, 0), "wood_light", 8)
    place([drum], (0, 90, 0), (0, 0.016, 0.072))
    p.append(drum)
    for sx in (-1, 1):
        for dy in (-1, 1):
            leg = bc.box("aframe", (0.003, 0.003, 0.018), (0, 0, 0), "wood_dark")
            place([leg], (dy * 18, 0, 0), (sx * 0.017, 0.016 + dy * 0.003, 0.068))
            p.append(leg)
        spoke = bc.box("handle", (0.002, 0.002, 0.016), (0, 0, 0), "wood_dark")
        place([spoke], (40, 0, 0), (sx * 0.019, 0.016, 0.072))
        p.append(spoke)
    p.append(bc.box("rope_line", (0.0012, 0.012, 0.0012), (0, 0.010, 0.076), "bone"))
    bow, tip = mount_bow(longbow(h=0.064, bulge=0.011), 0, (0, -0.004, 0.096))
    p += bow + [bc.box("mast", (0.005, 0.005, 0.026), (0, -0.004, 0.073), "wood_dark")]
    return p, tip


VARIANTS = {"A": variant_a, "B": variant_b, "C": variant_c, "D": variant_d}


def build(params=None, seed=0):
    v = (params or {}).get("variant", "A")
    parts, bolt_tip = VARIANTS[v]()
    root = bc.assemble(NAME, [("", parts, (0, 0, 0), None)])
    bc.anchor(root, "bolt_anchor", bolt_tip, size=0.004)
    bc.anchor(root, "pulse_anchor", (0, 0, 0), size=0.05)
    return root


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    v = args[0] if args else "A"
    bc.clear_scene()
    obj = build({"variant": v})
    print("BLEND", bc.save_blend(obj, "longbow_tower_" + v))
