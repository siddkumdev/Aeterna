extends SceneTree
## Filmstrip of the tower-to-enemy juice (desktop window needed, not --headless):
##   <godot console> --xr-mode off --path godot -s res://tools/juice_shot.gd -- OUT_PREFIX
## Rows: 1 a heavy hit (freeze, squash, push); 2 a healthy and a hurt grunt side by side (cracks, limp); 3 a kill and the spark
## flying to the nearest house; 4 a Wizard Tower's wind-up and recoil. Writes OUT_PREFIX_juice_strip.png.

const COLS := 6


func _grab(frames: Array, cam: Camera3D, g: Game, focus: Vector3, off: Vector3) -> void:
	cam.global_position = focus + off
	cam.look_at(focus, Vector3.UP)
	frames.append(root.get_viewport().get_texture().get_image())


func _run(g: Game, seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	var last := t0
	while (Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		await process_frame
		var now := Time.get_ticks_msec()
		g.step(minf(0.05, (now - last) / 1000.0))
		last = now


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := args[0] if args.size() > 0 else "juice_shot"
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 5:
		await process_frame
	g.night = 2
	g.faith = 900
	g.cards = {}
	g.try_build("fire", Vector2i(5, 12))
	g.start_night()
	g._spawn_queue.clear()
	g.set_process(false)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 28
	g._hud.visible = false
	g._msg.visible = false
	var rows: Array = []
	# row 1: a heavy hit, 0.03 s apart
	var e: Enemy = g._spawn(Vector2i(14, 20), "grunt", NavGrid.cell_centre(Vector2i(14, 20)))
	e.slow(0.0001, 1000.0)
	e.hp = 90.0
	e.max_hp = 90.0
	var focus := e.global_position + Vector3(0, 0.025, 0)
	var row: Array = []
	for i in 3:
		await process_frame
	_grab(row, cam, g, focus, Vector3(0.0, 0.05, 0.13))
	e.take_damage(2.0, true, "", 0.09, Vector3(1, 0, 0))
	var t0 := Time.get_ticks_msec()
	var next := 0.0
	var last := t0
	while row.size() < COLS:
		await process_frame
		var now := Time.get_ticks_msec()
		g.step(minf(0.05, (now - last) / 1000.0))
		last = now
		if (now - t0) / 1000.0 >= next:
			next += 0.03
			_grab(row, cam, g, focus, Vector3(0.0, 0.05, 0.13))
	rows.append(row)
	e.queue_free()
	g.enemies.clear()
	# row 2: healthy vs hurt, walking
	row = []
	var a: Enemy = g._spawn(Vector2i(14, 20), "grunt", NavGrid.cell_centre(Vector2i(14, 20)) + Vector3(-0.03, 0, 0))
	var b: Enemy = g._spawn(Vector2i(14, 20), "grunt", NavGrid.cell_centre(Vector2i(14, 20)) + Vector3(0.03, 0, 0))
	b.hp = b.max_hp * 0.3
	focus = NavGrid.cell_centre(Vector2i(14, 20)) + Vector3(0, 0.025, 0)
	t0 = Time.get_ticks_msec()
	next = 0.0
	last = t0
	while row.size() < COLS:
		await process_frame
		var now2 := Time.get_ticks_msec()
		g.step(minf(0.05, (now2 - last) / 1000.0))
		last = now2
		if (now2 - t0) / 1000.0 >= next:
			next += 0.12
			focus = (a.global_position + b.global_position) * 0.5 + Vector3(0, 0.025, 0)
			_grab(row, cam, g, focus, Vector3(0.0, 0.07, 0.17))
	rows.append(row)
	for o in g.enemies.duplicate():
		o.queue_free()
	g.enemies.clear()
	# row 3: a kill, the spark flies to the nearest house
	row = []
	var h: House = g.houses[0]
	var kc := h.cell + Vector2i(3, 0)
	var k: Enemy = g._spawn(kc, "grunt", NavGrid.cell_centre(kc))
	k.slow(0.0001, 1000.0)
	k.hp = 5.0
	focus = (k.global_position + h.global_position) * 0.5 + Vector3(0, 0.03, 0)
	for i in 3:
		await process_frame
	_grab(row, cam, g, focus, Vector3(0.0, 0.2, 0.3))
	k.take_damage(9999.0, true, "", 0.04, Vector3(1, 0, 0))
	t0 = Time.get_ticks_msec()
	next = 0.0
	last = t0
	while row.size() < COLS:
		await process_frame
		var now3 := Time.get_ticks_msec()
		g.step(minf(0.05, (now3 - last) / 1000.0))
		last = now3
		if (now3 - t0) / 1000.0 >= next:
			next += 0.11
			_grab(row, cam, g, focus, Vector3(0.0, 0.2, 0.3))
	rows.append(row)
	# row 4: the Wizard Tower winds up and kicks back
	row = []
	var t: Tower = g.towers[0]
	var tgt: Enemy = g._spawn(Vector2i(9, 12), "grunt", NavGrid.cell_centre(Vector2i(9, 12)))
	tgt.slow(0.0001, 1000.0)
	tgt.hp = 500.0
	t.cooldown = 0.35
	focus = t.global_position + Vector3(0, 0.05, 0)
	t0 = Time.get_ticks_msec()
	next = 0.0
	last = t0
	while row.size() < COLS:
		await process_frame
		var now4 := Time.get_ticks_msec()
		g.step(minf(0.05, (now4 - last) / 1000.0))
		last = now4
		if (now4 - t0) / 1000.0 >= next:
			next += 0.09
			_grab(row, cam, g, focus, Vector3(0.0, 0.07, 0.17))
	rows.append(row)
	var w: int = rows[0][0].get_width()
	var ht: int = rows[0][0].get_height()
	var cw := int(w * 0.5)
	var ch := int(ht * 0.5)
	var sheet := Image.create(cw * COLS, ch * rows.size(), false, Image.FORMAT_RGBA8)
	for r in rows.size():
		for i in COLS:
			var f: Image = rows[r][i]
			f.convert(Image.FORMAT_RGBA8)
			f.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(f, Rect2i(0, 0, cw, ch), Vector2i(i * cw, r * ch))
	sheet.save_png("%s_juice_strip.png" % prefix)
	print("JUICESHOT saved ", prefix, "_juice_strip.png")
	quit()
