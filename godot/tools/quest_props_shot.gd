extends SceneTree
## Shots of the quest prop models in the game (2026-11-18): kite on the roof, lamb, rain cloud over the dry field, the field after
## the rain, the gold mote, the ghost hand (desktop window, not --headless):
##   <godot console> --xr-mode off --resolution 1000x640 --path godot -s res://tools/quest_props_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_<kind>.png (close shot of each quest prop with its mote), OUT_PREFIX_field_wet.png, OUT_PREFIX_ghost.png.


func _hide_text(n: Node) -> void:
	if n is Label3D or n is Bubble or n is TitleCard:
		n.visible = false
	for c in n.get_children():
		_hide_text(c)


func _snap(cam: Camera3D, pos: Vector3, look: Vector3, name: String) -> void:
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	for i in 6:
		await process_frame
	_hide_text(root)
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(name)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "quest_props"
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
	g._clear_requests()
	HelpRequest.shown_kinds.clear()
	g.force_quests(["chimney", "bird", "rain"])
	for i in 60:
		await process_frame
	for r in g.requests:
		var p: Vector3 = r.prop.global_position
		var off := Vector3(0.05, 0.07, 0.11) if r.kind != "rain" else Vector3(0.0, 0.015, 0.08)
		await _snap(cam, p + off, p + Vector3(0, 0.01, 0), "%s_%s.png" % [prefix, r.kind])
	# the lamb led along the ground: walk it so the legs swing, then shoot
	for r in g.requests:
		if r.kind == "bird":
			r.engage()
			r.held = true
			for k in 8:
				r.move_to(r.prop.position + Vector3(0.004, 0, 0.002))
				r.tick(0.05, true)
				await process_frame
			var p2: Vector3 = r.prop.global_position
			await _snap(cam, p2 + Vector3(0.06, 0.04, 0.06), p2 + Vector3(0, 0.012, 0), "%s_lamb_walk.png" % prefix)
			r.held = false
	# the rain: carry the cloud over the field, let go, the field turns green
	for r in g.requests:
		if r.kind == "rain":
			r.held = true
			r.move_to(r._goal + Vector3(0, 0.03, 0))
			r.tick(0.3, true)
			r.tick(0.3, true)
			var done: bool = r.release()
			print("QUESTSHOT rain released done=", done)
			for i in 20:
				await process_frame
			var f: Vector3 = r.to_global(r._goal)
			await _snap(cam, f + Vector3(0.0, 0.14, 0.14), f, "%s_field_wet.png" % prefix)
	# the ghost hand pinching over the table
	var gh := GhostHand.carry(g.board, Vector3(-0.3, 0.03, 0.3), Vector3(-0.24, 0.03, 0.3))
	for i in 30:
		await process_frame
	var hp: Vector3 = gh.global_position
	await _snap(cam, hp + Vector3(0.05, 0.04, 0.09), hp + Vector3(0, 0.015, 0), "%s_ghost.png" % prefix)
	quit()
