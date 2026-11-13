class_name LedgerPage
extends Control
## One drawn page of the god's ledger, which is a physical book now (the user, 2026-11-11: "like a physical book you
## can turn the pages"). Our own look, the cards' family: parchment, gilt border, ember seals, never blue.
## `data` comes from Game.ledger_data(); `page` (0..COUNT-1) picks what is drawn. A spread is two pages: (0,1), (2,3), (4,5).
## Rendered into a SubViewport by Ledger.

const SIZE := Vector2(560, 760)
const COUNT := 6  # God, Village, Towers, Spells, Quests, How to play
const PARCHMENT := Color("F4E4B8")
const PARCH_SHADE := Color("E8D29A")
const INK := Color("111C30")
const GOLD := Color("E8B83A")
const GOLD_DARK := Color("A87A1C")
const OAK := Color("5B2920")
const OAK_LIGHT := Color("9A6538")
const EMBER := Color("E8452C")
const GREEN := Color("5D8548")  # leaf_green
const QUIT_RECT := Rect2(140, SIZE.y - 112, SIZE.x - 280, 46)
const ROMAN: Array[String] = ["I", "II", "III", "IV", "V", "VI", "VII"]
const TITLES: Array[String] = ["The God", "The Village", "Towers", "Spells", "Quests", "How to Play"]
const HOW: Array[String] = [
	"Pick a card up from the tray, set it on the grass and let go.",
	"Pinch and hold a tower to crush it back into faith.",
	"Tap a villager to hear their thoughts. Gold motes mark quests: carry, touch or tap to help.",
	"Hold the hourglass to hurry the day. Night falls on its own.",
	"Hold the island's rim to move or turn it; two hands resize it.",
	"Left palm up for a second opens this book. Tap the right page to turn forward, the left to turn back.",
]

var data: Dictionary = {}
var page := 0


func _init() -> void:
	size = SIZE
	custom_minimum_size = SIZE


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), PARCHMENT)
	draw_rect(Rect2(14, 14, SIZE.x - 28, SIZE.y - 28), GOLD_DARK, false, 3.0)
	draw_rect(Rect2(22, 22, SIZE.x - 44, SIZE.y - 44), GOLD, false, 2.0)
	for p in [Vector2(30, 30), Vector2(SIZE.x - 30, 30), Vector2(30, SIZE.y - 30), Vector2(SIZE.x - 30, SIZE.y - 30)]:
		draw_circle(p, 6, GOLD_DARK)
	_center(TITLES[clampi(page, 0, COUNT - 1)], Vector2(SIZE.x / 2.0, 78), 40, OAK)
	draw_line(Vector2(60, 98), Vector2(SIZE.x - 60, 98), GOLD_DARK, 3.0)
	_center(ROMAN[clampi(page, 0, ROMAN.size() - 1)], Vector2(SIZE.x / 2.0, SIZE.y - 38), 24, OAK_LIGHT)
	match page:
		0:
			_page_god()
		1:
			_page_village()
		2:
			_page_cards("Towers", data.get("towers", []))
		3:
			_page_cards("Spells", data.get("spells", []))
		4:
			_page_quests()
		5:
			_page_how()


func _page_god() -> void:
	var y := 160.0
	var night: int = data.get("night", 0)
	var days: int = data.get("days", 5)
	_left("Day", Vector2(50, y), 28, OAK_LIGHT)
	for i in days:
		var c := Vector2(170 + i * 70, y - 10)
		draw_circle(c, 24, GOLD_DARK)
		draw_circle(c, 20, GOLD if i <= night else PARCH_SHADE)
		if i == night:
			draw_arc(c, 28, 0, TAU, 32, EMBER, 3.0)
	y += 76
	_left("Loop", Vector2(50, y), 28, OAK_LIGHT)
	_left(ROMAN[clampi(data.get("loop", 0), 0, ROMAN.size() - 1)], Vector2(170, y), 38, INK)
	_left("Dusk in", Vector2(290, y), 28, OAK_LIGHT)
	_left(String(data.get("time_left", "")), Vector2(420, y), 36, INK)
	y += 84
	_left("Faith", Vector2(50, y), 28, OAK_LIGHT)
	draw_circle(Vector2(190, y - 10), 34, Color("7A2318"))
	draw_circle(Vector2(190, y - 10), 29, EMBER)
	_center(str(data.get("faith", 0)), Vector2(190, y), 26, PARCHMENT)
	_left("Foresight", Vector2(290, y), 28, OAK_LIGHT)
	_left("tier %d" % data.get("foresight", 0), Vector2(420, y), 30, INK)
	y += 84
	_left("Homes", Vector2(50, y), 28, OAK_LIGHT)
	var total: int = data.get("houses_total", 6)
	var up: int = data.get("houses", 6)
	for i in total:
		var b := Rect2(150 + i * 62, y - 34, 44, 34)
		draw_rect(b, GOLD_DARK)
		draw_rect(b.grow(-3), GOLD if i < up else Color("6B4228"))
		draw_colored_polygon(PackedVector2Array([b.position + Vector2(-5, 0), b.position + Vector2(22, -20), b.position + Vector2(49, 0)]), EMBER if i < up else Color("6B4228"))
	_left("%d of %d standing" % [up, total], Vector2(150, y + 34), 22, OAK_LIGHT)
	y += 100
	draw_line(Vector2(50, y - 30), Vector2(SIZE.x - 50, y - 30), GOLD_DARK, 2.0)
	_left("Gifts you carry", Vector2(50, y + 4), 28, OAK_LIGHT)
	var gifts: Array = data.get("gifts", [])
	if gifts.is_empty():
		_left("None yet.", Vector2(50, y + 46), 24, INK)
	for i in mini(gifts.size(), 8):
		_fit("- " + String(gifts[i]), Vector2(50, y + 46 + i * 34), 22, INK, SIZE.x - 100)


