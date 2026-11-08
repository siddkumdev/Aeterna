"""Cut licensed recordings into a kit of short single-hit "grains" that the sound recipes layer under code-made attacks.

    python tools/audio_grains.py            # rebuild assets/audio_src/grains/ from the sources listed below

Sources (raw files stay outside git: Freesound downloads in ~/Downloads or _work/freesound/files, the Sonniss GDC 2026
bundle in ~/Downloads/Sonniss.com-GDC2026-GameAudioBundle). Only the trimmed grains go into the repo (private, team only,
which the Sonniss licence allows; never publish them as sound files). Every grain keeps its source, author and licence in
assets/audio_src/grains/grains.json, and docs/AUDIO_CREDITS.md is written from the same list.

How a grain is cut: the file is read with ffmpeg (any format) as 44.1 kHz mono, an energy envelope finds each onset, and
each event is cut from just before its onset to where it has decayed 40 dB, a maximum length or the next onset, then
faded and peak-normalised. Quiet events, and events still ringing when the next hit starts, are skipped. A kit whose
raw sources are not on this machine is left untouched. Rebuilt kits are re-screened (tools/audio_grain_screen.py).
"""
import glob
import json
import os
import subprocess
import sys

import numpy as np
from scipy import signal
from scipy.io import wavfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "audio_src", "grains")
DL = os.path.join(os.path.expanduser("~"), "Downloads")
SONNISS = os.path.join(DL, "Sonniss.com-GDC2026-GameAudioBundle")
SR = 44100
FFMPEG = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WinGet", "Links", "ffmpeg.exe")
if not os.path.exists(FFMPEG):
    FFMPEG = "ffmpeg"

SONNISS_LIC = "Sonniss GDC Game Audio Bundle licence v2.0 (royalty-free, no attribution; not to be redistributed as sound effects)"
CC0 = "CC0 1.0"
BY3 = "CC BY 3.0"
BY4 = "CC BY 4.0"
LICENCE_URL = {CC0: "https://creativecommons.org/publicdomain/zero/1.0/", BY3: "https://creativecommons.org/licenses/by/3.0/",
               BY4: "https://creativecommons.org/licenses/by/4.0/"}

