class_name Ledger
extends Node3D
## The god's ledger as a PHYSICAL BOOK (the user, 2026-11-11: "like a physical book you can turn the pages"): an oak-and-gold
## book lying open in the air, two pages at a time, with a leaf that really turns about the spine. Tap (or point and pinch at)
## the RIGHT page to turn forward, the LEFT page to turn back; , and . on the desktop. It opens by the left palm held up for a
## second in the headset, or L on the desktop (see Game.ledger_from_palm). It only shows; it changes no rule.

const PW := 0.16  # m, one page's width
const PH := PW * LedgerPage.SIZE.y / LedgerPage.SIZE.x
const W := PW * 2.0  # the open spread's width
const H := PH
const SPREADS := LedgerPage.COUNT / 2
const REFRESH := 0.5  # s between redraws of the two visible pages
const TURN_TIME := 0.5  # s a leaf takes to turn
const SPINE_DEADZONE := 0.018  # m either side of the spine ignored so taps near the crease do not flip direction
const TURN_COOLDOWN := 0.22  # s after a leaf lands before another turn is accepted

var game  # Game
var open := false
var spread := 0  # 0 .. SPREADS-1: pages (2 * spread, 2 * spread + 1) are showing
var page: int:  # the left page's number (what the earlier tab version called the page)
	get:
		return spread * 2

var _book: Node3D
var _faces := {}  # "left" "right" "leaf_front" "leaf_back" -> {"vp": SubViewport, "page": LedgerPage, "mi": MeshInstance3D}
var _leaf: Node3D
var _since := 0.0
var _tween: Tween
var _turning := false
var _turn_cooldown := 0.0


func _ready() -> void:
	_book = Node3D.new()
	_book.name = "Book"
	add_child(_book)
	_box("cover_gold", Vector3(W + 0.020, PH + 0.020, 0.003), Vector3(0, 0, -0.0075), Color("E8B83A"), 18)
	_box("cover_oak", Vector3(W + 0.012, PH + 0.012, 0.004), Vector3(0, 0, -0.0045), Color("5B2920"), 19)
	_box("spine", Vector3(0.010, PH + 0.014, 0.009), Vector3(0, 0, -0.0010), Color("3F1B15"), 19)
	_box("pages_l", Vector3(PW - 0.002, PH - 0.002, 0.005), Vector3(-PW / 2.0, 0, -0.0020), Color("E8D29A"), 20)
	_box("pages_r", Vector3(PW - 0.002, PH - 0.002, 0.005), Vector3(PW / 2.0, 0, -0.0020), Color("E8D29A"), 20)
	_face("left", Vector3(-PW / 2.0, 0, 0.0008), _book, 21)
	_face("right", Vector3(PW / 2.0, 0, 0.0008), _book, 21)
	_leaf = Node3D.new()
	_leaf.name = "Leaf"
	_leaf.visible = false
	_book.add_child(_leaf)
	_face("leaf_front", Vector3(PW / 2.0, 0, 0.0016), _leaf, 22)
	_face("leaf_back", Vector3(PW / 2.0, 0, -0.0016), _leaf, 22)
	_faces["leaf_back"]["mi"].rotation.y = PI  # faces away until the leaf has turned over
	visible = false
	scale = Vector3.ONE * 0.01


