"""W02 Island underside: the floating sky-island rim that hangs under the board (24 x 24 cells = 1.2 m).
Run:
    blender --factory-startup -b -P assets/generators/make_island_underside.py -- A      (variants A-D, saved as island_underside_<V>.blend)

Decided with Siddharth (2026-10-29): "floating island rim like a sky island vibe, a magic propulsion thing visible
(obviously magic, not science) and magic villagers maintaining it, visible". Villagers are tiny static stand-ins
(character kit comes later from Durva). The island hovers over the table at a height the player sets in a
calibration step, so the whole underside stays shallow (it must clear a real table): the model is at most
MAX_DEPTH deep. ORIGIN = the attach plane (the island's base, z = 0); everything hangs DOWN (negative z, -Y in glTF).
The island v01 (12 x 12 cells, stretched x2 in Godot) has a 0.57 m wide base, so the rock starts HALF = 0.57 / 2.
Magic rules: black / orange / red only, never blue; glowing is VFX at `__..._anchor` empties, the model only
provides dark sockets, carved runes and floating stones. Not a machine: no pipes, no metal, no gears.
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
ROCK_DEPTH = 0.24
MAX_DEPTH = 0.36          # everything must hang inside this; the calibrated hover height is at least this plus a gap
NAME = "ew_world_island_underside_v01"


# ---------------------------------------------------------------------------------------------------------- helpers
def strut(name, p0, p1, r0, r1, col, segments=6):
    """A tapered stick from p0 (radius r0) to p1 (radius r1): chains, ropes, roots, ladder rails."""
    p0, p1 = mathutils.Vector(p0), mathutils.Vector(p1)
    d = p1 - p0
    o = bc.cone(name, r0, r1, d.length, (0, 0, 0), col, segments)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = mathutils.Vector((0, 0, 1)).rotation_difference(d.normalized())
    o.location = (p0 + p1) / 2
    bc.apply_transforms(o)
    o["no_bevel"] = True
    return o


def jitter(o, amp, seed, keep_z_below):
    """Rough up a layer: every vertex moves by an amount that depends only on its position, so the rings shared by two
    layers move together and no seams open. Vertices on the attach plane stay; the bottom plane keeps its height."""
    for v in o.data.vertices:
        if v.co.z > -0.001:
            continue
        rnd = random.Random("%s%.4f%.4f%.4f" % (seed, v.co.x, v.co.y, v.co.z))
        v.co.x += rnd.uniform(-amp, amp)
        v.co.y += rnd.uniform(-amp, amp)


def rock(seed, depth=ROCK_DEPTH):
    """The hanging stone body: four tapering rounded layers and a ragged ring of stalactites, saucer-shaped."""
    rnd = random.Random(seed)
    parts = []
    layers = ((0.0, 0.0, 0.08, "stone_dark"), (0.0, 0.08, 0.22, "stone"), (0.0, 0.22, 0.38, "stone"),
              (0.0, 0.38, 0.48, "dirt_light"))
    z = 0.0
    for i, (_, i_top, i_bot, col) in enumerate(layers):
        h = depth * (0.28, 0.3, 0.24, 0.18)[i]
        o = slab("rock%d" % i, z - h, z, col, inset_top=i_top, inset_bot=i_bot, r=0.12, segs=3, half=HALF)
        jitter(o, 0.012, seed, -depth)
        parts.append(o)
        z -= h
    return parts


CONTRAST = {"roof_orange": "wall_cream", "roof_teal": "wall_cream", "roof_terracotta": "wall_cream", "wall_cream": "roof_terracotta"}


def villager(tag, x, y, z, face_deg, cloth, tool, skin="skin_mid", hair=None):
    """A small static stand-in villager (about 4.5 cm so it reads at board scale: round hooded body, arm, a tool);
    z = feet. Durva's character kit replaces these later."""
    k = 3.2
    parts = []
    parts.append(bc.cone("%s_body" % tag, 0.0085 * k, 0.0055 * k, 0.016 * k, (x, y, z + 0.008 * k), cloth, 8))
    parts.append(bc.blob("%s_head" % tag, 0.0068 * k, (x, y, z + 0.0215 * k), skin, 1))
    hood = bc.cone("%s_hood" % tag, 0.0078 * k, 0.0005, 0.011 * k, (x, y, z + 0.0275 * k), hair or CONTRAST.get(cloth, "wall_cream"), 8)
    hood["no_bevel"] = True
    parts.append(hood)
    a = math.radians(face_deg)
    fx, fy = math.cos(a), math.sin(a)
    ax, ay = x + fx * 0.009 * k, y + fy * 0.009 * k
    parts.append(strut("%s_arm" % tag, (x, y, z + 0.0135 * k), (ax, ay, z + 0.017 * k), 0.0024 * k, 0.0020 * k, skin, 5))
    if tool == "brush":    # scrubbing brush on a stick
        parts.append(strut("%s_tool" % tag, (ax, ay, z + 0.004 * k), (ax, ay, z + 0.030 * k), 0.0014 * k, 0.0014 * k, "wood_dark", 4))
        parts.append(bc.box("%s_bristle" % tag, (0.008 * k, 0.004 * k, 0.005 * k), (ax, ay, z + 0.004 * k), "wood_light", face_deg))
    elif tool == "bucket":  # pail
        parts.append(bc.cone("%s_pail" % tag, 0.0065 * k, 0.0085 * k, 0.009 * k, (ax + fx * 0.004 * k, ay + fy * 0.004 * k, z + 0.012 * k), "wood_mid", 8))
    elif tool == "hammer":
        parts.append(strut("%s_tool" % tag, (ax, ay, z + 0.014 * k), (ax + fx * 0.002 * k, ay + fy * 0.002 * k, z + 0.034 * k), 0.0014 * k, 0.0014 * k, "wood_dark", 4))
        parts.append(bc.box("%s_head2" % tag, (0.009 * k, 0.004 * k, 0.004 * k), (ax + fx * 0.002 * k, ay + fy * 0.002 * k, z + 0.034 * k), "stone_dark", face_deg))
    elif tool == "cloth":   # polishing cloth held up
        parts.append(bc.box("%s_cloth" % tag, (0.009 * k, 0.002 * k, 0.009 * k), (ax, ay, z + 0.020 * k), "wall_cream", face_deg + 90))
    return parts


