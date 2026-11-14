class_name StoryPerson
extends Node3D
## A villager in the opening, at life size: separate parts (no skinned rig, the project rule) on pivots, animated
## here. Poses: "idle", "walk" (to a target), "pray" (kneel, hands raised), "flee" (run to a target), "sleep"
## (lie still: the Long Sleep), "wake" (rise from sleep). Built with StoryWorld's baking helpers and its one material.

var world: StoryWorld
var female := false
var hooded := false
var skin := Color(0.8, 0.6, 0.5)
var cloth := Color(0.4, 0.2, 0.1)
var cloth2 := Color(0.3, 0.3, 0.2)
var hair := Color(0.1, 0.07, 0.05)
var tall := 1.0
var pose := "idle"

var _body: Node3D
var _head: Node3D
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _target := Vector3.ZERO
var _speed := 1.3
var _ph := 0.0
var _k := 0.0  # 0..1 blend into the current pose (kneel, lie)


func _ready() -> void:
	scale = Vector3.ONE * tall
	_ph = randf() * TAU
	var W := world
	_body = Node3D.new()
	_body.position = Vector3(0, 0.95, 0)
	add_child(_body)
	var st := StoryWorld.new_st()
	var K := StoryWorld.K
	# tunic or long dress, belt, shoulders
	var skirt := 0.98 if female else 0.55
	W.lathe(st, PackedVector2Array([Vector2(0.27 if female else 0.2, -skirt + 0.1), Vector2(0.2, -0.05), Vector2(0.17, 0.12), Vector2(0.2, 0.42), Vector2(0.21, 0.55), Vector2(0.08, 0.62), Vector2(0.0, 0.63)]),
		Transform3D.IDENTITY, K.CLOTH, cloth, 12, 0.05)
	W.cyl(st, 0.185, 0.185, 0.06, StoryWorld.at(Vector3(0, 0.08, 0)), K.WOOD, Color(0.22, 0.14, 0.09), 12)
	if hooded:  # Maren's mantle over the shoulders
		W.lathe(st, PackedVector2Array([Vector2(0.3, 0.05), Vector2(0.27, 0.45), Vector2(0.16, 0.62), Vector2(0.0, 0.64)]), Transform3D.IDENTITY, K.CLOTH, cloth2, 12, 0.06)
	_mesh(_body, st)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.66, 0)
	_body.add_child(_head)
	var hs := StoryWorld.new_st()
	W.cyl(hs, 0.045, 0.055, 0.1, StoryWorld.at(Vector3(0, 0.03, 0)), K.SKIN, skin, 8)
	W.ball(hs, 0.105, Transform3D(Basis.from_scale(Vector3(0.88, 1.08, 0.95)), Vector3(0, 0.17, 0.01)), K.SKIN, skin, 14)
	W.ball(hs, 0.022, StoryWorld.at(Vector3(0, 0.16, 0.105)), K.SKIN, skin * 0.95, 6)  # nose
	for sx in [-1, 1]:
		W.ball(hs, 0.012, StoryWorld.at(Vector3(sx * 0.035, 0.195, 0.088)), K.IRON, Color(0.05, 0.04, 0.04), 5)  # eyes
		W.ball(hs, 0.022, Transform3D(Basis.from_scale(Vector3(0.5, 1, 0.8)), Vector3(sx * 0.093, 0.17, 0.0)), K.SKIN, skin * 0.92, 6)  # ears
	if hooded:
		W.ball(hs, 0.135, Transform3D(Basis.from_scale(Vector3(0.95, 1.1, 1.05)), Vector3(0, 0.19, -0.02)), K.CLOTH, cloth2, 12)
	elif female:
		W.ball(hs, 0.11, Transform3D(Basis.from_scale(Vector3(0.95, 0.95, 1.0)), Vector3(0, 0.205, -0.02)), K.HAIR, hair, 12)
		W.ball(hs, 0.06, StoryWorld.at(Vector3(0, 0.15, -0.11)), K.HAIR, hair, 8)  # a bun
	else:
		W.ball(hs, 0.108, Transform3D(Basis.from_scale(Vector3(0.93, 0.7, 0.98)), Vector3(0, 0.235, -0.015)), K.HAIR, hair, 12)
		W.ball(hs, 0.07, Transform3D(Basis.from_scale(Vector3(1.0, 0.8, 0.6)), Vector3(0, 0.1, 0.06)), K.HAIR, hair, 8)  # beard
	_mesh(_head, hs)
	for sx in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.22, 0.55, 0)
		_body.add_child(arm)
		var a := StoryWorld.new_st()
		W.cyl(a, 0.05, 0.045, 0.58, StoryWorld.at(Vector3(0, -0.29, 0)), K.CLOTH, cloth2 if not hooded else cloth, 8)
		W.ball(a, 0.045, Transform3D(Basis.from_scale(Vector3(0.8, 1.1, 0.6)), Vector3(0, -0.62, 0)), K.SKIN, skin, 8)
		_mesh(arm, a)
		_arms.append(arm)
	for sx in [-1, 1]:
		var leg := Node3D.new()
		leg.position = Vector3(sx * 0.09, 0.95, 0)
		add_child(leg)
		var l := StoryWorld.new_st()
		W.cyl(l, 0.065, 0.05, 0.86, StoryWorld.at(Vector3(0, -0.45, 0)), K.CLOTH, cloth2 * 0.7, 8)
		W.box(l, Vector3(0.1, 0.08, 0.24), StoryWorld.at(Vector3(0, -0.91, 0.04)), K.WOOD, Color(0.2, 0.13, 0.08))
		_mesh(leg, l)
		_legs.append(leg)


