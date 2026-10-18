"""AoE tower (spec name "Blast Brazier") as a MAGIC-BOMB tower: design variants A-D.

    blender --factory-startup -b -P assets/generators/make_bomb_tower.py            (final asset, exports .glb)
    blender --factory-startup -b -P assets/generators/make_bomb_tower.py -- A       (design variant A-H)

Siddharth (2026-10-17): the AoE tower uses magic bombs. Role unchanged (GAME_SPEC): short range
(2 cells), hits every ground enemy within 1 cell of where the bomb lands, lower damage, about one
bomb per second. Footprint 2 x 2 cells, Fire Tower detail level. The bomb flight and blast are VFX;
the bomb itself is a small model (a few are shown on each tower as dressing). Empties for Godot:
    __bomb_anchor   where a bomb appears / is launched from
    __pulse_anchor  ground centre (reference point for range rings)

Magic colour: black, orange and red (Siddharth: magic is NOT blue): ink bodies, fire_red and
lantern_glow glows, fire_yellow sparks. Blue is Foresight only; purple is the Warden's.

Variants (shape ideas, original geometry):
    A  Alchemist's Cauldron - bubbling cauldron on a stone hearth; bombs are brewed and lobbed out
    B  Rune Mortar          - stout stone base, short wide mortar barrel on a turntable, rune band
    C  Wizard's Workshop    - round cottage with a tall black wizard-hat roof; bombs pop out of a hatch
    D  Crystal Conjurer     - stone pedestal, claws holding a floating crystal; bombs are conjured
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import blender_common as bc  # noqa: E402

NAME = "ew_defense_bomb_tower_v06"
R8 = 22.5
MAGIC = "fire_red"      # magic is black / orange / red (Siddharth), never blue
MAGIC2 = "lantern_glow"


def ring(n, r, z, size, col, start=0.0, glow=False, name="ring"):
    out = []
    for i in range(n):
        a = math.radians(start + i * 360 / n)
        o = bc.box(name, size, (r * math.cos(a), r * math.sin(a), z), col, rot_z_deg=math.degrees(a) + 90)
        if glow:
            bc.paint(o, col, glow=True)
        out.append(o)
    return out


def glow(o, col=MAGIC):
    bc.paint(o, col, glow=True)
    return o


def bomb(x, y, z, r=0.0055, plain=False):
    """A magic bomb: dark round body, glowing rune band, fuse with a glowing tip. z = bottom.
    plain=True (critic suggestion): band painted roof_orange without glow and no spark; the fuse VFX lights it."""
    c = z + r
    band = bc.cone("bomb_band", r * 1.02, r * 1.02, r * 0.35, (x, y, c), "roof_orange" if plain else MAGIC2, 8)
    parts = [
        bc.blob("bomb", r, (x, y, c), "ink", 1),
        band if plain else glow(band, MAGIC2),
        bc.cone("bomb_fuse", r * 0.25, r * 0.2, r * 0.6, (x, y, c + r * 1.1), "wood_dark", 5),
    ]
    if not plain:
        parts.append(glow(bc.blob("bomb_spark", r * 0.28, (x, y, c + r * 1.5), "fire_yellow", 1), "fire_yellow"))
    return parts


def crystal(x, y, z, r, h):
    """Octahedral crystal centred at z."""
    top = bc.cone("crystal_top", r, 0.0, h / 2, (x, y, z + h / 4), MAGIC, 6)
    bot = bc.cone("crystal_bot", 0.0, r, h / 2, (x, y, z - h / 4), MAGIC, 6)
    return [glow(top), glow(bot)]


def variant_a():
    """Alchemist's Cauldron."""
    p = [
        bc.cone("hearth", 0.042, 0.041, 0.008, (0, 0, 0.004), "stone_dark", 8, R8),
        bc.cone("firering", 0.030, 0.029, 0.008, (0, 0, 0.012), "stone", 8, R8),
        glow(bc.cone("embers", 0.024, 0.024, 0.002, (0, 0, 0.0165), MAGIC2, 8, R8), MAGIC2),
    ]
    p += ring(3, 0.020, 0.022, (0.005, 0.005, 0.014), "ink", start=90, name="leg")
    p += [
        bc.cone("belly", 0.022, 0.032, 0.016, (0, 0, 0.035), "ink", 10),
        bc.cone("shoulder", 0.032, 0.027, 0.012, (0, 0, 0.049), "ink", 10),
        bc.cone("rim", 0.0295, 0.0295, 0.004, (0, 0, 0.0565), "stone_dark", 10),
        glow(bc.cone("brew", 0.026, 0.026, 0.002, (0, 0, 0.0575), MAGIC, 10)),
        glow(bc.blob("bubble", 0.006, (0.008, -0.004, 0.059), MAGIC, 1)),
        glow(bc.blob("bubble", 0.004, (-0.009, 0.006, 0.059), MAGIC, 1)),
    ]
    ladle = bc.box("ladle", (0.003, 0.003, 0.040), (0, 0, 0), "wood_light")
    bc.rotate(ladle, (0, 28, 25))
    ladle.location = (0.012, 0.006, 0.066)
    bc.apply_transforms(ladle)
    p.append(ladle)
    # little bomb rack by the hearth
    p += [bc.box("rack", (0.024, 0.010, 0.004), (-0.022, -0.032, 0.010), "wood_dark")]
    p += bomb(-0.029, -0.032, 0.012) + bomb(-0.016, -0.032, 0.012)
    p += [bc.box("rune_stone", (0.010, 0.004, 0.010), (0.0335, -0.012, 0.012), "stone"),
          glow(bc.box("rune", (0.005, 0.002, 0.005), (0.0360, -0.012, 0.013), MAGIC))]
    return p, (0, 0, 0.062)


