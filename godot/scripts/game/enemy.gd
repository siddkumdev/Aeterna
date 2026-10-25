class_name Enemy
extends Node3D
## One enemy, stand-in body (real models come with the character kit): dark ink shapes with ember eyes.
##   grunt     capsule
##   scout     small, thin, with a pointed hood; twice as fast
##   splitter  squat body under a wide mushroom cap; splits into 2 splitlings when it dies
##   splitling a small capsule
##   boss      the Warden, a Grunt 2.5x the size; immune to knockback. Warden (warden.gd) runs its three phases:
##             `shielded` blocks all damage, `on_zero` lets a phase end without dying
##   crystal   a Warden shield crystal: stands where Warden puts it, never moves or attacks, 40 HP
##   wisp      a small flying ink orb with a tail; rises out of the tree line and flies straight at the
##             nearest standing house, hovers over it and hits it. Only air attacks reach it.
##   tunneler  a squat digger; underground it is only a moving dirt mound (cannot be hit), it goes in a
##             straight line and pops up next to the nearest standing house, then fights like a Grunt
##   fog       a Grunt-like walker in pale mist grey; hidden from Foresight (step 3)
## Ground enemies walk cell to cell along their route to the nearest standing house, slightly off the centre
## line (their own `offset`, so a crowd spreads out), then hit the house. Ticked by Game.step(), never by _process, so the
## headless tests can run a night frame by frame.

signal died(enemy: Enemy)

const INK := Color(0.118, 0.102, 0.133)
const MIST := Color(0.62, 0.62, 0.64)
const DIRT := Color(0.36, 0.25, 0.17)

var game  # Game
var kind := "grunt"
var stats: Dictionary
var hp := 20.0
var cell := Vector2i.ZERO
var path: Array[Vector2i] = []
var target_house := -1
var attacking := false
var alive := true
var offset := Vector3.ZERO  # board-local, within GameConfig.SPREAD cells of the cell centre
var height := 0.045
var is_boss := false
var shielded := false  # the Warden in phase 2: takes no damage while a crystal stands
var on_zero := Callable()  # the Warden: returns true when 0 HP only ends a phase (it does not die)
var flying := false
var underground := false  # a Tunneler on its way: cannot be hit
var colour := INK
# status effects from cards: burning (Ember Shot, Hot Coals patches) and slowed (Heavy Bolts Legendary)
var burn_dps := 0.0
var burn_left := 0.0
var burn_spreads := false
var slow_left := 0.0
var slow_factor := 1.0

var _mats: Array[StandardMaterial3D] = []
var _flash := 0.0
var _body: Node3D
var _mound: MeshInstance3D
var _surface := Vector2i.ZERO  # where a Tunneler comes up


