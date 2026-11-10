"""Turn reference gameplay recordings into single sound effects and target numbers (the agent cannot hear, so it
compares numbers; research: reports/AI judging game sound by vibe.md).

    python tools/audio_reference.py cut [tag ...]       # _work/refs/raw/<tag>/*.wav -> _work/refs/events/<tag>/*.wav + events.json
    python tools/audio_reference.py band <tag> [tag ...] [--max-seconds S]   # print the target band (median, 25-75%) of their events
    python tools/audio_reference.py compare <file.wav ...> --ref <tag> [tag ...]  # where our sounds sit inside that band

Reference clips are private, for analysis only: they stay in the git-ignored _work/refs and are never shipped.

How an event is found: a 5 ms loudness envelope; the background level is the 20th percentile of the second before.
An event starts where the envelope jumps at least JUMP_DB above that background inside 30 ms, and ends when it falls
back near the background (or at MAX_EVENT_S, or at the next event). Only events whose peak stands CLEAN_DB above the
background are kept, so effects buried under music or other sounds are skipped rather than measured with the music.
"""
import json
import os
import sys

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio_measure  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "_work", "refs")
HOP_S = 0.005
JUMP_DB = 12.0
CLEAN_DB = 24.0
MAX_EVENT_S = 1.5
MIN_EVENT_S = 0.04
KEYS = ["lufs", "crest_db", "attack_ms", "decay_ms", "seconds", "centroid_hz", "above_5k_db", "above_10k_db",
        "brightness", "warmth", "hardness", "depth", "sharpness", "roughness", "boominess"]


def _env_db(x, sr):
    hop = int(HOP_S * sr)
    n = len(x) // hop
    e = np.sqrt(np.mean(x[: n * hop].reshape(n, hop) ** 2, axis=1)) + 1e-9
    return 20 * np.log10(e), hop


def find_events(x, sr):
    """[(start_sample, end_sample, peak_db, background_db)] of clean single sounds."""
    env, hop = _env_db(x, sr)
    back_n, rise_n = int(1.0 / HOP_S), int(0.03 / HOP_S)
    out, i = [], back_n
    while i < len(env) - rise_n:
        back = np.percentile(env[i - back_n: i], 20)
        if env[i + rise_n] - back < JUMP_DB or env[i] - back > JUMP_DB * 0.5:
            i += 1
            continue
        # start at the first hop that has really risen (6 dB over the background), one hop of lead-in: no background
        # before the sound, or the attack would be counted from the noise
        start = i
        while start < i + rise_n and env[start] - back < 6.0:
            start += 1
        start = max(i, start - 1)
        j = start + 1
        stop = min(len(env), start + int(MAX_EVENT_S / HOP_S))
        peak = env[start]
        end = None
        while j < stop:
            # a new sharp jump after the peak has decayed: the next event begins; end this one before that rise
            if j > start + 2 * rise_n and env[j] - env[j - rise_n] > JUMP_DB and env[j - rise_n] < peak - 10:
                end = j - rise_n
                break
            peak = max(peak, env[j])
            if j > start + rise_n and env[j] < back + 4.0:
                end = j
                break
            j += 1
        if end is None:
            end = j
        if peak - back >= CLEAN_DB and (end - start) * HOP_S >= MIN_EVENT_S:
            out.append((start * hop, end * hop, float(peak), float(back)))
        i = max(end, start + 1)
    return out


def cut(tag):
    src = os.path.join(ROOT, "raw", tag)
    dst = os.path.join(ROOT, "events", tag)
    os.makedirs(dst, exist_ok=True)
    for f in os.listdir(dst):
        if f.endswith(".wav"):
            os.remove(os.path.join(dst, f))
    rows = []
    for f in sorted(os.listdir(src)):
        if not f.endswith(".wav"):
            continue
        x, sr = sf.read(os.path.join(src, f), always_2d=True)
        mono = audio_measure._mono(x.astype(float))
        for k, (a, b, peak, back) in enumerate(find_events(mono, sr)):
            seg = x[a:b]
            fade = min(len(seg), int(0.01 * sr))  # no click at the cut end
            seg = seg.copy()
            seg[-fade:] *= np.linspace(1, 0, fade)[:, None]
            name = "%s_%07.2f.wav" % (tag, a / sr)
            sf.write(os.path.join(dst, name), seg, sr, subtype="PCM_24")
            r = audio_measure.measure_array(seg, sr, name)
            r.update({"tag": tag, "source": f, "at_s": round(a / sr, 2), "clean_db": round(peak - back, 1)})
            rows.append(r)
    json.dump(rows, open(os.path.join(dst, "events.json"), "w", encoding="utf-8"), indent=1)
    print("%-26s %4d clean events" % (tag, len(rows)))
    return rows


def load(tags, max_seconds=None):
    rows = []
    for t in tags:
        p = os.path.join(ROOT, "events", t, "events.json")
        rows += [r for r in json.load(open(p, encoding="utf-8")) if "error" not in r]
    if max_seconds:
        rows = [r for r in rows if r["seconds"] <= max_seconds]
    return rows


def band(rows):
    b = {}
    for k in KEYS:
        v = np.array([r[k] for r in rows if r.get(k) is not None], dtype=float)
        v = v[np.isfinite(v)]  # older events.json files may hold NaN readings
        if len(v):
            b[k] = (float(np.percentile(v, 25)), float(np.median(v)), float(np.percentile(v, 75)), len(v))
    return b


def where(value, b):
    """How far outside the 25-75% band, in band widths (0 = inside)."""
    lo, mid, hi, _ = b
    w = max(hi - lo, 1e-6)
    return 0.0 if lo <= value <= hi else (value - hi) / w if value > hi else (value - lo) / w


def _args(a):
    opts = {}
    if "--max-seconds" in a:
        i = a.index("--max-seconds")
        opts["max_seconds"] = float(a[i + 1])
        a = a[:i] + a[i + 2:]
    return a, opts


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        return
    cmd, a = a[0], a[1:]
    a, opts = _args(a)
    if cmd == "cut":
        for t in a or sorted(os.listdir(os.path.join(ROOT, "raw"))):
            cut(t)
    elif cmd == "band":
        rows = load(a, opts.get("max_seconds"))
        print("%d events from %s" % (len(rows), ", ".join(a)))
        for k, (lo, mid, hi, n) in band(rows).items():
            print("  %-13s 25%%=%9.1f  median=%9.1f  75%%=%9.1f   (n=%d)" % (k, lo, mid, hi, n))
    elif cmd == "compare":
        i = a.index("--ref")
        files, tags = a[:i], a[i + 1:]
        b = band(load(tags, opts.get("max_seconds")))
        print("%-22s " % "file" + " ".join("%10s" % k[:10] for k in KEYS))
        print("%-22s " % "ref median" + " ".join("%10.1f" % b[k][1] if k in b else "%10s" % "-" for k in KEYS))
        for f in files:
            r = audio_measure.measure(f)
            cells = []
            for k in KEYS:
                v = r.get(k)
                if v is None or k not in b:
                    cells.append("%10s" % "-")
                    continue
                d = where(v, b[k])
                cells.append("%9.1f%s" % (v, " " if d == 0 else ("+" if d > 0 else "-")))
            print("%-22s " % r["file"][:22] + " ".join(cells))
        print("(+ above the reference's 25-75% band, - below it, blank inside)")
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
