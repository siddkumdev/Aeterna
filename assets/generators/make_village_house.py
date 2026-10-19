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
# Three assets. A 0 HP house is "damaged but standing": part of one roof side caves in (a hole with broken
# rafters), the chimney top snaps and leans on its stump, the door hangs off one hinge, the windows go dark,
# a rubble pile appears. Godot tweens each moving part from its intact transform to the matching
# "<name>__<part>_broken" marker (same parent, full transform) with a dust puff; repair at dawn plays it
# backwards. Parts and markers:
#   __roof_cave  hinge at the hole's lower edge          -> swings down into the house
#   __chimney    pivot on the stump, downhill edge       -> leans over (smoke/rubble anchors ride on it)
#   __door       pivot at the hinge (also __door_open: inward, for villagers going in at dusk)
#   __rubble     ground pile, __rafters broken beams in the hole: intact scale 0.001 -> broken scale 1
#   __windows    glow glass (no marker; extra ew_broken = "off": Godot switches it off, dark glass behind)
# VFX anchors: __smoke_anchor + __rubble_anchor (chimney socket), __lantern_anchor (hook tip, the lost lantern
# hangs here), __dust_anchor (collapse and repair puff).

import random  # noqa: E402

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

FINAL = {"cottage": "ew_village_cottage_v01", "cabin": "ew_village_cabin_v01", "townhouse": "ew_village_townhouse_v01"}
TINY = 0.001  # scale of parts hidden until the house breaks


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


class House:
    """Collects static parts, moving parts, pivots and anchor points while a house is built."""

    def __init__(self):
        self.static, self.glow, self.door, self.rubble, self.rafters = [], [], [], [], []
        self.roof_cave, self.chimney = [], []
        self.hinge = self.door_m = self.cave = self.chim = self.lantern = self.smoke = None
        self.lean = 40  # chimney lean when broken (degrees)

    def openings(self, spec, half_w, half_d, frame, style, shutter_col, M0=None):
        M0 = M0 if M0 is not None else Matrix.Identity(4)
        for kind, face, along, z, w, h in spec:
            F = M0 @ face_matrix(face, along, z, half_w, half_d)
            if kind == "window":
                st, g = win_final(w, h, frame, style, shutter_col)
                self.static += put(st, F)
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
               cave=None, gable_t=0.004):
    """Gable roof like roof() but hollow: thin gable end walls and a dark attic floor instead of a solid prism,
    so a hole shows darkness. cave = (side, u0, u1): the upper half of that slab between u0..u1 along the
    ridge (local frame, ridge along Y) becomes __roof_cave; two broken rafters go in the hole."""
    s = span / 2
    a = math.atan2(h, s)
    L = (s + oh) / math.cos(a)
    full = length + 2 * oh
    Mrot = Matrix.Translation((at[0], at[1], 0))
    if axis == "x":
        Mrot = Mrot @ Matrix.Rotation(math.radians(90), 4, "Z")
    static, cave_parts, rafters = [], [], []

    def line(side):
        return Vector((side * (s + oh), 0, z0 - oh * math.tan(a))), Vector((0, 0, z0 + h))

    def slab_piece(side, t0, t1, u0, u1, sink=0.0):
        e, r = line(side)
        mid = (e.lerp(r, t0) + e.lerp(r, t1)) / 2
        n = Vector((side * math.sin(a), 0, math.cos(a)))
        o = tilted("roof", ((t1 - t0) * L, u1 - u0, thick), (0, side * math.degrees(a), 0),
                   tuple(mid - n * (thick / 2 + sink) + Vector((0, (u0 + u1) / 2, 0))), col)
        o["no_bevel"] = True  # neighbouring pieces must meet without bevel grooves
        return o

    for side in (-1, 1):
        if cave and cave[0] == side:
            _, u0, u1 = cave
            # critic v01: neighbours overlap the cave piece by 0.5 mm and it sits 0.2 mm lower, so the intact
            # roof shows no hairline seams (and nothing is coplanar)
            static += [slab_piece(side, 0.0, 0.5 + 0.0005 / L, -full / 2, full / 2),
                       slab_piece(side, 0.5, 1.0, -full / 2, u0 + 0.0005),
                       slab_piece(side, 0.5, 1.0, u1 - 0.0005, full / 2)]
            cave_parts.append(slab_piece(side, 0.5, 1.0, u0, u1, sink=0.0002))
        else:
            static.append(slab_piece(side, 0.0, 1.0, -full / 2, full / 2))
            if cave:  # dark lining under the far slab: looking through the hole shows darkness, not roof colour
                e, r = line(side)
                n = Vector((side * math.sin(a), 0, math.cos(a)))
                p0, p1 = e.lerp(r, 0.2), e.lerp(r, 0.85)  # critic v01: 0.97 poked out of the near slab at the ridge
                lin = tilted("lining", ((p1 - p0).length, length - 2 * gable_t - 0.001, 0.001), (0, side * math.degrees(a), 0),
                             tuple((p0 + p1) / 2 - n * (thick + 0.0007)), "ink")
                lin["no_bevel"] = True
                static.append(lin)
    drop = 0.5 * thick / math.cos(a)
    for sy in (-1, 1):  # thin gable end walls
        g = bc.gable("gable", span, gable_t, h - drop, (0, sy * (length / 2 - gable_t / 2), z0 - 0.0001), gable_col)
        g["no_bevel"] = True
        static.append(g)
    static.append(bc.box("attic", (span - 0.006, length - 0.006, 0.0012), (0, 0, z0 + 0.0006), "ink"))
    if cave:
        side, u0, u1 = cave
        e, r = line(side)
        n = Vector((side * math.sin(a), 0, math.cos(a)))
        hinge_l = e.lerp(r, 0.5) - n * thick
        hinge_l.y = (u0 + u1) / 2
        far_l = r - n * thick
        far_l.y = hinge_l.y
        under = n * (thick + 0.002)
        for uy, t_end, droop in ((u0 + 0.004, 0.88, 0), ((u0 + u1) / 2 + 0.002, 0.78, 18)):  # critic v01: 0.98 poked out
            p0, p1 = e.lerp(r, 0.46) - under, e.lerp(r, t_end) - under
            p0.y = p1.y = uy
            d = p1 - p0
            rot = Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()
            if droop:  # snapped: the free end hangs down into the attic
                rot = Matrix.Rotation(math.radians(side * droop), 4, "Y") @ rot
            stick = bc.box("rafter", (0.0035, 0.0035, d.length), (0, 0, d.length / 2), "wood_dark")
            put([stick], Matrix.Translation(p0) @ rot)
            stick["ew_min_dim"] = 0.0035
            rafters.append(stick)
        axis_w = (Mrot.to_3x3() @ Vector((0, 1, 0))).normalized()
        house.cave = (Mrot @ hinge_l, axis_w, Mrot @ far_l)
    put(static + cave_parts + rafters, Mrot)
    house.static += static
    house.roof_cave += cave_parts
    house.rafters += rafters


