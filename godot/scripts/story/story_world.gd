class_name StoryWorld
extends Node3D
## The opening's world (the user, 2026-11-14: "as realistic as you can get it... cover the player's 360 view", the
## player stands INSIDE it at human scale). Everything is built here from code: no outside art, no textures, only
## procedural shaders in res://shaders/story/. Local space: you stand at the origin facing -Z; the village is ahead
## (VILLAGE), the Dark Wood rings the island and is closest behind you (+Z), where Skotos rises; the island ends in
## a cliff at ~110 m with a sea of cloud below. The director (OpeningStage) drives moods and the actors.

const VILLAGE := Vector3(0, 0, -28)
const SKOTOS_AT := Vector3(5, 0, 44)
const FIRE_AT := Vector3(3.2, 0, -25.0)
const EDGE := 110.0
const SKY := preload("res://shaders/story/story_sky.gdshader")
const GROUND := preload("res://shaders/story/story_ground.gdshader")
const GRASS := preload("res://shaders/story/story_grass.gdshader")
const SURFACE := preload("res://shaders/story/story_surface.gdshader")
const FLAME := preload("res://shaders/story/story_flame.gdshader")
const SMOKE := preload("res://shaders/story/story_smoke.gdshader")
const VEIL := preload("res://shaders/story/story_veil.gdshader")
const GLASS := preload("res://shaders/story/story_glass.gdshader")

## Material kinds of story_surface.gdshader
enum K { PLASTER, STONE, WOOD, THATCH, CLOTH, SKIN, HAIR, BRASS, NEEDLES, LEAVES, EMBER, WINDOW, ROCK, IRON }

## Each mood is a full lighting state; set_mood() blends to it. light = [elevation, azimuth] in degrees (azimuth 0 =
## ahead, -Z, toward the village; 180 = behind you, over the Dark Wood).
const MOODS := {
	"predawn": {"light": [8.0, -35.0], "sun": [3.0, -35.0], "sun_col": Color(1.0, 0.55, 0.32), "energy": 0.35, "zenith": Color(0.06, 0.07, 0.16),
		"horizon": Color(0.55, 0.32, 0.3), "cloud_lit": Color(0.9, 0.55, 0.45), "cloud_shade": Color(0.17, 0.15, 0.22), "cover": 0.4, "stars": 0.5,
		"moon": 0.0, "curse": 0.0, "burn": 0.0, "fog": Color(0.32, 0.25, 0.3), "fog_d": 0.012, "amb": 0.35, "exposure": 1.0},
	"dawn": {"light": [9.0, -35.0], "sun": [5.0, -35.0], "sun_col": Color(1.0, 0.66, 0.38), "energy": 1.5, "zenith": Color(0.2, 0.3, 0.55),
		"horizon": Color(1.0, 0.7, 0.45), "cloud_lit": Color(1.0, 0.78, 0.6), "cloud_shade": Color(0.42, 0.36, 0.45), "cover": 0.42, "stars": 0.0,
		"moon": 0.0, "curse": 0.0, "burn": 0.0, "fog": Color(0.85, 0.66, 0.5), "fog_d": 0.009, "amb": 0.7, "exposure": 1.0},
	"morning": {"light": [24.0, -25.0], "sun": [24.0, -25.0], "sun_col": Color(1.0, 0.9, 0.76), "energy": 1.55, "zenith": Color(0.2, 0.4, 0.78),
		"horizon": Color(0.8, 0.84, 0.88), "cloud_lit": Color(1.0, 0.97, 0.93), "cloud_shade": Color(0.55, 0.57, 0.64), "cover": 0.38, "stars": 0.0,
		"moon": 0.0, "curse": 0.0, "burn": 0.0, "fog": Color(0.75, 0.8, 0.85), "fog_d": 0.006, "amb": 0.85, "exposure": 1.0},
	"dusk": {"light": [6.0, 160.0], "sun": [2.0, 160.0], "sun_col": Color(1.0, 0.42, 0.2), "energy": 1.1, "zenith": Color(0.1, 0.1, 0.24),
		"horizon": Color(0.95, 0.42, 0.24), "cloud_lit": Color(1.0, 0.5, 0.32), "cloud_shade": Color(0.25, 0.17, 0.27), "cover": 0.55, "stars": 0.15,
		"moon": 0.0, "curse": 0.15, "burn": 0.0, "fog": Color(0.45, 0.25, 0.25), "fog_d": 0.011, "amb": 0.45, "exposure": 1.0},
	"curse": {"light": [38.0, 140.0], "sun": [-20.0, 160.0], "sun_col": Color(0.62, 0.55, 0.78), "energy": 0.35, "zenith": Color(0.03, 0.02, 0.06),
		"horizon": Color(0.16, 0.07, 0.18), "cloud_lit": Color(0.35, 0.22, 0.42), "cloud_shade": Color(0.05, 0.03, 0.07), "cover": 0.6, "stars": 0.7,
		"moon": 1.0, "curse": 1.0, "burn": 0.0, "fog": Color(0.1, 0.05, 0.12), "fog_d": 0.014, "amb": 0.25, "exposure": 1.1},
	"fall": {"light": [30.0, 120.0], "sun": [-20.0, 160.0], "sun_col": Color(0.6, 0.45, 0.6), "energy": 0.25, "zenith": Color(0.04, 0.01, 0.03),
		"horizon": Color(0.4, 0.09, 0.05), "cloud_lit": Color(0.6, 0.2, 0.1), "cloud_shade": Color(0.06, 0.02, 0.03), "cover": 0.7, "stars": 0.2,
		"moon": 0.4, "curse": 0.5, "burn": 1.0, "fog": Color(0.22, 0.06, 0.04), "fog_d": 0.016, "amb": 0.22, "exposure": 1.1},
	"still": {"light": [14.0, -35.0], "sun": [3.0, -35.0], "sun_col": Color(1.0, 0.8, 0.5), "energy": 0.6, "zenith": Color(0.08, 0.06, 0.1),
		"horizon": Color(0.35, 0.25, 0.2), "cloud_lit": Color(0.6, 0.5, 0.4), "cloud_shade": Color(0.1, 0.08, 0.1), "cover": 0.5, "stars": 0.6,
		"moon": 0.0, "curse": 0.0, "burn": 0.0, "fog": Color(0.2, 0.15, 0.12), "fog_d": 0.01, "amb": 0.3, "exposure": 1.0},
}
const MOOD_KEYS_COL := ["sun_col", "zenith", "horizon", "cloud_lit", "cloud_shade", "fog"]
const MOOD_KEYS_F := ["energy", "cover", "stars", "moon", "curse", "burn", "fog_d", "amb", "exposure"]

var env: Environment
var sky_mat: ShaderMaterial
var surf: ShaderMaterial
var ground_mat: ShaderMaterial
var grass_mat: ShaderMaterial
var veil_mat: ShaderMaterial
var skotos_mat: ShaderMaterial
var beast_mat: ShaderMaterial
var glass_mat: ShaderMaterial
var sun: DirectionalLight3D
var fire_light: OmniLight3D
var burn_lights: Array[OmniLight3D] = []
var veil: MeshInstance3D
var skotos: Node3D
var skotos_eyes: OmniLight3D
var hourglass: Node3D
var sand_top: Node3D
var sand_bottom: Node3D
var houses: Array = []  # [{at, door, chimney}]
var people: Array[StoryPerson] = []
var beasts: Array = []  # [{node, legs, from, to}]
var fires: Array[GPUParticles3D] = []  # roof fires, off until the fall
var smoke_cols: Array[GPUParticles3D] = []
var chimneys: Array[GPUParticles3D] = []
var camp: Array[GPUParticles3D] = []
var motes: GPUParticles3D
var shards: GPUParticles3D
var unshards: GPUParticles3D
var skotos_fx: Array[GPUParticles3D] = []
var clock := 0.0
var clock_rate := 1.0
var wind := 1.0
var scorch := 0.0

var _mood := {}
var _mood_from := {}
var _mood_to := {}
var _mood_t := 1.0
var _mood_len := 1.0
var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _arrays := {}
var _fx_mats: Array[ShaderMaterial] = []


