class_name GameConfig
extends RefCounted
## Every gameplay number for the first playable slice, in one place. Sources: docs/GAME_SPEC.md and the
## decisions of 2026-10-22 in art/decisions.md. Distances and speeds are in CELLS (1 cell = 0.05 m).

const CELL := 0.05
const SIZE := 24  # 2026-10-22 (Siddharth): board 24 x 24 cells = 1.2 m (was 12 x 12)

# Economy (spec 5)
const START_TRUST := 100
const DAWN_TRUST_PER_HOUSE := 5
const NIGHT_CLEAR_TRUST := 0  # spec: paid on top of dawn income, amount still OPEN (Siddharth decides); 0 until then

# Houses (decided 2026-10-22: 60 HP). A night is lost at 3 or more shuttered houses (spec 2).
const HOUSE_HP := 60.0
const HOUSES_LOST_AT := 3
# Six 2x2 houses spread in a loose ring (radius about 5.5 cells) round an open centre, so towers fit
# between them as well as out by the forest (Siddharth 2026-10-22). Top-left cells. Fixed for the slice;
# procedural later.
const HOUSE_CELLS: Array[Vector2i] = [Vector2i(11, 5), Vector2i(16, 8), Vector2i(16, 14), Vector2i(11, 16), Vector2i(6, 14), Vector2i(6, 8)]
const HOUSE_SCENES: Array[String] = [
	"res://assets/village/ew_village_cottage_v05.glb",
	"res://assets/village/ew_village_cabin_v05.glb",
	"res://assets/village/ew_village_townhouse_v05.glb",
]

# Forest spawn points (decided 2026-10-22: north, east, west; the south edge faces the player).
# Each is the pair of edge cells left open in the forest ring.
const SPAWNS := {
	"north": [Vector2i(11, 0), Vector2i(12, 0)],
	"east": [Vector2i(23, 11), Vector2i(23, 12)],
	"west": [Vector2i(0, 11), Vector2i(0, 12)],
}

# Grunt (spec 9 + 2026-10-22: 2 damage per second in melee; cannot damage towers in this slice)
const GRUNT_HP := 20.0
const GRUNT_SPEED := 0.4  # cells per second
const GRUNT_DPS := 2.0
const GRUNT_THREAT := 1

# Waves (spec 6a + 2026-10-22): threat budget per night, 3 groups (one per spawn), a new group every 12 s
const NIGHT_BUDGETS: Array[int] = [6, 9, 12, 16, 20]
const GROUP_INTERVAL := 12.0
const FIRST_GROUP_DELAY := 3.0
const IN_GROUP_GAP := 1.0  # seconds between enemies of one group, so they do not stack (slice choice)

# Towers (spec 7). The Airship attacks air only and there are no flyers in this slice, so it is left out.
const TOWERS := {
	"fire": {
		"name": "Fire Tower", "cost": 60, "range": 5.0, "damage": 14.0, "interval": 1.5, "kind": "single",
		"scene": "res://assets/defense/ew_defense_fire_tower_v07.glb", "turn_part": "head",
		"shot": "res://assets/defense/ew_defense_fireball_v01.glb", "shot_speed": 12.0,
	},
	"brazier": {
		"name": "Blast Brazier", "cost": 50, "range": 2.0, "damage": 4.0, "interval": 1.0, "kind": "splash",
		"splash": 1.0, "scene": "res://assets/defense/ew_defense_bomb_tower_v06.glb", "turn_part": "head",
		"shot": "res://assets/defense/ew_defense_cannonball_v01.glb", "shot_speed": 6.0,
	},
	"crossbow": {
		"name": "Longbow Tower", "cost": 55, "range": 6.0, "damage": 4.0, "interval": 1.2, "kind": "pierce",
		"pierce_width": 0.5, "scene": "res://assets/defense/ew_defense_crossbow_tower_v03.glb", "turn_part": "swivel",
		"shot": "res://assets/defense/ew_defense_wind_bolt_v01.glb", "shot_speed": 20.0,
	},
}
const TOWER_ORDER: Array[String] = ["fire", "brazier", "crossbow"]
const TOWER_SIZE := Vector2i(2, 2)
