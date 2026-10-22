---
name: tracker-sync
description: Regenerate and republish Siddharth's live asset tracker (claude.ai artifact "Aeterna Assets") from docs/ASSET_LIST.md and assets/ASSETS.md, adding build badges and moving built items' shared status forward (never backwards). Run after every asset round (make-asset log step), whenever ASSET_LIST.md or ASSETS.md changes, or when asked to sync/update the tracker.
---

# tracker-sync

Decided with Siddharth (2026-10-17): runs **after every asset round**, **always republishes** the same link, shows a **build badge** per built item and moves its shared state **forward only**.

- Live page: https://claude.ai/artifact/8oCkgCTG1HLBgBhtkA1w2a (private; capabilities `db` + `user`, keep them: omit `capabilities` on publish).
- Local copy: `docs/Endless Watch Assets.html` (page code + `const DATA = {...}`).
- Shared state lives in the page's database, collection `status`, doc id = item id, fields `{state, owner, note}`; state is one of `todo`, `doing`, `review`, `done`. People change it on the page; **never touch `owner` or `note`, never move a state backwards.**

## Sources
- Items: `docs/ASSET_LIST.md` rows with a priority that are not REMOVED. `Open: ...` in the notes becomes the item's open question. Category titles from the `## <KEY> <title>` headings; blurbs kept from the page.
- Build badges: `assets/ASSETS.md`, column `id` = tracker item id (every new row needs it; several rows can share one id, e.g. the benchmark trio = PF07). The newest non-superseded row per id wins.
- Mapping (Siddharth): status contains "approved by" (Siddharth or his teammate) -> **done**; contains "awaiting" -> **review**; anything else (built, in progress) -> **doing**.

## Steps
1. Read the live page first: `Artifact` action `read` on the URL (required before republishing; also catches edits made elsewhere). If its page code differs from the local copy (not just DATA), merge the live code into `docs/Endless Watch Assets.html` before continuing.
2. Regenerate: `python tools/sync_tracker.py --against <saved live html path from step 1>`
   Prints items added / removed / renamed vs the live page, the badges, and warnings (an ASSETS.md id missing from the list). Writes the local page and `docs/tracker_sync.json` (`min_state` per id).
3. Optional quick look: open the local file in the browser pane and check a badge renders.
4. Republish: `Artifact` publish with `url` = the live link and `file_path` = `docs/Endless Watch Assets.html`, a short `label` ("Tracker sync <date>").
5. Move states forward: `ArtifactData` list `status` (limit 1000). For each id in `min_state`: if the doc is missing, create it `{state, owner:"", note:""}`; if its state ranks lower (todo < doing < review < done), `update` only `{state}` with `if_version`. Do all writes in one `batch`. Leave every other doc alone.
6. Report to Siddharth: the change summary (added/removed/renamed counts plus notable ones), badges, which states moved (from -> to), the link, and the command.

## Notes
- Item ids are stable: an id whose meaning CHANGED (e.g. D01 Archer -> Fire Tower) keeps its saved progress on purpose; REMOVED ids disappear from the page but their saved status stays in the database, harmless.
- The script adds the badge CSS/JS to the page only if missing, so it is safe to run repeatedly.
- Never publish the tracker as a new artifact; always the same URL.
