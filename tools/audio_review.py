"""First-opinion review of the game's sounds by an audio-capable model (Antigravity CLI `agy`, the user's own subscription).
The model can only listen and describe; it never makes sound. Its words are a noisy opinion (it once claimed clipping that
the measurements disproved), so every complaint is checked against tools/audio_measure.py before anything is changed.

    python tools/audio_review.py [sound ...]       # default: every one-shot in the game manifest
    python tools/audio_review.py --workers 3

Copies take 1 of each sound into _work/audio/agy_review/<sound>.wav (git-ignored, our own sounds only, never the reference
clips), asks `agy` in batches, and writes results.json (one record per sound) and results.md.
"""
import json
import os
import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
AGY = os.environ.get("AGY_EXE") or os.path.join(os.environ.get("LOCALAPPDATA", ""), "agy", "bin", "agy.exe")
WORK = os.path.join(ROOT, "_work", "audio", "agy_review")
BATCH = 4

PROMPT = """You are an experienced game sound designer reviewing short sound effects for a cozy VR tabletop game (a small wooden
village board; the target feel is warm, soft and tactile, like Townscaper or Animal Crossing). You are NOT told what each sound is
supposed to be: listen first and say what you hear. Be a critical reviewer, not a polite one: scores of 5 must be earned, and most
real sounds have a weakness. If you cannot tell, say "unclear". Only report an artifact (crunch, clipping, hiss, click, aliasing,
metallic ring) if you clearly hear it.

Files (in the current folder):
{items}

Reply with ONLY a JSON array, one object per file, in this form (no other text):
[{{"file": "name.wav", "what_it_is": "what you think the sound is, a few words", "harsh": 1-5, "full": 1-5, "cozy_fit": 1-5,
  "artifacts": "none or what you hear", "words": "one sentence in plain words", "fix": "one concrete change, e.g. softer attack, darker, shorter tail, more body, or none"}}]
Scales: harsh 1 = soft, 5 = harsh; full 1 = thin, 5 = full and rounded; cozy_fit 5 = fits a cozy wooden village game."""


def ask(files):
    """Blind: only the file names go in the prompt, never what the sound is meant to be (that primes the reviewer)."""
    items = "\n".join("- %s" % f for f in files)
    try:
        p = subprocess.run([AGY, "--mode", "plan", "-p", PROMPT.format(items=items)], cwd=WORK, capture_output=True, text=True,
                           encoding="utf-8", errors="replace", timeout=900)
        out = p.stdout
    except Exception as ex:  # a timeout or failed call loses this batch only, not the finished ones
        return [{"file": f, "error": "agy failed: %s" % type(ex).__name__} for f in files]
    recs = None
    start = out.find("[")
    while start != -1 and recs is None:
        try:
            recs, _ = json.JSONDecoder().raw_decode(out[start:])
        except ValueError:
            start = out.find("[", start + 1)
    if not isinstance(recs, list):
        return [{"file": f, "error": "no JSON in reply: " + out[-200:].replace("\n", " ")} for f in files]
    recs = [r for r in recs if isinstance(r, dict)]
    got = {r.get("file") for r in recs}
    return recs + [{"file": f, "error": "missing from the reply"} for f in files if f not in got]


def main():
    a = sys.argv[1:]
    workers = 3
    if "--workers" in a:
        i = a.index("--workers")
        workers = int(a[i + 1])
        a = a[:i] + a[i + 2:]
    if not os.path.exists(AGY):
        sys.exit("agy not found at %s (set AGY_EXE)" % AGY)
    man = json.load(open(os.path.join(ROOT, "godot", "assets", "audio", "manifest.json"), encoding="utf-8"))
    names = a or [k for k, v in sorted(man.items()) if not v.get("loop")]
    bad = [n for n in names if n not in man or man[n].get("loop")]
    if bad:
        sys.exit("not one-shot sounds in the manifest: %s" % ", ".join(bad))
    os.makedirs(WORK, exist_ok=True)
    notes = {}
    for n in names:
        fn = n + ".wav"
        shutil.copy2(os.path.join(ROOT, "godot", "assets", "audio", man[n]["files"][0]["file"]), os.path.join(WORK, fn))
        notes[fn] = man[n].get("note", "")
    files = sorted(notes)
    batches = [files[i:i + BATCH] for i in range(0, len(files), BATCH)]
    results = []
    with ThreadPoolExecutor(workers) as ex:
        for k, res in enumerate(ex.map(ask, batches)):
            results += res
            print("batch %d/%d done" % (k + 1, len(batches)), flush=True)
    json.dump(results, open(os.path.join(WORK, "results.json"), "w", encoding="utf-8"), indent=1)
    with open(os.path.join(WORK, "results.md"), "w", encoding="utf-8") as f:
        f.write("| sound | it heard | meant to be | harsh | full | cozy | artifacts | words | fix |\n" + "|---|" * 9 + "\n")
        for r in sorted(results, key=lambda r: r.get("file", "")):
            row = [r.get("file"), r.get("what_it_is", "-"), notes.get(r.get("file"), "")[:70], r.get("harsh", "-"), r.get("full", "-"),
                   r.get("cozy_fit", "-"), r.get("artifacts", r.get("error", "")), r.get("words", ""), r.get("fix", "")]
            f.write("| " + " | ".join(str(c) for c in row) + " |\n")
    print("wrote", os.path.join(WORK, "results.md"))


if __name__ == "__main__":
    main()
