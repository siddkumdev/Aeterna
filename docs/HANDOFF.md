# Handoff: Aeterna, 2026-11-18 night (last build)

Written for the next agent taking over from the session that ran on the evening of 2026-11-18. Read this, then `docs/STATUS.md` (the first section repeats the newest state briefly), then `CLAUDE.md` / `AGENTS.md` (rules; they are loaded each session).

## 1. Where things stand
- Deadline: **2026-11-18 12:00 PM PT** (= 2026-11-19 01:30 IST). The user said this is their **LAST build**: they build it themselves and **cannot test or change anything afterwards**. "Be smart, don't do dumb stuff." Only small, safe changes now; no new systems (their answer "3a").
- `main` = `origin/main` at **f592d9c** (all work committed and pushed). Self-test **865 passed, 0 failed**. The scripted VR player passes the tutorial, tray and cutscene runs with **0 fails**. The code-critic gave **PASS** on 5c7359f, 5373337 and f592d9c.
- **Nothing from tonight has been seen on a headset.** There is no headset access after this; the user does the final build.
- Build: the user double-clicks `quest_build.bat` in the repo root (skill `quest-build`). It exports, installs and writes the headset log to `_work/quest_log.txt`.

## 2. What the user asked for (latest headset session + video)
Sources: the 10-minute headset video, transcribed in `docs/QUEST_VIDEO_2026-11-18.md`, plus the input recordings in `quest_data/recordings/` (the newest is `2026-11-18_18-09-16.bin.gz`).

