"""Village props: the cosmetic 'lived in' set (Siddharth 2026-10-21, references art/moodboard/props_refs_2026-10-21/).
Everything here is decoration placed procedurally in Godot, so each prop declares what the placement algorithm needs
as custom properties on its root object (exported as glTF extras):
    ew_footprint  "WxD" in cells (1 cell = 5 cm), width along X, depth along Y
    ew_front      the side that should face the viewer / the street, "-Y" by default (houses face -Y too)
    ew_place      placement hint: near_house | plaza | lane_edge | field_edge | free | wall_side
Run:
    blender --factory-startup -b -P assets/generators/make_village_props.py -- SET            (all props in a grid, preview blend)
    blender --factory-startup -b -P assets/generators/make_village_props.py -- FINAL <name>   (one prop, blend + glb)
Style: chunky, calm, big readable shapes; colours only from the palette atlas; no blue (blue = Foresight only),
so the market awning stripes are warm (terracotta and cream).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import blender_common as bc  # noqa: E402
import bmesh  # noqa: E402
import bpy  # noqa: E402


def nb(o):
    o["no_bevel"] = True
    return o


def box(name, size, loc, col, rz=0.0):
    return bc.box(name, size, loc, col, rz)


def cyl(name, r, h, loc, col, seg=8, r_top=None, rz=0.0):
    """Cylinder / frustum standing on loc (loc is the BASE centre)."""
    x, y, z = loc
    return bc.cone(name, r, r if r_top is None else r_top, h, (x, y, z + h / 2), col, seg, rz)


def tilted(o, loc, rx=0.0, ry=0.0, rz=0.0):
    """Part built around the origin, rotated about its own centre, then moved to loc."""
    bpy.ops.object.select_all(action="DESELECT")
    o.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz))
    bpy.context.view_layer.update()
    bc.apply_transforms(o)
    bpy.ops.object.select_all(action="DESELECT")
    for v in o.data.vertices:
        v.co.x += loc[0]
        v.co.y += loc[1]
        v.co.z += loc[2]
    return o


def tbox(name, size, loc, col, rx=0.0, ry=0.0, rz=0.0):
    return tilted(bc.box(name, size, (0, 0, 0), col), loc, rx, ry, rz)


def tcyl(name, r, h, loc, col, seg=8, rx=0.0, ry=0.0, rz=0.0, r_top=None):
    """Tilted cylinder; loc is its CENTRE."""
    return tilted(bc.cone(name, r, r if r_top is None else r_top, h, (0, 0, 0), col, seg), loc, rx, ry, rz)


def sack_blob(name, r, loc, col, squash=(1.0, 0.9, 1.15)):
    o = bc.blob(name, r, loc, col, 1, squash)
    nb(o)
    return o


# --------------------------------------------------------------------- props: village life
def barrel(x=0.0, y=0.0, z=0.0, rz=0.0):
    p = [cyl("barrel", 0.0088, 0.0135, (x, y, z), "wood_light", 8, 0.0105),
         cyl("barrel", 0.0105, 0.0125, (x, y, z + 0.0135), "wood_light", 8, 0.0088),
         cyl("hoop", 0.0107, 0.0016, (x, y, z + 0.0036), "wood_dark", 8),
         cyl("hoop", 0.0107, 0.0016, (x, y, z + 0.0214), "wood_dark", 8),
         cyl("lid", 0.0080, 0.0006, (x, y, z + 0.0260), "wood_light", 8)]
    for q in p:
        nb(q)
    return p


def barrels():            # single barrel
    return barrel()


def barrel_stack():       # two upright barrels with one lying on top
    p = barrel(-0.0105, 0.0, 0.0) + barrel(0.0105, 0.0, 0.0)
    p.append(nb(tcyl("barrel", 0.0095, 0.024, (0.0, 0.0, 0.0345), "wood_light", 8, 0, 90, 0, 0.0095)))
    p.append(nb(tcyl("hoop", 0.0100, 0.0016, (-0.0065, 0.0, 0.0345), "wood_dark", 8, 0, 90, 0)))
    p.append(nb(tcyl("hoop", 0.0100, 0.0016, (0.0065, 0.0, 0.0345), "wood_dark", 8, 0, 90, 0)))
    return p


def crate(x=0.0, y=0.0, z=0.0, s=0.020, rz=0.0):
    t = 0.0024
    p = [box("crate_body", (s - 0.0008, s - 0.0008, s - 0.0008), (x, y, z + s / 2), "wood_light", rz)]
    for dx in (-1, 1):
        for dy in (-1, 1):
            c, sn = math.cos(math.radians(rz)), math.sin(math.radians(rz))
            ox, oy = dx * (s / 2 - t / 2), dy * (s / 2 - t / 2)
            p.append(box("crate_post", (t, t, s), (x + ox * c - oy * sn, y + ox * sn + oy * c, z + s / 2), "wood_dark", rz))
    p.append(box("crate_lid", (s, s, 0.0016), (x, y, z + s + 0.0004), "wood_light", rz))
    return [nb(q) for q in p]


def crate_stack():
    return crate(-0.0105, -0.003, 0.0, 0.020) + crate(0.0105, 0.002, 0.0, 0.018, 8) + crate(-0.001, 0.0, 0.0202, 0.017, -14)


def sacks():
    p = []
    for (x, y, r, h) in ((-0.0090, 0.0, 0.0085, 0.0210), (0.0085, 0.0020, 0.0082, 0.0190), (0.0, -0.0095, 0.0078, 0.0140)):
        p.append(nb(cyl("sack", r, h * 0.62, (x, y, 0.0), "path_stone", 8, r * 1.12)))
        p.append(nb(cyl("sack", r * 1.12, h * 0.30, (x, y, h * 0.62), "path_stone", 8, r * 0.60)))
        p.append(nb(cyl("sack_tie", r * 0.62, 0.0016, (x, y, h * 0.90), "path_dirt", 8)))
        p.append(nb(cyl("sack_top", r * 0.60, h * 0.12, (x, y, h * 0.90), "path_stone", 8, r * 0.30)))
    return p


def bench():
    p = [box("seat", (0.040, 0.0125, 0.0032), (0, 0, 0.0128), "wood_light"),
         box("back", (0.040, 0.0030, 0.0090), (0, 0.0050, 0.0205), "wood_light")]
    for sx in (-1, 1):
        p.append(box("leg", (0.0036, 0.0125, 0.0126), (sx * 0.0165, 0, 0.0063), "wood_dark"))
        p.append(box("arm", (0.0030, 0.0036, 0.0100), (sx * 0.0215, 0.0040, 0.0180), "wood_dark"))
    return p


def table_stool():
    p = [cyl("top", 0.0150, 0.0034, (0, 0, 0.0150), "wood_light", 10),
         cyl("post", 0.0048, 0.0150, (0, 0, 0.0), "wood_dark", 6)]
    for a in (0, 120, 240):
        r = math.radians(a)
        p.append(box("foot", (0.0090, 0.0026, 0.0026), (0.0045 * math.cos(r), 0.0045 * math.sin(r), 0.0013), "wood_dark", a))
    p.append(cyl("stool_top", 0.0058, 0.0030, (0.0215, -0.0010, 0.0090), "wood_light", 8))
    for a in (0, 120, 240):
        r = math.radians(a)
        p.append(box("stool_leg", (0.0026, 0.0026, 0.0090), (0.0215 + 0.0035 * math.cos(r), -0.0010 + 0.0035 * math.sin(r), 0.0045), "wood_dark"))
    return p


def flower_pots():
    p = []
    for (x, y, h, col) in ((-0.0105, 0.0, 0.0072, "roof_terracotta"), (0.0020, 0.0040, 0.0090, "roof_terracotta"), (0.0125, -0.0030, 0.0065, "roof_orange")):
        p.append(nb(cyl("pot", 0.0050, h, (x, y, 0.0), col, 8, 0.0064)))
        p.append(nb(cyl("pot_rim", 0.0068, 0.0016, (x, y, h), col, 8)))
        p.append(nb(cyl("soil", 0.0054, 0.0006, (x, y, h + 0.0016), "path_dirt", 8)))
        p.append(sack_blob("leaves", 0.0052, (x, y, h + 0.0058), "leaf_light", (1.15, 1.15, 0.65)))
        for k in range(3):
            a = math.radians(k * 120 + 30)
            p.append(nb(cyl("flower", 0.0022, 0.0026, (x + 0.0028 * math.cos(a), y + 0.0028 * math.sin(a), h + 0.0078),
                            ("roof_orange", "roof_orange", "wall_cream")[k], 5, 0.0009)))
    return p


def rnd_choice(seed, opts):
    return opts[int(abs(seed) * 1000) % len(opts)]


def haystack():
    p = [nb(cyl("hay", 0.0165, 0.0120, (0, 0, 0), "leaf_yellow", 10, 0.0140)),
         nb(cyl("hay", 0.0140, 0.0100, (0, 0, 0.0120), "leaf_yellow", 10, 0.0075)),
         nb(cyl("hay", 0.0075, 0.0080, (0, 0, 0.0220), "leaf_yellow", 10, 0.0020)),
         nb(cyl("band", 0.0143, 0.0016, (0, 0, 0.0108), "wood_light", 10, 0.0143))]
    p.append(tbox("fork_handle", (0.0028, 0.0028, 0.0280), (0.0150, -0.0070, 0.0150), "wood_light", 0, 14, 0))
    p.append(tbox("fork_head", (0.0090, 0.0024, 0.0034), (0.0205, -0.0070, 0.0300), "stone_dark", 0, 14, 0))
    for dx in (-0.0034, 0.0, 0.0034):
        p.append(tbox("fork_tine", (0.0020, 0.0020, 0.0058), (0.0205 + dx, -0.0070, 0.0338), "stone_dark", 0, 14, 0))
    return [nb(q) for q in p]


def well():
    p = [nb(cyl("ring", 0.0135, 0.0130, (0, 0, 0), "stone", 10, 0.0128)),
         nb(cyl("rim", 0.0140, 0.0030, (0, 0, 0.0130), "path_stone", 10, 0.0134)),
         nb(cyl("water", 0.0092, 0.0004, (0, 0, 0.0160), "ink", 10))]
    for a in range(0, 360, 36):
        r = math.radians(a)
        p.append(nb(box("block", (0.0050, 0.0028, 0.0034), (0.0134 * math.cos(r), 0.0134 * math.sin(r), 0.0065 + (0.0042 if (a // 36) % 2 else 0)),
                        "stone_dark" if (a // 36) % 3 == 0 else "path_stone", a + 90)))
    for sx in (-1, 1):
        p.append(box("post", (0.0030, 0.0030, 0.0300), (sx * 0.0125, 0.0, 0.0145 + 0.0130), "wood_dark"))
    p.append(box("beam", (0.0300, 0.0026, 0.0026), (0, 0, 0.0420), "wood_dark"))
    p.append(nb(bc.gable("roof", 0.0360, 0.0270, 0.0105, (0, 0, 0.0420), "roof_terracotta")))
    p.append(nb(cyl("bucket", 0.0042, 0.0060, (0.0, 0.0, 0.0268), "wood_light", 6, 0.0050)))
    p.append(box("rope", (0.0010, 0.0010, 0.0090), (0.0, 0.0, 0.0345), "path_dirt"))
    return p


def clothesline():
    p = []
    for sx in (-1, 1):
        p.append(box("post", (0.0040, 0.0040, 0.0300), (sx * 0.0230, 0, 0.0150), "wood_light"))
        p.append(box("arm", (0.0100, 0.0030, 0.0030), (sx * 0.0230 - sx * 0.0030, 0, 0.0290), "wood_light"))
    p.append(box("line", (0.0480, 0.0022, 0.0022), (0, 0, 0.0290), "path_dirt"))
    cloths = (("wall_cream", -0.0150, 0.0105, 0.0150), ("roof_terracotta", -0.0010, 0.0100, 0.0125), ("leaf_light", 0.0135, 0.0105, 0.0145))
    for col, x, w, h in cloths:
        p.append(tbox("cloth", (w, 0.0020, h), (x, 0.0, 0.0278 - h / 2), col, 0, 0, 0))
    return [nb(q) for q in p]


def market_stall():
    p = [box("counter", (0.0420, 0.0160, 0.0150), (0, 0.0020, 0.0075), "wood_light"),
         box("counter_top", (0.0440, 0.0180, 0.0030), (0, 0.0020, 0.0165), "wood_dark")]
    for sx in (-1, 1):
        p.append(box("post", (0.0030, 0.0030, 0.0420), (sx * 0.0205, -0.0070, 0.0210), "wood_dark"))
        p.append(box("post", (0.0030, 0.0030, 0.0360), (sx * 0.0205, 0.0100, 0.0180), "wood_dark"))
    n = 7
    w = 0.0460 / n
    for i in range(n):
        col = "roof_terracotta" if i % 2 == 0 else "wall_cream"
        p.append(tbox("awning", (w, 0.0270, 0.0016), (-0.0230 + w * (i + 0.5), 0.0015, 0.0410), col, -15, 0, 0))
    p.append(box("valance", (0.0460, 0.0016, 0.0040), (0, -0.0114, 0.0376), "roof_terracotta"))
    # goods on the counter
    for x, col, r in ((-0.0140, "roof_orange", 0.0042), (-0.0070, "roof_orange", 0.0040), (0.0000, "leaf_green", 0.0046), (0.0080, "leaf_light", 0.0044), (0.0150, "roof_terracotta", 0.0040)):
        p.append(sack_blob("goods", r, (x, 0.0000, 0.0180 + r * 0.7), col, (1, 1, 0.9)))
    return [nb(q) if q.name.startswith(("goods", "awning", "valance")) else q for q in p]


# --------------------------------------------------------------------- props: fences and signs
def fence_straight():
    p = []
    for sx in (-1, 0, 1):
        p.append(box("post", (0.0040, 0.0040, 0.0180), (sx * 0.0218, 0, 0.0090), "wood_light"))
    p.append(box("rail", (0.0500, 0.0030, 0.0042), (0, 0, 0.0120), "wood_mid"))
    p.append(box("rail", (0.0500, 0.0030, 0.0042), (0, 0, 0.0058), "wood_mid"))
    return p


def fence_corner():
    p = [box("post", (0.0044, 0.0044, 0.0190), (0, 0, 0.0095), "wood_light")]
    p.append(box("post", (0.0040, 0.0040, 0.0180), (0.0250, 0, 0.0090), "wood_light"))
    p.append(box("post", (0.0040, 0.0040, 0.0180), (0, 0.0250, 0.0090), "wood_light"))
    for z in (0.0120, 0.0058):
        p.append(box("rail", (0.0250, 0.0030, 0.0042), (0.0125, 0, z), "wood_mid"))
        p.append(box("rail", (0.0030, 0.0250, 0.0042), (0, 0.0125, z), "wood_mid"))
    return p


def fence_gate():
    p = []
    for sx in (-1, 1):
        p.append(box("post", (0.0050, 0.0050, 0.0240), (sx * 0.0170, 0, 0.0120), "wood_light"))
        p.append(nb(cyl("cap", 0.0034, 0.0020, (sx * 0.0170, 0, 0.0240), "wood_dark", 6, 0.0024)))
    p.append(box("gate_top", (0.0300, 0.0026, 0.0040), (0, 0, 0.0150), "wood_mid"))
    p.append(box("gate_bot", (0.0300, 0.0026, 0.0040), (0, 0, 0.0052), "wood_mid"))
    p.append(tbox("gate_brace", (0.0350, 0.0024, 0.0036), (0, 0, 0.0101), "wood_mid", 0, 20, 0))
    return p


def signpost():
    p = [box("post", (0.0042, 0.0042, 0.0330), (0, 0, 0.0165), "wood_light"),
         nb(cyl("cap", 0.0034, 0.0022, (0, 0, 0.0330), "wood_dark", 6, 0.0022))]
    p.append(tbox("board", (0.0170, 0.0026, 0.0066), (0.0085, 0.0034, 0.0276), "wood_mid", 0, 0, 10))
    p.append(tbox("board", (0.0170, 0.0026, 0.0066), (-0.0085, -0.0034, 0.0196), "roof_terracotta", 0, 0, -10))
    return p


def notice_board():
    p = []
    for sx in (-1, 1):
        p.append(box("post", (0.0040, 0.0040, 0.0300), (sx * 0.0140, 0, 0.0150), "wood_light"))
    p.append(box("board", (0.0310, 0.0022, 0.0200), (0, -0.0006, 0.0200), "wood_light"))
    p.append(box("frame_top", (0.0330, 0.0026, 0.0020), (0, -0.0006, 0.0310), "wood_dark"))
    p.append(box("frame_bot", (0.0330, 0.0026, 0.0020), (0, -0.0006, 0.0100), "wood_dark"))
    for x, z, w, h, col in ((-0.0090, 0.0225, 0.0090, 0.0100, "wall_cream"), (0.0060, 0.0245, 0.0080, 0.0070, "wall_cream"),
                            (0.0050, 0.0160, 0.0100, 0.0085, "roof_terracotta"), (-0.0085, 0.0140, 0.0075, 0.0065, "wall_cream")):
        p.append(box("paper", (w + 0.0006, 0.0014, h + 0.0006), (x, -0.0026, z), col))
    p.append(nb(bc.gable("roof", 0.0400, 0.0100, 0.0050, (0, 0, 0.0320), "roof_terracotta")))
    return p


def stone_wall():
    p = []
    rnd = random.Random(7)
    x = -0.0250
    row = 0
    cols = ("path_stone", "stone", "path_stone", "stone")
    for lvl, z0 in enumerate((0.0, 0.0062)):
        x = -0.0250 + (0.0 if lvl == 0 else 0.0055)
        while x < 0.0250 - 0.0030:
            w = rnd.uniform(0.0095, 0.0125)
            w = min(w, 0.0250 - x - 0.0010) if x + w > 0.0250 else w
            p.append(nb(box("wall_stone", (w - 0.0008, 0.0100, 0.0058), (x + w / 2, rnd.uniform(-0.0006, 0.0006), z0 + 0.0029), rnd.choice(cols))))
            x += w
    for k in range(4):
        cx = -0.0190 + 0.0127 * k
        p.append(nb(box("wall_cap", (0.0112, 0.0112, 0.0030), (cx, 0.0, 0.0138), "path_stone", rnd.uniform(-4, 4))))
    p.append(nb(cyl("moss", 0.0034, 0.0018, (-0.0090, 0.0050, 0.0128), "leaf_green", 6, 0.0022)))
    return p


def footbridge():
    p = []
    n = 4
    L = 0.0480
    for i in range(n):
        t = (i + 0.5) / n
        x = -L / 2 + L * t
        z = 0.0100 * (1 - (2 * t - 1) ** 2) + 0.0040
        slope = math.degrees(math.atan(0.0100 * -2 * (2 * t - 1) * 2 / L))
        p.append(tbox("plank", (L / n + 0.0016, 0.0200, 0.0040), (x, 0.0, z), "wood_mid", 0, -slope, 0))
    for sy in (-1, 1):
        for t in (0.04, 0.5, 0.96):
            x = -L / 2 + L * t
            z = 0.0100 * (1 - (2 * t - 1) ** 2) + 0.0040
            p.append(box("post", (0.0036, 0.0036, 0.0130), (x, sy * 0.0105, z + 0.0050), "wood_light"))
        for k in range(4):
            t0, t1 = k / 4, (k + 1) / 4
            def hz(t):
                return 0.0100 * (1 - (2 * t - 1) ** 2) + 0.0040 + 0.0100
            x0, x1 = -L / 2 + L * t0, -L / 2 + L * t1
            dx, dz = x1 - x0, hz(t1) - hz(t0)
            ang = math.degrees(math.atan2(dz, dx))
            p.append(tbox("rail", (math.hypot(dx, dz) + 0.0010, 0.0030, 0.0032), ((x0 + x1) / 2, sy * 0.0105, (hz(t0) + hz(t1)) / 2), "wood_light", 0, -ang, 0))
    for sx in (-1, 1):
        p.append(nb(box("abutment", (0.0060, 0.0240, 0.0070), (sx * 0.0245, 0.0, 0.0035), "stone")))
    return p


# --------------------------------------------------------------------- props: small clutter
def bucket():
    p = [nb(cyl("bucket", 0.0056, 0.0085, (0, 0, 0), "wood_light", 8, 0.0068)),
         nb(cyl("hoop", 0.0062, 0.0014, (0, 0, 0.0024), "stone_dark", 8)),
         nb(cyl("water", 0.0060, 0.0004, (0, 0, 0.0082), "stone_dark", 8))]
    p.append(tbox("handle", (0.0136, 0.0024, 0.0024), (0, 0, 0.0122), "wood_dark", 0, 0, 0))
    return p


def clay_pots():
    p = []
    for (x, y, h, r) in ((-0.0060, 0.0, 0.0150, 0.0055), (0.0070, 0.0030, 0.0110, 0.0050)):
        p.append(nb(cyl("pot", r, h * 0.55, (x, y, 0.0), "roof_terracotta", 8, r * 1.18)))
        p.append(nb(cyl("pot", r * 1.18, h * 0.30, (x, y, h * 0.55), "roof_terracotta", 8, r * 0.55)))
        p.append(nb(cyl("pot_neck", r * 0.55, h * 0.15, (x, y, h * 0.85), "roof_terracotta", 8, r * 0.7)))
        p.append(nb(cyl("pot_band", r * 1.19, 0.0014, (x, y, h * 0.50), "wall_cream", 8)))
    return p


def pumpkins():
    p = []
    for (x, y, r) in ((-0.0070, 0.0, 0.0072), (0.0060, 0.0020, 0.0062), (0.0000, -0.0090, 0.0052)):
        p.append(sack_blob("pumpkin", r, (x, y, r * 0.85), "roof_orange", (1.15, 1.15, 0.85)))
        p.append(nb(cyl("stem", 0.0012, 0.0030, (x, y, r * 1.5), "leaf_green", 5, 0.0008)))
    return p


def basket():
    p = [nb(cyl("basket", 0.0064, 0.0075, (0, 0, 0), "wood_light", 8, 0.0078)),
         nb(cyl("basket_band", 0.0070, 0.0014, (0, 0, 0.0030), "wood_dark", 8))]
    p.append(nb(cyl("basket_lip", 0.0082, 0.0014, (0, 0, 0.0066), "wood_dark", 8)))
    p.append(box("handle", (0.0024, 0.0130, 0.0024), (0.0, 0.0, 0.0158), "wood_dark"))
    p.append(box("handle", (0.0024, 0.0024, 0.0090), (0.0, -0.0058, 0.0116), "wood_dark"))
    p.append(box("handle", (0.0024, 0.0024, 0.0090), (0.0, 0.0058, 0.0116), "wood_dark"))
    for (x, y, col) in ((-0.0020, 0.0010, "leaf_green"), (0.0025, -0.0015, "roof_terracotta"), (0.0005, 0.0030, "leaf_light")):
        p.append(sack_blob("fruit", 0.0036, (x, y, 0.0092), col, (1, 1, 0.95)))
    return p


def tools_leaning():
    p = [tbox("shovel_handle", (0.0034, 0.0034, 0.0300), (-0.0060, 0.0, 0.0171), "wood_light", 0, 12, 0),
         tbox("shovel_blade", (0.0092, 0.0024, 0.0110), (-0.0098, 0.0, 0.0051), "stone_dark", 0, 12, 0),
         tbox("fork_handle", (0.0034, 0.0034, 0.0320), (0.0060, 0.0, 0.0160), "wood_light", 0, -10, 0),
         tbox("fork_head", (0.0100, 0.0024, 0.0032), (0.0100, 0.0, 0.0272), "stone_dark", 0, -10, 0)]
    for dx in (-0.0026, 0.0, 0.0026):
        p.append(tbox("fork_tine", (0.0020, 0.0020, 0.0054), (0.0100 + dx * 1.2 + 0.0008, 0.0, 0.0306), "stone_dark", 0, -10, 0))
    for q in p:
        q.location.z += 0.0013
    return [nb(q) for q in p]


# name: (builder, footprint cells, front, placement hint)
PROPS = {
    "barrel": (barrels, "1x1", "-Y", "near_house"),
    "barrel_stack": (barrel_stack, "1x1", "-Y", "near_house"),
    "crate_stack": (crate_stack, "1x1", "-Y", "near_house"),
    "sacks": (sacks, "1x1", "-Y", "near_house"),
    "bench": (bench, "1x1", "-Y", "plaza"),
    "table_stool": (table_stool, "1x1", "-Y", "plaza"),
    "flower_pots": (flower_pots, "1x1", "-Y", "near_house"),
    "haystack": (haystack, "1x1", "-Y", "field_edge"),
    "well": (well, "1x1", "-Y", "plaza"),
    "clothesline": (clothesline, "2x1", "-Y", "near_house"),
    "market_stall": (market_stall, "2x1", "-Y", "plaza"),
    "fence_straight": (fence_straight, "1x1", "-Y", "field_edge"),
    "fence_corner": (fence_corner, "1x1", "-Y", "field_edge"),
    "fence_gate": (fence_gate, "1x1", "-Y", "field_edge"),
    "signpost": (signpost, "1x1", "-Y", "lane_edge"),
    "notice_board": (notice_board, "1x1", "-Y", "plaza"),
    "stone_wall": (stone_wall, "1x1", "-Y", "wall_side"),
    "footbridge": (footbridge, "1x1", "-Y", "free"),
    "bucket": (bucket, "1x1", "-Y", "near_house"),
    "clay_pots": (clay_pots, "1x1", "-Y", "near_house"),
    "pumpkins": (pumpkins, "1x1", "-Y", "field_edge"),
    "basket": (basket, "1x1", "-Y", "near_house"),
    "tools_leaning": (tools_leaning, "1x1", "-Y", "wall_side"),
}


def build(name, version="v01"):
    fn, foot, front, hint = PROPS[name]
    parts = fn()
    obj = bc.assemble("ew_village_%s_%s" % (name, version), [("", parts, (0, 0, 0), None)])
    obj["ew_footprint"] = foot
    obj["ew_front"] = front
    obj["ew_place"] = hint
    return obj


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    mode = args[0] if args else "SET"
    bc.clear_scene()
    if mode == "FINAL":
        obj = build(args[1], args[2] if len(args) > 2 else "v01")
        print("BLEND", bc.save_blend(obj, "prop_" + args[1]))
        print("EXPORT", bc.export_glb(obj, "village"))
    else:
        objs = []
        for i, name in enumerate(PROPS):
            o = build(name)
            o.location = ((i % 6) * 0.20, -(i // 6) * 0.20, 0)
            objs.append(o)
        print("BLEND", bc.save_blend(objs[0], "props_all"))