def plank(tag, x, y, z, w, d, rot=0.0, posts=True):
    """A small wooden working platform (top surface at z) hung from the rock by two posts."""
    parts = [bc.box("%s_plank" % tag, (w, d, 0.006), (x, y, z - 0.003), "wood_light", rot)]
    if posts:
        for s in (-1, 1):
            ca, sa = math.cos(math.radians(rot)), math.sin(math.radians(rot))
            px, py = x + s * (w / 2 - 0.004) * ca, y + s * (w / 2 - 0.004) * sa
            parts.append(strut("%s_post%d" % (tag, s), (px, py, z - 0.004), (px, py, z + 0.13), 0.0030, 0.0030, "wood_dark", 4))
    return parts


def rope_ladder(tag, x, y, z_top, z_bot, rot=0.0):
    parts = []
    ca, sa = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    for s in (-1, 1):
        px, py = x + s * 0.007 * ca, y + s * 0.007 * sa
        parts.append(strut("%s_rail%d" % (tag, s), (px, py, z_top), (px, py, z_bot), 0.0016, 0.0016, "wood_dark", 4))
    n = max(2, int((z_top - z_bot) / 0.012))
    for k in range(n):
        zz = z_top - (k + 0.5) * (z_top - z_bot) / n
        parts.append(bc.box("%s_rung%d" % (tag, k), (0.016, 0.0028, 0.0028), (x, y, zz), "wood_light", rot))
    return parts


def rune_cuts(tag, cx, cy, cz, r, n, col="ink"):
    """Dark carved rune marks round a ring of radius r at height cz (flush slots on the outside)."""
    parts = []
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        parts.append(bc.box("%s_rune%d" % (tag, k), (0.0035, 0.012, 0.008), (cx + r * math.cos(a), cy + r * math.sin(a), cz),
                            col, math.degrees(a)))
    return parts


# ---------------------------------------------------------------------------------------------------------- variants
ZP = -0.21        # top of the working planks on the rock flank
ZB = -ROCK_DEPTH   # the rock's bottom plane


