class_name VeilDome
extends Node3D
## The Veil (plan Part D, 2026-11-10): the amber dome of the villagers' faith over the island. Story beats:
##   crack()    dusk of day 1: a purple crack (the Warden's colour) runs down from the top of the dome
##   shatter()  the Veil fails: the dome recedes and falls as embers
##   knit()     dawn: the dome weaves itself back up from the island's edge
##   snap(k, c) set the state at once (k = how knit, c = how cracked; both 0..1)
## `done(which)` is emitted when crack / shatter / knit finishes. Anchor for VFX: this node's origin is the dome's base
## centre; put it at the board's centre. Effects are logged in docs/VFX_NOTES.md.

signal done(which: String)

const AMBER := Color("F6A45D")  # palette.json lantern_glow
const GLOW := Color("FFD45A")  # fire_yellow
const WARDEN := Color("9C3EB0")  # crystal_purple, the Warden's purple
const EMBER_RED := Color("E8452C")  # fire_red
const RADIUS := 0.95  # m: past the 1.2 m board's corners (half-diagonal 0.85 m)
const HEIGHT := 0.8  # m at the top
const EMBERS := 170

var knit_amount := 1.0:
	set(v):
		knit_amount = clampf(v, 0.0, 1.0)
		_push()
var crack_amount := 0.0:
	set(v):
		crack_amount = clampf(v, 0.0, 1.0)
		_push()

var _mat: ShaderMaterial
var _dome: MeshInstance3D
var _embers: CPUParticles3D
var _tween: Tween


func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS  # a true hemisphere needs height == radius
	sphere.is_hemisphere = true
	sphere.radial_segments = 64
	sphere.rings = 24
	_dome = MeshInstance3D.new()
	_dome.name = "dome"
	_dome.mesh = sphere
	_dome.scale = Vector3(1.0, HEIGHT / RADIUS, 1.0)
	_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/veil_dome.gdshader")
	_mat.set_shader_parameter("amber", AMBER)
	_mat.set_shader_parameter("glow", GLOW)
	_mat.set_shader_parameter("warden", WARDEN)
	_dome.material_override = _mat
	add_child(_dome)
	_build_embers()
	_push()


func snap(knit_to: float, crack_to: float) -> void:
	_kill()
	knit_amount = knit_to
	crack_amount = crack_to


func crack(seconds := 1.6) -> void:
	## A purple crack runs down from the top.
	_kill()
	_tween = create_tween()
	_tween.tween_property(self, "crack_amount", 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func(): done.emit("crack"))


func shatter(seconds := 1.1) -> void:
	## The Veil fails: it falls away as embers.
	_kill()
	_embers.restart()
	_embers.emitting = true
	_tween = create_tween()
	_tween.tween_property(self, "knit_amount", 0.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func(): done.emit("shatter"))


func knit(seconds := 2.6) -> void:
	## Dawn: the dome weaves itself back up from the island's edge, and the crack is gone.
	_kill()
	crack_amount = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "knit_amount", 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func(): done.emit("knit"))


func set_crack_seed(seed_value: float) -> void:
	## A different crack path for each loop.
	if _mat:
		_mat.set_shader_parameter("crack_seed", seed_value)


func _push() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("knit", knit_amount)
	_mat.set_shader_parameter("crack", crack_amount)
	_dome.visible = knit_amount > 0.001


func _kill() -> void:
	if _tween:
		_tween.kill()


func _build_embers() -> void:
	_embers = CPUParticles3D.new()
	_embers.name = "embers"
	_embers.emitting = false
	_embers.one_shot = true
	_embers.amount = EMBERS
	_embers.lifetime = 2.4
	_embers.explosiveness = 0.8
	_embers.local_coords = false
	_embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pts := PackedVector3Array()
	for i in EMBERS:  # points over the dome's surface
		var a := rng.randf() * TAU
		var y := sqrt(rng.randf())  # more near the top than a uniform pick, so the dome seems to crumble from above
		var r := sqrt(maxf(1.0 - y * y, 0.0))
		pts.append(Vector3(cos(a) * r * RADIUS, y * HEIGHT, sin(a) * r * RADIUS))
	_embers.emission_points = pts
	_embers.direction = Vector3.DOWN
	_embers.spread = 55.0
	_embers.initial_velocity_min = 0.02
	_embers.initial_velocity_max = 0.12
	_embers.gravity = Vector3(0.0, -0.22, 0.0)
	_embers.damping_min = 0.1
	_embers.damping_max = 0.4
	_embers.scale_amount_min = 0.7
	_embers.scale_amount_max = 1.5
	var ramp := Gradient.new()
	ramp.set_color(0, GLOW)
	ramp.add_point(0.35, AMBER)
	ramp.add_point(0.75, EMBER_RED)
	ramp.set_color(ramp.get_point_count() - 1, Color(EMBER_RED, 0.0))
	_embers.color_ramp = ramp
	var shard := SphereMesh.new()
	shard.radius = 0.0035
	shard.height = 0.007
	shard.radial_segments = 6
	shard.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shard.material = m
	_embers.mesh = shard
	add_child(_embers)
