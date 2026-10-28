class_name VfxKit
extends RefCounted
## Shared building blocks for every effect (M2, Siddharth 2026-10-27). Hard-edged toon shapes with a glow, cheap on
## Quest: unshaded additive quads, a few CPUParticles3D bursts, no textures from outside (the shapes are drawn here).
## Magic colours are black / orange / red only (CLAUDE.md); the wind is pale green and only the Longbow uses it.
## Particle cap (asset list X20): at most MAX_BURSTS one-shot emitters alive at once, further ones are skipped.

const FIRE_RED := Color("E8452C")    # palette fire_red
const FIRE_ORANGE := Color("F6A45D") # palette lantern_glow
const FIRE_YELLOW := Color("FFD45A") # palette fire_yellow
const INK := Color("111C30")         # palette ink
const WIND := Color("BFF0C5")        # heal_green 7FE08A lightened 50% toward white: kept whiter than heal_green
const MAX_BURSTS := 24
const FIRE_SHADER := preload("res://shaders/fx_toon_fire.gdshader")
const BURST_SHADER := preload("res://shaders/fx_toon_burst.gdshader")
const WIND_SHADER := preload("res://shaders/fx_toon_wind.gdshader")
static var _noise: ImageTexture

static var _tex := {}
static var _mats := {}
static var _active := 0


static func tex(kind: String) -> Texture2D:
	## Shapes drawn in code: "glow" (soft), "disc" (hard edge), "ring", "diamond" (an ember spark), "streak" (a tapered wind line).
	if _tex.has(kind):
		return _tex[kind]
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var a := 0.0
			match kind:
				"glow":  # soft radial falloff for halos (the hard-edged "disc" is for particles and cores)
					var rr := clampf(sqrt(u * u + v * v), 0.0, 1.0)
					a = pow(1.0 - rr, 2.2)
				"disc":
					a = clampf((0.94 - sqrt(u * u + v * v)) * 14.0, 0.0, 1.0)
				"ring":
					var r := sqrt(u * u + v * v)
					a = clampf((0.98 - r) * 14.0, 0.0, 1.0) * clampf((r - 0.72) * 14.0, 0.0, 1.0)
				"diamond":
					a = clampf((0.94 - (absf(u) + absf(v))) * 12.0, 0.0, 1.0)
				"streak":  # long axis along x, pointed at both ends
					a = clampf((1.0 - absf(u)) * 3.0, 0.0, 1.0) * clampf((0.24 * (1.0 - absf(u)) - absf(v)) * 20.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t


static func material(shape: String, particles := false, additive := true) -> StandardMaterial3D:
	## One shared material per (shape, particles, additive). Colour comes from vertex colour (particles) or from
	## tinted(), which copies the material.
	var key := "%s|%s|%s" % [shape, particles, additive]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_texture = tex(shape)
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES if particles else BaseMaterial3D.BILLBOARD_ENABLED
	if particles:
		m.billboard_keep_scale = true
	_mats[key] = m
	return m


static func quad(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	return q


static func halo(parent: Node3D, size: float, color: Color, shape := "glow") -> MeshInstance3D:
	## A glowing billboard (own material so its colour and alpha can change).
	var mi := MeshInstance3D.new()
	mi.mesh = quad(size)
	var m: StandardMaterial3D = material(shape).duplicate()
	m.albedo_color = color
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func set_halo(mi: MeshInstance3D, size: float, color: Color) -> void:
	(mi.mesh as QuadMesh).size = Vector2(size, size)
	(mi.material_override as StandardMaterial3D).albedo_color = color


static func _emitter(color_a: Color, color_b: Color, amount: int, life: float, size: float, speed: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.mesh = quad(1.0)
	p.material_override = material("disc", true)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	var ramp := Gradient.new()
	ramp.set_color(0, color_a)
	ramp.set_color(1, Color(color_b, 0.0))
	ramp.add_point(0.35, color_b)
	p.color_ramp = ramp
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1.0))
	shrink.add_point(Vector2(1, 0.15))
	p.scale_amount_curve = shrink
	return p


static func burst(at_parent: Node, world_pos: Vector3, color_a: Color, color_b: Color, count := 12, speed := 0.06, life := 0.45, size := 0.006, gravity := -0.12) -> CPUParticles3D:
	## A one-shot puff of embers at world_pos. Skipped (returns null) when MAX_BURSTS are already alive.
	if _active >= MAX_BURSTS or at_parent == null or not at_parent.is_inside_tree():
		return null
	var p := _emitter(color_a, color_b, count, life, size, speed)
	p.one_shot = true
	p.explosiveness = 0.95
	p.gravity = Vector3(0, gravity, 0)
	at_parent.add_child(p)
	p.global_position = world_pos
	p.emitting = true
	_active += 1
	p.tree_exited.connect(_burst_gone)  # the counter drops whenever the emitter leaves the tree, however that happens
	_free_after(p, life + 0.15)
	return p


static func _burst_gone() -> void:
	_active = maxi(0, _active - 1)


static func _free_after(n: Node, seconds: float) -> void:
	## A timer that is itself a child of n, so it can never fire after n is gone.
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = seconds
	n.add_child(t)
	t.timeout.connect(n.queue_free)
	t.start()


static func trail(parent: Node3D, color_a: Color, color_b: Color, rate := 40, life := 0.3, size := 0.005) -> CPUParticles3D:
	## A continuous ember trail that stays where it was dropped (world space). Call release_trail() when its owner dies.
	var p := _emitter(color_a, color_b, rate, life, size, 0.012)
	p.spread = 60.0
	p.gravity = Vector3(0, 0.02, 0)
	p.emitting = true
	parent.add_child(p)
	return p


static func release_trail(p: CPUParticles3D, new_parent: Node) -> void:
	## The owner is done: leave the trail behind to fade out on its own.
	if p == null or not is_instance_valid(p) or new_parent == null or not new_parent.is_inside_tree():
		return
	var xf := p.global_transform
	p.get_parent().remove_child(p)
	new_parent.add_child(p)
	p.global_transform = xf
	p.emitting = false
	_free_after(p, p.lifetime + 0.1)


static func flash(at_parent: Node, world_pos: Vector3, color: Color, size := 0.03, life := 0.18) -> void:
	## A quick glow that swells then fades.
	if at_parent == null or not at_parent.is_inside_tree():
		return
	var mi := halo(at_parent as Node3D, size * 0.4, color)
	mi.global_position = world_pos
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(k: float): set_halo(mi, size * (0.4 + 0.6 * k), Color(color, color.a * (1.0 - k))), 0.0, 1.0, life)
	tw.chain().tween_callback(mi.queue_free)


