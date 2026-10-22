"""Machine-specific paths for the Aeterna tools.

Each person keeps their own `local.env` at the repo root (git-ignored; copy `local.env.example`).
Lines are KEY=VALUE; `#` starts a comment. A variable already set in the environment wins.

    BLENDER_EXE        Blender 4.5 blender.exe
    GODOT_EXE          Godot 4.7.2 *_console.exe (the console build, so headless output is visible)
    META_XR_SIM_JSON   Meta XR Simulator runtime json (only godot/run_sim.ps1 uses it, per process)

Importing this module loads the file into os.environ, so tools can read os.environ["BLENDER_EXE"].
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCAL_ENV = os.path.join(ROOT, "local.env")
DEFAULTS = {  # standard install locations; Godot is a portable download, so it has no default
    "BLENDER_EXE": r"C:\Program Files\Blender Foundation\Blender 4.5\blender.exe",
    "META_XR_SIM_JSON": r"C:\Program Files\MetaXRSimulator\v207.1\meta_openxr_simulator.json",
}


def read_local_env(path=LOCAL_ENV):
    values = {}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    values[k.strip()] = v.strip().strip('"')
    return values


def load():
    for k, v in read_local_env().items():
        os.environ.setdefault(k, v)
    for k, v in DEFAULTS.items():
        os.environ.setdefault(k, v)


def require(key):
    """The value of key, or exit with a message saying where to set it."""
    v = os.environ.get(key, "")
    if not v:
        raise SystemExit("%s is not set: add it to local.env at the repo root (see local.env.example), "
                         "then run python tools/doctor.py" % key)
    return v


load()
