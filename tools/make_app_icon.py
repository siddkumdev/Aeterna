"""Placeholder app icon for the Godot project (godot/icon.png), drawn from art/palette.json.

A dark ink square with a lantern-glow flame. Plain placeholder: replace with a real icon later.
Run: python tools/make_app_icon.py
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
MAT = json.loads((ROOT / "art" / "palette.json").read_text(encoding="utf-8"))["materials"]


def rgb(name):
    h = MAT[name]
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


S = 4  # supersample
N = 512
img = Image.new("RGB", (N * S, N * S), rgb("ink"))
d = ImageDraw.Draw(img)
cx, cy = N * S // 2, N * S // 2
for name, r in (("fire_red", 190), ("lantern_glow", 135), ("fire_yellow", 70)):
    rr = r * S
    d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=rgb(name))
img = img.resize((N, N), Image.LANCZOS)
out = ROOT / "godot" / "icon.png"
img.save(out)
print("wrote", out)
