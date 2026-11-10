"""Search a sound's recipe settings for the versions that measure closest to a reference band (the agent cannot hear;
it ranks by numbers, then the user hears only the 2-3 finalists, blind). Research: reports/AI judging game sound by vibe.md.

    python tools/audio_tune.py <sound> --ref <tag> [tag ...] [--max-seconds S] [--top N]

Writes the finalists to _work/audio/tune/<sound>/ (git-ignored) as <sound>_<letter>.wav, loudness-matched, plus
scores.json with every candidate's settings and numbers, and the current game version as <sound>_now.wav.
blind_1.wav ... are the same files shuffled (finalists and "now"), for a blind listen; key.json says which is which.
Candidates come from CANDIDATES below: one function per sound that takes a settings dict and returns the recipe body.
Only recordings are used (the same grain kits as make_audio.py); nothing is synthesised.
"""
import itertools
import json
import os
import sys

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
sys.path.insert(0, os.path.join(ROOT, "assets", "generators"))
import audio_measure  # noqa: E402
import audio_reference as ref  # noqa: E402
import make_audio as MA  # noqa: E402

OUT = os.path.join(ROOT, "_work", "audio", "tune")
# what the score compares: tone colour and envelope, not loudness or length (the mix level is set separately)
SCORE_KEYS = ["centroid_hz", "above_5k_db", "brightness", "warmth", "depth", "boominess", "sharpness", "hardness",
              "attack_ms", "decay_ms", "crest_db"]


def _place_thunk(s):
    def body(r, v):
        piece = MA.lp(MA.grain("chess", r, s["piece_pitch"]), s["piece_lp"])
        knock = MA.lp(MA.grain("wood_knock", r, s["knock_pitch"]), s["knock_lp"])
        stone = MA.lp(MA.grain("stone", r, s["stone_pitch"], seconds=0.3), 4500)
        return MA.mix((piece, 0, s["piece_w"]), (knock, 0, s["knock_w"]), (stone, 0.003, s["stone_w"]))
    return body


CANDIDATES = {
    "place_thunk": (_place_thunk, {
        "piece_pitch": [1.0, 1.25, 1.5], "piece_lp": [6000, 19000],
        "knock_pitch": [0.8, 1.1, 1.4], "knock_lp": [2500, 12000],
        "stone_pitch": [0.75, 1.0], "piece_w": [0.7, 1.0], "knock_w": [0.2, 0.4, 0.9], "stone_w": [0.0, 0.35],
        "warm": [True, False]}),
}
TAKES = 3  # each candidate is rendered with 3 seeds and scored on the average, so one lucky grain does not win


def score(rows, band):
    """Mean distance outside the reference's 25-75% band, in band widths, over SCORE_KEYS (0 = all inside)."""
    d = []
    for r in rows:
        for k in SCORE_KEYS:
            if r.get(k) is not None and k in band:
                d.append(abs(ref.where(r[k], band[k])))
    return float(np.mean(d)) if d else 99.0


def matched(x, lufs=-24.0):
    """Same perceived loudness (LUFS) for every file in a listening set: a louder file tends to win a blind test."""
    x = MA.normalise(x, rms_db=-22.0, max_peak_db=-1.5)
    now = audio_measure.measure_array(x, MA.SR_, "m").get("lufs")
    if now is not None:
        x = x * 10 ** ((lufs - now) / 20.0)
        x = x * min(1.0, 10 ** (-1.0 / 20) / (np.abs(x).max() + 1e-12))  # never above -1 dB peak
    return x


def render_candidate(name, maker, s, take):
    spec = dict(MA.RECIPES[name])
    spec["fn"] = maker(s)
    spec["warm"] = s.get("warm", spec["warm"])
    return MA.render(name, spec, 0, take)


