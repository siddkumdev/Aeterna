extends SceneTree
## Close-ups of the 2026-11-16 quest kinds with their props placed (desktop window, not --headless):
##   <godot console> --xr-mode off --resolution 1000x700 --path godot -s res://tools/quest_new_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_<kind>.png for laundry, well, apples, cat, weeds, bell, firewood and letter, plus
## OUT_PREFIX_wide_a.png / _wide_b.png (four quests each, from the seat), and prints each quest's house and spot.


func _hide_text(n: Node) -> void:
	if n is Label3D or n is Bubble or n is TitleCard:
		n.visible = false
	for c in n.get_children():
		_hide_text(c)


func _snap(name: String) -> void:
	for i in 6:
		await process_frame
	_hide_text(root)
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s.png" % name)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "quest_new"
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 5:
		await process_frame
	g._camera = null
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 40
	var groups := [["laundry", "well", "apples", "cat"], ["weeds", "bell", "firewood", "letter"]]
	var tags := ["a", "b"]
	for gi in 2:
		HelpRequest.shown_kinds.clear()
		g.force_quests(groups[gi])
		for i in 60:
			await process_frame
		cam.global_position = g.board.to_global(Vector3(0.0, 0.5, 1.05))
		cam.look_at(g.board.to_global(Vector3(0, 0.05, 0.25)), Vector3.UP)
		await _snap("%s_wide_%s" % [prefix, tags[gi]])
		for r: HelpRequest in g.requests:
			var pts: Array[Vector3] = []
			for n in r._items:
				pts.append(n.position)
			for n in r._extras:
				pts.append(n.position)
			if pts.is_empty():
				continue
			var lo := pts[0]
			var hi := pts[0]
			for p in pts:
				lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
				hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
			var c := (lo + hi) * 0.5
			var h: House = g.houses[r.house]
			var out := Vector3(c.x - h.position.x, 0, c.z - h.position.z)
			var up := 0.3
			var dist := 0.4
			if r.kind == "cat":  # on the roof ridge: look down at her
				c = r._items[0].position
				out = h.basis.z
				up = 0.25
				dist = 0.3
			elif r.kind == "bell":
				c = h.position + Vector3(0, 0.05, 0) + h.basis.z * 0.03
				out = h.basis.z
			out = out.normalized() if out.length() > 0.001 else h.basis.z
			cam.global_position = g.board.to_global(c + out * dist + Vector3(0, up, 0))
			cam.look_at(g.board.to_global(c + Vector3(0, 0.01, 0)), Vector3.UP)
			await _snap("%s_%s" % [prefix, r.kind])
			print("NEWSHOT ", r.kind, " house ", r.house, " items ", r._items.size(), " extras ", r._extras.size(), " prop ", r.prop.position)
	quit()