func setup(enemy_kind: String, night: int, loop: int, rng: RandomNumberGenerator) -> void:
	## night and loop are 0-based; HP grows by HP_RAMP_PER_NIGHT each night and by LOOP_HP_STEP each loop.
	kind = enemy_kind
	stats = GameConfig.ENEMIES[kind]
	is_boss = stats.get("boss", false)
	flying = stats.get("flying", false)
	underground = stats.get("burrows", false)
	colour = MIST if stats.get("hidden", false) else INK
	_body = Node3D.new()
	add_child(_body)
	hp = stats["hp"] * (1.0 + GameConfig.HP_RAMP_PER_NIGHT * night) * (1.0 + GameConfig.LOOP_HP_STEP * loop)
	if stats.get("static", false):
		hp = stats["hp"]  # crystals do not scale with the night or the loop
	var s := GameConfig.SPREAD * GameConfig.CELL
	offset = Vector3(rng.randf_range(-s, s), 0.0, rng.randf_range(-s, s))
	match kind:
		"scout":
			height = 0.036
			_capsule(0.008, 0.03)
			_cone(0.009, 0.014, 0.034)
			_eyes(0.0035, 0.024, 0.007)
		"splitter":
			height = 0.05
			_capsule(0.013, 0.034)
			_cap(0.024, 0.014, 0.036)
			_eyes(0.006, 0.024, 0.012)
		"splitling":
			height = 0.026
			_capsule(0.008, 0.024)
			_eyes(0.003, 0.017, 0.0072)
		"wisp":
			height = 0.024
			_ball(0.01, 0.012)
			_tail(0.006, 0.02, 0.012)
			_eyes(0.004, 0.014, 0.008)
		"tunneler":
			height = 0.04
			_capsule(0.015, 0.04)
			_cone(0.008, 0.012, 0.03)  # digging snout on top, tipped forward below
			_eyes(0.006, 0.028, 0.013)
			_mound = MeshInstance3D.new()
			var mm := SphereMesh.new()
			mm.radius = 0.018
			mm.height = 0.018
			mm.is_hemisphere = true
			_mound.mesh = mm
			_mound.material_override = ModelUtil.flat_material(DIRT)
			add_child(_mound)
			_body.visible = false
		"crystal":
			height = 0.06
			colour = Color(0.66, 0.45, 0.95)  # Warden purple, light enough to spot
			_crystal(0.012, 0.03, 0.04)
		"boss":
			height = 0.112
			_capsule(0.03, 0.112)
			_eyes(0.011, 0.08, 0.026)
		_:
			_capsule(0.012, 0.045)
			_eyes(0.0045, 0.032, 0.0102)


func _capsule(r: float, h: float) -> void:
	var m := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	m.mesh = cm
	m.position.y = h / 2.0
	_paint(m)


func _crystal(r: float, h: float, y: float) -> void:
	## a floating diamond: two cones base to base, centred at height y
	for flip in [1, -1]:
		var m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = r
		cm.height = h
		m.mesh = cm
		m.position.y = y + flip * h / 2.0
		if flip == -1:
			m.rotation.x = PI
		_paint(m)


func _ball(r: float, y: float) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	m.mesh = sm
	m.position.y = y
	_paint(m)


func _tail(r: float, length: float, y: float) -> void:
	## a cone trailing behind (-Z) the body
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r
	cm.height = length
	m.mesh = cm
	m.rotation.x = -PI / 2.0
	m.position = Vector3(0, y, -length / 2.0)
	_paint(m)


func _cone(r: float, h: float, y: float) -> void:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r
	cm.height = h
	m.mesh = cm
	m.position.y = y + h / 2.0
	_paint(m)


func _cap(r: float, h: float, y: float) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = h * 2.0
	sm.is_hemisphere = true
	m.mesh = sm
	m.position.y = y
	_paint(m)


func _paint(m: MeshInstance3D) -> void:
	var mat := ModelUtil.flat_material(colour)
	m.material_override = mat
	_mats.append(mat)
	_body.add_child(m)


func _eyes(spread: float, y: float, z: float) -> void:
	var eye_mat := ModelUtil.flat_material(Color8(0xFF, 0x8A, 0x2A), true)
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = spread * 0.6
		em.height = spread * 1.2
		eye.mesh = em
		eye.material_override = eye_mat
		eye.position = Vector3(side * spread, y, z)
		_body.add_child(eye)


func spawn_at(spawn_cell: Vector2i, at := Vector3.INF) -> void:
	cell = spawn_cell
	position = NavGrid.cell_centre(cell) + offset if at == Vector3.INF else at
	if flying:
		position.y = 1.5 * GameConfig.CELL  # rises out of the tree line
	_reroute()


func targetable(air: bool, ground: bool) -> bool:
	## Can an attack that hits air and/or ground reach this enemy right now?
	return alive and not underground and (air if flying else ground)


func _reroute() -> void:
	attacking = false
	if stats.get("static", false):
		return
	if flying or underground:
		target_house = game.nearest_house_to(position)
		path = []
		if underground and target_house != -1:
			_surface = game.surface_cell(target_house, position)  # the free cell by that house nearest to it
		return
	var r: Dictionary = game.nav.route(cell, game.standing_houses())
	if r.is_empty():
		path = []
		target_house = -1
		return
	target_house = r["house"]
	path = r["path"]
	if not path.is_empty() and path[0] == cell:
		path.remove_at(0)


