class_name Tower
extends Node3D
## A built tower (spec 7). Fires at the nearest enemy in range it can hit (slice choice, the spec does not
## set a targeting rule) and turns its head, swivel or turret to face it. Ground towers hit ground enemies,
## the Airship hits flyers; Long Draw and Long Mooring Legendaries widen that. Towers cannot be damaged in this slice.
## Its numbers are the base stats from GameConfig.TOWERS changed by the ability cards the player holds
## (spec 15); they are worked out once when the tower is built, since cards only change between loops.
## Ticked by Game.step().

var game  # Game
var kind := "fire"
var cfg: Dictionary
var cell := Vector2i.ZERO
var cooldown := 0.0
var built_night := 0  # the night (0-based, in this loop) whose day it was built on: selling refunds in full that day
var shots_fired := 0

# effective stats (base + cards)
var damage := 0.0
var interval := 1.0
var reach := 0.0  # m
var hits_air := false
var hits_ground := true
var targets_per_volley := 1  # Twin Cannons Legendary: 2
var shot_mods := {}  # extras handed to each projectile: burn, knockback, patch, slow, air, ground, ground_mult
var every_nth := 0  # Legendary "every Nth shot" bonus (Quick Fuse 5, Bellows 3), 0 = none

var _turn: Node3D
var _turn_home: Basis
var _muzzle_h := 0.1
var _muzzle: Node3D  # the model's muzzle anchor, when it has one (the Airship's cannon)
# Guard Tower (kind "spawner"): its Guards and the numbers cards change
var guards: Array[Guard] = []
var guards_air := false  # Shield Wall Legendary: Guards can hit flyers
var max_guards := 0
var guard_hp := 0.0
var respawn := 8.0
var _spawn_timer := 0.0
var _gate: Node3D  # the model's spawn_anchor: where a new Guard steps out

var last_from := Vector3.ZERO  # where the latest shot left the tower (world)
var crew: CrewMember  # the villager manning it (a stand-in body, animated)
var aiming := false  # a target is in range this tick (the effects read it; nothing in the rules does)
var fx: TowerFx  # this tower's visual effects, when it has them yet


func setup(tower_kind: String, top_left: Vector2i) -> void:
	kind = tower_kind
	cfg = GameConfig.TOWERS[kind]
	cell = top_left
	position = NavGrid.footprint_centre(cell, GameConfig.TOWER_SIZE)
	var model: Node3D = load(cfg["scene"]).instantiate()
	add_child(model)
	_muzzle_h = ModelUtil.bounds(model).end.y * 0.8
	var parts := ModelUtil.parts(model)
	_turn = parts.get(cfg["turn_part"])
	for n in ModelUtil.walk(model):
		if n is Marker3D and str(n.name).ends_with("muzzle_anchor"):
			_muzzle = n
		elif n is Marker3D and str(n.name).ends_with("spawn_anchor"):
			_gate = n
		elif n is Marker3D and str(n.name).ends_with("orb_anchor") and _muzzle == null:
			_muzzle = n  # the Wizard Tower fires from its floating orb
	if _turn:
		_turn_home = _turn.basis
	_add_crew(model)
	fx = TowerFx.attach(self, _muzzle)
	_apply_cards()
	if cfg["kind"] == "spawner":
		refill()


func _add_crew(model: Node3D) -> void:
	## The tower's NPC: at the model's crew_anchor when it has one, else at cfg["crew_at"] (model-local metres).
	if not cfg.has("crew"):
		return
	var at: Vector3 = cfg.get("crew_at", Vector3.ZERO)
	for n in ModelUtil.walk(model):
		if n is Marker3D and str(n.name).ends_with("crew_anchor"):
			var t := Transform3D.IDENTITY
			var p: Node = n
			while p != null and p != self:  # the anchor's place in the tower's space (works before it is in the tree)
				t = (p as Node3D).transform * t
				p = p.get_parent()
			at = t.origin
	crew = CrewMember.new()
	add_child(crew)
	crew.setup(cfg["crew"])
	crew.position = at


func _apply_cards() -> void:
	damage = cfg["damage"]
	interval = cfg["interval"]
	hits_air = cfg.get("targets", "ground") == "air"
	hits_ground = not hits_air
	var range_cells: float = cfg["range"]
	match kind:
		"fire":
			var q: int = game.card("quick_fuse")
			if q >= 0:
				interval /= 1.0 + Cards.value("quick_fuse", q) / 100.0
				every_nth = 5 if q == 2 else 0
			var e: int = game.card("ember_shot")
			if e >= 0:
				shot_mods["burn"] = Cards.value("ember_shot", e)
				shot_mods["burn_spreads"] = e == 2
		"guard":
			max_guards = cfg["guards"]
			guard_hp = cfg["guard_hp"]
			respawn = cfg["respawn"]
			guards_air = false
			var sw: int = game.card("shield_wall")
			if sw >= 0:
				guard_hp *= 1.0 + Cards.value("shield_wall", sw) / 100.0
				guards_air = sw == 2  # Legendary: Guards can also hit flyers
			var ff: int = game.card("friendly_faces")
			if ff >= 0:
				max_guards = int(Cards.value("friendly_faces", ff))
				respawn /= 1.0 + [0.0, 0.25, 0.5][ff]
		"crossbow":
			var hb: int = game.card("heavy_bolts")
			if hb >= 0:
				damage = Cards.value("heavy_bolts", hb)
				shot_mods["slow"] = hb == 2
			var ld: int = game.card("long_draw")
			if ld >= 0:
				range_cells = Cards.value("long_draw", ld)
				hits_air = ld == 2
		"airship":
			var lm: int = game.card("long_mooring")
			if lm >= 0:
				range_cells = Cards.value("long_mooring", lm)
				if lm == 2:
					hits_ground = true
					shot_mods["ground_mult"] = 0.5  # Long Mooring Legendary: ground enemies at half damage
			var tc: int = game.card("twin_cannons")
			if tc >= 0:
				interval /= 1.0 + Cards.value("twin_cannons", tc) / 100.0
				targets_per_volley = 2 if tc == 2 else 1
	reach = range_cells * GameConfig.CELL
	shot_mods["air"] = hits_air
	shot_mods["ground"] = hits_ground


