"""Guard Tower (replaces the Blast Brazier, Siddharth 2026-10-26): design variants A-D.

    blender --factory-startup -b -P assets/generators/make_guard_tower.py -- A      (variant A-D, saved only)

Role: a SPAWNING tower. It makes Guards (3 per tower, 30 HP, 4 damage a hit, a replacement every 8 s); they stand
in a ring touching the tower, never wander, and only move and attack when an enemy comes into their sight (then they
walk back to their post). Ground only. Footprint 2 x 2 cells (0.10 m), about 85% filled, Fire Tower detail level.
It must read at a glance as different from the tall Wizard Tower: low and wide, a "ours, friendly" village building
(cream, teal, terracotta; shape language round and stable, art bible 4). Magic is black / orange / red, never blue;
there is no magic here, so none is used. Empties for Godot:
    __spawn_anchor  at the door: where each new Guard steps out
    __pulse_anchor  ground centre (range / sight ring reference)
A small placeholder guard stands in each preview (3 in a ring in front) so the scale and the ring can be judged;
Durva's character kit replaces them and the final export has none.

Variants (shape ideas, original geometry):
    A  Barracks Hall   - a low long hall, teal gable roof, banner pole, shields on the wall, a big front door
    B  Gatehouse       - a squat stone gate tower with an arch, battlements, two teal-roofed corner turrets, a shield emblem
    C  Palisade Fort   - a round stone keep inside a ring of timber stakes with a gate gap, a banner on the keep
    D  Watch Post      - a small square watch tower with a lean-to armoury of spears and shields beside it
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import blender_common as bc  # noqa: E402

NAME = "ew_defense_guard_tower_v01"
R8 = 22.5


def tilted(o, rot, loc):
    bc.rotate(o, rot)
    o.location = loc
    bc.apply_transforms(o)
    return o


def shield(x, y, z, r=0.0065, col="roof_terracotta", face_deg=0.0):
    """A round shield hung on a wall that faces -Y (face_deg 0), or +X (90) / -X (-90) / +Y (180)."""
    disc = bc.cone("shield", r, r, 0.003, (0, 0, 0), col, 8)
    boss = bc.cone("shield_boss", r * 0.35, r * 0.35, 0.0022, (0, 0, 0.0025), "ink", 6)
    out = []
    for o in (disc, boss):
        bc.rotate(o, (90, 0, 0))  # axis from Z to Y: faces -Y
        o.rotation_euler = (0, 0, math.radians(face_deg))
        bc.apply_transforms(o)
        o.location = (x, y, z)
        bc.apply_transforms(o)
        out.append(o)
    return out


def shield_kite(x, y, z, col="roof_terracotta"):
    """A heater shield (square top, pointed bottom) on a wall facing -Y, z = its centre."""
    top = bc.box("kite_top", (0.0125, 0.003, 0.0075), (x, y, z + 0.0025), col)
    tip = bc.box("kite_tip", (0.0090, 0.003, 0.0090), (0, 0, 0), col)
    tilted(tip, (0, 45, 0), (x, y, z - 0.0020))
    boss = bc.blob("kite_boss", 0.0022, (x, y - 0.0018, z + 0.0005), "ink", 1)
    return [top, tip, boss]


def banner(x, y, z0, h=0.050, col="roof_terracotta"):
    """Pole with a pennant banner and a gold dot."""
    return [
        bc.box("pole", (0.003, 0.003, h), (x, y, z0 + h / 2), "wood_dark"),
        bc.box("banner", (0.014, 0.0022, 0.018), (x + 0.0085, y, z0 + h - 0.011), col),
        bc.blob("banner_dot", 0.0028, (x + 0.0085, y - 0.0018, z0 + h - 0.0105), "fire_yellow", 1),
        bc.cone("pole_cap", 0.0030, 0.0030, 0.003, (x, y, z0 + h + 0.0015), "stone_dark", 6),
    ]


def guard(x, y, z=0.0):
    """Placeholder guard, 0.7 cell tall (preview only): teal tunic, stone helmet, a spear."""
    g = [bc.cone("tunic", 0.0075, 0.0045, 0.020, (x, y, z + 0.010), "roof_teal", 8),
         bc.blob("head", 0.0055, (x, y, z + 0.0255), "skin_light", 1),
         bc.cone("helmet", 0.0062, 0.0050, 0.0065, (x, y, z + 0.0300), "stone", 8),
         bc.box("spear", (0.0016, 0.0016, 0.040), (x + 0.0095, y, z + 0.020), "wood_light"),
         bc.cone("spear_tip", 0.0030, 0.0, 0.007, (x + 0.0095, y, z + 0.0435), "stone", 4)]
    g[3]["no_bevel"] = True
    g[4]["no_bevel"] = True
    return g


def ring_guards(radius=0.074):
    return guard(-0.034, -radius) + guard(0.0, -radius - 0.004) + guard(0.034, -radius)


def variant_a():
    """Barracks Hall."""
    p = [
        bc.box("foundation", (0.088, 0.076, 0.008), (0, 0, 0.004), "stone_dark"),
        bc.box("walls_low", (0.082, 0.070, 0.014), (0, 0, 0.015), "stone"),
        bc.box("walls_up", (0.080, 0.068, 0.018), (0, 0, 0.031), "wall_cream"),
        bc.gable("roof", 0.092, 0.080, 0.028, (0, 0, 0.040), "roof_teal"),
        bc.box("ridge", (0.007, 0.084, 0.006), (0, 0, 0.0685), "roof_terracotta"),
        bc.box("eave_f", (0.094, 0.004, 0.004), (0, -0.040, 0.041), "wood_dark"),
        bc.box("eave_b", (0.094, 0.004, 0.004), (0, 0.040, 0.041), "wood_dark"),
        bc.box("chimney", (0.010, 0.010, 0.020), (0.026, 0.014, 0.0615), "stone_dark"),
        # big front door under the eave, stone frame, step
        bc.box("door_frame", (0.026, 0.004, 0.026), (0, -0.0355, 0.021), "stone_dark"),
        bc.box("door", (0.020, 0.0045, 0.022), (0, -0.0365, 0.019), "wood_dark"),
        bc.box("door_strap", (0.020, 0.005, 0.002), (0, -0.0368, 0.021), "ink"),
        bc.box("step", (0.030, 0.008, 0.005), (0, -0.0425, 0.0025), "stone_dark"),
    ]
    p += [bc.box("beam", (0.004, 0.0035, 0.018), (x, -0.0345, 0.031), "wood_dark") for x in (-0.034, -0.022, 0.022, 0.034)]
    p += shield(-0.0295, -0.0365, 0.029, 0.0088, "roof_terracotta") + shield(0.0295, -0.0365, 0.029, 0.0088, "roof_orange")
    p += [bc.box("window", (0.003, 0.010, 0.010), (0.0405, 0, 0.032), "lantern_glow"),
          bc.box("window", (0.003, 0.010, 0.010), (-0.0405, 0, 0.032), "lantern_glow")]
    for w in p[-2:]:
        bc.paint(w, "lantern_glow", glow=True)
    p += banner(-0.040, -0.030, 0.008, 0.062)
    return p, (0, -0.0385, 0.002)


def variant_b():
    """Gatehouse."""
    p = [
        bc.box("foundation", (0.088, 0.076, 0.008), (0, 0, 0.004), "stone_dark"),
        bc.box("body", (0.080, 0.068, 0.036), (0, 0, 0.026), "stone"),
        bc.box("band", (0.083, 0.071, 0.004), (0, 0, 0.0455), "wood_dark"),
        bc.box("parapet_base", (0.086, 0.074, 0.004), (0, 0, 0.0505), "stone_dark"),
    ]
    # battlements all round (merlons on the edge of the top)
    for x in (-0.030, -0.010, 0.010, 0.030):
        p.append(bc.box("merlon", (0.012, 0.007, 0.009), (x, -0.0335, 0.0565), "stone"))
        p.append(bc.box("merlon", (0.012, 0.007, 0.009), (x, 0.0335, 0.0565), "stone"))
    for y in (-0.014, 0.014):
        p.append(bc.box("merlon", (0.007, 0.012, 0.009), (-0.0395, y, 0.0565), "stone"))
        p.append(bc.box("merlon", (0.007, 0.012, 0.009), (0.0395, y, 0.0565), "stone"))
    # arched gate: frame, dark opening, door leaves, arch top as a half-disc
    p += [
        bc.box("gate_frame", (0.030, 0.004, 0.030), (0, -0.0345, 0.023), "stone_dark"),
        bc.box("gate", (0.022, 0.005, 0.022), (0, -0.0355, 0.019), "ink"),
        bc.box("gate_door", (0.010, 0.0045, 0.020), (-0.0055, -0.0365, 0.018), "wood_dark"),
        bc.box("gate_door", (0.010, 0.0045, 0.020), (0.0055, -0.0365, 0.018), "wood_dark"),
        bc.box("step", (0.032, 0.008, 0.005), (0, -0.0425, 0.0025), "stone_dark"),
    ]
    arch = bc.cone("arch", 0.011, 0.011, 0.005, (0, 0, 0), "ink", 8)
    tilted(arch, (90, 0, 0), (0, -0.0355, 0.030))
    p.append(arch)
    p += shield(0, -0.0355, 0.0405, 0.0072, "roof_terracotta")
    # corner turrets with teal cone roofs
    for sx in (-1, 1):
        p.append(bc.cone("turret", 0.0120, 0.0120, 0.030, (sx * 0.0375, -0.0295, 0.058), "stone", 8, R8))
        p.append(bc.cone("turret_roof", 0.0150, 0.0, 0.018, (sx * 0.0375, -0.0295, 0.082), "roof_teal", 8, R8))
        p[-1]["no_bevel"] = True
    p += banner(0.0, 0.020, 0.0545, 0.040)
    return p, (0, -0.0385, 0.002)


def variant_c():
    """Palisade Fort."""
    p = [
        bc.cone("ground_ring", 0.044, 0.043, 0.006, (0, 0, 0.003), "stone_dark", 10),
        bc.cone("keep", 0.027, 0.025, 0.034, (0, 0, 0.023), "stone", 8, R8),
        bc.cone("keep_band", 0.0275, 0.0275, 0.004, (0, 0, 0.030), "wood_dark", 8, R8),
        bc.cone("keep_roof", 0.032, 0.006, 0.030, (0, 0, 0.055), "roof_teal", 8, R8),
        bc.cone("keep_eave", 0.032, 0.032, 0.003, (0, 0, 0.0395), "wood_dark", 8, R8),
        bc.box("keep_door", (0.012, 0.004, 0.016), (0, -0.0255, 0.0145), "wood_dark"),
        bc.box("keep_door_frame", (0.016, 0.003, 0.019), (0, -0.0245, 0.0160), "stone_dark"),
    ]
    # palisade: stakes round the keep, a gap at the front (the gate)
    n = 10
    for i in range(n):
        deg = 270 + (i - (n - 1) / 2) * (300 / (n - 1))  # 300 degrees round, centred on the back
        a = math.radians(deg + 180)
        x, y = 0.040 * math.cos(a), 0.040 * math.sin(a)
        h = 0.026 + 0.003 * ((i * 7) % 3)
        st = bc.box("stake", (0.0095, 0.0095, h), (x, y, 0.003 + h / 2), "wood_light", rot_z_deg=math.degrees(a) + 90)
        st["no_bevel"] = True  # keeps the triangle count in budget
        p.append(st)
        tip = bc.cone("stake_tip", 0.0070, 0.0, 0.007, (x, y, 0.003 + h + 0.003), "wood_light", 4, 45)
        tip["no_bevel"] = True
        p.append(tip)
    # gate posts and a crossbar at the front
    for sx in (-1, 1):
        p.append(bc.box("gate_post", (0.008, 0.008, 0.036), (sx * 0.0135, -0.040, 0.021), "wood_dark"))
    p.append(bc.box("gate_beam", (0.036, 0.006, 0.006), (0, -0.040, 0.038), "wood_dark"))
    p += shield(0, -0.0435, 0.034, 0.0058, "roof_terracotta")
    p += banner(0.0, 0.0, 0.0735, 0.030)
    p.append(bc.box("step", (0.020, 0.008, 0.005), (0, -0.045, 0.0025), "stone_dark"))
    return p, (0, -0.0395, 0.002)


def variant_d():
    """Watch Post."""
    p = [
        bc.box("foundation", (0.088, 0.076, 0.008), (0, 0, 0.004), "stone_dark"),
        bc.box("tower_low", (0.046, 0.046, 0.022), (-0.020, 0.008, 0.019), "stone"),
        bc.box("tower_up", (0.044, 0.044, 0.018), (-0.020, 0.008, 0.043), "wall_cream"),
        bc.box("tower_band", (0.049, 0.049, 0.004), (-0.020, 0.008, 0.032), "wood_dark"),
        bc.box("deck", (0.052, 0.052, 0.004), (-0.020, 0.008, 0.054), "wood_dark"),
    ]
    for i in range(4):  # merlons on the deck corners and mid-sides
        for (dx, dy) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
            pass
    for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1), (0, -1), (0, 1), (-1, 0), (1, 0)):
        p.append(bc.box("merlon", (0.009, 0.009, 0.008), (-0.020 + dx * 0.0215, 0.008 + dy * 0.0215, 0.060), "stone"))
    p += banner(-0.020, 0.008, 0.056, 0.034)
    # door and window on the tower
    p += [bc.box("door_frame", (0.018, 0.004, 0.022), (-0.020, -0.0165, 0.019), "stone_dark"),
          bc.box("door", (0.013, 0.0045, 0.020), (-0.020, -0.0175, 0.018), "wood_dark"),
          bc.box("step", (0.022, 0.008, 0.005), (-0.020, -0.023, 0.0025), "stone_dark")]
    win = bc.box("window", (0.010, 0.003, 0.011), (-0.020, -0.0155, 0.043), "lantern_glow")
    bc.paint(win, "lantern_glow", glow=True)
    p.append(win)
    # lean-to armoury beside the tower: posts, a teal shed roof sloping down, a spear rack and shields
    p += [bc.box("shed_post", (0.004, 0.004, 0.026), (0.039, -0.022, 0.021), "wood_dark"),
          bc.box("shed_post", (0.004, 0.004, 0.026), (0.039, 0.030, 0.021), "wood_dark"),
          bc.box("shed_back", (0.003, 0.052, 0.024), (0.004, 0.004, 0.020), "wood_light")]
    roof = bc.box("shed_roof", (0.030, 0.058, 0.004), (0, 0, 0), "roof_teal")
    tilted(roof, (0, 12, 0), (0.0245, 0.004, 0.0345))
    p.append(roof)
    p.append(bc.box("rack", (0.006, 0.034, 0.003), (0.030, 0.004, 0.012), "wood_dark"))
    for i in range(3):
        y = -0.010 + i * 0.014
        sp = bc.box("spear", (0.0035, 0.0035, 0.022), (0.0305, y, 0.023), "wood_light")
        p.append(sp)
        tp = bc.cone("spear_tip", 0.0042, 0.0, 0.008, (0.0305, y, 0.038), "stone", 4)
        tp["no_bevel"] = True
        p.append(tp)
    p += shield(0.0345, -0.0235, 0.0105, 0.0058, "roof_terracotta", face_deg=-90)
    return p, (-0.020, -0.0235, 0.002)


# ---- round 2 (Siddharth: B's vibe, C's shape, D's overall design) ----------------------------------------
# An octagonal stone keep (C's shape) with B's arched gate, shield emblem and teal turrets or battlements, and D's
# lean-to armoury of spears and shields on its right side. The door and the gate face the front (-Y).

KX = -0.014  # keep centre (the lean-to takes the right side of the 2 x 2 footprint)


def at_keep(o, dx=0.0):
    o.location.x += KX + dx
    bc.apply_transforms(o)
    return o


def keep_base(r=0.032, top=0.050, cream_from=None):
    """Foundation, octagonal stone keep (optionally a cream upper storey from cream_from), a timber band, the gate."""
    wall = (r, r * 0.9, 0.008, top)
    p = [bc.box("foundation", (0.088, 0.076, 0.008), (0, 0, 0.004), "stone_dark")]
    if cream_from is None:
        p.append(bc.cone("keep", wall[0], wall[1], top - 0.008, (KX, 0, (0.008 + top) / 2), "stone", 8, R8))
    else:
        rm = r + (r * 0.9 - r) * (cream_from - 0.008) / (top - 0.008)
        p.append(bc.cone("keep_low", wall[0], rm, cream_from - 0.008, (KX, 0, (0.008 + cream_from) / 2), "stone", 8, R8))
        p.append(bc.cone("keep_up", rm, wall[1], top - cream_from, (KX, 0, (cream_from + top) / 2), "wall_cream", 8, R8))
        p.append(bc.cone("keep_band", rm + 0.0025, rm + 0.0025, 0.004, (KX, 0, cream_from), "wood_dark", 8, R8))
    p.append(bc.cone("eave", r * 0.9 + 0.004, r * 0.9 + 0.004, 0.004, (KX, 0, top + 0.002), "wood_dark", 8, R8))
    # the arched gate (B): stone frame, dark opening, two door leaves, an arch top, the step
    gz = 0.022
    ap = r * math.cos(math.pi / 8) - 0.0005
    p += [
        bc.box("gate_frame", (0.026, 0.004, 0.030), (KX, -ap - 0.0005, gz + 0.003), "stone_dark"),
        bc.box("gate", (0.018, 0.005, 0.022), (KX, -ap - 0.0015, gz), "ink"),
        bc.box("gate_door", (0.0085, 0.0045, 0.020), (KX - 0.0045, -ap - 0.0025, gz - 0.001), "wood_dark"),
        bc.box("gate_door", (0.0085, 0.0045, 0.020), (KX + 0.0045, -ap - 0.0025, gz - 0.001), "wood_dark"),
        bc.box("step", (0.028, 0.008, 0.005), (KX, -ap - 0.0065, 0.0025 + 0.003), "stone_dark"),
    ]
    arch = bc.cone("arch", 0.009, 0.009, 0.005, (0, 0, 0), "ink", 8)
    tilted(arch, (90, 0, 0), (KX, -ap - 0.0015, gz + 0.011))
    p.append(arch)
    p += shield_kite(KX, -ap - 0.0025, gz + 0.0195)
    return p, ap


def armoury(h=0.030):
    """D's lean-to on the right: posts, a teal shed roof sloping out, a back wall against the keep, chunky spears
    and shields."""
    p = [bc.box("shed_post", (0.0065, 0.0065, h), (0.0405, -0.022, 0.008 + h / 2), "wood_dark"),
         bc.box("shed_post", (0.0065, 0.0065, h), (0.0405, 0.026, 0.008 + h / 2), "wood_dark"),
         bc.box("shed_back", (0.003, 0.050, h - 0.004), (0.0165, 0.002, 0.008 + (h - 0.004) / 2), "wood_light")]
    roof = bc.box("shed_roof", (0.032, 0.056, 0.004), (0, 0, 0), "roof_teal")
    tilted(roof, (0, 13, 0), (0.0285, 0.002, 0.008 + h + 0.0005))
    p.append(roof)
    p.append(bc.box("rack", (0.006, 0.034, 0.003), (0.027, 0.002, 0.015), "wood_dark"))
    for i in range(3):
        y = -0.012 + i * 0.014
        p.append(bc.box("spear", (0.0046, 0.0046, 0.015), (0.027, y, 0.0225), "wood_light"))  # stays under the roof
        tp = bc.cone("spear_tip", 0.0055, 0.0, 0.007, (0.027, y, 0.0325), "stone", 4)
        tp["no_bevel"] = True
        p.append(tp)
    p += shield(0.0425 - 0.002, -0.0125, 0.0155, 0.0058, "roof_terracotta", face_deg=-90)
    return p


def keep_roof(r_eave, z, h=0.032, tip_flag=True):
    p = [bc.cone("keep_roof", r_eave, 0.006, h, (KX, 0, z + h / 2), "roof_teal", 8, R8)]
    if tip_flag:
        p += banner(KX, 0.0, z + h - 0.003, 0.026)
    return p


def variant_e():
    """Keep and Armoury: B's gate on C's keep, D's lean-to, the teal cone roof."""
    p, ap = keep_base()
    p += keep_roof(0.0385, 0.054)
    p += armoury()
    return p, (KX, -ap - 0.004, 0.002)


