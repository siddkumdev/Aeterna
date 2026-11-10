extends SceneTree
## Placement feel check (opens a window): builds a tower and prints its height and scale over the first half second,
## then saves a strip of crops to OUT_PREFIX_settle.png.
##   <godot console> --xr-mode off --path godot -s res://tools/settle_check.gd -- C:/path/prefix


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := args[0] if args.size() > 0 else "settle"
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 5:
		await process_frame
	g.FAITH = 2000
	g._hud.visible = false
	g._msg.visible = false
	g.try_build("fire", Vector2i(5, 12))
	var t: Tower = g.towers[-1]
	var rest := t.position.y - 0.03
	var start := Time.get_ticks_msec()
	var frames: Array[Image] = []
	var next_shot := 0
	var worst := 1.0
	while Time.get_ticks_msec() - start < 600:
		await process_frame
		var ms := Time.get_ticks_msec() - start
		worst = minf(worst, t.scale.y)
		print("%3d ms  y=%+.4f  scale=%s" % [ms, t.position.y - rest, t.scale])
		if ms >= next_shot and frames.size() < 5:
			next_shot += 90
			var img := root.get_viewport().get_texture().get_image()
			frames.append(img)
	print("end: y=%+.4f scale=%s  lowest height scale %.2f" % [t.position.y - rest, t.scale, worst])
	var cam := root.get_viewport().get_camera_3d()
	var p := cam.unproject_position(t.global_position + Vector3(0, 0.05, 0))
	var crop := 150
	var strip := Image.create(crop * frames.size(), crop, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		frames[i].convert(Image.FORMAT_RGBA8)
		strip.blit_rect(frames[i], Rect2i(int(p.x) - crop / 2, int(p.y) - crop / 2, crop, crop), Vector2i(i * crop, 0))
	strip.save_png(prefix + "_settle.png")
	quit()
