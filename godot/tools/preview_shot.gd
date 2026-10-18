extends SceneTree
## Renders imported models side by side in Godot itself (Mobile renderer, the game's look), to check the
## shared palette, the glow material and the VFX anchors in-engine. Needs a window (not --headless).
##   Godot_console.exe --xr-mode off --path godot -s res://tools/preview_shot.gd -- OUT.png res://assets/defense/a.glb ...
## Anchors are drawn as small orange spheres of their ew_size (preview only).

const CELL := 0.05


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("usage: -- OUT.png res://assets/<cat>/<model>.glb ...")
		quit(1)
		return
	var out := args[0]
	var paths := args.slice(1)
	var stage := Node3D.new()
	root.add_child(stage)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color8(128, 126, 122)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color8(0x86, 0xB4, 0xBC)
	env.environment.ambient_light_energy = 0.6
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color8(0xFF, 0xD8, 0x98)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-45, -35, 0)
	stage.add_child(sun)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(CELL * 4 * paths.size() + CELL * 2, CELL * 6)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color8(0x7A, 0xA0, 0x55)
	ground.material_override = gm
	stage.add_child(ground)

	var spacing := CELL * 3.5
	var tallest := 0.05
	for i in paths.size():
		var res = load(paths[i])
		if res == null:
			print("FAIL load ", paths[i])
			continue
		var m: Node3D = res.instantiate()
		m.position.x = (i - (paths.size() - 1) / 2.0) * spacing
		stage.add_child(m)
		for a in m.find_children("*", "Marker3D", true, false):
			if not a.is_in_group("ew_vfx_anchor"):
				continue
			var s := MeshInstance3D.new()
			var sm := SphereMesh.new()
			var r := clampf(float(a.get_meta("ew_size", 0.003)), 0.002, 0.012)  # big area effects capped
			sm.radius = r
			sm.height = r * 2
			s.mesh = sm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color8(0xFF, 0x8A, 0x2A)
			mat.emission_enabled = true
			mat.emission = Color8(0xFF, 0x8A, 0x2A)
			s.material_override = mat
			a.add_child(s)
		tallest = maxf(tallest, 0.14)

	var cam := Camera3D.new()
	cam.fov = 35
	var width := spacing * paths.size()
	stage.add_child(cam)
	cam.look_at_from_position(Vector3(width * 0.35, tallest * 1.6, width * 0.9 + 0.12), Vector3(0, tallest * 0.4, 0))
	cam.current = true

	for f in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("saved ", out)
	quit()
