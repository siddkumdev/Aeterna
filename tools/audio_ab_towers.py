"""Blind sets and the tour for the real-recording tower and spell sounds (restart round r16, Siddharth 2026-11-15).
Claude cannot listen: the user picks.

    python tools/audio_ab_towers.py

Writes (git-ignored, _work/audio_ab/):
  <id>/1.wav 2.wav KEY.txt   for wizard_hit, airship_shot, airship_hit: two candidates, take 1, level-matched at the install level,
                             shuffled order (the installed game sound is candidate A)
  towers_tour.wav + .txt     every tower shot then its hit three times, then the Boulder fall and its hit, 0.5 s apart, 1.5 s
                             between groups; the installed game files, mono, in the order listed in the .txt
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
M = I.M
OUT = os.path.join(ROOT, "_work", "audio_ab")
GAME = os.path.join(ROOT, "godot", "assets", "audio")

SETS = {
    "wizard_hit": (lambda v: (lambda r: I._mono(M.wizard_hit_real(v)(r))), -20.5),
    "airship_shot": (lambda v: (lambda r: I.room(M.airship_shot_real(v)(r))), -18.3),
    "airship_hit": (lambda v: (lambda r: I.room(M.airship_hit_real(v)(r))), -20.5),
}
WHAT = {"wizard_hit": {"a": "fire only (real fire whoosh + campfire), same family as wizard_launch",
                       "b": "the same fire plus a soft low real cannon-body thump under it (more weight)"},
        "airship_shot": {"a": "real distant cannon + its tail + a low war-drum body + a soft air puff",
                         "b": "real distant cannon with its long tail, no drum, no puff"},
        "airship_hit": {"a": "war-drum thump + stone + dust puff + cannon tail (heavy, earthy)",
                        "b": "real cannon shot as the thump + its tail + dust + a little stone (rounder, more cannon)"}}


def blind(name):
    mk, rms = SETS[name]
    d = os.path.join(OUT, name)
    os.makedirs(d, exist_ok=True)
    cands = {v: I.render_take(name, mk(v), 0, rms) for v in "ab"}
    order = list("ab")
    random.Random(20261115 + len(name)).shuffle(order)
    key = []
    for i, v in enumerate(order, 1):
        sf.write(os.path.join(d, "%d.wav" % i), cands[v], 44100, subtype="PCM_16")
        key.append("%d = candidate %s (%s)%s" % (i, v.upper(), WHAT[name][v], "  <- INSTALLED in the game" if v == "a" else ""))
    open(os.path.join(d, "KEY.txt"), "w", encoding="utf-8").write("\n".join(key) + "\n")
    print(name, "->", d, "|", "; ".join(k.split(" (")[0] for k in key))


def game(fn):
    x, sr = sf.read(os.path.join(GAME, fn))
    return x if x.ndim == 1 else x.mean(axis=1)


def tour():
    plan = [("Longbow Tower", "crossbow_shot_1.wav", ["crossbow_pierce_%d.wav" % i for i in (1, 2, 3)], "bolt then 3 pierce ticks"),
            ("Guard Tower", "guard_clop_1.wav", ["guard_hit_%d.wav" % i for i in (1, 2, 3)], "a Guard steps out, then 3 hits"),
            ("Airship", "airship_shot_1.wav", ["airship_hit_%d.wav" % i for i in (1, 2, 3)], "cannon shot then 3 landings"),
            ("Wizard Tower", "wizard_launch_1.wav", ["wizard_hit_%d.wav" % i for i in (1, 2, 3)], "fireball launch then 3 landings"),
            ("Boulder spell", "boulder_fall_1.wav", ["boulder_hit_1.wav"], "fall then landing")]
    sr = 44100
    parts, lines, t = [], [], 0.0
    for who, a, hits, what in plan:
        t0 = t
        for fn in [a] + hits:
            x = game(fn)
            parts.append((x, t))
            lines.append("%6.2f s  %-14s %s" % (t, who, fn))
            t += len(x) / sr + 0.5
        t += 1.0  # 0.5 s plus 1.0 s = 1.5 s between groups
    y = S.mix(*[(x, at, 1.0) for x, at in parts])
    y = S.normalise(y, peak_db=-2.0) if np.max(np.abs(y)) > 0.8 else y
    sf.write(os.path.join(OUT, "towers_tour.wav"), y, sr, subtype="PCM_16")
    open(os.path.join(OUT, "towers_tour.txt"), "w", encoding="utf-8").write(
        "Order (shot first, then the hits; 0.5 s apart, 1.5 s between towers). Game files, mono, same levels as in the game.\n" + "\n".join(lines) + "\n")
    print("tour ->", os.path.join(OUT, "towers_tour.wav"), "%.1f s" % (len(y) / sr))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for n in SETS:
        blind(n)
    tour()
