"""Help-request set: chimney rubble (V12), songbird (V13), handcart (V14), lantern (V15), trust heart (V17), help marker (V16).
Original designs; references = the moodboard and props refs. Run one variant:
    blender --factory-startup -b -P assets/generators/make_help_props.py -- <kind> <A|B|C|D>
Final:  ... -- FINAL <kind> <letter> <vNN>
Glow, smoke and sparkles are VFX added in Godot at the __*_anchor empties; models only carry the solid parts.
Front is -Y. Moving parts (bird wings, cart wheels, the cart's mud rut) are separate children with pivots.
"""
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "tools"))
sys.path.insert(0, HERE)
import blender_common as bc  # noqa: E402
import make_village_props as vp  # noqa: E402  (box, cyl, tbox, tcyl, nb helpers)

box, cyl, tbox, tcyl, nb = vp.box, vp.cyl, vp.tbox, vp.tcyl, vp.nb


def shaped(o, loc, sx=1.0, sy=1.0, sz=1.0):
    """A part built around the origin: squash its mesh, then move it to loc."""
    for v in o.data.vertices:
        v.co.x = v.co.x * sx + loc[0]
        v.co.y = v.co.y * sy + loc[1]
        v.co.z = v.co.z * sz + loc[2]
    return o


# ------------------------------------------------------------------ V12 chimney rubble (about 1 cell wide pile pulled from the socket)
def rubble_A():
    """Heap of five loose bricks with a soot cap."""
    p = [tbox("brick", (0.0075, 0.0038, 0.0030), (0, 0, 0.0016), "roof_terracotta", 0, 0, 10),
         tbox("brick", (0.0075, 0.0038, 0.0030), (0.0010, 0.0, 0.0047), "roof_terracotta", 0, 0, 80),
         tbox("brick", (0.0075, 0.0038, 0.0030), (-0.0045, -0.0030, 0.0016), "roof_terracotta", 0, 0, 40),
         tbox("brick", (0.0075, 0.0038, 0.0030), (0.0050, 0.0030, 0.0016), "roof_terracotta", 0, 0, 120),
         tbox("brick", (0.0075, 0.0038, 0.0030), (0.0, 0.0, 0.0078), "roof_terracotta", 0, 0, 35)]
    p.append(shaped(bc.blob("soot", 0.0042, (0, 0, 0), "stone_dark", 1), (0.0, 0.0, 0.0110), 1, 1, 0.6))
    return p


def rubble_B():
    """Fused chunk: a mortared lump of two bricks and stones with a sooty top."""
    return [tbox("chunk", (0.0105, 0.0085, 0.0070), (0, 0, 0.0035), "roof_terracotta", 0, 0, 15),
            tbox("chunk", (0.0070, 0.0070, 0.0058), (0.0030, -0.0015, 0.0099), "stone", 0, 0, 50),
            tbox("chunk", (0.0060, 0.0055, 0.0050), (-0.0035, 0.0010, 0.0095), "roof_terracotta", 0, 0, 70),
            shaped(bc.blob("soot", 0.0048, (0, 0, 0), "stone_dark", 1), (0.0, 0.0, 0.0126), 1, 1, 0.55)]


def rubble_C():
    """Bricks and a big round soot ball wedged on top."""
    return [tbox("brick", (0.0085, 0.0042, 0.0032), (0, 0, 0.0016), "roof_terracotta", 0, 0, 20),
            tbox("brick", (0.0085, 0.0042, 0.0032), (0.0010, 0.0010, 0.0049), "roof_terracotta", 0, 0, 100),
            tbox("brick", (0.0070, 0.0040, 0.0030), (-0.0050, -0.0040, 0.0015), "wall_cream", 0, 0, 60),
            bc.blob("soot", 0.0058, (0.0, 0.0, 0.0105), "stone_dark", 1)]


def rubble_D():
    """Broken cap slab leaning on two bricks."""
    return [tbox("brick", (0.0075, 0.0040, 0.0032), (-0.0030, 0.0, 0.0016), "roof_terracotta", 0, 0, 0),
            tbox("brick", (0.0075, 0.0040, 0.0032), (0.0040, 0.0020, 0.0016), "roof_terracotta", 0, 0, 90),
            tbox("slab", (0.0120, 0.0090, 0.0030), (0.0, 0.0, 0.0058), "stone_dark", 14, 18, 0),
            shaped(bc.blob("soot", 0.0035, (0, 0, 0), "stone_dark", 1), (0.0010, 0.0, 0.0085), 1, 1, 0.5)]


