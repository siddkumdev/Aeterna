extends SceneTree
## Screenshots of the dressed village (needs a window, not --headless):
##   <godot console> --xr-mode off --path godot -s res://tools/dress_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_view.png (the player's seat) and OUT_PREFIX_top.png (straight down onto the village).

func _initialize() -> void:
	var prefix := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "dress_shot"
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 5:
		await process_frame
	g.set_process(false)
	await _settle()
	root.get_viewport().get_texture().get_image().save_png(prefix + "_view.png")
	print("DRESS frame: %d primitives, %d draw calls" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	var c: Vector3 = g.board.global_position
	cam.global_position = c + Vector3(0, 1.1, 0.001)
	cam.look_at(c, Vector3(0, 0, -1))
	cam.fov = 40
	await _settle()
	root.get_viewport().get_texture().get_image().save_png(prefix + "_top.png")
	cam.global_position = c + Vector3(0.0, 0.32, 0.42)
	cam.look_at(c + Vector3(0, 0, 0.0), Vector3.UP)
	await _settle()
	root.get_viewport().get_texture().get_image().save_png(prefix + "_close.png")
	quit()


func _settle() -> void:
	for i in 4:
		await process_frame
