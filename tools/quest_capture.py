"""Pull everything we may need later from the Quest 3 (sykeriin, 2026-11-17: last session with the headset).
Run with the headset plugged in (USB) and awake. Safe to run more than once; each run makes a new folder.
    python tools/quest_capture.py            # device facts + logs + the game's input recordings
    python tools/quest_capture.py --no-rec   # device facts + logs only
Writes:
    quest_data/<stamp>/device/*.txt     properties, display, GPU, CPU, memory, thermal, battery, features, package, log
    quest_data/recordings/*.bin.gz      InputRecorder runs (head + hands + buttons), plus *_events.jsonl
Recordings already pulled are skipped. Read one with: python tools/rec_read.py quest_data/recordings/<file>.bin.gz
"""
import gzip
import os
import subprocess
import sys
import time

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
PKG = "com.aeterna.game"
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "quest_data")

SHELL = {  # file name -> shell command on the headset
    "getprop": "getprop",
    "display": "dumpsys display",
    "surfaceflinger": "dumpsys SurfaceFlinger",
    "gpu_info": "ovrgpuprofiler -i",
    "gpu_metrics_list": "ovrgpuprofiler -m",
    "cpuinfo": "cat /proc/cpuinfo",
    "cpu_freqs": "for c in /sys/devices/system/cpu/cpu[0-9]*; do echo $c $(cat $c/cpufreq/scaling_available_frequencies 2>/dev/null) max=$(cat $c/cpufreq/cpuinfo_max_freq 2>/dev/null); done",
    "meminfo": "cat /proc/meminfo",
    "app_meminfo": "dumpsys meminfo " + PKG,
    "app_gfxinfo": "dumpsys gfxinfo " + PKG,
    "app_package": "dumpsys package " + PKG,
    "thermal": "dumpsys thermalservice",
    "battery": "dumpsys battery",
    "power": "dumpsys power",
    "features": "pm list features",
    "packages": "pm list packages -f",
    "wm": "wm size; wm density",
    "storage": "df -h",
    "openxr_runtime": "ls -la /system/etc/openxr /vendor/etc/openxr 2>/dev/null; cat /system/etc/openxr/*/active_runtime*.json /vendor/etc/openxr/*/active_runtime*.json 2>/dev/null",
    "vrapi_props": "getprop | grep -iE 'vr|xr|oculus|meta|hand|refresh|debug.oculus'",
    "uptime": "uptime; date",
}


def adb(*a, binary=False):
    r = subprocess.run([ADB, *a], capture_output=True)
    return r.stdout if binary else r.stdout.decode("utf-8", "replace")


def main():
    devs = [l for l in adb("devices").splitlines()[1:] if l.strip().endswith("device")]
    if not devs:
        sys.exit("No headset: plug it in, put it on (or cover the sensor) and accept the USB prompt.")
    stamp = time.strftime("%Y-%m-%d_%H-%M-%S")
    dev_dir = os.path.join(ROOT, stamp, "device")
    os.makedirs(dev_dir, exist_ok=True)
    for name, cmd in SHELL.items():
        with open(os.path.join(dev_dir, name + ".txt"), "w", encoding="utf-8") as f:
            f.write(adb("shell", cmd))
    with open(os.path.join(dev_dir, "logcat_full.txt"), "w", encoding="utf-8") as f:
        f.write(adb("logcat", "-d", "-v", "time"))
    for src in ("_work/quest_log.txt",):  # quest_build.bat's live log, if it ran
        p = os.path.join(os.path.dirname(ROOT), src)
        if os.path.exists(p):
            with open(p, "rb") as a, open(os.path.join(dev_dir, "quest_build_log.txt"), "wb") as b:
                b.write(a.read())
    print("device facts ->", os.path.relpath(dev_dir))
    if "--no-rec" in sys.argv:
        return
    rec_dir = os.path.join(ROOT, "recordings")
    os.makedirs(rec_dir, exist_ok=True)
    names = adb("shell", "run-as", PKG, "ls", "files/rec").split()
    if not names:
        print("no recordings on the headset (files/rec is empty or the build is not debuggable)")
    for n in names:
        out = os.path.join(rec_dir, n + (".gz" if n.endswith(".bin") else ""))
        if os.path.exists(out) and not n.endswith("_events.jsonl"):
            continue
        data = adb("exec-out", "run-as", PKG, "cat", "files/rec/" + n, binary=True)
        if n.endswith(".bin"):
            with gzip.open(out, "wb", compresslevel=6) as f:
                f.write(data)
        else:
            with open(out, "wb") as f:
                f.write(data)
        print("  %s  %.1f MB raw -> %.1f MB" % (n, len(data) / 1e6, os.path.getsize(out) / 1e6))
    print("recordings ->", os.path.relpath(rec_dir))


if __name__ == "__main__":
    main()
