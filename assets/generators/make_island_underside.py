"""W02 Island underside: the floating sky-island rock that hangs under the board (24 x 24 cells = 1.2 m).
Run:
    blender --factory-startup -b -P assets/generators/make_island_underside.py -- E      (variants E-G, saved as island_underside_<V>.blend)

Brief (Siddharth, 2026-10-29): a floating sky island; a MAGIC propulsion that is visible (obviously magic, not science:
no pipes, metal or gears); tiny magic villagers maintaining it, visible; and the workers "should seem to channel energy to
it occasionally" (each villager has a separate raised-able arm part and an energy anchor; the VFX pulses from them into the
propulsion). References: art/moodboard/island_underside_refs_2026-10-29/ (thick cliff-faced floating rocks with horizontal
strata, moss over the rim, ragged hanging chunks, small drifting rocks). Round 1 (variants A-D, a smooth funnel) was rejected:
'this is what I had in mind, not what you gave'.

Shape: a thick rounded block with near-vertical cliff walls in five stratified bands (small ledges, a slow undercut), moss
drips over the rim, a rough bottom with chunky hanging rocks, and a few small rocks drifting below (a separate part).
ORIGIN = the attach plane (the island's base, z = 0); everything hangs DOWN (negative z, -Y in glTF). The island v01
(12 x 12 cells, stretched x2 in Godot) has a 0.57 m wide base, so the rock starts at HALF = 0.285 * 2 = 0.57 half width.
The calibrated hover height is at least the model depth (about 0.8 m) plus a gap above any real table.
Magic rules: black / orange / red only, never blue; glowing is VFX at `__..._anchor` empties, the model only provides dark
sockets, carved runes and floating stones.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_common as bc  # noqa: E402
import bpy  # noqa: E402
import mathutils  # noqa: E402
from make_island import slab  # noqa: E402

HALF = 0.285 * 2          # half the base of the stretched island v01
ROCK_DEPTH = 0.50
ZB = -ROCK_DEPTH          # the rock's bottom plane
ZH = ZB - 0.22            # where the propulsion hangs (below the keel's neck)
MAX_DEPTH = 1.10          # everything hangs inside this
NAME_FINAL = "ew_world_island_underside_v02"
NAME = "ew_world_island_underside_v03"
P = 1.3                   # scale of the propulsion cluster (seed, roots, fins) relative to round 2
CONTRAST = {"roof_orange": "wall_cream", "roof_teal": "wall_cream", "roof_terracotta": "wall_cream", "wall_cream": "roof_terracotta"}


# ---------------------------------------------------------------------------------------------------------- helpers
def strut(name, p0, p1, r0, r1, col, segments=6):
    """A tapered stick from p0 (radius r0) to p1 (radius r1): ropes, roots, chains, tool handles."""
    p0, p1 = mathutils.Vector(p0), mathutils.Vector(p1)
    d = p1 - p0
    o = bc.cone(name, r0, r1, d.length, (0, 0, 0), col, segments)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = mathutils.Vector((0, 0, 1)).rotation_difference(d.normalized())
    o.location = (p0 + p1) / 2
    bc.apply_transforms(o)
    o["no_bevel"] = True
    return o


def jitter(o, amp, seed):
    """Rough up a layer: a vertex moves by an amount that depends only on its position (so shared rings move together
    and no seams open). Vertices on the attach plane stay."""
    for v in o.data.vertices:
        if v.co.z > -0.001:
            continue
        rnd = random.Random("%s%.4f%.4f%.4f" % (seed, v.co.x, v.co.y, v.co.z))
        v.co.x += rnd.uniform(-amp, amp)
        v.co.y += rnd.uniform(-amp, amp)


# (height, colour, inset at the top, inset at the bottom, roughness): vertical cliff on top, ledges, then a long taper
BANDS = ((0.040, "stone", 0.000, 0.008, 0.010), (0.045, "dirt_light", 0.004, 0.030, 0.012), (0.050, "stone", 0.022, 0.070, 0.014),
         (0.055, "dirt_dark", 0.060, 0.130, 0.018), (0.055, "stone", 0.120, 0.200, 0.020), (0.060, "dirt_dark", 0.190, 0.275, 0.024),
         (0.060, "dirt_light", 0.260, 0.350, 0.026), (0.065, "dirt_dark", 0.340, 0.425, 0.026), (0.070, "stone_dark", 0.410, 0.440, 0.020))


def inset_at(z):
    """How far the rock's wall is pulled in from the rim at height z (linear inside each band)."""
    top = 0.0
    for h, _c, i_top, i_bot, _a in BANDS:
        if z >= top - h:
            return i_top + (i_bot - i_top) * (top - z) / h
        top -= h
    return BANDS[-1][3]


