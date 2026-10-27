class_name OrbGlow
extends Node3D
## The Wizard Tower's floating power orb (asset list X26): a VFX ball, not a model. It hangs at the model's
## __orb_anchor, bobs, pulses and gives off slow embers. Siddharth 2026-10-27: the orb is the power source. It dims
## while the wizard's staff charges (TowerFx sets `level`) and flares back to full when the shot is released
## (flare()). Magic stays black / orange / red.

var size := 0.012  # diameter, metres (the anchor's ew_size)
var level := 1.0   # 0..1: how full the orb is

var _t := 0.0
var _flare := 0.0
var _core: MeshInstance3D
var _core_mat: StandardMaterial3D
var _heart: MeshInstance3D
var _heart_mat: StandardMaterial3D
var _halo: MeshInstance3D
var _embers: CPUParticles3D
var _tongues: Array[MeshInstance3D] = []
const TONGUES := 5


func setup(diameter: float) -> void:
	size = diameter
	_t = randf() * 10.0
	_core = _ball(size * 0.5, Color("D8481F"))
	_core_mat = _core.material_override
	_heart = _ball(size * 0.3, VfxKit.FIRE_YELLOW)
	_heart.position = Vector3(0, 0, size * 0.28)  # offset toward the viewer's side so the hot heart shows through
	_heart_mat = _heart.material_override
	for i in TONGUES:  # flame tongues licking round the ball
		_tongues.append(VfxKit.halo(self, size * 0.8, Color(VfxKit.FIRE_ORANGE, 0.8), "diamond"))
	_halo = VfxKit.halo(self, size * 3.4, Color(VfxKit.FIRE_ORANGE, 0.4))
	_embers = VfxKit.trail(self, VfxKit.FIRE_YELLOW, VfxKit.FIRE_RED, 7, 0.9, size * 0.2)
	_embers.direction = Vector3.UP
	_embers.spread = 25.0
	_embers.initial_velocity_min = size * 0.4
	_embers.initial_velocity_max = size * 0.9
	_embers.gravity = Vector3.ZERO


func _ball(r: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 10
	sm.rings = 5
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func flare() -> void:
	_flare = 1.0


func _process(delta: float) -> void:
	_t += delta
	_flare = maxf(0.0, _flare - delta * 3.0)
	var lv := clampf(level + _flare * 0.5, 0.0, 1.0)
	position.y = sin(_t * 2.1) * size * 0.2  # bob
	var pulse := 1.0 + 0.07 * sin(_t * 6.0) * lv + _flare * 0.35
	scale = Vector3.ONE * (0.55 + 0.45 * lv) * pulse
	_core_mat.albedo_color = Color("5A1A14").lerp(Color("E2501F"), lv)
	_heart_mat.albedo_color = VfxKit.FIRE_ORANGE.lerp(VfxKit.FIRE_YELLOW, lv)
	VfxKit.set_halo(_halo, size * 3.4 * (0.6 + 0.4 * lv + _flare * 0.5), Color(VfxKit.FIRE_ORANGE, 0.25 + 0.6 * lv))
	for i in _tongues.size():  # flickering flame tongues: they orbit and breathe in and out
		var a := _t * (1.3 + 0.2 * i) + TAU * i / TONGUES
		var flick := 0.6 + 0.4 * sin(_t * (7.0 + i) + i * 2.0)
		var r := size * (0.52 + 0.14 * flick)
		_tongues[i].position = Vector3(cos(a) * r, sin(a * 1.3) * r * 0.9, sin(a) * r * 0.4)
		VfxKit.set_halo(_tongues[i], size * (0.55 + 0.45 * flick) * (0.4 + 0.6 * lv), Color(VfxKit.FIRE_YELLOW.lerp(VfxKit.FIRE_RED, 0.4 * (1.0 - flick)), 0.85 * lv))
	_embers.emitting = lv > 0.3
