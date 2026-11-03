"""Export Durva's characters and enemies as .glb, so they can be tried in the game. Designs are not changed.

Run through Blender (from the repo root):
  blender --factory-startup -b -P tools/export_characters.py            (everything)
  blender --factory-startup -b -P tools/export_characters.py -- bee_kid (one)
Saves assets/blend/char_<key>.blend or enemy_<key>.blend and writes assets/export/<category>/ew_<category>_<key>_v01.glb.
Prints one "TRIS <key> <n>" line per model. Then: python tools/sync_to_godot.py assets/export/village/... (see godot-import).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "assets", "generators"))
import make_characters as mc  # noqa: E402
import make_enemies2 as me  # noqa: E402

bc = mc.bc
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for key in mc.CHARACTERS:
    if argv and key not in argv:
        continue
    bc.clear_scene()
    cat = mc.CHARACTERS[key].get("cat", "village")
    obj = mc.build("ew_%s_%s_v01" % (cat, key), key)
    print("TRIS", key, mc.tri_count(obj))
    bc.save_blend(obj, "char_" + key)
    print("EXPORT", bc.export_glb(obj, cat))
for key in me.ENEMIES:
    if argv and key not in argv:
        continue
    bc.clear_scene()
    obj = me.build(key)
    print("TRIS", key, mc.tri_count(obj))
    bc.save_blend(obj, "enemy_" + key)
    print("EXPORT", bc.export_glb(obj, "enemy"))
