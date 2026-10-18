"""Render the open .blend under each lighting preset in art/palette.json. Runs inside Blender.

    blender -b asset.blend -P tools/render_lighting_inner.py -- OUT_DIR

Board-only lighting: key sun (colour, energy), rim sun from behind, ambient world colour.
Transparent film so the wrapper can composite onto a passthrough-like grey. Uses EEVEE if it
starts headless, otherwise Cycles on the CPU. A guide, not the final look (Godot renders the game).
Optional env EW_PRESETS=day,golden_hour limits the presets.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_common as bc  # noqa: E402
import ew_render as er  # noqa: E402

out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
os.makedirs(out, exist_ok=True)
scene = bpy.context.scene

er.add_vfx_standins(scene)  # before framing, so stand-ins are inside the shot

meshes = [o for o in scene.objects if o.type == "MESH"]
lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
for o in meshes:
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        lo, hi = Vector(map(min, lo, w)), Vector(map(max, hi, w))
center = (lo + hi) / 2
size = max((hi - lo).length, 0.05)

# ground: a 4 x 4 cell patch of board grass under the 2 x 2 asset
bc.box("ground", (4 * bc.CELL, 4 * bc.CELL, 0.004), (0, 0, -0.002), "grass")

engine = er.setup_engine(scene)
cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = size * 1.25
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
az, el = math.radians(35), math.radians(32)  # the player looks down at the board
d = size * 4
cam.location = center + Vector((d * math.cos(el) * math.sin(az), -d * math.cos(el) * math.cos(az), d * math.sin(el)))
er.look_at(cam, center)

for name, L in er.presets():
    made = er.apply_preset(scene, L)
    scene.render.filepath = os.path.join(out, "light_%s.png" % name)
    bpy.ops.render.render(write_still=True)
    for ob in made:
        bpy.data.objects.remove(ob)
print("ENGINE", engine)
print("rendered ->", out)
