"""Listening demos for sounds the game layers or schedules itself (Claude cannot listen; the user judges). Writes to
_work/audio/demo/ (git-ignored):

  1_barks.wav           each tower voice: ready, ready, cheer, cheer (wizard, archer, pilot, Guard Tower captain)
  2_day_ambience.wav    40 s of the day as the game plays it: day_bed + scattered one-shots (game.gd SCATTER_DAY)
  3_night_ambience.wav  40 s of the night: night_bed + SCATTER_NIGHT
  4_combo.wav           five quick enemy deaths climbing the scale (AudioBank.COMBO_STEPS), then one after a pause

Levels follow the game's bus mix (audio_bank.gd BUS_DB): ambience -15 dB, sfx -5 dB, ui -3 dB.
    python tools/audio_demo.py
"""
import glob
import json
import os
import re
import sys

import numpy as np
from scipy.io import wavfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from audio_synth import fade, n_of, pan, write_wav  # noqa: E402

EXP = os.path.join(ROOT, "assets", "export", "audio")
OUT = os.path.join(ROOT, "_work", "audio", "demo")
BUS_DB = {"ui": -3.0, "sfx": -5.0, "ambience": -15.0, "music": -10.0}
COMBO_STEPS = [0, 2, 4, 7, 9]
SCATTER_DAY = [("amb_bird", 5), ("amb_leaves", 2), ("amb_work", 2)]
SCATTER_NIGHT = [("amb_owl", 1), ("amb_creak", 2), ("amb_rustle", 2)]
MAN = json.load(open(os.path.join(EXP, "manifest.json"), encoding="utf-8"))
R = np.random.default_rng(11)


def load(fn):
    x = wavfile.read(os.path.join(EXP, fn))[1].astype(float) / 32768.0
    return x if x.ndim == 2 else np.stack([x, x], axis=1) * 0.7071


def take(name):
    files = MAN[name]["files"]
    return load(files[int(R.integers(0, len(files)))]["file"])


def gain(name):
    return 10 ** (BUS_DB[MAN[name]["bus"]] / 20)


def pitch(x, k):
    n = max(16, int(len(x) / k))
    at = np.linspace(0, len(x) - 1, n)
    return np.stack([np.interp(at, np.arange(len(x)), x[:, c]) for c in range(2)], axis=1)


def place(buf, x, t):
    i = n_of(t)
    j = min(len(buf), i + len(x))
    buf[i:j] += x[: j - i]


def mono_pan(x, p):
    return pan(x.mean(axis=1), p)


def ambience(bed, pool, gap, seconds=40.0):
    buf = np.zeros((n_of(seconds), 2))
    b = load(MAN[bed]["files"][0]["file"])
    reps = int(np.ceil(len(buf) / len(b)))
    place(buf, np.tile(b, (reps, 1))[: len(buf)] * gain(bed), 0)
    t = float(R.uniform(gap[0] * 0.5, gap[1]))
    ids, w = zip(*pool)
    w = np.array(w, float) / sum(w)
    while t < seconds - 3:
        name = ids[int(R.choice(len(ids), p=w))]
        x = pitch(take(name), 1 + float(R.uniform(-MAN[name]["vary"], MAN[name]["vary"])))
        place(buf, mono_pan(x, float(R.uniform(-0.9, 0.9))) * gain(name) * 0.8, t)  # far things: a little quieter, panned
        t += float(R.uniform(*gap))
    return fade(buf, 0.5, 1.5)


def main():
    os.makedirs(OUT, exist_ok=True)
    # 1 barks
    out, t = [], 0.0
    buf = np.zeros((n_of(40.0), 2))
    for crew in ("wizard", "archer", "pilot", "guard"):
        for kind in ("ready", "ready", "cheer", "cheer"):
            x = take("bark_%s_%s" % (crew, kind))
            place(buf, x * gain("bark_%s_%s" % (crew, kind)), t)
            t += len(x) / 44100 + 0.45
        t += 0.6
    write_wav(os.path.join(OUT, "1_barks.wav"), fade(buf[: n_of(t)], 0.001, 0.05) * 3.0)
    # 2, 3 ambience
    write_wav(os.path.join(OUT, "2_day_ambience.wav"), ambience("day_bed", SCATTER_DAY, (2.5, 6.0)) * 4.0)
    write_wav(os.path.join(OUT, "3_night_ambience.wav"), ambience("night_bed", SCATTER_NIGHT, (4.0, 9.0)) * 4.0)
    # 4 combo
    buf = np.zeros((n_of(5.0), 2))
    for i, st in enumerate(COMBO_STEPS):
        place(buf, pitch(take("enemy_death"), 2 ** (st / 12)) * gain("enemy_death"), i * 0.4)
    place(buf, take("enemy_death") * gain("enemy_death"), 3.6)
    write_wav(os.path.join(OUT, "4_combo.wav"), fade(buf, 0.001, 0.05) * 2.0)
    for f in sorted(os.listdir(OUT)):
        x = wavfile.read(os.path.join(OUT, f))[1].astype(float) / 32768
        print("%-22s %5.1fs peak %5.1f dB" % (f, len(x) / 44100, 20 * np.log10(np.max(np.abs(x)) + 1e-9)))


if __name__ == "__main__":
    main()
