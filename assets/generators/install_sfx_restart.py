"""Install the approved SFX-restart sounds into the game (Siddharth 2026-11-10: "add the sounds to the game so I can see if it
all works together").

    python -I assets/generators/install_sfx_restart.py

Renders every approved restart sound as game files (several takes with a small pitch/length change so repeats are not
robotic), writes them to godot/assets/audio/ and assets/export/audio/, and edits manifest.json in both. Levels = the replaced
sound's old mix level, so the balance is unchanged (spells a little louder than the towers). Candidates and their recipes live
in make_sfx_restart.py; this file only splits the approved packages into game sounds (launch / hit ...) and writes them.

make_audio.py regenerates manifest.json from its own (old) recipes: re-run this file after running it.
"""
import json
import os
import sys
import zlib

import numpy as np
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_sfx_restart as M  # noqa: E402

S = M.S
ROOT = M.ROOT
GODOT_OUT = os.path.join(ROOT, "godot", "assets", "audio")
EXPORT_OUT = os.path.join(ROOT, "assets", "export", "audio")
TAKE_PITCH = [1.0, 0.955, 1.045, 0.925, 1.075, 0.97, 1.03, 0.94]


def room(x, size=0.2, wet=0.07):  # a small room, then mono: 3D sounds are placed in the world by the game
    y = S.room(x, size, wet)
    return y.mean(axis=1) if y.ndim == 2 else y


def fire_orb_parts(r):
    """The two halves of the approved real-recording Fire Orb (round 12): (launch layers, hit layers)."""
    sw = S.curve([(0, 0.05), (0.35, 1.0), (0.9, 0.05)], 0.9, log=False)
    launch = [(S.pk(M._pick("fire_whoosh", "fire_whoosh_01.wav", 1.15, 0.9)) * sw, 0.0, 1.0),
              (S.pk(M._pick("fire_whoosh", "fire_whoosh_05.wav", 1.35, 0.9)) * sw, 0.05, 0.6),
              (S.pk(M._pick("bed_fire", "bed_fire_02.wav", 1.0, 0.9, 8000)) * sw, 0.0, 0.45)]
    hit = [(M._pick("cannon", "cannon_01.wav", 0.9, 0.5, 2500), 0.0, 1.3),
           (S.pk(M._pick("fire_whoosh", "fire_whoosh_02.wav", 1.5, 0.5)) * S.exp_env(0.5, 0.16, 0.003), 0.0, 1.0),
           (M._pick("fire_whoosh", "fire_whoosh_04.wav", 0.8, 0.2), 0.0, 0.8),
           (S.pk(M._pick("bed_fire", "bed_fire_02.wav", 1.0, 0.5, 8000)) * S.exp_env(0.5, 0.2, 0.003), 0.0, 0.4),
           (M._pick("crackle", "crackle_05.wav", 1.0, 0.3, 4500, 200), 0.12, 0.25),
           (M._pick("crackle", "crackle_18.wav", 1.0, 0.3, 4500, 200), 0.25, 0.2)]

    def lifted(layers):  # the approved version lifts the upper mids of the whole mix (real fire whooshes are dark)
        x = S.mix(*layers)
        return S.lp(x + 1.3 * S.hp(x, 1500), 9000)
    return lifted(launch), lifted(hit)


def bad_bop(r):
    wood = S.modal(340, 0.16, "wood", r, hardness=0.2, nmodes=4)
    low = S.thud(0.2, 220, 140, 0.06, r, grit=0.0)
    puff = S.lp(S.noise(0.1, r, "white"), 3500) * S.exp_env(0.1, 0.03, 0.002)
    return room(S.mix((wood, 0, 0.9), (low, 0, 0.5), (S.pk(puff), 0, 0.9)), 0.15, 0.04)


def plink(r, pair):
    a = M.MA.tuned("C5", r, ("wood_notes",), seconds=0.6)
    lo = S.marimba(261.6, 0.5, hard=0.1)
    if pair:
        b = M.MA.tuned("G5", r, ("wood_notes",), seconds=0.65)
        lo2 = S.marimba(392.0, 0.55, hard=0.1)
        x = S.mix((a, 0, 0.7), (b, 0.1, 0.9), (lo, 0, 0.5), (lo2, 0.1, 0.5))
    else:
        x = S.mix((a, 0, 0.7), (lo, 0, 0.5))
    return room(x, 0.15, 0.06)


