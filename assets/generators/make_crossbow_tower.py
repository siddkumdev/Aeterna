"""Wind crossbow tower (asset list D04, was "Longbow Tower"; name open): design variants A-D.

    blender --factory-startup -b -P assets/generators/make_crossbow_tower.py          (final: variant G, exported)
    blender --factory-startup -b -P assets/generators/make_crossbow_tower.py -- A     (design variant A-H)

Siddharth (2026-10-18): a BIG MOUNTED CROSSBOW (horizontal prod on a stock, a plain wooden bolt on top)
on a turning mount, powered by WIND MAGIC in pale green. The wind is pure VFX on the bolt (__bolt_anchor):
no vanes or vents on the model. Role (GAME_SPEC): weaker than the Fire Tower, longer range (6 cells),
piercing (each bolt hits every enemy in a line), 4 damage, one shot per 1.2 s.
Footprint 2 x 2 cells, Fire Tower detail level, chunky enough to read at arm's length (no thin spires).

Variants (shape ideas, original geometry; they differ in the base so the towers separate at a glance):
    A  Lookout Perch  - slender stone-and-timber lookout, crossbow on a swivel at the very top (tall, thin)
    B  Bolt Deck      - low wide timber deck on stone piers, crossbow on a turntable, bolt crate (low, open)
    C  Gate Mount     - two stone pillars carry the crossbow on an axle between them (frame, mid height)
    D  Crossbow Keep  - square stone keep, crossbow on a roof turntable behind corner merlons (solid, mid)
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import blender_common as bc  # noqa: E402
from mathutils import Vector  # noqa: E402

NAME = "ew_defense_crossbow_tower_v04"  # v04: adds __crew_anchor (geometry unchanged from v03)
R8 = 22.5


def place(objs, rot, loc):
    """Rotate parts built around the origin (degrees XYZ), then move them to loc."""
    for o in objs:
        bc.rotate(o, rot)
        o.location = loc
        bc.apply_transforms(o)
    return objs


def seg(name, a, b, w, d, col, extend=0.0):
    """A w x d box running from point a to point b (any direction), lengthened by extend at both ends."""
    a, b = Vector(a), Vector(b)
    if extend:
        u = (b - a).normalized()
        a, b = a - u * extend, b + u * extend
    o = bc.box(name, (w, d, (b - a).length), (0, 0, 0), col)
    o.rotation_euler = Vector((0, 0, 1)).rotation_difference(b - a).to_euler()
    o.location = (a + b) / 2
    bc.apply_transforms(o)
    return o


PROD_COL = "wood_dark"  # v02 (Siddharth): dark bow so it reads on the light deck and stays out of the orange family


def crossbow(span=0.064, bulge=0.010, stock=0.050):
    """Big mounted crossbow built around its pivot (the mount point under the stock) at the origin,
    shooting toward -Y. Horizontal prod (bow) at the front, string drawn back to the latch, plain wooden
    bolt on top. Returns (parts, bolt_tip)."""
    zt = 0.008                                   # stock top height above the pivot
    front = -stock / 2 + 0.004                   # prod position along Y
    parts = [
        bc.box("stock", (0.013, stock, 0.008), (0, 0, zt - 0.004), "wood_dark"),
        bc.box("butt", (0.013, 0.012, 0.011), (0, stock / 2 - 0.004, zt - 0.006), "wood_dark"),
        bc.box("rail", (0.004, stock - 0.006, 0.002), (0, -0.002, zt + 0.0008), "wood_light"),
        bc.box("prod_block", (0.016, 0.009, 0.011), (0, front, zt - 0.003), "stone_dark"),  # iron nose
    ]
    for y in (-0.004, 0.012):  # iron bands
        parts.append(bc.box("band", (0.015, 0.003, 0.009), (0, y, zt - 0.004), "stone_dark"))
    # prod: chunky curved limbs, bulging forward, tapering to the tips
    n, hw = 6, span / 2
    pts = [(x, front - bulge * (1 - (x / hw) ** 2) + bulge, zt - 0.001) for x in [-hw + i * span / n for i in range(n + 1)]]
    for i in range(n):
        t = abs((pts[i][0] + pts[i + 1][0]) / 2) / hw
        parts.append(seg("prod", pts[i], pts[i + 1], 0.0075 * (1.1 - 0.4 * t), 0.0078 * (1.1 - 0.4 * t), PROD_COL, extend=0.0012))
    for x in (-hw, hw):
        parts.append(bc.box("prod_cap", (0.005, 0.005, 0.005), (x, pts[0][1], zt - 0.001), "roof_terracotta"))
    latch = (0, 0.010, zt + 0.0015)
    parts += [seg("string", (-hw, pts[0][1] + 0.001, zt - 0.001), latch, 0.003, 0.003, "bone"),
              seg("string", latch, (hw, pts[0][1] + 0.001, zt - 0.001), 0.003, 0.003, "bone"),
              bc.box("latch", (0.008, 0.005, 0.005), (0, 0.013, zt + 0.0005), "stone_dark")]
    # plain wooden bolt on the rail
    tail, tip = 0.011, -stock / 2 - 0.010
    parts.append(seg("bolt", (0, tail, zt + 0.0035), (0, tip + 0.005, zt + 0.0040), 0.004, 0.004, "wood_light"))
    head = bc.cone("bolt_head", 0.0045, 0.0, 0.009, (0, 0, 0), "stone_dark", 4)
    head["no_bevel"] = True
    bc.rotate(head, (90, 0, 45))
    head.location = (0, tip + 0.001, zt + 0.0040)
    bc.apply_transforms(head)
    parts.append(head)
    for rx in (0, 90):  # cross fletching
        f = bc.box("fletch", (0.002, 0.009, 0.007), (0, 0, 0), "roof_terracotta")
        place([f], (0, rx, 0), (0, tail - 0.004, zt + 0.0040))
        parts.append(f)
    return parts, (0, tip - 0.003, zt + 0.0040)


BOW_SCALE = 1.3  # critic v01: the crossbow read as a thin "T"; scale it up about its pivot


def mount(cb, loc, pitch=0.0, scale=BOW_SCALE):
    parts, tip = cb
    for o in parts:
        o.scale = (scale,) * 3
        bc.apply_transforms(o)
    tip = tuple(c * scale for c in tip)
    place(parts, (pitch, 0, 0), loc)
    t = Vector(tip)
    t.rotate(bc.mathutils.Euler((math.radians(pitch), 0, 0)))
    return parts, tuple(t + Vector(loc))


def swivel(z, base=None, col="wood_dark"):
    """Fork that holds the (scaled) crossbow at its pivot z: post from base up to the stock, two cheeks
    touching the stock sides and a cross pin. base = top of whatever the post stands on."""
    base = z - 0.012 if base is None else base
    hw = 0.0065 * BOW_SCALE                      # half stock width after scaling
    return [bc.box("swivel_post", (0.010, 0.010, z - base + 0.001), (0, 0, (z + base) / 2), col),
            bc.box("swivel_pin", (2 * hw + 0.010, 0.006, 0.006), (0, 0, z + 0.004), "stone_dark")] +            [bc.box("swivel_cheek", (0.004, 0.013, 0.013), (sx * (hw + 0.002), 0, z + 0.002), col) for sx in (-1, 1)]


def variant_a():
    """Lookout Perch: slender, tall."""
    p = [
        bc.cone("footing", 0.038, 0.036, 0.008, (0, 0, 0.004), "stone_dark", 8, R8),
        bc.cone("stone", 0.031, 0.027, 0.044, (0, 0, 0.030), "stone", 8, R8),
        bc.cone("band", 0.029, 0.029, 0.005, (0, 0, 0.0545), "wood_dark", 8, R8),
    ]
    for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        p.append(bc.box("post", (0.005, 0.005, 0.030), (sx * 0.018, sy * 0.018, 0.072), "wood_dark"))
    for a in (0, 90, 180, 270):
        br = bc.box("brace", (0.034, 0.0035, 0.0035), (0, 0, 0), "wood_light")
        place([br], (0, 30, a), (0.018 * math.cos(math.radians(a + 90)), 0.018 * math.sin(math.radians(a + 90)), 0.072))
        p.append(br)
    p += [bc.cone("deck", 0.032, 0.032, 0.005, (0, 0, 0.0895), "wood_light", 8, R8),
          bc.cone("turntable", 0.014, 0.014, 0.004, (0, 0, 0.094), "wood_dark", 8, R8),
          bc.box("door", (0.012, 0.004, 0.018), (0, -0.0300, 0.017), "wood_dark"),
          bc.box("slit", (0.004, 0.004, 0.012), (0.0275, 0, 0.034), "ink")]
    p += swivel(0.112, 0.096)
    bow, tip = mount(crossbow(), (0, 0, 0.112))
    return p + bow, tip


def variant_b():
    """Bolt Deck: low, wide, open timber."""
    p = [bc.box("pier", (0.016, 0.016, 0.014), (sx * 0.030, sy * 0.030, 0.007), "stone")
         for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1))]
    p += [bc.box("deck", (0.084, 0.084, 0.005), (0, 0, 0.0165), "wood_light")]
    for i in range(5):
        p.append(bc.box("plank_gap", (0.084, 0.0008, 0.0006), (0, -0.034 + i * 0.017, 0.0192), "wood_dark"))
    for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        p.append(bc.box("rail_post", (0.005, 0.005, 0.012), (sx * 0.039, sy * 0.039, 0.025), "wood_dark"))
    p += [bc.box("rail", (0.082, 0.004, 0.004), (0, 0.039, 0.030), "wood_dark")]
    p += [bc.box("rail", (0.004, 0.082, 0.004), (sx * 0.039, 0, 0.030), "wood_dark") for sx in (-1, 1)]
    p += [bc.cone("turntable", 0.022, 0.022, 0.005, (0, 0, 0.0215), "wood_dark", 8, R8),
          bc.cone("drum", 0.012, 0.014, 0.012, (0, 0, 0.030), "stone", 8, R8)]
    p += [bc.box("crate", (0.016, 0.012, 0.010), (-0.026, 0.026, 0.024), "wood_light"),
          bc.box("crate_band", (0.017, 0.013, 0.002), (-0.026, 0.026, 0.024), "wood_dark")]
    p += [bc.box("bolt_spare", (0.020, 0.0025, 0.0025), (-0.026, 0.024 + dy, 0.0305), "wood_light") for dy in (-0.003, 0.003)]
    p += swivel(0.048)
    bow, tip = mount(crossbow(), (0, 0, 0.048))
    return p + bow, tip


def variant_c():
    """Gate Mount: two stone pillars carry the crossbow on an axle."""
    p = [bc.box("plinth", (0.084, 0.064, 0.008), (0, 0, 0.004), "stone_dark")]
    for sx in (-1, 1):
        p += [bc.box("pillar", (0.018, 0.024, 0.056), (sx * 0.033, 0.006, 0.036), "stone"),
              bc.box("pillar_cap", (0.022, 0.028, 0.005), (sx * 0.033, 0.006, 0.0665), "roof_terracotta")]
        for z in (0.018, 0.040):
            p.append(bc.box("block", (0.0185, 0.010, 0.006), (sx * 0.033, -0.007, z), "stone_dark"))
    axle = bc.cone("axle", 0.003, 0.003, 0.050, (0, 0, 0), "ink", 6)
    place([axle], (0, 90, 0), (0, 0.006, 0.052))
    p += [axle, bc.box("landing", (0.040, 0.020, 0.016), (0, 0.024, 0.016), "stone")]
    for i in range(2):
        p.append(bc.box("step", (0.020, 0.006, 0.005), (0, 0.037, 0.0105 + i * 0.000), "stone_dark"))
    bow, tip = mount(crossbow(span=0.056), (0, 0.004, 0.052))
    return p + bow, tip


def variant_d():
    """Crossbow Keep: square stone keep, crossbow on the roof."""
    p = [
        bc.box("footing", (0.082, 0.082, 0.008), (0, 0, 0.004), "stone_dark"),
        bc.box("keep", (0.070, 0.070, 0.044), (0, 0, 0.030), "stone"),
        bc.box("parapet_band", (0.076, 0.076, 0.004), (0, 0, 0.054), "wood_dark"),
    ]
    for i in range(4):
        a = math.radians(45 + i * 90)
        p.append(bc.box("merlon", (0.013, 0.013, 0.011), (0.0435 * math.cos(a), 0.0435 * math.sin(a), 0.0615), "stone"))
    p += [bc.box("door_frame", (0.020, 0.003, 0.025), (0, -0.0355, 0.0205), "stone_dark"),
          bc.box("door", (0.014, 0.004, 0.020), (0, -0.0365, 0.018), "wood_dark"),
          bc.box("window", (0.010, 0.003, 0.010), (0.0355, 0, 0.034), "ink"),
          bc.box("shutter", (0.004, 0.006, 0.010), (0.0375, -0.008, 0.034), "roof_orange")]
    for z in (0.016, 0.040):
        p.append(bc.box("block", (0.013, 0.004, 0.006), (-0.0355, 0.010, z), "stone_dark"))
    p += [bc.cone("turntable", 0.024, 0.024, 0.004, (0, 0, 0.058), "wood_dark", 8, R8)]
    p += swivel(0.074, 0.060)
    bow, tip = mount(crossbow(), (0, 0, 0.074))
    return p + bow, tip


# ---- hybrids of A, B and D (Siddharth liked A, B, D on 2026-10-18) --------------------------------

def deck_top(z, size=0.070, rails=True, crate=True, crate_at=(-1, 1)):
    """B's timber deck (planks, rail, bolt crate) with its top at height z."""
    p = [bc.box("deck", (size, size, 0.005), (0, 0, z - 0.0025), "wood_light")]
    h = size / 2 - 0.003
    if rails:
        for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
            p.append(bc.box("rail_post", (0.005, 0.005, 0.014), (sx * h, sy * h, z + 0.007), "wood_dark"))
        p += [bc.box("rail", (size - 0.002, 0.004, 0.004), (0, h, z + 0.010), "wood_dark")]
        p += [bc.box("rail", (0.004, size - 0.002, 0.004), (sx * h, 0, z + 0.010), "wood_dark") for sx in (-1, 1)]
    if crate:
        cx, cy = crate_at[0] * (h - 0.011), crate_at[1] * (h - 0.010)
        p += [bc.box("crate", (0.014, 0.011, 0.009), (cx, cy, z + 0.0045), "wood_dark"),   # v02: dark crate, light band
              bc.box("crate_band", (0.015, 0.012, 0.002), (cx, cy, z + 0.0045), "wood_light")]
        # one spare bolt with an iron head, so most of the dark crate top shows from above (critic v02)
        p += [bc.box("bolt_spare", (0.016, 0.0035, 0.0035), (cx, cy - 0.0025, z + 0.0100), "wood_light"),
              bc.box("bolt_spare_head", (0.004, 0.0045, 0.0045), (cx - 0.008, cy - 0.0025, z + 0.0100), "stone_dark")]
    return p


