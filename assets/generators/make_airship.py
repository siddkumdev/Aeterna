"""Airship tower (asset list D05): design variants A-D.

    blender --factory-startup -b -P assets/generators/make_airship.py          (final: K ship + plank pad, exported)
    blender --factory-startup -b -P assets/generators/make_airship.py -- A     (design variant A-L)

Siddharth (2026-10-19), references in art/moodboard/refs_airship/ (shape ideas only, never copied):
- main ship like ref1: a round balloon wrapped in a rope net with a band round its middle, a curved
  boat hull hanging below on ropes, a small flag on top;
- tethered like ref2: a wooden stake in the ground with a rope up to the hull;
- it shoots a flaming cannonball from a deck cannon TURRET that turns to aim (the ship stays moored);
- VFX later: muzzle flash + smoke, burner flame at the balloon mouth; idle bob and flag flutter.
Role (GAME_SPEC): the only tower that hits flyers; 2 x 2 footprint, floats 2 cells above the board,
about 3 cells tall; range 4, 6 damage per shot, 1 shot per second; max 2 on the board.

Variants (shape + colour ideas; colours are Siddharth's pick from the sheet):
    A  Balloon Skiff     - round balloon, classic upswept hull, bow cannon; cream + teal (the spec's colours)
    B  Lantern Galleon   - round balloon with a diamond net, dark hull with a stern cabin; warm bone + red
    C  Bubble Tub        - squat wide balloon, short round tub hull, cannon mid-deck; cream + orange
    D  Finned Cruiser    - longer balloon, slim hull with side fins; teal balloon + cream trim
"""
import math
import os
import sys

import bmesh

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import blender_common as bc  # noqa: E402
from mathutils import Vector  # noqa: E402

NAME = "ew_defense_airship_v01"
HULL_Z = 0.100  # hull bottom: the ship floats 2 cells above the board (GAME_SPEC)
ROPE = 0.0024   # rope thickness: thin enough to read as rope, thick enough to survive at arm's length


def place(objs, rot, loc):
    for o in objs:
        bc.rotate(o, rot)
        o.location = loc
        bc.apply_transforms(o)
    return objs


def seg(name, a, b, w, d, col):
    """A w x d box running from point a to point b."""
    a, b = Vector(a), Vector(b)
    o = bc.box(name, (w, d, (b - a).length), (0, 0, 0), col)
    o.rotation_euler = Vector((0, 0, 1)).rotation_difference(b - a).to_euler()
    o.location = (a + b) / 2
    bc.apply_transforms(o)
    o["ew_min_dim"] = min(w, d)  # a tilted box's bounding box is fat: bevel by its real thickness (ropes stay plain)
    return o


def chain(name, pts, w, col):
    return [seg(name, pts[i], pts[i + 1], w, w, col) for i in range(len(pts) - 1)]


# ---- hull -------------------------------------------------------------------------------------

def hull_station(t, L, W, D, rise, z0, tub=False):
    """Section of the hull at t in [-1, 1] (-1 = bow at -Y): (y, half width, depth, gunwale z)."""
    w = W / 2 * (1 - (0.55 if tub else 0.80) * abs(t) ** (2.0 if tub else 2.6))
    return t * L / 2, max(w, 0.003), D * (1 - 0.45 * t * t), z0 + D + rise * t * t


