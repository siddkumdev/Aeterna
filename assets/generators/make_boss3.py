"""The Warden, round 3: mythic creature bosses (Durva 2026-11-02: "not inanimate objects, otherworldly creatures: world serpents, fenrir,
unicorns, sphinx, crazy creatures with maximum colour, extreme detail and beauty, but still original and terrifying").

Run one:  blender --factory-startup -b -P assets/generators/make_boss3.py -- <key>     (saves assets/blend/boss_<key>.blend)
  aurora_wyrm   the world serpent: three rainbow coils round the board, a reared head with a flared frill, horns, four eyes, fangs, flame mane
  moonmaw       the star-furred hound of the end: flame ruff, comet tail, gaping jaws, six eyes, tattered ears, broken gold manacles
  dawn_chimera  the crouched sphinx-unicorn: three-eyed fanged face, a long twisted horn, rainbow feather wings and mane, serpent tail
Original creatures inspired by those myths, not copies. Colours: the existing palette only (it is full at 64): jade, mint, lime, gold, copper, orange,
red, coral, rose, pink and the Warden purples. No blue (Foresight). Footprint about 0.15 m, height about 0.2 m, budget 6000.
Anchors on each: crystal_anchor_1..3, eye_anchor, summon_anchor (+ mouth / horn / sting anchors). Earlier boss rounds stay for comparison.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_characters as mc  # noqa: E402
import make_enemies2 as me  # noqa: E402

bc, V, seg, chain, flat, place, ring3d = mc.bc, mc.V, mc.seg, mc.chain, mc.flat, mc.place, me.ring3d
PI = math.pi

RAINBOW = ["shell_jade", "hair_mint", "hair_lime", "leaf_yellow", "shell_gold", "roof_orange", "fire_red", "cloth_coral", "cloth_rose", "flower_pink", "warden_deep"]
FLAME = ["fire_red", "roof_orange", "fire_yellow", "cloth_coral", "flower_yellow", "fire_red"]
FEATHER = ["shell_jade", "hair_mint", "hair_lime", "flower_yellow", "shell_gold", "roof_orange", "cloth_coral", "cloth_rose"]


def grad(cols, t):
    return cols[max(0, min(len(cols) - 1, int(t * len(cols))))]


def scale_about(objs, c, k):
    """Scale already-placed parts about a centre (their meshes are in world coordinates)."""
    c = V(c)
    for o in objs:
        for v in o.data.vertices:
            v.co = c + (v.co - c) * k


def crystal_anchors(obj, z, r=0.1000):
    for i in range(3):
        a = math.radians(i * 120 + 90)
        bc.anchor(obj, "crystal_anchor_%d" % (i + 1), (math.cos(a) * r, math.sin(a) * r, z), "", 0.008)


def eye(p, R, col="fire_yellow", pupil="ink", facing=0.0):
    """An eye with a slit pupil, built at the origin facing -Y then placed (facing = rotation about Z, degrees)."""
    P = [bc.blob("eye", R, (0, 0, 0), col, 1, (1.0, 0.55, 1.15)), bc.box("pupil", (R * 0.28, R * 0.30, R * 1.55), (0, -R * 0.50, 0), pupil)]
    for o in P:
        place(o, (0, 0, facing), p)
    return P


def bez(p0, p1, p2, p3, t):
    u = 1 - t
    return u ** 3 * V(p0) + 3 * u * u * t * V(p1) + 3 * u * t * t * V(p2) + t ** 3 * V(p3)


def fan(base, tipdir, L, W, col, plane_w):
    """A leaf-shaped feather from `base` along tipdir (unit), width direction plane_w (unit), length L, width W."""
    b, d, w = V(base), V(tipdir), V(plane_w)
    pts = [b, b + d * L * 0.30 + w * W * 0.5, b + d * L * 0.80 + w * W * 0.38, b + d * L, b + d * L * 0.80 - w * W * 0.38, b + d * L * 0.30 - w * W * 0.5]
    return [tuple(p) for p in pts]


# ============================================================================= 1. AURORA WYRM (world serpent)
def aurora_wyrm():
    N = 50
    pts, rads, cols = [], [], []
    P0, P1, P2, P3 = (0, 0.040, 0.116), (0, 0.066, 0.170), (0, 0.032, 0.222), (0, -0.028, 0.208)
    for i in range(N):
        t = i / (N - 1)
        if t < 0.80:
            u = t / 0.80
            th = 2 * PI * 3.0 * u + PI / 2
            R = 0.062 - 0.022 * u
            z = 0.0050 + 0.108 * u ** 1.05
            p = V((math.cos(th) * R, math.sin(th) * R, z))
            rad = 0.0040 + 0.0082 * (u ** 0.8)
        else:
            v = (t - 0.80) / 0.20
            p = bez(P0, P1, P2, P3, v)
            rad = 0.0122 - 0.0034 * v
        pts.append(p)
        rads.append(rad * 1.38)
        cols.append(grad(RAINBOW, t))
    root = []
    for i in range(N - 1):
        root.append(seg("body", pts[i], pts[i + 1], rads[i], rads[i + 1], cols[i] if i % 4 else "shell_gold", 10))
        root.append(bc.blob("joint", rads[i + 1] * 1.04, pts[i + 1], cols[i], 1))
        up = V((0, 0, 1))
        if i < 40:
            radial = V((pts[i].x, pts[i].y, 0)).normalized()
            up = (radial * 0.6 + V((0, 0, 1))).normalized()
        if i % 2:
            root.append(seg("spike", pts[i] + up * rads[i] * 0.8, pts[i] + up * rads[i] * (2.6 if i % 2 else 1.9), rads[i] * 0.55, 0.0002, "warden_deep" if i % 3 else "fire_yellow", 4))
    root += [seg("tailspike", pts[0], pts[0] + V((0.0030, 0.0030, 0.0140)), 0.0030, 0.0002, "fire_yellow", 5), bc.blob("tip", 0.0040, pts[0], "shell_gold", 1)]
    for k in range(6):  # tail rattle crown
        a = 2 * PI * k / 6
        root.append(seg("tailfin", pts[1], pts[1] + V((math.cos(a) * 0.0090, math.sin(a) * 0.0090, 0.0100)), 0.0024, 0.0002, grad(FLAME, k / 6), 4))
    groups = [("", root, (0, 0, 0), "")]

    H = pts[-1]
    PITCH = 24
    head, jaw, frill = [], [], []

    for name, R, col, sub, sq, off in (("skull", 0.0160, "warden_deep", 3, (0.85, 1.50, 0.78), (0, -0.004, 0)), ("snout", 0.0105, "shell_jade", 2, (0.85, 1.35, 0.62), (0, -0.026, -0.003)),
                                       ("snout_gold", 0.0075, "shell_gold", 2, (0.9, 1.3, 0.5), (0, -0.034, -0.0048))):
        head.append(place(bc.blob(name, R, off, col, sub, sq), (PITCH, 0, 0), tuple(H)))
    for s in (-1, 1):
        for (ex, ey, ez, R_, col) in ((0.0105, -0.012, 0.0070, 0.0040, "fire_yellow"), (0.0080, -0.003, 0.0098, 0.0024, "fire_red")):
            head += [place(o, (PITCH, 0, 0), tuple(H)) for o in eye((s * ex, ey, ez), R_, col)]
        head.append(place(bc.box("brow", (0.0060, 0.0100, 0.0020), (s * 0.0100, -0.0100, 0.0115), "warden_dark"), (PITCH, 0, 0), tuple(H)))
        head += [place(o, (PITCH, 0, 0), tuple(H)) for o in chain("horn", [V((s * 0.0070, 0.0020, 0.0100)), V((s * 0.0150, 0.0110, 0.0230)), V((s * 0.0230, 0.0260, 0.0280)), V((s * 0.0250, 0.0420, 0.0200)), V((s * 0.0200, 0.0520, 0.0080))],
                                                              [0.0052, 0.0044, 0.0034, 0.0022, 0.0003], "shell_gold" if s < 0 else "shell_copper", 8)]
        head.append(place(seg("fang", V((s * 0.0050, -0.0300, -0.0030)), V((s * 0.0058, -0.0330, -0.0210)), 0.0026, 0.0002, "bone", 5), (PITCH, 0, 0), tuple(H)))
        for fy in (-0.012, -0.020):
            head.append(place(seg("tooth", V((s * 0.0070, fy, -0.0030)), V((s * 0.0074, fy, -0.0095)), 0.0012, 0.0002, "bone", 4), (PITCH, 0, 0), tuple(H)))
        head += [place(o, (PITCH, 0, 0), tuple(H)) for o in chain("whisker", [V((s * 0.0080, -0.0260, -0.0010)), V((s * 0.0220, -0.0320, 0.0000)), V((s * 0.0400, -0.0200, 0.0040)), V((s * 0.0540, 0.0020, 0.0140))],
                                                                  [0.0011, 0.0010, 0.0008, 0.0003], "shell_gold", 4, ball_tip=(0.0024, "fire_yellow"))]
    HS = 1.45
    scale_about(head, H, HS)
    groups.append(("head", head, tuple(H), ""))
    jw = [place(bc.blob("jaw", 0.0100, (0, -0.0250, -0.0090), "shell_jade", 2, (0.72, 1.40, 0.36)), (PITCH + 26, 0, 0), tuple(H)),
          place(seg("tongue", V((-0.0012, -0.0180, -0.0080)), V((-0.0040, -0.0450, -0.0180)), 0.0014, 0.0004, "fire_red", 4), (PITCH + 26, 0, 0), tuple(H)),
          place(seg("tongue", V((0.0012, -0.0180, -0.0080)), V((0.0040, -0.0450, -0.0180)), 0.0014, 0.0004, "fire_red", 4), (PITCH + 26, 0, 0), tuple(H))]
    for s in (-1, 1):
        jw.append(place(seg("fang", V((s * 0.0045, -0.0300, -0.0090)), V((s * 0.0050, -0.0330, 0.0040)), 0.0022, 0.0002, "bone", 5), (PITCH + 26, 0, 0), tuple(H)))
    scale_about(jw, H, HS)
    groups.append(("jaw", jw, tuple(H + V((0, 0.004, -0.004))), "head"))
    # cobra-like frill: spokes and rainbow webbing, flared behind the head
    c0 = V((0, 0.0080, 0.0000))
    spokes = []
    for k in range(11):
        a = math.radians(-125 + k * 25)
        L_ = 0.0420 if k % 2 == 0 else 0.0300
        spokes.append(V((math.sin(a) * L_, 0.0080 + 0.0080 * abs(math.sin(a)), math.cos(a) * L_)))
    for k in range(11):
        frill.append(place(seg("spoke", c0, spokes[k], 0.0020, 0.0006, "shell_gold", 5), (PITCH, 0, 0), tuple(H)))
    for k in range(10):
        frill.append(place(flat("web", [tuple(c0), tuple(spokes[k]), tuple(spokes[k + 1])], 0.0010, grad(RAINBOW[::-1], k / 10)), (PITCH, 0, 0), tuple(H)))
    for k in range(0, 11, 2):
        frill.append(place(bc.blob("eyespot", 0.0030, tuple(c0 + (spokes[k] - c0) * 0.62 + V((0, 0.0012, 0))), "ink", 1, (1, 0.4, 1)), (PITCH, 0, 0), tuple(H)))
    scale_about(frill, H, HS)
    groups.append(("frill", frill, tuple(H + V((0, 0.0080, 0))), "head"))
    mane = []
    for k in range(12):  # flame mane down the neck
        i = 40 + k
        if i >= N - 1:
            break
        p = pts[i]
        side = -1 if k % 2 else 1
        mane += chain("flame", [p + V((0, 0, rads[i] * 0.9)), p + V((side * 0.0070, 0.0090, rads[i] + 0.0100)), p + V((side * 0.0140, 0.0200, rads[i] + 0.0180))],
                      [0.0034, 0.0026, 0.0004], grad(FLAME, k / 12), 4)
    groups.append(("mane", mane, tuple(pts[44]), ""))
    stars = []
    for k in range(14):
        a = 2 * PI * k / 14
        p = V((math.cos(a) * 0.1040, math.sin(a) * 0.1040, 0.0700 + 0.0450 * math.sin(k * 1.9)))
        stars.append(seg("star", p + V((0, 0, -0.0080)), p + V((0, 0, 0.0080)), 0.0036, 0.0002, grad(RAINBOW, k / 14), 4))
        stars.append(seg("star", p + V((0, 0, -0.0080)), p + V((0, 0, -0.0150)), 0.0026, 0.0002, grad(RAINBOW, k / 14), 4))
    groups.append(("stars", stars, (0, 0, 0.0900), ""))
    obj = bc.assemble("ew_boss_aurora_wyrm_v01", groups)
    crystal_anchors(obj, 0.1000)
    bc.anchor(obj, "eye_anchor", tuple(H + V((0.0105, -0.0140, 0.0050))), "head", 0.005)
    bc.anchor(obj, "mouth_anchor", tuple(H + V((0, -0.0420, -0.0210)) * 1.0), "jaw", 0.006)
    bc.anchor(obj, "summon_anchor", (0, -0.0950, 0.0150), "", 0.008)
    return obj


# ============================================================================= 2. MOONMAW (the hound of the end)
def moonmaw():
    root = [bc.blob("chest", 0.0300, (0, -0.0300, 0.0720), "warden_dark", 3, (1.00, 1.35, 1.05)),
            bc.blob("rump", 0.0270, (0, 0.0420, 0.0640), "warden_dark", 3, (0.95, 1.30, 1.00)),
            bc.blob("belly", 0.0240, (0, 0.0050, 0.0540), "warden_deep", 2, (1.0, 2.0, 0.8)),
            seg("waist", V((0, -0.0100, 0.0700)), V((0, 0.0300, 0.0640)), 0.0240, 0.0230, "warden_dark", 12)]
    neck = chain("neck", [V((0, -0.0520, 0.0880)), V((0, -0.0680, 0.1060)), V((0, -0.0760, 0.1230))], [0.0200, 0.0180, 0.0150], "warden_dark", 10)
    root += neck
    for k in range(14):  # dark star-fur spikes along the back
        y = -0.0400 + k * 0.0080
        z = 0.0980 - 0.0040 * math.sin(k / 14 * PI) * -1 - abs(k - 4) * 0.0012
        root.append(seg("spine", V((0, y, z)), V((0, y + 0.0060, z + 0.0150 - 0.0006 * k)), 0.0042, 0.0002, "crystal_purple" if k % 2 else "warden_deep", 4))
    for ring in range(3):  # flame ruff around the neck and shoulders
        for k in range(10):
            a = 2 * PI * k / 10 + ring * 0.3
            c0 = V((0, -0.0560 - ring * 0.0100, 0.0900 + ring * 0.0170))
            d = V((math.cos(a) * 1.0, -0.3 + math.sin(a) * 0.4, math.sin(a) * 0.9 + 0.2)).normalized()
            root.append(seg("fur", c0 + d * 0.0180, c0 + d * (0.0300 + 0.0040 * ((k + ring) % 3)), 0.0050, 0.0002, grad(FLAME, ((k + ring * 4) % 12) / 12), 4))
    for s in (-1, 1):  # four legs, claws, manacles, broken chain
        for front in (True, False):
            if front:
                pts = [V((s * 0.0200, -0.0400, 0.0640)), V((s * 0.0260, -0.0480, 0.0320)), V((s * 0.0260, -0.0420, 0.0040))]
            else:
                pts = [V((s * 0.0200, 0.0450, 0.0620)), V((s * 0.0290, 0.0620, 0.0350)), V((s * 0.0260, 0.0480, 0.0040))]
            root += chain("leg", pts, [0.0105, 0.0085, 0.0070], "warden_dark", 8)
            paw = pts[-1] + V((0, -0.0040, 0.0010))
            root.append(bc.blob("paw", 0.0078, paw, "warden_deep", 2, (1.0, 1.35, 0.6)))
            for c in range(4):
                root.append(seg("claw", paw + V(((c - 1.5) * 0.0036 * 1.0, -0.0070, 0.0010)), paw + V(((c - 1.5) * 0.0040, -0.0140, -0.0018)), 0.0017, 0.0002, "bone", 4))
            root += ring3d((pts[-1].x, pts[-1].y, 0.0180), 0.0100, 0.0020, 8, "shell_gold", "xy")
            root += chain("chain", [V((pts[-1].x + s * 0.0100, pts[-1].y, 0.0180)), V((pts[-1].x + s * 0.0200, pts[-1].y - 0.0040, 0.0100)), V((pts[-1].x + s * 0.0270, pts[-1].y - 0.0100, 0.0020))], [0.0014] * 3, "shell_gold", 4)
            root.append(bc.cone("link", 0.0030, 0.0030, 0.0024, (pts[-1].x + s * 0.0270, pts[-1].y - 0.0100, 0.0016), "shell_copper", 6))
    for (cc, rr3) in (((0, -0.0300, 0.0720), (0.0300, 0.0405, 0.0315)), ((0, 0.0420, 0.0640), (0.0257, 0.0351, 0.0270))):  # rainbow star-spots on the fur
        for k in range(10):
            ph = 2.399963 * k
            zz = 0.95 - 1.6 * k / 9.0
            rr_ = math.sqrt(max(0.0, 1 - zz * zz))
            u = V((math.cos(ph) * rr_, math.sin(ph) * rr_, zz))
            pos = V(cc) + V((u.x * rr3[0], u.y * rr3[1], u.z * rr3[2])) * 1.01
            root.append(bc.blob("starspot", 0.0026 + 0.0006 * (k % 3), tuple(pos), RAINBOW[(k * 2 + (0 if cc[1] < 0 else 5)) % len(RAINBOW)], 1, (1, 1, 0.7)))
    groups = [("", root, (0, 0, 0), "")]
    HEAD = V((0, -0.0880, 0.1300))
    PITCH = 14
    head = []

    def hp(o):
        return place(o, (PITCH, 0, 0), tuple(HEAD))
    head += [hp(bc.blob("skull", 0.0190, (0, 0, 0), "warden_dark", 3, (0.85, 1.30, 0.78))), hp(bc.blob("snout", 0.0130, (0, -0.0210, -0.0040), "warden_deep", 3, (0.78, 1.35, 0.60))),
             hp(bc.blob("nose", 0.0042, (0, -0.0400, 0.0010), "ink", 1))]
    for s in (-1, 1):
        for (ex, ey, ez, R_, col) in ((0.0115, -0.0150, 0.0100, 0.0036, "fire_yellow"), (0.0125, -0.0070, 0.0105, 0.0028, "fire_red"), (0.0108, 0.0000, 0.0100, 0.0022, "fire_yellow")):
            head += [hp(o) for o in eye((s * ex, ey, ez), R_, col, "ink")]
        head.append(hp(bc.box("brow", (0.0050, 0.0200, 0.0020), (s * 0.0110, -0.0070, 0.0140), "ink")))
        head += [hp(flat("ear", [(s * 0.0070, 0.0050, 0.0140), (s * 0.0100, 0.0040, 0.0400), (s * 0.0150, 0.0040, 0.0300), (s * 0.0170, 0.0040, 0.0330), (s * 0.0190, 0.0040, 0.0200), (s * 0.0130, 0.0040, 0.0130)], 0.0015, "warden_deep"))]
        head += [hp(o) for o in chain("horn", [V((s * 0.0090, 0.0060, 0.0120)), V((s * 0.0180, 0.0120, 0.0230)), V((s * 0.0220, 0.0200, 0.0380))], [0.0050, 0.0038, 0.0003], "shell_gold", 8)]
        for (fx, fy) in ((0.0070, -0.0300), (0.0080, -0.0230)):
            head.append(hp(seg("fang", V((s * fx, fy, -0.0070)), V((s * (fx + 0.0004), fy - 0.0020, -0.0270 if fy < -0.026 else -0.0200)), 0.0030 if fy < -0.026 else 0.0024, 0.0002, "bone", 5)))
        for k in range(3):
            head.append(hp(seg("tooth", V((s * 0.0090, -0.0040 - k * 0.0050, -0.0070)), V((s * 0.0094, -0.0040 - k * 0.0050, -0.0140)), 0.0014, 0.0002, "bone", 4)))
        head.append(hp(seg("scar", V((s * 0.0140, -0.0200, 0.0090)), V((s * 0.0120, -0.0050, 0.0050)), 0.0006, 0.0006, "fire_red", 4)))
    groups.append(("head", head, tuple(HEAD), ""))
    JP = (PITCH + 30, 0, 0)
    jaw = [place(bc.blob("jaw", 0.0125, (0, -0.0190, -0.0100), "warden_deep", 2, (0.70, 1.40, 0.38)), JP, tuple(HEAD)), place(bc.blob("tongue", 0.0060, (0, -0.0170, -0.0070), "fire_red", 1, (0.8, 2.0, 0.4)), JP, tuple(HEAD))]
    for s in (-1, 1):
        jaw.append(place(seg("fang", V((s * 0.0060, -0.0300, -0.0090)), V((s * 0.0066, -0.0320, 0.0090)), 0.0028, 0.0002, "bone", 5), JP, tuple(HEAD)))
        for k in range(3):
            jaw.append(place(seg("tooth", V((s * 0.0090, -0.0100 - k * 0.0060, -0.0080)), V((s * 0.0094, -0.0100 - k * 0.0060, -0.0000)), 0.0014, 0.0002, "bone", 4), JP, tuple(HEAD)))
    groups.append(("jaw", jaw, tuple(HEAD + V((0, 0.0060, -0.0060))), "head"))
    tail = []
    for k in range(7):  # comet tail: seven-colour flame plume
        side = (k - 3.0) * 0.0048
        pts = [V((0, 0.0620, 0.0700)), V((side * 0.6, 0.0820, 0.0880 + 0.0020 * k)), V((side * 1.6, 0.1000, 0.1120 + 0.0030 * k)), V((side * 2.4, 0.1130, 0.1400 + 0.0040 * k)), V((side * 2.8, 0.1200, 0.1650 + 0.0030 * k))]
        tail += chain("plume", pts, [0.0060, 0.0050, 0.0036, 0.0020, 0.0003], FEATHER[k % len(FEATHER)] if k % 2 else grad(FLAME, k / 8), 4)
    groups.append(("tail", tail, (0, 0.0620, 0.0700), ""))
    obj = bc.assemble("ew_boss_moonmaw_v01", groups)
    crystal_anchors(obj, 0.0800, 0.1050)
    bc.anchor(obj, "eye_anchor", tuple(HEAD + V((0.0115, -0.0180, 0.0120))), "head", 0.005)
    bc.anchor(obj, "mouth_anchor", tuple(HEAD + V((0, -0.0300, -0.0220))), "jaw", 0.007)
    bc.anchor(obj, "summon_anchor", (0, -0.1000, 0.0150), "", 0.008)
    return obj


# ============================================================================= 3. DAWN CHIMERA (sphinx-unicorn)
def dawn_chimera():
    root = [bc.blob("haunch", 0.0340, (0, 0.0420, 0.0340), "roof_orange", 3, (1.10, 1.20, 0.85)), bc.blob("torso", 0.0300, (0, 0.0000, 0.0440), "roof_orange", 3, (1.00, 1.50, 0.95)),
            bc.blob("chest", 0.0260, (0, -0.0300, 0.0580), "shell_gold", 3, (1.00, 1.00, 1.20)), bc.blob("gem", 0.0050, (0, -0.0540, 0.0580), "fire_red", 2, (1, 0.6, 1.4))]
    for k in range(7):  # dark tiger stripes
        root.append(bc.box("stripe", (0.0640, 0.0040, 0.0040), (0, -0.0100 + k * 0.0100, 0.0690 - 0.0020 * abs(k - 3)), "ink"))
    for k in range(14):  # spine spikes
        y = -0.0200 + k * 0.0070
        root.append(seg("spine", V((0, y, 0.0690 - 0.0030 * abs(k - 6) * 0.3)), V((0, y + 0.0030, 0.0830 - 0.0030 * abs(k - 6) * 0.3)), 0.0034, 0.0002, "shell_jade" if k % 2 else "shell_gold", 4))
    for s in (-1, 1):  # forelegs stretched forward, paws with long claws; hind feet tucked
        pts = [V((s * 0.0190, -0.0250, 0.0460)), V((s * 0.0210, -0.0520, 0.0160)), V((s * 0.0210, -0.0800, 0.0080))]
        root += chain("foreleg", pts, [0.0120, 0.0100, 0.0090], "shell_gold", 8)
        paw = pts[-1] + V((0, -0.0050, 0.0000))
        root.append(bc.blob("paw", 0.0095, paw, "roof_orange", 2, (1.0, 1.35, 0.6)))
        for c in range(5):
            root.append(seg("claw", paw + V(((c - 2) * 0.0030, -0.0090, 0.0010)), paw + V(((c - 2) * 0.0036, -0.0190, 0.0000)), 0.0020, 0.0002, "bone", 4))
        root.append(bc.blob("foot", 0.0110, (s * 0.0260, 0.0300, 0.0070), "roof_orange", 2, (1.0, 1.5, 0.55)))
        for c in range(3):
            root.append(seg("hclaw", V((s * 0.0260 + (c - 1) * 0.0040, 0.0100, 0.0030)), V((s * 0.0260 + (c - 1) * 0.0046, 0.0000, 0.0000)), 0.0020, 0.0002, "bone", 4))
    root += chain("neck", [V((0, -0.0300, 0.0700)), V((0, -0.0380, 0.0950)), V((0, -0.0440, 0.1200))], [0.0170, 0.0150, 0.0130], "shell_gold", 10)
    root += ring3d((0, -0.0380, 0.0950), 0.0160, 0.0020, 10, "shell_copper", "xy") + ring3d((0, -0.0410, 0.1090), 0.0145, 0.0020, 10, "shell_gold", "xy")
    groups = [("", root, (0, 0, 0), "")]
    H = V((0, -0.0500, 0.1380))
    PITCH = -8
    head = []

    def hp(o):
        return place(o, (PITCH, 0, 0), tuple(H))
    head += [hp(bc.blob("face", 0.0170, (0, 0, 0), "roof_orange", 3, (0.85, 0.92, 1.10))), hp(bc.blob("muzzle", 0.0100, (0, -0.0120, -0.0090), "shell_gold", 2, (0.9, 1.1, 0.7))),
             hp(bc.box("nosebridge", (0.0040, 0.0040, 0.0140), (0, -0.0150, 0.0040), "shell_copper"))]
    head += [hp(o) for o in eye((-0.0085, -0.0140, 0.0050), 0.0036, "fire_yellow")] + [hp(o) for o in eye((0.0085, -0.0140, 0.0050), 0.0036, "fire_yellow")]
    head += [hp(o) for o in eye((0, -0.0150, 0.0130), 0.0026, "fire_red")]
    for s in (-1, 1):
        head.append(hp(seg("cheekspike", V((s * 0.0130, -0.0040, -0.0020)), V((s * 0.0260, 0.0000, -0.0080)), 0.0034, 0.0002, "shell_gold", 5)))
        head.append(hp(seg("cheekspike", V((s * 0.0120, 0.0000, 0.0020)), V((s * 0.0240, 0.0060, 0.0040)), 0.0028, 0.0002, "shell_copper", 5)))
        head += [hp(flat("ear", [(s * 0.0080, 0.0050, 0.0120), (s * 0.0130, 0.0040, 0.0320), (s * 0.0200, 0.0040, 0.0400), (s * 0.0180, 0.0040, 0.0210), (s * 0.0140, 0.0040, 0.0120)], 0.0016, "roof_orange"))]
        head += [hp(o) for o in chain("tassel", [V((s * 0.0200, 0.0040, 0.0400)), V((s * 0.0240, 0.0050, 0.0300)), V((s * 0.0250, 0.0060, 0.0200))], [0.0020, 0.0016, 0.0004], "hair_coral", 4)]
        for (fx, fy) in ((0.0050, -0.0200), (0.0070, -0.0140)):
            head.append(hp(seg("fang", V((s * fx, fy, -0.0120)), V((s * fx, fy - 0.0010, -0.0280 if fy < -0.016 else -0.0210)), 0.0024, 0.0002, "bone", 5)))
    # the unicorn horn: 16 collars of gold and jade, twisting outward and forward
    base, tip = V((0, -0.0140, 0.0190)), V((0, -0.0580, 0.0780))
    n = 12
    for i in range(n):
        a = base + (tip - base) * (i / n)
        b = base + (tip - base) * ((i + 1) / n)
        r0, r1 = 0.0068 * (1 - i / n) + 0.0003, 0.0068 * (1 - (i + 1) / n) + 0.0003
        head.append(hp(seg("horn", a, b, r0, r1, "shell_gold" if i % 2 else "shell_jade", 8)))
        if i % 2 == 0:
            ang = i * 1.1
            head.append(hp(seg("ridge", a + V((math.cos(ang) * r0 * 0.9, 0, math.sin(ang) * r0 * 0.9)), a + V((math.cos(ang) * r0 * 1.7, -0.0020, math.sin(ang) * r0 * 1.7)), 0.0010, 0.0002, "fire_yellow", 4)))
    CH = 1.35
    scale_about(head, H, CH)
    groups.append(("head", head, tuple(H), ""))
    jaw = [place(bc.blob("jaw", 0.0085, (0, -0.0110, -0.0150), "shell_gold", 2, (0.75, 1.20, 0.40)), (PITCH + 22, 0, 0), tuple(H))]
    for s in (-1, 1):
        jaw.append(place(seg("fang", V((s * 0.0050, -0.0190, -0.0160)), V((s * 0.0050, -0.0200, -0.0020)), 0.0020, 0.0002, "bone", 5), (PITCH + 22, 0, 0), tuple(H)))
    scale_about(jaw, H, CH)
    groups.append(("jaw", jaw, tuple(H + V((0, 0.0040, -0.0100))), "head"))
    mane = []
    for k in range(9):  # rainbow ribbon mane streaming back over the wings
        a = (k - 4.0) * 0.0044
        p0 = H + V((a, 0.0100, 0.0100 - abs(k - 4.0) * 0.0014))
        mane += chain("mane", [p0, p0 + V((a * 1.6, 0.0200, 0.0040)), p0 + V((a * 2.4, 0.0360, -0.0040)), p0 + V((a * 3.0, 0.0500, -0.0150))], [0.0034, 0.0030, 0.0020, 0.0004], FEATHER[k % len(FEATHER)], 4)
    groups.append(("mane", mane, tuple(H + V((0, 0.0100, 0.0050))), ""))
    for s, nm in ((-1, "r"), (1, "l")):  # huge rainbow feather wings
        sh = V((s * 0.0180, 0.0000, 0.0720))
        arm = chain("wingarm", [sh, sh + V((s * 0.0260, 0.0100, 0.0220)), sh + V((s * 0.0580, 0.0200, 0.0340)), sh + V((s * 0.0860, 0.0300, 0.0280))], [0.0070, 0.0058, 0.0044, 0.0016], "shell_gold", 8)
        pw = V((0, 0, 1))
        for row, (n_f, L0, W0, z0) in enumerate(((8, 0.0700, 0.0150, 0.0), (6, 0.0500, 0.0140, 0.0060), (5, 0.0320, 0.0130, 0.0110))):
            for j in range(n_f):
                f = j / (n_f - 1)
                base_p = sh + V((s * (0.0120 + 0.0780 * f), 0.0100 + 0.0200 * f - row * 0.0010, 0.0300 * math.sin(f * PI) * 0.8 + 0.0100 - z0))
                ang = math.radians(-70 - 5 * row + 100 * f * 0.0 - 24 * (1 - f) * 0)
                d = V((s * math.sin(math.radians(30 + 40 * f)) * 0.55, 0.50 - 0.1 * f, -math.cos(math.radians(50 - 25 * f)))).normalized()
                pts3 = fan(tuple(base_p), tuple(d), L0 * (0.75 + 0.25 * math.sin(f * PI)), W0, "x", (1, 0, 0) if False else (s * 0.2, 0.0, 1.0))
                arm.append(flat("feather", pts3, 0.0008, FEATHER[(j + row * 2) % len(FEATHER)]))
        groups.append(("wing_" + nm, arm, tuple(sh), ""))
    tail = chain("tail", [V((0, 0.0700, 0.0380)), V((0, 0.0900, 0.0540)), V((0, 0.0960, 0.0800)), V((0, 0.0840, 0.1040)), V((0, 0.0620, 0.1100)), V((0, 0.0400, 0.1000)), V((0, 0.0340, 0.0820))],
                 [0.0100, 0.0088, 0.0074, 0.0062, 0.0050, 0.0040, 0.0030], "shell_jade", 8)
    tail += [bc.blob("sting", 0.0050, (0, 0.0330, 0.0790), "fire_red", 2), seg("stinger", V((0, 0.0330, 0.0790)), V((0, 0.0310, 0.0620)), 0.0040, 0.0002, "bone", 5)]
    for k in range(5):
        tail.append(seg("barb", V((0, 0.0960 - k * 0.0000, 0.0800)), V((0.0060 * (k - 2), 0.1000, 0.0900 + 0.0040 * k)), 0.0030, 0.0002, FEATHER[k], 4))
    groups.append(("tail", tail, (0, 0.0700, 0.0380), ""))
    obj = bc.assemble("ew_boss_dawn_chimera_v01", groups)
    crystal_anchors(obj, 0.0800, 0.1050)
    bc.anchor(obj, "eye_anchor", tuple(H + V((0, -0.0170, 0.0130))), "head", 0.005)
    bc.anchor(obj, "horn_anchor", (0, -0.0640, 0.2060), "head", 0.008)
    bc.anchor(obj, "sting_anchor", (0, 0.0310, 0.0620), "tail", 0.006)
    bc.anchor(obj, "summon_anchor", (0, -0.1100, 0.0150), "", 0.008)
    return obj


BOSSES = {"aurora_wyrm": aurora_wyrm, "moonmaw": moonmaw, "dawn_chimera": dawn_chimera}

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    key = argv[0] if argv else "aurora_wyrm"
    bc.clear_scene()
    obj = BOSSES[key]()
    mc.smooth(obj)
    print("TRIS", key, mc.tri_count(obj))
    bc.save_blend(obj, "boss_" + key)