def variant_a():
    """A RUNE RING: stone slabs float, unconnected, in a ring round a dark socket under the rock. That is the magic.
    Villagers scrub the runes from hanging planks and a rope ladder."""
    parts = rock(11)
    zc = ZB - 0.052
    parts.append(bc.cone("collar", 0.075, 0.062, 0.020, (0, 0, ZB - 0.010), "stone_dark", 12))
    parts.append(bc.cone("socket", 0.050, 0.044, 0.008, (0, 0, ZB - 0.024), "ink", 12))
    parts += rune_cuts("collar", 0, 0, ZB - 0.010, 0.074, 8, "ink")
    ring = []
    for k in range(8):
        a = 2 * math.pi * k / 8
        x, y = 0.165 * math.cos(a), 0.165 * math.sin(a)
        zz = zc + 0.005 * (-1) ** k
        st = bc.blob("rstone%d" % k, 0.03, (x, y, zz), "stone", 0, (0.8, 0.55, 1.35))
        st.rotation_euler = (0, 0, a)
        bc.apply_transforms(st)
        st["no_bevel"] = True
        ring.append(st)
        ring.append(bc.box("rrune%d" % k, (0.004, 0.020, 0.030), (x + 0.0185 * math.cos(a), y + 0.0185 * math.sin(a), zz), "ink", math.degrees(a)))
    parts += plank("pA", 0.46, -0.10, ZP, 0.14, 0.075, 90)
    parts += villager("vA1", 0.46, -0.10, ZP, 180, "roof_orange", "cloth", "skin_light")
    parts += plank("pB", 0.10, -0.46, ZP, 0.14, 0.075, 0)
    parts += villager("vA2", 0.10, -0.46, ZP, 90, "roof_teal", "brush", "skin_dark", "hair_dark")
    parts += plank("pC", -0.20, -0.46, ZP, 0.14, 0.075, 0)
    parts += villager("vA3", -0.20, -0.46, ZP, 90, "roof_terracotta", "brush", "skin_mid")
    anchors = {"thrust_anchor": ((0, 0, ZB - 0.030), "", 0.04)}
    for k in range(8):
        a = 2 * math.pi * k / 8
        anchors["rune_anchor_%d" % (k + 1)] = ((0.165 * math.cos(a), 0.165 * math.sin(a), zc), "ring", 0.02)
    return [("", parts, (0, 0, 0), None), ("ring", ring, (0, 0, zc), "")], anchors


def variant_c():
    """C ROOT AND SEED: old roots grow down out of the island and cradle one big hanging seed pod with a dark crack: the
    island is carried by a living seed. Leaf fins round it turn slowly. Villagers prune and tie the roots."""
    parts = rock(13)
    rnd = random.Random(31)
    zs = ZB - 0.045
    for k in range(6):
        a = math.radians(60 * k + 12)
        p0 = (0.33 * math.cos(a), 0.33 * math.sin(a), -0.10)
        a2 = a + math.radians(18)
        p1 = (0.20 * math.cos(a2), 0.20 * math.sin(a2), -0.21)
        p2 = (0.066 * math.cos(a2 + 0.3), 0.066 * math.sin(a2 + 0.3), ZB - 0.040)
        parts.append(strut("root%da" % k, p0, p1, 0.020, 0.014, "wood_dark", 6))
        parts.append(strut("root%db" % k, p1, p2, 0.014, 0.009, "wood_mid", 6))
        parts.append(bc.blob("knot%d" % k, 0.016, p1, "wood_dark", 1))
    for k in range(6):  # leaves on the knots
        a = math.radians(60 * k + 12 + 18)
        parts.append(bc.cone("leaf%d" % k, 0.020, 0.003, 0.034, (0.20 * math.cos(a), 0.20 * math.sin(a), -0.185), "leaf_green", 5, math.degrees(a)))
    parts.append(bc.blob("seed", 0.066, (0, 0, zs), "wood_light", 2, (1, 1, 0.72)))
    for k in range(8):
        a = 2 * math.pi * k / 8
        parts.append(bc.box("ridge%d" % k, (0.009, 0.011, 0.060), (0.062 * math.cos(a), 0.062 * math.sin(a), zs + 0.002), "wood_mid", math.degrees(a)))
    parts.append(bc.cone("tip", 0.040, 0.026, 0.012, (0, 0, zs - 0.040), "wood_dark", 8))
    parts.append(bc.cone("crack", 0.026, 0.020, 0.008, (0, 0, zs - 0.0456), "ink", 8))
    fins = []
    for k in range(6):
        a = 2 * math.pi * k / 6
        fins.append(bc.cone("fin%d" % k, 0.003, 0.030, 0.050, (0.120 * math.cos(a), 0.120 * math.sin(a), zs - 0.004), "leaf_yellow", 5, math.degrees(a)))
    parts += plank("pA", 0.46, 0.08, ZP, 0.14, 0.075, 90)
    parts += villager("vC1", 0.46, 0.08, ZP, 180, "roof_teal", "hammer", "skin_mid")
    parts += plank("pB", 0.10, -0.46, ZP, 0.14, 0.075, 0)
    parts += villager("vC2", 0.10, -0.46, ZP, 90, "roof_orange", "cloth", "skin_light", "hair_blonde")
    parts += plank("pC", -0.20, -0.46, ZP, 0.14, 0.075, 0)
    parts += villager("vC3", -0.20, -0.46, ZP, 90, "wall_cream", "brush", "skin_dark")
    anchors = {"thrust_anchor": ((0, 0, zs - 0.0496), "", 0.036)}
    return [("", parts, (0, 0, 0), None), ("fins", fins, (0, 0, zs), "")], anchors


