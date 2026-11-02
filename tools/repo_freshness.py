"""Keep this checkout in step with GitHub. Runs from Claude Code hooks (.claude/settings.json) at session start and on
every prompt, and by hand: python tools/repo_freshness.py [--force]

Fast-forwards main when that is safe. Never merges, rebases, stashes or pushes: if it cannot update safely it says why,
and the agent deals with it. Prints nothing when the repo is up to date. Always exits 0, so it can never block a prompt.
"""
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
THROTTLE_SECONDS = 120  # prompts sent close together share one fetch
FETCH_TIMEOUT = 20
PULL_TIMEOUT = 150  # a pull also downloads the LFS files


def git(*args, timeout=FETCH_TIMEOUT):
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0")  # a missing login must fail, not wait on a hidden prompt
    return subprocess.run(["git", *args], cwd=ROOT, env=env, capture_output=True, text=True, timeout=timeout)


def throttled():
    stamp = os.path.join(git("rev-parse", "--absolute-git-dir").stdout.strip(), "ew_freshness_stamp")
    try:
        if time.time() - os.path.getmtime(stamp) < THROTTLE_SECONDS:
            return True
    except OSError:
        pass
    with open(stamp, "w"):
        pass
    return False


def check():
    if "--force" not in sys.argv and throttled():
        return
    fetch = git("fetch", "origin", "main")
    if fetch.returncode != 0:
        print("[repo] Could not reach GitHub, so this checkout may be out of date: " + fetch.stderr.strip()[:200])
        return
    counts = git("rev-list", "--left-right", "--count", "HEAD...origin/main").stdout.split()
    ahead, behind = int(counts[0]), int(counts[1])
    branch = git("rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
    if ahead:
        print("[repo] %d local commit(s) are not on GitHub yet: run the github-sync skill." % ahead)
    if not behind:
        return
    dirty = git("status", "--porcelain", "--untracked-files=no").stdout.strip()
    if branch != "main" or ahead or dirty:
        why = "on branch %s" % branch if branch != "main" else "local commits exist" if ahead else "uncommitted changes exist"
        print("[repo] %d commit(s) behind GitHub, NOT pulled (%s). Sync before relying on these files: git pull --rebase" % (behind, why))
        return
    pull = git("pull", "--ff-only", "origin", "main", timeout=PULL_TIMEOUT)
    if pull.returncode != 0:
        print("[repo] %d commit(s) behind GitHub and the pull failed: %s" % (behind, pull.stderr.strip()[:300]))
        return
    log = git("log", "--format=%an: %s", "-n", str(min(behind, 5)), "HEAD").stdout.strip()
    print("[repo] Pulled %d new commit(s) from GitHub. Files may have changed since you last read them.\n%s" % (behind, log))


if __name__ == "__main__":
    try:
        check()
    except (OSError, ValueError, IndexError, subprocess.SubprocessError) as err:
        print("[repo] Freshness check failed: %s" % err)