static func ring(at_parent: Node, world_pos: Vector3, color: Color, radius := 0.03, life := 0.4) -> void:
	## A flat ring on the ground that expands and fades (reads from above).
	if at_parent == null or not at_parent.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	mi.mesh = quad(1.0)
	var m: StandardMaterial3D = material("ring").duplicate()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	m.albedo_color = color
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	at_parent.add_child(mi)
	mi.global_position = world_pos + Vector3(0, 0.002, 0)
	mi.rotation.x = -PI / 2.0
	var tw := mi.create_tween()
	tw.tween_method(func(k: float):
		mi.scale = Vector3.ONE * radius * 2.0 * (0.25 + 0.75 * k)
		m.albedo_color = Color(color, color.a * (1.0 - k)), 0.0, 1.0, life)
	tw.tween_callback(mi.queue_free)


static func active_bursts() -> int:
	return _active


# ---- hand-painted toon fire (the moodboard VFX look: hard bands, ink cut-outs, swept tails) -----------------------

static func noise() -> ImageTexture:
	## Seamless soft noise (3 octaves of value noise) drawn once; the toon shaders scroll and threshold it.
	if _noise != null:
		return _noise
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_L8)
	var oct := [[4, 0.55], [8, 0.3], [16, 0.15]]
	var lat := {}
	for o in oct:
		var f: int = o[0]
		var g := []
		for i in f * f:
			g.append(randf_seed_hash(i * 7 + f * 131))
		lat[f] = g
	for y in n:
		for x in n:
			var v := 0.0
			for o in oct:
				var f: int = o[0]
				var fx := float(x) / n * f
				var fy := float(y) / n * f
				var x0 := int(floor(fx)) % f
				var y0 := int(floor(fy)) % f
				var x1 := (x0 + 1) % f
				var y1 := (y0 + 1) % f
				var tx := smoothstep(0.0, 1.0, fx - floor(fx))
				var ty := smoothstep(0.0, 1.0, fy - floor(fy))
				var g: Array = lat[f]
				var a := lerpf(g[y0 * f + x0], g[y0 * f + x1], tx)
				var b := lerpf(g[y1 * f + x0], g[y1 * f + x1], tx)
				v += lerpf(a, b, ty) * o[1]
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	_noise = ImageTexture.create_from_image(img)
	return _noise


