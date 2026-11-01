"""Character kit: one shared chibi body, swappable parts. Durva's character work (2026-11-01).

Run one variant:  blender --factory-startup -b -P assets/generators/make_character_kit.py -- A villager
  (saves assets/blend/char_kit_<A>_<character>.blend; variants are not exported)

Shape language only from the user's pixel-art chibi sheet (big head, small body, antennae, horns, wings,
tails, big hair); every design here is original. Colours come from art/palette.json names only.
Front is -Y (glTF forward +Z). Units are metres; a character stands about 1 cell (0.05 m) tall.

Parts (no skinned rig, each pivots where Godot rotates it):
  root         torso + skirt/dress + feet area      origin at the base
  __head       head, face, ears, front hair, hat    pivot at the neck
  __hair_back  back hair mass (sways)               pivot at the back of the head
  __arm_l/_r   sleeve + hand (+ held item)          pivot at the shoulder
  legs/boots   stay in the root: villagers hop when they walk (art bible), so the origin is the ground
  (extras: __tail, __wing_l/_r, __hat later)
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import blender_common as bc  # noqa: E402

# ---- the four kit ideas (proportions, body and hand style); round 1 of the make-asset workflow ----
KITS = {
    # A bean: giant round head on a tiny cone body, mitten hands (cutest, least detail)
    "A": dict(head_r=0.0150, squash=(1.0, 0.95, 0.92), leg=0.0060, body_h=0.0100, body_r=0.0052, body="cone",
              hands="mitten", arm_len=0.0078),
    # B doll: big head, boxy tunic body, faceted fingers (best for grabbing, waving, holding)
    "B": dict(head_r=0.0138, squash=(1.05, 0.95, 0.90), leg=0.0085, body_h=0.0125, body_r=0.0058, body="box",
              hands="fingers", arm_len=0.0095),
    # C acorn: head wider than tall, A-line dress body, mitten hands (soft and round)
    "C": dict(head_r=0.0135, squash=(1.18, 1.0, 0.84), leg=0.0070, body_h=0.0115, body_r=0.0060, body="dress",
              hands="mitten", arm_len=0.0085),
    # D peg: a bit taller (3-head), long legs, bigger fingered hands (most expressive, least chibi)
    "D": dict(head_r=0.0125, squash=(1.0, 0.95, 0.95), leg=0.0110, body_h=0.0140, body_r=0.0056, body="cone",
              hands="fingers", arm_len=0.0115),
}

# ---- characters (what is swapped on the kit) ----
CHARACTERS = {
    # round 1 test pair: a villager (hair, plain clothes) and a goblin (skin, ears, no hair)
    "villager": dict(skin="skin_light", hair="flower_pink", hair_style="bob", top="roof_teal", bottom="wall_cream",
                     boots="wood_dark", ears="round", eye="ink", cheeks="flower_pink", hat=None, scarf="lantern_glow"),
    "goblin": dict(skin="leaf_light", hair=None, hair_style="tuft", top="wood_mid", bottom="wood_dark",
                   boots="wood_dark", ears="goblin", eye="ink", cheeks="leaf_green", hat=None, scarf=None),
}


def ell_y(rx, ry, rz, x, z):
    """Front (-Y) surface of an ellipsoid at (x, z), so face bits sit on the head instead of floating."""
    t = 1 - (x / rx) ** 2 - (z / rz) ** 2
    return -ry * math.sqrt(max(t, 0.0))


def head_parts(k, c, hz):
    r = k["head_r"]
    sx, sy, sz = k["squash"]
    rx, ry, rz = r * sx, r * sy, r * sz
    P = []
    P.append(bc.blob("skull", r, (0, 0, hz), c["skin"], 2, (sx, sy, sz)))
    # eyes: tall ink ovals low on the face (chibi), each with a tiny bone sparkle
    ex, ez = rx * 0.44, -rz * 0.14
    for s in (-1, 1):
        y = ell_y(rx, ry, rz, ex, ez)
        e = bc.blob("eye", r * 0.20, (s * ex, y + r * 0.03, hz + ez), c["eye"], 1, (0.85, 0.5, 1.3))
        P.append(e)
        P.append(bc.blob("sparkle", r * 0.06, (s * ex + r * 0.04, y - r * 0.06, hz + ez + r * 0.10), "bone", 1))
        cy = ell_y(rx, ry, rz, s * rx * 0.66, -rz * 0.36)
        P.append(bc.blob("cheek", r * 0.11, (s * rx * 0.66, cy + r * 0.01, hz - rz * 0.36), c["cheeks"], 1, (1.0, 0.35, 0.7)))
    # ears
    et = c["ears"]
    for s in (-1, 1):
        if et == "round":
            P.append(bc.blob("ear", r * 0.20, (s * rx * 0.98, 0, hz - rz * 0.08), c["skin"], 1, (0.55, 0.8, 1.0)))
        elif et == "goblin":
            ear = bc.cone("ear", r * 0.30, 0.0, r * 0.95, (0, 0, 0), c["skin"], 4)
            ear["no_bevel"] = True
            bc.rotate(ear, (0, s * 100, 0))
            ear.location = (s * (rx * 1.10 + r * 0.30), r * 0.05, hz + rz * 0.12)
            bc.apply_transforms(ear)
            P.append(ear)
            P.append(bc.blob("earbase", r * 0.18, (s * rx * 0.98, 0, hz + rz * 0.02), c["skin"], 1, (0.55, 0.8, 1.0)))
    # hair
    hair, style = c["hair"], c["hair_style"]
    if hair and style in ("bob", "buns", "long", "spiky"):
        # cap: a bigger ellipsoid shifted up and back, so the face stays open in front
        P.append(bc.blob("hair_cap", r * 1.07, (0, r * 0.20, hz + r * 0.24), hair, 2, (sx, sy * 1.02, sz * 0.98)))
        # fringe (three wedges across the brow)
        for i, fx in enumerate((-0.50, 0.0, 0.50)):
            fz = hz + rz * 0.60 - (0.06 if i == 1 else 0.0) * r
            fy = ell_y(rx, ry, rz, fx * rx, fz - hz) - r * 0.015
            P.append(bc.box("fringe", (r * 0.52, r * 0.14, r * 0.26), (fx * rx, fy, fz), hair, rot_z_deg=0))
    if hair and style == "bob":
        for s in (-1, 1):  # side locks down to the jaw
            P.append(bc.box("lock", (r * 0.20, r * 0.46, r * 0.62), (s * rx * 0.90, r * 0.12, hz - rz * 0.10), hair))
    if hair and style == "buns":
        for s in (-1, 1):
            P.append(bc.blob("bun", r * 0.34, (s * rx * 0.72, r * 0.05, hz + rz * 1.05), hair, 1))
    if hair and style == "spiky":
        for i in range(6):
            a = math.radians(i * 60 + 20)
            sp = bc.cone("spike", r * 0.20, 0.0, r * 0.55, (0, 0, 0), hair, 4)
            sp["no_bevel"] = True
            bc.rotate(sp, (math.degrees(math.sin(a)) * 0.55, -math.degrees(math.cos(a)) * 0.55, 0))
            sp.location = (rx * 0.62 * math.cos(a), ry * 0.62 * math.sin(a) + r * 0.1, hz + rz * 0.92)
            bc.apply_transforms(sp)
            P.append(sp)
    if style == "tuft":  # goblin: a single wild tuft
        t = bc.cone("tuft", r * 0.16, 0.0, r * 0.55, (0, -r * 0.1, hz + rz * 1.15), "leaf_dark", 4)
        t["no_bevel"] = True
        P.append(t)
    return P


def hair_back_parts(k, c, hz):
    r = k["head_r"]
    sx, sy, sz = k["squash"]
    if not c["hair"] or c["hair_style"] not in ("long", "bob"):
        return []
    drop = r * (1.45 if c["hair_style"] == "long" else 0.8)
    return [bc.box("hair_back", (r * 1.55 * sx, r * 0.55, drop), (0, r * sy * 0.78, hz - r * 0.2 - drop / 2 + r * 0.45), c["hair"])]


def hand_parts(k, c, s, x, z):
    """A hand hanging at (x, 0, z), s = side. mitten = one faceted ball, fingers = palm + thumb + two fingers."""
    out = []
    if k["hands"] == "mitten":
        out.append(bc.blob("hand", 0.0030, (x, 0, z), c["skin"], 1))
    else:
        out.append(bc.box("palm", (0.0042, 0.0030, 0.0042), (x, 0, z), c["skin"]))
        out.append(bc.box("thumb", (0.0015, 0.0018, 0.0028), (x - s * 0.0026, -0.0006, z + 0.0002), c["skin"]))
        for j, dy in enumerate((-0.0009, 0.0009)):
            out.append(bc.box("finger", (0.0016, 0.0013, 0.0030), (x + s * 0.0008, dy, z - 0.0034), c["skin"]))
    return out


def build_character(name, kit, char):
    k, c = KITS[kit], CHARACTERS[char]
    lh, bh, br = k["leg"], k["body_h"], k["body_r"]
    neck = lh + bh
    hz = neck + k["head_r"] * k["squash"][2] * 0.80  # head centre
    root, head, hairb, arms, legs = [], [], [], {}, {}
    # torso
    if k["body"] == "box":
        root.append(bc.box("torso", (br * 2.0, br * 1.6, bh), (0, 0, lh + bh / 2), c["top"]))
        root.append(bc.box("belt", (br * 2.05, br * 1.65, bh * 0.14), (0, 0, lh + bh * 0.18), "wood_dark"))
        root.append(bc.box("hem", (br * 2.1, br * 1.7, bh * 0.22), (0, 0, lh + bh * 0.11), c["bottom"]))
    elif k["body"] == "dress":
        root.append(bc.cone("torso", br * 1.55, br * 0.85, bh, (0, 0, lh + bh / 2), c["top"], 8))
        root.append(bc.cone("skirt", br * 1.95, br * 1.35, bh * 0.45, (0, 0, lh + bh * 0.225), c["bottom"], 8))
    else:  # cone
        root.append(bc.cone("torso", br * 1.25, br * 0.85, bh, (0, 0, lh + bh / 2), c["top"], 8))
        root.append(bc.cone("hem", br * 1.30, br * 1.22, bh * 0.20, (0, 0, lh + bh * 0.10), c["bottom"], 8))
    if c["scarf"]:
        root.append(bc.cone("scarf", br * 1.05, br * 0.95, bh * 0.20, (0, 0, neck - bh * 0.06), c["scarf"], 8))
    # head parts (move with the neck)
    head += head_parts(k, c, hz)
    hairb += hair_back_parts(k, c, hz)
    # arms and legs
    groups = [("", root, (0, 0, 0), "")]
    ssx, ssz = br * 1.15 + 0.0012, neck - 0.0030
    for s, side in ((-1, "l"), (1, "r")):
        al = k["arm_len"]
        sleeve = bc.cone("sleeve", 0.0028, 0.0033, al * 0.62, (s * ssx, 0, ssz - al * 0.31), c["top"], 6)
        hand = hand_parts(k, c, s, s * ssx, ssz - al * 0.62 - 0.0014)
        groups.append(("arm_" + side, [sleeve] + hand, (s * ssx, 0, ssz), ""))
        hx = br * 0.55
        leg = bc.cone("leg", 0.0026, 0.0030, lh, (s * hx, 0, lh / 2), c["skin"], 6)
        boot = bc.box("boot", (0.0058, 0.0085, 0.0034), (s * hx, -0.0012, 0.0017), c["boots"])
        root += [leg, boot]
    groups.append(("head", head, (0, 0, neck), ""))
    if hairb:
        groups.append(("hair_back", hairb, (0, k["head_r"] * 0.7, hz), "head"))
    return bc.assemble(name, groups)


def tri_count(root):
    import bpy
    n = 0
    for o in [root] + list(root.children_recursive):
        if o.type == "MESH":
            n += sum(len(p.vertices) - 2 for p in o.data.polygons)
    return n


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    kit = argv[0] if argv else "A"
    char = argv[1] if len(argv) > 1 else "villager"
    bc.clear_scene()
    obj = build_character("ew_village_charkit_%s_v01" % char if char != "goblin" else "ew_enemy_charkit_goblin_v01", kit, char)
    print("TRIS", kit, char, tri_count(obj))
    bc.save_blend(obj, "char_kit_%s_%s" % (kit, char))
