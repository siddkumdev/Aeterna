class_name GodHandVisual
extends Node3D
## The player's hand as a god's hand (docs/VFX_NOTES.md X-GH1). Built from the 26 OpenXR hand joints: a tapered
## segment between each pair of joints plus a ball on each joint, in two MultiMeshes (two draw calls a hand).
## NO skinning and NO external model: every piece is a plain cylinder or sphere posed from the joint transforms,
## so it follows the project rule "no skinned rigs". Skin: godot/shaders/god_hand.gdshader (ember-gold, soft
## translucency, rim, shimmer). Fingertips shed ember sparks, more while pinching; the thumb and index tips glow
## hotter when something can be grabbed.
## With controllers only (no hand tracking) a small ember orb stands in for the hand.
## Add it as a child of the XROrigin3D: joint transforms are in the origin's space.

const J_PALM := 0
const J_WRIST := 1
const J_COUNT := 26
const THUMB_TIP := 5
const INDEX_TIP := 10
const TIPS := [5, 10, 15, 20, 25]  # thumb, index, middle, ring, little
# bone chains (joint index lists); a segment joins each neighbouring pair
const CHAINS := [
	[1, 2, 3, 4, 5],  # thumb
	[1, 6, 7, 8, 9, 10],  # index
	[1, 11, 12, 13, 14, 15],  # middle
	[1, 16, 17, 18, 19, 20],  # ring
	[1, 21, 22, 23, 24, 25],  # little
]
const KNUCKLES := [[6, 11], [11, 16], [16, 21]]  # the palm web between the finger bases
const PINCH_NEAR := 0.012  # m between the thumb and index tips that counts as full pinch
const PINCH_FAR := 0.06  # m at which the pinch value is 0
const CHUNK := 0.98  # 2026-11-11 (the user: "they look like gloves, they should be smooth hands"): true to the tracked bone width, no plump padding
const LOST_GRACE := 0.6  # s a hand keeps its last pose when tracking blinks out (the user: "my hands disappear midway")

# palette: fire_yellow FFD45A, lantern_glow F6A45D, fire_red E8452C (never blue)
const SPARK_START := Color8(0xFF, 0xD4, 0x5A, 0xE0)
const SPARK_END := Color8(0xE8, 0x45, 0x2C, 0x00)

var side := "left"  # "left" or "right"
var controller: Node3D  # the GameHand, for the controller-only orb
var tracked := false  # a tracked hand is being drawn
var ever_live := false  # the hand tracker has delivered a live hand at least once (so a lost hand is hidden, never replaced by the controller orb)
var pinch_strength := 0.0  # 0 open .. 1 thumb and index touching (raw, GameHand adds the hysteresis)

var _tracker: XRHandTracker
var _joints: Array[Transform3D] = []
var _radii: Array[float] = []
var _bones: MultiMeshInstance3D
var _balls: MultiMeshInstance3D
var _bone_pairs: Array = []  # [joint a, joint b, base radius or -1 = from joints]
var _ball_joints: Array = []
var _mat: ShaderMaterial
var _sparks: Array[CPUParticles3D] = []
var _tip_glow: Array[MeshInstance3D] = []  # thumb tip, index tip
var _pinch_glow: MeshInstance3D  # where the two tips meet
var _glow_mat: StandardMaterial3D
var _orb: MeshInstance3D
var _hot := false
var _manual := false  # set_pose_from was used: ignore the tracker
var _hot_amount := 0.0
var _lost := 0.0  # seconds without tracking data
var _was_live := false
var _still_t := 0.0  # seconds the tracker's joints have been bit-for-bit unchanged (a frozen last-known pose)
var _spark_boost := false
var _incoming: Array = []


func _ready() -> void:
	_joints.resize(J_COUNT)
	_radii.resize(J_COUNT)
	_incoming.resize(J_COUNT)
	for i in J_COUNT:
		_joints[i] = Transform3D.IDENTITY
		_radii[i] = 0.007
		_incoming[i] = Vector3.ZERO
	_build_pairs()
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/god_hand.gdshader")
	_bones = _make_multimesh(_bone_pairs.size(), _bone_mesh())
	_balls = _make_multimesh(_ball_joints.size(), _ball_mesh())
	add_child(_bones)
	add_child(_balls)
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_glow_mat.albedo_texture = _soft_dot()
	_glow_mat.albedo_color = Color8(0xFF, 0xD4, 0x5A, 0x90)  # palette fire_yellow
	_glow_mat.no_depth_test = false
	for i in 2:
		var g := _glow_sphere(0.007)
		add_child(g)
		_tip_glow.append(g)
	_pinch_glow = _glow_sphere(0.012)
	add_child(_pinch_glow)
	for k in TIPS.size():
		var p := _make_sparks(k < 2)
		add_child(p)
		_sparks.append(p)
	_orb = _glow_sphere(0.014)
	_orb.visible = false
	add_child(_orb)
	visible = true
	_set_tracked(false)