def variant_f():
    """Battlement Keep: the same keep with B's battlements and a small cream drum under the cone roof."""
    p, ap = keep_base()
    for i in range(6):
        a = math.radians(i * 60 + 30)
        p.append(bc.box("merlon", (0.011, 0.007, 0.010), (KX + 0.0275 * math.cos(a), 0.0275 * math.sin(a), 0.0575), "stone", rot_z_deg=math.degrees(a) + 90))
    p.append(bc.cone("drum", 0.019, 0.017, 0.016, (KX, 0, 0.061), "wall_cream", 8, R8))
    p += keep_roof(0.0235, 0.069, h=0.026)
    p += armoury()
    return p, (KX, -ap - 0.004, 0.002)


def variant_g():
    """Turret Keep: the keep with B's two corner turrets and a cone roof."""
    p, ap = keep_base()
    for sx in (-1, 1):
        tx, ty = KX + sx * 0.0215, -0.0245
        p.append(bc.cone("turret", 0.0105, 0.0105, 0.034, (tx, ty, 0.025), "stone", 8, R8))
        p.append(bc.cone("turret_eave", 0.0125, 0.0125, 0.003, (tx, ty, 0.0425), "wood_dark", 8, R8))
        cap = bc.cone("turret_roof", 0.0135, 0.0, 0.018, (tx, ty, 0.0535), "roof_teal", 8, R8)
        cap["no_bevel"] = True
        p.append(cap)
    p += keep_roof(0.0385, 0.054, h=0.030)
    p += armoury()
    return p, (KX, -ap - 0.004, 0.002)


