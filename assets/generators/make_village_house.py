"""Village houses (asset list V01-V03): design variants A-D, each in an open and a shuttered state.

    blender --factory-startup -b -P assets/generators/make_village_house.py -- A        (variant A, open)
    blender --factory-startup -b -P assets/generators/make_village_house.py -- A shut   (variant A, shuttered)

Siddharth (2026-10-19): three DIFFERENT house shapes (one per roof colour), ideas from the moodboard's
"vibes for the civilian houses" (#4, #6, #5; shape language only, never copied) and the v01 benchmark house.
The variants show different shuttered looks. Parts the final houses get: a door that opens, a chimney socket
(smoke + blocked-chimney rubble anchors), lit windows as their own glow part, a lantern hook by the door.
Role (GAME_SPEC): what the enemies attack; a house at 0 HP is shuttered (closed up, not destroyed) and repaired
free next day. 2 x 2 cells, about 3-4 cells tall, no plinth wider than the walls (art bible).

Variants (roof colours are suggestions; the 3 roof colours get assigned to the 3 picked shapes):
    A  Dormer Cottage    (#4)  cream walls, steep roof with a front dormer, door canopy; shutters SWING shut
    B  Little Gable      (#6)  small gable-front cottage with a lean-to shed;              windows BOARDED up
    C  Log Cabin         (#5)  log walls, big A-frame roof, front porch on posts;          slatted shutters ROLL down
    D  Timber Townhouse        two storeys, half-timbered, jettied upper floor, tall chimney; shutters FLAP down
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import blender_common as bc  # noqa: E402

NAME = "ew_village_house_v01"


def place(objs, rot, loc):
    for o in objs:
        bc.rotate(o, rot)
        o.location = (o.location[0] + loc[0], o.location[1] + loc[1], o.location[2] + loc[2])
        bc.apply_transforms(o)
    return objs


def tilted(name, size, rot, loc, col):
    """Box rotated after building; bevel judged by its real thickness, not its fat bounding box."""
    o = bc.box(name, size, (0, 0, 0), col)
    bc.rotate(o, rot)
    o.location = loc
    bc.apply_transforms(o)
    o["ew_min_dim"] = min(size)
    return o


# ---- roof ---------------------------------------------------------------------------------------

def roof(span, length, h, z0, col, gable_col, oh=0.007, thick=0.0045, axis="y", at=(0, 0)):
    """Gable roof over a span x length rectangle whose wall tops are at z0. Two slabs with an overhang of
    oh on every side, and a gable infill prism in gable_col. axis = direction of the ridge."""
    s = span / 2
    a = math.atan2(h, s)
    L = (s + oh) / math.cos(a)  # eave to ridge along the slope (top surfaces meet exactly at the ridge)
    parts = []
    for side in (-1, 1):
        ex, ez = side * (s + oh), z0 - oh * math.tan(a)       # eave point on the top surface
        mx, mz = (ex + 0) / 2, (ez + z0 + h) / 2              # midpoint of the top surface line
        nx, nz = side * math.sin(a), math.cos(a)              # outward normal
        slab = tilted("roof", (L, length + 2 * oh, thick), (0, side * math.degrees(a), 0),
                      (mx - nx * thick / 2, 0, mz - nz * thick / 2), col)
        parts.append(slab)
    drop = 0.5 * thick / math.cos(a)  # infill sits inside the slabs, so the slopes never z-fight
    infill = bc.gable("gable", span, length, h, (0, 0, z0 - drop), gable_col)
    infill["no_bevel"] = True
    parts.append(infill)
    if axis == "x":
        place(parts, (0, 0, 90), (0, 0, 0))
    return place(parts, (0, 0, 0), (at[0], at[1], 0))


def roof_z(h, span, dist_from_ridge, z0):
    """Height of the roof's top surface at a horizontal distance from the ridge."""
    return z0 + h - dist_from_ridge * h / (span / 2)


# ---- openings (built facing -Y at the origin, then placed on a wall) ----------------------------

FACES = {"front": 0, "right": 90, "back": 180, "left": -90}


def on_wall(parts, face, along, z, half_w, half_d):
    """Move parts built on the -Y face at x=along to the given wall face of a half_w x half_d box."""
    deg = FACES[face]
    if face == "front":
        loc = (along, -half_d, z)
    elif face == "back":
        loc = (-along, half_d, z)
    elif face == "right":
        loc = (half_w, along, z)
    else:
        loc = (-half_w, -along, z)
    return place(parts, (0, 0, deg), loc)


def window(w, h, frame, state, style, shutter_col, lit=True):
    """Window centred on the origin, glass facing -Y. Returns (parts, glass parts)."""
    p = [bc.box("frame", (w + 0.006, 0.004, h + 0.006), (0, -0.001, 0), frame),
         bc.box("sill", (w + 0.010, 0.007, 0.003), (0, -0.003, -h / 2 - 0.0045), frame)]
    glass = bc.box("glass", (w, 0.004, h), (0, -0.0025, 0), "lantern_glow")
    if state == "open" and lit:
        bc.paint(glass, "lantern_glow", glow=True)
    else:
        bc.paint(glass, "ink")
    p += [bc.box("mullion", (0.0018, 0.003, h), (0, -0.005, 0), frame),
          bc.box("mullion", (w, 0.003, 0.0018), (0, -0.005, 0), frame)]
    hw = w / 2
    if style == "swing":
        if state == "open":  # leaves folded back against the wall either side
            for sx in (-1, 1):
                p.append(bc.box("shutter", (hw + 0.001, 0.003, h + 0.004), (sx * (hw + 0.004 + hw / 2), -0.0015, 0), shutter_col))
        else:                # leaves closed over the glass, a dark line where they meet
            for sx in (-1, 1):
                p.append(bc.box("shutter", (hw + 0.0015, 0.003, h + 0.004), (sx * (hw / 2 + 0.0004), -0.0078, 0), shutter_col))
    elif style == "boards" and state != "open":
        for deg in (32, -32):
            p.append(tilted("board", (w + 0.010, 0.003, 0.0055), (0, deg, 0), (0, -0.0050, 0), "wood_light"))  # critic v01: ends rest on the frame
    elif style == "roll":
        p.append(bc.cone("roll", 0.0035, 0.0035, w + 0.006, (0, 0, 0), shutter_col, 6))
        place([p[-1]], (0, 90, 0), (0, -0.004, h / 2 + 0.0055))
        if state != "open":
            p.append(bc.box("slats", (w + 0.003, 0.003, h + 0.002), (0, -0.0078, 0), shutter_col))
            for k in (-1, 0, 1):
                p.append(bc.box("slat_line", (w + 0.003, 0.003, 0.0012), (0, -0.0085, k * h / 4), "wood_dark"))
    elif style == "flap":
        if state == "open":  # propped out on its top hinge
            p.append(tilted("flap", (w + 0.004, 0.003, h + 0.004), (-55, 0, 0),
                            (0, -0.0035 - (h / 2) * math.sin(math.radians(55)), h / 2 + 0.003 - (h / 2) * math.cos(math.radians(55))), shutter_col))
        else:
            p.append(bc.box("flap", (w + 0.004, 0.003, h + 0.004), (0, -0.0078, 0), shutter_col))
    return p, [glass]


