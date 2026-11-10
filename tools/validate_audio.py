"""Check the generated sounds and draw a picture sheet of them (Claude cannot listen, so this is how it looks at them).

    python tools/validate_audio.py                      # checks every file in assets/export/audio/ against manifest.json
    python tools/validate_audio.py --sheet out.png      # also a sheet: waveform on top, spectrogram below, one cell per sound
    python tools/validate_audio.py --sheet out.png name1 name2     # only some sounds in the sheet

Checks per file: not silent, no clipping (peak under -1 dBFS), no DC offset, a quiet first sample (no click at the start),
a short sound ends quietly, a loop's seam is no bigger a jump than the signal makes anyway, the length suits its kind.
"""
import json
import os
import sys

import numpy as np
from scipy import signal
from scipy.io import wavfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
DIR = os.path.join(ROOT, "assets", "export", "audio")


def load(path):
    sr, x = wavfile.read(path)
    return sr, x.astype(np.float64) / 32768.0


def check(name, spec, fspec):
    sr, x = load(os.path.join(DIR, fspec["file"]))
    mono = x if x.ndim == 1 else x.mean(axis=1)
    problems = []
    peak = np.max(np.abs(x))
    if peak < 0.01 and not spec.get("note", "").startswith("SILENT on purpose"):  # enemy_death, build_pop (2026-11-10)
        problems.append("silent")
    if peak > 10 ** (-1.0 / 20):
        problems.append("peak above -1 dBFS")
    if abs(np.mean(mono)) > 0.01:
        problems.append("DC offset %.3f" % np.mean(mono))
    secs = len(x) / sr
    if spec["loop"]:
        if fspec["seam"] is not None and fspec["seam"] > 3.0:
            problems.append("loop seam jump %.1f x normal" % fspec["seam"])
        if secs < 1.0:
            problems.append("loop shorter than 1 s")
    else:
        if abs(mono[0]) > 0.03 * peak + 1e-4:
            problems.append("click at the start (%.3f)" % abs(mono[0]))
        if abs(mono[-1]) > 0.01 * peak + 1e-4:
            problems.append("does not end quiet (%.3f)" % abs(mono[-1]))
        limit = 6.0 if spec["bus"] != "ambience" else 30.0
        if secs > limit:
            problems.append("long (%.1f s)" % secs)
    return problems, secs, peak


def sheet(names, manifest, out_path):
    from PIL import Image, ImageDraw
    cell_w, cell_h = 420, 150
    cols = 4
    items = []
    for name in names:
        for f in manifest[name]["files"]:
            items.append((f["file"], f))
    rows = (len(items) + cols - 1) // cols
    img = Image.new("RGB", (cols * cell_w, rows * cell_h), (20, 22, 30))
    d = ImageDraw.Draw(img)
    for i, (fn, f) in enumerate(items):
        sr, x = load(os.path.join(DIR, fn))
        mono = x if x.ndim == 1 else x.mean(axis=1)
        ox, oy = (i % cols) * cell_w, (i // cols) * cell_h
        w = cell_w - 8
        # waveform (top 45 px)
        n = len(mono)
        bins = np.array_split(np.arange(n), w)
        mid = oy + 30
        for k, b in enumerate(bins):
            if len(b) == 0:
                continue
            a = float(np.max(np.abs(mono[b])))
            h = int(a * 24)
            d.line([(ox + 4 + k, mid - h), (ox + 4 + k, mid + h)], fill=(120, 200, 255))
        # spectrogram (below, 85 px), 0 to 12 kHz
        nper = 512
        fr, tt, sp = signal.spectrogram(mono, sr, nperseg=nper, noverlap=nper * 3 // 4)
        keep = fr <= 12000
        sp = 10 * np.log10(sp[keep] + 1e-12)
        sp = np.clip((sp - (sp.max() - 70)) / 70, 0, 1)
        sp_img = Image.fromarray(np.uint8(sp[::-1] * 255)).resize((w, 80), Image.BILINEAR)
        arr = np.array(sp_img, dtype=np.float32) / 255.0
        rgb = np.stack([np.clip(arr * 2.2, 0, 1), np.clip(arr * 1.6 - 0.25, 0, 1), np.clip(arr * 0.9, 0, 1) * 0.6], axis=2)
        img.paste(Image.fromarray(np.uint8(rgb * 255)), (ox + 4, oy + 60))
        d.text((ox + 6, oy + 2), "%s  %.2fs  pk %.0f" % (fn[:-4], len(mono) / sr, f["peak_db"]), fill=(255, 220, 140))
        d.rectangle([ox, oy, ox + cell_w - 1, oy + cell_h - 1], outline=(50, 55, 70))
    img.save(out_path)
    print("sheet:", out_path, img.size)


def main():
    argv = sys.argv[1:]
    out = None
    if "--sheet" in argv:
        out = argv[argv.index("--sheet") + 1]
        argv = [a for i, a in enumerate(argv) if a != "--sheet" and (i == 0 or argv[i - 1] != "--sheet")]
    manifest = json.load(open(os.path.join(DIR, "manifest.json"), encoding="utf-8"))
    names = argv or sorted(manifest)
    bad = 0
    total = 0
    for name in names:
        spec = manifest[name]
        for f in spec["files"]:
            total += 1
            problems, secs, peak = check(name, spec, f)
            if problems:
                bad += 1
                print("FAIL %-22s %s" % (f["file"], "; ".join(problems)))
    print("%d sounds, %d with problems" % (total, bad))
    if out:
        sheet(names, manifest, out)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