def hull(L, W, D, rise, col, tub=False, stations=9, sides=6):
    """Curved boat hull, bottom at HULL_Z, upswept ends, flat deck at the gunwale. Returns (mesh, rail points)."""
    bm = bmesh.new()
    rings = []
    for i in range(stations):
        t = -1 + 2 * i / (stations - 1)
        y, w, d, zg = hull_station(t, L, W, D, rise, HULL_Z, tub)
        ring = [bm.verts.new((w * math.cos(math.pi * k / sides), y, zg - d * math.sin(math.pi * k / sides)))
                for k in range(sides + 1)]
        rings.append(ring)
    for i in range(stations - 1):
        a, b = rings[i], rings[i + 1]
        for k in range(sides):
            bm.faces.new((a[k], b[k], b[k + 1], a[k + 1]))
        bm.faces.new((a[sides], b[sides], b[0], a[0]))  # deck strip
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    rails = ([r[0].co.copy() for r in rings], [r[-1].co.copy() for r in rings])  # read before the bmesh is freed
    o = bc._new_obj("hull", bm)
    bc.paint(o, col)
    o["no_bevel"] = True  # curved, faceted already; a bevel would only multiply its triangles
    return o, rails


def hull_parts(L, W, D, rise, col, trim, tub=False):
    h, (right, left) = hull(L, W, D, rise, col, tub)
    up = Vector((0, 0, 0.0012))
    parts = [h]
    for side in (right, left):  # trim rail along each gunwale
        parts += chain("rail", [p + up for p in side], 0.0035, trim)
    # keel strip under the bottom
    parts.append(bc.box("keel", (0.004, L * 0.34, 0.003), (0, 0, HULL_Z + 0.0012), trim))  # short: the hull bottom curves up
    return parts


def deck_z(y, L, D, rise):
    t = 2 * y / L
    return HULL_Z + D + rise * t * t


# ---- balloon ----------------------------------------------------------------------------------

