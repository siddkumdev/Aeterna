class_name Bubble
extends Node3D
## A small parchment speech bubble that pops over a head (or the shrine), faces the player, and shrinks away.
## Palette: wall_cream parchment, shell_gold edge, ink text. Billboard, unshaded, so it reads in any light.

const PARCHMENT := Color("F4E4B8")
const EDGE := Color("A87A1C")
const INK := Color("111C30")
const WIDTH := 0.2  # m

var label: Label3D
var text := ""


static func say(parent: Node3D, at: Vector3, line: String, seconds := 4.5, colour := INK) -> Bubble:
	## Puts a bubble on `parent` at local position `at`, replacing one already there.
	var old := parent.get_node_or_null("Bubble")
	if old:
		old.queue_free()
		old.name = "BubbleOld"
	var b := Bubble.new()
	b.name = "Bubble"
	b.position = at
	parent.add_child(b)
	b.set_text(line, colour)
	b.scale = Vector3.ZERO
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(seconds)
	tw.tween_property(b, "scale", Vector3.ZERO, 0.2)
	tw.tween_callback(b.queue_free)
	return b


func set_text(line: String, colour := INK) -> void:
	text = line
	var lines := ceili(float(line.length()) / 17.0) + 1  # ~19 characters fit a line; word wrapping wastes some, so plan a spare line
	var h := 0.012 + lines * 0.021  # one line of 44 px text at 0.00042 m/px is ~0.022 m tall
	position.y += (lines - 2) * 0.01  # taller boxes sit a little higher, so the foot stays where it was
	var edge := MeshInstance3D.new()
	var eq := QuadMesh.new()
	eq.size = Vector2(WIDTH + 0.008, h + 0.008)
	edge.mesh = eq
	edge.material_override = _mat(EDGE)
	add_child(edge)
	var paper := MeshInstance3D.new()
	var pq := QuadMesh.new()
	pq.size = Vector2(WIDTH, h)
	paper.mesh = pq
	paper.material_override = _mat(PARCHMENT)
	paper.position.z = 0.0003
	add_child(paper)
	label = Label3D.new()
	label.text = line
	label.font_size = 44
	label.pixel_size = 0.00042
	label.width = (WIDTH - 0.02) / label.pixel_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = colour
	label.outline_size = 0
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = false
	label.position.z = 0.0007
	add_child(label)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		var to := cam.global_position - global_position
		to.y = 0.0
		if to.length() > 0.001:
			look_at(global_position - to, Vector3.UP)  # the face is on +Z: aim -Z away from the viewer


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
