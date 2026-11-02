"""Reach the Galaxy Watch through the laptop on its network (the watch cannot reach this PC directly).

    python watch/watch_bridge.py pair <ip:pairing_port> <code>   pair once, from the watch's Wireless debugging screen
    python watch/watch_bridge.py connect <ip:port>               connect adb on the laptop to the watch
    python watch/watch_bridge.py install                         install the built app, point it at the laptop, open it
    python watch/watch_bridge.py listen                          print the line rate only, to test the link first
    python watch/watch_bridge.py record <name>                   save a take to _work/watch/<name>.csv

record exits non-zero and saves <name>.incomplete.csv if the take did not finish, or cues or data were lost.
WATCH_BRIDGE in local.env is the laptop's ssh login (default: the-tank@100.95.40.122).
"""
import os
import queue
import re
import subprocess
import sys
import threading
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import ew_env  # noqa: E402,F401  (loads local.env into the environment)

BRIDGE = os.environ.get("WATCH_BRIDGE", "the-tank@100.95.40.122")
SSH_OPTIONS = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=15", "-o", "ServerAliveInterval=5", "-o", "ServerAliveCountMax=3"]
SSH = ["ssh"] + SSH_OPTIONS + [BRIDGE]
APK = os.path.join(ROOT, "watch", "build", "outputs", "apk", "debug", "aeterna-watch-debug.apk")
PACKAGE = "com.aeterna.watch"
PORT = 9100
STALL_SECONDS = 5  # silence after data has started means the take died
CLOCK_TOLERANCE_US = 1_000_000

# Runs on the laptop: every UDP datagram from the watch goes to stdout, so ssh carries it here with no inbound firewall rule.
# It stops when ssh closes its stdin, so no stale receiver keeps the port.
RECEIVER = """
import select, socket, sys
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(("0.0.0.0", %d))
sys.stdout.buffer.write(b"ready\\n")
sys.stdout.buffer.flush()
while True:
    got = select.select([s, sys.stdin], [], [])[0]
    if sys.stdin in got:
        break
    sys.stdout.buffer.write(s.recv(65535))
    sys.stdout.buffer.flush()
""" % PORT


def remote(command):
    return subprocess.run(SSH + [command], capture_output=True, text=True, timeout=120)


def watch_serial():
    """The watch's ip:port as adb on the laptop knows it. Wireless debugging can also list it under a second name."""
    devices = remote("adb devices").stdout
    found = re.findall(r"^(\d+\.\d+\.\d+\.\d+:\d+)\s+device\b", devices, re.M)
    if not found:
        sys.exit("The laptop has no watch connected. Run: python watch/watch_bridge.py connect <ip:port>\n" + devices)
    return found[0]


def laptop_ip(watch_ip):
    """The laptop's address on the interface that faces the watch."""
    ip = remote("ip -4 route get %s | sed -n 's/.* src \\([0-9.]*\\).*/\\1/p'" % watch_ip).stdout.strip()
    if not ip:
        sys.exit("Could not find the laptop's address towards the watch at " + watch_ip)
    return ip


def run_adb(command):
    result = remote("adb " + command)
    print((result.stdout + result.stderr).strip())
    return result.returncode == 0


def install():
    if not os.path.exists(APK):
        sys.exit("Build it first (see watch/README.md): " + APK)
    serial = watch_serial()
    subprocess.run(["scp", "-q"] + SSH_OPTIONS + [APK, BRIDGE + ":/tmp/aeterna-watch.apk"], check=True)
    if not run_adb("-s %s install -r /tmp/aeterna-watch.apk" % serial):
        sys.exit(1)
    if not run_adb("-s %s shell am start -S -n %s/.MainActivity --es host %s" % (serial, PACKAGE, laptop_ip(serial.split(":")[0]))):
        sys.exit(1)