def variant_b():
    """Rune Mortar."""
    p = [
        bc.cone("base", 0.042, 0.041, 0.010, (0, 0, 0.005), "stone_dark", 8, R8),
        bc.cone("body", 0.036, 0.032, 0.026, (0, 0, 0.023), "stone", 8, R8),
        bc.cone("turntable", 0.031, 0.031, 0.005, (0, 0, 0.0385), "wood_dark", 8, R8),
    ]
    p += ring(8, 0.0345, 0.024, (0.008, 0.004, 0.005), MAGIC, start=22.5, glow=True, name="rune")
    # short wide barrel tilted up toward the front
    barrel = bc.cone("barrel", 0.016, 0.018, 0.030, (0, 0, 0.015), "ink", 10)
    muzzle = bc.cone("muzzle", 0.020, 0.020, 0.005, (0, 0, 0.0305), "roof_terracotta", 10)
    inner = glow(bc.cone("muzzle_glow", 0.014, 0.014, 0.002, (0, 0, 0.0335), MAGIC, 10))
    for o in (barrel, muzzle, inner):
        bc.rotate(o, (-30, 0, 0))
        o.location = (0, -0.002, 0.040)
        bc.apply_transforms(o)
    p += [barrel, muzzle, inner]
    p += [bc.box("cheek", (0.004, 0.018, 0.016), (sx * 0.020, 0.002, 0.048), "wood_dark") for sx in (-1, 1)]
    p += bomb(0.030, -0.028, 0.010) + bomb(0.019, -0.033, 0.010) + bomb(0.025, -0.030, 0.020, 0.005)
    return p, (0, -0.016, 0.068)


