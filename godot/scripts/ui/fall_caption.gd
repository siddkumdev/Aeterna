extends Node3D
## The one caption style of the first-rewind cutscene (player-critic 2026-11-17): a parchment band, big lettering,
## the same size for every line, a small speaker name above the words. It stands in front of the island's player-side
## edge (never over the statue, the houses or Skotos) and faces the viewer. say(board, ...) replaces
## the previous caption.

const WIDTH := 0.74  # m
const TEXT_PX := 52
const NAME_PX := 30
const PIXEL := 0.0006  # m per font pixel: letters about 3.4 cm tall, readable at 60-80 cm in the headset
const PARCHMENT := Color("F4E4B8")
const EDGE := Color("5A3A24")
const INK := Color("111C30")
const BAND_AT := Vector3(0.0, 0.12, 0.64)  # board-local: in front of the player-side edge, clear of the village
const SHOWN_SCALE := 0.55  # stress test 2026-11-18: at full size the band sat 0.37 m from the eye and filled ~90 deg of view


static func say(board: Node3D, speaker: String, line: String, name_colour := Color("5A3A24"), seconds := 3.4) -> Node3D:
	for old in board.get_children():
		if str(old.name) == "FallCaption":
			old.name = "FallCaptionOld"
			old.queue_free()
	var c: Node3D = (load("res://scripts/ui/fall_caption.gd") as GDScript).new()
	c.name = "FallCaption"
	board.add_child(c)
	c.position = BAND_AT
	var cam := board.get_viewport().get_camera_3d() if board.is_inside_tree() else null
	if cam:  # face the viewer (a quad faces +Z, so aim -Z away from the camera)
		var here := c.global_position
		c.look_at(here + (here - cam.global_position), Vector3.UP)
	c._build(speaker, line, name_colour)
	c.scale = Vector3.ZERO
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector3.ONE * SHOWN_SCALE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(seconds)
	tw.tween_property(c, "scale", Vector3.ZERO, 0.2)
	tw.tween_callback(c.queue_free)
	return c


func _build(speaker: String, line: String, name_colour: Color) -> void:
	var rows := 4  # one fixed box for every line (player-critic: same size throughout)
	var line_h := TEXT_PX * PIXEL * 1.15
	var h := 0.05 + rows * line_h + (NAME_PX * PIXEL * 1.4 if speaker != "" else 0.0)
	var edge := MeshInstance3D.new()
	var eq := QuadMesh.new()
	eq.size = Vector2(WIDTH + 0.012, h + 0.012)
	edge.mesh = eq
	edge.material_override = _mat(EDGE, 0)
	add_child(edge)
	var paper := MeshInstance3D.new()
	var pq := QuadMesh.new()
	pq.size = Vector2(WIDTH, h)
	paper.mesh = pq
	paper.material_override = _mat(PARCHMENT, 1)
	paper.position.z = 0.0004
	add_child(paper)
	var top := h / 2.0 - 0.025
	if speaker != "":
		var n := _label(speaker.to_upper(), NAME_PX, name_colour)
		n.position = Vector3(0, top - NAME_PX * PIXEL * 0.5, 0.001)
		add_child(n)
		top -= NAME_PX * PIXEL * 1.4
	var t := _label(line, TEXT_PX, INK)
	t.width = int((WIDTH - 0.05) / PIXEL)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	t.position = Vector3(0, top, 0.001)
	add_child(t)


func _label(text: String, px: int, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = px
	l.pixel_size = PIXEL
	l.modulate = col
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.no_depth_test = true
	l.render_priority = 41
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _mat(col: Color, priority: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.no_depth_test = true
	m.render_priority = 39 + priority
	return m