func _page_village() -> void:
	var folk: Array = data.get("villagers", [])
	for i in mini(folk.size(), 12):
		var f: Dictionary = folk[i]
		var r := Rect2(40, 116 + i * 52, SIZE.x - 80, 48)
		draw_rect(r, GOLD_DARK)
		draw_rect(r.grow(-2), PARCH_SHADE)
		_left(String(f.get("name", "")), r.position + Vector2(10, 21), 20, OAK)
		_left(String(f.get("role", "")), r.position + Vector2(190, 21), 16, OAK_LIGHT)
		var said := String(f.get("said", ""))
		_fit("\"%s\"" % said if said != "" else "Not heard yet. Tap them.", r.position + Vector2(10, 40), 15, INK if said != "" else OAK_LIGHT, r.size.x - 20)


func _page_cards(label: String, list: Array) -> void:
	_left("%s you may call" % label, Vector2(50, 142), 22, OAK_LIGHT)
	for i in list.size():
		var c: Dictionary = list[i]
		var r := Rect2(40, 160 + i * 68, SIZE.x - 80, 62)
		draw_rect(r, GOLD_DARK)
		draw_rect(r.grow(-3), PARCH_SHADE)
		_fit(String(c.get("title", "")), r.position + Vector2(12, 26), 22, OAK, r.size.x - 24)
		var bits: Array[String] = []
		for s in c.get("stats", []):
			if String(s[0]) != "":
				bits.append("%s %s" % [s[0], s[1]])
		_fit("   ".join(bits), r.position + Vector2(12, 52), 16, INK, r.size.x - 24)


func _page_quests() -> void:
	var quests: Array = data.get("quests", [])
	var y := 124.0
	if quests.is_empty():
		_wrap_center("No one has asked for anything yet today. Gold motes will appear on the houses.", Rect2(60, 260, SIZE.x - 120, 200), 24, OAK_LIGHT)
	for q: Dictionary in quests:
		var r := Rect2(36, y, SIZE.x - 72, 138)
		var done: bool = q.get("done", false)
		draw_rect(r, GOLD_DARK)
		draw_rect(r.grow(-3), PARCH_SHADE if not done else Color("D8E0B4"))
		_fit(String(q.get("name", "")), r.position + Vector2(14, 30), 24, OAK, r.size.x - 120)
		_fit("asked by %s" % q.get("who", ""), r.position + Vector2(14, 54), 17, OAK_LIGHT, r.size.x - 120)
		_fit("\"%s\"" % q.get("ask", ""), r.position + Vector2(14, 84), 17, INK, r.size.x - 120)
		_fit(String(q.get("how", "")), r.position + Vector2(14, 116), 17, GREEN if done else EMBER, r.size.x - 120)
		var seal := r.position + Vector2(r.size.x - 48, 50)
		draw_circle(seal, 32, Color("7A2318") if not done else GREEN.darkened(0.3))
		draw_circle(seal, 27, EMBER if not done else GREEN)
		_center("done" if done else "+%d" % q.get("reward", 0), seal + Vector2(0, 8), 20, PARCHMENT)
		y += 146
	var more: int = data.get("quests_to_come", 0)
	if more > 0:
		_center("%d more will come before dusk." % more, Vector2(SIZE.x / 2.0, minf(y + 24, SIZE.y - 70)), 20, OAK_LIGHT)


func _page_how() -> void:
	var y := 122.0
	for line in HOW:
		draw_circle(Vector2(56, y + 14), 5, GOLD_DARK)
		_wrap_left(line, Rect2(76, y, SIZE.x - 120, 78), 20, INK)
		y += 78
	_center("Watch over them.", Vector2(SIZE.x / 2.0, SIZE.y - 134), 24, EMBER)
	draw_rect(QUIT_RECT, EMBER)
	draw_rect(QUIT_RECT.grow(-3), Color("E8C888"))
	_center("Quit Game", Vector2(SIZE.x / 2.0, QUIT_RECT.position.y + 32), 22, INK)


func _font() -> Font:
	return ThemeDB.fallback_font


func _center(s: String, at: Vector2, px: int, col: Color) -> void:
	var w := _font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(_font(), at - Vector2(w / 2.0, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _left(s: String, at: Vector2, px: int, col: Color) -> void:
	draw_string(_font(), at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _fit(s: String, at: Vector2, px: int, col: Color, width: float) -> void:
	var w := _font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var fs := px if w <= width else maxi(10, int(px * width / w))
	draw_string(_font(), at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _wrap_left(s: String, r: Rect2, px: int, col: Color) -> void:
	draw_multiline_string(_font(), r.position + Vector2(0, px), s, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, px, 3, col)


func _wrap_center(s: String, r: Rect2, px: int, col: Color) -> void:
	draw_multiline_string(_font(), r.position + Vector2(0, px), s, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, px, 4, col)
