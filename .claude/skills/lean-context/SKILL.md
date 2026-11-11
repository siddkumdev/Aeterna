---
name: lean-context
description: How to work on Aeterna without filling the context window - where to start after a break or compaction, how to look at code without reading whole files, how to run the tests and shots quietly, and what to write down before stopping. Use at the start of every session, after every compaction, and before reading any script over 10 KB (game.gd, game_selftest.gd, spells.gd, vfx_kit.gd).
---

# lean-context

Asked for by the teammate (sykeriin), 2026-11-11: "make a workflow, skills and rules so you dont waste context and optimise tokens". Rules live in `AGENTS.md` section 7; this is the how.

## 1. Starting (new session, after a break, after compaction)
1. Read `docs/STATUS.md`. It is the handoff: what is done, what is untested on the headset, what is open, what the user decided. Do not re-derive this from the transcript or from `git log`.
2. `git status -sb` and `git log --oneline -8`. If a teammate's commits arrived, look at what they touched with `git show --stat <hash>` before re-reading anything.
3. Only then open code, and only the part the task needs (section 2).

## 2. Looking at code
| Need | Command | Not this |
|---|---|---|
| What is in a script | `python tools/code_map.py game` (outline with line numbers) | Read of the whole file |
| One or a few functions | `python tools/code_map.py game sell sell_value` | Read of the whole file |
| Who defines or calls something | `python tools/code_map.py --find tap_villager` | several Greps |
| Which scripts are big | `python tools/code_map.py` | `ls -l` plus guessing |
| A known line range | Read with `offset` and `limit` | Read without them |

- Edit straight from the function body the tool printed; a Read first is not needed inside the repo.
- Never read `game.gd` or `game_selftest.gd` whole. Scripts under about 10 KB may be read whole when most of the file matters.
- Never read `.glb`, `.blend`, `.import`, `.uid`, `godot/.godot/` or `godot/android/build/` except the manifest.
- Data files: `godot/data/thoughts.json` is large. Query it with a Python one-liner (one villager, one loop) rather than reading it.

## 3. Running things
| Need | Command |
|---|---|
| Self-test | `python tools/selftest.py` (prints FAIL lines, errors and the total only; `--import` after a new `class_name` or asset; `--all` for everything) |
| Asset check | `python tools/sync_to_godot.py --check`, piped through `tail -5` |
| A shot | run the shot tool, then Read only the one PNG that shows the change |
| Any chatty command | pipe through `tail -n 20` or `grep -E "FAIL|ERROR"`; never let a full Godot or Gradle log into the conversation |

- Batch independent commands in one call.
- One shot per change. Look at it once. Do not re-render to "double check" without changing something.
- The Quest export runs in the user's own PowerShell (skill `quest-build`); do not start it from here.

## 4. Subagents and critics
- Spawn only what `AGENTS.md` asks for (code-critic, player-critic, art-critic) or what the user asks for. Give each the commit range and the two or three files that matter, not "review the project".
- Ask for a verdict plus at most ten findings, each with `file:line`.
- If the spawn is refused twice, stop retrying and say the critic did not run.

## 5. Asking and reporting
- Collect open design questions and ask them together in one AskUserQuestion, after doing everything that does not depend on the answers.
- Reports: result first, then what changed, then what is unverified. No recap of earlier turns.

## 6. Before stopping, and before a compaction
Update `docs/STATUS.md` (move items between its lists, add new decisions with the date and who decided), then commit and push with the rest. Keep it under about 80 lines: delete done items that no longer matter rather than letting it grow.