def chimney_final(house, x, y, z_bottom, z_top, w, col, roof_surface_z, downhill):
    """Stump (static) up to just above the roof, top part (__chimney) above it with cap and dark socket.
    roof_surface_z: roof height at the chimney's UPHILL edge (critic v01: so a full-width stump stands proud
    and the leaning top rests on it). downhill: (dx, dy) unit vector of the roof's fall line at the chimney."""
    zc = roof_surface_z + 0.004
    house.static.append(bc.box("chimney_stump", (w, w, zc - z_bottom), (x, y, (z_bottom + zc) / 2), col))
    # the top starts 3 mm inside the stump: the bevel rounds its bottom edge, so a top cut exactly at zc tipped
    # over a rounded corner and hovered ~2.4 mm off the stump when leaning (measured)
    house.chimney += chimney(x, y, zc - 0.003, z_top, w, col)
    dx, dy = downhill
    pivot = Vector((x + dx * w / 2, y + dy * w / 2, zc))
    axis = Vector((-dy, dx, 0))  # horizontal, along the roof's contour line
    house.chim = (pivot, axis, Vector((x, y, z_top)), Vector(downhill))
    house.smoke = Vector((x, y, z_top + 0.004))


def rubble_pile(house, cx, cy, z, roof_col, seed):
    """A small pile: stone chunks, two roof tiles, a plank (appears when the house breaks)."""
    rnd = random.Random(seed)
    bits = [("stone", (0.011, 0.009, 0.008)), ("stone_dark", (0.010, 0.008, 0.007)), ("stone", (0.008, 0.008, 0.007)),
            ("stone_dark", (0.007, 0.006, 0.005)),
            (roof_col, (0.012, 0.008, 0.003)), (roof_col, (0.011, 0.007, 0.003)), (roof_col, (0.009, 0.006, 0.003)),
            ("wood_light", (0.026, 0.005, 0.004)), ("wood_dark", (0.020, 0.004, 0.004))]
    stones = []  # (x, y, top z) of the stone chunks; tiles and planks rest on the one under them (critic v01)
    for k, (col, size) in enumerate(bits):  # a pile big enough to read at arm's length
        ox, oy = rnd.uniform(-0.009, 0.009), rnd.uniform(-0.003, 0.003)
        base = z
        if k >= 4:
            under = [t for (sx_, sy_, t) in stones if abs(sx_ - cx - ox) < 0.006 and abs(sy_ - cy - oy) < 0.005]
            base = max(under) - 0.001 if under else z
        else:
            stones.append((cx + ox, cy + oy, z + size[2]))
        o = tilted("rubble", size, (rnd.uniform(-15, 15), rnd.uniform(-20, 20) if k < 4 else rnd.uniform(-8, 8), rnd.uniform(0, 180)),
                   (cx + ox, cy + oy, base + size[2] / 2), col)
        o["no_bevel"] = True
        house.rubble.append(o)


