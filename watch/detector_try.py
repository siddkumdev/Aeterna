"""First detector experiment: baseline-relative jerk vs a plain threshold, on recorded takes. python watch/detector_try.py _work/watch/<take>.csv ..."""
import sys
import numpy as np

def load(path):
    rows = {"a": [], "g": []}; cues = []
    for line in open(path):
        p = line.strip().split(",")
        if p[0] in rows and len(p) >= 5: rows[p[0]].append([float(x) for x in p[1:5]])
        elif p[0] == "c" and len(p) == 4 and int(p[2]) >= 0: cues.append((int(p[1]) / 1e6, p[3]))
    a = np.array(sorted(rows["a"])); cues.sort()
    return a[:, 0] / 1e6, a[:, 1:4], cues

def score_series(t, acc, kind):
    jerk = np.r_[0, np.linalg.norm(np.diff(acc, axis=0), axis=1)]
    sm = np.convolve(jerk, np.ones(3) / 3, mode="same")
    if kind == "abs":
        return sm
    base = np.zeros_like(sm)
    for i in range(len(sm)):
        lo = np.searchsorted(t, t[i] - 0.6); hi = np.searchsorted(t, t[i] - 0.1)
        base[i] = np.median(sm[lo:hi]) if hi > lo else sm[i]
    return sm / (base + 0.08)

def run(path, kind, thresholds):
    t, acc, cues = load(path)
    sc = score_series(t, acc, kind)
    pinch = [c[0] for c in cues if c[1] in ("pinch", "pinch_moving")]
    other = [c[0] for c in cues if c[1] in ("open", "open_moving", "pinch", "pinch_moving")]
    dur = (t[-1] - t[0]) / 60
    out = []
    for thr in thresholds:
        dets, last = [], -9
        for i in np.where(sc > thr)[0]:
            if t[i] - last >= 0.5: dets.append(t[i]); last = t[i]
        hits = sum(any(c + 0.1 <= d <= c + 0.9 for d in dets) for c in pinch)
        fa = sum(not any(c - 0.2 <= d <= c + 1.3 for c in other) for d in dets)
        out.append((thr, hits, len(pinch), fa / dur))
    return out

for path in sys.argv[1:]:
    print("==", path.split("/")[-1])
    for kind, thr in (("abs", (0.5, 0.8, 1.0, 1.5)), ("ratio", (2, 3, 4, 5, 6, 8))):
        print(kind, "  ".join("thr %.1f: %d/%d hits, %.1f false/min" % r for r in run(path, kind, thr)))
