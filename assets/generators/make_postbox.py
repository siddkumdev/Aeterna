"""Wooden postbox on a post + separate letter for quest 'Deliver the mail' (catch a fluttering letter, drop it in the postbox).
Root = wooden postbox on post (1 x 1 cell footprint, 2-2.3 cells tall = 100-112 mm, prominent front -Y mail slot),
child __letter = separate envelope (~half a cell = 24 mm wide) with red wax seal (fire_red), resting beside the postbox at z = 0.

Run one variant: blender --factory-startup -b -P assets/generators/make_postbox.py -- A  (A-D)
Front is -Y. Palette names only.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "tools"))
sys.path.insert(0, HERE)
import quest_kit as qk  # noqa: E402
from quest_kit import box, cyl, nb  # noqa: E402
import make_village_props as vp  # noqa: E402

LETTER_AT = (0.036, -0.016)


def make_letter(lx, ly, seal_col="fire_red", style="classic"):
    """Chunky readable ~24 mm parchment envelope tipped forward (+rx) toward -Y camera with bright red wax seal (min z = 0)."""
    p = []
    # Note: +rx tips the +Z top face toward -Y (front/camera)
    if style == "classic":
        p.append(nb(vp.tbox("env_body", (0.025, 0.017, 0.0040), (lx, ly, 0.0068), "wall_cream", 36, 0, 14)))
        p.append(nb(vp.tbox("env_flap", (0.024, 0.007, 0.0016), (lx - 0.001, ly + 0.0018, 0.0094), "path_stone", 36, 0, 14)))
        p.append(nb(vp.tcyl("seal", 0.0044, 0.0024, (lx, ly - 0.0014, 0.0080), seal_col, 6, rx=36, rz=14)))
    elif style == "ribbon":
        p.append(nb(vp.tbox("env_body", (0.026, 0.016, 0.0044), (lx, ly, 0.0070), "wall_cream", 34, 0, -10)))
        p.append(nb(vp.tbox("ribbon", (0.0038, 0.0166, 0.0050), (lx, ly, 0.0072), "roof_terracotta", 34, 0, -10)))
        p.append(nb(vp.tcyl("seal", 0.0048, 0.0024, (lx, ly - 0.0014, 0.0082), seal_col, 8, rx=34, rz=-10)))
    elif style == "flutter":
        p.append(nb(vp.tbox("env_body", (0.025, 0.017, 0.0038), (lx, ly, 0.0082), "wall_cream", 46, -12, 18)))
        p.append(nb(vp.tbox("wing_flap", (0.023, 0.009, 0.0022), (lx + 0.001, ly + 0.0030, 0.0145), "path_stone", 16, -12, 18)))
        p.append(nb(vp.tcyl("seal", 0.0046, 0.0024, (lx, ly - 0.0020, 0.0092), seal_col, 6, rx=46, ry=-12, rz=18)))
    else:  # folded packet
        p.append(nb(vp.tbox("packet", (0.024, 0.018, 0.0046), (lx, ly, 0.0072), "wall_cream", 36, 0, 8)))
        p.append(nb(vp.tbox("wrap", (0.0246, 0.0030, 0.0052), (lx, ly, 0.0074), "wood_mid", 36, 0, 8)))
        p.append(nb(vp.tcyl("seal", 0.0050, 0.0024, (lx, ly - 0.0016, 0.0084), seal_col, 6, rx=36, rz=8)))
    # ensure lowest point sits at z = 0 cleanly
    zmin = min((v.co.z for o in p for v in o.data.vertices))
    if abs(zmin) > 1e-4:
        for o in p:
            for v in o.data.vertices:
                v.co.z -= zmin
    return p


def variant_A():
    """Cottage gable wooden postbox with terracotta roof, cream front plaque, dark slot + red flag."""
    p = [
        nb(box("plinth", (0.022, 0.022, 0.006), (0, 0, 0.003), "stone_dark")),
        box("post", (0.010, 0.010, 0.068), (0, 0, 0.036), "wood_dark"),
        nb(vp.tbox("brace_l", (0.0036, 0.0036, 0.016), (-0.008, 0, 0.063), "wood_mid", 0, -38, 0)),
        nb(vp.tbox("brace_r", (0.0036, 0.0036, 0.016), (0.008, 0, 0.063), "wood_mid", 0, 38, 0)),
        box("box_body", (0.034, 0.030, 0.028), (0, 0, 0.082), "wood_light"),
        nb(box("slot_plate", (0.026, 0.002, 0.011), (0, -0.0155, 0.086), "wall_cream")),
        nb(box("slot", (0.021, 0.0025, 0.0045), (0, -0.0168, 0.087), "ink")),
        nb(box("visor", (0.026, 0.005, 0.0022), (0, -0.0180, 0.091), "wood_dark")),
        nb(qk.bc.gable("roof", 0.042, 0.038, 0.016, (0, 0, 0.096), "roof_terracotta")),
        nb(box("flag_arm", (0.0024, 0.003, 0.016), (0.0185, -0.002, 0.089), "wood_dark")),
        nb(box("flag", (0.0026, 0.008, 0.0065), (0.0185, -0.006, 0.094), "fire_red")),
    ]
    return p, make_letter(*LETTER_AT, style="classic")


def variant_B():
    """Barrel-top arched wooden rural mailbox with dark iron straps, braced post, open drop flap."""
    p = [
        nb(box("foot_x", (0.026, 0.010, 0.006), (0, 0, 0.003), "wood_dark")),
        nb(box("foot_y", (0.010, 0.026, 0.0056), (0, 0, 0.0028), "wood_dark")),
        box("post", (0.0095, 0.0095, 0.072), (0, 0, 0.038), "wood_mid"),
        box("shelf", (0.028, 0.038, 0.004), (0, 0, 0.072), "wood_dark"),
        nb(box("lower", (0.026, 0.036, 0.016), (0, 0, 0.082), "wood_light")),
        # arched barrel roof lying along Y
        nb(vp.tcyl("barrel", 0.0135, 0.037, (0, 0, 0.090), "wood_mid", 6, rx=90)),
        nb(vp.tcyl("strap_f", 0.0142, 0.004, (0, -0.011, 0.090), "stone_dark", 6, rx=90)),
        nb(vp.tcyl("strap_b", 0.0142, 0.004, (0, 0.011, 0.090), "stone_dark", 6, rx=90)),
        nb(box("slot_frame", (0.022, 0.002, 0.012), (0, -0.0185, 0.085), "wood_dark")),
        nb(box("slot", (0.018, 0.0022, 0.0052), (0, -0.0196, 0.086), "ink")),
        nb(vp.tbox("flap_lip", (0.020, 0.006, 0.0040), (0, -0.0215, 0.080), "wood_light", 12, 0, 0)),
        nb(box("latch", (0.006, 0.003, 0.006), (0, -0.0195, 0.094), "shell_gold")),
    ]
    return p, make_letter(*LETTER_AT, style="ribbon")


def variant_C():
    """Carved village pillar postbox in warm orange wood with stepped turret cap and cream slot surround."""
    p = [
        nb(cyl("base_stone", 0.014, 0.008, (0, 0, 0.0), "stone", 6, 0.012)),
        box("pillar", (0.014, 0.014, 0.056), (0, 0, 0.034), "wood_mid"),
        box("head_box", (0.030, 0.030, 0.034), (0, 0, 0.078), "roof_orange"),
        nb(box("band_trim", (0.033, 0.033, 0.0035), (0, 0, 0.062), "wood_dark")),
        nb(box("slot_plaque", (0.024, 0.0025, 0.012), (0, -0.0155, 0.084), "wall_cream")),
        nb(box("slot", (0.019, 0.0025, 0.0050), (0, -0.0170, 0.085), "ink")),
        nb(box("door_seam", (0.022, 0.002, 0.012), (0, -0.0155, 0.070), "wood_dark")),
        nb(cyl("cap1", 0.023, 0.008, (0, 0, 0.095), "roof_terracotta", 4, 0.011, 45)),
        nb(cyl("cap_knob", 0.004, 0.005, (0, 0, 0.103), "shell_gold", 6, 0.002)),
    ]
    return p, make_letter(*LETTER_AT, style="flutter")


def variant_D():
    """Teal-roofed owl-cote postbox with front letter ledge, open parcel cubby, and heavy pegged post."""
    p = [
        nb(box("foot", (0.020, 0.020, 0.006), (0, 0, 0.003), "stone_dark")),
        box("post", (0.010, 0.010, 0.062), (0, 0, 0.034), "wood_mid"),
        box("cubby_back", (0.032, 0.026, 0.014), (0, 0.002, 0.067), "wood_dark"),
        box("box", (0.036, 0.030, 0.026), (0, 0, 0.085), "wood_light"),
        nb(box("front_panel", (0.028, 0.002, 0.014), (0, -0.0155, 0.086), "wall_cream")),
        nb(box("slot", (0.022, 0.0025, 0.0052), (0, -0.0170, 0.088), "ink")),
        nb(box("ledge", (0.030, 0.006, 0.003), (0, -0.0185, 0.079), "wood_dark")),
        nb(qk.bc.gable("roof", 0.044, 0.038, 0.018, (0, 0, 0.098), "roof_teal")),
        nb(box("ridge", (0.004, 0.040, 0.004), (0, 0, 0.1155), "wood_dark")),
    ]
    return p, make_letter(*LETTER_AT, style="packet")


VARIANTS = {
    "A": ("Cottage gable postbox: terracotta roof, cream slot plate, red signal flag + wax-sealed letter", variant_A),
    "B": ("Barrel-top rural mailbox: arched wood top with iron straps, ajar drop flap + ribboned letter", variant_B),
    "C": ("Village pillar postbox: orange turret box, stepped terracotta cap, brass knob + tilted letter", variant_C),
    "D": ("Owl-cote postbox: teal roof, front letter ledge, lower parcel cubby + bound letter packet", variant_D),
}

def build_final():
    """Postbox (variant B) -> ew_village_postbox_v01. Letter -> ew_village_letter_v01 (own export, origin at its base
    centre; the .blend places it at LETTER_AT for the preview only)."""
    box_parts, letter = variant_B()
    lx, ly = LETTER_AT
    for o in letter:
        for v in o.data.vertices:
            v.co.x -= lx
            v.co.y -= ly
    root = qk.bc.assemble("ew_village_postbox_v01", [("", box_parts, (0, 0, 0), None)])
    root["ew_footprint"], root["ew_front"], root["ew_place"] = "1x1", "-Y", "lane_edge"
    item = qk.bc.assemble("ew_village_letter_v01", [("", letter, (0, 0, 0), None)])
    item["ew_footprint"], item["ew_front"], item["ew_place"] = "1x1", "-Y", "pickable"
    return root, item


if __name__ == "__main__":
    qk.bc.clear_scene()
    if "--" not in sys.argv:
        root, item = build_final()
        for o in [root] + list(root.children_recursive) + [item] + list(item.children_recursive):
            if o.type == "MESH":
                print(o.name, qk.tris(o), "tris")
        print("EXPORT", qk.bc.export_glb(root, "village"))
        print("EXPORT", qk.bc.export_glb(item, "village"))
        # preview blend only: the item hangs on the root at its resting spot (exports above were made at 0)
        item.name = item.data.name = root.name + "__letter"
        item.parent = root
        item.location = (LETTER_AT[0], LETTER_AT[1], 0.0)
        print("BLEND", qk.bc.save_blend(root, "postbox"))
        sys.exit(0)
    L = qk.letter_arg()
    box_parts, letter_parts = VARIANTS[L][1]()
    groups = [("", box_parts, (0, 0, 0), None), ("letter", letter_parts, (LETTER_AT[0], LETTER_AT[1], 0.0), "")]
    qk.finish(L, "postbox", groups, "1x1", "lane_edge")
