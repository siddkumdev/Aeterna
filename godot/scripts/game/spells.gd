class_name Spells
extends Node3D
## The five spells (spec 11, redesigned 2026-10-25 with Siddharth). Cast during the night only, no resource
## cost, limited by each spell's own cooldown (all ready at the start of every night). Every spell can hit
## both ground and air enemies (his call). Magic colours: black, orange, red; blue is Foresight only, purple
## is the Warden, so no blue lightning and no purple Rage.
##   fire_orb  a ball of fire lands where you drop it: damage in a small radius
##   boulder   falls from the height you let go (1-8 cells, toy gravity): higher = harder and wider, later
##   storm     a dark cloud hangs where you drop it and strikes the nearest enemy under it every 1.5 s; each
##             strike chains to the nearest enemies near the last one
##   rage      a red ring on the ground: towers inside shoot faster for a while (like Clash Royale's Rage)
##   roots     a potion dropped over a house: tree roots grow round it and soak up damage for a while
## Ticked by Game.step(); positions are board-local (this node sits at the board's origin).

const ORB_COLOUR := Color("FFD45A")  # fire_yellow
const GLOW_COLOUR := Color("F6A45D")  # lantern_glow
const FIRE_RED := Color("E8452C")
const INK := Color(0.118, 0.102, 0.133)
const ROOT_WOOD := Color("5B2920")  # wood_dark
const GRAVITY := 0.25 * 9.8  # toy gravity (spec 12), m/s^2
const ROOT_DOME_RADIUS := 0.07  # m: where the roots come out of the ground (the house footprint is ~0.045 from its centre)
const ROOT_DOME_HEIGHT := 0.15  # m: where they meet over the roof

var game  # Game
var cooldown := {}  # spell id -> seconds left
var tokens := {}  # spell id -> Node3D on the table, for hand grabs in VR
var _fx: Array = []  # timed effects: {"kind", "left", "node", ...}
var _rng := RandomNumberGenerator.new()
var _aim: MeshInstance3D  # the ring that shows where a spell will land


func _ready() -> void:
	_aim = MeshInstance3D.new()
	_aim.visible = false
	_aim.material_override = ModelUtil.flat_material(GLOW_COLOUR, true, 0.6)
	add_child(_aim)


func reset() -> void:
	## A new night: every spell ready, no leftovers.
	cooldown.clear()
	clear_effects()
	_rng.seed = game.run_seed * 977 + game.loop * 31 + game.night


func clear_effects() -> void:
	for h in game.houses:
		h.ward = 0.0
	for f in _fx:
		if is_instance_valid(f["node"]):
			f["node"].queue_free()
	_fx.clear()
	hide_aim()


func is_ready(id: String) -> bool:
	return cooldown.get(id, 0.0) <= 0.0


func haste_at(p: Vector3) -> float:
	## Attack-speed multiplier a tower at p gets from Rage rings (the best one, they do not stack).
	var best := 1.0
	for f in _fx:
		if f["kind"] == "rage" and _flat(f["pos"] - p) <= f["radius"]:
			best = maxf(best, f["haste"])
	return best


func cast(id: String, pos: Vector3, height := 4.0) -> bool:
	## Casts spell `id` at a board-local position (the height only matters for the boulder). False when it
	## cannot be cast: not night, still cooling down, or (roots) no house near the drop.
	if game.phase != Game.Phase.NIGHT or not GameConfig.SPELLS.has(id) or not is_ready(id):
		return false
	var cfg: Dictionary = GameConfig.SPELLS[id]
	pos.y = 0.0
	match id:
		"fire_orb":
			_throw(pos, cfg["damage"], cfg["radius"] * GameConfig.CELL, cfg["flight"], 0.3, ORB_COLOUR, 0.009)
		"boulder":
			var h := clampf(height, cfg["min_height"], cfg["max_height"])
			var fall := sqrt(2.0 * h * GameConfig.CELL / GRAVITY)  # spec 12: 8 cells = 0.57 s
			var dmg: float = cfg["damage"] * (1.0 + h / 8.0)
			var r: float = cfg["radius"] * (1.0 + 0.5 * h / 8.0) * GameConfig.CELL
			_throw(pos, dmg, r, fall, h * GameConfig.CELL, Color("8C9096"), 0.012)
		"storm":
			_storm(pos, cfg)
		"rage":
			_rage(pos, cfg)
		"roots":
			if not _roots(pos, cfg):
				return false
	var cd: float = cfg["cooldown"]
	var hands: int = game.card("quick_hands")
	if hands >= 0:
		cd *= 1.0 - Cards.value("quick_hands", hands) / 100.0
		if hands == 2 and _rng.randf() < 0.25:
			cd = 0.0  # Quick Hands Legendary: a quarter of casts come straight back
	cooldown[id] = cd
	return true