def door(w, h, frame, state, style, col="wood_dark"):
    """Door with its bottom at z=0, facing -Y. Returns (frame parts, door leaf parts)."""
    fr = [bc.box("door_frame", (w + 0.006, 0.004, h + 0.003), (0, -0.001, h / 2 + 0.0015), frame)]
    leaf = [bc.box("door", (w, 0.004, h), (0, -0.0025, h / 2), col),
            bc.box("door_plank", (0.0012, 0.0012, h * 0.9), (0, -0.0049, h / 2), "ink"),
            bc.box("knob", (0.003, 0.003, 0.003), (w * 0.32, -0.0055, h * 0.48), "stone")]
    if state != "open" and style in ("boards", "roll"):
        fr.append(bc.box("door_bar", (w + 0.012, 0.004, 0.005), (0, -0.0060, h * 0.52), "wood_light"))
    return fr, leaf


def lantern_hook(frame):
    """Small bracket by the door; the returned lantern (V15) hangs from its tip."""
    return [bc.box("hook_plate", (0.004, 0.003, 0.008), (0, -0.0015, 0), frame),
            bc.box("hook_arm", (0.0025, 0.010, 0.0025), (0, -0.0065, 0.003), frame),
            bc.box("hook_tip", (0.0025, 0.0025, 0.004), (0, -0.0105, 0.0005), "ink")]


def chimney(x, y, z_bottom, z_top, w, col, cap="stone_dark"):
    """Chimney with a cap and a dark socket on top (smoke and rubble anchors sit in it)."""
    hgt = z_top - z_bottom
    return [bc.box("chimney", (w, w, hgt), (x, y, z_bottom + hgt / 2), col),
            bc.box("chimney_cap", (w + 0.005, w + 0.005, 0.004), (x, y, z_top + 0.001), cap),
            bc.box("chimney_hole", (w - 0.005, w - 0.005, 0.002), (x, y, z_top + 0.0026), "ink")]


def openings(spec, half_w, half_d, frame, state, style, shutter_col):
    """spec: list of (kind, face, along, z, w, h)."""
    parts = []
    for kind, face, along, z, w, h in spec:
        if kind == "window":
            p, g = window(w, h, frame, state, style, shutter_col)
            parts += on_wall(p + g, face, along, z, half_w, half_d)
        elif kind == "door":
            f, leaf = door(w, h, frame, state, style)
            parts += on_wall(f + leaf, face, along, z, half_w, half_d)
        elif kind == "hook":
            parts += on_wall(lantern_hook(frame), face, along, z, half_w, half_d)
    return parts


# ---- the four ideas ------------------------------------------------------------------------------

def variant_a(state):
    """Dormer Cottage (#4): cream walls on a flush stone course, steep roof (ridge left-right) with a front
    dormer, little canopy over the door, stone chimney on the right. Shutters swing shut."""
    W, D, H, RH = 0.078, 0.064, 0.060, 0.064
    roof_col, frame, shut = "roof_terracotta", "wood_dark", "wood_dark"
    p = [bc.box("base", (W, D, 0.008), (0, 0, 0.004), "stone"),
         bc.box("walls", (W, D, H - 0.008), (0, 0, 0.008 + (H - 0.008) / 2), "wall_cream")]
    p += roof(D, W, RH, H, roof_col, "wall_cream", axis="x")
    # dormer on the front slope
    yf = -(D / 2 - 0.010)
    zb = roof_z(RH, D, D / 2 - 0.010, H) - 0.003
    p.append(bc.box("dormer", (0.026, 0.030, 0.022), (0, yf + 0.015, zb + 0.011), "wall_cream"))
    p += roof(0.026, 0.030, 0.013, zb + 0.022, roof_col, "wall_cream", oh=0.004, thick=0.0035, at=(0, yf + 0.015))
    wp, wg = window(0.012, 0.011, frame, state, "swing", shut)
    p += place(wp + wg, (0, 0, 0), (0, yf, zb + 0.011))
    # door canopy
    p += roof(0.024, 0.010, 0.007, 0.041, roof_col, "wall_cream", oh=0.003, thick=0.003, at=(-0.016, -D / 2 - 0.005))
    p += openings([("door", "front", -0.016, 0.008, 0.017, 0.030),
                   ("window", "front", 0.020, 0.030, 0.016, 0.016),
                   ("hook", "front", -0.031, 0.030, 0, 0),
                   ("window", "right", 0.0, 0.032, 0.016, 0.016),
                   ("window", "left", 0.0, 0.032, 0.016, 0.016),
                   ("window", "back", 0.0, 0.032, 0.016, 0.016)], W / 2, D / 2, frame, state, "swing", shut)
    p.append(bc.box("step", (0.022, 0.008, 0.004), (-0.016, -D / 2 - 0.004, 0.002), "stone"))
    p += chimney(0.026, 0.012, 0.050, H + RH + 0.010, 0.014, "stone")
    return p


def variant_b(state):
    """Little Gable (#6): small cream cottage with its gable to the front (attic window in the gable), a
    lean-to shed on the left, light chimney. Windows boarded up when shuttered."""
    W, D, H, RH = 0.062, 0.070, 0.056, 0.050
    roof_col, frame = "roof_orange", "wood_dark"
    x0 = -0.009  # main house shifted left so the lean-to sits on the right, where the camera sees it
    p = [bc.box("base", (W, D, 0.006), (x0, 0, 0.003), "stone"),
         bc.box("walls", (W, D, H - 0.006), (x0, 0, 0.006 + (H - 0.006) / 2), "wall_cream")]
    p += roof(W, D, RH, H, roof_col, "wall_cream", at=(x0, 0))
    # lean-to shed: plank walls and a one-slope roof against the house (critic v01: closed ends, inside the cell)
    sw, sh, rise = 0.020, 0.034, 0.0085
    xw = x0 + W / 2
    sx = xw + sw / 2
    p.append(bc.box("shed", (sw, 0.044, sh), (sx, 0.008, sh / 2), "wood_light"))
    wedge = bc.gable("shed_gable", 2 * sw, 0.044, rise, (xw, 0.008, sh - 0.0015), "wood_light")
    wedge["no_bevel"] = True
    p.append(wedge)
    for k in range(3):
        p.append(bc.box("shed_plank", (0.0012, 0.0012, 0.030), (xw + 0.005 + k * 0.005, 0.008 - 0.0225, 0.017), "wood_dark"))
    ang = math.degrees(math.atan2(rise, sw))
    p.append(tilted("shed_roof", (sw + 0.008, 0.050, 0.0035), (0, ang, 0),
                    (sx + 0.002, 0.008, sh - 0.0015 + rise / 2 - 0.002 * math.tan(math.radians(ang)) + 0.0017), roof_col))
    attic, ag = window(0.011, 0.011, frame, state, "boards", "wood_dark")
    p += place(attic + ag, (0, 0, 0), (x0, -D / 2 - 0.0005, H + 0.016))
    o = openings([("door", "front", 0.0, 0.006, 0.017, 0.031),
                  ("hook", "front", -0.016, 0.030, 0, 0),
                  ("window", "left", -0.012, 0.030, 0.016, 0.016),
                  ("window", "left", 0.018, 0.030, 0.016, 0.016),
                  ("window", "back", 0.0, 0.030, 0.016, 0.016)], W / 2, D / 2, frame, state, "boards", "wood_dark")
    p += place(o, (0, 0, 0), (x0, 0, 0))
    p.append(bc.box("step", (0.022, 0.008, 0.004), (x0, -D / 2 - 0.004, 0.002), "stone"))
    p += chimney(x0 - 0.014, 0.016, 0.050, H + RH + 0.004, 0.012, "wall_cream")  # bone is a threat colour (art bible)
    return p


