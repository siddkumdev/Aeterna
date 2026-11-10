class_name CardFace
extends Control
## The printed face of a card, drawn with plain Control drawing (no external art, no third-party font):
## parchment, a gilded double border with knotwork corners, a name banner, an art window, a wax cost seal, four stat
## boxes, a text line and an italic-style flavour line. Rendered once into a SubViewport by Card3D.
## Colours are palette.json: wall_cream, wood_dark, wood_mid, wood_light, shell_gold, rarity_gold, fire_red, ink.

const SIZE := Vector2(504, 704)
const ART_SIZE := Vector2(392, 200)  # the art window inside the frame
const PARCHMENT := Color("F4E4B8")  # wall_cream
const PARCH_SHADE := Color("E8D29A")  # a touch darker than wall_cream for the inner panel
const INK := Color("111C30")  # ink
const GOLD := Color("E8B83A")  # shell_gold
const GOLD_DARK := Color("A87A1C")
const OAK := Color("5B2920")  # wood_dark
const OAK_LIGHT := Color("9A6538")  # wood_mid
const EMBER := Color("E8452C")  # fire_red
const FAMILY := {"oak": Color("5B2920"), "ember": Color("8E2A1A"), "ivory": Color("6B4228")}  # ivory = hair_brown, dark enough for gold text
const GREEN := Color("6FAE4A")  # heal green, for the roots emblem (never blue: blue is Foresight only)
const STONE := Color("8C9096")  # stone

var data: Dictionary = {}
var art: Texture2D  # optional: a rendered portrait of the model for the art window
var back := false


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE


func _draw() -> void:
	if back:
		_draw_back()
		return
	var fam: Color = FAMILY.get(data.get("family", "oak"), OAK)
	# base + outer gilt border + inner border
	draw_rect(Rect2(Vector2.ZERO, SIZE), fam)
	draw_rect(Rect2(10, 10, SIZE.x - 20, SIZE.y - 20), GOLD_DARK)
	draw_rect(Rect2(14, 14, SIZE.x - 28, SIZE.y - 28), GOLD)
	draw_rect(Rect2(22, 22, SIZE.x - 44, SIZE.y - 44), PARCHMENT)
	_corner_knots()
	# name banner
	var banner := Rect2(46, 40, SIZE.x - 92, 64)
	draw_rect(banner, fam)
	draw_rect(banner.grow(-4), fam.lightened(0.12))
	_text_center(String(data.get("title", "")), Vector2(SIZE.x / 2.0, 88), 40, GOLD, SIZE.x - 130)
	# art window (ART_SIZE: Card3D renders the portrait at exactly this size)
	var win := Rect2(56, 116, ART_SIZE.x, ART_SIZE.y)
	draw_rect(win.grow(5), GOLD_DARK)
	draw_rect(win, PARCH_SHADE)
	if art:
		draw_texture_rect(art, win, false)
	else:
		_art_fallback(win)
	# wax cost seal on the art window corner
	_seal(Vector2(win.position.x + 40, win.position.y + 42), String(data.get("seal", "")))
	# stat boxes (2 x 2)
	var stats: Array = data.get("stats", [])
	for i in range(mini(4, stats.size())):
		var lab: String = stats[i][0]
		if lab == "":
			continue
		var bx := Rect2(56 + (i % 2) * 200, 328 + (i / 2) * 72, 192, 64)
		draw_rect(bx, GOLD_DARK)
		draw_rect(bx.grow(-3), PARCH_SHADE)
		_text_left(lab.to_upper(), bx.position + Vector2(12, 24), 21, OAK_LIGHT)
		_text_fit(String(stats[i][1]), bx.position + Vector2(12, 55), 33, INK, bx.size.x - 24.0)
	# description + flavour (long ability text drops to a smaller size so it still fits)
	var txt := String(data.get("text", ""))
	_wrap(txt, Rect2(52, 476, SIZE.x - 104, 112), 26 if txt.length() <= 72 else 22, INK)
	var fl := String(data.get("flavour", ""))
	if fl != "":
		draw_line(Vector2(120, 592), Vector2(SIZE.x - 120, 592), GOLD_DARK, 2.0)
		_wrap("\"%s\"" % fl, Rect2(52, 598, SIZE.x - 104, 84), 21, OAK_LIGHT)


