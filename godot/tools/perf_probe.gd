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
	await _report("day", g)
	_groups(g)
	g.faith = 2000
	for t in [["fire", Vector2i(5, 12)], ["crossbow", Vector2i(16, 8)], ["guard", Vector2i(9, 16)], ["airship", Vector2i(15, 14)]]:
		g.try_build(t[0], t[1])
	g.night = 3
	g.start_night()
	for i in 60:
		g.step(0.05)
		await process_frame
	await _report("night", g)
	quit()


func _report(label: String, g: Node) -> void:
	await process_frame
	var rs := RenderingServer
	var lights := {"dir": 0, "omni": 0, "spot": 0, "shadowed": 0}
	var parts := 0
	var vps := 0
	var multimesh := 0
	var transparent := 0
	var meshes := 0
	var shadow_casters := 0
	var tris := 0
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
		if n is MultiMeshInstance3D and n.is_visible_in_tree():
			multimesh += 1
			if n.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				shadow_casters += 1
			if n.multimesh and n.multimesh.mesh:
				var inst: int = n.multimesh.visible_instance_count if n.multimesh.visible_instance_count >= 0 else n.multimesh.instance_count
				tris += _mesh_tris(n.multimesh.mesh) * inst
		elif n is MeshInstance3D and n.is_visible_in_tree():
			meshes += 1
			if n.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				shadow_casters += 1
			if n.mesh:
				tris += _mesh_tris(n.mesh)
		if n is GeometryInstance3D and n.visible and n.transparency > 0.0:
			transparent += 1
	var l = g.get("lighting")
	var env: Environment = l.env if l != null else g.get("env")
	print("[perf %s] draws=%d objects=%d prims=%d | meshes=%d tris=%d shadow_casters=%d | lights %s | particles=%d multimesh=%d subviewports=%d | glow=%s ssao=%s adj=%s fog=%s" % [
		label,
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		meshes, tris, shadow_casters,
		str(lights), parts, multimesh, vps,
		env.glow_enabled if env else "-", env.ssao_enabled if env else "-", env.adjustment_enabled if env else "-", env.fog_enabled if env else "-"])


func _mesh_tris(m: Mesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		var idx = a[Mesh.ARRAY_INDEX]
		t += (idx.size() if idx != null and idx.size() > 0 else a[Mesh.ARRAY_VERTEX].size()) / 3
	return t


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
