"""Firewood pile + separate pickable log for quest 'Stack firewood' (carry 3 logs to the house).
Root = the woodpile (about 1.5 x 1 cells, footprint 2x1), child __log = ONE pickable log (~1 cell long = 44 mm) resting
beside the pile at z = 0 so the sheet shows both clearly. In the final, the loose log is its own asset at world 0.

Run one variant: blender --factory-startup -b -P assets/generators/make_firewood.py -- A  (A-D)
Front is -Y. Palette names only.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "tools"))
sys.path.insert(0, HERE)
import quest_kit as qk  # noqa: E402
from quest_kit import box, cyl, nb, orient  # noqa: E402
import blender_common as bc  # noqa: E402
import bmesh  # noqa: E402
import make_village_props as vp  # noqa: E402

LOG_AT = (0.046, -0.020)


def _cap(r, loc, direction, col, seg=6):
    """Cheap 4-tri hexagonal flat end cap facing along `direction` (no thick extra cylinder)."""
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, cap_tris=False, radius=r, segments=seg)
    o = bc._new_obj("cut_end", bm)
    bc.paint(o, col)
    return nb(orient(o, loc, direction))


def log_x(r, L, loc, bark="wood_dark", end_col="wall_cream", seg=6, ry=0.0, rz=0.0):
    """Chunky faceted log lying roughly along X, capped with bright flat cut-end discs (zero z-fight)."""
    x, y, z = loc
    dx = math.cos(math.radians(rz))
    dy = math.sin(math.radians(rz))
    dz = -math.sin(math.radians(ry))
    p = [nb(vp.tcyl("bark", r, L, (x, y, z), bark, seg, 0.0, 90.0 + ry, rz))]
    for s in (-1, 1):
        d = (s * dx, s * dy, s * dz)
        off = L * 0.5 + 0.0003
        p.append(_cap(r * 0.78, (x + off * d[0], y + off * d[1], z + off * d[2]), d, end_col, seg))
    return p


def log_y(r, L, loc, bark="wood_mid", end_col="wall_cream", seg=6, rx=0.0, rz=0.0):
    """Chunky faceted log lying along Y (cut ends face -Y / +Y toward camera), loc = centre."""
    x, y, z = loc
    dx = -math.sin(math.radians(rz))
    dy = math.cos(math.radians(rz))
    dz = math.sin(math.radians(rx))
    p = [nb(vp.tcyl("bark", r, L, (x, y, z), bark, seg, 90.0 + rx, 0.0, rz))]
    for s in (-1, 1):
        d = (s * dx, s * dy, s * dz)
        off = L * 0.5 + 0.0003
        p.append(_cap(r * 0.78, (x + off * d[0], y + off * d[1], z + off * d[2]), d, end_col, seg))
    return p


def split_half_log(w, h, L, loc, bark="wood_dark", heart="wall_cream", rz=0.0):
    """Chunky split half-round firewood billet: dark curved bark belly below, bevelled pale cut heartwood face above."""
    x, y, z = loc
    p = [nb(vp.tbox("bark_base", (w, L, h * 0.42), (x, y, z + h * 0.21), bark, 0, 0, rz)),
         nb(vp.tbox("heart_wedge", (w * 0.86, L - 0.001, h * 0.48), (x, y, z + h * 0.50), heart, 0, 12, rz)),
         nb(vp.tbox("bark_side", (w * 0.24, L - 0.0005, h * 0.48), (x + w * 0.38 * math.cos(math.radians(rz)), y + w * 0.38 * math.sin(math.radians(rz)), z + h * 0.42), bark, 0, 0, rz))]
    return p


def variant_A():
    """Neat crisscross cordwood pyramid between dark upright end-stakes on low stone skids + knotted round log."""
    p = [nb(box("skid_l", (0.006, 0.032, 0.003), (-0.018, 0, 0.0015), "stone_dark")),
         nb(box("skid_r", (0.006, 0.032, 0.003), (0.018, 0, 0.0015), "stone_dark"))]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(nb(box("stake", (0.004, 0.004, 0.034), (sx * 0.025, sy * 0.012, 0.017), "wood_dark")))
    # 3 stacked rows of Y-facing logs (cut ends clearly face camera -Y)
    rows = [(0.0080, (-0.016, -0.008, 0.0, 0.008, 0.016)),
            (0.0162, (-0.012, -0.004, 0.004, 0.012)),
            (0.0242, (-0.008, 0.0, 0.008))]
    for zc, xs in rows:
        for k, xx in enumerate(xs):
            p += log_y(0.0042, 0.034, (xx, 0, zc), "wood_mid" if k % 2 == 0 else "wood_dark", "wall_cream")
    lx, ly = LOG_AT
    lg = log_y(0.0052, 0.044, (lx, ly, 0.0052), "wood_dark", "wall_cream", rz=14)
    lg.append(nb(cyl("knot", 0.0022, 0.0045, (lx + 0.004, ly - 0.006, 0.0082), "wood_mid", 5)))
    return p, lg


def variant_B():
    """Covered open-front woodshed rack with terracotta shingle roof + split pale-hearted billet log."""
    p = [nb(box("deck", (0.056, 0.034, 0.004), (0, 0, 0.002), "stone"))]
    for sx in (-1, 1):
        p.append(nb(box("fpost", (0.0044, 0.0044, 0.042), (sx * 0.026, -0.014, 0.021), "wood_dark")))
        p.append(nb(box("bpost", (0.0044, 0.0044, 0.034), (sx * 0.026, 0.014, 0.017), "wood_dark")))
    p.append(nb(vp.tbox("roof", (0.064, 0.042, 0.0045), (0, 0, 0.040), "roof_terracotta", -13, 0, 0)))
    p.append(nb(vp.tbox("roof_ridge", (0.066, 0.006, 0.004), (0, -0.017, 0.0445), "wood_dark")))
    for rrow, zz in enumerate((0.0085, 0.0165, 0.0242)):
        for k in range(5 if rrow < 2 else 4):
            xx = -0.018 + k * 0.009 + (0.0045 if rrow == 2 else 0.0)
            p += log_y(0.0040, 0.028, (xx, 0.001, zz), "wood_mid" if (k + rrow) % 2 else "wood_light", "wall_cream")
    lx, ly = LOG_AT
    lg = split_half_log(0.0105, 0.0096, 0.044, (lx, ly, 0.0), "wood_dark", "wall_cream", rz=-18)
    return p, lg


def variant_C():
    """Chopping block stump with wedged iron axe beside a rustic stone-backed firewood stack + forked log."""
    # stone back wall & rustic log pile
    p = [nb(box("wall", (0.042, 0.006, 0.028), (0.008, 0.012, 0.014), "stone"))]
    for j, (xx, zz, rr) in enumerate(((-0.002, 0.005, 0.0050), (0.009, 0.005, 0.0048), (0.020, 0.005, 0.0050),
                                        (0.003, 0.0135, 0.0046), (0.015, 0.0135, 0.0046), (0.009, 0.0215, 0.0044))):
        p += log_y(rr, 0.026, (xx, -0.001, zz), "wood_dark" if j % 2 else "wood_mid", "wall_cream")
    # chopping stump on left + iron/wood axe wedged cleanly into stump top (handle starts inside axe_head socket)
    p.append(nb(cyl("stump", 0.0105, 0.0190, (-0.024, -0.004, 0.0), "wood_dark", 8, 0.0095)))
    p.append(nb(cyl("stump_top", 0.0085, 0.0010, (-0.024, -0.004, 0.0190), "wall_cream", 8)))
    p.append(nb(vp.tbox("axe_head", (0.0026, 0.0092, 0.0072), (-0.024, -0.004, 0.0226), "stone_dark", 18, 0, 10)))
    p.append(qk.rod((-0.024, -0.004, 0.0226), (-0.021, 0.012, 0.039), 0.0028, "wood_light"))
    lx, ly = LOG_AT
    lg = log_y(0.0050, 0.044, (lx, ly, 0.0050), "wood_mid", "wall_cream", rz=8)
    lg.append(nb(vp.tcyl("branch", 0.0024, 0.011, (lx + 0.0025, ly + 0.002, 0.0072), "wood_dark", 6, rx=38, rz=-25)))
    return p, lg


def variant_D():
    """Crossed-X sawhorse cradling cordwood billets lashed with twine + roped hearth log."""
    p = []
    # two X sawhorse legs cleanly intersecting at z = 0
    for sx in (-1, 1):
        for ang in (-34, 34):
            p.append(nb(vp.tbox("xleg", (0.0038, 0.0038, 0.028), (sx * 0.017, 0.0, 0.0115), "wood_dark", ang, 0, 0)))
    p.append(nb(box("crossbar", (0.038, 0.0036, 0.0036), (0, 0, 0.0115), "wood_mid")))
    # bundle of long logs along X resting inside the X-Vee saddle
    for dy, dz, col in ((0.0, 0.0175, "wood_mid"), (-0.0055, 0.0215, "wood_dark"), (0.0055, 0.0215, "wood_light"),
                        (0.0, 0.0260, "wood_dark")):
        p += log_x(0.0042, 0.048, (0, dy, dz), col, "wall_cream")
    p.append(nb(box("rope_l", (0.0025, 0.017, 0.015), (-0.009, 0, 0.0215), "path_dirt")))
    p.append(nb(box("rope_r", (0.0025, 0.017, 0.015), (0.009, 0, 0.0215), "path_dirt")))
    lx, ly = LOG_AT
    lg = log_y(0.0050, 0.044, (lx, ly, 0.0050), "wood_dark", "wall_cream", rz=12)
    lg.append(nb(vp.tcyl("tie", 0.0055, 0.0032, (lx, ly, 0.0050), "path_dirt", 6, rx=90, rz=12)))
    return p, lg


VARIANTS = {
    "A": ("Stacked cordwood pyramid between end-stakes on stone skids + knotted round log", variant_A),
    "B": ("Covered terracotta-shingle woodshed rack + split pale-hearted billet log", variant_B),
    "C": ("Stone-backed stack & chopping stump with wedged hatchet + forked hearth log", variant_C),
    "D": ("Crossed-X sawhorse holding tied cordwood bundle + twine-bound fireplace log", variant_D),
}

def _ground_parts(parts):
    zmin = min(v.co.z for o in parts for v in o.data.vertices)
    if abs(zmin) > 1e-5:
        for o in parts:
            for v in o.data.vertices:
                v.co.z -= zmin
    return parts


if __name__ == "__main__":
    qk.bc.clear_scene()
    L = qk.letter_arg()
    pile, single_log = VARIANTS[L][1]()
    _ground_parts(pile)
    _ground_parts(single_log)
    groups = [("", pile, (0, 0, 0), None), ("log", single_log, (LOG_AT[0], LOG_AT[1], 0.0), "")]
    qk.finish(L, "firewood", groups, "2x1", "near_house")
