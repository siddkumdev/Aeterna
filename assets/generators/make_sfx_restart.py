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


ROUNDS = {"r1": {"tap_a": tap_a, "tap_b": tap_b, "tap_c": tap_c}}

if __name__ == "__main__":
    rnd = sys.argv[1] if len(sys.argv) > 1 else "r1"
    out = os.path.join(ROOT, "_work", "audio", "restart", rnd)
    os.makedirs(out, exist_ok=True)
    for name, fn in ROUNDS[rnd].items():
        S.write_wav(os.path.join(out, name + ".wav"), fn(1))
        print("wrote", name)
