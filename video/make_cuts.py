"""Turn the storyboard (cut_spec.json: clips tied to game events) into src/cuts.json (seconds in raw.mp4),
using the events log the bot run writes (events.txt). The same edit then fits any take of the showcase run.

    python video/make_cuts.py <run dir with events.txt>
"""
import json
import re
import sys
from pathlib import Path

run = Path(sys.argv[1])
here = Path(__file__).parent
ev = (run / "events.txt").read_text(encoding="utf-8").splitlines()

anchors: dict[str, float] = {}


def put(name: str, t: float) -> None:
    anchors.setdefault(name, t)


casts = 0
builds = 0
for line in ev:
    m = re.match(r"\s*([\d.]+)\s+(\w+)\s+(.*)", line)
    if not m:
        continue
    t, kind, rest = float(m.group(1)), m.group(2), m.group(3)
    if kind == "PHASE":
        ph, night, loop = re.findall(r"-?\d+", rest)[:3]
        if loop == "0" and ph == "0" and night == "0":
            put("day1", t)
        if loop == "0" and ph == "1" and night == "0":
            put("night1", t)
        if loop == "0" and ph == "0" and night == "1":
            put("dawn2", t)
        if loop == "0" and ph == "1" and night == "1":
            put("night2", t)
        if loop == "0" and ph == "2":
            put("lost", t)
        if loop == "1":
            put("loop2", t)
    elif kind == "MSG" and rest.startswith("Grab the hourglass"):
        put("hourglass", t)
    elif kind == "BOT":
        bt = t
        if "quest prayer: DONE" in rest:
            put("prayer_done", bt)
        if "quest warm: DONE" in rest:
            put("warm_done", bt)
        if "BUILT" in rest:
            builds += 1
            put(f"build{builds}", bt)
        if "cast " in rest and ": ok" in rest:
            casts += 1
            put(f"cast{casts}", bt)

spec = json.loads((here / "cut_spec.json").read_text(encoding="utf-8"))
dur = float(spec.get("_footage_len", 1e9))
out: dict[str, list] = {}
missing = []
for sec, cuts in spec.items():
    if sec.startswith("_"):
        continue
    out[sec] = []
    for c in cuts:
        a = c["at"]
        if a not in anchors:
            missing.append(a)
            continue
        cut = {"from": round(max(0.0, anchors[a] + c.get("off", 0.0)), 2), "len": c["len"]}
        if "caption" in c:
            cut["caption"] = c["caption"]
        out[sec].append(cut)
# each clip becomes its own short file (Remotion cannot seek reliably far into the long take)
import subprocess
clips = here / "public" / "footage" / "clips"
clips.mkdir(parents=True, exist_ok=True)
for old in clips.glob("*.mp4"):
    old.unlink()
raw = run / "raw.mp4"
for sec, cuts in out.items():
    for i, c in enumerate(cuts):
        name = f"{sec}_{i}.mp4"
        ln = max(float(c["len"]), 6.0 if sec == "titlePlate" else 0.0) + 0.5
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(c["from"]), "-i", str(raw), "-t", f"{ln:.2f}",
                        "-vf", "fps=30", "-c:v", "libx264", "-crf", "16", "-preset", "veryfast", "-g", "15",
                        "-pix_fmt", "yuv420p", "-af", "volume=3.0,alimiter=limit=0.89", "-c:a", "aac", "-b:a", "192k", "-ar", "48000", str(clips / name)], check=True)
        c["src"] = f"footage/clips/{name}"
(here / "src" / "cuts.json").write_text(json.dumps(out, indent=1), encoding="utf-8")
print("anchors:", {k: round(v, 1) for k, v in anchors.items()})
total = sum(c["len"] for s in out.values() for c in s)
print(f"footage seconds used: {total:.1f}; missing anchors: {missing or 'none'}")