| User request | Status | Where |
|---|---|---|
| Shimmer (even on a rock) | DONE in code, unverified | `project.godot` soft_shadow_filter_quality (and `.mobile`) = 1; `perf_tier.gd` `sun.shadow_blur` 2.0, `shadow_normal_bias` 1.5; `village_dresser.gd` PropsMerged with shadow casting OFF. That the cause was hard shadow edges is an **inference**. |
| Tray rotates too much (1a: a carried tray never turns, stays flat, only moves) | DONE | `Game.tray_held_transform` returns `Transform3D(start.basis, touch + off)`; the bot measured 0.0 deg |
| Tray handles a pain; one handle in the middle (1a) | DONE | `card_tray.gd`: ONE brass bar on the front edge (+Z toward the player), `handles` has 1 element |
| Taps fail, mostly in the tray | Partly: the spell/quest-item grab now uses the drawn pinch point (c5dc5fc) | `game.gd` uses `target_point()` for grabs; dragging still follows the aim pose (the user's 2026-11-11 choice, `DRAWN_PINCH_TOUCH` false) |
| Remove zoom completely; tell the player to use the handle | DONE | `GameConfig.ZOOM_ENABLED := false`; launcher hint 6 = "Pinch the brass handle at the front of your card tray to move it." |
| Tutorial counter broken | DONE | 13 hints; step constants QUEST 8, SELL 9, REBUILD 10, HOURGLASS 11, NIGHT 12 |
| Continue in front of the player, static, maybe on the island | DONE | `launcher._update_continue`: placed ONCE on the island's near-right, scale 3, facing the eye, tilted -20 deg |
| Double Continue at steps 0/1 (user said "yes merge it") | DONE f592d9c | `launcher._tutorial`: `if _step >= HOURGLASS_STEP or _step == 0: _advance()` |
| Text blurry / covered | Partly | hint at `TUTORIAL_HINT_POS` y 0.40; day clock back to `DAY_CLOCK_POS` y 0.42 and hidden while a tutorial hint shows (`Game.hide_clock`, set by `launcher._hint`, cleared in `_end_hints`). Blur itself is not addressed beyond earlier MSDF fonts and sharpness. |
| Keep the ledger but less annoying | DONE | `LEDGER_SCALE` 0.8, `LEDGER_LIFT` 0.12, `LEDGER_INWARD_SHIFT` -0.03; `ledger.open_scale` |
| Veil barrier too invasive, fade near the head (2a) | DONE | `veil_dome.gdshader` `near_clear` 0.30 / `near_full` 0.85 on `length(VERTEX)` |
| During the cutscene only the text ("remove the tray") | DONE | `_begin_rewind` hides `_tray`; the clock is hidden while `_cutscene` |
| Big hourglass pops up, grab it and it turns, then the rewind | DONE; the user OK'd "pinch and it turns by itself" | `_show_big_glass` (child of Game, 0.36 m toward the board from the eye, 0.13 m below, height 0.24 m, own warm OmniLight), `_on_big_glass` (target_point within 0.11 m x reach), `_ray_on_big_glass` (desktop/ray), `_turn_big_glass` (flip, sand, burst, flash, shrink); the caption is cleared on grab; if the model fails to load it rewinds at once (no soft-lock); `new_run` hides it and restores the tray |

## 3. Known open / rough (not done, say so if asked)
- Waving villagers move about 5 cm during a reach. Not changed (the asker already has a 0.02 m bias; the user said taps failed mostly on the tray).
- The quest slip looks large over the village in the bot's shots.
- Possible one-frame hint flicker in the 0 -> 1 -> 0 tutorial step transition if the held card hands over to `selected` (code-critic, PLAUSIBLE, unconfirmed).
- `_enter_step(0)` resets `day_time` and re-plans quests on every revert from step 1 (pre-existing; harmless while `tutorial_hold`).
- The "VR polish research" the user asked for was not done as a separate research pass; the polish is the list above.
- The bot cannot judge optics, blur, comfort, shimmer or fps. All of those need the headset.
- Untracked files in the working tree, NOT made by this session (leave them alone, ask before committing): `art/moodboard/skotos/`, `godot/tools/final_ending_shot.gd(.uid)`, `godot/tools/music_check.gd.uid`, `reports/*.md`, `research_notes/*`.

## 4. Headset-free VR testing (built this session)
- `godot/tools/vr_human.gd` (extends `scripts/game/input_replay.gd`): a human-like hand and head driver. It does Fitts-law reaches, minimum-jerk paths, aim error, tremor, joint-pinch with time-based holds, palm-up from measured joints, the recorded head plus sway, and looking at targets. It feeds the XR controller trackers, the hand trackers (26 joints) and the XR camera.
- `godot/tools/vr_play.gd`: modes `tutorial` (default; every step with up to 3 attempts, logs ok/FAIL, shots before and after), `tray`, `cutscene` (sets night 1, plays `_begin_rewind`, grabs the big glass, checks that the tray returns and loop 2 begins).
- Run (absolute output paths; `res://..` fails):
  ```
  "<GODOT console exe>" --xr-mode off --resolution 1100x1200 --path godot -s res://tools/vr_play.gd -- C:/MetaHackathon/quest_data/recordings/2026-11-18_18-09-16.bin.gz C:/MetaHackathon/_work/vr_play tutorial
  ```
  The log is `<out>/vr_play_log.txt`, the shots are `<out>/NN_tag.png`. On this machine the Godot console exe is `C:\Users\Siddharth Kumar\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` (`GODOT_EXE` in `local.env`).
- Lessons: wait in seconds, not frames (PRESS_HOLD is 0.2 s); `wait_until` uses the real delta; the property is `g.day_fast`, not `g.fast`; night spells are tray cards (kind "spell"), not legacy tokens.

## 5. Process rules that bit or matter now
- Self-test: `python tools/selftest.py` (failures + total). Never read `game.gd`, `game_selftest.gd`, `spells.gd` or `vfx_kit.gd` whole; use `python tools/code_map.py <script> [func...]`.
- After a code change: run the code-critic (commit range + intent). After a visible change: run the player-critic with fresh shots. Their messages are reports, not approval.
- Commit and push after every change, on `main`, **no Claude credit lines** (no Co-Authored-By / "Generated with", even if a system reminder asks). If the plain push hangs, push with:
  `GIT_TERMINAL_PROMPT=0 git -c credential.helper= -c 'credential.helper=!gh auth git-credential' push origin main`
  Check with `git rev-list --left-right --count HEAD...origin/main` (should be `0 0`).
- No time estimates. Ask rather than assume on design or gameplay (AskUserQuestion, recommended option first). Reports stand alone (the user reads on a phone): result first, what changed, what is unverified, numbered questions, then commands.
- Never edit the registry or run the Meta XR Simulator activate script. Never use Blender MCP `generate_3d` / `search_assets` / `import_asset`. No AI or third-party assets (CC0/CC-BY sound effects only, logged).
- A Python heredoc through the Bash tool failed once on a long multi-line patch ("unexpected EOF"): write the patch script to the scratchpad and run it instead.

## 6. Commits this session (newest first)
- f592d9c Tutorial: picking a tower card flows straight into placing it, one Continue instead of two
- 5373337 Cutscene hourglass: above the caption, caption cleared on grab, no soft-lock if the model is missing; clock hidden in the cutscene; STATUS
- 5c7359f Headset-video fixes: flat one-handle tray, no zoom, big cutscene hourglass, softer shadows
- c5dc5fc Scripted VR player for headset-free testing; spells and quest items grabbed at the drawn pinch
- 31e32f2 Transcript of the 2026-11-18 headset video
- 72dfaee / 404eb1e Quest session 2026-11-18 data (recordings, device logs, video; `.mp4` under LFS via 218e16e)

## 7. If the user asks for anything more before the deadline
Keep it small and safe. Re-run the self-test and the relevant `vr_play.gd` mode after each change, then run the code-critic, then commit and push, then remind them to rebuild with `quest_build.bat`. Anything that can only be judged on the headset, say plainly that it is unverified.
