class_name GhostHand
extends Node3D
## A faint golden hand that plays a gesture once or twice over something, to show how a quest is done
## (the user, 2026-11-11: "Maren asks, a ghost hand shows"). Made of a palm and two fingertips that close into a
## pinch. STAND-IN shapes (primitives), palette colours only. It frees itself after PLAYS runs.
##   GhostHand.carry(parent, from, to)  pinch at `from`, move to `to`, let go
##   GhostHand.hover(parent, at)        an open hand resting over `at`, pulsing
##   GhostHand.tap(parent, at)          a fingertip dipping onto `at`
## Positions are in the parent's space.

const GOLD := Color("FFD45A")  # fire_yellow
const PLAYS := 3

var _thumb: MeshInstance3D
var _index: MeshInstance3D
var _mat: StandardMaterial3D


static func carry(parent: Node3D, from: Vector3, to: Vector3) -> GhostHand:
	var g := _make(parent)
	g.position = from + Vector3(0, 0.03, 0)
	var tw := g.create_tween().set_loops(PLAYS)
	tw.tween_callback(g._open.bind(true))
	tw.tween_property(g, "position", from, 0.5).from(from + Vector3(0, 0.03, 0)).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(g._open.bind(false))
	tw.tween_interval(0.3)
	tw.tween_property(g, "position", to, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(g._open.bind(true))
	tw.tween_interval(0.6)
	tw.finished.connect(g.queue_free)
	return g


static func hover(parent: Node3D, at: Vector3) -> GhostHand:
	var g := _make(parent)
	g.position = at
	g._open(true)
	var tw := g.create_tween().set_loops(PLAYS * 2)
	tw.tween_property(g, "scale", Vector3.ONE * 1.25, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(g, "scale", Vector3.ONE, 0.7).set_trans(Tween.TRANS_SINE)
	tw.finished.connect(g.queue_free)
	return g


static func tap(parent: Node3D, at: Vector3) -> GhostHand:
	var g := _make(parent)
	g.position = at + Vector3(0, 0.03, 0)
	g._open(false)
	var tw := g.create_tween().set_loops(PLAYS * 2)
	tw.tween_property(g, "position", at, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(g, "position", at + Vector3(0, 0.03, 0), 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.3)
	tw.finished.connect(g.queue_free)
	return g


static func _make(parent: Node3D) -> GhostHand:
	var g := GhostHand.new()
	g.name = "GhostHand"
	parent.add_child(g)
	# ew_ui_ghost_hand_v02: a gold glove in a pinch, origin = the pinch point; parts thumb, index, fingers (rotate about Z)
	var model: Node3D = load("res://assets/ui/ew_ui_ghost_hand_v02.glb").instantiate()
	g.add_child(model)
	for n in ModelUtil.walk(model):
		if n is MeshInstance3D:
			var src := (n as MeshInstance3D).get_active_material(0)
			var m: StandardMaterial3D = src.duplicate() if src is StandardMaterial3D else ModelUtil.flat_material(GOLD)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(m.albedo_color, 0.55)
			m.no_depth_test = true
			(n as MeshInstance3D).material_override = m
	var parts := ModelUtil.parts(model)
	g._thumb = parts.get("thumb")
	g._index = parts.get("index")
	return g


func _open(open: bool) -> void:
	## Open: the fingertips apart. Closed: they meet in a pinch.
	## (the model is the closed pinch; opening swings the thumb out and the index slightly the other way)
	if _thumb == null or _index == null:
		return
	if not is_inside_tree():
		_thumb.rotation.z = -0.5 if open else 0.0
		_index.rotation.z = 0.15 if open else 0.0
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_thumb, "rotation:z", -0.5 if open else 0.0, 0.15)
	tw.tween_property(_index, "rotation:z", 0.15 if open else 0.0, 0.15)
