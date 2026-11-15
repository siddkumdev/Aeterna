class_name WorldBuilder
extends RefCounted
## Builds the static board: the island, the forest ring on the edge cells and the build grid lines.
## The forest must look natural, not placed (Siddharth): clumps are jittered, turned and scaled at random,
## variants are mixed, the three spawn gaps stay open and the south edge (facing the player) is kept
## low and sparse so it does not hide the village. Seeded, so a run always looks the same.

const ISLAND := "res://assets/world/ew_world_island_v01.glb"
const UNDERSIDE := "res://assets/world/ew_world_island_underside_v03.glb"
const CLUMPS: Array[String] = [
	"res://assets/world/ew_world_forest_clump_dark_v02.glb",
	"res://assets/world/ew_world_forest_clump_mix_v03.glb",
	"res://assets/world/ew_world_forest_clump_low_v02.glb",
]
const LOW_CLUMP := "res://assets/world/ew_world_forest_clump_low_v02.glb"
# The grass top is 0.09 m above the island's base (make_island.py HEIGHT; ray casts in tools/grass_surface.gd confirm it).
# This was 0.115 until 2026-11-10: that was the height of the tallest baked tuft or stone, so the whole island sat 2.5 cm
# too deep and the grass, houses and props floated above the ground. y = 0 on the board is now the grass itself.
const ISLAND_HEIGHT := 0.09
const ISLAND_CELLS := 12  # the approved island v01 is built for 12 x 12 cells (0.6 m)


static func build_island(board: Node3D) -> void:
	var island: Node3D = load(ISLAND).instantiate()
	island.position.y = -ISLAND_HEIGHT
	# STAND-IN: the board grew to 24 x 24; stretch v01 across it (height unchanged) until a 1.2 m island is built
	var s := float(GameConfig.SIZE) / ISLAND_CELLS
	island.scale = Vector3(s, 1.0, s)
	board.add_child(island)


