"""Small shared helpers for the quest props (garden, house bell, firewood, postbox). Runs inside Blender.
Units are metres; 1 cell = 0.05 m. Colours only by palette name."""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "tools"))
sys.path.insert(0, HERE)
import blender_common as bc  # noqa: E402
import bmesh  # noqa: E402
import bpy  # noqa: E402
import make_village_props as vp  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

box, cyl, tbox, tcyl, nb = vp.box, vp.cyl, vp.tbox, vp.tcyl, vp.nb


def orient(o, loc, direction):
    """Part built around the origin with its long axis on +Z: turn +Z onto `direction`, move to loc."""
    q = Vector((0, 0, 1)).rotation_difference(Vector(direction).normalized())
    bpy.ops.object.select_all(action="DESELECT")
    o.rotation_euler = q.to_euler()
    bpy.context.view_layer.update()
    bc.apply_transforms(o)
    bpy.ops.object.select_all(action="DESELECT")
    for v in o.data.vertices:
        v.co.x += loc[0]
        v.co.y += loc[1]
        v.co.z += loc[2]
    return o


def rod(p0, p1, t, col, bevel=False):
    """Square rod from p0 to p1."""
    d = Vector(p1) - Vector(p0)
    o = orient(bc.box("rod", (t, t, d.length), (0, 0, 0), col), (Vector(p0) + Vector(p1)) / 2, d)
    return o if bevel else nb(o)


def spike(p0, p1, r, col, seg=4, r_top=0.0):
    """Cone from base p0 to tip p1 (pointed by default)."""
    d = Vector(p1) - Vector(p0)
    o = orient(bc.cone("spike", r, r_top, d.length, (0, 0, 0), col, seg), (Vector(p0) + Vector(p1)) / 2, d)
    return nb(o)


def lump(r, loc, col, squash=(1, 1, 1)):
    """Faceted 20-triangle blob (icosahedron): vegetables, berries, soil clumps."""
    return nb(bc.blob("lump", r, loc, col, 0, squash))


def disc(r, loc, col, seg=6, rz=0.0):
    """One flat n-gon facing -Y (a cut log end, a slot plate): 'seg-2' triangles."""
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, cap_tris=False, radius=r, segments=seg)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(rz), 3, "Z"))
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "X"))
    bmesh.ops.translate(bm, vec=loc, verts=bm.verts)
    o = bc._new_obj("disc", bm)
    bc.paint(o, col)
    return nb(o)


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def finish(letter, short, groups, foot, place, ver="v01"):
    """groups: [("", root_parts, (0,0,0), None), ("weed", parts, pivot, ""), ...] -> assemble, tag, save, print."""
    name = "ew_village_%s_%s" % (short, ver)
    root = bc.assemble(name, groups)
    root["ew_footprint"], root["ew_front"], root["ew_place"] = foot, "-Y", place
    objs = [root] + list(root.children_recursive)
    total = sum(tris(o) for o in objs if o.type == "MESH")
    print("%s %s: %d tris total" % (name, letter, total))
    for o in objs:
        if o.type == "MESH":
            ws = [o.matrix_world @ Vector(c) for c in o.bound_box]
            print("  %s: %d tris, x %.1f..%.1f y %.1f..%.1f z %.1f..%.1f mm" % (
                o.name.replace(name, "root"), tris(o), 1000 * min(w.x for w in ws), 1000 * max(w.x for w in ws),
                1000 * min(w.y for w in ws), 1000 * max(w.y for w in ws), 1000 * min(w.z for w in ws), 1000 * max(w.z for w in ws)))
    print("BLEND", bc.save_blend(root, "%s_%s" % (short, letter)))
    return root


def letter_arg():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    return args[0] if args else "A"
