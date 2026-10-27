extends SceneTree
## Close-ups of the tower crews (desktop window needed, not --headless):
##   <godot console> --xr-mode off --path godot -s res://tools/crew_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_wizard.png, _archer.png, _pilot.png (each right after the tower has fired).


func _initialize() -> void:
	var prefix := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "crew_shot"
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 5:
		await process_frame
	g.trust = 500
	g.try_build("fire", Vector2i(5, 12))  # (6,12) now holds village props
	g.try_build("crossbow", Vector2i(11, 12))
	g.try_build("airship", Vector2i(17, 12))
	g.night = 2
	g.start_night()
	g._spawn_queue.clear()
	g.set_process(false)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 35
	for n in [["fire", Vector2i(6, 11), "grunt", Vector2i(7, 8), "wizard"], ["crossbow", Vector2i(11, 11), "grunt", Vector2i(11, 8), "archer"], ["airship", Vector2i(16, 11), "wisp", Vector2i(16, 9), "pilot"]]:
		for e in g.enemies.duplicate():
			e.queue_free()
		g.enemies.clear()
		var e: Enemy = g._spawn(n[3], n[2], NavGrid.cell_centre(n[3]) + Vector3(0, 0.0 if n[2] != "wisp" else 0.06, 0))
		e.slow(0.0001, 1000.0)
		var tw: Tower = g.towers.filter(func(t): return t.kind == n[0])[0]
		tw.cooldown = 0.0
		g.step(0.05)
		g.step(0.05)
		for i in 6:
			await process_frame
		var c := tw.crew.global_position
		cam.global_position = c + Vector3(0.09, 0.07, 0.13)
		cam.look_at(c + Vector3(0, 0.0, 0), Vector3.UP)
		await create_timer(0.2).timeout
		root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [prefix, n[4]])
	print("saved ", prefix, "_wizard / _archer / _pilot .png")
	quit()
