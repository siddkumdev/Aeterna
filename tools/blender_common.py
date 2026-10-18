"""Shared helpers for asset generators. Runs inside Blender (bpy), not system Python.

Typical generator:
    import sys, os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "tools"))
    import blender_common as bc
    bc.clear_scene()
    parts = [bc.box("wall", (1, 1, 0.8), (0, 0, 0.4), "wall_cream"), ...]
    obj = bc.finish(parts, "ew_village_house_v01")
    bc.save_blend(obj, "house")
    bc.export_glb(obj, "village")
"""
import json
import math
import os

import bpy
import bmesh
import mathutils

CELL = 0.05  # metres per grid cell; footprints and gameplay measures are whole cells
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
# EW_PALETTE_JSON / EW_ATLAS_PATH: preview a PROPOSED palette (tools/palette_change.py) without touching the real one.
PALETTE_PATH = os.environ.get("EW_PALETTE_JSON") or os.path.join(ROOT, "art", "palette.json")
_palette = None


def palette():
    global _palette
    if _palette is None:
        with open(PALETTE_PATH, encoding="utf-8") as f:
            _palette = json.load(f)
    return _palette


def color(name_or_hex):
    """Palette material name or 'RRGGBB' hex -> linear RGBA tuple (for lights/helpers; models use paint())."""
    hx = palette()["materials"].get(name_or_hex, name_or_hex).lstrip("#")
    srgb = [int(hx[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    return (*lin, 1.0)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for b in list(block):
            block.remove(b)


ATLAS_COLS = 8
ATLAS_CELL = 16  # px per swatch; 8x8 grid = 128 px texture
ATLAS_PATH = (os.environ.get("EW_ATLAS_PATH")
              or (os.path.splitext(os.environ["EW_PALETTE_JSON"])[0] + "_atlas.png" if os.environ.get("EW_PALETTE_JSON") else None)
              or os.path.join(ROOT, "art", "palette_atlas.png"))  # a proposal never overwrites the real atlas


def atlas_names():
    """Palette material names in stable order; index = swatch cell."""
    return list(palette()["materials"].keys())


def _write_png(path, size, rows):
    """Minimal RGB PNG writer (Blender's image.save() writes black in background mode)."""
    import struct
    import zlib

    def chunk(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)

    nul = bytes([0])
    raw = b''.join(nul + bytes(row) for row in rows)
    png = (bytes.fromhex('89504e470d0a1a0a') + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0))
           + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))
    with open(path, 'wb') as f:
        f.write(png)


