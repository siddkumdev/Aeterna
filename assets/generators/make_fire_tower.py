"""Fire Tower v01 (first real tower). Run: blender --factory-startup -b -P assets/generators/make_fire_tower.py

Role (GAME_SPEC): long range, single target, shoots fireballs, no AoE.
Footprint 2 x 2 cells (0.10 m), about 85% filled; height about 3.3 cells (chunky, not a lighthouse).
Shape base: the v01 benchmark tower (octagonal, banded, wider at the bottom), with Claude's reading of
"a little more detail": masonry blocks, timber framing, corbels, door frame and step, window sills,
a firewood stack, and a brazier head. Original geometry only.

Parts (moved separately in Godot, no rig):
    ew_defense_fire_tower_v06            base, origin at the base centre
    ew_defense_fire_tower_v06__head      turns to aim; pivot at the platform
    ew_defense_fire_tower_v06__orb_anchor  empty (no mesh): where Godot spawns the flame-orb VFX ball that
                                           powers the tower (bobs, pulses, charges, spits the fireball)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import blender_common as bc  # noqa: E402

DEFAULTS = {"name": "ew_defense_fire_tower_v07", "short": "fire_tower", "accent": "roof_terracotta",
            # critic design suggestions (2026-10-18). Siddharth picked prongs, big merlons and one lit window
            # (v05) and rejected coal lumps; "-- proposal" still previews all four
            "coal_lumps": False, "prongs": True, "big_merlons": True, "one_lit_window": True}
R8 = 22.5  # rotate octagons so a flat face points to the front (-Y)


def _ring(n, r, z, size, col, start_deg=22.5, name="ring"):
    """n boxes evenly spaced on a circle, each facing outward."""
    out = []
    for i in range(n):
        a = math.radians(start_deg + i * 360 / n)
        out.append(bc.box(name, size, (r * math.cos(a), r * math.sin(a), z), col, rot_z_deg=math.degrees(a) + 90))
    return out


# Wall frustums (r_bottom, r_top, z_bottom, z_top) of the octagonal storeys; faces point at 0, 45, 90... degrees.
LOWER = (0.037, 0.033, 0.010, 0.062)
UPPER = (0.033, 0.031, 0.070, 0.100)


def build(params=None, seed=0):
    p = {**DEFAULTS, **(params or {})}
    rnd = random.Random(seed)
    accent = p["accent"]

    # ---- base (static) ---------------------------------------------------------------
    base = [
        bc.cone("foundation", 0.042, 0.040, 0.010, (0, 0, 0.005), "stone_dark", 8, R8),
        bc.cone("lower", LOWER[0], LOWER[1], LOWER[3] - LOWER[2], (0, 0, (LOWER[2] + LOWER[3]) / 2), "stone", 8, R8),
        bc.cone("band", 0.0350, 0.0350, 0.008, (0, 0, 0.066), "wood_dark", 8, R8),
        bc.cone("upper", UPPER[0], UPPER[1], UPPER[3] - UPPER[2], (0, 0, (UPPER[2] + UPPER[3]) / 2), "wall_cream", 8, R8),
    ]
    # masonry blocks sticking out of the stone body (random but repeatable per seed), flat on a face
    placed = []  # (face, z) of blocks already on the wall
    for i in range(7):
        face = rnd.choice([0, 45, 90, 135, 180, 225, 270, 315])
        rnd.uniform(-12, 12)  # was an angle jitter (lifted blocks off the wall); kept so the seed's sequence holds
        z = rnd.uniform(0.018, 0.056)
        if face == 270 and z < 0.044:
            continue  # keep the door area clear
        if any(f == face and abs(z - pz) < 0.009 for f, pz in placed):
            rnd.choice(["stone_dark", "stone"])  # keep the sequence
            continue  # v06: two blocks on one face overlapped (z-fighting); skip the second
        placed.append((face, z))
        blk = bc.on_wall("block", 0.013, 0.004, 0.007, face, z, LOWER, rnd.choice(["stone_dark", "stone"]))
        del blk["ew_min_dim"]  # masonry keeps its rounded bevel (the approved v01 look)
        base.append(blk)
    # timber framing on the plaster storey
    base += [bc.on_wall("beam", 0.004, 0.0035, 0.030, f, 0.085, UPPER, "wood_dark", sink=0.0003) for f in (45, 135, 225, 315)]
    # corbels (brackets) under the platform, at the corners
    base += _ring(8, 0.0340, 0.096, (0.005, 0.008, 0.006), "wood_dark", start_deg=22.5, name="corbel")
    # door with stone frame and a step (the step stands on the ground in front of the foundation)
    base += [
        bc.on_wall("door_frame", 0.020, 0.004, 0.028, 270, 0.024, LOWER, "stone_dark"),
        bc.on_wall("door", 0.014, 0.0055, 0.022, 270, 0.021, LOWER, "wood_dark"),
        bc.on_wall("door_strap", 0.014, 0.0065, 0.002, 270, 0.026, LOWER, "ink"),
        bc.box("step", (0.022, 0.008, 0.012), (0, -0.0405, 0.006), "stone_dark"),
    ]
    # windows: arrow slit low, lit windows with sills on the plaster storey
    win = bc.on_wall("window", 0.010, 0.004, 0.012, 270, 0.086, UPPER, "lantern_glow")
    bc.paint(win, "lantern_glow", glow=True)
    if p["one_lit_window"]:  # side window dark with open shutters: breaks the lit "lighthouse" band
        win_side = bc.on_wall("window_side", 0.010, 0.004, 0.012, 0, 0.086, UPPER, "ink")
        for dy in (-0.0085, 0.0085):
            sh = bc.on_wall("shutter", 0.006, 0.0045, 0.012, 0, 0.086, UPPER, "roof_orange")
            sh.location.y += dy
            bc.apply_transforms(sh)
            base.append(sh)
    else:
        win_side = bc.on_wall("window_side", 0.010, 0.004, 0.012, 0, 0.086, UPPER, "lantern_glow")
        bc.paint(win_side, "lantern_glow", glow=True)
    base += [
        win_side,
        bc.on_wall("sill", 0.014, 0.006, 0.003, 270, 0.0785, UPPER, "wood_light"),
        bc.on_wall("sill_side", 0.014, 0.006, 0.003, 0, 0.0785, UPPER, "wood_light"),
        bc.on_wall("slit", 0.004, 0.004, 0.014, 0, 0.042, LOWER, "ink"),
    ]
    # firewood stack beside the door (fuel for the fire, a small story detail)
    for i, (x, z) in enumerate([(-0.0255, 0.0135), (-0.0180, 0.0135), (-0.0218, 0.0200)]):
        log = bc.cone("log", 0.0036, 0.0036, 0.016, (0, 0, 0), "wood_light" if i % 2 == 0 else "wood_dark", 6)
        bc.rotate(log, (90, 0, 0))
        log.location = (x, -0.0335, z)
        bc.apply_transforms(log)
        base.append(log)

    # ---- head (turns to aim) ----------------------------------------------------------
    PZ = 0.100  # platform bottom = head pivot
    head = [
        bc.cone("platform", 0.041, 0.041, 0.008, (0, 0, PZ + 0.004), "stone", 8, R8),
        bc.cone("pedestal", 0.011, 0.014, 0.008, (0, 0, PZ + 0.012), "stone_dark", 8, R8),
        bc.cone("bowl", 0.015, 0.024, 0.014, (0, 0, PZ + 0.023), "stone_dark", 8, R8),
    ]
    # accent studs around the bowl lip (colour matches the building, Siddharth's rule)
    if p["prongs"]:  # 5 tall prongs leaning outward: a fire basket, not cog teeth
        for i in range(5):
            a = 90 + i * 72
            pr = bc.cone("prong", 0.0035, 0.0010, 0.011, (0, 0, 0.0055), accent, 4)
            bc.rotate(pr, (0, 18, a))
            pr.location = (0.0215 * math.cos(math.radians(a)), 0.0215 * math.sin(math.radians(a)), PZ + 0.0285)
            bc.apply_transforms(pr)
            pr["no_bevel"] = True
            head.append(pr)
    else:
        head += _ring(8, 0.0235, PZ + 0.0295, (0.009, 0.004, 0.004), accent, start_deg=22.5, name="lip")
    if p["big_merlons"]:  # 6 chunkier merlons with clear gaps: fort battlement, not a gallery rail
        head += _ring(6, 0.0355, PZ + 0.014, (0.013, 0.007, 0.012), "stone", start_deg=30, name="merlon")
    else:
        head += _ring(8, 0.0360, PZ + 0.0115, (0.010, 0.006, 0.007), "stone", start_deg=0, name="merlon")

    # glowing coals in the bowl: the orb's heat source
    coal_parts = []
    if p["coal_lumps"]:  # faceted lumps on a dark bed, dark gaps between them (not a red lid)
        head.append(bc.cone("coal_bed", 0.0205, 0.0205, 0.002, (0, 0, PZ + 0.031), "ink", 8, R8))
        crnd = random.Random(seed + 7)
        spots = [(0, 0)] + [(0.0105 * math.cos(math.radians(a)), 0.0105 * math.sin(math.radians(a))) for a in range(30, 390, 60)]
        for i, (x, y) in enumerate(spots):
            col = "fire_red" if i % 2 == 0 else "lantern_glow"
            r = crnd.uniform(0.0042, 0.0052)  # low faceted nugget (5-sided frustum), cheap on triangles
            lump = bc.cone("coal", r, r * 0.45, r * 0.8, (x, y, PZ + 0.032 + r * 0.4), col, 5, rot_z_deg=crnd.uniform(0, 72))
            bc.paint(lump, col, glow=True)
            lump["no_bevel"] = True
            head.append(lump)
    else:
        coals = bc.cone("coals", 0.0150, 0.0150, 0.002, (0, 0, PZ + 0.0305), "fire_red", 8, R8)
        bc.paint(coals, "fire_red", glow=True)
        coal_parts = [coals]  # v07: own part (__coals) so its glow can pulse per tower as the orb charges

    # ---- flame orb anchor ---------------------------------------------------------------
    # Siddharth: the flame orb is a VFX ball, not a model. The model only carries an empty
    # marking where Godot spawns the orb effect (shader ball + embers), above the coals.
    R = 0.0155
    OZ = PZ + 0.031 + 0.009 + R

    # v07 (Siddharth: split every tower for animation/VFX): the lit window and the coals are their own
    # parts, so Godot can flicker / pulse them per tower without touching the shared glow material
    wv = [win.matrix_world @ v.co for v in win.data.vertices]
    win_pivot = tuple(sum(c[i] for c in wv) / len(wv) for i in range(3))
    groups = [("", base, (0, 0, 0), None), ("head", head, (0, 0, PZ), ""), ("window", [win], win_pivot, "")]
    if coal_parts:
        groups.append(("coals", coal_parts, (0, 0, PZ + 0.0305), "head"))
    root = bc.assemble(p["name"], groups)
    bc.anchor(root, "pulse_anchor", (0, 0, 0), size=0.05)  # range ring reference, like the other towers
    anchor = bc.bpy.data.objects.new(p["name"] + "__orb_anchor", None)
    bc.bpy.context.collection.objects.link(anchor)
    anchor.empty_display_type = "SPHERE"
    anchor.empty_display_size = R
    anchor["ew_size"] = R
    anchor.parent = bc.bpy.data.objects[p["name"] + "__head"]
    anchor.location = (0, 0, OZ - PZ)
    return root

if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    bc.clear_scene()
    if args and args[0] == "proposal":  # preview of the critic's suggestions: saved, never exported
        obj = build({"coal_lumps": True, "prongs": True, "big_merlons": True, "one_lit_window": True})
        print("BLEND", bc.save_blend(obj, DEFAULTS["short"] + "_proposal"))
    else:
        obj = build()
        bc.save_blend(obj, DEFAULTS["short"])
        print("EXPORT", bc.export_glb(obj, "defense"))