func _build_pairs() -> void:
	_bone_pairs.clear()
	_ball_joints.clear()
	for chain in CHAINS:
		for i in chain.size() - 1:
			_bone_pairs.append([chain[i], chain[i + 1], -1.0])
		for i in range(1, chain.size()):
			if not _ball_joints.has(chain[i]):
				_ball_joints.append(chain[i])
	for k in KNUCKLES:
		_bone_pairs.append([k[0], k[1], 0.0075])
	_ball_joints.append(-1)  # the palm: one flattened blob in the palm joint's frame (no overlapping bars to z-fight)


func _bone_mesh() -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = 1.0  # straight tubes: the joint balls carry the taper, so tube and ball meet without a step
	m.bottom_radius = 1.0
	m.height = 1.0
	m.radial_segments = 10
	m.rings = 1
	m.cap_top = false
	m.cap_bottom = false
	return m


func _ball_mesh() -> Mesh:
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = 12
	m.rings = 6
	return m


func _make_multimesh(count: int, mesh: Mesh) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = _mat
	inst.custom_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))  # the instances move: never cull on the first pose
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst


func _glow_sphere(r: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()  # a soft billboard dot of radius ~r (round at any angle, one cheap quad)
	qm.size = Vector2(r * 4.0, r * 4.0)
	mi.mesh = qm
	mi.material_override = _glow_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _make_sparks(strong: bool) -> CPUParticles3D:
	## Small embers rising off a fingertip. The thumb and index tips are "strong" (they pinch).
	var p := CPUParticles3D.new()
	p.amount = 6
	p.lifetime = 0.8
	p.local_coords = false
	p.direction = Vector3(0, 1, 0)
	p.spread = 55.0
	p.initial_velocity_min = 0.004
	p.initial_velocity_max = 0.02
	p.gravity = Vector3(0, 0.012, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.006, 0.006)
	p.mesh = q
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = _soft_dot()  # a round soft ember, not a square
	p.material_override = sm
	var g := Gradient.new()
	g.colors = PackedColorArray([SPARK_START, SPARK_END])
	p.color_ramp = g
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1))
	sc.add_point(Vector2(1, 0))
	p.scale_amount_curve = sc
	p.emitting = false
	p.set_meta("strong", strong)
	return p


static var _dot_tex: GradientTexture2D


static func _soft_dot() -> GradientTexture2D:
	## A radial white-to-clear gradient, built once and shared (no asset file).
	if _dot_tex == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		g.offsets = PackedFloat32Array([0.0, 1.0])
		_dot_tex = GradientTexture2D.new()
		_dot_tex.gradient = g
		_dot_tex.fill = GradientTexture2D.FILL_RADIAL
		_dot_tex.fill_from = Vector2(0.5, 0.5)
		_dot_tex.fill_to = Vector2(0.5, 0.0)
		_dot_tex.width = 32
		_dot_tex.height = 32
	return _dot_tex


func _tracker_name() -> String:
	return "/user/hand_tracker/" + side


func _process(delta: float) -> void:
	if _manual:  # an explicit pose (shot tool, tests): leave it alone, only animate the glow
		_hot_amount = move_toward(_hot_amount, 1.0 if _hot else 0.0, delta * 6.0)
		_update_glow()
		return
	var ok := false
	if _tracker == null or not is_instance_valid(_tracker):
		_tracker = XRServer.get_tracker(_tracker_name()) as XRHandTracker
	var flags := _tracker.get_hand_joint_flags(XRHandTracker.HAND_JOINT_WRIST) if _tracker != null else 0
	var live := _tracker != null and _tracker.has_tracking_data and (flags & XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED) != 0  # a frozen last-known pose is not live
	if live:
		if _incoming.size() != J_COUNT:
			_incoming.resize(J_COUNT)
		for i in J_COUNT:
			_incoming[i] = _tracker.get_hand_joint_transform(i).origin
		_still_t = still_time(_incoming, _still_t, delta)
		if is_stale(_still_t, controller != null and is_instance_valid(controller) and not controller.get_has_tracking_data()):
			live = false  # frozen past the blink grace AND the aim pose is gone: the hand left tracking, do not keep drawing it
	else:
		_still_t = 0.0
	if live != _was_live:
		_was_live = live
		print("[hand] %s %s (data=%s flags=%d fps=%d)" % [side, "tracked" if live else "LOST", str(_tracker != null and _tracker.has_tracking_data), flags, Engine.get_frames_per_second()])
	if live:
		for i in J_COUNT:
			_joints[i] = _tracker.get_hand_joint_transform(i)
			_radii[i] = maxf(_tracker.get_hand_joint_radius(i), 0.004)
		ok = true
	apply_tracking(ok, delta)
	if ok:
		_pose()
	elif _orb.visible:
		_orb.global_position = controller.global_position  # the controller-only stand-in
	_hot_amount = move_toward(_hot_amount, 1.0 if _hot else 0.0, delta * 6.0)
	_update_glow()