def keep_storey(h, w=0.070):
    """D's square stone keep (footing, walls, door, shuttered window, blocks), top at height h."""
    p = [bc.box("footing", (w + 0.012, w + 0.012, 0.008), (0, 0, 0.004), "stone_dark"),
         bc.box("keep", (w, w, h - 0.008), (0, 0, (h + 0.008) / 2), "stone"),
         bc.box("door_frame", (0.020, 0.003, 0.025), (0, -w / 2 - 0.0005, 0.0205), "stone_dark"),
         bc.box("door", (0.014, 0.004, 0.020), (0, -w / 2 - 0.0015, 0.018), "wood_dark"),
         bc.box("window", (0.010, 0.003, 0.010), (w / 2 + 0.0005, 0, min(0.034, h - 0.010)), "ink"),
         bc.box("shutter", (0.004, 0.006, 0.010), (w / 2 + 0.002, -0.008, min(0.034, h - 0.010)), "roof_orange")]
    for z in (0.016, min(0.040, h - 0.008)):
        p.append(bc.box("block", (0.004, 0.013, 0.006), (-w / 2 - 0.0005, 0.010, z), "stone_dark"))
    return p


def perch_frame(z0, z1, r=0.018):
    """A's open timber frame: 4 posts and post-to-post diagonal braces from z0 to z1."""
    p = [bc.box("post", (0.005, 0.005, z1 - z0), (sx * r, sy * r, (z0 + z1) / 2), "wood_dark")
         for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1))]
    run, rise = 2 * r - 0.005, (z1 - z0) - 0.006
    for a in (0, 90, 180, 270):
        br = bc.box("brace", (math.hypot(run, rise) + 0.003, 0.0035, 0.0035), (0, 0, 0), "wood_light")
        place([br], (0, math.degrees(math.atan2(rise, run)), a),
              (r * math.cos(math.radians(a + 90)), r * math.sin(math.radians(a + 90)), (z0 + z1) / 2))
        p.append(br)
    return p


