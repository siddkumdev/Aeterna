"""Render a life-size landscape asset (e.g. ew_world_story_ground) from where you stand and from above.
make_variant_sheet / make_sheet frame table-sized models and see nothing at 250 m. Usage:
    blender -b <file.blend> -P tools/render_landscape.py -- <out_prefix>
Writes <out_prefix>_eye.png (1.6 m eye height at the origin, looking at the village, Godot -Z = Blender +Y)
and <out_prefix>_top.png (high oblique). Eevee, one warm sun + sky-coloured world, palette atlas as authored.
"""
import math
import sys

import bpy
from mathutils import Euler

out = sys.argv[sys.argv.index("--") + 1]
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
sc.render.resolution_x, sc.render.resolution_y = 1280, 720
sc.view_settings.view_transform = "Standard"
w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.68, 0.85, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
sc.world = w
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.5
sun.data.color = (1.0, 0.93, 0.8)
sun.rotation_euler = Euler((math.radians(55), 0, math.radians(-35)))
sc.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.clip_start, cam.data.clip_end = 0.05, 1000.0
sc.collection.objects.link(cam)
sc.camera = cam
for name, loc, rot, lens in (("eye", (0, 0, 1.6), (88, 0, 0), 18), ("top", (0, -95, 70), (58, 0, 0), 24)):
    cam.location = loc
    cam.rotation_euler = Euler([math.radians(a) for a in rot])  # rot X 90 = looking along +Y (Godot -Z, the village)
    cam.data.lens = lens
    sc.render.filepath = "%s_%s.png" % (out, name)
    bpy.ops.render.render(write_still=True)
    print("WROTE", sc.render.filepath)