# ------------------------------------------------------------------ V13 songbird (plump, front -Y); wings are separate parts
def songbird(back, belly, head, beak, size=1.0, plump=1.0):
    s = size
    body = [shaped(bc.blob("body", 0.0075, (0, 0, 0), back, 1), (0, 0.0005 * s, 0.0105 * s), s, 1.15 * s * plump, 0.95 * s * plump),
            shaped(bc.blob("belly", 0.0066, (0, 0, 0), belly, 1), (0, -0.0022 * s, 0.0092 * s), 0.95 * s, 0.85 * s, 0.85 * s),
            bc.blob("head", 0.0050 * s, (0, -0.0062 * s, 0.0168 * s), head, 1),
            tcyl("beak", 0.0019 * s, 0.0045 * s, (0, -0.0112 * s, 0.0160 * s), beak, 4, 90, 0, 0, 0.0),
            tbox("tail", (0.0050 * s, 0.0075 * s, 0.0020 * s), (0, 0.0090 * s, 0.0118 * s), back, -22, 0, 0),
            box("foot", (0.0012 * s, 0.0032 * s, 0.0040 * s), (-0.0020 * s, -0.0010 * s, 0.0020 * s), "wood_dark"),
            box("foot", (0.0012 * s, 0.0032 * s, 0.0040 * s), (0.0020 * s, -0.0010 * s, 0.0020 * s), "wood_dark"),
            bc.blob("eye", 0.0011 * s, (-0.0030 * s, -0.0098 * s, 0.0178 * s), "stone_dark", 0),
            bc.blob("eye", 0.0011 * s, (0.0030 * s, -0.0098 * s, 0.0178 * s), "stone_dark", 0)]
    wl = [tbox("wing", (0.0014 * s, 0.0085 * s, 0.0065 * s), (-0.0076 * s, 0.0006 * s, 0.0108 * s), back, 12, 0, 0)]
    wr = [tbox("wing", (0.0014 * s, 0.0085 * s, 0.0065 * s), (0.0076 * s, 0.0006 * s, 0.0108 * s), back, 12, 0, 0)]
    for q in body + wl + wr:
        nb(q)
    return bc.assemble("ew_village_songbird_v01", [("", body, (0, 0, 0), None),
                                                  ("wing_l", wl, (-0.0072 * s, 0.0, 0.0125 * s), ""),
                                                  ("wing_r", wr, (0.0072 * s, 0.0, 0.0125 * s), "")])


def bird_A():
    return songbird("wood_light", "roof_terracotta", "wood_mid", "roof_orange")        # robin


def bird_B():
    return songbird("wood_mid", "wall_cream", "wood_light", "stone_dark")              # sparrow


def bird_C():
    return songbird("roof_orange", "wall_cream", "roof_orange", "wood_dark", 1.0, 1.0)  # canary


def bird_D():
    return songbird("wall_cream", "wall_cream", "roof_orange", "roof_orange", 1.05, 1.18)  # round puffball


# ------------------------------------------------------------------ V15 lantern (glass is a dark socket; light is VFX at __glow_anchor)
def lantern_A():
    """Round cage lantern: posts around a dark glass cylinder, cone cap, ring handle."""
    p = [cyl("base", 0.0090, 0.0030, (0, 0, 0), "wood_dark", 8), cyl("glass", 0.0066, 0.0165, (0, 0, 0.0030), "stone_dark", 8),
         cyl("top", 0.0092, 0.0026, (0, 0, 0.0195), "wood_dark", 8), cyl("cap", 0.0080, 0.0070, (0, 0, 0.0221), "wood_dark", 8, 0.0020)]
    for k in range(4):
        a = math.radians(k * 90 + 45)
        p.append(box("post", (0.0022, 0.0022, 0.0170), (0.0076 * math.cos(a), 0.0076 * math.sin(a), 0.0110), "wood_light"))
    for sx in (-1, 1):
        p.append(box("handle", (0.0020, 0.0020, 0.0100), (sx * 0.0040, 0, 0.0305), "wood_light"))
    p.append(box("handle", (0.0100, 0.0020, 0.0020), (0, 0, 0.0360), "wood_light"))
    return p


