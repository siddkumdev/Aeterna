extends SceneTree
## Screenshots of the slice in desktop mode (needs a window, not --headless):
##   <godot console> --xr-mode off --path godot -s res://tools/game_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_day.png (build ghost shown) and OUT_PREFIX_night.png (a night under way).


func _initialize() -> void:
	var prefix := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "game_shot"
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 5:
		await process_frame
	g.try_build("fire", Vector2i(11, 11))
	g.select("crossbow")
	g.set_process(false)  # keep the mouse from moving the ghost
	g._hover_cell = Vector2i(3, 9)
	g._update_ghost()
	await _settle()
	root.get_viewport().get_texture().get_image().save_png(prefix + "_day.png")
	g.select("")
	g.trust = 200
	g.try_build("crossbow", Vector2i(3, 9))
	g.try_build("brazier", Vector2i(19, 9))
	g.set_process(true)
	g.speed = 0.0  # the shot steps the night by hand below
	g.night = 2  # night 3: Grunts, Scouts and the first Splitter
	g.start_night()
	var t := 0.0
	while t < 19.0:
		g.step(0.05)
		t += 0.05
	await _settle()
	root.get_viewport().get_texture().get_image().save_png(prefix + "_night.png")
	print("saved ", prefix, "_day.png and _night.png")
	quit()


func _settle() -> void:
	await create_timer(1.6).timeout  # light tweens take 1.2 s
