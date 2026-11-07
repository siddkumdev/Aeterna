"""Aeterna sound synthesis kit (Siddharth 2026-11-07: audio is made from code, no recordings, no third-party samples).

Everything is numpy arrays at 44.1 kHz, float32, mono (n,) or stereo (n, 2), values nominally in -1..1.
Recipes in assets/generators/make_audio.py combine these pieces; every random choice comes from a seeded rng, so the
same recipe always makes the same file.

Pieces: oscillators (osc, fm, noise), envelopes (exp_env, adsr, glide), filters (lp, hp, bp, sweep_bp, sweep_lp),
instruments (bell, marimba, glass, thud, whoosh, crackle, formant_blip, chirp), effects (reverb, echo, soft_clip,
stereo_wide), mixing (mix, fade, normalise) and file output (write_wav).
"""
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
TWO_PI = 2.0 * np.pi


def rng(seed):
    return np.random.default_rng(seed)


def pk(x, peak=1.0):
    """Scale a layer so its loudest sample is `peak`. Filtered noise comes out very quiet, so recipes use this to make
    the gains in a mix mean what they say."""
    x = np.asarray(x, dtype=float)
    return x * (peak / (np.max(np.abs(x)) + 1e-12))


def db(x):
    return 10.0 ** (x / 20.0)


def to_db(x):
    return 20.0 * np.log10(max(float(x), 1e-9))


def n_of(seconds):
    return int(round(seconds * SR))


def t_of(seconds):
    return np.arange(n_of(seconds)) / SR


def note(name):
    """'C5' -> Hz. Sharps with '#', flats with 'b'."""
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    p = names[name[0]]
    i = 1
    while i < len(name) and name[i] in "#b":
        p += 1 if name[i] == "#" else -1
        i += 1
    octave = int(name[i:])
    return 440.0 * 2.0 ** ((p + 12 * (octave + 1) - 69) / 12.0)


# ------------------------------------------------------------------ curves and envelopes

def curve(points, seconds, log=True):
    """Value over time from [(t, v), ...] (seconds), interpolated in log space for frequencies."""
    ts = [p[0] for p in points]
    vs = [p[1] for p in points]
    t = t_of(seconds)
    if log:
        return np.exp(np.interp(t, ts, np.log(np.maximum(vs, 1e-6))))
    return np.interp(t, ts, vs)


def exp_env(seconds, tau, attack=0.002):
    t = t_of(seconds)
    e = np.exp(-t / max(tau, 1e-4))
    if attack > 0:
        e = e * np.minimum(t / attack, 1.0)
    return e


def adsr(seconds, a=0.01, d=0.1, s=0.7, r=0.1):
    n = n_of(seconds)
    t = np.arange(n) / SR
    e = np.ones(n)
    e = np.where(t < a, t / max(a, 1e-4), e)
    e = np.where((t >= a) & (t < a + d), 1.0 - (1.0 - s) * (t - a) / max(d, 1e-4), e)
    e = np.where(t >= a + d, s, e)
    tail = t > seconds - r
    e = np.where(tail, e * np.clip((seconds - t) / max(r, 1e-4), 0, 1), e)
    return e


def swell(seconds, peak=0.5):
    """Rises to a peak at `peak` (0..1 of the length) and falls away, smoothly."""
    t = np.linspace(0, 1, n_of(seconds))
    up = np.sin(np.clip(t / max(peak, 1e-3), 0, 1) * np.pi / 2) ** 2
    down = np.cos(np.clip((t - peak) / max(1 - peak, 1e-3), 0, 1) * np.pi / 2) ** 2
    return np.where(t < peak, up, down)


# ------------------------------------------------------------------ oscillators and noise

def _phase(f, seconds):
    f = np.broadcast_to(np.asarray(f, dtype=float), (n_of(seconds),)) if np.ndim(f) == 0 else np.asarray(f, dtype=float)
    return TWO_PI * np.cumsum(f) / SR


def osc(kind, f, seconds, phase0=0.0):
    """kind: sine, tri, square, saw. f in Hz, a number or an array (a glide). Saw and square are band limited."""
    ph = _phase(f, seconds) + phase0
    if kind == "sine":
        return np.sin(ph)
    if kind == "tri":
        return (2.0 / np.pi) * np.arcsin(np.sin(ph))
    fmax = float(np.max(f)) if np.ndim(f) else float(f)
    k_max = int(max(1, min(40, (SR / 2.2) / max(fmax, 1.0))))
    out = np.zeros_like(ph)
    if kind == "saw":
        for k in range(1, k_max + 1):
            out += np.sin(k * ph) / k
        return out * (2.0 / np.pi)
    if kind == "square":
        for k in range(1, k_max + 1, 2):
            out += np.sin(k * ph) / k
        return out * (4.0 / np.pi)
    raise ValueError(kind)


