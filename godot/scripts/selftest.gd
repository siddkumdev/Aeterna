extends SceneTree
## Headless logic test for the grid and placement rules (no XR needed).
## Run:  Godot_console.exe --headless --path godot -s res://scripts/selftest.gd

const GridBoardScript := preload("res://scripts/grid_board.gd")
const TowerPlacerScript := preload("res://scripts/tower_placer.gd")

var failures := 0


func check(name: String, cond: bool) -> void:
	if cond:
		print("PASS  ", name)
	else:
		print("FAIL  ", name)
		failures += 1


func _initialize() -> void:
	await process_frame  # nodes only report real transforms once the tree is running
	_run()


func _run() -> void:
	var g = GridBoardScript.new()
	var two := Vector2i(2, 2)
	check("in_bounds corner", g.in_bounds(Vector2i(10, 10), two))
	check("out_of_bounds", not g.in_bounds(Vector2i(11, 10), two))
	check("centre cell of board", g.local_to_cell(Vector3.ZERO, two) == Vector2i(5, 5))
	check("clamped to board", g.local_to_cell(Vector3(5, 0, 5), two) == Vector2i(10, 10))
	g.place(1, Vector2i(5, 5), two)
	check("occupied blocks", not g.can_place(Vector2i(6, 6), two))
	check("overlap by own id allowed", g.can_place(Vector2i(6, 6), two, 1))
	check("adjacent is free", g.can_place(Vector2i(7, 5), two))
	var near = g.nearest_valid(Vector2i(5, 5), two)
	check("nearest_valid avoids the blocker", near != null and g.can_place(near, two))
	check("off_board detected", g.is_off_board(Vector3(0.6, 0, 0)))
	check("edge not off_board", not g.is_off_board(Vector3(0.32, 0, 0)))
	g.remove(1)
	check("remove frees cells", g.can_place(Vector2i(5, 5), two))

	# placer with a real node tree
	var board := Node3D.new()
	root.add_child(board)
	var p: TowerPlacer = TowerPlacerScript.new()
	root.add_child(p)
	p.setup(board)
	var a := p.add_item(Node3D.new(), Vector2i(2, 5), two, 0.2)
	var b := p.add_item(Node3D.new(), Vector2i(6, 5), two, 0.2)
	check("items registered", p.items.size() == 2)

	var above := p.item_aabb(a).get_center() + Vector3(0, 0.5, 0)
	check("ray picks item from above", p.pick_by_ray(above, Vector3.DOWN) == a)
	check("ray misses empty cell", p.pick_by_ray(Vector3(0, 0.5, -0.2), Vector3.DOWN) == -1)
	check("point pick on item", p.pick_by_point(p.item_aabb(b).get_center()) == b)

	check("begin_hold", p.begin_hold("r", a))
	check("cannot double-grab same item", not p.begin_hold("l", a))
	check("one item per hand", not p.begin_hold("r", b))
	# drop on a free spot
	var free_target := board.to_global(p.grid.cell_centre(Vector2i(0, 0), two))
	p.update_hold("r", free_target)
	check("ghost visible when valid", p.ghost.visible)
	check("placed on free cell", p.end_hold("r", free_target) == "placed" and p.items[a]["cell"] == Vector2i(0, 0))
	# drop on top of the other item: displaced to the nearest free spot, never overlapping
	p.begin_hold("r", a)
	var onto_b := board.to_global(p.grid.cell_centre(Vector2i(6, 5), two))
	var res: String = p.end_hold("r", onto_b)
	check("overlap drop is placed elsewhere, not on top", res == "placed" and p.items[a]["cell"] != Vector2i(6, 5))
	var ca: Vector2i = p.items[a]["cell"]
	var cb: Vector2i = p.items[b]["cell"]
	var overlap := absi(ca.x - cb.x) < 2 and absi(ca.y - cb.y) < 2
	check("no overlap after drop", not overlap)
	# drag off the island cancels back to the original cell
	var before: Vector2i = p.items[a]["cell"]
	p.begin_hold("r", a)
	var away := board.to_global(Vector3(2.0, 0, 0))
	check("cancelled when dragged off island", p.end_hold("r", away) == "cancelled" and p.items[a]["cell"] == before)
	check("end_hold with nothing held", p.end_hold("r", Vector3.ZERO) == "none")

	print("")
	print("RESULT: ", "ALL PASSED" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures > 0 else 0)