def variant_e():
    """A on B: the slender (squared) lookout rises from a low timber deck on stone piers."""
    p = [bc.box("pier", (0.014, 0.014, 0.010), (sx * 0.031, sy * 0.031, 0.005), "stone")
         for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1))]
    p += deck_top(0.015, size=0.084, rails=False, crate=True)
    p += [bc.cone("stone", 0.031, 0.027, 0.034, (0, 0, 0.032), "stone", 4, 45),
          bc.cone("band", 0.029, 0.029, 0.005, (0, 0, 0.0515), "wood_dark", 4, 45),
          bc.box("door", (0.011, 0.004, 0.016), (0, -0.0215, 0.023), "wood_dark")]
    p += perch_frame(0.054, 0.084)
    p += [bc.cone("perch_deck", 0.040, 0.040, 0.005, (0, 0, 0.0865), "wood_light", 4, 45),
          bc.cone("turntable", 0.022, 0.022, 0.004, (0, 0, 0.091), "wood_dark", 8, R8)]
    p += swivel(0.109, 0.093)
    bow, tip = mount(crossbow(), (0, 0, 0.109))
    return p + bow, tip


def variant_f():
    """D + A: the square keep with A's open timber perch on its roof."""
    p = keep_storey(0.046)
    p += [bc.box("parapet_band", (0.076, 0.076, 0.004), (0, 0, 0.048), "wood_dark")]
    for i in range(4):
        a = math.radians(45 + i * 90)
        p.append(bc.box("merlon", (0.012, 0.012, 0.010), (0.0435 * math.cos(a), 0.0435 * math.sin(a), 0.055), "stone"))
    p += perch_frame(0.050, 0.078, r=0.016)
    p += [bc.cone("perch_deck", 0.036, 0.036, 0.005, (0, 0, 0.0805), "wood_light", 4, 45),
          bc.cone("turntable", 0.022, 0.022, 0.004, (0, 0, 0.085), "wood_dark", 8, R8)]
    p += swivel(0.103, 0.087)
    bow, tip = mount(crossbow(), (0, 0, 0.103))
    return p + bow, tip