def variant_c():
    """Wizard's Workshop."""
    p = [
        bc.cone("base", 0.040, 0.039, 0.006, (0, 0, 0.003), "stone_dark", 8, R8),
        bc.cone("walls", 0.034, 0.031, 0.030, (0, 0, 0.021), "wall_cream", 8, R8),
        bc.cone("eave", 0.040, 0.040, 0.004, (0, 0, 0.038), "wood_dark", 8, R8),
        bc.cone("hat", 0.037, 0.011, 0.044, (0, 0, 0.062), "ink", 8, R8),
        bc.cone("hat_band", 0.031, 0.031, 0.005, (0, 0, 0.0455), "roof_terracotta", 8, R8),
    ]
    tip = bc.cone("hat_tip", 0.0115, 0.0, 0.034, (0, 0, 0.017), "ink", 8, R8)
    tip["no_bevel"] = True  # bevel clamping would collapse the point
    bc.rotate(tip, (0, -55, 0))
    tip.location = (0.0, 0, 0.0825)
    bc.apply_transforms(tip)
    star = glow(bc.blob("hat_star", 0.0035, (-0.0285, 0, 0.1020), "fire_yellow", 1), "fire_yellow")
    p += [tip, star]
    p += ring(4, 0.031, 0.021, (0.004, 0.003, 0.030), "wood_dark", start=45, name="beam")
    p += [
        bc.box("door", (0.012, 0.004, 0.018), (0, -0.0325, 0.015), "wood_dark"),
        glow(bc.box("window", (0.009, 0.004, 0.009), (0.0315, 0, 0.024), MAGIC)),
        bc.box("sill", (0.004, 0.012, 0.002), (0.0335, 0, 0.0185), "wood_light"),
        # roof hatch the bombs pop out of
        bc.box("hatch", (0.012, 0.004, 0.010), (0, -0.029, 0.054), "wood_dark", rot_z_deg=0),
        glow(bc.box("hatch_glow", (0.008, 0.002, 0.006), (0, -0.0312, 0.054), MAGIC)),
        bc.box("crate", (0.014, 0.012, 0.010), (-0.025, -0.031, 0.011), "wood_light"),
    ]
    p += bomb(-0.028, -0.031, 0.016, 0.0045) + bomb(-0.021, -0.031, 0.016, 0.0045)
    return p, (0, -0.032, 0.055)


def variant_d():
    """Crystal Conjurer."""
    p = [
        bc.cone("base", 0.042, 0.041, 0.010, (0, 0, 0.005), "stone_dark", 8, R8),
        bc.cone("step", 0.032, 0.031, 0.008, (0, 0, 0.014), "stone", 8, R8),
        bc.cone("pillar", 0.016, 0.013, 0.026, (0, 0, 0.031), "stone_dark", 8, R8),
        bc.cone("cap", 0.019, 0.019, 0.004, (0, 0, 0.046), "roof_terracotta", 8, R8),
    ]
    for i in range(3):  # claws reaching up around the crystal
        a = math.radians(90 + i * 120)
        claw = bc.box("claw", (0.004, 0.004, 0.024), (0, 0, 0.012), "ink")
        bc.rotate(claw, (0, -22, math.degrees(a)))
        claw.location = (0.013 * math.cos(a), 0.013 * math.sin(a), 0.047)
        bc.apply_transforms(claw)
        p.append(claw)
    p += crystal(0, 0, 0.068, 0.010, 0.026)
    # floating rune stones circling the crystal (would spin in Godot)
    p += ring(5, 0.024, 0.066, (0.006, 0.003, 0.008), MAGIC, start=18, glow=True, name="rune_stone")
    p += [bc.box("rune_slab", (0.012, 0.004, 0.016), (0.0300, -0.022, 0.018), "stone", rot_z_deg=-40),
          glow(bc.box("rune", (0.006, 0.002, 0.007), (0.0318, -0.0242, 0.019), MAGIC, rot_z_deg=-40))]
    p += bomb(-0.028, -0.026, 0.010) + bomb(-0.018, -0.032, 0.010)
    return p, (0, 0, 0.068)


# ---- round 2: A (cauldron) x B (mortar) hybrids, Siddharth's pick -----------------------------

def place(objs, rot, loc):
    """Rotate parts built around the origin (degrees XYZ), then move them to loc."""
    for o in objs:
        bc.rotate(o, rot)
        o.location = loc
        bc.apply_transforms(o)
    return objs


