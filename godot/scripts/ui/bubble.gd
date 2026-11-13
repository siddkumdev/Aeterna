class_name Bubble
extends Node3D
## A small parchment speech bubble that pops over a head (or the shrine), faces the player, and shrinks away.
## Palette: wall_cream parchment, shell_gold edge, ink text. Billboard, unshaded, so it reads in any light.

const PARCHMENT := Color("F4E4B8")
const EDGE := Color("A87A1C")
const INK := Color("111C30")
const WIDTH := 0.16  # m; compact enough for the village view while still readable at seated VR distance
const FONT_SIZE := 42
const PIXEL_SIZE := 0.00036
const ACTIVE_GROUP := "active_speech_bubble"

var label: Label3D
var text := ""


static func say(parent: Node3D, at: Vector3, line: String, seconds := 4.5, colour := INK) -> Bubble:
	## Puts one bubble over `parent`. Speech is globally exclusive so villagers cannot cover each other.
	var tree := parent.get_tree()
	if tree:
		for old in tree.get_nodes_in_group(ACTIVE_GROUP):
			old.remove_from_group(ACTIVE_GROUP)
			old.name = "BubbleOld"
			old.queue_free()
	var b := Bubble.new()
	b.name = "Bubble"
	b.add_to_group(ACTIVE_GROUP)
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
	var chars_per_line := 16.0
	var lines := ceili(float(line.length()) / chars_per_line) + 1  # allow for word-wrap gaps
	var line_height := FONT_SIZE * PIXEL_SIZE * 1.12
	var h := 0.01 + lines * line_height
	position.y += (lines - 2) * line_height * 0.45  # taller boxes sit higher, keeping their lower edge near the speaker
	var edge := MeshInstance3D.new()
	var eq := QuadMesh.new()
	eq.size = Vector2(WIDTH + 0.008, h + 0.008)
	edge.mesh = eq
	edge.material_override = _mat(EDGE, 0)
	add_child(edge)
	var paper := MeshInstance3D.new()
	var pq := QuadMesh.new()
	pq.size = Vector2(WIDTH, h)
	paper.mesh = pq
	paper.material_override = _mat(PARCHMENT, 1)
	paper.position.z = 0.0003
	add_child(paper)
	label = Label3D.new()
	label.text = line
	label.font_size = FONT_SIZE
	label.pixel_size = PIXEL_SIZE
	label.width = (WIDTH - 0.02) / label.pixel_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = colour
	label.outline_size = 0
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	# A quest mote, roof edge, or other tiny foreground mesh used to punch apparent "missing glyphs" out of the text.
	# The parchment is world-space UI, so keep the whole bubble together and readable above scene geometry.
	label.no_depth_test = true
	label.render_priority = 2
	label.position.z = 0.0007
	add_child(label)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		var to := cam.global_position - global_position
		to.y = 0.0
		if to.length() > 0.001:
			look_at(global_position - to, Vector3.UP)  # the face is on +Z: aim -Z away from the viewer


func _mat(c: Color, priority: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	m.render_priority = priority
	return m
