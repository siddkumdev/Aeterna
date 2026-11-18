"""Build the app icon set from a real in-game frame of the whole floating island.

    python tools/make_icon.py <island.png>

<island.png>: transparent-background frame from godot/tools/thumb_shot.gd that shows the whole island
(e.g. _work/thumb/t_dusk_0.png, camera at 1.38 x the offsets). Writes into godot/:
  icon.png (1024, project / window icon)
  icons/icon_192.png (Android launcher, main)
  icons/icon_fg_432.png, icons/icon_bg_432.png, icons/icon_mono_432.png (Android adaptive layers)
No generated art: the island is the game itself; the sky is a plain gradient in the thumbnail's colours.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "godot"
TOP = (24, 12, 30)
MID = (74, 30, 52)
LOW = (170, 70, 40)
GLOW = (255, 170, 80)


def lerp(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def sky(n: int) -> Image.Image:
    img = Image.new("RGBA", (n, n))
    d = ImageDraw.Draw(img)
    for y in range(n):
        t = y / (n - 1)
        c = lerp(TOP, MID, t / 0.5) if t < 0.5 else lerp(MID, LOW, (t - 0.5) / 0.5)
        d.line((0, y, n, y), fill=c + (255,))
    glow = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((n * 0.12, n * 0.22, n * 0.88, n * 0.98), fill=GLOW + (110,))
    return Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(n * 0.09)))


def island(src: str) -> Image.Image:
    isl = Image.open(src).convert("RGBA")
    isl = isl.crop(isl.getbbox())
    # the frame cuts the hanging root; fade its bottom so no hard edge shows
    fade = Image.new("L", isl.size, 255)
    fd = ImageDraw.Draw(fade)
    n = int(isl.height * 0.18)
    for i in range(n):
        fd.line((0, isl.height - 1 - i, isl.width, isl.height - 1 - i), fill=int(255 * i / n))
    isl.putalpha(Image.composite(isl.getchannel("A"), Image.new("L", isl.size, 0), fade))
    return isl


def place(isl: Image.Image, n: int, width_share: float, centre_y: float) -> Image.Image:
    s = (n * width_share) / isl.width
    im = isl.resize((max(1, int(isl.width * s)), max(1, int(isl.height * s))), Image.LANCZOS)
    layer = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    layer.alpha_composite(im, ((n - im.width) // 2, int(n * centre_y - im.height / 2)))
    return layer


def main(src: str) -> None:
    isl = island(src)
    (OUT / "icons").mkdir(exist_ok=True)
    full = Image.alpha_composite(sky(1024), place(isl, 1024, 0.94, 0.58))
    full.convert("RGB").save(OUT / "icon.png")
    full.convert("RGB").resize((192, 192), Image.LANCZOS).save(OUT / "icons/icon_192.png")
    # adaptive: the launcher crops to the central ~66 %, so the island sits smaller in the foreground
    fg = place(isl, 432, 0.70, 0.52)
    fg.save(OUT / "icons/icon_fg_432.png")
    sky(432).convert("RGB").save(OUT / "icons/icon_bg_432.png")
    mono = Image.new("RGBA", (432, 432), (255, 255, 255, 0))
    mono.putalpha(fg.getchannel("A").point(lambda v: 255 if v > 96 else 0))
    mono.save(OUT / "icons/icon_mono_432.png")
    print("saved godot/icon.png and godot/icons/*.png")


if __name__ == "__main__":
    main(sys.argv[1])