# kit name -> list of (path glob, author, licence, source url, max grain seconds, max grains from this file)
FS = "https://freesound.org/s/%s/"
KITS = {
    "wood_knock": [
        (DL + "/104002__*", "RutgerMuller", CC0, FS % 104002, 0.5, 8),
        (DL + "/268822__*", "kwahmah_02", BY3, FS % 268822, 0.3, 2),
        (DL + "/329924__*", "Uzbazur", BY4, FS % 329924, 0.4, 6),
        (SONNISS + "/Epic Stock Media - Board Game*/GAMEBoard_Event Board Reset*", "Epic Stock Media (Sonniss)", SONNISS_LIC, "https://sonniss.com/gameaudiogdc", 0.4, 10),
    ],
    "chess": [
        (DL + "/646781__*", "pbimal", CC0, FS % 646781, 0.35, 4),
        (DL + "/546121__*", "el_boss", CC0, FS % 546121, 0.5, 2),
        (DL + "/755250__*", "IENBA", CC0, FS % 755250, 0.35, 14),
        (DL + "/733927__*", "JJTaynos", CC0, FS % 733927, 0.3, 14),
        (SONNISS + "/Epic Stock Media - Board Game*/GAMEBoard_Game Play Piece*", "Epic Stock Media (Sonniss)", SONNISS_LIC, "https://sonniss.com/gameaudiogdc", 0.4, 8),
    ],
    "blocks": [
        (os.path.join(ROOT, "_work", "freesound", "files", "245922.wav"), "sophiehall3535", CC0, FS % 245922, 0.6, 6),
        (DL + "/271379__*", "OverlookHotelRecords", CC0, FS % 271379, 0.4, 10),
    ],
    "stone": [
        (DL + "/530354__*", "danielpodlovics", CC0, FS % 530354, 0.4, 3),
        (DL + "/572753__*", "F.M.Audio", BY4, FS % 572753, 0.5, 3),
        (DL + "/574450__*", "F.M.Audio", BY4, FS % 574450, 0.5, 3),
        (DL + "/133783__*", "Julien Nicolas", BY4, FS % 133783, 0.8, 4),
    ],
    "door": [
        (DL + "/757195__*", "HenKonen", CC0, FS % 757195, 0.6, 3),
        (DL + "/397918__*", "nozefian", CC0, FS % 397918, 0.8, 3),
        (DL + "/216879__*", "CastIronCarousel", CC0, FS % 216879, 1.0, 2),
        (DL + "/125958__*", "Ryding", CC0, FS % 125958, 1.0, 3),
    ],
    "whoosh": [
        (DL + "/420668__*", "SypherZent", CC0, FS % 420668, 0.4, 2),
        (DL + "/427979__*", "Kinoton", CC0, FS % 427979, 0.6, 13),
        (DL + "/848728__*", "mikiko850", BY4, FS % 848728, 1.2, 8),
        (DL + "/802449__*", "Sadiquecat", CC0, FS % 802449, 0.8, 4),
    ],
    "squish": [
        (DL + "/167074__*", "DrMinky", BY4, FS % 167074, 0.7, 2),
        (SONNISS + "/Epic Stock Media - Tower Defense Game/WOODImpt_*", "Epic Stock Media (Sonniss)", SONNISS_LIC, "https://sonniss.com/gameaudiogdc", 0.6, 6),
    ],
    "dirt": [
        (DL + "/260130__*", "SpliceSound", CC0, FS % 260130, 0.6, 10),
        (DL + "/707538__*", "LiezelDippenaar", CC0, FS % 707538, 0.6, 8),
    ],
    "glass": [
        (DL + "/221528__*", "unfa", CC0, FS % 221528, 1.2, 2),
        (DL + "/260433__*", "RoganMcDougald", BY3, FS % 260433, 0.7, 2),
    ],
    "hammer": [
        (DL + "/655916__*", "YevashenPillay", BY4, FS % 655916, 0.3, 12),
    ],
    "steps": [
        (DL + "/620334__*", "marb7e", BY4, FS % 620334, 0.3, 6),
    ],
    "thunder": [
        (DL + "/670696__*", "GregorQuendel", BY4, FS % 670696, 3.0, 3),
        (SONNISS + "/Epic Stock Media - Public Spaces - Storms*/STORM_*", "Epic Stock Media (Sonniss)", SONNISS_LIC, "https://sonniss.com/gameaudiogdc", 3.0, 2),
    ],
    "cannon": [
        (DL + "/565794__*", "stomachache", CC0, FS % 565794, 1.5, 3),
    ],
    "bow": [
        (DL + "/85019__*", "Benboncan", BY4, FS % 85019, 0.6, 12),
        (DL + "/384919__*", "Ali_6868", CC0, FS % 384919, 0.6, 2),
    ],
    "creature": [
        (SONNISS + "/SoundBits - Vox Bestiae*/*", "SoundBits (Sonniss)", SONNISS_LIC, "https://sonniss.com/gameaudiogdc", 1.2, 6),
        (SONNISS + "/Epic Stock Media - Humanoid Creatures Vol 4*/*", "Epic Stock Media (Sonniss)", SONNISS_LIC, "https://sonniss.com/gameaudiogdc", 1.2, 6),
    ],
    # ambience one-shots (round 4): whole short phrases, see PHRASE_KITS
    "owl": [
        (DL + "/465697__*", "Breviceps", CC0, FS % 465697, 2.2, 4),
        (DL + "/745208__*", "Patrick_Corra", CC0, FS % 745208, 2.2, 4),
    ],
    "sheep_bells": [
        (DL + "/402638__*", "runeble", CC0, FS % 402638, 2.5, 6),
    ],
    "sheep": [
        (DL + "/383144__*", "zachrau", CC0, FS % 383144, 1.6, 6),
    ],
}


def SN(pack_glob, file_glob, vendor, max_s, max_n):
    """A Sonniss GDC 2026 source."""
    return (SONNISS + "/" + pack_glob + "/" + file_glob, vendor + " (Sonniss)", SONNISS_LIC, "https://sonniss.com/gameaudiogdc", max_s, max_n)


def F(sid, author, lic, max_s, max_n):
    """A Freesound download in ~/Downloads (<id>__<user>__<title>.<ext>)."""
    return (DL + "/%s__*" % sid, author, lic, FS % sid, max_s, max_n)