# ------------------------------------------------------------------ the land
static func height(x: float, z: float) -> float:
	## The ground's height at (x, z): flat where you stand and in the village, rolling hills around, then the cliff.
	var r := Vector2(x, z).length()
	var b := 0.9 * sin(x * 0.045 + 1.3) * cos(z * 0.05 - 0.4) + 0.45 * sin(x * 0.11 - z * 0.09 + 2.0) + 0.18 * sin(x * 0.27 + z * 0.23 + 0.7)
	b += 1.6 * sin(x * 0.021 - 0.8) * sin(z * 0.017 + 0.3)
	var flat := smoothstep(4.0, 16.0, r) * smoothstep(12.0, 24.0, Vector2(x - VILLAGE.x, z - VILLAGE.z).length())
	var h := (b + 0.8) * flat * (1.0 + r * 0.025)
	if r > 96.0:
		h -= pow((r - 96.0) / 14.0, 2.0) * 9.0  # the edge of the island bends down into the cliff
	return h


func ground_at(x: float, z: float) -> Vector3:
	return Vector3(x, height(x, z), z)


func _ready() -> void:
	_rng.seed = 1611
	_noise.seed = 77
	_noise.frequency = 1.0
	_build_env()
	_build_ground()
	_build_village()
	_build_grass()
	_build_wood()
	_build_ruin()
	_build_people()
	_build_fx()
	_build_veil()
	_build_skotos()
	_build_beasts()
	_build_hourglass()
	_mood = MOODS["predawn"].duplicate()
	_apply_mood()


func _process(delta: float) -> void:
	clock += delta * clock_rate
	if _mood_t < 1.0:
		_mood_t = minf(1.0, _mood_t + delta / _mood_len)
		var k := smoothstep(0.0, 1.0, _mood_t)
		for key in MOOD_KEYS_COL:
			_mood[key] = (_mood_from[key] as Color).lerp(_mood_to[key], k)
		for key in MOOD_KEYS_F:
			_mood[key] = lerpf(_mood_from[key], _mood_to[key], k)
		for key in ["light", "sun"]:
			var a: Array = _mood_from[key]
			var b: Array = _mood_to[key]
			_mood[key] = [lerpf(a[0], b[0], k), rad_to_deg(lerp_angle(deg_to_rad(a[1]), deg_to_rad(b[1]), k))]
		_apply_mood()
	for m in [sky_mat, surf, grass_mat, veil_mat, skotos_mat, beast_mat, ground_mat]:
		m.set_shader_parameter("clock", clock)
	for m in [grass_mat, surf]:
		m.set_shader_parameter("wind", wind)
	for m in [ground_mat, grass_mat, surf]:
		m.set_shader_parameter("scorch", scorch)
	for m in _fx_mats:
		m.set_shader_parameter("clock", clock)
	_flicker()
	for p in people:
		p.tick(delta)
	_tick_beasts(delta)


func set_mood(name: String, seconds := 4.0) -> void:
	_mood_from = _mood.duplicate()
	_mood_to = MOODS[name]
	_mood_len = maxf(seconds, 0.01)
	_mood_t = 0.0 if seconds > 0.0 else 1.0
	if seconds <= 0.0:
		_mood = MOODS[name].duplicate()
		_apply_mood()


static func dir_of(elev_az: Array) -> Vector3:
	## A unit direction from [elevation, azimuth] in degrees (azimuth 0 = -Z, 90 = +X).
	var e := deg_to_rad(float(elev_az[0]))
	var a := deg_to_rad(float(elev_az[1]))
	return Vector3(sin(a) * cos(e), sin(e), -cos(a) * cos(e))


func _apply_mood() -> void:
	var m := _mood
	var sd := global_transform.basis * dir_of(m["sun"])
	sky_mat.set_shader_parameter("sun_dir", sd)
	sky_mat.set_shader_parameter("moon_dir", global_transform.basis * dir_of([38.0, 140.0]))
	for key in ["zenith", "horizon", "cloud_lit", "cloud_shade"]:
		sky_mat.set_shader_parameter(key, m[key])
	sky_mat.set_shader_parameter("sun_color", m["sun_col"])
	for key in ["cover", "stars", "moon", "curse", "burn", "exposure"]:
		sky_mat.set_shader_parameter(key, m[key])
	var ld := dir_of(m["light"])
	sun.look_at_from_position(Vector3.ZERO, -ld, Vector3.UP if absf(ld.y) < 0.99 else Vector3.FORWARD)
	sun.light_color = m["sun_col"]
	sun.light_energy = m["energy"]
	env.fog_light_color = m["fog"]
	env.fog_density = m["fog_d"]
	env.ambient_light_energy = m["amb"]


# ------------------------------------------------------------------ mesh baking (one draw per material for the static world)
func _prim(key: String, mesh: PrimitiveMesh) -> Array:
	if not _arrays.has(key):
		_arrays[key] = mesh.get_mesh_arrays()
	return _arrays[key]


static func _put(st: SurfaceTool, arrays: Array, xf: Transform3D, kind: int, col: Color) -> void:
	## Appends a primitive mesh to `st`, moved by xf, with a material kind (UV2.x) and a tint (COLOR).
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv = arrays[Mesh.ARRAY_TEX_UV]
	var idx = arrays[Mesh.ARRAY_INDEX]
	var nb := xf.basis.inverse().transposed()
	var k2 := Vector2(kind, 0)
	var order: PackedInt32Array = idx if idx != null and idx.size() > 0 else PackedInt32Array(range(v.size()))
	for i in order:
		st.set_color(col)
		st.set_uv(uv[i] if uv != null and uv.size() > i else Vector2.ZERO)
		st.set_uv2(k2)
		st.set_normal((nb * n[i]).normalized())
		st.add_vertex(xf * v[i])


func box(st: SurfaceTool, size: Vector3, xf: Transform3D, kind: int, col: Color) -> void:
	_put(st, _prim("box", BoxMesh.new()), xf * Transform3D(Basis.from_scale(size), Vector3.ZERO), kind, col)


func cyl(st: SurfaceTool, r_top: float, r_bot: float, h: float, xf: Transform3D, kind: int, col: Color, sides := 10) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	_put(st, _prim("cyl%.3f_%.3f_%.3f_%d" % [r_top, r_bot, h, sides], c), xf, kind, col)


func ball(st: SurfaceTool, r: float, xf: Transform3D, kind: int, col: Color, seg := 12) -> void:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = seg
	s.rings = maxi(4, seg / 2)
	_put(st, _prim("ball%d" % seg, s), xf * Transform3D(Basis.from_scale(Vector3.ONE * r), Vector3.ZERO), kind, col)


func quad(st: SurfaceTool, size: Vector2, xf: Transform3D, kind: int, col: Color) -> void:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	_put(st, _prim("quad", q), xf * Transform3D(Basis.from_scale(Vector3(size.x, size.y, 1.0)), Vector3.ZERO), kind, col)


func prism(st: SurfaceTool, size: Vector3, xf: Transform3D, kind: int, col: Color) -> void:
	var p := PrismMesh.new()
	p.size = Vector3.ONE
	_put(st, _prim("prism", p), xf * Transform3D(Basis.from_scale(size), Vector3.ZERO), kind, col)


func lathe(st: SurfaceTool, profile: PackedVector2Array, xf: Transform3D, kind: int, col: Color, sides := 14, jitter := 0.0) -> void:
	## A turned shape: profile = (radius, height) from bottom to top.
	var rings: Array = []
	for j in profile.size():
		var ring: Array = []
		for i in sides + 1:
			var a := TAU * float(i % sides) / sides
			var r := profile[j].x * (1.0 + jitter * (_noise.get_noise_3d(cos(a) * 2.0, profile[j].y * 0.7, sin(a) * 2.0 + xf.origin.x)))
			ring.append(Vector3(cos(a) * r, profile[j].y, sin(a) * r))
		rings.append(ring)
	var k2 := Vector2(kind, 0)
	var tmp := SurfaceTool.new()
	tmp.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in profile.size() - 1:
		for i in sides:
			var a: Vector3 = rings[j][i]
			var b: Vector3 = rings[j][i + 1]
			var c: Vector3 = rings[j + 1][i + 1]
			var d: Vector3 = rings[j + 1][i]
			for p in [a, c, b, a, d, c]:
				tmp.set_uv(Vector2(float(i) / sides, float(j) / profile.size()))
				tmp.add_vertex(p)
	tmp.generate_normals()
	var arr := tmp.commit_to_arrays()
	_put(st, arr, xf, kind, col)


func bake(st: SurfaceTool, mat: Material, name_: String, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


static func new_st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func at(p: Vector3, yaw := 0.0, tilt := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(tilt.x, yaw, tilt.z)), p)


