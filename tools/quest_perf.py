"""Log Aeterna's performance on the Quest over a whole run, from the build already installed (no rebuild).

Every second it records, side by side:
  - the Quest compositor's own line (logcat tag VrApi: FPS, stale frames, CPU/GPU levels, app GPU time),
  - GPU counters from Meta's ovrgpuprofiler (utilisation, bus busy, vertex vs fragment time, texture stalls),
  - CPU % of the game's busiest threads (top -H), so a CPU-bound main/render thread shows up.
Writes _work/quest_perf/<stamp>.csv plus a raw log, and prints a per-10-second summary at the end.

Usage (headset plugged in, awake, worn):
  python tools/quest_perf.py --launch --seconds 150   # restarts the game, t=0 is launch, story follows the title
  python tools/quest_perf.py --seconds 120            # attach to whatever is running now
"""
import argparse
import datetime
import os
import re
import subprocess
import sys
import threading
import time

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
PKG = "com.aeterna.game"
GPU_METRICS = {  # ovrgpuprofiler ids -> short column names
    4: "gpu_util", 3: "bus_busy", 25: "t_vert", 32: "t_frag", 8: "tex_stall", 11: "sysmem_stall", 17: "shaders_busy",
}
VRAPI = re.compile(r"FPS=(\d+)/(\d+).*?Stale=(\d+).*?CPU\d*/GPU=(\d+)/(\d+).*?(?:App=([\d.]+)ms)?", re.S)


def adb(*a, **kw):
    return subprocess.run([ADB, *a], capture_output=True, text=True, errors="replace", **kw).stdout


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seconds", type=int, default=150)
    ap.add_argument("--launch", action="store_true", help="force-stop and start the game so t=0 is launch")
    args = ap.parse_args()
    if "device" not in adb("devices").split("\n", 1)[-1]:
        sys.exit("No headset: plug it in, wear it, accept the USB prompt.")
    out_dir = os.path.join(os.path.dirname(__file__), "..", "_work", "quest_perf")
    os.makedirs(out_dir, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    raw = open(os.path.join(out_dir, stamp + "_raw.txt"), "w", encoding="utf-8")
    adb("logcat", "-c")
    if args.launch:
        adb("shell", "am", "force-stop", PKG)
        adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
    t0 = time.time()
    rows = {}  # second -> dict
    lock = threading.Lock()
    procs = []  # killed at the end so no adb child keeps the console open

    def put(sec, **kv):
        with lock:
            rows.setdefault(sec, {}).update(kv)

    def logcat():
        p = subprocess.Popen([ADB, "logcat", "-v", "time", "VrApi:I", "godot:*", "*:S"], stdout=subprocess.PIPE, text=True, errors="replace")
        procs.append(p)
        for line in p.stdout:
            raw.write(line)
            sec = int(time.time() - t0)
            if "FPS=" in line:
                def f(rx):
                    m = re.search(rx, line)
                    return float(m.group(1)) if m else ""
                put(sec, fps=f(r"FPS=(\d+)/"), stale=f(r"Stale=(\d+)"), cpu_lvl=f(r"CPU\d*/GPU=(\d+)/"),
                    gpu_lvl=f(r"CPU\d*/GPU=\d+/(\d+)"), app_ms=f(r"App=([\d.]+)ms"))
            elif "godot" in line.lower():
                msg = line.split(":", 3)[-1].strip()[:80]
                with lock:
                    r = rows.setdefault(sec, {})
                    r["note"] = (r.get("note", "") + " | " + msg).strip(" |")[:200]
            if time.time() - t0 > args.seconds:
                p.kill()
                return

    def gpu():
        ids = ",".join(str(i) for i in GPU_METRICS)
        p = subprocess.Popen([ADB, "shell", f"ovrgpuprofiler -r={ids}"], stdout=subprocess.PIPE, text=True, errors="replace")
        procs.append(p)
        names = {v.lower(): k for k, v in {
            4: "GPU % Utilization", 3: "GPU % Bus Busy", 25: "% Time Shading Vertices", 32: "% Time Shading Fragments",
            8: "% Texture Fetch Stall", 11: "% Stalled on System Memory", 17: "% Shaders Busy"}.items()}
        for line in p.stdout:
            raw.write("[gpu] " + line)
            for full, mid in names.items():
                if full in line.lower():
                    v = re.findall(r"([\d.]+)\s*$", line.strip())
                    if v:
                        put(int(time.time() - t0), **{GPU_METRICS[mid]: float(v[0])})
            if time.time() - t0 > args.seconds:
                p.kill()
                return

    def cpu():
        while time.time() - t0 < args.seconds:
            pid = adb("shell", "pidof", PKG).strip()
            if pid:
                top = adb("shell", f"top -H -b -n 1 -p {pid} -o %CPU,TID,CMD")
                th = []
                for l in top.splitlines():
                    parts = l.split()
                    if len(parts) >= 3 and re.match(r"^[\d.]+$", parts[0]):
                        th.append((float(parts[0]), " ".join(parts[2:])))
                th.sort(reverse=True)
                put(int(time.time() - t0), threads=" ".join(f"{n}:{c:.0f}" for c, n in th[:3]))
            time.sleep(1.0)

    ts = [threading.Thread(target=f, daemon=True) for f in (logcat, gpu, cpu)]
    for t in ts:
        t.start()
    print(f"Recording {args.seconds} s ... play the story now. (Ctrl+C stops early.)")
    try:
        while time.time() - t0 < args.seconds + 2:
            time.sleep(1)
    except KeyboardInterrupt:
        pass
    for p in procs:
        p.kill()
    adb("shell", "pkill", "-f", "ovrgpuprofiler")  # adb side; the PC side has no pkill
    cols = ["t", "fps", "stale", "app_ms", "cpu_lvl", "gpu_lvl", *GPU_METRICS.values(), "threads", "note"]
    csv = os.path.join(out_dir, stamp + ".csv")
    with open(csv, "w", encoding="utf-8") as f:
        f.write(",".join(cols) + "\n")
        for s in sorted(rows):
            r = rows[s]
            f.write(",".join(str(s) if c == "t" else '"%s"' % str(r.get(c, "")).replace('"', "'") for c in cols) + "\n")
    raw.close()
    print(f"\nWrote {csv}\n\n  t     fps  stale app_ms gpu% frag% vert% texstall  top threads")
    for b in range(0, args.seconds + 1, 10):
        win = [rows[s] for s in range(b, b + 10) if s in rows]
        def avg(k):
            v = [w[k] for w in win if isinstance(w.get(k), (int, float))]
            return f"{sum(v) / len(v):5.1f}" if v else "    -"
        thr = next((w["threads"] for w in reversed(win) if w.get("threads")), "")
        print(f"{b:4d}s {avg('fps')} {avg('stale')} {avg('app_ms')} {avg('gpu_util')} {avg('t_frag')} {avg('t_vert')} {avg('tex_stall')}   {thr[:60]}")


if __name__ == "__main__":
    main()
