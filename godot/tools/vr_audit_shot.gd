extends SceneTree
## Needs a window. Tier comparison shots of the game (day + night, seat view, house / grass / tower / villager close-ups):
##   AETERNA_TIER=2 <godot console> --xr-mode off --path godot -s res://tools/vr_audit_shot.gd -- OUT_PREFIX
## AETERNA_TIER: unset = desktop look, 1 = low Quest, 2 = Quest 3 (PerfTier forced on the PC). Sets the window to 1832x1920 / 2 (one eye).


func _initialize() -> void:
	var prefix := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "vr_audit"
	root.size = Vector2i(1280, 960)
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 8:
		await process_frame
	g.faith = 3000
	g.try_build("crossbow", Vector2i(3, 9))
	g.try_build("guard", Vector2i(19, 9))
	g.try_build("fire", Vector2i(16, 11))
	g.select("")
	g._mouse_hand.global_position = Vector3(0, 3, 0)
	await _settle()
	await _views(g, prefix + "_day")
	g.speed = 0.0
	g.night = 2
	g.start_night()
	var t := 0.0
	while t < 17.0:
		g.step(0.05)
		t += 0.05
	await _settle()
	await _views(g, prefix + "_night")
	quit()


func _views(g: Game, name: String) -> void:
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	var bp: Vector3 = g.board.global_position
	var cell := GameConfig.CELL
	var half := GameConfig.SIZE * cell / 2.0
	var h: Vector2i = GameConfig.HOUSE_CELLS[0]
	var house := bp + Vector3((h.x + 1.0) * cell - half, 0.02, (h.y + 2.0) * cell - half)
	var tower := bp + Vector3((3 + 1.0) * cell - half, 0.03, (9 + 1.0) * cell - half)
	var views := {
		"seat": [bp + Vector3(0, 0.0, 0.0), Vector3(0, 0.55, 0.62), 60.0],
		"house": [house, Vector3(0.12, 0.10, 0.20), 40.0],
		"grass": [bp + Vector3(0.25, 0.01, 0.25), Vector3(0.0, 0.07, 0.22), 40.0],
		"tower": [tower, Vector3(0.1, 0.09, 0.2), 40.0],
	}
	for k in views:
		var v: Array = views[k]
		cam.fov = v[2]
		cam.near = 0.01
		cam.global_position = (v[0] as Vector3) + (v[1] as Vector3)
		cam.look_at(v[0], Vector3.UP)
		for i in 4:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [name, k])


func _settle() -> void:
	await create_timer(1.6).timeout