func _draw_back() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), OAK)
	draw_rect(Rect2(14, 14, SIZE.x - 28, SIZE.y - 28), GOLD)
	draw_rect(Rect2(22, 22, SIZE.x - 44, SIZE.y - 44), OAK)
	var c := SIZE / 2.0
	for r in [150.0, 110.0, 70.0, 34.0]:  # a small sun: the shrine sigil (palette ember colours)
		draw_circle(c, r, [GOLD, EMBER, Color("F6A45D"), Color("FFD45A")][[150.0, 110.0, 70.0, 34.0].find(r)])
	for i in 12:
		var a := TAU * i / 12.0
		draw_line(c + Vector2(cos(a), sin(a)) * 160.0, c + Vector2(cos(a), sin(a)) * 205.0, GOLD, 6.0)


func _corner_knots() -> void:
	for p in [Vector2(40, 130), Vector2(SIZE.x - 40, 130), Vector2(40, SIZE.y - 40), Vector2(SIZE.x - 40, SIZE.y - 40)]:
		draw_circle(p, 9, GOLD_DARK)
		draw_circle(p, 5, GOLD)


func _seal(at: Vector2, label: String) -> void:
	draw_circle(at, 34, Color("7A2318"))
	draw_circle(at, 29, EMBER)
	draw_arc(at, 29, 0, TAU, 32, Color("F6A45D"), 2.0)
	_text_center(label, at + Vector2(0, 11), 30 if label.length() <= 3 else 19, PARCHMENT, 56.0)


func _art_fallback(win: Rect2) -> void:
	## No model portrait (spells, abilities): a small painted emblem per card, drawn from palette colours only.
	var c := win.get_center()
	var glow := [Color("F6A45D"), Color("FFD45A"), Color("FFF1B8")]
	match String(data.get("id", "")):
		"boulder":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-70, 40), c + Vector2(-50, -30), c + Vector2(0, -62), c + Vector2(55, -35), c + Vector2(72, 30), c + Vector2(10, 58)]), STONE)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-50, -30), c + Vector2(0, -62), c + Vector2(20, -10), c + Vector2(-25, 5)]), STONE.lightened(0.25))
			draw_line(c + Vector2(-60, 70), c + Vector2(70, 70), OAK_LIGHT, 5.0)
		"storm":
			for p in [Vector2(-50, -10), Vector2(0, -34), Vector2(50, -10), Vector2(-20, 6), Vector2(25, 8)]:
				draw_circle(c + p, 42, Color("3C3442"))
			draw_polyline(PackedVector2Array([c + Vector2(8, 20), c + Vector2(-14, 52), c + Vector2(6, 52), c + Vector2(-16, 86)]), Color("FFD45A"), 9.0)
		"rage":
			for r in [88.0, 62.0, 36.0]:
				draw_arc(c, r, 0, TAU, 40, EMBER if r != 62.0 else glow[0], 10.0)
			draw_circle(c, 20, glow[1])
		"roots":
			for a in [-0.7, -0.25, 0.25, 0.7]:
				var pts := PackedVector2Array()
				for k in 7:
					pts.append(c + Vector2(sin(a * 3.0) * 70.0 * k / 6.0 + a * 30.0, 70.0 - k * 26.0 + sin(k + a) * 6.0))
				draw_polyline(pts, GREEN, 9.0)
			draw_circle(c + Vector2(0, 74), 16, OAK_LIGHT)
		"fire_orb":
			for r in [78.0, 54.0, 30.0]:
				draw_circle(c, r, glow[[78.0, 54.0, 30.0].find(r)])
		_:
			# ability: a gilded star-and-ring emblem
			draw_arc(c, 64.0, 0, TAU, 48, GOLD_DARK, 8.0)
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * 26.0, c + Vector2(cos(a), sin(a)) * 54.0, GOLD, 8.0)
			draw_circle(c, 20, GOLD)


func _font() -> Font:
	return ThemeDB.fallback_font


func _text_center(s: String, at: Vector2, px: int, col: Color, width := -1.0) -> void:
	var w := _font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var fs := px
	if width > 0.0 and w > width:
		fs = int(px * width / w)
		w = _font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font(), at - Vector2(w / 2.0, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _text_fit(s: String, at: Vector2, px: int, col: Color, width: float) -> void:
	## Left-aligned, shrunk to fit `width`.
	var fs := px
	var w := _font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if w > width:
		fs = maxi(14, int(px * width / w))
	draw_string(_font(), at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _text_left(s: String, at: Vector2, px: int, col: Color) -> void:
	draw_string(_font(), at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _wrap(s: String, r: Rect2, px: int, col: Color) -> void:
	draw_multiline_string(_font(), r.position + Vector2(0, px), s, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, px, 4, col)