func still_time(origins: Array, prev: float, delta: float) -> float:
	## Seconds the joints have been bit-for-bit the same as the pose held now: a real hand never repeats all 26 joints
	## exactly; a runtime that keeps serving its last pose does.
	for i in J_COUNT:
		if ((origins[i] as Vector3) - _joints[i].origin).length_squared() > 1e-10:
			return 0.0
	return prev + delta


static func is_stale(still_seconds: float, aim_gone: bool) -> bool:
	## Joints frozen longer than the blink grace while the hand's aim pose has no data: the tracker is serving a last-known pose.
	return still_seconds > LOST_GRACE and aim_gone


func apply_tracking(ok: bool, delta: float) -> void:
	## One frame of "is the hand tracked": a lost hand keeps its last pose for LOST_GRACE only, then the whole hand
	## (mesh, glows, sparks, orb) is hidden until tracking returns; it is then drawn at the real pose at once.
	if ok:
		_lost = 0.0
		ever_live = true
	else:
		_lost += delta
	var shown := ok or (tracked and _lost < LOST_GRACE)  # keep drawing the last pose through a short tracking blink
	if shown != tracked:
		_set_tracked(shown)
	_refresh_orb()


func _refresh_orb() -> void:
	## The controller-only stand-in: only while no tracked hand has ever been seen and the controller has a pose. Exactly one
	## representation (tracked hand or orb, never both, never a stale orb for a hand that left tracking).
	var has_data := false
	var on_ctrl := false
	if controller != null and is_instance_valid(controller):
		has_data = controller.get_has_tracking_data()
		on_ctrl = controller.has_method("on_controller") and bool(controller.call("on_controller"))
	var want := orb_wanted(has_data, on_ctrl)
	if _orb != null:
		_orb.visible = want
	visible = tracked or want


func orb_wanted(controller_has_pose: bool, on_real_controller: bool) -> bool:
	## The orb shows for a controller with a pose when no hand is drawn: always for a real controller (also after hands
	## were used), and for a never-tracked hand (the simulator). Back on hands, `tracked` hides it again.
	return not tracked and controller_has_pose and (on_real_controller or not ever_live)


func set_hot(hot: bool) -> void:
	## Something can be grabbed within reach: the thumb and index tips glow hotter.
	_hot = hot


func set_pose_from(joints: Array, radii: Array = []) -> void:
	## Draw an explicit pose (the shot tool and tests). joints = 26 Transform3D in this node's parent space.
	_manual = true
	for i in J_COUNT:
		_joints[i] = joints[i]
		_radii[i] = radii[i] if i < radii.size() else 0.007
	_set_tracked(true)
	_pose()
	_update_glow()


func index_tip_global() -> Vector3:
	return to_global(_joints[INDEX_TIP].origin)


func thumb_tip_global() -> Vector3:
	return to_global(_joints[THUMB_TIP].origin)


func _set_tracked(on: bool) -> void:
	tracked = on
	if _bones == null:
		return
	_bones.visible = on
	_balls.visible = on
	_pinch_glow.visible = on
	for g in _tip_glow:
		g.visible = on
	for s in _sparks:
		s.emitting = on
	_refresh_orb()


