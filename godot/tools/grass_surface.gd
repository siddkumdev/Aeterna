extends SceneTree
## Headless. Measures where the ground really is, in board space (y = 0 is the board plane), so the grass roots can be
## seated on it: every mesh under the island, the path tiles and the grass field, with its top and bottom in metres.
##   <godot console> --headless --xr-mode off --path godot -s res://tools/grass_surface.gd
func _initialize() -> void:
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 5:
		await process_frame
	var board: Node3D = g.board
	print("board y = ", board.global_position.y)
	_dump(board, board, 0)
	# the ground itself: straight-down rays through the island mesh (triangle mesh), a 48 x 48 grid over the playable cells
	var isl: MeshInstance3D = null
	for m in board.find_children("*", "MeshInstance3D", true, false):
		if str(m.get_path()).contains("ew_world_island_v01") and not str(m.get_path()).contains("underside"):
			isl = m
	var tm := isl.mesh.generate_triangle_mesh()
	var hits: Array[float] = []
	var half := GameConfig.SIZE * GameConfig.CELL / 2.0
	var step := (2.0 * (half - GameConfig.CELL)) / 47.0
	for ix in 48:
		for iz in 48:
			var wx := -half + GameConfig.CELL + ix * step
			var wz := -half + GameConfig.CELL + iz * step
			var from_l: Vector3 = isl.global_transform.affine_inverse() * (board.global_position + Vector3(wx, 1.0, wz))
			var r := tm.intersect_ray(from_l, Vector3.DOWN)
			if r.size() > 0:
				hits.append((isl.global_transform * (r["position"] as Vector3)).y - board.global_position.y)
	hits.sort()
	print("GROUND hits=%d min %+.4f p10 %+.4f median %+.4f p90 %+.4f max %+.4f (board space, metres)" % [hits.size(), hits[0], hits[hits.size() / 10], hits[hits.size() / 2], hits[hits.size() * 9 / 10], hits[-1]])
	var bins := {}
	for h in hits:
		var k := snappedf(h, 0.001)
		bins[k] = bins.get(k, 0) + 1
	var ks := bins.keys()
	ks.sort()
	for k in ks:
		print("  y %+.3f : %d" % [k, bins[k]])
	if g.grass:
		var mm: MultiMeshInstance3D = g.grass.get_child(0)
		print("GRASS inst y (board space) = ", mm.position.y, "  tuft count = ", g.grass.tuft_count())
	quit()


func _dump(n: Node, board: Node3D, depth: int) -> void:
	if n is MeshInstance3D and n.mesh:
		var bb: AABB = n.global_transform * n.mesh.get_aabb()
		var by: float = board.global_position.y
		var nm := str(n.get_path()).replace(str(board.get_path()), "")
		if depth <= 6 and (nm.contains("sland") or nm.contains("ath") or nm.contains("rass") or nm.contains("lan")):
			print("%-60s top %+.4f  bottom %+.4f  x %.3f..%.3f" % [nm.substr(0, 60), bb.end.y - by, bb.position.y - by, bb.position.x - board.global_position.x, bb.end.x - board.global_position.x])
	for c in n.get_children():
		_dump(c, board, depth + 1)
