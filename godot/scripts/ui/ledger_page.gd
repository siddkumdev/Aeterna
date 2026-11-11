class_name LedgerPage
extends Control
## One drawn page of the god's ledger (the user, 2026-11-11: stat screens to "pull up this info in one go").
## Our own look, the cards' family: oak, gilt edge, parchment, ember seals. Never blue (blue is Foresight's).
## `data` comes from Game.ledger_data(); `page` picks what is drawn. Rendered into a SubViewport by Ledger.

const SIZE := Vector2(1040, 720)
const TABS: Array[String] = ["The God", "The Village", "The Cards", "Quests"]
const TAB_Y := 96.0
const TAB_H := 54.0
const PARCHMENT := Color("F4E4B8")
const PARCH_SHADE := Color("E8D29A")
const INK := Color("111C30")
const GOLD := Color("E8B83A")
const GOLD_DARK := Color("A87A1C")
const OAK := Color("5B2920")
const OAK_LIGHT := Color("9A6538")
const EMBER := Color("E8452C")
const GREEN := Color("5D8548")  # leaf_green
const ROMAN: Array[String] = ["I", "II", "III", "IV", "V", "VI", "VII"]

var data: Dictionary = {}
var page := 0


func _init() -> void:
	size = SIZE
	custom_minimum_size = SIZE


static func tab_rect(i: int) -> Rect2:
	var w := (SIZE.x - 120.0) / TABS.size()
	return Rect2(60 + i * w, TAB_Y, w - 8, TAB_H)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), OAK)
	draw_rect(Rect2(10, 10, SIZE.x - 20, SIZE.y - 20), GOLD_DARK)
	draw_rect(Rect2(15, 15, SIZE.x - 30, SIZE.y - 30), GOLD)
	draw_rect(Rect2(24, 24, SIZE.x - 48, SIZE.y - 48), PARCHMENT)
	for p in [Vector2(42, 42), Vector2(SIZE.x - 42, 42), Vector2(42, SIZE.y - 42), Vector2(SIZE.x - 42, SIZE.y - 42)]:
		draw_circle(p, 10, GOLD_DARK)
		draw_circle(p, 6, GOLD)
	_center("THE LEDGER OF A SMALL GOD", Vector2(SIZE.x / 2.0, 74), 34, OAK)
	for i in TABS.size():
		var r := tab_rect(i)
		var on := i == page
		draw_rect(r, GOLD_DARK)
		draw_rect(r.grow(-3), OAK if on else PARCH_SHADE)
		_center(TABS[i], r.position + Vector2(r.size.x / 2.0, 38), 28, GOLD if on else OAK_LIGHT)
	draw_line(Vector2(60, TAB_Y + TAB_H + 10), Vector2(SIZE.x - 60, TAB_Y + TAB_H + 10), GOLD_DARK, 3.0)
	match page:
		0:
			_page_god()
		1:
			_page_village()
		2:
			_page_cards()
		3:
			_page_quests()


func _page_god() -> void:
	var y := 220.0
	var night: int = data.get("night", 0)
	var days: int = data.get("days", 5)
	_left("Day", Vector2(80, y), 30, OAK_LIGHT)
	for i in days:
		var c := Vector2(250 + i * 62, y - 10)
		draw_circle(c, 22, GOLD_DARK)
		draw_circle(c, 18, GOLD if i <= night else PARCH_SHADE)
		if i == night:
			draw_arc(c, 26, 0, TAU, 32, EMBER, 3.0)
	_left("of %d" % days, Vector2(250 + days * 62, y), 26, OAK_LIGHT)
	y += 78
	_left("Loop", Vector2(80, y), 30, OAK_LIGHT)
	_left(ROMAN[clampi(data.get("loop", 0), 0, ROMAN.size() - 1)], Vector2(250, y), 40, INK)
	_left("Dusk in", Vector2(560, y), 30, OAK_LIGHT)
	_left(String(data.get("time_left", "")), Vector2(720, y), 40, INK)
	y += 78
	_left("Faith", Vector2(80, y), 30, OAK_LIGHT)
	draw_circle(Vector2(280, y - 12), 34, Color("7A2318"))
	draw_circle(Vector2(280, y - 12), 29, EMBER)
	_center(str(data.get("faith", 0)), Vector2(280, y - 1), 28, PARCHMENT)
	_left("Foresight", Vector2(560, y), 30, OAK_LIGHT)
	_left("tier %d" % data.get("foresight", 0), Vector2(720, y), 34, INK)
	y += 82
	_left("Homes", Vector2(80, y), 30, OAK_LIGHT)
	var total: int = data.get("houses_total", 6)
	var up: int = data.get("houses", 6)
	for i in total:
		var b := Rect2(250 + i * 58, y - 34, 40, 34)
		draw_rect(b, GOLD_DARK)
		draw_rect(b.grow(-3), GOLD if i < up else Color("6B4228"))
		draw_colored_polygon(PackedVector2Array([b.position + Vector2(-5, 0), b.position + Vector2(20, -20), b.position + Vector2(45, 0)]), EMBER if i < up else Color("6B4228"))
	_left("%d of %d standing" % [up, total], Vector2(250 + total * 58 + 16, y), 26, OAK_LIGHT)
	y += 70
	draw_line(Vector2(80, y - 24), Vector2(SIZE.x - 80, y - 24), GOLD_DARK, 2.0)
	_left("Gifts you carry", Vector2(80, y + 14), 30, OAK_LIGHT)
	var gifts: Array = data.get("gifts", [])
	if gifts.is_empty():
		_left("None yet.", Vector2(80, y + 58), 26, INK)
	for i in mini(gifts.size(), 6):
		_left("- " + String(gifts[i]), Vector2(80 + (i % 2) * 450, y + 58 + (i / 2) * 38), 24, INK)