def variant_g():
    """D + B: a low stone keep with B's railed timber deck on top (crate, turntable)."""
    p = keep_storey(0.040)
    p += [bc.box("corbel", (0.005, 0.006, 0.006), (sx * 0.0375, sy * 0.020, 0.039), "wood_dark")
          for sx in (-1, 1) for sy in (-1, 1)]
    p += deck_top(0.045, size=0.082)
    p += [bc.cone("turntable", 0.026, 0.026, 0.005, (0, 0, 0.0475), "wood_dark", 8, R8),
          bc.cone("drum", 0.011, 0.013, 0.010, (0, 0, 0.055), "stone", 8, R8)]
    p += swivel(0.070, 0.060)
    bow, tip = mount(crossbow(), (0, 0, 0.070))
    return p + bow, tip


def variant_h():
    """A + B + D: A's tall lookout (squared, D's stone), topped by B's railed deck with D's corner merlons."""
    p = [bc.box("footing", (0.078, 0.078, 0.008), (0, 0, 0.004), "stone_dark"),
         bc.cone("stone", 0.044, 0.038, 0.050, (0, 0, 0.033), "stone", 4, 45),
         bc.box("door", (0.012, 0.004, 0.018), (0, -0.0305, 0.017), "wood_dark"),
         bc.box("slit", (0.004, 0.004, 0.012), (0.0290, 0, 0.036), "ink")]
    for a in (0, 90, 180, 270):
        for off in (-0.014, 0.014):
            c, sn = math.cos(math.radians(a)), math.sin(math.radians(a))
            p.append(bc.box("corbel", (0.006, 0.006, 0.006), (0.029 * c - off * sn, 0.029 * sn + off * c, 0.0575), "wood_dark"))
    p += deck_top(0.063, size=0.074, rails=False, crate=False)
    for i in range(4):
        a = math.radians(45 + i * 90)
        p.append(bc.box("merlon", (0.012, 0.012, 0.010), (0.0405 * math.cos(a), 0.0405 * math.sin(a), 0.068), "stone"))
    p += [bc.cone("turntable", 0.024, 0.024, 0.005, (0, 0, 0.0655), "wood_dark", 8, R8)]
    p += swivel(0.085, 0.068)
    bow, tip = mount(crossbow(), (0, 0, 0.085))
    return p + bow, tip


