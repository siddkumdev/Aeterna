extends SceneTree
## The physical cards inside the real game, desktop window (not --headless):
##   <godot console> --xr-mode off --path godot -s res://tools/card_play_shot.gd -- OUT_PREFIX
## Day: picks up the Wizard card with the desktop hand, hovers over the grass (ghost + ring), drops it (a tower
## must appear), then night: picks up Fire Orb. Writes OUT_PREFIX_day.png, _held.png, _built.png, _night.png and
## prints CARDPLAY lines with the checks.

func _initialize() -> void:
	var prefix := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "card_play"
	var g: Game = load("res://scripts/game/game.gd").new()
	g.with_rig = true
	root.add_child(g)
	for i in 12:
		await process_frame
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 50
	var look := g.board.to_global(Vector3(0, 0.02, 0.35))
	cam.global_position = g.board.to_global(Vector3(0, 0.45, 0.95))
	cam.look_at(look, Vector3.UP)
	g._camera = cam
	await _shot(prefix + "_day")
	var h: GameHand = g._mouse_hand
	print("CARDPLAY tray cards: ", g._tray.cards.size(), " mouse hand: ", h != null)
	var card: Card3D = g._tray.cards[0]
	h.global_position = card.global_position
	g.hand_pressed(h)
	print("CARDPLAY held: ", g._held_card != null, " kind=", card.data.get("id", ""))
	var spot := NavGrid.footprint_centre(Vector2i(11, 11), GameConfig.TOWER_SIZE)  # the cell game_selftest builds on
	h.global_position = g.board.to_global(spot + Vector3(0, 0.07, 0))
	g._update_held()
	print("CARDPLAY hover cell ", g._hover_cell, " can_build ", g.can_build("fire", g._hover_cell))
	print("CARDPLAY card at ", card.global_position, " hand ", h.global_position, " scale ", card.scale, " vis ", card.is_visible_in_tree(), " cam ", cam.global_position)
	g._camera = null  # the game only moves the mouse hand while it has a camera; the test holds the hand still
	_pin = h
	_pin_at = h.global_position
	await _shot(prefix + "_held")
	_pin = null
	g._camera = cam
	var before := g.towers.size()
	h.global_position = g.board.to_global(spot + Vector3(0, 0.07, 0))  # the mouse hand drifted back to the mouse
	g.hand_released(h)
	for i in 14:
		await process_frame
	print("CARDPLAY towers ", before, " -> ", g.towers.size(), " faith left ", g.faith)
	await _shot(prefix + "_built")
	g.faith = 500
	g.start_night()
	for i in 16:
		await process_frame
	print("CARDPLAY night tray: ", g._tray.cards.size(), " first=", g._tray.cards[0].data.get("id", ""))
	card = g._tray.cards[0]
	h.global_position = card.global_position
	g.hand_pressed(h)
	h.global_position = g.board.to_global(Vector3(0.0, 0.05, -0.1))
	g._update_held()
	g._camera = null
	_pin = h
	_pin_at = h.global_position
	await _shot(prefix + "_night")
	_pin = null
	g._camera = cam
	g.hand_released(h)
	quit()


var _pin: GameHand
var _pin_at := Vector3.ZERO


func _shot(name: String) -> void:
	for i in 6:
		if _pin:
			_pin.global_position = _pin_at  # the desktop mouse hand drifts to the mouse; keep it where the test put it
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s.png" % name)
