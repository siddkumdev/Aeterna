class_name StoryPerfSweep
extends Node
## MEASUREMENT ONLY (the user, 2026-11-17: "measure first, then decide"). During the story it hides one group of the
## story world at a time and logs the GPU time with and without it, so we know what costs what on the Quest.
## Read the result from the headset log: grep "\[storyperf\]". Switch off with OpeningStage.PERF_SWEEP = false.

const OFF_S := 4.0   # each group hidden this long
const ON_S := 2.5    # then shown again this long (the baseline next to it)
const SKIP_S := 0.8  # ignore the first frames after a switch

var world: Node3D
var _groups: Array = []  # [name, Array[Node], extra Callable or null]
var _i := -1
var _phase := "start"
var _t := 0.0
var _gpu_sum := 0.0
var _cpu_sum := 0.0
var _fps_sum := 0.0
var _n := 0
var _base := {}


func _ready() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_collect()
	print("[storyperf] start: %d groups, %.1f s each" % [_groups.size(), OFF_S + ON_S])


func _collect() -> void:
	var g := {}
	for c in world.get_children():
		var n := String(c.name)
		var key := n.rstrip("0123456789_")
		if c is GPUParticles3D:
			key = "particles"
		elif c is OmniLight3D or c is SpotLight3D:
			key = "lights"
		elif n.begins_with("ew_village_") or n.begins_with("@Node3D@") or n == "Village":
			key = "village"
		elif key in ["Pines0", "Pines1", "Pines2"]:
			key = "pines_near"
		elif key in ["FarPines0", "FarPines1"]:
			key = "pines_far"
		elif key == "Sun" or not (c is Node3D):
			continue
		if not g.has(key):
			g[key] = []
		(g[key] as Array).append(c)
	for k in g:
		_groups.append([k, g[k], null])
	var w := world
	_groups.append(["sun_shadows", [], func(on: bool) -> void:
		if w.get("sun"):
			(w.get("sun") as DirectionalLight3D).shadow_enabled = on])
	_groups.append(["env_glow_fog", [], func(on: bool) -> void:
		var e: Environment = w.get("env")
		if e:
			if not _base.has("glow"):
				_base["glow"] = e.glow_enabled
				_base["fog"] = e.fog_enabled
				_base["vfog"] = e.volumetric_fog_enabled
			e.glow_enabled = _base["glow"] and on
			e.fog_enabled = _base["fog"] and on
			e.volumetric_fog_enabled = _base["vfog"] and on])


func _show(group: Array, on: bool) -> void:
	for n in group[1]:
		if is_instance_valid(n):
			if on:
				(n as Node3D).visible = n.get_meta("_sweep_vis", true)
			else:
				n.set_meta("_sweep_vis", (n as Node3D).visible)
				(n as Node3D).visible = false
	if group[2] != null:
		(group[2] as Callable).call(on)


func _process(delta: float) -> void:
	if world == null or not is_instance_valid(world):
		return
	_t += delta
	var vp := get_viewport().get_viewport_rid()
	if _t > SKIP_S:
		_gpu_sum += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		_cpu_sum += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		_fps_sum += Engine.get_frames_per_second()
		_n += 1
	match _phase:
		"start":
			if _t >= ON_S:
				_report("ALL ON")
				_next()
		"off":
			if _t >= OFF_S:
				_report("without %s" % _groups[_i][0])
				_show(_groups[_i], true)
				_phase = "on"
				_reset()
		"on":
			if _t >= ON_S:
				_report("all on again")
				_next()


func _next() -> void:
	_i += 1
	_reset()
	if _i >= _groups.size():
		print("[storyperf] done")
		_phase = "done"
		set_process(false)
		return
	_show(_groups[_i], false)
	_phase = "off"


func _reset() -> void:
	_t = 0.0
	_gpu_sum = 0.0
	_cpu_sum = 0.0
	_fps_sum = 0.0
	_n = 0


func _report(label: String) -> void:
	if _n == 0:
		return
	var info := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var tris := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	print("[storyperf] %-28s fps=%5.1f gpu=%5.2fms cpu=%5.2fms draws=%d tris=%dk" % [label, _fps_sum / _n, _gpu_sum / _n, _cpu_sum / _n, info, tris / 1000])


func _exit_tree() -> void:
	if _i >= 0 and _i < _groups.size() and _phase == "off":
		_show(_groups[_i], true)
