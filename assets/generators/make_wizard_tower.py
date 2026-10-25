"""Wizard Tower (replaces the Fire Tower, Siddharth 2026-10-26): design variants A-D.

    blender --factory-startup -b -P assets/generators/make_wizard_tower.py -- A      (variant A-D, saved only)

Role is unchanged from the Fire Tower (GAME_SPEC 7): long range, one target, a fireball per shot, no AoE.
What changes is the look and the animation: a wizard's tower. Footprint 2 x 2 cells (0.10 m), about 85% filled,
Fire Tower detail level, height about 3.3 to 3.8 cells. Style references: moodboard #8 (round tower, pointed cap,
a flame floating above), #24 and #27 (wizard hats), plus the family of our own Fire Tower (octagonal stone body,
cream storey, timber framing).

Empties for Godot (the orb itself is VFX, never geometry; spec 10 and Siddharth's rule):
    __orb_anchor    where the floating fire orb sits (bobs, charges, spits the fireball)
    __pulse_anchor  ground centre (range ring reference)

Magic is black / orange / red, never blue.

Variants (shape ideas, original geometry):
    A  Hat Spire       - the Fire Tower's stone body with a tall bent black wizard-hat roof; the orb floats above the tip
    B  Open Belfry     - stone base, an open timber chamber under a terracotta cap; the orb floats inside, visible
    C  Horned Cage     - tall plain stone shaft, a crown of four ink horns curving over the orb like a cage
    D  Spiral Stair    - a round tower with an outer stair winding up to a balcony and a hoop round the orb
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import blender_common as bc  # noqa: E402

NAME = "ew_defense_wizard_tower_v02"
R8 = 22.5
LOWER = (0.037, 0.033, 0.010, 0.062)   # stone storey frustum (r_bottom, r_top, z_bottom, z_top)
UPPER = (0.033, 0.031, 0.070, 0.100)   # cream storey


def ring(n, r, z, size, col, start=22.5, name="ring"):
    out = []
    for i in range(n):
        a = math.radians(start + i * 360 / n)
        out.append(bc.box(name, size, (r * math.cos(a), r * math.sin(a), z), col, rot_z_deg=math.degrees(a) + 90))
    return out


def glow(o, col):
    bc.paint(o, col, glow=True)
    return o


def stone_body(top=0.062, door=True):
    """Foundation, stone storey with masonry, a timber band, a door with frame and step."""
    low = (LOWER[0], LOWER[1], LOWER[2], top)
    p = [
        bc.cone("foundation", 0.042, 0.040, 0.010, (0, 0, 0.005), "stone_dark", 8, R8),
        bc.cone("lower", low[0], low[1], low[3] - low[2], (0, 0, (low[2] + low[3]) / 2), "stone", 8, R8),
    ]
    for face, z, col in [(0, 0.024, "stone_dark"), (90, 0.036, "stone_dark"), (135, 0.020, "stone"), (180, 0.044, "stone_dark"),
                         (225, 0.030, "stone"), (315, 0.040, "stone_dark"), (45, 0.018, "stone")]:
        if z < top - 0.008:
            p.append(bc.on_wall("block", 0.013, 0.004, 0.007, face, z, low, col))
    p.append(bc.on_wall("slit", 0.004, 0.004, 0.014, 0, 0.042 if top > 0.05 else 0.03, low, "ink"))
    if door:
        p += [
            bc.on_wall("door_frame", 0.020, 0.004, 0.028, 270, 0.024, low, "stone_dark"),
            bc.on_wall("door", 0.014, 0.0055, 0.022, 270, 0.021, low, "wood_dark"),
            bc.on_wall("door_strap", 0.014, 0.0065, 0.002, 270, 0.026, low, "ink"),
            bc.box("step", (0.022, 0.008, 0.012), (0, -0.0405, 0.006), "stone_dark"),
        ]
    return p


def cream_storey(lit=True):
    p = [
        bc.cone("band", 0.0350, 0.0350, 0.008, (0, 0, 0.066), "wood_dark", 8, R8),
        bc.cone("upper", UPPER[0], UPPER[1], UPPER[3] - UPPER[2], (0, 0, (UPPER[2] + UPPER[3]) / 2), "wall_cream", 8, R8),
    ]
    p += [bc.on_wall("beam", 0.004, 0.0035, 0.030, f, 0.085, UPPER, "wood_dark", sink=0.0003) for f in (45, 135, 225, 315)]
    win = bc.on_wall("window", 0.010, 0.004, 0.012, 270, 0.086, UPPER, "lantern_glow")
    bc.paint(win, "lantern_glow", glow=True)
    p += [win, bc.on_wall("sill", 0.014, 0.006, 0.003, 270, 0.0785, UPPER, "wood_light"),
          bc.on_wall("window_side", 0.010, 0.004, 0.012, 0, 0.086, UPPER, "ink"),
          bc.on_wall("sill_side", 0.014, 0.006, 0.003, 0, 0.0785, UPPER, "wood_light")]
    p += ring(8, 0.0340, 0.096, (0.005, 0.008, 0.006), "wood_dark", name="corbel")
    return p


def tilted(o, rot, loc):
    bc.rotate(o, rot)
    o.location = loc
    bc.apply_transforms(o)
    return o


def variant_a():
    """Hat Spire: the Fire Tower's body under a tall bent wizard hat; the orb floats above the tip."""
    p = stone_body() + cream_storey()
    p.append(bc.cone("brim", 0.0405, 0.0405, 0.005, (0, 0, 0.1025), "wood_dark", 8, R8))
    p.append(bc.cone("hat", 0.037, 0.014, 0.040, (0, 0, 0.125), "ink", 8, R8))
    p.append(bc.cone("hat_band", 0.0305, 0.0305, 0.005, (0, 0, 0.1125), "roof_terracotta", 8, R8))
    tip = bc.cone("hat_tip", 0.0150, 0.0050, 0.026, (0, 0, 0.0), "ink", 8, R8)  # blunt, chunky, bent over
    tilted(tip, (0, -28, 0), (-0.0060, 0, 0.1580))  # base centre sits on the hat top (z 0.145)
    p.append(tip)
    p.append(bc.cone("orb_collar", 0.0085, 0.0085, 0.004, (-0.0125, 0, 0.1715), "stone_dark", 8, R8))  # dark socket the orb sits in
    return p, (-0.0125, 0, 0.1900)


