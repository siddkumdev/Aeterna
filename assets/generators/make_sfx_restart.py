"""SFX restart candidates (Siddharth 2026-11-10). Synthesis is allowed again. Brief: docs/AUDIO_DIRECTION.md.
Writes candidates to _work/audio/restart/<round>/ (git-ignored). Nothing here touches the game's sounds.
    python assets/generators/make_sfx_restart.py r1
Round r1: tower placing, 'a soft wooden tap', stylised, cosy, round, never buzzy/metallic/sharp/bit-crushed.
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import audio_synth as S  # noqa: E402


def _finish(x, tail=0.05):
    x = S.remove_dc(S.hp(x, 70))
    x = S.lp(x, 6500)  # nothing sharp: no content above 6.5 kHz
    x = S.fade(S.trim_silence(x, -55), 0.001, tail)
    x = S.room(x, 0.18, 0.12)
    return S.normalise(x, -5.0, -20.0, -3.0)


def tap_a(seed):  # a wooden block, soft mallet: round, short
    r = S.rng(seed)
    body = S.modal(330, 0.28, "wood", r, hardness=0.15, nmodes=3)
    low = S.thud(0.2, 150, 95, 0.06, r, grit=0.1) * 0.5
    return _finish(S.mix((body, 0, 1.0), (low, 0, 0.6)))


def tap_b(seed):  # a hollow wooden box: a warm knock with a soft low body
    r = S.rng(seed)
    body = S.modal(220, 0.3, "wood", r, hardness=0.1, nmodes=4)
    knock = S.thud(0.25, 190, 110, 0.07, r, grit=0.15)
    return _finish(S.mix((body, 0, 0.8), (knock, 0, 0.9)))


def tap_c(seed):  # a toy marimba-bar tap: very short, cute, a little pitched
    r = S.rng(seed)
    bar = S.marimba(392, 0.32, hard=0.1)
    tick = S.lp(S.modal(520, 0.1, "wood", r, hardness=0.2, nmodes=2), 3000) * 0.5
    low = S.thud(0.18, 170, 110, 0.05, r, grit=0.0) * 0.4
    return _finish(S.mix((bar, 0, 0.8), (tick, 0, 0.5), (low, 0, 0.5)))


# Round r2: Wizard Tower, a launch then (0.8 s later) the hit, as one package per choice. Clash Royale Wizard feel
# (his words), cosy, weighty hit, nothing buzzy/metallic/sharp. The hit sound belongs to the TOWER (his rule).
def _soft(x, hz=4500):
    x = S.remove_dc(S.hp(x, 90))  # headset-safe: no sub-bass rumble
    x = S.lp(x, hz)
    return S.fade(S.trim_silence(x, -55), 0.002, 0.05)


def wiz_launch_a(r):  # airy whoomf: a soft rising-then-falling air swell with a round low body
    air = S.whoosh(0.45, 500, 1400, r, q=0.8, peak=0.5)
    low = S.thud(0.3, 230, 120, 0.1, r, grit=0.0) * 0.5
    return _soft(S.mix((air, 0, 0.8), (low, 0.02, 0.7)), 3500)


def wiz_launch_b(r):  # round tonal 'bloop': a soft sine glide up
    g = S.chirp(280, 620, 0.32) * S.exp_env(0.32, 0.18, 0.01)
    g2 = S.chirp(140, 310, 0.32) * S.exp_env(0.32, 0.2, 0.01) * 0.6
    air = S.whoosh(0.35, 400, 900, r, q=0.8, peak=0.25)
    return _soft(S.mix((g, 0, 0.8), (g2, 0, 0.6), (air, 0, 0.5)), 3000)


def wiz_launch_c(r):  # warm fire: a soft fire rush with a little crackle
    f = S.lp(S.fire_texture(0.5, r, 1.0), 2800) * S.exp_env(0.5, 0.25, 0.04)
    cr = S.lp(S.crackle(0.4, r, 25, 1800), 2500) * 0.4
    low = S.thud(0.25, 200, 110, 0.08, r, grit=0.0) * 0.4
    return _soft(S.mix((f, 0, 0.9), (cr, 0.05, 0.5), (low, 0, 0.6)), 3500)


def wiz_hit_a(r):  # round thump with a soft air puff
    t = S.thud(0.45, 280, 120, 0.12, r, grit=0.08)
    puff = S.lp(S.noise(0.25, r), 1400) * S.exp_env(0.25, 0.07, 0.002)
    return _soft(S.mix((t, 0, 1.0), (puff, 0, 1.6)), 3000)


def wiz_hit_b(r):  # 'bwomp': a low sine drop with a soft wooden knock on top
    t = S.thud(0.5, 300, 125, 0.13, r, grit=0.0)
    k = S.modal(420, 0.2, "wood", r, hardness=0.15, nmodes=3)
    return _soft(S.mix((t, 0, 1.0), (k, 0, 1.0)), 2800)


def wiz_hit_c(r):  # warm burst: thump, soft fire puff and gentle crackles
    t = S.thud(0.4, 280, 120, 0.11, r, grit=0.05)
    f = S.lp(S.fire_texture(0.4, r, 1.0), 2200) * S.exp_env(0.4, 0.12, 0.002)
    cr = S.lp(S.crackle(0.35, r, 30, 1800), 2200) * 0.4
    return _soft(S.mix((t, 0, 1.0), (f, 0, 1.6), (cr, 0.03, 0.8)), 3200)


def _package(launch, hit, lg=2.2):
    def fn(seed):
        r = S.rng(seed)
        x = S.mix((launch(r), 0, lg), (hit(r), 0.8, 1.0))
        x = S.room(x, 0.2, 0.12)
        return S.normalise(x, -5.0, -21.0, -3.0)
    return fn


# Round r3 (after he rejected r2: "they dont sound like fire magic at all"). His words for fire: launch = whoosh + roar /
# flame rush; hit = soft 'fwoomf' burst. So now NOISE-led (air and flame), not tonal thumps; still soft-topped.
def _rush(seconds, r, lo, hi, peak_at, tex):
    n = S.noise(seconds, r, "pink")
    cut = S.curve([(0, lo), (seconds * peak_at, hi), (seconds, lo * 0.8)], seconds)
    air = S.sweep_lp(n, cut) * S.curve([(0, 0.02), (seconds * peak_at, 1.0), (seconds, 0.02)], seconds, log=False)
    fire = S.lp(S.fire_texture(seconds, r, 1.2), 4200) * S.curve([(0, 0.05), (seconds * peak_at, 1.0), (seconds, 0.05)], seconds, log=False)
    return S.pk(air) * 1.0 + S.pk(fire) * tex


def wiz3_launch(lo, hi, peak_at, tex, secs=0.6):
    return lambda r: _soft(_rush(secs, r, lo, hi, peak_at, tex), 5000)


def wiz3_hit(body, fire, secs=0.5):
    def fn(r):
        n = S.noise(secs, r, "pink")
        cut = S.curve([(0, 3200), (0.12, 900), (secs, 350)], secs)
        puff = S.sweep_lp(n, cut) * S.exp_env(secs, 0.13, 0.003)
        low = S.thud(secs, 240, 115, 0.1, r, grit=0.0)
        cr = S.lp(S.crackle(0.35, r, 28, 1800), 3200)
        f = S.lp(S.fire_texture(0.4, r, 1.0), 3500) * S.exp_env(0.4, 0.14, 0.003)
        return _soft(S.mix((S.pk(puff), 0, 1.0), (low, 0, body), (cr, 0.03, 0.35), (f, 0, fire)), 4800)
    return fn


ROUNDS_R3 = {"wiz_a": _package(wiz3_launch(450, 3200, 0.45, 0.6), wiz3_hit(0.4, 0.5), 1.0),
             "wiz_b": _package(wiz3_launch(600, 4200, 0.4, 0.25), wiz3_hit(0.3, 0.25), 1.0),
             "wiz_c": _package(wiz3_launch(350, 2400, 0.55, 1.0, 0.7), wiz3_hit(0.6, 0.9), 1.0)}

# Round r4: he liked r3 choices 2 and 3 (wiz_b, wiz_a) but found them muffled, "not like a fireball". Cause (measured in the
# code): pink noise, low-passes at 3.5-5 kHz and a dark room tail. Fix: open the top end (still no hiss above ~9 kHz),
# whiter noise, a falling 'swish' as the fireball flies away, brighter crackles, a hit with a full-bandwidth attack.
def _open(x, hz):
    x = S.remove_dc(S.hp(x, 90))
    x = S.lp(x, hz)
    return S.fade(S.trim_silence(x, -55), 0.002, 0.05)


def wiz4_launch(hi, tex, swish, hz, secs=0.6):
    def fn(r):
        n = 0.5 * S.noise(secs, r, "white") + 0.5 * S.noise(secs, r, "pink") * 0.6
        cut = S.curve([(0, 600), (secs * 0.35, hi), (secs, 700)], secs)
        env = S.curve([(0, 0.03), (secs * 0.3, 1.0), (secs, 0.03)], secs, log=False)
        air = S.sweep_lp(n, cut) * env
        fire = S.lp(S.fire_texture(secs, r, 1.2), hz) * env
        sw = S.sweep_bp(S.noise(secs, r, "white"), S.curve([(0, 4200), (secs, 900)], secs), 1.4) * S.curve([(0, 0.0), (secs * 0.35, 0.2), (secs, 0.0)], secs, log=False)
        tail = S.lp(S.crackle(secs, r, 35, 3000), hz) * env
        return _open(S.pk(air) + S.pk(fire) * tex + S.pk(sw) * swish + 0.35 * S.pk(tail), hz)
    return fn


def wiz4_hit(hz, body, spark, secs=0.55):
    def fn(r):
        n = 0.5 * S.noise(secs, r, "white") + 0.5 * S.noise(secs, r, "pink") * 0.6
        cut = S.curve([(0, hz), (0.1, 1800), (secs, 450)], secs)
        puff = S.sweep_lp(n, cut) * S.exp_env(secs, 0.15, 0.002)
        low = S.thud(secs, 250, 120, 0.1, r, grit=0.0)
        sp = S.lp(S.crackle(0.4, r, 45, 3500), hz) * S.exp_env(0.4, 0.16, 0.002)
        f = S.lp(S.fire_texture(0.45, r, 1.1), hz) * S.exp_env(0.45, 0.16, 0.002)
        return _open(S.mix((S.pk(puff), 0, 1.0), (low, 0, body), (sp, 0.02, spark), (f, 0, 0.5)), hz)
    return fn


def _package4(launch, hit, lg=1.0):
    def fn(seed):
        r = S.rng(seed)
        x = S.mix((launch(r), 0, lg), (hit(r), 0.8, 1.0))
        x = S.room(x, 0.2, 0.07)
        return S.normalise(x, -5.0, -21.0, -3.0)
    return fn


ROUNDS_R4 = {"wiz_a": _package4(wiz4_launch(5500, 0.35, 0.6, 7500), wiz4_hit(7500, 0.4, 0.5)),
             "wiz_b": _package4(wiz4_launch(7000, 0.5, 0.9, 9000), wiz4_hit(9000, 0.4, 0.6)),
             "wiz_c": _package4(wiz4_launch(8000, 0.8, 0.6, 11000), wiz4_hit(11000, 0.5, 0.9))}

# Round r5: the other towers, matched to the Wizard pick (Siddharth 2026-11-10: fireball_2 = wiz_a of r4, the softer one).
# Same open-but-soft top end (7.5 kHz), noise-led, no metal. One version each, to be confirmed or corrected by him.
HZ5 = 7500


def longbow_shot(r):  # a wooden 'thwip': a short wood knock of the limb plus a quick falling swish of the bolt
    knock = S.modal(520, 0.12, "wood", r, hardness=0.25, nmodes=3)
    sw = S.sweep_bp(S.noise(0.22, r, "white"), S.curve([(0, 3800), (0.22, 1200)], 0.22), 1.3) * S.exp_env(0.22, 0.08, 0.004)
    return _open(S.mix((knock, 0, 0.8), (S.pk(sw), 0.01, 0.9)), HZ5)


def longbow_tick(r):  # a soft wooden tick, one per enemy the bolt pierces
    return _open(S.modal(700, 0.07, "wood", r, hardness=0.2, nmodes=2), HZ5)


def longbow_pkg(seed):
    r = S.rng(seed)
    x = S.mix((longbow_shot(r), 0, 1.0), (longbow_tick(r), 0.4, 0.6), (longbow_tick(r), 0.52, 0.5), (longbow_tick(r), 0.64, 0.45))
    return S.normalise(S.room(x, 0.2, 0.07), -5.0, -21.0, -3.0)


def guard_clop(r):  # a Guard steps out: wood and cloth, small
    wood = S.modal(420, 0.14, "wood", r, hardness=0.3, nmodes=4)
    pat = S.lp(S.noise(0.1, r, "white"), 4500) * S.exp_env(0.1, 0.03, 0.002)
    return _open(S.mix((wood, 0, 0.8), (S.pk(pat), 0, 0.9)), HZ5)


def guard_hit(r):  # a dull light thud: cloth pat and a soft low body
    low = S.thud(0.2, 230, 130, 0.07, r, grit=0.0)
    pat = S.lp(S.noise(0.15, r, "white"), 4000) * S.exp_env(0.15, 0.04, 0.002)
    return _open(S.mix((low, 0, 0.7), (S.pk(pat), 0, 1.1)), HZ5)


def guard_pkg(seed):
    r = S.rng(seed)
    x = S.mix((guard_clop(r), 0, 1.0), (guard_clop(r), 0.2, 0.8), (guard_hit(r), 0.9, 1.1))
    return S.normalise(S.room(x, 0.2, 0.07), -5.0, -21.0, -3.0)


def cannon_shot(r):  # round 'thoomp' with a soft puff of air, no bang
    low = S.thud(0.45, 260, 115, 0.13, r, grit=0.05)
    puff = S.sweep_lp(S.noise(0.35, r, "white"), S.curve([(0, 6000), (0.1, 2200), (0.35, 600)], 0.35)) * S.exp_env(0.35, 0.1, 0.002)
    return _open(S.mix((low, 0, 0.8), (S.pk(puff), 0, 1.5)), HZ5)


def cannon_hit(r):  # a cannonball lands: heavy soft thump, earthy dust puff
    low = S.thud(0.5, 220, 100, 0.15, r, grit=0.1)
    dust = S.sweep_lp(S.noise(0.45, r, "white"), S.curve([(0, 5000), (0.15, 1800), (0.45, 500)], 0.45)) * S.exp_env(0.45, 0.14, 0.002)
    return _open(S.mix((low, 0, 0.8), (S.pk(dust), 0, 1.4)), HZ5)


def cannon_pkg(seed):
    r = S.rng(seed)
    x = S.mix((cannon_shot(r), 0, 1.0), (cannon_hit(r), 0.8, 1.0))
    return S.normalise(S.room(x, 0.2, 0.07), -5.0, -21.0, -3.0)


ROUNDS_R5 = {"longbow": longbow_pkg, "guard": guard_pkg, "airship": cannon_pkg}

# Round r6: Longbow Tower rebuilt as a CROSSBOW (Siddharth 2026-11-10: round 5 "doesn't sound like a bow, sounds so random";
# chose crossbow: a short tight 'thunk' of the release, one quick bolt whoosh, a soft 'thup' per pierced enemy).
# One coherent event instead of knock + unrelated swish: thunk, string snap and whoosh start together.
def xbow_shot(thunk_hz, snap, snap_hi, whoosh_g, body, hz=HZ5, click=0.0, wh_hi=3200):
    def fn(r):
        thunk = S.modal(thunk_hz, 0.14, "wood", r, hardness=0.3, nmodes=4)
        low = S.thud(0.12, 210, 130, 0.05, r, grit=0.0)
        sn = S.bp(S.noise(0.06, r, "white"), 1800, snap_hi) * S.exp_env(0.06, 0.012, 0.0008)
        wh = S.sweep_bp(S.noise(0.2, r, "white"), S.curve([(0, wh_hi), (0.2, 1400)], 0.2), 1.2) * S.exp_env(0.2, 0.06, 0.004)
        ck = S.modal(900, 0.04, "wood", r, hardness=0.5, nmodes=2)
        return _open(S.mix((thunk, 0, 0.9), (low, 0, body), (S.pk(sn), 0, snap), (S.pk(wh), 0.015, whoosh_g), (ck, 0, click)), hz)
    return fn


def xbow_thup(r):  # a soft pierce: short muted pat, not a tick
    pat = S.lp(S.noise(0.07, r, "white"), 3200) * S.exp_env(0.07, 0.02, 0.001)
    low = S.thud(0.08, 260, 160, 0.03, r, grit=0.0)
    return _open(S.mix((S.pk(pat), 0, 1.1), (low, 0, 0.5)), HZ5)


def xbow_pkg(shot):
    def fn(seed):
        r = S.rng(seed)
        x = S.mix((shot(r), 0, 1.0), (xbow_thup(r), 0.4, 0.6))  # one pierce sound only (Siddharth 2026-11-10: option 2)
        return S.normalise(S.room(x, 0.2, 0.07), -5.0, -21.0, -3.0)
    return fn


ROUNDS_R6 = {"xbow_a": xbow_pkg(xbow_shot(480, 0.9, 5000, 0.8, 0.4)),
             "xbow_b": xbow_pkg(xbow_shot(430, 0.9, 5500, 0.6, 0.5)),
             "xbow_c": xbow_pkg(xbow_shot(400, 0.7, 4000, 0.6, 0.7))}

# Round r7: he picked crossbow_1 (= xbow_a) but "a little dull": three less-dull variations of it (more top end, crisper snap).
ROUNDS_R7 = {"xbow_a1": xbow_pkg(xbow_shot(480, 1.3, 6500, 0.9, 0.4, 9000, 0.0, 4200)),
             "xbow_a2": xbow_pkg(xbow_shot(560, 1.0, 6000, 1.0, 0.25, 8500, 0.0, 4500)),
             "xbow_a3": xbow_pkg(xbow_shot(480, 1.1, 6000, 0.9, 0.35, 9000, 0.45, 4200))}

# Round r8: the five spells (Siddharth 2026-11-10). Fire Orb = the Wizard fireball bigger; Boulder = heavy stone thud;
# Storm Cloud = soft crackle + dark rolling rumble; Rage = swell like a drumbeat / heartbeat; Root Ward = creaky, woody.
# "Yes" to 'all clearly stronger than tower shots' is read by the agent as: yes, spells are bigger than tower sounds.
HZ8 = 8000


def _pkg8(fn_):
    def fn(seed):
        r = S.rng(seed)
        return S.normalise(S.room(fn_(r), 0.25, 0.08), -5.0, -21.0, -3.0)
    return fn


def fire_orb(r):
    launch = wiz4_launch(5500, 0.35, 0.6, 7500, 0.8)(r)
    hit = wiz4_hit(7500, 0.9, 0.5, 0.8)(r)
    big = S.thud(0.7, 210, 100, 0.18, r, grit=0.1)
    return S.mix((launch, 0, 1.0), (hit, 1.0, 1.3), (_open(big, HZ8), 1.0, 0.7))


def boulder(r):
    fall = S.sweep_bp(S.noise(0.5, r, "white"), S.curve([(0, 2500), (0.5, 600)], 0.5), 1.0) * S.curve([(0, 0.0), (0.45, 1.0), (0.5, 0.0)], 0.5, log=False)
    thud = S.thud(0.7, 200, 100, 0.2, r, grit=0.15)
    stone = S.modal(190, 0.3, "stone", r, hardness=0.35, nmodes=5)
    dust = S.sweep_lp(S.noise(0.7, r, "pink"), S.curve([(0, 6000), (0.2, 2000), (0.7, 500)], 0.7)) * S.exp_env(0.7, 0.2, 0.003)
    rumble = S.lp(S.noise(1.0, r, "pink"), 450) * S.exp_env(1.0, 0.35, 0.01)
    return S.mix((_open(S.pk(fall), HZ8), 0, 0.5), (_open(thud, HZ8), 0.5, 0.8), (_open(S.modal(300, 0.25, "stone", r, hardness=0.4, nmodes=5), HZ8), 0.5, 0.9),
                 (_open(stone, HZ8), 0.5, 0.6), (_open(S.pk(dust), HZ8), 0.5, 1.6), (_open(S.pk(rumble), 2000), 0.5, 0.4))


def storm_cloud(r):
    secs = 2.0
    rum = S.lp(S.noise(secs, r, "pink"), 500)
    am = 0.6 + 0.4 * S.lp(r.standard_normal(S.n_of(secs)), 3, 1) * 4
    env = S.curve([(0, 0.05), (0.5, 1.0), (1.6, 0.9), (secs, 0.05)], secs, log=False)
    body = S.pk(rum) * np.clip(am, 0.2, 1.2) * env
    mid = S.sweep_lp(S.noise(secs, r, "pink"), S.curve([(0, 1800), (1.0, 2600), (secs, 1400)], secs)) * env * 0.8
    out = [(_open(S.pk(body), 2500), 0, 1.0), (_open(S.pk(mid), 3000), 0, 1.0)]
    for at, g in ((0.7, 1.6), (1.05, 1.4), (1.4, 1.2)):  # three chained soft strikes
        cr = S.lp(S.crackle(0.18, r, 90, 3000), 5500) * S.exp_env(0.18, 0.05, 0.001)
        tk = S.thud(0.1, 240, 130, 0.04, r, grit=0.0)
        out += [(_open(S.pk(cr), HZ8), at, g), (_open(tk, HZ8), at, 0.5)]
    return S.mix(*out)


def rage(r):
    beats = []
    for k in range(4):  # lub-dub x4, each pair louder and a little higher: a swelling heartbeat
        t0 = k * 0.42
        g = 0.45 + 0.2 * k
        f0 = 230 + 18 * k
        beats.append((_open(S.thud(0.22, f0, 120, 0.07, r, grit=0.05), HZ8), t0, g))
        beats.append((_open(S.thud(0.22, f0 * 0.92, 112, 0.07, r, grit=0.05), HZ8), t0 + 0.17, g * 0.75))
        beats.append((_open(S.modal(420, 0.1, "wood", r, hardness=0.35, nmodes=3), HZ8), t0, g * 0.7))
        beats.append((_open(S.modal(380, 0.1, "wood", r, hardness=0.3, nmodes=3), HZ8), t0 + 0.17, g * 0.5))
    secs = 1.9
    sw = S.sweep_lp(S.noise(secs, r, "pink"), S.curve([(0, 1200), (secs, 5000)], secs)) * S.curve([(0, 0.05), (1.6, 1.0), (secs, 0.05)], secs, log=False)
    return S.mix(*beats, (_open(S.pk(sw), HZ8), 0, 1.0))


def root_ward(r):
    secs = 1.6
    out = []
    for at, f0, f1, g in ((0.0, 520, 840, 1.0), (0.45, 640, 420, 0.9), (0.9, 480, 760, 1.0)):  # three woody creaks
        n = S.noise(0.5, r, "white")
        c = S.sweep_bp(n, S.curve([(0, f0), (0.5, f1)], 0.5), 9.0)
        c = S.flutter(c, r, 0.5, 22.0) * S.curve([(0, 0.0), (0.12, 1.0), (0.4, 0.8), (0.5, 0.0)], 0.5, log=False)
        out.append((_open(S.pk(c), HZ8), at, g))
        out.append((_open(S.modal(f1 * 0.9, 0.12, "wood", r, hardness=0.3, nmodes=3), HZ8), at + 0.38, 0.6))
    leaf = S.sweep_bp(S.noise(secs, r, "white"), S.curve([(0, 1800), (secs, 2600)], secs), 0.8) * S.exp_env(secs, 0.6, 0.2) * 0.2
    out.append((_open(leaf, HZ8), 0, 1.0))
    return S.mix(*out)


ROUNDS_R8 = {"fire_orb": _pkg8(fire_orb), "boulder": _pkg8(boulder), "storm_cloud": _pkg8(storm_cloud),
             "rage": _pkg8(rage), "root_ward": _pkg8(root_ward)}

# Round r9: spells rebuilt on REAL RECORDINGS (Siddharth 2026-11-10: rejected the synthesised Boulder, Storm Cloud, Rage and Root
# Ward as "not what they are supposed to be"; chose "real recordings as the base"). Grains come from assets/audio_src/grains
# (cut and credited by the existing pipeline); code only cuts, pitches, filters and layers them. Fire Orb stays as r8.
sys.path.insert(0, HERE)
import make_audio as MA  # noqa: E402


def _g(kit, r, pitch=1.0, seconds=None, lpf=8000, hpf=90):
    x = MA.grain(kit, r, pitch, 0.05, seconds)
    return S.fade(S.lp(S.hp(x, hpf), lpf), 0.002, 0.03)


def boulder9(r):
    stone = [(_g("stone", r, 0.62, lpf=5000), 0.0, 1.0), (_g("stone", r, 0.75, lpf=5000), 0.015, 0.8)]
    thump = (_g("cannon", r, 0.9, seconds=0.5, lpf=2500), 0.0, 1.2)
    rumble = (_g("thunder", r, 1.0, seconds=1.2, lpf=1200), 0.02, 0.45)
    dust = (_g("dirt", r, 1.0, seconds=0.5, lpf=3500, hpf=300), 0.03, 0.5)
    fall = (S.sweep_bp(S.noise(0.45, r, "white"), S.curve([(0, 2200), (0.45, 700)], 0.45), 1.0)
            * S.curve([(0, 0.0), (0.42, 1.0), (0.45, 0.0)], 0.45, log=False) * 0.25, 0.0, 1.0)
    return S.mix(fall, *[(a, b + 0.45, c) for a, b, c in stone + [thump, rumble, dust]])


def storm9(r):
    secs = 2.4
    base = _g("thunder", r, 1.15, seconds=secs, lpf=2200, hpf=160)
    base = S.pk(base) * S.curve([(0, 0.1), (0.7, 1.0), (1.9, 0.9), (secs, 0.05)], secs, log=False) * 2.0
    out = [(base, 0, 1.0)]
    for at, g in ((0.8, 1.2), (1.2, 1.0), (1.6, 0.9)):
        out.append((_g("crackle", r, 1.0 + 0.1 * at, seconds=0.25, lpf=4200, hpf=300), at, g * 0.6))
    return S.mix(*out)


def rage9(r):
    out = []
    for k in range(4):
        t0 = k * 0.45
        g = 0.5 + 0.18 * k
        out.append((_g("drum", r, 1.25 + 0.03 * k, seconds=0.35, lpf=6000), t0, g * 0.7))
        out.append((_g("drum", r, 1.1 + 0.03 * k, seconds=0.35, lpf=6000), t0 + 0.18, g * 0.5))
        out.append((_g("wood_knock", r, 1.6, seconds=0.2, lpf=4500), t0, g * 1.0))
        out.append((_g("wood_knock", r, 1.4, seconds=0.2, lpf=4500), t0 + 0.18, g * 0.7))
    return S.mix(*out)


def root9(r):
    out = [(_g("creak", r, 1.0, seconds=1.4, lpf=3500, hpf=150), 0.0, 1.0), (_g("creak", r, 0.85, seconds=1.4, lpf=3500, hpf=150), 0.5, 0.8)]
    out.append((_g("wood_knock", r, 1.0, seconds=0.2, lpf=3500), 0.7, 0.4))
    out.append((_g("leaves", r, 1.0, seconds=1.5, lpf=3500, hpf=200), 0.1, 0.35))
    return S.mix(*out)


def _pkg9(fn_):
    def fn(seed):
        r = S.rng(seed)
        np.random.seed(seed)
        return S.normalise(S.room(fn_(r), 0.25, 0.08), -5.0, -21.0, -3.0)
    return fn


ROUNDS_R9 = {"boulder": _pkg9(boulder9), "storm_cloud": _pkg9(storm9), "rage": _pkg9(rage9), "root_ward": _pkg9(root9)}

# Round r10: Boulder good, Rage liked (kept). Storm Cloud: "sounds like sparks" -> no crackle grains at all; dark rolling thunder.
# Root Ward: "not a floorboard creak, a more Groot's branches sound" -> branches growing and slithering: leaf rustle, short
# twisting wood groans, soft swell, no long creaks.
def storm10a(r):  # rolling rumble with three low thunder 'strikes' (short thunder grains)
    secs = 2.6
    base = S.pk(_g("thunder", r, 1.1, seconds=secs, lpf=2200, hpf=150)) * S.curve([(0, 0.1), (0.8, 1.0), (2.0, 0.9), (secs, 0.05)], secs, log=False)
    out = [(base, 0, 1.0)]
    for at, g, kit in ((0.9, 1.0, "thunder"), (1.3, 0.85, "thunder"), (1.7, 0.75, "thunder")):
        out.append((_g(kit, r, 1.5, seconds=0.3, lpf=2500, hpf=140), at, g))
    return S.mix(*out)


def storm10b(r):  # only a dark rolling swell: two thunder layers
    secs = 2.6
    env = S.curve([(0, 0.05), (1.0, 1.0), (2.0, 0.8), (secs, 0.03)], secs, log=False)
    a = S.pk(_g("thunder", r, 1.0, seconds=secs, lpf=2000, hpf=150)) * env
    b = S.pk(_g("thunder", r, 1.35, seconds=secs, lpf=2600, hpf=200)) * env * 0.7
    return S.mix((a, 0, 1.0), (b, 0.15, 0.8))


def root10a(r):  # rustle-heavy: leaves swelling, short groans under it
    secs = 2.2
    env = S.curve([(0, 0.05), (0.9, 1.0), (1.8, 0.8), (secs, 0.03)], secs, log=False)
    lv = S.pk(_g("leaves", r, 0.95, seconds=secs, lpf=4500, hpf=250)) * env
    out = [(lv, 0, 1.0)]
    for at, pitch in ((0.2, 0.9), (0.7, 1.15), (1.2, 1.0)):
        out.append((_g("creak", r, pitch, seconds=0.34, lpf=3500, hpf=150), at, 0.55))
    return S.mix(*out)


def root10b(r):  # groan-heavy: many short twisting groans, a lighter rustle
    out = []
    t = 0.0
    for pitch, g in ((0.8, 0.8), (1.1, 0.7), (0.95, 0.8), (1.25, 0.6), (0.85, 0.7), (1.05, 0.5)):
        out.append((_g("creak", r, pitch, seconds=0.34, lpf=3500, hpf=150), t, g))
        t += float(r.uniform(0.18, 0.3))
    out.append((_g("leaves", r, 1.0, seconds=1.7, lpf=4000, hpf=250), 0.0, 0.5))
    return S.mix(*out)


ROUNDS_R10 = {"storm_a": _pkg9(storm10a), "storm_b": _pkg9(storm10b), "root_a": _pkg9(root10a), "root_b": _pkg9(root10b)}

ROUNDS = {"r1": {"tap_a": tap_a, "tap_b": tap_b, "tap_c": tap_c},
          "r2": {"wiz_a": _package(wiz_launch_a, wiz_hit_a), "wiz_b": _package(wiz_launch_b, wiz_hit_b, 1.4),
                 "wiz_c": _package(wiz_launch_c, wiz_hit_c, 2.6)}, "r3": ROUNDS_R3, "r4": ROUNDS_R4, "r5": ROUNDS_R5, "r6": ROUNDS_R6, "r7": ROUNDS_R7, "r8": ROUNDS_R8, "r9": ROUNDS_R9, "r10": ROUNDS_R10}

if __name__ == "__main__":
    rnd = sys.argv[1] if len(sys.argv) > 1 else "r1"
    out = os.path.join(ROOT, "_work", "audio", "restart", rnd)
    os.makedirs(out, exist_ok=True)
    for name, fn in ROUNDS[rnd].items():
        S.write_wav(os.path.join(out, name + ".wav"), fn(1))
        print("wrote", name)