func step(delta: float) -> void:
	if cfg["kind"] == "spawner":
		_step_guards(delta)
		return
	cooldown = maxf(0.0, cooldown - delta * game.spells.haste_at(position))  # Rage rings speed it up
	var target := _nearest([])
	aiming = target != null
	if target == null:
		return
	if _turn:
		var d := target.global_position - global_position
		var a := atan2(d.x, d.z) - global_rotation.y
		_turn.basis = Basis(Vector3.UP, a) * _turn_home
	if cooldown <= 0.0:
		cooldown = interval
		shots_fired += 1
		var mods := shot_mods.duplicate()
		mods["damage"] = damage
		if every_nth > 0 and shots_fired % every_nth == 0:
			if kind == "fire":
				mods["damage"] = damage * 2.0
				mods["scale"] = 2.0
		var from := _muzzle.global_position if _muzzle and _muzzle.is_inside_tree() else global_position + Vector3(0, _muzzle_h, 0)
		if crew:
			crew.react(target.global_position)
			if cfg.get("shoot_from_crew", false):
				from = crew.hand_point()
		last_from = from
		if kind == "crossbow" and game.grass != null:
			game.grass.gust(from, target.global_position)  # the bolt's pale-green wind runs through the grass
		var picked: Array = [target]
		while picked.size() < targets_per_volley:
			var other := _nearest(picked)  # Twin Cannons Legendary: a second, different target
			if other == null:
				break
			picked.append(other)
		for e in picked:
			var shot := Projectile.new()
			shot.game = game
			game.shots_root.add_child(shot)
			shot.launch(from, e, cfg, reach, mods)
			game.shots.append(shot)


func _nearest(skip: Array) -> Enemy:
	var best: Enemy = null
	var best_d: float = reach
	for e in game.enemies:
		if not is_instance_valid(e) or not e.targetable(hits_air, hits_ground) or skip.has(e):
			continue
		var v: Vector3 = e.global_position - global_position
		var d := Vector2(v.x, v.z).length()
		if d <= best_d:
			best_d = d
			best = e
	return best


# ---- Guard Tower ---------------------------------------------------------------------------------

func _step_guards(delta: float) -> void:
	## Night tick: every Guard acts; a missing Guard is replaced every `respawn` seconds.
	for g in guards.duplicate():
		if is_instance_valid(g):
			g.step(delta)
	guards = guards.filter(func(g): return is_instance_valid(g) and g.alive)
	if guards.size() < max_guards:
		_spawn_timer -= delta * game.spells.haste_at(position)
		if _spawn_timer <= 0.0:
			_spawn_timer = respawn
			_spawn_guard(true)
	else:
		_spawn_timer = respawn


func refill() -> void:
	## Dawn (and when built): every Guard is back at its post at full health.
	for g in guards:
		if is_instance_valid(g):
			g.hp = guard_hp
			g.max_hp = guard_hp
	while guards.size() < max_guards:
		_spawn_guard(false)
	_spawn_timer = respawn


func _spawn_guard(from_gate: bool) -> Guard:
	var used := guards.map(func(g): return g.index)
	var idx := 0
	while used.has(idx):
		idx += 1
	var g := Guard.new()
	add_child(g)
	g.setup(self, idx, guard_hp, cfg)
	var at := post_point(idx)
	if from_gate and _gate and _gate.is_inside_tree():
		at = Vector3(_gate.global_position.x, at.y, _gate.global_position.z)
		g.state = "to_post"
	else:
		g.state = "idle"
	g.global_position = at
	guards.append(g)
	return g


func post_point(i: int) -> Vector3:
	## World position of post i: a free cell in the ring touching the tower, the posts spread evenly round it,
	## starting from the gate side. Worked out when asked, so a tower built beside the ring moves the post.
	var ring: Array = []
	var fp := NavGrid.footprint(cell, GameConfig.TOWER_SIZE)
	var cx := cell.x + (GameConfig.TOWER_SIZE.x - 1) * 0.5
	var cy := cell.y + (GameConfig.TOWER_SIZE.y - 1) * 0.5
	for x in range(cell.x - 1, cell.x + GameConfig.TOWER_SIZE.x + 1):
		for y in range(cell.y - 1, cell.y + GameConfig.TOWER_SIZE.y + 1):
			var c := Vector2i(x, y)
			if fp.has(c) or not game.nav.astar.is_in_boundsv(c) or game.nav.astar.is_point_solid(c):
				continue
			ring.append({"cell": c, "angle": fposmod(atan2(x - cx, y - cy), TAU)})  # 0 = the gate side (+Z)
	if ring.is_empty():
		return global_position
	ring.sort_custom(func(a, b): return a["angle"] < b["angle"])
	var k := int(floor((i % maxi(max_guards, 1) + 0.5) * ring.size() / float(maxi(max_guards, 1))))
	return get_parent().to_global(NavGrid.cell_centre(ring[mini(k, ring.size() - 1)]["cell"]))
