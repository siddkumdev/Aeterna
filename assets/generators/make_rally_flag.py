"""Rally flag (D11). Original design. Run: blender --factory-startup -b -P assets/generators/make_rally_flag.py -- <A|B|C|D>

The ring is VFX (Siddharth 2026-10-21): a Godot shader/particle ring at __ring_anchor, not a model.
Root = pole + base; child __cloth pivots at the pole so Godot can sway it with a tween. 1 x 1 cell footprint.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import blender_common as bc  # noqa: E402

RING = 0.06  # ring anchor size (m): troops hold within about this radius of the flag


def mound(r=0.018, h=0.008):
    p = [bc.cone("mound", r, r * 0.82, h, (0, 0, h / 2), "stone", 8)]
    for k, (x, y, s) in enumerate(((0.012, -0.010, 0.006), (-0.013, -0.004, 0.005), (0.002, 0.014, 0.0055))):
        p.append(bc.cone("rock", s, s * 0.8, s * 0.9, (x, y, h + s * 0.35), "path_stone" if k != 1 else "stone_dark", 6, 20 * k))
    return p


def stepped_pennant(x0, z, length, step_h, cols, thick=0.003, n=3):
    """Stepped toy pennant: n slabs shrinking toward the tip; x0 = pole face, z = top edge."""
    parts = []
    for i in range(n):
        w = length * (1 - i / n * 0.85)
        parts.append(bc.box("cloth", (w, thick, step_h), (x0 + w / 2, 0, z - step_h * (i + 0.5)), cols[i % len(cols)]))
    return parts


def build_A():
    """Banner on a pole: stone mound, wood pole, cream pennant with a terracotta stripe."""
    base = mound() + [bc.cone("pole", 0.0032, 0.0028, 0.108, (0, 0, 0.062), "wood_light", 6),
                      bc.cone("finial", 0.0042, 0.0042, 0.005, (0, 0, 0.118), "wood_dark", 6)]
    cloth = [bc.box("cloth", (0.034, 0.003, 0.014), (0.019, 0, 0.101), "wall_cream"),
             bc.box("cloth", (0.034, 0.0034, 0.0045), (0.019, 0, 0.101), "roof_terracotta"),
             bc.box("cloth", (0.024, 0.003, 0.010), (0.014, 0, 0.0895 + 0.0), "wall_cream"),
             bc.box("cloth", (0.014, 0.003, 0.007), (0.009, 0, 0.0815), "wall_cream")]
    return bc.assemble("ew_defense_rally_flag_v01", [("", base, (0, 0, 0), None), ("cloth", cloth, (0.0, 0, 0.101), "")])


def build_B():
    """Hanging banner from a crossbar, wooden stake base with stones."""
    base = mound(0.016, 0.006) + [bc.cone("pole", 0.0032, 0.0028, 0.108, (0, 0, 0.060), "wood_dark", 6),
                                  bc.box("bar", (0.044, 0.004, 0.004), (0, 0, 0.108), "wood_dark"),
                                  bc.cone("cap", 0.0035, 0.0, 0.007, (0, 0, 0.117), "wood_light", 6)]
    cloth = [bc.box("cloth", (0.026, 0.0032, 0.040), (0, -0.0035, 0.086), "wall_cream"),
             bc.box("cloth", (0.026, 0.0036, 0.008), (0, -0.0035, 0.098), "roof_terracotta"),
             bc.box("cloth", (0.026, 0.0036, 0.008), (0, -0.0035, 0.080), "roof_terracotta"),
             bc.box("cloth", (0.008, 0.0032, 0.008), (-0.009, -0.0035, 0.062), "wall_cream"),
             bc.box("cloth", (0.008, 0.0032, 0.008), (0.009, -0.0035, 0.062), "wall_cream")]
    return bc.assemble("ew_defense_rally_flag_v01", [("", base, (0, 0, 0), None), ("cloth", cloth, (0, -0.0035, 0.106), "")])


def build_C():
    """Spear planted in a cairn with a round shield and a small pennant."""
    base = mound(0.017, 0.007) + [bc.cone("pole", 0.0032, 0.0028, 0.108, (0, 0, 0.062), "wood_light", 6),
                                  bc.cone("spear", 0.0050, 0.0, 0.016, (0, 0, 0.1235), "stone_dark", 4, 45),
                                  ]
    shield = bc.cone("shield", 0.0150, 0.0150, 0.0045, (0, 0, 0), "roof_terracotta", 10)
    shield.location = (0, -0.0065, 0.060)
    boss = bc.cone("boss", 0.0055, 0.0055, 0.0030, (0, 0, 0), "wall_cream", 8)
    boss.location = (0, -0.0100, 0.060)
    base += [bc.rotate(shield, (90, 0, 0)), bc.rotate(boss, (90, 0, 0))]
    cloth = stepped_pennant(0.0, 0.110, 0.026, 0.0065, ("roof_terracotta", "wall_cream"), n=3)
    return bc.assemble("ew_defense_rally_flag_v01", [("", base, (0, 0, 0), None), ("cloth", cloth, (0.0, 0, 0.110), "")])


def build_D():
    """Tall pole on a tripod of leaning stakes, big stepped pennant in teal and cream."""
    base = mound(0.019, 0.006) + [bc.cone("pole", 0.0034, 0.0028, 0.128, (0, 0, 0.070), "wood_light", 6),
                                  bc.cone("cap", 0.0045, 0.0, 0.009, (0, 0, 0.1335), "wood_dark", 6)]
    for k, (x, y) in enumerate(((0.014, 0.0), (-0.007, 0.012), (-0.007, -0.012))):
        base.append(bc.cone("stake", 0.0030, 0.0020, 0.030, (x * 0.7, y * 0.7, 0.019), "wood_dark", 5, 30 * k))
    cloth = stepped_pennant(0.0, 0.126, 0.040, 0.0085, ("roof_teal", "wall_cream"), n=4)
    return bc.assemble("ew_defense_rally_flag_v01", [("", base, (0, 0, 0), None), ("cloth", cloth, (0.0, 0, 0.126), "")])


BUILDERS = {"A": build_A, "B": build_B, "C": build_C, "D": build_D}


def finish(root):
    bc.anchor(root, "ring_anchor", (0, 0, 0.001), size=RING)
    root["ew_footprint"], root["ew_front"], root["ew_place"] = "1x1", "-Y", "board"
    return root


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    v = args[0] if args else "A"
    bc.clear_scene()
    if v == "FINAL":
        letter, ver = args[1], args[2]
        root = BUILDERS[letter]()
        root.name = root.name.replace("_v01", "_" + ver)
        for ch in root.children_recursive:
            ch.name = ch.name.replace("_v01", "_" + ver)
        finish(root)
        bc.save_blend(root, "rally_flag")
        print("EXPORT", bc.export_glb(root, "defense"))
    else:
        root = BUILDERS[v]()
        finish(root)
        bc.save_blend(root, "rally_flag_" + v)