def variant_b():
    """Open Belfry: a timber chamber under a terracotta cap with the orb floating inside."""
    p = stone_body(top=0.066)
    p.append(bc.cone("floor", 0.038, 0.038, 0.006, (0, 0, 0.069), "stone_dark", 8, R8))
    p.append(bc.cone("pedestal", 0.012, 0.016, 0.008, (0, 0, 0.076), "stone", 8, R8))
    for i in range(4):  # corner posts
        a = math.radians(45 + 90 * i)
        post = bc.box("post", (0.008, 0.008, 0.034), (0.029 * math.cos(a), 0.029 * math.sin(a), 0.090), "wood_dark", rot_z_deg=math.degrees(a))
        p.append(post)
    p += ring(4, 0.0295, 0.0745, (0.006, 0.009, 0.006), "stone", start=0, name="foot")
    p.append(bc.cone("rail_low", 0.0305, 0.0305, 0.003, (0, 0, 0.082), "wood_light", 8, R8))
    p.append(bc.cone("eave", 0.041, 0.041, 0.004, (0, 0, 0.109), "wood_dark", 8, R8))
    p.append(bc.cone("cap", 0.039, 0.007, 0.030, (0, 0, 0.126), "roof_terracotta", 8, R8))
    p.append(bc.cone("finial", 0.006, 0.006, 0.003, (0, 0, 0.1425), "ink", 6))
    pt = bc.cone("finial_tip", 0.0045, 0.0, 0.014, (0, 0, 0.152), "ink", 6)
    pt["no_bevel"] = True
    p.append(pt)
    p += ring(4, 0.0245, 0.0765, (0.005, 0.003, 0.005), "fire_red", start=45, name="rune")
    return p, (0, 0, 0.098)


