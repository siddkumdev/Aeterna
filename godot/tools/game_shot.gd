extends SceneTree
## Screenshots of the slice in desktop mode (needs a window, not --headless):
##   <godot console> --xr-mode off --path godot -s res://tools/game_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_day.png (build ghost shown), _night.png (a night under way), _air.png (Wisps, Airships,
## a Tunneler mound, Fog variants), _boss.png and _cards.png.


func _initialize() -> void:
	var prefix := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "game_shot"
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 5:
		await process_frame
	g.try_build("fire", Vector2i(11, 11))
	g.select("crossbow")
	g.set_process(false)  # keep the mouse from moving the ghost
	g._hover_cell = Vector2i(3, 9)
	g._update_ghost()
	await _settle()
	root.get_viewport().get_texture().get_image().save_png(prefix + "_day.png")
	# sell mode: the orange plate over the tower under the pointer
	g.select("sell")
	g._hover_board_cell = Vector2i(12, 12)
	g._update_ghost()
	await _settle()
	root.get_viewport().get_texture().get_image().save_png(prefix + "_sell.png")
	# the desktop mouse hand near the lost lantern: the bubble lights up when something can be grabbed
	g.select("")
	var lan: HelpRequest = g.requests.filter(func(r): return r.kind == "lantern")[0]
	g._hand_height = 0.045
	g._mouse_hand.global_position = lan.grab_point() + Vector3(0.05, g._hand_height - 0.008, 0.03)
	g._hand_stem.scale.y = g._hand_height
	g._hand_stem.position.y = -g._hand_height / 2.0
	g._hand_ring.position.y = -g._hand_height + 0.002
	g._mouse_hand.set_bubble_hot(g.grabbable_near(g._mouse_hand.global_position))
	await _settle()
	root.get_viewport().get_texture().get_image().save_png(prefix + "_hand.png")
	g._mouse_hand.global_position = Vector3(0, 3, 0)  # out of the later shots
	g.select("")
	g.trust = 200
	g.try_build("crossbow", Vector2i(3, 9))
	g.try_build("brazier", Vector2i(19, 9))
	g.set_process(true)
	g.speed = 0.0  # the shot steps the night by hand below
	g.night = 2  # night 3: Grunts, Scouts and the first Splitter
	g.start_night()
	var t := 0.0
	while t < 19.0:
		g.step(0.05)
		t += 0.05
	await _settle()
	root.get_viewport().get_texture().get_image().save_png(prefix + "_night.png")
	# air and underground (step 2): Wisps flying in at the Airships, a Tunneler's mound, Fog variants walking
	g._clear_night()
	g.phase = Game.Phase.DAY
	g.trust = 200
	g.try_build("airship", Vector2i(14, 5))
	g.try_build("airship", Vector2i(5, 14))
	g.loop = 1
	g.night = 2
	g.start_night()
	g._spawn_queue.clear()
	for i in 3:
		g._spawn(GameConfig.SPAWNS["north"][i], "wisp")
	for i in 2:
		g._spawn(GameConfig.SPAWNS["west"][i + 1], "wisp")
		g._spawn(GameConfig.SPAWNS["west"][i * 2], "fog")
	g._spawn(GameConfig.SPAWNS["east"][1], "tunneler")
	g._spawn(GameConfig.SPAWNS["east"][3], "tunneler")
	t = 0.0
	while t < 4.0:
		g.step(0.05)
		t += 0.05
	await _settle()
	root.get_viewport().get_texture().get_image().save_png(prefix + "_air.png")
	# spells (step 7): a Storm Cloud striking a group, a Rage ring round a tower, roots round a house, an orb landing
	g._clear_night()
	g.phase = Game.Phase.DAY
	g.loop = 0
	g.night = 2
	g.trust = 400
	g.try_build("fire", Vector2i(4, 9))
	g.try_build("crossbow", Vector2i(18, 9))
	g.start_night()
	g._spawn_queue.clear()
	for p in [Vector2i(5, 14), Vector2i(6, 14), Vector2i(7, 15), Vector2i(8, 16)]:
		var e: Enemy = g._spawn(p, "grunt", NavGrid.cell_centre(p))
		e.slow(0.0001, 1000.0)
	for p in [Vector2i(18, 14), Vector2i(19, 15)]:
		var e2: Enemy = g._spawn(p, "scout", NavGrid.cell_centre(p))
		e2.slow(0.0001, 1000.0)
	g.cast_spell("storm", NavGrid.cell_centre(Vector2i(6, 14)))
	g.cast_spell("rage", g.towers[0].position)
	g.cast_spell("roots", g.house_point(2))
	g.cast_spell("fire_orb", NavGrid.cell_centre(Vector2i(18, 14)))
	t = 0.0
	while t < 0.62:
		g.step(0.05)
		t += 0.05
	await _settle()
	root.get_viewport().get_texture().get_image().save_png(prefix + "_spells.png")
	# boss night: the placeholder Warden walking in with its escorts
	for tw in g.towers.filter(func(x): return x.kind == "airship"):
		tw.queue_free()
		g.towers.erase(tw)
	g.loop = 0
	g._clear_night()
	g.night = GameConfig.BOSS_NIGHT
	g.phase = Game.Phase.DAY
	g.start_night()
	t = 0.0
	while t < GameConfig.BOSS_DELAY + 14.0:
		g.step(0.05)
		t += 0.05
	await _settle()
	root.get_viewport().get_texture().get_image().save_png(prefix + "_boss.png")
	# phase 2: the Warden shielded by its ring of crystals
	var boss: Enemy = g.warden.boss
	boss.take_damage(boss.hp + 1.0)
	t = 0.0
	while t < 1.0:
		g.step(0.05)
		t += 0.05
	await _settle()
	root.get_viewport().get_texture().get_image().save_png(prefix + "_boss_p2.png")
	# the cards offered after beating the boss (cards for every tower, so one shows each rarity colour)
	g._end_loop(true)
	g.offers = [{"id": "quick_fuse", "rarity": 0}, {"id": "hot_coals", "rarity": 1}, {"id": "ember_shot", "rarity": 2}]
	g._refresh_ui()
	await _settle()
	root.get_viewport().get_texture().get_image().save_png(prefix + "_cards.png")
	# Foresight (step 3): the lens reveal of the coming night in loops 1, 3 and 5 = tiers 1, 2, 3 (desktop: every gap)
	g.set_process(false)  # keep the desktop L key from putting the lens down
	for lp in [0, 2, 4]:
		g.new_run(1)
		g.loop = lp
		g.night = 2
		g._start_loop("Foresight, loop %d" % (lp + 1))
		g.night = 2
		g.try_build("fire", Vector2i(11, 11))
		g._lens.transform = g._lens_rest.translated(Vector3(0, 0.12, -0.03))
		g.set_lens(true)
		g._refresh_ui()
		await _settle()
		root.get_viewport().get_texture().get_image().save_png(prefix + "_foresight_t%d.png" % g.foresight_tier())
	print("saved ", prefix, "_day / _sell / _hand / _night / _air / _spells / _boss / _boss_p2 / _cards / _foresight_t1/t2/t3 .png")
	quit()


func _settle() -> void:
	await create_timer(1.6).timeout  # light tweens take 1.2 s
