"""Reach the Galaxy Watch through the laptop on its network (the watch cannot reach this PC directly).

    python watch/watch_bridge.py pair <ip:pairing_port> <code>   pair once, from the watch's Wireless debugging screen
    python watch/watch_bridge.py connect <ip:port>               connect adb on the laptop to the watch
    python watch/watch_bridge.py install                         install the built app, point it at the laptop, open it
    python watch/watch_bridge.py record <name>                   save the stream to _work/watch/<name>.csv until the cues end
    python watch/watch_bridge.py listen                          print the packet rate only, to test the link

WATCH_BRIDGE in local.env is the laptop's ssh login (default: the-tank@100.95.40.122).
"""
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import ew_env  # noqa: E402

BRIDGE = os.environ.get("WATCH_BRIDGE", "the-tank@100.95.40.122")  # ew_env loads local.env into the environment
SSH = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=15", BRIDGE]
APK = os.path.join(ROOT, "watch", "build", "outputs", "apk", "debug", "aeterna-watch-debug.apk")
PACKAGE = "com.aeterna.watch"
PORT = 9100

# Runs on the laptop: every UDP datagram from the watch goes to stdout, so ssh carries it here with no inbound firewall rule.
# It stops when ssh closes its stdin, so no stale receiver keeps the port.
RECEIVER = """
import select, socket, sys
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(("0.0.0.0", %d))
while True:
    ready = select.select([s, sys.stdin], [], [])[0]
    if sys.stdin in ready:
        break
    sys.stdout.buffer.write(s.recv(65535))
    sys.stdout.buffer.flush()
""" % PORT


def remote(command):
    return subprocess.run(SSH + [command], capture_output=True, text=True, timeout=120)


def laptop_ip():
    return remote("ip -4 route get 1.1.1.1 | sed -n 's/.* src \\([0-9.]*\\).*/\\1/p'").stdout.strip()


def run_adb(command):
    result = remote("adb " + command)
    print((result.stdout + result.stderr).strip())
    return result.returncode == 0


def install():
    if not os.path.exists(APK):
        sys.exit("Build it first (see watch/README.md): " + APK)
    subprocess.run(["scp", "-q", "-o", "BatchMode=yes", APK, BRIDGE + ":/tmp/aeterna-watch.apk"], check=True)
    if not run_adb("install -r /tmp/aeterna-watch.apk"):
        sys.exit(1)
    run_adb("shell am start -n %s/.MainActivity --es host %s" % (PACKAGE, laptop_ip()))


def stream():
    return subprocess.Popen(SSH + ["python3 -u -c '%s'" % RECEIVER], stdin=subprocess.PIPE, stdout=subprocess.PIPE)


def listen():
    proc = stream()
    print("Listening on %s port %d. Ctrl+C to stop." % (laptop_ip(), PORT))
    start, lines, seen = time.time(), 0, False
    try:
        for line in proc.stdout:
            lines += 1
            if not seen:
                seen = True
                print("First data: " + line.decode("ascii", "replace").strip())
            if time.time() - start >= 2:
                print("%.0f lines/s" % (lines / (time.time() - start)))
                start, lines = time.time(), 0
    except KeyboardInterrupt:
        pass
    finally:
        proc.kill()


def record(name):
    folder = os.path.join(ROOT, "_work", "watch")
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, name + ".csv")
    proc = stream()
    print("Recording to %s. Tap the watch to start. Stops by itself at the end of the cues; Ctrl+C stops it early." % path)
    counts = {}
    first, last = {}, {}
    try:
        with open(path, "wb") as out:
            for line in proc.stdout:
                out.write(line)
                parts = line.decode("ascii", "replace").strip().split(",")
                if len(parts) < 3:
                    continue
                tag, stamp = parts[0], parts[1]
                counts[tag] = counts.get(tag, 0) + 1
                if tag != "c" and stamp.isdigit():
                    first.setdefault(tag, int(stamp))
                    last[tag] = int(stamp)
                if tag == "c":
                    print("cue: " + parts[2])
                    if parts[2] == "end":
                        break
    except KeyboardInterrupt:
        print("Stopped early.")
    finally:
        proc.kill()
    for tag, name_ in (("a", "accelerometer"), ("g", "gyroscope"), ("r", "rotation")):
        if tag in first and last[tag] > first[tag]:
            print("%s: %d samples, %.0f Hz" % (name_, counts[tag], counts[tag] / ((last[tag] - first[tag]) / 1e6)))
        else:
            print("%s: no data" % name_)


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