# ------------------------------------------------------------------ the sky, light and air
func _build_env() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.0
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_sun_scatter = 0.35
	env.fog_aerial_perspective = 0.5
	env.fog_sky_affect = 0.0
	env.fog_height = 1.5
	env.fog_height_density = 0.04
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.04
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_blur = 1.5
	add_child(sun)


func _build_ground() -> void:
	## A polar grid, dense under your feet and coarse at the horizon, heights from height().
	var st := new_st()
	var rings := 72
	var seg := 112
	var pts: Array = []
	for j in rings + 1:
		var r := 125.0 * pow(float(j) / rings, 1.75)
		var ring: Array = []
		for i in seg:
			var a := TAU * i / seg
			var x := cos(a) * r
			var z := sin(a) * r
			ring.append(Vector3(x, height(x, z) if r < 124.0 else -40.0, z))
		pts.append(ring)
	for j in rings:
		for i in seg:
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j][(i + 1) % seg]
			var c: Vector3 = pts[j + 1][(i + 1) % seg]
			var d: Vector3 = pts[j + 1][i]
			for p in [a, c, b, a, d, c]:
				st.set_uv(Vector2(p.x, p.z) * 0.25)
				st.add_vertex(p)
	st.generate_normals()
	st.generate_tangents()
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = GROUND
	ground_mat.set_shader_parameter("village", Vector2(VILLAGE.x, VILLAGE.z))
	var mi := bake(st, ground_mat, "Ground")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _path_dist(p: Vector2) -> float:
	var a := Vector2(0, 1.5)
	var b := Vector2(VILLAGE.x, VILLAGE.z + 5.0)
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
	return (p - (a + ab * t) - Vector2(sin(p.y * 0.35) * 0.8, 0)).length()


# ------------------------------------------------------------------ the village
func _build_village() -> void:
	surf = ShaderMaterial.new()
	surf.shader = SURFACE
	var st := new_st()
	var plaster := [Color(0.74, 0.68, 0.57), Color(0.68, 0.62, 0.51), Color(0.76, 0.71, 0.61), Color(0.66, 0.57, 0.45)]
	var n := 8
	for i in n:
		var ang := -PI * 0.92 + TAU * (i + 0.5) / n + _rng.randf_range(-0.12, 0.12)
		var off := wrapf(ang - PI / 2.0, -PI, PI)
		if absf(off) < 0.8:
			ang = PI / 2.0 + signf(off if off != 0.0 else 1.0) * 0.8  # keep the gap on the side the path comes in (toward you)
		var r := _rng.randf_range(9.5, 12.5)
		var c := VILLAGE + Vector3(cos(ang) * r, 0, sin(ang) * r)
		c.y = height(c.x, c.z)
		var yaw := atan2(VILLAGE.x - c.x, VILLAGE.z - c.z)  # the door faces the square
		_house(st, c, yaw, Vector3(_rng.randf_range(4.2, 6.0), _rng.randf_range(2.5, 3.1), _rng.randf_range(3.6, 4.6)), plaster[i % 4])
	_well(st, VILLAGE + Vector3(-2.5, 0, 1.5))
	_statue(st, VILLAGE + Vector3(0, 0, -1.5))
	_campfire(st, FIRE_AT)
	for k in 6:  # lantern posts round the square
		var a := TAU * k / 6.0 + 0.3
		var p := VILLAGE + Vector3(cos(a) * 6.8, 0, sin(a) * 6.8)
		p.y = height(p.x, p.z)
		cyl(st, 0.05, 0.07, 2.4, at(p + Vector3(0, 1.2, 0)), K.WOOD, Color(0.33, 0.22, 0.14), 6)
		box(st, Vector3(0.5, 0.06, 0.06), at(p + Vector3(0.2, 2.35, 0)), K.WOOD, Color(0.33, 0.22, 0.14))
		box(st, Vector3(0.2, 0.26, 0.2), at(p + Vector3(0.42, 2.12, 0)), K.IRON, Color(0.15, 0.14, 0.13))
		ball(st, 0.07, at(p + Vector3(0.42, 2.1, 0)), K.EMBER, Color(1.0, 0.62, 0.25), 8)
	for k in 5:  # fences along the meadow
		var a := -1.2 + k * 0.55
		var p0 := VILLAGE + Vector3(cos(a) * 15.0, 0, sin(a) * 15.0 + 2.0)
		for f in 7:
			var p := p0 + Vector3(-sin(a), 0, cos(a)) * (f * 1.4)
			p.y = height(p.x, p.z)
			cyl(st, 0.05, 0.06, 1.1, at(p + Vector3(0, 0.5, 0), 0, Vector3(_rng.randf_range(-0.06, 0.06), 0, _rng.randf_range(-0.06, 0.06))), K.WOOD, Color(0.4, 0.33, 0.26), 6)
		var mid := p0 + Vector3(-sin(a), 0, cos(a)) * 4.2
		mid.y = height(mid.x, mid.z)
		for y in [0.45, 0.85]:
			box(st, Vector3(0.06, 0.07, 8.6), at(mid + Vector3(0, y, 0), atan2(-sin(a), cos(a)) - PI / 2.0 + PI / 2.0), K.WOOD, Color(0.42, 0.35, 0.27))
	for k in 34:  # boulders strewn about the meadow
		var a := _rng.randf_range(0, TAU)
		var r := _rng.randf_range(7.0, 60.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if Vector2(p.x - VILLAGE.x, p.z - VILLAGE.z).length() < 14.0 or _path_dist(Vector2(p.x, p.z)) < 2.5:
			continue
		p.y = height(p.x, p.z) - 0.15
		var s := _rng.randf_range(0.3, 1.4)
		_rock(st, p, s)
	bake(st, surf, "Village")


func _rock(st: SurfaceTool, p: Vector3, s: float) -> void:
	var sph := SphereMesh.new()
	sph.radial_segments = 10
	sph.rings = 6
	var arr := sph.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var o := Vector3(_rng.randf() * 50, _rng.randf() * 50, 0)
	for i in v.size():
		var q := v[i]
		v[i] = q * Vector3(1.3, 0.75, 1.0) * (1.0 + 0.45 * _noise.get_noise_3dv(q * 1.6 + o))
	arr[Mesh.ARRAY_VERTEX] = v
	var t := SurfaceTool.new()
	t.create_from_arrays(arr)
	t.generate_normals()
	_put(st, t.commit_to_arrays(), at(p, _rng.randf_range(0, TAU)) * Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3.ZERO), K.ROCK, Color(0.5, 0.47, 0.42))


