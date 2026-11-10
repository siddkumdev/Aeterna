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


ROUNDS = {"r1": {"tap_a": tap_a, "tap_b": tap_b, "tap_c": tap_c},
          "r2": {"wiz_a": _package(wiz_launch_a, wiz_hit_a), "wiz_b": _package(wiz_launch_b, wiz_hit_b, 1.4),
                 "wiz_c": _package(wiz_launch_c, wiz_hit_c, 2.6)}}

if __name__ == "__main__":
    rnd = sys.argv[1] if len(sys.argv) > 1 else "r1"
    out = os.path.join(ROOT, "_work", "audio", "restart", rnd)
    os.makedirs(out, exist_ok=True)
    for name, fn in ROUNDS[rnd].items():
        S.write_wav(os.path.join(out, name + ".wav"), fn(1))
        print("wrote", name)