static func randf_seed_hash(i: int) -> float:
	var h := (i * 374761393 + 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 10007) / 10007.0


static func toon_fire(parent: Node3D, mode: int, size: Vector2, energy := 1.0, flow := 1.0) -> MeshInstance3D:
	## mode 0 orb, 1 plume, 2 comet (see fx_toon_fire.gdshader). size = world size in metres (along the axis, across).
	var mi := MeshInstance3D.new()
	mi.mesh = quad(1.0)
	var m := ShaderMaterial.new()
	m.shader = FIRE_SHADER
	m.set_shader_parameter("noise", noise())
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("size", size)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("flow", flow)
	m.set_shader_parameter("seed", randf() * 40.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	parent.add_child(mi)
	return mi


static func toon_set(mi: MeshInstance3D, param: String, value: Variant) -> void:
	(mi.material_override as ShaderMaterial).set_shader_parameter(param, value)


static func toon_wind(parent: Node3D, mode: int, size: Vector2, energy := 1.0, flow := 1.0) -> MeshInstance3D:
	## The Longbow's painted wind (fx_toon_wind.gdshader): mode 0 vortex, 1 gust streaks along `axis`.
	var mi := MeshInstance3D.new()
	mi.mesh = quad(1.0)
	var m := ShaderMaterial.new()
	m.shader = WIND_SHADER
	m.set_shader_parameter("noise", noise())
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("size", size)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("flow", flow)
	m.set_shader_parameter("seed", randf() * 40.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	parent.add_child(mi)
	return mi


static func toon_wind_burst(at_parent: Node, world_pos: Vector3, size: float, kind := "slash", life := 0.4) -> MeshInstance3D:
	## One-shot painted wind: "slash" (pierce flash, faces the camera) or "ring" (a flat gust ring on the ground).
	if _active >= MAX_BURSTS or at_parent == null or not at_parent.is_inside_tree():
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = quad(1.0)
	var m := ShaderMaterial.new()
	m.shader = WIND_SHADER
	m.set_shader_parameter("noise", noise())
	m.set_shader_parameter("mode", 2 if kind == "ring" else 3)
	m.set_shader_parameter("size", Vector2(size, size))
	m.set_shader_parameter("seed", randf() * 40.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	at_parent.add_child(mi)
	mi.global_position = world_pos + (Vector3(0, 0.002, 0) if kind == "ring" else Vector3.ZERO)
	_active += 1
	mi.tree_exited.connect(_burst_gone)
	var tw := mi.create_tween()
	tw.tween_method(func(k: float): m.set_shader_parameter("progress", k), 0.0, 1.0, life)
	tw.tween_callback(mi.queue_free)
	return mi


static func toon_burst(at_parent: Node, world_pos: Vector3, size: float, kind := "burst", life := 0.5) -> MeshInstance3D:
	## A one-shot painted explosion ("burst": cloud, dark blotches and pale shards) or a flaming ground ring ("ring").
	if _active >= MAX_BURSTS or at_parent == null or not at_parent.is_inside_tree():
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = quad(1.0)
	var m := ShaderMaterial.new()
	m.shader = BURST_SHADER
	m.set_shader_parameter("noise", noise())
	m.set_shader_parameter("mode", 1 if kind == "ring" else 0)
	m.set_shader_parameter("size", Vector2(size, size))
	m.set_shader_parameter("seed", randf() * 40.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	at_parent.add_child(mi)
	mi.global_position = world_pos + (Vector3(0, 0.002, 0) if kind == "ring" else Vector3.ZERO)
	_active += 1
	mi.tree_exited.connect(_burst_gone)
	var tw := mi.create_tween()
	tw.tween_method(func(k: float): m.set_shader_parameter("progress", k), 0.0, 1.0, life)
	tw.tween_callback(mi.queue_free)
	return mi


static func build_pop(parent: Node, at: Vector3) -> void:
	## A tower going up (or being sold): a painted dust-and-spark cloud and a ground ring round its base.
	toon_burst(parent, at + Vector3(0, 0.02, 0), 0.12, "burst", 0.45)
	toon_burst(parent, at, 0.16, "ring", 0.45)
	burst(parent, at + Vector3(0, 0.01, 0), FIRE_ORANGE, INK, 8, 0.04, 0.4, 0.004)


static func toon_ring(parent: Node3D, radius: float) -> MeshInstance3D:
	## A standing flaming ring on the ground (the burst shader's ring in its held mode: thin, steady), `radius` metres out to its flame.
	## Its teeth lick when `progress` moves a little (the caller wobbles it). The quad lies flat, so the node must stay level.
	var mi := MeshInstance3D.new()
	mi.mesh = quad(1.0)
	var m := ShaderMaterial.new()
	m.shader = BURST_SHADER
	m.set_shader_parameter("noise", noise())
	m.set_shader_parameter("mode", 1)
	m.set_shader_parameter("size", Vector2.ONE * radius / 0.41)  # a held ring sits at 0.82 of the half-size
	m.set_shader_parameter("hold", 1.0)
	m.set_shader_parameter("seed", randf() * 40.0)
	m.set_shader_parameter("progress", 0.5)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	parent.add_child(mi)
	return mi


static func toon_cloud(parent: Node3D, size: float) -> MeshInstance3D:
	## A standing painted storm cloud blob (the burst shader held at one lumpy frame): ink and smoky greys, no spikes.
	var mi := MeshInstance3D.new()
	mi.mesh = quad(1.0)
	var m := ShaderMaterial.new()
	m.shader = BURST_SHADER
	m.set_shader_parameter("noise", noise())
	m.set_shader_parameter("mode", 0)
	m.set_shader_parameter("size", Vector2(size, size))
	m.set_shader_parameter("seed", randf() * 40.0)
	m.set_shader_parameter("progress", 0.3)
	m.set_shader_parameter("shards", 0.0)
	m.set_shader_parameter("c_core", Color("5B4F50"))
	m.set_shader_parameter("c_mid", Color("2E2A33"))
	m.set_shader_parameter("c_out", Color("111C30"))
	m.set_shader_parameter("c_ink", Color("111C30"))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	parent.add_child(mi)
	return mi


static func toon_smoke(parent: Node, at: Vector3, size: float, life := 1.6) -> void:
	## A painted ink-smoke puff (ink, stone_dark and stone bands, same cloud shape as the burst) that drifts up and thins out.
	var mi := toon_burst(parent, at, size, "burst", life)
	if mi == null:
		return
	var m := mi.material_override as ShaderMaterial
	m.set_shader_parameter("c_core", Color("8C9096"))
	m.set_shader_parameter("c_mid", Color("5B4F50"))
	m.set_shader_parameter("c_out", Color("111C30"))
	m.set_shader_parameter("c_ink", Color("111C30"))
	m.set_shader_parameter("shards", 0.0)
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position", at + Vector3(0.004, size * 0.7, 0), life)


static func toon_dust(parent: Node, at: Vector3, size: float) -> void:
	## A painted dust puff (path_stone and dirt bands, no spikes) that swells and fades at ground level.
	var mi := toon_burst(parent, at, size, "burst", 0.7)
	if mi == null:
		return
	var m := mi.material_override as ShaderMaterial
	m.set_shader_parameter("c_core", Color("C2B49A"))
	m.set_shader_parameter("c_mid", Color("A89878"))
	m.set_shader_parameter("c_out", Color("7E6048"))
	m.set_shader_parameter("c_ink", Color("7E6048"))
	m.set_shader_parameter("shards", 0.0)
	m.set_shader_parameter("depth_bias", 0.02)  # in front of the grass
