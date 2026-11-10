class_name House
extends Node3D
## One village house on a 2 x 2 footprint. Grunts wear its HP down; at 0 it is shuttered (spec 2):
## each moving part tweens to its "<part>_broken" marker, lit windows go off, rubble appears.
## At dawn it heals GameConfig.DAWN_REPAIR HP (damage carries over); the hourglass rewind repairs it fully.

signal shuttered(house: House)

var index := 0
var cell := Vector2i.ZERO
var max_hp := GameConfig.HOUSE_HP  # raised by the Sturdy Homes card
var hp := GameConfig.HOUSE_HP
## Asked once when the house would be shuttered; returning true keeps it at 1 HP (Sturdy Homes, Legendary)
var hold_check: Callable
var on_hit: Callable  # called when the house takes damage (the game plays the sound)
var is_shuttered := false
var ward := 0.0  # damage still soaked up by Root Ward roots
var fx := false  # the game turns the effects on (chimney smoke, dust); logic-only games stay without them
var chimney_blocked := false  # a blocked-chimney request: no smoke until the rubble is out

var _smoke_at: Marker3D
var _dust_at: Marker3D
var _smoke_t := 0.0
var _hurt_t := 0.0

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
		if n is Marker3D and str(n.name).ends_with("smoke_anchor"):
			_smoke_at = n
		if n is Marker3D and str(n.name).ends_with("dust_anchor"):
			_dust_at = n
	_smoke_t = randf() * 3.0
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


func _process(delta: float) -> void:
	if not fx or is_shuttered:
		return
	_smoke_t -= delta
	if _smoke_t <= 0.0:
		_smoke_t = randf_range(2.6, 4.0)
		if not chimney_blocked and _smoke_at != null and VfxKit.active_bursts() <= VfxKit.MAX_BURSTS - 10:
			VfxKit.toon_smoke(get_parent(), _smoke_at.global_position, 0.026, 2.2)
	if hp < max_hp * 0.5:  # a badly hurt house smoulders
		_hurt_t -= delta
		if _hurt_t <= 0.0:
			_hurt_t = randf_range(0.9, 1.5)
			if _dust_at != null and VfxKit.active_bursts() <= VfxKit.MAX_BURSTS - 10:
				VfxKit.ink_puff(get_parent(), _dust_at.global_position, 0.03, 0.9)


func _break_fx() -> void:
	if fx and _dust_at != null and is_inside_tree():
		VfxKit.toon_dust(get_parent(), _dust_at.global_position, 0.09)
		VfxKit.burst(get_parent(), _dust_at.global_position, Color("7E6048"), Color("C2B49A"), 12, 0.07, 0.6, 0.006, -0.18, false)


func _repair_fx() -> void:
	## Dawn: the house puts itself back like a rewind, with a little dust and a sparkle.
	if fx and _dust_at != null and is_inside_tree():
		VfxKit.toon_dust(get_parent(), _dust_at.global_position, 0.05)
		VfxKit.burst(get_parent(), _dust_at.global_position + Vector3(0, 0.03, 0), VfxKit.FIRE_YELLOW, VfxKit.FIRE_ORANGE, 8, 0.05, 0.7, 0.005, 0.02)


func damage(amount: float) -> void:
	if is_shuttered:
		return
	if ward > 0.0:
		var soaked := minf(ward, amount)
		ward -= soaked
		amount -= soaked
		if amount <= 0.0:
			return
	hp = maxf(0.0, hp - amount)
	if on_hit.is_valid():
		on_hit.call()
	if hp <= 0.0 and hold_check.is_valid() and hold_check.call(self):
		hp = 1.0
	_update_bar()
	if hp <= 0.0:
		is_shuttered = true
		_apply(true, true)
		_break_fx()
		shuttered.emit(self)


func heal(amount: float) -> void:
	## Dawn repair: some HP back; a shuttered house that has HP again opens up.
	hp = minf(max_hp, hp + amount)
	_update_bar()
	if is_shuttered and hp > 0.0:
		is_shuttered = false
		_apply(false, true)
		_repair_fx()


func repair() -> void:
	hp = max_hp
	_update_bar()
	if is_shuttered:
		is_shuttered = false
		_apply(false, true)
		_repair_fx()


func _update_bar() -> void:
	var f := hp / max_hp
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
