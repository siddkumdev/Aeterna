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
# icons + counts (no departure times: Siddharth 2026-10-23); 3 adds path ribbons (and where Tunnelers come up) and the rewrite
# (close one spawn for the night: its groups come from the next open edge instead). The Fog variant never shows.
const FORESIGHT_TIERS := 3
const FORESIGHT_TIER_BY_LOOP: Array[int] = [1, 1, 2, 2, 3]
const FORESIGHT_COLOUR := Color("3FB7D9")  # palette crystal_blue: blue is Foresight only
const LENS_SCENE := "res://assets/foresight/ew_foresight_crystal_lens_v01.glb"
const LENS_GRAB_REACH := 0.09  # m from the hand to the lens's grip for a grab
const LENS_RAISE := 0.15  # m above the table: the lens counts as held up to the eye
# Easy reach (debug aid, 2026-10-25): grab distances are multiplied by this on the desktop (mouse hand) and when
# the env var AETERNA_EASY_REACH=1 (set by run_sim.ps1), so keyboard-driven hands can find small objects. Real
# headset: 1.
const EASY_REACH := 2.0
const LENS_GAZE_DEG := 20.0  # a group is seen when its gap is within this angle of where the head looks (gaps are ~32 deg apart from the seat)
# Systems that exist in the build; cards for anything else are not offered (Cards.available)
const BUILT_SYSTEMS: Array[String] = ["airship", "spells"]

# Villager help requests (spec 18; step 5 of the full loop). Each day REQUESTS_PER_DAY requests, one of each
# kind, on different standing houses; done by hand for trust. Rewards are Claude's stand-ins inside the spec's
# 10-25 range (harder gesture, more trust). Unfinished requests vanish at night.
const REQUESTS := {
	"chimney": {"name": "Blocked chimney", "reward": 15, "scene": "res://assets/village/ew_village_chimney_rubble_v01.glb"},
	"bird": {"name": "Stuck bird", "reward": 10, "scene": "res://assets/village/ew_village_songbird_v01.glb"},
	"lantern": {"name": "Lost lantern", "reward": 20, "scene": "res://assets/village/ew_village_lantern_v01.glb"},
	"cart": {"name": "Stuck cart", "reward": 25, "scene": "res://assets/village/ew_village_handcart_v01.glb"},
}
const REQUESTS_PER_DAY := 4
const HELP_MARKER_SCENE := "res://assets/ui/ew_ui_help_marker_v01.glb"
const REQUEST_GRAB_REACH := 0.05  # m from a hand (or the mouse ray) to a prop to grab it
const LANTERN_DISTANCE := Vector2(4, 7)  # cells from its house where a lost lantern lies

# Houses (decided 2026-10-22: 60 HP). Damage carries over between nights (Siddharth 2026-10-23): each dawn a
# house heals DAWN_REPAIR HP (a shuttered house with HP again opens up); the hourglass rewind repairs fully.
# A night is lost at 3 or more shuttered houses (spec 2).
const DAWN_REPAIR := 10.0
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
	# The Warden (spec 9, M1 version with 3 phases, run by Warden). It walks to the houses like a Grunt, 2.5x the size;
	# "hp" is phase 1 (WARDEN_P3_HP is the final stand). Speed and dps are stand-ins; phase 3 multiplies both.
	"boss": {"name": "Warden", "hp": 150.0, "speed": 0.25, "dps": 6.0, "threat": 0, "unlock": 99, "weight": 0,
		"boss": true},
	# its shield crystals (phase 2): stand where the Warden puts them, break like any enemy
	"crystal": {"name": "Warden crystal", "hp": 40.0, "speed": 0.0, "dps": 0.0, "threat": 0, "unlock": 99, "weight": 0,
		"static": true},
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
const BOSS_DELAY := 15.0  # the Warden leaves the forest after the first escort group
# The Warden's phases (Siddharth chose these stand-ins 2026-10-25; retuned in M3). Phase HP is scaled by the night
# and loop like any enemy's; crystal HP is not.
const WARDEN_SUMMON_EVERY := 10.0  # phase 1: this many seconds between summons ...
const WARDEN_SUMMON_COUNT := 2  # ... of this many Grunts beside it
const WARDEN_CRYSTALS := 3  # phase 2: shield crystals; it takes no damage until all are broken
const WARDEN_CRYSTAL_RING := 2.0  # cells from the Warden
const WARDEN_P3_HP := 200.0  # phase 3 (the final stand)
const WARDEN_ENRAGE := 1.5  # phase 3: speed and damage multiplier
const WARDEN_WISP_EVERY := 8.0  # phase 3: Wisps rise from a random forest edge this often ...
const WARDEN_WISP_COUNT := 2  # ... this many at a time
const SPREAD := 0.3  # each enemy walks up to this many cells off the centre line, so a crowd does not form a queue

