## (no class_name: loaded with preload by game.gd, so it works before the editor has refreshed its class cache)
extends Node3D
## A small parchment slip pinned to the front lip of the card tray (Siddharth, 2026-11-17: quests were hard to follow).
## It shows the ACTIVE quest: its name, the next step, where it is, progress ticks, and a small seal for every other
## open quest. Touching it asks the game to make the asker's house glow. Styled like the ledger pages (their colours
## and fonts). Hangs below the lip, tilted up toward the player, so it never covers the cards.
##   set_data({name, step, where, ticks, ticks_done, others})   (rebuilt only when the data changed)

const W := 0.27
const H := 0.125
const TILT_DEG := -62.0
const MAX_TICKS := 6
const MAX_SEALS := 5
const NAME_PX := 0.00036  # m per font pixel: the name is about 1.7 cm tall, like the tray's toasts and seal numbers
const STEP_PX := 0.00033
const SMALL_PX := 0.00030

var _body: MeshInstance3D
var _name: Label3D
var _step: Label3D
var _where: Label3D
var _hint: Label3D
var _more: Label3D
var _count: Label3D
var _ticks: Array[MeshInstance3D] = []
var _seals: Array[MeshInstance3D] = []
var _tick_on: StandardMaterial3D
var _tick_off: StandardMaterial3D
var _sig := ""
var shown := {}  # what is drawn now (read by the tests)


func _ready() -> void:
	_build()


func _flat(col: Color) -> StandardMaterial3D:
	var m := ModelUtil.flat_material(col)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _label(px: float, font_size: int, col: Color, at: Vector3, bold := false) -> Label3D:
	var l := Label3D.new()
	l.font = UiFonts.title() if bold else UiFonts.text()
	l.font_size = font_size
	l.pixel_size = px
	l.modulate = col
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.position = at
	l.no_depth_test = false
	_body.add_child(l)
	return l


func _build() -> void:
	## The slip's pivot is its top edge, on the tray lip; the body hangs from it.
	rotation_degrees.x = TILT_DEG
	_body = MeshInstance3D.new()
	_body.name = "SlipBody"
	var b := BoxMesh.new()
	b.size = Vector3(W, H, 0.002)
	_body.mesh = b
	_body.material_override = _flat(LedgerPage.PARCHMENT)
	_body.position = Vector3(0, -H / 2.0, 0)
	add_child(_body)
	var edge := MeshInstance3D.new()  # a thin ember strip along the top: the pinned edge
	var eb := BoxMesh.new()
	eb.size = Vector3(W, 0.004, 0.0026)
	edge.mesh = eb
	edge.material_override = _flat(LedgerPage.EMBER)
	edge.position = Vector3(0, H / 2.0 - 0.002, 0)
	_body.add_child(edge)
	var z := 0.0016
	_name = _label(NAME_PX, 46, LedgerPage.OAK, Vector3(-W / 2.0 + 0.008, H / 2.0 - 0.02, z), true)
	_step = _label(STEP_PX, 40, LedgerPage.INK, Vector3(-W / 2.0 + 0.008, H / 2.0 - 0.038, z))
	_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_step.width = (W - 0.016) / STEP_PX
	_step.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_where = _label(STEP_PX, 40, LedgerPage.INK, Vector3(-W / 2.0 + 0.008, -H / 2.0 + 0.033, z))
	_hint = _label(STEP_PX, 40, LedgerPage.OAK, Vector3(-W / 2.0 + 0.008, -H / 2.0 + 0.0125, z))
	_hint.text = "touch: show me"
	_more = _label(SMALL_PX, 36, LedgerPage.OAK, Vector3(W / 2.0 - 0.011 - MAX_SEALS * 0.0125, -H / 2.0 + 0.0125, z))
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count = _label(SMALL_PX, 38, LedgerPage.OAK_LIGHT, Vector3(W / 2.0 - 0.008, H / 2.0 - 0.02, z))
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for l in [_name, _step, _where, _count, _hint, _more]:
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER if l != _step else VERTICAL_ALIGNMENT_TOP
	_tick_on = _flat(LedgerPage.GREEN)
	_tick_off = _flat(LedgerPage.PARCH_SHADE)
	var ring_mat := _flat(Color(0.36, 0.24, 0.15))  # the ledger's ring (GOLD_DARK) round each tick
	var disc := CylinderMesh.new()
	disc.top_radius = 0.0042
	disc.bottom_radius = 0.0042
	disc.height = 0.0012
	disc.radial_segments = 12
	var ring := CylinderMesh.new()
	ring.top_radius = 0.0058
	ring.bottom_radius = 0.0058
	ring.height = 0.0012
	ring.radial_segments = 12
	for i in MAX_TICKS:
		var rg := MeshInstance3D.new()
		rg.mesh = ring
		rg.material_override = ring_mat
		rg.rotation_degrees.x = 90.0
		rg.visible = false
		_body.add_child(rg)
		var t := MeshInstance3D.new()
		t.mesh = disc
		t.position = Vector3(0, 0.0004, 0)  # (cylinder axis is local Y: this lifts it off the ring)
		rg.add_child(t)
		_ticks.append(rg)
	var seal := CylinderMesh.new()
	seal.top_radius = 0.005
	seal.bottom_radius = 0.005
	seal.height = 0.0012
	seal.radial_segments = 12
	var wax := _flat(Color("9C3420"))  # ember wax
	for i in MAX_SEALS:
		var s := MeshInstance3D.new()
		s.mesh = seal
		s.material_override = wax
		s.rotation_degrees.x = 90.0
		s.position = Vector3(W / 2.0 - 0.011 - i * 0.0125, -H / 2.0 + 0.0125, z)
		s.visible = false
		_body.add_child(s)
		_seals.append(s)


