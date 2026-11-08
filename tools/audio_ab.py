"""Listening test to find out what the user dislikes in the sounds (Claude cannot listen; the user compares and says
which one is better). Writes numbered files to _work/audio/ab/ (git-ignored):

  1 day bed: which part is the "alarm beep"?   1a now   1b birds removed   1c wind chime removed   1d new softer birds, no chime
  2 one attack, one thing changed at a time:   2a now   2b richer body   2c + small irregularities   2d + a real room   2e all three
  3 place_thunk, the same steps:               3a now ... 3e all three
  4 monotony, 8 hits in a row:                 4a now (the 4 takes)   4b every hit built fresh

Each file in a test is loudness-matched, so a louder one does not win just by being louder.
    python tools/audio_ab.py
"""
import os
import sys

import numpy as np
from scipy.io import wavfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
sys.path.insert(0, os.path.join(ROOT, "assets", "generators"))
from audio_synth import *  # noqa: F401,F403,E402
import make_audio as M  # noqa: E402

OUT = os.path.join(ROOT, "_work", "audio", "ab")
EXP = os.path.join(ROOT, "assets", "export", "audio")


def load(name):
    sr, x = wavfile.read(os.path.join(EXP, name))
    return x.astype(float) / 32768.0


def save(fn, x, rms=-22.0):
    x = remove_dc(np.asarray(x, dtype=float))
    if x.shape[0] < n_of(6.0):
        x = fade(x, 0.001, 0.02)  # removing DC moves the ends off zero: fade again or they click
    else:
        x = fade(x, 0.3, 0.5)  # a bed excerpt (not looped here) fades in and out
    x = normalise(x, rms_db=rms, max_peak_db=-1.5)
    write_wav(os.path.join(OUT, fn), x)
    print("wrote", fn)


# ------------------------------------------------------------------ 1 day bed
def day_bed(birds="old", chime=True, seed=1):
    r = rng(seed)
    d = 12.0
    wind = lp(noise(d, r, "pink"), 600) * M._slow(r, d, 0.25, 0.3, 1.0)
    leaves = lp(bp(noise(d, r), 1800, 5200), 6000) * 0.09 * M._slow(r, d, 0.5, 0.0, 1.0) ** 2
    layers = [stereo_wide(wind * 0.8 + leaves, 0.6)]
    if chime:
        for at_c in (2.2, 8.1):
            tones = [note(n) for n in ("D6", "E6", "G6", "A6", "B6")]
            ring, t0 = [], 0.0
            for k in range(int(r.integers(2, 4))):
                ring.append((glass(tones[int(r.integers(0, len(tones)))], 1.6, 1.6), t0, 1.0))
                t0 += float(r.uniform(0.18, 0.4))
            layers.append((pan(mix(*ring) * 0.035, float(r.uniform(-0.6, 0.6))), at_c, 1.0))
    at = 0.8
    while birds != "none" and at < d - 1.6:
        if birds == "old":  # the current birds: pure sine sweeps, identical pips 0.11 s apart (the suspected "beep")
            f0 = float(r.uniform(2400, 4200))
            notes, t0 = [], 0.0
            for k in range(int(r.integers(2, 5))):
                notes.append((chirp(f0 * float(r.uniform(0.9, 1.15)), f0 * float(r.uniform(1.15, 1.5)), 0.07, 0.01, 40), t0, 1.0))
                t0 += 0.11
            bird = lp(mix(*notes), 6000) * 0.05
        else:  # softer birds: warbling (FM), breathy, uneven phrasing, further away (darker, quieter, in the room)
            notes, t0 = [], 0.0
            base = float(r.uniform(1800, 3000))
            for k in range(int(r.integers(2, 6))):
                dur = float(r.uniform(0.05, 0.16))
                f_a = base * float(r.uniform(0.85, 1.2))
                f_b = f_a * float(r.uniform(0.8, 1.35))
                c = chirp(f_a, f_b, dur, vib=float(r.uniform(0.02, 0.06)), vib_rate=float(r.uniform(25, 60)), shape=float(r.uniform(0.6, 1.8)))
                c = c * (0.7 + 0.3 * float(r.random())) + 0.15 * bp(noise(dur, r), f_a * 0.8, f_a * 1.3) * np.sin(np.pi * t_of(dur) / dur)
                notes.append((flutter(c, r, 0.3, 40), t0, 1.0))
                t0 += dur + float(r.uniform(0.03, 0.14))
            bird = lp(mix(*notes), 4200) * 0.025
            bird = room(bird, 0.5, 0.45, seed=int(r.integers(1, 99)))
        p = float(r.uniform(-0.8, 0.8))
        layers.append(((pan(bird, p) if bird.ndim == 1 else bird), at, 1.0))
        at += float(r.uniform(2.5, 5.5))
    return mix(*layers, seconds=d)


