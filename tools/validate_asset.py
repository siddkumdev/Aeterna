"""Validate an asset against project conventions. Runs inside Blender via the wrapper below.

    python tools/validate_asset.py assets/blend/house.blend

Checks: name pattern, triangle budget by category, origin at base, transforms applied,
material count, leftover modifiers, uses the palette atlas. Exit code 1 on any failure.
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

import ew_env  # noqa: E402  (local.env paths)
BLENDER = ew_env.require("BLENDER_EXE")
BUDGETS = {"world": 800, "village": 2000, "defense": 2000, "enemy": 2000, "boss": 6000,
           "portal": 2000, "vr": 800, "foresight": 800, "ui": 800, "vfx": 800}
# per-asset budgets that differ from the category default (the 12 x 12 board is one big model: ASSET_LIST W01 says 1-2k)
BUDGET_OVERRIDES = {"ew_world_island": 4000, "ew_world_path_plaza": 1500}  # lush grass (Siddharth 2026-10-20) needs ~3.5k; whole-board budget is 150k
NAME = re.compile(r"^ew_(world|village|defense|enemy|boss|portal|vr|foresight|ui|vfx)_[a-z0-9_]+_v\d{2}$")

INNER = r'''
import bpy, json, sys
res = []
for o in bpy.context.scene.objects:
    if o.type != "MESH":
        continue
    me = o.data
    me.calc_loop_triangles()
    zs = [v.co.z for v in me.vertices]
    cells = sorted({min(7, max(0, int((1 - l.uv[1]) * 8))) * 8 + min(7, max(0, int(l.uv[0] * 8)))
                    for l in me.uv_layers.active.data}) if me.uv_layers else []
    res.append(dict(name=o.name, parent=o.parent.name if o.parent else None, tris=len(me.loop_triangles), loc=list(o.location),
                    rot=list(o.rotation_euler), scale=list(o.scale), min_z=min(zs), starts_hidden=bool(o.get("ew_starts_hidden")),
                    materials=len(me.materials), modifiers=len(o.modifiers), cells=cells,
                    has_atlas=bool(me.uv_layers) and any(m and m.node_tree and any(n.type == "TEX_IMAGE" and n.image and n.image.name == "ew_palette_atlas" for n in m.node_tree.nodes) for m in me.materials)))
print("VALIDATE_JSON" + json.dumps(res))
'''


def main(blend):
    code_path = os.path.join(os.environ.get("TEMP", "."), "ew_validate_inner.py")
    open(code_path, "w").write(INNER)
    r = subprocess.run([BLENDER, "--factory-startup", "-b", os.path.abspath(blend), "-P", code_path], capture_output=True, text=True)
    line = next((l for l in r.stdout.splitlines() if l.startswith("VALIDATE_JSON")), None)
    if r.returncode != 0 or not line:
        sys.exit("blender failed:\n" + r.stdout[-1500:] + r.stderr[-1500:])
    objs = json.loads(line[len("VALIDATE_JSON"):])
    bad = []
    roots = [o for o in objs if "__" not in o["name"]]
    if len(roots) != 1:
        bad.append("expected exactly 1 root mesh object, found %d" % len(roots))
    root = roots[0]["name"] if roots else ""
    total = sum(o["tris"] for o in objs)
    for o in objs:
        n = o["name"]
        is_part = "__" in n  # separate moving part: <root>__<part>, parented, origin at its pivot
        if not NAME.match(n.split("__")[0]):
            bad.append("%s: name must match ew_<category>_<name>_v<NN>" % n)
        if is_part:
            if not n.startswith(root + "__") or not re.match(r"^[a-z0-9_]+$", n.split("__", 1)[1]):
                bad.append("%s: part name must be %s__<part>" % (n, root))
            if not o["parent"] or not o["parent"].startswith(root):
                bad.append("%s: part must be parented to the asset" % n)
            hidden_ok = o.get("starts_hidden") and len(set(round(s, 6) for s in o["scale"])) == 1 and o["scale"][0] <= 0.01
            if any(abs(v) > 1e-4 for v in o["rot"]) or (any(abs(s - 1) > 1e-4 for s in o["scale"]) and not hidden_ok):
                bad.append("%s: part rotation/scale not applied" % n)
            # a part tagged ew_starts_hidden (e.g. rubble that appears when a house breaks) may carry a tiny
            # uniform scale: Godot grows it to its "<part>_broken" marker's scale
        else:
            if any(abs(v) > 1e-4 for v in o["loc"] + o["rot"]) or any(abs(s - 1) > 1e-4 for s in o["scale"]):
                bad.append("%s: transforms not applied / object not at origin" % n)
            if abs(o["min_z"]) > 1e-3:
                bad.append("%s: origin not at base (min z = %.4f)" % (n, o["min_z"]))
        if o["modifiers"]:
            bad.append("%s: %d leftover modifiers" % (n, o["modifiers"]))
        if o["materials"] > 2:
            bad.append("%s: %d materials (keep to 1-2)" % (n, o["materials"]))
        if not o["has_atlas"]:
            bad.append("%s: not using the palette atlas (UVs + ew_palette_atlas material)" % n)
        print("%s: %d tris, %d materials" % (n, o["tris"], o["materials"]))
    cat = root.split("_")[1] if root.startswith("ew_") else None
    budget = BUDGETS.get(cat)
    for prefix, limit in BUDGET_OVERRIDES.items():
        if root.startswith(prefix + "_v"):
            budget = limit
    print("total: %d tris (budget %s)" % (total, budget))
    if budget and total > budget:
        bad.append("%s: %d tris in total > budget %d for '%s'" % (root, total, budget, cat))
    pal = json.load(open(os.path.join(ROOT, "art", "palette.json"), encoding="utf-8"))
    names = list(pal["materials"])
    used = {names[c] for o in objs for c in o.get("cells", []) if c < len(names)}
    print("colours: " + ", ".join(sorted(used)))
    for r in sorted(used & set(pal.get("retired", []))):
        print("WARNING: uses retired colour '%s' (see art/palette.json 'retired')" % r)
    print("FAIL" if bad else "OK")
    for b in bad:
        print(" -", b)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
