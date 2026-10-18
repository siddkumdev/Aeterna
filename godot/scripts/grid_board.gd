class_name GridBoard
extends RefCounted
## Pure grid rules, no nodes and no XR, so it can be unit-tested headless.
## Everything is in cells: 1 cell = 0.05 m, board is SIZE x SIZE cells, centred on the board origin.
## A footprint is anchored by its top-left cell (x = column, y = row).

const CELL := 0.05
const SIZE := 12
const CANCEL_MARGIN_CELLS := 1.5  # dragging this far past the board edge cancels a move

var occupied: Dictionary = {}  # Vector2i -> int (item id)


func half_extent() -> float:
	return SIZE * CELL / 2.0


func in_bounds(cell: Vector2i, size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x + size.x <= SIZE and cell.y + size.y <= SIZE


func is_free(cell: Vector2i, size: Vector2i, ignore_id: int = -1) -> bool:
	for dx in range(size.x):
		for dy in range(size.y):
			var id: int = occupied.get(Vector2i(cell.x + dx, cell.y + dy), -1)
			if id != -1 and id != ignore_id:
				return false
	return true


func can_place(cell: Vector2i, size: Vector2i, ignore_id: int = -1) -> bool:
	return in_bounds(cell, size) and is_free(cell, size, ignore_id)


func place(id: int, cell: Vector2i, size: Vector2i) -> void:
	for dx in range(size.x):
		for dy in range(size.y):
			occupied[Vector2i(cell.x + dx, cell.y + dy)] = id


func remove(id: int) -> void:
	for k in occupied.keys():
		if occupied[k] == id:
			occupied.erase(k)


func local_to_cell(p: Vector3, size: Vector2i) -> Vector2i:
	## Top-left cell of the footprint whose centre is nearest to board-local point p, clamped onto the board.
	var cx := roundi((p.x + half_extent()) / CELL - size.x / 2.0)
	var cy := roundi((p.z + half_extent()) / CELL - size.y / 2.0)
	return Vector2i(clampi(cx, 0, SIZE - size.x), clampi(cy, 0, SIZE - size.y))


func cell_centre(cell: Vector2i, size: Vector2i) -> Vector3:
	return Vector3(
		-half_extent() + (cell.x + size.x / 2.0) * CELL,
		0.0,
		-half_extent() + (cell.y + size.y / 2.0) * CELL)


func is_off_board(p: Vector3) -> bool:
	var limit := half_extent() + CANCEL_MARGIN_CELLS * CELL
	return absf(p.x) > limit or absf(p.z) > limit


func nearest_valid(cell: Vector2i, size: Vector2i, ignore_id: int = -1, max_radius: int = 2) -> Variant:
	## The wanted cell if free, else the closest free anchor within max_radius cells, else null.
	if can_place(cell, size, ignore_id):
		return cell
	var best: Variant = null
	var best_d := INF
	for dx in range(-max_radius, max_radius + 1):
		for dy in range(-max_radius, max_radius + 1):
			var c := Vector2i(cell.x + dx, cell.y + dy)
			if can_place(c, size, ignore_id):
				var d := float(dx * dx + dy * dy)
				if d < best_d:
					best_d = d
					best = c
	return best
