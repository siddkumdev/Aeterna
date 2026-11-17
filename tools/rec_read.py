"""Read an InputRecorder file (godot/scripts/game/input_recorder.gd) on the PC.
    python tools/rec_read.py <file.bin|file.bin.gz>              # summary: length, tracking coverage, pinches
    python tools/rec_read.py <file> --csv out.csv                # head + aim poses + inputs per frame (no joints)
    python tools/rec_read.py <file> --json out.json              # everything, joints included
Python API: frames, header = load(path) -> list of dicts {t, head, hands: {left/right: {aim, grip, trigger, ...}}}.
"""
import gzip
import json
import struct
import sys

JOINTS = 26


def load(path):
    raw = (gzip.open if path.endswith(".gz") else open)(path, "rb").read()
    if raw[:8] != b"AETREC01":
        raise ValueError("not an InputRecorder file")
    n = struct.unpack("<I", raw[8:12])[0]
    header = json.loads(raw[12:12 + n])
    ff = header["frame_floats"]
    body = raw[12 + n:]
    count = len(body) // (ff * 4)
    vals = struct.unpack("<%df" % (count * ff), body[:count * ff * 4])
    frames = []
    for i in range(count):
        v = vals[i * ff:(i + 1) * ff]
        k = 8
        fr = {"t": v[0], "head": v[1:8], "hands": {}}
        for h in ("left", "right"):
            d = {"aim_ok": v[k] > 0.5, "aim": v[k + 1:k + 8], "grip_ok": v[k + 8] > 0.5, "grip": v[k + 9:k + 16],
                 "trigger": v[k + 16], "grip_val": v[k + 17], "trigger_click": v[k + 18] > 0.5, "grip_click": v[k + 19] > 0.5,
                 "hand_tracked": v[k + 20] > 0.5}
            j0 = k + 21
            d["joints"] = [v[j0 + j * 7:j0 + j * 7 + 7] for j in range(JOINTS)]
            fr["hands"][h] = d
            k = j0 + JOINTS * 7
        frames.append(fr)
    return frames, header


def main():
    path = sys.argv[1]
    frames, header = load(path)
    dur = frames[-1]["t"] if frames else 0.0
    print("%s: %d frames, %.1f s, %s Hz, device %s, started %s" % (path, len(frames), dur, header["rate_hz"], header.get("device"), header.get("started_local")))
    for h in ("left", "right"):
        tr = sum(f["hands"][h]["hand_tracked"] for f in frames)
        pin = sum(1 for a, b in zip(frames, frames[1:]) if b["hands"][h]["trigger_click"] and not a["hands"][h]["trigger_click"])
        print("  %s hand: tracked %.0f%% of frames, %d pinches" % (h, 100.0 * tr / max(1, len(frames)), pin))
    ev = path.replace(".bin.gz", "_events.jsonl").replace(".bin", "_events.jsonl")
    try:
        lines = open(ev, encoding="utf-8").read().splitlines()
        kinds = {}
        for l in lines:
            k = json.loads(l)["kind"]
            kinds[k] = kinds.get(k, 0) + 1
        print("  events:", kinds)
    except OSError:
        pass
    if "--csv" in sys.argv:
        out = sys.argv[sys.argv.index("--csv") + 1]
        with open(out, "w", encoding="utf-8") as f:
            cols = ["t"] + ["head_" + c for c in "px py pz qx qy qz qw".split()]
            for h in ("left", "right"):
                cols += ["%s_aim_%s" % (h, c) for c in "ok px py pz qx qy qz qw".split()]
                cols += ["%s_%s" % (h, c) for c in "trigger grip_val trigger_click grip_click hand_tracked".split()]
            f.write(",".join(cols) + "\n")
            for fr in frames:
                row = [fr["t"], *fr["head"]]
                for h in ("left", "right"):
                    d = fr["hands"][h]
                    row += [int(d["aim_ok"]), *d["aim"], d["trigger"], d["grip_val"], int(d["trigger_click"]), int(d["grip_click"]), int(d["hand_tracked"])]
                f.write(",".join("%.5g" % x for x in row) + "\n")
        print("wrote", out)
    if "--json" in sys.argv:
        out = sys.argv[sys.argv.index("--json") + 1]
        json.dump({"header": header, "frames": frames}, open(out, "w", encoding="utf-8"))
        print("wrote", out)


if __name__ == "__main__":
    main()
