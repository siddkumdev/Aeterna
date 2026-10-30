"""Render the island underside (W02) from below and from the side, with the real island v01 on top as a stand-in
(stretched x2 like in Godot), under day and night lighting. Runs inside Blender (see make_underside_sheet.py).

    blender -b assets/blend/island_underside_A.blend -P tools/render_underside_inner.py -- OUT_DIR

Preview-only: glowing stand-ins appear at every `__thrust_anchor*` (a red/orange plume pointing down) and
`__rune_anchor*` (a small ember), so the review shows where the VFX will sit. Nothing here is exported.
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

# the real island on top (appended, stretched x2 horizontally like in Godot)
with bpy.data.libraries.load(os.path.join(bc.ROOT, "assets", "blend", "island.blend")) as (src, dst):
    dst.objects = [n for n in src.objects if n.startswith("ew_world_island_v01")]
for o in dst.objects:
    scene.collection.objects.link(o)
    if o.parent is None:
        o.scale = (2.0, 2.0, 1.0)

stand = []
for e in [o for o in scene.objects if o.type == "EMPTY"]:
    base = e.name.split(".")[0]
    pos = e.matrix_world.translation
    r = e.get("ew_size", e.empty_display_size)
    if "__thrust_anchor" in base:
        h = r * 2.2
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=r * 0.15, radius2=r * 1.0, depth=h, location=(pos.x, pos.y, pos.z - h / 2))
        f = bpy.context.active_object
        f.data.materials.append(er._glow_mat("thrust_standin", "fire_red", "fire_red", 1.8))
        stand.append(f)
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=r * 0.08, radius2=r * 0.55, depth=h * 0.8, location=(pos.x, pos.y, pos.z - h * 0.4))
        g = bpy.context.active_object
        g.data.materials.append(er._glow_mat("thrust_standin2", "fire_yellow", "lantern_glow", 2.2))
    elif "_energy_anchor" in base:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.009, segments=10, ring_count=6, location=pos)
        s = bpy.context.active_object
        s.data.materials.append(er._glow_mat("energy_standin", "fire_yellow", "lantern_glow", 2.5))
    elif "__rune_anchor" in base:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=r * 0.5, segments=12, ring_count=6, location=pos)
        s = bpy.context.active_object
        s.data.materials.append(er._glow_mat("rune_standin", "lantern_glow", "lantern_glow", 2.0))

meshes = [o for o in scene.objects if o.type == "MESH"]
lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
for o in meshes:
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        lo, hi = Vector(map(min, lo, w)), Vector(map(max, hi, w))
center = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2 * 0.8))  # frame the whole depth
size = max(hi.x - lo.x, hi.y - lo.y, (hi.z - lo.z) * 1.25)

er.setup_engine(scene, 520, 380)
cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = size * 1.02
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

# (file, az, el, preset): side from the front at the player's eye height, from below, side at night
views = [("side", 25, 10, "day"), ("close", 20, 4, "day"), ("below", 25, -42, "day"), ("night", 25, -20, "night")]
focus = os.environ.get("EW_FOCUS")  # "x,y,z,ortho_scale,az,el": one extra close-up of a spot
if focus:
    fx, fy, fz, fs, faz, fel = [float(n) for n in focus.split(",")]
    views.append(("focus", faz, fel, "day"))
presets = dict(er.presets())
for name, az_d, el_d, preset in views:
    az, el = math.radians(az_d), math.radians(el_d)
    d = size * 4
    cam.location = center + Vector((d * math.cos(el) * math.sin(az), -d * math.cos(el) * math.cos(az), d * math.sin(el)))
    tgt = Vector((0.15, -0.57, -0.2)) if name == "close" else center
    cam.data.ortho_scale = 0.7 if name == "close" else size * 1.12
    if name == "focus":
        tgt, cam.data.ortho_scale = Vector((fx, fy, fz)), fs
    cam.location = tgt + (cam.location - center)
    er.look_at(cam, tgt)
    made = er.apply_preset(scene, presets[preset])
    scene.render.filepath = os.path.join(out, name + ".png")
    bpy.ops.render.render(write_still=True)
    for ob in made:
        bpy.data.objects.remove(ob)
print("rendered ->", out)