def fm(f_carrier, ratio, index, seconds, index_env=None):
    """Two operator FM. index may be a number or an array (time shaped brightness)."""
    t = t_of(seconds)
    idx = index * (index_env if index_env is not None else 1.0)
    fc = np.broadcast_to(np.asarray(f_carrier, float), t.shape)
    return np.sin(_phase(fc, seconds) + idx * np.sin(_phase(fc * ratio, seconds)))


def noise(seconds, r, kind="white"):
    n = n_of(seconds)
    w = r.standard_normal(n)
    if kind == "white":
        return w / 3.0
    spec = np.fft.rfft(w)
    f = np.fft.rfftfreq(n, 1 / SR)
    f[0] = f[1]
    spec = spec / (f ** (0.5 if kind == "pink" else 1.0))
    x = np.fft.irfft(spec, n)
    return x / (np.max(np.abs(x)) + 1e-9)


def impulses(seconds, r, rate, tau=0.004, spread=1.0):
    """A random click train (crackle, rain drops): Poisson clicks with random size, each a tiny decaying burst."""
    n = n_of(seconds)
    out = np.zeros(n)
    count = r.poisson(rate * seconds)
    kernel_n = n_of(tau * 8)
    kt = np.arange(kernel_n) / SR
    for _ in range(count):
        at = int(r.integers(0, max(n - kernel_n, 1)))
        amp = r.random() ** 2 * spread
        grain = r.standard_normal(kernel_n) * np.exp(-kt / tau)
        out[at:at + kernel_n] += amp * grain
    return out


# ------------------------------------------------------------------ filters

def _sos(kind, fc, order=2):
    nyq = SR / 2.0
    if isinstance(fc, (list, tuple)):
        w = [min(max(f, 20.0), nyq * 0.98) for f in fc]
        return signal.butter(order, w, kind, fs=SR, output="sos")
    return signal.butter(order, min(max(fc, 20.0), nyq * 0.98), kind, fs=SR, output="sos")


def lp(x, fc, order=2):
    return signal.sosfilt(_sos("low", fc, order), x, axis=0)


def hp(x, fc, order=2):
    return signal.sosfilt(_sos("high", fc, order), x, axis=0)


def bp(x, f1, f2, order=2):
    return signal.sosfilt(_sos("band", [f1, f2], order), x, axis=0)


