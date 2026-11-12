extends SceneTree
## The card tray from the seated player's view (desktop window, not --headless):
##   <godot console> --xr-mode off --path godot -s res://tools/tray_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_start.png (the tray at its start pose, day) and OUT_PREFIX_islandmoved.png (the island moved,
## turned and resized: the tray must stay put).

func _initialize() -> void:
	var prefix := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "tray"
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 85
	cam.global_position = Vector3(0, 1.1, 0.2)  # a seated player's eyes, looking down at the front of the board
	var g: Game = load("res://scripts/game/game.gd").new()
	g.with_rig = true
	root.add_child(g)
	g._camera = cam
	for i in 12:
		await process_frame
	cam.look_at(Vector3(g.board.global_position.x, 0.72, -0.3), Vector3.UP)
	print("TRAYSHOT tray at ", g._tray.global_position, " board at ", g.board.global_position)
	await _shot(prefix + "_start")
	var xf := Transform3D(Basis(Vector3.UP, 0.5) * Basis.from_scale(Vector3(0.8, 0.8, 0.8)), g.board.global_position + Vector3(0.25, 0, -0.1))
	g.board.global_transform = xf
	cam.look_at(Vector3(g.board.global_position.x, 0.72, -0.3), Vector3.UP)
	await _shot(prefix + "_islandmoved")
	print("TRAYSHOT tray after island move ", g._tray.global_position)
	quit()


func _shot(name: String) -> void:
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s.png" % name)