func _house(st: SurfaceTool, c: Vector3, yaw: float, size: Vector3, wall_col: Color) -> void:
	## A timber-framed cottage: stone plinth, limewashed walls, oak frame, a deep thatch, a stone chimney, lit windows.
	## Local +Z is the front (the door).
	var w := size.x
	var hgt := size.y
	var d := size.z
	var base := at(c, yaw)
	var oak := Color(0.26, 0.17, 0.11)
	box(st, Vector3(w + 0.2, 0.6, d + 0.2), base * at(Vector3(0, 0.0, 0)), K.STONE, Color(0.55, 0.52, 0.47))
	box(st, Vector3(w, hgt, d), base * at(Vector3(0, 0.3 + hgt / 2.0, 0)), K.PLASTER, wall_col)
	var top := 0.3 + hgt
	for sx in [-1, 1]:  # corner posts and the wall plates
		for sz in [-1, 1]:
			box(st, Vector3(0.2, hgt, 0.2), base * at(Vector3(sx * w / 2.0, 0.3 + hgt / 2.0, sz * d / 2.0)), K.WOOD, oak)
	for sz in [-1, 1]:
		box(st, Vector3(w + 0.1, 0.18, 0.2), base * at(Vector3(0, top, sz * d / 2.0)), K.WOOD, oak)
		box(st, Vector3(w + 0.1, 0.14, 0.18), base * at(Vector3(0, 0.3 + hgt * 0.48, sz * (d / 2.0 + 0.01))), K.WOOD, oak)
		for k in [-1, 1]:  # braces and studs on the long walls
			var bx: float = k * w * 0.3
			box(st, Vector3(0.14, hgt * 0.95, 0.16), base * at(Vector3(bx, 0.3 + hgt / 2.0, sz * (d / 2.0 + 0.01)), 0, Vector3(0, 0, k * 0.5)), K.WOOD, oak)
	for sx in [-1, 1]:
		box(st, Vector3(0.2, 0.18, d + 0.1), base * at(Vector3(sx * w / 2.0, top, 0)), K.WOOD, oak)
	# the thatch: a deep, overhanging roof, ridge along the length
	var rh := d * 0.62
	prism(st, Vector3(d + 1.1, rh, w + 0.9), base * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(0, top + rh / 2.0 - 0.05, 0)), K.THATCH, Color(0.62, 0.5, 0.32))
	box(st, Vector3(w + 0.95, 0.22, 0.3), base * at(Vector3(0, top + rh - 0.04, 0)), K.THATCH, Color(0.5, 0.42, 0.28))
	# gable ends: plaster triangles under the thatch
	for sx in [-1, 1]:
		prism(st, Vector3(d, rh * 0.95, 0.1), base * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(sx * (w / 2.0 - 0.02), top + rh * 0.47, 0)), K.PLASTER, wall_col * 0.95)
	# the chimney, at one gable
	var ch := Vector3(-w / 2.0 + 0.5, 0, -d * 0.15)
	box(st, Vector3(0.7, top + rh + 0.9, 0.7), base * at(ch + Vector3(0, (top + rh + 0.9) / 2.0, 0)), K.STONE, Color(0.5, 0.47, 0.43))
	box(st, Vector3(0.82, 0.12, 0.82), base * at(ch + Vector3(0, top + rh + 0.9, 0)), K.STONE, Color(0.45, 0.42, 0.38))
	# the door and its frame
	box(st, Vector3(1.0, 1.95, 0.08), base * at(Vector3(w * 0.12, 0.3 + 0.98, d / 2.0 + 0.04)), K.WOOD, Color(0.36, 0.24, 0.15))
	box(st, Vector3(1.22, 0.16, 0.16), base * at(Vector3(w * 0.12, 0.3 + 2.0, d / 2.0 + 0.05)), K.WOOD, oak)
	ball(st, 0.05, base * at(Vector3(w * 0.12 + 0.35, 1.25, d / 2.0 + 0.1)), K.IRON, Color(0.12, 0.11, 0.1), 6)
	box(st, Vector3(1.2, 0.18, 0.5), base * at(Vector3(w * 0.12, 0.1, d / 2.0 + 0.3)), K.STONE, Color(0.5, 0.48, 0.44))
	# windows front and back, each with a sill and a frame
	for side in [1, -1]:
		for wx in ([-w * 0.28] if side == 1 else [-w * 0.22, w * 0.22]):
			var wz: float = side * (d / 2.0 + 0.03)
			var wy := 0.3 + hgt * 0.58
			quad(st, Vector2(0.75, 0.85), base * at(Vector3(wx, wy, wz), 0.0 if side == 1 else PI), K.WINDOW, Color(1.0, 0.62, 0.28))
			box(st, Vector3(0.95, 0.1, 0.22), base * at(Vector3(wx, wy - 0.48, wz)), K.WOOD, oak)
			box(st, Vector3(0.95, 0.1, 0.12), base * at(Vector3(wx, wy + 0.48, wz)), K.WOOD, oak)
	# a firewood stack against one wall, a barrel at the other
	var pile := Vector3(w / 2.0 + 0.45, 0, 0.4)
	for row in 3:
		for k in 4 - row:
			cyl(st, 0.09, 0.09, 1.0, base * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), pile + Vector3(0, 0.1 + row * 0.17, -0.3 + k * 0.19 + row * 0.09)), K.WOOD, Color(0.45, 0.33, 0.22), 7)
	var barrel := Vector3(-w / 2.0 - 0.45, 0.45, d * 0.3)
	lathe(st, PackedVector2Array([Vector2(0.28, 0), Vector2(0.34, 0.3), Vector2(0.35, 0.45), Vector2(0.34, 0.6), Vector2(0.28, 0.9), Vector2(0.0, 0.9)]), base * at(barrel - Vector3(0, 0.45, 0)), K.WOOD, Color(0.4, 0.28, 0.17), 12)
	var chim_world := base * (ch + Vector3(0, top + rh + 1.0, 0))
	houses.append({"at": c, "yaw": yaw, "door": base * Vector3(w * 0.12, 0, d / 2.0 + 0.8), "chimney": chim_world, "roof": base * Vector3(0, top + rh * 0.5, 0), "size": size})


func _well(st: SurfaceTool, p: Vector3) -> void:
	p.y = height(p.x, p.z)
	lathe(st, PackedVector2Array([Vector2(0.95, 0), Vector2(0.95, 0.8), Vector2(0.75, 0.8), Vector2(0.75, 0.2)]), at(p), K.STONE, Color(0.55, 0.52, 0.48), 16)
	for sx in [-1, 1]:
		box(st, Vector3(0.14, 2.0, 0.14), at(p + Vector3(sx * 0.85, 1.0, 0)), K.WOOD, Color(0.3, 0.2, 0.13))
	box(st, Vector3(1.9, 0.1, 0.1), at(p + Vector3(0, 1.75, 0)), K.WOOD, Color(0.3, 0.2, 0.13))
	prism(st, Vector3(2.2, 0.7, 1.5), Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis(Vector3.UP, PI / 2.0), p + Vector3(0, 2.3, 0)), K.THATCH, Color(0.55, 0.45, 0.3))
	cyl(st, 0.012, 0.012, 1.1, at(p + Vector3(0, 1.2, 0)), K.CLOTH, Color(0.55, 0.48, 0.35), 4)
	lathe(st, PackedVector2Array([Vector2(0.14, 0), Vector2(0.17, 0.25), Vector2(0.0, 0.25)]), at(p + Vector3(0, 0.55, 0)), K.WOOD, Color(0.35, 0.25, 0.16), 8)


func _statue(st: SurfaceTool, p: Vector3) -> void:
	## The hooded little god of the village square, in weathered stone (the game's statue, at life size).
	p.y = height(p.x, p.z)
	box(st, Vector3(1.6, 0.5, 1.6), at(p + Vector3(0, 0.25, 0)), K.STONE, Color(0.52, 0.5, 0.46))
	box(st, Vector3(1.1, 0.5, 1.1), at(p + Vector3(0, 0.7, 0)), K.STONE, Color(0.55, 0.53, 0.49))
	lathe(st, PackedVector2Array([Vector2(0.5, 0), Vector2(0.45, 0.6), Vector2(0.32, 1.2), Vector2(0.28, 1.45), Vector2(0.3, 1.6), Vector2(0.26, 1.85), Vector2(0.12, 2.0), Vector2(0.0, 2.04)]),
		at(p + Vector3(0, 0.95, 0)), K.ROCK, Color(0.62, 0.6, 0.55), 16, 0.06)
	ball(st, 0.12, at(p + Vector3(0, 2.2, 0.22)), K.EMBER, Color(1.0, 0.6, 0.22), 8)  # the small flame it holds


func _campfire(st: SurfaceTool, p: Vector3) -> void:
	p.y = height(p.x, p.z)
	for k in 9:
		var a := TAU * k / 9.0
		_rock(st, p + Vector3(cos(a) * 0.75, -0.05, sin(a) * 0.75), 0.22)
	for k in 5:
		var a := TAU * k / 5.0
		cyl(st, 0.07, 0.08, 0.9, Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 1.15), p + Vector3(cos(a) * 0.18, 0.22, sin(a) * 0.18)), K.WOOD, Color(0.2, 0.13, 0.09), 7)
	ball(st, 0.32, Transform3D(Basis.from_scale(Vector3(1, 0.3, 1)), p + Vector3(0, 0.05, 0)), K.EMBER, Color(1.0, 0.35, 0.1), 10)
	for k in 3:  # log benches round it
		var a := TAU * k / 3.0 + 0.4
		var bp := p + Vector3(cos(a) * 2.0, 0.2, sin(a) * 2.0)
		cyl(st, 0.2, 0.2, 1.8, Transform3D(Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, PI / 2.0), bp), K.WOOD, Color(0.36, 0.26, 0.18), 10)