# Round 5 (Siddharth 2026-11-08: "minimal code, mainly real sounds"): every sound is built from these recordings.
KITS.update({
    # tuned notes: every grain's pitch is measured (f0), the recipes shift the nearest one to each note of the key
    "wood_notes": [
        # single notes only (code-critic round 5: the kalimba "3 Up" and the xylophone ringtone were jingles, and a
        # shifted jingle goes off key). sgossner's VSCO-2 marimba (as written) and xylophone (sounds an octave up),
        # downloaded with Siddharth's OK 2026-11-08; pitches pinned in NOTE_MIDI.
        *[F(s, "sgossner", CC0, 1.2, 1) for s in (373579, 373585, 373577, 373583, 373580, 373586, 373578, 373581)],
        *[F(s, "sgossner", CC0, 1.0, 1) for s in (374703, 374699, 374704, 374700, 374705, 374701, 374706, 374702)],
    ],
    # glockenspiel single notes (sounds an octave over the written note); the Christmas bells and music boxes were
    # dropped as notes: no single clear pitch, so they could not be put on the key reliably
    "bell_notes": [F(s, "sgossner", CC0, 1.6, 1) for s in (373367, 373364, 373368, 373365, 373369, 373366)],
    "church": [SN("Ivo Vicic - Church Bells", "04 Church Bells*", "Ivo Vicic", 3.5, 4)],
    # small things in the hand
    "click": [
        SN("Epic Stock Media - Board Game*", "UIClick_*", "Epic Stock Media", 0.15, 2),
        SN("Epic Stock Media - HD Lock*", "MECHLtch_*", "Epic Stock Media", 0.3, 1),
        SN("Epic Stock Media - HD Lock*", "MACHMech_*", "Epic Stock Media", 0.25, 2),
    ],
    "cloth": [
        SN("InMotionAudio - Foley T-Shirt", "*", "InMotionAudio", 0.5, 8),
        SN("Epic Stock Media - Fantasy Game 2*", "CLOTHFlp_*", "Epic Stock Media", 0.6, 1),
        F(475440, "o_ciz", CC0, 0.6, 6), F(467037, "kelsey_w", BY3, 0.7, 6),
    ],
    "coins": [
        F(223343, "jalastram", CC0, 0.6, 2),
        SN("Cinematic Sound Design - UI Interaction Elements", "Ting Coins*", "Cinematic Sound Design", 1.0, 1),
        SN("Cinematic Sound Design - Hybrid Game & UI Elements", "Foley Coin Flip*", "Cinematic Sound Design", 0.8, 1),
    ],
    "cards": [
        SN("Epic Stock Media - Board Game*", "PAPRHndl_*", "Epic Stock Media", 0.3, 1),
        SN("344 Audio - Casino Cards Vol. 1", "*", "344 Audio", 0.4, 6),
        SN("344 Audio - Antique Books", "*Flicking*", "344 Audio", 0.4, 3),
    ],
    # fire, magic, air
    "fire_whoosh": [
        F(848728, "mikiko850", BY4, 1.0, 8),
        SN("Epic Stock Media - Elemental Mutation*", "FIREWhsh_*", "Epic Stock Media", 1.5, 1),
    ],
    "crackle": [
        F(563766, "florianreichelt", CC0, 0.35, 8), F(730704, "newlocknew", BY4, 0.35, 8),
        SN("Ivo Vicic - Campfire - Bonfire FX", "24 Campfire*", "Ivo Vicic", 0.35, 8),
    ],
    "magic": [
        SN("Alexander Kopeikin - Emotion and Magic", "magic, energy flow*", "Alexander Kopeikin", 2.5, 4),
        SN("Epic Stock Media - Fantasy Game 2*", "MAGAngl_*", "Epic Stock Media", 2.5, 1),
        SN("CB_Sounddesign*", "GAMEMisc_Magic Creation*", "CB Sounddesign", 2.5, 1),
        F(761330, "TheLittleCrow", CC0, 2.0, 4),
    ],
    "shards": [SN("Epic Stock Media - Elemental Mutation*", "GLASMvmt_*", "Epic Stock Media", 2.0, 1)],
    "whistle": [SN("Ivo Vicic - Fireworks FX", "02 Fireworks*", "Ivo Vicic", 1.4, 6)],
    "wings": [F(655322, "21100495", CC0, 0.4, 10)],
    "bubbles": [
        SN("Cinematic Sound Design - Cartoon & Animation Vol 2", "Cartoon Bubbles*", "Cinematic Sound Design", 0.9, 1),
        F(553954, "isbeorn", CC0, 0.5, 8),
    ],
    "drum": [F(274223, "PearceWilsonKing", CC0, 0.45, 8)],
    "ticks": [SN("344 Audio - Antique Clocks", "*", "344 Audio", 0.2, 10)],
    "creak": [F(456763, "WavJunction.com", CC0, 1.4, 3), F(216879, "CastIronCarousel", CC0, 1.0, 2)],
    "rewind": [F(754845, "Poulpy2.0", CC0, 2.5, 4)],
    "bowl": [F(204915, "brodjaman", CC0, 3.0, 2), F(573805, "hollandm", CC0, 3.0, 2)],
    # voices (chopped into syllables for barks and villagers; no real words survive)
    "voice_m": [F(832122, "dergraph", CC0, 0.3, 40), F(9958, "batchku", CC0, 0.3, 3), F(10260, "batchku", CC0, 0.3, 3),
                F(10178, "batchku", CC0, 0.3, 3)],
    "voice_f": [F(800349, "cloyen", CC0, 0.3, 30)],
    "voice_old": [F(128488, "gipsyGA", BY4, 0.35, 8)],
    "grunt": [F(511023, "ale-batec", CC0, 0.45, 12)],
    "whisper": [F(193812, "geoneo0", CC0, 1.6, 4), F(362503, "balloonhead", CC0, 1.6, 4)],
    "bird": [F(518674, "jackmichaelking", CC0, 1.6, 10), F(853112, "hoshisato", CC0, 1.6, 6),
             SN("CB_Sounddesign*", "TOONMisc_Bird Flutes*", "CB Sounddesign", 1.0, 1)],
    "leaves": [F(191454, "leah15", CC0, 1.5, 6)],
    # beds: long stereo windows (BED_KITS), looped by the recipes
    "bed_wind": [F(483076, "GregorQuendel", BY4, 14.0, 3)],
    "bed_birds": [F(853112, "hoshisato", CC0, 14.0, 2),
                  SN("Just Sound Effects - Highlands of Norway", "AMBSwmp_*", "Just Sound Effects", 14.0, 2)],
    "bed_crickets": [F(440574, "ES335-001", CC0, 16.0, 3), F(522299, "Defelozedd94", CC0, 16.0, 2)],
    "bed_rain": [F(398740, "Anthousai", CC0, 9.0, 2)],
    "bed_fire": [F(730704, "newlocknew", BY4, 4.0, 2), SN("Ivo Vicic - Campfire - Bonfire FX", "24 Campfire*", "Ivo Vicic", 4.0, 1)],
    "bed_propeller": [F(853012, "Wavewire", BY4, 3.0, 1),
                      SN("Sonik Sound Library - Toy Quadcopter", "*Sustained*", "Sonik Sound Library", 3.0, 1)],
    "bed_bowl": [F(573805, "hollandm", CC0, 10.0, 2)],
    "bed_drone": [SN("Alexander Kopeikin - Emotion and Magic", "magic, drone, tension*", "Alexander Kopeikin", 16.0, 2)],
    "bed_flutter": [F(655322, "21100495", CC0, 2.0, 2)],
    "bed_whisper": [F(193812, "geoneo0", CC0, 3.0, 2), F(362503, "balloonhead", CC0, 3.0, 2)],
})
# Kits cut as phrases (a hoot series, a bell jingle, a bleat): a cut may run over the next onset (up to max seconds),
# and an onset inside the previous cut is skipped, so phrases never overlap.
PHRASE_KITS = {"owl", "sheep_bells", "sheep", "church", "drum", "magic", "shards", "whistle", "creak", "rewind", "bowl", "whisper",
               "bird", "leaves"}
