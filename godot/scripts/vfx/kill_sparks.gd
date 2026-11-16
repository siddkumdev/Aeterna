class_name KillSparks
extends Node3D
## Kill reward spark (Siddharth 2026-11-16), looks only: when an enemy dies a small spark in the magic palette (fire_yellow /
## lantern_glow / fire_red, never blue) pops out of the body and flies in an arc to the nearest standing house, which glows
## softly when it arrives. It changes no faith, damage or timing. A fixed pool of MAX sparks, built once; nothing is allocated
## per frame, and a kill while the pool is busy simply gets no spark.

const MAX := 8
const FLIGHT := 0.7
const LIFT := 0.12          # how high the arc rises above the straight line, metres
const SIZE := 0.012
const HALO := 0.06          # the soft additive glow round each spark, metres
const SOUND := ""           # no existing id fits a soft arrival chime without reading as "faith earned"; set one to play it quietly
const COLOURS: Array[Color] = [Color("FFD45A"), Color("F6A45D"), Color("E8452C")]

var game
var active := 0
var _spark: Array[MeshInstance3D] = []
var _trail: Array[CPUParticles3D] = []
var _t := PackedFloat32Array()
var _a: Array[Vector3] = []
var _c: Array[Vector3] = []
var _b: Array[Vector3] = []
var _house: Array = []


func _init() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = SIZE
	mesh.height = SIZE * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var mats: Array[StandardMaterial3D] = []
	for col in COLOURS:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col
		mats.append(m)
	for i in MAX:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mats[i % mats.size()]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		VfxKit.halo(mi, HALO, Color(COLOURS[i % COLOURS.size()], 0.7))
		var tr := VfxKit.trail(mi, COLOURS[i % COLOURS.size()], COLOURS[(i + 1) % COLOURS.size()], 70, 0.28, 0.008)
		tr.emitting = false
		_trail.append(tr)
		_spark.append(mi)
		_t.append(-1.0)
		_a.append(Vector3.ZERO)
		_c.append(Vector3.ZERO)
		_b.append(Vector3.ZERO)
		_house.append(null)
	set_process(false)


func nearest_house(at: Vector3) -> House:
	var best: House = null
	var best_d := INF
	for h in game.houses:
		if h.is_shuttered:
			continue
		var d := Vector2(h.global_position.x - at.x, h.global_position.z - at.z).length_squared()
		if d < best_d:
			best_d = d
			best = h
	return best


func spawn(from: Vector3) -> bool:
	## Launches a spark from `from` (board-world) to the nearest standing house. False if none is free or no house stands.
	if active >= MAX or game == null or not is_inside_tree():
		return false
	var h := nearest_house(from)
	if h == null:
		return false
	var i := _t.find(-1.0)
	if i < 0:
		return false
	var to := h.global_position + Vector3(0, 0.05, 0)
	_a[i] = from
	_b[i] = to
	_c[i] = (from + to) * 0.5 + Vector3(0, LIFT + 0.25 * from.distance_to(to), 0)
	_house[i] = h
	_t[i] = 0.0
	active += 1
	_spark[i].visible = true
	_spark[i].global_position = from
	_trail[i].emitting = true
	set_process(true)
	return true


func _process(delta: float) -> void:
	for i in MAX:
		if _t[i] < 0.0:
			continue
		_t[i] += delta / FLIGHT
		var u := _t[i]
		if u >= 1.0:
			_arrive(i)
			continue
		var e := u * u * (3.0 - 2.0 * u)  # eased
		var p := (1.0 - e) * (1.0 - e) * _a[i] + 2.0 * (1.0 - e) * e * _c[i] + e * e * _b[i]
		_spark[i].global_position = p
		var pop := minf(1.0, u / 0.15)  # grows out of the body
		_spark[i].scale = Vector3.ONE * pop * (1.0 - 0.5 * smoothstep(0.7, 1.0, u))


func _arrive(i: int) -> void:
	_t[i] = -1.0
	_spark[i].visible = false
	_trail[i].emitting = false
	active -= 1
	if active <= 0:
		set_process(false)
	var h = _house[i]
	_house[i] = null
	if is_instance_valid(h) and not h.is_shuttered:
		h.glow_pulse()
		if SOUND != "" and game != null:
			game.snd(SOUND, h.global_position)
