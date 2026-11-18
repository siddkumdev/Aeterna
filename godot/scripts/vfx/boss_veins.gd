class_name BossVeins
extends Node3D
## Phase 2: glowing purple root veins run along the ground from Skotos to each heartwood knot until the knot is broken
## (Siddharth 2026-11-18). Looks only. One triangle strip per knot, rebuilt every frame (3 knots x 10 points). A vein
## snaps (a purple burst, then gone) when its knot dies; the whole thing frees itself when no vein is left or the boss is gone.
## Lives in the same parent as the boss (the enemies root), so boss.position and knot.position share one space.

const POINTS := 10
const WIDTH := 0.028
const GLOW := Color("C77CF0")

var boss: Enemy
var knots: Array = []  # Enemy
var _mesh := ImmediateMesh.new()
var _mi := MeshInstance3D.new()
var _t := 0.0
var _seed := 0.0
var _acc := 0.0  # the strip is rebuilt at 30 Hz, not every frame


static func attach(b: Enemy, shield: Array) -> BossVeins:
	## Adds the veins beside the boss. Returns null when the boss has no parent yet.
	if b == null or b.get_parent() == null:
		return null
	var v := BossVeins.new()
	v.boss = b
	v.knots = shield.duplicate()
	b.get_parent().add_child(v)
	return v


func _ready() -> void:
	_mi.mesh = _mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mi.material_override = m
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.extra_cull_margin = 2.0
	add_child(_mi)
	_seed = randf() * 10.0


func vein_count() -> int:
	return knots.size()


func _process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(boss) or not boss.alive:
		queue_free()
		return
	var keep: Array = []
	for k in knots:
		if is_instance_valid(k) and k.alive:
			keep.append(k)
		elif is_instance_valid(k):
			_snap(k.position)
	knots = keep
	if keep.is_empty():
		queue_free()
		return
	_acc += delta
	if _acc < 1.0 / 30.0:
		return
	_acc = 0.0
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for ki in knots.size():
		var a := Vector3(boss.position.x, 0.035, boss.position.z)
		var kp: Vector3 = knots[ki].position
		var b := Vector3(kp.x, 0.035, kp.z)
		var d := b - a
		var dist := d.length()
		if dist < 0.001:
			continue
		var side := Vector3(-d.z, 0, d.x) / dist
		for i in POINTS:
			var u := float(i) / (POINTS - 1)
			var wob := sin(u * 9.0 + _seed + ki * 2.0 + _t * 0.8) * 0.012 * sin(u * PI)  # the vein winds
			var p := a.lerp(b, u) + side * wob
			p.y = 0.035 + 0.002 * sin(u * 14.0 + _t * 2.0)
			var pulse := 0.8 + 0.2 * sin(_t * 4.0 - u * 10.0 + ki)  # light runs along it, boss -> knot
			var w := WIDTH * (1.0 - 0.4 * u) * (0.7 + 0.5 * pulse)
			var c := Color(GLOW, 0.95 * pulse)
			_mesh.surface_set_color(c)
			_mesh.surface_add_vertex(p + side * w)
			_mesh.surface_set_color(c)
			_mesh.surface_add_vertex(p - side * w)
		# a degenerate pair joins this strip to the next one
		_mesh.surface_set_color(Color(GLOW, 0.0))
		_mesh.surface_add_vertex(b)
		_mesh.surface_set_color(Color(GLOW, 0.0))
		_mesh.surface_add_vertex(b)
	_mesh.surface_end()


func _snap(local_pos: Vector3) -> void:
	## The knot broke: the vein snaps (a flash and a spray of purple sparks along it).
	if not is_inside_tree() or not is_instance_valid(boss):
		return
	var mid := Vector3(boss.position.x, 0.0, boss.position.z).lerp(Vector3(local_pos.x, 0.0, local_pos.z), 0.5) + Vector3(0, 0.004, 0)
	var at := global_transform * mid
	VfxKit.burst(get_parent(), at, GLOW, Color("3B1F5C"), 10, 0.05, 0.5, 0.004, 0.0)
	VfxKit.flash(get_parent(), at, Color(GLOW, 0.5), 0.035, 0.2)