# Bed kits: evenly spaced windows of max seconds (stereo, from 2 s in), not onsets; recipes loop them.
BED_KITS = {k for k in KITS if k.startswith("bed_")} | {"leaves"}  # a steady rustle has no onsets: windows too


# Sounding notes of the single-note samples (Freesound id -> MIDI). From sgossner's "midi-note-NN" tags (his titles say
# F# where the tag says G); xylophone and glockenspiel sound an octave over the tag (measured 2026-11-08: every file's
# pitch class matched, the octave was one up; the top notes were mismeasured, hence pinned rather than measured).
NOTE_MIDI = {
    373579: 48, 373585: 55, 373577: 59, 373583: 65, 373580: 72, 373586: 79, 373578: 83, 373581: 96,  # marimba
    374703: 67, 374699: 72, 374704: 79, 374700: 84, 374705: 91, 374701: 96, 374706: 103, 374702: 108,  # xylophone
    373367: 79, 373364: 84, 373368: 91, 373365: 96, 373369: 103, 373366: 108,  # glockenspiel
}


def pitch_of(path, g):
    sid = os.path.basename(path).split("__")[0]
    if sid.isdigit() and int(sid) in NOTE_MIDI:
        return 440.0 * 2 ** ((NOTE_MIDI[int(sid)] - 69) / 12)
    return f0_of(g)


