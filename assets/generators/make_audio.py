"""Aeterna sound effects and ambience, all synthesised from code (Siddharth 2026-11-07: no recordings, no third-party
samples or soundfont). One recipe per sound; a recipe returns a numpy array and the framework below trims, cleans,
loudness-matches and writes it.

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


TAKE_PITCH = [1.0, 0.955, 1.045, 0.925, 1.075]  # take k of a sound is resampled by this (a small pitch and length change)
WARM_HZ = 10000  # second pass (Siddharth 2026-11-08, "peaceful and cozy"): one-shots lose their hard top end


def recipe(name, tid, bus="sfx", peak=-4.0, loop=False, rms=None, spatial=False, cooldown=0.0, vary=0.03, variants=1,
           xfade=0.3, note="", takes=1, duck=False, warm=True):
    ## variants: the recipe is called with v = 0..variants-1 and draws a different sound for each (enemy kinds...).
    ## takes: the same recipe rendered several times with its own seed and pitch, so repeats do not sound robotic.
    ## duck: while it plays the game lowers ambience and music (a story beat). warm: roll off above WARM_HZ.
    def deco(fn):
        RECIPES[name] = dict(fn=fn, tid=tid, bus=bus, peak=peak, loop=loop, rms=rms, spatial=spatial,
                             cooldown=cooldown, vary=vary, variants=variants, xfade=xfade, note=note, takes=takes,
                             duck=duck, warm=warm)
        return fn
    return deco


# ============================================================================== HANDS AND MENUS (bus: ui)

@recipe("pinch", "A08", takes=4, bus="ui", peak=-8, vary=0.06, cooldown=0.05, note="finger and thumb meet: a soft wooden tick and a small pip")
def pinch(r, v):
    tick = pk(bp(noise(0.03, r), 2200, 5200) * exp_env(0.03, 0.006, 0.0003))
    pip = osc("sine", curve([(0, 1500), (0.05, 2100)], 0.05), 0.05) * exp_env(0.05, 0.016, 0.0008)
    return mix((tick, 0, 0.55), (pip, 0, 0.55), (thud(0.05, 420, 260, 0.02), 0, 0.3))


@recipe("grab", "A08", takes=4, bus="ui", peak=-7, vary=0.06, cooldown=0.05, note="a hand closes on something: a duller wooden thok")
def grab(r, v):
    body = thud(0.16, 270, 120, 0.07, r, 0.45)
    pip = osc("sine", curve([(0, 760), (0.1, 520)], 0.1), 0.1) * exp_env(0.1, 0.035, 0.001)
    tick = pk(bp(noise(0.02, r), 1000, 2600) * exp_env(0.02, 0.004, 0.0003))
    return mix((body, 0, 1.0), (pip, 0.005, 0.45), (tick, 0, 0.3))


@recipe("release", "A08", takes=4, bus="ui", peak=-9, vary=0.06, cooldown=0.05, note="the hand lets go: a falling pip and a breath of air")
def release(r, v):
    pip = osc("sine", curve([(0, 1250), (0.09, 760)], 0.09), 0.09) * exp_env(0.09, 0.03, 0.002)
    air = pk(hp(noise(0.08, r), 3000) * exp_env(0.08, 0.02, 0.003))
    return mix((pip, 0, 0.7), (air, 0, 0.25), (thud(0.06, 200, 110, 0.025), 0.01, 0.25))


@recipe("menu_open", "A09", bus="ui", peak=-8, note="a rising two-step wooden plink")
def menu_open(r, v):
    x = mix((marimba(note("C5"), 0.5), 0, 1.0), (marimba(note("G5"), 0.5), 0.08, 0.9), (marimba(note("C6"), 0.55), 0.17, 0.75))
    return reverb(x, 0.6, 0.12)


@recipe("menu_close", "A09", bus="ui", peak=-10, note="the same two notes falling, shorter")
def menu_close(r, v):
    x = mix((marimba(note("G5"), 0.4), 0, 0.9), (marimba(note("C5"), 0.45), 0.07, 0.9))
    return reverb(x, 0.5, 0.1)


@recipe("ui_hover", "A46", bus="ui", peak=-17, vary=0.1, cooldown=0.06, note="pointer over a button: a tiny tick")
def ui_hover(r, v):
    return mix((osc("sine", 2100, 0.03) * exp_env(0.03, 0.008, 0.0005), 0, 0.7),
               (pk(bp(noise(0.02, r), 3000, 6000) * exp_env(0.02, 0.004, 0.0003)), 0, 0.3))


@recipe("ui_cancel", "A46", bus="ui", peak=-10, note="a low soft step down")
def ui_cancel(r, v):
    return reverb(mix((marimba(note("A4"), 0.3), 0, 0.9), (marimba(note("E4"), 0.35), 0.07, 0.8)), 0.4, 0.08)


@recipe("cooldown_ready", "A46", bus="ui", peak=-12, note="a spell is ready again: a tiny rising glint")
def cooldown_ready(r, v):
    return reverb(mix((glass(note("E6"), 0.4, 0.6), 0, 0.8), (glass(note("A6"), 0.45, 0.6), 0.07, 0.9)), 0.5, 0.12)


# ============================================================================== BUILDING

@recipe("place_thunk", "A10", takes=4, peak=-4, vary=0.05, note="a tower sets down on the board: a woody stone thunk")
def place_thunk(r, v):
    body = thud(0.35, 150, 58, 0.12, r, 0.5)
    stone = pk(bp(noise(0.04, r), 1400, 3600) * exp_env(0.04, 0.008, 0.0003))
    sub = osc("sine", 52, 0.25) * exp_env(0.25, 0.1, 0.004)
    return mix((body, 0, 1.0), (stone, 0, 0.3), (sub, 0, 0.5))


@recipe("build_pop", "A12", takes=4, peak=-6, vary=0.05, note="a puff of dust and a bubbly pop with two sparkles")
def build_pop(r, v):
    pop = osc("sine", curve([(0, 350), (0.07, 1100)], 0.08), 0.08) * exp_env(0.08, 0.025, 0.001)
    dust = pk(hp(lp(noise(0.35, r), 3200), 500) * exp_env(0.35, 0.09, 0.004))
    sp1 = glass(note("G6"), 0.3, 0.6)
    sp2 = glass(note("C7"), 0.35, 0.6)
    return reverb(mix((pop, 0, 0.9), (dust, 0, 0.4), (sp1, 0.04, 0.25), (sp2, 0.09, 0.2)), 0.5, 0.12)


@recipe("invalid", "A11", bus="ui", peak=-8, cooldown=0.15, note="can't place or can't afford: two soft low knocks, falling")
def invalid(r, v):
    a = lp(marimba(note("E3"), 0.25, 0.8), 1500)
    b = lp(marimba(note("D#3"), 0.3, 0.8), 1400)
    return mix((a, 0, 1.0), (b, 0.12, 0.9))


@recipe("sell", "A48", peak=-7, note="a tower is sold: coins and the thunk backwards-ish")
def sell(r, v):
    thunk = thud(0.2, 120, 60, 0.07, r, 0.3)
    c1 = glass(note("E6"), 0.35, 0.5)
    c2 = glass(note("B6"), 0.4, 0.5)
    c3 = glass(note("E7"), 0.4, 0.4)
    return reverb(mix((thunk, 0, 0.7), (c1, 0.06, 0.4), (c2, 0.12, 0.4), (c3, 0.18, 0.3)), 0.6, 0.12)


# ============================================================================== COIN (not built yet, parked)

@recipe("coin_flick", "A13", takes=4, peak=-7, note="a coin spun into the air and caught")
def coin_flick(r, v):
    t = t_of(0.55)
    spin = fm(2600, 1.41, 2.5 * np.exp(-t / 0.2), 0.55) * exp_env(0.55, 0.28, 0.001) * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * (14 - 8 * t) * t)))
    catch = bell(3100, 0.3, 1.0, 0.25)
    return mix((spin, 0, 0.7), (catch, 0.6, 0.6), (thud(0.1, 200, 120, 0.04), 0.6, 0.3))


@recipe("coin_good", "A14", peak=-7, note="a good result: a bright rising arpeggio")
def coin_good(r, v):
    x = mix((glass(note("E6"), 0.7), 0, 0.8), (glass(note("G#6"), 0.7), 0.07, 0.8), (glass(note("B6"), 0.8), 0.14, 0.8))
    return reverb(x, 0.9, 0.2)


@recipe("coin_neutral", "A14", peak=-8, note="a middling result: one round bell")
def coin_neutral(r, v):
    return reverb(bell(note("G5"), 0.9, 0.7, 0.8), 0.7, 0.15)


@recipe("coin_bad", "A14", peak=-8, note="a bad result: two low notes, falling")
def coin_bad(r, v):
    x = mix((lp(marimba(note("E4"), 0.5), 1800), 0, 0.9), (lp(marimba(note("C4"), 0.6), 1600), 0.15, 0.9))
    return reverb(x, 0.7, 0.15)


# ============================================================================== COMBAT

@recipe("fireball_launch", "A15", takes=4, peak=-5, spatial=True, vary=0.05, note="the orb throws a fireball: air, a low fwoomp and crackle")
def fireball_launch(r, v):
    air = whoosh(0.45, 300, 1700, r, 1.0, 0.3)
    boom = osc("sine", curve([(0, 70), (0.25, 190)], 0.3), 0.3) * exp_env(0.3, 0.12, 0.01)
    cr = crackle(0.4, r, 70, 3000) * exp_env(0.4, 0.2, 0.002)
    return mix((air, 0, 0.7), (boom, 0, 0.55), (cr, 0.03, 0.35))


@recipe("fireball_hit", "A15", takes=4, peak=-6, spatial=True, vary=0.07, cooldown=0.04, note="a small fire burst where it lands")
def fireball_hit(r, v):
    body = thud(0.38, 115, 46, 0.12, r, 0.4)
    puff = pk(lp(noise(0.35, r), 2600) * exp_env(0.35, 0.1, 0.003))
    sparks = crackle(0.3, r, 80, 3500) * exp_env(0.3, 0.12, 0.001)
    return mix((body, 0, 0.9), (puff, 0, 0.45), (sparks, 0.02, 0.35))


@recipe("hit_soft", "A48", takes=4, peak=-12, spatial=True, vary=0.1, cooldown=0.05, note="a light hit (a bolt, a Guard's strike): a short thump and tick")
def hit_soft(r, v):
    return mix((thud(0.1, 230, 120, 0.04, r, 0.3), 0, 0.9), (pk(bp(noise(0.02, r), 1800, 4500) * exp_env(0.02, 0.004)), 0, 0.5))


@recipe("melee_hit", "A16", takes=4, peak=-8, spatial=True, vary=0.08, cooldown=0.05, note="a troop's blow: a thud and a cloth slap")
def melee_hit(r, v):
    slap = pk(bp(noise(0.06, r), 900, 2600) * exp_env(0.06, 0.02, 0.0005))
    return mix((thud(0.15, 200, 105, 0.055, r, 0.3), 0, 0.9), (slap, 0, 0.5))


@recipe("enemy_death", "A17", peak=-8, spatial=True, vary=0.08, variants=3, cooldown=0.04,
        note="1 grunt: a falling bloop and a poof; 2 scout: pip and pff; 3 flyer: feathery whoosh")
def enemy_death(r, v):
    if v == 0:
        bloop = osc("sine", curve([(0, 430), (0.22, 105)], 0.24), 0.24) * exp_env(0.24, 0.1, 0.002)
        poof = pk(lp(noise(0.3, r), 1800) * exp_env(0.3, 0.07, 0.003))
        return mix((bloop, 0, 0.9), (poof, 0, 0.5), (thud(0.2, 120, 60, 0.08), 0, 0.5))
    if v == 1:
        pip = osc("sine", curve([(0, 950), (0.12, 310)], 0.13), 0.13) * exp_env(0.13, 0.05, 0.001)
        pff = pk(hp(noise(0.2, r), 1800) * exp_env(0.2, 0.05, 0.002))
        return mix((pip, 0, 0.9), (pff, 0.01, 0.4))
    air = whoosh(0.4, 3200, 800, r, 0.9, 0.2)
    soft = osc("sine", curve([(0, 720), (0.18, 210)], 0.2), 0.2) * exp_env(0.2, 0.07, 0.002)
    return reverb(mix((air, 0, 0.55), (soft, 0, 0.7), (glass(note("D7"), 0.3, 0.5), 0.15, 0.2)), 0.5, 0.12)


@recipe("enemy_spawn", "A18", takes=4, peak=-12, spatial=True, vary=0.08, cooldown=0.2, note="something stirs in the forest: a leaf rustle and a low creak")
def enemy_spawn(r, v):
    n = bp(noise(0.9, r), 1200, 4500)
    am = lp(noise(0.9, r), 14)
    am = 0.35 + 0.65 * np.clip((am - am.min()) / (np.ptp(am) + 1e-9), 0, 1)
    creak = osc("saw", curve([(0, 90), (0.6, 70)], 0.9), 0.9) * swell(0.9, 0.4)
    creak = lp(creak, 300)
    return mix((n * am * swell(0.9, 0.35), 0, 0.8), (creak, 0, 0.35))


@recipe("wisp_wings", "A19", bus="sfx", peak=-14, loop=True, spatial=True, xfade=0.15, vary=0.04, note="loop: a flyer's soft flutter")
def wisp_wings(r, v):
    d = 1.35
    t = t_of(d)
    flutter = (0.55 + 0.45 * np.sin(2 * np.pi * 15 * t)) ** 1.6
    n = bp(noise(d, r), 1100, 3400) * flutter
    hum = osc("sine", 520 + 40 * np.sin(2 * np.pi * 1.5 * t), d) * 0.12 * flutter
    return n + hum


@recipe("wisp_screech", "A19", peak=-12, spatial=True, vary=0.08, cooldown=0.5, note="a flyer's cry: a short rise and fall, soft")
def wisp_screech(r, v):
    a = chirp(1800, 3200, 0.12, 0.01, 28)
    b = chirp(3200, 900, 0.24, 0.015, 24)
    return reverb(mix((a, 0, 0.5), (b, 0.1, 0.5)), 0.5, 0.15)


@recipe("tunneler_pop", "A20", takes=4, peak=-8, spatial=True, vary=0.08, note="it bursts out of the ground: thump, gravel and a plop")
def tunneler_pop(r, v):
    body = thud(0.3, 100, 48, 0.1, r, 0.5)
    gravel = pk(lp(crackle(0.35, r, 140, 2200), 3500) * exp_env(0.35, 0.12, 0.002))
    plop = osc("sine", curve([(0, 250), (0.08, 520)], 0.09), 0.09) * exp_env(0.09, 0.03, 0.002)
    return mix((body, 0, 1.0), (gravel, 0, 0.5), (plop, 0.05, 0.4))


@recipe("splitter_split", "A21", peak=-9, spatial=True, vary=0.08, note="a squelchy split: a wobbly slurp, a pop and two little plinks")
def splitter_split(r, v):
    t = t_of(0.2)
    f = curve([(0, 200), (0.18, 700)], 0.2) * (1 + 0.08 * np.sin(2 * np.pi * 28 * t))
    slurp = osc("sine", f, 0.2) * exp_env(0.2, 0.09, 0.003)
    pop = osc("sine", curve([(0, 500), (0.04, 1500)], 0.05), 0.05) * exp_env(0.05, 0.015)
    return mix((slurp, 0, 0.8), (pop, 0.17, 0.6), (marimba(note("G5"), 0.25), 0.2, 0.35), (pan(marimba(note("D6"), 0.25), 0.5)[:, 0], 0.24, 0.3))


@recipe("boss_roar", "A22", duck=True, peak=-3, spatial=True, cooldown=2.0, vary=0.03, note="a deep growl with a moving mouth, ending in a rumble")
def boss_roar(r, v):
    d = 1.9
    t = t_of(d)
    f0 = curve([(0, 62), (0.5, 74), (d, 46)], d)
    src = osc("saw", f0, d)
    mouth = curve([(0, 300), (0.7, 750), (d, 280)], d)
    voiced = sweep_bp(src, mouth, 1.6) * 3.0
    gr = lp(noise(d, r), 700) * 0.5
    x = (voiced + gr) * (0.72 + 0.28 * np.sin(2 * np.pi * 27 * t)) * swell(d, 0.3)
    return reverb(soft_clip(x, 1.6), 1.3, 0.22)


@recipe("boss_phase", "A22", duck=True, peak=-5, spatial=True, cooldown=1.0, note="a phase change: a crystal crack, falling shimmer and a boom")
def boss_phase(r, v):
    cr = crackle(0.5, r, 160, 5200) * exp_env(0.5, 0.15, 0.001)
    boom = thud(0.8, 90, 36, 0.25, r, 0.6)
    shim = mix(*[(glass(note(n), 1.0, 1.0), 0.05 * i, 0.3) for i, n in enumerate(["E7", "C7", "A6", "E6", "C6"])])
    return reverb(mix((cr, 0, 0.8), (boom, 0, 1.0), (shim, 0.1, 0.5)), 1.1, 0.2)


# ============================================================================== VILLAGE

@recipe("house_hit", "A23", takes=4, peak=-8, spatial=True, vary=0.06, cooldown=0.7, note="an enemy strikes a house: wood cracks and a beam creaks")
def house_hit(r, v):
    crack1 = pk(bp(noise(0.06, r), 700, 2400) * exp_env(0.06, 0.012, 0.0005))
    crack2 = pk(bp(noise(0.08, r), 600, 2000) * exp_env(0.08, 0.02, 0.0005))
    creak = osc("saw", curve([(0, 190), (0.25, 150)], 0.3), 0.3) * exp_env(0.3, 0.12, 0.01)
    creak = lp(bp(creak, 150, 900), 900) * (0.7 + 0.3 * np.sin(2 * np.pi * 22 * t_of(0.3)))
    return mix((thud(0.3, 120, 66, 0.1, r, 0.4), 0, 1.0), (crack1, 0, 0.8), (crack2, 0.07, 0.6), (creak, 0.05, 0.4))


@recipe("shutter_close", "A23", peak=-7, spatial=True, note="the house shuts up: three wooden clacks and a slide")
def shutter_close(r, v):
    def clack(tau):
        return mix((bp(noise(0.05, r), 900, 2000) * exp_env(0.05, tau, 0.0003), 0, 1.0),
                   (lp(marimba(note("G3"), 0.1, 1.0), 900), 0, 0.5))
    slide = lp(noise(0.12, r), 1800) * swell(0.12, 0.5)
    return mix((slide, 0, 0.25), (clack(0.012), 0.08, 0.9), (clack(0.012), 0.14, 0.8), (clack(0.02), 0.19, 1.0))


@recipe("door_close", "A35", takes=4, peak=-8, spatial=True, cooldown=0.1, note="a wooden door and a latch click")
def door_close(r, v):
    return mix((thud(0.25, 170, 85, 0.09, r, 0.5), 0, 1.0),
               (bp(noise(0.015, r), 2500, 4500) * exp_env(0.015, 0.003, 0.0002), 0.12, 0.7))


@recipe("gate_open", "A43", peak=-9, spatial=True, note="the Guard Tower gate swings open: a creak and a thump")
def gate_open(r, v):
    d = 0.6
    t = t_of(d)
    n = sweep_bp(noise(d, r), curve([(0, 300), (d, 520)], d), 3.0)
    n = n * (0.55 + 0.45 * np.sin(2 * np.pi * 17 * t)) * swell(d, 0.5)
    return mix((n, 0, 1.2), (thud(0.2, 130, 70, 0.07, r, 0.3), 0.45, 0.6))


@recipe("trust_chime", "A33", bus="ui", peak=-8, note="trust gained: two bright glass notes and a sparkle")
def trust_chime(r, v):
    x = mix((glass(note("E6"), 0.6, 0.8), 0, 0.9), (glass(note("B6"), 0.7, 0.8), 0.08, 0.9),
            (hp(noise(0.25, r), 6000) * exp_env(0.25, 0.06, 0.001), 0.05, 0.05))
    return reverb(x, 0.7, 0.2)


@recipe("help_done", "A34", duck=True, bus="ui", peak=-8, note="a request finished: a four note marimba jingle and a bell")
def help_done(r, v):
    x = mix(*[(marimba(note(n), 0.5), 0.09 * i, 0.85) for i, n in enumerate(["C5", "E5", "G5", "C6"])],
            (bell(note("C6"), 1.0, 0.6, 0.7), 0.3, 0.45))
    return reverb(x, 0.9, 0.18)


@recipe("request_new", "A48", bus="ui", peak=-12, spatial=True, cooldown=0.2, note="a '!' appears over a house: a curious little two-step")
def request_new(r, v):
    return reverb(mix((marimba(note("E5"), 0.3), 0, 0.8), (marimba(note("B5"), 0.4), 0.1, 0.9)), 0.5, 0.1)


@recipe("villager_blip", "A32", bus="sfx", peak=-12, spatial=True, vary=0.05, variants=5, cooldown=0.3,
        note="five little voices of gibberish, each with its own pitch and vowels (no real speech)")
def villager_blip(r, v):
    base = [190, 240, 300, 370, 150][v]
    vow = {0: "aou", 1: "eai", 2: "iea", 3: "oua", 4: "uoa"}[v]
    out = []
    at = 0.0
    for i in range(int(r.integers(3, 6))):
        d = float(r.uniform(0.06, 0.1))
        f1 = base * float(r.uniform(0.85, 1.25))
        f2 = f1 * float(r.uniform(0.8, 1.3))
        out.append((formant_blip([(0, f1), (d, f2)], vow[i % 3], d, r), at, 1.0))
        at += d + float(r.uniform(0.015, 0.04))
    return reverb(mix(*out) * 0.5, 0.3, 0.06)


@recipe("village_bell", "A45", duck=True, peak=-6, spatial=False, cooldown=1.0, note="the village bell: a deep clang, twice")
def village_bell(r, v):
    b = bell(note("D4"), 3.0, 0.8, 1.5, ratios=(1.0, 2.0, 2.97, 4.2))
    return reverb(mix((b, 0, 1.0), (b, 1.1, 0.8)), 1.4, 0.2)


@recipe("dawn_bell", "A38", duck=True, bus="sfx", peak=-7, note="day begins: a soft struck bell with a music-box overtone")
def dawn_bell(r, v):
    b = bell(note("G4"), 3.4, 0.7, 1.3)
    mb = glass(note("D6"), 2.0, 1.6)
    return reverb(mix((b, 0, 1.0), (mb, 0.02, 0.25)), 1.5, 0.25)


@recipe("night_fall", "A48", duck=True, peak=-10, note="dusk turns to night: a soft falling minor third over a low swell (a little tense, same world)")
def night_fall(r, v):
    d = 2.6
    x = mix((glass(note("G4"), 1.8, 1.5), 0, 0.75), (glass(note("Eb4"), 2.0, 1.5), 0.45, 0.75),
            (lp(marimba(note("C3"), 1.2, 0.3), 900), 0.9, 0.45))
    hum = lp(osc("tri", note("C2"), d), 300) * swell(d, 0.55)
    air = pk(lp(noise(d, r), 600) * swell(d, 0.5), 0.15)
    return reverb(mix((x, 0, 1.0), (pk(hum, 0.22), 0, 1.0), (air, 0, 1.0), seconds=d), 1.5, 0.28)


@recipe("heal_chime", "A27", bus="sfx", peak=-8, note="a house repairs: three rising glass notes")
def heal_chime(r, v):
    x = mix(*[(glass(note(n), 0.8), 0.09 * i, 0.85) for i, n in enumerate(["E6", "G6", "C7"])])
    return reverb(x, 1.0, 0.25)


@recipe("potion_pour", "A29", peak=-12, note="a vial poured: glugs rising in pitch")
def potion_pour(r, v):
    d = 1.1
    t = t_of(d)
    ph = np.cumsum(2 * np.pi * (6.5 + 4 * t / d) / SR_)
    glug = (0.5 + 0.5 * np.sin(ph)) ** 2
    n = sweep_bp(noise(d, r), curve([(0, 380), (d, 950)], d), 3.0)
    return n * glug * swell(d, 0.6) * 2.0


SR_ = S.SR


# ============================================================================== SPELLS AND TOWERS

@recipe("throw_whoosh", "A24", takes=4, bus="ui", peak=-10, vary=0.06, cooldown=0.05, note="a thrown spell leaves the hand: a short airy whoosh")
def throw_whoosh(r, v):
    return whoosh(0.35, 400, 1500, r, 1.1, 0.4)


@recipe("boulder_fall", "A25", peak=-6, spatial=True, note="a long whistle falling: pitch drops as it nears the ground")
def boulder_fall(r, v):
    d = 0.9
    t = t_of(d)
    f = curve([(0, 1700), (d, 360)], d) * (1 + 0.012 * np.sin(2 * np.pi * 6 * t))
    w = osc("sine", f, d) * (0.2 + 0.8 * (t / d) ** 1.4) * 0.5
    air = hp(noise(d, r), 2500) * (t / d) ** 2 * 0.2
    return mix((w, 0, 1.0), (air, 0, 1.0))


@recipe("boulder_hit", "A25", takes=4, peak=-3, spatial=True, cooldown=0.1, note="a boulder lands: a heavy thud, gravel and dust")
def boulder_hit(r, v):
    body = thud(0.8, 85, 34, 0.22, r, 0.8)
    gravel = pk(lp(crackle(0.5, r, 160, 2000), 4000) * exp_env(0.5, 0.2, 0.002))
    dust = pk(hp(lp(noise(0.5, r), 2400), 400) * exp_env(0.5, 0.18, 0.004))
    return reverb(mix((body, 0, 1.0), (gravel, 0.01, 0.6), (dust, 0, 0.4)), 0.5, 0.15)


@recipe("fire_loop", "A26", bus="sfx", peak=-14, rms=-30, loop=True, spatial=True, xfade=0.3, note="loop: a small fire crackling")
def fire_loop(r, v):
    d = 2.3
    cr = crackle(d, r, 55, 2800, 1.0)
    bed = lp(noise(d, r, "brown"), 220) * (0.6 + 0.4 * lp(noise(d, r), 4) / 3) * 0.35
    return cr * 0.8 + bed


@recipe("spell_pick", "A48", bus="ui", peak=-11, note="picking up a spell token: a bright wooden plink")
def spell_pick(r, v):
    return reverb(mix((marimba(note("A5"), 0.3), 0, 0.9), (glass(note("E7"), 0.3, 0.5), 0.02, 0.3)), 0.4, 0.1)


@recipe("storm_cloud", "A48", peak=-7, spatial=True, note="Storm Cloud: a roll of low thunder and raindrops")
def storm_cloud(r, v):
    d = 1.5
    rum = pk(lp(noise(d, r, "brown"), 260) * swell(d, 0.3))
    rain = hp(noise(d, r), 3500) * 0.15 * swell(d, 0.5) + 0.3 * impulses(d, r, 120, 0.003)
    return reverb(mix((rum, 0, 1.0), (rain, 0.1, 0.8)), 0.8, 0.15)


@recipe("rage_cast", "A48", peak=-6, spatial=True, note="Rage: a war drum and a rising swell")
def rage_cast(r, v):
    drum = thud(0.5, 110, 65, 0.15, r, 0.5)
    drum2 = thud(0.5, 120, 70, 0.15, r, 0.5)
    sw = osc("saw", curve([(0, 110), (0.7, 220)], 0.8), 0.8)
    sw = lp(sw, 900) * swell(0.8, 0.8) * 0.4
    return reverb(mix((drum, 0, 1.0), (drum2, 0.16, 0.9), (sw, 0, 0.6)), 0.7, 0.15)


@recipe("root_grow", "A28", peak=-9, spatial=True, note="Root Ward: wood creaks and cracks as roots grow")
def root_grow(r, v):
    d = 0.9
    t = t_of(d)
    cr = sweep_bp(noise(d, r), curve([(0, 250), (d, 700)], d), 2.5) * (0.5 + 0.5 * np.sin(2 * np.pi * 14 * t)) * swell(d, 0.6)
    pops = lp(crackle(d, r, 30, 1200), 2000) * 0.7
    return mix((cr, 0, 1.2), (pops, 0, 0.6))


@recipe("ward_cast", "A28", peak=-8, spatial=True, note="a rune lights: a bell ping and a low hum swelling")
def ward_cast(r, v):
    t = t_of(1.2)
    hum = (osc("sine", 220, 1.2) + 0.7 * osc("sine", 330, 1.2)) * swell(1.2, 0.35) * (0.85 + 0.15 * np.sin(2 * np.pi * 5 * t))
    return reverb(mix((bell(note("A5"), 1.2, 0.7, 0.9), 0, 0.8), (hum, 0, 0.35)), 0.8, 0.18)


@recipe("ward_hum", "A28", bus="sfx", peak=-16, rms=-32, loop=True, spatial=True, xfade=0.25, note="loop: a shield humming softly")
def ward_hum(r, v):
    d = 1.8
    t = t_of(d)
    return (osc("sine", 196, d) + 0.6 * osc("sine", 294, d) + 0.2 * osc("sine", 588, d)) * (0.8 + 0.2 * np.sin(2 * np.pi * 3 * t))


@recipe("forest_rumble", "A30", peak=-9, spatial=True, cooldown=1.0, note="a wave gathers at the tree line: a low rumble with creaking branches")
def forest_rumble(r, v):
    d = 1.9
    rum = pk(lp(noise(d, r, "brown"), 140) * swell(d, 0.45))
    tone = osc("sine", curve([(0, 38), (d, 47)], d), d) * swell(d, 0.5)
    leaves = pk(bp(noise(d, r), 1500, 4000) * swell(d, 0.6)) * 0.12
    creaks = pk(lp(impulses(d, r, 7, 0.02), 900)) * 0.3
    return mix((rum, 0, 0.8), (tone, 0, 0.8), (leaves, 0, 1.0), (creaks, 0, 0.8))


@recipe("orb_charge", "A43", peak=-12, spatial=True, note="the Wizard Tower's orb gathers power: a rising hum and a shimmer")
def orb_charge(r, v):
    d = 0.9
    t = t_of(d)
    hum = lp(osc("saw", curve([(0, 120), (d, 300)], d), d), 800) * swell(d, 0.85)
    shim = osc("sine", curve([(0, 880), (d, 1760)], d), d) * swell(d, 0.9) * 0.15
    cr = crackle(d, r, 20, 3500) * swell(d, 0.9) * 0.4
    return mix((hum, 0, 0.6), (shim, 0, 1.0), (cr, 0, 1.0))


@recipe("crossbow_shot", "A43", takes=4, peak=-7, spatial=True, vary=0.05, note="the Wind Crossbow: a bowstring twang and a pale rush of air")
def crossbow_shot(r, v):
    t = t_of(0.2)
    twang = osc("sine", curve([(0, 330), (0.18, 170)], 0.2), 0.2) * exp_env(0.2, 0.09, 0.0005) \
        + 0.5 * osc("sine", curve([(0, 660), (0.18, 340)], 0.2), 0.2) * exp_env(0.2, 0.05, 0.0005)
    tick = pk(bp(noise(0.015, r), 2000, 5000) * exp_env(0.015, 0.004))
    gust = whoosh(0.35, 1800, 700, r, 0.9, 0.25) * 0.5 + hp(noise(0.35, r), 4000) * swell(0.35, 0.3) * 0.12
    return mix((twang, 0, 0.8), (tick, 0, 0.35), (gust, 0.02, 0.8))


@recipe("crossbow_pierce", "A43", takes=4, peak=-12, spatial=True, vary=0.08, cooldown=0.08, note="the bolt passes through: a thin rising whistle")
def crossbow_pierce(r, v):
    d = 0.28
    w = osc("sine", curve([(0, 1800), (d, 2600)], d), d) * swell(d, 0.4) * 0.25
    return mix((w, 0, 1.0), (whoosh(d, 2000, 1000, r, 1.0, 0.4), 0, 0.4))


@recipe("airship_engine", "A43", bus="sfx", peak=-16, rms=-32, loop=True, spatial=True, xfade=0.3, note="loop: a soft propeller chug")
def airship_engine(r, v):
    d = 2.2
    t = t_of(d)
    blade = (0.55 + 0.45 * np.sin(2 * np.pi * 17 * t)) ** 1.5
    low = lp(osc("saw", 52, d), 260)
    air = lp(noise(d, r), 500) * 0.5
    return soft_clip((low * 0.7 + air) * blade, 1.4)


@recipe("airship_shot", "A43", takes=4, peak=-5, spatial=True, vary=0.05, note="the Airship's cannon: a deep thump and a puff of smoke")
def airship_shot(r, v):
    return mix((thud(0.5, 95, 40, 0.15, r, 0.5), 0, 1.0), (whoosh(0.3, 900, 400, r, 0.9, 0.3), 0, 0.4),
               (crackle(0.25, r, 60, 3000) * exp_env(0.25, 0.1), 0.02, 0.3))


# ============================================================================== FORESIGHT, REWIND, CARDS

@recipe("foresight_whisper", "A36", bus="ui", peak=-10, variants=3, note="the lens: a breathy whisper that gets sharper with each tier (vague, clear, sharp)")
def foresight_whisper(r, v):
    d = 1.2
    n = noise(d, r)
    centres = [(1400, 2400), (1800, 3600), (2200, 5200)][v]
    air = sweep_bp(n, curve([(0, centres[0]), (d, centres[1])], d), 1.4 + v)
    shine = osc("sine", curve([(0, 1200 * (1 + v * 0.5)), (d, 2400 * (1 + v * 0.5))], d), d) * (0.06 + 0.07 * v)
    return reverb((air * 2.2 + shine) * swell(d, 0.55), 0.9, 0.2)


@recipe("rewind_whoosh", "A37", duck=True, peak=-4, note="time runs backwards: a reversed bell chord sucking in, a rising sweep and ticking")
def rewind_whoosh(r, v):
    chord = mix(*[(bell(note(n), 2.0, 0.8, 1.0), 0.05 * i, 0.5) for i, n in enumerate(["C4", "G4", "C5", "E5"])],
                (glass(note("C6"), 1.5), 0.15, 0.3))
    chord = reverb(chord, 1.5, 0.35)
    backwards = chord[::-1].copy()
    backwards = backwards * np.linspace(0.5, 1.0, len(backwards)) ** 1.5
    sweep = whoosh(2.2, 220, 5200, r, 0.9, 0.85) * 0.6
    ticks = np.zeros(n_of(2.2))
    at = 0.0
    gap = 0.22
    while at < 2.0:
        i = n_of(at)
        k = n_of(0.01)
        ticks[i:i + k] += (bp(noise(0.01, r), 1800, 4500) * exp_env(0.01, 0.003))[: len(ticks[i:i + k])] * (0.3 + 0.7 * at / 2.0)
        at += gap
        gap = max(gap * 0.88, 0.04)
    end = glass(note("C7"), 0.6, 0.7)
    return mix((backwards, 0, 0.8), (sweep, 0, 0.8), (ticks, 0, 0.6), (end, 2.05, 0.35))


@recipe("rarity_common", "A47", bus="ui", peak=-10, note="a Common card: one glass note")
def rarity_common(r, v):
    return reverb(glass(note("C6"), 0.8, 0.8), 0.6, 0.15)


@recipe("rarity_rare", "A47", duck=True, bus="ui", peak=-8, note="a Rare card: a note, a fifth above, and a shimmer")
def rarity_rare(r, v):
    x = mix((glass(note("E6"), 1.0), 0, 0.9), (glass(note("B6"), 1.1), 0.1, 0.8),
            (hp(noise(0.5, r), 6000) * swell(0.5, 0.3), 0.1, 0.08))
    return reverb(x, 1.0, 0.22)


@recipe("rarity_legendary", "A47", duck=True, bus="ui", peak=-5, note="a Legendary card: a rising arpeggio, a sub boom and a long shimmer")
def rarity_legendary(r, v):
    arp = mix(*[(glass(note(n), 1.4), 0.08 * i, 0.7) for i, n in enumerate(["C5", "E5", "G5", "C6", "E6", "G6"])])
    boom = thud(1.0, 80, 36, 0.3, r, 0.2)
    shim = whoosh(1.4, 1500, 7000, r, 1.0, 0.6) * 0.3
    bl = bell(note("C5"), 2.0, 0.8, 1.4)
    return reverb(mix((arp, 0.1, 1.0), (boom, 0.5, 0.8), (shim, 0.4, 0.5), (bl, 0.55, 0.5)), 1.6, 0.28)


# ============================================================================== AMBIENCE (loops, stereo)

def _slow(r, seconds, rate, lo=0.0, hi=1.0):
    """A smooth random curve between lo and hi that wanders about `rate` times a second."""
    x = lp(noise(seconds, r), rate, 1)
    x = (x - x.min()) / (np.ptp(x) + 1e-9)
    return lo + (hi - lo) * x


@recipe("day_bed", "A39", bus="ambience", peak=-12, rms=-30, loop=True, xfade=0.6, note="loop: soft wind, rustling leaves and the odd bird")
def day_bed(r, v):
    d = 12.6  # 12 s after the loop crossfade
    wind = lp(noise(d, r, "pink"), 600) * _slow(r, d, 0.25, 0.3, 1.0)
    leaves = lp(bp(noise(d, r), 1800, 5200), 6000) * 0.09 * _slow(r, d, 0.5, 0.0, 1.0) ** 2
    bed = stereo_wide(wind * 0.8 + leaves, 0.6)
    layers = [bed]
    # a far wind chime: a few pentatonic glass notes, very quiet, twice per loop
    for at_c in (2.2, 8.1):
        tones = [note(n) for n in ("D6", "E6", "G6", "A6", "B6")]
        ring = []
        t0 = 0.0
        for k in range(int(r.integers(2, 4))):
            ring.append((glass(tones[int(r.integers(0, len(tones)))], 1.6, 1.6), t0, 1.0))
            t0 += float(r.uniform(0.18, 0.4))
        layers.append((pan(mix(*ring) * 0.035, float(r.uniform(-0.6, 0.6))), at_c, 1.0))
    at = 0.8
    while at < d - 1.6:
        f0 = float(r.uniform(2400, 4200))
        notes = []
        t0 = 0.0
        for k in range(int(r.integers(2, 5))):
            c = chirp(f0 * float(r.uniform(0.9, 1.15)), f0 * float(r.uniform(1.15, 1.5)), 0.07, 0.01, 40)
            notes.append((c, t0, 1.0))
            t0 += 0.11
        bird = lp(mix(*notes), 6000) * 0.05
        layers.append((pan(bird, float(r.uniform(-0.8, 0.8))), at, 1.0))
        at += float(r.uniform(2.0, 5.0))
    return reverb(mix(*layers, seconds=d), 0.8, 0.1)[: n_of(d)]


@recipe("night_bed", "A40", bus="ambience", peak=-12, rms=-31, loop=True, xfade=0.6, note="loop: crickets, a low breeze and a far owl")
def night_bed(r, v):
    d = 14.6  # 14 s after the loop crossfade
    wind = lp(noise(d, r, "pink"), 350) * _slow(r, d, 0.2, 0.2, 1.0)
    layers = [stereo_wide(wind * 0.6, 0.5)]
    for k, (f, rate, p) in enumerate([(4300, 14.0, -0.6), (4900, 17.0, 0.5), (3900, 11.0, 0.1)]):
        t = t_of(d)
        gate = (np.sin(2 * np.pi * rate * t) > 0.2).astype(float)
        group = (np.sin(2 * np.pi * (0.55 + 0.1 * k) * t + k) > 0.1).astype(float)
        g = lp(gate * group, 300, 1)
        cr = osc("sine", f, d) * g * 0.05
        layers.append(pan(cr, p))
    at = float(r.uniform(2.0, 5.0))
    hoot = mix((osc("sine", curve([(0, 430), (0.35, 380)], 0.4), 0.4) * swell(0.4, 0.3), 0, 1.0),
               (osc("sine", curve([(0, 430), (0.35, 370)], 0.4), 0.4) * swell(0.4, 0.3), 0.55, 0.9)) * 0.06
    layers.append((pan(lp(hoot, 900), 0.7), at, 1.0))
    # the tension: a low hum (C and a soft minor third) that breathes slowly, never loud
    t = t_of(d)
    breathe = 0.6 + 0.4 * np.sin(2 * np.pi * t / d * 2 - 1.2)  # two slow breaths per loop, so it loops cleanly
    hum = (osc("sine", note("C2"), d) + 0.5 * osc("sine", note("Eb2"), d) + 0.25 * osc("tri", note("G2"), d)) * breathe
    layers.append(stereo_wide(lp(hum, 260) * 0.035, 0.3))
    # a branch creaks somewhere in the forest, once per loop
    cr_at = float(r.uniform(6.0, 10.0))
    creak = sweep_bp(noise(0.7, r), curve([(0, 240), (0.7, 420)], 0.7), 3.0) * (0.5 + 0.5 * np.sin(2 * np.pi * 16 * t_of(0.7))) * swell(0.7, 0.5)
    layers.append((pan(lp(pk(creak), 1200) * 0.05, float(r.uniform(-0.8, 0.8))), cr_at, 1.0))
    return reverb(mix(*layers, seconds=d), 1.0, 0.15)[: n_of(d)]


@recipe("rain_loop", "A41", bus="ambience", peak=-12, rms=-30, loop=True, xfade=0.5, note="loop: steady rain (Gentle Rain)")
def rain_loop(r, v):
    d = 8.0
    base = hp(lp(noise(d, r), 9000), 1200) * 0.5
    drops = bp(impulses(d, r, 500, 0.002), 2500, 8000) * 0.8
    low = lp(noise(d, r, "pink"), 400) * 0.15
    return stereo_wide(base + drops + low, 0.8)


@recipe("fog_loop", "A41", bus="ambience", peak=-14, rms=-34, loop=True, xfade=0.6, note="loop: a muffled hush with a faint low tone (Foggy Night)")
def fog_loop(r, v):
    d = 10.0
    hush = lp(noise(d, r, "pink"), 450) * _slow(r, d, 0.2, 0.4, 1.0)
    tone = osc("sine", 110, d) * 0.05 * _slow(r, d, 0.15, 0.3, 1.0)
    return stereo_wide(hush + tone, 0.7)


# ============================================================================== BUILD


def render(name, spec, v, take=0):
    seed = zlib.crc32(("%s:%d" % (name, v)).encode()) if take == 0 else zlib.crc32(("%s:%d:t%d" % (name, v, take)).encode())
    r = rng(seed)
    x = np.asarray(spec["fn"](r, v), dtype=float)
    if take > 0:
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
    else:
        x = normalise(x, peak_db=spec["peak"])
    return x


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    godot = "--godot" in sys.argv
    names = args or list(RECIPES)
    os.makedirs(OUT, exist_ok=True)
    manifest_path = os.path.join(OUT, "manifest.json")
    manifest = {}
    if os.path.exists(manifest_path):
        manifest = json.load(open(manifest_path, encoding="utf-8"))
    for name in names:
        spec = RECIPES[name]
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
                              cooldown=spec["cooldown"], vary=spec["vary"], files=files, note=spec["note"],
                              duck=spec["duck"])
        f = files[0]
        print("%-18s %-4s %-8s %5.2fs peak %5.1f rms %5.1f%s" % (name, spec["tid"], spec["bus"], f["seconds"], f["peak_db"], f["rms_db"],
                                                                  "  seam %.2f" % f["seam"] if f["seam"] is not None else ""))
    json.dump(manifest, open(manifest_path, "w", encoding="utf-8"), indent=1, sort_keys=True)
    if godot:
        import shutil
        os.makedirs(GODOT_OUT, exist_ok=True)
        for fn in os.listdir(OUT):
            if fn.endswith((".wav", ".json")):
                shutil.copy2(os.path.join(OUT, fn), os.path.join(GODOT_OUT, fn))
        print("copied to", GODOT_OUT)


if __name__ == "__main__":
    main()
