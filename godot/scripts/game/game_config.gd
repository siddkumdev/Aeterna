class_name GameConfig
extends RefCounted
## Every gameplay number for the first playable slice, in one place. Sources: docs/GAME_SPEC.md and the
## decisions of 2026-10-22 in art/decisions.md. Distances and speeds are in CELLS (1 cell = 0.05 m).

const CELL := 0.05
const SIZE := 24  # 2026-10-22 (Siddharth): board 24 x 24 cells = 1.2 m (was 12 x 12)

# Economy (spec 5)
const START_TRUST := 200  # 2026-10-22 (Siddharth): 100 was too low; 200 = three towers before night 1
const DAWN_TRUST_PER_HOUSE := 5
# Clearing a night pays 10 x the night number on top of dawn income (Siddharth 2026-10-22): night 1 = 10 ... boss night = 60
const NIGHT_CLEAR_TRUST_PER_NIGHT := 10

# Time loop (spec 6 + 15). A loop = 5 nights + the boss night; a run = loop 1 + loop 2, then it ends.
const NIGHTS_PER_LOOP := 6
const BOSS_NIGHT := 5  # 0-based: the 6th night
const LOOPS_PER_RUN := 5  # 2026-10-22 (Siddharth): 5 loops for M1
# Each loop after the first (spec 16 for loop 2: +40% enemy HP and one extra group per night; Claude's stand-in
# for loops 3-5: the same step again each loop). Loop n (0-based) = HP x(1 + 0.4 n), n extra groups per night.
const LOOP_HP_STEP := 0.4
const EXTRA_GROUPS_PER_LOOP := 1

# Foresight (spec 13): the Crystal Lens shows the coming night during the day. 3 tiers spread over the 5 loops
# (Siddharth 2026-10-23: loops 1-2 / 3-4 / 5). 1 blurry silhouettes + the direction of each group; 2 adds type
# icons + counts + when each group leaves; 3 adds path ribbons (and where Tunnelers come up) and the rewrite
# (close one spawn for the night: its groups come from the next open edge instead). The Fog variant never shows.
const FORESIGHT_TIERS := 3
const FORESIGHT_TIER_BY_LOOP: Array[int] = [1, 1, 2, 2, 3]
const FORESIGHT_COLOUR := Color("3FB7D9")  # palette crystal_blue: blue is Foresight only
const LENS_SCENE := "res://assets/foresight/ew_foresight_crystal_lens_v01.glb"
const LENS_GRAB_REACH := 0.09  # m from the hand to the lens's grip for a grab
const LENS_RAISE := 0.15  # m above the table: the lens counts as held up to the eye
const LENS_GAZE_DEG := 20.0  # a group is seen when its gap is within this angle of where the head looks (gaps are ~32 deg apart from the seat)
# Systems that exist in the build; cards for anything else are not offered (Cards.available)
const BUILT_SYSTEMS: Array[String] = ["airship"]

# Houses (decided 2026-10-22: 60 HP). A night is lost at 3 or more shuttered houses (spec 2).
const HOUSE_HP := 60.0
const HOUSES_LOST_AT := 3
# Six 2x2 houses in a tight ring (radius about 3.5 cells; Siddharth 2026-10-22: 5.5 felt too far apart)
# round a small open centre that still fits one tower; 1 to 2 cells between neighbours. Top-left cells.
# Fixed for the slice; procedural later.
const HOUSE_CELLS: Array[Vector2i] = [Vector2i(11, 7), Vector2i(14, 9), Vector2i(14, 13), Vector2i(11, 15), Vector2i(8, 13), Vector2i(8, 9)]
const HOUSE_SCENES: Array[String] = [
	"res://assets/village/ew_village_cottage_v05.glb",
	"res://assets/village/ew_village_cabin_v05.glb",
	"res://assets/village/ew_village_townhouse_v05.glb",
]

# Forest spawn points (decided 2026-10-22: north, east, west; the south edge faces the player).
# Each is the row of edge cells left open in the forest ring: 4 cells wide (2026-10-22, Siddharth: wide gaps,
# so enemies come out spread across the gap instead of in single file).
const SPAWNS := {
	"north": [Vector2i(10, 0), Vector2i(11, 0), Vector2i(12, 0), Vector2i(13, 0)],
	"east": [Vector2i(23, 10), Vector2i(23, 11), Vector2i(23, 12), Vector2i(23, 13)],
	"west": [Vector2i(0, 10), Vector2i(0, 11), Vector2i(0, 12), Vector2i(0, 13)],
}

