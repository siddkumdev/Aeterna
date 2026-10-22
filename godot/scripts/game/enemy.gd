class_name Enemy
extends Node3D
## Grunt, stand-in body (the real model comes with the character kit): a dark ink capsule with two ember
## eyes. Walks cell to cell along its route to the nearest standing house, then hits it (2 HP/s).
## Ticked by Game.step(), never by _process, so the headless tests can run a night frame by frame.

signal died(enemy: Enemy)

const RADIUS := 0.012
const HEIGHT := 0.045

var game  # Game
var hp := GameConfig.GRUNT_HP
var cell := Vector2i.ZERO
var path: Array[Vector2i] = []
var target_house := -1
var attacking := false
var alive := true

var _mat: StandardMaterial3D
var _flash := 0.0


func _init() -> void:
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = RADIUS
	cm.height = HEIGHT
	body.mesh = cm
	body.position.y = HEIGHT / 2.0
	_mat = ModelUtil.flat_material(Color8(0x1E, 0x1A, 0x22))
	body.material_override = _mat
	add_child(body)
	var eye_mat := ModelUtil.flat_material(Color8(0xFF, 0x8A, 0x2A), true)
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.0028
		em.height = 0.0056
		eye.mesh = em
		eye.material_override = eye_mat
		eye.position = Vector3(side * 0.0045, HEIGHT * 0.72, RADIUS * 0.85)
		add_child(eye)


func spawn_at(spawn_cell: Vector2i) -> void:
	cell = spawn_cell
	position = NavGrid.cell_centre(cell)
	_reroute()


func _reroute() -> void:
	attacking = false
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
			_mat.albedo_color = Color8(0x1E, 0x1A, 0x22)
	if target_house == -1 or game.houses[target_house].is_shuttered:
		_reroute()
		if target_house == -1:
			return  # nothing left to reach: stands still until the night ends
	if attacking:
		game.houses[target_house].damage(GameConfig.GRUNT_DPS * delta)
		return
	if path.is_empty():
		attacking = true
		_face(NavGrid.footprint_centre(game.houses[target_house].cell, GameConfig.TOWER_SIZE))
		return
	var goal := NavGrid.cell_centre(path[0])
	var to := goal - position
	var stride := GameConfig.GRUNT_SPEED * GameConfig.CELL * delta
	_face(goal)
	if to.length() <= stride:
		position = goal
		cell = path[0]
		path.remove_at(0)
	else:
		position += to.normalized() * stride


func _face(p: Vector3) -> void:
	var d := p - position
	if Vector2(d.x, d.z).length() > 0.0001:
		rotation.y = atan2(d.x, d.z)


func take_damage(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	_mat.albedo_color = Color8(0xFF, 0xE6, 0xC8)
	_flash = 0.08
	if hp <= 0.0:
		alive = false
		died.emit(self)
		queue_free()


func chest() -> Vector3:
	return global_position + Vector3(0, HEIGHT * 0.55, 0)
