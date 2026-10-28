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
	## The orb is a dark core wrapped in painted fire with a swept comet tail (like the Wizard's fireball); the boulder is a plain rock.
	var fire := colour == ORB_COLOUR
	var ball := Node3D.new()
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size * (0.7 if fire else 1.0)
	sm.height = sm.radius * 2.0
	if not fire:  # a chunky faceted rock, not a ball
		sm.radial_segments = 6
		sm.rings = 3
		core.scale = Vector3(1.0, 0.85, 1.1)
	core.mesh = sm
	core.material_override = ModelUtil.flat_material(INK if fire else colour)
	ball.add_child(core)
	add_child(ball)
	var rec := {"kind": "ball", "node": ball, "left": flight, "total": flight, "pos": pos, "dmg": damage,
		"radius": radius, "up": from_height, "arc": fire, "fire": fire, "last": Vector3.ZERO}
	if fire:
		rec["glow"] = VfxKit.toon_fire(ball, 0, Vector2(0.04, 0.04), 1.0, 1.4)
		rec["trail"] = VfxKit.toon_fire(ball, 2, Vector2(0.1, 0.04), 1.0, 1.2)
	else:
		# a soft dark shadow on the ground that tightens onto the landing spot as the rock comes down
		var sh := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = radius
		cm.bottom_radius = radius
		cm.height = 0.0006
		cm.radial_segments = 24
		sh.mesh = cm
		sh.material_override = ModelUtil.flat_material(INK, true, 0.4)
		sh.position = Vector3(pos.x, 0.0035, pos.z)
		add_child(sh)
		rec["shadow"] = sh
		rec["spin"] = Vector3(_rng.randf_range(-5, 5), _rng.randf_range(-5, 5), _rng.randf_range(-5, 5))
	_fx.append(rec)


func _storm(pos: Vector3, cfg: Dictionary) -> void:
	## The cloud: five overlapping painted ink blobs that bob a little, hung over the drop point.
	var cloud := Node3D.new()
	cloud.position = pos + Vector3(0, cfg["height"] * GameConfig.CELL, 0)
	add_child(cloud)
	for i in range(5):
		var blob := VfxKit.toon_cloud(cloud, 0.12 - 0.025 * (i % 2))
		blob.position = Vector3(cos(i * TAU / 5.0) * 0.026, 0.006 * (i % 2), sin(i * TAU / 5.0) * 0.014)
		VfxKit.toon_set(blob, "depth_bias", 0.004 + 0.003 * i)
	_fx.append({"kind": "storm", "node": cloud, "left": cfg["duration"], "pos": pos, "next": 0.5, "cfg": cfg,
		"base_y": cloud.position.y, "age": 0.0})


func _rage(pos: Vector3, cfg: Dictionary) -> void:
	## A ring of painted flame on the ground that licks while it lasts; towers inside get a red pulse (see step).
	var r: float = cfg["radius"] * GameConfig.CELL
	var ring := Node3D.new()
	ring.position = pos + Vector3(0, 0.003, 0)
	add_child(ring)
	var flame := VfxKit.toon_ring(ring, r)
	VfxKit.toon_burst(self, to_global(pos), r * 2.4, "ring", 0.5)  # it sweeps out from where it lands
	_fx.append({"kind": "rage", "node": ring, "left": cfg["duration"], "total": cfg["duration"], "pos": pos, "radius": r,
		"haste": cfg["haste"], "flame": flame, "age": 0.0, "pulse": 0.4})


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
				f["age"] += delta
				f["node"].position.y = f["base_y"] + 0.003 * sin(f["age"] * 2.0)
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


func _step_rage(f: Dictionary, delta: float) -> void:
	f["age"] += delta
	var m := (f["flame"] as MeshInstance3D).material_override as ShaderMaterial
	m.set_shader_parameter("progress", 0.5 + 0.2 * sin(f["age"] * 1.7) + 0.1 * sin(f["age"] * 4.3))
	m.set_shader_parameter("alpha", clampf(f["left"] / 0.6, 0.0, 1.0))  # fades in its last moments
	f["pulse"] -= delta
	if f["pulse"] <= 0.0 and f["left"] > 0.3:
		f["pulse"] = 0.7
		for t in game.towers:  # a red pulse at the foot of every tower the ring is speeding up
			if is_instance_valid(t) and _flat(t.position - f["pos"]) <= f["radius"]:
				VfxKit.toon_burst(self, t.global_position + Vector3(0, 0.002, 0), 0.12, "ring", 0.45)
				VfxKit.burst(self, t.global_position + Vector3(0, 0.01, 0), FIRE_RED, INK, 5, 0.03, 0.5, 0.004, 0.15)


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
	var v: Vector3 = p - f["node"].position
	f["node"].position = p
	if f.has("spin"):
		f["node"].rotation = f["spin"] * t * f["total"]
		f["shadow"].scale = Vector3.ONE * (1.6 - 0.6 * t) * Vector3(1, 1, 1)
	if f.has("trail") and v.length() > 0.0001 and f["last"] != Vector3.ZERO:
		VfxKit.toon_set(f["trail"], "axis", v.normalized())
	f["last"] = p
	if f["left"] <= 0.0:
		if f.has("shadow") and is_instance_valid(f["shadow"]):
			f["shadow"].queue_free()
		_burst(pos, f["dmg"], f["radius"], f["fire"])