func _fit(l: Label3D, text: String, px: float, max_w: float) -> void:
	## Sets the text and shrinks the pixel size if it would be wider than max_w metres.
	l.text = text
	var w: float = l.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size).x * px
	l.pixel_size = px if w <= max_w or w <= 0.0 else px * max_w / w


func set_data(d: Dictionary) -> void:
	## d: name, step, where (strings), ticks / ticks_done (ints), others (int, how many other open quests).
	var sig := "%s|%s|%s|%d|%d|%d" % [d.get("name", ""), d.get("step", ""), d.get("where", ""), d.get("ticks", 0), d.get("ticks_done", 0), d.get("others", 0)]
	if sig == _sig:
		return
	_sig = sig
	shown = d.duplicate()
	if _body == null:
		_build()
	var n: int = mini(int(d.get("ticks", 0)), MAX_TICKS)
	var got: int = int(d.get("ticks_done", 0))
	_fit(_name, String(d.get("name", "")), NAME_PX, W - 0.016 - (0.05 + n * 0.0125 if n > 0 else 0.0))
	_step.text = String(d.get("step", ""))
	_fit(_where, String(d.get("where", "")), STEP_PX, W - 0.016)
	_more.text = "also open" if int(d.get("others", 0)) > 0 else ""
	_count.text = "%d/%d" % [got, n] if n > 0 else ""
	for i in MAX_TICKS:
		var t := _ticks[i]
		t.visible = i < n
		if i < n:
			(t.get_child(0) as MeshInstance3D).material_override = _tick_on if i < got else _tick_off
			t.position = Vector3(W / 2.0 - 0.036 - (n - 1 - i) * 0.0125, H / 2.0 - 0.02, 0.0016)
	for i in MAX_SEALS:
		_seals[i].visible = i < int(d.get("others", 0))


func _local(world: Vector3) -> Vector3:
	return _body.global_transform.affine_inverse() * world


func hit_point(world: Vector3, reach: float) -> bool:
	## A fingertip on the slip (within `reach` of its face).
	if not is_visible_in_tree() or _body == null:
		return false
	var p := _local(world)
	var sc := maxf(_body.global_basis.x.length(), 0.01)
	return absf(p.z) <= reach / sc and absf(p.x) <= W / 2.0 and absf(p.y) <= H / 2.0


func hit_ray(origin: Vector3, dir: Vector3) -> bool:
	if not is_visible_in_tree() or _body == null:
		return false
	var inv := _body.global_transform.affine_inverse()
	var o := inv * origin
	var d := inv.basis * dir
	if absf(d.z) < 0.00001:
		return false
	var t := -o.z / d.z
	if t < 0.0:
		return false
	var p := o + d * t
	return absf(p.x) <= W / 2.0 and absf(p.y) <= H / 2.0