def on_wall(a, z, out=0.0):
    """A point on the rock's wall at angle a (rounded-square plan), height z, `out` metres outside the wall."""
    r = HALF - inset_at(z) + out
    d = min(r / max(abs(math.cos(a)), abs(math.sin(a))), r * 1.22)
    x, y = d * math.cos(a), d * math.sin(a)
    k = warp(x, y, z)
    return x * k, y * k


def warp(x, y, z):
    """Radial scale that makes the rock lopsided and lumpy deeper down (0 at the rim). Same function for the walls and for
    everything stuck on them."""
    t = min(1.0, -z / 0.20) if z < 0 else 0.0
    a = math.atan2(y, x)
    return 1.0 + t * (0.07 * math.sin(a + 0.8) + 0.06 * math.sin(2 * a + 2.0) + 0.045 * math.sin(3 * a + 0.3) + 0.03 * math.sin(5 * a + 1.1 + 6 * z))


def drip(name, px, py, top_z, w, h, col, a_deg):
    """A tapered flat drip (moss): wide at the top, pointed at the bottom, thin in depth."""
    o = bc.cone(name, 0.004, w / 2, h, (0, 0, 0), col, 4, 45)
    o.scale = (1.0, 0.22, 1.0)
    bc.apply_transforms(o)
    o.rotation_euler = (0, 0, math.radians(a_deg))
    o.location = (px, py, top_z - h / 2)
    bc.apply_transforms(o)
    o["no_bevel"] = True
    return o


def rock(seed):
    """A heavy cliff block that tapers into a long keel: nine stratified bands, draped moss over the rim, boulders stuck on
    the ledges, big faceted masses hanging round the keel, and a neck where the propulsion hangs."""
    rnd = random.Random(seed)
    parts = []
    z = 0.0
    for i, (h, col, i_top, i_bot, amp) in enumerate(BANDS):
        o = slab("rock%d" % i, z - h, z, col, inset_top=i_top, inset_bot=i_bot, r=0.10, segs=3, half=HALF)
        jitter(o, amp, seed)
        for v in o.data.vertices:
            k = warp(v.co.x, v.co.y, v.co.z)
            v.co.x *= k
            v.co.y *= k
        parts.append(o)
        z -= h
    # draped moss over the rim: a few tapered drips of different width and length
    for side in range(4):
        a = math.radians(90 * side)
        tx, ty = -math.sin(a), math.cos(a)
        for j in range(3):
            t = -0.40 + 0.40 * j + rnd.uniform(-0.10, 0.10)
            px, py = (HALF + 0.006) * math.cos(a) + t * tx, (HALF + 0.006) * math.sin(a) + t * ty
            col = rnd.choice(("leaf_green", "leaf_light", "leaf_green"))
            parts.append(drip("moss", px, py, 0.0, rnd.uniform(0.07, 0.16), rnd.uniform(0.06, 0.20), col, math.degrees(a) + 90 + rnd.uniform(-8, 8)))
            if rnd.random() < 0.7:
                parts.append(drip("mosst", px + 0.07 * tx, py + 0.07 * ty, 0.0, rnd.uniform(0.04, 0.08), rnd.uniform(0.10, 0.26), col, math.degrees(a) + 90))
    # boulders stuck on the ledges, some with a moss cap
    for k in range(9):
        a = 2 * math.pi * k / 9 + rnd.uniform(-0.25, 0.25)
        zz = rnd.uniform(-0.06, -0.34)
        sz = rnd.uniform(0.035, 0.060)
        x, y = on_wall(a, zz, 0.004)
        bl = bc.blob("boulder%d" % k, sz, (x, y, zz), rnd.choice(("stone", "stone_dark", "dirt_light")), 0, (1.0, 0.9, 0.75))
        bl["no_bevel"] = True
        parts.append(bl)
        if rnd.random() < 0.6:
            parts.append(bc.cone("bcap%d" % k, sz * 0.9, sz * 0.65, 0.012, (x, y, zz + sz * 0.6), "leaf_green", 6, rnd.uniform(0, 60)))
    # big faceted masses hanging off the lower cliff, long and irregular (the reference's ragged hanging chunks)
    for k in range(11):
        a = 2 * math.pi * k / 11 + rnd.uniform(-0.2, 0.2)
        zt = rnd.uniform(-0.14, -0.42)
        h = rnd.uniform(0.12, 0.24)
        x, y = on_wall(a, zt, -0.020)
        o = bc.cone("mass%d" % k, rnd.uniform(0.010, 0.020), rnd.uniform(0.045, 0.075), h, (x, y, zt - h / 2 + 0.01),
                    rnd.choice(("stone", "dirt_dark", "stone", "dirt_light")), rnd.choice((5, 6, 7)), rnd.uniform(0, 60))
        o["no_bevel"] = True
        parts.append(o)
    for k, (a, zt, h) in enumerate(((0.5, -0.20, 0.34), (2.6, -0.17, 0.30), (4.4, -0.24, 0.27))):
        x, y = on_wall(a, zt, -0.020)
        o = bc.cone("stal%d" % k, 0.012, 0.062, h, (x, y, zt - h / 2 + 0.01), "dirt_dark", 6, 20 * k)
        o["no_bevel"] = True
        parts.append(o)
    # the central keel: a heavy cone that tapers down into the propulsion, so the engine grows out of the rock
    parts.append(bc.cone("keel1", 0.120, 0.175, 0.130, (0, 0, ZB - 0.050), "stone", 10))
    parts.append(bc.cone("keel2", 0.080, 0.120, 0.110, (0, 0, ZB - 0.155), "dirt_dark", 9))
    return parts