func _mat(col: Color, prio: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.no_depth_test = true  # always readable, like the other panels
	m.render_priority = prio
	return m


func _box(nm: String, size: Vector3, at: Vector3, col: Color, prio: int) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(col, prio)
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_book.add_child(mi)


func _face(key: String, at: Vector3, parent: Node3D, prio: int) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(int(LedgerPage.SIZE.x), int(LedgerPage.SIZE.y))
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	var pg := LedgerPage.new()
	vp.add_child(pg)
	var mi := MeshInstance3D.new()
	mi.name = key
	var q := QuadMesh.new()
	q.size = Vector2(PW, PH)
	mi.mesh = q
	var m := _mat(Color.WHITE, prio)
	m.albedo_texture = vp.get_texture()
	m.cull_mode = BaseMaterial3D.CULL_BACK
	mi.material_override = m
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	_faces[key] = {"vp": vp, "page": pg, "mi": mi}


func _draw_face(key: String, page_no: int) -> void:
	var f: Dictionary = _faces[key]
	var pg: LedgerPage = f["page"]
	if game:
		pg.data = game.ledger_data()
	pg.page = clampi(page_no, 0, LedgerPage.COUNT - 1)
	pg.visible = page_no >= 0 and page_no < LedgerPage.COUNT
	pg.queue_redraw()
	(f["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE


func set_open(on: bool) -> void:
	if on == open:
		return
	open = on
	if game:
		game.snd("menu_open")
	if _tween:
		_tween.kill()
	_turning = false
	_turn_cooldown = 0.0
	_leaf.visible = false
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


func turn(by: int) -> bool:
	## Turn one leaf forward (+1) or back (-1). False at the first or last spread, or while a leaf is still turning / cooling down.
	var to := spread + (1 if by > 0 else -1)
	if _turning or (open and is_inside_tree() and _turn_cooldown > 0.0) or to < 0 or to >= SPREADS:
		return false
	var old := spread
	spread = to
	if game:
		game.snd("pinch")
	if not open or not is_inside_tree():
		redraw()
		return true
	_turning = true
	_since = 0.0
	if to > old:  # forward: the old right page lifts and turns over onto the left
		_draw_face("leaf_front", old * 2 + 1)
		_draw_face("leaf_back", to * 2)
		_draw_face("right", to * 2 + 1)
		_place_leaf(PW / 2.0, 0.0)
	else:  # back: the old left page lifts and turns over onto the right
		_draw_face("leaf_front", old * 2)
		_draw_face("leaf_back", to * 2 + 1)
		_draw_face("left", to * 2)
		_place_leaf(-PW / 2.0, 0.0)
	_leaf.visible = true
	_leaf.rotation = Vector3.ZERO
	var angle := -PI if to > old else PI
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(k: float):
		_leaf.rotation.y = angle * k
		_leaf.position.z = sin(k * PI) * 0.02, 0.0, 1.0, TURN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_land)
	return true


func _place_leaf(x: float, _z: float) -> void:
	for k in ["leaf_front", "leaf_back"]:
		(_faces[k]["mi"] as Node3D).position.x = x


func _land() -> void:
	_turning = false
	_turn_cooldown = TURN_COOLDOWN
	_leaf.visible = false
	_leaf.position.z = 0.0
	redraw()


func set_page(i: int) -> void:
	var s := clampi(i / 2, 0, SPREADS - 1)
	if s == spread or _turning:
		return
	spread = s
	redraw()


func redraw() -> void:
	_since = 0.0
	_draw_face("left", spread * 2)
	_draw_face("right", spread * 2 + 1)


func _process(delta: float) -> void:
	if _turn_cooldown > 0.0:
		_turn_cooldown = maxf(0.0, _turn_cooldown - delta)
	if not open or _turning:
		return
	_since += delta
	if _since >= REFRESH:
		redraw()


func _local(world: Vector3) -> Vector3:
	return _book.global_transform.affine_inverse() * world


func _side(p: Vector3) -> int:
	if absf(p.x) < SPINE_DEADZONE or absf(p.x) > W / 2.0 + 0.01 or absf(p.y) > H / 2.0 + 0.01:
		return 0
	return -1 if p.x < 0.0 else 1


func near_open_book(world: Vector3, reach: float) -> bool:
	if not open:
		return false
	var p := _local(world)
	return absf(p.z) <= reach / maxf(scale.x, 0.01) and absf(p.x) <= W / 2.0 + 0.02 and absf(p.y) <= H / 2.0 + 0.02


func page_hit_ray(origin: Vector3, dir: Vector3) -> int:
	## Which page a ray lands on: -1 the left page, +1 the right, 0 neither (or the book is shut).
	if not open:
		return 0
	var o := _local(origin)
	var d := _book.global_transform.affine_inverse().basis * dir
	if absf(d.z) < 0.00001:
		return 0
	var t := -o.z / d.z
	if t < 0.0:
		return 0
	return _side(o + d * t)


func page_hit_point(world: Vector3, reach: float) -> int:
	## Which page a fingertip is on (within `reach` of the book's face), -1 / +1 / 0.
	if not open:
		return 0
	var p := _local(world)
	if absf(p.z) > reach / maxf(scale.x, 0.01):
		return 0
	return _side(p)


func _on_quit_button(p: Vector3) -> bool:
	return p.x >= 0.025 and p.x <= PW - 0.025 and p.y >= -PH / 2.0 + 0.012 and p.y <= -PH / 2.0 + 0.044


func quit_hit_point(world: Vector3, reach: float) -> bool:
	## True when touching the Quit Game seal at the bottom of the final page (spread == SPREADS - 1).
	if not open or _turning or spread != SPREADS - 1:
		return false
	var p := _local(world)
	return absf(p.z) <= reach / maxf(scale.x, 0.01) and _on_quit_button(p)


func quit_hit_ray(origin: Vector3, dir: Vector3) -> bool:
	## True when a pointer ray hits the Quit Game seal on the final page.
	if not open or _turning or spread != SPREADS - 1:
		return false
	var o := _local(origin)
	var d := _book.global_transform.affine_inverse().basis * dir
	if absf(d.z) < 0.00001:
		return false
	var t := -o.z / d.z
	if t < 0.0:
		return false
	return _on_quit_button(o + d * t)
