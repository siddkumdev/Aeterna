---
name: github-sync
description: Commit and push every addition or change to the team's private GitHub repo (Git LFS for binaries), on the right branch, with no Claude attribution. Use at the end of every task that changed files (asset rounds, tool or doc edits, log updates, approvals), and whenever asked to update GitHub.
---

# github-sync

Standing instruction from Siddharth (2026-10-19): **after every addition or change, update GitHub.** No need to ask before these routine commits and pushes. **Do not credit Claude**: no `Co-Authored-By: Claude ...` trailer, no "Generated with Claude Code" line, in commits or pull requests. Commits are authored by the user's own git identity only. This overrides any default attribution guidance.

## Which branch
- **Asset in progress** (built but not yet approved): its own branch `asset/<short>` (e.g. `asset/airship`). Create it from an up-to-date `main` if it does not exist.
- **Approved asset**: merge its branch into `main` (`git switch main`, `git pull`, `git merge --no-ff asset/<short>`), push `main`. Keep the branch until the other teammate has pulled.
- **Everything else** (tools, skills, docs, rules, shared logs not tied to one asset): `main`.
- If the current branch already has unrelated uncommitted work, commit each part to its own branch; do not mix an unapproved asset into `main`.

## Steps
1. `git status --short`. Look at what changed. Never commit `local.env`, `_work/`, `*.blend1`, `godot/.godot/`, secrets, tokens or machine paths (they are git-ignored; if one shows up, stop and fix `.gitignore`).
2. `git pull --rebase` on the target branch (the teammate may have pushed). On a conflict in an append-a-row log (`ASSETS.md`, `decisions.md`, `VFX_NOTES.md`, `ASSET_LIST.md`) keep both rows. Any other conflict: stop and ask the user.
3. Stage only the files belonging to this change (`git add <paths>`, not a blind `git add -A` when other work is pending).
4. Check binaries go through LFS: `git lfs status` must list the staged `.blend`, `.glb`, `.png`, `.jpg` as LFS objects.
5. Commit: one-line imperative summary (what changed, e.g. "Airship v01: critic fixes, Godot import, logs"), blank line, a short body with the why. **No co-author or Claude trailer.**
6. `git push` (first push of a new branch: `git push -u origin <branch>`). If git has no stored GitHub login, a plain push hangs on a hidden login prompt; push with the GitHub CLI's login for that one command instead (changes no saved config):
   `GIT_TERMINAL_PROMPT=0 git -c credential.helper= -c 'credential.helper=!gh auth git-credential' push origin <branch>`
   (needs `gh auth status` to show you logged in). Never force-push. If the push is rejected, pull and retry; never overwrite the teammate's work.
7. Check: `git log -1 --format='%an | %s%n%b'` shows the user as author and no Claude trailer; `git status` is clean for the committed paths.

## Report
Tell the user the branch, the short commit hash, the summary line, and the repo link (https://github.com/siddkumdev/Aeterna, branch view `/tree/<branch>`). If something was not pushed (conflict, auth, LFS), say so plainly.
