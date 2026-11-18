"""Story (cutscene) score, 170 s, timed to the five opening chapters (opening_stage.gd CHAPTERS: 34/28/34/30/44 s).
  I   The Island      0-34   the day music as it is (happy)
  II  The Forgotten  34-62   the day motif turning minor (new render, same instruments as the day track)
  III+IV  Curse/Dark 62-126  the voice memo's melody on cello, with a slightly flat music box and soft low piano
  V   Your Turn     126-170  the day music again
Run (from this folder):  python build_story.py MEMO_AUDIO OUT.wav
Needs: librosa, pretty_midi, pyloudnorm, numpy, soundfile, ffmpeg, FluidSynth + a GM soundfont (paths below).
The memo is a private voice memo; only its pitches are used (nothing of the recording is in the output).
"""
import os, random, subprocess, sys
import numpy as np
import librosa, soundfile as sf, pyloudnorm as pln
import pretty_midi as pm

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
from build import grid as DAY_GRID, snap, CH, ROOT  # the day track's melody grid and chord tables

WORK = os.environ.get("STORY_WORK", os.path.join(REPO, "_work", "story_music"))
FLUID = os.environ.get("FLUIDSYNTH", os.path.join(REPO, "_work", "music", "tools",
        "fluidsynth-v2.6.2-win10-x64-cpp11", "bin", "fluidsynth.exe"))
SF2 = os.environ.get("SOUNDFONT", os.path.join(REPO, "_work", "music", "sf", "GeneralUser-GS.sf2"))
DAY_WAV = os.path.join(REPO, "godot", "assets", "audio", "music", "day_music.wav")
SR = 44100
BOUNDS = [0.0, 34.0, 62.0, 126.0, 170.0]  # four musical sections: I | II | III+IV | V (starts, then the end)
XF = 4.0  # s crossfade centred on each chapter boundary
G_MINOR = {7, 9, 10, 0, 2, 3, 5}  # G A Bb C D Eb F


def render(mid, name, lowpass, lufs):
    raw = os.path.join(WORK, name + "_raw.wav")
    subprocess.run([FLUID, "-ni", "-g", "0.9", "-F", raw, "-r", str(SR), SF2, mid],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    out = os.path.join(WORK, name + "_eq.wav")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-af",
                    "lowpass=f=%d,highpass=f=40,acompressor=threshold=-24dB:ratio=2.2:attack=30:release=300,"
                    "aecho=0.8:0.6:90|170:0.22|0.14" % lowpass, out], check=True)
    y, sr = sf.read(out, always_2d=True)
    m = pln.Meter(sr)
    y = pln.normalize.loudness(y, m.integrated_loudness(y), lufs)
    return np.clip(y, -1, 1), sr


def memo_grid(memo, bpm=76.0):
    wav = os.path.join(WORK, "memo.wav")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", memo, "-ac", "1", "-ar", "22050", wav], check=True)
    y, sr = librosa.load(wav, sr=22050)
    f0, _, _ = librosa.pyin(y, fmin=librosa.note_to_hz("C2"), fmax=librosa.note_to_hz("C6"), sr=sr, hop_length=256)
    t = librosa.times_like(f0, sr=sr, hop_length=256)
    midi = np.where(np.isnan(f0), np.nan, librosa.hz_to_midi(f0))
    step = 60 / bpm / 2
    cells = []
    for i in range(int(len(y) / sr / step)):
        m = midi[(t >= i * step + 0.05) & (t < (i + 1) * step)]
        m = m[~np.isnan(m)]
        cells.append(int(round(np.median(m))) if len(m) >= 3 else None)
    return cells


def snap_scale(n):
    return min((n + d for d in range(-2, 3) if (n + d) % 12 in G_MINOR), key=lambda c: abs(c - n))


def ominous(path, cells, bpm=76.0, bars_total=None):
    """Cello carries the memo's tune; music box and piano under it. Dynamics follow the story: III soft, IV swelling."""
    random.seed(3)
    e = 60 / bpm / 2
    notes = []  # (slot, midi) merged runs
    last = None
    for i, c in enumerate(cells):
        if c is None:
            last = None
            continue
        c = snap_scale(c)
        while c < 43: c += 12  # cello floor: G2
        while c > 67: c -= 12
        if notes and last == c and notes[-1][0] + notes[-1][2] == i:
            notes[-1][2] += 1
        else:
            notes.append([i, c, 1])
        last = c
    m = pm.PrettyMIDI(initial_tempo=bpm)
    cello = pm.Instrument(42, name="cello"); box = pm.Instrument(10, name="box"); pno = pm.Instrument(0, name="piano")
    box.pitch_bends.append(pm.PitchBend(-900, 0.0))  # about 22 cents flat: a slightly sour music box
    total = max(len(cells), 1) * e  # the tune's length: dynamics follow it
    bars = int(max(total, 72.0) / (8 * e)) + 1  # the section needs 68 s: piano and box carry on after the tune ends
    for i, c, ln in notes:
        t0 = i * e
        prog = t0 / total
        vel = int(46 + 30 * min(1.0, max(0.0, (prog - 0.35) / 0.4)))  # swells into chapter IV
        cello.notes.append(pm.Note(vel, c, t0, t0 + max(ln, 2) * e * 0.98))
        if random.random() < 0.28 and ln >= 2:
            box.notes.append(pm.Note(int(34 + 12 * prog), c + 24, t0 + e * 0.5, t0 + e * 5))
    cs = ["Gm", "Gm", "Ebmaj7", "Cm", "Gm", "Ebmaj7", "Cm", "Gm"]
    for b in range(bars):
        t0 = b * 8 * e
        ch = cs[b % len(cs)]
        r = ROOT[ch]
        v = int(34 + 16 * min(1, b / max(bars - 1, 1) * 1.4))
        pno.notes.append(pm.Note(v, r - 12 + 12, t0, t0 + 8 * e))  # low root, held
        pno.notes.append(pm.Note(v - 8, r + 7, t0 + 2 * e, t0 + 8 * e))  # a fifth above, entering late
    for ins in (cello, box, pno): m.instruments.append(ins)
    m.write(path)
    return bars * 8 * e