def balloon(c, r, col, net, band, squash=(1, 1, 1), diamond=False, segs=10):
    """Round faceted balloon centred at c, rope net (meridians + rings), a band round the middle and
    a dark mouth underneath. Returns (parts, mouth point, rope hook points at the lower net)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=8, radius=r)
    bmesh.ops.scale(bm, vec=squash, verts=bm.verts)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0),
                     matrix=bc.mathutils.Matrix.Rotation(math.pi / segs, 3, "Z"))
    bmesh.ops.translate(bm, vec=c, verts=bm.verts)
    ball = bc._new_obj("balloon", bm)
    bc.paint(ball, col)
    ball["no_bevel"] = True  # faceted sphere: bevelling adds triangles, not shape
    parts = [ball]
    cx, cy, cz = c
    sx, sy, sz = squash

    def on(theta, phi, out=0.0012):
        k = 1 + out / r
        return (cx + r * k * math.sin(theta) * math.cos(phi) * sx,
                cy + r * k * math.sin(theta) * math.sin(phi) * sy,
                cz + r * k * math.cos(theta) * sz)

    n_mer = 6
    for m in range(n_mer):  # meridian ropes from the crown down to the mouth
        phi = math.radians(m * 360 / n_mer + 30)
        parts += chain("net", [on(math.radians(a), phi) for a in (12, 40, 68, 90, 115, 140, 160)], ROPE, net)
    if diamond:  # crossing ropes between meridians on the upper half: the diamond net of ref1
        for m in range(n_mer):
            p0, p1 = math.radians(m * 60 + 30), math.radians(m * 60 + 90)
            parts.append(seg("net", on(math.radians(40), p0), on(math.radians(68), (p0 + p1) / 2), ROPE, ROPE, net))
            parts.append(seg("net", on(math.radians(68), (p0 + p1) / 2), on(math.radians(40), p1), ROPE, ROPE, net))
    # band round the middle and a ring near the crown (rings sit just outside the balloon surface)
    for theta, depth, col_ in ((90, 0.006, band), (40, 0.003, net)):
        rr = r * math.sin(math.radians(theta)) + 0.0015
        ring = bc.cone("ring", rr * max(sx, sy), rr * max(sx, sy), depth, (cx, cy, cz + r * sz * math.cos(math.radians(theta))), col_, segs)
        ring.scale = (sx / max(sx, sy), sy / max(sx, sy), 1)
        bc.apply_transforms(ring)
        ring["no_bevel"] = True
        parts.append(ring)
    mouth_z = cz - r * sz
    parts += [bc.cone("mouth_ring", 0.0085, 0.0075, 0.004, (cx, cy, mouth_z - 0.001), net, 8),
              bc.cone("mouth", 0.0065, 0.0065, 0.002, (cx, cy, mouth_z - 0.0030), "ink", 8)]
    hooks = [on(math.radians(140), math.radians(a)) for a in (45, 135, 225, 315)]
    return parts, (cx, cy, mouth_z - 0.006), hooks


def flag(top, col, pole="wood_dark"):
    """Short mast on the balloon crown with a flag (the flag flutters in Godot)."""
    x, y, z = top
    return [bc.box("mast", (0.0025, 0.0025, 0.020), (x, y, z + 0.010), pole),
            bc.box("flag", (0.0025, 0.014, 0.009), (x, y + 0.0082, z + 0.015), col)]


def suspension(hooks, deck_pts, col):
    w = 0.003  # critic v01: the 4 load ropes a little thicker than the net so they hold up at arm's length
    return [seg("suspension", h, d, w, w, col) for h, d in zip(hooks, deck_pts)]


# ---- cannon and tether ------------------------------------------------------------------------

def cannon(base, col_base, col_barrel="stone_dark", pitch=25):
    """Deck cannon turret at base (turntable + cheeks + barrel pitched up toward -Y). Returns (parts, muzzle)."""
    x, y, z = base
    # critic final_v01: base sinks 2.5 mm into the sloped deck so no edge floats at any heading
    parts = [bc.cone("turret_base", 0.0110, 0.0100, 0.0075, (x, y, z + 0.00125), col_base, 8),
             bc.box("cheek", (0.0035, 0.010, 0.011), (x - 0.0072, y, z + 0.0105), col_base),
             bc.box("cheek", (0.0035, 0.010, 0.011), (x + 0.0072, y, z + 0.0105), col_base)]
    parts[0]["no_bevel"] = True  # as before the 2.5 mm sink (it was below the bevel threshold)
    L, PZ = 0.036, 0.012  # barrel length; trunnion height above the deck (critic: bigger so it reads)
    barrel = place([bc.cone("barrel", 0.0070, 0.0056, L, (0, 0, L / 2 - 0.008), col_barrel, 8),
                    bc.cone("muzzle_ring", 0.0075, 0.0075, 0.004, (0, 0, L - 0.010), "ink", 8),
                    bc.blob("breech", 0.0068, (0, 0, -0.008), col_barrel, 1)],
                   (90 - pitch, 0, 0), (x, y, z + PZ))  # critic v01: 90 + pitch aimed the barrel DOWN into the bow
    parts += barrel
    a = math.radians(pitch)
    muzzle = (x, y - (L - 0.008) * math.cos(a), z + PZ + (L - 0.008) * math.sin(a))
    return parts, muzzle


def tether(stake_at, hull_point, rope_col="wood_light", base=0.0):
    """Ground stake with a stone cap (ref2) and the rope from it up to the hull."""
    x, y = stake_at
    parts = [bc.box("stake", (0.010, 0.010, 0.020), (x, y, 0.010), "wood_dark"),
             bc.box("stake_cap", (0.013, 0.013, 0.005), (x, y, 0.0215), "stone"),
             bc.cone("rope_coil", 0.0075, 0.0075, 0.004, (x - 0.011, y + 0.004, base + 0.002), rope_col, 8)]  # base: top of a mooring pad
    parts.append(seg("tether", (x, y, 0.019), hull_point, 0.0035, 0.0035, rope_col))
    return parts


# ---- variants ---------------------------------------------------------------------------------

def ship(L, W, D, rise, hull_col, trim, bal_r, bal_col, net, band, flag_col, gap, cannon_y,
         tub=False, squash=(1, 1, 1), diamond=False):
    parts = hull_parts(L, W, D, rise, hull_col, trim, tub)
    top_mid = HULL_Z + D
    bc_z = top_mid + gap + bal_r * squash[2]
    b, mouth, hooks = balloon((0, 0, bc_z), bal_r, bal_col, net, band, squash, diamond)
    parts += b
    parts += flag((0, 0, bc_z + bal_r * squash[2]), flag_col)
    deck_pts = [(sx * W * 0.32, sy * L * 0.22, deck_z(sy * L * 0.22, L, D, rise) + 0.001) for sx, sy in ((1, 1), (-1, 1), (-1, -1), (1, -1))]
    hooks = sorted(hooks, key=lambda h: (math.atan2(h[1], h[0])))
    deck_pts = sorted(deck_pts, key=lambda d: (math.atan2(d[1], d[0])))
    parts += suspension(hooks, deck_pts, net)
    cz = deck_z(cannon_y, L, D, rise)
    gun, muzzle = cannon((0, cannon_y, cz), "wood_light" if hull_col == "wood_dark" else trim)  # light backdrop for the dark barrel
    parts += gun
    bow = (0, -L / 2 + 0.006, deck_z(-L / 2 + 0.006, L, D, rise) - D * 0.5)
    return parts, muzzle, mouth, bow


def variant_a():
    """Balloon Skiff: closest to ref1. Cream balloon, teal band and trim, light wood hull, bow cannon."""
    p, muzzle, mouth, bow = ship(0.086, 0.046, 0.023, 0.011, "wood_light", "roof_teal", 0.034, "wall_cream",
                                 "wood_dark", "roof_teal", "roof_teal", 0.040, -0.024)
    p += [bc.cone("barrel_cargo", 0.0045, 0.0045, 0.008, (0.006, 0.020, deck_z(0.020, 0.086, 0.023, 0.011) + 0.004), "wood_dark", 8)]
    p += tether((0.034, -0.034), bow)
    return p, muzzle, mouth


def variant_b():
    """Lantern Galleon: warm bone balloon with a diamond net and red band, dark hull, a small stern cabin."""
    L, D, rise = 0.088, 0.024, 0.012
    p, muzzle, mouth, bow = ship(L, 0.046, D, rise, "wood_dark", "roof_terracotta", 0.034, "bone",
                                 "wood_dark", "roof_terracotta", "roof_terracotta", 0.040, -0.024, diamond=True)
    zc = deck_z(0.019, L, D, rise) - 0.001  # cabin bottom at its front edge (the deck rises toward the stern)
    p += [bc.box("cabin", (0.020, 0.014, 0.014), (0, 0.026, zc + 0.007), "wood_light"),
          bc.box("cabin_roof", (0.023, 0.017, 0.003), (0, 0.026, zc + 0.0155), "roof_terracotta"),
          bc.box("cabin_window", (0.008, 0.002, 0.005), (0, 0.0185, zc + 0.009), "ink")]
    p += tether((0.034, -0.034), bow)
    return p, muzzle, mouth


def variant_c():
    """Bubble Tub: squat wide balloon, short round tub hull, cannon mid-deck; cream with orange band."""
    L, D, rise = 0.070, 0.026, 0.006
    p, muzzle, mouth, bow = ship(L, 0.052, D, rise, "wood_light", "wood_dark", 0.040, "wall_cream",
                                 "wood_dark", "roof_orange", "roof_orange", 0.034, -0.020, tub=True, squash=(1, 1, 0.78))
    p += tether((0.034, -0.034), bow)
    return p, muzzle, mouth


def variant_d():
    """Finned Cruiser: longer balloon, slim hull with side fins (ref2's fins), teal balloon with cream trim."""
    L, W, D, rise = 0.090, 0.040, 0.021, 0.013
    p, muzzle, mouth, bow = ship(L, W, D, rise, "wood_dark", "wall_cream", 0.032, "roof_teal",
                                 "wall_cream", "wall_cream", "wall_cream", 0.040, -0.026, squash=(1, 1.3, 0.95))
    zf = HULL_Z + D * 0.55
    for sx in (-1, 1):
        fin = bc.box("fin", (0.016, 0.020, 0.003), (0, 0, 0), "roof_teal")
        _y, hw, _d, _zg = hull_station(2 * 0.016 / L, L, W, D, rise, HULL_Z)
        place([fin], (0, sx * -20, 0), (sx * (hw * 0.85 + 0.0075 - 0.001), 0.016, zf))  # inner edge sunk 1 mm into the hull side
        p.append(fin)
    p += [bc.box("tail_fin", (0.003, 0.014, 0.014), (0, L / 2 - 0.004, deck_z(L / 2, L, D, rise) + 0.004), "roof_teal")]
    p += tether((0.034, -0.034), bow)
    return p, muzzle, mouth


# ---- mixes of A, B and C (Siddharth liked A, B, C on 2026-10-19) ----------------------------------

def cabin(L, D, rise, wall="wood_light", roof="roof_terracotta"):
    """B's small stern cabin, standing on the rising deck."""
    zc = deck_z(0.019, L, D, rise) - 0.001
    return [bc.box("cabin", (0.020, 0.014, 0.014), (0, 0.026, zc + 0.007), wall),
            bc.box("cabin_roof", (0.023, 0.017, 0.003), (0, 0.026, zc + 0.0155), roof),
            bc.box("cabin_window", (0.008, 0.002, 0.005), (0, 0.0185, zc + 0.009), "ink")]


def mooring_pad(kind):
    """Ground pad that marks the 2 x 2 cells as taken (option for Siddharth): planks or stone."""
    if kind == "planks":
        p = [bc.box("pad", (0.084, 0.084, 0.004), (0, 0, 0.002), "wood_light")]
        p += [bc.box("pad_gap", (0.080, 0.002, 0.001), (0, -0.042 + i * 0.084 / 5, 0.0042), "wood_dark") for i in range(1, 5)]
        p += [bc.box("pad_edge", (0.006, 0.088, 0.006), (sx * 0.042, 0, 0.003), "wood_dark") for sx in (-1, 1)]  # battens cross the planks: a frame
        return p
    p = [bc.box("pad", (0.086, 0.086, 0.004), (0, 0, 0.002), "path_stone")]
    p += [bc.box("pad_kerb", (0.090, 0.006, 0.006), (0, sy * 0.043, 0.003), "stone") for sy in (-1, 1)]
    p += [bc.box("pad_kerb", (0.006, 0.080, 0.006), (sx * 0.043, 0, 0.003), "stone") for sx in (-1, 1)]  # butt between the y kerbs (no overlap)
    return p


def variant_e():
    """A + B: A's ship and colours with B's diamond net (the critic's suggestion), cargo barrel on deck."""
    L, W, D, rise = 0.086, 0.046, 0.023, 0.011
    p, muzzle, mouth, bow = ship(L, W, D, rise, "wood_light", "roof_teal", 0.034, "wall_cream",
                                 "wood_dark", "roof_teal", "roof_teal", 0.040, -0.024, diamond=True)
    p += [bc.cone("barrel_cargo", 0.0045, 0.0045, 0.008, (0.006, 0.020, deck_z(0.020, L, D, rise) + 0.004), "wood_dark", 8)]
    p += tether((0.034, -0.034), bow)
    return p, muzzle, mouth


def variant_f():
    """B + A: B's dark hull and stern cabin under A's cream balloon with teal band and trim."""
    L, W, D, rise = 0.088, 0.046, 0.024, 0.012
    p, muzzle, mouth, bow = ship(L, W, D, rise, "wood_dark", "roof_teal", 0.034, "wall_cream",
                                 "wood_dark", "roof_teal", "roof_teal", 0.040, -0.024)
    p += cabin(L, D, rise, wall="wall_cream", roof="roof_teal")
    p += tether((0.034, -0.034), bow)
    return p, muzzle, mouth


def variant_g():
    """C + A: C's squat cream balloon with orange band over A's classic hull; plank mooring pad."""
    L, W, D, rise = 0.084, 0.046, 0.023, 0.011
    p, muzzle, mouth, bow = ship(L, W, D, rise, "wood_light", "wood_dark", 0.039, "wall_cream",
                                 "wood_dark", "roof_orange", "roof_orange", 0.036, -0.024, squash=(1, 1, 0.80))
    p += [bc.cone("barrel_cargo", 0.0045, 0.0045, 0.008, (0.006, 0.020, deck_z(0.020, L, D, rise) + 0.004), "wood_dark", 8)]
    p += mooring_pad("planks")
    p += tether((0.034, -0.034), bow, base=0.004)
    return p, muzzle, mouth


def variant_h():
    """B + C: B's bone balloon with diamond net, red band and cabin, on a wider rounder hull; stone mooring pad."""
    L, W, D, rise = 0.080, 0.052, 0.025, 0.008
    p, muzzle, mouth, bow = ship(L, W, D, rise, "wood_dark", "roof_terracotta", 0.036, "bone",
                                 "wood_dark", "roof_terracotta", "roof_terracotta", 0.038, -0.022, diamond=True)
    p += cabin(L, D, rise)
    p += mooring_pad("stone")
    p += tether((0.034, -0.034), bow, base=0.004)
    return p, muzzle, mouth


# ---- mixes of G and H (Siddharth likes both their colours and the landing pad, 2026-10-19) ------

def round_hull_ship(bal_col, band, flag_col, hull_col, trim, squash=(1, 1, 1), bal_r=0.036):
    """H's ship with the critic's fix: a truly wider hull (W 0.056) whose ends still sweep up like ref1."""
    L, W, D, rise = 0.080, 0.056, 0.025, 0.011
    p, muzzle, mouth, bow = ship(L, W, D, rise, hull_col, trim, bal_r, bal_col, "wood_dark", band, flag_col,
                                 0.038, -0.022, squash=squash, diamond=True)
    return p, muzzle, mouth, bow, (L, D, rise)


def variant_i():
    """H's ship in G's colours: cream balloon, orange band and flag, light wood hull; plank pad."""
    p, muzzle, mouth, bow, (L, D, rise) = round_hull_ship("wall_cream", "roof_orange", "roof_orange", "wood_light", "wood_dark")
    p += cabin(L, D, rise, wall="wall_cream", roof="roof_orange")
    p += mooring_pad("planks") + tether((0.034, -0.034), bow, base=0.004)
    return p, muzzle, mouth


def variant_j():
    """H as it is (bone balloon, red band, dark hull, cabin) on G's plank pad."""
    p, muzzle, mouth, bow, (L, D, rise) = round_hull_ship("bone", "roof_terracotta", "roof_terracotta", "wood_dark", "roof_terracotta")
    p += cabin(L, D, rise)
    p += mooring_pad("planks") + tether((0.034, -0.034), bow, base=0.004)
    return p, muzzle, mouth


def variant_k():
    """G's squat balloon (now with the diamond net) in H's colours over a dark hull with cabin; stone pad."""
    p, muzzle, mouth, bow, (L, D, rise) = round_hull_ship("bone", "roof_terracotta", "roof_terracotta", "wood_dark", "roof_terracotta",
                                                          squash=(1, 1, 0.80), bal_r=0.039)
    p += cabin(L, D, rise)
    p += mooring_pad("stone") + tether((0.034, -0.034), bow, base=0.004)
    return p, muzzle, mouth


def variant_l():
    """Colour blend: H's bone balloon with G's orange band, dark hull with orange trim, red flag; plank pad."""
    p, muzzle, mouth, bow, (L, D, rise) = round_hull_ship("bone", "roof_orange", "roof_terracotta", "wood_dark", "roof_orange")
    p += cabin(L, D, rise, wall="wood_light", roof="roof_terracotta")
    p += mooring_pad("planks") + tether((0.034, -0.034), bow, base=0.004)
    return p, muzzle, mouth


VARIANTS = {"A": variant_a, "B": variant_b, "C": variant_c, "D": variant_d,
            "E": variant_e, "F": variant_f, "G": variant_g, "H": variant_h,
            "I": variant_i, "J": variant_j, "K": variant_k, "L": variant_l}


def build(params=None, seed=0):
    v = (params or {}).get("variant", "A")
    parts, muzzle, mouth = VARIANTS[v]()
    root = bc.assemble(NAME, [("", parts, (0, 0, 0), None)])
    bc.anchor(root, "muzzle_anchor", muzzle, size=0.005)   # flaming cannonball, muzzle flash + smoke
    bc.anchor(root, "burner_anchor", mouth, size=0.008)    # burner flame under the balloon
    bc.anchor(root, "pulse_anchor", (0, 0, 0), size=0.05)
    return root


def build_final(seed=0):
    """Siddharth's pick (2026-10-19): K's ship and colours on G's plank landing pad, ropes outside the hull.

    Parts (moved separately in Godot, no rig):
        ew_defense_airship_vNN               landing pad, stake, rope coil (static)
        ..__tether                           rope from the stake top to the bow (pivot at the stake top: re-aim it as the ship bobs)
        ..__ship                             hull, balloon, net, ropes, cabin (pivot at the hull bottom centre: bob / sway)
        ..__flag                             flag on the balloon crown (pivot at the mast: flutter)
        ..__turret                           cannon turntable + cheeks (child of ship, turns 360 degrees about Z)
        ..__barrel                           cannon barrel (child of turret, pivot at the trunnion: tilts up to aim)
    Anchors: __muzzle_anchor (barrel: flaming cannonball, flash, smoke), __burner_anchor (ship: burner flame),
             __tether_anchor (ship: where the tether meets the bow), __pulse_anchor (ground centre).
    """
    L, W, D, rise = 0.080, 0.056, 0.025, 0.011
    R, SQ = 0.039, (1, 1, 0.80)
    hull_col, trim = "wood_dark", "roof_terracotta"
    ship_p = hull_parts(L, W, D, rise, hull_col, trim)
    cz = HULL_Z + D + 0.038 + R * SQ[2]
    b, mouth, _ = balloon((0, 0, cz), R, "bone", "wood_dark", trim, SQ, diamond=True)
    ship_p += b
    crown = cz + R * SQ[2]
    mast, flag_box = flag((0, 0, crown), trim)
    ship_p.append(mast)
    # suspension ropes from lugs on the OUTSIDE of the hull up to the balloon band, clear of the turret's sweep
    ropes = []
    hook_theta = math.radians(110)
    # critic final_v01: the rope tips ended on bare canvas in the air; a load ring (like ref1's lower net ring)
    # gives them something to hook onto, and the tips sit inside it
    ring_z = cz + R * SQ[2] * math.cos(hook_theta)
    ring_r = R * math.sin(hook_theta) + 0.0015
    load_ring = bc.cone("load_ring", ring_r, ring_r, 0.003, (0, 0, ring_z), "wood_dark", 10)
    load_ring["no_bevel"] = True
    ship_p.append(load_ring)
    for sx in (-1, 1):
        for y in (0.0, 0.024):
            _y, hw, _d, zg = hull_station(2 * y / L, L, W, D, rise, HULL_Z)
            # critic final_v01: lugs follow the tapering hull side (no gap or buried end) and sink 1 mm into it
            dhw = (hull_station(2 * (y + 0.001) / L, L, W, D, rise, HULL_Z)[1]
                   - hull_station(2 * (y - 0.001) / L, L, W, D, rise, HULL_Z)[1]) / 0.002
            lug = bc.box("rope_lug", (0.004, 0.006, 0.007), (sx * (hw + 0.0005), y, zg - 0.0035), trim,
                         rot_z_deg=-math.degrees(math.atan(sx * dhw)))
            lug["ew_min_dim"] = 0.004
            ship_p.append(lug)
            a = Vector((sx * (hw + 0.0025), y, zg - 0.003))
            phi = math.atan2(a.y, a.x)
            rr = ring_r * math.cos(math.pi / 10) - 0.0005
            hook = Vector((rr * math.cos(phi), rr * math.sin(phi), ring_z))
            ropes.append((a, hook))
            ship_p.append(seg("suspension", a, hook, 0.003, 0.003, "wood_dark"))
    ship_p += cabin(L, D, rise)
    ty = -0.016  # turret pivot: far enough aft that the muzzle stays inside the 2 x 2 cells at any heading
    tz = deck_z(ty, L, D, rise)
    gun, muzzle = cannon((0, ty, tz), "wood_light")
    turret, barrel = gun[:3], gun[3:]
    bow = (0, -L / 2 + 0.006, deck_z(-L / 2 + 0.006, L, D, rise) - D * 0.5)
    stake, cap, coil, rope = tether((0.034, -0.034), bow, base=0.004)
    root_p = mooring_pad("planks") + [stake, cap, coil]

    # check: the barrel must clear every suspension rope at any turret heading (Siddharth's 360-degree turret)
    def dist_seg(p, a, b_):
        ab = b_ - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
        return (p - (a + ab * t)).length
    pitch, blen, brad = math.radians(25), 0.036, 0.0075
    worst = 1.0
    for deg in range(0, 360, 5):
        yaw = math.radians(deg)
        for k in range(13):
            s_ = -0.008 + k * (blen / 12)
            local = Vector((0, -s_ * math.cos(pitch), s_ * math.sin(pitch)))
            p = Vector((local.x * math.cos(yaw) - local.y * math.sin(yaw), local.x * math.sin(yaw) + local.y * math.cos(yaw), 0))
            p += Vector((0, ty, tz + 0.012 + local.z))
            for a, hook in ropes:
                worst = min(worst, dist_seg(p, a, hook) - brad - 0.0015)
    print("TURRET SWEEP min rope clearance %.1f mm" % (worst * 1000))

    stake_top = (0.034, -0.034, 0.019)
    root = bc.assemble(NAME, [
        ("", root_p, (0, 0, 0), None),
        ("tether", [rope], stake_top, ""),
        ("ship", ship_p, (0, 0, HULL_Z), ""),
        ("flag", [flag_box], (0, 0, crown + 0.015), "ship"),
        ("turret", turret, (0, ty, tz), "ship"),
        ("barrel", barrel, (0, ty, tz + 0.012), "turret"),
    ])
    # critic final_v01: the bevel left zero-area faces on the barrel (the long spike in the wire view); merge them away
    for o in [root] + list(root.children_recursive):
        if o.type == "MESH":
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
            bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-6)
            bm.to_mesh(o.data)
            bm.free()
    bc.anchor(root, "muzzle_anchor", muzzle, parent_suffix="barrel", size=0.005)
    bc.anchor(root, "burner_anchor", mouth, parent_suffix="ship", size=0.008)
    bc.anchor(root, "tether_anchor", bow, parent_suffix="ship", size=0.003)
    bc.anchor(root, "pulse_anchor", (0, 0, 0), size=0.05)
    return root


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    v = args[0] if args else "final"
    bc.clear_scene()
    if v == "final":
        obj = build_final()
        print("BLEND", bc.save_blend(obj, "airship"))
        print("EXPORT", bc.export_glb(obj, "defense"))
    else:
        obj = build({"variant": v})
        print("BLEND", bc.save_blend(obj, "airship_" + v))