def boulder_fall(r):
    fall = S.sweep_bp(S.noise(0.45, r, "white"), S.curve([(0, 2200), (0.45, 700)], 0.45), 1.0) \
        * S.curve([(0, 0.0), (0.42, 1.0), (0.45, 0.0)], 0.45, log=False)
    return room(S.pk(fall) * 0.5, 0.25, 0.08)


def boulder_hit(r):
    parts = [(M._g("stone", r, 0.62, lpf=5000), 0.0, 1.0), (M._g("stone", r, 0.75, lpf=5000), 0.015, 0.8),
             (M._g("cannon", r, 0.9, seconds=0.5, lpf=2500), 0.0, 1.2),
             (M._g("thunder", r, 1.0, seconds=1.2, lpf=1200), 0.02, 0.45),
             (M._g("dirt", r, 1.0, seconds=0.5, lpf=3500, hpf=300), 0.03, 0.5)]
    return room(S.mix(*parts), 0.25, 0.08)


def storm_cloud(r):
    secs = 2.6
    env = S.curve([(0, 0.05), (1.0, 1.0), (2.0, 0.8), (secs, 0.03)], secs, log=False)
    a = S.pk(M._g("thunder", r, 1.0, seconds=secs, lpf=2000, hpf=150)) * env
    b = S.pk(M._g("thunder", r, 1.35, seconds=secs, lpf=2600, hpf=200)) * env * 0.7
    return room(S.mix((a, 0, 1.0), (b, 0.15, 0.8)), 0.25, 0.08)


def place_knock(r):
    return room(S.mix((S.modal(220, 0.3, "wood", r, hardness=0.1, nmodes=4), 0, 0.8),
                      (S.thud(0.25, 190, 110, 0.07, r, grit=0.15), 0, 0.9)), 0.18, 0.12)


# id: (render fn(r), takes, target rms dB or None = silent, manifest entry to copy bus/spatial/cooldown/vary from, tracker, note)
INSTALL = {
    "wizard_launch": (lambda r: room(M.wiz4_launch(5500, 0.35, 0.6, 7500)(r)), 6, -18.3, "fireball_launch", "A15", "Wizard Tower shot: whoosh and flame rush (restart r4 wiz_a)"),
    "wizard_hit": (lambda r: room(M.wiz4_hit(7500, 0.4, 0.5)(r)), 8, -20.5, "fireball_hit", "A15", "Wizard Tower fireball lands: soft fwoomf burst (restart r4 wiz_a)"),
    "orb_launch": (lambda r: room(fire_orb_parts(r)[0], 0.25, 0.08), 4, -17.5, "fireball_launch", "A20", "Fire Orb spell launch: real fire whooshes (restart r12)"),
    "orb_hit": (lambda r: room(fire_orb_parts(r)[1], 0.25, 0.08), 4, -18.5, "fireball_hit", "A20", "Fire Orb spell burst: real cannon thump and fire (restart r12)"),
    "crossbow_shot": (lambda r: room(M.xbow_shot(480, 1.1, 6000, 0.9, 0.35, 9000, 0.45, 4200)(r)), 6, -22.4, "crossbow_shot", "A16", "Longbow Tower shot: tight crossbow thunk with a wood click (restart r7)"),
    "crossbow_pierce": (lambda r: room(M.xbow_thup(r)), 6, -24.7, "crossbow_pierce", "A16", "bolt pierces an enemy: one soft thup (restart r7)"),
    "guard_clop": (lambda r: room(M.guard_clop(r)), 4, -24.0, "hit_soft", "A16", "a Guard steps out: soft wood and cloth clop (restart r5)"),
    "guard_hit": (lambda r: room(M.guard_hit(r)), 6, -25.7, "hit_soft", "A16", "a Guard hits an enemy: dull light thud (restart r5)"),
    "airship_shot": (lambda r: room(M.cannon_shot(r)), 4, -18.3, "airship_shot", "A16", "Airship cannon shot: round thoomp (restart r5)"),
    "airship_hit": (lambda r: room(M.cannon_hit(r)), 6, -20.5, "fireball_hit", "A16", "Airship cannonball lands: heavy soft thump (restart r5)"),
    "boulder_fall": (boulder_fall, 3, -24.6, "throw_whoosh", "A20", "Boulder released: a short falling whoosh (restart r9)"),
    "boulder_hit": (boulder_hit, 4, -20.0, "boulder_hit", "A20", "Boulder lands: heavy stone thud, dust and rumble (restart r9)"),
    "storm_cloud": (storm_cloud, 2, -22.0, "storm_cloud", "A20", "Storm Cloud cast: a dark rolling thunder swell (restart r11)"),
    "storm_crack": (lambda r: room(M._g("thunder", r, 1.5, seconds=0.3, lpf=2500, hpf=140), 0.25, 0.08), 4, -20.0, "boulder_hit", "A20", "a Storm Cloud strike hits an enemy: a short low thunder crack (restart r11)"),
    "rage_cast": (lambda r: room(M.rage9(r), 0.25, 0.08), 2, -19.9, "rage_cast", "A20", "Rage: a swelling heartbeat from a real drum (restart r9)"),
    "ward_cast": (lambda r: room(M.root11(1.0, 0.35, 0.15)(r), 0.25, 0.08), 2, -21.3, "ward_cast", "A20", "Root Ward: roots and branches sliding, leaf rustle (restart r11 root_a)"),
    "place_thunk": (place_knock, 6, -19.9, "place_thunk", "A10", "a tower is placed: hollow wooden box knock (restart r1 tap_b)"),
    "pinch": (lambda r: room(M._pick("cards", "cards_04.wav", 1.2, 0.13, 5000, 200), 0.15, 0.03), 4, -26.3, "pinch", "A08", "hand pinch: a soft paper flip (restart r13)"),
    "invalid": (bad_bop, 2, -22.0, "invalid", "A11", "not allowed: a soft low wooden bop (restart r13)"),
    "trust_chime": (lambda r: plink(r, True), 2, -22.3, "trust_chime", "A14", "reward: wooden marimba plink C5 G5 (restart r13)"),
    "help_done": (lambda r: plink(r, False), 2, -24.0, "help_done", "A14", "help done: the first plink note only; plays together with trust_chime (arrangement, restart r13)"),
    "enemy_death": (lambda r: np.zeros(S.n_of(0.05)), 1, None, "enemy_death", "A17", "SILENT on purpose: he asked for silent or minimal enemy deaths (2026-11-10)"),
    "build_pop": (lambda r: np.zeros(S.n_of(0.05)), 1, None, "build_pop", "A12", "SILENT on purpose: the approved placing sound is the wooden knock alone (2026-11-10)"),
}
KEEP_PITCH = {"trust_chime", "help_done"}  # notes in the key: a take's resample would put them off key


