class_name CardTray
extends Node3D
## A carved wooden tray at the table edge with a fan of cards on it. By day it holds the tower cards, at night the
## spell cards (set_cards swaps them). The tray only owns the cards and their resting places; game.gd owns what
## happens when one is picked up and dropped.
## Layout: cards stand slightly tilted back in a shallow arc, front toward the player (who sits on +Z).

const CARD_SPACING := 0.07
const ENDS := 0.165  # room at each end of the tray for the compass, faith seal, hourglass and crystal lens
const FAN_ARC := 0.06  # radians of tilt per card away from the middle
const HANDLE_OUT := 0.027  # m the brass handle rails stand out past each end of the base
const OAK := Color("9A6538")  # wood_mid
const OAK_DARK := Color("5B2920")  # wood_dark

var cards: Array[Card3D] = []
var _base: MeshInstance3D
var _face_shader: Shader


static func make_face_shader() -> Shader:
	var s := Shader.new()
	s.code = Card3D.FACE_SHADER
	return s


func _ready() -> void:
	_build_base(0.5)


func _build_base(width: float) -> void:
	if _base:
		_base.queue_free()
	_base = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(width, 0.012, 0.11)
	_base.mesh = b
	_base.material_override = ModelUtil.flat_material(OAK)
	_base.position = Vector3(0, -0.006, 0)
	add_child(_base)
	var rim := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(width + 0.012, 0.01, 0.008)
	rim.mesh = rb
	rim.material_override = ModelUtil.flat_material(OAK_DARK)
	rim.position = Vector3(0, 0.004, 0.05)
	_base.add_child(rim)
	# Grab handles at both ends, like the island's rim handles (sykeriin, 2026-11-17): wood posts and a brass rail.
	var wood := ModelUtil.flat_material(OAK_DARK)
	var brass := ModelUtil.flat_material(Color8(0xF2, 0xB6, 0x30))
	brass.emission_enabled = true
	brass.emission = Color8(0xF6, 0xA4, 0x5D)
	brass.emission_energy_multiplier = 0.18
	for sx in [-1.0, 1.0]:
		for sz in [-0.035, 0.035]:
			var post := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.03, 0.012, 0.012)
			post.mesh = pm
			post.material_override = wood
			post.position = Vector3(sx * (width / 2.0 + 0.012), 0.004, sz)
			_base.add_child(post)
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.014, 0.014, 0.09)
		rail.mesh = rm
		rail.material_override = brass
		rail.position = Vector3(sx * (width / 2.0 + HANDLE_OUT), 0.006, 0)
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_base.add_child(rail)


func set_cards(list: Array[Dictionary]) -> void:
	## Replace what is on the tray. Existing cards are freed.
	for c in cards:
		if is_instance_valid(c):
			c.queue_free()
	cards.clear()
	var n := list.size()
	_build_base(maxf(0.3, n * CARD_SPACING + ENDS * 2.0))
	if _face_shader == null:
		_face_shader = make_face_shader()
	for i in n:
		var card := Card3D.new()
		add_child(card)  # in the tree first: the portrait render needs get_tree()
		card.setup(list[i], _face_shader)
		var off := float(i) - (n - 1) / 2.0
		var t := Transform3D(Basis(Vector3.RIGHT, -0.9) * Basis(Vector3.UP, -off * FAN_ARC), Vector3(off * CARD_SPACING, 0.04, -abs(off) * 0.004))
		card.home = t
		card.transform = t
		cards.append(card)


func body_distance(world_pos: Vector3) -> float:
	## How far `world_pos` is from the tray's wooden base (0 on it): the part a pinch can take to move the whole tray.
	if _base == null or not is_instance_valid(_base):
		return INF
	var half: Vector3 = (_base.mesh as BoxMesh).size / 2.0
	half.x += HANDLE_OUT + 0.01  # the end handles count as the tray's body
	var l := to_local(world_pos) - _base.position
	var out := Vector3(maxf(absf(l.x) - half.x, 0.0), maxf(absf(l.y) - half.y, 0.0), maxf(absf(l.z) - half.z, 0.0))
	return out.length()


func card_near(world_pos: Vector3, reach: float) -> Card3D:
	## The unlifted card whose physical face is within `reach` of `world_pos` (a fingertip), nearest first.
	var best: Card3D = null
	var best_d := reach
	for c in cards:
		if c.lifted or not is_instance_valid(c):
			continue
		# Keep the established reach bubble so nearby wood remains grabbable; surface distance only decides which of
		# the overlapping eligible cards is actually under the pinch.
		if c.global_position.distance_to(world_pos) > reach:
			continue
		var d := c.touch_distance(world_pos)
		if d <= best_d:
			best_d = d
			best = c
	return best