def variant_c(state):
    """Log Cabin (#5): stacked log walls with crossed corners, big steep A-frame roof (gable to the front,
    dark plank gable), covered porch on two posts with a plank deck. Slatted shutters roll down."""
    W, D, H, RH = 0.070, 0.058, 0.054, 0.060
    roof_col, frame, shut = "roof_teal", "wood_dark", "wood_dark"
    y0 = 0.008  # cabin set back to make room for the porch (critic v01: whole cabin inside 0.095 m)
    p = [bc.box("core", (W - 0.004, D - 0.004, H), (0, y0, H / 2), "wood_dark")]
    n, ch = 6, H / 6
    for k in range(n):
        z = ch * (k + 0.5)
        for sy in (-1, 1):  # front/back logs run past the corners
            p.append(bc.box("log", (W + 0.010, 0.006, ch * 0.86), (0, y0 + sy * (D / 2 - 0.001), z), "wood_light"))
        for sx in (-1, 1):
            p.append(bc.box("log", (0.006, D - 0.004, ch * 0.86), (sx * (W / 2 - 0.001), y0, z), "wood_light"))
    p += roof(W, D, RH, H, roof_col, "wood_dark", oh=0.007, at=(0, y0))
    # porch: deck, two posts, a one-slope roof
    py0, py1 = -0.037, y0 - D / 2
    p.append(bc.box("deck", (W, py1 - py0, 0.006), (0, (py0 + py1) / 2, 0.003), "wood_light"))
    for sx in (-1, 1):
        p.append(bc.box("post", (0.005, 0.005, 0.040), (sx * (W / 2 - 0.006), py0 + 0.004, 0.026), "wood_dark"))
    p.append(tilted("porch_roof", (W - 0.006, py1 - py0 + 0.010, 0.004), (14, 0, 0), (0, (py0 + py1) / 2 - 0.002, 0.048), roof_col))
    o = openings([("door", "front", 0.0, 0.006, 0.017, 0.032),
                  ("window", "front", 0.023, 0.028, 0.013, 0.014),
                  ("window", "front", -0.023, 0.028, 0.013, 0.014),
                  ("window", "right", 0.0, 0.030, 0.016, 0.015),
                  ("window", "left", 0.0, 0.030, 0.016, 0.015)], W / 2 + 0.002, D / 2 + 0.002, frame, state, "roll", shut)
    p += place(o, (0, 0, 0), (0, y0, 0))
    p += place(lantern_hook(frame), (0, 0, 0), (-(W / 2 - 0.006), py0 + 0.0015, 0.034))  # critic v01: on the left porch post
    gw, gg = window(0.012, 0.012, frame, state, "roll", shut)
    p += place(gw + gg, (0, 0, 0), (0, y0 - D / 2 - 0.0005, H + 0.020))
    p += chimney(-0.022, y0 + 0.012, 0.040, H + RH + 0.002, 0.013, "stone")
    return p


def variant_d(state):
    """Timber Townhouse: two storeys, cream with dark half-timbering, the upper floor jutting out over the
    lower, steep roof (ridge left-right), tall chimney. Shutters hinge at the top and flap down."""
    W, D, H1, H2, RH = 0.068, 0.058, 0.048, 0.044, 0.056
    roof_col, frame, shut = "roof_terracotta", "wood_dark", "roof_teal"
    J = 0.004  # jetty: upper floor overhang front and back
    p = [bc.box("base", (W, D, 0.008), (0, 0, 0.004), "stone"),
         bc.box("lower", (W, D, H1 - 0.008), (0, 0, 0.008 + (H1 - 0.008) / 2), "wall_cream"),
         bc.box("floor_beam", (W + 0.006, D + 2 * J + 0.003, 0.005), (0, 0, H1 + 0.0025), "wood_dark"),
         bc.box("upper", (W + 0.004, D + 2 * J, H2), (0, 0, H1 + 0.005 + H2 / 2), "wall_cream")]
    zt = H1 + 0.005 + H2
    p += roof(D + 2 * J, W + 0.004, RH, zt, roof_col, "wall_cream", axis="x")
    # half-timbering on the upper front and back: corner posts, a middle post, two braces
    for sy in (-1, 1):
        y = sy * (D / 2 + J + 0.0012)
        for x in (-(W / 2 + 0.002) + 0.002, 0.0, (W / 2 + 0.002) - 0.002):
            p.append(bc.box("timber", (0.004, 0.0026, H2), (x, y, H1 + 0.005 + H2 / 2), "wood_dark"))
        for sx in (-1, 1):
            p.append(tilted("brace", (0.014, 0.0026, 0.0035), (0, sx * 38, 0), (sx * 0.0285, y, H1 + 0.012), "wood_dark"))
    for sx in (-1, 1):  # corner posts on the lower floor
        for sy in (-1, 1):
            p.append(bc.box("timber", (0.004, 0.004, H1 - 0.008), (sx * (W / 2 - 0.0015), sy * (D / 2 - 0.0015) + sy * 0.0012, 0.008 + (H1 - 0.008) / 2), "wood_dark"))
    p += openings([("door", "front", -0.016, 0.008, 0.016, 0.030),
                   ("window", "front", 0.018, 0.028, 0.014, 0.014),
                   ("hook", "front", -0.027, 0.030, 0, 0),
                   ("window", "back", 0.0, 0.028, 0.014, 0.014)], W / 2, D / 2, frame, state, "flap", shut)
    up = openings([("window", "front", -0.014, H1 + 0.026, 0.012, 0.013),
                   ("window", "front", 0.014, H1 + 0.026, 0.012, 0.013),
                   ("window", "right", 0.0, H1 + 0.026, 0.014, 0.013),
                   ("window", "left", 0.0, H1 + 0.026, 0.014, 0.013)], W / 2 + 0.002, D / 2 + J, frame, state, "flap", shut)
    p += up
    p.append(bc.box("step", (0.020, 0.008, 0.004), (-0.016, -D / 2 - 0.004, 0.002), "stone"))
    p += chimney(0.022, -0.010, 0.080, zt + RH + 0.014, 0.013, "stone")
    return p