def variant_d():
    """D BELL AND SIGIL: an inverted bell hangs from the rock on chains; below its mouth a stone sigil disc floats, carved
    with a star and ringed by charms, slowly turning. Villagers polish the bell and ring a small one."""
    parts = rock(16)
    zb = ZB
    for k in range(4):
        a = math.radians(45 + 90 * k)
        parts.append(strut("chain%d" % k, (0.17 * math.cos(a), 0.17 * math.sin(a), -0.17),
                           (0.050 * math.cos(a), 0.050 * math.sin(a), zb - 0.028), 0.0035, 0.0035, "stone_dark", 4))
    parts.append(bc.cone("crown", 0.028, 0.044, 0.008, (0, 0, zb - 0.030), "stone_dark", 10))
    parts.append(bc.cone("bell", 0.078, 0.046, 0.036, (0, 0, zb - 0.052), "wood_light", 10))
    parts.append(bc.cone("belband", 0.084, 0.080, 0.007, (0, 0, zb - 0.0735), "roof_terracotta", 10))
    parts.append(bc.cone("mouth", 0.072, 0.070, 0.004, (0, 0, zb - 0.0790), "ink", 10))
    parts += rune_cuts("bell", 0, 0, zb - 0.052, 0.061, 8, "ink")
    zsig = zb - 0.082
    sig = [bc.cone("disc", 0.130, 0.130, 0.008, (0, 0, zsig), "stone_dark", 16),
           bc.cone("discin", 0.104, 0.104, 0.004, (0, 0, zsig + 0.0055), "stone", 16)]
    for k in range(6):
        a = 2 * math.pi * k / 6
        sig.append(bc.box("pt%d" % k, (0.044, 0.011, 0.004), (0.054 * math.cos(a), 0.054 * math.sin(a), zsig + 0.0085), "ink", math.degrees(a)))
        sig.append(bc.cone("charm%d" % k, 0.007, 0.003, 0.013, (0.123 * math.cos(a), 0.123 * math.sin(a), zsig - 0.010), "roof_orange", 4, 45))
    parts += plank("pA", 0.46, -0.10, ZP, 0.14, 0.075, 90)
    parts += villager("vD1", 0.46, -0.10, ZP, 180, "roof_orange", "cloth", "skin_light")
    parts += plank("pB", 0.10, -0.46, ZP, 0.14, 0.075, 0)
    parts += villager("vD2", 0.10, -0.46, ZP, 90, "roof_teal", "hammer", "skin_dark", "hair_dark")
    parts += plank("pC", -0.20, -0.46, ZP, 0.14, 0.075, 0)
    parts += villager("vD3", -0.20, -0.46, ZP, 90, "wall_cream", "brush", "skin_mid", "hair_brown")
    anchors = {"thrust_anchor": ((0, 0, zsig + 0.008), "sigil", 0.045)}
    for k in range(6):
        a = 2 * math.pi * k / 6
        anchors["rune_anchor_%d" % (k + 1)] = ((0.054 * math.cos(a), 0.054 * math.sin(a), zsig + 0.010), "sigil", 0.012)
    return [("", parts, (0, 0, 0), None), ("sigil", sig, (0, 0, zsig), "")], anchors


VARIANTS = {"A": variant_a, "C": variant_c, "D": variant_d}


def build(v, name=NAME):
    groups, anchors = VARIANTS[v]()
    root = bc.assemble(name, groups)
    for aname, (loc, parent, size) in anchors.items():
        bc.anchor(root, aname, loc, parent, size)
    return root


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    v = args[0] if args else "A"
    bc.clear_scene()
    obj = build(v)
    print("BLEND", bc.save_blend(obj, "island_underside_" + v))
