class_name NavGrid
extends RefCounted
## The board grid (GameConfig.SIZE square) as the enemies see it: which cells can be walked, and the route from a spawn to a house.
## Enemies walk around towers and houses (spec 2; towers cannot be damaged in this slice). The forest ring
## on the edge cells is not walkable except at the three spawn gaps. Pure logic, no nodes: tested headless.

const N := GameConfig.SIZE

var astar := AStarGrid2D.new()
var kind: Dictionary = {}  # Vector2i -> "forest" | "spawn" | "house" | "tower"
var house_cells: Array = []  # per house: Array[Vector2i] of its footprint


func _init() -> void:
	astar.region = Rect2i(0, 0, N, N)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	var spawn_cells := {}
	for k in GameConfig.SPAWNS:
		for c in GameConfig.SPAWNS[k]:
			spawn_cells[c] = true
	for x in range(N):
		for y in range(N):
			var c := Vector2i(x, y)
			if x == 0 or y == 0 or x == N - 1 or y == N - 1:
				if spawn_cells.has(c):
					kind[c] = "spawn"
				else:
					kind[c] = "forest"
					astar.set_point_solid(c, true)
	for h in GameConfig.HOUSE_CELLS:
		var cells := footprint(h, GameConfig.TOWER_SIZE)
		house_cells.append(cells)
		for c in cells:
			kind[c] = "house"
			astar.set_point_solid(c, true)


static func footprint(top_left: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx in range(size.x):
		for dy in range(size.y):
			out.append(Vector2i(top_left.x + dx, top_left.y + dy))
	return out


func goals_of(house: int) -> Array[Vector2i]:
	## Walkable cells next to (4-neighbour) a house: where a Grunt stands to hit it.
	var out: Array[Vector2i] = []
	for c in house_cells[house]:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if astar.is_in_boundsv(n) and not astar.is_point_solid(n) and not out.has(n):
				out.append(n)
	return out


func route(from: Vector2i, houses: Array[int]) -> Dictionary:
	## Shortest route from a cell to the nearest reachable house among `houses`.
	## Returns {"house": index, "path": Array[Vector2i]} or {} when none can be reached.
	var best := {}
	var best_len := INF
	for h in houses:
		for g in goals_of(h):
			var p: Array[Vector2i] = astar.get_id_path(from, g)
			if p.is_empty():
				continue
			var length := 0.0
			for i in range(1, p.size()):
				length += Vector2(p[i] - p[i - 1]).length()
			if length < best_len:
				best_len = length
				best = {"house": h, "path": p}
	return best


func can_build(top_left: Vector2i, size: Vector2i, standing: Array[int]) -> bool:
	## A tower fits if every cell is plain open ground and every spawn can still reach a standing house.
	var cells := footprint(top_left, size)
	for c in cells:
		if not astar.is_in_boundsv(c) or kind.has(c):
			return false
	for c in cells:
		astar.set_point_solid(c, true)
	var ok := true
	for k in GameConfig.SPAWNS:
		if route(GameConfig.SPAWNS[k][0], standing).is_empty():
			ok = false
			break
	for c in cells:
		astar.set_point_solid(c, false)
	return ok


func add_tower(top_left: Vector2i, size: Vector2i) -> void:
	for c in footprint(top_left, size):
		kind[c] = "tower"
		astar.set_point_solid(c, true)


func remove_tower(top_left: Vector2i, size: Vector2i) -> void:
	for c in footprint(top_left, size):
		if kind.get(c, "") == "tower":
			kind.erase(c)
			astar.set_point_solid(c, false)


func clear_towers() -> void:
	for c in kind.keys():
		if kind[c] == "tower":
			kind.erase(c)
			astar.set_point_solid(c, false)


static func cell_centre(cell: Vector2i) -> Vector3:
	## Board-local centre of one cell (board origin = board centre, top surface at y = 0).
	var half := N * GameConfig.CELL / 2.0
	return Vector3(-half + (cell.x + 0.5) * GameConfig.CELL, 0.0, -half + (cell.y + 0.5) * GameConfig.CELL)


static func footprint_centre(top_left: Vector2i, size: Vector2i) -> Vector3:
	var half := N * GameConfig.CELL / 2.0
	return Vector3(-half + (top_left.x + size.x / 2.0) * GameConfig.CELL, 0.0, -half + (top_left.y + size.y / 2.0) * GameConfig.CELL)


static func local_to_cell(p: Vector3) -> Vector2i:
	var half := N * GameConfig.CELL / 2.0
	return Vector2i(floori((p.x + half) / GameConfig.CELL), floori((p.z + half) / GameConfig.CELL))
