class_name BossVfx
extends Node3D
## Skotos' effects (the Warden, E08; Siddharth 2026-11-17/18: phases 1-3 are a reskin, "Groot-like" wood growth, glow
## stays Warden purple with ember-red sparks, never blue, never glowing geometry). Lives on the boss Enemy; built on the
## model's anchors (eye_l/eye_r, chest_knot, band_1..4, hand_l/hand_r, fan, roots) as billboard glows and a few cheap
## particle emitters. The static helpers (telegraph, root_mound, root_spike, leaf_swirl) are shared with Warden.
## Logged in docs/VFX_NOTES.md. Everything is capped: no per-frame allocation, one-shot effects share VfxKit's burst cap.

const PURPLE := Color("9C3EB0")   # palette crystal_purple: the Warden
const BRIGHT := Color("C77CF0")   # lighter purple for glow cores
const HOT := Color("EBC4FF")      # eye cores: almost white-lilac
const DEEP := Color("3B1F5C")
const RED := Color("E8452C")
const EMBER := Color("F6A45D")
const MAROON := Color("7A2318")
const DIRT := Color(0.36, 0.25, 0.17)
const BARK := Color(0.20, 0.14, 0.10)
const BARK_LIGHT := Color(0.42, 0.30, 0.20)
const LEAF_A := Color(0.42, 0.50, 0.22)
const LEAF_B := Color(0.55, 0.36, 0.18)
const MAX_GROUND_FX := 10
const EYE_FORWARD := 0.02
const RIM_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform vec4 rim_color : source_color = vec4(0.6, 0.25, 0.8, 1.0);
uniform float strength = 0.5;
void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.5);
	ALBEDO = rim_color.rgb * f * strength;
}
"""
static var _rim_shader: Shader

static var _ground_fx := 0
static var _bark_mat: StandardMaterial3D
static var _dirt_mat: StandardMaterial3D

var boss: Enemy
var form := -1

var _eyes: Array[MeshInstance3D] = []
var _eye_glows: Array[MeshInstance3D] = []
var _bands: Array[MeshInstance3D] = []
var _chest: MeshInstance3D
var _hands: Array[MeshInstance3D] = []
var _live: Array[Node] = []
var _t := 0.0
var _pulse_t := 0.0
var _cast := 0.0  # seconds of casting left: the hands glow, the arms rise
var _cast_len := 1.0
var _flare := 0.0  # a phase change or a hit: everything brightens, then settles
var _rage := 0.0   # 0 calm -> 1 enraged (form 3 and up): red-shifted, faster, roots erupt
var _erupt_t := 2.0
var _splinter_t := 1.0
var _sizes := {}
var _rim: ShaderMaterial  # the purple fresnel rim on the body (separates the dark crown and arms from the night sky)


func setup(b: Enemy) -> void:
	boss = b
	boss.add_child(self)
	enter_form(0)


func enter_form(i: int, announce := false) -> void:
	form = i
	for n in _live:
		if is_instance_valid(n):
			n.queue_free()
	_live.clear()
	_eyes.clear()
	_eye_glows.clear()
	_bands.clear()
	_hands.clear()
	_chest = null
	_sizes.clear()
	_rage = 1.0 if form >= 2 else 0.0
	var rig: CharacterRig = boss._rig
	if rig == null or rig.model == null:
		return
	for side in ["eye_l", "eye_r"]:
		var at := rig.marker(side + "_anchor")
		if at:
			var sz := _size(at, 0.012)
			_eye_glows.append(_halo(at, sz * 3.2, Color(PURPLE, 0.5)))
			_eyes.append(_halo(at, sz * 1.05, Color(HOT, 0.95), "disc"))
			for h in [_eye_glows[-1], _eyes[-1]]:
				if form >= 2:  # P3: the discs sat low and squashed in the sockets: raise them and space them apart
					h.position = Vector3(signf(at.position.x) * 0.004, 0.005, EYE_FORWARD + 0.01)
				else:
					h.position.z = EYE_FORWARD  # the anchor sits in the dark socket: bring the glow out in front of the visor so the face reads
			var sp := VfxKit.trail(at, RED, MAROON, 4, 0.9, 0.0035)  # ember-red sparks drift off the eyes
			sp.gravity = Vector3(0, 0.01, 0)
			sp.spread = 90.0
			_live.append(sp)
	var ck := rig.marker("chest_knot_anchor")
	if ck:
		_chest = _halo(ck, _size(ck, 0.02) * 2.6, Color(BRIGHT, 0.45))
	for k in 4:
		if form >= 2 and k > 0:  # P3 is a skeletal tree: bands 2-4 float where the tiers fell away, no glow
			continue
		var b := rig.marker("band_%d_anchor" % (k + 1))
		if b:
			_bands.append(_halo(b, _size(b, 0.022) * 3.0, Color(PURPLE, 0.3)))
	for side in ["hand_l", "hand_r"]:
		var h := rig.marker(side + "_anchor")
		if h:
			_hands.append(_halo(h, _size(h, 0.024) * 2.4, Color(BRIGHT, 0.0)))
	var fan := rig.marker("fan_anchor")
	if fan:  # faint rim motes drifting off the leaf fan
		var m := VfxKit.trail(fan, BRIGHT, DEEP, 5, 1.8, 0.003)
		m.gravity = Vector3(0, 0.006, 0)
		m.spread = 180.0
		m.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		m.emission_sphere_radius = _size(fan, 0.045) * 0.5
		_live.append(m)
	if _rage > 0.0:  # enraged: bark splinters stream off the shoulders
		var rt := rig.marker("band_4_anchor")
		if rt:
			var sp2 := VfxKit.trail(rt, BARK_LIGHT, BARK, 9, 1.0, 0.004)
			sp2.gravity = Vector3(0, -0.03, 0)
			sp2.material_override = VfxKit.material("diamond", true, false)
			_live.append(sp2)
	_apply_rim(rig)
	rig.fury = _rage
	if announce:
		transition()


func _apply_rim(rig: CharacterRig) -> void:
	## A subtle purple fresnel rim on every body surface (one extra additive pass on the boss only), stronger in P3.
	if _rim_shader == null:
		_rim_shader = Shader.new()
		_rim_shader.code = RIM_SHADER_CODE
	_rim = ShaderMaterial.new()
	_rim.shader = _rim_shader
	for n in ModelUtil.walk(rig.model):
		if n is MeshInstance3D:
			for i in n.mesh.get_surface_count():
				var base: Material = n.get_active_material(i)
				if base is StandardMaterial3D or base is BaseMaterial3D:
					var d: Material = base.duplicate()
					d.next_pass = _rim
					n.set_surface_override_material(i, d)


func _size(n: Node, fallback: float) -> float:
	return float(n.get_meta("ew_size", fallback))


func _halo(at: Node3D, size: float, col: Color, shape := "glow") -> MeshInstance3D:
	var h := VfxKit.halo(at, size, col, shape)
	_sizes[h] = size
	_live.append(h)
	return h


func cast(seconds := 1.2) -> void:
	## The hands glow and the arms rise (a summon, a shield, a roar).
	_cast = seconds
	_cast_len = seconds


func hit_pulse() -> void:
	_pulse_t = 0.18


func transition() -> void:
	## The change of form (shed and grow): a purple flash, rings, a burst of leaves and bark, roots erupting round him.
	var root := boss.get_parent()
	if root == null or not boss.is_inside_tree():
		return
	_flare = 1.3
	cast(1.4)
	var at := boss.global_position + Vector3(0, 0.12, 0)
	VfxKit.flash(root, at, Color(BRIGHT, 0.65), 0.24, 0.4)
	for k in 3:
		get_tree().create_timer(0.12 * k).timeout.connect(func():
			if is_instance_valid(boss) and boss.is_inside_tree():
				VfxKit.ring(root, boss.global_position, Color(PURPLE if k % 2 == 0 else BRIGHT, 0.9), 0.16 + 0.05 * k, 0.7))
	VfxKit.burst(root, at, LEAF_A, LEAF_B, 30, 0.10, 1.0, 0.008, -0.03, false)
	VfxKit.burst(root, at, BARK_LIGHT, BARK, 22, 0.12, 0.8, 0.006, -0.15, false)
	for k in 5:
		var a := TAU * k / 5.0 + randf() * 0.4
		root_spike(root, boss.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(0.15, 0.22))


func _process(delta: float) -> void:
	_t += delta
	_pulse_t = maxf(0.0, _pulse_t - delta)
	_flare = maxf(0.0, _flare - delta / 1.2)
	_cast = maxf(0.0, _cast - delta)
	var rig: CharacterRig = boss._rig if is_instance_valid(boss) else null
	var c := _cast / maxf(_cast_len, 0.01)
	var cast_k := sin(PI * clampf(1.0 - c, 0.0, 1.0)) if _cast > 0.0 else 0.0  # rises, holds, falls
	if boss.attacking:
		cast_k = maxf(cast_k, 0.6 + 0.4 * sin(_t * 6.0))
	if rig:
		rig.act_k = lerpf(rig.act_k, cast_k, clampf(delta * 6.0, 0.0, 1.0))
	var k := 1.0 + 0.9 * _pulse_t / 0.18 + _flare
	var col_main := PURPLE.lerp(RED, 0.45 * _rage)
	var col_eye := HOT.lerp(Color("FF8A5C"), 0.6 * _rage)
	if _rim:
		_rim.set_shader_parameter("strength", (0.25 + 0.5 * _rage) * (1.0 + 0.8 * _flare))
	var flick := 0.85 + 0.15 * sin(_t * 7.0) * sin(_t * 2.3)
	for i in _eyes.size():
		_glow(_eyes[i], 1.0 + 0.25 * _flare, Color(col_eye, minf(1.0, 0.9 * flick * (0.9 + 0.4 * _flare))))
		_glow(_eye_glows[i], k * (1.0 + 0.1 * _rage), Color(col_main.lightened(0.15), minf(0.9, (0.45 - 0.2 * _rage) * flick * k)))  # P3: a thin glow, the pink haze used to cover the face
	if _chest:
		var beat := pow(0.5 + 0.5 * sin(_t * (2.2 + 1.6 * _rage)), 3.0)
		_glow(_chest, (1.0 + 0.35 * beat) * (1.0 + 0.5 * _flare), Color(col_main.lightened(0.25), minf(0.9, 0.35 + 0.35 * beat + 0.3 * _flare)))
	for i in _bands.size():
		var ph := 0.5 + 0.5 * sin(_t * (1.5 + _rage) - i * 0.9)
		_glow(_bands[i], 1.0 + 0.2 * ph + 0.5 * _flare, Color(col_main, minf(0.9, 0.18 + 0.28 * ph + 0.35 * _rage + 0.4 * _flare)))
	for h in _hands:
		var a := 0.06 + 0.8 * cast_k + 0.3 * _rage
		_glow(h, 1.0 + 0.6 * cast_k + 0.4 * _flare, Color(BRIGHT.lerp(RED, 0.3 * _rage), minf(a, 0.95)))
	if _rage > 0.0 and boss.is_inside_tree():
		var root := boss.get_parent()
		_erupt_t -= delta
		if _erupt_t <= 0.0 and root:  # roots erupt around him now and then (cosmetic)
			_erupt_t = randf_range(2.0, 3.4)
			var a := randf() * TAU
			root_spike(root, boss.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(0.16, 0.26))
		_splinter_t -= delta
		if _splinter_t <= 0.0 and root:
			_splinter_t = randf_range(1.0, 1.8)
			VfxKit.burst(root, boss.global_position + Vector3(0, 0.15, 0), BARK_LIGHT, BARK, 8, 0.09, 0.7, 0.005, -0.2, false)


func _glow(h: MeshInstance3D, factor: float, col: Color) -> void:
	VfxKit.set_halo(h, _sizes[h] * factor, col)


# ---------------------------------------------------------------- shared one-shots

static func _bark() -> StandardMaterial3D:
	if _bark_mat == null:
		_bark_mat = ModelUtil.flat_material(BARK)
	return _bark_mat


static func _dirt() -> StandardMaterial3D:
	if _dirt_mat == null:
		_dirt_mat = ModelUtil.flat_material(DIRT)
	return _dirt_mat


static func _gone() -> void:
	_ground_fx = maxi(0, _ground_fx - 1)


static func telegraph(root: Node, world_pos: Vector3, radius: float, seconds: float) -> void:
	## A purple ring on the ground that fades in, pulses, and goes: where the roots will push up.
	if root == null or not root.is_inside_tree() or _ground_fx >= MAX_GROUND_FX:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = VfxKit.quad(1.0)
	var m: StandardMaterial3D = VfxKit.material("ring").duplicate()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	m.albedo_color = Color(PURPLE, 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.global_position = world_pos + Vector3(0, 0.002, 0)
	mi.rotation.x = -PI / 2.0
	mi.scale = Vector3.ONE * radius * 2.0
	_ground_fx += 1
	mi.tree_exited.connect(_gone)
	var tw := mi.create_tween()
	tw.tween_method(func(k: float):
		var pulse := 0.75 + 0.25 * sin(k * seconds * 9.0)
		m.albedo_color = Color(BRIGHT, 0.85 * pulse * minf(1.0, k * 5.0) * (1.0 - 0.6 * pow(k, 4.0)))
		mi.scale = Vector3.ONE * radius * 2.0 * (1.15 - 0.15 * k), 0.0, 1.0, seconds)
	tw.tween_callback(mi.queue_free)


static func root_mound(root: Node, world_pos: Vector3, size := 0.02) -> void:
	## A mound of earth with three root tips pushes up out of the ground with a dirt and bark burst; it settles back.
	## Grunts rise out of these (the summons).
	if root == null or not root.is_inside_tree() or _ground_fx >= MAX_GROUND_FX:
		return
	var holder := Node3D.new()
	root.add_child(holder)
	holder.global_position = world_pos
	var mound := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 1.2
	sm.radial_segments = 8
	sm.rings = 3
	sm.is_hemisphere = true
	mound.mesh = sm
	mound.material_override = _dirt()
	holder.add_child(mound)
	for k in 3:
		var tip := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = size * 0.04
		cm.bottom_radius = size * 0.28
		cm.height = size * 1.5
		cm.radial_segments = 5
		cm.rings = 1
		tip.mesh = cm
		tip.material_override = _bark()
		var a := TAU * k / 3.0 + 0.5
		tip.position = Vector3(cos(a), 0.4, sin(a)) * size * 0.7
		tip.rotation = Vector3(sin(a) * 0.7, 0, -cos(a) * 0.7)
		holder.add_child(tip)
	holder.scale = Vector3(1, 0.05, 1)
	_ground_fx += 1
	holder.tree_exited.connect(_gone)
	var tw := holder.create_tween()
	tw.tween_property(holder, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.7)
	tw.tween_property(holder, "position:y", holder.position.y - size * 1.4, 0.5)
	tw.tween_callback(holder.queue_free)
	VfxKit.burst(root, world_pos + Vector3(0, size * 0.5, 0), DIRT.lightened(0.2), DIRT, 12, 0.06, 0.55, 0.005, -0.2, false)
	VfxKit.burst(root, world_pos + Vector3(0, size * 0.6, 0), BARK_LIGHT, BARK, 7, 0.08, 0.5, 0.004, -0.2, false)


static func root_spike(root: Node, world_pos: Vector3) -> void:
	## A big root erupts from the ground and sinks back (phase 3, looks only).
	if root == null or not root.is_inside_tree() or _ground_fx >= MAX_GROUND_FX:
		return
	var holder := Node3D.new()
	root.add_child(holder)
	holder.global_position = world_pos
	var tip := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0015
	cm.bottom_radius = 0.009
	cm.height = 0.07
	cm.radial_segments = 6
	cm.rings = 1
	tip.mesh = cm
	tip.material_override = _bark()
	tip.position.y = 0.03
	holder.rotation = Vector3(randf_range(-0.35, 0.35), randf() * TAU, randf_range(-0.35, 0.35))
	holder.add_child(tip)
	holder.scale = Vector3(1, 0.05, 1)
	_ground_fx += 1
	holder.tree_exited.connect(_gone)
	var tw := holder.create_tween()
	tw.tween_property(holder, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(holder, "scale", Vector3(1, 0.05, 1), 0.4)
	tw.tween_callback(holder.queue_free)
	VfxKit.burst(root, world_pos + Vector3(0, 0.01, 0), DIRT.lightened(0.2), DIRT, 10, 0.06, 0.5, 0.005, -0.2, false)
	VfxKit.burst(root, world_pos + Vector3(0, 0.02, 0), Color(PURPLE, 0.9), DEEP, 5, 0.04, 0.5, 0.004, 0.0)


static func leaf_swirl(root: Node, world_pos: Vector3) -> void:
	## Leaves swirl up where a Wisp rises from the tree line.
	if root == null or not root.is_inside_tree():
		return
	VfxKit.burst(root, world_pos + Vector3(0, 0.01, 0), LEAF_A, LEAF_B, 14, 0.05, 0.9, 0.005, 0.03, false)
	VfxKit.burst(root, world_pos + Vector3(0, 0.02, 0), Color(BRIGHT, 0.8), DEEP, 5, 0.03, 0.7, 0.004, 0.02)
