class_name CrewMember
extends Node3D
## The villager who mans a tower (Siddharth 2026-10-26): always busy, and reacts when the tower fires.
## STAND-IN body of primitive shapes until Durva's character kit exists; the animation is tweened by hand
## (no rig), purely cosmetic: it never changes a gameplay number. The model's forward is +Z.
##   wizard  (Wizard Tower)   robe, pointed hat, a staff in the right hand. Idle: sways, the left hand stirs the
##                            air. Fires: turns to the target and thrusts the staff at it; shots leave from the staff tip.
##   archer  (Longbow Tower)  tunic and cap, both hands on the crossbow's crank: winds it, and a hard pull on each shot.
##   pilot   (Airship)        tunic and cap, both hands on a little wheel: steers; points at the target on each shot.
##   guard   (Guard Tower)    teal tunic, helmet and a spear. Idle: shifts its weight and looks about; walking: hops;
##                            thrusts the spear on each hit. Driven by Guard (set_facing, walking).

const SKIN := Color(0.949, 0.788, 0.627)
const INK := Color(0.067, 0.11, 0.188)
const TEAL := Color(0.184, 0.561, 0.541)
const TUNIC := Color(0.878, 0.608, 0.306)
const WOOD := Color(0.357, 0.161, 0.125)
const ACT_TIME := 0.4  # seconds one shot animation lasts

var kind := "wizard"
var _t := 0.0
var _act := 0.0  # seconds left of the shot animation
var _yaw_goal := 0.0
var _body: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _staff: Node3D  # the wizard's staff (pivots at the right hand)
var _wheel: Node3D
var walking := false  # the Guard sets this while it walks (a hop)


func setup(crew_kind: String) -> void:
	kind = crew_kind
	_body = Node3D.new()
	add_child(_body)
	var robe_col := TEAL if (kind == "wizard" or kind == "guard") else TUNIC
	_cyl(_body, 0.0072, 0.0042, 0.016, Vector3(0, 0.008, 0), robe_col)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.0195, 0)
	_body.add_child(_head)
	_ball(_head, 0.0050, Vector3.ZERO, SKIN)
	_ball(_head, 0.0009, Vector3(-0.0017, 0.0007, 0.0044), INK)  # eyes (front is +Z)
	_ball(_head, 0.0009, Vector3(0.0017, 0.0007, 0.0044), INK)
	match kind:
		"wizard":
			_cyl(_head, 0.0088, 0.0088, 0.0014, Vector3(0, 0.0042, 0), INK)  # brim
			_cyl(_head, 0.0068, 0.0, 0.013, Vector3(0, 0.0105, 0), INK)  # hat
			_cyl(_head, 0.0069, 0.0069, 0.0016, Vector3(0, 0.0058, 0), Color(0.69, 0.31, 0.19))  # band
		"guard":
			_cyl(_head, 0.0062, 0.0050, 0.0065, Vector3(0, 0.0050, 0), Color(0.549, 0.565, 0.588))  # stone-grey helmet
		"archer":
			_cyl(_head, 0.0056, 0.0030, 0.0055, Vector3(0, 0.0048, 0), WOOD)  # cap
		_:
			_cyl(_head, 0.0056, 0.0030, 0.0055, Vector3(0, 0.0048, 0), TEAL)
	_arm_l = _arm(-1)
	_arm_r = _arm(1)
	if kind == "wizard":
		_staff = Node3D.new()  # pivots at the right hand, tip up and a little forward
		_staff.position = Vector3(0.0085, 0.0095, 0.0035)
		_body.add_child(_staff)
		_cyl(_staff, 0.0013, 0.0013, 0.032, Vector3(0, 0.010, 0), WOOD)
		_ball(_staff, 0.0028, Vector3(0, 0.0265, 0), Color(0.69, 0.31, 0.19))  # a dark knob; the glow is VFX
		_arm_r.rotation.x = -0.9
	elif kind == "guard":
		_staff = Node3D.new()  # the spear, pivots at the right hand
		_staff.position = Vector3(0.0085, 0.0095, 0.0035)
		_body.add_child(_staff)
		_cyl(_staff, 0.0013, 0.0013, 0.034, Vector3(0, 0.008, 0), WOOD)
		_cyl(_staff, 0.0028, 0.0, 0.007, Vector3(0, 0.0275, 0), Color(0.549, 0.565, 0.588))
		_arm_r.rotation.x = -0.7
	elif kind == "pilot":
		_wheel = Node3D.new()
		_wheel.position = Vector3(0, 0.0105, 0.0085)
		_body.add_child(_wheel)
		var disc := _cyl(_wheel, 0.0050, 0.0050, 0.0012, Vector3.ZERO, WOOD)
		disc.rotation.x = PI / 2.0
	_yaw_goal = 0.0


