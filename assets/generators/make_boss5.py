"""The Warden, round 5: SCARY bosses (Durva 2026-11-02: "no, scarier: these are too cute, I don't like any of them. Giant mammoths, bears,
orcs, really scary creatures outputting flames: the player needs to be afraid").

Run one:  blender --factory-startup -b -P assets/generators/make_boss5.py -- <key> [p1|p2|p3]   (saves assets/blend/boss_<key>.blend)
  cinder_mammoth   a colossal charred war-mammoth: matted burnt fur, obsidian armour plates, cracked tusks in iron bands, a raised trunk that is a fire maw
  gravemaw_bear    a rearing, half-rotten monster bear: torn flesh, exposed ribs round a burning brand, an eye socket full of fire, huge claws and fangs
  furnace_orc      a hulking iron-and-scar orc: a furnace in his chest, spiked pauldrons, tusks, a notched cleaver, smoking exhaust pipes, a skull flail
Palette: soot, charred bone, rusted iron, blood and ember. NO pastels, flowers or rainbows. Fire is in cracks, mouths, furnaces (ember colours)
plus anchors for the real flame VFX (never glowing geometry). Three phases tagged ew_phase / ew_phase_until like round 4: P1 armoured, P2 armour
breaks and the burning inside shows, P3 full inferno. Budget 20000 (untested on a Quest). Built with boss_kit.py.
"""
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import boss_kit as bk  # noqa: E402
import make_boss3 as b3  # noqa: E402
import make_boss4 as b4  # noqa: E402

mc = bk.mc
bc, V, seg, chain, flat, place = bk.bc, bk.V, bk.seg, bk.chain, bk.flat, bk.place
PI = math.pi
stop, tag, shift, keep_phase = b4.stop, b4.tag, b4.shift, b4.keep_phase

FLAME = ["blood_red", "ember", "marigold_deep", "saffron", "ember", "crimson"]


def sample(c, r3, n, fn=None):
    out = []
    for k in range(n):
        zz = 0.98 - 1.96 * k / max(1, n - 1)
        ph = 2.399963 * k
        rr = math.sqrt(max(0.0, 1 - zz * zz))
        u = V((math.cos(ph) * rr, math.sin(ph) * rr, zz))
        if fn and not fn(u):
            continue
        pos = V(c) + V((u.x * r3[0], u.y * r3[1], u.z * r3[2]))
        nrm = V((u.x / r3[0], u.y / r3[1], u.z / r3[2])).normalized()
        out.append((pos, nrm, u))
    return out


def fur(c, r3, n, cols, L, w, bias=(0, 0, 0), fn=None, name="fur"):
    parts = []
    for k, (pos, nrm, u) in enumerate(sample(c, r3, n, fn)):
        d = (nrm + V(bias)).normalized()
        ln = L * (0.7 + 0.6 * ((k * 7) % 5) / 4.0)
        parts.append(seg(name, pos - nrm * 0.002, pos + d * ln, w, 0.0002, cols[k % len(cols)], 4))
    return parts


def claws(base, d, n, spread, L, w, col="bone_aged", side=None):
    base, d = V(base), V(d).normalized()
    ref = V((0, 0, 1)) if abs(d.z) < 0.9 else V((1, 0, 0))
    wv = d.cross(ref).normalized()
    out = []
    for k in range(n):
        off = (k - (n - 1) / 2.0) * spread
        p0 = base + wv * off
        mid = p0 + d * L * 0.55
        tip = p0 + d * L * 0.95 + V((0, 0, -L * 0.28))
        out += chain("claw", [p0, mid, tip], [w, w * 0.7, 0.0002], col, 5, joints=False)
    return out


def tusk(pts, r0, col="bone_warm", bands=(0.25, 0.55, 0.8), band_col="charcoal"):
    n = len(pts)
    rr = [r0 * (1 - 0.88 * (i / (n - 1))) for i in range(n)]
    objs = bk.skin("tusk", pts, rr, rr, lambda i, k: col if i % 3 else "bone_aged", sides=10, per=1, caps=(False, True))[0]
    for b in bands:
        i = min(n - 2, int(b * (n - 1)))
        t = (V(pts[i + 1]) - V(pts[i])).normalized()
        objs.append(seg("band", V(pts[i]) - t * 0.0018, V(pts[i]) + t * 0.0018, rr[i] * 1.28, rr[i] * 1.28, band_col, 10))
    return objs


def ember_cracks(c, r3, n, seed=0, col=("ember", "marigold_deep", "blood_red"), w=0.0013, fn=None, L=0.010):
    """Zig-zag magma cracks on an ellipsoid surface."""
    out = []
    for k, (pos, nrm, u) in enumerate(sample(c, r3, n, fn)):
        t = nrm.cross(V((0, 0, 1)))
        if t.length < 0.1:
            t = V((1, 0, 0))
        t.normalize()
        b = nrm.cross(t)
        p = pos
        for j in range(3):
            q = p + (t * (0.5 + 0.5 * math.sin(k * 3.1 + j)) + b * (0.9 * math.cos(k * 1.7 + j * 2.0))) * L * 0.5 + nrm * 0.0004
            out.append(seg("crack", p + nrm * 0.0006, q + nrm * 0.0006, w, w * 0.7, col[(k + j) % len(col)], 4))
            p = q
    return out


def maw(centre, d, R, teeth, col_in="ember", tooth_col="bone_warm", ring_col="charcoal"):
    """A flared fire-maw: a ring, an ember throat and fangs pointing inward, built around centre looking along d."""
    centre, d = V(centre), V(d).normalized()
    ref = V((0, 0, 1)) if abs(d.z) < 0.9 else V((1, 0, 0))
    u = d.cross(ref).normalized()
    v = d.cross(u).normalized()
    out = [seg("throat", centre - d * R * 0.9, centre + d * R * 0.1, R * 0.62, R * 0.95, col_in, 12), seg("lip", centre, centre + d * R * 0.35, R * 1.05, R * 1.25, ring_col, 12)]
    for k in range(teeth):
        a = 2 * PI * k / teeth
        p = centre + d * R * 0.30 + (u * math.cos(a) + v * math.sin(a)) * R * 1.0
        out.append(seg("fang", p, p + d * R * 0.55 - (u * math.cos(a) + v * math.sin(a)) * R * 0.45, R * 0.20, 0.0002, tooth_col, 5))
    return out


