"""Regenerate the asset tracker page from docs/ASSET_LIST.md (items) and assets/ASSETS.md (build badges).

    python tools/sync_tracker.py [--against PUBLISHED.html]

- Items: every row of docs/ASSET_LIST.md with a priority that is not REMOVED. "Open: ..." text in the
  notes becomes the item's open question. Category titles come from the "## <KEY> <title>" headings,
  blurbs are kept from the current page.
- Build badges: the newest assets/ASSETS.md row for each tracker id (the `id` column) shows as
  "Build: v03 · awaiting Siddharth". Rows marked superseded are skipped.
- Writes docs/Endless Watch Assets.html (same page, new data) and docs/tracker_sync.json, which holds
  the state each built item should have at least (Siddharth's mapping, 2026-10-17):
  built/in progress -> doing, awaiting -> review, approved by <either teammate> -> done.
  Claude then republishes the page and moves shared states forward only (tracker-sync skill).
Prints what changed against the previous page: items added, removed, renamed, badges.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIST = os.path.join(ROOT, "docs", "ASSET_LIST.md")
LOG = os.path.join(ROOT, "assets", "ASSETS.md")
PAGE = os.path.join(ROOT, "docs", "Endless Watch Assets.html")
SYNC = os.path.join(ROOT, "docs", "tracker_sync.json")
RANK = {"todo": 0, "doing": 1, "review": 2, "done": 3}

# Page additions (idempotent): a build badge in each row.
BADGE_CSS = ".build{font-size:11.5px;border-radius:5px;padding:1px 7px;font-family:var(--f-mono);color:var(--ink);background:var(--surface2);border:1px solid var(--line)}"
BADGE_JS = '  if (i.build) meta.appendChild(el("span","build","Build: "+i.build));\n'


def cells(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def parse_list():
    cats, items, cat = [], [], None
    for line in open(LIST, encoding="utf-8"):
        m = re.match(r"## ([A-Z]{1,2}) (.+)", line)
        if m:
            cat = m.group(1)
            cats.append({"key": cat, "title": m.group(2).strip()})
            continue
        if not cat or not re.match(r"\|\s*[A-Z]{1,2}\d+\s*\|", line):
            continue
        c = [x.replace("`", "") for x in cells(line)]  # the page shows plain text
        if len(c) == 6:  # row without a budget cell
            c = c[:5] + [""] + c[5:]
        iid, pri, kind, name, notes, budget, change = (c + [""] * 7)[:7]
        if not pri or "REMOVED" in change:
            continue
        om = re.search(r"Open: (.+?)(?:\.\s|\.$|$)", notes)
        items.append({"id": iid, "cat": re.match(r"[A-Z]+", iid).group(0), "name": name, "notes": notes,
                      "pri": pri, "kind": kind, "budget": budget, "open": om.group(1).strip() if om else ""})
    return cats, items


def parse_log():
    builds = {}
    for line in open(LOG, encoding="utf-8"):
        if not line.startswith("| ew_"):
            continue
        name, iid, _cat, _gen, ver, _tris, status = cells(line)[:7]
        if not iid or "superseded" in status.lower():
            continue
        s = status.lower()
        state = "done" if "approved by" in s else "review" if "awaiting" in s else "doing"
        word = {"done": "approved", "review": "awaiting approval", "doing": "in progress"}[state]
        builds[iid] = {"text": "%s · %s" % (ver, word), "state": state}
    return builds  # later rows overwrite earlier ones: the newest version wins


def main():
    page = open(PAGE, encoding="utf-8").read()
    i = page.index("const DATA = ") + len("const DATA = ")
    old, end = json.JSONDecoder().raw_decode(page[i:])
    if "--against" in sys.argv:  # report changes against another copy (e.g. the live page) instead
        other = open(sys.argv[sys.argv.index("--against") + 1], encoding="utf-8").read()
        j = other.index("const DATA = ") + len("const DATA = ")
        old_report = json.JSONDecoder().raw_decode(other[j:])[0]
    else:
        old_report = old
    cats, items = parse_list()
    blurbs = {c["key"]: c.get("blurb", "") for c in old["cats"]}
    for c in cats:
        c["blurb"] = blurbs.get(c["key"], "")
    builds = parse_log()
    for it in items:
        if it["id"] in builds:
            it["build"] = builds[it["id"]]["text"]
    missing = [k for k in builds if k not in {it["id"] for it in items}]
    data = {"cats": cats, "items": items}

    new = page[:i] + json.dumps(data, ensure_ascii=False, separators=(",", ":")) + page[i + end:]
    if ".build{" not in new:
        new = new.replace("</style>\n\n<div class=\"wrap\">", BADGE_CSS + "\n</style>\n\n<div class=\"wrap\">", 1)
    if 'el("span","build"' not in new:
        anchor = '  if (i.open) meta.appendChild(el("span","open","Open: "+i.open));\n'
        new = new.replace(anchor, anchor + BADGE_JS, 1)
    if ".build{" not in new or 'el("span","build"' not in new:
        sys.exit("could not add the build badge to the page (template changed?)")
    open(PAGE, "w", encoding="utf-8", newline="\n").write(new)
    json.dump({"min_state": {k: v["state"] for k, v in builds.items()}, "rank": RANK},
              open(SYNC, "w", encoding="utf-8"), indent=2)

    o = {it["id"]: it for it in old_report["items"]}
    n = {it["id"]: it for it in items}
    print("items: %d (was %d)" % (len(n), len(o)))
    for k in n.keys() - o.keys():
        print("  added    %s %s" % (k, n[k]["name"]))
    for k in o.keys() - n.keys():
        print("  removed  %s %s" % (k, o[k]["name"]))
    for k in sorted(n.keys() & o.keys()):
        if n[k]["name"] != o[k]["name"]:
            print("  renamed  %s %s -> %s" % (k, o[k]["name"], n[k]["name"]))
    changed = sum(1 for k in n.keys() & o.keys() if n[k] != o[k])
    print("  %d kept items have changed text, priority or badge" % changed)
    for k, b in builds.items():
        print("badge    %s  %s  (state at least: %s)" % (k, b["text"], b["state"]))
    for k in missing:
        print("WARNING  ASSETS.md id %s is not an item in ASSET_LIST.md" % k)
    print("wrote", os.path.relpath(PAGE, ROOT), "and", os.path.relpath(SYNC, ROOT))


if __name__ == "__main__":
    main()