def f0_of(g):
    """Rough pitch (Hz) of a grain: harmonic product spectrum of its first 0.25 s after the attack, 60-5000 Hz.
    (The strongest peak is NOT used: on a xylophone it is the overtone an octave up.) Sources with a published note
    (NOTE_HZ) skip this and use that note."""
    seg = g[int(0.01 * SR): int(0.26 * SR)]
    if len(seg) < 1024:
        seg = g
    n = 1 << 16
    sp = np.abs(np.fft.rfft(seg * np.hanning(len(seg)), n))
    fr = np.fft.rfftfreq(n, 1 / SR)
    h = sp.copy()
    for k in (2, 3):
        d = sp[::k]
        h[: len(d)] *= d
    m = (fr >= 60) & (fr <= 5000)
    return float(fr[m][np.argmax(h[m])])


def read(path, channels=1):
    p = subprocess.run([FFMPEG, "-v", "error", "-nostdin", "-i", path, "-vn", "-f", "f32le", "-acodec", "pcm_f32le",
                        "-ac", str(channels), "-ar", str(SR), "-"], capture_output=True)
    if p.returncode != 0 or not p.stdout:
        raise RuntimeError("cannot read %s: %s" % (path, p.stderr.decode(errors="replace")[-200:]))
    x = np.frombuffer(p.stdout, dtype=np.float32).astype(float)
    return x if channels == 1 else x.reshape(-1, channels)


def onsets(x, min_gap=0.08):
    """Sample indices where the short-term energy jumps (a hit starts)."""
    hop = 128
    n = len(x) // hop
    e = np.sqrt(np.mean(x[: n * hop].reshape(n, hop) ** 2, axis=1) + 1e-12)
    db = 20 * np.log10(e)
    floor = np.percentile(db, 30)
    rise = np.diff(db, prepend=db[0])
    peak = db.max()
    out = []
    last = -10 ** 9
    for i in range(2, n):
        if rise[i] > 6.0 and db[i] > max(floor + 18, peak - 35) and (i - last) * hop > min_gap * SR:
            out.append(i * hop)
            last = i
    return out, db, hop