def variant_h():
    """Two-tone Keep: a stone lower storey and a cream upper storey like D, wider and a little lower, cone roof."""
    p, ap = keep_base(r=0.033, top=0.048, cream_from=0.030)
    p += keep_roof(0.0395, 0.052, h=0.028)
    p += armoury()
    return p, (KX, -ap - 0.004, 0.002)


def build_final(seed=0):
    """The chosen design (Siddharth picked E, 2026-10-26): Keep and Armoury, as the real game asset. No guards in the
    model: the troops are characters from the character kit, which stand in a ring touching the tower.

    Parts (moved separately in Godot, no rig):
        ew_defense_guard_tower_v01                 keep, roof, armoury (static)
        ew_defense_guard_tower_v01__door_l / __door_r   the two gate leaves, pivots on their outer hinges: swing open
                                                   when a Guard steps out
        ew_defense_guard_tower_v01__banner         pennant and pole, pivot at the pole's foot: flutter or sway
        ew_defense_guard_tower_v01__spawn_anchor   empty in the gateway: where each new Guard appears
        ew_defense_guard_tower_v01__pulse_anchor   empty at ground centre (sight / range ring reference)
    """
    base, ap = keep_base()
    doors = [o for o in base if o.name.startswith("gate_door")]
    base = [o for o in base if not o.name.startswith("gate_door")]
    base += keep_roof(0.0385, 0.054, tip_flag=False) + armoury()
    ban = banner(KX, 0.0, 0.054 + 0.032 - 0.003, 0.026)
    gz = 0.022
    gy = -ap - 0.0025
    dl, dr = doors[0], doors[1]
    groups = [("", base, (0, 0, 0), None),
              ("door_l", [dl], (KX - 0.0045 - 0.00425, gy, gz), ""),
              ("door_r", [dr], (KX + 0.0045 + 0.00425, gy, gz), ""),
              ("banner", ban, (KX, 0.0, 0.054 + 0.032 - 0.003), "")]
    root = bc.assemble(NAME, groups)
    bc.anchor(root, "spawn_anchor", (KX, -ap - 0.004, 0.002), size=0.008)
    bc.anchor(root, "pulse_anchor", (0, 0, 0), size=0.05)
    return root


VARIANTS = {"A": variant_a, "B": variant_b, "C": variant_c, "D": variant_d,
            "E": variant_e, "F": variant_f, "G": variant_g, "H": variant_h}


def build(params=None, seed=0):
    v = (params or {}).get("variant", "A")
    parts, door_at = VARIANTS[v]()
    parts += ring_guards()
    root = bc.assemble(NAME, [("", parts, (0, 0, 0), None)])
    bc.anchor(root, "spawn_anchor", door_at, size=0.008)
    bc.anchor(root, "pulse_anchor", (0, 0, 0), size=0.05)
    return root


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    v = args[0] if args else "final"
    bc.clear_scene()
    if v == "final":
        obj = build_final()
        print("BLEND", bc.save_blend(obj, "guard_tower"))
        print("EXPORT", bc.export_glb(obj, "defense"))
    else:
        obj = build({"variant": v})
        print("BLEND", bc.save_blend(obj, "guard_tower_" + v))