def variant_c():
    """Horned Cage: a tall plain stone shaft, four ink horns arching over the orb."""
    p = stone_body(top=0.090)
    p.append(bc.cone("band", 0.0345, 0.0345, 0.008, (0, 0, 0.070), "wood_dark", 8, R8))
    p.append(bc.cone("collar", 0.0385, 0.0385, 0.008, (0, 0, 0.094), "stone", 8, R8))
    p.append(bc.cone("crown", 0.034, 0.028, 0.008, (0, 0, 0.102), "stone_dark", 8, R8))
    p += ring(6, 0.0385, 0.094, (0.010, 0.006, 0.006), "wood_dark", start=0, name="stud")
    p.append(bc.cone("socket", 0.012, 0.015, 0.006, (0, 0, 0.109), "ink", 8, R8))
    for i in range(4):  # each horn: a lower segment leaning outward, an upper one curling in, a tip cap
        a = math.radians(45 + 90 * i)
        c, s = math.cos(a), math.sin(a)
        lo = bc.box("horn_lo", (0.011, 0.011, 0.030), (0, 0, 0), "ink")
        lo.rotation_euler = (math.radians(-14 * s), math.radians(14 * c), 0)  # top leans outward
        bc.apply_transforms(lo)
        lo.location = (0.027 * c, 0.027 * s, 0.123)
        bc.apply_transforms(lo)
        p.append(lo)
        up = bc.box("horn_up", (0.010, 0.010, 0.024), (0, 0, 0), "ink")
        up.rotation_euler = (math.radians(38 * s), math.radians(-38 * c), 0)  # top curls inward
        bc.apply_transforms(up)
        up.location = (0.0232 * c, 0.0232 * s, 0.1475)
        bc.apply_transforms(up)
        p.append(up)
    return p, (0, 0, 0.1285)


def variant_d():
    """Spiral Stair: a round tower with an outer stair winding up to a balcony; a hoop round the orb."""
    top = 0.112
    p = [
        bc.cone("foundation", 0.042, 0.040, 0.010, (0, 0, 0.005), "stone_dark", 8, R8),
        bc.cone("lower", 0.036, 0.032, 0.054, (0, 0, 0.037), "stone", 8, R8),
        bc.cone("band", 0.0345, 0.0345, 0.006, (0, 0, 0.067), "wood_dark", 8, R8),
        bc.cone("upper", 0.031, 0.029, top - 0.070, (0, 0, (0.070 + top) / 2), "wall_cream", 8, R8),
        bc.cone("balcony", 0.040, 0.040, 0.006, (0, 0, top + 0.003), "stone_dark", 8, R8),
    ]
    p += [bc.on_wall("door_frame", 0.020, 0.004, 0.028, 270, 0.024, (0.036, 0.032, 0.010, 0.064), "stone_dark"),
          bc.on_wall("door", 0.014, 0.0055, 0.022, 270, 0.021, (0.036, 0.032, 0.010, 0.064), "wood_dark")]
    win = bc.on_wall("window", 0.009, 0.004, 0.012, 270, 0.092, (0.031, 0.029, 0.070, top), "lantern_glow")
    bc.paint(win, "lantern_glow", glow=True)
    p.append(win)
    steps = 20  # stair winding anticlockwise from the left of the door up to the balcony
    for i in range(steps):
        t = i / (steps - 1)
        a = math.radians(200 + t * 410)
        z = 0.020 + t * (top - 0.024)
        r = 0.0345 - 0.0025 * t
        p.append(bc.box("stair", (0.014, 0.0085, 0.0045), (r * math.cos(a), r * math.sin(a), z), "wood_light", rot_z_deg=math.degrees(a) + 90))
    p += ring(6, 0.0375, top + 0.0095, (0.009, 0.004, 0.008), "stone", start=30, name="merlon")
    cz = top + 0.026
    return p, (0, 0, cz)


# ---- round 2 (Siddharth: loves A and B; the towers are manned, so each has a spot for its wizard) ----------
# A placeholder wizard (capsule robe, head, pointed hat) stands in each preview so the crew's scale and spot can be
# judged; Durva's character kit replaces it. __crew_anchor marks where the crew member stands (feet).

