extends SceneTree
## The statue at the island's centre (desktop window): --xr-mode off --path godot -s res://tools/statue_shot.gd -- OUT.png
func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "statue.png"
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 30:
		await process_frame
	g.asleep = false
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 45
	g._camera = null
	var c := g.board.to_global(Vector3(0, 0.09, 0))
	cam.global_position = c + Vector3(0.0, 0.10, 0.22)
	cam.look_at(c, Vector3.UP)
	for i in 8:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
