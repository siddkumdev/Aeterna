extends SceneTree
## The quests on the island (desktop window, not --headless):
##   <godot console> --xr-mode off --path godot -s res://tools/quest_shot.gd -- OUT_PREFIX [kind kind ...]
## Wakes the game past the intro, posts the given quest kinds (default: rain warm lights prayer) and writes
## OUT_PREFIX_wide.png (the seat) and OUT_PREFIX_close.png (over the village).

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "quest_shot"
	var kinds: Array = args.slice(1) if args.size() > 1 else ["rain", "warm", "lights", "prayer"]
	var l: Launcher = load("res://scripts/ui/launcher.gd").new()
	root.add_child(l)
	for i in 40:
		await process_frame
	l._press_plaque("wake")
	l._skip = true
	for i in 30:
		await process_frame
	l.game._camera = null
	HelpRequest.shown_kinds.clear()
	l.game.force_quests(kinds)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 48
	for i in 150:  # let the askers walk over
		await process_frame
	cam.global_position = l.game.board.to_global(Vector3(0.0, 0.5, 1.05))
	cam.look_at(l.game.board.to_global(Vector3(0, 0.05, 0.25)), Vector3.UP)
	await _snap(prefix + "_wide")
	cam.global_position = l.game.board.to_global(Vector3(0.0, 0.3, 0.42))
	cam.look_at(l.game.board.to_global(Vector3(0, 0.03, 0.0)), Vector3.UP)
	await _snap(prefix + "_close")
	for r in l.game.requests:
		print("QUESTSHOT ", r.kind, " house ", r.house, " asker ", r.asker() != null, " ghost ", r._ghost != null)
	quit()


func _snap(name: String) -> void:
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s.png" % name)