def main():
    a = sys.argv[1:]
    if not a or "--ref" not in a:
        print(__doc__)
        return
    name = a[0]
    top = 3
    if "--top" in a:
        i = a.index("--top")
        top = int(a[i + 1])
        a = a[:i] + a[i + 2:]
    a, opts = ref._args(a)
    tags = a[a.index("--ref") + 1:]
    band = ref.band(ref.load(tags, opts.get("max_seconds")))
    maker, grid = CANDIDATES[name]
    keys = list(grid)
    results = []
    for combo in itertools.product(*(grid[k] for k in keys)):
        s = dict(zip(keys, combo))
        rows = [audio_measure.measure_array(render_candidate(name, maker, s, t), MA.SR_, "c") for t in range(TAKES)]
        avg = {k: float(np.mean([r[k] for r in rows if r.get(k) is not None]))
               for k in SCORE_KEYS if any(r.get(k) is not None for r in rows)}
        results.append({"settings": s, "score": round(score(rows, band), 3), "numbers": {k: round(v, 1) for k, v in avg.items()}})
    results.sort(key=lambda e: e["score"])
    now = [audio_measure.measure_array(MA.render(name, MA.RECIPES[name], 0, t), MA.SR_, "now") for t in range(TAKES)]
    out = os.path.join(OUT, name)
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if os.path.isfile(os.path.join(out, f)):
            os.remove(os.path.join(out, f))
    # finalists must differ: skip a candidate whose settings differ from an earlier finalist in only one value
    picks = []
    for e in results:
        if all(sum(e["settings"][k] != p["settings"][k] for k in keys) >= 2 for p in picks):
            picks.append(e)
        if len(picks) == top:
            break
    for i, e in enumerate(picks):
        e["letter"] = "ABCDEFGH"[i]
        x = np.concatenate([np.concatenate([matched(render_candidate(name, maker, e["settings"], t)), np.zeros(int(0.5 * MA.SR_))])
                            for t in range(TAKES)])
        MA.write_wav(os.path.join(out, "%s_%s.wav" % (name, e["letter"])), x)  # each take matched on its own
    x = np.concatenate([np.concatenate([matched(MA.render(name, MA.RECIPES[name], 0, t)), np.zeros(int(0.5 * MA.SR_))]) for t in range(TAKES)])
    MA.write_wav(os.path.join(out, "%s_now.wav" % name), x)
    # blind set for the user: the finalists and the current game version, shuffled under numbers; the key is in key.json
    import shutil
    names = ["%s_%s.wav" % (name, e["letter"]) for e in picks] + ["%s_now.wav" % name]
    order = np.random.default_rng().permutation(len(names))
    key = {}
    for n, i in enumerate(order):
        shutil.copy2(os.path.join(out, names[i]), os.path.join(out, "blind_%d.wav" % (n + 1)))
        key["blind_%d" % (n + 1)] = names[i][len(name) + 1: -4]
    json.dump(key, open(os.path.join(out, "key.json"), "w", encoding="utf-8"), indent=1)
    json.dump({"ref": tags, "band": band, "now_score": round(score(now, band), 3), "candidates": results},
              open(os.path.join(out, "scores.json"), "w", encoding="utf-8"), indent=1)
    print("%d candidates scored against %s (%d events)" % (len(results), ", ".join(tags), band["centroid_hz"][3]))
    print("score = mean distance outside the reference 25-75%% band, in band widths (0 = inside on every number)")
    print("now (game version): %.2f" % score(now, band))
    hdr = "%-6s %6s " % ("", "score") + " ".join("%9s" % k[:9] for k in SCORE_KEYS)
    print(hdr)
    print("%-6s %6s " % ("ref", "") + " ".join("%9.1f" % band[k][1] if k in band else "%9s" % "-" for k in SCORE_KEYS))
    nowavg = {k: np.mean([r[k] for r in now if r.get(k) is not None]) for k in SCORE_KEYS}
    print("%-6s %6.2f " % ("now", score(now, band)) + " ".join("%9.1f" % nowavg[k] for k in SCORE_KEYS))
    for e in picks:
        print("%-6s %6.2f " % (e["letter"], e["score"]) + " ".join("%9.1f" % e["numbers"].get(k, float("nan")) for k in SCORE_KEYS))
        print("        ", e["settings"])
    print("wrote", out)


if __name__ == "__main__":
    main()