# Enemies (spec 9; speeds in cells/s). None can damage towers in this slice. dps (damage per second to a
# house) is only given for the Grunt (2, decided 2026-10-22); the others reuse it as a STAND-IN.
# unlock = first night (1-based) the type can appear; unlock_loop = first loop (0-based) it can appear
# (spec 16: Tunnelers and the Fog variant are loop 2 only). threat = cost against the night budget (spec 6a).
# weight = how often the wave plan picks it among unlocked types (slice choice: mostly Grunts).
#   flying:  the Wisp (spec 10) rises out of the tree line and flies straight at the nearest standing house,
#            fly_height cells above the board; only air attacks hit it (the Airship, Long Draw Legendary).
#   burrows: the Tunneler (spec 9) travels underground in a straight line, untouchable, and pops up next to
#            the nearest standing house.
#   hidden:  the Fog variant is hidden from Foresight (step 3); otherwise it walks like a Grunt.
const ENEMIES := {
	"grunt": {"name": "Grunt", "hp": 20.0, "speed": 0.4, "dps": 2.0, "threat": 1, "unlock": 1, "weight": 5},
	"scout": {"name": "Scout", "hp": 10.0, "speed": 0.8, "dps": 2.0, "threat": 1, "unlock": 2, "weight": 3},
	"splitter": {"name": "Splitter", "hp": 25.0, "speed": 0.4, "dps": 2.0, "threat": 3, "unlock": 3, "weight": 2,
		"splits_into": "splitling", "split_count": 2},
	"wisp": {"name": "Wisp", "hp": 8.0, "speed": 1.2, "dps": 2.0, "threat": 2, "unlock": 2, "weight": 2,
		"flying": true, "fly_height": 4.0},
	"tunneler": {"name": "Tunneler", "hp": 30.0, "speed": 0.4, "dps": 2.0, "threat": 3, "unlock": 2, "unlock_loop": 1,
		"weight": 2, "burrows": true},
	"fog": {"name": "Fog variant", "hp": 25.0, "speed": 0.4, "dps": 2.0, "threat": 3, "unlock": 3, "unlock_loop": 1,
		"weight": 2, "hidden": true},
	# the two small pieces a Splitter leaves (spec: 2 x 8 HP); never bought by the wave plan
	# PLACEHOLDER boss (spec E11: a scaled-up Grunt so the loop is testable; the real Warden comes later).
	# Stats are Claude's stand-ins (the spec gives none); it walks to the houses like a Grunt, 2.5x the size.
	"boss": {"name": "Warden (placeholder)", "hp": 200.0, "speed": 0.25, "dps": 6.0, "threat": 0, "unlock": 99, "weight": 0,
		"boss": true},
	"splitling": {"name": "Splitling", "hp": 8.0, "speed": 0.4, "dps": 1.0, "threat": 0, "unlock": 99, "weight": 0},
}
const WAVE_TYPES: Array[String] = ["grunt", "scout", "splitter", "wisp", "tunneler", "fog"]  # what the wave plan may buy
const FLYER_SHARE := 1.0 / 3.0  # spec 6a guard rail: flyers never more than a third of a night's threat
# Enemy HP grows each night (2026-10-22, Siddharth: ramp per night): night n has x(1 + HP_RAMP * (n - 1)).
const HP_RAMP_PER_NIGHT := 0.25

# Waves (spec 6a; 2026-10-22: harder, budgets ramp up). Threat budget per night, 3 groups (one per spawn),
# a new group every 12 s. Each group leaves the forest in clusters of 2-3 that come out together.
const NIGHT_BUDGETS: Array[int] = [8, 14, 22, 32, 44, 30]  # the 6th = the boss night's escort groups
const GROUP_INTERVAL := 12.0
const FIRST_GROUP_DELAY := 3.0
const CLUSTER_SIZE := Vector2i(2, 3)
const CLUSTER_GAP := 2.5  # seconds between clusters of one group
const BOSS_DELAY := 15.0  # the placeholder boss leaves the forest after the first escort group
const SPREAD := 0.3  # each enemy walks up to this many cells off the centre line, so a crowd does not form a queue

# Towers (spec 7). targets: what a tower can hit ("ground" or "air"); cards can widen it (Long Draw and Long
# Mooring Legendaries). max = how many of that kind may stand on the board (spec 7: at most 2 Airships).
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
	# the shot is a small cannonball (STAND-IN until the Airship gets its own shot).
	# cost 35 = half the spec's 70 (Siddharth 2026-10-22: "for now")
	"airship": {
		"name": "Airship", "cost": 35, "range": 4.0, "damage": 6.0, "interval": 1.0, "kind": "single", "targets": "air",
		"max": 2, "scene": "res://assets/defense/ew_defense_airship_v01.glb", "turn_part": "turret",
		"shot": "res://assets/defense/ew_defense_cannonball_v01.glb", "shot_scale": 0.6, "shot_speed": 14.0,
	},
}
const TOWER_ORDER: Array[String] = ["fire", "brazier", "crossbow", "airship"]
const TOWER_SIZE := Vector2i(2, 2)