def figure(x, y, z, face_deg=270.0):
    """Placeholder wizard, about 0.7 cell tall. face_deg 270 = looking to the front (-Y)."""
    f = [bc.cone("robe", 0.0075, 0.0045, 0.020, (x, y, z + 0.010), "roof_teal", 8),
         bc.blob("head", 0.0055, (x, y, z + 0.0255), "skin_light", 1),
         bc.cone("wiz_hat", 0.0072, 0.0, 0.014, (x, y, z + 0.0375), "ink", 8),
         bc.cone("wiz_brim", 0.0085, 0.0085, 0.0014, (x, y, z + 0.0315), "ink", 8)]
    f[3]["no_bevel"] = True
    f[2]["no_bevel"] = True
    return f


def variant_e():
    """A refined: Hat Spire with a front balcony, where the wizard stands next to the lit window."""
    p, _ = variant_a()
    p.append(bc.box("balcony", (0.026, 0.014, 0.004), (0, -0.0405, 0.0975), "wood_light"))
    p += [bc.box("balcony_post", (0.004, 0.004, 0.012), (sx * 0.0115, -0.0455, 0.1055), "wood_dark") for sx in (-1, 1)]
    p.append(bc.box("balcony_rail", (0.026, 0.003, 0.003), (0, -0.0455, 0.1095), "wood_dark"))
    p += [bc.box("bracket", (0.004, 0.012, 0.004), (sx * 0.0105, -0.0385, 0.0925), "wood_dark") for sx in (-1, 1)]
    p += figure(0, -0.0405, 0.0995)
    return p, (-0.0125, 0, 0.1900), (0, -0.0405, 0.0995)


def variant_f():
    """A, slimmer and taller (critic: be different from the Fire Tower): narrow cream tier with a terracotta belt,
    wide-brimmed hat with a curled tip; the wizard looks out of a side balcony."""
    up = (0.030, 0.027, 0.070, 0.104)
    p = stone_body(top=0.062)
    p += [
        bc.cone("band", 0.0350, 0.0350, 0.008, (0, 0, 0.066), "roof_terracotta", 8, R8),
        bc.cone("upper", up[0], up[1], up[3] - up[2], (0, 0, (up[2] + up[3]) / 2), "wall_cream", 8, R8),
    ]
    p += [bc.on_wall("beam", 0.004, 0.0035, 0.030, f, 0.087, up, "wood_dark", sink=0.0003) for f in (45, 135, 225, 315)]
    win = bc.on_wall("window", 0.010, 0.004, 0.012, 270, 0.088, up, "lantern_glow")
    bc.paint(win, "lantern_glow", glow=True)
    p += [win, bc.on_wall("sill", 0.014, 0.006, 0.003, 270, 0.0805, up, "wood_light")]
    p.append(bc.cone("brim", 0.045, 0.040, 0.004, (0, 0, 0.1055), "ink", 8, R8))  # wide brim, overhangs the footprint edge a little
    p.append(bc.cone("brim_band", 0.0415, 0.0415, 0.004, (0, 0, 0.1085), "roof_terracotta", 8, R8))
    p.append(bc.cone("hat", 0.030, 0.012, 0.050, (0, 0, 0.1345), "ink", 8, R8))
    mid = bc.cone("hat_mid", 0.0125, 0.0075, 0.020, (0, 0, 0.0), "ink", 8, R8)
    tilted(mid, (0, -20, 0), (-0.0020, 0, 0.1655))
    tip = bc.cone("hat_tip", 0.0075, 0.0035, 0.018, (0, 0, 0.0), "ink", 8, R8)
    tilted(tip, (0, -50, 0), (-0.0105, 0, 0.1815))
    p += [mid, tip, bc.cone("orb_collar", 0.0085, 0.0085, 0.004, (-0.0205, 0, 0.1868), "stone_dark", 8, R8)]
    # side balcony on the east face (the wizard looks out over the board's right side)
    p.append(bc.box("balcony", (0.014, 0.024, 0.004), (0.0395, 0, 0.0975 - 0.002), "wood_light"))
    p += [bc.box("balcony_post", (0.004, 0.004, 0.012), (0.0455, sy * 0.0115, 0.1035), "wood_dark") for sy in (-1, 1)]
    p.append(bc.box("balcony_rail", (0.003, 0.026, 0.003), (0.0455, 0, 0.1075), "wood_dark"))
    p += figure(0.0395, 0, 0.0975)
    return p, (-0.0205, 0, 0.2050), (0.0395, 0, 0.0975)


