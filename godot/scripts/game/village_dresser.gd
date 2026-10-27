class_name VillageDresser
extends RefCounted
## Makes the village look lived in (M2, Siddharth 2026-10-27). Purely cosmetic and procedural, seeded so a run always
## looks the same:
##   * a round plaza in the open centre, a stone doorstep in front of every door and a path from each doorstep
##     to the plaza (decor only, never an enemy route; paths do NOT block towers, so a tower can stand on the plaza)
##   * 2 to 3 props beside every house (barrels, crates, pots, benches ...) and a few landmarks on the south
##     outskirts (well, market stall, notice board)
## Props DO block tower placement (Siddharth 2026-10-27): each prop cell is marked "decor" in the NavGrid. Enemies
## still walk through, so the nav, the wall-off rule and the waves are untouched. Props never use the centre block
## (the one open tower spot of the ring), the forest edge or a cell on a path.
## Tile conventions (Godot frame, set by make_path.py): straight arms +x/-x, stones run along +x, doorstep door
## side -z. Rotations are found by brute force from the arm sets, not hard-coded.

const WORLD := "res://assets/world/"
const VILLAGE := "res://assets/village/"
const TILE := {
	"plaza": WORLD + "ew_world_path_plaza_v01.glb",
	"doorstep": WORLD + "ew_world_path_doorstep_v01.glb",
	"straight": WORLD + "ew_world_path_straight_v02.glb",
	"stones": WORLD + "ew_world_path_stones_v01.glb",
}
const HOUSE_PROPS := ["barrel_v02", "barrel_stack_v02", "crate_stack_v02", "haystack_v03", "sacks_v02", "clay_pots_v02",
	"pumpkins_v02", "bench_v02", "table_stool_v02", "basket_v02", "bucket_v02"]
const SMALL_PROPS := ["basket_v02", "bucket_v02", "barrel_v02", "clay_pots_v02"]
const LANDMARKS := ["well_v02", "market_stall_v02", "notice_board_v02", "haystack_v03"]
const CENTRE_BLOCK := Rect2i(10, 10, 4, 4)  # cells kept free of props: the open centre that fits one tower
const EPS := 0.00012  # metres: later tiles sit a hair higher so overlapping tiles never z-fight

var _rng := RandomNumberGenerator.new()
var _scenes := {}
var _tiles: Array[Rect2] = []  # footprints of every path tile, in cell coordinates (corner origin)
var _props: Array[Vector2] = []  # where every prop stands, in cell coordinates (the grass clears a ring round each)
var _root: Node3D
var _nav: NavGrid
var _z := 0


static func build(board: Node3D, rng_seed: int) -> Dictionary:
	## Returns {"decor": the cells the props stand on, "tiles": the path tile footprints (cell coordinates)}. The game
	## re-marks the decor cells in every fresh NavGrid (the time loop builds a new one each loop), so they keep
	## blocking towers; the grass keeps off the tiles.
	var d := VillageDresser.new()
	d._rng.seed = rng_seed
	d._nav = NavGrid.new()  # only used to know which cells are house, forest or spawn
	d._root = Node3D.new()
	d._root.name = "Dressing"
	board.add_child(d._root)
	d._paths()
	d._house_props()
	d._landmarks()
	var out: Array[Vector2i] = []
	for c in d._nav.kind:
		if d._nav.kind[c] == "decor":
			out.append(c)
	return {"decor": out, "tiles": d._tiles, "props": d._props}


func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


func _to_local(p: Vector2) -> Vector3:
	## cell coordinates (corner origin, +y south) -> board-local metres
	var half := GameConfig.SIZE / 2.0
	return Vector3((p.x - half) * GameConfig.CELL, 0.0, (p.y - half) * GameConfig.CELL)


func _arms_rotation(native: Array, want: Array) -> float:
	## The yaw (a multiple of 90 degrees) that turns the tile's native arm directions onto the wanted ones.
	for q in 4:
		var th := q * PI / 2.0
		var s := roundi(sin(th))
		var c := roundi(cos(th))
		var ok := true
		var turned: Array[Vector2i] = []
		for a in native:
			var v: Vector2i = a
			turned.append(Vector2i(v.x * c + v.y * s, -v.x * s + v.y * c))
		for w in want:
			if not turned.has(w):
				ok = false
		if ok and turned.size() == want.size():
			return th
	return 0.0


func _tile(kind: String, centre: Vector2, extent: Vector2, native: Array, want: Array, yaw := NAN) -> void:
	var n: Node3D = _scene(TILE[kind]).instantiate()
	_root.add_child(n)
	_z += 1
	n.position = _to_local(centre) + Vector3(0, EPS * _z, 0)
	n.rotation.y = yaw if not is_nan(yaw) else _arms_rotation(native, want)
	_tiles.append(Rect2(centre - extent / 2.0, extent))