VARIANTS = {"A": variant_a, "B": variant_b, "C": variant_c, "D": variant_d}


# ---- final houses (Siddharth 2026-10-19: A, C, D; broken state + tumble animation) ----------------------
#
# Three assets. A 0 HP house is HALF COLLAPSED (Siddharth 2026-10-19, after "damaged but standing" read too
# weakly): one whole roof side falls in (its rafters stay, some snapped and sticking up), a corner of the walls
# is knocked out (dark inside), the chimney topples and lands in the breach, the door hangs off its top hinge,
# the windows go dark and a big rubble pile spreads round the house up to the 2 x 2 edge. Godot tweens each
# moving part to its "<name>__<part>_broken" marker (same parent, full transform incl. scale) under a dust puff;
# the dawn repair plays it backwards. Parts:
#   __roof_fall    the whole fallen roof side (with the cottage's dormer): drops toward the rubble and shrinks to
#                  nothing (marker scale 0.001) - it "becomes" the rubble under the dust
#   __wall_corner  the knocked-out corner block (with the windows in it): same, drops and shrinks
#   __chimney      snapped top: falls and lies on its side in the breach
#   __door         pivot at the hinge (also __door_open: inward, for villagers going in at dusk)
#   __rubble       spread pile, __rafters snapped rafter stubs: intact scale 0.001 -> broken scale 1
#                  (glTF extra ew_starts_hidden)
#   __windows      glow glass (no marker; extra ew_broken = "off": Godot switches it off, dark glass behind)
# Static rafters, a ridge beam and dark linings sit under the roof all the time (hidden while it is whole).
# VFX anchors: __smoke_anchor + __rubble_anchor (chimney socket), __lantern_anchor (hook tip, the lost lantern
# hangs here), __dust_anchor (collapse and repair puff, later rising dust/smoke).

import random  # noqa: E402

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

FINAL = {"cottage": "ew_village_cottage_v02", "cabin": "ew_village_cabin_v02", "townhouse": "ew_village_townhouse_v02"}
TINY = 0.001  # scale of parts that are hidden (not yet appeared / already gone)


def put(parts, M):
    for o in parts:
        o.matrix_world = M @ o.matrix_world
        bc.apply_transforms(o)
    return parts


def face_matrix(face, along, z, half_w, half_d):
    deg = FACES[face]
    loc = {"front": (along, -half_d, z), "back": (-along, half_d, z),
           "right": (half_w, along, z), "left": (-half_w, -along, z)}[face]
    return Matrix.Translation(loc) @ Matrix.Rotation(math.radians(deg), 4, "Z")


def win_final(w, h, frame, style, shutter_col):
    """Window, glass facing -Y. Returns (static parts, glow glass). Shutters stay in their open pose."""
    static = [bc.box("frame", (w + 0.006, 0.004, h + 0.006), (0, -0.001, 0), frame),
              bc.box("sill", (w + 0.010, 0.007, 0.003), (0, -0.003, -h / 2 - 0.0045), frame),
              bc.box("dark_glass", (w, 0.001, h), (0, -0.0035, 0), "ink"),  # shows when the glow is off
              bc.box("mullion", (0.0018, 0.003, h), (0, -0.005, 0), frame),
              bc.box("mullion", (w, 0.003, 0.0018), (0, -0.005, 0), frame)]
    glass = bc.box("glass", (w, 0.004, h), (0, -0.0025, 0), "lantern_glow")
    bc.paint(glass, "lantern_glow", glow=True)
    hw = w / 2
    if style == "swing":
        for sx in (-1, 1):
            static.append(bc.box("shutter", (hw + 0.001, 0.003, h + 0.004), (sx * (hw + 0.004 + hw / 2), -0.0015, 0), shutter_col))
    elif style == "roll":
        r = bc.cone("roll", 0.0035, 0.0035, w + 0.006, (0, 0, 0), shutter_col, 6)
        static += put([r], Matrix.Translation((0, -0.004, h / 2 + 0.0055)) @ Matrix.Rotation(math.radians(90), 4, "Y"))
    elif style == "flap":  # propped 35 degrees so side flaps stay inside the 2 x 2 cells
        a = math.radians(35)
        static.append(tilted("flap", (w + 0.004, 0.003, h + 0.004), (-35, 0, 0),
                             (0, -0.0035 - (h / 2) * math.sin(a), h / 2 + 0.003 - (h / 2) * math.cos(a)), shutter_col))
    return static, [glass]


def door_final(w, h, frame):
    """Door, bottom at z=0, facing -Y. Returns (static frame + dark doorway, leaf parts, hinge point)."""
    static = [bc.box("door_frame", (w + 0.006, 0.004, h + 0.003), (0, -0.001, h / 2 + 0.0015), frame),
              bc.box("doorway", (w, 0.001, h), (0, -0.0035, h / 2), "ink")]
    leaf = [bc.box("door", (w, 0.004, h), (0, -0.0025, h / 2), "wood_dark"),
            bc.box("door_plank", (0.0012, 0.0012, h * 0.9), (0, -0.0049, h / 2), "ink"),
            bc.box("knob", (0.003, 0.003, 0.003), (w * 0.32, -0.0055, h * 0.48), "stone")]
    return static, leaf, Vector((-w / 2, -0.0025, 0))


def bounds(objs):
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    return (Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))),
            Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))))


def centre(objs):
    lo, hi = bounds(objs)
    return (lo + hi) / 2


