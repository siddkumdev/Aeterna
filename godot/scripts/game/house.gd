class_name House
extends Node3D
## One village house on a 2 x 2 footprint. Grunts wear its HP down; at 0 it is shuttered (spec 2):
## each moving part tweens to its "<part>_broken" marker, lit windows go off, rubble appears.
## Repaired at dawn (slice: every house is repaired for free).

signal shuttered(house: House)

var index := 0
var cell := Vector2i.ZERO
var hp := GameConfig.HOUSE_HP
var is_shuttered := false

var _parts := {}  # part -> MeshInstance3D
var _home := {}  # part -> Transform3D (standing pose)
var _broken := {}  # part -> Transform3D (from the "_broken" pose markers)
var _bar_fill: MeshInstance3D
var _bar: Node3D

const BAR_W := 0.08


func setup(scene: PackedScene, house_index: int, top_left: Vector2i) -> void:
	index = house_index
	cell = top_left
	var model: Node3D = scene.instantiate()
	add_child(model)
	_parts = ModelUtil.parts(model)
	for p in _parts:
		_home[p] = _parts[p].transform
	for n in ModelUtil.walk(model):
		if n is Marker3D and n.is_in_group("ew_pose") and String(n.name).ends_with("_broken"):
			_broken[str(n.get_meta("ew_pose_of"))] = n.transform
	_build_bar(ModelUtil.bounds(model).end.y + 0.02)
	_apply(false, false)


func _build_bar(height: float) -> void:
	_bar = Node3D.new()
	_bar.position = Vector3(0, height, 0)
	add_child(_bar)
	var bg := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(BAR_W, 0.006, 0.002)
	bg.mesh = bm
	bg.material_override = ModelUtil.flat_material(Color8(0x2A, 0x22, 0x20), true)
	_bar.add_child(bg)
	_bar_fill = MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(BAR_W, 0.0045, 0.0025)
	_bar_fill.mesh = fm
	_bar_fill.material_override = ModelUtil.flat_material(Color8(0xE8, 0x9A, 0x3C), true)
	_bar.add_child(_bar_fill)
	_bar.visible = false


func damage(amount: float) -> void:
	if is_shuttered:
		return
	hp = maxf(0.0, hp - amount)
	_update_bar()
	if hp <= 0.0:
		is_shuttered = true
		_apply(true, true)
		shuttered.emit(self)


func repair() -> void:
	hp = GameConfig.HOUSE_HP
	_update_bar()
	if is_shuttered:
		is_shuttered = false
		_apply(false, true)


func _update_bar() -> void:
	var f := hp / GameConfig.HOUSE_HP
	_bar.visible = f < 1.0 and not is_shuttered
	_bar_fill.scale.x = maxf(f, 0.001)
	_bar_fill.position.x = -BAR_W * (1.0 - f) / 2.0
	# the bar faces the player whichever way the house is turned
	_bar.global_basis = Basis.IDENTITY if is_inside_tree() else _bar.basis


func _apply(broken: bool, animate: bool) -> void:
	var tw: Tween = create_tween().set_parallel() if animate and is_inside_tree() and not _parts.is_empty() else null
	for p in _parts:
		var node: MeshInstance3D = _parts[p]
		var target: Transform3D = _broken[p] if broken and _broken.has(p) else _home[p]
		if tw:
			tw.tween_property(node, "transform", target, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			node.transform = target
		if str(node.get_meta("ew_broken", "")) == "off":
			node.visible = not broken
		if node.get_meta("ew_starts_hidden", false):
			node.visible = broken