func _burst(pos: Vector3, damage: float, radius: float, fire := false) -> void:
	for e in game.enemies.duplicate():
		if is_instance_valid(e) and e.targetable(true, true) and _flat(e.position - pos) <= radius:
			e.take_damage(damage)
	if fire:  # painted fireball burst and a flaming ring the size of the blast
		VfxKit.toon_burst(self, to_global(pos + Vector3(0, 0.03, 0)), maxf(0.12, radius * 3.2), "burst", 0.5)
		VfxKit.toon_burst(self, to_global(Vector3(pos.x, 0.0, pos.z)), maxf(0.1, radius * 2.3), "ring", 0.55)
		return
	# the rock lands: a dust cloud and a ring of dust racing out to the blast radius, and grey chips thrown up
	var at := to_global(Vector3(pos.x, 0.0, pos.z))
	VfxKit.toon_dust(self, at + Vector3(0, 0.012, 0), maxf(0.1, radius * 2.4))
	var ring := VfxKit.toon_burst(self, at, maxf(0.12, radius * 2.5), "ring", 0.55)
	if ring != null:
		var m := ring.material_override as ShaderMaterial
		m.set_shader_parameter("c_core", Color("C2B49A"))
		m.set_shader_parameter("c_mid", Color("A89878"))
		m.set_shader_parameter("c_out", Color("7E6048"))
		m.set_shader_parameter("c_ink", Color("7E6048"))
	VfxKit.burst(self, at + Vector3(0, 0.01, 0), Color("8C9096"), INK, 10, 0.09, 0.5, 0.005, -0.5)


func _strike(f: Dictionary) -> void:
	## One lightning strike: the nearest enemy under the cloud, then on to the nearest enemies near the last.
	var cfg: Dictionary = f["cfg"]
	var cloud: Vector3 = f["pos"]
	var from: Vector3 = to_global(f["node"].position + Vector3(0, -0.006, 0))
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
		VfxKit.toon_burst(self, points[i + 1], 0.045, "burst", 0.3)  # a spark where it lands
	if points.size() > 1:
		VfxKit.toon_burst(self, from, 0.05, "burst", 0.2)  # and a flash in the cloud


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
	## One forked lightning link between two points: a zigzag of thin boxes, ink edge, orange body, yellow core.
	## It flickers for a moment (see step: "bolt").
	var bolt := Node3D.new()
	add_child(bolt)
	var dir := b - a
	var len := dir.length()
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()
	var n := maxi(3, int(len / 0.02))
	var pts: Array[Vector3] = [a]
	for i in range(1, n):
		var j := _rng.randf_range(-1.0, 1.0) * minf(0.012, len * 0.18)
		pts.append(a + dir * (float(i) / n) + side * j + Vector3(0, _rng.randf_range(-0.003, 0.003), 0))
	pts.append(b)
	var layers := [[0.0085, INK, false], [0.0052, GLOW_COLOUR, true], [0.0022, ORB_COLOUR, true]]
	for k in range(pts.size() - 1):
		var p0 := pts[k]
		var p1 := pts[k + 1]
		var l := maxf(p0.distance_to(p1), 0.001)
		for li in range(layers.size()):
			var layer: Array = layers[li]
			var m := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(layer[0], layer[0], l + layer[0] * 0.6)
			m.mesh = bm
			var mat := ModelUtil.flat_material(layer[1], layer[2])
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA  # drawn in layer order, so the thin core shows inside the ink edge
			mat.render_priority = li
			m.material_override = mat
			bolt.add_child(m)
			m.position = (p0 + p1) / 2.0
			if l > 0.001:
				m.look_at_from_position(m.position, p1, Vector3.UP if absf((p1 - p0).normalized().y) < 0.99 else Vector3.RIGHT)
	_fx.append({"kind": "bolt", "node": bolt, "left": 0.22, "total": 0.22})


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