class House:
    """Collects static parts, moving parts, pivots and anchor points while a house is built."""

    def __init__(self, notch):
        self.static, self.glow, self.door, self.rubble, self.rafters = [], [], [], [], []
        self.roof_fall, self.chimney, self.corner = [], [], []
        self.hinge = self.door_m = self.chim = self.lantern = self.smoke = self.ridge = None
        self.notch = notch  # (x0, y1, z0): the knocked-out corner is x > x0, y < y1, z > z0 (front-right, top)

    def in_notch(self, p):
        x0, y1, z0 = self.notch
        return p.x > x0 and p.y < y1 and p.z > z0

    def wall_box(self, name, size, loc, col, no_bevel=False):
        """A wall box, split so the part inside the notch becomes the knocked-out corner."""
        sx, sy, sz = size
        b0 = Vector(loc) - Vector(size) / 2
        b1 = Vector(loc) + Vector(size) / 2
        x0, y1, z0 = self.notch
        ix0, iy1, iz0 = max(b0.x, x0), min(b1.y, y1), max(b0.z, z0)
        pieces = []
        if ix0 >= b1.x or iy1 <= b0.y or iz0 >= b1.z:  # no overlap with the notch
            pieces.append(("s", b0, b1))
        else:
            if iz0 > b0.z:
                pieces.append(("s", b0, Vector((b1.x, b1.y, iz0))))
            if ix0 > b0.x:
                pieces.append(("s", Vector((b0.x, b0.y, iz0)), Vector((ix0, b1.y, b1.z))))
            if b1.y > iy1:
                pieces.append(("s", Vector((ix0, iy1, iz0)), Vector((b1.x, b1.y, b1.z))))
            pieces.append(("c", Vector((ix0, b0.y, iz0)), Vector((b1.x, iy1, b1.z))))
        for kind, lo, hi in pieces:
            o = bc.box(name, tuple(hi - lo), tuple((lo + hi) / 2), col)
            if no_bevel:
                o["no_bevel"] = True
            (self.corner if kind == "c" else self.static).append(o)

    def split_gables(self):
        """Gable end walls whose lower corner sits over the knocked-out corner: cut off the part over the notch
        and move it into __wall_corner (critic v02: it hung in the air once the corner fell)."""
        x0, y1, z0 = self.notch
        for g in [o for o in self.static if o.name.startswith("gable")]:
            lo, hi = bounds([g])
            if lo.x >= x0 - 1e-6 and lo.y < y1:
                plane_co, plane_no, corner_side = Vector((0, y1, 0)), Vector((0, 1, 0)), -1  # corner part: y < y1
            elif hi.y <= y1 + 1e-6 and hi.x > x0:
                plane_co, plane_no, corner_side = Vector((x0, 0, 0)), Vector((1, 0, 0)), 1   # corner part: x > x0
            else:
                continue
            c = g.copy()
            c.data = g.data.copy()
            bpy.context.collection.objects.link(c)
            for obj, keep_corner in ((g, False), (c, True)):
                bm = bmesh.new()
                bm.from_mesh(obj.data)
                # clear_outer removes the side the normal points to; keep the side we want
                outer_is_corner = corner_side == 1
                res = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=plane_co,
                                             plane_no=plane_no, clear_outer=(outer_is_corner != keep_corner),
                                             clear_inner=(outer_is_corner == keep_corner))
                cut = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
                if cut:
                    bmesh.ops.contextual_create(bm, geom=cut)
                bm.to_mesh(obj.data)
                bm.free()
            c["no_bevel"] = True
            self.corner.append(c)

    def notch_lining(self, x_right, y_front, z_top):
        """Dark faces inside the notch (hidden inside the corner block until it is knocked out)."""
        x0, y1, z0 = self.notch
        e = 0.0006
        for size, loc in (((0.001, y1 - y_front, z_top - z0), (x0 + e, (y1 + y_front) / 2, (z0 + z_top) / 2)),
                          ((x_right - x0, 0.001, z_top - z0), ((x0 + x_right) / 2, y1 - e, (z0 + z_top) / 2)),
                          ((x_right - x0, y1 - y_front, 0.001), ((x0 + x_right) / 2, (y1 + y_front) / 2, z0 + e))):
            o = bc.box("notch_dark", size, loc, "ink")
            o["no_bevel"] = True
            self.static.append(o)

    def openings(self, spec, half_w, half_d, frame, style, shutter_col, M0=None):
        M0 = M0 if M0 is not None else Matrix.Identity(4)
        for kind, face, along, z, w, h in spec:
            F = M0 @ face_matrix(face, along, z, half_w, half_d)
            gone = self.in_notch(F @ Vector((0, 0, 0)))  # a window in the knocked-out corner goes with it
            if kind == "window":
                st, g = win_final(w, h, frame, style, shutter_col)
                (self.corner if gone else self.static).extend(put(st, F))
                self.glow += put(g, F)
            elif kind == "door":
                st, leaf, hinge = door_final(w, h, frame)
                self.static += put(st, F)
                self.door += put(leaf, F)
                self.hinge, self.door_m, self.door_h = F @ hinge, F, h
            elif kind == "hook":
                self.hook(F)

    def hook(self, F):
        self.static += put(lantern_hook("wood_dark"), F)
        self.lantern = F @ Vector((0, -0.0105, -0.002))


def roof_final(house, span, length, h, z0, col, gable_col, oh=0.007, thick=0.0045, axis="y", at=(0, 0),
               fall_side=1, gable_t=0.004, n_rafters=5):
    """Gable roof like roof() but hollow: thin gable end walls, a dark attic floor, a ridge beam, rafters under
    the fall side and a dark lining under the other side. The whole fall_side slab (local frame, ridge along Y)
    becomes __roof_fall; two snapped rafter stubs (__rafters) appear when it is gone."""
    s = span / 2
    a = math.atan2(h, s)
    L = (s + oh) / math.cos(a)
    full = length + 2 * oh
    Mrot = Matrix.Translation((at[0], at[1], 0))
    if axis == "x":
        Mrot = Mrot @ Matrix.Rotation(math.radians(90), 4, "Z")
    static, fall, stubs = [], [], []

    def line(side):
        return Vector((side * (s + oh), 0, z0 - oh * math.tan(a))), Vector((0, 0, z0 + h))

    def normal(side):
        return Vector((side * math.sin(a), 0, math.cos(a)))

    def slab(side):
        e, r = line(side)
        n = normal(side)
        o = tilted("roof", (L, full, thick), (0, side * math.degrees(a), 0), tuple((e + r) / 2 - n * thick / 2), col)
        o["no_bevel"] = True
        return o

    def stick(name, p0, p1, w, colr):
        d = p1 - p0
        rot = Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()
        o = bc.box(name, (w, w, d.length), (0, 0, d.length / 2), colr)
        put([o], Matrix.Translation(p0) @ rot)
        o["ew_min_dim"] = w
        return o

    for side in (-1, 1):
        if side == fall_side:
            fall.append(slab(side))
        else:
            static.append(slab(side))
            e, r = line(side)
            n = normal(side)
            p0, p1 = e.lerp(r, 0.2), e.lerp(r, 0.85)
            lin = tilted("lining", ((p1 - p0).length, length - 2 * gable_t - 0.001, 0.001), (0, side * math.degrees(a), 0),
                         tuple((p0 + p1) / 2 - n * (thick + 0.0007)), "ink")
            lin["no_bevel"] = True
            static.append(lin)
    drop = 0.5 * thick / math.cos(a)
    for sy in (-1, 1):  # thin gable end walls
        g = bc.gable("gable", span, gable_t, h - drop, (0, sy * (length / 2 - gable_t / 2), z0 - 0.0001), gable_col)
        g["no_bevel"] = True
        static.append(g)
    att = bc.box("attic", (span - 0.006, length - 0.006, 0.0012), (0, 0, z0 + 0.0006), "ink")
    att["no_bevel"] = True
    static.append(att)
    # ridge beam and rafters under the fall side (hidden under the roof while it is whole)
    rb_z = z0 + h - thick / math.cos(a) - 0.006
    static.append(bc.box("ridge_beam", (0.004, length - 2 * gable_t, 0.004), (0, 0, rb_z), "wood_dark"))
    e, r = line(fall_side)
    under = normal(fall_side) * (thick + 0.0022)
    inner = length / 2 - gable_t - 0.004
    ys = [-inner + k * (2 * inner) / (n_rafters - 1) for k in range(n_rafters)]
    snapped = {1, n_rafters - 2}
    for k, y in enumerate(ys):
        p0, p1 = e.lerp(r, 0.08) - under, e.lerp(r, 0.86) - under
        p0.y = p1.y = y
        if k in snapped:  # its lower half is a stub (static), its upper half juts up out of the hole (__rafters)
            mid = p0.lerp(p1, 0.45)
            static.append(stick("rafter", p0, mid, 0.0035, "wood_dark"))
            frac = 0.8 if k == 1 else 0.5  # critic v02: out along the roof normal so the tips clear the old roof line
            tip = mid + (p1 - mid).normalized() * (p1 - mid).length * frac + normal(fall_side) * 0.017
            tip.y += 0.004 if k == 1 else -0.004
            stubs.append(stick("rafter_snapped", mid, tip, 0.0035, "wood_dark"))
        else:
            static.append(stick("rafter", p0, p1, 0.0035, "wood_dark"))
    put(static + fall + stubs, Mrot)
    house.static += static
    house.roof_fall += fall
    house.rafters += stubs