# ------------------------------------------------------------------ the meadow
func _grass() -> ArrayMesh:
	## One clump: 7 curved, tapering blades. UV.y = height (0 root, 1 tip).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for b in 7:
		var a := r.randf_range(0, TAU)
		var root := Vector3(cos(a), 0, sin(a)) * r.randf_range(0.0, 0.14)
		var face := r.randf_range(0, TAU)
		var side := Vector3(cos(face), 0, sin(face))
		var lean := Vector3(-sin(face), 0, cos(face)) * r.randf_range(0.05, 0.22)
		var h := r.randf_range(0.28, 0.62)
		var w := r.randf_range(0.012, 0.022)
		var prev_l := root - side * w
		var prev_r := root + side * w
		var segs := 3
		for s in range(1, segs + 1):
			var t := float(s) / segs
			var c := root + Vector3(0, h * t, 0) + lean * t * t * h
			var ww := w * (1.0 - t * 0.85)
			var l := c - side * ww
			var rr := c + side * ww
			var nrm := (Vector3.UP * 0.6 + side.cross(Vector3.UP).normalized()).normalized()
			var tv := float(s - 1) / segs
			for q in ([[prev_l, tv], [prev_r, tv], [rr, t], [prev_l, tv], [rr, t], [l, t]] if s < segs else [[prev_l, tv], [prev_r, tv], [c, t]]):
				st.set_normal(nrm)
				st.set_uv(Vector2(0, q[1]))
				st.add_vertex(q[0])
			prev_l = l
			prev_r = rr
	return st.commit()


func _build_grass() -> void:
	grass_mat = ShaderMaterial.new()
	grass_mat.shader = GRASS
	grass_mat.set_shader_parameter("village", Vector2(VILLAGE.x, VILLAGE.z))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _grass()
	var xfs: Array = []
	var tries := 0
	while xfs.size() < 4200 and tries < 20000:
		tries += 1
		var r := 22.0 * pow(_rng.randf(), 0.7) + 0.6
		var a := _rng.randf_range(0, TAU)
		var x := cos(a) * r
		var z := sin(a) * r
		var p2 := Vector2(x, z)
		if _path_dist(p2) < 1.0 or (p2 - Vector2(VILLAGE.x, VILLAGE.z)).length() < 7.0:
			continue
		var near_house := false
		for h in houses:
			if Vector2(x - h["at"].x, z - h["at"].z).length() < 3.6:
				near_house = true
				break
		if near_house:
			continue
		var s := _rng.randf_range(0.8, 1.5) * (1.0 + smoothstep(8.0, 22.0, r) * 0.4)
		xfs.append([Transform3D(Basis(Vector3.UP, _rng.randf_range(0, TAU)).scaled(Vector3.ONE * s), Vector3(x, height(x, z) - 0.02, z)),
			Color(_rng.randf(), _rng.randf() * _rng.randf(), _rng.randf(), 0)])
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i][0])
		mm.set_instance_custom_data(i, xfs[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Grass"
	mmi.multimesh = mm
	mmi.material_override = grass_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	# wild flowers among it
	var st := new_st()
	cyl(st, 0.004, 0.004, 0.35, at(Vector3(0, 0.17, 0)), K.LEAVES, Color(0.25, 0.4, 0.12), 3)
	ball(st, 0.028, Transform3D(Basis.from_scale(Vector3(1, 0.4, 1)), Vector3(0, 0.35, 0)), K.CLOTH, Color(1, 1, 1), 6)
	ball(st, 0.01, at(Vector3(0, 0.36, 0)), K.CLOTH, Color(1.0, 0.75, 0.2), 4)
	var fm := MultiMesh.new()
	fm.transform_format = MultiMesh.TRANSFORM_3D
	fm.mesh = st.commit()
	fm.instance_count = 700
	for i in 700:
		var r := _rng.randf_range(1.5, 20.0)
		var a := _rng.randf_range(0, TAU)
		var x := cos(a) * r
		var z := sin(a) * r
		fm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.7, 1.3)), Vector3(x, height(x, z), z)))
	var fmi := MultiMeshInstance3D.new()
	fmi.name = "Flowers"
	fmi.multimesh = fm
	fmi.material_override = surf
	fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fmi)


# ------------------------------------------------------------------ the Dark Wood
func _pine(seed_: int) -> ArrayMesh:
	## A conifer about 1 unit tall per metre of `scale`: a tapering trunk and drooping, ragged tiers of boughs.
	var st := new_st()
	var r := RandomNumberGenerator.new()
	r.seed = seed_
	var tiers := 7
	lathe(st, PackedVector2Array([Vector2(0.32, 0), Vector2(0.22, 1.5), Vector2(0.14, 8.0), Vector2(0.02, 13.0)]), Transform3D.IDENTITY, K.WOOD, Color(0.3, 0.22, 0.17), 8, 0.1)
	for t in tiers:
		var k := float(t) / tiers
		var y0 := 2.2 + k * 9.0
		var rad := lerpf(3.4, 0.9, k) * r.randf_range(0.85, 1.1)
		var hh := lerpf(3.2, 2.2, k)
		var shade := lerpf(0.55, 1.0, k)
		var prof := PackedVector2Array([Vector2(0.15, y0 + 0.5), Vector2(rad, y0 - 0.25), Vector2(rad * 0.7, y0 + hh * 0.35), Vector2(rad * 0.3, y0 + hh * 0.75), Vector2(0.0, y0 + hh)])
		lathe(st, prof, at(Vector3.ZERO, r.randf_range(0, TAU)), K.NEEDLES, Color(0.13, 0.2, 0.12) * shade, 11, 0.32)
	return st.commit()


func _oak(seed_: int) -> ArrayMesh:
	var st := new_st()
	var r := RandomNumberGenerator.new()
	r.seed = seed_
	lathe(st, PackedVector2Array([Vector2(0.6, 0), Vector2(0.42, 0.8), Vector2(0.36, 3.5), Vector2(0.15, 6.0)]), Transform3D.IDENTITY, K.WOOD, Color(0.33, 0.27, 0.21), 10, 0.15)
	for b in 3:
		var a := TAU * b / 3.0 + 0.4
		cyl(st, 0.08, 0.2, 3.0, Transform3D(Basis(Vector3(cos(a), 0, sin(a)).cross(Vector3.UP).normalized(), 0.8), Vector3(cos(a) * 0.9, 4.2, sin(a) * 0.9)), K.WOOD, Color(0.33, 0.27, 0.21), 7)
	for b in 9:
		var a := r.randf_range(0, TAU)
		var rr := r.randf_range(0.5, 2.6)
		var p := Vector3(cos(a) * rr, r.randf_range(5.0, 8.0), sin(a) * rr)
		ball(st, r.randf_range(1.6, 2.5), Transform3D(Basis.from_scale(Vector3(1.0, 0.8, 1.0)), p), K.LEAVES, Color(0.2, 0.3, 0.1) * r.randf_range(0.8, 1.15), 12)
	return st.commit()


func _bush() -> ArrayMesh:
	var st := new_st()
	for b in 4:
		var a := TAU * b / 4.0
		ball(st, 0.55, Transform3D(Basis.from_scale(Vector3(1, 0.75, 1)), Vector3(cos(a) * 0.4, 0.4, sin(a) * 0.4)), K.LEAVES, Color(0.17, 0.26, 0.09), 9)
	return st.commit()


func _scatter(mesh: Mesh, xfs: Array, name_: String, shadows := true) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name_
	mmi.multimesh = mm
	mmi.material_override = surf
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _build_wood() -> void:
	var sets: Array = [[], [], []]
	for i in 420:
		var a := _rng.randf_range(0, TAU)
		var behind := cos(a - PI / 2.0)  # +1 behind you (+Z)
		var r0 := lerpf(34.0, 22.0, maxf(behind, 0.0))
		var r := _rng.randf_range(r0, 104.0)
		var x := cos(a) * r
		var z := sin(a) * r
		if Vector2(x - VILLAGE.x, z - VILLAGE.z).length() < 24.0 or Vector2(x - SKOTOS_AT.x, z - SKOTOS_AT.z).length() < 9.0:
			continue
		var s := _rng.randf_range(0.8, 1.45)
		sets[i % 3].append(Transform3D(Basis(Vector3.UP, _rng.randf_range(0, TAU)).scaled(Vector3(s, s * _rng.randf_range(0.9, 1.2), s)), Vector3(x, height(x, z) - 0.2, z)))
	for k in 3:
		_scatter(_pine(11 + k * 7), sets[k], "Pines%d" % k, true)
	var oaks: Array = []
	for p in [Vector3(-14, 0, -9), Vector3(13, 0, -27), Vector3(-9, 0, -31), Vector3(16, 0, -6)]:
		oaks.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.9, 1.2)), Vector3(p.x, height(p.x, p.z) - 0.1, p.z)))
	_scatter(_oak(3), oaks, "Oaks")
	var bushes: Array = []
	for i in 110:
		var a := _rng.randf_range(0, TAU)
		var r := _rng.randf_range(16.0, 34.0)
		var x := cos(a) * r
		var z := sin(a) * r
		if _path_dist(Vector2(x, z)) < 2.0 or Vector2(x - VILLAGE.x, z - VILLAGE.z).length() < 13.0:
			continue
		bushes.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.6, 1.5)), Vector3(x, height(x, z) - 0.1, z)))
	_scatter(_bush(), bushes, "Bushes", false)


