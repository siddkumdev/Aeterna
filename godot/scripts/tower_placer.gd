class_name TowerPlacer
extends Node3D
## Pick up / drag / drop placement on the grid. Input-agnostic: a hand (or a test) calls
## pick_by_ray / pick_by_point, begin_hold, update_hold, end_hold. No XR types in here.

const GridBoardScript := preload("res://scripts/grid_board.gd")
const LIFT := 0.04  # held items hover this far above the board (metres)

var board: Node3D  # board root; its local XZ plane is the grid, origin at the board centre
var grid: GridBoard = GridBoardScript.new()
var items: Dictionary = {}  # id -> {node, cell, size, height}
var held: Dictionary = {}   # hand_id (String) -> item id
var ghost: MeshInstance3D
var ghost_mat: StandardMaterial3D
var _next_id := 1
var _hover: int = -1


func setup(board_root: Node3D) -> void:
	board = board_root
	ghost = MeshInstance3D.new()
	var bm := BoxMesh.new()
	ghost.mesh = bm
	ghost_mat = StandardMaterial3D.new()
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.material_override = ghost_mat
	ghost.visible = false
	board.add_child(ghost)


func add_item(node: Node3D, cell: Vector2i, size: Vector2i, height: float) -> int:
	var id := _next_id
	_next_id += 1
	items[id] = {"node": node, "cell": cell, "size": size, "height": height}
	grid.place(id, cell, size)
	board.add_child(node)
	node.position = grid.cell_centre(cell, size)
	return id


func item_aabb(id: int) -> AABB:
	## World-space bounding box of an item's footprint and height.
	var it: Dictionary = items[id]
	var n: Node3D = it["node"]
	var size: Vector2i = it["size"]
	var half := Vector3(size.x * GridBoard.CELL / 2.0, it["height"] / 2.0, size.y * GridBoard.CELL / 2.0)
	var centre := n.global_position + Vector3(0, it["height"] / 2.0, 0)
	return AABB(centre - half, half * 2.0)


func pick_by_ray(origin: Vector3, dir: Vector3) -> int:
	var best := -1
	var best_t := INF
	for id in items:
		if _is_held(id):
			continue
		var hit: Variant = item_aabb(id).intersects_ray(origin, dir)
		if hit != null:
			var t := origin.distance_to(hit)
			if t < best_t:
				best_t = t
				best = id
	return best


func pick_by_point(p: Vector3, radius: float = 0.07) -> int:
	var best := -1
	var best_d := radius
	for id in items:
		if _is_held(id):
			continue
		var box := item_aabb(id).grow(radius * 0.5)
		if box.has_point(p):
			var d := p.distance_to(box.get_center())
			if d < best_d or best == -1:
				best_d = d
				best = id
	return best


func set_hover(id: int) -> void:
	if id == _hover:
		return
	if _hover != -1 and items.has(_hover):
		items[_hover]["node"].scale = Vector3.ONE
	_hover = id
	if id != -1 and items.has(id) and not _is_held(id):
		items[id]["node"].scale = Vector3.ONE * 1.06


func _is_held(id: int) -> bool:
	return held.values().has(id)


func begin_hold(hand_id: String, id: int) -> bool:
	if id == -1 or not items.has(id) or _is_held(id) or held.has(hand_id):
		return false
	var it: Dictionary = items[id]
	grid.remove(id)  # frees the cells so the item can be re-placed where it was
	held[hand_id] = id
	(it["node"] as Node3D).scale = Vector3.ONE
	_hover = -1
	return true


func update_hold(hand_id: String, target_world: Vector3) -> void:
	if not held.has(hand_id):
		return
	var id: int = held[hand_id]
	var it: Dictionary = items[id]
	var node: Node3D = it["node"]
	var size: Vector2i = it["size"]
	var local := board.to_local(target_world)
	node.global_position = target_world + board.global_transform.basis.y * LIFT
	if grid.is_off_board(local):
		ghost.visible = false
		return
	var want := grid.local_to_cell(local, size)
	var spot: Variant = grid.nearest_valid(want, size, id)
	var bm: BoxMesh = ghost.mesh
	bm.size = Vector3(size.x * GridBoard.CELL, 0.004, size.y * GridBoard.CELL)
	ghost.visible = true
	if spot != null:
		ghost.position = grid.cell_centre(spot, size) + Vector3(0, 0.003, 0)
		ghost_mat.albedo_color = Color(0.2, 0.9, 0.3, 0.55)
	else:
		ghost.position = grid.cell_centre(want, size) + Vector3(0, 0.003, 0)
		ghost_mat.albedo_color = Color(0.95, 0.2, 0.2, 0.55)


func end_hold(hand_id: String, target_world: Vector3) -> String:
	## Returns "placed", "returned" (blocked, snapped back) or "cancelled" (dragged off the island).
	if not held.has(hand_id):
		return "none"
	var id: int = held[hand_id]
	held.erase(hand_id)
	ghost.visible = false
	var it: Dictionary = items[id]
	var node: Node3D = it["node"]
	var size: Vector2i = it["size"]
	var local := board.to_local(target_world)
	var result := "returned"
	var dest: Vector2i = it["cell"]
	if not grid.is_off_board(local):
		var want := grid.local_to_cell(local, size)
		var spot: Variant = grid.nearest_valid(want, size, id)
		if spot != null:
			dest = spot
			result = "placed"
	else:
		result = "cancelled"
	it["cell"] = dest
	grid.place(id, dest, size)
	node.position = grid.cell_centre(dest, size)
	return result
