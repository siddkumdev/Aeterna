"""Archer tower (benchmark). Run: blender --factory-startup -b -P assets/generators/make_tower_archer.py

Shape language from board #7/#8: tapered round stone base, wooden tier band, crenellated platform, conical cap.
Original geometry; no specific tower is reproduced.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import blender_common as bc  # noqa: E402

DEFAULTS = {"s": 0.75, "name": "ew_defense_tower_archer_v01", "short": "tower_archer", "cap": "roof_teal"}


def build(params=None, seed=0):
    p = {**DEFAULTS, **(params or {})}
    S = p["s"]          # overall scale
    W = 1.3             # radial chunkiness: widens everything except heights
    r8 = 22.5           # rotate octagons so a flat face points to the front (-Y)
    parts = [
        bc.cone("plinth", 0.075 * S * W, 0.07 * S * W, 0.015 * S, (0, 0, 0.0075 * S), "stone_dark", 8, r8),
        bc.cone("lower", 0.065 * S * W, 0.05 * S * W, 0.085 * S, (0, 0, 0.0575 * S), "stone", 8, r8),
        bc.cone("band", 0.056 * S * W, 0.056 * S * W, 0.012 * S, (0, 0, 0.106 * S), "wood_dark", 8, r8),
        bc.cone("upper", 0.058 * S * W, 0.05 * S * W, 0.06 * S, (0, 0, 0.142 * S), "wood_light", 8, r8),
        bc.cone("platform", 0.066 * S * W, 0.066 * S * W, 0.012 * S, (0, 0, 0.178 * S), "stone", 8, r8),
        bc.cone("turret", 0.037 * S * W, 0.034 * S * W, 0.038 * S, (0, 0, 0.203 * S), "stone", 8, r8),
        bc.cone("cap", 0.044 * S * W, 0.004 * S * W, 0.075 * S, (0, 0, 0.2595 * S), p["cap"], 8, r8),
        bc.cone("finial", 0.009 * S * W, 0.0, 0.026 * S, (0, 0, 0.3105 * S), "lantern_glow", 6),
        bc.box("door", (0.036 * S, 0.014 * S, 0.046 * S), (0, -0.0565 * S * W, 0.038 * S), "wood_dark"),
        bc.box("slit_a", (0.016 * S, 0.012 * S, 0.04 * S), (0, -0.0525 * S * W, 0.142 * S), "ink"),
        bc.box("slit_b", (0.014 * S, 0.012 * S, 0.026 * S), (0, -0.0345 * S * W, 0.203 * S), "ink"),
    ]
    for i in range(8):  # chunky merlons around the platform rim
        a = math.radians(i * 45 + 22.5)
        r = 0.058 * S * W
        parts.append(bc.box("merlon", (0.034 * S, 0.016 * S, 0.028 * S),
                            (r * math.cos(a), r * math.sin(a), 0.198 * S), "stone",
                            rot_z_deg=math.degrees(a) + 90))
    return bc.finish(parts, p["name"])


if __name__ == "__main__":
    bc.clear_scene()
    obj = build()
    bc.save_blend(obj, DEFAULTS["short"])
    print("EXPORT", bc.export_glb(obj, "defense"))
