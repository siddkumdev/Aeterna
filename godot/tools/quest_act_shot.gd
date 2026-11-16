extends SceneTree
## Shots for the quest act-out, the quest outline and the table-turn-proof HUD text (desktop window, not --headless):
##   <godot console> --xr-mode off --resolution 1000x640 --path godot -s res://tools/quest_act_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_hud_turned.png (the tutorial text and day clock behind a table turned 130 degrees),
## OUT_PREFIX_actout.png (a strip of the asker hopping, waving both arms and pointing at the kite),
## OUT_PREFIX_outline.png (the kite, the lamb and the three lanterns outlined, before anyone touched them).


func _hide_text(n: Node) -> void:
	if n is Label3D or n is Bubble or n is TitleCard:
		n.visible = false
	for c in n.get_children():
		_hide_text(c)


func _snap(cam: Camera3D, pos: Vector3, look: Vector3, hide := true) -> Image:
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	for i in 4:
		await process_frame
	if hide:
		_hide_text(root)
		await process_frame
	return root.get_viewport().get_texture().get_image()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "quest_act"
	var l: Launcher = load("res://scripts/ui/launcher.gd").new()
	root.add_child(l)
	for i in 40:
		await process_frame
	l._press_plaque("skip")
	for i in 30:
		await process_frame
	var g := l.game
	g._camera = null
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 40
	var b := g.board
	# 1: text behind a turned table
	b.rotation.y = deg_to_rad(130.0)
	await create_timer(0.6).timeout
	(await _snap(cam, b.to_global(Vector3(0.0, 0.0, 0.0)) + Vector3(0, 0.55, 0.95), b.global_position + Vector3(0, 0.15, -0.3), false)).save_png(prefix + "_hud_turned.png")
	b.rotation.y = 0.0
	# 2: act-out strip
	g._clear_requests()
	HelpRequest.shown_kinds.clear()
	g.force_quests(["chimney"])
	for i in 150:
		await process_frame
	var r: HelpRequest = g.requests[0]
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 60000 and r.asker().rig.anim != "plead":  # the asker walks over first
		await process_frame
	var strip: Array[Image] = []
	for k in 8:
		var who := r.asker()
		var p := who.global_position + Vector3(0, 0.03, 0)
		print("ACTSHOT asker ", who.key, " state ", who.state, " anim ", who.rig.anim, " pos ", who.position)
		var fwd: Vector3 = b.to_global(who.ask_face) - who.global_position
		fwd = Vector3(fwd.x, 0, fwd.z).normalized()
		strip.append(await _snap(cam, p + fwd.cross(Vector3.UP) * 0.11 - fwd * 0.03 + Vector3(0, 0.02, 0), p))
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 300:
			await process_frame
	var w := strip[0].get_width() / 2
	var h := strip[0].get_height() / 2
	var sheet := Image.create(w * 4, h * 2, false, Image.FORMAT_RGBA8)
	for i in strip.size():
		var im: Image = strip[i]
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, h)
		sheet.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % 4) * w, (i / 4) * h))
	sheet.save_png(prefix + "_actout.png")
	# 3: outlines
	g._clear_requests()
	g.force_quests(["chimney", "bird", "lights"])
	for i in 100:
		await process_frame
	var names := ["kite", "lamb", "lights"]
	for i in 3:
		var q: HelpRequest = g.requests[i]
		var f := q.focus_point() + Vector3(0, 0.02, 0)
		(await _snap(cam, f + Vector3(0.0, 0.07, 0.14), f)).save_png(prefix + "_outline_" + names[i] + ".png")
	var kq: HelpRequest = g.requests[0]
	kq._stop_outline()
	var f3 := kq.focus_point() + Vector3(0, 0.02, 0)
	(await _snap(cam, f3 + Vector3(0.0, 0.07, 0.14), f3)).save_png(prefix + "_nooutline_kite.png")
	var lamb: HelpRequest = g.requests[1]
	lamb._stop_outline()
	var f2 := lamb.focus_point() + Vector3(0, 0.02, 0)
	(await _snap(cam, f2 + Vector3(0.0, 0.07, 0.14), f2)).save_png(prefix + "_nooutline_lamb.png")
	for rq in g.requests:
		print("ACTSHOT ", rq.kind, " outlined ", rq._outlined.size(), " ask_face ", rq.asker().ask_face if rq.asker() else "-")
	quit()
