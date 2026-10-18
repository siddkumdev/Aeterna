"""Check that this machine can run the Endless Watch pipeline. Prints OK / FIX per item; exit 1 on any FIX.

    python tools/doctor.py

Checks local.env, Python and Pillow, Blender 4.5, Godot 4.7.2 (console build), the Meta XR Simulator,
Git LFS, and whether the .blend files (LFS) and the Godot import cache exist yet.
"""
import glob
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ew_env  # noqa: E402

ROOT = ew_env.ROOT
problems = 0


def report(ok, what, fix=""):
    global problems
    print(("OK   " if ok else "FIX  ") + what + ("" if ok or not fix else "\n     -> " + fix))
    problems += 0 if ok else 1


def version_of(cmd):
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        return (out.stdout + out.stderr).strip().splitlines()[0] if (out.stdout or out.stderr) else ""
    except (OSError, subprocess.TimeoutExpired) as e:
        return "ERROR " + str(e)


report(os.path.exists(ew_env.LOCAL_ENV), "local.env exists",
       "copy local.env.example to local.env and fix the paths for this machine")

report(sys.version_info >= (3, 10), "Python %d.%d" % sys.version_info[:2], "install Python 3.10 or newer")
try:
    import PIL  # noqa: F401
    report(True, "Pillow installed")
except ImportError:
    report(False, "Pillow installed", "python -m pip install pillow")

b = os.environ.get("BLENDER_EXE", "")
if os.path.exists(b):
    v = version_of([b, "--version"])
    report(v.startswith("Blender 4.5"), "Blender: " + v, "install Blender 4.5 (the generators target 4.5)")
else:
    report(False, "Blender at BLENDER_EXE (%s)" % (b or "not set"), "install Blender 4.5 or fix BLENDER_EXE in local.env")

g = os.environ.get("GODOT_EXE", "")
if os.path.exists(g):
    v = version_of([g, "--version"])
    report(v.startswith("4.7.2"), "Godot: " + v, "use Godot 4.7.2 stable (same version as the project)")
    report(g.lower().endswith("_console.exe"), "GODOT_EXE is the console build",
           "point GODOT_EXE at Godot_v4.7.2-stable_win64_console.exe (headless output needs it)")
else:
    report(False, "Godot at GODOT_EXE (%s)" % (g or "not set"), "download Godot 4.7.2 stable, set GODOT_EXE in local.env")

s = os.environ.get("META_XR_SIM_JSON", "")
report(os.path.exists(s), "Meta XR Simulator runtime (%s)" % s,
       "install Meta XR Simulator 207.1 or fix META_XR_SIM_JSON (needed only for godot\\run_sim.ps1)")

git = shutil.which("git")
report(bool(git), "git installed", "install Git for Windows")
if git:
    report("git-lfs" in version_of([git, "lfs", "version"]), "Git LFS installed",
           "install Git LFS, then run: git lfs install  and  git lfs pull")

blends = glob.glob(os.path.join(ROOT, "assets", "blend", "*.blend"))
report(bool(blends), ".blend files present (%d)" % len(blends),
       "they come through Git LFS: git lfs install, then git lfs pull")
report(os.path.isdir(os.path.join(ROOT, "godot", ".godot")), "Godot import cache (godot/.godot)",
       "python tools/sync_to_godot.py --check   (imports every model once)")

print("\n%s" % ("All good." if not problems else "%d thing(s) to fix." % problems))
sys.exit(1 if problems else 0)
