extends SceneTree
## A filmstrip of one tower's effects (desktop window needed, not --headless):
##   <godot console> --xr-mode off --path godot -s res://tools/vfx_shot.gd -- OUT_PREFIX [tower]
## tower = fire (default). Builds the tower, puts a motionless enemy in range and plays one night in real time.
## Writes OUT_PREFIX_<tower>_strip.png: 12 frames, 0.15 s apart, left to right and top to bottom, plus a few full frames.

const FRAMES := 12
const STEP := 0.1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := args[0] if args.size() > 0 else "vfx_shot"
	var which := args[1] if args.size() > 1 else "fire"
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 5:
		await process_frame
	g.trust = 500
	g.cards = {}
	var spot := {"fire": Vector2i(5, 12), "crossbow": Vector2i(5, 12), "airship": Vector2i(5, 12), "guard": Vector2i(5, 12)}
	g.try_build(which, spot[which])
	g.night = 2
	g.start_night()
	g._spawn_queue.clear()
	g.set_process(false)
	var tw: Tower = g.towers[0]
	var air := which == "airship"
	var foe_cell := Vector2i(7, 9)
	var e: Enemy = g._spawn(foe_cell, "wisp" if air else "grunt", NavGrid.cell_centre(foe_cell) + Vector3(0, 0.06 if air else 0.0, 0))
	e.slow(0.0001, 1000.0)
	e.hp = 99999.0
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 30
	# from the south-west (the houses are to the east) at the tower's top and the first stretch of the shot
	g._hud.visible = false
	g._msg.visible = false
	var focus := tw.global_position + Vector3(0.05, 0.15, -0.05)
	cam.global_position = focus + Vector3(-0.15, 0.03, 0.34)
	if args.size() > 2 and args[2] == "shot":  # the flight and the impact instead of the tower top
		focus = (tw.global_position + Vector3(0, 0.07, 0) + e.global_position) * 0.5
		cam.fov = 32
		cam.global_position = focus + Vector3(0.0, 0.3, 0.17)  # from above, like the player leaning over the board
	cam.look_at(focus, Vector3.UP)
	tw.cooldown = 0.25
	var frames: Array[Image] = []
	var next := 0.0
	var t := 0.0
	while frames.size() < FRAMES:
		g.step(1.0 / 60.0)
		t += 1.0 / 60.0
		await process_frame
		if t >= next:
			next += STEP
			var img := root.get_viewport().get_texture().get_image()
			frames.append(img)
	if OS.get_environment("VFX_DEBUG") == "1":
		for n in g.find_children("*", "MeshInstance3D", true, false):
			if n.visible and n.mesh is QuadMesh:
				print("VFXDBG quad ", n.get_path(), " at ", n.global_position, " size ", (n.mesh as QuadMesh).size)
	var w := frames[0].get_width()
	var h := frames[0].get_height()
	var cw := int(w * 0.5)
	var ch := int(h * 0.5)
	var cols := 4
	var sheet := Image.create(cw * cols, ch * ((FRAMES + cols - 1) / cols), false, Image.FORMAT_RGBA8)
	for i in frames.size():
		var f := frames[i]
		f.convert(Image.FORMAT_RGBA8)
		f.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(f, Rect2i(0, 0, cw, ch), Vector2i((i % cols) * cw, (i / cols) * ch))
	sheet.save_png("%s_%s_strip.png" % [prefix, which])
	frames[3].save_png("%s_%s_frame3.png" % [prefix, which])
	print("VFXSHOT saved ", prefix, "_", which, "_strip.png")
	quit()
