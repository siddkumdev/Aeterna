"""Change the palette safely: propose, show Siddharth, apply only after his OK.

    python tools/palette_change.py usage                      which colours each exported asset uses
    python tools/palette_change.py propose art/palette_proposal.json
    python tools/palette_change.py apply                      ONLY after Siddharth said OK
    python tools/palette_change.py atlas                      rebuild art/palette_atlas.png from palette.json

Proposal file (JSON):
    {"reason": "why", "add": {"moss_green": "6E8B3D"}, "edit": {"grass": "8BB85A"}, "retire": ["crystal_blue"]}
Rules (Siddharth, 2026-10-17):
- add: appended at the END of "materials" (atlas cell = order, so nothing already built shifts).
- edit: an existing colour's hex may change, but only after a before/after of every built asset using it.
- retire: the colour keeps its slot and hex; it is listed in "retired" and the validator warns if used.
- Never delete or reorder colours. Max 64 colours (8 x 8 atlas).
propose writes art/palette_proposed.json, its atlas, art/palette_preview_proposed.png (changes outlined
in red) and, when an existing colour changes, the diorama with the proposed palette
(assets/previews/diorama/<layout>_proposed/). apply copies the proposal into palette.json, rebuilds the
atlas and the swatch sheet, and lists the assets to re-export.
"""
import datetime
import glob
import json
import os
import re
import shutil
import struct
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PAL = os.path.join(ROOT, "art", "palette.json")
ATLAS = os.path.join(ROOT, "art", "palette_atlas.png")
PROPOSED = os.path.join(ROOT, "art", "palette_proposed.json")
PROPOSED_ATLAS = os.path.join(ROOT, "art", "palette_proposed_atlas.png")
PROPOSED_SHEET = os.path.join(ROOT, "art", "palette_preview_proposed.png")
PROPOSAL_META = os.path.join(ROOT, "art", "palette_proposed_changes.json")
COLS, CELL, MAX = 8, 16, 64  # must match tools/blender_common.py
HEX = re.compile(r"^[0-9A-Fa-f]{6}$")


def load(p):
    return json.load(open(p, encoding="utf-8"))


def save(p, d):
    with open(p, "w", encoding="utf-8") as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
        f.write("\n")


def make_atlas(pal, path):
    """Same layout as blender_common.atlas_image(): 8 x 8 cells of 16 px, cell index = order in materials."""
    names = list(pal["materials"])
    img = Image.new("RGB", (COLS * CELL, COLS * CELL), (0, 0, 0))
    for i, n in enumerate(names):
        hx = pal["materials"][n].lstrip("#")
        x, y = (i % COLS) * CELL, (i // COLS) * CELL
        img.paste(tuple(int(hx[k:k + 2], 16) for k in (0, 2, 4)), (x, y, x + CELL, y + CELL))
    img.save(path)


def glb_cells(path):
    """Atlas cells used by an exported .glb, from its TEXCOORD_0 data (glTF v runs top-down)."""
    b = open(path, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + n])
    off = 20 + n
    bin_len = struct.unpack("<I", b[off:off + 4])[0]
    data = b[off + 8:off + 8 + bin_len]
    cells = set()
    for mesh in j.get("meshes", []):
        for prim in mesh["primitives"]:
            a = prim["attributes"].get("TEXCOORD_0")
            if a is None:
                continue
            acc = j["accessors"][a]
            bv = j["bufferViews"][acc["bufferView"]]
            start = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
            stride = bv.get("byteStride", 8)
            for i in range(acc["count"]):
                u, v = struct.unpack_from("<ff", data, start + i * stride)
                cells.add(min(COLS - 1, max(0, int(v * COLS))) * COLS + min(COLS - 1, max(0, int(u * COLS))))
    return cells


def latest_exports():
    """Newest version of each exported asset (older versions are history, not shipped)."""
    best = {}
    for p in glob.glob(os.path.join(ROOT, "assets", "export", "*", "ew_*_v*.glb")):
        base, ver = os.path.basename(p)[:-4].rsplit("_v", 1)
        if base not in best or int(ver) > best[base][0]:
            best[base] = (int(ver), p)
    return sorted(p for _, p in best.values())


def usage(pal):
    names = list(pal["materials"])
    out = {}
    for p in latest_exports():
        out[os.path.basename(p)[:-4]] = sorted(names[c] if c < len(names) else "EMPTY_CELL_%d" % c for c in glb_cells(p))
    return out


def cmd_usage():
    pal = load(PAL)
    use = usage(pal)
    for asset, cols in use.items():
        print("%-36s %s" % (asset, ", ".join(cols)))
    unused = [n for n in pal["materials"] if not any(n in c for c in use.values())]
    print("\nnot used by any exported asset yet: " + ", ".join(unused))
    bad = [n for n in pal.get("retired", []) if any(n in c for c in use.values())]
    if bad:
        print("WARNING retired colours still used: " + ", ".join(bad))