def variant_g():
    """B refined: Open Belfry with the cap raised on chunky posts so the orb and the wizard both show."""
    p = stone_body(top=0.066)
    p.append(bc.cone("floor", 0.038, 0.038, 0.006, (0, 0, 0.069), "stone_dark", 8, R8))
    p.append(bc.cone("pedestal", 0.011, 0.015, 0.008, (0, 0, 0.076), "stone", 8, R8))
    for i in range(4):
        a = math.radians(45 + 90 * i)
        p.append(bc.box("post", (0.008, 0.008, 0.042), (0.029 * math.cos(a), 0.029 * math.sin(a), 0.093), "wood_dark", rot_z_deg=math.degrees(a)))
    p += ring(4, 0.0295, 0.0745, (0.008, 0.011, 0.006), "stone", start=0, name="foot")
    p.append(bc.cone("rail_low", 0.0305, 0.0305, 0.003, (0, 0, 0.083), "wood_light", 8, R8))
    p.append(bc.cone("eave", 0.042, 0.042, 0.004, (0, 0, 0.116), "wood_dark", 8, R8))
    p.append(bc.cone("cap", 0.040, 0.007, 0.032, (0, 0, 0.134), "roof_terracotta", 8, R8))
    p.append(bc.cone("finial", 0.006, 0.006, 0.003, (0, 0, 0.1515), "ink", 6))
    pt = bc.cone("finial_tip", 0.0045, 0.0, 0.014, (0, 0, 0.161), "ink", 6)
    pt["no_bevel"] = True
    p.append(pt)
    p += ring(4, 0.0245, 0.0765, (0.005, 0.003, 0.005), "fire_red", start=45, name="rune")
    p += figure(0.0, -0.0215, 0.072)  # beside the orb, in front, looking out
    return p, (0, 0.004, 0.100), (0, -0.0215, 0.072)


def variant_h():
    """A x B hybrid (the critic's idea): A's black wizard hat raised on four pillars over an open chamber."""
    p = stone_body(top=0.066)
    p.append(bc.cone("floor", 0.038, 0.038, 0.006, (0, 0, 0.069), "stone_dark", 8, R8))
    p.append(bc.cone("pedestal", 0.011, 0.015, 0.008, (0, 0, 0.076), "stone", 8, R8))
    for i in range(4):
        a = math.radians(45 + 90 * i)
        p.append(bc.box("pillar", (0.008, 0.008, 0.040), (0.029 * math.cos(a), 0.029 * math.sin(a), 0.092), "stone", rot_z_deg=math.degrees(a)))
    p += ring(4, 0.0295, 0.0745, (0.008, 0.011, 0.006), "stone_dark", start=0, name="foot")
    p.append(bc.cone("brim", 0.0425, 0.0425, 0.005, (0, 0, 0.1145), "wood_dark", 8, R8))
    p.append(bc.cone("hat_band", 0.0345, 0.0345, 0.005, (0, 0, 0.1215), "roof_terracotta", 8, R8))
    p.append(bc.cone("hat", 0.037, 0.014, 0.038, (0, 0, 0.1365), "ink", 8, R8))
    tip = bc.cone("hat_tip", 0.0150, 0.0050, 0.026, (0, 0, 0.0), "ink", 8, R8)
    tilted(tip, (0, -28, 0), (-0.0060, 0, 0.1675))
    p += [tip, bc.cone("orb_collar", 0.0085, 0.0085, 0.004, (-0.0125, 0, 0.1810), "stone_dark", 8, R8)]
    p += ring(4, 0.0245, 0.0765, (0.005, 0.003, 0.005), "fire_red", start=45, name="rune")
    p += figure(0.0, -0.0215, 0.072)
    return p, (-0.0125, 0, 0.2000), (0, -0.0215, 0.072)


