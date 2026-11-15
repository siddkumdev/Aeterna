class_name Card3D
extends Node3D
## A physical card you pick up (trading-card size, 6.3 x 8.8 cm, 2 mm thick, gilded edge). Its face is a CardFace
## rendered once into a SubViewport. Towers get a live portrait of their own model (rendered in a private 3D
## world, so no art is drawn or imported). Lift it and it turns to face your eyes and grows a little.
## Authored for the tray (CardTray); game.gd decides what releasing a card over the board does.

signal face_ready

const W := 0.063
const H := 0.088
const T := 0.002
const LIFT_SCALE := 1.2
const GOLD := Color("C9B48A")  # pale bone (no gilding, 2026-11-14)
const FACE_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform sampler2D face_texture : source_color;
uniform float unavailable : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 face = texture(face_texture, UV);
	float value = dot(face.rgb, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(face.rgb, vec3(value * 0.55), unavailable);
	ALPHA = face.a;
}
"""

static var _portrait_cache: Dictionary = {}  # scene_path -> ImageTexture
static var _shared_back_tex: Texture2D = null
static var _shared_back_vp: SubViewport = null
static var _back_waiters: Array[ShaderMaterial] = []

var data: Dictionary = {}
var home := Transform3D.IDENTITY  # where it rests in the tray (parent space)
var lifted := false
var glow := false

var _face_vp: SubViewport
var _face: CardFace
var _tween: Tween
var _body: MeshInstance3D
var _availability_applied := false
var _print_materials: Array[ShaderMaterial] = []
var _back_mat: ShaderMaterial
var _shared_shader: Shader
var _built := false
var _portrait_started := false


func setup(card: Dictionary, shared_shader: Shader = null) -> Card3D:
	data = card
	_shared_shader = shared_shader
	_build()
	return self


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE and _built:
		_start_in_tree_renders()


func _build() -> void:
	# edge slab
	_body = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(W, H, T)
	_body.mesh = box
	_body.material_override = ModelUtil.flat_material(GOLD.darkened(0.25))
	add_child(_body)
	# printed face (front) and back
	_face_vp = SubViewport.new()
	_face_vp.size = Vector2i(int(CardFace.SIZE.x), int(CardFace.SIZE.y))
	_face_vp.transparent_bg = false
	_face_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_face_vp)
	_face = CardFace.new()
	_face.data = data
	_face_vp.add_child(_face)
	_add_quad(_face_vp.get_texture(), T / 2.0 + 0.0002, false)
	if _shared_back_tex != null:
		_back_mat = _add_quad(_shared_back_tex, -T / 2.0 - 0.0002, true)
	else:
		var pending_tex: Texture2D = _shared_back_vp.get_texture() if is_instance_valid(_shared_back_vp) else null
		_back_mat = _add_quad(pending_tex, -T / 2.0 - 0.0002, true)
	_built = true
	if is_inside_tree():
		_start_in_tree_renders()


func _start_in_tree_renders() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_ensure_shared_back()
	if not _portrait_started:
		_portrait_started = true
		_render_portrait()


func _ensure_shared_back() -> void:
	if _back_mat == null:
		return
	if _shared_back_tex != null:
		_back_mat.set_shader_parameter("face_texture", _shared_back_tex)
		return
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	if not is_instance_valid(_shared_back_vp):
		var back_vp := SubViewport.new()
		back_vp.size = _face_vp.size
		back_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var back := CardFace.new()
		back.back = true
		back_vp.add_child(back)
		back_vp.set_meta(&"wait_frames", 2)
		_shared_back_vp = back_vp
		# Own the temporary back SubViewport on root so CardTray rebuilds cannot free it mid-bake.
		back_vp.ready.connect(func() -> void:
			if is_instance_valid(tree) and is_instance_valid(back_vp):
				tree.process_frame.connect(_on_back_frame.bind(tree, back_vp), CONNECT_ONE_SHOT))
		tree.root.add_child.call_deferred(back_vp)
	_back_mat.set_shader_parameter("face_texture", _shared_back_vp.get_texture())
	if not _back_waiters.has(_back_mat):
		_back_waiters.append(_back_mat)


static func _on_back_frame(tree: SceneTree, vp: SubViewport) -> void:
	if not is_instance_valid(vp):
		if _shared_back_vp == vp:
			_shared_back_vp = null
			_back_waiters.clear()
		return
	var left := int(vp.get_meta(&"wait_frames", 0)) - 1
	if left > 0:
		vp.set_meta(&"wait_frames", left)
		if is_instance_valid(tree):
			tree.process_frame.connect(_on_back_frame.bind(tree, vp), CONNECT_ONE_SHOT)
		return
	var vtex := vp.get_texture()
	var img := vtex.get_image() if vtex != null else null
	if img != null and not img.is_empty():
		_shared_back_tex = ImageTexture.create_from_image(img)
		for mat in _back_waiters:
			if is_instance_valid(mat):
				mat.set_shader_parameter("face_texture", _shared_back_tex)
	_back_waiters.clear()
	if _shared_back_vp == vp:
		_shared_back_vp = null
	vp.queue_free()


func _add_quad(tex: Texture2D, z: float, flip: bool) -> ShaderMaterial:
	var q := MeshInstance3D.new()
	var m := QuadMesh.new()
	m.size = Vector2(W - 0.002, H - 0.002)
	q.mesh = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	if _shared_shader == null:
		_shared_shader = Shader.new()
		_shared_shader.code = FACE_SHADER
	mat.shader = _shared_shader
	mat.set_shader_parameter("face_texture", tex)
	q.material_override = mat
	_print_materials.append(mat)
	q.position.z = z
	if flip:
		q.rotation.y = PI
	add_child(q)
	return mat


func _render_portrait() -> void:
	## Towers: a live portrait of the real model. Other kinds keep the face's own emblem.
	if data.get("kind", "") != "tower" or not is_inside_tree():
		return
	var path: String = GameConfig.TOWERS[data["id"]]["scene"]
	if _portrait_cache.has(path):
		_face.art = _portrait_cache[path]
		_face.queue_redraw()
		_face_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await get_tree().process_frame
		await get_tree().process_frame
		if is_instance_valid(self):
			face_ready.emit()
		return
	var res := load(path)
	if res == null:
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(int(CardFace.ART_SIZE.x), int(CardFace.ART_SIZE.y))
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var model: Node3D = res.instantiate()
	vp.add_child(model)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 35, 0)
	light.light_energy = 1.3
	vp.add_child(light)
	var cam := Camera3D.new()
	cam.fov = 28.0
	vp.add_child(cam)
	var box := _model_bounds(model)
	var c := box.get_center()
	var d := maxf(box.size.y, box.size.x) * 1.9 + 0.01
	cam.position = c + Vector3(d * 0.55, box.size.y * 0.15, d)
	cam.look_at_from_position(cam.position, c, Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(_face):
		if is_instance_valid(vp):
			vp.queue_free()
		return
	var vtex := vp.get_texture()
	var img := vtex.get_image() if vtex != null else null
	if img != null and not img.is_empty():
		var cached := ImageTexture.create_from_image(img)
		_portrait_cache[path] = cached
		_face.art = cached
		vp.queue_free()
	else:
		_face.art = vtex
	_face.queue_redraw()
	_face_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(self):
		face_ready.emit()


func _model_bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		var b := m.global_transform * m.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func set_glow(on: bool) -> void:
	if _availability_applied and on == glow:
		return
	_availability_applied = true
	glow = on
	(_body.material_override as StandardMaterial3D).albedo_color = GOLD if on else Color("575757")
	for mat in _print_materials:
		mat.set_shader_parameter("unavailable", 0.0 if on else 1.0)


func touch_distance(world_pos: Vector3) -> float:
	## World-space distance to this card's oriented box, rather than to its centre. This makes the face under a pinch
	## win when the generous headset reach overlaps adjacent cards.
	var p := to_local(world_pos)
	var nearest := Vector3(
		clampf(p.x, -W / 2.0, W / 2.0),
		clampf(p.y, -H / 2.0, H / 2.0),
		clampf(p.z, -T / 2.0, T / 2.0))
	return world_pos.distance_to(to_global(nearest))


func lift(eye: Vector3) -> void:
	## Pick it up: turn the face toward `eye` (a world position) and grow a little.
	lifted = true
	_kill_tween()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector3.ONE * LIFT_SCALE, 0.15)


func face_toward(eye: Vector3) -> void:
	## Called every frame while held: keep the front toward the player's eyes.
	var to_eye := eye - global_position
	if to_eye.length() < 0.01:
		return
	look_at(global_position - to_eye, Vector3.UP)  # the face is on +Z; look_at points -Z, so aim away from the eye


func release_to_home(duration := 0.25) -> void:
	lifted = false
	_kill_tween()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "transform", home, duration)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
