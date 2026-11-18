extends SceneTree
## Single-model hero frames for the app icon (desktop window needed, not --headless):
##   <godot console> --xr-mode off --resolution 1024x1024 --path godot -s res://tools/icon_shot.gd -- OUT_DIR res://assets/<cat>/<model>.glb ...
## Each model is framed to fill the square from a slightly low three-quarter view, warm key + soft fill,
## on a transparent background: OUT_DIR/<model>.png. The model is the real game asset (shared palette materials).


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0]
	root.transparent_bg = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.7, 0.75)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.82, 0.6)
	key.light_energy = 1.6
	key.rotation_degrees = Vector3(-38, -35, 0)
	root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(1.0, 0.45, 0.3)
	rim.light_energy = 1.1
	rim.rotation_degrees = Vector3(-20, 150, 0)
	root.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	cam.make_current()
	for i in range(1, args.size()):
		var ps: PackedScene = load(args[i])
		if ps == null:
			print("ICONSHOT cannot load ", args[i])
			continue
		var m: Node3D = ps.instantiate()
		root.add_child(m)
		await process_frame
		var box := _aabb(m, Transform3D.IDENTITY)
		var c := box.get_center()
		var r := box.size.length() * 0.5
		var d := r / sin(deg_to_rad(cam.fov * 0.5)) * 0.92
		cam.global_position = c + Vector3(0.55, 0.32, 1.0).normalized() * d
		cam.look_at(c, Vector3.UP)
		for f in 10:
			await process_frame
		var img := root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var path := "%s/%s.png" % [out_dir, args[i].get_file().get_basename()]
		img.save_png(path)
		print("ICONSHOT saved ", path)
		root.remove_child(m)
		m.free()
	quit()


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is VisualInstance3D:
		var b: AABB = t * (n as VisualInstance3D).get_aabb()
		box = b
		first = false
	for ch in n.get_children():
		var cb := _aabb(ch, t)
		if cb.size == Vector3.ZERO:
			continue
		box = cb if first else box.merge(cb)
		first = false
	return box
