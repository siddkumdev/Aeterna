extends SceneTree
## A filmstrip of the combat-feel effects (desktop window needed, not --headless):
##   <godot console> --xr-mode off --path godot -s res://tools/combat_shot.gd -- OUT_PREFIX
## Each of grunt, scout, splitter, tunneler and wisp takes a hit and then dies, one at a time.
## Writes OUT_PREFIX_combat_strip.png: one row per kind: a hit, then the death 0.08 s apart.

const COLS := 6
const STEP := 0.08
const KINDS := ["grunt", "scout", "splitter", "tunneler", "wisp"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := args[0] if args.size() > 0 else "combat_shot"
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 5:
		await process_frame
	g.night = 2
	g.start_night()
	g._spawn_queue.clear()
	g.set_process(false)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 28
	g._hud.visible = false
	g._msg.visible = false
	var rows: Array = []  # one row of frames per kind: a hit, then the death every 0.08 s
	for k in KINDS.size():
		var c := Vector2i(10, 12)
		var at := NavGrid.cell_centre(c) + Vector3(0, 0.05 if KINDS[k] == "wisp" else 0.0, 0)
		var e: Enemy = g._spawn(c, KINDS[k], at)
		e.slow(0.0001, 1000.0)
		e.hp = 60.0
		if KINDS[k] == "tunneler":
			e._pop_up()  # already surfaced, so it is a body to hit
		var focus := e.global_position + Vector3(0, 0.02, 0)
		cam.global_position = focus + Vector3(0.0, 0.1, 0.12)
		cam.look_at(focus, Vector3.UP)
		for i in 4:
			await process_frame
		e.take_damage(1.0)
		var th := Time.get_ticks_msec()
		while Time.get_ticks_msec() - th < 60:  # the spark shows a moment after the hit
			g.step(1.0 / 60.0)
			await process_frame
		var row: Array[Image] = [root.get_viewport().get_texture().get_image()]
		e.take_damage(9999.0)
		var t0 := Time.get_ticks_msec()
		var next := 0.0
		while row.size() < COLS:  # the effects run on real time, so the frames are taken on real time too
			g.step(1.0 / 60.0)
			await process_frame
			var t := (Time.get_ticks_msec() - t0) / 1000.0
			if t >= next:
				next += STEP
				row.append(root.get_viewport().get_texture().get_image())
		rows.append(row)
		t0 = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 1200:  # let the effects finish and the splitlings go
			g.step(1.0 / 60.0)
			await process_frame
		for o in g.enemies.duplicate():
			if is_instance_valid(o):
				o.queue_free()
		g.enemies.clear()
	var w: int = rows[0][0].get_width()
	var h: int = rows[0][0].get_height()
	var cw := int(w * 0.5)
	var ch := int(h * 0.5)
	var sheet := Image.create(cw * COLS, ch * rows.size(), false, Image.FORMAT_RGBA8)
	for r in rows.size():
		for i in COLS:
			var f: Image = rows[r][i]
			f.convert(Image.FORMAT_RGBA8)
			f.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(f, Rect2i(0, 0, cw, ch), Vector2i(i * cw, r * ch))
	sheet.save_png("%s_combat_strip.png" % prefix)
	print("COMBATSHOT saved ", prefix, "_combat_strip.png")
	quit()
