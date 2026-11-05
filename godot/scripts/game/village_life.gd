class_name VillageLife
extends Node3D
## The village by day and the forest's watchers (Siddharth 2026-11-03). Cosmetic only: no rule reads any of this.
##   Day    each villager does its job, takes a break for a chat, then goes back. Whoever has a help request walks over and waves.
##   Night  everyone sprints to a door as it starts; nothing can hurt them. Dawn: they come back out, even from a shuttered house.
##   Forest by day a few enemies, of the types the coming night can bring, lurk just inside the tree line and never come further;
##          at night they sink away and the real waves come. Which ones lurk is random: it says nothing about the coming waves.
## Villagers walk round houses, towers and props on their own grid (a tower built on one just makes it walk off).

const CAST := [  # 2 villagers per house
	{"key": "elder_ram", "job": "stroll", "home": 0},
	{"key": "clerk_owl", "job": "notices", "home": 0},
	{"key": "farmer_horse", "job": "farm", "home": 1},
	{"key": "builder_ant", "job": "build", "home": 1},
	{"key": "dancer_butterfly", "job": "dance", "home": 2},
	{"key": "baker_mouse", "job": "bake", "home": 2},
	{"key": "tailor_spider", "job": "sew", "home": 3},
	{"key": "kid_bunny", "job": "chase", "home": 3},
	{"key": "kid_sprout", "job": "follow", "home": 4},
	{"key": "bee_kid", "job": "flowers", "home": 4},
	{"key": "cat_girl", "job": "sweep", "home": 5},
	{"key": "shroom_goblin", "job": "well", "home": 5},
]
const ENEMY_MODELS := {"grunt": ["blightbark", "bark"], "scout": ["veilrunner", "veil"], "splitter": ["sporebloom", "spore"], "wisp": ["lantern_spirit", "lantern"]}
const LURKER_SCALE := 0.75
const LURKER_LIFT := 0.008  # stands a little above the tall edge grass, so it reads as a figure and not as red tips in the grass

var game  # Game
var villagers: Array[Villager] = []
var lurkers: Array[Dictionary] = []  # {"rig", "cell", "goal": Vector3, "wait"}
var landmarks := {}  # prop name -> cell (from VillageDresser)

var _grid := AStarGrid2D.new()
var _rng := RandomNumberGenerator.new()
var _first_day := true


func setup(g, marks: Dictionary) -> void:
	game = g
	landmarks = marks
	_rng.seed = 41
	_grid.region = Rect2i(0, 0, GameConfig.SIZE, GameConfig.SIZE)
	_grid.cell_size = Vector2.ONE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	for c in CAST:
		var v := Villager.new()
		add_child(v)
		v.setup(self, c["key"], c["job"], c["home"])
		v.visible = false
		v.state = "inside"
		villagers.append(v)
	game.phase_changed.connect(_on_phase)


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	for v in villagers:
		v.tick(delta)
	_tick_lurkers(delta)


func pushers() -> Array:
	## The grass parts round everyone who is out, so it does not hide their legs.
	var out: Array = []
	for v in villagers:
		if v.visible:
			out.append(Vector4(v.global_position.x, v.global_position.y, v.global_position.z, 0.03))
	return out


# ---------------------------------------------------------------- day and night

func _on_phase(p: int) -> void:
	if p == Game.Phase.DAY:
		_morning()
	else:
		_nightfall()


func _morning() -> void:
	_clear_lurkers(true)
	_spawn_lurkers()
	var i := 0
	for v in villagers:
		if _first_day:
			v.put(_job_spot(v), "idle", _rng.randf_range(0.2, 2.0))
		elif v.state == "inside" or v.state == "wait_out" or v.state == "enter":
			v.come_out(0.1 + 0.18 * i)
		i += 1
	_first_day = false


func _nightfall() -> void:
	_clear_lurkers(false)
	for v in villagers:
		v.run_home(door_point(v.home), _path(NavGrid.local_to_cell(v.position), NavGrid.local_to_cell(door_point(v.home))))


func door_point(house: int) -> Vector3:
	var h: House = game.houses[house]
	return h.position + h.basis.z * GameConfig.CELL * 1.2


func exit_point(v: Villager) -> Vector3:
	## The door; a shuttered house's people turn up beside it.
	var h: House = game.houses[v.home]
	var p := door_point(v.home)
	if h.is_shuttered:
		p += h.basis.x * GameConfig.CELL * (1.0 if villagers.find(v) % 2 == 0 else -1.0)
	return p


func dust_at(p: Vector3) -> void:
	if game.with_rig and is_inside_tree():
		VfxKit.toon_dust(self, to_global(p), 0.02)