func _page_village() -> void:
	var folk: Array = data.get("villagers", [])
	var cols := 3
	var w := (SIZE.x - 140.0) / cols
	for i in mini(folk.size(), 12):
		var f: Dictionary = folk[i]
		var r := Rect2(70 + (i % cols) * w, 178 + (i / cols) * 128, w - 14, 116)
		draw_rect(r, GOLD_DARK)
		draw_rect(r.grow(-3), PARCH_SHADE)
		_left(String(f.get("name", "")), r.position + Vector2(14, 34), 26, OAK)
		_left(String(f.get("role", "")), r.position + Vector2(14, 58), 19, OAK_LIGHT)
		var said := String(f.get("said", ""))
		_wrap_left("\"%s\"" % said if said != "" else "Not heard yet. Tap them.", Rect2(r.position + Vector2(14, 64), Vector2(r.size.x - 28, 48)), 17, INK if said != "" else OAK_LIGHT)


func _page_cards() -> void:
	var y := 196.0
	for group in [["Towers", data.get("towers", [])], ["Spells", data.get("spells", [])]]:
		_left(group[0], Vector2(80, y + 8), 30, OAK_LIGHT)
		y += 22
		var list: Array = group[1]
		for i in list.size():
			var c: Dictionary = list[i]
			var r := Rect2(80 + (i % 2) * 446, y + (i / 2) * 62, 434, 54)
			draw_rect(r, GOLD_DARK)
			draw_rect(r.grow(-3), PARCH_SHADE)
			_fit(String(c.get("title", "")), r.position + Vector2(12, 24), 22, OAK, 200)
			var stats: Array = c.get("stats", [])
			var bits: Array[String] = []
			for s in stats:
				if String(s[0]) != "":
					bits.append("%s %s" % [s[0], s[1]])
			_fit("   ".join(bits), r.position + Vector2(12, 46), 17, INK, r.size.x - 24)
		y += ceili(list.size() / 2.0) * 62 + 22


func _page_quests() -> void:
	var quests: Array = data.get("quests", [])
	var y := 180.0
	if quests.is_empty():
		_center("No one has asked for anything yet today.", Vector2(SIZE.x / 2.0, 300), 28, OAK_LIGHT)
	for q: Dictionary in quests:
		var r := Rect2(70, y, SIZE.x - 140, 108)
		var done: bool = q.get("done", false)
		draw_rect(r, GOLD_DARK)
		draw_rect(r.grow(-3), PARCH_SHADE if not done else Color("D8E0B4"))
		_left(String(q.get("name", "")), r.position + Vector2(16, 34), 28, OAK)
		_left("asked by %s" % q.get("who", ""), r.position + Vector2(360, 32), 22, OAK_LIGHT)
		_fit("\"%s\"" % q.get("ask", ""), r.position + Vector2(16, 64), 22, INK, r.size.x - 150)
		_fit(String(q.get("how", "")), r.position + Vector2(16, 94), 22, GREEN if done else EMBER, r.size.x - 150)
		var seal := r.position + Vector2(r.size.x - 62, 54)
		draw_circle(seal, 36, Color("7A2318") if not done else GREEN.darkened(0.3))
		draw_circle(seal, 31, EMBER if not done else GREEN)
		_center("done" if done else "+%d" % q.get("reward", 0), seal + Vector2(0, 9), 24, PARCHMENT)
		y += 118
	var more: int = data.get("quests_to_come", 0)
	if more > 0:
		_center("%d more will come before dusk." % more, Vector2(SIZE.x / 2.0, minf(y + 34, SIZE.y - 50)), 24, OAK_LIGHT)


func _font() -> Font:
	return ThemeDB.fallback_font


func _center(s: String, at: Vector2, px: int, col: Color) -> void:
	var w := _font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(_font(), at - Vector2(w / 2.0, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _left(s: String, at: Vector2, px: int, col: Color) -> void:
	draw_string(_font(), at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _fit(s: String, at: Vector2, px: int, col: Color, width: float) -> void:
	var w := _font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var fs := px if w <= width else maxi(11, int(px * width / w))
	draw_string(_font(), at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _wrap_left(s: String, r: Rect2, px: int, col: Color) -> void:
	draw_multiline_string(_font(), r.position + Vector2(0, px), s, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, px, 2, col)
