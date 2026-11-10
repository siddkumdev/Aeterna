extends SceneTree
## The Veil dome beats (desktop window needed, not --headless):
##   <godot console> --xr-mode off --path godot -s res://tools/veil_shot.gd -- OUT_PREFIX
## Builds the game, adds a VeilDome on the board and photographs: knit, cracking (half, full), shattering (mid, late),
## knitting again. Writes OUT_PREFIX_veil_strip.png (6 frames, 3 across) and OUT_PREFIX_veil_<n>.png.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := args[0] if args.size() > 0 else "veil_shot"
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 5:
		await process_frame
	g.set_process(false)
	g._hud.visible = false
	g._msg.visible = false
	var veil := VeilDome.new()
	veil.name = "VeilDome"
	g.board.add_child(veil)
	await process_frame
	g.lighting.set_mood("dusk", 0.0)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 38
	cam.global_position = g.board.global_position + Vector3(0.0, 0.7, 1.9)
	cam.look_at(g.board.global_position + Vector3(0.0, 0.3, 0.0), Vector3.UP)
	var frames: Array[Image] = []
	veil.snap(1.0, 0.0)
	await _wait(0.4)
	frames.append(_grab())
	veil.snap(1.0, 0.5)
	await _wait(0.3)
	frames.append(_grab())
	veil.snap(1.0, 1.0)
	await _wait(0.3)
	frames.append(_grab())
	veil.shatter(1.2)
	await _wait(0.5)
	frames.append(_grab())
	await _wait(0.5)
	frames.append(_grab())
	veil.snap(0.0, 0.0)
	veil.knit(2.0)
	await _wait(1.0)
	frames.append(_grab())
	for i in frames.size():
		frames[i].save_png("%s_veil_%d.png" % [prefix, i])
	var w := frames[0].get_width() / 2
	var h := frames[0].get_height() / 2
	var sheet := Image.create(w * 3, h * 2, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		var f := frames[i]
		f.convert(Image.FORMAT_RGBA8)
		f.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(f, Rect2i(0, 0, w, h), Vector2i((i % 3) * w, (i / 3) * h))
	sheet.save_png("%s_veil_strip.png" % prefix)
	print("VEILSHOT saved ", prefix, "_veil_strip.png")
	quit()


func _wait(seconds: float) -> void:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(seconds * 1000.0):
		await process_frame


func _grab() -> Image:
	return root.get_viewport().get_texture().get_image()
