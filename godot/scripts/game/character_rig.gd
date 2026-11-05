class_name CharacterRig
extends Node3D
## One of Durva's models with its tween-free procedural animation (no skinned rig: each moving part is turned about its
## pivot every frame). Purely cosmetic, it never changes a gameplay number. Forward is +Z. Whoever owns it sets `anim` and
## `gait`; hit(), rise(), sink() and die() are one-shots.
##   anim for people   idle, walk, startle, fork, hammer, roll, dance, read, sew, water, sweep, tend, talk, wave, cheer, channel,
##                     crew_wizard, crew_archer, crew_guard (these read `act_k`, 0 -> 1 -> 0 over a shot)
##   anim for enemies  walk, attack, idle
## Walking people either hop (the art bible's way) or step their legs: `step_legs`, press G in the game to compare.

const RUN_SPEED := 6.0  # cells per second at which `gait` counts as a full sprint

static var step_legs := false
static var _flash_mat: StandardMaterial3D
static var _mist_mat: StandardMaterial3D
static var _scenes := {}  # model path -> PackedScene: enemies spawn in clusters, so a load must not hitch

var key := ""
var family := "char"  # char, bark (Grunt), veil (Scout), spore (Splitter), lantern (Wisp), drill (Tunneler)
var anim := "idle"
var gait := 0.0  # how fast it is moving, cells per second
var act_k := 0.0
var model: Node3D
var parts := {}

var _home := {}  # part -> Transform3D
var _meshes: Array[MeshInstance3D] = []
var _t := 0.0
var _phase := 0.0
var _hit := 0.0
var _rise := 1.0
var _rise_rate := 0.0
var _dying := -1.0
var _flash := 0.0
var _misty := false
# this frame's pose
var _al := Vector3.ZERO
var _ar := Vector3.ZERO
var _ll := Vector3.ZERO
var _lr := Vector3.ZERO
var _hd := Vector3.ZERO
var _it := Vector3.ZERO  # the tool in the right hand
var _body := Vector3.ZERO  # lean of the whole model
var _lift := 0.0
var _fwd := 0.0
var _sq := 1.0  # squash (< 1) and stretch (> 1)


static func model_path(model_key: String) -> String:
	if model_key in ["blightbark", "veilrunner", "sporebloom", "sporebud", "lantern_spirit", "mawdrill", "shroom_goblin"]:
		return "res://assets/enemy/ew_enemy_%s_v01.glb" % model_key
	return "res://assets/village/ew_village_%s_v01.glb" % model_key


func setup(model_key: String, rig_family := "char") -> void:
	key = model_key
	family = rig_family
	_t = randf() * 20.0
	_phase = randf() * TAU
	var path := model_path(key)
	if not _scenes.has(path):
		_scenes[path] = load(path)
	model = _scenes[path].instantiate()
	add_child(model)
	parts = ModelUtil.parts(model)
	for p in parts:
		_home[p] = parts[p].transform
	for n in ModelUtil.walk(model):
		if n is MeshInstance3D:
			_meshes.append(n)


func marker(suffix: String) -> Marker3D:
	for n in ModelUtil.walk(model):
		if n is Marker3D and str(n.name).ends_with(suffix):
			return n
	return null


# ---------------------------------------------------------------- one-shots

func hit() -> void:
	_hit = 0.16
	_flash = 0.08
	_overlay(_flash_material())


func set_misty() -> void:
	## The Fog variant: the Grunt under a pale veil (decided: a tint, no model of its own).
	_misty = true
	_overlay(_mist_material())


func rise(seconds := 0.5) -> void:
	## Comes up out of the ground.
	_rise = 0.0
	_rise_rate = 1.0 / seconds


func sink(seconds := 0.4) -> void:
	## Goes back down and frees itself.
	_rise_rate = -1.0 / seconds


func die() -> void:
	## Topples and shrinks away, then frees itself (Enemy hands it to the board first).
	_dying = 0.0
	_overlay(null if not _misty else _mist_material())


func _overlay(mat: Material) -> void:
	for m in _meshes:
		m.material_overlay = mat


static func _flash_material() -> StandardMaterial3D:
	if _flash_mat == null:
		_flash_mat = ModelUtil.flat_material(Color8(0xFF, 0xE6, 0xC8), true, 0.75)
	return _flash_mat


static func _mist_material() -> StandardMaterial3D:
	if _mist_mat == null:
		_mist_mat = ModelUtil.flat_material(Color(0.62, 0.62, 0.64), true, 0.6)
	return _mist_mat


# ---------------------------------------------------------------- every frame

func _process(delta: float) -> void:
	if visible and is_visible_in_tree():
		tick(delta)


