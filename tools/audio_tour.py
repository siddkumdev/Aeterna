"""Old-vs-new listening tours, one file per group, for judging a whole sound round on a phone. In each file every sound
plays its OLD version (first take), a short pause, then its NEW version (first take), then a longer pause before the
next sound. Loops: 5 s of each. Loudness-matched per pair. A text file lists the order with timestamps.

    python tools/audio_tour.py <old_dir> <out_dir> [new_dir]   # new defaults to assets/export/audio
"""
import json
import os
import sys

import numpy as np
from scipy.io import wavfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from audio_synth import fade, n_of, write_wav  # noqa: E402

NEW = os.path.join(ROOT, "assets", "export", "audio")
GROUPS = [
    ("1_hands_menus", ["pinch", "grab", "release", "menu_open", "menu_close", "ui_hover", "ui_cancel", "cooldown_ready", "invalid", "spell_pick", "throw_whoosh"]),
    ("2_building_coins_cards", ["place_thunk", "build_pop", "sell", "coin_flick", "coin_good", "coin_neutral", "coin_bad", "rarity_common", "rarity_rare", "rarity_legendary"]),
    ("3_towers_combat", ["fireball_launch", "fireball_hit", "orb_charge", "crossbow_shot", "crossbow_pierce", "airship_shot", "airship_engine", "hit_soft", "melee_hit", "gate_open"]),
    ("4_enemies", ["enemy_spawn", "enemy_death", "wisp_wings", "wisp_screech", "tunneler_pop", "splitter_split", "forest_rumble", "boss_roar", "boss_phase"]),
    ("5_village", ["house_hit", "shutter_close", "door_close", "trust_chime", "help_done", "request_new", "villager_blip", "village_bell", "dawn_bell", "night_fall", "heal_chime"]),
    ("6_spells", ["potion_pour", "boulder_fall", "boulder_hit", "fire_loop", "storm_cloud", "rage_cast", "root_grow", "ward_cast", "ward_hum", "foresight_whisper", "rewind_whoosh"]),
    ("7_voices", ["bark_wizard_ready", "bark_wizard_cheer", "bark_archer_ready", "bark_archer_cheer", "bark_pilot_ready", "bark_pilot_cheer", "bark_guard_ready", "bark_guard_cheer"]),
    ("8_ambience", ["day_bed", "night_bed", "rain_loop", "fog_loop", "amb_bird", "amb_leaves", "amb_work", "amb_owl", "amb_creak", "amb_rustle"]),
]


def first(folder, name, man):
    m = man[name]
    fn = m["files"][0]["file"]
    path = os.path.join(folder, fn)
    if not os.path.exists(path):
        return None
    x = wavfile.read(path)[1].astype(float) / 32768.0
    x = x.mean(axis=1) if x.ndim == 2 else x
    if m["loop"]:
        x = fade(np.tile(x, int(np.ceil(n_of(5.0) / len(x))) + 1)[: n_of(5.0)].copy(), 0.2, 0.4)
    return x


def rms(x):
    return float(np.sqrt(np.mean(x ** 2))) + 1e-12


def main():
    old_dir, out_dir = sys.argv[1], sys.argv[2]
    new_dir = sys.argv[3] if len(sys.argv) > 3 else NEW
    man = json.load(open(os.path.join(NEW, "manifest.json"), encoding="utf-8"))
    os.makedirs(out_dir, exist_ok=True)
    lines = []
    for tag, names in GROUPS:
        parts, t = [], 0.0
        lines.append("%s.wav" % tag)
        for name in names:
            if name not in man:
                continue
            a, b = first(old_dir, name, man), first(new_dir, name, man)
            if b is None:
                continue
            target = 10 ** (-24 / 20)
            seg = []
            if a is not None:
                seg += [a * target / rms(a), np.zeros(n_of(0.7))]
            seg += [b * target / rms(b), np.zeros(n_of(1.6))]
            x = np.concatenate(seg)
            lines.append("  %5.1fs  %s%s" % (t, name, "" if a is not None else " (new only)"))
            parts.append(x)
            t += len(x) / 44100
        x = np.concatenate(parts)
        x = x * min(1.0, 10 ** (-1 / 20) / (np.max(np.abs(x)) + 1e-12))
        write_wav(os.path.join(out_dir, tag + ".wav"), x)
    open(os.path.join(out_dir, "ORDER.txt"), "w", encoding="utf-8").write(
        "Each sound: OLD, short pause, NEW, longer pause.\n" + "\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
