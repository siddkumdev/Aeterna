"""Aeterna sound effects and ambience, built from REAL recordings (Siddharth 2026-11-08: "minimal use of code generated
sounds, it should mainly be real sounds"): free CC0 / CC BY / royalty-free (Sonniss GDC) recordings, cut by
tools/audio_grains.py into assets/audio_src/grains/ and credited in docs/AUDIO_CREDITS.md. Code only processes them
(cut, pitch onto the key, filter, layer, room); main() fails if a recipe calls a synthesis function. One recipe per
sound; a recipe returns a numpy array and the framework below trims, cleans, loudness-matches and writes it.

Run (no Blender needed):
    python assets/generators/make_audio.py [name ...]        # all sounds, or only the ones named
    python assets/generators/make_audio.py --godot           # also copy to godot/assets/audio/ (then import in Godot)
Outputs: assets/export/audio/<name>.wav (variants: <name>_1.wav ...) and manifest.json, which the game reads.

Mood (GAME_SPEC 22 and the moodboard): cozy, toy-like diorama. Wooden clicks, marimba and glass plinks, soft bells; magic is
airy shimmer and fire crackle, never electronic zaps. Loud things stay soft-edged.

Buses (godot AudioBank): "ui" (hand and menu sounds), "sfx" (the world), "ambience" (loops), "music" (later).
"""
import json
import os
import re
import sys
import zlib

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from audio_synth import *  # noqa: F401,F403,E402
import audio_synth as S  # noqa: E402

OUT = os.path.join(ROOT, "assets", "export", "audio")
GODOT_OUT = os.path.join(ROOT, "godot", "assets", "audio")

RECIPES = {}


TAKE_PITCH = [1.0, 0.955, 1.045, 0.925, 1.075, 0.97, 1.03, 0.94]  # take k is resampled by this (a small pitch and length change)
WARM_HZ = 10000  # second pass (Siddharth 2026-11-08, "peaceful and cozy"): one-shots lose their hard top end

GRAINS = os.path.join(ROOT, "assets", "audio_src", "grains")
_GRAIN_CACHE = {}


def _mono(x):
    return x.mean(axis=1) if x.ndim == 2 else x


