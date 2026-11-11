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
	g._mat = ModelUtil.flat_material(Color(GOLD.r, GOLD.g, GOLD.b, 0.55), true)
	g._mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g._mat.no_depth_test = true
	g._ball(Vector3(0, 0.02, 0.012), Vector3(0.016, 0.02, 0.008))  # the palm, above and behind the fingertips
	g._thumb = g._ball(Vector3(-0.008, 0.004, 0), Vector3(0.006, 0.012, 0.006))
	g._index = g._ball(Vector3(0.008, 0.004, 0), Vector3(0.006, 0.014, 0.006))
	return g


func _ball(at: Vector3, size: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 10
	s.rings = 5
	m.mesh = s
	m.scale = size
	m.position = at
	m.material_override = _mat
	add_child(m)
	return m


func _open(open: bool) -> void:
	## Open: the fingertips apart. Closed: they meet in a pinch.
	var x := 0.008 if open else 0.0025
	_thumb.position.x = -x
	_index.position.x = x