func _build_ruin() -> void:
	## Skotos's forgotten temple in the Dark Wood behind you: broken columns, a toppled lintel, steps under moss.
	var st := new_st()
	var c := Vector3(3, 0, 40)
	c.y = height(c.x, c.z)
	for k in 3:
		box(st, Vector3(9.0 - k * 1.6, 0.35, 5.0 - k * 1.0), at(c + Vector3(0, 0.17 + k * 0.35, 0)), K.STONE, Color(0.48, 0.47, 0.44))
	var hs := [5.5, 2.4, 4.1, 1.2, 5.8, 3.0]
	for k in 6:
		var x := -3.6 + k * 1.45
		var tilt := Vector3(_rng.randf_range(-0.08, 0.08), 0, _rng.randf_range(-0.08, 0.08))
		cyl(st, 0.36, 0.42, hs[k], at(c + Vector3(x, 1.05 + hs[k] / 2.0, -1.2), 0, tilt), K.STONE, Color(0.55, 0.54, 0.5), 12)
	box(st, Vector3(5.5, 0.8, 1.0), at(c + Vector3(1.0, 0.5, 2.6), 0.4, Vector3(0, 0, 0.12)), K.STONE, Color(0.5, 0.49, 0.45))
	cyl(st, 0.4, 0.4, 3.0, Transform3D(Basis(Vector3.UP, 0.9) * Basis(Vector3.FORWARD, PI / 2.0), c + Vector3(-5, 0.4, 2.0)), K.STONE, Color(0.52, 0.51, 0.47), 12)
	lathe(st, PackedVector2Array([Vector2(0.8, 0), Vector2(0.7, 0.6), Vector2(0.55, 1.6), Vector2(0.62, 2.4), Vector2(0.3, 3.0), Vector2(0.0, 3.1)]), at(c + Vector3(0, 1.05, -2.2)), K.ROCK, Color(0.42, 0.4, 0.42), 14, 0.12)
	bake(st, surf, "Ruin")


# ------------------------------------------------------------------ people
func _build_people() -> void:
	var skin := [Color(0.86, 0.66, 0.53), Color(0.62, 0.44, 0.32), Color(0.9, 0.72, 0.6), Color(0.45, 0.31, 0.22), Color(0.78, 0.58, 0.45)]
	var cloth := [Color(0.42, 0.18, 0.12), Color(0.3, 0.32, 0.22), Color(0.55, 0.45, 0.3), Color(0.25, 0.22, 0.28), Color(0.6, 0.35, 0.18), Color(0.35, 0.28, 0.2)]
	var hair := [Color(0.12, 0.08, 0.05), Color(0.35, 0.22, 0.12), Color(0.55, 0.53, 0.5), Color(0.06, 0.05, 0.05), Color(0.5, 0.32, 0.15)]
	for i in 10:
		var p := StoryPerson.new()
		p.world = self
		p.female = i % 2 == 0
		p.skin = skin[i % skin.size()]
		p.cloth = cloth[i % cloth.size()]
		p.cloth2 = cloth[(i + 3) % cloth.size()]
		p.hair = hair[(i * 3) % hair.size()]
		p.tall = _rng.randf_range(0.93, 1.05) * (0.97 if p.female else 1.02)
		p.hooded = i == 0  # Maren, the old priestess, wears a hood
		if i == 0:
			p.hair = hair[2]
		p.name = "Person%d" % i
		add_child(p)
		people.append(p)
	# where they are at the start: round the fire, at the well, on the path
	var spots := [VILLAGE + Vector3(0, 0, 0.6), FIRE_AT + Vector3(1.6, 0, 1.0), FIRE_AT + Vector3(-1.4, 0, 1.5), VILLAGE + Vector3(-3.6, 0, 2.5),
		VILLAGE + Vector3(4.5, 0, -3.0), VILLAGE + Vector3(-5, 0, -2), FIRE_AT + Vector3(0.6, 0, -1.9), VILLAGE + Vector3(2.0, 0, 4.0),
		VILLAGE + Vector3(-1.5, 0, 5.2), VILLAGE + Vector3(6.0, 0, 1.0)]
	for i in people.size():
		var s: Vector3 = spots[i]
		people[i].place(Vector3(s.x, height(s.x, s.z), s.z), _rng.randf_range(0, TAU))


# ------------------------------------------------------------------ fire, smoke, motes, shards
func _particles(name_: String, amount: int, life: float, mesh_size: float, mat: Material, pm: ParticleProcessMaterial, p: Vector3) -> GPUParticles3D:
	var g := GPUParticles3D.new()
	g.name = name_
	g.amount = amount
	g.lifetime = life
	g.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2.ONE * mesh_size
	q.material = mat
	g.draw_pass_1 = q
	g.position = p
	g.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 60, 80))
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)
	return g


