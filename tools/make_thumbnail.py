"""Compose the Devpost / store thumbnail from a real in-game frame.

    python tools/make_thumbnail.py <island.png> <out.png> [zoom] [WxH]

WxH: output size (default 1800x1200), e.g. 2560x1440 for a 16:9 cover; text scales with the height.

zoom: island width as a share of the image width (e.g. 1.15 lets it run past the edges); omitted = fit it all in;
-1 = full-bleed close-up (the frame used as shot at its own size, top darkened for the title).

<island.png> is a transparent-background frame from godot/tools/thumb_shot.gd (e.g. _work/thumb/t_dusk_0.png).
Adds a dusk sky gradient, a warm glow behind the island, the title in Cinzel and the tagline in EB Garamond
(both OFL, shipped with the game). No generated art: the island is the game itself.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONTS = ROOT / "godot/assets/fonts"
W, H = 1800, 1200
TOP = (24, 12, 30)        # deep plum night
MID = (74, 30, 52)        # dusk wine
LOW = (170, 70, 40)       # ember horizon (fire_red family)
GLOW = (255, 170, 80)     # lantern_glow
TITLE = (255, 214, 150)
SUB = (236, 196, 170)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def sky() -> Image.Image:
    img = Image.new("RGB", (W, H))
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        c = lerp(TOP, MID, t / 0.55) if t < 0.55 else lerp(MID, LOW, (t - 0.55) / 0.45)
        for x in range(W):
            px[x, y] = c
    return img


def _resize(w: int, h: int) -> None:
    global W, H
    W, H = w, h


def main(src: str, out: str, zoom: float = 0.0) -> None:
    base = sky().convert("RGBA")
    # warm glow behind the island
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((W * 0.2, H * 0.36, W * 0.8, H * 0.98), fill=GLOW + (120,))
    base = Image.alpha_composite(base, glow.filter(ImageFilter.GaussianBlur(160 * H / 1200)))

    isl = Image.open(src).convert("RGBA")
    if zoom < 0:  # full-bleed close-up: keep the frame as shot (any size, e.g. 1920 x 1080 for a 16:9 cover), darken the top for the title
        _resize(*isl.size)
        base = sky().convert("RGBA")
        base.alpha_composite(isl)
        shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        sd = ImageDraw.Draw(shade)
        for yy in range(int(H * 0.42)):
            sd.line((0, yy, W, yy), fill=TOP + (int(235 * (1 - yy / (H * 0.42)) ** 1.4),))
        base = Image.alpha_composite(base, shade)
        return _text(base, out)
    bbox = isl.getbbox()
    isl = isl.crop(bbox)
    scale = min((W * 0.86) / isl.width, (H * 0.74) / isl.height)
    if zoom:
        scale = (W * zoom) / isl.width
    isl = isl.resize((int(isl.width * scale), int(isl.height * scale)), Image.LANCZOS)
    x = (W - isl.width) // 2
    y = H - isl.height + int(H * 0.02) if not zoom else int(H * 0.29)
    # soft shadow-free drop: fade the island's lowest roots into the horizon
    fade = Image.new("L", isl.size, 255)
    fd = ImageDraw.Draw(fade)
    n = int(isl.height * 0.14)
    for i in range(n):
        fd.line((0, isl.height - 1 - i, isl.width, isl.height - 1 - i), fill=int(255 * i / n))
    a = Image.composite(isl.getchannel("A"), Image.new("L", isl.size, 0), fade)
    isl.putalpha(a)
    base.alpha_composite(isl, (x, y))
    _text(base, out)


def _text(base: Image.Image, out: str) -> None:
    k = H / 1200  # everything below was laid out for a 1200 px tall image
    d = ImageDraw.Draw(base)
    title_font = ImageFont.truetype(str(FONTS / "cinzel/Cinzel.ttf"), round(168 * k))
    sub_font = ImageFont.truetype(str(FONTS / "ebgaramond/EBGaramond-Italic.ttf"), round(52 * k))
    title = "AETERNA"
    ty, sy = 48 * k, 252 * k
    tw = d.textlength(title, font=title_font)
    # glow under the title
    tg = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(tg).text(((W - tw) / 2, ty), title, font=title_font, fill=TOP + (255,), stroke_width=round(10 * k), stroke_fill=TOP + (255,))
    base = Image.alpha_composite(base, tg.filter(ImageFilter.GaussianBlur(14 * k)))
    tg = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(tg).text(((W - tw) / 2, ty), title, font=title_font, fill=GLOW + (200,))
    base = Image.alpha_composite(base, tg.filter(ImageFilter.GaussianBlur(18 * k)))
    d = ImageDraw.Draw(base)
    d.text(((W - tw) / 2, ty), title, font=title_font, fill=TITLE)
    sub = "Defend a tiny village with your bare hands. Then turn back time."
    sw = d.textlength(sub, font=sub_font)
    # dark soft shadow so the tagline reads over a busy close-up
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).text(((W - sw) / 2, sy), sub, font=sub_font, fill=TOP + (255,), stroke_width=round(6 * k), stroke_fill=TOP + (255,))
    base = Image.alpha_composite(base, sh.filter(ImageFilter.GaussianBlur(8 * k)))
    d = ImageDraw.Draw(base)
    d.text(((W - sw) / 2, sy), sub, font=sub_font, fill=SUB)

    base.convert("RGB").save(out, quality=95)
    print("saved", out)


if __name__ == "__main__":
    if len(sys.argv) > 4:
        _resize(*(int(v) for v in sys.argv[4].lower().split("x")))
    main(sys.argv[1], sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 0.0)