def chimney_final(house, x, y, z_bottom, z_top, w, col, roof_surface_z, z_attic):
    """Short stump (static) 10 mm above the attic floor; the section from there up to just above the roof falls
    in with the roof (__roof_fall, critic v02: a tall stump read as a standing chimney); the snapped top
    (__chimney, with cap and dark socket) starts 3 mm inside that section, at the roof line + 4 mm."""
    zc = roof_surface_z + 0.004
    z_cut = max(z_bottom + 0.004, z_attic + 0.010)
    house.static.append(bc.box("chimney_stump", (w, w, z_cut - z_bottom), (x, y, (z_bottom + z_cut) / 2), col))
    mid = bc.box("chimney_mid", (w, w, zc - z_cut), (x, y, (z_cut + zc) / 2), col)
    mid["no_bevel"] = True  # mostly hidden inside the roof
    house.roof_fall.append(mid)
    house.chimney += chimney(x, y, zc - 0.003, z_top, w, col)
    house.chim = Vector((x, y, zc - 0.003))
    house.smoke = Vector((x, y, z_top + 0.004))


def rubble_spread(house, spots, roof_col, wall_col, seed):
    """Rubble around the house (appears when it breaks): spots = [(x, y, z, n)], n pieces near each spot.
    Stones, roof tiles, wall chunks and planks; tiles and planks rest on the stone under them."""
    rnd = random.Random(seed)
    kinds = [("stone", (0.010, 0.009, 0.008)), (roof_col, (0.013, 0.009, 0.003)), ("stone_dark", (0.008, 0.007, 0.006)),
             (wall_col, (0.010, 0.008, 0.007)), ("wood_light", (0.024, 0.005, 0.004)), (roof_col, (0.011, 0.008, 0.003)),
             ("stone", (0.007, 0.007, 0.006)), ("wood_dark", (0.020, 0.004, 0.004))]
    k = 0
    for x, y, z, n in spots:
        stones = []
        if n >= 3:  # critic v02: a low faceted heap gives each main spot some mass
            mound = bc.cone("rubble_heap", 0.010, 0.004, 0.007, (x, y, z + 0.0035), "stone_dark", 6, rnd.uniform(0, 60))
            mound["no_bevel"] = True
            lo, hi = bounds([mound])
            shift = Vector((max(0.0, -0.0485 - lo.x) - max(0.0, hi.x - 0.0485), max(0.0, -0.0485 - lo.y) - max(0.0, hi.y - 0.0485), 0))
            if shift.length:
                put([mound], Matrix.Translation(shift))
            house.rubble.append(mound)
            stones.append((x + shift.x, y + shift.y, z + 0.007))
        for i in range(n):
            col, size = kinds[k % len(kinds)]
            size = tuple(v * 1.3 for v in size)
            k += 1
            ox, oy = rnd.uniform(-0.006, 0.006), rnd.uniform(-0.003, 0.003)
            flat = col in (roof_col, "wood_light", "wood_dark")
            base = z
            if flat:
                under = [t for (sx_, sy_, t) in stones if abs(sx_ - x - ox) < 0.007 and abs(sy_ - y - oy) < 0.005]
                base = max(under) - 0.001 if under else z
            else:
                stones.append((x + ox, y + oy, z + size[2]))
            o = tilted("rubble", size, (rnd.uniform(-12, 12), rnd.uniform(-15, 15) if not flat else rnd.uniform(-6, 6),
                                        rnd.uniform(0, 180)), (x + ox, y + oy, base + size[2] / 2), col)
            o["no_bevel"] = True
            lo, hi = bounds([o])  # keep every piece inside the 2 x 2 cells
            shift = Vector((max(0.0, -0.0485 - lo.x) - max(0.0, hi.x - 0.0485), max(0.0, -0.0485 - lo.y) - max(0.0, hi.y - 0.0485), 0))
            if shift.length:
                put([o], Matrix.Translation(shift))
            house.rubble.append(o)


def cottage():
    """A: Dormer Cottage, terracotta roof, swing shutters. Front roof side (with the dormer) falls; front-right
    corner knocked out."""
    W, D, Hh, RH = 0.078, 0.064, 0.060, 0.064
    hs = House(notch=(0.008, -0.014, 0.022))
    roof_col, frame = "roof_terracotta", "wood_dark"
    hs.static.append(bc.box("base", (W, D, 0.008), (0, 0, 0.004), "stone"))
    hs.wall_box("walls", (W, D, Hh - 0.008), (0, 0, 0.008 + (Hh - 0.008) / 2), "wall_cream")
    hs.notch_lining(W / 2, -D / 2, Hh)
    # ridge along X: local side -1 is the front slope
    roof_final(hs, D, W, RH, Hh, roof_col, "wall_cream", axis="x", fall_side=-1)
    hs.split_gables()
    yf = -(D / 2 - 0.010)
    zb = roof_z(RH, D, D / 2 - 0.010, Hh) - 0.003
    dormer = [bc.box("dormer", (0.026, 0.030, 0.022), (0, yf + 0.015, zb + 0.011), "wall_cream")]
    dormer += roof(0.026, 0.016, 0.013, zb + 0.022, roof_col, "wall_cream", oh=0.004, thick=0.0035, at=(0, -0.016))
    st, g = win_final(0.012, 0.011, frame, "swing", frame)
    dormer += put(st, Matrix.Translation((0, yf, zb + 0.011)))
    hs.glow += put(g, Matrix.Translation((0, yf, zb + 0.011)))
    hs.roof_fall += dormer  # the dormer sits on the front slope, so it falls with it
    hs.static += roof(0.024, 0.010, 0.007, 0.041, roof_col, "wall_cream", oh=0.003, thick=0.003, at=(-0.016, -D / 2 - 0.005))
    hs.openings([("door", "front", -0.016, 0.008, 0.017, 0.030),
                 ("window", "front", 0.020, 0.030, 0.016, 0.016),
                 ("hook", "front", -0.031, 0.030, 0, 0),
                 ("window", "right", 0.0, 0.032, 0.016, 0.016),
                 ("window", "left", 0.0, 0.032, 0.016, 0.016),
                 ("window", "back", 0.0, 0.032, 0.016, 0.016)], W / 2, D / 2, frame, "swing", frame)
    hs.static.append(bc.box("step", (0.022, 0.008, 0.004), (-0.016, -D / 2 - 0.004, 0.002), "stone"))
    cx, cy = 0.026, 0.012
    chimney_final(hs, cx, cy, 0.062, Hh + RH + 0.010, 0.014, "stone", roof_z(RH, D, cy - 0.007, Hh), Hh)
    hs.land = (Vector((0.024, -0.023)), 0.022)  # the chimney lands in the breach (x, y on the notch floor, z)
    rubble_spread(hs, [(0.010, -0.041, 0.0, 5), (0.034, -0.040, 0.0, 4), (0.044, -0.020, 0.0, 3),
                       (-0.040, -0.041, 0.0, 2)], roof_col, "wall_cream", 1)
    return hs, Vector((0.010, -0.010, 0.05))