def cmd_propose(proposal_path):
    pal = load(PAL)
    prop = load(proposal_path)
    add, edit, retire = prop.get("add", {}), prop.get("edit", {}), prop.get("retire", [])
    errs = []
    for k, v in list(add.items()) + list(edit.items()):
        if not HEX.match(v.lstrip("#")):
            errs.append("%s: '%s' is not a 6-digit hex colour" % (k, v))
    for k in add:
        if k in pal["materials"]:
            errs.append("add %s: name already exists (use edit)" % k)
        if not re.match(r"^[a-z][a-z0-9_]*$", k):
            errs.append("add %s: use lower_snake_case names" % k)
    for k in list(edit) + list(retire):
        if k not in pal["materials"]:
            errs.append("%s: no such colour" % k)
    if len(pal["materials"]) + len(add) > MAX:
        errs.append("atlas full: %d + %d > %d colours" % (len(pal["materials"]), len(add), MAX))
    if errs:
        sys.exit("proposal rejected:\n  " + "\n  ".join(errs))

    new = json.loads(json.dumps(pal))
    marks = {}
    for k, v in edit.items():
        marks[k] = ("changed", pal["materials"][k])
        new["materials"][k] = v.lstrip("#").upper()
    for k, v in add.items():
        new["materials"][k] = v.lstrip("#").upper()
        marks[k] = ("new", None)
    for k in retire:
        new.setdefault("retired", [])
        if k not in new["retired"]:
            new["retired"].append(k)
        marks[k] = ("retired", None)
    save(PROPOSED, new)
    make_atlas(new, PROPOSED_ATLAS)
    sys.path.insert(0, HERE)
    import make_palette_preview
    make_palette_preview.main(PROPOSED_SHEET, PROPOSED, marks)

    use = usage(pal)
    affected = {a: sorted(set(c) & (set(edit) | set(retire))) for a, c in use.items()}
    affected = {a: c for a, c in affected.items() if c}
    save(PROPOSAL_META, {"reason": prop.get("reason", ""), "add": add, "edit": edit, "retire": retire,
                         "affected": affected, "proposal_file": os.path.relpath(proposal_path, ROOT)})
    print("proposal OK: %d new, %d changed, %d retired (%d colours after)" % (len(add), len(edit), len(retire), len(new["materials"])))
    for k, (kind, old) in marks.items():
        print("  %-8s %-18s %s%s" % (kind, k, new["materials"][k], "  (was %s)" % old if old else ""))
    print("built assets using a changed/retired colour:" + ("" if affected else " none"))
    for a, c in affected.items():
        print("  %s: %s" % (a, ", ".join(c)))
    print("swatch sheet:", os.path.relpath(PROPOSED_SHEET, ROOT))
    sys.stdout.flush()
    if edit:
        env = dict(os.environ, EW_PALETTE_JSON=PROPOSED)
        layout = os.path.join(ROOT, "assets", "diorama", "layout_mock.json")
        out = os.path.join(ROOT, "assets", "previews", "diorama", "layout_mock_proposed")
        r = subprocess.run([sys.executable, os.path.join(HERE, "render_diorama.py"), layout, out], env=env)
        if r.returncode == 0:
            print("diorama AFTER:", os.path.relpath(os.path.join(out, "diorama.png"), ROOT),
                  " BEFORE: assets/previews/diorama/layout_mock/diorama.png (re-render with python tools/render_diorama.py if stale)")
    print("\nShow Siddharth; run 'python tools/palette_change.py apply' only after he says OK.")


def cmd_apply():
    if not os.path.exists(PROPOSED):
        sys.exit("no proposal to apply (run propose first)")
    meta = load(PROPOSAL_META)
    new = load(PROPOSED)
    old = load(PAL)
    if list(new["materials"])[:len(old["materials"])] != list(old["materials"]):
        sys.exit("refusing: the proposal reorders or removes colours (palette.json changed since propose?)")
    stamp = datetime.date.today().isoformat()
    shutil.copy2(PAL, os.path.join(ROOT, "art", "palette_backup_%s.json" % datetime.datetime.now().strftime("%Y%m%d_%H%M%S")))
    parts = []
    if meta["add"]:
        parts.append("added " + ", ".join(meta["add"]))
    if meta["edit"]:
        parts.append("changed " + ", ".join("%s %s->%s" % (k, old["materials"][k], new["materials"][k]) for k in meta["edit"]))
    if meta["retire"]:
        parts.append("retired " + ", ".join(meta["retire"]))
    new["_status"] = new["_status"].rstrip() + " %s: %s, APPROVED by Siddharth (%s)." % (stamp, "; ".join(parts), meta["reason"] or "no reason given")
    save(PAL, new)
    make_atlas(new, ATLAS)
    sys.path.insert(0, HERE)
    import make_palette_preview
    make_palette_preview.main(os.path.join(ROOT, "art", "palette_preview.png"))
    for p in (PROPOSED, PROPOSED_ATLAS, PROPOSED_SHEET, PROPOSAL_META):
        if os.path.exists(p):
            os.remove(p)
    print("applied: " + "; ".join(parts))
    print("wrote art/palette.json, art/palette_atlas.png, art/palette_preview.png (old palette backed up in art/)")
    if meta["affected"]:
        print("re-export these (their .glb files carry the old colours):")
        for a in meta["affected"]:
            print("  " + a)
    print("then: python tools/sync_to_godot.py --check   (copies the new atlas into Godot)")


if __name__ == "__main__":
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__)
    if a[0] == "usage":
        cmd_usage()
    elif a[0] == "propose" and len(a) > 1:
        cmd_propose(a[1])
    elif a[0] == "apply":
        cmd_apply()
    elif a[0] == "atlas":
        make_atlas(load(PAL), ATLAS)
        print("wrote", ATLAS)
    else:
        sys.exit(__doc__)
