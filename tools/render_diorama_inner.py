"""Diorama shot: place exported assets on the 12 x 12 board from a layout file and render review views.
Runs inside Blender (started empty). Use the wrapper: python tools/render_diorama.py

    blender --factory-startup -b -P tools/render_diorama_inner.py -- LAYOUT.json OUT_DIR

Views per lighting preset: player (seated, ~50 cm from the board centre, looking down), top-down,
and one close-up per placed asset. Writes PNGs plus stats.json (triangles, objects, material slots).
The board here is a plain review stage (grass slab with a cell grid), not the island asset.
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_common as bc  # noqa: E402
import ew_render as er  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
layout_path, out = os.path.abspath(args[0]), os.path.abspath(args[1])
os.makedirs(out, exist_ok=True)
layout = json.load(open(layout_path, encoding="utf-8"))
N = layout.get("board_cells", 12)
C = bc.CELL
HALF = N * C / 2

bc.clear_scene()
scene = bpy.context.scene
engine = er.setup_engine(scene)

# ---- review stage: grass slab with a faint cell grid --------------------------------------------
stage = [bc.box("stage", (N * C, N * C, 0.012), (0, 0, -0.006), "grass"),
         bc.box("stage_edge", (N * C + 0.006, N * C + 0.006, 0.010), (0, 0, -0.011), "stone_dark")]
for i in range(N + 1):
    t = -HALF + i * C
    stage.append(bc.box("grid", (0.0008, N * C, 0.0003), (t, 0, 0.00015), "leaf_green"))
    stage.append(bc.box("grid", (N * C, 0.0008, 0.0003), (0, t, 0.00015), "leaf_green"))
stage_names = {o.name for o in stage}

# ---- place the real assets ---------------------------------------------------------------------
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
placed = []
for p in layout["placements"]:
    path = p.get("asset")
    if not path:
        continue
    full = os.path.join(root, path)
    if not os.path.exists(full):
        print("MISSING", path)
        continue
    before = set(scene.objects)
    bpy.ops.import_scene.gltf(filepath=full)
    new = [o for o in scene.objects if o not in before]
    tops = [o for o in new if o.parent is None or o.parent not in new]
    w, h = p.get("footprint", [1, 1])
    cx = -HALF + (p["cell"][0] + w / 2) * C
    cy = -HALF + (p["cell"][1] + h / 2) * C
    for t in tops:
        t.location = (cx, cy, 0)
        t.rotation_euler = (0, 0, math.radians(p.get("rot", 0)))
    bpy.context.view_layer.update()
    meshes = [o for o in new if o.type == "MESH"]
    zmax = max((o.matrix_world @ Vector(c)).z for o in meshes for c in o.bound_box) if meshes else 0.1
    placed.append(dict(label=p.get("label", os.path.basename(path)), asset=path, objects=new,
                       centre=(cx, cy), height=zmax))

# ---- proposed palette preview: swap the atlas copy embedded in each imported model ---------------
if os.environ.get("EW_PALETTE_JSON"):
    atlas = bc.atlas_image()
    for m in bpy.data.materials:
        if m.node_tree:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image and n.image != atlas:
                    n.image = atlas
    print("PROPOSED PALETTE", os.environ["EW_PALETTE_JSON"])

# ---- stats (real assets only; stage and preview stand-ins excluded) ---------------------------
dg = bpy.context.evaluated_depsgraph_get()
tris = objs = slots = 0
per_asset = []
for pl in placed:
    t = 0
    for o in pl["objects"]:
        if o.type != "MESH":
            continue
        me = o.evaluated_get(dg).to_mesh()
        me.calc_loop_triangles()
        t += len(me.loop_triangles)
        o.evaluated_get(dg).to_mesh_clear()
        objs += 1
        slots += max(1, len(o.data.materials))
    tris += t
    per_asset.append(dict(label=pl["label"], asset=pl["asset"], tris=t))
standins = er.add_vfx_standins(scene)
json.dump(dict(layout=os.path.basename(layout_path), assets=per_asset, tris=tris, mesh_objects=objs,
               material_slots=slots, vfx_standins=standins, engine=engine),
          open(os.path.join(out, "stats.json"), "w"), indent=2)

# ---- cameras -----------------------------------------------------------------------------------
def camera(name, ortho=None, lens=24):
    cd = bpy.data.cameras.new(name)
    if ortho:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    else:
        cd.lens = lens
        cd.sensor_width = 36
    cd.clip_start = 0.005
    ob = bpy.data.objects.new(name, cd)
    scene.collection.objects.link(ob)
    return ob


views = []
# seated player: eyes ~40 cm above the table and ~30 cm back from the board centre (≈50 cm away)
cam = camera("player", lens=22)
cam.location = (0, -0.30, 0.40)
er.look_at(cam, (0, 0.03, 0))
views.append(("player", cam, (960, 640)))
cam = camera("top", ortho=N * C * 1.08)
cam.location = (0, 0, 1.0)
cam.rotation_euler = (0, 0, 0)
views.append(("top", cam, (640, 640)))
for i, pl in enumerate(placed):
    cam = camera("close_%d" % i, lens=50)
    tgt = Vector((pl["centre"][0], pl["centre"][1], pl["height"] * 0.5))
    az, el, d = math.radians(35), math.radians(32), 0.26 + pl["height"] * 1.4  # taller asset, further back
    cam.location = tgt + Vector((d * math.cos(el) * math.sin(az), -d * math.cos(el) * math.cos(az), d * math.sin(el)))
    er.look_at(cam, tgt)
    views.append(("close_%d" % i, cam, (480, 480)))

for name, L in er.presets():
    made = er.apply_preset(scene, L)
    for vname, cam, (rx, ry) in views:
        scene.camera = cam
        scene.render.resolution_x, scene.render.resolution_y = rx, ry
        scene.render.filepath = os.path.join(out, "%s_%s.png" % (vname, name))
        bpy.ops.render.render(write_still=True)
    for ob in made:
        bpy.data.objects.remove(ob)
print("ENGINE", engine)
print("rendered ->", out)