def cabin():
    """C: Log Cabin, teal roof, roll shutters. Right roof side falls; front-right corner of the logs knocked out."""
    W, D, Hh, RH = 0.070, 0.058, 0.054, 0.060
    y0 = 0.008
    hs = House(notch=(0.013, y0 - D / 2 + 0.017, 0.020))
    roof_col, frame = "roof_teal", "wood_dark"
    hs.wall_box("core", (W - 0.004, D - 0.004, Hh), (0, y0, Hh / 2), "wood_dark", no_bevel=True)  # only seen between logs
    ch = Hh / 5  # 5 courses (was 6): the knocked-out corner splits logs, and bevelled logs are the budget
    for k in range(5):
        z = ch * (k + 0.5)
        for sy in (-1, 1):
            hs.wall_box("log", (W + 0.010, 0.006, ch * 0.86), (0, y0 + sy * (D / 2 - 0.001), z), "wood_light")
        for sx in (-1, 1):
            hs.wall_box("log", (0.006, D - 0.004, ch * 0.86), (sx * (W / 2 - 0.001), y0, z), "wood_light")
    hs.notch_lining(W / 2 - 0.001, y0 - D / 2 + 0.002, Hh)
    roof_final(hs, W, D, RH, Hh, roof_col, "wood_dark", oh=0.007, at=(0, y0), fall_side=1)
    hs.split_gables()
    py0, py1 = -0.037, y0 - D / 2
    hs.static.append(bc.box("deck", (W, py1 - py0, 0.006), (0, (py0 + py1) / 2, 0.003), "wood_light"))
    for sx in (-1, 1):
        hs.static.append(bc.box("post", (0.005, 0.005, 0.040), (sx * (W / 2 - 0.006), py0 + 0.004, 0.026), "wood_dark"))
    hs.static.append(tilted("porch_roof", (W - 0.006, py1 - py0 + 0.010, 0.004), (14, 0, 0), (0, (py0 + py1) / 2 - 0.002, 0.048), roof_col))
    hs.openings([("door", "front", 0.0, 0.006, 0.017, 0.032),
                 ("window", "front", 0.023, 0.028, 0.013, 0.014),
                 ("window", "front", -0.023, 0.028, 0.013, 0.014),
                 ("window", "right", 0.0, 0.030, 0.016, 0.015),
                 ("window", "left", 0.0, 0.030, 0.016, 0.015)], W / 2 + 0.002, D / 2 + 0.002, frame, "roll", frame,
                Matrix.Translation((0, y0, 0)))
    hs.hook(Matrix.Translation((-(W / 2 - 0.006), py0 + 0.0015, 0.034)))
    st, g = win_final(0.012, 0.012, frame, "roll", frame)
    Mg = Matrix.Translation((0, y0 - D / 2 - 0.0005, Hh + 0.020))
    hs.static += put(st, Mg)
    hs.glow += put(g, Mg)
    cx, cy = -0.022, y0 + 0.012
    chimney_final(hs, cx, cy, 0.040, Hh + RH + 0.002, 0.013, "stone", roof_z(RH, W, abs(cx) - 0.0065, Hh), Hh)
    hs.land = (Vector((0.024, -0.014)), 0.020)
    rubble_spread(hs, [(0.024, -0.029, 0.006, 3), (0.004, -0.043, 0.0, 3), (0.042, -0.012, 0.0, 1)],
                  roof_col, "wood_light", 2)
    return hs, Vector((0.010, y0 - 0.006, 0.045))


def townhouse():
    """D: Timber Townhouse, orange roof, teal flap shutters. Front roof side falls; front-right corner of the
    upper floor knocked out."""
    W, D, H1, H2, RH = 0.068, 0.058, 0.048, 0.044, 0.056
    J = 0.004
    hs = House(notch=(0.004, -0.012, H1 + 0.005))
    roof_col, frame, shut = "roof_orange", "wood_dark", "roof_teal"
    hs.static += [bc.box("base", (W, D, 0.008), (0, 0, 0.004), "stone"),
                  bc.box("lower", (W, D, H1 - 0.008), (0, 0, 0.008 + (H1 - 0.008) / 2), "wall_cream"),
                  bc.box("floor_beam", (W + 0.006, D + 2 * J + 0.003, 0.005), (0, 0, H1 + 0.0025), "wood_dark")]
    hs.wall_box("upper", (W + 0.004, D + 2 * J, H2), (0, 0, H1 + 0.005 + H2 / 2), "wall_cream")
    zt = H1 + 0.005 + H2
    hs.notch_lining(W / 2 + 0.002, -(D / 2 + J), zt)
    roof_final(hs, D + 2 * J, W + 0.004, RH, zt, roof_col, "wall_cream", axis="x", fall_side=-1)
    hs.split_gables()
    timbers = []
    for sy in (-1, 1):
        y = sy * (D / 2 + J + 0.0012)
        for x in (-(W / 2 + 0.002) + 0.002, 0.0, (W / 2 + 0.002) - 0.002):
            timbers.append(bc.box("timber", (0.004, 0.0026, H2 - 0.005), (x, y, H1 + 0.005 + (H2 - 0.005) / 2), "wood_dark"))
        for sx in (-1, 1):
            timbers.append(tilted("brace", (0.014, 0.0026, 0.0035), (0, sx * 38, 0), (sx * 0.0285, y, H1 + 0.012), "wood_dark"))
    for t in timbers:  # timbers on the knocked-out corner go with it
        (hs.corner if hs.in_notch(centre([t])) else hs.static).append(t)
    for sx in (-1, 1):
        for sy in (-1, 1):
            hs.static.append(bc.box("timber", (0.004, 0.004, H1 - 0.008),
                                    (sx * (W / 2 - 0.0015), sy * (D / 2 - 0.0015) + sy * 0.0012, 0.008 + (H1 - 0.008) / 2), "wood_dark"))
    hs.openings([("door", "front", -0.016, 0.008, 0.016, 0.030),
                 ("window", "front", 0.018, 0.028, 0.014, 0.014),
                 ("hook", "front", -0.027, 0.030, 0, 0),
                 ("window", "back", 0.0, 0.028, 0.014, 0.014)], W / 2, D / 2, frame, "flap", shut)
    hs.openings([("window", "front", -0.014, H1 + 0.026, 0.012, 0.013),
                 ("window", "front", 0.014, H1 + 0.026, 0.012, 0.013),
                 ("window", "right", 0.0, H1 + 0.026, 0.014, 0.013),
                 ("window", "left", 0.0, H1 + 0.026, 0.014, 0.013)], W / 2 + 0.002, D / 2 + J, frame, "flap", shut)
    hs.static.append(bc.box("step", (0.020, 0.008, 0.004), (-0.016, -D / 2 - 0.004, 0.002), "stone"))
    cx, cy = 0.022, -0.010
    chimney_final(hs, cx, cy, 0.080, zt + RH + 0.014, 0.013, "stone", roof_z(RH, D + 2 * J, abs(cy) - 0.0065, zt), zt)
    hs.land = (Vector((0.020, -0.023)), H1 + 0.005)
    rubble_spread(hs, [(0.004, -0.039, 0.0, 4), (0.030, -0.038, 0.0, 5), (0.042, -0.012, 0.0, 3),
                       (-0.040, -0.039, 0.0, 2)], roof_col, "wall_cream", 3)
    return hs, Vector((0.012, -0.012, 0.07))