def _db(v):
    return float(20 * np.log10(v + 1e-12))


def install():
    man_path = os.path.join(GODOT_OUT, "manifest.json")
    man = json.load(open(man_path, encoding="utf-8"))
    for name, (fn, takes, rms, meta_from, tracker, note) in INSTALL.items():
        meta = dict(man[meta_from])
        files = []
        for k in range(takes):
            seed = zlib.crc32(("restart:%s:%d" % (name, k)).encode())
            r = S.rng(seed)
            np.random.seed(seed % (2 ** 31))
            x = np.asarray(fn(r), dtype=float)
            if rms is not None:
                if k > 0 and name not in KEEP_PITCH:
                    kk = TAKE_PITCH[k % len(TAKE_PITCH)]
                    x = np.interp(np.linspace(0, len(x) - 1, max(16, int(len(x) / kk))), np.arange(len(x)), x)
                x = S.fade(S.trim_silence(S.remove_dc(x), -55.0, 0.02), 0.0015, 0.05)
                x = S.normalise(x, rms_db=rms, max_peak_db=-2.0)
            fname = "%s_%d.wav" % (name, k + 1) if takes > 1 else "%s.wav" % name
            for d in (GODOT_OUT, EXPORT_OUT):
                sf.write(os.path.join(d, fname), x, 44100, subtype="PCM_16")
            files.append({"file": fname, "peak_db": round(_db(float(np.max(np.abs(x)))), 1),
                          "rms_db": round(_db(float(np.sqrt(np.mean(x ** 2)))), 1), "seam": None, "seconds": round(len(x) / 44100, 3)})
        meta.update({"files": files, "note": note, "tracker": tracker})
        if name == "storm_crack":
            meta["cooldown"] = 0.0  # a whole chain is struck in one call: every enemy struck gets its crack
        man[name] = meta
        print("installed %-16s %d take(s), rms %s" % (name, takes, "silent" if rms is None else rms))
    for d in (GODOT_OUT, EXPORT_OUT):
        json.dump(man, open(os.path.join(d, "manifest.json"), "w", encoding="utf-8"), indent=1, sort_keys=True)
    print("manifest updated in godot/assets/audio and assets/export/audio")


if __name__ == "__main__":
    install()
