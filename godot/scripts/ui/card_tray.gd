class_name CardTray
extends Node3D
## A carved wooden tray at the table edge with a fan of cards on it. By day it holds the tower cards, at night the
## spell cards (set_cards swaps them). The tray only owns the cards and their resting places; game.gd owns what
## happens when one is picked up and dropped.
## Layout: cards stand slightly tilted back in a shallow arc, front toward the player (who sits on +Z).

const CARD_SPACING := 0.07
const ENDS := 0.09  # room at each end of the tray for the faith seal and the small hourglass
const FAN_ARC := 0.06  # radians of tilt per card away from the middle
const OAK := Color("9A6538")  # wood_mid
const OAK_DARK := Color("5B2920")  # wood_dark

var cards: Array[Card3D] = []
var _base: MeshInstance3D


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


func set_cards(list: Array[Dictionary]) -> void:
	## Replace what is on the tray. Existing cards are freed.
	for c in cards:
		if is_instance_valid(c):
			c.queue_free()
	cards.clear()
	var n := list.size()
	_build_base(maxf(0.3, n * CARD_SPACING + ENDS * 2.0))
	for i in n:
		var card := Card3D.new()
		add_child(card)  # in the tree first: the portrait render needs get_tree()
		card.setup(list[i])
		var off := float(i) - (n - 1) / 2.0
		var t := Transform3D(Basis(Vector3.RIGHT, -0.9) * Basis(Vector3.UP, -off * FAN_ARC), Vector3(off * CARD_SPACING, 0.04, -abs(off) * 0.004))
		card.home = t
		card.transform = t
		cards.append(card)


func card_near(world_pos: Vector3, reach: float) -> Card3D:
	## The unlifted card whose centre is within `reach` of `world_pos` (a fingertip), nearest first.
	var best: Card3D = null
	var best_d := reach
	for c in cards:
		if c.lifted or not is_instance_valid(c):
			continue
		var d := c.global_position.distance_to(world_pos)
		if d <= best_d:
			best_d = d
			best = c
	return best
