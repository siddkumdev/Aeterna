class_name TitleCard
extends Node3D
## Words that come up over the island for a moment and fade (the user, 2026-11-11: after the hourglass,
## "text with gilded edges ... time has been rewinded loop 2"). No box: gold lettering with a dark edge between two
## thin gilt rules. TitleCard.show_over(parent, at, "TIME HAS BEEN REWOUND", "Loop II") frees itself when done.

const SIZE := Vector2(1200, 360)
const W := 0.8  # m
const WIDE := Vector2(2100, 0)  # the wrapped card's width in px
const DENSITY := 1500.0  # px per metre (SIZE.x / W)
const EDGE := Color("1E140E")  # a soft ink edge so the words read over a bright sky
const CREAM := Color("F6E9CF")

var title := ""
var sub := ""
var title_px := 84
var _mat: StandardMaterial3D


class Face extends Control:
	var title := ""
	var sub := ""
	var px := 84
	var card := TitleCard.SIZE
	var lines: Array = []  # wrapped title lines (empty = the single-line layout)

	func _draw() -> void:
		## Plain lettering in Cinzel, warm cream with a soft dark edge, one thin rule under the title (the user,
		## 2026-11-14: the gilded frame did not make sense, so it is gone).
		var f := UiFonts.title()
		var mid := card.x / 2.0
		var y := 206.0
		var ty := 168.0 + (px - 84) * 0.3
		var sy := 270.0
		if not lines.is_empty():  # wrapped (tutorial hints): lines grow down, rule and subline follow
			var lh := px * 1.2
			ty = 20.0 + px
			y = ty + (lines.size() - 1) * lh + 34.0
			sy = y + 64.0
		for k in 24:  # a hairline that fades toward its ends
			var x0 := lerpf(mid - 300.0, mid, k / 24.0)
			var a := (k + 1) / 24.0
			draw_line(Vector2(x0, y), Vector2(x0 + 12.5, y), Color(TitleCard.CREAM, a * 0.8), 2.5)
			draw_line(Vector2(card.x - x0 - 12.5, y), Vector2(card.x - x0, y), Color(TitleCard.CREAM, a * 0.8), 2.5)
		if lines.is_empty():
			_line(f, title, ty, px, TitleCard.CREAM)
		else:
			for i in lines.size():
				_line(f, lines[i], ty + i * px * 1.2, px, TitleCard.CREAM)
		_line(UiFonts.italic(), sub, sy, 60, TitleCard.CREAM.darkened(0.08))

	func _line(f: Font, s: String, y: float, px: int, col: Color) -> void:
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var fs := px if w <= card.x - 120 else int(px * (card.x - 120) / w)
		w = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2((card.x - w) / 2.0, y)
		draw_string_outline(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(TitleCard.EDGE, 0.75))
		draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


static func wrap_lines(f: Font, s: String, px: int, max_w: float) -> Array:
	var out: Array = []
	var cur := ""
	for word in s.split(" "):
		var t: String = word if cur == "" else cur + " " + word
		if cur != "" and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > max_w:
			out.append(cur)
			cur = word
		else:
			cur = t
	out.append(cur)
	return out


static func show_over(parent: Node3D, at: Vector3, line: String, under := "", hold := 3.2, px := 84) -> TitleCard:
	var old := parent.get_node_or_null("TitleCard")
	if old:
		old.name = "TitleCardOld"
		old.queue_free()
	var t := TitleCard.new()
	t.name = "TitleCard"
	t.title = line
	t.sub = under
	t.title_px = px
	parent.add_child(t)
	t.position = at
	t._play(hold)
	return t


func _ready() -> void:
	## A long line at a modest size (the tutorial hints) gets a wider, taller card and wraps instead of shrinking; the
	## pixel density stays 1500 px per metre (the same as the 1200 px / 0.8 m card), so it is as sharp as before.
	var card := SIZE
	var w_m := W
	var lines: Array = []
	var f := UiFonts.title()
	if title_px <= 80 and f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x > SIZE.x - 120.0:
		card.x = WIDE.x
		w_m = WIDE.x / DENSITY
		lines = wrap_lines(f, title, title_px, card.x - 160.0)
		card.y = 20.0 + title_px + (lines.size() - 1) * title_px * 1.2 + 34.0 + 64.0 + 50.0
	var vp := SubViewport.new()
	vp.size = Vector2i(int(card.x), int(card.y))
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var face := Face.new()
	face.size = card
	face.card = card
	face.lines = lines
	face.title = title
	face.sub = sub
	face.px = title_px
	vp.add_child(face)
	var quad := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w_m, w_m * card.y / card.x)
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
	if hold < 0.0:
		return  # stays until dismiss()
	tw.tween_interval(hold)
	tw.tween_property(_mat, "albedo_color:a", 0.0, 0.8)
	tw.tween_callback(queue_free)


func dismiss() -> void:
	name = "TitleCardOld"
	var tw := create_tween()
	tw.tween_property(_mat, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(queue_free)
