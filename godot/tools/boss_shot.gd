extends SceneTree
## The Warden in its four forms with their effects (desktop window):
##   <godot console> --xr-mode off --path godot -s res://tools/boss_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_form1.png .. _form4.png.

func _initialize() -> void:
	var prefix := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "boss_shot"
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 10:
		await process_frame
	g.start_night()
	g.asleep = false
	g._spawn_queue.clear()
	var boss: Enemy = g._spawn(Vector2i(12, 2), "boss")
	boss.slow(0.0001, 100000.0)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 40
	g._camera = null
	for f in 4:
		if f > 0:
			boss.set_form(f)
		for i in 50:
			await process_frame
		var c := boss.global_position + Vector3(0, 0.14, 0)
		cam.global_position = c + Vector3(0.0, 0.05, 0.42)
		cam.look_at(c, Vector3.UP)
		for i in 4:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s_form%d.png" % [prefix, f + 1])
	quit()