# Towers (spec 7). targets: what a tower can hit ("ground" or "air"); cards can widen it (Long Draw and Long
# Mooring Legendaries). Optional "max" = how many of that kind may stand on the board (none set: the 2-Airship
# limit from spec 7 was removed by Siddharth 2026-10-23).
const TOWERS := {
	"fire": {
		"name": "Wizard Tower", "cost": 60, "range": 5.0, "damage": 14.0, "interval": 1.5, "kind": "single",
		"scene": "res://assets/defense/ew_defense_wizard_tower_v02.glb", "turn_part": "",  # the hat does not turn to aim
		"shot": "res://assets/defense/ew_defense_fireball_v01.glb", "shot_speed": 12.0,
		"crew": "wizard", "shoot_from_crew": true,  # stands at the model's crew_anchor; fireballs leave from his staff tip
	},
	# The Guard Tower (Siddharth 2026-10-26, replaces the Blast Brazier): spawns Guards that stand in a ring touching
	# it and fight only what comes into their sight. Numbers are the old Watch Hut / Guard ones he chose; the rest are
	# stand-ins (~): hit every second, walking speed, the reach of a spear. Cards: Shield Wall, Friendly Faces.
	"guard": {
		"name": "Guard Tower", "cost": 70, "range": 2.0, "damage": 4.0, "interval": 1.0, "kind": "spawner",
		"scene": "res://assets/defense/ew_defense_guard_tower_v01.glb", "turn_part": "",
		"guards": 3, "guard_hp": 30.0, "guard_damage": 4.0, "respawn": 8.0,
		"sight": 2.0, "leash": 4.0,  # cells from the post (Siddharth: chase, then walk back)
		"attack_interval": 1.0, "guard_speed": 0.8, "reach": 0.6,  # ~
	},
	"crossbow": {
		"name": "Longbow Tower", "cost": 55, "range": 6.0, "damage": 4.0, "interval": 1.2, "kind": "pierce",
		"pierce_width": 0.5, "scene": "res://assets/defense/ew_defense_crossbow_tower_v03.glb", "turn_part": "swivel",
		"shot": "res://assets/defense/ew_defense_wind_bolt_v01.glb", "shot_speed": 20.0,
		"crew": "archer", "crew_at": Vector3(0.033, 0.056, 0.033),  # model-local metres (this model has no crew anchor yet)
	},
	# the shot is a small cannonball (STAND-IN until the Airship gets its own shot).
	# cost 35 = half the spec's 70 (Siddharth 2026-10-22: "for now")
	"airship": {
		"name": "Airship", "cost": 35, "range": 4.0, "damage": 6.0, "interval": 1.0, "kind": "single", "targets": "air",
		"scene": "res://assets/defense/ew_defense_airship_v01.glb", "turn_part": "turret",
		"shot": "res://assets/defense/ew_defense_cannonball_v01.glb", "shot_scale": 0.6, "shot_speed": 14.0,
		"crew": "pilot", "crew_at": Vector3(0.0, 0.121, -0.012),
	},
}
# Spells (spec 11, redesigned with Siddharth 2026-10-25): all hit ground AND air. Cast at night only, cooldown only.
# Numbers from the spec where it gives them (Fire Orb 12 / 1 cell / 8 s, Boulder 15 s and the drop rule of spec 12,
# Ward 40 for 8 s / 25 s); everything else is Claude's stand-in for the balance pass (marked ~).
const SPELLS := {
	"fire_orb": {"name": "Fire Orb", "cooldown": 8.0, "damage": 12.0, "radius": 1.0, "flight": 0.5},
	# ~ base damage 15 and radius 1.5 cells at height 0; height 1-8 cells scales both (spec 12)
	"boulder": {"name": "Boulder Drop", "cooldown": 15.0, "damage": 15.0, "radius": 1.5, "min_height": 1.0, "max_height": 8.0, "default_height": 4.0},
	# ~ the chain jumps to up to 2 more enemies within 2 cells of the last one; 6 s of cloud
	"storm": {"name": "Storm Cloud", "cooldown": 12.0, "duration": 6.0, "interval": 1.5, "damage": 8.0, "reach": 2.5,
		"chain": 2, "chain_reach": 2.0, "height": 5.0},
	# ~ towers inside the ring shoot 50% faster
	"rage": {"name": "Rage", "cooldown": 25.0, "duration": 8.0, "radius": 3.0, "haste": 1.5},
	# the spec's Ward Rune, now tree roots from a dropped potion (Siddharth 2026-10-25)
	"roots": {"name": "Root Ward", "cooldown": 25.0, "duration": 8.0, "absorb": 40.0, "reach": 2.0},
}
const SPELL_ORDER: Array[String] = ["fire_orb", "boulder", "storm", "rage", "roots"]
const SPELL_GRAB_REACH := 0.05  # m from a hand to a spell token on the table to grab it (VR)

const TOWER_ORDER: Array[String] = ["fire", "guard", "crossbow", "airship"]
# Selling (Siddharth 2026-10-23): day only, with the Sell sign. Full cost back on the day the tower was built
# (undo a mistake), half (rounded down) once a night has passed.
const SELL_LATER := 0.5
const TOWER_SIZE := Vector2i(2, 2)