def cauldron(s=1.0):
    """A's cauldron, base at z=0."""
    return [
        bc.cone("belly", 0.022 * s, 0.032 * s, 0.016 * s, (0, 0, 0.008 * s), "ink", 10),
        bc.cone("shoulder", 0.032 * s, 0.027 * s, 0.012 * s, (0, 0, 0.022 * s), "ink", 10),
        bc.cone("rim", 0.0295 * s, 0.0295 * s, 0.004 * s, (0, 0, 0.0295 * s), "stone_dark", 10),
        glow(bc.cone("brew", 0.026 * s, 0.026 * s, 0.002 * s, (0, 0, 0.0322 * s), MAGIC, 10)),  # just above the rim top: no z-fighting
        glow(bc.blob("bubble", 0.006 * s, (0.008 * s, -0.004 * s, 0.032 * s), MAGIC, 1)),
    ]


def mortar(s=1.0):
    """B's barrel, base at z=0, pointing up."""
    return [
        bc.cone("barrel", 0.016 * s, 0.018 * s, 0.030 * s, (0, 0, 0.015 * s), "ink", 10),
        bc.cone("muzzle", 0.020 * s, 0.020 * s, 0.005 * s, (0, 0, 0.0305 * s), "roof_terracotta", 10),
        glow(bc.cone("muzzle_glow", 0.014 * s, 0.014 * s, 0.002 * s, (0, 0, 0.0335 * s), MAGIC, 10)),
    ]


def base_b():
    """B's stone base with the glowing rune band and turntable (top at z = 0.041)."""
    p = [
        bc.cone("base", 0.042, 0.041, 0.010, (0, 0, 0.005), "stone_dark", 8, R8),
        bc.cone("body", 0.036, 0.032, 0.026, (0, 0, 0.023), "stone", 8, R8),
        bc.cone("turntable", 0.031, 0.031, 0.005, (0, 0, 0.0385), "wood_dark", 8, R8),
    ]
    return p + ring(8, 0.0345, 0.024, (0.008, 0.004, 0.005), MAGIC, start=22.5, glow=True, name="rune")


def base_a():
    """A's hearth with embers and three legs (legs carry an object at z = 0.027)."""
    p = [
        bc.cone("hearth", 0.042, 0.041, 0.008, (0, 0, 0.004), "stone_dark", 8, R8),
        bc.cone("firering", 0.030, 0.029, 0.008, (0, 0, 0.012), "stone", 8, R8),
        glow(bc.cone("embers", 0.024, 0.024, 0.002, (0, 0, 0.0165), MAGIC2, 8, R8), MAGIC2),
    ]
    return p + ring(3, 0.020, 0.022, (0.005, 0.005, 0.014), "ink", start=90, name="leg")


def bomb_rack(x=-0.022, y=-0.032):
    return ([bc.box("rack", (0.024, 0.010, 0.004), (x, y, 0.010), "wood_dark")]
            + bomb(x - 0.007, y, 0.012) + bomb(x + 0.006, y, 0.012))


def variant_e():
    """Tipping Cauldron: B's rune base and turntable carry A's cauldron between two cheeks,
    tilted forward like a mortar; it tips to lob each bomb."""
    p = base_b()
    p += [bc.box("cheek", (0.004, 0.020, 0.026), (sx * 0.0285, 0.002, 0.053), "wood_dark") for sx in (-1, 1)]
    axle = bc.cone("axle", 0.003, 0.003, 0.062, (0, 0, 0), "ink", 6)
    p += place([axle], (0, 90, 0), (0, 0.002, 0.058))
    p += place(cauldron(0.85), (-28, 0, 0), (0, 0.004, 0.044))
    p += bomb(0.029, -0.030, 0.010) + bomb(0.019, -0.034, 0.010)
    return p, (0, -0.012, 0.072)


def variant_f():
    """Brew-fed Mortar: B's mortar, fed by a small cauldron brewing beside it through a pipe."""
    p = base_b()
    p += place(mortar(), (-30, 0, 0), (0, -0.006, 0.040))
    p += [bc.box("cheek", (0.004, 0.018, 0.016), (sx * 0.020, -0.004, 0.048), "wood_dark") for sx in (-1, 1)]
    p += place(cauldron(0.5), (0, 0, 0), (0.019, 0.015, 0.041))  # on the side the player sees
    p += [bc.box("pipe", (0.020, 0.005, 0.005), (0.010, 0.006, 0.056), "ink", rot_z_deg=40)]
    p += bomb(0.029, -0.030, 0.010) + bomb(0.019, -0.034, 0.010)
    return p, (0, -0.022, 0.066)


