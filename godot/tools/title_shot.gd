extends SceneTree
## The start experience (desktop window, not --headless):
##   <godot console> --xr-mode off --path godot -s res://tools/title_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_title.png, _narration.png, _hint.png and prints TITLESHOT lines.

func _initialize() -> void:
	var prefix := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "title_shot"
	var l: Launcher = load("res://scripts/ui/launcher.gd").new()
	root.add_child(l)
	for i in 40:
		await process_frame
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 48
	l.game._camera = null
	var look := l.game.board.to_global(Vector3(0, 0.1, 0.1))
	cam.global_position = l.game.board.to_global(Vector3(0, 0.55, 0.95))
	cam.look_at(look, Vector3.UP)
	await _snap(prefix + "_title")
	print("TITLESHOT state ", l._state, " asleep ", l.game.asleep, " plaques ", l._plaques.keys())
	l._press_plaque("wake")
	l._press_plaque("wake")  # a double press must not start it twice
	for i in 40:
		await process_frame
	await _snap(prefix + "_narration")
	print("TITLESHOT narrating: ", l._state)
	var st: OpeningStage = l.game.get_node_or_null("OpeningStage")
	print("TITLESHOT stages ", l.game.get_children().filter(func(c): return c is OpeningStage).size())
	if st:
		st._skipped = true
	for i in 120:
		await process_frame
	print("TITLESHOT after skip: ", l._state, " asleep ", l.game.asleep)
	cam.global_position = l.game.board.to_global(Vector3(0.0, 0.42, 1.15))  # the player's seat, looking at the tray
	cam.look_at(l.game.board.to_global(Vector3(0, 0.08, 0.7)), Vector3.UP)
	await _snap(prefix + "_hint")
	quit()


func _snap(name: String) -> void:
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s.png" % name)
