"""Render review images for the open .blend. Runs inside Blender.

    blender -b asset.blend -P tools/render_preview.py -- OUT_DIR

Writes front/side/top/three_quarter/wire.png (512 px) and silhouette.png (256 px).
Workbench engine: works headless without a GPU context.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
os.makedirs(out, exist_ok=True)

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if not meshes:
    sys.exit("no mesh objects in scene")

lo = Vector((1e9, 1e9, 1e9))
hi = Vector((-1e9, -1e9, -1e9))
for o in meshes:
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        lo = Vector(map(min, lo, w))
        hi = Vector(map(max, hi, w))
center = (lo + hi) / 2
radius = max((hi - lo).length / 2, 0.01)

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False
world = bpy.data.worlds.new("w") if not scene.world else scene.world
scene.world = world
world.color = (0.92, 0.92, 0.92)
sh = scene.display.shading
sh.light = "STUDIO"
sh.color_type = "TEXTURE"
sh.show_object_outline = True
sh.object_outline_color = (0.1, 0.1, 0.1)
sh.background_type = "WORLD"

cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = radius * 2.3
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam


def shoot(name, az_deg, el_deg, size=512, mode="color"):
    az, el = math.radians(az_deg), math.radians(el_deg)
    d = radius * 4
    cam.location = center + Vector((d * math.cos(el) * math.sin(az), -d * math.cos(el) * math.cos(az), d * math.sin(el)))
    direction = center - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.render.resolution_x = scene.render.resolution_y = size
    if mode == "silhouette":
        sh.light = "FLAT"
        sh.color_type = "SINGLE"
        sh.single_color = (0, 0, 0)
        sh.show_object_outline = False
        world.color = (1, 1, 1)
    elif mode == "wire":
        sh.light = "FLAT"
        sh.color_type = "SINGLE"
        sh.single_color = (0.05, 0.05, 0.05)
        sh.show_object_outline = False
        for o in meshes:
            m = o.modifiers.new("ew_wire", "WIREFRAME")
            m.thickness = radius * 0.012
    scene.render.filepath = os.path.join(out, name + ".png")
    bpy.ops.render.render(write_still=True)
    # restore
    for o in meshes:
        if "ew_wire" in o.modifiers:
            o.modifiers.remove(o.modifiers["ew_wire"])
    sh.type = "SOLID"
    sh.light = "STUDIO"
    sh.color_type = "TEXTURE"
    sh.show_object_outline = True
    world.color = (0.92, 0.92, 0.92)


shoot("front", 0, 0)
shoot("side", 90, 0)
shoot("top", 0, 90)
shoot("three_quarter", 35, 28)
shoot("wire", 35, 28, mode="wire")
shoot("silhouette", 35, 28, size=256, mode="silhouette")
print("rendered ->", out)
