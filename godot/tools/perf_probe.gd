extends SceneTree
## What the GPU is asked to draw, for the Quest lag hunt (desktop window, not --headless):
##   <godot console> --xr-mode off --path godot -s res://tools/perf_probe.gd
## Prints draw calls, objects, primitives, lights, shadowed lights, particles, viewports and the environment's
## post-process switches for the day and for a busy night. Desktop numbers are a proxy: the Quest cost per draw
## call and per full-screen pass is far higher.


func _initialize() -> void:
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 30:
		await process_frame
	_report("day", g)
	_groups(g)
	quit()
	return
	g.night = 3
	g.start_night()
	for i in 240:
		g.step(1.0 / 60.0)
		await process_frame
	_report("night", g)
	quit()


func _report(label: String, g: Node) -> void:
	await process_frame
	var rs := RenderingServer
	var lights := {"dir": 0, "omni": 0, "spot": 0, "shadowed": 0}
	var parts := 0
	var vps := 0
	var multimesh := 0
	var transparent := 0
	for n in _all(root):
		if n is DirectionalLight3D:
			lights["dir"] += 1
		elif n is OmniLight3D:
			lights["omni"] += 1
		elif n is SpotLight3D:
			lights["spot"] += 1
		if n is Light3D and n.visible and n.shadow_enabled:
			lights["shadowed"] += 1
		if (n is GPUParticles3D or n is CPUParticles3D) and n.visible:
			parts += 1
		if n is SubViewport:
			vps += 1
		if n is MultiMeshInstance3D and n.visible:
			multimesh += 1
		if n is GeometryInstance3D and n.visible and n.transparency > 0.0:
			transparent += 1
	var env: Environment = g.get("env")
	print("[perf %s] draws=%d objects=%d prims=%d | lights %s | particles=%d multimesh=%d subviewports=%d | glow=%s ssao=%s adj=%s fog=%s" % [
		label,
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		str(lights), parts, multimesh, vps,
		env.glow_enabled if env else "-", env.ssao_enabled if env else "-", env.adjustment_enabled if env else "-", env.fog_enabled if env else "-"])


func _all(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


func _groups(g: Node) -> void:
	## Visible meshes per path prefix (the first three levels under the game), biggest first.
	var count := {}
	for n in _all(g):
		if n is MeshInstance3D and n.is_visible_in_tree():
			var path := str(g.get_path_to(n)).split("/")
			var key := "/".join(path.slice(0, mini(3, path.size() - 1)))
			key = key.rstrip("0123456789@")
			count[key] = count.get(key, 0) + 1
	var keys := count.keys()
	keys.sort_custom(func(a, b): return count[a] > count[b])
	for k in keys.slice(0, 25):
		print("[mesh] %5d  %s" % [count[k], k])
