"""Look at GDScript without reading whole files (game.gd alone is over 80 KB).

    python tools/code_map.py                      sizes of every script, biggest first
    python tools/code_map.py game                 outline of game.gd: consts, vars, signals, funcs with line numbers
    python tools/code_map.py game _play_hourglass print just that function (several names allowed)
    python tools/code_map.py --find tap_villager  every file and line that defines or calls it

A file is named by any part of its path ("game" matches game.gd exactly before it matches game_config.gd).
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "godot"
SKIP = {".godot", "addons", "android"}
HEAD = re.compile(r"^(static func|func|signal|const|var|@export var|@onready var|class_name|extends|enum|class)\s+([A-Za-z_0-9]+)?")


def scripts():
    return sorted(p for p in ROOT.rglob("*.gd") if not SKIP & set(p.relative_to(ROOT).parts))


def pick(name):
    hits = [p for p in scripts() if p.stem == name] or [p for p in scripts() if name in p.as_posix()]
    if not hits:
        sys.exit("no script matches '%s'" % name)
    if len(hits) > 1:
        sys.exit("'%s' matches several: %s" % (name, ", ".join(p.relative_to(ROOT).as_posix() for p in hits)))
    return hits[0]


def sizes():
    rows = sorted(((p.stat().st_size, p) for p in scripts()), reverse=True)
    for size, p in rows:
        print("%6.1f KB  %s" % (size / 1024, p.relative_to(ROOT).as_posix()))


def outline(path):
    lines = path.read_text(encoding="utf-8").splitlines()
    print("%s  (%d lines)" % (path.relative_to(ROOT).as_posix(), len(lines)))
    for i, line in enumerate(lines, 1):
        m = HEAD.match(line)
        if not m:
            continue
        if m.group(1).endswith("func"):
            print("%5d  %s" % (i, line.rstrip(":").strip()))
        elif m.group(1) in ("const", "var", "@export var", "@onready var", "signal", "enum"):
            print("%5d  %s" % (i, line.split("#")[0].strip()[:100]))
        else:
            print("%5d  %s" % (i, line.strip()))


def body(path, names):
    lines = path.read_text(encoding="utf-8").splitlines()
    for name in names:
        start = next((i for i, l in enumerate(lines) if re.match(r"^(static )?func %s\(" % re.escape(name), l)), None)
        if start is None:
            print("-- %s: not found in %s" % (name, path.name))
            continue
        end = start + 1
        while end < len(lines) and (lines[end].startswith(("\t", " ", "#")) or lines[end].strip() == ""):
            end += 1
        while end > start + 1 and lines[end - 1].strip() == "":
            end -= 1
        print("-- %s:%d-%d" % (path.relative_to(ROOT).as_posix(), start + 1, end))
        for i in range(start, end):
            print("%5d\t%s" % (i + 1, lines[i]))


def find(word):
    pat = re.compile(r"\b%s\b" % re.escape(word))
    for p in scripts():
        for i, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
            if pat.search(line):
                print("%s:%d  %s" % (p.relative_to(ROOT).as_posix(), i, line.strip()[:110]))


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        sizes()
    elif args[0] == "--find" and len(args) == 2:
        find(args[1])
    elif len(args) == 1:
        outline(pick(args[0]))
    else:
        body(pick(args[0]), args[1:])