func tick(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_overlay(_mist_material() if _misty else null)
	_al = Vector3.ZERO
	_ar = Vector3.ZERO
	_ll = Vector3.ZERO
	_lr = Vector3.ZERO
	_hd = Vector3.ZERO
	_it = Vector3.ZERO
	_body = Vector3.ZERO
	_lift = 0.0
	_fwd = 0.0
	_sq = 1.0
	if family == "char":
		_person(delta)
	else:
		_creature(delta)
	if _hit > 0.0:
		_hit = maxf(0.0, _hit - delta)
		var k := sin(PI * _hit / 0.16)
		_body.x -= 0.35 * k
		_sq -= 0.1 * k
		_hd.x -= 0.3 * k
	if _rise_rate != 0.0:
		_rise = clampf(_rise + _rise_rate * delta, 0.0, 1.0)
		if _rise >= 1.0:
			_rise_rate = 0.0
		elif _rise <= 0.0 and _rise_rate < 0.0:
			queue_free()
			return
	if _dying >= 0.0:
		_dying += delta / 0.4
		if _dying >= 1.0:
			queue_free()
			return
		var f := _dying * _dying
		_body.x = -1.5 * f  # falls on its back
		_sq = 1.0 - 0.3 * f
		model.scale = Vector3.ONE * (1.0 - f)
	else:
		var side := 1.0 / sqrt(maxf(_sq, 0.1))
		model.scale = Vector3(side, _sq, side)
	model.position = Vector3(0, _lift - (1.0 - _rise) * 0.07, _fwd)
	model.rotation = _body
	_pose("head", _hd)
	_pose("arm_l", _al)
	_pose("arm_r", _ar)
	_pose("leg_l", _ll)
	_pose("leg_r", _lr)
	_pose("item", _it)
	_secondary()


func _pose(part: String, euler: Vector3) -> void:
	if parts.has(part):
		parts[part].transform = _home[part] * Transform3D(Basis.from_euler(euler))


func _person(delta: float) -> void:
	var t := _t
	if gait > 0.0:
		_gait_person(delta)
	else:
		_sq = 1.0 + 0.012 * sin(t * 2.2)
		_hd.y = 0.3 * sin(t * 0.7) + 0.15 * sin(t * 1.9)
		_hd.x = 0.05 * sin(t * 1.1)
		_al.z = 0.05 + 0.03 * sin(t * 1.3)
		_ar.z = -0.05 - 0.03 * sin(t * 1.3)
	match anim:
		"startle":  # jumps, arms up
			_lift = 0.014 * absf(sin(t * 12.0))
			_al.z = 1.6  # the arms are short and the heads big: straight up would hide them behind the head
			_ar.z = -1.6
			_hd.x = -0.2
		"fork":  # digs in, lifts and tosses
			var c := sin(t * 2.4)
			_ar.x = -0.7 - 0.7 * c
			_al.x = -0.5 - 0.5 * c
			_body.x = 0.18 + 0.16 * c
			_hd.x = 0.2 * c
		"hammer":  # slow up, fast strike
			var a := fposmod(t * 1.5, 1.0)
			var k := a / 0.7 if a < 0.7 else 1.0 - (a - 0.7) / 0.3
			_ar.x = -0.3 - 1.25 * k
			_ar.z = -0.45
			_body.x = 0.2 * (1.0 - k)
			_hd.x = 0.08
			_al.x = -0.4
		"roll":  # both hands push the rolling pin
			var c := sin(t * 2.8)
			_al.x = -1.2 - 0.35 * c
			_ar.x = -1.2 - 0.35 * c
			_body.x = 0.14 + 0.1 * c
			_hd.x = 0.08
		"dance":  # twirls with the arms up, then a little hold
			var spin := fposmod(t * 0.5, 1.0)
			_body.y = TAU * smoothstep(0.1, 0.65, spin)
			_lift = 0.005 * absf(sin(t * 5.0))
			_sq = 1.0 + 0.05 * sin(t * 5.0)
			_al.z = 1.5 + 0.3 * sin(t * 5.0)
			_ar.z = -1.5 + 0.3 * sin(t * 5.0)
			_hd.z = 0.15 * sin(t * 2.5)
		"read":  # holds the scroll up, the head follows the lines
			_ar.x = -1.25
			_al.x = -1.1
			_hd.x = 0.08 + 0.04 * sin(t * 6.0)
			_hd.y = 0.14 * sin(t * 1.6)
		"sew":  # quick little stitches
			_ar.x = -1.1 + 0.28 * sin(t * 8.0)
			_ar.z = 0.25 * sin(t * 4.0)
			_al.x = -1.0
			_hd.x = 0.08
		"water":  # tips its tool over the flowers, sways
			_ar.x = -1.0 + 0.3 * sin(t * 2.0)
			_ar.z = -0.3 * sin(t * 1.0)
			_body.z = 0.05 * sin(t * 1.0)
			_hd.x = 0.08
		"sweep":  # side to side, leaning
			var c := sin(t * 3.0)
			_al.x = -0.8
			_ar.x = -0.8
			_al.z = 0.45 * c
			_ar.z = 0.45 * c
			_body.z = 0.08 * c
			_body.x = 0.15
			_hd.x = 0.05
		"tend":  # bends down to work, up to rest
			var k := 0.5 + 0.5 * sin(t * 1.4)
			_body.x = 0.5 * k
			_al.x = -0.9 * k
			_ar.x = -1.1 * k + 0.2 * sin(t * 7.0) * k
			_sq = 1.0 - 0.06 * k
		"talk":  # nods, and one hand explains
			_hd.x = 0.1 * sin(t * 3.1)
			_hd.y = 0.16 * sin(t * 1.3)
			_al.x = -0.9 + 0.35 * sin(t * 3.7)
			_al.z = 0.25 + 0.2 * sin(t * 2.3)
			_body.z = 0.03 * sin(t * 1.3)
		"wave":  # please help
			_al.z = 1.65 + 0.35 * sin(t * 9.0)
			_hd.x = -0.15
			_lift = 0.002 * absf(sin(t * 4.5))
		"cheer":
			_lift = 0.012 * absf(sin(t * 8.0))
			_sq = 1.0 + 0.08 * cos(t * 16.0)
			_al.z = 1.6 + 0.3 * sin(t * 16.0)
			_ar.z = -1.6 + 0.3 * sin(t * 16.0)
			_hd.x = -0.25
		"channel":  # raises its tool high and holds it, sending energy to the seed under the island
			_ar.x = -1.75 + 0.08 * sin(t * 9.0)
			_ar.z = -0.8  # out to the side: straight up would hide it behind the big head
			_it = Basis.from_euler(_ar).inverse().get_euler()  # the tool stays upright in the raised hand, or the arm tips it flat
			_al.x = -0.9
			_al.z = 0.5
			_hd.x = -0.12
			_sq = 1.03
			_lift = 0.0012 * sin(t * 6.0)
		"crew_wizard":
			_al.x = -0.5 + 0.45 * sin(t * 1.4) - 1.0 * act_k
			_al.z = 0.35 + 0.2 * sin(t * 0.9)
			_ar.x = -0.5 + 0.1 * sin(t * 1.1) - 0.9 * act_k
			_hd.y = 0.25 * sin(t * 0.7)
		"crew_archer":
			var crank := sin(t * 3.2)
			_al.x = -1.1 + 0.5 * crank - 0.5 * act_k
			_ar.x = -1.1 - 0.5 * crank - 0.5 * act_k
			_body.x = 0.05 * crank + 0.18 * act_k
		"crew_guard":
			_al.x = -0.15 + 0.1 * sin(t * 1.3)
			_ar.x = -0.6 + 0.05 * sin(t * 0.9) - 1.25 * act_k  # a thrust
			_body.x += 0.2 * act_k
			_hd.y = 0.35 * sin(t * 0.6)


func _gait_person(delta: float) -> void:
	var sp := clampf(gait / RUN_SPEED, 0.0, 1.0)
	_phase += delta * TAU * lerpf(1.9, 4.8, sp)
	var s := sin(_phase)
	if step_legs:
		var swing := lerpf(0.55, 1.1, sp)
		_ll.x = swing * s
		_lr.x = -swing * s
		_lift = lerpf(0.0012, 0.003, sp) * absf(cos(_phase))
	else:
		var a := absf(s)
		_lift = lerpf(0.004, 0.012, sp) * a
		_sq = lerpf(0.9, 1.06, a)
		_ll.x = -0.35 * a * sp
		_lr.x = 0.35 * a * sp
	var arm := lerpf(0.45, 1.0, sp)
	_al.x = -arm * s
	_ar.x = arm * s
	_al.z = sp * (0.55 + 0.3 * sin(_phase * 1.7))  # the arms flail on a sprint
	_ar.z = -sp * (0.55 + 0.3 * cos(_phase * 1.3))
	_it = Vector3(-_ar.x * 0.85, 0, -_ar.z * 0.85)  # carries its tool upright, not as a lance
	_body.x = lerpf(0.06, 0.4, sp)
	_hd.x = -_body.x * 0.6
	_hd.y = 0.5 * sp * sin(_t * 3.0)  # and it looks back over its shoulder


func _creature(delta: float) -> void:
	var moving := anim == "walk"
	var attack := anim == "attack"
	_phase += delta * TAU * (1.5 + gait)
	var s := sin(_phase)
	var a := fposmod(_t * 1.1, 1.0)  # the attack beat: a slow wind-up, then a fast blow
	var blow := a / 0.72 if a < 0.72 else 1.0 - (a - 0.72) / 0.28
	var strike := 1.0 - blow if a >= 0.72 else 0.0
	match family:
		"bark":  # stomps on its root legs, swings the thorn club
			if moving:
				_ll.x = 0.6 * s
				_lr.x = -0.6 * s
				_body.z = 0.09 * s
				_lift = 0.002 * absf(cos(_phase))
				_al.x = -0.3 * s
				_ar.x = 0.25 * s
			_hd.y = 0.2 * sin(_t * 0.9)
			if attack:
				_ar.x = -2.3 * blow
				_body.x = 0.3 * strike
				_hd.x = 0.3 * strike
		"veil":  # glides on its streaming veil, blades out
			_lift = 0.0025 + 0.0015 * sin(_t * 3.0)
			_body.x = 0.22 if moving else 0.05
			_al.x = -0.45 + 0.15 * s
			_ar.x = -0.45 - 0.15 * s
			if attack:
				var left := fposmod(_t * 0.55, 1.0) < 0.5
				_al.x = -1.6 * blow if left else -0.4
				_ar.x = -1.6 * blow if not left else -0.4
				_body.y = (0.35 if left else -0.35) * strike
		"spore":  # waddles, swaying its heavy double cap
			if moving:
				_body.z = 0.16 * s
				_lift = 0.0025 * absf(s)
				_sq = 1.0 - 0.03 * absf(s)
			else:
				_sq = 1.0 + 0.02 * sin(_t * 2.0)
			_al.x = -0.3 * s
			if attack:  # blows the spore flute in pulses
				_ar.x = -1.4
				_sq = 1.0 + 0.2 * strike - 0.1 * blow
				_body.x = 0.3 * strike
		"lantern":  # hovers, and dives at what it attacks
			_lift = 0.002 * sin(_t * 2.3)
			_body.x = 0.12 if moving else 0.0
			_body.z = 0.06 * sin(_t * 1.7)
			if attack:
				_body.x = 0.55 * strike
				_fwd = 0.012 * strike
		"drill":  # wriggles on its claw legs, jabs the drill forward
			_body.y = 0.07 * s
			_lift = 0.001 * absf(s)
			if attack:
				_fwd = 0.022 * strike
				_body.x = 0.2 * strike


func _secondary() -> void:
	## The little things that are always alive: tails, wings, ears, feelers, veils.
	var t := _t
	var rush := clampf(gait / RUN_SPEED, 0.0, 1.0)
	if parts.has("tail"):
		_pose("tail", Vector3(0.08 * sin(t * 1.7), (0.3 + 0.3 * rush) * sin(t * (2.6 + 6.0 * rush)), 0))
	if parts.has("wing_l"):
		var hz := 13.0 if family == "lantern" or rush > 0.3 else 3.0
		var w := (0.4 if hz > 5.0 else 0.18) * sin(t * hz)
		_pose("wing_l", Vector3(0, w, 0))
		_pose("wing_r", Vector3(0, -w, 0))
	if parts.has("ear_l"):
		var tw := 0.12 * maxf(0.0, sin(t * 0.9) - 0.75) * 4.0
		_pose("ear_l", Vector3(-0.5 * rush, 0, -tw))
		_pose("ear_r", Vector3(-0.5 * rush, 0, tw))
	if parts.has("ant_l"):
		_pose("ant_l", Vector3(0.14 * sin(t * 3.1), 0, 0.1 * sin(t * 1.9)))
		_pose("ant_r", Vector3(0.14 * sin(t * 2.7), 0, -0.1 * sin(t * 2.2)))
	if parts.has("hair_back"):
		_pose("hair_back", Vector3(-0.5 * rush + 0.04 * sin(t * 2.0), 0, 0))
	if parts.has("spider"):
		_pose("spider", Vector3(0.08 * sin(t * 2.4) + 0.2 * rush * sin(t * 15.0), 0, 0))
	if parts.has("web"):
		_pose("web", Vector3(0.04 * sin(t * 1.3), 0, 0.04 * sin(t * 1.1)))
	if parts.has("rings"):
		_pose("rings", Vector3(0, t * (6.0 if anim == "attack" else 3.0), 0))
	if parts.has("veil"):
		_pose("veil", Vector3(0.18 * sin(t * 4.0), 0.14 * sin(t * 2.6), 0))
	if parts.has("spores"):
		_pose("spores", Vector3(0, t * 1.4, 0))
	if parts.has("drill"):
		_pose("drill", Vector3(0, 0, t * (26.0 if anim == "attack" else 14.0)))
	if parts.has("jaw_l"):
		var j := 0.28 * sin(t * (12.0 if anim == "attack" else 6.0))
		_pose("jaw_l", Vector3(0, j, 0))
		_pose("jaw_r", Vector3(0, -j, 0))