def lay_down(objs, pivot, target_xy, ground_z, yaw=20):
    """Marker matrix that lays a part (origin at pivot) on its side with its lowest point on ground_z and its
    centre over target_xy."""
    R = Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Rotation(math.radians(90), 4, "Y")
    pts = [R.to_3x3() @ ((o.matrix_world @ v.co) - pivot) for o in objs for v in o.data.vertices]
    cx = (min(p.x for p in pts) + max(p.x for p in pts)) / 2
    cy = (min(p.y for p in pts) + max(p.y for p in pts)) / 2
    t = Vector((target_xy.x - cx, target_xy.y - cy, ground_z - min(p.z for p in pts)))
    return Matrix.Translation(t) @ R


def pose(root, part, name, M):
    """Empty <root>__<name> holding the part's target world transform (parented to the root, like the part)."""
    bpy.context.view_layer.update()
    e = bpy.data.objects.new(root.name + "__" + name, None)
    bpy.context.collection.objects.link(e)
    e.empty_display_type = "ARROWS"
    e.empty_display_size = 0.01
    e["ew_pose_of"] = part
    e.parent = root
    e.matrix_world = M
    return e


def build_final(kind, state="intact"):
    hs, dust = {"cottage": cottage, "cabin": cabin, "townhouse": townhouse}[kind]()
    name = FINAL[kind]
    pile_c = centre(hs.rubble)
    pile_c.z = 0.0
    raf_c = centre(hs.rafters)
    fall_c = centre(hs.roof_fall)
    corner_c = centre(hs.corner)
    chim_land = lay_down(hs.chimney, hs.chim, *hs.land)
    root = bc.assemble(name, [
        ("", hs.static, (0, 0, 0), None),
        ("windows", hs.glow, (0, 0, 0.03), ""),
        ("door", hs.door, tuple(hs.hinge), ""),
        ("roof_fall", hs.roof_fall, tuple(fall_c), ""),
        ("wall_corner", hs.corner, tuple(corner_c), ""),
        ("chimney", hs.chimney, tuple(hs.chim), ""),
        ("rubble", hs.rubble, tuple(pile_c), ""),
        ("rafters", hs.rafters, tuple(raf_c), ""),
    ])
    bpy.data.objects[name + "__windows"]["ew_broken"] = "off"
    bc.anchor(root, "smoke_anchor", hs.smoke, parent_suffix="chimney", size=0.012)
    bc.anchor(root, "rubble_anchor", hs.smoke - Vector((0, 0, 0.005)), parent_suffix="chimney", size=0.008)
    bc.anchor(root, "lantern_anchor", hs.lantern, size=0.006)
    bc.anchor(root, "dust_anchor", dust, size=0.08)
    Fd = hs.door_m.to_3x3().to_4x4()
    # door hangs off its TOP hinge: swung 40 degrees out, free corner dropped 10 degrees
    top = hs.hinge + Fd.to_3x3() @ Vector((0, 0, hs.door_h))
    R_door = Fd @ Matrix.Rotation(math.radians(-40), 4, "Z") @ Matrix.Rotation(math.radians(10), 4, "Y") @ Fd.inverted()
    tiny = Matrix.Diagonal((TINY, TINY, TINY, 1))

    def gone(c, tilt):  # drops toward the rubble and shrinks away under the dust
        tgt = c.lerp(pile_c, 0.6)
        tgt.z = max(0.004, c.z * 0.25)
        return Matrix.Translation(tgt) @ Matrix.Rotation(math.radians(tilt), 4, "X") @ tiny

    poses = {"roof_fall": gone(fall_c, 35), "wall_corner": gone(corner_c, -25), "chimney": chim_land,
             "door": Matrix.Translation(top + R_door.to_3x3() @ (hs.hinge - top)) @ R_door,
             "rubble": Matrix.Translation(pile_c), "rafters": Matrix.Translation(raf_c)}
    for part, M in poses.items():
        pose(root, part, part + "_broken", M)
    pose(root, "door", "door_open", Matrix.Translation(hs.hinge) @ Fd @ Matrix.Rotation(math.radians(80), 4, "Z") @ Fd.inverted())
    for part in ("rubble", "rafters"):
        bpy.data.objects[name + "__" + part].scale = (TINY, TINY, TINY)
        bpy.data.objects[name + "__" + part]["ew_starts_hidden"] = True
    if state == "broken":  # preview only: every part in its broken pose, windows off
        bpy.context.view_layer.update()
        for part in poses:
            obj = bpy.data.objects[name + "__" + part]
            obj.matrix_world = bpy.data.objects[name + "__" + part + "_broken"].matrix_world.copy()
        bpy.data.objects[name + "__windows"].scale = (TINY, TINY, TINY)
    return root


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    v = args[0] if args else "A"
    state = args[1] if len(args) > 1 else "open"
    bc.clear_scene()
    if v in FINAL:  # final house: intact (saved + exported) or broken (preview blend only)
        obj = build_final(v, "broken" if state == "broken" else "intact")
        if state == "broken":
            print("BLEND", bc.save_blend(obj, v + "_broken"))
        else:
            print("BLEND", bc.save_blend(obj, v))
            print("EXPORT", bc.export_glb(obj, "village"))
        sys.exit(0)
    obj = build({"variant": v, "state": state})
    print("BLEND", bc.save_blend(obj, "village_house_%s%s" % (v, "_shut" if state != "open" else "")))