def grain(kit, r, pitch=1.0, spread=0.06, seconds=None):
    """One random kept grain of `kit`, resampled by pitch * (1 +- spread), peak 1. Each take draws its own grain."""
    if kit not in _GRAIN_CACHE:
        from scipy.io import wavfile
        idx = json.load(open(os.path.join(GRAINS, "grains.json"), encoding="utf-8"))[kit]
        keep = [e for e in idx if e.get("keep", True)] or idx
        _GRAIN_CACHE[kit] = [_mono(wavfile.read(os.path.join(GRAINS, kit, e["file"]))[1].astype(float) / 32768.0) for e in keep]
    xs = _GRAIN_CACHE[kit]
    if not xs:
        raise RuntimeError("grain kit %r is empty: rebuild it with tools/audio_grains.py %s" % (kit, kit))
    x = xs[int(r.integers(0, len(xs)))]
    k = pitch * (1.0 + float(r.uniform(-spread, spread)))
    if k > 1.0:  # shrinking: filter first or the top end folds back down (aliasing)
        x = lp(x, 0.45 * S.SR / k, 4)
    n = max(16, int(len(x) / k))
    x = np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)
    if seconds is not None:  # exactly `seconds` long: cut with a short fade, or pad with silence
        if len(x) > n_of(seconds):
            x = x[: n_of(seconds)].copy()
            m = min(len(x) // 3, n_of(0.08))
            x[-m:] *= np.linspace(1, 0, m)
        else:
            x = np.concatenate([x, np.zeros(n_of(seconds) - len(x))])
    return pk(x)


def recipe(name, tid, bus="sfx", peak=-4.0, loop=False, rms=None, spatial=False, cooldown=0.0, vary=0.03, variants=1,
           xfade=0.3, note="", takes=1, duck=False, warm=True, match=None, combo=False, tuned=False):
    ## variants: the recipe is called with v = 0..variants-1 and draws a different sound for each (enemy kinds...).
    ## takes: the same recipe rendered several times with its own seed and pitch, so repeats do not sound robotic.
    ## duck: while it plays the game lowers ambience and music (a story beat). warm: roll off above WARM_HZ.
    ## match: loudness (RMS dB) to hit instead of `peak`, with peaks allowed up to 4 dB over `peak`: a sound rebuilt on a
    ## sharper recorded body keeps the old sound's loudness, and the new punch shows as attack, not as "quieter".
    ## tuned: takes only change the seed, not the pitch (keeps a sound's notes or a voice's contour as built).
    ## combo: repeats in quick succession climb the key's pentatonic scale in the game (AudioBank.COMBO_STEPS).
    def deco(fn):
        RECIPES[name] = dict(fn=fn, tid=tid, bus=bus, peak=peak, loop=loop, rms=rms, spatial=spatial,
                             cooldown=cooldown, vary=vary, variants=variants, xfade=xfade, note=note, takes=takes,
                             duck=duck, warm=warm, match=match, combo=combo, tuned=tuned)
        return fn
    return deco


# ============================================================================== RECORDINGS (round 5)
# Siddharth 2026-11-08: "minimal use of code generated sounds, it should mainly be real sounds". Every recipe below is
# built ONLY from recordings (grains cut by tools/audio_grains.py, credited in docs/AUDIO_CREDITS.md). Code only
# processes them: cut, pitch, filter, layer, place in a small room. main() checks no synthesis function is called.

# Loudness of each one-shot's approved previous version (round 4, the mix he heard): the recordings peak sharper, so
# they are matched to this average level (peaks may go up to 4 dB over `peak`) instead of coming out quieter.
MIX_RMS = { "airship_shot": -16.6, "amb_bird": -23.8, "amb_creak": -27.9, "amb_leaves": -29.7, "amb_owl": -24.1, "amb_rustle": -32.1, "amb_work": -31.3, "bark_archer_cheer": -25.5, "bark_archer_ready": -24.3, "bark_guard_cheer": -24.4, "bark_guard_ready": -24.5, "bark_pilot_cheer": -25.6, "bark_pilot_ready": -25.4, "bark_wizard_cheer": -23.8, "bark_wizard_ready": -25.3, "boss_phase": -20.9, "boss_roar": -19.3, "boulder_fall": -14.8, "boulder_hit": -18.5, "build_pop": -23.4, "coin_bad": -24.2, "coin_flick": -19.3, "coin_good": -23.0, "coin_neutral": -20.5, "cooldown_ready": -25.5, "crossbow_pierce": -21.7, "crossbow_shot": -22.4, "dawn_bell": -24.8, "door_close": -22.1, "enemy_death": -21.9, "enemy_spawn": -25.0, "fireball_hit": -19.0, "fireball_launch": -16.9, "foresight_whisper": -26.7, "forest_rumble": -20.7, "gate_open": -24.5, "grab": -17.9, "heal_chime": -24.0, "help_done": -24.0, "hit_soft": -24.3, "house_hit": -23.5, "invalid": -18.5, "melee_hit": -21.2, "menu_close": -24.2, "menu_open": -23.2, "night_fall": -23.0, "orb_charge": -22.2, "pinch": -23.1, "place_thunk": -17.2, "potion_pour": -33.2, "rage_cast": -19.9, "rarity_common": -26.8, "rarity_legendary": -23.1, "rarity_rare": -21.5, "release": -20.2, "request_new": -27.3, "rewind_whoosh": -21.9, "root_grow": -29.1, "sell": -20.4, "shutter_close": -16.8, "spell_pick": -22.8, "splitter_split": -20.3, "storm_cloud": -24.0, "throw_whoosh": -24.6, "trust_chime": -20.6, "tunneler_pop": -20.5, "ui_cancel": -23.9, "ui_hover": -29.8, "village_bell": -22.1, "villager_blip": -25.0, "ward_cast": -18.7, "wisp_screech": -26.4 }

SR_ = S.SR

# The game's key (Siddharth 2026-11-08: bells and chimes in the music's key; no music yet, so the key is set here and the
# music follows it): C major by day; night sounds may borrow from the parallel C minor (Eb, Ab, Bb) for a little tension.
KEY_DAY = {0, 2, 4, 5, 7, 9, 11}
KEY_NIGHT = KEY_DAY | {3, 8, 10}
NIGHT_SOUNDS = {"night_fall", "night_bed", "amb_owl", "amb_creak", "amb_rustle", "boss_roar", "boss_phase", "fog_loop"}
_NOTES_USED = []


def _pitch_class(name):
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    p = names[name[0]]
    for ch in name[1:]:
        if ch == "#":
            p += 1
        elif ch == "b":
            p -= 1
    return p % 12


def note(name):  # noqa: F811  (wraps audio_synth.note so every recipe's notes can be checked against the key)
    _NOTES_USED.append(name)
    return S.note(name)


_INDEX = None
_STEREO = {}


def _index():
    global _INDEX
    if _INDEX is None:
        _INDEX = json.load(open(os.path.join(GRAINS, "grains.json"), encoding="utf-8"))
    return _INDEX


def _resample(x, k):
    """Play x at k times its speed (k > 1: higher and shorter), with an anti-alias filter when shrinking."""
    if abs(k - 1.0) < 1e-6:
        return x
    if k > 1.0:
        x = lp(x, 0.45 * SR_ / k, 4)
    n = max(16, int(x.shape[0] / k))
    at = np.linspace(0, x.shape[0] - 1, n)
    src = np.arange(x.shape[0])
    return np.interp(at, src, x) if x.ndim == 1 else np.stack([np.interp(at, src, x[:, c]) for c in range(x.shape[1])], axis=1)


MAX_SHIFT = 5.5  # semitones a real note may be shifted (a fourth and a bit: the church bell F5 -> C5); further sounds
# fake (code-critic round 5) and fails the build
_FAR_NOTES = []


def tuned(name, r, kits=("wood_notes",), seconds=None, minlen=0.2):
    """A real recorded note (marimba, xylophone, kalimba, music box, bell) shifted to the key's note `name`: the grain
    whose measured pitch is nearest the target, so no note is stretched far."""
    from scipy.io import wavfile
    target = note(name)
    cands = [(abs(np.log2(target / e["f0"])), kit, e) for kit in kits for e in _index()[kit]
             if e.get("keep", True) and e.get("f0") and e["seconds"] >= minlen]
    if not cands:
        raise RuntimeError("tuned(%s): no kept grain with a pitch in %s" % (name, ", ".join(kits)))
    d0 = min(c[0] for c in cands)
    near = [c for c in cands if c[0] <= d0 + 0.05]  # within ~half a semitone of the closest: pick one at random
    d, kit, e = near[int(r.integers(0, len(near)))]
    if d * 12 > MAX_SHIFT:
        _FAR_NOTES.append("%s from %s %.0f Hz (%+.1f st)" % (name, kit, e["f0"], 12 * np.log2(target / e["f0"])))
    x = _mono(wavfile.read(os.path.join(GRAINS, kit, e["file"]))[1].astype(float) / 32768.0)
    x = _resample(x, target / e["f0"])
    if seconds is not None and len(x) > n_of(seconds):
        x = x[: n_of(seconds)].copy()
        x[-n_of(0.06):] *= np.linspace(1, 0, n_of(0.06))
    return pk(x)


def melody(names, r, kits=("wood_notes",), gap=0.09, gains=None, seconds=None):
    """Notes one after another (a jingle), each a real recorded note in key."""
    return mix(*[(tuned(n, r, kits, seconds), gap * i, (gains[i] if gains else 0.9)) for i, n in enumerate(names)])


def bed(kit, r, seconds):
    """`seconds` of a long stereo recording window (wind, crickets, rain, fire...), from a random point in it."""
    from scipy.io import wavfile
    keep = [e for e in _index()[kit] if e.get("keep", True)]
    e = keep[int(r.integers(0, len(keep)))]
    path = os.path.join(GRAINS, kit, e["file"])
    if path not in _STEREO:
        x = wavfile.read(path)[1].astype(float) / 32768.0
        _STEREO[path] = x if x.ndim == 2 else np.stack([x, x], axis=1)
    x = _STEREO[path]
    n = n_of(seconds)
    if len(x) <= n:  # window too short: lay copies end to end with an equal-power crossfade, so no seam clicks
        xf = max(1, min(n_of(0.3), len(x) // 3))
        w = np.sin(np.linspace(0, np.pi / 2, xf))[:, None]
        out = x.copy()
        while len(out) < n:
            out = np.concatenate([out[:-xf], out[-xf:] * w[::-1] + x[:xf] * w, x[xf:]])
        return out[:n].copy()
    a = int(r.integers(0, len(x) - n))
    return x[a: a + n].copy()


# Each voice kit's syllables span a wide range of pitches (different takes, some octave misreads); a narrow band per kit
# keeps one speaker's syllables close together, so a bark's contour is not lost in 20-semitone jumps (code-critic).
VOICE_BAND = {"voice_m": (70, 100), "grunt": (100, 160)}  # Hz; voice_f (158-205) and voice_old (92-121) are already narrow


def voice(kit, r, seconds=None, step=0.0, slide=0.0):
    """A real voice syllable at the speaker's OWN pitch (Siddharth 2026-11-08: no more shifting voices onto the key's
    notes, it made them chipmunky), moved only `step` semitones for a little up/down contour; slide: semitones of rise
    over the syllable's second half."""
    from scipy.io import wavfile
    lo, hi = VOICE_BAND.get(kit, (70, 450))
    keep = [e for e in _index()[kit] if e.get("keep", True) and lo <= e.get("f0", 0) <= hi and e["seconds"] > 0.08]
    if not keep:
        raise RuntimeError("voice(%s): no kept syllable between %d and %d Hz" % (kit, lo, hi))
    e = keep[int(r.integers(0, len(keep)))]
    x = _mono(wavfile.read(os.path.join(GRAINS, kit, e["file"]))[1].astype(float) / 32768.0)
    k = 2 ** (step / 12)
    lift = 2 ** (slide / 12) if slide else 1.0
    kmax = k * max(1.0, lift)
    if kmax > 1.0:  # one anti-alias filter over the whole syllable (no restart mid-syllable)
        x = lp(x, 0.45 * SR_ / kmax, 4)
    # speed rises smoothly from k to k * lift over the syllable (a small upward lift when slide > 0)
    m = len(x)
    # read position through the source: speed k for the first half, then rising to k * lift by the end
    grid = np.linspace(0.0, m - 1, 512)
    spd = k * lift ** np.clip(2 * grid / (m - 1) - 1.0, 0.0, 1.0)
    t_at = np.concatenate([[0.0], np.cumsum(np.diff(grid) / ((spd[1:] + spd[:-1]) / 2))])  # output time at each grid point
    x = np.interp(np.interp(np.arange(int(t_at[-1]) + 1), t_at, grid), np.arange(m), x)
    if seconds is not None and len(x) > n_of(seconds):
        x = x[: n_of(seconds)].copy()
    return fade(pk(x), 0.008, 0.04)


def far(x, r, cutoff=3000, size=0.6, wet=0.45):
    """Push a recording away: darker and in a room (mono out)."""
    y = room(lp(x, cutoff), size, wet, seed=int(r.integers(1, 99)))
    return y[:, 0] if y.ndim == 2 else y


# ============================================================================== HANDS AND MENUS (bus: ui)

@recipe("pinch", "A08", takes=4, bus="ui", peak=-8, vary=0.06, cooldown=0.05, note="finger and thumb meet: a real small analog click")
def pinch(r, v):
    return lp(grain("click", r, 1.25, seconds=0.12), 7000)


@recipe("grab", "A08", takes=4, bus="ui", peak=-7, vary=0.06, cooldown=0.05, note="a hand closes on something: a cloth pat and a soft wooden knock")
def grab(r, v):
    return mix((lp(grain("cloth", r, 1.0, seconds=0.25), 6000), 0, 0.9), (lp(grain("wood_knock", r, 0.8, seconds=0.2), 4000), 0, 0.5))


@recipe("release", "A08", takes=4, bus="ui", peak=-9, vary=0.06, cooldown=0.05, note="the hand lets go: a light cloth brush and a click")
def release(r, v):
    return mix((lp(grain("cloth", r, 1.35, seconds=0.2), 7000), 0, 0.8), (lp(grain("click", r, 1.5, seconds=0.08), 6000), 0.02, 0.3))


@recipe("menu_open", "A09", bus="ui", peak=-8, note="a rising wooden jingle: real marimba / xylophone notes C5 G5 C6")
def menu_open(r, v):
    return room(melody(["C5", "G5", "C6"], r, gap=0.08, gains=[1.0, 0.9, 0.75]), 0.3, 0.2)[:, 0]


@recipe("menu_close", "A09", bus="ui", peak=-10, note="the same notes falling, shorter: G5 C5")
def menu_close(r, v):
    return room(melody(["G5", "C5"], r, gap=0.07, seconds=0.4), 0.3, 0.2)[:, 0]


@recipe("ui_hover", "A46", bus="ui", peak=-17, vary=0.1, cooldown=0.06, note="pointer over a button: a tiny real tick")
def ui_hover(r, v):
    return lp(grain("click", r, 1.7, seconds=0.05), 6000)


@recipe("ui_cancel", "A46", bus="ui", peak=-10, note="a low soft step down: real marimba A4 E4")
def ui_cancel(r, v):
    return room(melody(["A4", "E4"], r, gap=0.07, seconds=0.35), 0.3, 0.15)[:, 0]


@recipe("cooldown_ready", "A46", bus="ui", peak=-12, note="a spell is ready again: two music-box notes E6 A6")
def cooldown_ready(r, v):
    return room(melody(["E6", "A6"], r, ("bell_notes",), gap=0.07, seconds=0.5), 0.3, 0.2)[:, 0]


# ============================================================================== BUILDING

@recipe("place_thunk", "A10", takes=6, peak=-4, vary=0.05, note="a tower sets down on the board: a real game piece on wood, a deep wooden knock and a stone")
def place_thunk(r, v):
    piece = lp(grain("chess", r, 0.8), 6000)
    body = lp(grain("wood_knock", r, 0.5), 2500)
    stone = lp(grain("stone", r, 0.75, seconds=0.3), 4500)
    return mix((piece, 0, 0.7), (body, 0, 0.9), (stone, 0.003, 0.35))


@recipe("build_pop", "A12", takes=4, peak=-6, vary=0.05, note="a clatter of wooden blocks, a bubbly pop and two music-box sparkles")
def build_pop(r, v):
    blocks = lp(grain("blocks", r, 1.0), 7000)
    pop = lp(grain("bubbles", r, 1.2, seconds=0.25), 6000)
    sp = melody(["G6", "C7"], r, ("bell_notes",), gap=0.05, seconds=0.4)
    return room(mix((blocks, 0, 0.7), (pop, 0, 0.6), (sp, 0.05, 0.25)), 0.3, 0.15)[:, 0]


@recipe("invalid", "A11", bus="ui", peak=-8, cooldown=0.15, note="can't place or can't afford: two soft low marimba knocks, falling (E3 D3)")
def invalid(r, v):
    return lp(melody(["E3", "D3"], r, gap=0.12, seconds=0.3), 1600)


@recipe("sell", "A48", peak=-7, note="a tower is sold: real coins and a wooden thunk")
def sell(r, v):
    return mix((lp(grain("wood_knock", r, 0.6, seconds=0.25), 3000), 0, 0.6), (lp(grain("coins", r, 1.0), 8000), 0.05, 0.9))


# ============================================================================== COIN (not built yet, parked)

@recipe("coin_flick", "A13", takes=4, peak=-7, note="a real coin flipped and caught")
def coin_flick(r, v):
    return lp(grain("coins", r, 1.0), 9000)


@recipe("coin_good", "A14", peak=-7, note="a good result: music-box notes C6 E6 G6, rising")
def coin_good(r, v):
    return room(melody(["C6", "E6", "G6"], r, ("bell_notes",), gap=0.07), 0.5, 0.25)[:, 0]


@recipe("coin_neutral", "A14", peak=-8, note="a middling result: one bell G5")
def coin_neutral(r, v):
    return room(tuned("G5", r, ("bell_notes",)), 0.5, 0.25)[:, 0]


@recipe("coin_bad", "A14", peak=-8, note="a bad result: two low marimba notes, falling (E4 C4)")
def coin_bad(r, v):
    return room(lp(melody(["E4", "C4"], r, gap=0.15), 2000), 0.5, 0.2)[:, 0]


# ============================================================================== COMBAT

@recipe("fireball_launch", "A15", takes=6, peak=-5, spatial=True, vary=0.05, note="the orb throws a fireball: a real fire whoosh and a little crackle")
def fireball_launch(r, v):
    fire = lp(grain("fire_whoosh", r, 1.15, seconds=0.55), 7000)
    cr = lp(grain("crackle", r, 1.0), 6000)
    return mix((fire, 0, 1.0), (cr, 0.05, 0.3))


@recipe("fireball_hit", "A15", takes=8, peak=-6, spatial=True, vary=0.07, cooldown=0.04, note="a small fire burst where it lands: a short fire whoosh, crackles and a soil thump")
def fireball_hit(r, v):
    burst = lp(grain("fire_whoosh", r, 1.4, seconds=0.4), 6500) * exp_env(0.4, 0.14, 0.004)
    thump = lp(grain("dirt", r, 0.6, seconds=0.35), 1800)
    cr = mix((lp(grain("crackle", r, 1.0), 6000), 0.02, 1.0), (lp(grain("crackle", r, 1.2), 6000), 0.09, 0.7))
    return mix((burst, 0, 0.9), (thump, 0, 0.7), (cr, 0, 0.45))


@recipe("hit_soft", "A48", takes=8, peak=-12, spatial=True, vary=0.1, cooldown=0.05, note="a light hit (a bolt, a Guard's strike): a real wood knock and a cloth pat")
def hit_soft(r, v):
    return mix((lp(grain("wood_knock", r, 1.1, seconds=0.25), 6500), 0, 0.9), (lp(grain("cloth", r, 1.2, seconds=0.12), 5000), 0, 0.35))


@recipe("melee_hit", "A16", takes=8, peak=-8, spatial=True, vary=0.08, cooldown=0.05, note="a troop's blow: a real wooden whack and a cloth slap")
def melee_hit(r, v):
    return mix((lp(grain("hammer", r, 0.8), 5500), 0, 0.9), (lp(grain("cloth", r, 1.0, seconds=0.15), 5000), 0.004, 0.45))


@recipe("enemy_death", "A17", combo=True, peak=-8, spatial=True, vary=0.08, variants=3, cooldown=0.04,
        note="1 grunt: a squelch and a cloth poof; 2 scout: a high squelch; 3 flyer: a flutter of wings")
def enemy_death(r, v):
    if v == 0:
        return mix((lp(grain("squish", r, 0.9), 5000), 0, 0.9), (lp(grain("cloth", r, 0.8, seconds=0.3), 4000), 0.02, 0.5),
                   (lp(grain("dirt", r, 0.7, seconds=0.25), 2500), 0, 0.4))
    if v == 1:
        return mix((lp(grain("squish", r, 1.4), 6000), 0, 0.9), (lp(grain("cloth", r, 1.3, seconds=0.2), 6000), 0.01, 0.4))
    return room(mix((lp(grain("wings", r, 1.1), 7000), 0, 0.9), (lp(grain("cloth", r, 1.4, seconds=0.2), 6000), 0.03, 0.4)), 0.4, 0.2)[:, 0]


@recipe("enemy_spawn", "A18", takes=4, peak=-12, spatial=True, vary=0.08, cooldown=0.2, note="something stirs in the forest: real leaves rustle and a low wooden creak")
def enemy_spawn(r, v):
    leaves = lp(_mono(bed("leaves", r, 0.9)), 6000) * swell(0.9, 0.4)
    creak = lp(grain("creak", r, 0.7, seconds=0.9), 1500) * swell(0.9, 0.5)
    return mix((pk(leaves), 0, 0.8), (pk(creak), 0, 0.35))


@recipe("wisp_wings", "A19", bus="sfx", peak=-14, loop=True, spatial=True, xfade=0.15, vary=0.04, note="loop: a flyer's soft flutter (real wings)")
def wisp_wings(r, v):
    return lp(_mono(bed("bed_flutter", r, 1.35)), 7000)


@recipe("wisp_screech", "A19", peak=-12, spatial=True, vary=0.08, cooldown=0.5, note="a flyer's cry: a real bird call, pitched down a little and in the air")
def wisp_screech(r, v):
    return room(lp(grain("bird", r, 0.85, seconds=0.45), 6000), 0.5, 0.25)[:, 0]


@recipe("tunneler_pop", "A20", takes=4, peak=-8, spatial=True, vary=0.08, note="it bursts out of the ground: real soil, a stone and a bubbly plop")
def tunneler_pop(r, v):
    return mix((lp(grain("dirt", r, 1.0, seconds=0.4), 5000), 0, 0.9), (lp(grain("stone", r, 0.6, seconds=0.3), 3000), 0, 0.6),
               (lp(grain("bubbles", r, 1.0, seconds=0.2), 5000), 0.05, 0.4))


@recipe("splitter_split", "A21", peak=-9, spatial=True, vary=0.08, note="a squelchy split: a real squelch, bubbles and two marimba plinks (G5 D6)")
def splitter_split(r, v):
    return mix((lp(grain("squish", r, 1.1), 5000), 0, 0.9), (lp(grain("bubbles", r, 1.3, seconds=0.3), 6000), 0.05, 0.5),
               (melody(["G5", "D6"], r, gap=0.05, seconds=0.3), 0.18, 0.35))


@recipe("boss_roar", "A22", duck=True, peak=-3, spatial=True, cooldown=2.0, vary=0.03, note="a deep growl: two real creature voices pitched down, with a far thunder rumble")
def boss_roar(r, v):
    a = lp(grain("creature", r, 0.6, spread=0.03, seconds=2.0), 3000)
    b = lp(grain("creature", r, 0.75, spread=0.03, seconds=2.0), 3500)
    rum = lp(grain("thunder", r, 0.6, seconds=2.4), 600)
    return reverb(mix((a, 0, 1.0), (b, 0.08, 0.7), (rum, 0.3, 0.5)), 1.3, 0.22)


@recipe("boss_phase", "A22", duck=True, peak=-5, spatial=True, cooldown=1.0, note="a phase change: real glass shards, a thunder boom and falling bells")
def boss_phase(r, v):
    shards = lp(grain("shards", r, 1.0, seconds=1.2), 7000)
    boom = lp(grain("thunder", r, 0.8, seconds=1.5), 1200)
    fall = melody(["E7", "C7", "A6", "E6", "C6"], r, ("bell_notes",), gap=0.06, seconds=0.8)
    return reverb(mix((shards, 0, 0.8), (boom, 0, 1.0), (fall, 0.1, 0.45)), 1.1, 0.2)


# ============================================================================== VILLAGE

@recipe("house_hit", "A23", takes=4, peak=-8, spatial=True, vary=0.06, cooldown=0.7, note="an enemy strikes a house: real wood knocks, a whack and a creak")
def house_hit(r, v):
    return mix((lp(grain("wood_knock", r, 0.7), 5000), 0, 0.9), (lp(grain("hammer", r, 0.7), 4500), 0.01, 0.6),
               (lp(grain("creak", r, 0.9, seconds=0.3), 2500), 0.05, 0.35))


@recipe("shutter_close", "A23", peak=-7, spatial=True, note="the house shuts up: three real wooden clacks and a door")
def shutter_close(r, v):
    k = [(lp(grain("wood_knock", r, 1.0, seconds=0.12), 5000), t, g) for t, g in ((0.08, 0.9), (0.14, 0.8), (0.19, 1.0))]
    return mix(*k, (lp(grain("door", r, 1.2, seconds=0.4), 5000), 0.0, 0.4))


@recipe("door_close", "A35", takes=4, peak=-8, spatial=True, cooldown=0.1, note="a real small wooden door closing and a latch click")
def door_close(r, v):
    return mix((lp(grain("door", r, 1.15, seconds=0.7), 6000), 0, 0.9), (lp(grain("click", r, 1.0, seconds=0.12), 6000), 0.1, 0.35))


@recipe("gate_open", "A43", peak=-9, spatial=True, note="the Guard Tower gate swings open: a real wooden gate creak and a thump")
def gate_open(r, v):
    return mix((lp(grain("creak", r, 1.0, seconds=0.7), 5000), 0, 1.0), (lp(grain("wood_knock", r, 0.6, seconds=0.25), 3000), 0.45, 0.6))


@recipe("trust_chime", "A33", bus="ui", peak=-8, note="trust gained: two music-box notes (E6 B6)")
def trust_chime(r, v):
    return room(melody(["E6", "B6"], r, ("bell_notes",), gap=0.08), 0.5, 0.25)[:, 0]


@recipe("help_done", "A34", duck=True, bus="ui", peak=-8, note="a request finished: a four note marimba jingle (C5 E5 G5 C6) and a bell")
def help_done(r, v):
    x = mix((melody(["C5", "E5", "G5", "C6"], r, gap=0.09), 0, 1.0), (tuned("C6", r, ("bell_notes",)), 0.3, 0.45))
    return room(x, 0.5, 0.25)[:, 0]


@recipe("request_new", "A48", bus="ui", peak=-12, spatial=True, cooldown=0.2, note="a '!' appears over a house: a curious marimba two-step (E5 B5)")
def request_new(r, v):
    return room(melody(["E5", "B5"], r, gap=0.1), 0.4, 0.2)[:, 0]


@recipe("villager_blip", "A32", bus="sfx", peak=-12, spatial=True, vary=0.05, variants=5, cooldown=0.3,
        note="five villagers' gibberish: real voice syllables at the speakers' own pitch, each villager a little higher or lower (no real words)")
def villager_blip(r, v):
    # (voice kit, semitones from the speaker's own pitch): small offsets only, so five villagers differ without chipmunks
    kit, base = [("voice_f", 0), ("voice_m", 1), ("voice_f", 2), ("voice_m", -2), ("voice_f", -2)][v]
    out, at = [], 0.0
    for i in range(int(r.integers(3, 6))):
        s = voice(kit, r, seconds=float(r.uniform(0.1, 0.16)), step=base + float(r.choice([0, 1, 2])))
        out.append((s, at, 1.0))
        at += len(s) / SR_ + float(r.uniform(0.01, 0.03))
    return room(mix(*out) * 0.6, 0.3, 0.15)[:, 0]


@recipe("village_bell", "A45", duck=True, peak=-6, spatial=False, cooldown=1.0, note="the village bell: a real church bell, twice (tuned to D4)")
def village_bell(r, v):
    b = tuned("D4", r, ("church",), seconds=3.0)
    return reverb(mix((b, 0, 1.0), (b, 1.1, 0.8)), 1.4, 0.2)


@recipe("dawn_bell", "A38", duck=True, bus="sfx", peak=-7, note="day begins: a real church bell (G4) with a music-box note over it")
def dawn_bell(r, v):
    return reverb(mix((tuned("G4", r, ("church",), seconds=3.2), 0, 1.0), (tuned("D6", r, ("bell_notes",)), 0.02, 0.3)), 1.5, 0.25)


@recipe("night_fall", "A48", duck=True, peak=-10, note="dusk turns to night: a falling minor third on a real church bell (G4 Eb4), a low marimba and a singing-bowl hum")
def night_fall(r, v):
    d = 2.6
    x = mix((tuned("G4", r, ("church",), seconds=1.6), 0, 0.75), (tuned("Eb4", r, ("church",), seconds=1.6), 0.45, 0.75),
            (lp(tuned("C3", r), 900), 0.9, 0.45))
    hum = lp(tuned("C3", r, ("bowl",), seconds=d), 500) * swell(d, 0.55)
    return reverb(mix((x, 0, 1.0), (pk(hum, 0.3), 0, 1.0), seconds=d), 1.5, 0.28)


@recipe("heal_chime", "A27", bus="sfx", peak=-8, note="a house repairs: three music-box notes rising (E6 G6 C7)")
def heal_chime(r, v):
    return room(melody(["E6", "G6", "C7"], r, ("bell_notes",), gap=0.09), 0.6, 0.3)[:, 0]


@recipe("potion_pour", "A29", peak=-12, note="a vial poured: real bottle glugs")
def potion_pour(r, v):
    out, at = [], 0.0
    while at < 0.9:
        out.append((lp(grain("bubbles", r, 1.0 + at * 0.4, seconds=0.25), 6000), at, float(r.uniform(0.6, 1.0))))
        at += float(r.uniform(0.11, 0.18))
    return mix(*out)


# ============================================================================== SPELLS AND TOWERS

@recipe("throw_whoosh", "A24", takes=4, bus="ui", peak=-10, vary=0.06, cooldown=0.05, note="a thrown spell leaves the hand: a real short whoosh")
def throw_whoosh(r, v):
    return lp(grain("whoosh", r, 1.1, seconds=0.4), 7000)


@recipe("boulder_fall", "A25", peak=-6, spatial=True, note="a boulder falls: a real flying-object whoosh, slowed and falling in pitch as it nears the ground")
def boulder_fall(r, v):
    # a real flying-object whoosh slowed right down, its pitch falling in the second half (the firework whistles carried
    # their bang with them)
    w = lp(grain("whoosh", r, 0.6, spread=0.03), 5000)
    h = len(w) // 2
    w = np.concatenate([w[:h], _resample(w[h:], 0.8)])
    return w * np.linspace(0.3, 1.0, len(w)) ** 1.5


@recipe("boulder_hit", "A25", takes=4, peak=-3, spatial=True, cooldown=0.1, note="a boulder lands: real stones knocking, soil and a far thunder thump")
def boulder_hit(r, v):
    body = lp(grain("stone", r, 0.45), 1500)
    stone = lp(grain("stone", r, 0.7), 5000)
    soil = lp(grain("dirt", r, 0.9, seconds=0.5), 4500) * exp_env(0.5, 0.2, 0.004)
    boom = lp(grain("thunder", r, 1.0, seconds=0.8), 400)
    return reverb(mix((body, 0, 1.0), (stone, 0, 0.7), (soil, 0.02, 0.4), (boom, 0, 0.6)), 0.5, 0.15)


@recipe("fire_loop", "A26", bus="sfx", peak=-14, rms=-30, loop=True, spatial=True, xfade=0.3, note="loop: a real campfire crackling")
def fire_loop(r, v):
    return soft_clip(pk(lp(_mono(bed("bed_fire", r, 2.3)), 8000)), 3.0)  # tame the sharpest pops so it can sit at its level


@recipe("spell_pick", "A48", bus="ui", peak=-11, note="picking up a spell token: a marimba A5 and a music-box E7")
def spell_pick(r, v):
    return room(mix((tuned("A5", r), 0, 0.9), (tuned("E7", r, ("bell_notes",), seconds=0.4), 0.02, 0.3)), 0.3, 0.15)[:, 0]


@recipe("storm_cloud", "A48", peak=-7, spatial=True, note="Storm Cloud: a real thunder roll and real rain")
def storm_cloud(r, v):
    d = 1.8
    rum = lp(grain("thunder", r, 0.9, seconds=d), 2500)
    rain = hp(_mono(bed("bed_rain", r, d)), 600) * swell(d, 0.5)
    return reverb(mix((rum, 0, 1.0), (pk(rain), 0.1, 0.4)), 0.8, 0.15)


@recipe("rage_cast", "A48", peak=-6, spatial=True, note="Rage: two real war-drum hits and a shout")
def rage_cast(r, v):
    drum = lp(grain("drum", r, 0.9), 4000)
    shout = lp(grain("grunt", r, 0.85, seconds=0.6), 4000)
    return reverb(mix((drum, 0, 1.0), (lp(grain("drum", r, 1.0), 4000), 0.16, 0.9), (shout, 0.2, 0.5)), 0.7, 0.15)


@recipe("root_grow", "A28", peak=-9, spatial=True, note="Root Ward: real wood creaking, soil and a crack as roots grow")
def root_grow(r, v):
    return mix((lp(grain("creak", r, 0.65, seconds=0.9), 2500), 0, 1.0), (lp(grain("dirt", r, 0.8, seconds=0.6), 4000), 0.1, 0.6),
               (lp(grain("hammer", r, 0.6), 3000), 0.6, 0.4))


@recipe("ward_cast", "A28", peak=-8, spatial=True, note="a rune lights: a struck bell (A5) and a singing bowl swelling")
def ward_cast(r, v):
    bowl = lp(tuned("A2", r, ("bowl",), seconds=1.2), 3000) * swell(1.2, 0.35)
    return reverb(mix((tuned("A5", r, ("bell_notes",)), 0, 0.8), (pk(bowl), 0, 0.45)), 0.8, 0.18)


@recipe("ward_hum", "A28", bus="sfx", peak=-16, rms=-32, loop=True, spatial=True, xfade=0.25, note="loop: a shield humming softly (a real singing bowl)")
def ward_hum(r, v):
    return lp(_mono(bed("bed_bowl", r, 1.8)), 3000)


@recipe("forest_rumble", "A30", peak=-9, spatial=True, cooldown=1.0, note="a wave gathers at the tree line: a low real thunder rumble, leaves and creaking branches")
def forest_rumble(r, v):
    d = 1.9
    rum = lp(grain("thunder", r, 0.5, seconds=d), 300) * swell(d, 0.45)
    leaves = lp(_mono(bed("leaves", r, d)), 5000) * swell(d, 0.6)
    creak = lp(grain("creak", r, 0.6, seconds=d), 1200)
    return mix((pk(rum), 0, 0.9), (pk(leaves), 0, 0.4), (creak, 0.3, 0.35))


@recipe("orb_charge", "A43", peak=-12, spatial=True, note="the Wizard Tower's orb gathers power: a real magic shimmer rising, with a crackle")
def orb_charge(r, v):
    d = 0.9
    mg = lp(grain("magic", r, 1.0, seconds=d), 8000) * swell(d, 0.85)
    return mix((pk(mg), 0, 1.0), (lp(grain("crackle", r, 1.0), 6000), 0.6, 0.35))


@recipe("crossbow_shot", "A43", takes=6, peak=-7, spatial=True, vary=0.05, note="the Wind Crossbow: a real bow release and a rush of air")
def crossbow_shot(r, v):
    return mix((lp(grain("bow", r, 1.0, seconds=0.45), 7000), 0, 0.9), (lp(grain("whoosh", r, 0.9, seconds=0.4), 6000), 0.03, 0.5))


@recipe("crossbow_pierce", "A43", takes=6, peak=-12, spatial=True, vary=0.08, cooldown=0.08, note="the bolt passes through: a real stick whoosh")
def crossbow_pierce(r, v):
    return hp(grain("whoosh", r, 1.3, seconds=0.35), 900)


@recipe("airship_engine", "A43", bus="sfx", peak=-16, rms=-32, loop=True, spatial=True, xfade=0.3, note="loop: a soft propeller chug (a real slow propeller)")
def airship_engine(r, v):
    return lp(_mono(bed("bed_propeller", r, 2.2)), 2500)


@recipe("airship_shot", "A43", takes=4, peak=-5, spatial=True, vary=0.05, note="the Airship's cannon: a real far cannon pitched up (toy-sized) and a stone thump")
def airship_shot(r, v):
    boom = lp(grain("cannon", r, 1.25, seconds=0.8), 3200)
    return mix((boom, 0, 1.0), (lp(grain("stone", r, 0.5, seconds=0.3), 1500), 0, 0.5))


# ============================================================================== FORESIGHT, REWIND, CARDS

@recipe("foresight_whisper", "A36", bus="ui", peak=-10, variants=3, note="the lens: real whispering, sharper with each tier (vague, clear, sharp)")
def foresight_whisper(r, v):
    d = 1.2
    w = _mono(bed("bed_whisper", r, d))
    w = lp(w, [1800, 3200, 5500][v])  # each tier a little clearer (no added treble: it read as a blade)
    return reverb(pk(w) * swell(d, 0.55), 0.9, 0.2)


@recipe("rewind_whoosh", "A37", duck=True, peak=-4, note="time runs backwards: a real tape rewinding, clock ticks speeding up and a bell played backwards")
def rewind_whoosh(r, v):
    tape = lp(grain("rewind", r, 1.0, seconds=2.2), 7000)
    bell = reverb(tuned("C5", r, ("church",), seconds=2.0), 1.5, 0.35)
    backwards = bell[::-1].copy() * np.linspace(0.5, 1.0, len(bell)) ** 1.5
    ticks, at, gap = [], 0.0, 0.22
    while at < 2.0:
        ticks.append((lp(grain("ticks", r, 1.0 + at * 0.3, seconds=0.06), 6000), at, 0.3 + 0.7 * at / 2.0))
        at += gap
        gap = max(gap * 0.88, 0.04)
    return mix((backwards, 0, 0.7), (tape, 0, 0.7), (mix(*ticks), 0, 0.6), (tuned("C7", r, ("bell_notes",)), 2.05, 0.35))


@recipe("rarity_common", "A47", bus="ui", peak=-10, note="a Common card: a card flip and one music-box note (C6)")
def rarity_common(r, v):
    return room(mix((lp(grain("cards", r, 1.0), 8000), 0, 0.5), (tuned("C6", r, ("bell_notes",)), 0.03, 0.9)), 0.5, 0.2)[:, 0]


@recipe("rarity_rare", "A47", duck=True, bus="ui", peak=-8, note="a Rare card: a card flip, a note, a fifth above, and a shimmer")
def rarity_rare(r, v):
    x = mix((lp(grain("cards", r, 1.0), 8000), 0, 0.5), (melody(["E6", "B6"], r, ("bell_notes",), gap=0.1), 0.03, 0.9),
            (lp(grain("magic", r, 1.2, seconds=0.8), 9000) * swell(0.8, 0.3), 0.1, 0.25))
    return reverb(x, 1.0, 0.22)


@recipe("rarity_legendary", "A47", duck=True, bus="ui", peak=-5, note="a Legendary card: a card flip, a rising bell arpeggio, a church bell and a long magic shimmer")
def rarity_legendary(r, v):
    arp = melody(["C5", "E5", "G5", "C6", "E6", "G6"], r, ("bell_notes", "wood_notes"), gap=0.08, gains=[0.7] * 6)
    shim = lp(grain("magic", r, 1.0, seconds=1.6), 9000) * swell(1.6, 0.6)
    return reverb(mix((lp(grain("cards", r, 0.9), 8000), 0, 0.5), (arp, 0.1, 1.0), (tuned("C5", r, ("church",), seconds=2.0), 0.55, 0.5),
                      (pk(shim), 0.4, 0.4)), 1.6, 0.28)


# ============================================================================== TOWER VOICES (barks)
# Siddharth 2026-11-08: towers get short voice barks; round 5: chopped REAL voice syllables (Animalese-style, no real
# words), at the speakers' own pitch (Siddharth 2026-11-08), only nudged a few semitones for the "hup-hup-HAH" contour.
# "ready" when the tower is placed, "cheer" now and then on a kill.
VOICES = {  # crew: (voice kit, semitones for the low syllables, for the high ones), relative to the speaker's own pitch
    "wizard": ("voice_m", -2, 1),   # an old, warm voice (a man's syllables, a little low)
    "archer": ("voice_f", 0, 2),    # young and quick
    "pilot": ("voice_f", 1, 3),     # cheery and bouncy
    "guard": ("grunt", -1, 1),      # a gruff captain (real effort grunts)
}


def _bark(r, crew, kind):
    kit, lo, hi = VOICES[crew]
    out, at = [], 0.0
    n = int(r.integers(2, 4)) if kind == "ready" else int(r.integers(1, 3))
    for i in range(n):
        last = i == n - 1
        if kind == "ready":  # "hup-hup-HAH": low steps, the last syllable on the high step with a lift
            s = voice(kit, r, seconds=0.24 if last else 0.16, step=hi if last else lo, slide=2 if last else 0)
        else:  # a cheer: the high step with a lift
            s = voice(kit, r, seconds=0.2, step=hi, slide=2)
        if crew == "wizard" and r.random() < 0.6:
            s = voice("voice_old", r, seconds=0.22, step=lo)
        out.append((s, at, 1.0 if last else 0.8))
        at += len(s) / SR_ + float(r.uniform(0.02, 0.05))
    return room(lp(mix(*out), 5000) * 0.6, 0.25, 0.2, seed=int(r.integers(1, 99)))[:, 0]


for _crew in VOICES:
    for _kind, _cd, _what in (("ready", 0.5, "the tower is placed: a short 'hup-hup-hah'"), ("cheer", 3.0, "a kill, now and then: a quick happy yelp")):
        def _make(crew=_crew, kind=_kind):
            return lambda r, v: _bark(r, crew, kind)
        recipe("bark_%s_%s" % (_crew, _kind), "A49", takes=4, tuned=True, peak=-11, spatial=True, vary=0.0, cooldown=_cd,
               note="%s voice, %s (chopped real voice, no words)" % (_crew, _what))(_make())


# ============================================================================== AMBIENCE ONE-SHOTS
# The game scatters these at things you can see (AudioBank.set_scatter, pools in game.gd).

@recipe("amb_bird", "A50", bus="ambience", takes=8, peak=-9, spatial=True, vary=0.06, cooldown=1.0, note="a real bird in the forest ring calls once")
def amb_bird(r, v):
    return far(grain("bird", r, 1.0, spread=0.04), r, 6000, 0.5, 0.35)


@recipe("amb_leaves", "A50", bus="ambience", takes=4, peak=-12, spatial=True, vary=0.05, cooldown=2.0, note="a gust runs through one tree's real leaves")
def amb_leaves(r, v):
    d = float(r.uniform(1.0, 1.4))
    return lp(_mono(bed("leaves", r, d)), 6000) * swell(d, 0.4)


@recipe("amb_work", "A50", bus="ambience", takes=6, peak=-13, spatial=True, vary=0.06, cooldown=3.0, note="a villager at work by a house: a few far hammer taps or a door")
def amb_work(r, v):
    if r.random() < 0.6:  # hammering: 2-4 taps, a little uneven
        taps, at = [], 0.0
        for k in range(int(r.integers(2, 5))):
            taps.append((lp(grain("hammer", r, 0.9), 2600), at, float(r.uniform(0.6, 1.0))))
            at += float(r.uniform(0.32, 0.5))
        x = mix(*taps)
    else:
        x = lp(grain("door", r, 1.0, seconds=0.8), 2600)
    return room(x, 0.6, 0.5, seed=int(r.integers(1, 99)))[:, 0]


@recipe("amb_owl", "A51", bus="ambience", takes=3, peak=-10, spatial=True, vary=0.03, cooldown=6.0, note="night: an owl hoots in the forest ring")
def amb_owl(r, v):
    # pitched down: the recordings sit near 890 Hz (read as "a kettle"); a tawny owl's hoot is lower and softer
    return room(lp(grain("owl", r, 0.75, spread=0.03), 2000), 0.8, 0.45, seed=int(r.integers(1, 99)))[:, 0]


@recipe("amb_creak", "A51", bus="ambience", takes=4, peak=-12, spatial=True, vary=0.05, cooldown=4.0, note="night: a branch creaks in the forest ring (a real wooden creak, far)")
def amb_creak(r, v):
    return far(grain("creak", r, 0.8, seconds=0.9), r, 1500, 0.6, 0.4)


@recipe("amb_rustle", "A51", bus="ambience", takes=4, peak=-13, spatial=True, vary=0.05, cooldown=4.0, note="night: something small moves in the undergrowth (a little tense)")
def amb_rustle(r, v):
    out, at = [], 0.0
    for k in range(int(r.integers(2, 4))):
        out.append((lp(grain("dirt", r, 1.2, seconds=0.25), 3500), at, float(r.uniform(0.5, 1.0))))
        at += float(r.uniform(0.12, 0.3))
    return mix(*out)


# ============================================================================== AMBIENCE (loops, stereo)

@recipe("day_bed", "A39", bus="ambience", peak=-12, rms=-30, loop=True, xfade=0.6, note="loop: real wind through leaves with soft far woodland birdsong")
def day_bed(r, v):
    d = 12.6  # 12 s after the loop crossfade
    wind = lp(bed("bed_wind", r, d), 2500)  # softer and darker: at full width it read as "ocean waves"
    birds = lp(bed("bed_birds", r, d), 7000)
    return mix((pk(wind), 0, 0.45), (pk(birds), 0, 0.6), seconds=d)


@recipe("night_bed", "A40", bus="ambience", peak=-12, rms=-31, loop=True, xfade=0.6, note="loop: real crickets, a low breeze and a faint tense drone")
def night_bed(r, v):
    d = 14.6  # 14 s after the loop crossfade
    crickets = lp(bed("bed_crickets", r, d), 9000)
    wind = lp(bed("bed_wind", r, d), 600)
    drone = lp(bed("bed_drone", r, d), 900)
    return mix((pk(crickets), 0, 0.7), (pk(wind), 0, 0.5), (pk(drone), 0, 0.12), seconds=d)


@recipe("rain_loop", "A41", bus="ambience", peak=-12, rms=-30, loop=True, xfade=0.5, note="loop: steady real rain (Gentle Rain)")
def rain_loop(r, v):
    return soft_clip(pk(lp(bed("bed_rain", r, 8.0), 9000)), 3.0)  # tame the loudest drips so the rain can sit at its level


@recipe("fog_loop", "A41", bus="ambience", peak=-14, rms=-34, loop=True, xfade=0.6, note="loop: a muffled hush with a faint singing-bowl tone (Foggy Night)")
def fog_loop(r, v):
    d = 10.0
    hush = lp(bed("bed_wind", r, d), 450)
    tone = lp(bed("bed_bowl", r, d), 800)
    return mix((pk(hush), 0, 0.9), (pk(tone), 0, 0.15), seconds=d)


# ============================================================================== BUILD


def render(name, spec, v, take=0):
    seed = zlib.crc32(("%s:%d" % (name, v)).encode()) if take == 0 else zlib.crc32(("%s:%d:t%d" % (name, v, take)).encode())
    r = rng(seed)
    x = np.asarray(spec["fn"](r, v), dtype=float)
    # a sound with key notes in it (tuned() and melody() go through note()) keeps its pitch: a take's resample
    # would put it off key (code-critic round 5)
    if take > 0 and not spec["tuned"] and not _NOTES_USED:
        k = TAKE_PITCH[take % len(TAKE_PITCH)]
        n = max(16, int(round(x.shape[0] / k)))
        src = np.arange(x.shape[0])
        at = np.linspace(0, x.shape[0] - 1, n)  # plain interpolation: an FFT resample would wrap the attack onto the tail
        x = np.interp(at, src, x) if x.ndim == 1 else np.stack([np.interp(at, src, x[:, c]) for c in range(x.shape[1])], axis=1)
    if spec["warm"] and not spec["loop"]:
        x = lp(x, WARM_HZ, 2)
    if not spec["loop"]:
        x = remove_dc(x)
        x = trim_silence(x, -55.0, 0.02)
        x = fade(x, 0.0015, 0.015)
    else:
        x = remove_dc(x)
        x = loop_seamless(x, spec["xfade"])
    if spec["rms"] is not None:
        x = normalise(x, rms_db=spec["rms"], max_peak_db=-2.0)
    elif spec["match"] is not None or (not spec["loop"] and name in MIX_RMS):
        target = spec["match"] if spec["match"] is not None else MIX_RMS[name]
        x = normalise(x, rms_db=target, max_peak_db=min(-1.0, spec["peak"] + 4.0))
    else:
        x = normalise(x, peak_db=spec["peak"])
    return x


SYNTH = ["osc", "noise", "thud", "chirp", "fm", "glass", "marimba", "bell", "formant_blip", "crackle", "whoosh", "modal",
         "impulses", "resonate", "fire_texture"]  # sound SOURCES from audio_synth; recipes may only process recordings
_SYNTH_USED = []


def _guard(fn_name):
    real = getattr(S, fn_name)

    def wrapped(*a, **k):
        _SYNTH_USED.append(fn_name)
        return real(*a, **k)
    return wrapped


for _f in SYNTH:
    globals()[_f] = _guard(_f)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    godot = "--godot" in sys.argv
    names = args or list(RECIPES)
    os.makedirs(OUT, exist_ok=True)
    manifest_path = os.path.join(OUT, "manifest.json")
    manifest = {}
    if os.path.exists(manifest_path):
        manifest = json.load(open(manifest_path, encoding="utf-8"))
    off_key = []
    synth = []
    for name in names:
        spec = RECIPES[name]
        del _NOTES_USED[:]
        del _SYNTH_USED[:]
        for folder in ([OUT, GODOT_OUT] if godot and os.path.isdir(GODOT_OUT) else [OUT]):
            for old in os.listdir(folder):
                if re.fullmatch(re.escape(name) + r"(_\d+)?\.wav(\.import)?", old):
                    os.remove(os.path.join(folder, old))
        files = []
        renders = [(v, t) for v in range(spec["variants"]) for t in range(spec["takes"])]
        for i, (v, t) in enumerate(renders):
            x = render(name, spec, v, t)
            fn = "%s_%d.wav" % (name, i + 1) if len(renders) > 1 else "%s.wav" % name
            write_wav(os.path.join(OUT, fn), x)
            files.append(dict(file=fn, seconds=round(len(x) / SR_, 3), peak_db=round(to_db(peak_of(x)), 1),
                              rms_db=round(to_db(rms_of(x)), 1), seam=round(seam_error(x), 2) if spec["loop"] else None))
        manifest[name] = dict(tracker=spec["tid"], bus=spec["bus"], loop=spec["loop"], spatial=spec["spatial"],
                              cooldown=spec["cooldown"], files=files, note=spec["note"],
                              # in-game random pitch: none for sounds built on key notes, or they drift off key
                              vary=0.0 if (_NOTES_USED or spec["tuned"]) else spec["vary"],
                              duck=spec["duck"], combo=spec["combo"])
        if _SYNTH_USED:
            synth.append("%s: %s" % (name, " ".join(sorted(set(_SYNTH_USED)))))
        key = KEY_NIGHT if name in NIGHT_SOUNDS else KEY_DAY
        bad = sorted({n for n in _NOTES_USED if _pitch_class(n) not in key})
        if bad:
            off_key.append("%s: %s" % (name, " ".join(bad)))
        f = files[0]
        print("%-18s %-4s %-8s %5.2fs peak %5.1f rms %5.1f%s" % (name, spec["tid"], spec["bus"], f["seconds"], f["peak_db"], f["rms_db"],
                                                                  "  seam %.2f" % f["seam"] if f["seam"] is not None else ""))
    json.dump(manifest, open(manifest_path, "w", encoding="utf-8"), indent=1, sort_keys=True)
    print("key check (C major by day, C minor allowed at night):", "OK" if not off_key else "OFF KEY " + "; ".join(off_key))
    print("real-recordings check (no synthesis sources):", "OK" if not synth else "SYNTH USED " + "; ".join(synth))
    far_notes = sorted(set(_FAR_NOTES))
    print("note-shift check (real notes moved at most %g semitones):" % MAX_SHIFT,
          "OK" if not far_notes else "TOO FAR " + "; ".join(far_notes))
    if synth or far_notes:
        sys.exit(1)
    if godot:
        import shutil
        os.makedirs(GODOT_OUT, exist_ok=True)
        for fn in os.listdir(OUT):
            if fn.endswith((".wav", ".json")):
                shutil.copy2(os.path.join(OUT, fn), os.path.join(GODOT_OUT, fn))
        print("copied to", GODOT_OUT)


if __name__ == "__main__":
    main()
