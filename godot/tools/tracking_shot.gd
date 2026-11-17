extends SceneTree
## Quest tracking shots (2026-11-17): the pinned slip on the tray, the ledger's quest page, the point-the-way glow and the
## dotted trail on a few kinds (desktop window, not --headless):
##   <godot console> --xr-mode off --resolution 1100x720 --path godot -s res://tools/tracking_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_slip.png (seated view), _slip_close.png, _ledger.png, _point.png, _trail_<kind>.png.


func _hide_text(n: Node) -> void:
	if n is Label3D or n is Bubble or n is TitleCard:
		n.visible = false
	for c in n.get_children():
		_hide_text(c)


func _snap(name: String, frames := 8) -> void:
	for i in frames:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s.png" % name)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "tracking"
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 60
	cam.global_position = Vector3(0, 1.1, 0.2)
	var g: Game = load("res://scripts/game/game.gd").new()
	g.with_rig = true
	root.add_child(g)
	g._camera = cam
	for i in 12:
		await process_frame
	g.force_quests(["laundry", "well", "weeds", "firewood"])
	for i in 10:
		await process_frame
	var laundry: HelpRequest = g.requests[0]
	laundry.progress = 1.0
	laundry.engage()
	g.update_slip()
	cam.look_at(Vector3(g.board.global_position.x, 0.66, -0.2), Vector3.UP)  # the seated frame takes in the tray's front
	await _snap(prefix + "_slip")
	var tp := g._tray.global_position
	cam.global_position = tp + Vector3(0, 0.38, 0.42)
	cam.look_at(tp + Vector3(0, 0.0, 0.03), Vector3.UP)
	await _snap(prefix + "_slip_close")
	# before / after: the asker's house close up
	var lr: HelpRequest = g.requests[0]
	var hh: House = g.houses[lr.house]
	cam.fov = 45
	cam.global_position = g.board.to_global(hh.position + Vector3(0.0, 0.3, 0.3))
	cam.look_at(g.board.to_global(hh.position + Vector3(0, 0.02, 0)), Vector3.UP)
	await _snap(prefix + "_house_before")
	g.point_active_quest()
	await _snap(prefix + "_house_after", 14)
	cam.fov = 60
	cam.global_position = g.board.to_global(Vector3(0.0, 0.55, 0.95))
	cam.look_at(g.board.to_global(Vector3(0, 0.03, 0.1)), Vector3.UP)
	await _snap(prefix + "_point", 10)
	_hide_text(g)
	for r: HelpRequest in g.requests:
		if r.kind == "laundry" or r.kind == "well" or r.kind == "weeds":
			var h: House = g.houses[r.house]
			var c := (r.prop.position + r._goal) * 0.5 if r.kind != "weeds" else r.prop.position
			var out: Vector3 = h.basis.z
			cam.fov = 40
			cam.global_position = g.board.to_global(c + Vector3(0, 0.34, 0.2))
			cam.look_at(g.board.to_global(c + Vector3(0, 0.01, 0)), Vector3.UP)
			print("TRACK ", r.kind, " dots ", r.trail_dots(), " from ", r._trail_from, " to ", r._trail_to, " visible ", r._trail.visible)
			await _snap("%s_trail_%s" % [prefix, r.kind])
	# the ledger, quests page
	g.toggle_ledger()
	for i in 20:
		await process_frame
	g.ledger.set_page(4)
	for i in 40:
		await process_frame
	g.ledger.redraw()
	cam.global_position = g.ledger.global_position + g.ledger.global_basis.z * 0.45
	cam.look_at(g.ledger.global_position, Vector3.UP)
	await _snap(prefix + "_ledger", 20)
	quit()