def lantern_B():
    """Hexagonal lantern with a pyramid roof and a loop handle."""
    p = [cyl("base", 0.0085, 0.0030, (0, 0, 0), "stone_dark", 6), cyl("glass", 0.0078, 0.0150, (0, 0, 0.0030), "wood_dark", 6, 0.0066),
         cyl("roof", 0.0100, 0.0075, (0, 0, 0.0180), "roof_terracotta", 6, 0.0012), cyl("knob", 0.0026, 0.0030, (0, 0, 0.0255), "stone_dark", 6)]
    for sx in (-1, 1):
        p.append(box("handle", (0.0020, 0.0020, 0.0100), (sx * 0.0030, 0, 0.0320), "stone_dark"))
    p.append(box("handle", (0.0080, 0.0020, 0.0020), (0, 0, 0.0375), "stone_dark"))
    return p


def lantern_C():
    """Square box lantern: corner posts, dark glass block, flat roof with a smaller cap, bail handle."""
    p = [box("base", (0.0150, 0.0150, 0.0030), (0, 0, 0.0015), "wood_dark"), box("glass", (0.0110, 0.0110, 0.0160), (0, 0, 0.0110), "stone_dark"),
         box("roof", (0.0170, 0.0170, 0.0026), (0, 0, 0.0203), "wood_dark"), box("cap", (0.0100, 0.0100, 0.0040), (0, 0, 0.0236), "wood_light")]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(box("post", (0.0024, 0.0024, 0.0165), (sx * 0.0066, sy * 0.0066, 0.0110), "wood_light"))
    p += [box("handle", (0.0020, 0.0020, 0.0095), (-0.0050, 0, 0.0290), "wood_light"), box("handle", (0.0020, 0.0020, 0.0095), (0.0050, 0, 0.0290), "wood_light"),
          box("handle", (0.0120, 0.0020, 0.0020), (0, 0, 0.0345), "wood_light")]
    return p


def lantern_D():
    """Round paper-style lantern: a squashed dark ball between two caps, carried by a loop."""
    p = [bc.blob("glass", 0.0088, (0, 0, 0.0125), "stone_dark", 1, (1, 1, 1.1)),
         cyl("cap", 0.0058, 0.0030, (0, 0, 0.0220), "roof_terracotta", 8), cyl("foot", 0.0056, 0.0028, (0, 0, 0.0005), "roof_terracotta", 8),
         bc.blob("ring", 0.0030, (0, 0, 0.0268), "wood_dark", 0)]
    p += [cyl("band", 0.0092, 0.0022, (0, 0, 0.0064), "roof_terracotta", 8), cyl("band", 0.0092, 0.0022, (0, 0, 0.0176), "roof_terracotta", 8)]
    return p


# ------------------------------------------------------------------ V14 handcart (about 2 x 1 cells): wheels and the mud rut are separate parts
def wheel(x, y, z, r=0.0112, thick=0.0050):
    """Parts of one wheel; axle along Y."""
    return [tcyl("wheel", r, thick, (x, y, z), "wood_dark", 8, 90, 0, 0), tcyl("wheel", r * 0.78, thick + 0.0004, (x, y, z), "wood_light", 8, 90, 0, 0),
            tcyl("hub", r * 0.30, thick + 0.0012, (x, y, z), "wood_dark", 6, 90, 0, 0)]


def cart_assemble(root_parts, wheels, with_rut=True, rut_y=-0.0170, rut_x=-0.0060):
    groups = [("", root_parts, (0, 0, 0), None)]
    for i, (x, y, z, parts) in enumerate(wheels):
        groups.append(("wheel_%d" % (i + 1), parts, (x, y, z), ""))
    if with_rut:
        rut = [bc.cone("rut", 0.0150, 0.0092, 0.0055, (rut_x, rut_y, 0.00275), "path_dirt", 7),
               bc.cone("rut", 0.0070, 0.0050, 0.0030, (rut_x - 0.0020, rut_y - 0.0050, 0.0068), "dirt_dark", 6, 20),
               tbox("rock", (0.0045, 0.0040, 0.0035), (rut_x + 0.0090, rut_y - 0.0030, 0.0040), "stone", 0, 0, 30)]
        groups.append(("rut", rut, (rut_x, rut_y, 0.0), ""))
    return bc.assemble("ew_village_handcart_v01", groups)


