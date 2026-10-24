class_name HelpRequest
extends Node3D
## One villager help request (spec 18), done by hand during the day for trust:
##   chimney  rubble plugs the house's chimney: grab it and pull it out (move it 1.5 cells from the socket)
##   bird     a songbird is stuck on the chimney: grab it and move it 2 cells away; it flies off
##   lantern  a lantern lies out on the grass: carry it back and let go within 1.5 cells of the house's
##            lantern hook; it stands by the door
##   cart     a handcart is stuck in a rut next to the house: push it 2 cells clear along the ground
## Each has the "!" marker over its house and a STAND-IN villager (capsule body, round head) by the door
## until the real villagers exist. Let go too early and the prop goes back (a lantern stays where dropped).
## Positions are board-local (this node is a child of the board at its origin).

const MARK_HOVER := 0.012  # m above the roof
const MARK_SCALE := 2.0  # the approved "!" is 2.6 cm tall: drawn twice that so it reads from the seat

var game  # Game
var kind := ""
var house := -1
var reward := 0
var done := false
var prop: Node3D
var held := false

var _home := Vector3.ZERO  # where the prop started
var _goal := Vector3.ZERO  # lantern: where it is returned to
var _marker: Node3D
var _prop_marker: Node3D  # a second "!" that rides on a lantern or cart, so it can be found even behind a tall tower
var _villager: Node3D


func setup(request_kind: String, house_index: int, lantern_at := Vector3.ZERO) -> void:
	kind = request_kind
	house = house_index
	var cfg: Dictionary = GameConfig.REQUESTS[kind]
	reward = cfg["reward"]
	var h: House = game.houses[house]
	prop = load(cfg["scene"]).instantiate()
	add_child(prop)
	var socket := _anchor(h, "rubble_anchor")
	match kind:
		"chimney", "bird":
			_home = socket
		"lantern":
			_home = lantern_at
			var hook := _anchor(h, "lantern_anchor")
			_goal = Vector3(hook.x, 0.0, hook.z)
		"cart":
			_home = _free_beside(h)
	prop.position = _home
	prop.rotation.y = h.rotation.y
	var m = load(GameConfig.HELP_MARKER_SCENE)
	if m:
		_marker = m.instantiate()
		_marker.scale = Vector3.ONE * MARK_SCALE
		add_child(_marker)
		_marker.position = h.position + Vector3(0, ModelUtil.bounds(h.get_child(0)).end.y + MARK_HOVER, 0)
		if is_inside_tree():
			var tw := _marker.create_tween().set_loops()
			tw.tween_property(_marker, "position:y", _marker.position.y + 0.008, 0.6).set_trans(Tween.TRANS_SINE)
			tw.tween_property(_marker, "position:y", _marker.position.y, 0.6).set_trans(Tween.TRANS_SINE)
	if kind == "lantern" or kind == "cart":
		var pm = load(GameConfig.HELP_MARKER_SCENE)
		if pm:
			_prop_marker = pm.instantiate()
			_prop_marker.scale = Vector3.ONE * MARK_SCALE
			prop.add_child(_prop_marker)
			_prop_marker.position = Vector3(0, ModelUtil.bounds(prop).end.y + 0.004, 0)
	_villager = _stand_in_villager(house)
	add_child(_villager)
	_villager.position = _beside_door(h, 1.2) + h.basis.x * GameConfig.CELL * 0.8
	_villager.rotation.y = h.rotation.y


func grab_point() -> Vector3:
	## World position a hand has to be near to grab the prop.
	return prop.global_position + Vector3(0, 0.008, 0)


func grab() -> bool:
	if done or held:
		return false
	held = true
	return true


func move_to(local: Vector3) -> void:
	## While held: the prop follows the hand (board-local). The cart and lantern stay on the ground.
	if not held:
		return
	if kind == "cart":
		local.y = 0.0
	prop.position = local


