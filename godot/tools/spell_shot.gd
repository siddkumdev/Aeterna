extends SceneTree
## A filmstrip of one spell (desktop window needed, not --headless):
##   <godot console> --xr-mode off --path godot -s res://tools/spell_shot.gd -- OUT_PREFIX [spell]
## spell = fire_orb (default). Puts a motionless grunt and a wisp on the board at night, casts the spell on them
## and writes OUT_PREFIX_<spell>_strip.png (12 frames, STEP seconds apart) plus a few full frames.

const FRAMES := 12
const STEP := 0.1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := args[0] if args.size() > 0 else "spell_shot"
	var which := args[1] if args.size() > 1 else "fire_orb"
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 5:
		await process_frame
	g.trust = 500
	g.cards = {}
	g.night = 2
	g.start_night()
	g._spawn_queue.clear()
	g.set_process(false)
	var cell := Vector2i(10, 10)
	var at := NavGrid.cell_centre(cell)
	var e: Enemy = g._spawn(cell, "grunt", at)
	e.slow(0.0001, 1000.0)
	e.hp = 99999.0
	var e2: Enemy = g._spawn(cell + Vector2i(1, 0), "grunt", NavGrid.cell_centre(cell + Vector2i(1, 0)))
	e2.slow(0.0001, 1000.0)
	e2.hp = 99999.0
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 34
	g._hud.visible = false
	g._msg.visible = false
	var focus := g.board.to_global(at) + Vector3(0, 0.04, 0)
	cam.global_position = focus + Vector3(0.0, 0.28, 0.3)  # from above, like the player leaning over the board
	if which == "storm":  # the cloud hangs high: frame it and the ground below
		focus += Vector3(0, 0.1, 0)
		cam.fov = 44
		cam.global_position = focus + Vector3(0.0, 0.2, 0.38)
	cam.look_at(focus, Vector3.UP)
	var ok: bool = g.spells.cast(which, at, 4.0)
	print("SPELLSHOT cast ", which, " -> ", ok)
	var frames: Array[Image] = []
	var next := 0.0
	var t := 0.0
	var step := float(OS.get_environment("VFX_STEP")) if OS.get_environment("VFX_STEP") != "" else STEP
	while frames.size() < FRAMES:
		g.step(1.0 / 60.0)
		t += 1.0 / 60.0
		await process_frame
		if t >= next:
			next += step
			frames.append(root.get_viewport().get_texture().get_image())
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
	frames[4].save_png("%s_%s_frame4.png" % [prefix, which])
	print("SPELLSHOT saved ", prefix, "_", which, "_strip.png")
	quit()