def cart_A():
    """Two-wheel handcart: plank bed with side boards, two long handles, a sack on board."""
    body = [box("bed", (0.0420, 0.0290, 0.0030), (0, 0, 0.0145), "wood_light"),
            box("side", (0.0420, 0.0030, 0.0075), (0, -0.0130, 0.0195), "wood_mid"), box("side", (0.0420, 0.0030, 0.0075), (0, 0.0130, 0.0195), "wood_mid"),
            box("back", (0.0030, 0.0290, 0.0075), (-0.0195, 0, 0.0195), "wood_mid"),
            box("axle", (0.0030, 0.0400, 0.0030), (-0.0060, 0, 0.0112), "wood_dark"),
            box("handle", (0.0300, 0.0030, 0.0030), (0.0345, -0.0105, 0.0150), "wood_dark"), box("handle", (0.0300, 0.0030, 0.0030), (0.0345, 0.0105, 0.0150), "wood_dark"),
            vp.sack_blob("sack", 0.0075, (-0.0030, 0.0020, 0.0220), "path_stone")]
    return cart_assemble(body, [(-0.0060, -0.0170, 0.0112, wheel(-0.0060, -0.0170, 0.0112)), (-0.0060, 0.0170, 0.0112, wheel(-0.0060, 0.0170, 0.0112))])


def cart_B():
    """Wheelbarrow: single front wheel, tilted tray, two legs, two handles."""
    body = [tbox("tray", (0.0300, 0.0230, 0.0060), (0.0030, 0, 0.0170), "wood_light", 0, -8, 0),
            tbox("side", (0.0300, 0.0030, 0.0070), (0.0030, -0.0105, 0.0205), "wood_mid", 0, -8, 0), tbox("side", (0.0300, 0.0030, 0.0070), (0.0030, 0.0105, 0.0205), "wood_mid", 0, -8, 0),
            tbox("front", (0.0030, 0.0230, 0.0075), (0.0170, 0, 0.0200), "wood_mid", 0, -8, 0),
            box("handle", (0.0320, 0.0030, 0.0030), (-0.0170, -0.0090, 0.0170), "wood_dark"), box("handle", (0.0320, 0.0030, 0.0030), (-0.0170, 0.0090, 0.0170), "wood_dark"),
            box("leg", (0.0030, 0.0030, 0.0130), (-0.0100, -0.0100, 0.0065), "wood_dark"), box("leg", (0.0030, 0.0030, 0.0130), (-0.0100, 0.0100, 0.0065), "wood_dark"),
            box("fork", (0.0030, 0.0120, 0.0030), (0.0185, 0, 0.0125), "wood_dark")]
    w = wheel(0.0185, 0.0, 0.0100, 0.0100, 0.0055)
    return cart_assemble(body, [(0.0185, 0.0, 0.0100, w)], rut_x=0.0185, rut_y=-0.0040)


def cart_C():
    """Hay cart: low rails around a heaped hay load, two wheels, a front pole."""
    body = [box("bed", (0.0420, 0.0300, 0.0030), (0, 0, 0.0145), "wood_light"),
            box("rail", (0.0420, 0.0020, 0.0040), (0, -0.0140, 0.0200), "wood_mid"), box("rail", (0.0420, 0.0020, 0.0040), (0, 0.0140, 0.0200), "wood_mid"),
            box("post", (0.0024, 0.0024, 0.0090), (-0.0190, -0.0140, 0.0200), "wood_dark"), box("post", (0.0024, 0.0024, 0.0090), (0.0190, -0.0140, 0.0200), "wood_dark"),
            box("post", (0.0024, 0.0024, 0.0090), (-0.0190, 0.0140, 0.0200), "wood_dark"), box("post", (0.0024, 0.0024, 0.0090), (0.0190, 0.0140, 0.0200), "wood_dark"),
            box("axle", (0.0030, 0.0420, 0.0030), (-0.0060, 0, 0.0112), "wood_dark"), box("pole", (0.0300, 0.0030, 0.0030), (0.0320, 0, 0.0140), "wood_dark"),
            shaped(bc.blob("hay", 0.0180, (0, 0, 0), "leaf_yellow", 1), (0.0, 0.0, 0.0190), 1.05, 0.72, 0.60)]
    nb(body[-1])
    return cart_assemble(body, [(-0.0060, -0.0175, 0.0112, wheel(-0.0060, -0.0175, 0.0112)), (-0.0060, 0.0175, 0.0112, wheel(-0.0060, 0.0175, 0.0112))])