func help_wanted(house: int, at: Vector3) -> Villager:
	## A help request went up: one of that house's people goes to stand by it and wave.
	for v in villagers:
		if v.home == house and v.claim == Vector3.INF:
			v.claim = at
			if v.state == "stay" or v.state == "go":
				next_goal(v)
			return v
	return null


func clear_claims() -> void:
	for v in villagers:
		v.claim = Vector3.INF


# ---------------------------------------------------------------- jobs

func next_goal(v: Villager) -> void:
	if v.claim != Vector3.INF:
		if v.position.distance_to(v.claim) < GameConfig.CELL * 0.5:  # already there: keeps waving, no shuffling about
			v.wave_on(door_point(v.home))
		else:
			_send(v, v.claim, Villager.WALK, "wave", 3.0, door_point(v.home))
		return
	v.turn += 1
	match v.job:
		"chase":  # the kids run round the plaza
			_send(v, _free_point(_plaza(), 5), 3.0, "cheer", _rng.randf_range(0.6, 1.6))
		"follow":
			var other := _villager("kid_bunny")
			_send(v, other.position if other and other.visible else _free_point(_plaza(), 4), 2.6, "cheer", _rng.randf_range(0.3, 0.9))
		"stroll":  # the elder calls on every house in turn
			_send(v, door_point(v.turn % game.houses.size()) + Vector3(0.02, 0, 0.02), Villager.WALK * 0.7, "talk", _rng.randf_range(4.0, 7.0))
		_:
			if v.turn % 3 == 0:  # a break: a chat with whoever is near the plaza
				var spot := _free_point(_plaza(), 5)
				_send(v, spot, Villager.WALK, "talk", _rng.randf_range(4.0, 8.0), _nearest_other(v, spot))
			else:
				_send(v, _job_spot(v), Villager.WALK, _job_anim(v.job), _rng.randf_range(9.0, 18.0), _job_face(v))


func _job_anim(job: String) -> String:
	return {"notices": "read", "farm": "fork", "build": "hammer", "dance": "dance", "bake": "roll", "sew": "sew", "flowers": "water", "sweep": "sweep", "well": "tend"}.get(job, "idle")


func _job_mark(v: Villager) -> Vector3:
	## What the job is done at: a landmark prop, a house being repaired, or its own home.
	var names: Array = {"notices": ["notice_board_v02"], "farm": ["haystack_v03", "pumpkins_v02", "sacks_v02"], "bake": ["market_stall_v02"], "well": ["well_v02"]}.get(v.job, [])
	for n in names:  # the dressing is random, so the farmer takes whichever crop is there
		if landmarks.has(n):
			return NavGrid.cell_centre(landmarks[n])
	if v.job == "dance":
		return _plaza()
	if v.job == "build":  # goes to the most damaged house
		var worst: House = game.houses[v.home]
		for h: House in game.houses:
			if h.hp / h.max_hp < worst.hp / worst.max_hp:
				worst = h
		return worst.position
	return game.houses[v.home].position


func _job_spot(v: Villager) -> Vector3:
	if v.job == "stroll" or v.job == "chase" or v.job == "follow":
		return _free_point(_plaza(), 4)
	if v.job == "dance":
		return _free_point(_plaza(), 2)
	return _free_point(_job_mark(v), 3)


func _job_face(v: Villager) -> Vector3:
	return Vector3.INF if v.job == "dance" else _job_mark(v)


func _plaza() -> Vector3:
	return Vector3.ZERO  # the board's centre


func _villager(key: String) -> Villager:
	for v in villagers:
		if v.key == key:
			return v
	return null


