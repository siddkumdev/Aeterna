"""In-game night music v4 (2026-11-18, Siddharth: exciting, semi-action, keep the main theme of Night but more upbeat).
Same theme as the calm night bed (build.night: G D Bb Ab G D G F Eb D, G minor with the sour flat 2nd), now at 120 BPM with a driving
pulse: plucked-string ostinato, plucked bass, soft taiko on 1 and 3; the theme on a music box; in the second half the theme doubles
on piano and tremolo strings swell underneath. 16 bars = 32 s, folded so it loops without a seam.
Run (from this folder):  python build_night_action.py OUT.wav [LUFS]
"""
import os, random, subprocess, sys
import numpy as np
import soundfile as sf, pyloudnorm as pln
import pretty_midi as pm

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
WORK = os.environ.get("STORY_WORK", os.path.join(REPO, "_work", "story_music"))
FLUID = os.path.join(REPO, "_work", "music", "tools", "fluidsynth-v2.6.2-win10-x64-cpp11", "bin", "fluidsynth.exe")
SF2 = os.path.join(REPO, "_work", "music", "sf", "GeneralUser-GS.sf2")
SR = 44100
BPM = 120.0
E = 60 / BPM / 2  # an eighth: 0.25 s
BARS = 16
LEN = BARS * 8 * E  # 32 s
ROOT = {"Gm": 43, "Eb": 39, "Cm": 36, "D": 38}
TONES = {"Gm": (0, 3, 7), "Eb": (0, 4, 7), "Cm": (0, 3, 7), "D": (0, 4, 7)}
PROG = ["Gm", "Gm", "Eb", "Eb", "Cm", "Cm", "D", "D", "Gm", "Eb", "Gm", "Eb", "Cm", "Cm", "D", "D"]
THEME = [(67, 0, 2), (62, 2, 2), (58, 4, 3), (68, 7, 3), (67, 10, 2), (62, 12, 2), (55, 14, 3), (65, 17, 2), (63, 19, 3), (62, 22, 3)]


def build(path):
    random.seed(4)
    m = pm.PrettyMIDI(initial_tempo=BPM)
    box = pm.Instrument(10); pizz = pm.Instrument(45); bass = pm.Instrument(32); taiko = pm.Instrument(116)
    pno = pm.Instrument(0); strs = pm.Instrument(44)
    box.pitch_bends.append(pm.PitchBend(-700, 0.0))  # a hair flat, like the calm night bed
    for ph in range(4):  # four 4-bar phrases of the theme
        t0 = ph * 4 * 8 * E
        for p, s, ln in THEME:
            box.notes.append(pm.Note(66 if ph < 2 else 74, p + 12, t0 + s * E, t0 + (s + ln) * E * 1.15))
            if ph >= 2:  # second half: the piano doubles the theme
                pno.notes.append(pm.Note(72, p, t0 + s * E, t0 + (s + ln) * E * 1.1))
    for b, ch in enumerate(PROG):
        tb = b * 8 * E
        r = ROOT[ch]
        hi = b >= 8
        pat = [0, 12, 7, 12, 0, 12, 7, 12]
        for s in range(8):  # plucked ostinato on every eighth
            vel = int((58 if not hi else 68) + (6 if s % 4 == 0 else 0) + random.randint(-3, 3))
            pizz.notes.append(pm.Note(vel, r + 24 + pat[s], tb + s * E, tb + s * E + E * 0.8))
        for s in (0, 3, 4, 7 if hi else 6):  # plucked bass pushes
            bass.notes.append(pm.Note(int(76 + random.randint(-3, 3)), r + 12 if s in (0, 4) else r + 19, tb + s * E, tb + s * E + E * 1.6))
        for s in (0, 4):  # soft taiko on 1 and 3
            taiko.notes.append(pm.Note(50 if not hi else 64, r + 12, tb + s * E, tb + s * E + E * 3))
        if b % 8 == 7:  # a small fill into the next section
            for k, s in enumerate((5, 6, 7)):
                taiko.notes.append(pm.Note(54 + 8 * k, r + 12 + 4 * (k % 2), tb + s * E, tb + s * E + E))
        if hi:  # tremolo strings hold the chord for tension and lift
            for tone in TONES[ch]:
                strs.notes.append(pm.Note(46, r + 24 + tone, tb, tb + 8 * E))
    for ins in (box, pizz, bass, taiko, pno, strs):
        m.instruments.append(ins)
    m.write(path)


def main(out, lufs=-31.0):
    os.makedirs(WORK, exist_ok=True)
    mid = os.path.join(WORK, "night_action.mid"); raw = os.path.join(WORK, "night_action_raw.wav"); eq = os.path.join(WORK, "night_action_eq.wav")
    build(mid)
    subprocess.run([FLUID, "-ni", "-g", "0.9", "-F", raw, "-r", str(SR), SF2, mid], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-af",
                    "lowpass=f=4200,highpass=f=45,acompressor=threshold=-22dB:ratio=2.6:attack=25:release=250,aecho=0.8:0.6:70:0.18", eq], check=True)
    y, _ = sf.read(eq, always_2d=True)
    n = int(round(LEN * SR))
    body = y[:n].copy()
    tail = y[n:n + int(3 * SR)]
    body[:len(tail)] += tail  # fold the ring-out onto the start: the loop has no seam
    body = pln.normalize.loudness(body, pln.Meter(SR).integrated_loudness(body), lufs)
    sf.write(out, np.clip(body, -1, 1), SR, subtype="PCM_16")
    print("wrote", out, round(len(body) / SR, 1), "s, peak %.2f" % np.abs(body).max())


if __name__ == "__main__":
    main(sys.argv[1], float(sys.argv[2]) if len(sys.argv) > 2 else -31.0)