def banner(base, h, w, col, tilt=0.0):
    b = V(base)
    pts = [tuple(b), tuple(b + V((w * 0.55, 0, 0.0))), tuple(b + V((w, 0.0, -h * 0.35))), tuple(b + V((w * 0.7, 0.0, -h * 0.7))), tuple(b + V((w * 0.3, 0.0, -h * 0.55))), tuple(b + V((w * 0.15, 0.0, -h)))]
    return flat("banner", pts, 0.0010, col)


# ============================================================================= 1. CINDER MAMMOTH
def cinder_mammoth():
    groups = []
    root = [bc.blob("barrel", 0.041, (0, 0.012, 0.092), "charcoal", 3, (1.0, 1.60, 0.92)), bc.blob("hump", 0.031, (0, -0.034, 0.124), "obsidian", 3, (1.0, 0.95, 1.0)),
            bc.blob("rump", 0.034, (0, 0.058, 0.090), "charcoal", 3, (0.95, 1.0, 0.95)), bc.blob("belly", 0.034, (0, 0.012, 0.062), "obsidian", 2, (1.0, 1.9, 0.6))]
    for (lx, ly) in ((-0.029, -0.040), (0.029, -0.040), (-0.029, 0.058), (0.029, 0.058)):  # four pillar legs
        pts = [V((lx, ly, 0.092)), V((lx * 1.12, ly, 0.052)), V((lx * 1.14, ly - 0.002, 0.012))]
        root += bk.skin("leg", pts, [0.0200, 0.0175, 0.0210], [0.0200, 0.0175, 0.0210], lambda i, n: "charcoal" if i < 2 else "obsidian", sides=12, per=1, caps=(False, True))[0]
        root.append(bc.blob("foot", 0.0165, (lx * 1.14, ly - 0.004, 0.0090), "obsidian", 2, (1.0, 1.2, 0.5)))
        root += fur((lx * 1.13, ly, 0.052), (0.024, 0.024, 0.036), 34, ["charcoal", "obsidian", "ash_grey", "bone_shadow"], 0.014, 0.0040, (0, 0.1, -0.5), lambda u: u.z < 0.7)
        for t in (-1, 0, 1):
            root.append(seg("nail", V((lx * 1.14 + t * 0.0062, ly - 0.016, 0.0060)), V((lx * 1.14 + t * 0.0070, ly - 0.0225, 0.0030)), 0.0030, 0.0004, "bone_shadow", 5))
    # hanging matted fur skirt
    for k in range(120):
        side = -1 if k % 2 else 1
        y = -0.060 + 0.128 * ((k // 2) / 59.0)
        top = V((side * (0.038 - 0.006 * abs(y) / 0.07), y, 0.072 + 0.006 * math.sin(k)))
        root.append(seg("strand", top, top + V((side * 0.0060, 0.002 * math.sin(k * 2.0), -0.034 - 0.008 * ((k * 3) % 4))), 0.0046, 0.0002, stop(["charcoal", "obsidian", "ash_grey", "bone_shadow"], ((k * 5) % 4) / 4), 4))
    root += fur((0, 0.012, 0.092), (0.041, 0.066, 0.038), 250, ["charcoal", "obsidian", "ash_grey", "charcoal", "bone_shadow", "ember"], 0.018, 0.0044, (0, 0.5, 0.7), lambda u: u.z > -0.15)
    root += fur((0, -0.034, 0.124), (0.031, 0.029, 0.031), 80, ["obsidian", "charcoal", "ash_grey"], 0.020, 0.0046, (0, -0.2, 0.9), lambda u: u.z > 0.0)
    # chains and manacles on the front legs
    for s in (-1, 1):
        root += b3.me.ring3d((s * 0.033, -0.042, 0.030), 0.0200, 0.0030, 12, "bronze", "xy")
        root += chain("chain", [V((s * 0.053, -0.042, 0.030)), V((s * 0.062, -0.050, 0.016)), V((s * 0.068, -0.058, 0.0030))], [0.0020] * 3, "gold_dark", 5, joints=False)
    root.append(seg("tailbone", V((0, 0.090, 0.090)), V((0, 0.090, 0.0)), 0.0001, 0.0001, "charcoal", 3))
    groups.append(("", root, (0, 0, 0), ""))
    # head: massive skull, brow, small deep-set burning eyes
    HP = V((0, -0.074, 0.118))
    head = [bc.blob("skull", 0.028, tuple(HP), "charcoal", 3, (0.95, 1.05, 1.05)), bc.blob("dome", 0.023, tuple(HP + V((0, 0.006, 0.020))), "obsidian", 3, (1.0, 1.0, 1.0)),
            bc.blob("cheek_l", 0.014, tuple(HP + V((-0.016, -0.014, -0.010))), "ash_grey", 2, (0.9, 1.0, 1.0)), bc.blob("cheek_r", 0.014, tuple(HP + V((0.016, -0.014, -0.010))), "ash_grey", 2, (0.9, 1.0, 1.0))]
    for s in (-1, 1):
        head += [bc.blob("brow", 0.012, tuple(HP + V((s * 0.0120, -0.0210, 0.0090))), "obsidian", 2, (1.4, 0.8, 0.6)), bc.blob("socket", 0.0066, tuple(HP + V((s * 0.0125, -0.0230, 0.0020))), "obsidian", 2, (1.0, 0.6, 1.0)),
                 bc.blob("eye", 0.0040, tuple(HP + V((s * 0.0125, -0.0262, 0.0020))), "ember", 1, (1.0, 0.5, 1.0)), bc.blob("eyecore", 0.0020, tuple(HP + V((s * 0.0125, -0.0282, 0.0020))), "saffron", 1, (1.0, 0.5, 1.0))]
        head.append(flat("ear", [(s * 0.0260, -0.0020, 0.1180), (s * 0.0480, 0.0000, 0.1380), (s * 0.0580, 0.0040, 0.1250), (s * 0.0540, 0.0060, 0.1050), (s * 0.0340, 0.0040, 0.1040)], 0.0020, "obsidian"))
        head.append(flat("ear_in", [(s * 0.0290, -0.0030, 0.1170), (s * 0.0450, -0.0010, 0.1300), (s * 0.0520, 0.0020, 0.1220), (s * 0.0480, 0.0030, 0.1090)], 0.0012, "blood_red"))
        head += claws(HP + V((s * 0.0150, -0.0200, 0.0160)), V((s * 0.4, -0.2, 0.9)), 3, 0.0040, 0.0130, 0.0040, "bone_shadow")  # horn-like brow spikes
    head += fur(tuple(HP + V((0, 0.004, 0.008))), (0.029, 0.029, 0.029), 70, ["charcoal", "obsidian", "ash_grey", "ember"], 0.014, 0.0040, (0, 0.2, 0.5), lambda u: u.z > 0.1 or u.y > 0.2)
    # armour plates riveted onto the head and shoulders (phase 1; they break in phase 2)
    plates = []
    for (c, r_, sq) in (((0, -0.092, 0.128), 0.0120, (1.4, 0.5, 0.8)), ((-0.030, -0.040, 0.138), 0.0170, (1.0, 1.3, 0.35)), ((0.030, -0.040, 0.138), 0.0170, (1.0, 1.3, 0.35)),
                        ((0, -0.034, 0.150), 0.0150, (1.2, 1.0, 0.35)), ((-0.040, 0.010, 0.120), 0.0180, (0.4, 1.4, 1.0)), ((0.040, 0.010, 0.120), 0.0180, (0.4, 1.4, 1.0))):
        plates.append(bc.blob("plate", r_, c, "obsidian", 2, sq))
        for k in range(5):
            a = 2 * PI * k / 5
            plates.append(seg("rivet", V(c) + V((math.cos(a) * r_ * 0.7 * sq[0], math.sin(a) * r_ * 0.7 * sq[1], r_ * sq[2] * 0.7)), V(c) + V((math.cos(a) * r_ * 0.7 * sq[0], math.sin(a) * r_ * 0.7 * sq[1], r_ * sq[2] * 1.5)), 0.0030, 0.0002, "bronze", 4))
    for s in (-1, 1):  # long shoulder spikes
        plates += chain("spike", [V((s * 0.044, -0.040, 0.138)), V((s * 0.058, -0.044, 0.158)), V((s * 0.062, -0.048, 0.182))], [0.0070, 0.0050, 0.0002], "obsidian", 6, joints=False)
    groups.append(("plates", plates, (0, 0, 0.12), ""))
    HS = 1.28
    b3.scale_about(head, HP, HS)
    groups.append(("head", head, tuple(HP), ""))
    # trunk: a raised, flared fire maw
    tp = [V(p) for p in ((0, -0.098, 0.104), (0, -0.110, 0.116), (0, -0.118, 0.136), (0, -0.114, 0.158), (0, -0.102, 0.176))]
    tr = [0.0150, 0.0135, 0.0120, 0.0105, 0.0100]
    trunk, _ = bk.skin("trunk", tp, tr, tr, lambda i, n: "obsidian" if i % 2 else "charcoal", sides=12, per=1, caps=(False, False))
    for i in range(4):  # trunk wrinkles
        trunk.append(seg("wrinkle", tp[i + 1] - V((0, 0, 0.0010)), tp[i + 1] + V((0, 0, 0.0010)), tr[i + 1] * 1.12, tr[i + 1] * 1.12, "obsidian", 12))
    trunk += maw(tp[-1] + V((0, -0.002, 0.004)), V((0, -0.35, 0.94)), 0.0135, 12)
    b3.scale_about(trunk, HP, HS)
    groups.append(("trunk", trunk, tuple(V(tp[0]) + (V(tp[0]) - HP) * (HS - 1)), "head"))
    # tusks: giant, cracked, iron-banded
    for s in (-1, 1):
        tp2 = [V((s * 0.020, -0.092, 0.104)), V((s * 0.046, -0.102, 0.088)), V((s * 0.062, -0.116, 0.080)), V((s * 0.066, -0.132, 0.092)), V((s * 0.058, -0.144, 0.112)), V((s * 0.044, -0.148, 0.132))]
        tk = tusk(tp2, 0.0090)
        b3.scale_about(tk, HP, HS)
        groups.append(("tusk_" + ("r" if s < 0 else "l"), tk, tuple(V(tp2[0]) + (V(tp2[0]) - HP) * (HS - 1)), "head"))
    # ruined howdah on the back
    how = [bc.box("deck", (0.056, 0.046, 0.004), (0, 0.018, 0.152), "wood_dark"), bc.box("rail", (0.056, 0.003, 0.012), (0, -0.005, 0.158), "wood_mid"), bc.box("rail", (0.056, 0.003, 0.012), (0, 0.041, 0.158), "wood_mid")]
    for (px, py) in ((-0.026, -0.004), (0.026, -0.004), (-0.026, 0.040), (0.026, 0.040)):
        how.append(seg("post", V((px, py, 0.152)), V((px, py, 0.178)), 0.0030, 0.0002, "bone_shadow", 5))
    how += b4.mini_skull(V((0, 0.018, 0.168)), 0.0085, "bone_shadow", 0)
    for (px, h_, c_) in ((-0.026, 0.034, "blood_red"), (0.026, 0.028, "crimson")):
        how.append(seg("pole", V((px, 0.018, 0.152)), V((px, 0.018, 0.152 + h_ + 0.012)), 0.0014, 0.0014, "gold_dark", 5))
        how.append(banner((px, 0.018, 0.152 + h_ + 0.012), 0.030, 0.026 * (1 if px > 0 else -1), c_))
    groups.append(("howdah", how, (0, 0.018, 0.152), ""))
    # P2: magma cracks split through the hide.  P3: a mane of flames.
    cr = ember_cracks((0, 0.012, 0.092), (0.0415, 0.0665, 0.0385), 46, col=("ember", "marigold_deep", "blood_red"), w=0.0016, L=0.014, fn=lambda u: abs(u.x) > 0.25 or u.z > 0.3)
    cr += ember_cracks((0, 0.058, 0.090), (0.0345, 0.0345, 0.0345), 12, col=("ember", "blood_red"), w=0.0015, L=0.012)
    groups.append(("cracks", cr, (0, 0.012, 0.092), ""))
    fl = []
    for k, (pos, nrm, u) in enumerate(sample((0, 0.012, 0.092), (0.042, 0.067, 0.039), 70, lambda u: u.z > 0.25)):
        fl += chain("flame", [pos, pos + V((0.003 * math.sin(k), 0.006, 0.020)), pos + V((0.006 * math.cos(k), 0.013, 0.040)), pos + V((0.003 * math.sin(k * 2), 0.020, 0.062))], [0.0060, 0.0048, 0.0030, 0.0002], stop(FLAME, (k % 6) / 6), 4, joints=False)
    groups.append(("flames", fl, (0, 0.012, 0.130), ""))
    tail = chain("tail", [V((0, 0.090, 0.098)), V((0, 0.100, 0.082)), V((0, 0.104, 0.058)), V((0, 0.100, 0.034))], [0.0070, 0.0058, 0.0044, 0.0030], "charcoal", 7, joints=False)
    tail += fur((0, 0.100, 0.030), (0.010, 0.010, 0.016), 22, ["charcoal", "ember", "obsidian"], 0.014, 0.0040, (0, 0.2, -0.4))
    groups.append(("tail", tail, (0, 0.090, 0.098), ""))
    obj = bc.assemble("ew_boss_cinder_mammoth_v01", groups)
    for suffix, ph, until in (("plates", 1, 1), ("cracks", 2, None), ("flames", 3, None)):
        tag(obj, suffix, ph, until)
    b3.crystal_anchors(obj, 0.0900, 0.1050)
    bc.anchor(obj, "flame_anchor", tuple(HP + (V((0, -0.1130, 0.1880)) - HP) * HS), "trunk", 0.010)
    bc.anchor(obj, "eye_anchor", tuple(HP + V((0.0125, -0.0290, 0.0020))), "head", 0.005)
    bc.anchor(obj, "summon_anchor", (0, -0.1300, 0.0200), "", 0.008)
    bc.anchor(obj, "stomp_anchor", (0, -0.0420, 0.0020), "", 0.012)
    return obj



# ============================================================================= 2. GRAVEMAW BEAR
def gravemaw_bear():
    groups = []
    root = [bc.blob("chest", 0.040, (0, -0.006, 0.128), "charcoal", 3, (1.05, 0.88, 1.15)), bc.blob("belly", 0.032, (0, 0.012, 0.092), "obsidian", 3, (1.0, 0.9, 1.1)),
            bc.blob("hips", 0.034, (0, 0.022, 0.066), "charcoal", 3, (1.15, 0.95, 0.95)), bc.blob("hump", 0.030, (0, 0.004, 0.152), "obsidian", 3, (1.3, 0.9, 0.7))]
    for s in (-1, 1):  # hind legs, feet and claws
        pts = [V((s * 0.026, 0.022, 0.072)), V((s * 0.040, 0.006, 0.040)), V((s * 0.036, -0.014, 0.012))]
        root += bk.skin("hindleg", pts, [0.019, 0.015, 0.013], [0.019, 0.015, 0.013], lambda i, n: "charcoal", sides=12, per=1, caps=(False, True))[0]
        root.append(bc.blob("foot", 0.0140, (s * 0.036, -0.022, 0.0075), "obsidian", 2, (1.0, 1.5, 0.5)))
        root += claws((s * 0.036, -0.036, 0.0070), V((0, -1, -0.1)), 4, 0.0050, 0.016, 0.0034, "bone_aged")
        root += fur((s * 0.038, 0.010, 0.046), (0.020, 0.020, 0.030), 36, ["charcoal", "obsidian", "ash_grey", "blood_red"], 0.014, 0.0040, (0, 0.2, -0.3))
    # the burning brand in the chest, torn flesh around it, and the exposed ribs over it
    root += [bc.blob("brand", 0.0200, (0, -0.0400, 0.1280), "ember", 2, (0.85, 0.35, 1.15)), bc.blob("brand_core", 0.0110, (0, -0.0430, 0.1280), "saffron", 2, (0.8, 0.3, 1.1))]
    for k in range(8):
        a = 2 * PI * k / 8
        root.append(bc.blob("flesh", 0.0085, (math.cos(a) * 0.0250, -0.0390, 0.1280 + math.sin(a) * 0.0300), "blood_red" if k % 2 else "vein_pink", 1, (1.2, 0.5, 1.0)))
    for kk in range(6):
        z = 0.1060 + 0.0085 * kk
        pts = [V((t * 0.0300, -0.0495 + 0.0120 * t * t, z - 0.0030 * abs(t))) for t in (-1.0, -0.5, 0.0, 0.5, 1.0)]
        root += chain("rib", pts, [0.0019, 0.0020, 0.0021, 0.0020, 0.0019], "bone_aged", 5, joints=False)
    root += fur((0, -0.006, 0.128), (0.041, 0.035, 0.046), 150, ["charcoal", "obsidian", "ash_grey", "charcoal", "bone_shadow", "blood_red"], 0.018, 0.0046, (0, 0.2, 0.5), lambda u: not (u.y < -0.3 and abs(u.x) < 0.6 and abs(u.z) < 0.7))
    root += fur((0, 0.012, 0.092), (0.033, 0.029, 0.036), 60, ["charcoal", "obsidian", "ash_grey"], 0.016, 0.0044, (0, 0.2, 0.2))
    root += fur((0, 0.022, 0.066), (0.039, 0.032, 0.032), 60, ["charcoal", "obsidian", "ash_grey"], 0.016, 0.0044, (0, 0.4, 0.1))
    root += fur((0, 0.004, 0.152), (0.039, 0.027, 0.021), 60, ["obsidian", "charcoal", "bone_shadow"], 0.020, 0.0050, (0, 0.5, 0.8), lambda u: u.z > 0)
    for k in range(10):  # a ridge of bone spikes along the back
        y = 0.000 + k * 0.0060
        root.append(seg("spine", V((0, 0.014 + y * 0.9, 0.172 - k * 0.0075)), V((0, 0.022 + y, 0.196 - k * 0.0072)), 0.0046, 0.0002, "bone_shadow", 5))
    root += b3.me.ring3d((0, -0.024, 0.172), 0.0250, 0.0030, 12, "bronze", "xy")  # spiked iron collar
    for k in range(8):
        a = 2 * PI * k / 8
        root.append(seg("collarspike", V((math.cos(a) * 0.0250, -0.024 + math.sin(a) * 0.0250, 0.172)), V((math.cos(a) * 0.0330, -0.024 + math.sin(a) * 0.0330, 0.178)), 0.0034, 0.0002, "gold_dark", 4))
    root += chain("chain", [V((0.012, -0.046, 0.164)), V((0.016, -0.054, 0.150)), V((0.012, -0.058, 0.136))], [0.0016] * 3, "gold_dark", 4, joints=False)
    groups.append(("", root, (0, 0, 0), ""))
    # raised arms with huge paws and claws
    for s, nm in ((-1, "r"), (1, "l")):
        pts = [V((s * 0.040, -0.004, 0.150)), V((s * 0.070, -0.026, 0.160)), V((s * 0.066, -0.066, 0.178))]
        arm = bk.skin("arm", pts, [0.0185, 0.0150, 0.0165], [0.0185, 0.0150, 0.0165], lambda i, n: "charcoal", sides=12, per=1, caps=(False, False))[0]
        arm.append(bc.blob("paw", 0.0155, tuple(pts[-1] + V((0, -0.008, -0.002))), "obsidian", 3, (1.0, 1.1, 0.85)))
        arm += claws(tuple(pts[-1] + V((0, -0.016, -0.004))), V((s * 0.1, -0.65, -0.75)), 5, 0.0048, 0.022, 0.0040, "bone_aged")
        arm += fur(tuple(pts[1]), (0.020, 0.020, 0.020), 36, ["charcoal", "obsidian", "ash_grey", "blood_red"], 0.014, 0.0042, (0, 0.2, 0.3))
        arm.append(bc.blob("bonepatch", 0.0070, tuple(pts[1] + V((s * 0.006, -0.010, 0.010))), "bone_warm", 2, (1.0, 0.6, 1.2)))
        groups.append(("arm_" + nm, arm, tuple(pts[0]), ""))
    # head: skull, ember eye, an eye socket full of fire, fangs, ragged ears
    HC = V((0, -0.030, 0.190))
    head = [bc.blob("skull", 0.0225, tuple(HC), "charcoal", 3, (1.05, 1.0, 0.95)), bc.blob("muzzle", 0.0150, tuple(HC + V((0, -0.026, -0.004))), "obsidian", 3, (0.8, 1.5, 0.75)),
            bc.blob("nose", 0.0050, tuple(HC + V((0, -0.0510, 0.0010))), "ink", 1, (1.3, 0.8, 0.8)), bc.blob("brow_r", 0.0110, tuple(HC + V((-0.0100, -0.0180, 0.0110))), "obsidian", 2, (1.4, 0.8, 0.6)),
            bc.blob("brow_l", 0.0110, tuple(HC + V((0.0100, -0.0180, 0.0110))), "obsidian", 2, (1.4, 0.8, 0.6))]
    for s in (-1, 1):
        head.append(bc.blob("ear", 0.0085, tuple(HC + V((s * 0.0170, 0.0070, 0.0190))), "charcoal", 2, (1.0, 0.5, 1.0)))
        head.append(bc.blob("ear_in", 0.0050, tuple(HC + V((s * 0.0170, 0.0030, 0.0190))), "blood_red", 1, (1.0, 0.4, 1.0)))
    head += [bc.blob("eye", 0.0050, tuple(HC + V((-0.0110, -0.0230, 0.0050))), "ember", 2, (1.0, 0.5, 1.0)), bc.blob("eyecore", 0.0024, tuple(HC + V((-0.0110, -0.0270, 0.0050))), "saffron", 1, (1.0, 0.5, 1.0)),
             bc.blob("socket", 0.0090, tuple(HC + V((0.0110, -0.0200, 0.0050))), "obsidian", 2, (1.0, 0.7, 1.1)), bc.blob("socketfire", 0.0075, tuple(HC + V((0.0110, -0.0250, 0.0050))), "ember", 2, (1.0, 0.5, 1.1)),
             bc.blob("socketfire2", 0.0045, tuple(HC + V((0.0110, -0.0290, 0.0060))), "marigold_deep", 1, (1.0, 0.5, 1.2))]
    head += chain("scar", [HC + V((0.0200, -0.0100, 0.0160)), HC + V((0.0140, -0.0230, 0.0040)), HC + V((0.0090, -0.0380, -0.0100))], [0.0012] * 3, "blood_red", 4, joints=False)
    for s in (-1, 1):
        head.append(seg("canine", HC + V((s * 0.0070, -0.0450, -0.0070)), HC + V((s * 0.0075, -0.0480, -0.0290)), 0.0046, 0.0002, "bone_warm", 6))
        for k in range(3):
            head.append(seg("tooth", HC + V((s * (0.0100 + 0.0012 * k), -0.0300 + k * 0.0040, -0.0090)), HC + V((s * (0.0100 + 0.0012 * k), -0.0300 + k * 0.0040, -0.0190)), 0.0024, 0.0002, "bone_warm", 4))
    groups.append(("head", head, tuple(HC), ""))
    hinge = V((0, 0.004, -0.010))
    jaw = [bc.blob("jaw", 0.0135, (0, -0.0300, -0.0160), "obsidian", 3, (0.8, 1.5, 0.45)), bc.blob("tongue", 0.0080, (0, -0.0240, -0.0090), "marigold_deep", 1, (0.9, 1.8, 0.4)),
           bc.blob("throat", 0.0090, (0, -0.0110, -0.0060), "ember", 2, (1.0, 1.0, 0.7))]
    for s in (-1, 1):
        jaw.append(seg("canine", V((s * 0.0070, -0.0450, -0.0200)), V((s * 0.0075, -0.0470, 0.0020)), 0.0040, 0.0002, "bone_warm", 6))
        for k in range(3):
            jaw.append(seg("tooth", V((s * 0.0100, -0.0290 + k * 0.0040, -0.0190)), V((s * 0.0100, -0.0290 + k * 0.0040, -0.0100)), 0.0022, 0.0002, "bone_warm", 4))
    jaw = shift(jaw, -hinge)
    jaw = [place(o, (38, 0, 0), tuple(HC + hinge)) for o in jaw]
    groups.append(("jaw", jaw, tuple(HC + hinge), "head"))
    # P2: bone plates burst through the hide.  P3: fire pours off the shoulders and back.
    bp = []
    for k in range(7):
        bp += chain("riblet", [V((0.0200 + k * 0.0040, 0.020, 0.178 - k * 0.0120)), V((0.0420 + k * 0.0040, 0.012, 0.172 - k * 0.0120)), V((0.0500 + k * 0.0040, -0.004, 0.158 - k * 0.0130))], [0.0030, 0.0026, 0.0003], "bone_warm", 5, joints=False)
        bp += chain("riblet", [V((-0.0200 - k * 0.0040, 0.020, 0.178 - k * 0.0120)), V((-0.0420 - k * 0.0040, 0.012, 0.172 - k * 0.0120)), V((-0.0500 - k * 0.0040, -0.004, 0.158 - k * 0.0130))], [0.0030, 0.0026, 0.0003], "bone_warm", 5, joints=False)
    groups.append(("bone_burst", bp, (0, 0.010, 0.150), ""))
    fl = []
    for k, (pos, nrm, u) in enumerate(sample((0, 0.004, 0.130), (0.043, 0.040, 0.050), 90, lambda u: u.z > 0.15 and u.y > -0.3)):
        fl += chain("flame", [pos, pos + V((0.003 * math.sin(k), 0.006, 0.022)), pos + V((0.006 * math.cos(k), 0.012, 0.044)), pos + V((0.003 * math.sin(k * 2), 0.018, 0.066))], [0.0060, 0.0048, 0.0030, 0.0002], stop(FLAME, (k % 6) / 6), 4, joints=False)
    groups.append(("flames", fl, (0, 0.004, 0.150), ""))
    obj = bc.assemble("ew_boss_gravemaw_bear_v01", groups)
    for suffix, ph, until in (("bone_burst", 2, None), ("flames", 3, None)):
        tag(obj, suffix, ph, until)
    b3.crystal_anchors(obj, 0.0900, 0.1050)
    bc.anchor(obj, "flame_anchor", tuple(HC + V((0, -0.0420, -0.0100))), "jaw", 0.010)
    bc.anchor(obj, "eye_anchor", tuple(HC + V((-0.0110, -0.0290, 0.0050))), "head", 0.005)
    bc.anchor(obj, "brand_anchor", (0, -0.0480, 0.1280), "", 0.008)
    bc.anchor(obj, "summon_anchor", (0, -0.1000, 0.0200), "", 0.008)
    return obj


# ============================================================================= 3. FURNACE ORC
def furnace_orc():
    groups = []
    SK, SK2 = "swamp_green", "moss_dark"
    root = [bc.blob("torso", 0.042, (0, 0, 0.120), SK, 3, (1.0, 0.85, 1.1)), bc.blob("belly", 0.034, (0, -0.010, 0.094), SK, 3, (1.1, 0.9, 0.9)), bc.blob("hunch", 0.034, (0, 0.022, 0.146), SK2, 3, (1.2, 0.9, 0.9)),
            bc.blob("hips", 0.030, (0, 0.004, 0.078), SK2, 3, (1.2, 0.9, 0.8))]
    for s in (-1, 1):  # legs with riveted greaves and clawed feet
        pts = [V((s * 0.020, 0.002, 0.082)), V((s * 0.030, -0.008, 0.046)), V((s * 0.028, -0.004, 0.012))]
        root += bk.skin("leg", pts, [0.018, 0.015, 0.012], [0.018, 0.015, 0.012], lambda i, n: SK2, sides=12, per=1, caps=(False, True))[0]
        root.append(bc.blob("greave", 0.0135, (s * 0.030, -0.010, 0.030), "bronze", 2, (1.0, 1.1, 1.7)))
        root.append(bc.blob("knee", 0.0120, (s * 0.030, -0.014, 0.050), "gold_dark", 2, (1.0, 0.8, 0.8)))
        root.append(seg("kneespike", V((s * 0.030, -0.020, 0.052)), V((s * 0.032, -0.036, 0.058)), 0.0050, 0.0002, "bone_shadow", 5))
        root.append(bc.blob("foot", 0.0125, (s * 0.028, -0.014, 0.0070), "charcoal", 2, (1.0, 1.6, 0.5)))
        root += claws((s * 0.028, -0.030, 0.0060), V((0, -1, -0.1)), 3, 0.0060, 0.014, 0.0036, "bone_aged")
    # the furnace in his chest
    root += [bc.box("frame", (0.032, 0.006, 0.040), (0, -0.0360, 0.1220), "charcoal"), bc.box("fire", (0.026, 0.004, 0.034), (0, -0.0385, 0.1220), "ember"), bc.box("fire_core", (0.016, 0.004, 0.022), (0, -0.0392, 0.1220), "saffron")]
    for k in range(5):
        root.append(bc.box("bar", (0.0016, 0.0060, 0.0400), (-0.0100 + k * 0.0050, -0.0400, 0.1220), "charcoal"))
    root.append(bc.box("hood", (0.034, 0.008, 0.005), (0, -0.0370, 0.1450), "charcoal"))
    root += chain("strap", [V((-0.034, -0.024, 0.152)), V((0.0, -0.040, 0.104)), V((0.034, -0.024, 0.086))], [0.0030] * 3, "gold_dark", 5, joints=False)
    root += chain("strap", [V((0.034, -0.024, 0.152)), V((0.0, -0.040, 0.104)), V((-0.034, -0.024, 0.086))], [0.0030] * 3, "bronze", 5, joints=False)
    root += b4.mini_skull(V((0, -0.0440, 0.1040)), 0.0070, "bone_aged", 0)
    root += b3.me.ring3d((0, -0.004, 0.084), 0.0340, 0.0034, 14, "bronze", "xy")
    root += b4.mini_skull(V((0, -0.0400, 0.0840)), 0.0080, "bone_aged", 0)
    for k in range(60):  # scars and bristle
        pass
    root += fur((0, 0.022, 0.146), (0.040, 0.031, 0.031), 70, ["moss_dark", "charcoal", "swamp_green"], 0.012, 0.0040, (0, 0.5, 0.6), lambda u: u.z > 0.1)
    for k, (pos, nrm, u) in enumerate(sample((0, 0, 0.120), (0.042, 0.036, 0.046), 22, lambda u: u.y < 0.2)):
        root += chain("scar", [pos, pos + V((0.008, 0, -0.006)), pos + V((0.014, 0, -0.014))], [0.0011] * 3, "blood_red", 4, joints=False)
    # smoking exhaust pipes on the back
    for s in (-1, 1):
        root += [seg("pipe", V((s * 0.016, 0.040, 0.138)), V((s * 0.020, 0.052, 0.206)), 0.0070, 0.0066, "charcoal", 8), seg("pipe_rim", V((s * 0.020, 0.052, 0.206)), V((s * 0.0205, 0.0525, 0.2085)), 0.0095, 0.0095, "bronze", 8),
                 seg("pipe_mouth", V((s * 0.020, 0.052, 0.2085)), V((s * 0.0205, 0.0525, 0.2095)), 0.0058, 0.0058, "ember", 8)]
        for z in (0.158, 0.178, 0.196):
            root.append(seg("pipe_band", V((s * (0.016 + (z - 0.138) * 0.059), 0.040 + (z - 0.138) * 0.176, z)) , V((s * (0.016 + (z - 0.138) * 0.059), 0.040 + (z - 0.138) * 0.176, z + 0.0020)), 0.0092, 0.0092, "gold_dark", 8))
    groups.append(("", root, (0, 0, 0), ""))
    # pauldrons, arms, cleaver and skull flail
    for s, nm in ((-1, "r"), (1, "l")):
        sh = V((s * 0.052, 0, 0.150))
        arm = [bc.blob("pauldron", 0.0230, tuple(sh + V((s * 0.004, 0, 0.004))), "bronze", 3, (1.0, 1.0, 0.6))]
        for k in range(6):
            a = 2 * PI * k / 6
            arm.append(seg("pspike", sh + V((s * 0.004 + math.cos(a) * 0.0150, math.sin(a) * 0.0150, 0.0100)), sh + V((s * 0.004 + math.cos(a) * 0.0250, math.sin(a) * 0.0250, 0.0230)), 0.0050, 0.0002, "gold_dark", 5))
        pts = [sh + V((0, 0, -0.004)), V((s * 0.072, -0.018, 0.122)), V((s * 0.074, -0.040, 0.102))]
        arm += bk.skin("arm", pts, [0.0165, 0.0135, 0.0130], [0.0165, 0.0135, 0.0130], lambda i, n: SK, sides=12, per=1, caps=(False, False))[0]
        arm.append(bc.blob("fist", 0.0130, tuple(pts[-1] + V((0, -0.004, -0.004))), SK2, 2, (1.0, 1.0, 1.0)))
        for k in range(4):
            arm.append(seg("knuckle", pts[-1] + V(((k - 1.5) * 0.0044, -0.014, -0.002)), pts[-1] + V(((k - 1.5) * 0.0044, -0.022, 0.004)), 0.0030, 0.0002, "gold_dark", 4))
        arm.append(bc.cone("gauntlet", 0.0140, 0.0130, 0.0100, tuple(pts[-1] + V((0, 0.006, 0.014))), "bronze", 8))
        if s == -1:  # the notched cleaver with ember runes
            F = pts[-1] + V((0, -0.004, 0))
            arm.append(seg("haft", F + V((0, 0, -0.026)), F + V((0.004, -0.004, 0.070)), 0.0034, 0.0036, "wood_dark", 7))
            arm.append(seg("pommel", F + V((0, 0, -0.026)), F + V((0, 0, -0.030)), 0.0058, 0.0058, "gold_dark", 8))
            bx, by = F.x, F.y - 0.004
            blade = [(bx - 0.016, by, F.z + 0.036), (bx - 0.020, by, F.z + 0.070), (bx - 0.014, by, F.z + 0.118), (bx + 0.020, by, F.z + 0.124), (bx + 0.028, by, F.z + 0.086), (bx + 0.014, by, F.z + 0.040)]
            arm.append(flat("blade", blade, 0.0050, "silver"))
            arm.append(flat("edge", [(bx + 0.020, by - 0.0006, F.z + 0.124), (bx + 0.028, by - 0.0006, F.z + 0.086), (bx + 0.022, by - 0.0006, F.z + 0.086), (bx + 0.016, by - 0.0006, F.z + 0.120)], 0.0020, "ash_grey"))
            for k in range(4):  # chips and ember runes
                arm.append(bc.box("notch", (0.0060, 0.0070, 0.0050), (bx + 0.026 - 0.002 * k, by, F.z + 0.100 - 0.016 * k), "charcoal"))
                arm.append(bc.box("rune", (0.0050, 0.0010, 0.0100), (bx - 0.003, by - 0.0030, F.z + 0.056 + 0.016 * k), "ember"))
            arm.append(bc.box("crossguard", (0.0300, 0.0070, 0.0050), (bx + 0.004, by + 0.004, F.z + 0.034), "gold_dark"))
        else:  # a chain-flail ending in a spiked skull
            F = pts[-1]
            ch = [F + V((0.0, -0.010, -0.010)), F + V((-0.012, -0.016, -0.026)), F + V((-0.020, -0.020, -0.046)), F + V((-0.024, -0.022, -0.064))]
            arm += chain("flailchain", ch, [0.0018] * 4, "bronze", 5, joints=False)
            sk = ch[-1] + V((0, -0.002, -0.010))
            arm += b4.mini_skull(sk, 0.0120, "bone_aged", 0)
            for k in range(8):
                a = 2 * PI * k / 8
                arm.append(seg("flailspike", sk + V((math.cos(a) * 0.0100, 0, math.sin(a) * 0.0100)), sk + V((math.cos(a) * 0.0200, 0, math.sin(a) * 0.0200)), 0.0030, 0.0002, "gold_dark", 4))
        groups.append(("arm_" + nm, arm, tuple(sh), ""))
    # head: brutal skull in an iron half-helm, horns, tusks, ember eyes
    HC = V((0, -0.016, 0.172))
    head = [bc.blob("skull", 0.0200, tuple(HC), SK, 3, (1.0, 1.05, 0.88)), bc.blob("brow", 0.0120, tuple(HC + V((0, -0.0170, 0.0090))), SK2, 2, (1.9, 0.6, 0.5)),
            bc.blob("nose", 0.0060, tuple(HC + V((0, -0.0230, -0.0030))), SK2, 2, (1.1, 0.8, 0.9)), bc.blob("helm", 0.0210, tuple(HC + V((0, 0.0040, 0.0090))), "bronze", 3, (1.03, 1.0, 0.78)),
            bc.box("nasal", (0.0040, 0.0040, 0.0130), tuple(HC + V((0, -0.0225, 0.0000))), "bronze"), bc.box("helmband", (0.0420, 0.0360, 0.0030), tuple(HC + V((0, 0.0000, 0.0100))), "gold_dark")]
    for s in (-1, 1):
        head += [bc.blob("socket", 0.0058, tuple(HC + V((s * 0.0085, -0.0190, 0.0020))), "obsidian", 2, (1.1, 0.6, 0.9)), bc.blob("eye", 0.0034, tuple(HC + V((s * 0.0085, -0.0225, 0.0020))), "ember", 1, (1.0, 0.5, 0.9)),
                 bc.blob("cheek", 0.0075, tuple(HC + V((s * 0.0140, -0.0120, -0.0050))), SK2, 2, (0.9, 1.0, 0.9))]
        head += chain("horn", [HC + V((s * 0.0160, 0.0020, 0.0140)), HC + V((s * 0.0300, 0.0000, 0.0200)), HC + V((s * 0.0380, -0.0050, 0.0360)), HC + V((s * 0.0350, -0.0100, 0.0500))], [0.0060, 0.0050, 0.0036, 0.0002], "bone_shadow", 7, joints=False)
        head.append(flat("ear", [(s * 0.0190, 0.0050, 0.1700), (s * 0.0320, 0.0040, 0.1760), (s * 0.0400, 0.0040, 0.1860), (s * 0.0300, 0.0040, 0.1700), (s * 0.0210, 0.0040, 0.1640)], 0.0020, SK2))
        head += b3.me.ring3d((s * 0.0300, 0.0040, 0.1720), 0.0030, 0.0008, 6, "gold_dark", "xz")
    head += chain("scar", [HC + V((0.0150, -0.0150, 0.0160)), HC + V((0.0080, -0.0230, 0.0040)), HC + V((0.0030, -0.0230, -0.0120))], [0.0012] * 3, "blood_red", 4, joints=False)
    groups.append(("head", head, tuple(HC), ""))
    hinge = V((0, 0.004, -0.008))
    jaw = [bc.blob("jaw", 0.0160, (0, -0.0160, -0.0170), SK2, 3, (1.0, 1.1, 0.6)), bc.blob("chin", 0.0080, (0, -0.0300, -0.0200), SK, 2, (1.1, 0.9, 1.0)), bc.blob("throat", 0.0090, (0, -0.0100, -0.0080), "ember", 2, (1.0, 0.8, 0.7))]
    for s in (-1, 1):
        jaw += chain("tusk", [V((s * 0.0100, -0.0260, -0.0200)), V((s * 0.0125, -0.0300, -0.0080)), V((s * 0.0105, -0.0280, 0.0100)), V((s * 0.0090, -0.0240, 0.0200))], [0.0058, 0.0050, 0.0036, 0.0002], "bone_warm", 7, joints=False)
        for k in range(4):
            jaw.append(seg("tooth", V((s * 0.0070, -0.0090 - k * 0.0040, -0.0160)), V((s * 0.0070, -0.0090 - k * 0.0040, -0.0080)), 0.0020, 0.0002, "bone_warm", 4))
    jaw = shift(jaw, -hinge)
    jaw = [place(o, (32, 0, 0), tuple(HC + hinge)) for o in jaw]
    groups.append(("jaw", jaw, tuple(HC + hinge), "head"))
    # hide cape
    cape = []
    for k in range(12):
        x0 = (k - 5.5) * 0.0072
        pts = [V((x0, 0.030, 0.158)), V((x0 * 1.3, 0.044, 0.140)), V((x0 * 1.6, 0.056, 0.100)), V((x0 * 1.8, 0.062, 0.060)), V((x0 * 2.0, 0.066, 0.018))]
        cape += bk.skin("hide", pts, [0.0012] * 5, [0.0058] * 5, lambda i, n, k=k: stop(["wood_dark", "hand_dark_brown", "wood_mid", "charcoal"], ((k + i) % 4) / 4), sides=4, per=4)[0]
    groups.append(("cape", cape, (0, 0.030, 0.158), ""))
    # P3: fire gushes from the pipes, the furnace door and the cleaver
    fl = []
    for s in (-1, 1):
        for k in range(7):
            fl += chain("flame", [V((s * 0.020 + 0.0030 * (k - 3) * 0.4, 0.0525, 0.2090)), V((s * 0.020 + 0.0040 * (k - 3) * 0.6, 0.0560, 0.2250 + 0.002 * k)), V((s * 0.020 + 0.0060 * (k - 3) * 0.8, 0.0620, 0.2450 + 0.003 * k)), V((s * 0.020 + 0.0070 * (k - 3), 0.0660, 0.2650 + 0.004 * k))],
                         [0.0050, 0.0040, 0.0024, 0.0002], stop(FLAME, (k % 6) / 6), 4, joints=False)
    for k in range(9):
        fl += chain("furnace_flame", [V((-0.012 + k * 0.0030, -0.0400, 0.1400)), V((-0.012 + k * 0.0030, -0.0470, 0.1500 + 0.002 * k)), V((-0.012 + k * 0.0030 + 0.002 * (k - 4) * 0.5, -0.0550, 0.1620 + 0.003 * k))], [0.0040, 0.0028, 0.0002], stop(FLAME, (k % 6) / 6), 4, joints=False)
    groups.append(("flames", fl, (0, 0.040, 0.210), ""))
    obj = bc.assemble("ew_boss_furnace_orc_v01", groups)
    tag(obj, "flames", 3, None)
    b3.crystal_anchors(obj, 0.0900, 0.1050)
    bc.anchor(obj, "flame_anchor", tuple(HC + V((0, -0.0350, -0.0150))), "jaw", 0.010)
    bc.anchor(obj, "eye_anchor", tuple(HC + V((0.0085, -0.0240, 0.0020))), "head", 0.005)
    bc.anchor(obj, "furnace_anchor", (0, -0.0450, 0.1220), "", 0.010)
    bc.anchor(obj, "pipe_anchor_l", (0.0205, 0.0525, 0.2100), "", 0.008)
    bc.anchor(obj, "pipe_anchor_r", (-0.0205, 0.0525, 0.2100), "", 0.008)
    bc.anchor(obj, "blade_anchor", (-0.070, -0.052, 0.260), "arm_r", 0.010)
    bc.anchor(obj, "summon_anchor", (0, -0.1000, 0.0200), "", 0.008)
    return obj


BOSSES = {"cinder_mammoth": cinder_mammoth, "gravemaw_bear": gravemaw_bear, "furnace_orc": furnace_orc}

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    key = argv[0] if argv else "cinder_mammoth"
    bc.clear_scene()
    obj = BOSSES[key]()
    mc.smooth(obj)
    print("TRIS", key, mc.tri_count(obj))
    ph = argv[1] if len(argv) > 1 and argv[1] in ("p1", "p2", "p3") else None
    if ph:
        keep_phase(obj, int(ph[1]))
        bc.save_blend(obj, "boss_%s_%s" % (key, ph))
    else:
        bc.save_blend(obj, "boss_" + key)
