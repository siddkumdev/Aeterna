extends SceneTree
## Headless test of the first slice: wave plan, routes, build rules, then whole nights played by a bot.
## Run:  <godot console> --headless --xr-mode off --path godot -s res://tests/game_selftest.gd
## The bot nights also print how the numbers play out (a balance read, not a pass/fail on its own).

var failures := 0


func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		failures += 1


func _initialize() -> void:
	await process_frame
	_waves()
	_nav()
	await _nights()
	print("game_selftest: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


func _waves() -> void:
	for n in range(GameConfig.NIGHT_BUDGETS.size()):
		var g := WavePlan.groups_for(n, 1)
		var total := 0
		var edges := {}
		for x in g:
			total += x["count"]
			edges[x["spawn"]] = true
		check("night %d: group sizes add up to the budget (%d)" % [n + 1, total], total == GameConfig.NIGHT_BUDGETS[n])
		check("night %d: one group from each spawn" % (n + 1), edges.size() == 3)
	check("same seed, same plan", str(WavePlan.groups_for(2, 5)) == str(WavePlan.groups_for(2, 5)))


func _nav() -> void:
	var nav := NavGrid.new()
	var all: Array[int] = [0, 1, 2, 3, 4, 5]
	for k in GameConfig.SPAWNS:
		var r := nav.route(GameConfig.SPAWNS[k][0], all)
		check("route from %s reaches a house" % k, not r.is_empty())
	check("cannot build on a house", not nav.can_build(GameConfig.HOUSE_CELLS[0], Vector2i(2, 2), all))
	check("cannot build on the forest ring", not nav.can_build(Vector2i(0, 2), Vector2i(2, 2), all))
	check("cannot build on a spawn gap", not nav.can_build(Vector2i(5, 0), Vector2i(2, 2), all))
	check("can build on open ground", nav.can_build(Vector2i(1, 1), Vector2i(2, 2), all))
	# Plug the north gap: the cells just inside it. Building there must be refused.
	check("cannot seal a spawn off", not nav.can_build(Vector2i(5, 1), Vector2i(2, 2), all))
	nav.add_tower(Vector2i(1, 1), Vector2i(2, 2))
	check("tower cells are blocked", not nav.can_build(Vector2i(2, 2), Vector2i(2, 2), all))
	var r := nav.route(Vector2i(0, 5), all)
	var crosses := false
	for c in r.get("path", []):
		if nav.kind.get(c, "") in ["tower", "house", "forest"]:
			crosses = true
	check("routes avoid towers, houses and forest", not r.is_empty() and not crosses)


func _make_game() -> Game:
	var g: Game = load("res://scripts/game/game.gd").new()
	g.with_rig = false
	root.add_child(g)
	await process_frame
	return g


func _play_night(g: Game) -> void:
	g.start_night()
	var t := 0.0
	while g.phase == Game.Phase.NIGHT and t < 600.0:
		g.step(0.05)
		t += 0.05
		if int(t / 0.05) % 20 == 0:
			await process_frame  # let queue_free run


func _nights() -> void:
	# 1) No towers: Grunts must reach the houses and hurt them.
	var g := await _make_game()
	check("starts in day with 100 trust", g.phase == Game.Phase.DAY and g.trust == 100)
	g.trust = 10
	check("unaffordable tower refused", not g.try_build("fire", Vector2i(1, 1)) and g.towers.is_empty())
	g.trust = GameConfig.START_TRUST
	await _play_night(g)
	var hurt := 0
	for h in g.houses:
		if h.hp < GameConfig.HOUSE_HP or h.is_shuttered:
			hurt += 1
	print("      no towers, night 1: phase %s, houses hit %d, standing %d" % [Game.Phase.keys()[g.phase], hurt, g.standing_houses().size()])
	check("undefended: Grunts reach and damage houses", hurt > 0 or g.phase == Game.Phase.LOST)
	g.queue_free()
	await process_frame

	# 2) Bot: every day spend all trust, cycling fire / brazier / crossbow on spots near the gaps.
	g = await _make_game()
	var spots: Array[Vector2i] = [Vector2i(5, 5), Vector2i(5, 1), Vector2i(1, 3), Vector2i(9, 3), Vector2i(3, 1), Vector2i(7, 1),
		Vector2i(1, 7), Vector2i(9, 7), Vector2i(1, 9), Vector2i(9, 9), Vector2i(5, 5), Vector2i(3, 10), Vector2i(7, 10)]
	var order := ["fire", "crossbow", "brazier"]
	var k := 0
	check("build costs trust", g.try_build("fire", Vector2i(5, 5)) and g.trust == 40)
	while g.phase == Game.Phase.DAY:
		var built := true
		while built:
			built = false
			for s in spots:
				if g.try_build(order[k % 3], s):
					k += 1
					built = true
					break
		var n := g.night + 1
		await _play_night(g)
		var hp := []
		for h in g.houses:
			hp.append(int(h.hp))
		print("      bot night %d: towers %d, result %s, trust now %d, %s" % [n, g.towers.size(), Game.Phase.keys()[g.phase], g.trust, g.last_message])
	check("bot run ends (lost or loop complete)", g.phase == Game.Phase.LOST or g.phase == Game.Phase.DONE)
	check("new run resets", (func(): g.new_run(2); return g.phase == Game.Phase.DAY and g.towers.is_empty() and g.trust == 100 and g.standing_houses().size() == 6).call())