static func ramp(cols: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(range(cols.size()).map(func(i): return float(i) / (cols.size() - 1)))
	g.colors = PackedColorArray(cols)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for pt in points:
		c.add_point(pt)
	var t := CurveTexture.new()
	t.curve = c
	return t


func flame_mat(mode: int, energy: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FLAME
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("energy", energy)
	_fx_mats.append(m)
	return m


func smoke_mat(col: Color, density: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SMOKE
	m.set_shader_parameter("smoke_col", col)
	m.set_shader_parameter("density", density)
	_fx_mats.append(m)
	return m


func fire_at(p: Vector3, spread: Vector3, amount: int, size: float) -> Array[GPUParticles3D]:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = spread
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.4 * size
	pm.initial_velocity_max = 1.0 * size
	pm.gravity = Vector3(0, 1.2 * size, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	pm.scale_curve = curve([Vector2(0, 0.6), Vector2(0.3, 1.0), Vector2(1, 0.15)])
	pm.color_ramp = ramp([Color(1.0, 0.75, 0.3), Color(1.0, 0.38, 0.1), Color(0.6, 0.1, 0.04)])
	var f := _particles("Flame", amount, 0.9, 0.75 * size, flame_mat(0, 2.6), pm, p)
	var em := ParticleProcessMaterial.new()
	em.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	em.emission_box_extents = spread
	em.direction = Vector3.UP
	em.spread = 25.0
	em.initial_velocity_min = 1.0 * size
	em.initial_velocity_max = 2.5 * size
	em.gravity = Vector3(0.4, 0.5, 0)
	em.turbulence_enabled = true
	em.turbulence_noise_strength = 2.0
	em.turbulence_influence_min = 0.1
	em.turbulence_influence_max = 0.25
	em.color_ramp = ramp([Color(1.0, 0.8, 0.4), Color(1.0, 0.35, 0.1, 0.0)])
	var e := _particles("Embers", amount, 2.6, 0.035 * maxf(size, 1.0), flame_mat(1, 5.0), em, p + Vector3(0, 0.3, 0))
	var sm := ParticleProcessMaterial.new()
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sm.emission_box_extents = spread
	sm.direction = Vector3.UP
	sm.spread = 10.0
	sm.initial_velocity_min = 0.8 * size
	sm.initial_velocity_max = 1.2 * size
	sm.gravity = Vector3(0.35, 0.15, 0.1)
	sm.scale_curve = curve([Vector2(0, 0.4), Vector2(1, 1.0)])
	var s := _particles("Smoke", maxi(8, amount / 2), 6.0, 1.6 * size, smoke_mat(Color(0.25, 0.23, 0.22), 0.45), sm, p + Vector3(0, 1.0 * size, 0))
	return [f, e, s]


func _build_fx() -> void:
	camp.assign(fire_at(FIRE_AT + Vector3(0, height(FIRE_AT.x, FIRE_AT.z) + 0.15, 0), Vector3(0.22, 0.05, 0.22), 26, 1.0))
	fire_light = OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.55, 0.25)
	fire_light.omni_range = 11.0
	fire_light.light_energy = 2.2
	fire_light.position = FIRE_AT + Vector3(0, 1.0, 0)
	add_child(fire_light)
	for h in houses:  # a thread of smoke from every chimney
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3.UP
		pm.spread = 6.0
		pm.initial_velocity_min = 0.5
		pm.initial_velocity_max = 0.8
		pm.gravity = Vector3(0.25, 0.1, 0.08)
		pm.scale_curve = curve([Vector2(0, 0.35), Vector2(1, 1.0)])
		chimneys.append(_particles("Chimney", 10, 8.0, 1.6, smoke_mat(Color(0.72, 0.7, 0.68), 0.32), pm, h["chimney"]))
	for i in 5:  # the fall: roofs catch, a column of smoke over each
		var h: Dictionary = houses[i * 2 % houses.size()] if i < 4 else houses[1]
		var size: Vector3 = h["size"]
		var set := fire_at(h["roof"], Vector3(size.x * 0.4, 0.4, size.z * 0.3), 34, 2.2)
		for g in set:
			g.emitting = false
			fires.append(g)
	for i in 2:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.4, 0.15)
		l.omni_range = 18.0
		l.light_energy = 0.0
		l.position = (houses[i * 3]["roof"] as Vector3) + Vector3(0, 2, 0)
		add_child(l)
		burn_lights.append(l)
	# the villagers' faith rising as motes of light
	var mp := ParticleProcessMaterial.new()
	mp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mp.emission_box_extents = Vector3(9, 0.5, 9)
	mp.direction = Vector3.UP
	mp.spread = 15.0
	mp.initial_velocity_min = 0.8
	mp.initial_velocity_max = 1.6
	mp.gravity = Vector3(0, 0.4, 0)
	mp.turbulence_enabled = true
	mp.turbulence_noise_strength = 1.5
	mp.turbulence_influence_min = 0.05
	mp.turbulence_influence_max = 0.15
	mp.color_ramp = ramp([Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.75, 0.35, 1.0), Color(1.0, 0.6, 0.25, 0.0)])
	motes = _particles("Faith", 260, 9.0, 0.09, flame_mat(1, 4.0), mp, VILLAGE + Vector3(0, 1.2, 0))
	motes.emitting = false
	# the Veil's fall: shards rain from the dome; the rewind: they fly back up
	var sp := ParticleProcessMaterial.new()
	sp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	sp.emission_sphere_radius = 36.0
	sp.gravity = Vector3(0, -3.5, 0)
	sp.initial_velocity_min = 0.0
	sp.initial_velocity_max = 2.0
	sp.direction = Vector3.DOWN
	sp.spread = 60.0
	sp.scale_min = 0.5
	sp.scale_max = 1.6
	sp.color_ramp = ramp([Color(1.0, 0.8, 0.45), Color(1.0, 0.45, 0.2), Color(0.8, 0.2, 0.1, 0.0)])
	shards = _particles("Shards", 900, 7.0, 0.55, flame_mat(2, 3.0), sp, VILLAGE)
	shards.one_shot = true
	shards.explosiveness = 0.85
	shards.emitting = false
	var up := ParticleProcessMaterial.new()
	up.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	up.emission_box_extents = Vector3(30, 0.3, 30)
	up.gravity = Vector3(0, 4.0, 0)
	up.direction = Vector3.UP
	up.spread = 5.0
	up.initial_velocity_min = 2.0
	up.initial_velocity_max = 5.0
	up.scale_min = 0.5
	up.scale_max = 1.4
	up.color_ramp = ramp([Color(1.0, 0.6, 0.3, 0.0), Color(1.0, 0.8, 0.45), Color(1.0, 0.85, 0.55, 0.0)])
	unshards = _particles("Unshards", 700, 5.0, 0.5, flame_mat(2, 3.5), up, VILLAGE)
	unshards.emitting = false


func _flicker() -> void:
	var f := 0.82 + 0.1 * sin(clock * 11.0) + 0.08 * sin(clock * 23.0 + 1.3)
	fire_light.light_energy = 2.2 * f * (1.0 if camp[0].emitting else 0.0)
	for i in burn_lights.size():
		if burn_lights[i].light_energy > 0.0 or fires[0].emitting:
			burn_lights[i].light_energy = (4.0 if fires[0].emitting else 0.0) * (0.75 + 0.25 * sin(clock * (9.0 + i * 4.0)))


# ------------------------------------------------------------------ the Veil
func _build_veil() -> void:
	veil_mat = ShaderMaterial.new()
	veil_mat.shader = VEIL
	veil_mat.set_shader_parameter("strength", 0.0)
	var s := SphereMesh.new()
	s.radius = 36.0
	s.height = 72.0
	s.radial_segments = 64
	s.rings = 32
	veil = MeshInstance3D.new()
	veil.name = "Veil"
	veil.mesh = s
	veil.material_override = veil_mat
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	veil.position = VILLAGE
	add_child(veil)


# ------------------------------------------------------------------ Skotos
func _build_skotos() -> void:
	## A god the world forgot, risen out of the Dark Wood behind you: a hooded shape of smoke some 30 m tall, two
	## ember eyes, arms that reach over the trees. Warden purple rims the smoke; no blue.
	skotos = Node3D.new()
	skotos.name = "Skotos"
	skotos.position = SKOTOS_AT + Vector3(0, -45, 0)
	skotos.rotation.y = atan2(-SKOTOS_AT.x, -SKOTOS_AT.z)  # faces the village and you
	skotos.scale = Vector3.ONE * 1.7  # the hood must clear the pines from where you stand
	add_child(skotos)
	skotos_mat = ShaderMaterial.new()
	skotos_mat.shader = SMOKE
	skotos_mat.set_shader_parameter("billboard", false)
	skotos_mat.set_shader_parameter("smoke_col", Color(0.16, 0.08, 0.2))
	skotos_mat.set_shader_parameter("density", 0.97)
	skotos_mat.set_shader_parameter("rim", 2.2)
	var st := new_st()
	lathe(st, PackedVector2Array([Vector2(11.0, 0), Vector2(8.0, 6.0), Vector2(6.2, 14.0), Vector2(6.6, 21.0), Vector2(5.0, 25.0), Vector2(3.2, 28.0),
		Vector2(3.6, 30.0), Vector2(3.0, 32.5), Vector2(1.6, 34.5), Vector2(0.0, 35.0)]), Transform3D.IDENTITY, K.CLOTH, Color(1, 1, 1), 24, 0.18)
	for sx in [-1, 1]:  # arms
		lathe(st, PackedVector2Array([Vector2(1.6, 0), Vector2(1.3, 6.0), Vector2(0.9, 12.0), Vector2(1.3, 13.0), Vector2(0.4, 15.0), Vector2(0.0, 15.5)]),
			Transform3D(Basis(Vector3.FORWARD, sx * -1.25) * Basis(Vector3.RIGHT, 0.35), Vector3(sx * 5.0, 22.0, 1.0)), K.CLOTH, Color(1, 1, 1), 10, 0.2)
	var body := MeshInstance3D.new()
	body.mesh = st.commit()
	body.material_override = skotos_mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skotos.add_child(body)
	var eyes := new_st()
	for sx in [-1, 1]:
		ball(eyes, 0.42, Transform3D(Basis.from_scale(Vector3(1.3, 0.55, 0.5)), Vector3(sx * 0.9, 30.8, 2.7)), K.EMBER, Color(0.75, 0.45, 1.0), 10)
	var em := MeshInstance3D.new()
	em.mesh = eyes.commit()
	em.material_override = surf
	skotos.add_child(em)
	skotos_eyes = OmniLight3D.new()
	skotos_eyes.light_color = Color(0.6, 0.35, 0.85)
	skotos_eyes.omni_range = 30.0
	skotos_eyes.light_energy = 0.0
	skotos_eyes.position = Vector3(0, 30, 6)
	skotos.add_child(skotos_eyes)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 9.0
	pm.direction = Vector3.UP
	pm.spread = 30.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.5
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_curve = curve([Vector2(0, 0.5), Vector2(1, 1.0)])
	var smoke := _particles("SkotosSmoke", 40, 7.0, 12.0, smoke_mat(Color(0.06, 0.04, 0.07), 0.7), pm, Vector3.ZERO)
	remove_child(smoke)
	skotos.add_child(smoke)
	smoke.position = Vector3(0, 6, 0)
	var ep := ParticleProcessMaterial.new()
	ep.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ep.emission_box_extents = Vector3(14, 10, 8)
	ep.direction = Vector3.UP
	ep.initial_velocity_min = 1.0
	ep.initial_velocity_max = 3.0
	ep.gravity = Vector3(0, 0.8, 0)
	ep.color_ramp = ramp([Color(0.6, 0.35, 0.85, 0.0), Color(0.75, 0.45, 1.0), Color(0.9, 0.3, 0.2, 0.0)])
	var sparks := _particles("SkotosEmbers", 120, 5.0, 0.25, flame_mat(1, 5.0), ep, Vector3.ZERO)
	remove_child(sparks)
	skotos.add_child(sparks)
	sparks.position = Vector3(0, 15, 0)
	skotos_fx = [smoke, sparks]
	skotos.visible = false


# ------------------------------------------------------------------ the dark that comes out of the wood
func _build_beasts() -> void:
	beast_mat = ShaderMaterial.new()
	beast_mat.shader = SMOKE
	beast_mat.set_shader_parameter("billboard", false)
	beast_mat.set_shader_parameter("smoke_col", Color(0.03, 0.02, 0.03))
	beast_mat.set_shader_parameter("density", 1.0)
	beast_mat.set_shader_parameter("rim", 0.6)
	beast_mat.set_shader_parameter("rim_col", Color(0.9, 0.3, 0.15))
	for i in 9:
		var b := Node3D.new()
		b.name = "Shade%d" % i
		var st := new_st()
		lathe(st, PackedVector2Array([Vector2(0.0, -0.9), Vector2(0.35, -0.7), Vector2(0.45, 0.0), Vector2(0.38, 0.6), Vector2(0.2, 0.9), Vector2(0.0, 1.0)]),
			Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0.95, 0)), K.CLOTH, Color(1, 1, 1), 10, 0.25)
		ball(st, 0.32, Transform3D(Basis.from_scale(Vector3(0.8, 0.8, 1.2)), Vector3(0, 1.25, 1.05)), K.CLOTH, Color(1, 1, 1), 10)
		var body := MeshInstance3D.new()
		body.mesh = st.commit()
		body.material_override = beast_mat
		b.add_child(body)
		var eyes := new_st()
		for sx in [-1, 1]:
			ball(eyes, 0.06, at(Vector3(sx * 0.13, 1.32, 1.33)), K.EMBER, Color(1.0, 0.4, 0.12), 6)
		var em := MeshInstance3D.new()
		em.mesh = eyes.commit()
		em.material_override = surf
		b.add_child(em)
		var legs: Array = []
		for k in 4:
			var leg := Node3D.new()
			leg.position = Vector3(0.22 * (1 if k % 2 else -1), 0.85, 0.55 if k < 2 else -0.55)
			var ls := new_st()
			cyl(ls, 0.07, 0.1, 0.85, at(Vector3(0, -0.42, 0)), K.CLOTH, Color(1, 1, 1), 6)
			var lm := MeshInstance3D.new()
			lm.mesh = ls.commit()
			lm.material_override = beast_mat
			leg.add_child(lm)
			b.add_child(leg)
			legs.append(leg)
		var a := PI / 2.0 + (i - 4) * 0.42 + _rng.randf_range(-0.1, 0.1)  # out of the wood on your side, round to the flanks
		var from := Vector3(cos(a) * 34.0, 0, sin(a) * 34.0 - 4.0)
		var house: Dictionary = houses[i % houses.size()]
		b.visible = false
		add_child(b)
		beasts.append({"node": b, "legs": legs, "from": from, "to": (house["door"] as Vector3), "t": -_rng.randf_range(0.0, 3.0), "speed": _rng.randf_range(0.075, 0.11), "back": false})


