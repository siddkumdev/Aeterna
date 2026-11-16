"""Scale reference for variant sheets: builds the variants in a row beside the real basket, clothesline and a villager.
Used by make_laundry.py / make_apples.py / make_cat.py in mode SCALE (preview only, never exported).
Reference blends are read from assets/blend (prop_basket, prop_clothesline, char_cat_girl)."""
import os

import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
REFS = [("prop_basket", 0.0), ("prop_clothesline", 0.0), ("char_cat_girl", 0.0)]


def add_refs(x0, y):
    """Append the reference objects in a row starting at x0 (metres), at row y. Returns the next free x."""
    x = x0
    for blend, _ in REFS:
        path = os.path.join(ROOT, "assets", "blend", blend + ".blend")
        with bpy.data.libraries.load(path, link=False) as (src, dst):
            dst.objects = list(src.objects)
        objs = [o for o in dst.objects if o is not None]
        for o in objs:
            bpy.context.collection.objects.link(o)
        roots = [o for o in objs if o.parent is None]
        wmax = 0.0
        for r in roots:
            r.location.x += x
            r.location.y += y
        meshes = [o for o in objs if o.type == "MESH"]
        xs = [(o.matrix_world @ __import__("mathutils").Vector(c)).x for o in meshes for c in o.bound_box]
        bpy.context.view_layer.update()
        xs = [(o.matrix_world @ __import__("mathutils").Vector(c)).x for o in meshes for c in o.bound_box]
        wmax = max(xs) - min(xs) if xs else 0.03
        shift = x - min(xs)
        for r in roots:
            r.location.x += shift
        x += wmax + 0.012
    return x