func _paths() -> void:
	var half := GameConfig.SIZE / 2.0
	var centre := Vector2(half, half)
	_tile("plaza", centre, Vector2(2.1, 2.1), [], [])
	for i in GameConfig.HOUSE_CELLS.size():
		var c: Vector2i = GameConfig.HOUSE_CELLS[i]
		var wall := Vector2(c) + Vector2.ONE  # the house centre
		var d := centre - wall
		# same rule as Game._build_houses: the door faces the centre along the longer axis (a tie goes north/south)
		var f := Vector2i(signi(roundi(d.x)), 0) if absf(d.x) > absf(d.y) else Vector2i(0, signi(roundi(d.y)))
		var ff := Vector2(f)
		var door := wall + ff  # on the wall
		# doorstep: its door side (-z) faces the house
		_tile("doorstep", door + ff * 0.5, Vector2(1.1, 0.9) if f.x == 0 else Vector2(0.9, 1.1), [Vector2i(0, -1)], [Vector2i(-f.x, -f.y)])
		var edge := door + ff  # outer edge of the doorstep
		if f.x == 0:
			# door line points at the plaza: straight tiles until the plaza edge
			var p := edge + ff * 0.5
			while absf(p.y - centre.y) > 1.0:
				_tile("straight", p, Vector2(1.3, 1.0), [Vector2i(1, 0), Vector2i(-1, 0)], [Vector2i(0, 1), Vector2i(0, -1)])
				p += ff
		else:
			# the door line misses the plaza: a short footpath of stepping stones from the doorstep to the plaza edge
			var dir := (centre - edge).normalized()
			var end := centre - dir * 1.0
			var len := edge.distance_to(end)
			var n := maxi(1, roundi(len / 1.0))
			for k in n:
				var at := edge.lerp(end, (k + 0.5) / n)
				_tile("stones", at, Vector2(1.1, 1.1), [], [], atan2(-dir.y, dir.x) + _rng.randf_range(-0.12, 0.12))


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell), Vector2.ONE)


func _usable(cell: Vector2i) -> bool:
	if cell.x < 2 or cell.y < 2 or cell.x > GameConfig.SIZE - 3 or cell.y > GameConfig.SIZE - 3:
		return false
	if CENTRE_BLOCK.has_point(cell) or _nav.kind.has(cell):
		return false
	var r := _cell_rect(cell).grow(-0.12)
	for t in _tiles:
		if t.intersects(r):
			return false
	return true


func _place(name: String, cell: Vector2i, facing: float, scale := 1.0) -> void:
	var n: Node3D = _scene(VILLAGE + "ew_village_%s.glb" % name).instantiate()
	_root.add_child(n)
	var jitter := Vector2(_rng.randf_range(-0.16, 0.16), _rng.randf_range(-0.16, 0.16))
	n.position = _to_local(Vector2(cell) + Vector2(0.5, 0.5) + jitter) + Vector3(0, 0.0015, 0)  # a hair up: above the grass
	_props.append(Vector2(cell) + Vector2(0.5, 0.5) + jitter)
	n.rotation.y = facing + _rng.randf_range(-0.45, 0.45)
	n.scale = Vector3.ONE * scale * _rng.randf_range(0.95, 1.05)
	_nav.kind[cell] = "decor"


func _house_props() -> void:
	for h in GameConfig.HOUSE_CELLS:
		var cells: Array[Vector2i] = []
		for x in range(h.x - 1, h.x + 3):
			for y in range(h.y - 1, h.y + 3):
				var c := Vector2i(x, y)
				if (x == h.x - 1 or x == h.x + 2 or y == h.y - 1 or y == h.y + 2) and _usable(c):
					cells.append(c)
		# seeded shuffle
		for i in range(cells.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var t := cells[i]
			cells[i] = cells[j]
			cells[j] = t
		var wall := Vector2(h) + Vector2.ONE
		var want := _rng.randi_range(2, 3)
		for c in cells.slice(0, want):
			var out := Vector2(c) + Vector2(0.5, 0.5) - wall
			var facing := atan2(out.x, out.y)  # the prop's front looks away from the house
			_place(HOUSE_PROPS[_rng.randi_range(0, HOUSE_PROPS.size() - 1)], c, facing)
			if _rng.randf() < 0.35:  # a small second item in the same cell
				var n: Node3D = _scene(VILLAGE + "ew_village_%s.glb" % SMALL_PROPS[_rng.randi_range(0, SMALL_PROPS.size() - 1)]).instantiate()
				_root.add_child(n)
				var at := Vector2(c) + Vector2(0.5, 0.5) + Vector2(_rng.randf_range(0.18, 0.3), _rng.randf_range(-0.3, 0.3)).rotated(facing)
				n.position = _to_local(at) + Vector3(0, 0.0015, 0)
				_props.append(at)
				n.rotation.y = _rng.randf_range(0.0, TAU)


func _landmarks() -> void:
	## A few bigger props on the south outskirts (facing the player), at least 3 cells apart.
	var placed: Array[Vector2i] = []
	var tries := 0
	var i := 0
	while i < 3 and tries < 200:
		tries += 1
		var c := Vector2i(_rng.randi_range(6, 17), _rng.randi_range(17, 20))
		if not _usable(c):
			continue
		var ok := true
		for p in placed:
			if Vector2(p).distance_to(Vector2(c)) < 3.0:
				ok = false
		if not ok:
			continue
		placed.append(c)
		_place(LANDMARKS[i], c, _rng.randf_range(-0.5, 0.5))  # south edge looks at the player, so face +z
		i += 1
