"""Blast Brazier design variants (A-D) for Siddharth to pick and mix.

    blender --factory-startup -b -P assets/generators/make_blast_brazier.py -- A

Role (GAME_SPEC): short range (2 cells), good AoE (hits everything within 1 cell), lower damage,
pulses about once a second. Footprint 2 x 2 cells (0.10 m), ~85% filled. Detail level matches the
Fire Tower (Siddharth: "about right"). The fire and the AoE pulse are VFX (Siddharth: active towers
rely on VFX): the model only carries empties where Godot attaches them:
    __fire_anchor   where the flame VFX sits
    __pulse_anchor  centre of the AoE pulse ring, at ground level

Variants (shape ideas, original geometry):
    A  Great Brazier  - squat stepped plinth with a huge iron fire bowl on stubby legs
    B  Kiln           - round stone kiln/forge with a brick chimney and glowing vents all round
    C  Bellows Tower  - short stout tower with a fire bowl and two big bellows that pump each pulse
    D  Fire Shrine    - open pavilion: four posts, terracotta roof, a sunken fire pit underneath
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import blender_common as bc  # noqa: E402

NAME = "ew_defense_blast_brazier_v01"
R8 = 22.5


def ring(n, r, z, size, col, start=0.0, glow=False, name="ring"):
    out = []
    for i in range(n):
        a = math.radians(start + i * 360 / n)
        o = bc.box(name, size, (r * math.cos(a), r * math.sin(a), z), col, rot_z_deg=math.degrees(a) + 90)
        if glow:
            bc.paint(o, col, glow=True)
        out.append(o)
    return out


def glow(o, col):
    bc.paint(o, col, glow=True)
    return o


def woodpile(x, y, z0=0.0, along_x=False):
    out = []
    for i, (dx, dz) in enumerate([(-0.0038, 0.0036), (0.0038, 0.0036), (0.0, 0.0098)]):
        log = bc.cone("log", 0.0034, 0.0034, 0.015, (0, 0, 0), "wood_light" if i != 1 else "wood_dark", 6)
        bc.rotate(log, (0, 90, 0) if along_x else (90, 0, 0))
        log.location = (x + (0 if along_x else dx), y + (dx if along_x else 0), z0 + dz)
        bc.apply_transforms(log)
        out.append(log)
    return out


def variant_a():
    """Great Brazier: low, wide, one huge bowl. Fire VFX makes the height."""
    p = [
        bc.cone("plinth1", 0.042, 0.041, 0.010, (0, 0, 0.005), "stone_dark", 8, R8),
        bc.cone("plinth2", 0.035, 0.034, 0.010, (0, 0, 0.015), "stone", 8, R8),
        bc.box("step", (0.024, 0.008, 0.005), (0, -0.0385, 0.0125), "stone"),
    ]
    p += ring(8, 0.0375, 0.0130, (0.012, 0.004, 0.006), "stone", start=0, name="block")
    p += ring(4, 0.021, 0.028, (0.006, 0.006, 0.016), "ink", start=45, name="leg")
    p += [
        bc.cone("bowl", 0.020, 0.037, 0.022, (0, 0, 0.047), "stone_dark", 8, R8),
        bc.cone("band", 0.0335, 0.0335, 0.004, (0, 0, 0.051), "roof_terracotta", 8, R8),
        glow(bc.cone("coals", 0.034, 0.034, 0.002, (0, 0, 0.0585), "fire_red", 8, R8), "fire_red"),
    ]
    p += ring(10, 0.0365, 0.0585, (0.008, 0.004, 0.004), "roof_terracotta", start=18, name="lip")
    p += ring(6, 0.0275, 0.043, (0.006, 0.004, 0.006), "lantern_glow", start=0, glow=True, name="vent")
    p += woodpile(0.030, -0.030, 0.020, along_x=False)
    return p, (0, 0, 0.062), 0.026


def variant_b():
    """Kiln: a round stone forge that breathes fire out of its vents."""
    p = [
        bc.cone("base", 0.042, 0.041, 0.008, (0, 0, 0.004), "stone_dark", 8, R8),
        bc.cone("lower", 0.038, 0.034, 0.026, (0, 0, 0.021), "stone", 8, R8),
        bc.cone("band", 0.0345, 0.0345, 0.005, (0, 0, 0.0365), "roof_terracotta", 8, R8),
        bc.cone("dome", 0.033, 0.012, 0.024, (0, 0, 0.051), "stone", 8, R8),
        bc.cone("chimney", 0.010, 0.009, 0.022, (0, 0, 0.073), "roof_terracotta", 8, R8),
        bc.cone("chimney_cap", 0.012, 0.012, 0.004, (0, 0, 0.086), "stone_dark", 8, R8),
        bc.box("firebox_frame", (0.020, 0.004, 0.018), (0, -0.0355, 0.020), "stone_dark"),
        glow(bc.box("firebox", (0.014, 0.004, 0.012), (0, -0.0370, 0.019), "fire_red"), "fire_red"),
    ]
    # glowing vents round the body (the AoE pulse bursts out of these)
    for i in range(5):
        a = math.radians(-90 + 72 * (i + 0.5))
        r = 0.0355
        p.append(bc.box("vent_frame", (0.012, 0.004, 0.012), (r * math.cos(a), r * math.sin(a), 0.022), "stone_dark",
                        rot_z_deg=math.degrees(a) + 90))
        p.append(glow(bc.box("vent", (0.008, 0.004, 0.008), ((r + 0.0012) * math.cos(a), (r + 0.0012) * math.sin(a), 0.022),
                             "lantern_glow", rot_z_deg=math.degrees(a) + 90), "lantern_glow"))
    p += ring(6, 0.024, 0.052, (0.010, 0.004, 0.004), "stone_dark", start=30, name="brick")
    p += woodpile(-0.031, -0.028, 0.008, along_x=False)
    return p, (0, 0, 0.088), 0.008


def variant_c():
    """Bellows Tower: two big bellows pump the fire; each pump is one pulse."""
    p = [
        bc.cone("base", 0.040, 0.039, 0.008, (0, 0, 0.004), "stone_dark", 8, R8),
        bc.cone("body", 0.031, 0.028, 0.040, (0, 0, 0.028), "stone", 8, R8),
        bc.cone("band", 0.0300, 0.0300, 0.006, (0, 0, 0.049), "wood_dark", 8, R8),
        bc.cone("bowl", 0.016, 0.029, 0.014, (0, 0, 0.059), "stone_dark", 8, R8),
        glow(bc.cone("coals", 0.026, 0.026, 0.002, (0, 0, 0.0665), "fire_red", 8, R8), "fire_red"),
        bc.box("door", (0.012, 0.004, 0.018), (0, -0.0300, 0.017), "wood_dark"),
    ]
    p += ring(8, 0.0285, 0.0665, (0.008, 0.004, 0.004), "roof_terracotta", start=22.5, name="lip")
    for side in (-1, 1):  # bellows on the left and right, nozzles into the tower
        x = side * 0.034
        body = bc.box("bellows", (0.010, 0.022, 0.016), (x, 0.004, 0.030), "wood_dark")
        top = bc.box("bellows_board", (0.012, 0.026, 0.003), (x, 0.004, 0.0395), "wood_light")
        bot = bc.box("bellows_board", (0.012, 0.026, 0.003), (x, 0.004, 0.0205), "wood_light")
        handle = bc.box("bellows_handle", (0.003, 0.012, 0.003), (x, 0.022, 0.0405), "wood_light")
        nozzle = bc.cone("nozzle", 0.003, 0.002, 0.010, (0, 0, 0), "ink", 6)
        bc.rotate(nozzle, (0, 90, 0))
        nozzle.location = (side * 0.0285, -0.008, 0.030)
        bc.apply_transforms(nozzle)
        p += [body, top, bot, handle, nozzle]
    return p, (0, 0, 0.070), 0.020


def variant_d():
    """Fire Shrine: an open pavilion sheltering a sunken fire pit."""
    p = [
        bc.box("platform", (0.084, 0.084, 0.008), (0, 0, 0.004), "stone"),
        bc.box("platform_edge", (0.088, 0.088, 0.003), (0, 0, 0.0015), "stone_dark"),
        bc.cone("pit_ring", 0.022, 0.022, 0.006, (0, 0, 0.011), "stone_dark", 8, R8),
        glow(bc.cone("coals", 0.0185, 0.0185, 0.002, (0, 0, 0.0135), "fire_red", 8, R8), "fire_red"),
    ]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(bc.box("post", (0.006, 0.006, 0.040), (sx * 0.034, sy * 0.034, 0.028), "wood_dark"))
            lan = bc.box("lantern", (0.005, 0.005, 0.007), (sx * 0.026, sy * 0.026, 0.040), "lantern_glow")
            p.append(glow(lan, "lantern_glow"))
    p += [
        bc.box("beam_x1", (0.074, 0.005, 0.005), (0, -0.034, 0.0475), "wood_dark"),
        bc.box("beam_x2", (0.074, 0.005, 0.005), (0, 0.034, 0.0475), "wood_dark"),
        bc.box("beam_y1", (0.005, 0.074, 0.005), (-0.034, 0, 0.0475), "wood_dark"),
        bc.box("beam_y2", (0.005, 0.074, 0.005), (0.034, 0, 0.0475), "wood_dark"),
        bc.cone("roof", 0.064, 0.012, 0.024, (0, 0, 0.062), "roof_terracotta", 4, 45),
        bc.cone("vent_cap", 0.013, 0.006, 0.008, (0, 0, 0.078), "stone_dark", 4, 45),
    ]
    p += woodpile(0.006, -0.036, 0.008, along_x=True)
    return p, (0, 0, 0.016), 0.015


VARIANTS = {"A": variant_a, "B": variant_b, "C": variant_c, "D": variant_d}


def build(params=None, seed=0):
    v = (params or {}).get("variant", "A")
    parts, fire_at, fire_size = VARIANTS[v]()
    root = bc.assemble(NAME, [("", parts, (0, 0, 0), None)])
    bc.anchor(root, "fire_anchor", fire_at, size=fire_size)  # size = flame base radius
    bc.anchor(root, "pulse_anchor", (0, 0, 0), size=0.05)
    return root


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    v = args[0] if args else "A"
    bc.clear_scene()
    obj = build({"variant": v})
    print("BLEND", bc.save_blend(obj, "blast_brazier_" + v))