def atlas_image():
    """Build the palette atlas PNG from art/palette.json, load it, and pack it into the .blend."""
    img = bpy.data.images.get("ew_palette_atlas")
    if img:
        return img
    names = atlas_names()
    size = ATLAS_COLS * ATLAS_CELL
    if len(names) > ATLAS_COLS * ATLAS_COLS:
        raise ValueError("palette has more than %d colours" % (ATLAS_COLS * ATLAS_COLS))
    rows = []
    for y in range(size):
        row = []
        for x in range(size):
            i = (y // ATLAS_CELL) * ATLAS_COLS + (x // ATLAS_CELL)
            hx = palette()["materials"][names[i]].lstrip("#") if i < len(names) else "000000"
            row += [int(hx[k:k + 2], 16) for k in (0, 2, 4)]
        rows.append(row)
    _write_png(ATLAS_PATH, size, rows)
    img = bpy.data.images.load(ATLAS_PATH)
    img.name = "ew_palette_atlas"
    img.colorspace_settings.name = "sRGB"
    img.pack()
    return img


def atlas_material():
    """One shared material sampling the palette atlas (nearest filter)."""
    mat = bpy.data.materials.get("ew_palette")
    if mat:
        return mat
    mat = bpy.data.materials.new("ew_palette")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = atlas_image()
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Metallic"].default_value = 0.0
    return mat


def glow_material():
    """Second shared material: same atlas, also used as emission (fire, lit windows, magic).
    Godot maps it to an emissive material; strength is tuned there."""
    mat = bpy.data.materials.get("ew_palette_glow")
    if mat:
        return mat
    mat = bpy.data.materials.new("ew_palette_glow")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = atlas_image()
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 2.0
    bsdf.inputs["Roughness"].default_value = 0.85
    return mat


def paint(obj, name, glow=False):
    """Colour the whole object with one palette swatch by pointing every UV at that cell's centre.
    glow=True uses the emissive ew_palette_glow material instead of ew_palette."""
    names = atlas_names()
    if name not in names:
        raise ValueError("'%s' is not a palette colour; add it to art/palette.json first" % name)
    i = names.index(name)
    size = ATLAS_COLS * ATLAS_CELL
    u = ((i % ATLAS_COLS) + 0.5) * ATLAS_CELL / size
    v = 1.0 - ((i // ATLAS_COLS) + 0.5) * ATLAS_CELL / size  # image row 0 is at the top
    me = obj.data
    uv = me.uv_layers.get("UVMap") or me.uv_layers.new(name="UVMap")
    uv.data.foreach_set("uv", [u, v] * len(me.loops))
    mat = glow_material() if glow else atlas_material()
    if me.materials:
        me.materials[0] = mat
    else:
        me.materials.append(mat)


def _new_obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    return obj


def box(name, size, loc, col, rot_z_deg=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=mathutils.Matrix.Rotation(math.radians(rot_z_deg), 3, "Z"))
    bmesh.ops.translate(bm, vec=loc, verts=bm.verts)
    obj = _new_obj(name, bm)
    paint(obj, col)
    return obj


def cone(name, r_bottom, r_top, depth, loc, col, segments=8, rot_z_deg=0.0):
    """Cone / cylinder / frustum. Origin of the mesh is its centre; loc is the centre."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments,
                          radius1=r_bottom, radius2=r_top, depth=depth)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=mathutils.Matrix.Rotation(math.radians(rot_z_deg), 3, "Z"))
    bmesh.ops.translate(bm, vec=loc, verts=bm.verts)
    obj = _new_obj(name, bm)
    paint(obj, col)
    return obj


def gable(name, w, d, h, loc, col):
    """Gable roof prism: footprint w (x) by d (y), ridge along y, height h. loc = centre of the base."""
    bm = bmesh.new()
    v = [bm.verts.new(c) for c in ((-w / 2, -d / 2, 0), (w / 2, -d / 2, 0), (w / 2, d / 2, 0),
                                   (-w / 2, d / 2, 0), (0, -d / 2, h), (0, d / 2, h))]
    for f in ((0, 3, 2, 1), (0, 1, 4), (3, 5, 2), (1, 2, 5, 4), (0, 4, 5, 3)):
        bm.faces.new([v[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.translate(bm, vec=loc, verts=bm.verts)
    obj = _new_obj(name, bm)
    paint(obj, col)
    return obj


def blob(name, radius, loc, col, subdiv=1, squash=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    bmesh.ops.scale(bm, vec=squash, verts=bm.verts)
    bmesh.ops.translate(bm, vec=loc, verts=bm.verts)
    obj = _new_obj(name, bm)
    paint(obj, col)
    return obj


def bevel(obj, width=None, segments=None):
    """Apply a bevel modifier using the palette style defaults."""
    st = palette()["style"]
    mod = obj.modifiers.new("bevel", "BEVEL")
    w = width if width is not None else st["bevel_width_m"]
    mod.width = min(w, obj.get("ew_min_dim", min(obj.dimensions)) * 0.25)  # never bevel deeper than a quarter of the thinnest side
    mod.segments = segments if segments is not None else st["bevel_segments"]
    mod.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = obj.data.name = name
    return obj


def origin_to_base(obj):
    """Put the origin at the centre of the bottom face (min Z), at world 0."""
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    zs = [v.co.z for v in obj.data.vertices]
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    off = ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs))
    for v in obj.data.vertices:
        v.co.x -= off[0]
        v.co.y -= off[1]
        v.co.z -= off[2]
    obj.location = (0, 0, 0)


def apply_transforms(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def finish(parts, name, do_bevel=True):
    """Bevel each part (keeps colour cells intact), join, flat shade, origin at base."""
    if do_bevel:
        for p in parts:
            bevel(p)
    obj = join(parts, name) if len(parts) > 1 else parts[0]
    obj.name = obj.data.name = name
    for p in obj.data.polygons:
        p.use_smooth = False
    origin_to_base(obj)
    return obj


def rotate(obj, deg_xyz):
    """Rotate a freshly built part (degrees, XYZ) and bake the rotation into the mesh."""
    obj.rotation_euler = [math.radians(d) for d in deg_xyz]
    apply_transforms(obj)
    return obj



def on_wall(name, w, d, h, face_deg, zc, wall, col, sink=0.001, sides=8):
    """A w (along the face) x d (out of the face) x h box mounted flat on one face of a tapered
    regular-polygon wall built with cone(..., segments=sides, rot_z_deg=180/sides), whose faces point at
    0, 360/sides, ... degrees. wall = (r_bottom, r_top, z_bottom, z_top). The box is tilted to the face's
    slope and pushed `sink` m into it, so it touches along its whole height (a vertical box at a fixed
    radius floats off a tapered face)."""
    rb, rt, zb, zt = wall
    ap = lambda z: (rb + (rt - rb) * (z - zb) / (zt - zb)) * math.cos(math.pi / sides)
    o = box(name, (d, w, h), (0, 0, 0), col)
    rotate(o, (0, math.degrees(math.atan((ap(zt) - ap(zb)) / (zt - zb))), face_deg))
    cx = ap(zc) + d / 2 - sink
    o.location = (cx * math.cos(math.radians(face_deg)), cx * math.sin(math.radians(face_deg)), zc)
    apply_transforms(o)
    o["ew_min_dim"] = min(w, d, h)  # the tilt inflates the bounding box; bevel decisions use the true size
    return o

def assemble(name, groups, bevel_min=0.006):
    """Build a multi-part asset whose parts move separately in Godot (no rigs).

    groups: list of (suffix, parts, pivot, parent_suffix[, bevel]). suffix "" is the root (origin at the base,
    at world 0). Other parts become objects named <name>__<suffix>, parented to their parent part,
    with their origin at `pivot` (world coordinates) so Godot can rotate/scale them around it.
    Parts thinner than bevel_min, or tagged obj["no_bevel"] = True (pointed cones: the bevel's clamp
    collapses their tip), are not bevelled; a group with
    bevel=False is not bevelled at all (soft shapes such as fire).
    """
    made = {}
    groups = [tuple(g) + (True,) * (5 - len(g)) for g in groups]
    for suffix, parts, pivot, parent, do_bevel in groups:
        for p in parts:
            if do_bevel and p.get("ew_min_dim", min(p.dimensions)) >= bevel_min and not p.get("no_bevel"):
                bevel(p)
        obj = join(parts, name + ("__" + suffix if suffix else "")) if len(parts) > 1 else parts[0]
        obj.name = obj.data.name = name + ("__" + suffix if suffix else "")
        for poly in obj.data.polygons:
            poly.use_smooth = False
        apply_transforms(obj)
        px, py, pz = pivot
        for v in obj.data.vertices:
            v.co.x -= px
            v.co.y -= py
            v.co.z -= pz
        made[suffix] = (obj, mathutils.Vector(pivot))
    for suffix, parts, pivot, parent, _ in groups:
        obj, pv = made[suffix]
        if suffix == "":
            obj.location = (0, 0, 0)
        else:
            pobj, ppv = made[parent]
            obj.parent = pobj
            obj.location = pv - ppv
    return made[""][0]


def anchor(root, part_name, loc, parent_suffix="", size=0.01):
    """Empty marker child (no mesh) where Godot attaches VFX, e.g. <asset>__orb_anchor.
    loc is in world coordinates; parented to root (or root__<parent_suffix>)."""
    parent = bpy.data.objects[root.name + ("__" + parent_suffix if parent_suffix else "")]
    bpy.context.view_layer.update()
    e = bpy.data.objects.new(root.name + "__" + part_name, None)
    bpy.context.collection.objects.link(e)
    e.empty_display_type = "SPHERE"
    e.empty_display_size = size
    e["ew_size"] = size  # survives glTF export (extras), so imports know the effect size
    e.parent = parent
    e.location = mathutils.Vector(loc) - parent.matrix_world.translation
    return e


def save_blend(obj, short_name):
    path = os.path.join(ROOT, "assets", "blend", short_name + ".blend")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=path)
    return path


def export_glb(obj, category):
    """Export only this object as .glb (Y up, atlas texture embedded)."""
    out_dir = os.path.join(ROOT, "assets", "export", category)
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, obj.name + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    for child in obj.children_recursive:  # separate moving parts travel with their root
        child.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_yup=True, export_apply=True, export_cameras=False, export_extras=True,
                              export_lights=False)
    return path
