class_name Ledger
extends Node3D
## The god's ledger in the world: a gilded parchment panel that unfolds over the left palm when it is turned up
## (headset), or in front of the camera on L (desktop). Tabs along the top turn the page: poke one with a
## fingertip, point and pinch, or use , and . on the keyboard. It only shows; it changes no rule.

const W := 0.30  # m
const H := W * LedgerPage.SIZE.y / LedgerPage.SIZE.x
const REFRESH := 0.5  # s between redraws while open

var game  # Game
var open := false
var page := 0

var _vp: SubViewport
var _face: LedgerPage
var _quad: MeshInstance3D
var _since := 0.0
var _tween: Tween


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(int(LedgerPage.SIZE.x), int(LedgerPage.SIZE.y))
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_face = LedgerPage.new()
	_vp.add_child(_face)
	_quad = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(W, H)
	_quad.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = _vp.get_texture()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true  # always readable, like the other panels
	m.render_priority = 20
	_quad.material_override = m
	add_child(_quad)
	visible = false
	scale = Vector3.ONE * 0.01


func set_open(on: bool) -> void:
	if on == open:
		return
	open = on
	if game:
		game.snd("menu_open")
	if _tween:
		_tween.kill()
	if not is_inside_tree():
		visible = on
		scale = Vector3.ONE if on else Vector3.ONE * 0.01
		return
	_tween = create_tween()
	if on:
		visible = true
		redraw()
		_tween.tween_property(self, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.14)
		_tween.tween_callback(func(): visible = false)


func turn(by: int) -> void:
	set_page(posmod(page + by, LedgerPage.TABS.size()))


func set_page(i: int) -> void:
	if i == page or i < 0 or i >= LedgerPage.TABS.size():
		return
	page = i
	if game:
		game.snd("pinch")
	redraw()


func redraw() -> void:
	_since = 0.0
	if game:
		_face.data = game.ledger_data()
	_face.page = page
	_face.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _process(delta: float) -> void:
	if not open:
		return
	_since += delta
	if _since >= REFRESH:
		redraw()


func tab_at_ray(origin: Vector3, dir: Vector3) -> int:
	## Which tab a ray hits (-1: none; -2: the panel but no tab, so the press is still used up).
	if not open:
		return -1
	var inv := _quad.global_transform.affine_inverse()
	var o := inv * origin
	var d := inv.basis * dir
	if absf(d.z) < 0.00001:
		return -1
	var t := -o.z / d.z
	if t < 0.0:
		return -1
	return _tab_at_local(o + d * t)


func tab_at_point(world: Vector3, reach: float) -> int:
	## Which tab a fingertip is on (within `reach` of the panel's face).
	if not open:
		return -1
	var p := _quad.global_transform.affine_inverse() * world
	if absf(p.z) > reach / maxf(scale.x, 0.01):
		return -1
	return _tab_at_local(p)


func _tab_at_local(p: Vector3) -> int:
	if absf(p.x) > W / 2.0 or absf(p.y) > H / 2.0:
		return -1
	var px := Vector2((p.x / W + 0.5) * LedgerPage.SIZE.x, (0.5 - p.y / H) * LedgerPage.SIZE.y)
	for i in LedgerPage.TABS.size():
		if LedgerPage.tab_rect(i).grow(10).has_point(px):
			return i
	return -2
