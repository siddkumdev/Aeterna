"""Bring exported .glb assets into the Godot project, import them headless and check them.

    python tools/sync_to_godot.py assets/export/defense/ew_defense_fire_tower_v03.glb [more.glb ...]
    python tools/sync_to_godot.py --check            (re-import and check what is already in godot/assets)

- Copies art/palette_atlas.png to godot/assets/palette/ (the one atlas every model shares).
- Copies each .glb to godot/assets/<category>/ (category from the ew_<category>_ name).
- Writes a .import file for each new .glb so Godot discards the embedded atlas copy and runs
  godot/tools/ew_post_import.gd (shared materials, VFX anchors as Marker3D, part tags).
- Runs Godot headless --import, then godot/tools/check_assets.gd on the synced files. Exit code 1 on FAIL.
Never deletes anything in the Godot project.
"""
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT_PROJECT = os.path.join(ROOT, "godot")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ew_env  # noqa: E402  (local.env paths)
GODOT = ew_env.require("GODOT_EXE")

# Atlas: no mipmaps (swatches would bleed into each other at a distance), lossless.
ATLAS_IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
mipmaps/generate=false
"""

# Models: drop the embedded atlas copy (gltf/embedded_image_handling=0) and run the post-import script.
GLB_IMPORT = """[remap]

importer="scene"
importer_version=1
type="PackedScene"

[params]

nodes/apply_root_scale=true
nodes/root_scale=1.0
meshes/generate_lods=true
meshes/create_shadow_meshes=true
import_script/path="res://tools/ew_post_import.gd"
gltf/naming_version=2
gltf/embedded_image_handling=0
"""


def copy_with_import(src, dst, import_text):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)
    imp = dst + ".import"
    if not os.path.exists(imp):
        with open(imp, "w", encoding="utf-8", newline="\n") as f:
            f.write(import_text)
    print("synced", os.path.relpath(dst, ROOT))


def main(args):
    check_only = "--check" in args
    glbs = [a for a in args if a != "--check"]
    if not glbs and not check_only:
        sys.exit(__doc__)
    copy_with_import(os.path.join(ROOT, "art", "palette_atlas.png"),
                     os.path.join(GODOT_PROJECT, "assets", "palette", "palette_atlas.png"), ATLAS_IMPORT)
    names = []
    for g in glbs:
        base = os.path.basename(g)
        m = re.match(r"ew_([a-z]+)_.+_v\d+\.glb$", base)
        if not m:
            sys.exit("not an Endless Watch export name: " + base)
        copy_with_import(os.path.abspath(g), os.path.join(GODOT_PROJECT, "assets", m.group(1), base), GLB_IMPORT)
        names.append(os.path.splitext(base)[0])
    r = subprocess.run([GODOT, "--headless", "--xr-mode", "off", "--path", GODOT_PROJECT, "--import"], capture_output=True, text=True, timeout=600)
    errs = [l for l in (r.stdout + r.stderr).splitlines() if "ERROR" in l or "WARNING" in l]
    if errs:
        print("Godot import messages:\n  " + "\n  ".join(errs[:40]))
    r = subprocess.run([GODOT, "--headless", "--xr-mode", "off", "--path", GODOT_PROJECT, "-s", "res://tools/check_assets.gd", "--"] + names,
                       capture_output=True, text=True, timeout=600)
    out = r.stdout[r.stdout.find("\nres://"):] if "\nres://" in r.stdout else r.stdout
    print(out.rstrip())
    if r.returncode != 0:
        print(r.stderr[-2000:])
    sys.exit(r.returncode)


if __name__ == "__main__":
    main(sys.argv[1:])
