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
	await _cards()
	print("game_selftest: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


func _waves() -> void:
	for n in range(GameConfig.NIGHT_BUDGETS.size()):
		var g := WavePlan.groups_for(n, 1)
		var total := 0
		var edges := {}
		var kinds := {}
		var max_share := 0
		for x in g:
			var t := WavePlan.threat_of(x["enemies"])
			total += t
			max_share = maxi(max_share, t)
			edges[x["spawn"]] = true
			for k in x["enemies"]:
				kinds[k] = true
				check("night %d: %s is unlocked" % [n + 1, k], GameConfig.ENEMIES[k]["unlock"] <= n + 1) if GameConfig.ENEMIES[k]["unlock"] > n + 1 else null
		check("night %d: threat adds up to the budget (%d)" % [n + 1, total], total == GameConfig.NIGHT_BUDGETS[n])
		check("night %d: one group from each spawn" % (n + 1), edges.size() == 3)
		check("night %d: no spawn gets more than half the budget" % (n + 1), max_share * 2 <= GameConfig.NIGHT_BUDGETS[n] + 2)
		for k in GameConfig.WAVE_TYPES:
			if GameConfig.ENEMIES[k]["unlock"] == n + 1 and n > 0:
				check("night %d: new type %s opens the night alone" % [n + 1, k], g[0]["enemies"].all(func(e): return e == k))
		print("      night %d: %s" % [n + 1, str(g.map(func(x): return "%s %s" % [x["spawn"], _count(x["enemies"])]))])
	check("same seed, same plan", str(WavePlan.groups_for(2, 5)) == str(WavePlan.groups_for(2, 5)))
	# loop 2: one extra group, a third more threat, and still no edge with more than half of it
	for n in range(5):
		var g2 := WavePlan.groups_for(n, 1, 1)
		var per := {}
		var total2 := 0
		for x in g2:
			var t := WavePlan.threat_of(x["enemies"])
			per[x["spawn"]] = per.get(x["spawn"], 0) + t
			total2 += t
		check("loop 2 night %d: 4 groups, more threat (%d > %d)" % [n + 1, total2, GameConfig.NIGHT_BUDGETS[n]], g2.size() == 4 and total2 > GameConfig.NIGHT_BUDGETS[n])
		check("loop 2 night %d: no edge over half" % (n + 1), per.values().max() * 2 <= total2 + 2)


func _count(list: Array) -> String:
	var c := {}
	for k in list:
		c[k] = c.get(k, 0) + 1
	return str(c)


func _nav() -> void:
	var nav := NavGrid.new()
	var all: Array[int] = [0, 1, 2, 3, 4, 5]
	for k in GameConfig.SPAWNS:
		var r := nav.route(GameConfig.SPAWNS[k][0], all)
		check("route from %s reaches a house" % k, not r.is_empty())
	check("cannot build on a house", not nav.can_build(GameConfig.HOUSE_CELLS[0], Vector2i(2, 2), all))
	check("cannot build on the forest ring", not nav.can_build(Vector2i(0, 2), Vector2i(2, 2), all))
	check("cannot build on a spawn gap", not nav.can_build(Vector2i(10, 0), Vector2i(2, 2), all))
	check("can build on open ground", nav.can_build(Vector2i(1, 1), Vector2i(2, 2), all))
	# Plug the north gap: the cells just inside it. Building there must be refused.
	check("cannot seal a spawn off", _seals_north(nav, all))
	nav.add_tower(Vector2i(1, 1), Vector2i(2, 2))
	check("tower cells are blocked", not nav.can_build(Vector2i(2, 2), Vector2i(2, 2), all))
	var r := nav.route(GameConfig.SPAWNS["west"][0], all)
	var crosses := false
	for c in r.get("path", []):
		if nav.kind.get(c, "") in ["tower", "house", "forest"]:
			crosses = true
	check("routes avoid towers, houses and forest", not r.is_empty() and not crosses)


func _seals_north(nav: NavGrid, all: Array[int]) -> bool:
	## The north gap is 4 cells wide: one 2x2 tower inside it is fine, the second that closes it is refused.
	var first := nav.can_build(Vector2i(10, 1), Vector2i(2, 2), all)
	nav.add_tower(Vector2i(10, 1), Vector2i(2, 2))
	var second := nav.can_build(Vector2i(12, 1), Vector2i(2, 2), all)
	nav.clear_towers()
	return first and not second


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
	check("starts in day with the start trust", g.phase == Game.Phase.DAY and g.trust == GameConfig.START_TRUST)
	g.trust = 10
	check("unaffordable tower refused", not g.try_build("fire", Vector2i(1, 1)) and g.towers.is_empty())
	g.trust = GameConfig.START_TRUST
	await _play_night(g)
	var hurt := 0
	for h in g.houses:
		if h.hp < GameConfig.HOUSE_HP or h.is_shuttered:
			hurt += 1
	print("      no towers, night 1: phase %s, houses hit %d, standing %d" % [Game.Phase.keys()[g.phase], hurt, g.standing_houses().size()])
	check("undefended: Grunts reach and damage houses", hurt > 0 or g.phase != Game.Phase.NIGHT)
	check("losing loop 1 offers exactly 1 Common card", g.phase == Game.Phase.CARDS and g.offers.size() == 1 and g.offers[0]["rarity"] == 0)
	var offered: String = g.offers[0]["id"] if not g.offers.is_empty() else ""
	check("taking it rewinds to loop 2, day 1, trust and towers reset, card kept",
		g.choose_card(0) and g.loop == 1 and g.night == 0 and g.phase == Game.Phase.DAY and g.towers.is_empty() and g.cards.has(offered))
	g.queue_free()
	await process_frame

	# 2) A whole run (2 loops) by a bot that keeps building round the village and takes the first card offered.
	g = await _make_game()
	check("build costs trust", g.try_build("fire", Vector2i(11, 11)) and g.trust == GameConfig.START_TRUST - 60)
	g.queue_free()
	await process_frame
	var run := await _run_bot(true, true)
	check("a full run ends (run complete or run over)", run["phase"] == Game.Phase.DONE)
	check("the run went through the hourglass into loop 2", run["loops"] >= 2)
	print("      full run: %s" % str(run["log"]))

	# Balance read (2026-10-22, Siddharth: "too easy, 3 towers won"). Target: three towers alone fall by
	# night 3; a player who keeps building near the village can still go far.
	var three := await _run_bot(false, false)
	var keeps := await _run_bot(true, false)
	check("balance: 3 towers alone fall by night 3", three["lost_on"] <= 3)
	print("      balance, loop 1 only: 3 towers lost on night %d; keep-building bot lost on night %d (7 = beat the boss)" % [three["lost_on"], keeps["lost_on"]])

	# 3) Speed: the same defended night at x1, x2 (player) and x10 (debug), driven the way a frame does it.
	var results := []
	for spd in [1.0, 2.0, 10.0]:
		var gs := await _make_game()
		gs.try_build("fire", Vector2i(11, 11))
		gs.try_build("crossbow", Vector2i(9, 3))
		gs.try_build("brazier", Vector2i(3, 9))
		gs.set_speed(spd)
		gs.start_night()
		var frames := 0
		while gs.phase == Game.Phase.NIGHT and frames < 60 * 600:
			gs._process(1.0 / 60.0)
			frames += 1
			if frames % 120 == 0:
				await process_frame
		results.append([spd, frames, gs.standing_houses().size(), Game.Phase.keys()[gs.phase]])
		print("      speed x%d: night took %d frames, houses standing %d, %s" % [int(spd), frames, gs.standing_houses().size(), Game.Phase.keys()[gs.phase]])
		gs.queue_free()
		await process_frame
	check("x2 night ends in about half the frames", absf(float(results[1][1]) / results[0][1] - 0.5) < 0.05)
	check("x10 night ends in about a tenth of the frames", absf(float(results[2][1]) / results[0][1] - 0.1) < 0.03)
	check("same outcome at x1, x2 and x10", results[0][2] == results[1][2] and results[0][2] == results[2][2] and results[0][3] == results[2][3])


func _run_bot(keep_building: bool, whole_run: bool) -> Dictionary:
	## 3 towers on day 1 near the village, then either nothing more or every day all trust spent on spots
	## round the village; takes the first card offered. Plays loop 1 only, or the whole run.
	## Returns {"lost_on": night lost in loop 1 (7 = beat the boss), "loops", "phase", "log"}.
	var g := await _make_game()
	var spots: Array[Vector2i] = [Vector2i(11, 11), Vector2i(11, 4), Vector2i(5, 11), Vector2i(17, 11), Vector2i(11, 18),
		Vector2i(14, 5), Vector2i(8, 5), Vector2i(5, 15), Vector2i(17, 15), Vector2i(5, 7), Vector2i(17, 7), Vector2i(14, 17)]
	var order := ["fire", "crossbow", "brazier"]
	var out := {"lost_on": 7, "loops": 1, "log": []}
	while g.phase != Game.Phase.DONE:
		if g.phase == Game.Phase.CARDS:
			if not whole_run:
				break
			out["log"].append("card %s" % Cards.describe(g.offers[0]["id"], g.offers[0]["rarity"]).split("\n")[0])
			g.choose_card(0)
			out["loops"] = g.loop + 1
			continue
		var k := 0
		if g.night == 0 or keep_building:
			var built := true
			while built and (keep_building or k < 3):
				built = false
				for s in spots:
					if g.try_build(order[(k + g.towers.size()) % 3], s):
						k += 1
						built = true
						break
		var label := "L%d N%d" % [g.loop + 1, g.night + 1]
		var was_loop := g.loop
		var was_night := g.night
		await _play_night(g)
		var result := "held"
		if g.phase == Game.Phase.CARDS or g.phase == Game.Phase.DONE:
			result = "BEAT BOSS" if g.loop_won else "LOST"
			if was_loop == 0 and out["lost_on"] == 7 and not g.loop_won:
				out["lost_on"] = was_night + 1
		out["log"].append("%s %s (towers %d)" % [label, result, g.towers.size()])
		print("        %s %s: towers %d, %s" % ["keep" if keep_building else "three", label, g.towers.size(), g.last_message])
	out["phase"] = g.phase
	g.queue_free()
	await process_frame
	return out


func _cards() -> void:
	# offers: rarity odds, no duplicates at the same or lower rarity, unbuilt systems never offered
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var counts := [0, 0, 0]
	var unbuilt := 0
	for i in range(2000):
		for o in Cards.offers({}, 3, rng):
			counts[o["rarity"]] += 1
			if not Cards.available(o["id"]):
				unbuilt += 1
	var n := float(counts[0] + counts[1] + counts[2])
	print("      rarity mix over %d offers: %.1f%% / %.1f%% / %.1f%%" % [n, counts[0] / n * 100, counts[1] / n * 100, counts[2] / n * 100])
	check("rarity odds near 70 / 25 / 5", absf(counts[0] / n - 0.7) < 0.03 and absf(counts[1] / n - 0.25) < 0.03 and absf(counts[2] / n - 0.05) < 0.015)
	check("cards for unbuilt systems are never offered", unbuilt == 0)
	var dup_bad := 0
	for i in range(500):
		for o in Cards.offers({"quick_fuse": 1}, 3, rng):
			if o["id"] == "quick_fuse" and o["rarity"] <= 1:
				dup_bad += 1
	check("a held card is only offered at a higher rarity", dup_bad == 0)
	check("loss offers are Common", Cards.offers({}, 1, rng, true).all(func(o): return o["rarity"] == 0))

	# effects: build towers with cards held and check their numbers
	var g := await _make_game()
	g.cards = {"quick_fuse": 2, "hot_coals": 1, "long_draw": 0, "sturdy_homes": 1, "deep_pockets": 0}
	g._start_loop("test")
	check("Deep Pockets: +30 starting trust", g.trust == GameConfig.START_TRUST + 30)
	check("Sturdy Homes Rare: houses 60 -> 90 HP", is_equal_approx(g.houses[0].max_hp, 90.0) and is_equal_approx(g.houses[0].hp, 90.0))
	g.trust = 1000
	g.try_build("fire", Vector2i(11, 11))
	g.try_build("brazier", Vector2i(11, 4))
	g.try_build("crossbow", Vector2i(5, 11))
	var f: Tower = g.towers[0]
	var b: Tower = g.towers[1]
	var c: Tower = g.towers[2]
	check("Quick Fuse Legendary: 40% faster and every 5th shot", is_equal_approx(f.interval, 1.5 / 1.4) and f.every_nth == 5)
	check("Hot Coals Rare: 6 damage per pulse, no patch", is_equal_approx(b.damage, 6.0) and not b.shot_mods.get("patch", false))
	check("Long Draw Common: range 7 cells", is_equal_approx(c.reach, 7 * GameConfig.CELL) and not c.hits_air)
	g.queue_free()
	await process_frame