def debris(seed):
    """A few drifting rocks near the island's edge (their own part: Godot can bob and turn them slowly): a stone body with a
    moss cap, like the reference's small floating islands."""
    rnd = random.Random(seed)
    out = []
    for k in range(5):
        a = 2 * math.pi * k / 5 + rnd.uniform(-0.3, 0.3)
        r = rnd.uniform(0.62, 0.78)
        z = rnd.uniform(-0.55, -0.22)
        s = rnd.uniform(0.060, 0.090)
        x, y = r * math.cos(a), r * math.sin(a)
        b = bc.blob("drift%d" % k, s, (x, y, z), rnd.choice(("stone", "stone_dark", "dirt_light")), 0, (1.0, 0.9, 0.62))
        b["no_bevel"] = True
        out.append(b)
        out.append(bc.cone("driftcap%d" % k, s * 0.95, s * 0.7, 0.018, (x, y, z + s * 0.62), "leaf_green", 6, rnd.uniform(0, 60)))
    return out


def villager(tag, x, y, z, face_deg, cloth, tool, skin="skin_mid", hair=None):
    """A small static stand-in villager (about 8 cm so it reads at board scale; round hooded body, head, hood). The ARM and
    its tool are returned separately so Godot can raise them (channelling the island's energy). Returns
    (body parts, arm parts, shoulder position, tool-tip position). Durva's character kit replaces these later."""
    k = 4.0
    body = [bc.cone("%s_body" % tag, 0.0085 * k, 0.0055 * k, 0.016 * k, (x, y, z + 0.008 * k), cloth, 8),
            bc.blob("%s_head" % tag, 0.0068 * k, (x, y, z + 0.0215 * k), skin, 1)]
    hood = bc.cone("%s_hood" % tag, 0.0078 * k, 0.0005, 0.011 * k, (x, y, z + 0.0275 * k), hair or CONTRAST.get(cloth, "wall_cream"), 8)
    hood["no_bevel"] = True
    body.append(hood)
    a = math.radians(face_deg)
    fx, fy = math.cos(a), math.sin(a)
    shoulder = (x, y, z + 0.0135 * k)
    ax, ay = x + fx * 0.009 * k, y + fy * 0.009 * k
    arm = [strut("%s_arm" % tag, shoulder, (ax, ay, z + 0.017 * k), 0.0024 * k, 0.0020 * k, skin, 5)]
    tip = (ax, ay, z + 0.030 * k)
    if tool == "brush":
        arm.append(strut("%s_tool" % tag, (ax, ay, z + 0.004 * k), tip, 0.0014 * k, 0.0014 * k, "wood_dark", 4))
        arm.append(bc.box("%s_bristle" % tag, (0.008 * k, 0.004 * k, 0.005 * k), (ax, ay, z + 0.004 * k), "wood_light", face_deg))
    elif tool == "bucket":
        arm.append(bc.cone("%s_pail" % tag, 0.0065 * k, 0.0085 * k, 0.009 * k, (ax + fx * 0.004 * k, ay + fy * 0.004 * k, z + 0.012 * k), "wood_mid", 8))
        tip = (ax + fx * 0.004 * k, ay + fy * 0.004 * k, z + 0.019 * k)
    elif tool == "hammer":
        tip = (ax + fx * 0.002 * k, ay + fy * 0.002 * k, z + 0.034 * k)
        arm.append(strut("%s_tool" % tag, (ax, ay, z + 0.014 * k), tip, 0.0014 * k, 0.0014 * k, "wood_dark", 4))
        arm.append(bc.box("%s_head2" % tag, (0.009 * k, 0.004 * k, 0.004 * k), tip, "stone_dark", face_deg))
    elif tool == "cloth":
        arm.append(bc.box("%s_cloth" % tag, (0.009 * k, 0.002 * k, 0.009 * k), (ax, ay, z + 0.020 * k), "wall_cream", face_deg + 90))
        tip = (ax, ay, z + 0.026 * k)
    return body, arm, shoulder, tip


