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
const GOLD := Color("E8B83A")  # shell_gold

var data: Dictionary = {}
var home := Transform3D.IDENTITY  # where it rests in the tray (parent space)
var lifted := false
var glow := false

var _face_vp: SubViewport
var _face: CardFace
var _tween: Tween
var _body: MeshInstance3D


func setup(card: Dictionary) -> Card3D:
	data = card
	_build()
	return self


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
	var back_vp := SubViewport.new()
	back_vp.size = _face_vp.size
	back_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(back_vp)
	var back := CardFace.new()
	back.back = true
	back_vp.add_child(back)
	_add_quad(_face_vp, T / 2.0 + 0.0002, false)
	_add_quad(back_vp, -T / 2.0 - 0.0002, true)
	if DisplayServer.get_name() != "headless":
		_render_portrait()


func _add_quad(vp: SubViewport, z: float, flip: bool) -> void:
	var q := MeshInstance3D.new()
	var m := QuadMesh.new()
	m.size = Vector2(W - 0.002, H - 0.002)
	q.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = vp.get_texture()
	q.material_override = mat
	q.position.z = z
	if flip:
		q.rotation.y = PI
	add_child(q)


func _render_portrait() -> void:
	## Towers: a live portrait of the real model. Other kinds keep the face's own emblem.
	if data.get("kind", "") != "tower":
		return
	var path: String = GameConfig.TOWERS[data["id"]]["scene"]
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
		return
	_face.art = vp.get_texture()
	_face.queue_redraw()
	_face_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
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
	if on == glow:
		return
	glow = on
	(_body.material_override as StandardMaterial3D).albedo_color = GOLD if on else GOLD.darkened(0.25)


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