def variant_g():
    """Cauldron Cannon: A's cauldron on its hearth, with a lid and a short mortar barrel on top;
    the brew glows round the lid and the bomb fires through the barrel."""
    p = base_a()
    p += place(cauldron(1.0), (0, 0, 0), (0, 0, 0.027))
    p += [bc.cone("lid", 0.023, 0.020, 0.005, (0, 0, 0.0610), "ink", 10)]
    p += place(mortar(0.72), (-30, 0, 0), (0, -0.003, 0.063))
    p += bomb_rack()
    return p, (0, -0.014, 0.084)


def variant_h():
    """Hearth Mortar: a mortar barrel shaped like a pot-bellied cauldron, cradled over A's fire."""
    p = base_a()
    body = [
        bc.cone("pot_belly", 0.022, 0.031, 0.014, (0, 0, 0.007), "ink", 10),
        bc.cone("pot_neck", 0.031, 0.019, 0.016, (0, 0, 0.022), "ink", 10),
        bc.cone("muzzle", 0.022, 0.022, 0.005, (0, 0, 0.0325), "roof_terracotta", 10),
        glow(bc.cone("muzzle_glow", 0.016, 0.016, 0.002, (0, 0, 0.0355), MAGIC, 10)),
        bc.cone("band", 0.0315, 0.0315, 0.004, (0, 0, 0.014), "roof_terracotta", 10),
    ]
    p += place(body, (-25, 0, 0), (0, 0.003, 0.027))
    p += bomb_rack()
    p += [bc.box("rune_stone", (0.010, 0.004, 0.010), (0.0335, -0.012, 0.012), "stone"),
          glow(bc.box("rune", (0.005, 0.002, 0.005), (0.0360, -0.012, 0.013), MAGIC))]
    return p, (0, -0.014, 0.066)


VARIANTS = {"A": variant_a, "B": variant_b, "C": variant_c, "D": variant_d,
            "E": variant_e, "F": variant_f, "G": variant_g, "H": variant_h}