func release_beasts() -> void:
	for b in beasts:
		b["node"].visible = true
		b["back"] = false


func recall_beasts() -> void:
	for b in beasts:
		b["back"] = true


func _tick_beasts(delta: float) -> void:
	for b in beasts:
		var n: Node3D = b["node"]
		if not n.visible:
			continue
		b["t"] = clampf(b["t"] + delta * b["speed"] * (-2.5 if b["back"] else 1.0), -3.0, 1.0)
		var k := clampf(b["t"], 0.0, 1.0)
		var p: Vector3 = (b["from"] as Vector3).lerp(b["to"], k)
		p.y = height(p.x, p.z)
		n.position = p
		var dir: Vector3 = (b["to"] as Vector3) - (b["from"] as Vector3)
		n.rotation.y = atan2(dir.x, dir.z)
		var moving := 1.0 if (k > 0.0 and k < 1.0) else 0.15
		var ph := clock * 9.0 + n.get_index()
		for j in 4:
			(b["legs"][j] as Node3D).rotation.x = sin(ph + (PI if j in [1, 2] else 0.0)) * 0.7 * moving
		if b["back"] and b["t"] <= -2.9:
			n.visible = false


# ------------------------------------------------------------------ the hourglass
func _build_hourglass() -> void:
	## A brass-and-glass hourglass as tall as a person, hanging in the air in front of you for the rewind.
	hourglass = Node3D.new()
	hourglass.name = "Hourglass"
	hourglass.position = Vector3(0, 2.05, -4.6)
	hourglass.visible = false
	add_child(hourglass)
	var st := new_st()
	var brass := Color(0.78, 0.56, 0.25)
	for y in [-1.0, 1.0]:
		cyl(st, 0.55, 0.55, 0.1, at(Vector3(0, y * 0.95, 0)), K.BRASS, brass, 24)
		cyl(st, 0.48, 0.5, 0.06, at(Vector3(0, y * 0.88, 0)), K.WOOD, Color(0.3, 0.17, 0.1), 24)
	for k in 3:
		var a := TAU * k / 3.0
		lathe(st, PackedVector2Array([Vector2(0.035, -0.9), Vector2(0.05, -0.6), Vector2(0.035, -0.3), Vector2(0.05, 0.0), Vector2(0.035, 0.3), Vector2(0.05, 0.6), Vector2(0.035, 0.9)]),
			at(Vector3(cos(a) * 0.46, 0, sin(a) * 0.46)), K.BRASS, brass, 8)
	var frame := MeshInstance3D.new()
	frame.mesh = st.commit()
	frame.material_override = surf
	hourglass.add_child(frame)
	var sand_col := Color(0.95, 0.72, 0.4)
	var top := new_st()
	lathe(top, PackedVector2Array([Vector2(0.02, 0.0), Vector2(0.2, 0.18), Vector2(0.3, 0.42), Vector2(0.0, 0.42)]), Transform3D.IDENTITY, K.EMBER, sand_col * 0.5, 16)
	sand_top = MeshInstance3D.new()
	(sand_top as MeshInstance3D).mesh = top.commit()
	(sand_top as MeshInstance3D).material_override = surf
	sand_top.position = Vector3(0, 0.08, 0)
	hourglass.add_child(sand_top)
	var bot := new_st()
	lathe(bot, PackedVector2Array([Vector2(0.36, 0.0), Vector2(0.3, 0.2), Vector2(0.0, 0.38)]), Transform3D.IDENTITY, K.EMBER, sand_col * 0.5, 16)
	sand_bottom = MeshInstance3D.new()
	(sand_bottom as MeshInstance3D).mesh = bot.commit()
	(sand_bottom as MeshInstance3D).material_override = surf
	sand_bottom.position = Vector3(0, -0.85, 0)
	hourglass.add_child(sand_bottom)
	glass_mat = ShaderMaterial.new()
	glass_mat.shader = GLASS
	var gs := new_st()
	lathe(gs, PackedVector2Array([Vector2(0.44, -0.86), Vector2(0.45, -0.6), Vector2(0.36, -0.3), Vector2(0.08, -0.04), Vector2(0.05, 0.0), Vector2(0.08, 0.04), Vector2(0.36, 0.3),
		Vector2(0.45, 0.6), Vector2(0.44, 0.86)]), Transform3D.IDENTITY, K.BRASS, Color(1, 1, 1), 28)
	var g := MeshInstance3D.new()
	g.mesh = gs.commit()
	g.material_override = glass_mat
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hourglass.add_child(g)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.omni_range = 5.0
	light.light_energy = 1.2
	hourglass.add_child(light)
