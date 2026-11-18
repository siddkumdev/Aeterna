extends Node3D
## Quest tiers only (PerfTier.tier != DESKTOP): a cheap stand-in for the bloom that the headset cannot afford
## (perf_tier.gd turns the full-screen glow off). Small camera-facing, additive, soft radial halos sit on the
## lit house windows and on the statue's candle flame. One MultiMesh, one shared ShaderMaterial, depth-tested with
## no depth write, a few dozen tiny quads: overdraw is negligible. Warm colours only (lantern_glow / fire_yellow).
## No class_name on purpose (loaded by path from game.gd, so no re-import is needed): Game does
## `load("res://scripts/vfx/fake_bloom.gd").attach(self)`.
## Fades: by day (follows the sun energy of Lighting, so dawn/day = none, dusk fades in, night full), per window
## with the house's lamp part (shuttered, snuffed or flickering = gone), with the statue flame's scale (cutscene dim).
## (the user, 2026-11-18: VR look audit, flat night village without bloom; Claude, delegated overnight)

const WINDOW_TINT := Color("F6A45D")  # lantern_glow
const FLAME_TINT := Color("FFD45A")  # fire_yellow
const WINDOW_SIZE := 0.05  # metres across (a house is ~0.08 m wide)
const FLAME_SIZE := 0.08
const WINDOW_GAIN := 1.6  # raised from 1.1 (Claude, overnight): halos barely read from the seat
const FLAME_GAIN := 1.3
const CLUSTER_R := 0.011  # window vertices closer than this (part space) are one window
const MAX_PER_HOUSE := 8
const MAX_INSTANCES := 64
const SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform float falloff = 2.4;
varying vec3 tint;
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	VERTEX.z += 0.014 / s;  // toward the eye: the quad clears the shutters and eaves in front of the window
	tint = COLOR.rgb;
}
void fragment() {
	float d = clamp(length(UV - vec2(0.5)) * 2.0, 0.0, 1.0);
	float a = pow(1.0 - d, falloff);
	ALBEDO = tint * a;
	ALPHA = 1.0;
}
"""

## test hook: >= 0 replaces the lighting-derived night level
var force_level := -1.0
var game: Node
var lighting: Object
var enabled := false  # true once built on a Quest tier
var sources: Array[Dictionary] = []  # {gate, house, pos, size, tint, gain, flame, phase}

var _mm: MultiMesh
var _mmi: MultiMeshInstance3D
var _last := PackedFloat32Array()
var _t := 0.0
var _built := false
var _off := false  # tools: AETERNA_NO_HALO=1 for before shots


static func attach(g: Node) -> Node:
	var fb: Node3D = load("res://scripts/vfx/fake_bloom.gd").new()
	fb.name = "FakeBloom"
	fb.game = g
	g.board.add_child(fb)
	return fb


func _ready() -> void:
	_off = OS.get_environment("AETERNA_NO_HALO") != ""
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	q.material = mat
	_mm.mesh = q
	_mm.instance_count = MAX_INSTANCES
	_mm.visible_instance_count = 0
	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = _mm
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mmi.custom_aabb = AABB(Vector3(-0.8, -0.3, -0.8), Vector3(1.6, 1.0, 1.6))  # the whole board: never culled by a tiny quad
	_mmi.visible = false
	add_child(_mmi)
	set_process(true)


func _process(delta: float) -> void:
	var on := PerfTier.tier != PerfTier.DESKTOP and not _off
	if on and not _built:
		build()
	enabled = on and _built
	_mmi.visible = enabled and _level() > 0.01
	if not enabled:
		return
	_t += delta
	var lv := _level()
	for i in sources.size():
		var s: Dictionary = sources[i]
		var g: Node3D = s["gate"]
		var v := 0.0
		if is_instance_valid(g) and g.is_visible_in_tree() and not (s["house"] != null and s["house"].is_shuttered):
			v = lv
			if s["flame"]:
				v *= clampf(g.scale.x, 0.0, 1.0) * (0.9 + 0.1 * sin(_t * 9.0 + s["phase"]))
		v *= s["gain"]
		if absf(v - _last[i]) > 0.003:
			_last[i] = v
			var c: Color = s["tint"]
			_mm.set_instance_color(i, Color(c.r * v, c.g * v, c.b * v, 1.0))


func _level() -> float:
	## 0 by day, 1 at night: follows the sun's energy, which Lighting tweens through dawn / dusk.
	if force_level >= 0.0:
		return force_level
	if lighting == null or not is_instance_valid(lighting):
		return 0.0
	var e: float = lighting.sun.light_energy
	return clampf(1.0 - e / 0.9, 0.0, 1.0)


func visible_halos() -> int:
	## Halos currently drawn with any strength (tests).
	var n := 0
	if not enabled or not _mmi.visible:
		return 0
	for v in _last:
		if v > 0.01:
			n += 1
	return n


func build() -> void:
	_built = true
	lighting = game.get("lighting")
	var board: Node3D = game.board
	for h in game.houses:
		_add_house(h, board)
	var flame: Node3D = game.get("_shrine_flame")
	if flame != null:
		_add_source(flame, null, ModelUtil.xform_to(flame, board).origin, FLAME_SIZE, FLAME_TINT, FLAME_GAIN, true)
	_mm.visible_instance_count = sources.size()
	_last.resize(sources.size())
	_last.fill(-1.0)


func _add_source(gate: Node3D, house: Node, pos: Vector3, size: float, tint: Color, gain: float, flame := false) -> void:
	if sources.size() >= MAX_INSTANCES:
		return
	var i := sources.size()
	sources.append({"gate": gate, "house": house, "tint": tint, "gain": gain, "flame": flame, "phase": randf() * TAU, "size": size})
	_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), pos))
	_mm.set_instance_color(i, Color(0, 0, 0, 1))


func _add_house(h: Node3D, board: Node3D) -> void:
	for n in ModelUtil.walk(h):
		if not (n is MeshInstance3D) or str(n.get_meta("ew_broken", "")) != "off" or n.mesh == null:
			continue
		var xf := ModelUtil.xform_to(n, board)
		var count := 0
		for p in _window_points(n.mesh):
			if count >= MAX_PER_HOUSE:
				break
			var pos: Vector3 = xf * (p[0] as Vector3)
			pos += (xf.basis * (p[1] as Vector3)).normalized() * 0.004  # off the wall, so the quad is not half buried
			_add_source(n, h, pos, WINDOW_SIZE, WINDOW_TINT, WINDOW_GAIN)
			count += 1


func _window_points(mesh: Mesh) -> Array:
	## One [centre, outward normal] per window: the glow-material vertices, grouped by distance.
	var cs: Array[Vector3] = []
	var ns: Array[Vector3] = []
	var cnt: Array[int] = []
	for si in mesh.get_surface_count():
		var m := mesh.surface_get_material(si)
		if m == null or not ("glow" in m.resource_path or "glow" in m.resource_name):
			continue
		var arr := mesh.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nm = arr[Mesh.ARRAY_NORMAL]
		for k in vs.size():
			var hit := -1
			for c in cs.size():
				if cs[c].distance_to(vs[k]) < CLUSTER_R:
					hit = c
					break
			var nrm: Vector3 = nm[k] if nm != null and nm.size() > k else Vector3.UP
			if hit < 0:
				cs.append(vs[k])
				ns.append(nrm)
				cnt.append(1)
			else:
				cs[hit] = (cs[hit] * cnt[hit] + vs[k]) / (cnt[hit] + 1)
				ns[hit] += nrm
				cnt[hit] += 1
	var out := []
	for c in cs.size():
		out.append([cs[c], ns[c]])
	return out
