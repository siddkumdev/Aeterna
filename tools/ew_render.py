"""Shared render helpers for review images. Runs inside Blender (imported by render_lighting_inner.py
and render_diorama_inner.py). Preview-only: nothing here is ever exported.
"""
import math
import os

import bpy
import mathutils

import blender_common as bc


def setup_engine(scene, res_x=480, res_y=480):
    """EEVEE if it starts headless, otherwise Cycles on the CPU. Transparent film, Standard view."""
    engine = None
    for e in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "CYCLES"):
        try:
            scene.render.engine = e
            engine = e
            break
        except TypeError:
            continue
    if engine == "CYCLES":
        scene.cycles.device = "CPU"
        scene.cycles.samples = 48
    scene.render.film_transparent = True
    scene.render.resolution_x, scene.render.resolution_y = res_x, res_y
    scene.view_settings.view_transform = "Standard"
    world = scene.world or bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    return engine


def _glow_mat(name, base, emit, strength):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bs = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bs.inputs["Base Color"].default_value = bc.color(base)
    bs.inputs["Emission Color"].default_value = bc.color(emit)
    bs.inputs["Emission Strength"].default_value = strength
    return m


def _anchor_size(e):
    """Effect size: the "ew_size" custom property (kept through glTF extras), else the empty's display size."""
    return e.get("ew_size", e.empty_display_size) * max(e.matrix_world.to_scale())


def add_vfx_standins(scene):
    """Preview-only stand-ins so reviews show where effects sit: a glowing ball at every
    "__orb_anchor", a flame-tongue cluster at every "__fire_anchor", a glowing dome at every
    "__brew_anchor". Returns the count."""
    n = 0
    for e in [o for o in scene.objects if o.type == "EMPTY" and o.name.split(".")[0].endswith("__orb_anchor")]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=_anchor_size(e), segments=24, ring_count=12,
                                             location=e.matrix_world.translation)
        ball = bpy.context.active_object
        bpy.ops.object.shade_smooth()
        ball.data.materials.append(_glow_mat("vfx_standin", "fire_yellow", "lantern_glow", 1.6))
        halo = bpy.data.lights.new("vfx_glow", "POINT")
        halo.color = bc.color("lantern_glow")[:3]
        halo.energy = 0.6
        halo.shadow_soft_size = 0.01
        hob = bpy.data.objects.new("vfx_glow", halo)
        scene.collection.objects.link(hob)
        hob.location = e.matrix_world.translation
        n += 1
    # "__brew_anchor": a low glowing dome of lava/fire (the bomb tower's brew), ew_size = mouth radius
    for e in [o for o in scene.objects if o.type == "EMPTY" and o.name.split(".")[0].endswith("__brew_anchor")]:
        r = _anchor_size(e) * 0.9
        bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=20, ring_count=10, location=e.matrix_world.translation)
        dome = bpy.context.active_object
        dome.scale = (1, 1, 0.35)
        dome.rotation_euler = e.matrix_world.to_euler()
        bpy.ops.object.shade_smooth()
        dome.data.materials.append(_glow_mat("vfx_brew_standin", "fire_red", "fire_red", 1.4))
        n += 1
    tongues = [(0, 0, 0.42, 2.6, 0, "fire_red"), (0.55, 30, 0.30, 1.8, 22, "fire_red"), (0.55, 150, 0.30, 1.6, 22, "fire_red"),
               (0.55, 270, 0.30, 1.9, 22, "fire_red"), (0.25, 200, 0.28, 2.0, 8, "lantern_glow"), (0.2, 300, 0.18, 1.3, 5, "fire_yellow")]
    for e in [o for o in scene.objects if o.type == "EMPTY" and o.name.split(".")[0].endswith("__fire_anchor")]:
        r = _anchor_size(e)
        pos = e.matrix_world.translation
        for (d, ang, rr, hh, tilt, col) in tongues:
            a_ = math.radians(ang)
            bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=rr * r, radius2=0, depth=hh * r, location=(0, 0, hh * r / 2))
            f = bpy.context.active_object
            f.data.transform(mathutils.Matrix.Rotation(math.radians(tilt), 4, "X"))
            f.rotation_euler = (0, 0, a_ + math.pi / 2)
            f.location = (pos.x + d * r * math.cos(a_), pos.y + d * r * math.sin(a_), pos.z)
            f.data.materials.append(_glow_mat("vfx_flame_standin", col, col, 1.6))
        n += 1
    return n


def presets(only=None):
    """(name, preset) pairs from palette.json 'lighting', optionally filtered by name list or EW_PRESETS."""
    only = only or [p for p in os.environ.get("EW_PRESETS", "").split(",") if p]
    return [(k, v) for k, v in bc.palette()["lighting"].items() if not k.startswith("_") and (not only or k in only)]


def apply_preset(scene, L):
    """Key sun, rim sun from behind, ambient world colour. Returns the lights to remove afterwards."""
    def sun(name, colour, strength, rot):
        ld = bpy.data.lights.new(name, "SUN")
        ld.color = bc.color(colour)[:3]
        ld.energy = strength
        ld.angle = math.radians(8)
        ob = bpy.data.objects.new(name, ld)
        scene.collection.objects.link(ob)
        ob.rotation_euler = [math.radians(r) for r in rot]
        return ob
    elev, kaz = L.get("key_elev", 40), L.get("key_az", -35)
    made = [sun("key", L["key"], 4.0 * L["energy"], (90 - elev, 0, kaz)),
            sun("rim", L["rim"], 2.5 * L["energy"] * L.get("rim_scale", 1.0), (60, 0, 160))]
    bg = next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = bc.color(L["ambient"])
    bg.inputs["Strength"].default_value = L.get("ambient_strength", 0.9)
    return made


def look_at(cam, target):
    cam.rotation_euler = (mathutils.Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
