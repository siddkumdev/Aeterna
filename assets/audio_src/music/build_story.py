"""Story (cutscene) score v3, 170 s, scored to the opening cutscene's beats (opening_stage.gd CHAPTERS + _once cues).
Chapter starts: I 0, II 34, III 62, IV 96, V 126 s. Beats (absolute s) and what the player should feel:
  0-13  island at predawn: wonder, softly         13  morning light: warmth        19-26  Maren, the prayers: cozy then awe
  26    the prayers weave the Veil: a rising shimmer
  34-44 the Dark Wood's forgotten god: uneasy     44.5 rumble   44-52 forgotten: sad     52 the lights dim: hunger
  62    the curse rises: low swell                65 "the hunger turned to spite"         68 thunder (sound effect, left alone)
  73-80 Skotos: "they love you, I remember how that felt": bitter, wistful, only the high line   77 first crack   86 second crack
  97.5  the Veil shatters: shock                  100 the beasts: terror, driving          105.5 doors   114.5 lights out: held breath
  126-135 Maren kneels: fragile, small            135 dawn returns   143 "her prayer is your light": a new hopeful theme, full   164 "Watch over them": soft
The memo ("AUDIO-2026-11-10-23-38-34") is two voices at once (a low bass line and a higher line, on a steady pulse). v1/v2 tried to
follow it as one melody and jumped between the voices; v3 transcribes both (bass -> cello, upper -> slightly flat music box).
Only the memo's pitches are used (nothing of the recording is in the output).
Run (from this folder):  python build_story.py MEMO_AUDIO OUT.wav
Needs: librosa, pretty_midi, pyloudnorm, numpy, soundfile, ffmpeg, FluidSynth + a GM soundfont (paths below).
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
END = 170.0
XF = 4.0  # s crossfade at a section boundary
G_MINOR = {7, 9, 10, 0, 2, 3, 5}  # G A Bb C D Eb F
BPM = 76.0
CELL = 60 / BPM / 2  # the memo's pulse: an eighth
MEMO_T0 = 62.5  # story second the memo's first cell sounds
OM_OFF = 60.0  # the ominous render's t=0 is story second 60 (2 s before chapter III, for the crossfade)
MN_OFF = 32.0  # the chapter II render's t=0 is story second 32
# dB trims on the soundfont renders, which come out at their own level (tuned by measurement against the day music)
LEVELS = {"om": 6.0, "mn": 6.0, "sh": 0.0, "fr": 8.0, "hp": 3.3}


def kf(points):
    """Keyframes [(t, v), ...] -> function of t (linear, held beyond the ends)."""
    ts = [p[0] for p in points]; vs = [p[1] for p in points]
    return lambda t: float(np.interp(t, ts, vs))


def render(mid, name, lowpass):
    raw = os.path.join(WORK, name + "_raw.wav")
    subprocess.run([FLUID, "-ni", "-g", "0.9", "-F", raw, "-r", str(SR), SF2, mid],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    out = os.path.join(WORK, name + "_eq.wav")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-af",
                    "lowpass=f=%d,highpass=f=40,acompressor=threshold=-24dB:ratio=2.2:attack=30:release=300,"
                    "aecho=0.8:0.6:90|170:0.22|0.14" % lowpass, out], check=True)
    y, _ = sf.read(out, always_2d=True)
    return y


def snap_scale(n):
    return min((n + d for d in range(-2, 3) if (n + d) % 12 in G_MINOR), key=lambda c: abs(c - n))


def memo_voices(memo):
    """Two-voice transcription: lowest strong note (C2-G3) and the strongest higher note (A3-G5) per eighth-note cell."""
    wav = os.path.join(WORK, "memo.wav")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", memo, "-ac", "1", "-ar", "22050", wav], check=True)
    y, sr = librosa.load(wav, sr=22050)
    H = 512
    C = np.abs(librosa.cqt(y, sr=sr, fmin=librosa.note_to_hz("C1"), n_bins=72, bins_per_octave=12, hop_length=H))
    n = int(len(y) / sr / CELL)

    def pick(col, lo, hi, thr):
        seg = col[lo - 24:hi - 24 + 1]
        k = int(np.argmax(seg))
        return lo + k if seg[k] >= thr * col.max() else None

    bass, up = [], []
    for i in range(n):
        a = int((i * CELL + 0.03) * sr / H); b = max(a + 1, int((i * CELL + 0.25) * sr / H))
        col = C[:, a:b].mean(axis=1)
        bs = pick(col, 36, 55, 0.35); us = pick(col, 57, 79, 0.4)
        if bs is not None and us is not None and (us - bs) % 12 in (0, 7) and col[us - 24] < 0.8 * col[bs - 24]:
            us = None  # that is just the bass note's own harmonic
        bass.append(snap_scale(bs) if bs else None)
        up.append(snap_scale(us) if us else None)
    return bass, up


def ominous(path, bass, up):
    """Chapters III and IV. Timeline in story seconds; the render starts at OM_OFF."""
    random.seed(3)
    A = lambda t: t - OM_OFF
    cello_v = kf([(62, 0), (63.5, 26), (65, 36), (72, 38), (73.0, 36), (73.6, 0), (80, 0), (80.5, 34), (86, 52), (92, 56),
                  (97.4, 56), (97.5, 100), (100, 92), (105, 88), (105.5, 50), (110, 46), (114.4, 44), (114.5, 0), (118, 0),
                  (118.5, 22), (123, 18), (126, 0)])
    box_v = kf([(62, 0), (66, 26), (72, 32), (74, 46), (79, 44), (82, 30), (97, 34), (100, 52), (105, 48), (110, 38),
                (114.5, 26), (118, 0)])
    pno_v = kf([(62, 0), (63, 34), (80, 34), (97, 38), (100, 50), (114.4, 46), (114.5, 40), (126, 26)])
    m = pm.PrettyMIDI(initial_tempo=BPM)
    cello = pm.Instrument(42, name="cello"); box = pm.Instrument(10, name="box"); pno = pm.Instrument(0, name="piano")
    box.pitch_bends.append(pm.PitchBend(-900, 0.0))  # about 22 cents flat: a slightly sour music box
    # low line: one cello note per run of equal notes; in the beasts (100-105.5) re-strike every cell so it drives
    i = 0
    while i < len(bass):
        if bass[i] is None:
            i += 1; continue
        j = i
        while j + 1 < len(bass) and bass[j + 1] == bass[i] and not (100 <= MEMO_T0 + i * CELL <= 105.5):
            j += 1
        t0 = MEMO_T0 + i * CELL
        v = int(cello_v(t0))
        if v > 6:
            n = bass[i]
            while n < 43: n += 12
            cello.notes.append(pm.Note(min(v, 120), n, A(t0), A(t0 + (j - i + 1) * CELL * 0.98)))
        i = j + 1
    # high line: music box, an octave up for sparkle; a few notes dropped so it breathes
    for i, u in enumerate(up):
        if u is None: continue
        t0 = MEMO_T0 + i * CELL
        v = int(box_v(t0))
        if v > 6 and random.random() < 0.8:
            box.notes.append(pm.Note(v, u + 12 if u < 70 else u, A(t0 + 0.02), A(t0 + CELL * 5)))
    # soft low piano pedal: the commonest bass note of each half bar, an octave down
    for k in range(0, len(bass), 4):
        seg = [b for b in bass[k:k + 4] if b]
        if not seg: continue
        t0 = MEMO_T0 + k * CELL
        v = int(pno_v(t0))
        if v > 6:
            n = max(set(seg), key=seg.count)
            while n > 40: n -= 12
            pno.notes.append(pm.Note(v, n, A(t0), A(t0 + 4 * CELL)))

    def hit(t, vel, notes, ln):
        for n in notes: pno.notes.append(pm.Note(vel, n, A(t), A(t + ln)))
    hit(77.0, 84, [31, 38, 44], 3.0)            # first crack (Ab over G and D: sour)
    hit(86.0, 96, [31, 38, 44], 3.5)            # second crack
    hit(97.5, 118, [28, 31, 38, 44, 50], 7.0)   # the Veil shatters
    cello.notes.append(pm.Note(104, 43, A(97.5), A(105.0)))
    hit(105.5, 62, [31, 38], 3.0)               # the doors
    pno.notes.append(pm.Note(30, 31, A(114.6), A(126.0)))   # lights out: a bare low pedal, then nothing
    pno.notes.append(pm.Note(22, 38, A(118.0), A(126.0)))
    for ins in (cello, box, pno): m.instruments.append(ins)
    m.write(path)


def chapter_two(path, bpm=80.0, bars=12):
    """Chapter II (34-62 s): the day motif turning minor and thinning: uneasy, then sad, then hungry. Render t=0 is story 32 s."""
    random.seed(11)
    e = 60 / bpm / 2
    prog = ["Gm", "Ebmaj7", "Cm", "Gm", "Gm", "Ebmaj7", "Cm", "Gm", "Cm", "Gm", "Gm", "Gm"][:bars]
    p_v = kf([(32, 44), (44, 38), (52, 28), (58, 18)])
    h_v = kf([(32, 36), (44, 30), (52, 22), (58, 14)])
    m = pm.PrettyMIDI(initial_tempo=bpm)
    piano = pm.Instrument(0); bass = pm.Instrument(32); harp = pm.Instrument(46)
    for b, ch in enumerate(prog):
        t0 = b * 8 * e
        ta = MN_OFF + t0
        d = min(1.0, 0.1 + b / (bars - 1) * 1.0)  # darkness 0.1 -> 1
        step = 2 if d < 0.55 else 4  # the tune thins out as it gets sadder
        for s in range(0, 8, step):
            n = DAY_GRID[(b * 8 + s) % len(DAY_GRID)]
            n = snap(n, ch) if n else snap(55 + random.choice([0, 3, 7]), ch)
            n = n + 12 if n < 62 else n
            n = max(60, min(n, 76))
            piano.notes.append(pm.Note(int(p_v(ta + s * e)) + random.randint(-2, 2), n, t0 + s * e + random.uniform(-0.008, 0.008),
                                       t0 + s * e + e * (3.6 + 2 * d)))
        for q in (0, 4):
            if d < 0.8 or q == 0:
                bass.notes.append(pm.Note(int(66 - 22 * d), ROOT[ch] + (0 if d > 0.5 else 12), t0 + q * e, t0 + q * e + e * 2.5))
        base = CH[ch]
        for k, pos in enumerate([3, 7] if d < 0.4 else [6]):
            harp.notes.append(pm.Note(int(h_v(ta + pos * e)), 60 + ((base[(b + k) % len(base)] - 60) % 12), t0 + pos * e,
                                      t0 + pos * e + e * 4))
    piano.notes.append(pm.Note(40, 31, 44.4 - MN_OFF, 51.0 - MN_OFF))   # the rumble (44.5): a very soft low swell
    piano.notes.append(pm.Note(34, 29, 52.0 - MN_OFF, 61.0 - MN_OFF))   # the lights dim (52): a sinking low note
    for ins in (piano, bass, harp): m.instruments.append(ins)
    m.write(path)


def shimmer(path):
    """Chapter I, 26 s: the prayers weave the Veil: a rising harp and music box line. Render t=0 is story 26 s."""
    m = pm.PrettyMIDI(initial_tempo=90)
    harp = pm.Instrument(46); box = pm.Instrument(10)
    for k, n in enumerate([70, 74, 77, 82, 86, 89, 94]):  # up the Bb major chord
        t = 0.2 + k * 0.42
        harp.notes.append(pm.Note(38 + 4 * k, n - 12 if n > 88 else n, t, t + 3.0))
        box.notes.append(pm.Note(26 + 3 * k, n, t + 0.1, t + 4.0))
    for ins in (harp, box): m.instruments.append(ins)
    m.write(path)


def fragile(path):
    """Chapter V, 126-143 s: Maren kneels; small and quiet, Bb major: a few music box and harp notes. Render t=0 is story 126 s."""
    random.seed(5)
    m = pm.PrettyMIDI(initial_tempo=66)
    box = pm.Instrument(10); harp = pm.Instrument(46)
    v = kf([(126, 30), (136, 44), (143, 40)])
    seq = [(1.0, 70), (3.2, 65), (5.1, 67), (7.3, 62), (9.4, 70), (11.2, 74), (13.5, 77), (15.6, 74)]
    for t, n in seq:
        box.notes.append(pm.Note(int(v(126 + t)), n, t, t + 3.5))
        if random.random() < 0.7:
            harp.notes.append(pm.Note(int(v(126 + t)) - 6, n - 12, t + 0.05, t + 3.0))
    for ins in (box, harp): m.instruments.append(ins)
    m.write(path)


def hope(path):
    """Chapter V, 135-170 s: a hopeful 'you are my only hope' theme (Bb major, warm, rising), not the day music.
    Render t=0 is story 135 s. Bars at 88 BPM are 2.73 s; the theme and strings enter at 143.2 s (her prayer is your light),
    swell to 153-160, and ease at 164 (Watch over them) to a held Bb."""
    random.seed(21)
    bpm = 88.0
    e = 60 / bpm / 2
    bar = 8 * e
    ROOTS = {"Bb": 46, "F": 41, "Gm": 43, "Eb": 39, "Cm": 36}
    TONES = {"Bb": (0, 4, 7), "F": (0, 4, 7), "Gm": (0, 3, 7), "Eb": (0, 4, 7), "Cm": (0, 3, 7)}
    prog = ["Gm", "Eb", "F", "Bb", "F", "Gm", "Eb", "Bb", "F", "Eb", "Cm", "F", "Bb"]  # bar 3 (Bb) lands on 143.2 s
    # melody: (bar, eighth, pitch, length in eighths); a rising fourth, a held note, a gentle fall
    mel = [(3, 0, 65, 2), (3, 2, 70, 2), (3, 4, 74, 4),
           (4, 0, 72, 2), (4, 2, 69, 2), (4, 4, 72, 4),
           (5, 0, 70, 2), (5, 2, 74, 2), (5, 4, 79, 4),
           (6, 0, 77, 3), (6, 3, 75, 1), (6, 4, 74, 4),
           (7, 0, 74, 2), (7, 2, 77, 2), (7, 4, 82, 4),
           (8, 0, 81, 2), (8, 2, 77, 2), (8, 4, 72, 4),
           (9, 0, 79, 2), (9, 2, 82, 2), (9, 4, 79, 2), (9, 6, 75, 2),
           (10, 0, 79, 3), (10, 3, 77, 1), (10, 4, 77, 4),
           (11, 0, 76, 2), (11, 2, 77, 2), (11, 4, 72, 4),
           (12, 0, 70, 8)]
    lead_v = kf([(135, 30), (143, 52), (153, 66), (163, 64), (166, 46), (170, 36)])
    str_v = kf([(135, 0), (142.5, 0), (143.5, 44), (153, 58), (163, 56), (166, 40), (170, 30)])
    harp_v = kf([(135, 34), (143, 46), (153, 56), (163, 52), (170, 30)])
    bass_v = kf([(135, 30), (143, 56), (153, 70), (163, 64), (170, 40)])
    m = pm.PrettyMIDI(initial_tempo=bpm)
    pno = pm.Instrument(0); harp = pm.Instrument(46); strs = pm.Instrument(49); bass = pm.Instrument(32); timp = pm.Instrument(47)
    for b, ch in enumerate(prog):
        tb = b * bar
        ta = 135.0 + tb
        r = ROOTS[ch]
        tones = [r + 24 + t for t in TONES[ch]]
        for s in range(8):  # rolling harp arpeggio through the chord, every eighth
            n = tones[(s * 2) % 3] if s % 2 == 0 else tones[(s + 1) % 3] + 12
            harp.notes.append(pm.Note(int(harp_v(ta + s * e)) + random.randint(-2, 2), n, tb + s * e, tb + s * e + e * 3))
        for q in (0, 4):
            bass.notes.append(pm.Note(int(bass_v(ta + q * e)), r + 12, tb + q * e, tb + q * e + e * 3.2))
        if ta >= 142.5:  # slow strings hold the chord from the entry
            for t in TONES[ch]:
                strs.notes.append(pm.Note(int(str_v(ta)), r + 24 + t, tb, tb + bar * (1.02 if b < 12 else 3.0)))
    for bar_i, s0, n, ln in mel:
        tb = bar_i * bar + s0 * e
        ta = 135.0 + tb
        pno.notes.append(pm.Note(int(lead_v(ta)), n, tb, tb + ln * e * 1.05))
        if 153.0 <= ta < 164.0:  # in the middle the melody is doubled an octave down on strings
            strs.notes.append(pm.Note(int(str_v(ta)) - 6, n - 12, tb, tb + ln * e))
    # before the entry: a few soft piano notes asking the question (dawn returns, 135-143)
    for t, n in [(0.6, 70), (2.6, 74), (4.5, 77), (6.4, 74)]:
        pno.notes.append(pm.Note(int(lead_v(135 + t)) - 6, n - 12, t, t + 2.5))
    timp.notes.append(pm.Note(58, 46, 143.2 - 135.0, 143.2 - 135.0 + 2.5))   # a soft lift at the entry
    timp.notes.append(pm.Note(52, 46, 154.1 - 135.0, 154.1 - 135.0 + 2.0))   # and as the theme rises a second time
    for ins in (pno, harp, strs, bass, timp): m.instruments.append(ins)
    m.write(path)


def lowpassed(y, hz):
    a = os.path.join(WORK, "_lp_in.wav"); b = os.path.join(WORK, "_lp_out.wav")
    sf.write(a, y, SR, subtype="FLOAT")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", a, "-af", "lowpass=f=%d" % hz, b], check=True)
    return sf.read(b, always_2d=True)[0]


def tile_to(src, n):
    reps = int(np.ceil(n / len(src))) + 1
    return np.tile(src, (reps, 1))[:n]


def env(points, t0, n):
    """dB keyframes in story seconds -> linear gain over n samples starting at story second t0."""
    t = t0 + np.arange(n) / SR
    return (10 ** (np.interp(t, [p[0] for p in points], [p[1] for p in points]) / 20.0))[:, None]


def wet(points, t0, n):
    t = t0 + np.arange(n) / SR
    return np.interp(t, [p[0] for p in points], [p[1] for p in points])[:, None]


def place(mix, clip, start_s):
    a = int(round(start_s * SR))
    if a < 0:
        clip = clip[-a:]; a = 0
    b = min(len(mix), a + len(clip))
    mix[a:b] += clip[:b - a]


def xfade(clip, fin, fout):
    n = int(XF * SR)
    if fin:
        clip[:n] *= np.sin(np.linspace(0, 1, n) * np.pi / 2)[:, None]
    if fout:
        clip[-n:] *= np.cos(np.linspace(0, 1, n) * np.pi / 2)[:, None]
    return clip


def trim(y, key):
    return y * 10 ** (LEVELS[key] / 20.0)


def main(memo, out):
    os.makedirs(WORK, exist_ok=True)
    day, sr = sf.read(DAY_WAV, always_2d=True)
    assert sr == SR, sr
    day_lp = lowpassed(day, 700)
    bass, up = memo_voices(memo)
    print("memo cells", len(bass), "bass notes", sum(1 for b in bass if b), "upper notes", sum(1 for u in up if u))
    ominous(os.path.join(WORK, "ominous.mid"), bass, up); om = trim(render(os.path.join(WORK, "ominous.mid"), "ominous", 2800), "om")
    chapter_two(os.path.join(WORK, "minor.mid")); mn = trim(render(os.path.join(WORK, "minor.mid"), "minor", 3000), "mn")
    shimmer(os.path.join(WORK, "shimmer.mid")); sh = trim(render(os.path.join(WORK, "shimmer.mid"), "shimmer", 4500), "sh")
    fragile(os.path.join(WORK, "fragile.mid")); fr = trim(render(os.path.join(WORK, "fragile.mid"), "fragile", 3200), "fr")
    mix = np.zeros((int(END * SR), 2))

    # I  0-36: the day music, opening from dark to bright as the island wakes, a lift at the prayers (26)
    n = int(36 * SR)
    w = wet([(0, 1.0), (4, 1.0), (13, 0.0)], 0, n)
    c = (tile_to(day, n) * (1 - w) + tile_to(day_lp, n) * w) * env(
        [(0, -40), (3, -15), (9, -9), (13, -4), (19, -1.5), (26, 0), (33, -1)], 0, n)
    place(mix, xfade(c, False, True), 0.0)
    place(mix, sh[:int(8 * SR)], 26.0)
    # II 32-64
    place(mix, xfade(mn[:int(32 * SR)].copy(), True, True), MN_OFF)
    # III + IV 60-128
    place(mix, xfade(om[:int(68 * SR)].copy(), True, True), OM_OFF)
    # V 124-170: kneeling (fragile notes), the dawn (135), a new hopeful theme from 143 (not the day music), easing at 164
    place(mix, xfade(fr[:int(20 * SR)].copy(), True, True), 124.0)
    hope(os.path.join(WORK, "hope.mid"))
    hp = trim(render(os.path.join(WORK, "hope.mid"), "hope", 4200), "hp")[:int((END - 135.0 + 1) * SR)].copy()
    hp[:int(2.0 * SR)] *= np.linspace(0, 1, int(2.0 * SR))[:, None]
    place(mix, hp, 135.0)  # the hopeful theme from the dawn (135) on
    fade_n = int(4.0 * SR)
    mix[-fade_n:] *= np.cos(np.linspace(0, 1, fade_n) * np.pi / 2)[:, None] ** 2
    sf.write(out, np.clip(mix, -1, 1), SR, subtype="PCM_16")
    print("wrote", out, round(len(mix) / SR, 1), "s")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