def build_final(seed=0):
    """The chosen design (Siddharth picked H, 2026-10-26): A's black wizard hat raised on four stone pillars over
    an open chamber, the orb floating above the hat tip. No placeholder wizard: crews come from the character kit.

    Parts (moved separately in Godot, no rig):
        ew_defense_wizard_tower_v02              stone base, floor, pedestal, four pillars (static)
        ew_defense_wizard_tower_v02__hat         brim, band, hat, bent tip, orb collar; pivot at the brim, for a sway or bob
        ew_defense_wizard_tower_v02__orb_anchor  empty above the hat tip: the floating fire orb (VFX)
        ew_defense_wizard_tower_v02__crew_anchor empty on the chamber floor: where the wizard stands (feet)
        ew_defense_wizard_tower_v02__pulse_anchor empty at ground centre (range ring reference)
    """
    base = stone_body(top=0.066)
    base.append(bc.cone("floor", 0.038, 0.038, 0.006, (0, 0, 0.069), "stone_dark", 8, R8))
    base.append(bc.cone("pedestal", 0.011, 0.015, 0.008, (0, 0, 0.076), "stone", 8, R8))
    for i in range(4):
        a = math.radians(45 + 90 * i)
        base.append(bc.box("pillar", (0.011, 0.011, 0.040), (0.029 * math.cos(a), 0.029 * math.sin(a), 0.092), "stone", rot_z_deg=math.degrees(a)))
    base += ring(4, 0.0295, 0.0745, (0.008, 0.011, 0.006), "stone_dark", start=0, name="foot")
    base += ring(4, 0.0245, 0.0765, (0.005, 0.003, 0.005), "fire_red", start=45, name="rune")
    HZ = 0.1145  # hat pivot = brim centre
    hat = [
        bc.cone("brim", 0.0425, 0.0425, 0.005, (0, 0, HZ), "wood_dark", 8, R8),
        bc.cone("hat_band", 0.0345, 0.0345, 0.005, (0, 0, 0.1215), "roof_terracotta", 8, R8),
        bc.cone("hat", 0.037, 0.014, 0.038, (0, 0, 0.1365), "ink", 8, R8),
    ]
    tip = bc.cone("hat_tip", 0.0150, 0.0050, 0.026, (0, 0, 0.0), "ink", 8, R8)
    tilted(tip, (0, -28, 0), (-0.0060, 0, 0.1675))
    hat += [tip, bc.cone("orb_collar", 0.0085, 0.0085, 0.004, (-0.0125, 0, 0.1810), "stone_dark", 8, R8)]
    root = bc.assemble(NAME, [("", base, (0, 0, 0), None), ("hat", hat, (0, 0, HZ), "")])
    bc.anchor(root, "orb_anchor", (-0.0125, 0, 0.2000), size=0.0155)
    bc.anchor(root, "crew_anchor", (0, -0.0215, 0.072), size=0.008)
    bc.anchor(root, "pulse_anchor", (0, 0, 0), size=0.05)
    return root


VARIANTS = {"A": variant_a, "B": variant_b, "C": variant_c, "D": variant_d,
            "E": variant_e, "F": variant_f, "G": variant_g, "H": variant_h}


def build(params=None, seed=0):
    v = (params or {}).get("variant", "A")
    res = VARIANTS[v]()
    parts, orb_at = res[0], res[1]
    root = bc.assemble(NAME, [("", parts, (0, 0, 0), None)])
    bc.anchor(root, "orb_anchor", orb_at, size=0.0155)
    if len(res) > 2:
        bc.anchor(root, "crew_anchor", res[2], size=0.008)  # where the wizard's feet stand
    bc.anchor(root, "pulse_anchor", (0, 0, 0), size=0.05)
    return root


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    v = args[0] if args else "final"
    bc.clear_scene()
    if v == "final":
        obj = build_final()
        print("BLEND", bc.save_blend(obj, "wizard_tower"))
        print("EXPORT", bc.export_glb(obj, "defense"))
    else:
        obj = build({"variant": v})
        print("BLEND", bc.save_blend(obj, "wizard_tower_" + v))
