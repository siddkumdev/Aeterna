#!/usr/bin/env python3
"""bee2md: turn a BeeRef .bee moodboard into files Claude (and humans) can read.

Usage:  python3 -I bee2md.py BOARD.bee OUTDIR [groups.json]
        groups.json (optional) overrides grouping: {"island": [1,2,3], "ui": [37,38,41]}
Output: OUTDIR/BOARD.md        readable report (start here)
        OUTDIR/index.json      machine-readable item list
        OUTDIR/images/         every image, original bytes, named img_<id>.<ext>
        OUTDIR/overview.jpg    whole board, every image labelled with its id
        OUTDIR/sections/*.jpg  one contact sheet per labelled section
Read-only on the .bee. Needs Pillow.
"""
import sqlite3, sys, os, json, zlib, math, re, hashlib, collections, pathlib
if hasattr(sys.stdout, "reconfigure"): sys.stdout.reconfigure(encoding="utf-8", errors="replace")
from PIL import Image, ImageDraw, ImageFont, ImageOps

MAX_BYTES = 64 * 1024 * 1024          # per-image decompression cap
LINK = re.compile(r"^\s*https?://", re.I)

def font(sz):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
              "C:/Windows/Fonts/arialbd.ttf"):
        try: return ImageFont.truetype(p, sz)
        except Exception: pass
    return ImageFont.load_default()

def inflate(blob, sz):
    if sz == len(blob): return blob                      # stored raw
    d = zlib.decompressobj(); out = d.decompress(blob, MAX_BYTES)
    if d.unconsumed_tail: raise ValueError("image too large")
    return out

def sniff(raw):
    if raw[:4] == b"\x89PNG": return "png"
    if raw[:2] == b"\xff\xd8": return "jpg"
    if raw[8:12] == b"WEBP": return "webp"
    if raw[:3] == b"GIF": return "gif"
    return "bin"

def hexc(c): return "%02X%02X%02X" % c

def palette(im, n=8):
    """Dominant colours, ignoring transparent pixels. Returns [(hex, percent)]."""
    im = im.convert("RGBA"); im.thumbnail((160, 160))
    data = im.get_flattened_data() if hasattr(im, 'get_flattened_data') else im.getdata()
    px = [p[:3] for p in data if p[3] > 200]
    if not px: return []
    t = Image.new("RGB", (len(px), 1)); t.putdata(px)
    q = t.quantize(colors=n, method=Image.Quantize.MEDIANCUT)
    pal = q.getpalette(); cnt = sorted(q.getcolors(), reverse=True)
    tot = sum(c for c, _ in cnt)
    return [(hexc(tuple(pal[i*3:i*3+3])), round(100*c/tot)) for c, i in cnt]

def is_blank(im):
    a = im.convert("RGBA").getchannel("A")
    if a.getextrema()[1] < 10: return "fully transparent"
    g = im.convert("L").getextrema()
    if g[1] - g[0] < 4: return "single flat colour"
    return None

