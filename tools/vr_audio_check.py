"""Measure the sound of a recorded VR bot run (Godot Movie Maker .avi + vr_monitor events.txt).

Usage: python tools/vr_audio_check.py <run_dir>   (expects <run_dir>/<name>.avi and <run_dir>/events.txt)

Writes <run_dir>/audio_report.md and short clips of each flagged moment to <run_dir>/clips/.
Flags (measured, not judged by ear):
  CLIP     samples at or above -0.3 dBFS (distortion)
  SPIKE    the short-term level jumps 12 dB or more above the 3 s before it and lands above -14 dBFS (a startle)
  LOUD     a sound whose peak is 8 dB or more above that sound's median (the same effect much louder this time)
  QUIET    a sound that starts but stays under -45 dBFS in its first 0.6 s (likely inaudible)
  STACK    5 or more sounds starting within 0.5 s (a pile-up)
  (LOUD and QUIET read the whole mix after a sound starts, so music and other sounds sway them: hints, not proof)
  SILENT   a bot action that should give feedback (pinch/pick/cast/build/tap) with no sound starting within 0.4 s
"""
import re
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

run = Path(sys.argv[1])
avis = sorted(run.glob("*.avi"), key=lambda f: f.stat().st_mtime)
if not avis or not (run / "events.txt").exists():
    sys.exit("need a .avi and events.txt in %s" % run)
avi = avis[-1]
wav = run / "audio.wav"
subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(avi), "-vn", "-ac", "2", "-ar", "48000", str(wav)], check=True)
with wave.open(str(wav)) as w:
    sr = w.getframerate()
    x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).reshape(-1, 2).astype(np.float32) / 32768.0
mono = np.abs(x).max(axis=1)
dur = len(mono) / sr


def db(v):
    return 20 * np.log10(np.maximum(v, 1e-6))


hop = int(0.05 * sr)
n = len(mono) // hop
blocks = x[: n * hop].reshape(n, hop, 2)
rms = db(np.sqrt((blocks ** 2).mean(axis=(1, 2))))
peak = db(np.abs(blocks).max(axis=(1, 2)))

events = []
for line in (run / "events.txt").read_text(encoding="utf-8").splitlines():
    m = re.match(r"\s*([\d.]+)\s+(\w+)\s+(.*)", line)
    if m:
        events.append((float(m.group(1)), m.group(2), m.group(3)))
snd = [(t, rest.split(" ")[0], rest) for t, k, rest in events if k == "SND"]

flags = []


def flag(kind, t, text):
    flags.append((t, kind, text))


# CLIP
clip_blocks = np.where(peak >= -0.3)[0]
last = -10.0
for b in clip_blocks:
    t = b * 0.05
    if t - last > 2.0:
        flag("CLIP", t, "peak %.1f dBFS" % peak[b])
    last = t
# SPIKE
for b in range(60, n):
    before = max(float(np.median(rms[b - 60 : b])), -60.0)  # silence before is not a 100 dB jump
    if rms[b] - before >= 12 and rms[b] > -14:
        t = b * 0.05
        if not flags or not (flags[-1][1] == "SPIKE" and t - flags[-1][0] < 2.0):
            flag("SPIKE", t, "level %.1f dB, %.1f dB above the 3 s before" % (rms[b], rms[b] - before))
# per-sound peaks
per = {}
for t, name, rest in snd:
    b0 = int(t / 0.05)
    win = peak[b0 : b0 + 12]
    if len(win) == 0:
        continue
    per.setdefault(name, []).append((t, float(win.max()), rest))
table = []
for name, rows in sorted(per.items()):
    vals = np.array([r[1] for r in rows])
    med = float(np.median(vals))
    table.append((name, len(rows), med, float(vals.max()), float(vals.min())))
    for t, v, rest in rows:
        if v - med >= 8 and len(rows) >= 3:
            flag("LOUD", t, "%s at %.1f dBFS (its median %.1f)" % (name, v, med))
        if v < -45:
            flag("QUIET", t, "%s peaks at %.1f dBFS in its first 0.6 s (%s)" % (name, v, rest))
# STACK
ts = [s[0] for s in snd]
i = 0
last = -10
for j in range(len(ts)):
    while ts[j] - ts[i] > 0.5:
        i += 1
    if j - i + 1 >= 5 and ts[j] - last > 2.0:
        names = ", ".join(sorted({snd[k][1] for k in range(i, j + 1)}))
        flag("STACK", ts[i], "%d sounds start within 0.5 s: %s" % (j - i + 1, names))
        last = ts[j]
# SILENT actions
action = re.compile(r"(?i:ok   .*(pick|cast|build|tap|turn|hurr|choos|grab))|(cast \w+: cooldown started)|(: BUILT$)")
for t, k, rest in events:
    if k == "BOT" and action.search(rest):
        near = [s for s in ts if t - 1.2 <= s <= t + 0.4]
        if not near:
            flag("SILENT", t, rest.strip()[:110])

flags.sort()
clips = run / "clips"
clips.mkdir(exist_ok=True)
out = ["# Audio check: %s" % run.name, "",
       "Length %.0f s. Overall: median level %.1f dBFS, loudest block %.1f dBFS. Max sounds at once: %s." % (
           dur, float(np.median(rms)), float(peak.max()),
           next((l.split()[-1] for l in (run / "events.txt").read_text().splitlines() if l.startswith("MAX_CONCURRENT")), "?")),
       "", "## Flags (%d)" % len(flags), "", "| video time | flag | what | clip |", "|---|---|---|---|"]
for k, (t, kind, text) in enumerate(flags):
    clip = clips / ("%03d_%s_%06.1f.wav" % (k, kind, t))
    if kind in ("CLIP", "SPIKE", "LOUD", "STACK", "QUIET") and k < 80:
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", "%.2f" % max(0.0, t - 1.5), "-t", "4", "-i", str(wav), str(clip)], check=True)
        cname = clip.name
    else:
        cname = ""
    out.append("| %d:%05.2f | %s | %s | %s |" % (int(t // 60), t % 60, kind, text.replace("|", "/"), cname))
out += ["", "## Every sound (first 0.6 s peak, dBFS)", "", "| sound | times | median | loudest | quietest |", "|---|---|---|---|---|"]
for name, cnt, med, mx, mn in table:
    out.append("| %s | %d | %.1f | %.1f | %.1f |" % (name, cnt, med, mx, mn))
(run / "audio_report.md").write_text("\n".join(out) + "\n", encoding="utf-8")
print("flags:", {k: sum(1 for f in flags if f[1] == k) for k in ["CLIP", "SPIKE", "LOUD", "QUIET", "STACK", "SILENT"]})