def build_final(seed=0, plain_bombs=True, light_trim=False, high_brew=False):
    # critic suggestions (2026-10-18): Siddharth picked plain bombs (v04); rejected light trim and high brew
    """The chosen design (Siddharth picked E, 2026-10-17): Tipping Cauldron, as the real game asset.

    Parts (moved separately in Godot, no rig):
        ew_defense_bomb_tower_v05                  stone base with a band of carved rune slots (static)
        ew_defense_bomb_tower_v05__head            turntable, cheeks and axle; turns to aim
        ew_defense_bomb_tower_v05__cauldron        tips forward on the axle to lob each bomb
        ew_defense_bomb_tower_v05__bomb_anchor     empty at the cauldron mouth (bomb VFX / projectile)
        ew_defense_bomb_tower_v05__pulse_anchor    empty at ground centre (range ring reference)

    v02 (Siddharth's mark-up): the glowing parts become VFX. The brew is a lava/fire VFX inside the
    cauldron (__brew_anchor), the rune band is VFX on carved slots (__rune_anchor_1..8), and each
    bomb gets VFX on its fuse (__fuse_anchor_1..3). The model keeps no glowing brew or rune cubes.
    """
    import random
    rnd = random.Random(seed)
    BODY = (0.036, 0.032, 0.010, 0.036)  # stone drum: r_bottom, r_top, z_bottom, z_top; faces at 0, 45, 90...
    base = [
        bc.cone("base", 0.042, 0.041, 0.010, (0, 0, 0.005), "stone_dark", 8, R8),
        bc.cone("body", BODY[0], BODY[1], BODY[3] - BODY[2], (0, 0, (BODY[2] + BODY[3]) / 2), "stone", 8, R8),
        bc.cone("collar", 0.0335, 0.0335, 0.004, (0, 0, 0.034), "wood_dark", 8, R8),
    ]
    # carved rune slots: dark recesses that the rune VFX lights up (no glowing geometry). v03: on the faces
    # (were on the corners, sticking out), only 0.3 mm proud so they read as sockets, not stuck-on tiles.
    RUNE_Z = 0.020
    base += [bc.on_wall("rune_slot", 0.008, 0.003, 0.005, f, RUNE_Z, BODY, "ink", sink=0.0027) for f in range(0, 360, 45)]
    # masonry blocks (Fire Tower detail level), flat on the faces, in two rows that clear the rune band
    # (z 0.0175-0.0225) and the collar (from z 0.032); the bomb pile side (315) is left clear
    # v05: each block gets its own (face, row) slot, so no two overlap (they z-fought), and the front
    # face (270) is included; only the bomb-pile side (315) stays bare
    slots = rnd.sample([(f, zr) for f in (0, 45, 90, 135, 180, 225, 270) for zr in (0.0135, 0.027)], 6)
    for face, zr in slots:
        z = zr + rnd.uniform(-0.0005, 0.0005)
        blk = bc.on_wall("block", 0.011, 0.004, 0.006, face, z, BODY, rnd.choice(["stone_dark", "stone"]))
        del blk["ew_min_dim"]  # masonry keeps its rounded bevel (the approved v01 look)
        base.append(blk)
    # bomb pile on the ground at the front-right corner, clear of the plinth (v03: was half off the ledge)
    d, t = 0.0495, (math.cos(math.radians(45)), math.sin(math.radians(45)))  # pile centre distance; tangent
    cx, cy = d * math.cos(math.radians(-45)), d * math.sin(math.radians(-45))
    # v05: lower bombs spread 6.8 mm (was 5.8) so their fuses clear the top bomb; top bomb rests on both
    SP = 0.0068
    BOMBS = [(cx - SP * t[0], cy - SP * t[1], 0.0, 0.0055), (cx + SP * t[0], cy + SP * t[1], 0.0, 0.0055),
             (cx, cy, 0.0055 + math.sqrt(0.0105 ** 2 - SP ** 2) - 0.005, 0.005)]
    # v06: each displayed bomb is its own part (__bomb_1..3, pivot at its foot) carrying its fuse anchor
    bomb_parts = [bomb(bx, by, bz, br, plain=plain_bombs) for bx, by, bz, br in BOMBS]

    HZ = 0.036  # head pivot: top of the collar
    # light_trim (critic suggestion): lighter turntable and cauldron rim so the head reads at night
    head = [bc.cone("turntable", 0.031, 0.031, 0.005, (0, 0, HZ + 0.0025), "wood_light" if light_trim else "wood_dark", 8, R8)]
    head += [bc.box("cheek", (0.004, 0.020, 0.028), (sx * 0.0285, 0.002, HZ + 0.019), "wood_dark") for sx in (-1, 1)]
    head += [bc.box("cheek_cap", (0.006, 0.022, 0.003), (sx * 0.0285, 0.002, HZ + 0.0345), "roof_terracotta") for sx in (-1, 1)]
    axle = bc.cone("axle", 0.003, 0.003, 0.064, (0, 0, 0), "ink", 6)
    head += place([axle], (0, 90, 0), (0, 0.002, 0.058))
    head += [bc.cone("axle_cap", 0.0045, 0.0045, 0.003, (0, 0, 0), "roof_terracotta", 8) for _ in (0, 1)]
    for sx, cap in zip((-1, 1), head[-2:]):
        place([cap], (0, 90, 0), (sx * 0.0320, 0.002, 0.058))
    # ladle: v03 stands on the turntable in front of the right cheek and leans on it (was floating
    # outside the turntable); a small bowl at its foot so it reads as a ladle, not a stray stick
    ladle = bc.box("ladle", (0.003, 0.003, 0.032), (0, 0, 0), "wood_light")
    ladle_parts = place([ladle], (-8, 0, 0), (0.027, -0.0115, HZ + 0.0085 + 0.016))
    ladle_parts.append(bc.blob("ladle_bowl", 0.0035, (0.027, -0.0137, HZ + 0.005 + 0.0025), "wood_light", 1, squash=(1, 1, 0.8)))
    LADLE_PIVOT = (0.027, -0.0137, HZ + 0.005)  # v06: own part (__ladle), pivots at its foot (stir / wobble)

    AX = (0, 0.002, 0.058)  # cauldron pivot = the axle
    s = 0.85  # cauldron without the brew mesh: the brew is VFX now; a dark inner floor shows below the rim
    pot = place([
        bc.cone("belly", 0.022 * s, 0.032 * s, 0.016 * s, (0, 0, 0.008 * s), "ink", 10),
        bc.cone("shoulder", 0.032 * s, 0.027 * s, 0.012 * s, (0, 0, 0.022 * s), "ink", 10),
        bc.cone("rim", 0.0295 * s, 0.0295 * s, 0.004 * s, (0, 0, 0.0295 * s), "stone" if light_trim else "stone_dark", 10),
        bc.cone("opening", 0.025 * s, 0.025 * s, 0.002 * s, (0, 0, 0.0322 * s), "ink", 10),  # dark mouth the brew VFX fills
    ], (16, 0, 0), (0, 0.005, 0.043))  # mouth tipped toward the front (-Y)
    pot += place([bc.box("lug", (0.004, 0.008, 0.008), (0, 0, 0), "ink") for _ in (0, 1)], (0, 0, 0), (0, 0, 0))
    lugs = pot[-2:]
    for sx, lug in zip((-1, 1), lugs):
        lug.location = (sx * 0.0255, 0.002, 0.058)
        bc.apply_transforms(lug)

    root = bc.assemble(NAME, [
        ("", base, (0, 0, 0), None),
        ("head", head, (0, 0, HZ), ""),
        ("cauldron", pot, AX, "head"),
        ("ladle", ladle_parts, LADLE_PIVOT, "head"),
    ] + [("bomb_%d" % (i + 1), parts, (bx, by, bz), "") for i, (parts, (bx, by, bz, br)) in enumerate(zip(bomb_parts, BOMBS))])
    bc.anchor(root, "bomb_anchor", (0, -0.006, 0.073), parent_suffix="cauldron", size=0.006)
    # high_brew (critic suggestion): the brew VFX domes up above the rim so it reads from behind too
    bc.anchor(root, "brew_anchor", (0, -0.002, 0.075 if high_brew else 0.069), parent_suffix="cauldron", size=0.022)
    for i in range(8):
        a = math.radians(i * 45)  # on the slots' faces
        r = (BODY[0] + (BODY[1] - BODY[0]) * (RUNE_Z - BODY[2]) / (BODY[3] - BODY[2])) * math.cos(math.pi / 8) + 0.0005
        bc.anchor(root, "rune_anchor_%d" % (i + 1), (r * math.cos(a), r * math.sin(a), RUNE_Z), size=0.004)
    for i, (bx, by, bz, br) in enumerate(BOMBS):
        bc.anchor(root, "fuse_anchor_%d" % (i + 1), (bx, by, bz + br * 2.5), parent_suffix="bomb_%d" % (i + 1), size=0.002)
    bc.anchor(root, "pulse_anchor", (0, 0, 0), size=0.05)
    return root


def build(params=None, seed=0):
    v = (params or {}).get("variant", "A")
    parts, bomb_at = VARIANTS[v]()
    root = bc.assemble(NAME, [("", parts, (0, 0, 0), None)])
    bc.anchor(root, "bomb_anchor", bomb_at, size=0.006)
    bc.anchor(root, "pulse_anchor", (0, 0, 0), size=0.05)
    return root


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    v = args[0] if args else "final"
    bc.clear_scene()
    if v == "proposal":  # preview of the critic's suggestions: saved, never exported
        obj = build_final(plain_bombs=True, light_trim=True, high_brew=True)
        print("BLEND", bc.save_blend(obj, "bomb_tower_proposal"))
    elif v == "final":
        obj = build_final()
        print("BLEND", bc.save_blend(obj, "bomb_tower"))
        print("EXPORT", bc.export_glb(obj, "defense"))
    else:
        obj = build({"variant": v})
        print("BLEND", bc.save_blend(obj, "bomb_tower_" + v))