def main(src, out, groups_file=None):
    os.makedirs(os.path.join(out, "images"), exist_ok=True)
    os.makedirs(os.path.join(out, "sections"), exist_ok=True)
    db = sqlite3.connect(pathlib.Path(src).resolve().as_uri() + "?mode=ro", uri=True)
    rows = db.execute("select id,type,x,y,z,scale,rotation,flip,data from items").fetchall()
    blobs = {r[0]: r[1:] for r in db.execute("select item_id,name,sz,data from sqlar")}
    items = []
    for id_, typ, x, y, z, sc, rot, flip, data in rows:
        d = json.loads(data) if data else {}
        r = dict(id=id_, type=typ, x=x, y=y, z=z, scale=sc, rot=rot, flip=flip)
        if typ == "text":
            r["text"] = d.get("text", "").replace("\ufffc", "").strip()
        elif id_ in blobs:
            name, sz, blob = blobs[id_]
            try: raw = inflate(blob, sz)
            except Exception as e: r["error"] = str(e); items.append(r); continue
            fn = "img_%03d.%s" % (id_, sniff(raw))
            open(os.path.join(out, "images", fn), "wb").write(raw)
            im = Image.open(os.path.join(out, "images", fn)); im.load()
            crop = d.get("crop")                         # [x, y, w, h] in image px
            was_cropped = bool(crop) and (crop[2] < im.width or crop[3] < im.height)
            if was_cropped:
                im = im.crop((int(crop[0]), int(crop[1]), int(crop[0]+crop[2]), int(crop[1]+crop[3])))
            r.update(file=fn, orig_name=name, bytes=len(raw), px=im.size, cropped=was_cropped,
                     W=im.width*sc, H=im.height*sc, opacity=d.get("opacity", 1.0),
                     grayscale=d.get("grayscale", False))
            r["blank"] = is_blank(im); r["palette"] = [] if r["blank"] else palette(im)
            r["_im"] = im
        items.append(r)
    imgs = [r for r in items if "_im" in r]
    texts = [r for r in items if r["type"] == "text"]
    for t in texts:
        t["W"], t["H"] = 5 * len(t["text"]) * t["scale"], 40 * t["scale"]
    labels = [t for t in texts if not LINK.match(t["text"])]
    links = [t for t in texts if LINK.match(t["text"])]

    # duplicates
    seen = collections.defaultdict(list)
    for r in imgs: seen[hashlib.md5(open(os.path.join(out, "images", r["file"]), "rb").read()).hexdigest()].append(r["id"])
    dupes = [v for v in seen.values() if len(v) > 1]

    # Grouping. In most boards a text note is a CAPTION placed just BELOW its images, so each
    # image goes to the nearest note that sits below it (vertical gap + 2x horizontal offset).
    def owner(r):
        best = None
        for t in labels:
            gap = t["y"] - (r["y"] + r["H"])
            if gap < -0.1 * r["H"]: continue            # note is above the image -> not its caption
            dx = max(r["x"] - (t["x"] + t["W"]), t["x"] - (r["x"] + r["W"]), 0)
            c = max(gap, 0) + 2 * dx
            if best is None or c < best[0]: best = (c, t["id"])
        return best[1] if best else None
    for r in imgs: r["section"] = owner(r)
    override = None
    if groups_file:
        override = json.load(open(groups_file, encoding="utf-8"))
        by_id = {r["id"]: r for r in imgs}
        for name, ids in override.items():
            for i in ids:
                if i in by_id: by_id[i]["section"] = "g:" + name
    def dist(a, b):
        dx = max(a["x"] - (b["x"] + b["W"]), b["x"] - (a["x"] + a["W"]), 0)
        dy = max(a["y"] - (b["y"] + b["H"]), b["y"] - (a["y"] + a["H"]), 0)
        return math.hypot(dx, dy)
    for t in links:                                       # attach links to nearest image
        near = min(imgs, key=lambda r: dist(r, t)) if imgs else None
        t["near_image"] = near["id"] if near else None

    # ---- overview image (honours scale; red box + id on every image)
    allb = items
    minx = min(r["x"] for r in allb); miny = min(r["y"] for r in allb)
    maxx = max(r["x"] + r["W"] for r in allb); maxy = max(r["y"] + r["H"] for r in allb)
    S = 3200 / max(1, maxx - minx)
    ov = Image.new("RGB", (3200, int((maxy - miny) * S) + 20), "white"); d = ImageDraw.Draw(ov); f = font(22)
    for r in sorted(items, key=lambda r: r["z"]):
        X, Y = (r["x"] - minx) * S, (r["y"] - miny) * S
        if "_im" in r:
            w, h = max(8, int(r["W"] * S)), max(8, int(r["H"] * S))
            t = r["_im"].convert("RGBA").resize((w, h)); bg = Image.new("RGBA", t.size, "white")
            ov.paste(Image.alpha_composite(bg, t).convert("RGB"), (int(X), int(Y)))
            d.rectangle([X, Y, X + w, Y + h], outline="red", width=2); d.text((X + 4, Y + 2), str(r["id"]), fill="red", font=f)
        elif r["type"] == "text":
            d.text((X, Y), ("LINK " if LINK.match(r["text"]) else "T: ") + r["text"][:50], fill="blue", font=f)
    ov.save(os.path.join(out, "overview.jpg"), quality=85)

    # ---- one contact sheet per section
    sections = {}                                       # key -> (title, note_id, [images])
    for t in labels:
        sections[t["id"]] = (t["text"], t["id"], [r for r in imgs if r["section"] == t["id"]])
    for name in (override or {}):
        sections["g:" + name] = (name, None, [r for r in imgs if r["section"] == "g:" + name])
    if override:                                        # drop auto sections emptied by overrides
        sections = {k: v for k, v in sections.items() if v[2]}
    for key, (title, nid, mine) in sections.items():
        mine.sort(key=lambda r: (round(r["y"] / 400), r["x"]))
        if not mine: continue
        tiles = []
        for r in mine:
            th = 700; im = r["_im"].convert("RGBA"); w = max(1, int(im.width * th / im.height))
            bg = Image.new("RGBA", (w, th), "white"); bg.alpha_composite(im.resize((w, th)))
            tile = bg.convert("RGB"); dd = ImageDraw.Draw(tile)
            dd.rectangle([0, 0, 110, 40], fill="black"); dd.text((6, 4), "#%d" % r["id"], fill="yellow", font=font(28))
            tiles.append(tile)
        rows_, cur, cw = [], [], 0
        for t_ in tiles:
            if cw + t_.width > 2400 and cur: rows_.append(cur); cur, cw = [], 0
            cur.append(t_); cw += t_.width + 8
        rows_.append(cur)
        sheet = Image.new("RGB", (max(sum(t_.width + 8 for t_ in r_) for r_ in rows_),
                                   sum(700 + 8 for _ in rows_)), "white"); y = 0
        for r_ in rows_:
            x = 0
            for t_ in r_: sheet.paste(t_, (x, y)); x += t_.width + 8
            y += 708
        slug = re.sub(r"[^a-z0-9]+", "_", title.lower()).strip("_")[:40] or "section"
        sheet.save(os.path.join(out, "sections", "%02d_%s.jpg" % (nid if nid is not None else 0, slug)), quality=88)

    # ---- index.json
    clean = [{k: v for k, v in r.items() if k != "_im"} for r in items]
    json.dump(sorted(clean, key=lambda r: r["id"]), open(os.path.join(out, "index.json"), "w", encoding="utf-8"), indent=1, default=list)

    # ---- BOARD.md
    L = ["# Board report: %s" % os.path.basename(src), "",
         "- %d items: %d images, %d text notes (%d are links)" % (len(items), len(imgs), len(labels), len(links)),
         "- Look at `overview.jpg` first (every image has its id), then `sections/` for detail.", ""]
    blanks = [r["id"] for r in imgs if r["blank"]]
    if blanks: L.append("- Blank images (ignore): " + ", ".join("#%d (%s)" % (r["id"], r["blank"]) for r in imgs if r["blank"]))
    if dupes: L.append("- Duplicate images: " + "; ".join("/".join("#%d" % i for i in g) for g in dupes))
    L.append("")
    L.append("## Sections (each text note and the images nearest to it)")
    for key, (title, nid, mine) in sorted(sections.items(), key=lambda kv: (round(min([r["y"] for r in kv[1][2]] or [0]) / 500), min([r["x"] for r in kv[1][2]] or [0]))):
        L += ["", "### %s" % title, "_%simages: %s_" % ("note #%d · " % nid if nid is not None else "manual group · ", ", ".join("#%d" % r["id"] for r in mine) or "none"), ""]
        L += ["| id | size | cropped | dominant colours (hex, %) |", "|---|---|---|---|"]
        for r in mine:
            pal = " ".join("%s %d%%" % p for p in r["palette"][:6]) if r["palette"] else "(blank)"
            L.append("| #%d | %dx%d | %s | %s |" % (r["id"], r["px"][0], r["px"][1], "yes" if r["cropped"] else "", pal))
    empty = [t["text"] for t in labels if not sections.get(t["id"], (0, 0, []))[2]] if not override else []
    if empty: L += ["", "_Notes with no images assigned: " + "; ".join(empty) + "_"]
    if links:
        L += ["", "## Links", ""] + ["- %s (next to image #%s)" % (t["text"], t["near_image"]) for t in links]
    L += ["", "## Caveats", "- Auto-grouping assumes each text note is a caption BELOW its images. Verify against `overview.jpg`; fix wrong ones by rerunning with a groups.json.",
          "- Colours are quantised from the image; treat as a guide, not exact brand values."]
    open(os.path.join(out, "BOARD.md"), "w", encoding="utf-8").write("\n".join(L) + "\n")
    print("\n".join(L))

if __name__ == "__main__":
    if len(sys.argv) not in (3, 4): sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) == 4 else None)
