"""Streaming pinch / release detector for the watch's accelerometer. Pure Python, no dependencies, so the live bridge and the
replay test use the same code.

A pinch makes a short burst of shake in the accelerometer. The burst is compared with the movement just before it, so
that aiming does not count as a pinch. While a pinch is held the game already knows it is waiting for a release, so the
release uses a lower threshold than the press (the release burst is about half as strong).

    d = PinchDetector()
    event = d.feed(t_seconds, (ax, ay, az))   # None, "down" or "up"
"""
import math
from collections import deque

SMOOTH = 3  # samples averaged (30 ms at 100 Hz)
BASE_FROM, BASE_TO = 0.6, 0.1  # the movement baseline is the median of the signal from 0.6 s to 0.1 s ago
BASE_FLOOR = 0.08  # keeps a perfectly still arm from dividing by nothing
DOWN_RATIO = 3.0  # press: a burst this many times the recent movement
UP_RATIO = 1.7  # release: lower, because we already know a pinch is held
MIN_HOLD = 0.35  # s: a release this soon after a press is the press itself ringing
REFRACTORY = 0.4  # s between events


class PinchDetector:
    def __init__(self, down_ratio=DOWN_RATIO, up_ratio=UP_RATIO):
        self.down_ratio, self.up_ratio = down_ratio, up_ratio
        self.held = False
        self._prev = None
        self._raw = deque(maxlen=SMOOTH)
        self._history = deque()  # (t, smoothed jerk)
        self._last_event = -9.0
        self._held_since = 0.0

    def _baseline(self, t):
        values = sorted(v for ts, v in self._history if t - BASE_FROM <= ts <= t - BASE_TO)
        return values[len(values) // 2] if values else None

    def feed(self, t, acc):
        if self._prev is None:
            self._prev = acc
            return None
        jerk = math.sqrt(sum((a - b) ** 2 for a, b in zip(acc, self._prev)))
        self._prev = acc
        self._raw.append(jerk)
        smooth = sum(self._raw) / len(self._raw)
        self._history.append((t, smooth))
        while self._history and self._history[0][0] < t - BASE_FROM - 0.2:
            self._history.popleft()
        base = self._baseline(t)
        if base is None or t - self._last_event < REFRACTORY:
            return None
        ratio = smooth / (base + BASE_FLOOR)
        if not self.held and ratio > self.down_ratio:
            self.held, self._held_since, self._last_event = True, t, t
            return "down"
        if self.held and t - self._held_since >= MIN_HOLD and ratio > self.up_ratio:
            self.held, self._last_event = False, t
            return "up"
        return None


def load_take(path):
    """Accelerometer samples and cues from a recorded take: ([(t, (x, y, z))], [(t, name)])."""
    samples, cues = [], []
    with open(path) as f:
        for line in f:
            p = line.strip().split(",")
            if p[0] == "a" and len(p) >= 5:
                samples.append((int(p[1]) / 1e6, (float(p[2]), float(p[3]), float(p[4]))))
            elif p[0] == "c" and len(p) == 4 and int(p[2]) >= 0:
                cues.append((int(p[1]) / 1e6, p[3]))
    samples.sort()
    cues.sort()
    return samples, cues


def replay(path, **kwargs):
    """Run a take through the detector. Returns the events [(t, 'down'|'up')] and the cues."""
    samples, cues = load_take(path)
    d = PinchDetector(**kwargs)
    events = [(t, e) for t, acc in samples for e in [d.feed(t, acc)] if e]
    return events, cues, samples[-1][0] - samples[0][0]


def score(events, cues, duration):
    """Presses should follow a pinch cue (0.1 to 0.9 s), releases an open cue. Anything else is a false event."""
    pinch = [t for t, n in cues if n in ("pinch", "pinch_moving", "grab")]
    opens = [t for t, n in cues if n in ("open", "open_moving", "release")]
    downs = [t for t, e in events if e == "down"]
    ups = [t for t, e in events if e == "up"]

    def hits(times, targets):
        return sum(any(c + 0.1 <= d <= c + 0.9 for d in targets) for c in times)

    # while holding (between a pinch cue and the next open cue) an "up" is early; a "down" outside a pinch cue is false
    false_down = [t for t in downs if not any(c - 0.2 <= t <= c + 1.3 for c in pinch)]
    early_up = [t for t in ups if not any(c - 0.2 <= t <= c + 1.3 for c in opens)]
    return {
        "press_hit": "%d/%d" % (hits(pinch, downs), len(pinch)),
        "release_hit": "%d/%d" % (hits(opens, ups), len(opens)),
        "false_press_per_min": round(len(false_down) / (duration / 60), 1),
        "early_release_per_min": round(len(early_up) / (duration / 60), 1),
    }


if __name__ == "__main__":
    import sys
    for path in sys.argv[1:]:
        for down, up in ((3.0, 1.7), (3.0, 1.4), (3.0, 2.0)):
            events, cues, duration = replay(path, down_ratio=down, up_ratio=up)
            print("%-22s down>%.1f up>%.1f  %s" % (path.replace("\\", "/").split("/")[-1], down, up, score(events, cues, duration)))