def cottage():
    """A: Dormer Cottage, terracotta roof, swing shutters."""
    hs = House()
    W, D, Hh, RH = 0.078, 0.064, 0.060, 0.064
    roof_col, frame = "roof_terracotta", "wood_dark"
    hs.static += [bc.box("base", (W, D, 0.008), (0, 0, 0.004), "stone"),
                  bc.box("walls", (W, D, Hh - 0.008), (0, 0, 0.008 + (Hh - 0.008) / 2), "wall_cream")]
    # ridge along X; local u -> world -x, so u -0.038..-0.018 puts the hole at world x 0.018..0.038 (right of the dormer)
    roof_final(hs, D, W, RH, Hh, roof_col, "wall_cream", axis="x", cave=(-1, -0.038, -0.018))
    yf = -(D / 2 - 0.010)
    zb = roof_z(RH, D, D / 2 - 0.010, Hh) - 0.003
    hs.static.append(bc.box("dormer", (0.026, 0.030, 0.022), (0, yf + 0.015, zb + 0.011), "wall_cream"))
    # critic v01: the 0.030 long dormer roof came out through the back slope; this one ends inside the front slope
    hs.static += roof(0.026, 0.016, 0.013, zb + 0.022, roof_col, "wall_cream", oh=0.004, thick=0.0035, at=(0, -0.016))
    st, g = win_final(0.012, 0.011, frame, "swing", frame)
    hs.static += put(st, Matrix.Translation((0, yf, zb + 0.011)))
    hs.glow += put(g, Matrix.Translation((0, yf, zb + 0.011)))
    hs.static += roof(0.024, 0.010, 0.007, 0.041, roof_col, "wall_cream", oh=0.003, thick=0.003, at=(-0.016, -D / 2 - 0.005))
    hs.openings([("door", "front", -0.016, 0.008, 0.017, 0.030),
                 ("window", "front", 0.020, 0.030, 0.016, 0.016),
                 ("hook", "front", -0.031, 0.030, 0, 0),
                 ("window", "right", 0.0, 0.032, 0.016, 0.016),
                 ("window", "left", 0.0, 0.032, 0.016, 0.016),
                 ("window", "back", 0.0, 0.032, 0.016, 0.016)], W / 2, D / 2, frame, "swing", frame)
    hs.static.append(bc.box("step", (0.022, 0.008, 0.004), (-0.016, -D / 2 - 0.004, 0.002), "stone"))
    cx, cy = 0.026, 0.012
    chimney_final(hs, cx, cy, 0.062, Hh + RH + 0.010, 0.014, "stone", roof_z(RH, D, cy - 0.007, Hh), (0, 1))  # stump from above the attic floor (critic v01)
    rubble_pile(hs, 0.030, -D / 2 - 0.009, 0.0, roof_col, 1)
    return hs, Vector((0, 0, 0.05))


