---
name: character-kit
description: How Aeterna's characters and enemies get into the game and move - parts in the generators, export, the CharacterRig animations, adding a job or an enemy animation, and the pose sheets to check them. Use when adding or changing a villager, crew member, Guard or enemy, or their animation.
---

# character-kit

Durva owns the character designs; do not change a look without her. No skinned rigs: every moving part is a separate mesh turned about its pivot in Godot.

## Models
- Generators: `assets/generators/make_characters.py` (people, shared body kit in `build()`, one dict per character in `CHARACTERS`), `make_enemies2.py` (enemies).
- Parts the animation reads: `head`, `arm_l`, `arm_r`, `leg_l`, `leg_r`, `item` (child of `arm_r`), `hair_back`, `ear_*`, `ant_*`, `wing_*`, `tail`, `spider`, `web`, `hat`; enemies also `rings`, `veil`, `spores`, `drill`, `jaw_*`. A missing part is skipped. Character's right is -X, front is -Y in Blender, +Z in Godot.
- Export everything or one: `blender --factory-startup -b -P tools/export_characters.py [-- <key>]`, then `python tools/sync_to_godot.py <glb...>`. Validate with `python tools/validate_asset.py`. When splitting parts, prove nothing changed: same triangle count, pixel-diff of the sheets.

## Animation (`godot/scripts/game/character_rig.gd`)
- Owners set `anim` and `gait` (cells per second); `hit()`, `rise()`, `sink()`, `die()`, `set_misty()` are one-shots. Add a pose as a new `anim` branch in `_person()` or a `family` branch in `_creature()`. Rotation.x < 0 swings an arm or leg forward; rotation.z > 0 lifts `arm_l` outward, < 0 lifts `arm_r`.
- It is cosmetic: never read it from a rule. Models only load with `game.with_rig`, so logic-only tests keep the stand-ins.
- `CharacterRig.step_legs` chooses hopping or stepping (G in the game), until the team decides.

## Who uses it
- `village_life.gd` `CAST` (who, job, home house), `_job_anim`, `_job_mark`; `villager.gd` (walking, the night sprint, the doors).
- `enemy.gd` `MODELS`, `crew_member.gd` `MODELS` and `MODEL_SCALE`.

## Check
`"<godot console>" --xr-mode off --resolution 1200x700 --path godot -s res://tools/village_shot.gd -- <prefix>` writes day, close, night, nightfall strip, poses, enemies and walks sheets. Look at them, run code-critic and player-critic. Tests: `_village_life` in `godot/tests/game_selftest.gd`.
