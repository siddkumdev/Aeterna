class_name StoryPanel
extends Node3D
## A big parchment that floats over the island and shows lines of story: the opening narration and "The Tale". Same
## look as the speech bubbles (wall_cream paper, leather-brown edge, ink text), only larger. Faces the player.

const PARCHMENT := Color("F4E4B8")
const EDGE := Color("5A3A24")  # leather brown edge (no gilding, 2026-11-14)
const INK := Color("111C30")
const W := 0.46
const H := 0.20

var label: Label3D
var _quads: Array[QuadMesh] = []
var _fade := 0.0
var _target := 0.0


static func make(parent: Node3D, at: Vector3) -> StoryPanel:
	var p := StoryPanel.new()
	p.position = at
	parent.add_child(p)
	p._build()
	return p


func _build() -> void:
	for spec in [[Vector2(W + 0.012, H + 0.012), EDGE, 0.0], [Vector2(W, H), PARCHMENT, 0.0004]]:
		var m := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = spec[0]
		_quads.append(q)
		m.mesh = q
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = spec[1]
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.material_override = mat
		m.position.z = spec[2]
		add_child(m)
	label = Label3D.new()
	label.font_size = 52
	label.pixel_size = 0.00042
	label.width = (W - 0.04) / label.pixel_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = INK
	label.outline_size = 0
	label.position.z = 0.0008
	add_child(label)
	scale = Vector3.ZERO


func show_text(line: String) -> void:
	label.text = line
	var chars_per_line := 36.0  # at this width and size, with word wrapping
	var lines := ceili(float(line.length()) / chars_per_line) + line.count("\n") + 1
	var h := clampf(0.04 + lines * 0.026, 0.08, 0.5)
	_quads[0].size = Vector2(W + 0.012, h + 0.012)
	_quads[1].size = Vector2(W, h)
	_target = 1.0


func hide_panel() -> void:
	_target = 0.0


func _process(delta: float) -> void:
	_fade = move_toward(_fade, _target, delta * 3.0)
	scale = Vector3.ONE * smoothstep(0.0, 1.0, _fade)
	var cam := get_viewport().get_camera_3d()
	if cam and _fade > 0.0:
		var to := cam.global_position - global_position
		to.y = 0.0
		if to.length() > 0.001:
			look_at(global_position - to, Vector3.UP)