def sweep_bp(x, f_curve, q=2.0, block=256):
    """Band pass whose centre follows f_curve (array, Hz, same length). Bandwidth = centre / q."""
    out = np.zeros_like(x, dtype=float)
    zi = None
    for s in range(0, len(x), block):
        fc = float(f_curve[min(s + block // 2, len(f_curve) - 1)])
        sos = _sos("band", [fc * (1 - 0.5 / q), fc * (1 + 0.5 / q)], 2)
        if zi is None:
            zi = np.zeros((sos.shape[0], 2))
        y, zi = signal.sosfilt(sos, x[s:s + block], zi=zi)
        out[s:s + block] = y
    return out


def sweep_lp(x, f_curve, block=256, order=2):
    out = np.zeros_like(x, dtype=float)
    zi = None
    for s in range(0, len(x), block):
        fc = float(f_curve[min(s + block // 2, len(f_curve) - 1)])
        sos = _sos("low", fc, order)
        if zi is None:
            zi = np.zeros((sos.shape[0], 2))
        y, zi = signal.sosfilt(sos, x[s:s + block], zi=zi)
        out[s:s + block] = y
    return out


# ------------------------------------------------------------------ instruments

def bell(f, seconds, brightness=1.0, decay=1.0, ratios=(1.0, 2.76, 5.40, 8.93), r=None):
    """A struck bell: inharmonic partials, each fading faster the higher it is. Soft strike click on top."""
    out = np.zeros(n_of(seconds))
    amps = [1.0, 0.55, 0.32, 0.18]
    for i, ra in enumerate(ratios):
        if f * ra > SR / 2.3:
            continue
        tau = decay * 0.9 / (1.0 + 1.5 * i)
        out += amps[min(i, 3)] * (brightness if i else 1.0) * exp_env(seconds, tau, 0.001) * np.sin(
            _phase(f * ra * (1 + 0.0008 * i), seconds))
    return out / 2.0


def marimba(f, seconds=0.5, hard=0.5):
    """A wooden bar: strong fundamental, a quick 4x overtone and a tick."""
    out = exp_env(seconds, 0.22, 0.001) * np.sin(_phase(f, seconds))
    out += 0.35 * exp_env(seconds, 0.07, 0.0005) * np.sin(_phase(f * 3.99, seconds))
    out += 0.12 * hard * exp_env(seconds, 0.02, 0.0003) * np.sin(_phase(f * 9.9, seconds))
    return out


def glass(f, seconds=0.8, decay=1.0):
    """A glass plink: pure, a little shimmer."""
    out = exp_env(seconds, 0.35 * decay, 0.001) * np.sin(_phase(f, seconds))
    out += 0.3 * exp_env(seconds, 0.2 * decay, 0.001) * np.sin(_phase(f * 2.01, seconds))
    out += 0.12 * exp_env(seconds, 0.12 * decay, 0.001) * np.sin(_phase(f * 3.02, seconds))
    return out


def thud(seconds, f0=140.0, f1=55.0, tau=0.09, r=None, grit=0.3):
    """A soft body hit: a sine falling in pitch, plus a little low-passed grit."""
    t = t_of(seconds)
    f = f1 + (f0 - f1) * np.exp(-t / (tau * 0.5))
    out = np.sin(_phase(f, seconds)) * exp_env(seconds, tau, 0.001)
    if r is not None and grit > 0:
        out += grit * lp(noise(seconds, r), 700) * exp_env(seconds, tau * 0.6, 0.0005)
    return out


def whoosh(seconds, f_start, f_end, r, q=1.2, peak=0.4, body=1.0):
    """Air moving past: noise through a band pass that glides, swelling in and out."""
    n = noise(seconds, r)
    fc = curve([(0, f_start), (seconds, f_end)], seconds)
    return sweep_bp(n, fc, q) * swell(seconds, peak) * body


def crackle(seconds, r, rate=40.0, tone=2500.0, spread=1.0):
    c = impulses(seconds, r, rate, 0.0025, spread)
    return hp(c, 500) * 0.8 + 0.2 * bp(c, tone * 0.6, tone * 1.5)


def chirp(f0, f1, seconds, vib=0.0, vib_rate=30.0, shape=None):
    """A short bird-like sweep."""
    t = t_of(seconds)
    f = f0 + (f1 - f0) * (t / seconds) ** (shape or 1.0)
    f = f * (1.0 + vib * np.sin(TWO_PI * vib_rate * t))
    return np.sin(_phase(f, seconds)) * np.sin(np.pi * t / seconds) ** 0.7


VOWELS = {
    "a": (800, 1200, 2600),
    "e": (500, 1800, 2500),
    "i": (330, 2200, 3000),
    "o": (500, 900, 2500),
    "u": (330, 800, 2400),
}


def formant_blip(f0_curve_pts, vowel, seconds, r, breath=0.04, q=6.0):
    """One 'animalese' syllable: a buzzy source filtered to a vowel, with a pitch contour."""
    f0 = curve(f0_curve_pts, seconds)
    src = osc("saw", f0, seconds)
    f1, f2, f3 = VOWELS[vowel]
    out = np.zeros_like(src)
    for fc, g in ((f1, 1.0), (f2, 0.55), (f3, 0.25)):
        out += g * bp(src, fc * 0.92, fc * 1.08, 2)
    out += breath * bp(noise(seconds, r), 2500, 6000)
    env = np.sin(np.pi * np.linspace(0, 1, len(out))) ** 0.6
    return out * env


# ------------------------------------------------------------------ effects

def reverb(x, rt60=1.0, wet=0.2, predelay=0.012, damp=5000.0, seed=7):
    """A cheap room: a noise impulse that fades over rt60, darker toward the tail. Works on mono or stereo."""
    r = rng(seed)
    n = n_of(rt60 * 1.1)
    t = np.arange(n) / SR
    ir = r.standard_normal(n) * np.exp(-6.91 * t / rt60)
    ir = lp(ir, damp, 1)
    ir[: n_of(predelay)] = 0.0
    ir = ir / (np.sqrt(np.sum(ir ** 2)) + 1e-9)
    if x.ndim == 1:
        wetsig = signal.fftconvolve(x, ir)[: len(x) + n_of(rt60 * 0.8)]
        dry = np.pad(x, (0, len(wetsig) - len(x)))
        return dry * (1 - wet * 0.5) + wetsig * wet * 2.2
    cols = []
    for c in range(x.shape[1]):
        ir2 = np.roll(ir, 37 * (c + 1))
        w = signal.fftconvolve(x[:, c], ir2)[: len(x) + n_of(rt60 * 0.8)]
        d = np.pad(x[:, c], (0, len(w) - len(x)))
        cols.append(d * (1 - wet * 0.5) + w * wet * 2.2)
    return np.stack(cols, axis=1)


def echo(x, delay, feedback=0.35, mixv=0.3, taps=4):
    out = np.pad(x, (0, n_of(delay * taps)))
    for i in range(1, taps + 1):
        g = mixv * (feedback ** (i - 1))
        s = n_of(delay * i)
        out[s:s + len(x)] += x * g
    return out


def soft_clip(x, drive=1.5):
    return np.tanh(x * drive) / np.tanh(drive)


def stereo_wide(x, width=0.3, seed=11):
    """Mono to stereo: a hair of different delay and tone each side so it sits wide instead of in the middle."""
    d = n_of(0.0004 + 0.0012 * width)
    left = x
    right = np.pad(x, (d, 0))[: len(x)]
    right = lp(right, 9000 - 3000 * width, 1) * 0.98
    return np.stack([left, right], axis=1)


def pan(x, p):
    """p in -1..1: equal power pan of a mono array to stereo."""
    a = (p + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)


# ------------------------------------------------------------------ mixing and output

def mix(*layers, seconds=None):
    """layers: arrays or (array, at_seconds, gain) tuples; mono and stereo may be mixed."""
    items = []
    for L in layers:
        if isinstance(L, tuple):
            arr = L[0]
            at = L[1] if len(L) > 1 else 0.0
            g = L[2] if len(L) > 2 else 1.0
        else:
            arr, at, g = L, 0.0, 1.0
        items.append((np.asarray(arr, dtype=float), n_of(at), g))
    total = max(s + len(a) for a, s, _ in items)
    if seconds is not None:
        total = max(total, n_of(seconds))
    stereo = any(a.ndim == 2 for a, _, _ in items)
    out = np.zeros((total, 2) if stereo else total)
    for a, s, g in items:
        if stereo and a.ndim == 1:
            a = np.stack([a, a], axis=1)
        out[s:s + len(a)] += a * g
    return out


def fade(x, fade_in=0.002, fade_out=0.01):
    x = np.array(x, dtype=float)
    n = len(x)
    fi = min(n_of(fade_in), n // 2)
    fo = min(n_of(fade_out), n // 2)
    ramp = np.ones(n)
    if fi:
        ramp[:fi] = np.linspace(0, 1, fi)
    if fo:
        ramp[-fo:] = np.linspace(1, 0, fo)
    return x * (ramp if x.ndim == 1 else ramp[:, None])


def trim_silence(x, threshold_db=-60.0, keep=0.01):
    mag = np.max(np.abs(x), axis=1) if x.ndim == 2 else np.abs(x)
    idx = np.where(mag > db(threshold_db) * max(float(np.max(mag)), 1e-9))[0]
    if len(idx) == 0:
        return x
    end = min(len(x), idx[-1] + n_of(keep))
    return x[:end]


def remove_dc(x):
    return x - np.mean(x, axis=0)


def peak_of(x):
    return float(np.max(np.abs(x)))


def rms_of(x):
    return float(np.sqrt(np.mean(np.square(x))))


def normalise(x, peak_db=-3.0, rms_db=None, max_peak_db=-1.0):
    """Scale to a peak, or to an RMS level (but never past max_peak_db)."""
    x = np.asarray(x, dtype=float)
    p = peak_of(x) + 1e-12
    if rms_db is None:
        return x * (db(peak_db) / p)
    g = db(rms_db) / (rms_of(x) + 1e-12)
    g = min(g, db(max_peak_db) / p)
    return x * g


def loop_seamless(x, crossfade=0.25):
    """Make x loop without a click: the end fades into the start (equal power), and the file shortens by the overlap."""
    n = n_of(crossfade)
    x = np.asarray(x, dtype=float)
    head, tail = x[:n].copy(), x[-n:].copy()
    w = np.linspace(0, 1, n)
    wi, wo = np.sin(w * np.pi / 2), np.cos(w * np.pi / 2)
    if x.ndim == 2:
        wi, wo = wi[:, None], wo[:, None]
    body = x[:-n].copy()
    body[:n] = head * wi + tail * wo
    return body


def seam_error(x):
    """How big the jump is where the end meets the start, compared with the normal sample to sample change (1 = same)."""
    a = x[-1] if x.ndim == 1 else x[-1].mean()
    b = x[0] if x.ndim == 1 else x[0].mean()
    d = np.abs(np.diff(x, axis=0))
    typical = float(np.mean(d)) + 1e-9
    return float(abs(a - b) / typical)


def write_wav(path, x):
    x = np.asarray(x, dtype=float)
    x = np.clip(x, -1.0, 1.0)
    wavfile.write(path, SR, (x * 32767.0).astype(np.int16))