def cart_D():
    """Barrel cart: bed with two barrels strapped on, two wheels, two handles."""
    body = [box("bed", (0.0400, 0.0280, 0.0030), (0, 0, 0.0145), "wood_mid"),
            box("axle", (0.0030, 0.0400, 0.0030), (-0.0040, 0, 0.0112), "wood_dark"),
            box("handle", (0.0280, 0.0030, 0.0030), (0.0330, -0.0100, 0.0150), "wood_dark"), box("handle", (0.0280, 0.0030, 0.0030), (0.0330, 0.0100, 0.0150), "wood_dark")]
    for (x, y) in ((-0.0070, 0.0), (0.0090, 0.0)):
        for q in vp.barrel(x, y, 0.0160):
            body.append(q)
    return cart_assemble(body, [(-0.0040, -0.0170, 0.0112, wheel(-0.0040, -0.0170, 0.0112)), (-0.0040, 0.0170, 0.0112, wheel(-0.0040, 0.0170, 0.0112))])


# ------------------------------------------------------------------ V17 trust heart (upright, faces -Y)
def heart(col, s=1.0, thick=0.55, loc=(0, 0, 0)):
    x0, y0, z0 = loc
    p = [shaped(bc.blob("lobe", 0.0058 * s, (0, 0, 0), col, 1), (x0 - 0.0044 * s, y0, z0 + 0.0150 * s), 1, thick, 1),
         shaped(bc.blob("lobe", 0.0058 * s, (0, 0, 0), col, 1), (x0 + 0.0044 * s, y0, z0 + 0.0150 * s), 1, thick, 1),
         shaped(bc.cone("point", 0.0, 0.0102 * s, 0.0150 * s, (0, 0, 0), col, 4, 45), (x0, y0, z0 + 0.0085 * s), 1, thick * 0.9, 1)]
    return p


def token_A():
    return heart("fire_red")


def token_B():
    """Heart on a gold coin."""
    coin = [tcyl("coin", 0.0115, 0.0034, (0, 0, 0.0115), "rarity_gold", 10, 90, 0, 0),
            tcyl("rim", 0.0120, 0.0028, (0, 0.0003, 0.0115), "roof_orange", 10, 90, 0, 0)]
    return coin + heart("fire_red", 0.78, 0.6, (0, -0.0026, 0.0020))


def token_C():
    """Boxy heart: a diamond block plus two round lobes, with a small cream highlight."""
    p = [tbox("diamond", (0.0125, 0.0058, 0.0125), (0, 0, 0.0080), "fire_red", 0, 45, 0),
         shaped(bc.blob("lobe", 0.0062, (0, 0, 0), "fire_red", 1), (-0.0046, 0, 0.0148), 1, 0.9, 1),
         shaped(bc.blob("lobe", 0.0062, (0, 0, 0), "fire_red", 1), (0.0046, 0, 0.0148), 1, 0.9, 1),
         bc.blob("shine", 0.0014, (-0.0056, -0.0030, 0.0165), "wall_cream", 0)]
    return p


def token_D():
    """Two-tone heart: red outer heart with a raised orange inner heart."""
    return heart("fire_red", 1.0, 0.55) + heart("roof_orange", 0.62, 0.9, (0, -0.0034, 0.0050))


# ------------------------------------------------------------------ V16 help marker (a chunky "!")
def bang(col, s=1.0, y=0.0, z0=0.0):
    return [bc.cone("bar", 0.0030 * s, 0.0052 * s, 0.0150 * s, (0, y, z0 + 0.0215 * s), col, 4, 45),
            bc.box("dot", (0.0058 * s, 0.0058 * s, 0.0058 * s), (0, y, z0 + 0.0072 * s), col, 45)]


