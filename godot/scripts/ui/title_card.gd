class_name TitleCard
extends Node3D
## Gilded words that come up over the island for a moment and fade (the user, 2026-11-11: after the hourglass,
## "text with gilded edges ... time has been rewinded loop 2"). No box: gold lettering with a dark edge between two
## thin gilt rules. TitleCard.show_over(parent, at, "TIME HAS BEEN REWOUND", "Loop II") frees itself when done.

const SIZE := Vector2(1200, 360)
const W := 0.8  # m
const GOLD := Color("E8B83A")
const GOLD_LIGHT := Color("FFD45A")  # fire_yellow
const EDGE := Color("5B2920")  # wood_dark

var title := ""
var sub := ""
var _mat: StandardMaterial3D


class Face extends Control:
	var title := ""
	var sub := ""

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		var mid := TitleCard.SIZE.x / 2.0
		for y in [58.0, 302.0]:  # a double rule with a diamond at its middle, above and below
			draw_line(Vector2(140, y), Vector2(TitleCard.SIZE.x - 140, y), TitleCard.EDGE, 9.0)
			draw_line(Vector2(140, y), Vector2(TitleCard.SIZE.x - 140, y), TitleCard.GOLD, 5.0)
			draw_colored_polygon(PackedVector2Array([Vector2(mid - 22, y), Vector2(mid, y - 15), Vector2(mid + 22, y), Vector2(mid, y + 15)]), TitleCard.EDGE)
			draw_colored_polygon(PackedVector2Array([Vector2(mid - 16, y), Vector2(mid, y - 10), Vector2(mid + 16, y), Vector2(mid, y + 10)]), TitleCard.GOLD_LIGHT)
			for x in [140.0, TitleCard.SIZE.x - 140.0]:
				draw_circle(Vector2(x, y), 9, TitleCard.EDGE)
				draw_circle(Vector2(x, y), 6, TitleCard.GOLD_LIGHT)
		_line(f, title, 168, 84, TitleCard.GOLD_LIGHT)
		_line(f, sub, 262, 64, TitleCard.GOLD_LIGHT)

	func _line(f: Font, s: String, y: float, px: int, col: Color) -> void:
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var fs := px if w <= TitleCard.SIZE.x - 120 else int(px * (TitleCard.SIZE.x - 120) / w)
		w = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2((TitleCard.SIZE.x - w) / 2.0, y)
		draw_string_outline(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, TitleCard.EDGE)
		draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


static func show_over(parent: Node3D, at: Vector3, line: String, under := "", hold := 3.2) -> TitleCard:
	var old := parent.get_node_or_null("TitleCard")
	if old:
		old.name = "TitleCardOld"
		old.queue_free()
	var t := TitleCard.new()
	t.name = "TitleCard"
	t.title = line
	t.sub = under
	parent.add_child(t)
	t.position = at
	t._play(hold)
	return t


func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(int(SIZE.x), int(SIZE.y))
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var face := Face.new()
	face.size = SIZE
	face.title = title
	face.sub = sub
	vp.add_child(face)
	var quad := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(W, W * SIZE.y / SIZE.x)
	quad.mesh = q
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_texture = vp.get_texture()
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mat.no_depth_test = true
	_mat.render_priority = 30
	_mat.albedo_color = Color(1, 1, 1, 0)
	quad.material_override = _mat
	add_child(quad)


func _play(hold: float) -> void:
	scale = Vector3.ONE * 0.86
	var tw := create_tween()
	tw.tween_property(_mat, "albedo_color:a", 1.0, 0.5)
	tw.parallel().tween_property(self, "scale", Vector3.ONE, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(_mat, "albedo_color:a", 0.0, 0.8)
	tw.tween_callback(queue_free)