func step(delta: float) -> void:
	if not alive:
		return
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			for m in _mats:
				m.albedo_color = colour
	if burn_left > 0.0:
		burn_left -= delta
		take_damage(burn_dps * delta, false)
		if not alive:
			return
	if slow_left > 0.0:
		slow_left -= delta
		if slow_left <= 0.0:
			slow_factor = 1.0
	if stats.get("static", false):
		return  # a crystal only stands there (Warden moves it)
	if target_house == -1 or game.houses[target_house].is_shuttered:
		_reroute()
		if target_house == -1:
			return  # nothing left to reach: stands still until the night ends
	if attacking:
		game.houses[target_house].damage(stats["dps"] * delta)
		return
	var stride: float = stats["speed"] * slow_factor * GameConfig.CELL * delta
	if flying or underground:
		_move_straight(stride)
		return
	if path.is_empty():
		attacking = true
		_face(NavGrid.footprint_centre(game.houses[target_house].cell, GameConfig.TOWER_SIZE))
		return
	var goal := NavGrid.cell_centre(path[0]) + offset
	var to := goal - position
	_face(goal)
	if to.length() <= stride:
		position = goal
		cell = path[0]
		path.remove_at(0)
	else:
		position += to.normalized() * stride


func _move_straight(stride: float) -> void:
	## Flyers head for a point fly_height cells over the house; a Tunneler for its surfacing cell.
	var goal: Vector3
	if flying:
		goal = game.house_point(target_house) + offset + Vector3(0, stats["fly_height"] * GameConfig.CELL, 0)
	else:
		goal = NavGrid.cell_centre(_surface) + offset
	var to := goal - position
	_face(goal)
	if to.length() <= stride:
		position = goal
		cell = NavGrid.local_to_cell(position)
		if flying:
			attacking = true
		else:
			_pop_up()
	else:
		position += to.normalized() * stride
		cell = NavGrid.local_to_cell(position)


func _pop_up() -> void:
	underground = false
	cell = _surface
	_body.visible = true
	_mound.visible = false
	_reroute()


func _face(p: Vector3) -> void:
	var d := p - position
	if Vector2(d.x, d.z).length() > 0.0001:
		rotation.y = atan2(d.x, d.z)


func take_damage(amount: float, flash := true) -> void:
	if not alive or shielded:
		return
	hp -= amount
	if flash:
		for m in _mats:
			m.albedo_color = Color8(0xFF, 0xE6, 0xC8)
		_flash = 0.08
	if hp <= 0.0:
		if on_zero.is_valid() and on_zero.call():
			return  # a phase ended, the Warden lives on
		alive = false
		died.emit(self)
		queue_free()


func set_tint(c: Color) -> void:
	colour = c
	for m in _mats:
		m.albedo_color = c


func chest() -> Vector3:
	return global_position + Vector3(0, height * 0.55, 0)


func ignite(dps: float, seconds: float, spreads: bool) -> void:
	## Burning does not stack: the stronger burn wins and the timer refreshes.
	burn_dps = maxf(burn_dps, dps)
	burn_left = maxf(burn_left, seconds)
	burn_spreads = burn_spreads or spreads


func slow(factor: float, seconds: float) -> void:
	slow_factor = minf(slow_factor, factor)
	slow_left = maxf(slow_left, seconds)


func knockback(from: Vector3) -> void:
	## Pushed 1 cell away from `from` (board-local), if that cell can be walked; then re-plans its route.
	if is_boss or flying or underground or not alive or stats.get("static", false):
		return
	var d := position - from
	d.y = 0.0
	if d.length() < 0.0001:
		return
	var step := Vector2i(roundi(d.normalized().x), roundi(d.normalized().z))
	var c := cell + step
	if not game.nav.astar.is_in_boundsv(c) or game.nav.astar.is_point_solid(c):
		return
	cell = c
	position = NavGrid.cell_centre(c) + offset
	_reroute()