def minor_motif(path, bpm=92.0, bars=14):
    """The day motif (the day track's melody grid) over minor chords, dark rising: bridge for chapter II."""
    random.seed(11)
    e = 60 / bpm / 2
    prog = ["Gm", "Ebmaj7", "Cm", "Gm", "Gm", "Ebmaj7", "Cm", "Gm", "Cm", "Gm", "Ebmaj7", "Gm", "Gm", "Gm"][:bars]
    m = pm.PrettyMIDI(initial_tempo=bpm)
    piano = pm.Instrument(0); bass = pm.Instrument(32); harp = pm.Instrument(46)
    for b, ch in enumerate(prog):
        t0 = b * 8 * e
        d = min(1.0, 0.15 + b / (bars - 1) * 0.9)  # darkness 0.15 -> 1
        for s in range(0, 8, 2):
            n = DAY_GRID[(b * 8 + s) % len(DAY_GRID)]
            n = snap(n, ch) if n else snap(55 + random.choice([0, 3, 7]), ch)
            n = n + 12 if n < 62 else n
            n = max(60, min(n, 76))
            piano.notes.append(pm.Note(int(46 + 5 * (s % 4 == 0) - 10 * d + random.randint(-3, 3)), n,
                                       t0 + s * e + random.uniform(-0.008, 0.008), t0 + s * e + e * (3.6 + d)))
        for q in (0, 4):
            bass.notes.append(pm.Note(int(70 - 12 * d), ROOT[ch] + (0 if d > 0.5 else 12), t0 + q * e, t0 + q * e + e * 1.5))
        base = CH[ch]
        for k, pos in enumerate([3, 7] if d < 0.4 else [6]):
            harp.notes.append(pm.Note(int(40 - 10 * d), 60 + ((base[(b + k) % len(base)] - 60) % 12), t0 + pos * e, t0 + pos * e + e * 4))
    for ins in (piano, bass, harp): m.instruments.append(ins)
    m.write(path)
    return bars * 8 * e


def fade(y, a, b, kind):
    n = int(XF * SR) if b is None else b - a
    n = min(n, len(y) - a)
    ramp = np.linspace(0, 1, n)
    g = np.sin(ramp * np.pi / 2) if kind == "in" else np.cos(ramp * np.pi / 2)  # equal-power
    y[a:a + n] *= g[:, None]
    if kind == "out":
        y[a + n:] = 0


def place(mix, clip, start_s):
    a = int(start_s * SR)
    b = min(len(mix), a + len(clip))
    mix[a:b] += clip[:b - a]


def main(memo, out):
    os.makedirs(WORK, exist_ok=True)
    day, sr = sf.read(DAY_WAV, always_2d=True)
    assert sr == SR, sr
    target = pln.Meter(SR).integrated_loudness(day)
    cells = memo_grid(memo)
    print("memo cells", len(cells), "notes", sum(1 for c in cells if c))
    om_len = ominous(os.path.join(WORK, "ominous.mid"), cells)
    om, _ = render(os.path.join(WORK, "ominous.mid"), "ominous", 2800, target - 1.0)
    mm_len = minor_motif(os.path.join(WORK, "minor.mid"))
    mn, _ = render(os.path.join(WORK, "minor.mid"), "minor", 3000, target - 0.5)
    print("day LUFS %.1f  ominous %.1fs  minor %.1fs" % (target, om_len, mm_len))
    total = int((BOUNDS[-1] + 1) * SR)
    mix = np.zeros((total, 2))
    half = XF / 2

    def seg(src, k, loop=False):
        start = BOUNDS[k] - (half if k > 0 else 0)
        end = BOUNDS[k + 1] + (half if k < 3 else 0)
        n = int((end - start) * SR)
        if loop:  # the day loop is seamless, so wrap it
            reps = int(np.ceil(n / len(src))) + 1
            src = np.tile(src, (reps, 1))
        clip = src[:n].copy()
        if len(clip) < n:
            clip = np.vstack([clip, np.zeros((n - len(clip), 2))])
        if k > 0: fade(clip, 0, int(XF * SR), "in")
        if k < 3: fade(clip, len(clip) - int(XF * SR), len(clip), "out")
        place(mix, clip, start)

    seg(day, 0, True)      # I
    seg(mn, 1)             # II
    seg(om, 2)             # III + IV: one continuous ominous passage, 62 s to 126 s
    seg(day, 3, True)      # V
    mix = mix[:int(BOUNDS[-1] * SR)]
    fade(mix, len(mix) - int(3 * SR), len(mix), "out")
    sf.write(out, np.clip(mix, -1, 1), SR, subtype="PCM_16")
    print("wrote", out, round(len(mix) / SR, 1), "s")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
