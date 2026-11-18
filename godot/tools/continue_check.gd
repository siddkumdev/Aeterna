extends SceneTree
## Checks auto-save Continue (2026-11-18): opens the real launcher scene (so it saves), presses Continue, reports the
## restored run and saves a shot. Needs user://save.json first.
##   <godot console> --xr-mode off --resolution 960x1024 --path godot -s res://tools/continue_check.gd -- OUT.png


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://continue.png"
	print("save before: ", Game.has_save())
	change_scene_to_file("res://scenes/launcher.tscn")
	for i in 30:
		await process_frame
	var l: Launcher = current_scene
	print("continue plaque: ", l._plaques.has("continue"), "  auto start: ", l._auto_at)
	l._press_plaque("continue")
	for i in 90:
		await process_frame
	var g: Game = l.game
	print("loop ", g.loop, " night ", g.night, " faith ", g.faith, " phase ", g.phase, " towers ", g.towers.size(),
		" tutorial step ", l._step, " hold ", g.tutorial_hold, " msg: ", g.last_message)
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