func _nearest_other(v: Villager, at: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	for o in villagers:
		if o != v and o.visible and o.position.distance_to(at) < best_d:
			best_d = o.position.distance_to(at)
			best = o.position
	return best


func _send(v: Villager, at: Vector3, speed: float, anim: String, seconds: float, face := Vector3.INF) -> void:
	v.go(_path(NavGrid.local_to_cell(v.position), NavGrid.local_to_cell(at)), at, speed, anim, seconds, face)


# ---------------------------------------------------------------- grid

func _sync_grid() -> void:
	_grid.fill_solid_region(_grid.region, false)
	for c in game.nav.kind:
		if game.nav.kind[c] != "spawn":
			_grid.set_point_solid(c, true)


func _path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	## The cells to walk. Empty when it stands on something solid (a tower just went up on it) or cannot get there: it
	## then walks straight, which is fine for something nobody fights.
	_sync_grid()
	if not _grid.is_in_boundsv(from) or not _grid.is_in_boundsv(to) or _grid.is_point_solid(from):
		return []
	var goal := to
	if _grid.is_point_solid(goal):
		var near := _free_cell_near(goal, 3)
		if near.x < 0:
			return []
		goal = near
	return _grid.get_id_path(from, goal)


func is_free(c: Vector2i) -> bool:
	_sync_grid()
	return _grid.is_in_boundsv(c) and not _grid.is_point_solid(c)


func _free_cell_near(c: Vector2i, radius: int) -> Vector2i:
	## A random free cell at the smallest distance that has one.
	for r in range(0, radius + 1):
		var ring: Array[Vector2i] = []
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == r and _grid.is_in_boundsv(n) and not _grid.is_point_solid(n):
					ring.append(n)
		if not ring.is_empty():
			return ring[_rng.randi_range(0, ring.size() - 1)]
	return Vector2i(-1, -1)


func _free_point(around: Vector3, radius: int) -> Vector3:
	_sync_grid()
	var c := NavGrid.local_to_cell(around)
	if radius > 2:  # somewhere in the area rather than always the nearest cell
		c += Vector2i(_rng.randi_range(-radius, radius), _rng.randi_range(-radius, radius))
		c = c.clamp(Vector2i(1, 1), Vector2i(GameConfig.SIZE - 2, GameConfig.SIZE - 2))
	var f := _free_cell_near(c, 6)
	if f.x < 0:
		return around
	return NavGrid.cell_centre(f) + Vector3(_rng.randf_range(-0.2, 0.2), 0, _rng.randf_range(-0.2, 0.2)) * GameConfig.CELL


# ---------------------------------------------------------------- the forest's watchers

func _unlocked() -> Array[String]:
	var out: Array[String] = []
	for k in ENEMY_MODELS:
		var e: Dictionary = GameConfig.ENEMIES[k]
		if e["unlock"] <= game.night + 1 and game.loop >= e.get("unlock_loop", 0):
			out.append(k)
	return out


func _edge_cell() -> Vector2i:
	## The first row of cells inside the forest ring (the ring itself runs off the island's edge).
	var n := GameConfig.SIZE - 2
	var i := _rng.randi_range(1, n)
	match _rng.randi_range(0, 3):
		0:
			return Vector2i(i, 1)
		1:
			return Vector2i(i, n)
		2:
			return Vector2i(1, i)
	return Vector2i(n, i)


func _spawn_lurkers() -> void:
	var kinds := _unlocked()
	if kinds.is_empty():
		return
	for i in mini(4 + game.night, 8):
		var k: String = kinds[_rng.randi_range(0, kinds.size() - 1)]
		var rig := CharacterRig.new()
		add_child(rig)
		rig.setup(ENEMY_MODELS[k][0], ENEMY_MODELS[k][1])
		rig.scale = Vector3.ONE * LURKER_SCALE
		var c := _edge_cell()
		rig.position = NavGrid.cell_centre(c) + Vector3(0, 0.05 if k == "wisp" else LURKER_LIFT, 0)
		rig.rise(_rng.randf_range(0.5, 1.2))
		lurkers.append({"rig": rig, "cell": c, "goal": rig.position, "wait": _rng.randf_range(0.5, 6.0)})
		_look_inward(rig)


func _look_inward(rig: CharacterRig) -> void:
	rig.rotation.y = atan2(-rig.position.x, -rig.position.z) + _rng.randf_range(-0.5, 0.5)


func _tick_lurkers(delta: float) -> void:
	var n := GameConfig.SIZE - 2
	for l in lurkers:
		var rig: CharacterRig = l["rig"]
		var to: Vector3 = l["goal"] - rig.position
		to.y = 0.0
		if to.length() > 0.0005:
			var stride := 0.5 * GameConfig.CELL * delta
			rig.position += to.normalized() * minf(stride, to.length())
			rig.rotation.y = atan2(to.x, to.z)
			rig.anim = "walk"
			rig.gait = 0.5
			continue
		rig.anim = "idle"
		rig.gait = 0.0
		l["wait"] -= delta
		if l["wait"] <= 0.0:  # a few cells along the tree line, never onto the board
			l["wait"] = _rng.randf_range(3.0, 9.0)
			var c: Vector2i = l["cell"]
			var slide := _rng.randi_range(-3, 3)
			c = Vector2i(clampi(c.x + slide, 1, n), c.y) if c.y == 1 or c.y == n else Vector2i(c.x, clampi(c.y + slide, 1, n))
			l["cell"] = c
			var at := NavGrid.cell_centre(c)
			l["goal"] = Vector3(at.x, rig.position.y, at.z)
			if slide == 0:
				_look_inward(rig)


func _clear_lurkers(at_once: bool) -> void:
	for l in lurkers:
		var rig: CharacterRig = l["rig"]
		if is_instance_valid(rig):
			if at_once:
				rig.queue_free()
			else:
				rig.anim = "idle"
				rig.gait = 0.0
				rig.sink(_rng.randf_range(0.3, 0.8))
	lurkers.clear()
