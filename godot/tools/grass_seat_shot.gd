extends SceneTree
## Needs a window. Side-on close-ups at table level of where the grass meets the ground (is it seated or floating?):
##   <godot console> --xr-mode off --path godot -s res://tools/grass_seat_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_meadow.png (open meadow, camera a hair above the ground, looking along it), _house.png (a house
## base and the grass hugging it), _edge.png (the island rim). The camera height comes from a ray cast at the spot,
## so the same shot is comparable before and after a fix.


func _initialize() -> void:
	var prefix := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "grass_seat"
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 5:
		await process_frame
	g.set_process(false)
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	cam.fov = 30
	cam.near = 0.004
	var bp: Vector3 = g.board.global_position
	var cell := GameConfig.CELL
	var half := GameConfig.SIZE * cell / 2.0
	var spots := {
		"meadow": [Vector3(0.30, 0, 0.30), Vector3(0.0, 0.0, 0.30)],
		"house": [_house_point(g), Vector3(0.0, 0.0, 0.30)],
		"edge": [Vector3(0.0, 0, half - 0.06), Vector3(0.0, 0.0, 0.30)],
	}
	for k in spots:
		var at: Vector3 = bp + spots[k][0]
		var gy := _ground_y(g, at)
		var focus := Vector3(at.x, gy + 0.006, at.z)
		cam.global_position = focus + spots[k][1] + Vector3(0, 0.020, 0)  # a little above the blade tips, looking slightly down
		cam.look_at(focus, Vector3.UP)
		for i in 4:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [prefix, k])
		print("SEAT %s: ground y = %+.4f (board space)" % [k, gy - bp.y])
	quit()


func _house_point(g: Game) -> Vector3:
	var h: Vector2i = GameConfig.HOUSE_CELLS[0]
	var half := GameConfig.SIZE * GameConfig.CELL / 2.0
	return Vector3((h.x + 1.0) * GameConfig.CELL - half, 0, (h.y + 2.6) * GameConfig.CELL - half)


func _ground_y(g: Game, world: Vector3) -> float:
	## Highest island-mesh hit straight below world's x,z (the island glb only, not the dressing meshes).
	var best := -INF
	for m in g.board.find_children("*", "MeshInstance3D", true, false):
		var p := str(m.get_path())
		if not p.contains("ew_world_island_v01") or p.contains("underside"):
			continue
		var tm: TriangleMesh = m.mesh.generate_triangle_mesh()
		var from_l: Vector3 = m.global_transform.affine_inverse() * Vector3(world.x, world.y + 1.0, world.z)
		var r := tm.intersect_ray(from_l, Vector3.DOWN)
		if r.size() > 0:
			best = maxf(best, (m.global_transform * (r["position"] as Vector3)).y)
	return best
