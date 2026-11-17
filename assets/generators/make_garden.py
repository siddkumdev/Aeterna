"""Garden patch + weed for the quest "Weed the garden" (pinch and pull 4 weeds out of the patch).
Root = the vegetable patch (about 2 x 2 cells), child __weed = ONE weed with a visible root clump (pickable; in the
final it becomes its own object, here it stands beside the patch so the sheet shows both).
    blender --factory-startup -b -P assets/generators/make_garden.py -- A   (A-D)
Front is -Y. Palette names only."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import quest_kit as qk
from quest_kit import box, cyl, nb, lump, spike, rod

WEED_AT = (0.060, -0.030)


# ----------------------------------------------------------------- vegetables
def cabbage(x, y, z, r=0.0084, big="leaf_green", top="leaf_light"):
    return [lump(r, (x, y, z + r * 0.75), big, (1, 1, 0.85)), lump(r * 0.62, (x, y, z + r * 1.25), top, (1, 1, 0.8))]


def carrot(x, y, z):
    p = [nb(cyl("carrot", 0.0034, 0.0030, (x, y, z), "roof_orange", 5, 0.0022))]
    for a in (0, 150, 250):
        r = math.radians(a)
        p.append(spike((x, y, z + 0.002), (x + 0.0040 * math.cos(r), y + 0.0040 * math.sin(r), z + 0.0105), 0.0016, "leaf_green", 4))
    return p


def pumpkin(x, y, z, r=0.0085):
    return [lump(r, (x, y, z + r * 0.8), "roof_orange", (1.1, 1.1, 0.8)), nb(cyl("stem", 0.0012, 0.0028, (x, y, z + r * 1.45), "leaf_green", 4, 0.0008))]


def tomato_stake(x, y, z, h=0.020):
    p = [rod((x, y, z), (x, y, z + h), 0.0018, "wood_dark")]
    for k, zz in enumerate((0.007, 0.012, 0.016)):
        p.append(lump(0.0030, (x + (0.0032 if k % 2 else -0.0032), y - 0.0020, z + zz), "fire_red"))
        p.append(spike((x, y, z + zz - 0.001), (x + (0.0055 if k % 2 else -0.0055), y, z + zz + 0.0035), 0.0020, "leaf_green", 4))
    return p


def lettuce(x, y, z):
    return [nb(cyl("lettuce", 0.0062, 0.0036, (x, y, z), "leaf_light", 6, 0.0048)), nb(cyl("lettuce", 0.0038, 0.0030, (x, y, z + 0.0036), "wall_cream", 6, 0.0016))]


def ridge(y, x0=-0.034, x1=0.034, z=0.0, w=0.0120, h=0.0040, col="dirt_light"):
    return nb(box("ridge", (x1 - x0, w, h), ((x0 + x1) / 2, y, z + h / 2), col))


# ----------------------------------------------------------------- weeds (each built around WEED_AT, base z = 0)
def roots(wx, wy, crown=0.0100, n=4):
    """Visible root clump: a soil lump with pale roots hanging down (bottoms at z 0)."""
    p = [lump(0.0050, (wx, wy, crown - 0.0020), "dirt_dark", (1, 1, 0.9))]
    for k in range(n):
        a = math.radians(k * 360 / n + 20)
        p.append(spike((wx + 0.0020 * math.cos(a), wy + 0.0020 * math.sin(a), crown - 0.0030),
                       (wx + 0.0048 * math.cos(a), wy + 0.0048 * math.sin(a), 0.0), 0.0016, "path_stone", 4))
    return p


def weed_A(wx, wy):   # dandelion: jagged rosette + yellow puff on a stalk
    p = roots(wx, wy)
    for k in range(7):
        a = math.radians(k * 360 / 7)
        p.append(spike((wx, wy, 0.0102), (wx + 0.0105 * math.cos(a), wy + 0.0105 * math.sin(a), 0.0150), 0.0022, "leaf_dark", 4))
    p.append(rod((wx, wy, 0.0105), (wx + 0.0010, wy, 0.0230), 0.0016, "leaf_green"))
    p.append(lump(0.0042, (wx + 0.0010, wy, 0.0245), "flower_yellow"))
    return p


def weed_B(wx, wy):   # thistle: upright spiky leaves + a pink bristle head
    p = roots(wx, wy, n=5)
    for k in range(5):
        a = math.radians(k * 72 + 10)
        p.append(spike((wx, wy, 0.0105), (wx + 0.0070 * math.cos(a), wy + 0.0070 * math.sin(a), 0.0210), 0.0024, "leaf_dark", 4))
    p.append(rod((wx, wy, 0.0105), (wx, wy, 0.0215), 0.0018, "leaf_green"))
    p.append(nb(cyl("thistle_cup", 0.0030, 0.0020, (wx, wy, 0.0212), "leaf_green", 6, 0.0044)))
    p.append(lump(0.0036, (wx, wy, 0.0255), "flower_pink", (1, 1, 0.9)))
    return p


def weed_C(wx, wy):   # grass tuft: many thin tall blades, seed head
    p = roots(wx, wy, n=4)
    for k in range(10):
        a = math.radians(k * 36)
        h = 0.0215 + 0.004 * (k % 3)
        rr = 0.0030 + 0.0020 * (k % 2)
        p.append(spike((wx, wy, 0.0100), (wx + rr * math.cos(a) * 1.8, wy + rr * math.sin(a) * 1.8, h), 0.0018, "leaf_dark" if k % 2 else "leaf_green", 4))
    p.append(lump(0.0030, (wx + 0.0030, wy, 0.0280), "leaf_yellow", (0.8, 0.8, 1.5)))
    return p


def weed_D(wx, wy):   # broadleaf: round dark leaves on stalks, tiny cream flower
    p = roots(wx, wy, n=4)
    for k in range(5):
        a = math.radians(k * 72 + 30)
        lx, ly, lz = wx + 0.0065 * math.cos(a), wy + 0.0065 * math.sin(a), 0.0150 + 0.0020 * (k % 2)
        p.append(rod((wx, wy, 0.0105), (lx, ly, lz), 0.0014, "leaf_green"))
        p.append(nb(cyl("leaf", 0.0042, 0.0014, (lx, ly, lz), "leaf_dark" if k % 2 else "leaf_green", 5, 0.0030)))
    p.append(rod((wx, wy, 0.0105), (wx, wy, 0.0230), 0.0014, "leaf_green"))
    p.append(nb(cyl("blossom", 0.0030, 0.0016, (wx, wy, 0.0230), "wall_cream", 6, 0.0018)))
    return p


def weed_V2(wx, wy):   # 2026-11-18 (fix F): scraggly rosette of chunky dark-green and yellow-brown blades, 3 crooked stalks with dandelion heads (critic: no hair-thin parts)
    p = roots(wx, wy, crown=0.0110, n=5)
    cols = ["leaf_dark", "leaf_yellow", "leaf_dark", "path_dirt", "leaf_dark", "leaf_yellow", "leaf_dark"]
    for k, c in enumerate(cols):   # 7 ragged blades, uneven lengths and heights, splayed wide
        a = math.radians(k * 51 + 14 * (k % 3))
        r = 0.0085 + 0.0040 * (k % 3)
        p.append(spike((wx, wy, 0.0112), (wx + r * math.cos(a), wy + r * math.sin(a), 0.0125 + 0.0055 * (k % 3)), 0.0034, c, 4))
    for (ax, ay, h, kind) in ((-0.0100, 0.0030, 0.0290, "yellow"), (0.0095, -0.0050, 0.0350, "seed"), (0.0010, 0.0100, 0.0230, "bud")):
        top = (wx + ax, wy + ay, h)
        mid = (wx + ax * 0.35 + 0.0020, wy + ay * 0.35, h * 0.55)   # a kink in the stalk
        p.append(rod((wx, wy, 0.0112), mid, 0.0020, "leaf_dark"))
        p.append(rod(mid, top, 0.0020, "leaf_dark"))
        if kind == "yellow":
            p.append(lump(0.0070, (top[0], top[1], top[2] + 0.0020), "fire_yellow", (1, 1, 0.85)))
            p.append(lump(0.0036, (top[0], top[1], top[2] + 0.0050), "flower_yellow"))
        elif kind == "seed":
            p.append(lump(0.0066, (top[0], top[1], top[2] + 0.0020), "wall_cream"))
            p.append(lump(0.0034, (top[0] + 0.0016, top[1], top[2] + 0.0050), "bone"))
        else:
            p.append(lump(0.0034, (top[0], top[1], top[2] + 0.0010), "wood_dark", (1, 1, 1.3)))
    return p


# ----------------------------------------------------------------- patches
def patch_A():   # raised wooden bed: cabbages, carrots, tomato stakes
    p = [box("plank", (0.0920, 0.0060, 0.0120), (0, -0.0430, 0.0060), "wood_light"),
         box("plank", (0.0920, 0.0060, 0.0120), (0, 0.0430, 0.0060), "wood_light"),
         box("plank", (0.0060, 0.0800, 0.0120), (-0.0430, 0, 0.0060), "wood_light"),
         box("plank", (0.0060, 0.0800, 0.0120), (0.0430, 0, 0.0060), "wood_light"),
         nb(box("soil", (0.0800, 0.0800, 0.0100), (0, 0, 0.0050), "dirt_dark"))]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(nb(box("post", (0.0072, 0.0072, 0.0150), (sx * 0.0430, sy * 0.0430, 0.0075), "wood_dark")))
    for y in (-0.025, 0.0, 0.025):
        p.append(ridge(y, -0.034, 0.034, 0.0100, 0.0120, 0.0034))
    for x in (-0.025, 0.0, 0.025):
        p += cabbage(x, -0.025, 0.0134)
    for x in (-0.027, -0.009, 0.009, 0.027):
        p += carrot(x, 0.0, 0.0134)
    p += tomato_stake(-0.020, 0.025, 0.0134) + tomato_stake(0.020, 0.025, 0.0134)
    return p


def patch_B():   # open furrows, no frame: four mounded rows of different crops + pumpkins
    p = [nb(box("tilled", (0.0900, 0.0900, 0.0030), (0, 0, 0.0015), "dirt_dark"))]
    for y in (-0.030, -0.010, 0.010, 0.030):
        p.append(nb(box("row", (0.0780, 0.0100, 0.0050), (0, y, 0.0030 + 0.0025), "dirt_light")))
        p.append(nb(box("row_top", (0.0780, 0.0060, 0.0016), (0, y, 0.0080 + 0.0008), "dirt_light")))
    for x in (-0.026, 0.0, 0.026):
        p += cabbage(x, -0.030, 0.0096, 0.0076, "leaf_light", "wall_cream")
    for x in (-0.030, -0.010, 0.010, 0.030):
        p += lettuce(x, -0.010, 0.0096)
    for x in (-0.027, -0.009, 0.009, 0.027):
        p += carrot(x, 0.010, 0.0096)
    p += pumpkin(-0.018, 0.030, 0.0096) + pumpkin(0.020, 0.032, 0.0096, 0.0058)
    for sx in (-1, 1):   # row-end stakes with a string marker
        p.append(rod((sx * 0.0430, -0.0430, 0.0030), (sx * 0.0430, -0.0430, 0.0200), 0.0020, "wood_light"))
    p.append(rod((-0.0430, -0.0430, 0.0180), (0.0430, -0.0430, 0.0180), 0.0010, "path_dirt"))
    return p


def patch_C():   # cottage garden: low picket fence on three sides, bean teepee, sunflower, flowers
    p = [nb(box("soil", (0.0900, 0.0900, 0.0050), (0, 0, 0.0025), "dirt_dark"))]
    for sx in (-1, 1):   # side fences
        p.append(box("rail", (0.0030, 0.0900, 0.0036), (sx * 0.0440, 0, 0.0100), "wood_mid"))
    p.append(box("rail", (0.0900, 0.0030, 0.0036), (0, 0.0440, 0.0100), "wood_mid"))
    for i in range(7):
        x = -0.0440 + i * 0.0147
        p.append(nb(box("picket", (0.0040, 0.0030, 0.0150), (x, 0.0440, 0.0075), "wood_light")))
    for sx in (-1, 1):
        for j in range(5):
            p.append(nb(box("picket", (0.0030, 0.0040, 0.0150), (sx * 0.0440, -0.0400 + j * 0.0200, 0.0075), "wood_light")))
    for sx in (-1, 1):   # front corner posts, gap between = the gate
        p.append(nb(box("post", (0.0060, 0.0060, 0.0190), (sx * 0.0440, -0.0440, 0.0095), "wood_dark")))
    # bean teepee
    for a in (0, 120, 240):
        r = math.radians(a)
        p.append(rod((0.0200 * math.cos(r) - 0.020, 0.0200 * math.sin(r) + 0.012, 0.005), (-0.020, 0.012, 0.0300), 0.0018, "wood_light"))
    for (dx, dy, dz) in ((0.008, -0.002, 0.012), (-0.006, 0.006, 0.018), (0.002, 0.008, 0.024), (-0.007, -0.006, 0.022)):
        p.append(lump(0.0036, (-0.020 + dx * 0.9, 0.012 + dy * 0.9, 0.005 + dz), "leaf_green", (1, 1, 1.2)))
    # sunflower
    p.append(rod((0.025, 0.025, 0.005), (0.025, 0.025, 0.0300), 0.0022, "leaf_green"))
    p.append(nb(cyl("petals", 0.0070, 0.0018, (0.025, 0.0235, 0.0290), "flower_yellow", 8, 0.0070, 0)))
    p.append(nb(cyl("seeds", 0.0036, 0.0022, (0.025, 0.0215, 0.0292), "wood_dark", 6)))
    # pumpkins and flowers
    p += pumpkin(0.022, -0.022, 0.005) + pumpkin(-0.002, -0.026, 0.005, 0.0056)
    for (x, y, col) in ((-0.030, -0.020, "flower_pink"), (-0.020, -0.034, "flower_yellow"), (0.002, 0.026, "flower_pink"), (-0.008, 0.004, "wall_cream")):
        p.append(rod((x, y, 0.005), (x, y, 0.0140), 0.0014, "leaf_green"))
        p.append(nb(cyl("flower", 0.0036, 0.0020, (x, y, 0.0138), col, 5, 0.0024)))
    return p


def patch_D():   # round bed ringed with stones: wedge crops around a centre marker stake
    p = [nb(cyl("soil", 0.0400, 0.0070, (0, 0, 0.0), "dirt_dark", 8))]
    for k in range(8):
        a = math.radians(k * 45)
        p.append(nb(box("stone", (0.0125, 0.0080, 0.0095), (0.0425 * math.cos(a), 0.0425 * math.sin(a), 0.0048), "stone_dark" if k % 3 == 0 else "path_stone", k * 45 + 90)))
    p.append(rod((0, 0, 0.0070), (0, 0, 0.0300), 0.0022, "wood_dark"))
    p.append(box("flag", (0.0100, 0.0016, 0.0070), (0.0050, 0, 0.0262), "cloth_mustard"))
    for a, kind in ((45, "cab"), (135, "car"), (225, "let"), (315, "pum")):
        r = math.radians(a)
        for rad, das in ((0.0290, (-17, 17)), (0.0170, (0,))):
            for da in (das if not (kind == "pum" and rad < 0.02) else ()):
                x, y = rad * math.cos(r + math.radians(da)), rad * math.sin(r + math.radians(da))
                if kind == "cab":
                    p += cabbage(x, y, 0.0070, 0.0066)
                elif kind == "car":
                    p += carrot(x, y, 0.0070)
                elif kind == "let":
                    p += lettuce(x, y, 0.0070)
                else:
                    p += pumpkin(x, y, 0.0070, 0.0060)
    return p


VARIANTS = {"A": (patch_A, weed_A), "B": (patch_B, weed_B), "C": (patch_C, weed_C), "D": (patch_D, weed_D)}

WEED_SCALE = 1.6   # variant A weed 25 mm tall -> 40 mm: a pinchable handle next to the 100 mm bed


def grow(parts, k):
    for o in parts:
        for v in o.data.vertices:
            v.co *= k
    qk.bpy.context.view_layer.update()   # refresh .dimensions for the bevel decision
    return parts


def build_final():
    """Variant A. Two exports: ew_village_garden_v01 (raised bed, 2 x 2 cells, origin at its centre) and ew_village_garden_weed_v01
    (one dandelion weed with root clump, origin at the base centre; Godot spawns several in the bed). garden.blend = bed root +
    __weed part standing beside it, PREVIEW ONLY, not exported."""
    bc = qk.bc
    bc.clear_scene()
    bed = bc.assemble("ew_village_garden_v01", [("", patch_A(), (0, 0, 0), None)])
    bed["ew_footprint"], bed["ew_front"], bed["ew_place"] = "2x2", "-Y", "field_edge"
    bc.save_blend(bed, "garden_bed")
    print("EXPORT", bc.export_glb(bed, "village"), qk.tris(bed), "tris", ["%.1f" % (d * 1000) for d in bed.dimensions])
    bc.clear_scene()
    wd = bc.assemble("ew_village_garden_weed_v01", [("", grow(weed_A(0.0, 0.0), WEED_SCALE), (0, 0, 0), None)], bevel_min=0.0015)
    wd["ew_footprint"], wd["ew_front"], wd["ew_place"] = "1x1", "-Y", "free"
    bc.save_blend(wd, "garden_weed")
    print("EXPORT", bc.export_glb(wd, "village"), qk.tris(wd), "tris", ["%.1f" % (d * 1000) for d in wd.dimensions])
    bc.clear_scene()
    wx = 0.075
    root = bc.assemble("ew_village_garden_v01", [("", patch_A(), (0, 0, 0), None), ("weed", [o for o in move_x(grow(weed_A(0.0, 0.0), WEED_SCALE), wx)], (wx, 0, 0), "")])
    root["ew_footprint"], root["ew_front"], root["ew_place"] = "2x2", "-Y", "field_edge"
    print("PREVIEW", bc.save_blend(root, "garden"), sum(qk.tris(o) for o in [root] + list(root.children)))


def move_x(parts, dx):
    for o in parts:
        for v in o.data.vertices:
            v.co.x += dx
    return parts


if __name__ == "__main__" and "V02" in sys.argv:   # new weed only: ew_village_garden_weed_v02
    qk.bc.clear_scene()
    wd = qk.bc.assemble("ew_village_garden_weed_v02", [("", grow(weed_V2(0.0, 0.0), 1.3), (0, 0, 0), None)], bevel_min=0.0015)
    wd["ew_footprint"], wd["ew_front"], wd["ew_place"] = "1x1", "-Y", "free"
    qk.bc.save_blend(wd, "garden_weed_v02")
    print("EXPORT", qk.bc.export_glb(wd, "village"), qk.tris(wd), "tris", ["%.1f" % (d * 1000) for d in wd.dimensions])
    sys.exit(0)

if __name__ == "__main__" and "FINAL" in sys.argv:
    build_final()
    sys.exit(0)

if __name__ == "__main__":
    qk.bc.clear_scene()
    L = qk.letter_arg()
    patch, weed = VARIANTS[L]
    groups = [("", patch(), (0, 0, 0), None), ("weed", weed(*WEED_AT), (WEED_AT[0], WEED_AT[1], 0.0), "")]
    qk.finish(L, "garden", groups, "2x2", "field_edge")