# ------------------------------------------------------------------ 2 an attack (the fireball hitting)
def fireball_hit(r, body="old", texture=False, space=False):
    d = 0.6
    if body == "old":
        b = thud(0.38, 115, 46, 0.12, r, 0.4)
        puff = pk(lp(noise(0.35, r), 2600) * exp_env(0.35, 0.1, 0.003))
        sparks = crackle(0.3, r, 80, 3500) * exp_env(0.3, 0.12, 0.001)
        x = mix((b, 0, 0.9), (puff, 0, 0.45), (sparks, 0.02, 0.35), seconds=d)
    else:
        # a soft "whumpf": low air pushed out of a body (resonated noise, not a sine), fire licking out, embers falling
        push = resonate(noise(d, r, "pink"), [72, 118, 190, 260], q=4.0, gains=[1.0, 0.7, 0.45, 0.25]) * exp_env(d, 0.09, 0.004)
        sub = thud(0.3, 90, 42, 0.1, r, 0.0) * 0.5
        lick = (fire_texture(d, r, 1.2) if texture else lp(noise(d, r), 2400)) * exp_env(d, 0.16, 0.01)
        embers = np.zeros(n_of(d))
        for _ in range(int(r.integers(5, 10))):
            e = modal(float(r.uniform(1800, 4200)), 0.05, "clay", r, hardness=0.8, nmodes=3) * float(r.uniform(0.1, 0.5))
            a = int(r.integers(n_of(0.03), n_of(0.45)))
            embers[a:a + len(e)] += e[: len(embers) - a]
        x = mix((pk(push), 0, 1.0), (sub, 0, 0.6), (pk(lick), 0.01, 0.55), (pk(embers), 0, 0.22), seconds=d)
    if texture:
        x = jitter_pitch(flutter(x, r, 0.18, 22), r, 15, 5)
    x = fade(trim_silence(x, -55, 0.02), 0.001, 0.02)
    return room(x, 0.3, 0.25) if space else x


# ------------------------------------------------------------------ 3 a tower set down
def place_thunk(r, body="old", texture=False, space=False):
    if body == "old":
        b = thud(0.35, 150, 58, 0.12, r, 0.5)
        stone = pk(bp(noise(0.04, r), 1400, 3600) * exp_env(0.04, 0.008, 0.0003))
        sub = osc("sine", 52, 0.25) * exp_env(0.25, 0.1, 0.004)
        x = mix((b, 0, 1.0), (stone, 0, 0.3), (sub, 0, 0.5))
    else:
        # a stone-based wooden tower on a wooden table: the table rings (wood modes), the base knocks (stone), a sub
        table = modal(float(r.uniform(105, 125)), 0.45, "wood", r, hardness=0.35)
        base = modal(float(r.uniform(420, 520)), 0.2, "stone", r, hardness=0.55)
        grit = lp(impulses(0.08, r, 160, 0.002), 3500) * exp_env(0.08, 0.03)
        sub = thud(0.3, 85, 45, 0.11, r, 0.0)
        x = mix((pk(table), 0, 0.9), (pk(base), 0.002, 0.55), (pk(grit), 0.004, 0.25), (sub, 0, 0.5))
    if texture:
        x = jitter_pitch(flutter(x, r, 0.12, 25), r, 10, 6)
    x = fade(trim_silence(x, -55, 0.02), 0.001, 0.02)
    return room(x, 0.3, 0.25) if space else x


def volley(make, n=8, gap=0.42, fresh=True):
    out = []
    files = sorted(f for f in os.listdir(EXP) if f.startswith("fireball_hit_"))
    for i in range(n):
        if fresh:
            x = make(rng(1000 + i))
        else:
            x = load(files[i % len(files)])
            k = 1.0 + float(rng(500 + i).uniform(-0.07, 0.07))  # the game's own random pitch change
            idx = np.linspace(0, len(x) - 1, int(len(x) / k))
            x = np.interp(idx, np.arange(len(x)), x)
        out.append((x, i * gap, 1.0))
    return mix(*out)


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        os.remove(os.path.join(OUT, f))
    save("1a_day_now.wav", day_bed("old", True), -30)
    save("1b_day_no_birds.wav", day_bed("none", True), -30)
    save("1c_day_no_chime.wav", day_bed("old", False), -30)
    save("1d_day_soft_birds_no_chime.wav", day_bed("new", False), -30)
    for tag, fn in (("2", fireball_hit), ("3", place_thunk)):
        nm = "fireball_hit" if tag == "2" else "place_thunk"
        save("%sa_%s_now.wav" % (tag, nm), fn(rng(7)))
        save("%sb_%s_richer_body.wav" % (tag, nm), fn(rng(7), "new"))
        save("%sc_%s_body_irregular.wav" % (tag, nm), fn(rng(7), "new", True))
        save("%sd_%s_body_room.wav" % (tag, nm), fn(rng(7), "new", False, True))
        save("%se_%s_all.wav" % (tag, nm), fn(rng(7), "new", True, True))
    save("4a_volley_now.wav", volley(None, fresh=False))
    save("4b_volley_fresh_each_hit.wav", volley(lambda r: fireball_hit(r, "new", True, True)))


if __name__ == "__main__":
    main()
