class_name FlowerField
extends Node3D
## Tiny meadow flowers and clover in the lush grass (M2, Siddharth 2026-10-27: "yes" to flowers and clover, from the
## Clash-style reference). Two MultiMeshes drawn with flower.gdshader: flowers (stem, star-shaped head, centre) in
## clusters, and clover pads (three round leaves) in the open rings round props, beside paths and scattered in the
## meadow. Cosmetic only. Colours are palette hexes: wall_cream, flower_pink, flower_yellow, roof_orange, leaf_light,
## leaf_green. They sway with the grass, bend away from pushers and hide under towers like the grass does.

const SHADER := preload("res://shaders/flower.gdshader")
const PETALS := [["F4E4B8", 3], ["EE8FA8", 3], ["F6D65C", 3], ["E09B4E", 1]]  # wall_cream, flower_pink, flower_yellow, roof_orange (weights)
const CENTRE_YELLOW := "F6D65C"  # flower_yellow
const CENTRE_ORANGE := "E09B4E"  # roof_orange (the centre of a yellow flower)
const CLOVER := ["8DB85A", "5D8548"]  # leaf_light, leaf_green

var _mat: ShaderMaterial
var _flowers: MultiMesh
var _clover: MultiMesh
var _f_xf: Array[Transform3D] = []
var _f_cell: Array[Vector2i] = []
var _c_xf: Array[Transform3D] = []
var _c_cell: Array[Vector2i] = []
var _hidden: Dictionary = {}


static func build(parent: Node3D, nav: NavGrid, tiles: Array[Rect2], props: Array[Vector2], rng_seed: int) -> FlowerField:
	var f := FlowerField.new()
	f.name = "Flowers"
	parent.add_child(f)
	f._make(nav, tiles, props, rng_seed)
	return f


static func _lin(hex: String) -> Color:
	return Color.html(hex).srgb_to_linear()


func _vtx(st: SurfaceTool, p: Vector3, part: float, h: float) -> void:
	st.set_uv(Vector2(part, h))
	st.set_color(Color.WHITE)
	st.add_vertex(p)


func _flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hgt := 0.026
	var lean := Vector3(0.002, 0, 0)
	var top := lean + Vector3(0, hgt, 0)
	_vtx(st, Vector3(-0.0005, 0, 0), 0.0, 0.0)
	_vtx(st, Vector3(0.0005, 0, 0), 0.0, 0.0)
	_vtx(st, top, 0.0, 1.0)
	var tilt := Basis(Vector3.RIGHT, -0.55)  # the head tips towards the viewer a little
	var n := 10
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var r0 := 0.0036 if k % 2 == 0 else 0.0021  # a star: long and short points
		var r1 := 0.0036 if (k + 1) % 2 == 0 else 0.0021
		_vtx(st, top, 1.0, 1.0)
		_vtx(st, top + tilt * Vector3(cos(a0) * r0, 0, sin(a0) * r0), 1.0, 1.0)
		_vtx(st, top + tilt * Vector3(cos(a1) * r1, 0, sin(a1) * r1), 1.0, 1.0)
	var up := tilt * Vector3(0, 0.0004, 0)
	for k in 6:
		var a0 := TAU * k / 6.0
		var a1 := TAU * (k + 1) / 6.0
		_vtx(st, top + up, 2.0, 1.0)
		_vtx(st, top + up + tilt * Vector3(cos(a0) * 0.0013, 0, sin(a0) * 0.0013), 2.0, 1.0)
		_vtx(st, top + up + tilt * Vector3(cos(a1) * 0.0013, 0, sin(a1) * 0.0013), 2.0, 1.0)
	return st.commit()


func _clover_mesh() -> ArrayMesh:
	## Three round leaves (hexagons) lying just above the ground.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for leaf in 3:
		var la := TAU * leaf / 3.0 + 0.4
		var c := Vector3(cos(la) * 0.0034, 0.0007, sin(la) * 0.0034)
		for k in 6:
			var a0 := TAU * k / 6.0
			var a1 := TAU * (k + 1) / 6.0
			_vtx(st, c, 3.0, 0.0)
			_vtx(st, c + Vector3(cos(a0) * 0.0036, 0, sin(a0) * 0.0036), 3.0, 0.0)
			_vtx(st, c + Vector3(cos(a1) * 0.0036, 0, sin(a1) * 0.0036), 3.0, 0.0)
	return st.commit()