def cabin():
    """C: Log Cabin, teal roof, roll-down slatted shutters (shown rolled up)."""
    hs = House()
    W, D, Hh, RH = 0.070, 0.058, 0.054, 0.060
    roof_col, frame = "roof_teal", "wood_dark"
    y0 = 0.008
    hs.static.append(bc.box("core", (W - 0.004, D - 0.004, Hh), (0, y0, Hh / 2), "wood_dark"))
    ch = Hh / 6
    for k in range(6):
        z = ch * (k + 0.5)
        for sy in (-1, 1):
            hs.static.append(bc.box("log", (W + 0.010, 0.006, ch * 0.86), (0, y0 + sy * (D / 2 - 0.001), z), "wood_light"))
        for sx in (-1, 1):
            hs.static.append(bc.box("log", (0.006, D - 0.004, ch * 0.86), (sx * (W / 2 - 0.001), y0, z), "wood_light"))
    # ridge along Y: the right slab (camera side) caves in its middle third
    roof_final(hs, W, D, RH, Hh, roof_col, "wood_dark", oh=0.007, at=(0, y0), cave=(1, -0.012, 0.012))
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
    chimney_final(hs, cx, cy, 0.040, Hh + RH + 0.002, 0.013, "stone", roof_z(RH, W, abs(cx) - 0.0065, Hh), (-1, 0))
    hs.lean = 22  # near the eave: a smaller lean keeps it over the roof
    rubble_pile(hs, 0.020, -0.027, 0.006, roof_col, 2)
    return hs, Vector((0, y0, 0.045))


def townhouse():
    """D: Timber Townhouse, orange roof, top-hinged flap shutters (shown propped open)."""
    hs = House()
    W, D, H1, H2, RH = 0.068, 0.058, 0.048, 0.044, 0.056
    roof_col, frame, shut = "roof_orange", "wood_dark", "roof_teal"
    J = 0.004
    hs.static += [bc.box("base", (W, D, 0.008), (0, 0, 0.004), "stone"),
                  bc.box("lower", (W, D, H1 - 0.008), (0, 0, 0.008 + (H1 - 0.008) / 2), "wall_cream"),
                  bc.box("floor_beam", (W + 0.006, D + 2 * J + 0.003, 0.005), (0, 0, H1 + 0.0025), "wood_dark"),
                  bc.box("upper", (W + 0.004, D + 2 * J, H2), (0, 0, H1 + 0.005 + H2 / 2), "wall_cream")]
    zt = H1 + 0.005 + H2
    # ridge along X; u -0.010..0.018 puts the hole at world x -0.018..0.010, clear of the chimney
    roof_final(hs, D + 2 * J, W + 0.004, RH, zt, roof_col, "wall_cream", axis="x", cave=(-1, -0.010, 0.018))
    for sy in (-1, 1):
        y = sy * (D / 2 + J + 0.0012)
        for x in (-(W / 2 + 0.002) + 0.002, 0.0, (W / 2 + 0.002) - 0.002):
            # stops 5 mm under the eave: full-height posts poked through the roof (dark dots on the slope)
            hs.static.append(bc.box("timber", (0.004, 0.0026, H2 - 0.005), (x, y, H1 + 0.005 + (H2 - 0.005) / 2), "wood_dark"))
        for sx in (-1, 1):
            hs.static.append(tilted("brace", (0.014, 0.0026, 0.0035), (0, sx * 38, 0), (sx * 0.0285, y, H1 + 0.012), "wood_dark"))
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
    chimney_final(hs, cx, cy, 0.080, zt + RH + 0.014, 0.013, "stone", roof_z(RH, D + 2 * J, abs(cy) - 0.0065, zt), (0, -1))
    rubble_pile(hs, 0.026, -D / 2 - 0.009, 0.0, roof_col, 3)
    return hs, Vector((0, 0, 0.06))


def _rot_toward(pivot, axis, far, angle_deg, want_dir=None):
    """Rotation about `axis` through `pivot` by +/- angle: the sign that moves `far` down, or toward want_dir."""
    best = None
    for sgn in (1, -1):
        R = Matrix.Rotation(math.radians(sgn * angle_deg), 4, axis)
        q = pivot + R.to_3x3() @ (far - pivot)
        score = -q.z if want_dir is None else (q - far).to_2d().dot(want_dir.to_2d())
        if best is None or score > best[0]:
            best = (score, R)
    return best[1]


