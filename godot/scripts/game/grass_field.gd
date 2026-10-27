class_name GrassField
extends Node3D
## Wavy grass (M2, Siddharth 2026-10-27): small tufts of blades that sway in the wind and bend away from ground
## enemies, Guards and the hands. One MultiMesh (one draw call, a few thousand triangles). Purely cosmetic: it never
## touches the nav or a gameplay number. Tufts avoid paths, the plaza and houses, thin out round props, near the
## forest edge and in patches, and vanish under a tower while it stands (refresh()).
## Look: leaf_green roots to leaf_light tips from the palette, a few tufts with dry yellow tips.

const SHADER := preload("res://shaders/grass.gdshader")
const SPACING := 0.32  # cells between jittered grid points
const LEAVES := 6
const TRIS_PER_TUFT := LEAVES * 3
const MAX_PUSH := 16

var _mm: MultiMesh
var _mat: ShaderMaterial
var _xf: Array[Transform3D] = []
var _cell: Array[Vector2i] = []
var _hidden: Dictionary = {}  # cells whose tufts are currently scaled to nothing
var _gusts: Array = [null, null, null, null]  # {"start": Vector2, "dir": Vector2, "len": float, "age": float}
const GUST_LIFE_EXTRA := 0.3  # seconds a gust lingers after its pulse reached the target
const GUST_SPEED := 1.4  # m/s, same as the shader


static func build(board: Node3D, nav: NavGrid, tiles: Array[Rect2], props: Array[Vector2], rng_seed: int) -> GrassField:
	## tiles: path tile footprints, props: where village props stand (both in cell coordinates). The grass keeps off
	## the tiles and leaves a clearing round every prop, so the props sit above it and stay readable.
	var g := GrassField.new()
	g.name = "Grass"
	board.add_child(g)
	g._make(nav, tiles, props, rng_seed)
	return g


func _clump_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	## One lush clump (the Clash Royale / Clash of Clans reference, Siddharth 2026-10-20): LEAVES broad leaves fanned
	## round a centre, each a base, a wide middle and a drooping pointed tip (3 triangles). UV.y = 0 at the root,
	## 0.5 mid-leaf, 1 at the tip (the shader colours and sways by it).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in LEAVES:
		var a := TAU * (i + rng.randf_range(-0.2, 0.2)) / LEAVES
		var out := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-sin(a), 0.0, cos(a))
		var r := rng.randf_range(0.0006, 0.0022)
		var hgt := rng.randf_range(0.017, 0.027)
		var wid := rng.randf_range(0.0062, 0.0082)  # broad leaves, not thin blades
		var lean := rng.randf_range(0.007, 0.013)
		var root := out * r
		var mid := root + out * lean * 0.45 + Vector3(0, hgt * 0.62, 0)
		var tip := root + out * lean + Vector3(0, hgt * 0.82, 0)  # drooping tip
		var bl := root - side * wid * 0.32
		var br := root + side * wid * 0.32
		var ml := mid - side * wid * 0.5
		var mr := mid + side * wid * 0.5
		for t in [[bl, 0.0, br, 0.0, ml, 0.5], [br, 0.0, mr, 0.5, ml, 0.5], [ml, 0.5, mr, 0.5, tip, 1.0]]:
			for k in 3:
				st.set_uv(Vector2(0.5, t[k * 2 + 1]))
				st.set_color(Color.WHITE)
				st.add_vertex(t[k * 2])
	return st.commit()


func _make(nav: NavGrid, tiles: Array[Rect2], props: Array[Vector2], rng_seed: int) -> void:
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
			var keep := 0.95 * (0.7 + 0.3 * (noise.get_noise_2d(p.x, p.y) * 0.5 + 0.5) * 1.6)  # lush: almost everywhere
			var edge := minf(minf(p.x, n - p.x), minf(p.y, n - p.y))
			if edge < 2.5:
				keep *= 0.8
			for q in props:  # a clearing round every prop, a thin ring of grass just outside it
				var d := q.distance_to(p)
				if d < 0.5:
					keep = 0.0
				elif d < 0.8:
					keep *= 0.5
			for r in houses:
				if r.grow(0.05).has_point(p):
					keep = 0.0
				elif r.grow(0.7).has_point(p):
					keep *= 0.8  # grass hugs the walls
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
	_mm.mesh = _clump_mesh(rng)
	_mm.instance_count = pts.size()
	for i in pts.size():
		var p: Vector2 = pts[i]
		var s := rng.randf_range(0.8, 1.35)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s))
		var xf := Transform3D(b, Vector3((p.x - half) * GameConfig.CELL, 0.0, (p.y - half) * GameConfig.CELL))
		_xf.append(xf)
		_cell.append(Vector2i(floori(p.x), floori(p.y)))
		_mm.set_instance_transform(i, xf)
		# r = how much of the tip is dry yellow, g = this clump's tone (lighter or darker), so no two clumps match
		var tone := clampf(noise.get_noise_2d(p.x * 2.3 + 40.0, p.y * 2.3) * 0.5 + 0.5 + rng.randf_range(-0.25, 0.25), 0.0, 1.0)
		# b = lighter-patch amount: big soft sunlit patches of lighter grass (Siddharth 2026-10-27, from the reference)
		var patch := smoothstep(0.52, 0.8, noise.get_noise_2d(p.x * 0.55 + 90.0, p.y * 0.55 + 15.0) * 0.5 + 0.5)
		_mm.set_instance_color(i, Color(1.0 if rng.randf() < 0.16 else 0.0, tone, patch))
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
