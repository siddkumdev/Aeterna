"""Blind-pick set for the Storm Cloud strike (restart batch 4, Siddharth 2026-11-15). Claude cannot listen: the user picks.

    python tools/audio_ab_storm.py

Writes _work/audio_ab/storm_strike/ (git-ignored):
  1.wav 2.wav 3.wav          the three strike candidates (take 1 of each), level-matched, in a shuffled order
  ctx_1.wav ctx_2.wav ctx_3.wav   the same three in a short in-game mix: cast swell, soft rain under the cloud, three strikes
                             (a chain of 3 enemies = strike + two snaps, a single enemy, an empty strike = far roll, a chain again)
  KEY.txt                    which number is which candidate (do not open before listening)
The strike is level-matched at the install level; everything else in the mix is the installed game sound.
"""
import os
import random
import sys

import numpy as np
import soundfile as sf

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.join(ROOT, "assets", "generators"))
import install_sfx_restart as I  # noqa: E402

S = I.S
OUT = os.path.join(ROOT, "_work", "audio_ab", "storm_strike")
EXP = os.path.join(ROOT, "godot", "assets", "audio")
SEED = 20261115


def strike(cand, k=0):
    import zlib
    seed = zlib.crc32(("ab:storm_strike:%s:%d" % (cand, k)).encode())
    r = S.rng(seed)
    x = I.room(I.STORM_CANDIDATES[cand](r), 0.25, 0.08)
    x = S.fade(S.trim_silence(S.remove_dc(np.asarray(x, float)), -55.0, 0.02), 0.0015, 0.05)
    return S.normalise(x, rms_db=-19.0, max_peak_db=-2.0)


def game(name):
    x, sr = sf.read(os.path.join(EXP, name))
    return x if x.ndim == 1 else x.mean(axis=1)


def context(st):
    rain = game("storm_rain.wav")
    n = S.n_of(6.6)
    rain = np.tile(rain, 2)[:n].copy()
    fi, fo = S.n_of(0.4), S.n_of(0.5)
    rain[:fi] *= np.linspace(0, 1, fi)
    rain[-fo:] *= np.linspace(1, 0, fo)
    layers = [(game("storm_cloud_1.wav"), 0.0, 1.0), (rain, 0.0, 1.0)]
    snaps = [game("storm_snap_1.wav"), game("storm_snap_3.wav")]
    layers += [(st, 0.5, 1.0), (snaps[0], 0.5, 0.9), (snaps[1], 0.5, 0.8)]      # chain of 3
    layers += [(S.fade(strike_alt(1), 0.0015, 0.05), 2.0, 1.0)]                   # single enemy
    layers += [(game("storm_far_1.wav"), 3.5, 1.0)]                               # empty strike
    layers += [(st, 5.0, 1.0), (snaps[1], 5.0, 0.9), (snaps[0], 5.0, 0.8)]       # chain again
    y = S.mix(*layers, seconds=7.4)
    return S.normalise(y, peak_db=-1.5) if np.max(np.abs(y)) > 0.89 else y


_CAND = {}


def strike_alt(k):
    return strike(_CAND["c"], k)


def main():
    os.makedirs(OUT, exist_ok=True)
    cands = ["A", "B", "C"]
    order = cands[:]
    random.Random(SEED).shuffle(order)
    key = []
    for i, c in enumerate(order, 1):
        _CAND["c"] = c
        st = strike(c, 0)
        sf.write(os.path.join(OUT, "%d.wav" % i), st, 44100, subtype="PCM_16")
        sf.write(os.path.join(OUT, "ctx_%d.wav" % i), context(st), 44100, subtype="PCM_16")
        key.append("%d = candidate %s (%s)" % (i, c, {"A": "full strike, 1.6 s, top rounded at 4.5 kHz",
                                                      "B": "with the first small crack before the crash, 2.0 s, top rounded at 3.6 kHz",
                                                      "C": "tight and round, 1.1 s, top rounded at 2.8 kHz"}[c]))
        print("wrote %d.wav and ctx_%d.wav" % (i, i))
    open(os.path.join(OUT, "KEY.txt"), "w").write("\n".join(key) + "\nCandidate A is the provisional default in the game.\n")


if __name__ == "__main__":
    main()
