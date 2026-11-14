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
	var elder := hooded  # Maren: old, a little stooped, shawl and apron, grey bun (the user, 2026-11-14: make her look good)
	if elder:
		_body.rotation.x = 0.12
	# a dress or tunic with a waist, a chest and soft shoulders
	var skirt := 0.98 if female else 0.68  # a knee-length tunic
	W.lathe(st, PackedVector2Array([Vector2(0.29 if female else 0.2, -skirt + 0.1), Vector2(0.24 if female else 0.19, -skirt * 0.5), Vector2(0.17, 0.0), Vector2(0.16, 0.12),
		Vector2(0.19, 0.3), Vector2(0.195, 0.42), Vector2(0.17, 0.51), Vector2(0.12, 0.575), Vector2(0.06, 0.615), Vector2(0.0, 0.62)]),
		Transform3D.IDENTITY, K.CLOTH, cloth, 16, 0.03)
	W.cyl(st, 0.166, 0.166, 0.04, StoryWorld.at(Vector3(0, 0.08, 0)), K.WOOD, Color(0.22, 0.14, 0.09), 16)  # belt
	W.box(st, Vector3(0.05, 0.05, 0.02), StoryWorld.at(Vector3(0, 0.08, 0.17)), K.BRASS, Color(0.7, 0.55, 0.3))  # buckle
	if female:  # an apron, slightly lighter linen
		W.box(st, Vector3(0.22, 0.6, 0.012), Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(0, -0.27, 0.28)), K.CLOTH, Color(0.66, 0.6, 0.5))
	if elder:  # a knitted shawl: draped over the shoulders, falling to a point at the back, with a fringe
		W.lathe(st, PackedVector2Array([Vector2(0.215, 0.34), Vector2(0.225, 0.43), Vector2(0.2, 0.515), Vector2(0.145, 0.58), Vector2(0.08, 0.63), Vector2(0.055, 0.64)]), Transform3D.IDENTITY, K.CLOTH, cloth2, 16, 0.02)
		for k in 9:
			W.box(st, Vector3(0.012, 0.06, 0.012), StoryWorld.at(Vector3((k - 4) * 0.03, 0.15 + absf(k - 4) * 0.028, -0.215)), K.CLOTH, cloth2 * 0.8)
	_mesh(_body, st)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.6, 0.02 if elder else 0.0)
	_head.scale = Vector3.ONE * 1.1  # a touch larger reads as a person at story distance, not a mannequin
	_body.add_child(_head)
	var hs := StoryWorld.new_st()
	var lip := skin.darkened(0.22).lerp(Color(0.6, 0.3, 0.28), 0.35)
	W.cyl(hs, 0.045, 0.055, 0.1, StoryWorld.at(Vector3(0, 0.03, 0)), K.SKIN, skin, 10)
	# skull, then a jaw and cheeks so the face is not a ball
	W.ball(hs, 0.1, Transform3D(Basis.from_scale(Vector3(0.86, 1.0, 0.95)), Vector3(0, 0.19, -0.005)), K.SKIN, skin, 16)
	W.ball(hs, 0.075, Transform3D(Basis.from_scale(Vector3(0.95, 0.9, 1.0)), Vector3(0, 0.125, 0.03)), K.SKIN, skin, 12)  # jaw
	for sx in [-1, 1]:
		W.ball(hs, 0.03, StoryWorld.at(Vector3(sx * 0.045, 0.15, 0.075)), K.SKIN, skin.lerp(Color(0.85, 0.45, 0.4), 0.15), 8)  # cheek
		# eyes in sockets: white, a dark iris, a brow, a lid
		W.ball(hs, 0.017, StoryWorld.at(Vector3(sx * 0.034, 0.19, 0.074)), K.SKIN, skin.darkened(0.3), 6)  # socket shadow
		W.ball(hs, 0.0095, StoryWorld.at(Vector3(sx * 0.034, 0.19, 0.08)), K.CLOTH, Color(0.82, 0.78, 0.72), 6)
		W.ball(hs, 0.0055, StoryWorld.at(Vector3(sx * 0.034, 0.189, 0.0885)), K.IRON, Color(0.12, 0.08, 0.05), 5)
		W.ball(hs, 0.0115, Transform3D(Basis.from_scale(Vector3(1.1, 0.55, 1.0)), Vector3(sx * 0.034, 0.197, 0.08)), K.SKIN, skin * 0.9, 6)  # upper lid
		W.box(hs, Vector3(0.034, 0.008, 0.012), StoryWorld.at(Vector3(sx * 0.036, 0.212, 0.084), 0.0, Vector3(0, 0, -sx * 0.18)), K.HAIR, hair if not elder else Color(0.72, 0.7, 0.66))
		W.ball(hs, 0.022, Transform3D(Basis.from_scale(Vector3(0.45, 1.0, 0.75)), Vector3(sx * 0.088, 0.18, -0.005)), K.SKIN, skin * 0.92, 6)  # ears
	W.prism(hs, Vector3(0.022, 0.05, 0.03), StoryWorld.at(Vector3(0, 0.165, 0.098)), K.SKIN, skin * 0.97)  # nose bridge
	W.ball(hs, 0.014, StoryWorld.at(Vector3(0, 0.145, 0.104)), K.SKIN, skin * 0.95, 6)  # nose tip
	W.box(hs, Vector3(0.036, 0.009, 0.01), StoryWorld.at(Vector3(0, 0.118, 0.098)), K.SKIN, lip)  # mouth
	if elder:  # grey hair swept back into a bun, under a loose headscarf edge
		W.ball(hs, 0.108, Transform3D(Basis.from_scale(Vector3(0.95, 0.92, 1.04)), Vector3(0, 0.218, -0.024)), K.HAIR, hair, 14)
		for sx in [-1, 1]:  # soft waves over the temples
			W.ball(hs, 0.045, Transform3D(Basis.from_scale(Vector3(0.6, 0.9, 1.0)), Vector3(sx * 0.08, 0.215, 0.0)), K.HAIR, hair, 8)
		W.ball(hs, 0.05, StoryWorld.at(Vector3(0, 0.24, -0.11)), K.HAIR, hair, 10)
		W.cyl(hs, 0.03, 0.035, 0.02, Transform3D(Basis(Vector3.RIGHT, 1.2), Vector3(0, 0.23, -0.085)), K.CLOTH, cloth, 10)  # a ribbon round the bun
		for sx in [-1, 1]:  # crow's feet / lines under the eyes, as small darker creases
			W.box(hs, Vector3(0.022, 0.004, 0.006), StoryWorld.at(Vector3(sx * 0.035, 0.175, 0.085)), K.SKIN, skin.darkened(0.2))
	elif female:
		W.ball(hs, 0.106, Transform3D(Basis.from_scale(Vector3(0.92, 0.95, 1.0)), Vector3(0, 0.215, -0.02)), K.HAIR, hair, 14)
		W.ball(hs, 0.05, StoryWorld.at(Vector3(0, 0.2, -0.11)), K.HAIR, hair, 10)
		W.lathe(hs, PackedVector2Array([Vector2(0.03, 0.0), Vector2(0.025, 0.2), Vector2(0.0, 0.24)]), Transform3D(Basis(Vector3.RIGHT, PI - 0.2), Vector3(0, 0.2, -0.1)), K.HAIR, hair, 8)  # a braid
	else:
		W.ball(hs, 0.104, Transform3D(Basis.from_scale(Vector3(0.92, 0.72, 0.98)), Vector3(0, 0.24, -0.015)), K.HAIR, hair, 14)
		W.ball(hs, 0.062, Transform3D(Basis.from_scale(Vector3(1.0, 0.85, 0.55)), Vector3(0, 0.1, 0.06)), K.HAIR, hair, 10)  # beard
	_mesh(_head, hs)
	for sx in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.2, 0.5, 0)
		_body.add_child(arm)
		var a := StoryWorld.new_st()
		var sleeve: Color = cloth if (hooded or female) else cloth2
		# a shoulder, an upper arm and a forearm meeting at a soft elbow, the sleeve widening a touch at the cuff
		var elbow := Vector3(0, -0.29, -0.01)
		var wrist := Vector3(0, -0.53, 0.07)
		W.ball(a, 0.062, Transform3D(Basis.from_scale(Vector3(1.0, 0.9, 1.0)), Vector3(0, -0.02, 0)), K.CLOTH, sleeve, 10)
		W.seg(a, Vector3(0, -0.02, 0), elbow, 0.058, 0.046, K.CLOTH, sleeve, 12)
		W.ball(a, 0.046, StoryWorld.at(elbow), K.CLOTH, sleeve, 10)
		W.seg(a, elbow, wrist - (wrist - elbow).normalized() * 0.02, 0.046, 0.05, K.CLOTH, sleeve, 12)
		W.seg(a, wrist - (wrist - elbow).normalized() * 0.03, wrist + Vector3(0, -0.02, 0.004), 0.027, 0.024, K.SKIN, skin, 8)
		var hand := wrist + Vector3(0, -0.07, 0.01)
		W.ball(a, 1.0, Transform3D(Basis.from_scale(Vector3(0.03, 0.05, 0.016)), hand), K.SKIN, skin, 10)  # palm
		for f in 4:  # slightly curled fingers
			var fx := -0.017 + f * 0.0115
			var f0 := hand + Vector3(fx, -0.035, 0.004)
			var f1 := f0 + Vector3(0, -0.035 + absf(f - 1.5) * 0.005, 0.01)
			W.seg(a, f0, f1, 0.0068, 0.0058, K.SKIN, skin * 0.98, 6)
			W.seg(a, f1, f1 + Vector3(0, -0.018, 0.012), 0.0058, 0.005, K.SKIN, skin * 0.97, 6)
		W.seg(a, hand + Vector3(-sx * 0.022, 0.01, 0.01), hand + Vector3(-sx * 0.03, -0.035, 0.03), 0.009, 0.007, K.SKIN, skin, 6)  # thumb
		_mesh(arm, a)
		_arms.append(arm)
	for sx in [-1, 1]:
		var leg := Node3D.new()
		leg.position = Vector3(sx * 0.09, 0.95, 0)
		add_child(leg)
		var l := StoryWorld.new_st()
		# thigh, knee and calf: tapered, the shin a little behind the knee, so the leg is not a post
		W.seg(l, Vector3(0, 0.02, 0), Vector3(0, -0.45, 0.01), 0.072, 0.052, K.CLOTH, cloth2 * 0.7, 12)
		W.ball(l, 0.052, StoryWorld.at(Vector3(0, -0.45, 0.012)), K.CLOTH, cloth2 * 0.7, 10)
		W.seg(l, Vector3(0, -0.45, 0.01), Vector3(0, -0.62, -0.012), 0.052, 0.056, K.CLOTH, cloth2 * 0.7, 12)  # calf
		W.seg(l, Vector3(0, -0.62, -0.012), Vector3(0, -0.9, 0.0), 0.056, 0.036, K.CLOTH, cloth2 * 0.7, 12)
		W.lathe(l, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.055, 0.005), Vector2(0.06, 0.06), Vector2(0.045, 0.1), Vector2(0.0, 0.1)]),
			Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 2.1)), Vector3(0, -0.95, 0.04)), K.WOOD, Color(0.2, 0.13, 0.08), 10)  # a rounded leather shoe
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
		_arms[i].rotation = Vector3(-s * swing * side, 0, -side * 0.1)  # hanging a little away from the hips
	if pose == "pray" or (pose == "idle" and _k > 0.0):  # kneel, lift the hands
		_body.position.y = lerpf(_body.position.y, 0.55, _k)
		for leg in _legs:
			leg.position.y = lerpf(0.95, 0.55, _k)
			leg.rotation.x = lerpf(0.0, -1.4, _k)
		for i in 2:
			_arms[i].rotation = Vector3(lerpf(0.0, -2.6, _k), 0, (1.0 if i == 0 else -1.0) * lerpf(-0.1, -0.25, _k))
		_head.rotation.x = lerpf(0.0, -0.35, _k)
	elif pose == "sleep":
		rotation.x = lerpf(0.0, -PI / 2.0 + 0.05, _k)
		position.y = StoryWorld.height(position.x, position.z) + 0.12 * _k
	else:
		rotation.x = lerpf(rotation.x, 0.0, minf(1.0, delta * 2.0))
		for leg in _legs:
			leg.position.y = 0.95