# ---------------------------------------------------------------- the spells

func _throw(pos: Vector3, damage: float, radius: float, flight: float, from_height: float, colour: Color, size: float) -> void:
	## Fire Orb and Boulder: a ball falls (the orb arcs in from the player's side) and bursts on landing.
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	ball.mesh = sm
	ball.material_override = ModelUtil.flat_material(colour, colour == ORB_COLOUR)
	add_child(ball)
	_fx.append({"kind": "ball", "node": ball, "left": flight, "total": flight, "pos": pos, "dmg": damage,
		"radius": radius, "up": from_height, "arc": colour == ORB_COLOUR})


func _storm(pos: Vector3, cfg: Dictionary) -> void:
	var cloud := Node3D.new()
	cloud.position = pos + Vector3(0, cfg["height"] * GameConfig.CELL, 0)
	add_child(cloud)
	var mat := ModelUtil.flat_material(INK)
	for i in range(4):
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.018 - 0.002 * (i % 2)
		sm.height = sm.radius * 2.0
		m.mesh = sm
		m.material_override = mat
		m.position = Vector3(cos(i * TAU / 4.0) * 0.016, 0.004 * (i % 2), sin(i * TAU / 4.0) * 0.016)
		cloud.add_child(m)
	_fx.append({"kind": "storm", "node": cloud, "left": cfg["duration"], "pos": pos, "next": 0.5, "cfg": cfg})


func _rage(pos: Vector3, cfg: Dictionary) -> void:
	var tm := TorusMesh.new()
	var r: float = cfg["radius"] * GameConfig.CELL
	tm.inner_radius = r - 0.004
	tm.outer_radius = r
	var ring := MeshInstance3D.new()
	ring.mesh = tm
	ring.scale.y = 0.4
	ring.position = pos + Vector3(0, 0.003, 0)
	ring.material_override = ModelUtil.flat_material(FIRE_RED, true, 0.8)
	add_child(ring)
	_fx.append({"kind": "rage", "node": ring, "left": cfg["duration"], "pos": pos, "radius": r, "haste": cfg["haste"]})


func _roots(pos: Vector3, cfg: Dictionary) -> bool:
	## Dropped within `reach` cells of a standing house: roots grow round it and absorb damage.
	var best := -1
	var best_d: float = cfg["reach"] * GameConfig.CELL
	for i in game.standing_houses():
		var d := _flat(game.house_point(i) - pos)
		if d <= best_d:
			best_d = d
			best = i
	if best < 0:
		game.last_message = "Drop the root potion over a house."
		return false
	var h: House = game.houses[best]
	h.ward = cfg["absorb"]
	for f in _fx:  # a second potion on the same house replaces the first
		if f["kind"] == "roots" and f["house"] == best:
			f["left"] = 0.0
	var cage := Node3D.new()
	cage.position = game.house_point(best)
	add_child(cage)
	var wood := ModelUtil.flat_material(ROOT_WOOD)
	var tip := ModelUtil.flat_material(GLOW_COLOUR, true)
	# a dome: each root rises from the ground outside the house walls and bends in over the roof to one point
	var top := Vector3(0, ROOT_DOME_HEIGHT, 0)
	for i in range(12):
		var a := i * TAU / 12.0
		var foot := Vector3(cos(a), 0, sin(a)) * ROOT_DOME_RADIUS
		var root := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0012
		cm.bottom_radius = 0.0032
		cm.height = foot.distance_to(top)
		root.mesh = cm
		root.material_override = wood
		root.look_at_from_position((foot + top) / 2.0, top, Vector3.UP)
		root.rotate_object_local(Vector3.RIGHT, -PI / 2.0)  # the cylinder's +Y now runs from the foot to the top
		cage.add_child(root)
		var glow := MeshInstance3D.new()  # an orange bud near each foot
		var sm := SphereMesh.new()
		sm.radius = 0.0028
		sm.height = 0.0056
		glow.mesh = sm
		glow.material_override = tip
		glow.position = foot.lerp(top, 0.18)
		cage.add_child(glow)
	_fx.append({"kind": "roots", "node": cage, "left": cfg["duration"], "house": best})
	return true


