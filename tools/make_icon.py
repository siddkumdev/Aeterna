"""Build the app icon set from a real in-game render of one bold subject (default: the rewind hourglass).

    python tools/make_icon.py <subject.png>

<subject.png>: transparent-background render from godot/tools/icon_shot.gd (e.g. _work/icon/ew_vfx_rewind_hourglass_v02.png).
The subject is fitted by height so a tall object fills the icon. Writes into godot/:
  icon.png (1024, project / window icon)
  icons/icon_192.png (Android launcher, main)
  icons/icon_fg_432.png, icons/icon_bg_432.png, icons/icon_mono_432.png (Android adaptive layers)
No generated art: the subject is the game model itself; the sky is a plain gradient in the thumbnail's colours.
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
        c = lerp(TOP, MID, t / 0.6) if t < 0.6 else lerp(MID, LOW, (t - 0.6) / 0.4)
        d.line((0, y, n, y), fill=c + (255,))
    glow = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((n * 0.2, n * 0.2, n * 0.8, n * 0.8), fill=GLOW + (150,))
    return Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(n * 0.11)))


def island(src: str) -> Image.Image:
    isl = Image.open(src).convert("RGBA")
    isl = isl.crop(isl.getbbox())
    return isl


def place(isl: Image.Image, n: int, height_share: float, centre_y: float) -> Image.Image:
    s = (n * height_share) / isl.height
    im = isl.resize((max(1, int(isl.width * s)), max(1, int(isl.height * s))), Image.LANCZOS)
    layer = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    layer.alpha_composite(im, ((n - im.width) // 2, int(n * centre_y - im.height / 2)))
    return layer


def main(src: str) -> None:
    isl = island(src)
    (OUT / "icons").mkdir(exist_ok=True)
    full = Image.alpha_composite(sky(1024), place(isl, 1024, 0.84, 0.5))
    full.convert("RGB").save(OUT / "icon.png")
    full.convert("RGB").resize((192, 192), Image.LANCZOS).save(OUT / "icons/icon_192.png")
    # adaptive: the launcher crops to the central ~66 %, so the subject sits smaller in the foreground
    fg = place(isl, 432, 0.54, 0.5)
    fg.save(OUT / "icons/icon_fg_432.png")
    sky(432).convert("RGB").save(OUT / "icons/icon_bg_432.png")
    mono = Image.new("RGBA", (432, 432), (255, 255, 255, 0))
    mono.putalpha(fg.getchannel("A").point(lambda v: 255 if v > 96 else 0))
    mono.save(OUT / "icons/icon_mono_432.png")
    print("saved godot/icon.png and godot/icons/*.png")


if __name__ == "__main__":
    main(sys.argv[1])
