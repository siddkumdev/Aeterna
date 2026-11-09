"""Measure a sound the way a listener would describe it, so the agent (which cannot hear) can judge sounds by numbers.

    python tools/audio_measure.py <file.wav> [more.wav ...]        # prints one row of numbers per file
    python tools/audio_measure.py --json out.json <files...>        # also writes them as JSON

Measures (research: reports/AI judging game sound by vibe.md):
  - Audio Commons timbral models (pip timbral_models, Apache-2.0; validated against listeners on non-music sounds):
    brightness r~0.86, hardness 0.87, depth 0.89, warmth 0.79, sharpness 0.78, roughness 0.56-0.70, boominess 0.67.
  - loudness (LUFS, pyloudnorm, short clips padded), peak, crest factor, attack time, decay time, length,
    spectral centroid and the share of energy above 5 and 10 kHz.
timbral_models was last released in 2024 for older numpy/librosa; the shims below adapt it without editing the package.
"""
import json
import os
import sys
import warnings

import numpy as np
import soundfile as sf

warnings.filterwarnings("ignore", category=FutureWarning)  # only librosa/numpy deprecation notices

# --- compatibility shims for timbral_models (numpy 2, librosa >= 0.10 keyword-only arguments)
np.lib.pad = np.pad
import librosa  # noqa: E402

_od, _os, _rs = librosa.onset.onset_detect, librosa.onset.onset_strength, librosa.core.resample
librosa.onset.onset_detect = lambda y=None, sr=22050, **k: _od(y=y, sr=sr, **k)
librosa.onset.onset_strength = lambda y=None, sr=22050, **k: _os(y=y, sr=sr, **k)
librosa.core.resample = lambda y, orig_sr=None, target_sr=None, **k: _rs(y, orig_sr=orig_sr, target_sr=target_sr, **k)
import pyloudnorm  # noqa: E402
import timbral_models  # noqa: E402

TIMBRAL = ["brightness", "warmth", "hardness", "depth", "sharpness", "roughness", "boominess"]


def _mono(x):
    # the louder channel, not the average: opposite-phase channels would cancel to silence
    if x.ndim == 2:
        return x[:, int(np.argmax(np.sqrt(np.mean(x ** 2, axis=0))))]
    return x


def measure(path):
    x, sr = sf.read(path, always_2d=False)
    return measure_array(x, sr, os.path.basename(path))


def measure_array(x, sr, name="clip"):
    """The same numbers for audio already in memory (mono or [n, channels])."""
    x = _mono(np.asarray(x, dtype=float))
    out = {"file": name, "seconds": round(len(x) / sr, 3)}
    if len(x) == 0 or not np.any(x):
        out["error"] = "empty or silent"
        return out
    # silence at either end must not change any number: measure only from the first to the last sample above -60 dB
    loud = np.flatnonzero(np.abs(x) > np.abs(x).max() * 1e-3)
    x = x[loud[0]: loud[-1] + 1]
    out["seconds"] = round(len(x) / sr, 3)  # the sound itself, without silence at either end
    peak = float(np.abs(x).max()) + 1e-12
    rms = float(np.sqrt(np.mean(x ** 2))) + 1e-12
    out["peak_db"] = round(20 * np.log10(peak), 1)
    out["crest_db"] = round(20 * np.log10(peak / rms), 1)
    # loudness (BS.1770): a short hit is measured as one 400 ms block (padded with silence), the same block size longer
    # clips are measured in, so short and long sounds compare like for like
    pad = max(0, int(0.4 * sr) - len(x))
    try:
        lufs = float(pyloudnorm.Meter(sr).integrated_loudness(np.concatenate([x, np.zeros(pad)])))
        out["lufs"] = round(lufs, 1) if np.isfinite(lufs) else None
    except Exception:
        out["lufs"] = None
    # envelope: attack = time from 10% of the peak envelope to the peak; decay = from the peak down to 10% (-20 dB)
    hop = max(1, int(0.002 * sr))
    env = np.sqrt(np.convolve(x ** 2, np.ones(hop) / hop, "same"))
    ip = int(np.argmax(env))
    e = env / (env[ip] + 1e-12)
    a10 = np.flatnonzero(e[: ip + 1] >= 0.1)
    out["attack_ms"] = round((ip - a10[0]) / sr * 1000, 1) if len(a10) else 0.0
    after = np.flatnonzero(e[ip:] < 0.1)
    out["decay_ms"] = round(after[0] / sr * 1000, 1) if len(after) else None  # None: cut off before it decayed
    # spectrum: no window over the whole clip (a Hann window would mute the attack of a one-shot, where the transient is)
    sp = np.abs(np.fft.rfft(x)) ** 2
    f = np.fft.rfftfreq(len(x), 1 / sr)
    tot = sp.sum() + 1e-20
    out["centroid_hz"] = round(float((f * sp).sum() / tot))
    out["above_5k_db"] = round(10 * np.log10(sp[f >= 5000].sum() / tot + 1e-12), 1)
    out["above_10k_db"] = round(10 * np.log10(sp[f >= 10000].sum() / tot + 1e-12), 1)
    try:
        with warnings.catch_warnings():  # timbral_models' own internal level fixes and short-clip FFT notices
            warnings.simplefilter("ignore", UserWarning)
            t = timbral_models.timbral_extractor(x, fs=sr, verbose=False)  # the trimmed audio, not the file
        for k in TIMBRAL:
            v = t.get(k)
            out[k] = round(float(v), 1) if v is not None and np.isfinite(float(v)) else None  # NaN: model gave no reading
    except Exception as ex:  # very short or silent clips can fail inside the timbral models
        out["timbral_error"] = "%s: %s" % (type(ex).__name__, str(ex)[:120])
    return out


def main():
    args = sys.argv[1:]
    jpath = None
    if args and args[0] == "--json":
        jpath, args = args[1], args[2:]
    rows = [measure(p) for p in args]
    keys = ["seconds", "lufs", "crest_db", "attack_ms", "decay_ms", "centroid_hz", "above_5k_db", "above_10k_db"] + TIMBRAL
    print("%-28s " % "file" + " ".join("%9s" % k[:9] for k in keys))
    for r in rows:
        print("%-28s " % r["file"][:28] + " ".join("%9s" % (r.get(k) if r.get(k) is not None else "-") for k in keys))
    if jpath:
        json.dump(rows, open(jpath, "w", encoding="utf-8"), indent=1)


if __name__ == "__main__":
    main()