def centre(objs):
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    return sum(pts, Vector()) / len(pts)


def pose(root, part, name, pivot, R, scale=1.0):
    """Empty <root>__<name> holding the part's target transform (parented to the root, like the part)."""
    bpy.context.view_layer.update()
    e = bpy.data.objects.new(root.name + "__" + name, None)
    bpy.context.collection.objects.link(e)
    e.empty_display_type = "ARROWS"
    e.empty_display_size = 0.01
    e["ew_pose_of"] = part
    e.parent = root
    e.matrix_world = Matrix.Translation(pivot) @ R @ Matrix.Diagonal((scale, scale, scale, 1))
    return e


def build_final(kind, state="intact"):
    hs, dust = {"cottage": cottage, "cabin": cabin, "townhouse": townhouse}[kind]()
    name = FINAL[kind]
    pile_c = centre(hs.rubble)
    pile_c.z = 0.0 if kind != "cabin" else 0.006
    raf_c = centre(hs.rafters)
    hinge_cave, axis_cave, far_cave = hs.cave
    chim_pivot, chim_axis, chim_top, downhill = hs.chim
    root = bc.assemble(name, [
        ("", hs.static, (0, 0, 0), None),
        ("windows", hs.glow, (0, 0, 0.03), ""),
        ("door", hs.door, tuple(hs.hinge), ""),
        ("roof_cave", hs.roof_cave, tuple(hinge_cave), ""),
        ("chimney", hs.chimney, tuple(chim_pivot), ""),
        ("rubble", hs.rubble, tuple(pile_c), ""),
        ("rafters", hs.rafters, tuple(raf_c), ""),
    ])
    bpy.data.objects[name + "__windows"]["ew_broken"] = "off"
    bc.anchor(root, "smoke_anchor", hs.smoke, parent_suffix="chimney", size=0.012)
    bc.anchor(root, "rubble_anchor", hs.smoke - Vector((0, 0, 0.005)), parent_suffix="chimney", size=0.008)
    bc.anchor(root, "lantern_anchor", hs.lantern, size=0.006)
    bc.anchor(root, "dust_anchor", dust, size=0.06)
    Fd = hs.door_m.to_3x3().to_4x4()
    I = Matrix.Identity(4)
    poses = [("roof_cave", hinge_cave, _rot_toward(hinge_cave, axis_cave, far_cave, 105)),
             ("chimney", chim_pivot, _rot_toward(chim_pivot, chim_axis, chim_top, hs.lean, want_dir=downhill)),
             ("door", hs.hinge, None),
             ("rubble", pile_c, I), ("rafters", raf_c, I)]
    # door hangs off its TOP hinge: swung 40 degrees out, free corner dropped 10 degrees
    top = hs.hinge + Fd.to_3x3() @ Vector((0, 0, hs.door_h))
    R_door = Fd @ Matrix.Rotation(math.radians(-40), 4, "Z") @ Matrix.Rotation(math.radians(10), 4, "Y") @ Fd.inverted()
    door_M = Matrix.Translation(top + R_door.to_3x3() @ (hs.hinge - top)) @ R_door
    for part, pv, R in poses:
        if part == "door":
            e = pose(root, part, part + "_broken", pv, Matrix.Identity(4))
            e.matrix_world = door_M
        else:
            pose(root, part, part + "_broken", pv, R)
    pose(root, "door", "door_open", hs.hinge, Fd @ Matrix.Rotation(math.radians(80), 4, "Z") @ Fd.inverted())
    for part in ("rubble", "rafters"):
        bpy.data.objects[name + "__" + part].scale = (TINY, TINY, TINY)
        bpy.data.objects[name + "__" + part]["ew_starts_hidden"] = True
    if state == "broken":  # preview only: every part in its broken pose, windows off
        bpy.context.view_layer.update()
        for part, _, _ in poses:
            obj = bpy.data.objects[name + "__" + part]
            obj.matrix_world = bpy.data.objects[name + "__" + part + "_broken"].matrix_world.copy()
        bpy.data.objects[name + "__windows"].scale = (TINY, TINY, TINY)
    return root


def build(params=None, seed=0):
    params = params or {}
    v, state = params.get("variant", "A"), params.get("state", "open")
    parts = VARIANTS[v](state)
    return bc.assemble(NAME, [("", parts, (0, 0, 0), None)])


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
