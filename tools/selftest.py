"""Run the headless game self-test and print only what matters: script errors, FAIL lines and the total.

    python tools/selftest.py            quiet: failures, errors, the "N failure(s)" line
    python tools/selftest.py --import   re-import first (needed after adding a new class_name script or asset)
    python tools/selftest.py --all      the full output, as Godot printed it

Exit code 0 only when the test printed "game_selftest: 0 failure(s)" and no script error.
"""
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ew_env  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
BAD = ("FAIL  ", "SCRIPT ERROR", "Parse Error", "ERROR:", "Invalid ", "Cannot call", "   at: ")


def run(extra):
    cmd = [ew_env.require("GODOT_EXE"), "--headless", "--xr-mode", "off", "--path", str(ROOT / "godot")] + extra
    done = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return (done.stdout or "") + (done.stderr or "")


if __name__ == "__main__":
    if "--import" in sys.argv:
        run(["--import"])
    out = run(["-s", "res://tests/game_selftest.gd"])
    if "--all" in sys.argv:
        print(out)
    lines = out.splitlines()
    bad = [l for l in lines if any(b in l for b in BAD)]
    total = [l for l in lines if l.startswith("game_selftest:")]
    for l in bad[:60]:
        print(l)
    if len(bad) > 60:
        print("... %d more lines (use --all)" % (len(bad) - 60))
    print("%d checks passed" % sum(1 for l in lines if l.startswith("PASS  ")))
    print(total[-1] if total else "game_selftest: DID NOT FINISH (no total line; run with --all)")
    sys.exit(0 if total and total[-1].strip() == "game_selftest: 0 failure(s)" and not any("SCRIPT ERROR" in l or "Parse Error" in l for l in lines) else 1)