# ---------------------------------------------------------------- ticking

func step(delta: float) -> void:
	for id in cooldown.keys():
		cooldown[id] = maxf(0.0, cooldown[id] - delta)
	for f in _fx.duplicate():
		f["left"] -= delta
		match f["kind"]:
			"ball":
				_step_ball(f)
			"storm":
				f["next"] -= delta
				while f["next"] <= 0.0 and f["left"] > 0.0:
					f["next"] += f["cfg"]["interval"]
					_strike(f)
			"roots":
				if game.houses[f["house"]].ward <= 0.0:
					f["left"] = 0.0
			"flash", "bolt":
				var k: float = clampf(f["left"] / f["total"], 0.0, 1.0)
				if f["kind"] == "flash":
					f["node"].scale = Vector3.ONE * (1.0 + (1.0 - k) * 1.5) * Vector3(1, 0.3, 1)
		if f["left"] <= 0.0:
			if f["kind"] == "roots":
				game.houses[f["house"]].ward = 0.0
			if is_instance_valid(f["node"]):
				f["node"].queue_free()
			_fx.erase(f)


func _step_ball(f: Dictionary) -> void:
	var t: float = 1.0 - maxf(f["left"], 0.0) / f["total"]
	var pos: Vector3 = f["pos"]
	var p := pos
	if f["arc"]:
		# the orb arcs in from the player's side
		p = (pos + Vector3(0, 0.0, 0.25)).lerp(pos, t)
		p.y = 0.3 * 4.0 * t * (1.0 - t) * 0.6 + (1.0 - t) * 0.02
	else:
		p.y = maxf(0.0, f["up"] - 0.5 * GRAVITY * pow(t * f["total"], 2.0))  # toy gravity (spec 12)
	f["node"].position = p
	if f["left"] <= 0.0:
		_burst(pos, f["dmg"], f["radius"])


func _burst(pos: Vector3, damage: float, radius: float) -> void:
	for e in game.enemies.duplicate():
		if is_instance_valid(e) and e.targetable(true, true) and _flat(e.position - pos) <= radius:
			e.take_damage(damage)
	var tm := TorusMesh.new()
	tm.inner_radius = maxf(radius - 0.003, 0.001)
	tm.outer_radius = radius
	var ring := MeshInstance3D.new()
	ring.mesh = tm
	ring.position = pos + Vector3(0, 0.003, 0)
	ring.scale.y = 0.3
	ring.material_override = ModelUtil.flat_material(GLOW_COLOUR, true, 0.8)
	add_child(ring)
	_fx.append({"kind": "flash", "node": ring, "left": 0.25, "total": 0.25})


func _strike(f: Dictionary) -> void:
	## One lightning strike: the nearest enemy under the cloud, then on to the nearest enemies near the last.
	var cfg: Dictionary = f["cfg"]
	var cloud: Vector3 = f["pos"]
	var from: Vector3 = f["node"].position
	var hit: Array = []
	var at := _nearest(cloud, cfg["reach"] * GameConfig.CELL, hit)
	var points: Array[Vector3] = [from]
	while at != null and hit.size() <= cfg["chain"]:
		hit.append(at)
		points.append(at.chest())
		at.take_damage(cfg["damage"])
		var last: Vector3 = at.position
		at = _nearest(last, cfg["chain_reach"] * GameConfig.CELL, hit)
	for i in range(points.size() - 1):
		_bolt(points[i] - position, points[i + 1] - position)