func _pose() -> void:
	var bm: MultiMesh = _bones.multimesh
	for n in _bone_pairs.size():
		var pr: Array = _bone_pairs[n]
		var a: Vector3 = _joints[pr[0]].origin
		var b: Vector3 = _joints[pr[1]].origin
		var r: float = pr[2]
		if r < 0.0:
			r = (_radii[pr[0]] + _radii[pr[1]]) * 0.5
		bm.set_instance_transform(n, _segment(a, b, r * CHUNK))
	var gm: MultiMesh = _balls.multimesh
	for n in _ball_joints.size():
		var j: int = _ball_joints[n]
		if j < 0:  # the palm blob: x = width across the knuckles, y = thickness (the joint's +Y points to the back of the hand), z = length
			var pb := _joints[J_PALM].basis.orthonormalized()
			pb = pb * Basis.from_scale(Vector3(0.028, 0.008, 0.034))
			gm.set_instance_transform(n, Transform3D(pb, _joints[J_PALM].origin + _joints[J_PALM].basis.orthonormalized().z * -0.004))
			continue
		# a hair larger than the tubes (x1.06) so the ball and tube surfaces never coincide (no z-fighting at the joints)
		gm.set_instance_transform(n, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _radii[j] * CHUNK * 1.06), _joints[j].origin))
	var d := (_joints[THUMB_TIP].origin - _joints[INDEX_TIP].origin).length()
	pinch_strength = clampf(1.0 - (d - PINCH_NEAR) / (PINCH_FAR - PINCH_NEAR), 0.0, 1.0)
	_mat.set_shader_parameter("pinch", pinch_strength)
	var boost := pinch_strength > 0.5
	for k in _sparks.size():
		var s := _sparks[k]
		s.position = _joints[TIPS[k]].origin
		if bool(s.get_meta("strong")) and boost != _spark_boost:
			s.amount = 14 if boost else 6  # more embers while pinching (set only on a change: it restarts the emitter)
	_spark_boost = boost


func _segment(a: Vector3, b: Vector3, r: float) -> Transform3D:
	## A unit cylinder (radius 1, height 1, along Y) stretched from a to b with radius r.
	var d := b - a
	var len := maxf(d.length(), 0.0005)
	var y := d / len
	var helper := Vector3.RIGHT if absf(y.dot(Vector3.UP)) > 0.9 else Vector3.UP
	var x := helper.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Transform3D(Basis(x * r, y * len, z * r), (a + b) * 0.5)


func _update_glow() -> void:
	if not tracked:
		return
	var heat := 0.6 + _hot_amount * 1.4
	for k in 2:
		var g := _tip_glow[k]
		g.position = _joints[TIPS[k]].origin
		g.scale = Vector3.ONE * (heat + pinch_strength * 0.4)
	var mid := (_joints[THUMB_TIP].origin + _joints[INDEX_TIP].origin) * 0.5
	_pinch_glow.position = mid
	_pinch_glow.scale = Vector3.ONE * (0.2 + pinch_strength * 1.3)
	_pinch_glow.visible = pinch_strength > 0.35


# a plain open hand pointing along -Z at the origin, for the shot tool and tests; curl 0..1 closes the fingers,
# pinch 0..1 brings the thumb tip to the index tip. NOT tracker data: only a stand-in to look at the look.
static func demo_joints(curl: float, pinch: float) -> Array:
	var out: Array = []
	out.resize(J_COUNT)
	out[J_PALM] = Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.045))
	out[J_WRIST] = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	# finger bases across the knuckles (x), bone lengths [meta, prox, inter, distal, tip nub]
	var bases := {6: -0.03, 11: -0.01, 16: 0.011, 21: 0.03}
	var lens := {6: [0.045, 0.04, 0.025, 0.02, 0.012], 11: [0.045, 0.044, 0.028, 0.021, 0.012], 16: [0.042, 0.04, 0.026, 0.02, 0.012], 21: [0.038, 0.03, 0.019, 0.017, 0.011]}
	for base in bases.keys():
		var pos := Vector3(bases[base], 0, 0)
		var ang := 0.0
		for k in 5:
			var step: float = lens[base][k]
			if k >= 1:
				ang += curl * 0.9
			pos += Vector3(0, -sin(ang), -cos(ang)) * step
			out[base + k] = Transform3D(Basis.IDENTITY, pos)
	# thumb: 2..5
	var tp := Vector3(0.03, -0.004, -0.012)
	out[2] = Transform3D(Basis.IDENTITY, tp)
	var dirs := [Vector3(0.5, 0.0, -0.9), Vector3(0.45, -0.02, -0.85), Vector3(0.4, -0.04, -0.8)]
	var tl := [0.035, 0.03, 0.025]
	for k in 3:
		tp += dirs[k].normalized() * tl[k]
		out[3 + k] = Transform3D(Basis.IDENTITY, tp)
	if pinch > 0.0:
		var idx_tip: Vector3 = out[INDEX_TIP].origin
		var thumb_tip: Vector3 = out[THUMB_TIP].origin
		out[THUMB_TIP] = Transform3D(Basis.IDENTITY, thumb_tip.lerp(idx_tip + Vector3(0.006, 0, 0), pinch))
		out[4] = Transform3D(Basis.IDENTITY, (out[3].origin as Vector3).lerp((out[3].origin + out[THUMB_TIP].origin) * 0.5 + Vector3(0, 0.004, 0), pinch * 0.5))
	return out
