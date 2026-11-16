"""House bell for the quest "Ring the bell" (pinch the rope, pull it 3 times to call supper).
A small bell on a wooden bracket that mounts on a house wall. The wall plane is y = 0; the bracket reaches out toward
-Y (the front). Moving parts (bc.assemble): __bell swings (pivot = the hang point under the bracket), __rope is
pulled (pivot = its top, at the bell's clapper). Lowest point of the whole model = z 0 (the wall plate's bottom).
    blender --factory-startup -b -P assets/generators/make_house_bell.py -- A   (A-D)
No glow in the model (a ring effect / sound is added in Godot at the __ring_anchor empty)."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import quest_kit as qk
from quest_kit import box, cyl, nb, lump, spike, rod

ZH = 0.0600     # hang point (underside of the bracket)
YH = -0.0150    # hang point distance from the wall
RIM = ZH - 0.0203


def bell_parts(col, cx=0.0, cy=YH, zrim=RIM, s=1.0, band=None):
    """Bell built around its vertical axis in world coordinates, rim at zrim, top knob at zrim + 0.0203*s."""
    p = [nb(cyl("lip", 0.0105 * s, 0.0018 * s, (cx, cy, zrim), col, 8)),
         nb(cyl("bell", 0.0092 * s, 0.0120 * s, (cx, cy, zrim + 0.0018 * s), col, 8, 0.0052 * s)),
         nb(cyl("shoulder", 0.0052 * s, 0.0045 * s, (cx, cy, zrim + 0.0138 * s), col, 8, 0.0030 * s)),
         nb(cyl("knob", 0.0022 * s, 0.0020 * s, (cx, cy, zrim + 0.0183 * s), col, 6)),
         lump(0.0026 * s, (cx, cy, zrim - 0.0012 * s), "stone_dark")]
    if band:
        p.append(nb(cyl("band", 0.0086 * s, 0.0016 * s, (cx, cy, zrim + 0.0070 * s), band, 8, 0.0078 * s)))
    return p


def rope_parts(top_z, bottom_z, handle, cy=YH, cx=0.0):
    """Rope from top_z down to the handle at bottom_z (+ handle height). Pivot = (cx, cy, top_z)."""
    p = [rod((cx, cy, top_z), (cx, cy, bottom_z + 0.0062), 0.0024, "path_dirt"),
         lump(0.0026, (cx, cy, top_z - 0.0100), "path_dirt", (1, 1, 0.7)),
         lump(0.0026, (cx, cy, top_z - 0.0200), "path_dirt", (1, 1, 0.7))]
    if handle == "toggle":
        p.append(nb(cyl("toggle", 0.0030, 0.0070, (cx, cy, bottom_z), "wood_light", 6)))
    elif handle == "ball":
        p.append(lump(0.0042, (cx, cy, bottom_z + 0.0040), "wood_light", (1, 1, 1.1)))
    elif handle == "ring":
        p.append(nb(cyl("ring", 0.0040, 0.0020, (cx, cy, bottom_z + 0.0010), "stone_dark", 8)))
        p.append(nb(cyl("ring_hole", 0.0024, 0.0022, (cx, cy, bottom_z + 0.0010), "wood_dark", 8)))
        p.append(nb(cyl("grip", 0.0034, 0.0050, (cx, cy, bottom_z + 0.0030), "wood_light", 6)))
    return p


def plate(h=0.0700, w=0.0200, col="wood_mid"):
    return [box("plate", (w, 0.0040, h), (0, -0.0020, h / 2), col)]


def variant_A():   # classic: wood plate, L bracket with a diagonal brace, brass bell, toggle rope
    root = plate() + [box("arm", (0.0038, 0.0215, 0.0040), (0, -0.0107, ZH + 0.0020), "wood_light"),
                      rod((0, -0.0030, 0.0470), (0, -0.0168, ZH + 0.0004), 0.0034, "wood_light"),
                      nb(cyl("cap", 0.0034, 0.0010, (0, YH - 0.0010, ZH + 0.0040), "wood_dark", 6))]
    bell = bell_parts("shell_gold", zrim=ZH - 0.0203 * 1.3, s=1.3)
    rope = rope_parts(ZH - 0.0203 * 1.3 - 0.0035, 0.0090, "toggle")
    return root, bell, rope


def variant_B():   # bell-cote: a tiny gabled roof on two posts over the bell
    root = plate(0.0760, 0.0300) + [
        box("beam", (0.0290, 0.0036, 0.0036), (0, YH, ZH + 0.0018), "wood_dark"),
        nb(bc_gable()),
        box("post", (0.0036, 0.0036, 0.0670), (-0.0128, -0.0070, 0.0335), "wood_dark"),
        box("post", (0.0036, 0.0036, 0.0670), (0.0128, -0.0070, 0.0335), "wood_dark")]
    for sx in (-1, 1):   # ties from the posts to the wall
        root.append(box("tie", (0.0030, 0.0140, 0.0030), (sx * 0.0128, -0.0070, 0.0400), "wood_dark"))
    bell = bell_parts("shell_gold", zrim=ZH - 0.0203 * 1.15, s=1.15, band="roof_terracotta")
    rope = rope_parts(ZH - 0.0203 * 1.15 - 0.0035, 0.0090, "ball")
    return root, bell, rope


def bc_gable():
    return qk.bc.gable("roof", 0.0340, 0.0300, 0.0095, (0, -0.0120, ZH + 0.0036), "roof_terracotta")


def variant_C():   # ship's bell: squat round copper bell on an iron hook-shaped bracket, ring handle
    root = plate(0.0700, 0.0160, "wood_mid")
    # curved iron arm: out, up and over (a shepherd's hook) built from rods
    pts = [(0, -0.0020, 0.0420), (0, -0.0055, 0.0520), (0, -0.0100, 0.0580), (0, -0.0150, 0.0600)]
    for a, b in zip(pts, pts[1:]):
        root.append(rod(a, b, 0.0042, "stone_dark"))
    root.append(lump(0.0036, (0, -0.0158, 0.0594), "stone_dark"))
    root.append(nb(cyl("flange", 0.0070, 0.0014, (0, -0.0008, 0.0420), "stone_dark", 6)))
    k = 1.35
    r0 = ZH - 0.0176 * k   # rim height so the knob touches the hook
    p = [nb(cyl("lip", 0.0100 * k, 0.0016 * k, (0, YH, r0 + 0.0030 * k), "shell_copper", 8)),
         nb(cyl("bell", 0.0090 * k, 0.0070 * k, (0, YH, r0 + 0.0046 * k), "shell_copper", 8, 0.0070 * k)),
         nb(cyl("dome", 0.0070 * k, 0.0040 * k, (0, YH, r0 + 0.0116 * k), "shell_copper", 8, 0.0036 * k)),
         nb(cyl("knob", 0.0020 * k, 0.0020 * k, (0, YH, r0 + 0.0156 * k), "stone_dark", 6)),
         lump(0.0026 * k, (0, YH, r0 + 0.0018 * k), "stone_dark"),
         nb(cyl("belt", 0.0092 * k, 0.0014 * k, (0, YH, r0 + 0.0070 * k), "shell_gold", 8, 0.0088 * k)),
         nb(cyl("skirt", 0.0104 * k, 0.0014 * k, (0, YH, r0 + 0.0014 * k), "shell_gold", 8, 0.0100 * k))]
    bell = p
    rope = rope_parts(r0 + 0.0030 * k - 0.0030, 0.0100, "ring")
    return root, bell, rope


def variant_D():   # yoke bell: headstock beam + rope wheel on the bell, two uprights on the wall plate
    root = plate(0.0700, 0.0300, "wood_light")
    for sx in (-1, 1):
        root.append(box("upright", (0.0034, 0.0034, 0.0200), (sx * 0.0120, -0.0138, 0.0500), "wood_dark"))
        root.append(box("brace", (0.0034, 0.0140, 0.0034), (sx * 0.0120, -0.0070, 0.0560), "wood_dark"))
    root.append(box("bar", (0.0280, 0.0034, 0.0034), (0, -0.0138, 0.0606), "wood_dark"))
    zh = 0.0606
    zrim = zh - 0.0203 * 1.3
    bell = bell_parts("shell_gold", cy=-0.0138, zrim=zrim, s=1.3, band="wall_cream")
    # wheel (disc turning about X) on the bell's crown, rope runs from its rim
    wheel = qk_tcyl_x(0.0072, 0.0030, (0.0, -0.0138, zh - 0.0005), "wood_light")
    bell.append(wheel)
    bell.append(box("yoke", (0.0250, 0.0030, 0.0030), (0, -0.0138, zh - 0.0005), "wood_dark"))
    rope = rope_parts(zrim - 0.0010, 0.0090, "toggle", cy=-0.0138 - 0.0072)
    return root, bell, rope, (0, -0.0138, zh)


def qk_tcyl_x(r, h, loc, col):
    return nb(qk.tcyl("wheel", r, h, loc, col, 8, 0, 90, 0))


VARIANTS = {"A": variant_A, "B": variant_B, "C": variant_C, "D": variant_D}

if __name__ == "__main__":
    qk.bc.clear_scene()
    L = qk.letter_arg()
    res = VARIANTS[L]()
    root, bell, rope = res[:3]
    hang = res[3] if len(res) > 3 else (0.0, YH, ZH)
    # rope pivot = top of the rope = its highest vertex
    zs = [v.co.z for o in rope for v in o.data.vertices]
    ry = rope[0].data.vertices[0].co.y
    groups = [("", root, (0, 0, 0), None), ("bell", bell, hang, ""), ("rope", rope, (0.0, ry, max(zs) - 0.0004), "")]
    r = qk.finish(L, "house_bell", groups, "1x1", "wall_side")