def cut(x, at, max_s, db, hop, next_at=None):
    """One event from onset `at` to where it has decayed 40 dB, max_s, or the next onset (whichever is first). None if
    too short, silent, or still ringing (less than 20 dB down) when the next hit starts: that cut would hold two hits."""
    start = max(0, at - int(0.003 * SR))
    i0 = at // hop
    lvl = db[i0: i0 + int(0.03 * SR / hop) + 1].max()
    end_i = i0
    full = min(len(db), i0 + int(max_s * SR / hop))
    lim = full if next_at is None else min(full, max(i0 + 1, next_at // hop - 1))
    while end_i < lim and db[end_i] > lvl - 40:
        end_i += 1
    if end_i >= lim and lim < full and db[min(end_i, len(db) - 1)] > lvl - 20:
        return None
    g = x[start: end_i * hop].copy()
    if len(g) < int(0.03 * SR):
        return None
    k = min(len(g) // 4, int(0.02 * SR))
    g[-k:] *= np.linspace(1, 0, k)
    g[: int(0.001 * SR)] *= np.linspace(0, 1, int(0.001 * SR))
    g = g - np.mean(g)
    pk = np.max(np.abs(g))
    if pk < 1e-4:
        return None
    return g / pk * 0.89


def main():
    only = sys.argv[1:]
    os.makedirs(OUT, exist_ok=True)
    index_path = os.path.join(OUT, "grains.json")
    index = json.load(open(index_path, encoding="utf-8")) if os.path.exists(index_path) else {}
    rebuilt = []
    for kit, sources in KITS.items():
        if only and kit not in only:
            continue
        missing = [src[0] for src in sources if not glob.glob(src[0])]
        if missing:  # never wipe a committed kit because the raw downloads are not on this machine
            print("%-11s SKIPPED (kept as is): missing source %s" % (kit, "; ".join(missing)))
            continue
        kdir = os.path.join(OUT, kit)
        os.makedirs(kdir, exist_ok=True)
        for f in glob.glob(os.path.join(kdir, "*.wav")):
            os.remove(f)
        entries = []
        rebuilt.append(kit)
        for pattern, author, lic, url, max_s, max_n in sources:
            files = sorted(glob.glob(pattern))
            per_file = max(1, max_n // len(files))
            for path in files:
                if kit in BED_KITS:  # evenly spaced stereo windows, gently faded, peak 0.89
                    x = read(path, 2)
                    w = int(max_s * SR)
                    room = max(1, len(x) - w - 2 * SR)
                    for k in range(per_file):
                        a = 2 * SR + (room * k) // max(1, per_file)
                        g = x[a: a + w].copy()
                        if len(g) < SR:
                            continue
                        g -= g.mean(axis=0)
                        g /= np.max(np.abs(g)) + 1e-9
                        name = "%s_%02d.wav" % (kit, len(entries) + 1)
                        wavfile.write(os.path.join(kdir, name), SR, (g * 0.89 * 32767).astype(np.int16))
                        entries.append(dict(file=name, seconds=round(len(g) / SR, 3), source=os.path.basename(path),
                                            author=author, licence=lic, url=url, at=round(a / SR, 3)))
                    continue
                x = read(path)
                at, db, hop = onsets(x)
                if not at:  # slow swells (voices): start where it first gets within 20 dB of its peak
                    at = [int(np.argmax(db > db.max() - 20)) * hop]
                n = 0
                prev_end = -1
                for j, a in enumerate(at):
                    phrase = kit in PHRASE_KITS
                    if phrase and a < prev_end:
                        continue
                    g = cut(x, a, max_s, db, hop, None if phrase else (at[j + 1] if j + 1 < len(at) else None))
                    if g is None:
                        continue
                    prev_end = a + len(g)
                    name = "%s_%02d.wav" % (kit, len(entries) + 1)
                    wavfile.write(os.path.join(kdir, name), SR, (g * 32767).astype(np.int16))
                    entries.append(dict(file=name, seconds=round(len(g) / SR, 3), source=os.path.basename(path),
                                        author=author, licence=lic, url=url, at=round(a / SR, 3), f0=round(pitch_of(path, g), 1)))
                    n += 1
                    if n >= per_file:
                        break
        index[kit] = entries
        print("%-11s %2d grains" % (kit, len(entries)))
    json.dump(index, open(index_path, "w", encoding="utf-8"), indent=1)
    write_credits(index)
    if rebuilt:  # new cuts have no screen verdict yet (grain() would use them all): screen them now
        print("screening", " ".join(rebuilt))
        subprocess.run([sys.executable, os.path.join(ROOT, "tools", "audio_grain_screen.py"), *rebuilt], check=False)


def write_credits(index):
    rows = {}
    for kit, entries in index.items():
        for e in entries:
            key = (e["source"], e["author"], e["licence"], e["url"])
            rows.setdefault(key, set()).add(kit)
    lines = ["# Audio credits", "",
             "Sound effects in Aeterna are made from code (assets/generators/make_audio.py), some layered with short cuts",
             "(\"grains\") of the recordings below. CC BY sounds are credited as their licence requires; CC0 and Sonniss sounds",
             "need no credit and are listed for provenance. All grains are modified (cut, filtered, pitched, layered).",
             "Generated by tools/audio_grains.py from assets/audio_src/grains/grains.json; do not edit by hand.", "",
             "The shipped game must also show the CC BY rows on a credits screen (or the store page).", "",
             "| recording | author | licence | source | used in |", "|---|---|---|---|---|"]
    for (src, author, lic, url), kits in sorted(rows.items(), key=lambda kv: (kv[0][2], kv[0][1])):
        lic_txt = "[%s](%s)" % (lic, LICENCE_URL[lic]) if lic in LICENCE_URL else lic
        lines.append("| %s | %s | %s | %s | %s |" % (src.replace("|", "/"), author, lic_txt, url, ", ".join(sorted(kits))))
    open(os.path.join(ROOT, "docs", "AUDIO_CREDITS.md"), "w", encoding="utf-8").write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
