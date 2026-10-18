"""Trees (benchmark): pine and round variants. Run: blender --factory-startup -b -P assets/generators/make_tree.py

Shape language from board #30 (cone and blob trees). Original geometry.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import blender_common as bc  # noqa: E402


def build_pine(name="ew_world_tree_pine_v01"):
    parts = [bc.cone("trunk", 0.014, 0.012, 0.036, (0, 0, 0.018), "wood_dark", 6)]
    # (radius, height, base z, colour): steep, overlapping tiers; the top tier is a true point
    for r, h, z, c in ((0.052, 0.062, 0.03, "leaf_green"), (0.04, 0.056, 0.066, "leaf_light"), (0.028, 0.05, 0.1, "leaf_green")):
        parts.append(bc.cone("tier", r, 0.0, h, (0, 0, z + h / 2), c, 7))
    return bc.finish(parts, name)


def build_round(name="ew_world_tree_round_v01"):
    parts = [
        bc.cone("trunk", 0.016, 0.013, 0.05, (0, 0, 0.025), "wood_dark", 6),
        bc.blob("crown", 0.055, (0, 0, 0.092), "leaf_green", 1, (1, 1, 0.92)),
        bc.blob("accent", 0.028, (0.02, -0.03, 0.115), "leaf_light", 1, (1, 1, 0.9)),
    ]
    return bc.finish(parts, name)


if __name__ == "__main__":
    for builder, short in ((build_pine, "tree_pine"), (build_round, "tree_round")):
        bc.clear_scene()
        obj = builder()
        bc.save_blend(obj, short)
        print("EXPORT", bc.export_glb(obj, "world"))
