class_name WorldBuilder
extends RefCounted
## Builds the static board: the island, the forest ring on the edge cells and the build grid lines.
## The forest must look natural, not placed (Siddharth): clumps are jittered, turned and scaled at random,
## variants are mixed, the three spawn gaps stay open and the south edge (facing the player) is kept
## low and sparse so it does not hide the village. Seeded, so a run always looks the same.

const ISLAND := "res://assets/world/ew_world_island_v01.glb"
const UNDERSIDE := "res://assets/world/ew_world_island_underside_v02.glb"
const CLUMPS: Array[String] = [
	"res://assets/world/ew_world_forest_clump_dark_v02.glb",
	"res://assets/world/ew_world_forest_clump_mix_v02.glb",
	"res://assets/world/ew_world_forest_clump_low_v02.glb",
]
const LOW_CLUMP := "res://assets/world/ew_world_forest_clump_low_v02.glb"
const ISLAND_HEIGHT := 0.115  # measured: the island's top surface is 0.115 m above its base
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
## slowly; the villager arms and the thrust / energy anchors are left for the VFX pass.
static func build_underside(board: Node3D) -> Node3D:
	var under: Node3D = load(UNDERSIDE).instantiate()
	under.position.y = -ISLAND_HEIGHT
	board.add_child(under)
	for n in under.find_children("*", "Node3D", true, false):
		var part := str(n.get_meta("ew_part", ""))
		if part == "drift":
			var tw := n.create_tween().set_loops()
			tw.tween_property(n, "position:y", n.position.y + 0.012, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(n, "position:y", n.position.y - 0.012, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		elif part == "fins":
			var tw2 := n.create_tween().set_loops()
			tw2.tween_property(n, "rotation:y", TAU, 24.0).as_relative()
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
	lines.visible = false
	board.add_child(lines)
	return lines
