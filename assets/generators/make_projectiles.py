"""Projectiles (D15 fireball core, D16 wind crossbow bolt, D20 Airship cannonball). Original designs.

Run: blender --factory-startup -b -P assets/generators/make_projectiles.py -- <fireball|bolt|cannonball> <A|B|C|D>
     blender --factory-startup -b -P assets/generators/make_projectiles.py -- FINAL <fireball|bolt|cannonball> <A-D> <vNN>

Fire and wind are VFX (Siddharth 2026-10-21: dark core with VFX sockets): the model is only the solid core, with an
empty at __fire_anchor / __wind_anchor where Godot attaches the flames, trail or wind streaks.
Travel direction is +Y in Blender (forward, -Z in Godot after the glTF export); origin = bottom centre of the lying shape.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import blender_common as bc  # noqa: E402


# ------------------------------------------------------------------ fireball core (about 1/3 cell)
def fireball_A():
    """Faceted ember-rock: a squashed icosphere with a darker lower half."""
    return [bc.blob("core", 0.0085, (0, 0, 0.0085), "stone_dark", 1, (1, 1, 0.92)),
            bc.blob("crust", 0.0060, (0.0035, -0.0030, 0.0120), "wood_dark", 1, (1, 1, 0.8))]


def fireball_B():
    """Comet: round rock head and two shrinking tail lumps behind it (built along +Z, then laid down so travel is +Y)."""
    return [bc.blob("head", 0.0085, (0, 0, 0.0230), "stone_dark", 1),
            bc.blob("tail", 0.0068, (0, 0, 0.0130), "wood_dark", 1),
            bc.blob("tail", 0.0045, (0, 0, 0.0055), "wood_dark", 1)]


def fireball_C():
    """Jagged cluster: three spikes of different heights."""
    return [bc.cone("spike", 0.0060, 0.0, 0.0170, (0, 0, 0.0085), "stone_dark", 5, 10),
            bc.cone("spike", 0.0050, 0.0, 0.0130, (0.0065, 0.0020, 0.0065), "wood_dark", 5, 40),
            bc.cone("spike", 0.0048, 0.0, 0.0115, (-0.0058, 0.0035, 0.0058), "wood_dark", 5, 70),
            bc.cone("base", 0.0090, 0.0075, 0.0040, (0.0005, 0.0010, 0.0020), "stone_dark", 6)]


def fireball_D():
    """Banded ball: round core with an iron-like belt."""
    return [bc.blob("core", 0.0085, (0, 0, 0.0085), "stone_dark", 1),
            bc.cone("band", 0.0090, 0.0090, 0.0026, (0, 0, 0.0085), "wood_dark", 8)]


# ------------------------------------------------------------------ wind crossbow bolt (about 0.9 cell long, built along +Z)
def bolt_A():
    """Straight bolt: wood shaft, dark pyramid head, three cream fins."""
    p = [bc.box("shaft", (0.0036, 0.0036, 0.036), (0, 0, 0.018), "wood_light"),
         bc.cone("head", 0.0054, 0.0, 0.012, (0, 0, 0.042), "stone_dark", 4, 45)]
    for k in range(3):
        th = k * 120
        a = math.radians(th)
        p.append(bc.box("fin", (0.0026, 0.0075, 0.0100), (-0.0040 * math.sin(a), 0.0040 * math.cos(a), 0.0060), "wall_cream", th))
    return p


def bolt_B():
    """Fat dart: thick tapered shaft, big stone-dark head, two terracotta fins."""
    return [bc.cone("shaft", 0.0030, 0.0042, 0.030, (0, 0, 0.015), "wood_light", 6),
            bc.cone("head", 0.0060, 0.0, 0.014, (0, 0, 0.0370), "stone_dark", 6),
            bc.box("fin", (0.0014, 0.0110, 0.0100), (0, 0, 0.0060), "roof_terracotta"),
            bc.box("fin", (0.0110, 0.0014, 0.0100), (0, 0, 0.0060), "roof_terracotta")]


def bolt_C():
    """Harpoon bolt: dark shaft, wide barbed head, cream wrap band."""
    return [bc.box("shaft", (0.0032, 0.0032, 0.040), (0, 0, 0.020), "wood_dark"),
            bc.cone("head", 0.0050, 0.0, 0.009, (0, 0, 0.0445), "stone_dark", 4, 45),
            bc.box("barb", (0.0100, 0.0022, 0.0030), (0, 0, 0.0385), "stone_dark"),
            bc.box("band", (0.0044, 0.0044, 0.0040), (0, 0, 0.0300), "wall_cream"),
            bc.box("fin", (0.0014, 0.0090, 0.0090), (0, 0, 0.0050), "wall_cream"),
            bc.box("fin", (0.0090, 0.0014, 0.0090), (0, 0, 0.0050), "wall_cream")]


def bolt_D():
    """Stubby quarrel: short chunky wood body, rounded stone head, no fins (reads at arm's length)."""
    return [bc.cone("shaft", 0.0040, 0.0040, 0.026, (0, 0, 0.013), "wood_light", 6),
            bc.blob("head", 0.0055, (0, 0, 0.0295), "stone_dark", 1, (1, 1, 1.5)),
            bc.cone("nock", 0.0050, 0.0050, 0.0030, (0, 0, 0.0015), "roof_terracotta", 6)]


# ------------------------------------------------------------------ Airship cannonball (about 1/4 cell)
def cannon_A():
    """Smooth iron ball with a belt."""
    return [bc.blob("ball", 0.0090, (0, 0, 0.0090), "stone_dark", 2),
            bc.cone("band", 0.0093, 0.0093, 0.0024, (0, 0, 0.0090), "wood_dark", 8)]


def cannon_B():
    """Faceted chunky ball (icosahedron), two-tone."""
    return [bc.blob("ball", 0.0095, (0, 0, 0.0095), "stone_dark", 1),
            bc.blob("cap", 0.0060, (0.0030, -0.0030, 0.0125), "stone", 1)]


def cannon_C():
    """Fuse ball: round shell with a wood fuse stub and cap (VFX fuse sparks at the anchor)."""
    return [bc.blob("ball", 0.0090, (0, 0, 0.0090), "stone_dark", 1),
            bc.cone("stub", 0.0024, 0.0018, 0.0050, (0, 0, 0.0190), "wood_light", 5),
            bc.cone("collar", 0.0040, 0.0040, 0.0018, (0, 0, 0.0170), "wood_dark", 6)]


def cannon_D():
    """Studded ball: dark shell with three raised cream rivets."""
    p = [bc.blob("ball", 0.0090, (0, 0, 0.0090), "stone_dark", 1)]
    for k in range(3):
        a = math.radians(k * 120 + 20)
        p.append(bc.blob("rivet", 0.0020, (0.0085 * math.cos(a), 0.0085 * math.sin(a), 0.0090 + (0.002 if k == 0 else 0.0)), "wall_cream", 0))
    return p


KINDS = {"fireball": (dict(A=fireball_A, B=fireball_B, C=fireball_C, D=fireball_D), "fire_anchor", "defense_fireball", False, 0.022),
         "bolt": (dict(A=bolt_A, B=bolt_B, C=bolt_C, D=bolt_D), "wind_anchor", "defense_wind_bolt", True, 0.020),
         "cannonball": (dict(A=cannon_A, B=cannon_B, C=cannon_C, D=cannon_D), "fire_anchor", "defense_cannonball", False, 0.022)}


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def build(kind, letter, ver="v01"):
    builders, anchor_name, short, lay, asize = KINDS[kind]
    bc.clear_scene()
    name = "ew_%s_%s" % (short, ver)
    obj = bc.finish(builders[letter](), name, do_bevel=False)  # parts are 2-10 mm: a bevel would only add triangles
    if lay or (kind == "fireball" and letter == "B"):  # built along +Z, travel direction +Y
        bc.rotate(obj, (-90, 0, 0))
        bc.origin_to_base(obj)
    xs = [v.co for v in obj.data.vertices]
    cz = (min(c.z for c in xs) + max(c.z for c in xs)) / 2
    bc.anchor(obj, anchor_name, (0, 0, cz), size=asize)
    obj["ew_footprint"], obj["ew_front"], obj["ew_place"] = "1x1", "+Y", "projectile"
    dims = obj.dimensions
    print("%s %s: %d tris, %.1f x %.1f x %.1f mm" % (name, letter, tris(obj), dims.x * 1000, dims.y * 1000, dims.z * 1000))
    return obj


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if args and args[0] == "FINAL":
        obj = build(args[1], args[2], args[3])
        bc.save_blend(obj, "projectile_" + args[1])
        print("EXPORT", bc.export_glb(obj, "defense"))
    else:
        kind, letter = args[0], args[1]
        obj = build(kind, letter)
        bc.save_blend(obj, "proj_%s_%s" % (kind, letter))
