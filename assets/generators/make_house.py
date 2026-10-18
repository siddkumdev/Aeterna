"""Village house (benchmark). Run: blender --factory-startup -b -P assets/generators/make_house.py

Shape language from board #3/#4/#6: chunky cream walls, steep terracotta gable roof with overhang, chimney,
warm glowing windows. Original geometry; only the style is borrowed.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import blender_common as bc  # noqa: E402

DEFAULTS = {"roof": "roof_terracotta", "wall": "wall_cream", "name": "ew_village_house_v01", "short": "house"}


def build(params=None, seed=0):
    p = {**DEFAULTS, **(params or {})}
    parts = [
        bc.box("foundation", (0.13, 0.11, 0.012), (0, 0, 0.006), "stone"),
        bc.box("walls", (0.12, 0.10, 0.07), (0, 0, 0.047), p["wall"]),
        bc.gable("roof", 0.15, 0.13, 0.10, (0, 0, 0.082), p["roof"]),
        bc.box("chimney", (0.03, 0.03, 0.07), (0.04, 0.02, 0.14), "stone"),
        bc.box("door", (0.026, 0.008, 0.042), (0, -0.052, 0.033), "wood_dark"),
        bc.box("step", (0.044, 0.016, 0.008), (0, -0.064, 0.004), "stone"),
    ]
    for sx in (-1, 1):  # front windows: frame + glow
        parts.append(bc.box("frame", (0.03, 0.006, 0.032), (sx * 0.04, -0.051, 0.058), "wood_dark"))
        parts.append(bc.box("glass", (0.02, 0.008, 0.022), (sx * 0.04, -0.0525, 0.058), "lantern_glow"))
    return bc.finish(parts, p["name"])


if __name__ == "__main__":
    bc.clear_scene()
    obj = build()
    bc.save_blend(obj, DEFAULTS["short"])
    print("EXPORT", bc.export_glb(obj, "village"))