VARIANTS = {"A": variant_a, "B": variant_b, "C": variant_c, "D": variant_d,
            "E": variant_e, "F": variant_f, "G": variant_g, "H": variant_h}


def build_final(seed=0):
    """Variant G picked by Siddharth (2026-10-18): low square stone keep, railed timber deck on top with a
    bolt crate, crossbow on a turntable. The turntable, drum, swivel and crossbow turn together as __swivel
    (pivot: deck top centre, rotates about Z); the wind VFX anchor rides on it."""
    W, KEEP_TOP, DECK = 0.070, 0.040, 0.045
    hw = W / 2
    base = keep_storey(KEEP_TOP, W)
    base += [bc.box("corbel", (0.005, 0.006, 0.006), (sx * 0.0375, sy * 0.020, 0.039), "wood_dark")
             for sx in (-1, 1) for sy in (-1, 1)]
    # masonry blocks on every face (critic v02: front and right were bare); stick out 1.5 mm
    for x, z in ((-0.024, 0.013), (0.024, 0.020), (-0.019, 0.031)):            # front (-Y), clear of the door
        base.append(bc.box("block", (0.013, 0.004, 0.006), (x, -hw - 0.0005, z), "stone_dark"))
    for y, z in ((0.022, 0.014), (-0.022, 0.016), (0.020, 0.031)):             # right (+X), clear of the window
        base.append(bc.box("block", (0.004, 0.013, 0.006), (hw + 0.0005, y, z), "stone_dark"))
    for x, z in ((0.015, 0.016), (-0.020, 0.028)):                             # back (+Y)
        base.append(bc.box("block", (0.013, 0.004, 0.006), (x, hw + 0.0005, z), "stone_dark"))
    base += [bc.box("sill", (0.015, 0.005, 0.0025), (hw + 0.0015, 0, 0.0238), "wood_dark"),
             bc.box("step", (0.024, 0.006, 0.0025), (0, -hw - 0.003, 0.0092), "stone")]
    base += deck_top(DECK, size=0.082, crate_at=(1, 1))  # crate back-right: seen by the camera, not under the bow at rest
    base += [bc.box("plank_groove", (0.080, 0.002, 0.001), (0, -0.041 + (i + 1) * 0.082 / 5, DECK + 0.0004), "wood_dark")
             for i in range(4)]
    turn = [bc.cone("turntable", 0.026, 0.026, 0.005, (0, 0, DECK + 0.0025), "wood_dark", 8, R8),
            bc.cone("drum", 0.013, 0.011, 0.010, (0, 0, DECK + 0.010), "stone", 8, R8)]
    turn += swivel(DECK + 0.025, DECK + 0.015)
    bow, tip = mount(crossbow(), (0, 0, DECK + 0.025))
    # v03 (Siddharth: split for animation/VFX): string, bolt and prod are their own parts under __swivel
    def kind(o):
        n = o.name.split(".")[0]
        return "string" if n == "string" else "bolt" if n in ("bolt", "bolt_head", "fletch") else                "prod" if n in ("prod", "prod_cap") else "stock"
    sets = {k: [o for o in bow if kind(o) == k] for k in ("stock", "string", "bolt", "prod")}
    def verts(objs):
        return [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    sv, bv, pv = verts(sets["string"]), verts(sets["bolt"]), verts(sets["prod"])
    mid = lambda vs, i: (min(v[i] for v in vs) + max(v[i] for v in vs)) / 2
    # string pivot on the line between the prod tips: scale Y to ~0.1 there and the V snaps flat (release)
    string_pivot = (0, min(v.y for v in sv), mid(sv, 2))
    bolt_pivot = (0, max(v.y for v in bv), mid(bv, 2))           # tail of the bolt (nock): slides / flies forward
    prod_pivot = (0, mid(pv, 1), mid(pv, 2))                     # centre of the bow arms: flex by scaling X
    root = bc.assemble(NAME, [("", base, (0, 0, 0), None),
                              ("swivel", turn + sets["stock"], (0, 0, DECK), ""),
                              ("string", sets["string"], string_pivot, "swivel"),
                              ("bolt", sets["bolt"], bolt_pivot, "swivel"),
                              ("prod", sets["prod"], prod_pivot, "swivel")])
    bc.anchor(root, "bolt_anchor", tip, parent_suffix="bolt", size=0.006)  # pale-green wind VFX rides on the bolt
    bc.anchor(root, "crew_anchor", (0.033, -0.033, 0.056), size=0.008)  # where the crew member stands: a deck corner, clear of the swinging bow
    bc.anchor(root, "pulse_anchor", (0, 0, 0), size=0.05)
    return root


def build(params=None, seed=0):
    v = (params or {}).get("variant", "A")
    parts, bolt_tip = VARIANTS[v]()
    root = bc.assemble(NAME, [("", parts, (0, 0, 0), None)])
    bc.anchor(root, "bolt_anchor", bolt_tip, size=0.006)  # wind VFX (pale green) wraps the bolt here
    bc.anchor(root, "pulse_anchor", (0, 0, 0), size=0.05)
    return root


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    v = args[0] if args else "final"
    bc.clear_scene()
    if v == "final":
        obj = build_final()
        print("BLEND", bc.save_blend(obj, "crossbow_tower"))
        print("EXPORT", bc.export_glb(obj, "defense"))
    else:
        obj = build({"variant": v})
        print("BLEND", bc.save_blend(obj, "crossbow_tower_" + v))