def open_stream():
    """Start the receiver and wait until the port is really open. Returns the process and a queue of lines (None at the end)."""
    proc = subprocess.Popen(SSH + ["python3 -u -c '%s'" % RECEIVER], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    lines = queue.Queue()

    def pump():
        for line in proc.stdout:
            lines.put(line)
        lines.put(None)

    threading.Thread(target=pump, daemon=True).start()
    try:
        first = lines.get(timeout=30)
    except queue.Empty:
        first = None
    if first != b"ready\n":
        proc.kill()
        sys.exit("The laptop's receiver did not start. Port %d may be in use there, or ssh failed." % PORT)
    return proc, lines


def listen():
    proc, lines = open_stream()
    print("Listening on port %d. Open the app on the watch: a hello should arrive. Ctrl+C to stop." % PORT)
    start, count, seen = time.time(), 0, False
    try:
        while True:
            line = lines.get()
            if line is None:
                print("The connection to the laptop ended.")
                return
            if line.startswith(b"s,"):
                continue
            count += 1
            if not seen:
                seen = True
                print("First data: " + line.decode("ascii", "replace").strip())
            if time.time() - start >= 2:
                print("%.0f lines/s" % (count / (time.time() - start)))
                start, count = time.time(), 0
    except KeyboardInterrupt:
        pass
    finally:
        proc.kill()


class Take:
    """What arrived, and what the watch says should have arrived."""

    def __init__(self):
        self.counts = {}
        self.first = {}
        self.last = {}
        self.cues = set()
        self.sequences = set()
        self.end = None  # [time_us, cues_sent, send_failures, reason]

    def problems(self, ssh_code):
        found = []
        if self.end is None:
            found.append("The end of the take never arrived (ssh exit code %s). The app may have stopped." % ssh_code)
        else:
            if self.end[3] != "complete":
                found.append("The take ended early: " + self.end[3])
            missing = sorted(set(range(int(self.end[1]))) - self.cues)
            if missing:
                found.append("%d cue(s) lost, so labels are wrong. Indexes: %s" % (len(missing), missing[:20]))
            if self.end[2] != "0":
                found.append("The watch failed to send %s time(s)." % self.end[2])
            newest = max(self.last.values(), default=None)
            if newest is not None and abs(int(self.end[0]) - newest) > CLOCK_TOLERANCE_US:
                found.append("Sensor and cue clocks differ by %.1f s, so labels would be misaligned." % (abs(int(self.end[0]) - newest) / 1e6))
        for tag, name in (("a", "accelerometer"), ("g", "gyroscope"), ("r", "rotation")):
            if tag not in self.first:
                found.append("No %s data." % name)
        return found

    def summary(self):
        for tag, name in (("a", "accelerometer"), ("g", "gyroscope"), ("r", "rotation")):
            if tag in self.first and self.last[tag] > self.first[tag]:
                print("%s: %d samples, %.0f Hz" % (name, self.counts[tag], self.counts[tag] / ((self.last[tag] - self.first[tag]) / 1e6)))
        if self.sequences:
            span = max(self.sequences) - min(self.sequences) + 1
            print("Datagrams lost: %d of %d (%.1f%%)" % (span - len(self.sequences), span, 100 * (span - len(self.sequences)) / span))


def record(name):
    folder = os.path.join(ROOT, "_work", "watch")
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, name + ".csv")
    bad_path = os.path.join(folder, name + ".incomplete.csv")
    part = path + ".part"
    if os.path.exists(path):
        sys.exit("%s already exists. Pick another name." % path)
    proc, lines = open_stream()
    print("Ready. Tap the watch to start. Ctrl+C stops early.")
    take = Take()
    newest = None
    try:
        with open(part, "wb") as out:
            while take.end is None:
                try:
                    line = lines.get(timeout=1)
                except queue.Empty:
                    if newest is not None and time.time() - newest > STALL_SECONDS:
                        print("No data for %d s." % STALL_SECONDS)
                        break
                    continue
                if line is None:
                    break
                parts = line.decode("ascii", "replace").strip().split(",")
                tag = parts[0]
                if tag == "s" and len(parts) == 2 and parts[1].isdigit():
                    take.sequences.add(int(parts[1]))
                elif tag == "c" and len(parts) == 4:
                    index = int(parts[2])
                    if index >= 0 and index not in take.cues:  # cues arrive three times
                        take.cues.add(index)
                        out.write(line)
                        print("cue %d: %s" % (index, parts[3]))
                elif tag == "e" and len(parts) == 5:
                    take.end = parts[1:]
                elif tag in ("a", "g", "r") and len(parts) >= 5:
                    stamp = int(parts[1])
                    take.counts[tag] = take.counts.get(tag, 0) + 1
                    take.first.setdefault(tag, stamp)
                    take.last[tag] = stamp
                    newest = time.time()
                    out.write(line)
    except KeyboardInterrupt:
        print("Stopped early.")
    finally:
        proc.kill()
    take.summary()
    problems = take.problems(proc.poll())
    if problems:
        os.replace(part, bad_path)
        print("INCOMPLETE, saved as " + bad_path)
        for problem in problems:
            print("- " + problem)
        sys.exit(1)
    os.replace(part, path)
    print("OK, saved as " + path)


def main():
    args = sys.argv[1:]
    if len(args) == 3 and args[0] == "pair":
        sys.exit(0 if run_adb("pair %s %s" % (args[1], args[2])) else 1)
    if len(args) == 2 and args[0] == "connect":
        run_adb("connect " + args[1])
        run_adb("devices -l")
    elif args == ["install"]:
        install()
    elif args == ["listen"]:
        listen()
    elif len(args) == 2 and args[0] == "record":
        record(args[1])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