func _mesh(parent: Node3D, st: SurfaceTool) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = world.surf
	parent.add_child(mi)


func place(p: Vector3, yaw: float) -> void:
	position = p
	rotation.y = yaw
	_target = p


func go(to: Vector3, mode := "walk", speed := 1.3) -> void:
	_target = Vector3(to.x, StoryWorld.height(to.x, to.z), to.z)
	pose = mode
	_speed = speed


func set_pose(p: String) -> void:
	pose = p
	_k = 0.0 if p in ["pray", "sleep"] else _k


func face(p: Vector3) -> void:
	rotation.y = atan2(p.x - position.x, p.z - position.z)


func tick(delta: float) -> void:
	if _body == null:
		return
	_ph += delta
	var moving := false
	if pose in ["walk", "flee"]:
		var d := _target - position
		d.y = 0.0
		if d.length() > 0.15:
			var step := minf(d.length(), _speed * delta)
			position += d.normalized() * step
			position.y = StoryWorld.height(position.x, position.z)
			rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), minf(1.0, delta * 6.0))
			moving = true
		else:
			pose = "idle"
	var target_k := 1.0 if pose in ["pray", "sleep"] else 0.0
	_k = move_toward(_k, target_k, delta * (0.7 if pose == "sleep" else 1.2))
	var run := pose == "flee"
	var f := 8.0 if run else 5.2
	var swing := (0.75 if run else 0.45) if moving else 0.0
	var s := sin(_ph * f)
	_legs[0].rotation.x = s * swing
	_legs[1].rotation.x = -s * swing
	var breathe := sin(_ph * 1.6) * 0.012
	_body.position.y = 0.95 + absf(s) * 0.04 * float(moving) + breathe
	_body.rotation.x = (0.25 if run else 0.04) * float(moving)
	_head.rotation.y = sin(_ph * 0.4) * 0.3 * float(not moving)
	_head.rotation.x = 0.0
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		_arms[i].rotation = Vector3(-s * swing * side, 0, side * 0.08)
	if pose == "pray" or (pose == "idle" and _k > 0.0):  # kneel, lift the hands
		_body.position.y = lerpf(_body.position.y, 0.55, _k)
		for leg in _legs:
			leg.position.y = lerpf(0.95, 0.55, _k)
			leg.rotation.x = lerpf(0.0, -1.4, _k)
		for i in 2:
			_arms[i].rotation = Vector3(lerpf(0.0, -2.6, _k), 0, (1.0 if i == 0 else -1.0) * lerpf(0.08, -0.25, _k))
		_head.rotation.x = lerpf(0.0, -0.35, _k)
	elif pose == "sleep":
		rotation.x = lerpf(0.0, -PI / 2.0 + 0.05, _k)
		position.y = StoryWorld.height(position.x, position.z) + 0.12 * _k
	else:
		rotation.x = lerpf(rotation.x, 0.0, minf(1.0, delta * 2.0))
		for leg in _legs:
			leg.position.y = 0.95