func _nearest(centre: Vector3, reach: float, skip: Array) -> Enemy:
	var best: Enemy = null
	var best_d := reach
	for e in game.enemies:
		if not is_instance_valid(e) or not e.targetable(true, true) or skip.has(e):
			continue
		var d := _flat(e.position - centre)
		if d <= best_d:
			best_d = d
			best = e
	return best


func _bolt(a: Vector3, b: Vector3) -> void:
	## A thin orange bolt between two points, shown for a moment.
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.004, 0.004, maxf(a.distance_to(b), 0.001))
	m.mesh = bm
	m.material_override = ModelUtil.flat_material(ORB_COLOUR, true)
	add_child(m)
	m.position = (a + b) / 2.0
	if a.distance_to(b) > 0.001:
		m.look_at_from_position(m.position, b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	_fx.append({"kind": "bolt", "node": m, "left": 0.18, "total": 0.18})


# ---------------------------------------------------------------- aiming and tokens

func show_aim(id: String, pos: Vector3, height := 4.0) -> void:
	## A ring on the board where the spell would land (size = its radius).
	var cfg: Dictionary = GameConfig.SPELLS[id]
	var r: float = 0.0
	match id:
		"fire_orb":
			r = cfg["radius"]
		"boulder":
			r = cfg["radius"] * (1.0 + 0.5 * clampf(height, cfg["min_height"], cfg["max_height"]) / 8.0)
		"storm":
			r = cfg["reach"]
		"rage":
			r = cfg["radius"]
		"roots":
			r = cfg["reach"]
	r *= GameConfig.CELL
	var tm := TorusMesh.new()
	tm.inner_radius = maxf(r - 0.002, 0.001)
	tm.outer_radius = r
	_aim.mesh = tm
	_aim.scale = Vector3(1, 0.3, 1)
	_aim.position = Vector3(pos.x, 0.003, pos.z)
	_aim.visible = true


func hide_aim() -> void:
	if _aim:
		_aim.visible = false


func token_near(world: Vector3) -> String:
	## The spell token a hand is close enough to grab (VR), or "".
	var best := ""
	var best_d: float = game.reach(GameConfig.SPELL_GRAB_REACH)
	for id in tokens:
		var d: float = tokens[id].global_position.distance_to(world)
		if tokens[id].visible and d <= best_d:
			best_d = d
			best = id
	return best


static func make_token(id: String) -> Node3D:
	## The little object a spell is held as (stand-in shapes; real models come with the VFX pass).
	var n := Node3D.new()
	var m := MeshInstance3D.new()
	match id:
		"fire_orb":
			var sm := SphereMesh.new()
			sm.radius = 0.012
			sm.height = 0.024
			m.mesh = sm
			m.material_override = ModelUtil.flat_material(ORB_COLOUR, true)
		"boulder":
			var sm := SphereMesh.new()
			sm.radius = 0.014
			sm.height = 0.026
			m.mesh = sm
			m.material_override = ModelUtil.flat_material(Color("8C9096"))
		"storm":
			var sm := SphereMesh.new()
			sm.radius = 0.016
			sm.height = 0.022
			m.mesh = sm
			m.material_override = ModelUtil.flat_material(INK)
		"rage":
			var tm := TorusMesh.new()
			tm.inner_radius = 0.008
			tm.outer_radius = 0.016
			m.mesh = tm
			m.material_override = ModelUtil.flat_material(FIRE_RED, true)
		"roots":
			var cm := CylinderMesh.new()  # a potion bottle
			cm.top_radius = 0.005
			cm.bottom_radius = 0.011
			cm.height = 0.026
			m.mesh = cm
			m.material_override = ModelUtil.flat_material(ROOT_WOOD)
	n.add_child(m)
	return n


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()
