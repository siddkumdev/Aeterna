# Setting up Endless Watch on a new PC

Everything the two of us need to work from the same project. Windows 11.

## 1. Install (same versions on both machines)
| Tool | Version | Notes |
|---|---|---|
| Git for Windows | any recent | includes Git LFS |
| Python | 3.10 or newer | then `python -m pip install pillow` |
| Blender | 4.5 (LTS) | default install folder is fine |
| Godot | 4.7.2 stable, win64 | it is a zip: keep the folder with both the editor exe and the `_console.exe` |
| Meta XR Simulator | 207.1 | only needed to run the game in VR mode; never run its "activate" script (it changes a system setting) |
| Claude Code | desktop app | open the repo folder as the project |

## 2. Get the project
```
git lfs install
git clone <repo url> MetaHackathon
```
`git lfs install` once per machine; it makes clone/pull fetch the `.blend`, `.glb` and image files.

## 3. Tell the tools where things are
Copy `local.env.example` to `local.env` (same folder) and fix the three paths for your machine. `local.env` is never committed: each person has their own.

## 4. Check the machine
```
python tools/doctor.py
```
Fix anything marked FIX until it says "All good." (The last item, the Godot import cache, is fixed by step 5.)

## 5. Import the models into Godot once
```
python tools/sync_to_godot.py --check
```
Must end with `0 FAIL`.

## 6. Try it
- Logic self-test: `"<GODOT_EXE>" --headless --xr-mode off --path godot -s res://scripts/selftest.gd` must end with `ALL PASSED`.
- Render a sheet: `python tools/make_sheet.py assets/blend/crossbow_tower.blend _work/test_sheet` (writes `_work/test_sheet/sheet.png`).
- Run the game in the simulator: `powershell -File godot\run_sim.ps1`.

## 7. Claude Code extras (come with the repo)
- Project skills and the art critic load automatically. `CLAUDE.md` (rules) imports `AGENTS.md` (how the agent behaves).
- When you open the project, Claude Code may ask you to trust the project settings: they add Siddharth's `i-have-adhd` plugin (from GitHub `ayghri/i-have-adhd`; it only switches on if you type `/i-have-adhd`) and the Blender MCP server.
- Blender MCP (optional, for letting Claude look at a live Blender scene): install `uv` (`python -m pip install uv`), install the Blender add-on that `mcp-for-blender` documents, and approve the `blender` server when asked. The asset pipeline itself does not need it.

## 8. How we work together
- **Tracker:** the live asset tracker is a private claude.ai page owned by Siddharth; he shares it from the page's Share menu. Put your name as owner on an item before starting it.
- **One owner per asset.** Everyone works on `main` (no new branches unless really needed); `git pull` before you start.
- **Never edit `.blend` or `.glb` by hand.** Change the generator in `assets/generators/` and regenerate; binary files cannot be merged.
- **Logs are add-a-row** (`assets/ASSETS.md`, `art/decisions.md`, `docs/VFX_NOTES.md`, `docs/ASSET_LIST.md`). On a merge conflict keep both rows.
- **Approval:** either of us can approve an asset (`approved by <name> (date)` in `ASSETS.md`); then push.
- **GitHub stays current:** Claude commits and pushes after every change (skill `github-sync`), with no Claude co-author lines. Pull before you start.
- **Claude:** project rules are in `CLAUDE.md`; workflows are skills in `.claude/skills/` (start an asset with "make-asset"). They come with the repo, so both Claudes behave the same.
- The repo stays **private**: the moodboard contains other people's images.