## The floating sky-island rock under the island (W02). Its origin is the attach plane = the island's base, and it is built
## for the stretched 24 x 24 island (0.57 m half width), so it is not scaled. The drifting rocks bob and the leaf fins turn
## slowly; the thrust anchor carries the IslandThrust propulsion effect; IslandWorkers stands the characters at the worker anchors.
static func build_underside(board: Node3D) -> Node3D:
	var under: Node3D = load(UNDERSIDE).instantiate()
	under.position.y = -ISLAND_HEIGHT
	board.add_child(under)
	for n in under.find_children("*", "Node3D", true, false):
		var part := str(n.get_meta("ew_part", ""))
		if part == "drift" or part == "fins":
			for m in ModelUtil.walk(n):
				if m is MeshInstance3D:
					(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if part == "drift":
			var tw := n.create_tween().set_loops()
			tw.tween_property(n, "position:y", n.position.y + 0.012, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(n, "position:y", n.position.y - 0.012, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		elif part == "fins":
			var tw2 := n.create_tween().set_loops()
			tw2.tween_property(n, "rotation:y", TAU, 24.0).as_relative()
	for a in under.find_children("*", "Marker3D", true, false):
		if a.name.ends_with("thrust_anchor"):
			var thrust := IslandThrust.new()
			a.add_child(thrust)
			thrust.setup(float(a.get_meta("ew_size", 0.06)))
	return under


static func build_forest(board: Node3D, rng_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var scenes := {}
	for p in CLUMPS:
		scenes[p] = load(p)
	var forest := Node3D.new()
	forest.name = "Forest"
	board.add_child(forest)
	var gaps: Array[Vector2i] = []
	for k in GameConfig.SPAWNS:
		gaps.append_array(GameConfig.SPAWNS[k])
	var n := GameConfig.SIZE
	var half := n * GameConfig.CELL / 2.0
	# Walk the edge ring in steps of about 1.6 cells. Each point sits on the middle of the edge cells.
	var edges := [
		["north", Vector2(0.5, 0.5), Vector2(1, 0)],
		["east", Vector2(n - 0.5, 0.5), Vector2(0, 1)],
		["south", Vector2(n - 0.5, n - 0.5), Vector2(-1, 0)],
		["west", Vector2(0.5, n - 0.5), Vector2(0, -1)],
	]
	for e in edges:
		var side: String = e[0]
		var start: Vector2 = e[1]
		var along: Vector2 = e[2]
		var t := rng.randf_range(0.0, 0.8)
		while t < n - 1.0:
			var c := start + along * t
			var spacing := rng.randf_range(1.4, 1.9)
			if side == "south":
				spacing *= 1.7  # sparse in front of the player
			t += spacing
			var near_gap := false
			for g in gaps:
				if Vector2(g).distance_to(c - Vector2(0.5, 0.5)) < 1.3:
					near_gap = true
			if near_gap:
				continue
			var path: String = LOW_CLUMP if side == "south" else CLUMPS[rng.randi_range(0, CLUMPS.size() - 1)]
			var clump: Node3D = scenes[path].instantiate()
			var inward := Vector2(-along.y, along.x)  # points into the board
			var jitter := along * rng.randf_range(-0.25, 0.25) + inward * rng.randf_range(-0.15, 0.2)
			var p := (c + jitter) * GameConfig.CELL - Vector2(half, half)
			clump.position = Vector3(p.x, 0.0, p.y)
			# long side roughly along the edge, then a free turn so no two clumps line up
			clump.rotation.y = atan2(along.x, along.y) + PI / 2.0 + rng.randf_range(-0.6, 0.6) + (PI if rng.randf() < 0.5 else 0.0)
			var s := rng.randf_range(0.8, 1.15) * (0.8 if side == "south" else 1.0)
			clump.scale = Vector3(s, s * rng.randf_range(0.9, 1.1), s)
			forest.add_child(clump)
	ModelUtil.merge_static_meshes(forest, [], GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "ForestMerged")


static func build_grid_lines(board: Node3D) -> MeshInstance3D:
	## Faint cell lines over the inner cells, shown only while placing a tower.
	var n := GameConfig.SIZE
	var cell := GameConfig.CELL
	var half := n * cell / 2.0
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(1, n):
		var p := -half + i * cell
		im.surface_add_vertex(Vector3(p, 0.0015, -half + cell))
		im.surface_add_vertex(Vector3(p, 0.0015, half - cell))
		im.surface_add_vertex(Vector3(-half + cell, 0.0015, p))
		im.surface_add_vertex(Vector3(half - cell, 0.0015, p))
	im.surface_end()
	var lines := MeshInstance3D.new()
	lines.mesh = im
	lines.material_override = ModelUtil.flat_material(Color8(0xFF, 0xF4, 0xDC), true, 0.35)
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lines.visible = false
	board.add_child(lines)
	return lines


static func build_rim_handles(board: Node3D) -> Array[MeshInstance3D]:
	## Four carved wood-and-brass grab handles along the cardinal edges so seated players can see where to spin/slide the island.
	var half := GameConfig.SIZE * GameConfig.CELL / 2.0
	var root := Node3D.new()
	root.name = "RimHandles"
	board.add_child(root)
	var rails: Array[MeshInstance3D] = []
	var rail_nodes: Array[Node] = []
	var wood_mat := ModelUtil.flat_material(Color8(0x5B, 0x29, 0x20))  # wood_dark
	var brass_mat := ModelUtil.flat_material(Color8(0xF2, 0xB6, 0x30))  # brass/rarity_gold
	brass_mat.emission_enabled = true
	brass_mat.emission = Color8(0xF6, 0xA4, 0x5D)
	brass_mat.emission_energy_multiplier = 0.18
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(0.20, 0.016, 0.018)
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.022, 0.020, 0.032)
	var sides := [
		[Vector3(0, -0.002, half + 0.032), 0.0],
		[Vector3(0, -0.002, -(half + 0.032)), PI],
		[Vector3(half + 0.032, -0.002, 0), PI / 2.0],
		[Vector3(-(half + 0.032), -0.002, 0), -PI / 2.0],
	]
	for side in sides:
		var holder := Node3D.new()
		holder.position = side[0]
		holder.rotation.y = side[1]
		root.add_child(holder)
		for sx in [-0.082, 0.082]:
			var post := MeshInstance3D.new()
			post.mesh = post_mesh
			post.material_override = wood_mat
			post.position = Vector3(sx, 0.0, -0.014)
			post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(post)
		var rail := MeshInstance3D.new()
		rail.mesh = rail_mesh
		rail.material_override = brass_mat
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(rail)
		rails.append(rail)
		rail_nodes.append(rail)
	ModelUtil.merge_static_meshes(root, rail_nodes, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "HandlesMerged")
	return rails