def plank(tag, x, y, z, w, d, rot=0.0, up=0.24):
    """A small wooden working platform (top surface at z) hung from the rim by two ropes."""
    parts = [bc.box("%s_plank" % tag, (w, d, 0.012), (x, y, z - 0.006), "wood_light", rot)]
    ca, sa = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    for s in (-1, 1):
        px, py = x + s * (w / 2 - 0.005) * ca, y + s * (w / 2 - 0.005) * sa
        parts.append(strut("%s_rope%d" % (tag, s), (px, py, z - 0.004), (px, py, z + up), 0.014, 0.014, "wood_dark", 5))
    return parts


def rune_cuts(tag, cx, cy, cz, r, n, col="ink"):
    """Dark carved rune marks round a ring of radius r at height cz."""
    return [bc.box("%s_rune%d" % (tag, k), (0.0035, 0.012, 0.008),
                   (cx + r * math.cos(2 * math.pi * (k + 0.5) / n), cy + r * math.sin(2 * math.pi * (k + 0.5) / n), cz),
                   col, math.degrees(2 * math.pi * (k + 0.5) / n)) for k in range(n)]


# the three working platforms hang on the cliff walls (the walls are near vertical, so the whole figure shows)
ZP = -0.24
SPOTS = ((0.575, -0.10, 90, 180), (0.10, -0.575, 0, 90), (-0.26, -0.575, 0, 90))   # x, y, plank rot, face_deg


def crew(prefix, specs):
    """Planks + villagers for SPOTS. specs: (cloth, tool, skin, hair). Returns (static parts, arm groups, anchors)."""
    parts, groups, anchors = [], [], {}
    for i, ((x, y, rot, face), (cloth, tool, skin, hair)) in enumerate(zip(SPOTS, specs)):
        tag = "%s%d" % (prefix, i + 1)
        parts += plank("p" + tag, x, y, ZP, 0.17, 0.09, rot)
        body, arm, shoulder, tip = villager("v" + tag, x, y, ZP, face, cloth, tool, skin, hair)
        parts += body
        groups.append(("v%s_arm" % tag, arm, shoulder, ""))
        anchors["v%s_energy_anchor" % tag] = (tip, "v%s_arm" % tag, 0.02)
    return parts, groups, anchors


# ---------------------------------------------------------------------------------------------------------- variants
def variant_e():
    """E RUNE RING: carved stone chunks float, unconnected, in a ring round a dark socket under the rock. That is the magic."""
    parts = rock(21)
    zc = ZH - 0.085
    parts.append(bc.cone("collar", 0.085, 0.070, 0.020, (0, 0, ZH - 0.010), "stone_dark", 12))
    parts.append(bc.cone("socket", 0.058, 0.050, 0.008, (0, 0, ZH - 0.024), "ink", 12))
    parts += rune_cuts("collar", 0, 0, ZH - 0.010, 0.084, 8, "ink")
    ring = []
    anchors = {"thrust_anchor": ((0, 0, ZH - 0.030), "", 0.045)}
    for k in range(8):
        a = 2 * math.pi * k / 8
        x, y = 0.21 * math.cos(a), 0.21 * math.sin(a)
        zz = zc + 0.006 * (-1) ** k
        st = bc.blob("rstone%d" % k, 0.046, (x, y, zz), "stone", 0, (0.8, 0.55, 1.35))
        st.rotation_euler = (0, 0, a)
        bc.apply_transforms(st)
        st["no_bevel"] = True
        ring.append(st)
        ring.append(bc.box("rrune%d" % k, (0.005, 0.030, 0.046), (x + 0.0285 * math.cos(a), y + 0.0285 * math.sin(a), zz), "ink", math.degrees(a)))
        anchors["rune_anchor_%d" % (k + 1)] = ((x, y, zz), "ring", 0.02)
    people, arm_groups, arm_anchors = crew("e", (("roof_orange", "cloth", "skin_light", None), ("roof_teal", "brush", "skin_dark", "hair_dark"),
                                                 ("roof_terracotta", "brush", "skin_mid", None)))
    anchors.update(arm_anchors)
    return [("", parts + people, (0, 0, 0), None), ("ring", ring, (0, 0, zc), ""), ("drift", debris(5), (0, 0, ZH - 0.15), "")] + arm_groups, anchors