func _cyl(parent: Node3D, r_bottom: float, r_top: float, h: float, at: Vector3, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = r_bottom
	cm.top_radius = r_top
	cm.height = h
	cm.radial_segments = 8
	m.mesh = cm
	m.material_override = ModelUtil.flat_material(col)
	m.position = at
	parent.add_child(m)
	return m


func _ball(parent: Node3D, r: float, at: Vector3, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	m.mesh = sm
	m.material_override = ModelUtil.flat_material(col)
	m.position = at
	parent.add_child(m)
	return m


func _arm(side: int) -> Node3D:
	## shoulder pivot; the arm hangs along -Y (rotation.x < 0 swings it forward)
	var pivot := Node3D.new()
	pivot.position = Vector3(side * 0.0065, 0.0145, 0.0)
	_body.add_child(pivot)
	_cyl(pivot, 0.0017, 0.0017, 0.0095, Vector3(0, -0.00475, 0), SKIN)
	return pivot


func react(target_pos: Vector3) -> void:
	## The tower fired at target_pos (world): face it and play the shot animation.
	var d := target_pos - global_position
	if Vector2(d.x, d.z).length() > 0.0001:
		_yaw_goal = atan2(d.x, d.z) - get_parent().global_rotation.y
	_act = ACT_TIME


func set_facing(yaw: float) -> void:
	_yaw_goal = yaw


func hand_point() -> Vector3:
	## World position shots leave from (the wizard's staff tip).
	if _staff:
		return _staff.to_global(Vector3(0, 0.0285, 0))  # wizard staff / guard spear tip
	return global_position + Vector3(0, 0.02, 0)


func _process(delta: float) -> void:
	_t += delta
	rotation.y = lerp_angle(rotation.y, _yaw_goal, minf(1.0, delta * 8.0))
	if _act > 0.0:
		_act = maxf(0.0, _act - delta)
	var k := sin(PI * (1.0 - _act / ACT_TIME)) if _act > 0.0 else 0.0  # 0 -> 1 -> 0 over the shot
	_body.position.y = 0.0006 * sin(_t * 2.2)  # breathing
	match kind:
		"guard":
			_arm_l.rotation.x = -0.15 + 0.1 * sin(_t * 1.3)
			_staff.rotation.x = -0.05 + 0.04 * sin(_t * 0.9) - 1.25 * k  # a thrust
			_head.rotation.y = 0.35 * sin(_t * 0.6)
			if walking:
				_body.position.y = 0.0016 * absf(sin(_t * 10.0))
		"wizard":
			_arm_l.rotation.x = -0.5 + 0.45 * sin(_t * 1.4) - 1.0 * k  # stirs the air, flings out on a shot
			_arm_l.rotation.z = 0.35 + 0.2 * sin(_t * 0.9)
			_staff.rotation.x = -0.12 + 0.07 * sin(_t * 1.1) - 0.9 * k  # a gentle sway, a thrust on a shot
			_head.rotation.y = 0.25 * sin(_t * 0.7)
		"archer":
			var crank := sin(_t * 3.2)
			_arm_l.rotation.x = -1.1 + 0.5 * crank - 0.5 * k
			_arm_r.rotation.x = -1.1 - 0.5 * crank - 0.5 * k
			_body.rotation.x = 0.05 * crank + 0.18 * k  # leans into the pull
		_:
			_wheel.rotation.z = 0.7 * sin(_t * 0.8)
			_arm_l.rotation.x = -1.2 + 0.1 * sin(_t * 0.8)
			_arm_r.rotation.x = -1.2 - 0.1 * sin(_t * 0.8) - 0.9 * k  # one hand off the wheel, pointing, on a shot
			_body.rotation.z = 0.06 * sin(_t * 0.8)
