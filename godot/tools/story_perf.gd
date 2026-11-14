extends SceneTree
## Frame time of the story world on this machine (desktop window):
##   <godot console> --xr-mode off --path godot -s res://tools/story_perf.gd
## Prints fps, draw calls and primitives for a few views and moods, and the biggest nodes by primitive count.


func _initialize() -> void:
	var w := StoryWorld.new()
	root.add_child(w)
	var cam := Camera3D.new()
	cam.fov = 90.0
	root.add_child(cam)
	cam.current = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for i in 5:
		await process_frame
	for mood in ["morning", "curse"]:
		w.set_mood(mood, 0.0)
		for yaw in [0.0, 90.0, 180.0]:
			cam.position = Vector3(0, StoryWorld.height(0, 3) + 1.6, 3)
			cam.rotation_degrees = Vector3(-5, yaw, 0)
			for i in 20:
				await process_frame
			var t0 := Time.get_ticks_usec()
			var gpu := 0.0
			var cpu := 0.0
			for i in 60:
				await process_frame
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
				cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
			var ms := (Time.get_ticks_usec() - t0) / 60000.0
			var rs := RenderingServer
			print("[story %s yaw %d] %.1f ms/frame (%.0f fps) gpu=%.1f ms render-cpu=%.1f ms draws=%d prims=%d" % [mood, yaw, ms, 1000.0 / ms, gpu / 60.0, cpu / 60.0,
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	var rows := []
	for n in _all(w):
		var tris := 0
		if n is MultiMeshInstance3D and n.multimesh and n.multimesh.mesh:
			tris = _tris(n.multimesh.mesh) * n.multimesh.visible_instance_count if n.multimesh.visible_instance_count >= 0 else _tris(n.multimesh.mesh) * n.multimesh.instance_count
		elif n is MeshInstance3D and n.mesh:
			tris = _tris(n.mesh)
		if tris > 0:
			rows.append([tris, str(w.get_path_to(n))])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows.slice(0, 15):
		print("[tris] %8d  %s" % r)
	var lights := 0
	for n in _all(w):
		if n is Light3D and n.visible:
			lights += 1
			if n.shadow_enabled:
				print("[shadow light] ", w.get_path_to(n), " ", n.get_class())
	print("[lights] ", lights)
	quit()


func _tris(m: Mesh) -> int:
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
