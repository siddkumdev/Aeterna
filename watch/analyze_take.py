"""Look for the pinch in a recorded take: python watch/analyze_take.py _work/watch/<take>.csv (an .incomplete.csv works too).
Prints the cue-aligned average of the motion signal, how well pinch windows separate from quiet and from movement, and a
threshold detector's hits and false alarms. A first look, not the final detector."""
import sys
import numpy as np

path = sys.argv[1]
rows = {"a": [], "g": [], "r": []}
cues = []
for line in open(path):
    p = line.strip().split(",")
    if p[0] in rows and len(p) >= 5:
        rows[p[0]].append([float(x) for x in p[1:]])
    elif p[0] == "c" and len(p) == 4 and int(p[2]) >= 0:
        cues.append((int(p[2]), int(p[1]) / 1e6, p[3]))
cues.sort()
a = np.array(rows["a"]); g = np.array(rows["g"])
a = a[np.argsort(a[:, 0])]; g = g[np.argsort(g[:, 0])]
ta, tg = a[:, 0] / 1e6, g[:, 0] / 1e6
print("cues %d..%d, accel %d samples, %.1f s" % (cues[0][0], cues[-1][0], len(a), ta[-1] - ta[0]))
# per-sample features: jerk (change in acceleration) and gyro magnitude
jerk = np.r_[0, np.linalg.norm(np.diff(a[:, 1:4], axis=0), axis=1)]
gmag = np.linalg.norm(g[:, 1:4], axis=1)

def window(t, x, lo, hi):
    m = (t >= lo) & (t < hi)
    return x[m]

def auc(pos, neg):
    pos, neg = np.asarray(pos), np.asarray(neg)
    if len(pos) == 0 or len(neg) == 0:
        return float("nan")
    allv = np.r_[pos, neg]
    ranks = allv.argsort().argsort() + 1.0
    return (ranks[:len(pos)].sum() - len(pos) * (len(pos) + 1) / 2) / (len(pos) * len(neg))

by = {}
for i, t, n in cues:
    by.setdefault(n, []).append(t)
print({k: len(v) for k, v in by.items()})

def triggered(times, label):
    edges = np.arange(-0.5, 2.01, 0.1)
    jr, gr = [], []
    for t in times:
        jr.append([np.mean(window(ta, jerk, t + e, t + e + 0.1)) for e in edges[:-1]])
        gr.append([np.mean(window(tg, gmag, t + e, t + e + 0.1)) for e in edges[:-1]])
    jr, gr = np.nanmean(jr, 0), np.nanmean(gr, 0)
    print("\n%s: mean jerk (m/s2 per sample) and gyro (rad/s) per 100 ms from cue" % label)
    print("t   " + " ".join("%5.1f" % e for e in edges[:-1]))
    print("jerk" + " ".join("%5.2f" % v for v in jr))
    print("gyro" + " ".join("%5.2f" % v for v in gr))

triggered(by.get("pinch", []), "PINCH at rest (arm still)")
triggered(by.get("open", []), "OPEN at rest")
triggered(by.get("pinch_moving", []), "PINCH while aiming")

def feats(t, lo, hi):
    return (np.sqrt(np.mean(window(ta, jerk, t + lo, t + hi) ** 2)), np.sqrt(np.mean(window(tg, gmag, t + lo, t + hi) ** 2)))

print("\nSeparability (AUC, 0.5 = chance, 1.0 = perfect): feature in the pinch window vs an equal quiet window")
for lo, hi in ((0.1, 0.5), (0.2, 0.8), (0.0, 1.0)):
    pos = [feats(t, lo, hi) for t in by.get("pinch", [])]
    neg = [feats(t - 1.3, 0, hi - lo) for t in by.get("pinch", [])]
    print("rest pinch window [%.1f,%.1f] vs quiet before: jerk AUC %.2f  gyro AUC %.2f" % (lo, hi, auc([p[0] for p in pos], [n[0] for n in neg]), auc([p[1] for p in pos], [n[1] for n in neg])))
if "move" in by:
    t0 = by["move"][0]
    moves = [(t0 + s, t0 + s + 0.6) for s in np.arange(0, 28, 0.7)]
    mv = [(np.sqrt(np.mean(window(ta, jerk, lo, hi) ** 2)), np.sqrt(np.mean(window(tg, gmag, lo, hi) ** 2))) for lo, hi in moves]
    pos = [feats(t, 0.2, 0.8) for t in by.get("pinch", [])]
    print("rest pinches vs free arm movement (no pinching): jerk AUC %.2f  gyro AUC %.2f   <- must be well above 0.5, or movement will look like pinches" % (auc([p[0] for p in pos], [m[0] for m in mv]), auc([p[1] for p in pos], [m[1] for m in mv])))
    pm = [feats(t, 0.2, 0.8) for t in by.get("pinch_moving", [])]
    print("pinches while aiming vs aiming without pinch: jerk AUC %.2f  gyro AUC %.2f  (n=%d)" % (
        auc([p[0] for p in pm], [feats(t, 0.2, 0.8)[0] for t in by.get("aim", [])]),
        auc([p[1] for p in pm], [feats(t, 0.2, 0.8)[1] for t in by.get("aim", [])]), len(pm)))
    print("typical level: free movement jerk %.2f gyro %.2f | rest pinch jerk %.2f gyro %.2f | rest quiet jerk %.2f gyro %.2f" % (
        np.median([m[0] for m in mv]), np.median([m[1] for m in mv]), np.median([p[0] for p in pos]), np.median([p[1] for p in pos]),
        np.median([feats(t - 1.3, 0, 0.6)[0] for t in by.get("pinch", [])]), np.median([feats(t - 1.3, 0, 0.6)[1] for t in by.get("pinch", [])])))

# --- simple detector: smoothed jerk crosses a threshold. Hits = a detection 0.1..0.9 s after a cue; false alarms = detections far from any cue.
sm = np.convolve(jerk, np.ones(3) / 3, mode="same")
def detections(thr, t_lo, t_hi, refractory=0.4):
    out, last = [], -9
    idx = np.where((ta >= t_lo) & (ta < t_hi) & (sm > thr))[0]
    for i in idx:
        if ta[i] - last >= refractory:
            out.append(ta[i]); last = ta[i]
    return out
print("\nDetector: smoothed jerk above a threshold")
print("thr    pinch hit   release hit   false alarms/min (quiet)   false alarms/min (free movement)")
pinch_t = by.get("pinch", []); open_t = by.get("open", []); move_t = by.get("move", [None])[0]
rest_lo, rest_hi = (cues[0][1], move_t if move_t else ta[-1])
for thr in (0.3, 0.4, 0.5, 0.6, 0.8, 1.0):
    det_rest = detections(thr, rest_lo, rest_hi)
    def near(times, win):
        return sum(any(t + win[0] <= d <= t + win[1] for d in det_rest) for t in times)
    hit_p = near(pinch_t, (0.1, 0.9)); hit_o = near(open_t, (0.1, 0.9))
    cue_times = np.array(pinch_t + open_t)
    fa_quiet = [d for d in det_rest if not np.any((d >= cue_times + 0.0) & (d <= cue_times + 1.0))]
    quiet_min = (rest_hi - rest_lo) / 60.0
    fa_move = len(detections(thr, move_t + 1, move_t + 29)) / (28 / 60.0) if move_t else float("nan")
    print("%.1f    %2d/%2d       %2d/%2d         %5.1f                      %5.1f" % (thr, hit_p, len(pinch_t), hit_o, len(open_t), len(fa_quiet) / quiet_min, fa_move))
