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
    obj = build({"variant": v, "state": state})
    print("BLEND", bc.save_blend(obj, "village_house_%s%s" % (v, "_shut" if state != "open" else "")))
