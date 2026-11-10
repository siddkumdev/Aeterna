"""Before/after listening files for one sound round. For each sound: <n>_<name>_A_old.wav and <n>_<name>_B_new.wav,
each = every take of the sound in a row (so the variety is heard too), loudness-matched. Loops: a 10 s excerpt.

    python tools/audio_compare.py <old_dir> <out_dir> name [name ...]     # new files are read from assets/export/audio
"""
import glob
import os
import re
import sys

import numpy as np
from scipy.io import wavfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from audio_synth import fade, n_of, write_wav  # noqa: E402

NEW = os.path.join(ROOT, "assets", "export", "audio")


def takes(folder, name):
    fs = [f for f in glob.glob(os.path.join(folder, name + "*.wav")) if re.fullmatch(re.escape(name) + r"(_\d+)?\.wav", os.path.basename(f))]
    fs.sort(key=lambda f: int(re.findall(r"_(\d+)\.wav$", f)[0]) if re.search(r"_\d+\.wav$", f) else 0)
    out = []
    for f in fs:
        sr, x = wavfile.read(f)
        x = x.astype(float) / 32768.0
        if x.ndim == 2:
            x = x.mean(axis=1)
        out.append(x)
    return out


def row(xs, gap=0.55):
    if len(xs) == 1 and len(xs[0]) > n_of(4.0):  # a loop: 10 s with soft ends
        return fade(xs[0][: n_of(10.0)].copy(), 0.3, 0.5)
    parts = []
    for x in xs:
        parts += [x, np.zeros(n_of(gap))]
    return np.concatenate(parts)


def main():
    old_dir, out_dir, names = sys.argv[1], sys.argv[2], sys.argv[3:]
    os.makedirs(out_dir, exist_ok=True)
    for i, name in enumerate(names, 1):
        for tag, folder in (("A_old", old_dir), ("B_new", NEW)):
            xs = takes(folder, name)
            if not xs:
                print("no files for", name, "in", folder)
                continue
            x = row(xs)
            loud = np.concatenate(xs)  # match loudness over the sounds themselves, not the gaps between them
            target = -24.0 if len(xs) > 1 else -28.0
            g = min(10 ** (target / 20) / (np.sqrt(np.mean(loud ** 2)) + 1e-12), 10 ** (-1.0 / 20) / (np.max(np.abs(x)) + 1e-12))
            x = x * g
            write_wav(os.path.join(out_dir, "%02d_%s_%s.wav" % (i, name, tag)), x)
        print("%02d %s" % (i, name))


if __name__ == "__main__":
    main()
