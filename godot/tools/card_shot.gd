extends SceneTree
## Renders the physical cards (desktop window needed, not --headless):
##   <godot console> --xr-mode off --path godot -s res://tools/card_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_towers.png, _spells.png, _abilities.png (the tray seen from above and ahead) and
## OUT_PREFIX_closeup.png (one card at reading distance, ~45 cm).

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := args[0] if args.size() > 0 else "card_shot"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("3A3340")
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 40
	for i in 3:
		await process_frame  # the root is not inside the tree yet during _initialize
	var tray := CardTray.new()
	root.add_child(tray)
	var sets := {
		"towers": GameConfig.TOWER_ORDER.map(func(id): return CardData.tower(id)),
		"spells": GameConfig.SPELL_ORDER.map(func(id): return CardData.spell(id)),
		"abilities": [CardData.ability("ember_shot", 0), CardData.ability("shield_wall", 1), CardData.ability("deep_pockets", 2)],
	}
	for key in sets:
		var list: Array[Dictionary] = []
		list.assign(sets[key])
		tray.set_cards(list)
		for i in 12:
			await process_frame
		cam.global_position = Vector3(0, 0.22, 0.34)
		cam.look_at(Vector3(0, 0.03, 0), Vector3.UP)
		await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [prefix, key])
		print("CARDSHOT ", key, " ", list.size(), " cards")
	# one card at reading distance
	var one: Array[Dictionary] = [CardData.tower("fire")]
	tray.set_cards(one)
	for i in 12:
		await process_frame
	var c: Card3D = tray.cards[0]
	c.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0))
	c.scale = Vector3.ONE * Card3D.LIFT_SCALE  # as held
	cam.global_position = Vector3(0, 0.1, 0.45)  # ~45 cm: reading distance
	cam.look_at(Vector3(0, 0.1, 0), Vector3.UP)
	cam.fov = 14  # crop to the card so the print can be judged
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s_closeup.png" % prefix)
	print("CARDSHOT closeup done")
	quit()