def marker_A():
    """Gold bang on a dark backing plate (silhouette stays readable on any background)."""
    return [box("plate", (0.0140, 0.0030, 0.0300), (0, 0.0022, 0.0160), "wood_dark")] + bang("rarity_gold", 1.0, -0.0010, 0.0)


def marker_B():
    """Bang in a round cream badge."""
    return [tcyl("badge", 0.0140, 0.0036, (0, 0.0020, 0.0160), "wall_cream", 10, 90, 0, 0),
            tcyl("rim", 0.0150, 0.0030, (0, 0.0026, 0.0160), "wood_dark", 10, 90, 0, 0)] + bang("roof_orange", 0.9, -0.0016, 0.0020)


def marker_C():
    """Orange diamond sign with a cream bang."""
    return [tbox("sign", (0.0230, 0.0036, 0.0230), (0, 0.0020, 0.0160), "roof_orange", 0, 45, 0),
            tbox("edge", (0.0262, 0.0030, 0.0262), (0, 0.0026, 0.0160), "wood_dark", 0, 45, 0)] + bang("wall_cream", 0.8, -0.0016, 0.0035)


def marker_D():
    """Red-orange bang, no plate: biggest and plainest."""
    return bang("fire_red", 1.15, 0.0, -0.0010)


KINDS = {
    "rubble": ("village_chimney_rubble", dict(A=rubble_A, B=rubble_B, C=rubble_C, D=rubble_D), "static", "smoke_anchor", 0.014, "1x1", "chimney_request"),
    "bird": ("village_songbird", dict(A=bird_A, B=bird_B, C=bird_C, D=bird_D), "assembled", None, 0.0, "1x1", "request"),
    "lantern": ("village_lantern", dict(A=lantern_A, B=lantern_B, C=lantern_C, D=lantern_D), "static", "glow_anchor", 0.020, "1x1", "request"),
    "cart": ("village_handcart", dict(A=cart_A, B=cart_B, C=cart_C, D=cart_D), "assembled", None, 0.0, "2x1", "request"),
    "heart": ("village_trust_heart", dict(A=token_A, B=token_B, C=token_C, D=token_D), "static", "sparkle_anchor", 0.026, "1x1", "token"),
    "marker": ("ui_help_marker", dict(A=marker_A, B=marker_B, C=marker_C, D=marker_D), "static", "pulse_anchor", 0.030, "1x1", "marker"),
}


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def build(kind, letter, ver="v01"):
    short, builders, mode, anchor_name, asize, foot, hint = KINDS[kind]
    bc.clear_scene()
    name = "ew_%s_%s" % (short, ver)
    if mode == "assembled":
        root = builders[letter]()
        root.name = root.name.replace("_v01", "_" + ver)
        for ch in root.children_recursive:
            ch.name = ch.name.replace("_v01", "_" + ver)
        if kind == "bird":
            bc.anchor(root, "perch_anchor", (0, 0, 0.0), size=0.012)
        else:
            bc.anchor(root, "rut_anchor", (0, 0, 0.0), size=0.016)
    else:
        root = bc.finish(builders[letter](), name)
        if anchor_name:
            vs = [v.co for v in root.data.vertices]
            bc.anchor(root, anchor_name, (0, 0, (min(c.z for c in vs) + max(c.z for c in vs)) / 2), size=asize)
    root["ew_footprint"], root["ew_front"], root["ew_place"] = foot, "-Y", hint
    total = sum(tris(o) for o in [root] + list(root.children_recursive) if o.type == "MESH")
    dims = root.dimensions
    print("%s %s: %d tris, %.1f x %.1f x %.1f mm" % (name, letter, total, dims.x * 1000, dims.y * 1000, dims.z * 1000))
    return root


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if args and args[0] == "FINAL":
        root = build(args[1], args[2], args[3])
        bc.save_blend(root, "help_" + args[1])
        print("EXPORT", bc.export_glb(root, "ui" if args[1] == "marker" else "village"))
    else:
        root = build(args[0], args[1])
        bc.save_blend(root, "help_%s_%s" % (args[0], args[1]))
