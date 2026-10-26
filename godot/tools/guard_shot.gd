extends SceneTree
## Guard Tower close-ups (desktop window, not --headless):
##   <godot console> --xr-mode off --path godot -s res://tools/guard_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_idle.png (the ring of Guards at their posts) and _fight.png (one chasing and hitting a Grunt).


func _initialize() -> void:
	var prefix := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "guard_shot"
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 5:
		await process_frame
	g.trust = 500
	g.try_build("guard", Vector2i(11, 11))
	var gt: Tower = g.towers[0]
	g.night = 2
	g.start_night()
	g._spawn_queue.clear()
	g.set_process(false)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 35
	for i in 6:
		await process_frame
	var c := gt.global_position + Vector3(0, 0.03, 0)
	cam.global_position = c + Vector3(0.10, 0.12, 0.17)
	cam.look_at(c, Vector3.UP)
	await create_timer(0.3).timeout
	root.get_viewport().get_texture().get_image().save_png(prefix + "_idle.png")
	var post: Vector3 = gt.get_parent().to_local(gt.guards[0].post())
	var e: Enemy = g._spawn(Vector2i(11, 14), "grunt", post + Vector3(0, 0, 1.2 * GameConfig.CELL))
	e.slow(0.0001, 1000.0)
	e.hp = 1000.0
	for i in 28:
		g.step(0.05)
		await process_frame
	var mid := (gt.guards[0].global_position + e.global_position) / 2.0
	cam.global_position = mid + Vector3(0.10, 0.10, 0.16)
	cam.look_at(mid + Vector3(0, 0.015, 0), Vector3.UP)
	await create_timer(0.25).timeout
	root.get_viewport().get_texture().get_image().save_png(prefix + "_fight.png")
	print("saved ", prefix, "_idle / _fight .png")
	quit()