def variant_f():
    """F ROOT AND SEED: old thick roots grow out of the keel and curl round one big seed pod with a dark crack: the island is
    carried by a living seed. Leaf fins round it turn slowly. Everything is P times the round-2 size."""
    parts = rock(22)
    zs = ZH - 0.105 * P
    for k in range(6):
        a = math.radians(60 * k + 12)
        a2 = a + math.radians(26)
        p0 = (0.100 * math.cos(a), 0.100 * math.sin(a), ZH + 0.020)
        p1 = (0.165 * P * math.cos(a2), 0.165 * P * math.sin(a2), ZH - 0.045 * P)
        p2 = (0.125 * P * math.cos(a2 + 0.35), 0.125 * P * math.sin(a2 + 0.35), zs + 0.010 * P)
        parts.append(strut("root%da" % k, p0, p1, 0.032, 0.026, "wood_dark", 6))
        parts.append(strut("root%db" % k, p1, p2, 0.026, 0.017, "wood_mid", 6))
        parts.append(bc.blob("knot%d" % k, 0.028, p1, "wood_dark", 1))
        parts.append(bc.cone("leaf%d" % k, 0.030, 0.005, 0.050, (p1[0], p1[1], p1[2] + 0.014), "leaf_green", 5, math.degrees(a2)))
    parts.append(bc.blob("seed", 0.095 * P, (0, 0, zs), "wood_light", 2, (1, 1, 0.72)))
    for k in range(8):
        a = 2 * math.pi * k / 8
        parts.append(bc.box("ridge%d" % k, (0.014, 0.016, 0.085 * P), (0.090 * P * math.cos(a), 0.090 * P * math.sin(a), zs + 0.002), "wood_mid", math.degrees(a)))
    parts.append(bc.cone("tip", 0.056 * P, 0.036 * P, 0.016 * P, (0, 0, zs - 0.058 * P), "wood_dark", 8))
    parts.append(bc.cone("crack", 0.036 * P, 0.028 * P, 0.010 * P, (0, 0, zs - 0.0665 * P), "ink", 8))
    fins = [bc.cone("fin%d" % k, 0.005, 0.050, 0.085, (0.200 * P * math.cos(2 * math.pi * k / 6), 0.200 * P * math.sin(2 * math.pi * k / 6), zs - 0.010 * P),
                    "leaf_yellow", 5, math.degrees(2 * math.pi * k / 6)) for k in range(6)]
    people, arm_groups, anchors = crew("f", (("roof_teal", "hammer", "skin_mid", None), ("roof_orange", "cloth", "skin_light", "hair_blonde"),
                                             ("wall_cream", "brush", "skin_dark", None)))
    anchors["thrust_anchor"] = ((0, 0, zs - 0.0715 * P), "", 0.06)
    return [("", parts + people, (0, 0, 0), None), ("fins", fins, (0, 0, zs), ""), ("drift", debris(6), (0, 0, ZH - 0.15), "")] + arm_groups, anchors


VARIANTS = {"E": variant_e, "F": variant_f}


def build(v, name=NAME):
    groups, anchors = VARIANTS[v]()
    root = bc.assemble(name, groups)
    for aname, (loc, parent, size) in anchors.items():
        bc.anchor(root, aname, loc, parent, size)
    return root


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    v = args[0] if args else "F"
    bc.clear_scene()
    if "final" in args:  # the chosen design (F, root and seed), exported as the real asset
        obj = build("F", NAME_FINAL)
        print("BLEND", bc.save_blend(obj, "island_underside"))
        print("GLB", bc.export_glb(obj, "world"))
    else:
        obj = build(v)
        print("BLEND", bc.save_blend(obj, "island_underside_" + v))
