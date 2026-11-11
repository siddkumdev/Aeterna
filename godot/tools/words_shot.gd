extends SceneTree
## The gilded rewind words (desktop window): <godot console> --xr-mode off --path godot -s res://tools/words_shot.gd -- OUT.png

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "words_shot.png"
	var l: Launcher = load("res://scripts/ui/launcher.gd").new()
	root.add_child(l)
	for i in 40:
		await process_frame
	l._press_plaque("wake")
	l._skip = true
	for i in 30:
		await process_frame
	var g := l.game
	g._camera = null
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 48
	cam.global_position = g.board.to_global(Vector3(0.0, 0.5, 1.05))
	cam.look_at(g.board.to_global(Vector3(0, 0.12, 0.2)), Vector3.UP)
	g.loop = 1
	g.show_rewind_words()
	for i in 80:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