func release() -> bool:
	## Let go: true when that finished the request.
	if not held:
		return false
	held = false
	var moved := prop.position - _home
	var flat := Vector2(moved.x, moved.z).length()
	match kind:
		"chimney":
			if moved.length() >= 1.5 * GameConfig.CELL:
				_finish()
				_toss(prop)
				return true
		"bird":
			if moved.length() >= 2.0 * GameConfig.CELL:
				_finish()
				_fly_off(prop)
				return true
		"lantern":
			var to_goal := prop.position - _goal
			if Vector2(to_goal.x, to_goal.z).length() <= 1.5 * GameConfig.CELL:
				prop.position = _goal
				_finish()
				return true
			prop.position.y = 0.0  # dropped on the grass, can be picked up again
			return false
		"cart":
			if flat >= 2.0 * GameConfig.CELL:
				var parts := ModelUtil.parts(prop)
				if parts.has("rut"):
					parts["rut"].visible = false
				_finish()
				return true
	prop.position = _home
	return false


func dodge(footprint: Array[Vector2i]) -> void:
	## A tower was just built: a lantern or cart on or right beside its cells (a tall tower hides what is
	## next to it from the seat) is carried to the nearest open ground. Not while someone is holding it.
	if done or held or (kind != "lantern" and kind != "cart"):
		return
	var c := NavGrid.local_to_cell(prop.position)
	for f in footprint:
		if absi(f.x - c.x) <= 1 and absi(f.y - c.y) <= 1:
			var spot: Vector3 = game.open_ground_near(prop.position)
			var shift := spot - prop.position
			prop.position = spot
			_home += Vector3(shift.x, 0, shift.z)
			if kind == "lantern":
				pass  # its goal is the house's hook, which never moves
			return


func _finish() -> void:
	done = true
	if _marker:
		_marker.visible = false
	if _prop_marker:
		_prop_marker.visible = false
	if _villager and _villager.is_inside_tree():
		var tw := _villager.create_tween()  # a happy hop
		tw.tween_property(_villager, "position:y", 0.02, 0.15).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_villager, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_BOUNCE)


func _toss(n: Node3D) -> void:
	if not n.is_inside_tree():
		n.visible = false
		return
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3.ONE * 0.001, 0.4)
	tw.tween_callback(func(): n.visible = false)


func _fly_off(n: Node3D) -> void:
	if not n.is_inside_tree():
		n.visible = false
		return
	var tw := n.create_tween()
	tw.tween_property(n, "position", n.position + Vector3(0.15, 0.25, -0.2), 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): n.visible = false)


func _anchor(h: House, suffix: String) -> Vector3:
	## A house anchor in board space (the house is a child of the board's "Houses" node at the origin).
	var model: Node3D = h.get_child(0)
	for n in ModelUtil.walk(model):
		if n is Marker3D and str(n.name).ends_with(suffix):
			return h.transform * ModelUtil.xform_to(n, model).origin
	return h.position


func _free_beside(h: House) -> Vector3:
	## The first side of the house (back, right, left, front) with open ground for the cart: no house, tower
	## or forest within a cell of it.
	for dir in [-h.basis.z, h.basis.x, -h.basis.x, h.basis.z]:
		var p: Vector3 = h.position + dir * GameConfig.CELL * 2.3
		var c := NavGrid.local_to_cell(p)
		var clear := true
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var n := c + Vector2i(dx, dy)
				if n.x < 1 or n.y < 1 or n.x > GameConfig.SIZE - 2 or n.y > GameConfig.SIZE - 2 or game.nav.kind.has(n):
					clear = false
		if clear:
			return p
	return h.position - h.basis.z * GameConfig.CELL * 2.3


func _beside_door(h: House, cells: float) -> Vector3:
	## The doors face the village centre (+Z of the model).
	return h.position + h.basis.z * GameConfig.CELL * cells


static func _stand_in_villager(i: int) -> Node3D:
	## STAND-IN until Durva's villagers: a small capsule body in a warm cloth colour and a round head.
	var cloth: Array[Color] = [Color("B04F31"), Color("2F8F8A"), Color("E09B4E"), Color("9A6538"), Color("6479E0"), Color("C6924C")]
	var v := Node3D.new()
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.007
	cm.height = 0.024
	body.mesh = cm
	body.position.y = 0.012
	body.material_override = ModelUtil.flat_material(cloth[i % cloth.size()])
	v.add_child(body)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.0075
	sm.height = 0.015
	head.mesh = sm
	head.position.y = 0.03
	head.material_override = ModelUtil.flat_material(Color("F2C9A0"))
	v.add_child(head)
	return v
