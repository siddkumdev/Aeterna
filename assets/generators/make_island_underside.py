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
The calibrated hover height is at least the model depth (about 0.5 m) plus a gap above any real table.
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
ROCK_DEPTH = 0.26
ZB = -ROCK_DEPTH          # the rock's bottom plane
ZH = ZB - 0.04            # where the propulsion hangs (below the keel's neck)
MAX_DEPTH = 0.52          # everything hangs inside this
NAME = "ew_world_island_underside_v02"
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


def rock(seed):
    """The cliff block that tapers into a keel: six stratified bands (a vertical cliff on top, ledges, then a heavy undercut
    down to a narrow ragged keel), draped moss over the rim, a few large hanging masses round the keel, and a neck under
    it where the propulsion hangs."""
    rnd = random.Random(seed)
    parts = []
    # (height, colour, inset at the top, inset at the bottom, roughness)
    bands = ((0.036, "stone", 0.000, 0.010, 0.010), (0.040, "dirt_light", 0.004, 0.026, 0.010), (0.040, "stone", 0.020, 0.062, 0.012),
             (0.045, "dirt_dark", 0.052, 0.150, 0.016), (0.045, "stone_dark", 0.140, 0.290, 0.018), (0.054, "dirt_dark", 0.280, 0.400, 0.006))
    z = 0.0
    for i, (h, col, i_top, i_bot, amp) in enumerate(bands):
        o = slab("rock%d" % i, z - h, z, col, inset_top=i_top, inset_bot=i_bot, r=0.10, segs=3, half=HALF)
        jitter(o, amp, seed)
        parts.append(o)
        z -= h
    # draped moss over the rim: wide irregular leaf curtains, not spikes
    for side in range(4):
        a = math.radians(90 * side)
        tx, ty = -math.sin(a), math.cos(a)
        for j in range(4):
            t = rnd.uniform(-0.45, 0.45)
            px, py = (HALF + 0.003) * math.cos(a) + t * tx, (HALF + 0.003) * math.sin(a) + t * ty
            col = rnd.choice(("leaf_green", "leaf_light", "leaf_green"))
            w = rnd.uniform(0.07, 0.12)
            h = rnd.uniform(0.04, 0.07)
            parts.append(bc.box("moss", (w, 0.014, h), (px, py, -h / 2 - 0.002), col, math.degrees(a) + 90))
            for dx, hh in ((-0.28, 0.6), (0.22, 0.85)):  # uneven tongues hanging lower
                parts.append(bc.box("mosst", (w * 0.3, 0.014, h * hh), (px + dx * w * tx, py + dx * w * ty, -h - h * hh / 2 + 0.002 - 0.01),
                                    col, math.degrees(a) + 90))
    # large hanging masses round the keel (chunky, irregular, a few tinted cool grey)
    for k in range(5):
        a = 2 * math.pi * k / 5 + rnd.uniform(-0.2, 0.2)
        r = rnd.uniform(0.11, 0.16)
        h = rnd.uniform(0.05, 0.08)
        o = bc.cone("mass", rnd.uniform(0.018, 0.026), rnd.uniform(0.050, 0.068), h, (r * math.cos(a), r * math.sin(a), ZB - h / 2 + 0.004),
                    rnd.choice(("stone_dark", "dirt_dark", "stone")), 6, rnd.uniform(0, 60))
        o["no_bevel"] = True
        parts.append(o)
    # the neck: where the keel narrows to the propulsion
    neck = bc.cone("neck", 0.080, 0.130, 0.044, (0, 0, ZB - 0.020), "stone_dark", 10)
    parts.append(neck)
    return parts


def debris(seed):
    """A few drifting rocks near the island's edge (their own part: Godot can bob and turn them slowly): a stone body with a
    moss cap, like the reference's small floating islands."""
    rnd = random.Random(seed)
    out = []
    for k in range(5):
        a = 2 * math.pi * k / 5 + rnd.uniform(-0.3, 0.3)
        r = rnd.uniform(0.55, 0.66)
        z = rnd.uniform(-0.34, -0.22)
        s = rnd.uniform(0.032, 0.046)
        x, y = r * math.cos(a), r * math.sin(a)
        b = bc.blob("drift%d" % k, s, (x, y, z), rnd.choice(("stone", "stone_dark", "dirt_light")), 0, (1.0, 0.9, 0.62))
        b["no_bevel"] = True
        out.append(b)
        out.append(bc.cone("driftcap%d" % k, s * 0.95, s * 0.7, 0.012, (x, y, z + s * 0.62), "leaf_green", 6, rnd.uniform(0, 60)))
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


