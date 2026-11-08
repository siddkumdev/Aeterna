"""Screen the grain kits with earshot: rank each kit's grains against a plain description and mark the worst ones
"keep": false in assets/audio_src/grains/grains.json (the recipes only draw kept grains). A coarse filter for bad cuts
(a cough, a double hit, the wrong noise), NOT a quality score to tune sounds against.

    python tools/audio_grain_screen.py [kit ...]     # needs earshot on PATH (~/.local/bin)
"""
import glob
import json
import os
import shutil
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
GR = os.path.join(ROOT, "assets", "audio_src", "grains")
KEEP = 0.6  # fraction of each kit kept
MIN_KEEP = 4

DESCRIBE = {
    "wood_knock": "a single knock on wood",
    "chess": "a single wooden game piece set down on a wooden board",
    "blocks": "wooden toy blocks clattering",
    "stone": "a stone knocking on stones",
    "door": "a wooden door closing with a latch",
    "whoosh": "a fast whoosh of air",
    "squish": "a wet squelch",
    "dirt": "digging in soil and leaves",
    "glass": "glass breaking",
    "hammer": "a hammer hitting wood",
    "steps": "a footstep on wood",
    "thunder": "a rumble of thunder",
    "cannon": "a distant cannon shot",
    "bow": "a bowstring released, an arrow shot",
    "creature": "a monster growl",
    "owl": "an owl hooting",
    "sheep_bells": "sheep bells tinkling",
    "sheep": "a sheep bleating",
}
PHRASE_KITS = {"owl", "sheep_bells", "sheep"}  # several onsets per grain is normal there: no double-hit rule


def double_hit(path):
    """A second hit more than 60 ms in and within 10 dB of the main one: a double tap, not a single hit."""
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import numpy as np
    from scipy.io import wavfile
    import audio_grains as G
    x = wavfile.read(path)[1].astype(float) / 32768.0
    at, db, hop = G.onsets(x)
    return any(a > 0.06 * G.SR and db[a // hop: a // hop + 20].max() > db.max() - 10 for a in at)


def main():
    exe = shutil.which("earshot") or os.path.join(os.path.expanduser("~"), ".local", "bin", "earshot.exe")
    index_path = os.path.join(GR, "grains.json")
    index = json.load(open(index_path, encoding="utf-8"))
    kits = sys.argv[1:] or list(index)
    for kit in kits:
        files = sorted(glob.glob(os.path.join(GR, kit, "*.wav")))
        if not files:
            continue
        ranked = []
        if os.path.exists(exe):
            p = subprocess.run([exe, "rank", DESCRIBE[kit], *files, "--json"], capture_output=True, text=True)
            try:
                res = json.loads(p.stdout[p.stdout.index("{"):])
                ranked = [os.path.basename(x.get("path") or x.get("name") or "") for x in (res.get("ranked") or res.get("results") or [])]
            except ValueError:
                print(kit, "earshot failed (only the double-hit rule applied):", p.stderr[-300:])
        else:
            print(kit, "earshot not found (only the double-hit rule applied)")
        n_keep = max(MIN_KEEP, int(round(len(ranked) * KEEP)))
        keep = set(ranked[:n_keep])
        for e in index.get(kit, []):
            e["keep"] = (e["file"] in keep if ranked else True) and (kit in PHRASE_KITS or not double_hit(os.path.join(GR, kit, e["file"])))
            e["rank"] = ranked.index(e["file"]) + 1 if e["file"] in ranked else None
        print("%-11s kept %d of %d" % (kit, sum(1 for e in index.get(kit, []) if e["keep"]), len(index.get(kit, []))))
        json.dump(index, open(index_path, "w", encoding="utf-8"), indent=1)


if __name__ == "__main__":
    main()
