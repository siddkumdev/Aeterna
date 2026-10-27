class_name GrassField
extends Node3D
## Wavy grass (M2, Siddharth 2026-10-27): small tufts of blades that sway in the wind and bend away from ground
## enemies, Guards and the hands. One MultiMesh (one draw call, a few thousand triangles). Purely cosmetic: it never
## touches the nav or a gameplay number. Tufts avoid paths, the plaza and houses, thin out round props, near the
## forest edge and in patches, and vanish under a tower while it stands (refresh()).
## Look: leaf_green roots to leaf_light tips from the palette, a few tufts with dry yellow tips.

const SHADER := preload("res://shaders/grass.gdshader")
const SPACING := 0.34  # cells between jittered grid points (denser 2026-10-27: "i can barely see it")
const BLADES := 5
const MAX_PUSH := 16

var _mm: MultiMesh
var _mat: ShaderMaterial
var _xf: Array[Transform3D] = []
var _cell: Array[Vector2i] = []
var _hidden: Dictionary = {}  # cells whose tufts are currently scaled to nothing
var _gusts: Array = [null, null, null, null]  # {"start": Vector2, "dir": Vector2, "len": float, "age": float}
const GUST_LIFE_EXTRA := 0.3  # seconds a gust lingers after its pulse reached the target
const GUST_SPEED := 1.4  # m/s, same as the shader


static func build(board: Node3D, nav: NavGrid, tiles: Array[Rect2], rng_seed: int) -> GrassField:
	var g := GrassField.new()
	g.name = "Grass"
	board.add_child(g)
	g._make(nav, tiles, rng_seed)
	return g


func _blade_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	## One tuft: BLADES thin triangles round a centre, leaning outward a little. UV.y = 0 at the root, 1 at the tip.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in BLADES:
		var a := TAU * (i + rng.randf_range(-0.25, 0.25)) / BLADES
		var r := rng.randf_range(0.0008, 0.0030)
		var hgt := rng.randf_range(0.011, 0.019)
		var w := 0.0016
		var root := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var side := Vector3(-sin(a), 0.0, cos(a)) * w
		var lean := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.0015, 0.0045)
		var tip := root + lean + Vector3(0, hgt, 0)
		for v in [[root - side, 0.0], [root + side, 0.0], [tip, 1.0]]:
			st.set_uv(Vector2(0.5, v[1]))
			st.set_color(Color.WHITE)
			st.add_vertex(v[0])
	return st.commit()


func _make(nav: NavGrid, tiles: Array[Rect2], rng_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var noise := FastNoiseLite.new()
	noise.seed = rng_seed
	noise.frequency = 0.11
	var n := GameConfig.SIZE
	var half := n / 2.0
	var houses: Array[Rect2] = []
	for h in GameConfig.HOUSE_CELLS:
		houses.append(Rect2(Vector2(h), Vector2(2, 2)))
	var pts: Array[Vector2] = []
	var x := 1.2
	while x < n - 1.2:
		var y := 1.2
		while y < n - 1.2:
			var p := Vector2(x, y) + Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2))
			var keep := 0.85 * (0.5 + 0.5 * (noise.get_noise_2d(p.x, p.y) * 0.5 + 0.5) * 1.6)
			var edge := minf(minf(p.x, n - p.x), minf(p.y, n - p.y))
			if edge < 3.0:
				keep *= 0.55
			var cell := Vector2i(floori(p.x), floori(p.y))
			if nav.kind.get(cell, "") == "decor":
				keep *= 0.3
			for r in houses:
				if r.grow(0.1).has_point(p):
					keep = 0.0
				elif r.grow(0.9).has_point(p):
					keep *= 0.35
			for t in tiles:
				if t.grow(0.12).has_point(p):
					keep = 0.0
			if rng.randf() < keep:
				pts.append(p)
			y += SPACING
		x += SPACING
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = _blade_mesh(rng)
	_mm.instance_count = pts.size()
	for i in pts.size():
		var p: Vector2 = pts[i]
		var s := rng.randf_range(0.75, 1.3)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s))
		var xf := Transform3D(b, Vector3((p.x - half) * GameConfig.CELL, 0.0, (p.y - half) * GameConfig.CELL))
		_xf.append(xf)
		_cell.append(Vector2i(floori(p.x), floori(p.y)))
		_mm.set_instance_transform(i, xf)
		_mm.set_instance_color(i, Color(1.0 if rng.randf() < 0.18 else 0.0, 0, 0))
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = _mm
	inst.material_override = _mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.position.y = 0.0006  # a hair above the island so the roots never z-fight with the ground
	add_child(inst)


func tuft_count() -> int:
	return _xf.size()


func gust(from_world: Vector3, to_world: Vector3) -> void:
	## A Longbow bolt leaves: a pale-green pulse of wind runs through the grass along its line (the shader draws it).
	var d := Vector2(to_world.x - from_world.x, to_world.z - from_world.z)
	if d.length() < 0.01:
		return
	var slot := 0
	var oldest := -1.0
	for i in 4:  # a free slot, else the oldest gust
		if _gusts[i] == null:
			slot = i
			break
		if _gusts[i]["age"] > oldest:
			oldest = _gusts[i]["age"]
			slot = i
	_gusts[slot] = {"start": Vector2(from_world.x, from_world.z), "dir": d.normalized(), "len": d.length(), "age": 0.0}


func gust_count() -> int:
	return _gusts.filter(func(x): return x != null).size()


func _process(delta: float) -> void:
	if _mat == null:
		return
	var a := PackedVector4Array()
	var s := PackedVector4Array()
	a.resize(4)
	s.resize(4)
	for i in 4:
		var g = _gusts[i]
		if g == null:
			continue
		g["age"] += delta
		if g["age"] > g["len"] / GUST_SPEED + GUST_LIFE_EXTRA:
			_gusts[i] = null
			continue
		a[i] = Vector4(g["start"].x, g["start"].y, g["dir"].x, g["dir"].y)
		s[i] = Vector4(g["age"], g["len"], 1.0, 0.0)
	_mat.set_shader_parameter("gusts", a)
	_mat.set_shader_parameter("gust_state", s)


func refresh(nav: NavGrid) -> void:
	## Hide the tufts under standing towers, show them again once a tower is sold or the loop resets.
	var now := {}
	for c in nav.kind:
		if nav.kind[c] == "tower":
			now[c] = true
	if now.size() == _hidden.size() and now.keys().all(func(c): return _hidden.has(c)):
		return
	for i in _xf.size():
		var c := _cell[i]
		if now.has(c) != _hidden.has(c):
			_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), _xf[i].origin) if now.has(c) else _xf[i])
	_hidden = now


func set_pushers(world_points: Array) -> void:
	## world_points: Vector4(x, y, z, radius) in world metres; the first MAX_PUSH are used.
	var n := mini(world_points.size(), MAX_PUSH)
	var arr := PackedVector4Array()
	arr.resize(MAX_PUSH)
	for i in n:
		arr[i] = world_points[i]
	_mat.set_shader_parameter("pushers", arr)
	_mat.set_shader_parameter("push_count", n)