def plank(tag, x, y, z, w, d, rot=0.0, up=0.20):
    """A small wooden working platform (top surface at z) hung from the rim by two ropes."""
    parts = [bc.box("%s_plank" % tag, (w, d, 0.006), (x, y, z - 0.003), "wood_light", rot)]
    ca, sa = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    for s in (-1, 1):
        px, py = x + s * (w / 2 - 0.005) * ca, y + s * (w / 2 - 0.005) * sa
        parts.append(strut("%s_rope%d" % (tag, s), (px, py, z - 0.004), (px, py, z + up), 0.006, 0.006, "wood_dark", 4))
    return parts


def rune_cuts(tag, cx, cy, cz, r, n, col="ink"):
    """Dark carved rune marks round a ring of radius r at height cz."""
    return [bc.box("%s_rune%d" % (tag, k), (0.0035, 0.012, 0.008),
                   (cx + r * math.cos(2 * math.pi * (k + 0.5) / n), cy + r * math.sin(2 * math.pi * (k + 0.5) / n), cz),
                   col, math.degrees(2 * math.pi * (k + 0.5) / n)) for k in range(n)]


# the three working platforms hang on the cliff walls (the walls are near vertical, so the whole figure shows)
ZP = -0.20
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
    people, arm_groups, arm_anchors = crew("E", (("roof_orange", "cloth", "skin_light", None), ("roof_teal", "brush", "skin_dark", "hair_dark"),
                                                 ("roof_terracotta", "brush", "skin_mid", None)))
    anchors.update(arm_anchors)
    return [("", parts + people, (0, 0, 0), None), ("ring", ring, (0, 0, zc), ""), ("drift", debris(5), (0, 0, ZH - 0.09), "")] + arm_groups, anchors


def variant_f():
    """F ROOT AND SEED: old thick roots grow out of the keel and curl round one big seed pod with a dark crack: the island is
    carried by a living seed. Leaf fins round it turn slowly."""
    parts = rock(22)
    zs = ZH - 0.105
    for k in range(6):
        a = math.radians(60 * k + 12)
        a2 = a + math.radians(26)
        p0 = (0.115 * math.cos(a), 0.115 * math.sin(a), ZH + 0.004)
        p1 = (0.165 * math.cos(a2), 0.165 * math.sin(a2), ZH - 0.045)
        p2 = (0.125 * math.cos(a2 + 0.35), 0.125 * math.sin(a2 + 0.35), zs + 0.010)
        parts.append(strut("root%da" % k, p0, p1, 0.026, 0.020, "wood_dark", 6))
        parts.append(strut("root%db" % k, p1, p2, 0.020, 0.013, "wood_mid", 6))
        parts.append(bc.blob("knot%d" % k, 0.022, p1, "wood_dark", 1))
        parts.append(bc.cone("leaf%d" % k, 0.024, 0.004, 0.040, (p1[0], p1[1], p1[2] + 0.014), "leaf_green", 5, math.degrees(a2)))
    parts.append(bc.blob("seed", 0.095, (0, 0, zs), "wood_light", 2, (1, 1, 0.72)))
    for k in range(8):
        a = 2 * math.pi * k / 8
        parts.append(bc.box("ridge%d" % k, (0.012, 0.014, 0.085), (0.090 * math.cos(a), 0.090 * math.sin(a), zs + 0.002), "wood_mid", math.degrees(a)))
    parts.append(bc.cone("tip", 0.056, 0.036, 0.016, (0, 0, zs - 0.058), "wood_dark", 8))
    parts.append(bc.cone("crack", 0.036, 0.028, 0.010, (0, 0, zs - 0.0665), "ink", 8))
    fins = [bc.cone("fin%d" % k, 0.004, 0.040, 0.066, (0.170 * math.cos(2 * math.pi * k / 6), 0.170 * math.sin(2 * math.pi * k / 6), zs - 0.010),
                    "leaf_yellow", 5, math.degrees(2 * math.pi * k / 6)) for k in range(6)]
    people, arm_groups, anchors = crew("F", (("roof_teal", "hammer", "skin_mid", None), ("roof_orange", "cloth", "skin_light", "hair_blonde"),
                                             ("wall_cream", "brush", "skin_dark", None)))
    anchors["thrust_anchor"] = ((0, 0, zs - 0.0715), "", 0.05)
    return [("", parts + people, (0, 0, 0), None), ("fins", fins, (0, 0, zs), ""), ("drift", debris(6), (0, 0, ZH - 0.09), "")] + arm_groups, anchors


VARIANTS = {"E": variant_e, "F": variant_f}


def build(v, name=NAME):
    groups, anchors = VARIANTS[v]()
    root = bc.assemble(name, groups)
    for aname, (loc, parent, size) in anchors.items():
        bc.anchor(root, aname, loc, parent, size)
    return root


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    v = args[0] if args else "E"
    bc.clear_scene()
    obj = build(v)
    print("BLEND", bc.save_blend(obj, "island_underside_" + v))
