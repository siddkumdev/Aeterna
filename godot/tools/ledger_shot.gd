extends SceneTree
## The ledger's pages (desktop window, not --headless):
##   <godot console> --xr-mode off --path godot -s res://tools/ledger_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_0.png .. _2.png (the three spreads) and _turn1/_turn2.png (a leaf mid-turn) from the seat.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "ledger_shot"
	var l: Launcher = load("res://scripts/ui/launcher.gd").new()
	root.add_child(l)
	for i in 40:
		await process_frame
	l._press_plaque("skip")
	l._skip = true
	for i in 30:
		await process_frame
	var g := l.game
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 48
	cam.global_position = g.board.to_global(Vector3(0.0, 0.5, 1.05))
	cam.look_at(g.board.to_global(Vector3(0, 0.05, 0.25)), Vector3.UP)
	g._camera = cam
	g.force_quests(["rain", "prayer", "lights"])
	g.cards = {"deep_pockets": 1} if Cards.POOL.has("deep_pockets") else {}
	for i in mini(5, g.life.villagers.size()):
		g.tap_villager(g.life.villagers[i])
	g.requests[1].answer(g.requests[1].asker())
	g.toggle_ledger()
	for i in 30:
		await process_frame
	for sp in Ledger.SPREADS:
		if sp > 0:
			g.ledger.turn(1)
			for i in 12:  # mid-turn: the leaf standing up
				await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s_turn%d.png" % [prefix, sp])
			for i in 60:
				await process_frame
		for i in 12:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s_%d.png" % [prefix, sp])
	quit()
