extends SceneTree
## The first-rewind cutscene (end of loop 1) in a desktop window, a few frames:
##   <godot console> --xr-mode off --path godot -s res://tools/loop_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_<seconds>.png at fixed times after the cutscene starts.

const TIMES := [2.5, 5.5, 8.0, 11.0, 14.0, 18.0, 21.5, 25.0, 27.5, 29.0, 30.5, 32.5, 36.0]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "loop_shot"
	var g: Game = load("res://scripts/game/game.gd").new()  # the game alone, no opening
	root.add_child(g)
	for i in 40:
		await process_frame
	g._camera = null
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 48
	cam.global_position = g.board.to_global(Vector3(0.0, 0.95, 1.25))
	cam.look_at(g.board.to_global(Vector3(0, 0.0, 0.05)), Vector3.UP)
	for h in g.houses.slice(0, 3):  # as after a real fall: three houses already dark
		h.force_dark()
	g.night = g.fall_night()
	g.phase = Game.Phase.NIGHT
	g._end_loop(false)  # the fall: cards, then the cutscene
	g.choose_card(0)
	var t0 := Time.get_ticks_msec()
	for t: float in TIMES:
		while (Time.get_ticks_msec() - t0) / 1000.0 < t:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s_%04.1f.png" % [prefix, t])
	print("cutscene: count %d, loop %d, cutscene active %s" % [g.cutscene_count, g.loop, str(g.is_cutscene())])
	quit()