func _pick_petal(rng: RandomNumberGenerator) -> String:
	var total := 0
	for p in PETALS:
		total += p[1]
	var r := rng.randi_range(0, total - 1)
	for p in PETALS:
		r -= p[1]
		if r < 0:
			return p[0]
	return PETALS[0][0]


func _make(nav: NavGrid, tiles: Array[Rect2], props: Array[Vector2], rng_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed + 101
	var noise := FastNoiseLite.new()
	noise.seed = rng_seed + 7
	noise.frequency = 0.30
	var n := GameConfig.SIZE
	var half := n / 2.0
	var houses: Array[Rect2] = []
	for h in GameConfig.HOUSE_CELLS:
		houses.append(Rect2(Vector2(h), Vector2(2, 2)))
	var f_pts: Array[Vector2] = []
	var c_pts: Array[Vector2] = []
	var x := 1.4
	while x < n - 1.4:
		var y := 1.4
		while y < n - 1.4:
			var p := Vector2(x, y) + Vector2(rng.randf_range(-0.18, 0.18), rng.randf_range(-0.18, 0.18))
			var ok := true
			for r in houses:
				if r.grow(0.2).has_point(p):
					ok = false
			for t in tiles:
				if t.grow(0.1).has_point(p):
					ok = false
			var near_prop := 9.0
			for q in props:
				near_prop = minf(near_prop, q.distance_to(p))
			if near_prop < 0.4:
				ok = false
			if ok:
				var cluster := noise.get_noise_2d(p.x, p.y) * 0.5 + 0.5
				if cluster > 0.58 and rng.randf() < 0.65:
					f_pts.append(p)
				# clover: round the props, and scattered through the meadow
				var c_chance := 0.35 if near_prop < 1.0 else 0.07
				if rng.randf() < c_chance:
					c_pts.append(p + Vector2(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.1, 0.1)))
			y += 0.4
		x += 0.4
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_flowers = _fill(f_pts, _flower_mesh(), rng, true, half)
	_clover = _fill(c_pts, _clover_mesh(), rng, false, half)


func _fill(pts: Array[Vector2], mesh: ArrayMesh, rng: RandomNumberGenerator, is_flower: bool, half: float) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = pts.size()
	for i in pts.size():
		var p := pts[i]
		var s := rng.randf_range(0.85, 1.3)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)),
				Vector3((p.x - half) * GameConfig.CELL, 0.0, (p.y - half) * GameConfig.CELL))
		var cell := Vector2i(floori(p.x), floori(p.y))
		mm.set_instance_transform(i, xf)
		if is_flower:
			var hex := _pick_petal(rng)
			mm.set_instance_color(i, _lin(hex))
			mm.set_instance_custom_data(i, _lin(CENTRE_ORANGE if hex == "F6D65C" else CENTRE_YELLOW))
			_f_xf.append(xf)
			_f_cell.append(cell)
		else:
			mm.set_instance_color(i, _lin(CLOVER[rng.randi_range(0, 1)]))
			_c_xf.append(xf)
			_c_cell.append(cell)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = _mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.position.y = 0.0006
	add_child(inst)
	return mm


func flower_count() -> int:
	return _f_xf.size()


func clover_count() -> int:
	return _c_xf.size()


func refresh(nav: NavGrid) -> void:
	var now := {}
	for c in nav.kind:
		if nav.kind[c] == "tower":
			now[c] = true
	if now.size() == _hidden.size() and now.keys().all(func(c): return _hidden.has(c)):
		return
	for i in _f_xf.size():
		var c := _f_cell[i]
		if now.has(c) != _hidden.has(c):
			_flowers.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), _f_xf[i].origin) if now.has(c) else _f_xf[i])
	for i in _c_xf.size():
		var c := _c_cell[i]
		if now.has(c) != _hidden.has(c):
			_clover.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), _c_xf[i].origin) if now.has(c) else _c_xf[i])
	_hidden = now


func set_pushers(arr: PackedVector4Array, count: int) -> void:
	_mat.set_shader_parameter("pushers", arr)
	_mat.set_shader_parameter("push_count", count)
