"""Keep this checkout in step with GitHub. Runs from Claude Code hooks (.claude/settings.json) at session start and on
every prompt, and by hand: python tools/repo_freshness.py [--force]

Fast-forwards main when that is safe. Never merges, rebases, stashes or pushes: if it cannot update safely it says why,
and the agent deals with it. Prints nothing when nothing changed. Always exits 0, so it can never block a prompt.
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
THROTTLE_SECONDS = 120  # prompts sent close together share one fetch; the local comparison still runs every time
FETCH_TIMEOUT = 20
PULL_TIMEOUT = 150  # a pull also downloads the LFS files; stays under the hook's 180 s limit
NOT_YOURS = "Do not stash or commit work you did not make; ask the user if unsure."


class Result:
    def __init__(self, returncode, stdout, stderr):
        self.returncode, self.stdout, self.stderr = returncode, stdout, stderr


def git(*args, timeout=FETCH_TIMEOUT, kill_on_timeout=True):
    """Run git. Output goes to temp files, not pipes: git's child processes keep pipes open after a kill, which would make
    a timeout wait for them. Returns None if it timed out and was left running."""
    # A missing login must fail, not wait on a prompt or a login window.
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0", GCM_INTERACTIVE="never", GIT_ASKPASS="")
    with tempfile.TemporaryFile() as out, tempfile.TemporaryFile() as err:
        proc = subprocess.Popen(["git", *args], cwd=ROOT, env=env, stdin=subprocess.DEVNULL, stdout=out, stderr=err)
        timed_out = False
        try:
            proc.wait(timeout)
        except subprocess.TimeoutExpired:
            if not kill_on_timeout:
                return None
            timed_out = True
            if os.name == "nt":
                subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)], capture_output=True)
            else:
                proc.kill()
            proc.wait()
        out.seek(0)
        err.seek(0)
        stdout = out.read().decode("utf-8", "replace")
        stderr = err.read().decode("utf-8", "replace")
    return Result(124 if timed_out else proc.returncode, stdout, "timed out" if timed_out else stderr)


def git_dir_file(name):
    return os.path.join(git("rev-parse", "--absolute-git-dir").stdout.strip(), name)


def fetch_due():
    try:
        return time.time() - os.path.getmtime(git_dir_file("ew_freshness_stamp")) >= THROTTLE_SECONDS
    except OSError:
        return True


def is_dirty():
    status = git("status", "--porcelain", "--untracked-files=no")
    return status.returncode != 0 or bool(status.stdout.strip())


def session_id():
    """The hook passes JSON on stdin; a run by hand has no session."""
    if "--force" in sys.argv or sys.stdin is None or sys.stdin.isatty():
        return ""
    try:
        return re.sub(r"[^A-Za-z0-9_-]", "", str(json.loads(sys.stdin.read()).get("session_id", "")))
    except ValueError:
        return ""


def recent(rev_range):
    return git("log", "--format=%an: %s", "-n", "5", rev_range).stdout.strip()


def report_moved(session, reported):
    """Tell this session when HEAD moved since its last check (another session may have pulled or committed)."""
    if not session:
        return
    path = git_dir_file("ew_freshness_seen_" + session)
    head = git("rev-parse", "HEAD").stdout.strip()
    try:
        with open(path) as f:
            seen = f.read().strip()
    except OSError:
        seen = head
    if seen != head and not reported:
        print("[repo] The checkout moved since your last prompt (these may be your own commits). Re-read files you rely on.\n" + recent(seen + "..HEAD"))
    with open(path, "w") as f:
        f.write(head)


def pull(behind):
    """Fast-forward. Returns True if the checkout moved and that was reported."""
    marker = git_dir_file("ew_freshness_pull")
    result = git("pull", "--ff-only", "origin", "main", timeout=PULL_TIMEOUT, kill_on_timeout=False)
    if result is None:
        with open(marker, "w") as f:
            f.write("timed out")
        print("[repo] The pull of %d commit(s) is still running in the background. Do not edit files yet." % behind)
        return False
    if result.returncode != 0:
        reason = result.stderr.strip()[-300:]
        if is_dirty():
            with open(marker, "w") as f:
                f.write(reason)
        print("[repo] %d commit(s) behind GitHub and the pull failed: %s" % (behind, reason))
        return False
    print("[repo] Pulled %d new commit(s) from GitHub. Files may have changed since you last read them." % behind)
    print(recent("HEAD~%d..HEAD" % behind))
    return True


def check():
    force = "--force" in sys.argv
    session = session_id()
    if force or fetch_due():
        fetch = git("fetch", "origin", "main")
        if fetch.returncode == 0:
            with open(git_dir_file("ew_freshness_stamp"), "w"):
                pass
        else:  # no stamp: try again on the next prompt, and compare against the last known GitHub state below
            print("[repo] Could not reach GitHub, so this checkout may be out of date: " + fetch.stderr.strip()[-200:])
    counts = git("rev-list", "--left-right", "--count", "HEAD...origin/main").stdout.split()
    ahead, behind = int(counts[0]), int(counts[1])
    branch = git("rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
    dirty = is_dirty()

    # An earlier pull stopped partway or is still going: what `git status` shows may not be anyone's work.
    marker = git_dir_file("ew_freshness_pull")
    if os.path.exists(marker):
        with open(marker) as f:
            reason = f.read().strip()
        if os.path.exists(git_dir_file("index.lock")) or (behind and dirty):
            print("[repo] An earlier pull stopped partway or is still running (%s). Files in `git status` may be leftovers from it, not real work. Ask the user before changing them. %s" % (reason, NOT_YOURS))
            report_moved(session, False)
            return
        os.remove(marker)

    if ahead:
        print("[repo] %d local commit(s) are not on GitHub yet: run the github-sync skill." % ahead)
    reported = False
    if behind:
        if branch != "main":
            print("[repo] %d commit(s) behind GitHub main, NOT pulled (on branch %s). Ask the user how to proceed." % (behind, branch))
        elif ahead:
            print("[repo] %d commit(s) behind GitHub, NOT pulled (local commits exist). The github-sync skill rebases and pushes them." % behind)
        elif dirty:
            print("[repo] %d commit(s) behind GitHub, NOT pulled (uncommitted changes exist). Finish and sync your own work with github-sync. %s" % (behind, NOT_YOURS))
        else:
            reported = pull(behind)
    report_moved(session, reported)


if __name__ == "__main__":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        check()
    except Exception as err:  # noqa: BLE001 (a freshness check must never break the prompt)
        print("[repo] Freshness check failed: %s" % err)
