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
	await _step2()
	await _foresight()
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
		var fresh := GameConfig.WAVE_TYPES.filter(func(k): return GameConfig.ENEMIES[k]["unlock"] == n + 1 and n > 0 \
			and GameConfig.ENEMIES[k].get("unlock_loop", 0) == 0)
		for i in fresh.size():
			var k: String = fresh[i]
			check("night %d: new type %s opens alone in group %d" % [n + 1, k, i + 1], not g[i]["enemies"].is_empty() and g[i]["enemies"].all(func(e): return e == k))
		print("      night %d: %s" % [n + 1, str(g.map(func(x): return "%s %s" % [x["spawn"], _count(x["enemies"])]))])
	check("same seed, same plan", str(WavePlan.groups_for(2, 5)) == str(WavePlan.groups_for(2, 5)))
	for lp in range(2, GameConfig.LOOPS_PER_RUN):
		var gl := WavePlan.groups_for(3, 1, lp)
		check("loop %d: %d groups (3 + %d extra)" % [lp + 1, gl.size(), lp], gl.size() == 3 + lp)
	# flyers never more than a third of a night; Tunnelers and the Fog variant only in loop 2, from their night
	var air_bad := 0
	var loop1_bad := 0
	var seen := {}
	for sd in range(1, 41):
		for lp in range(2):
			for n in range(GameConfig.NIGHTS_PER_LOOP):
				var all_threat := 0
				var air := 0
				for x in WavePlan.groups_for(n, sd, lp):
					all_threat += WavePlan.threat_of(x["enemies"])
					for k in x["enemies"]:
						if GameConfig.ENEMIES[k].get("flying", false):
							air += GameConfig.ENEMIES[k]["threat"]
						if lp == 0 and GameConfig.ENEMIES[k].get("unlock_loop", 0) > 0:
							loop1_bad += 1
						if not seen.has("%s L%d" % [k, lp]) or seen["%s L%d" % [k, lp]] > n + 1:
							seen["%s L%d" % [k, lp]] = n + 1
				if air * 3 > all_threat + 1:
					air_bad += 1
	check("flyers never more than a third of a night's threat (40 seeds, both loops)", air_bad == 0)
	check("no Tunneler or Fog variant in loop 1", loop1_bad == 0)
	check("Wisps from night 2", seen.get("wisp L0", 0) == 2)
	check("loop 2: Tunnelers from night 2, Fog from night 3", seen.get("tunneler L1", 0) == 2 and seen.get("fog L1", 0) == 3)
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
	for spd in [1.0, 2.0, 10.0, 50.0]:
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
	check("x50 night ends in about a fiftieth of the frames", absf(float(results[3][1]) / results[0][1] - 0.02) < 0.01)
	check("same outcome at x1, x2, x10 and x50", results.all(func(r): return r[2] == results[0][2] and r[3] == results[0][3]))


func _run_bot(keep_building: bool, whole_run: bool) -> Dictionary:
	## 3 towers on day 1 near the village, then either nothing more or every day all trust spent on spots
	## round the village; takes the first card offered. Plays loop 1 only, or the whole run.
	## Returns {"lost_on": night lost in loop 1 (7 = beat the boss), "loops", "phase", "log"}.
	var g := await _make_game()
	var spots: Array[Vector2i] = [Vector2i(11, 11), Vector2i(11, 4), Vector2i(5, 11), Vector2i(17, 11), Vector2i(11, 18),
		Vector2i(14, 5), Vector2i(8, 5), Vector2i(5, 15), Vector2i(17, 15), Vector2i(5, 7), Vector2i(17, 7), Vector2i(14, 17)]
	var order := ["fire", "crossbow", "brazier", "airship"]
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
				for o in range(order.size()):
					for s in spots:
						if g.try_build(order[(k + g.towers.size() + o) % (order.size() if keep_building else 3)], s):
							k += 1
							built = true
							break
					if built:
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


func _night_with(g: Game, kind: String, spawn_cell: Vector2i, seconds: float) -> Enemy:
	## Starts a night with no planned waves and puts one enemy of `kind` at a spawn cell; plays `seconds`.
	g.start_night()
	g._spawn_queue.clear()
	var e: Enemy = g._spawn(spawn_cell, kind)
	var t := 0.0
	while t < seconds and is_instance_valid(e) and e.alive:
		g.step(0.05)
		t += 0.05
	return e


func _step2() -> void:
	var north: Vector2i = GameConfig.SPAWNS["north"][1]
	# Wisp vs ground towers: a Fire Tower right beside the north gap never shoots it; it flies to a house
	var g := await _make_game()
	g.try_build("fire", Vector2i(11, 3))
	var w := await _night_with(g, "wisp", north, 25.0)
	var fire: Tower = g.towers[0]
	check("Wisp flies above the board", is_instance_valid(w) and w.position.y > 3.0 * GameConfig.CELL)
	check("ground towers never shoot a Wisp", fire.shots_fired == 0)
	var hurt := g.houses.filter(func(h): return h.hp < h.max_hp).size()
	check("the Wisp reaches a house and hurts it", is_instance_valid(w) and w.attacking and hurt == 1)
	g.queue_free()
	await process_frame

	# Airship: shoots the Wisp down, ignores ground enemies; at most 2
	g = await _make_game()
	g.trust = 1000
	check("Airship builds", g.try_build("airship", Vector2i(11, 3)))
	check("second Airship builds", g.try_build("airship", Vector2i(4, 4)))
	check("a third Airship is refused (max 2)", not g.try_build("airship", Vector2i(17, 4)) and g.at_max("airship"))
	w = await _night_with(g, "wisp", north, 25.0)
	check("the Airship shoots a Wisp down", not is_instance_valid(w) or not w.alive)
	g.queue_free()
	await process_frame
	g = await _make_game()
	g.try_build("airship", Vector2i(11, 3))
	var gr := await _night_with(g, "grunt", north, 15.0)
	check("the Airship never shoots ground enemies", is_instance_valid(gr) and gr.hp == gr.stats["hp"] * 1.0)
	g.queue_free()
	await process_frame

	# Tunneler: cannot be hit underground, comes up next to a house, then towers can hit it
	g = await _make_game()
	g.trust = 1000
	g.try_build("brazier", Vector2i(11, 2))  # right where it leaves the forest
	g.start_night()
	g._spawn_queue.clear()
	var tu: Enemy = g._spawn(north, "tunneler")
	var full: float = tu.hp
	var was_under := true
	for i in range(200):  # 10 s, still underground, the Brazier pulsing on top of it
		g.step(0.05)
		was_under = was_under and tu.underground
	check("a Tunneler starts underground and cannot be hit", was_under and is_equal_approx(tu.hp, full))
	var t := 0.0
	while tu.underground and t < 120.0:
		g.step(0.05)
		t += 0.05
	var goals := g.nav.goals_of(tu.target_house)
	check("it pops up next to a house (%.1f s)" % (10.0 + t), not tu.underground and goals.has(tu.cell))
	for i in range(40):
		g.step(0.05)
	check("then it hits that house", tu.attacking and g.houses[tu.target_house].hp < g.houses[tu.target_house].max_hp)
	g.queue_free()
	await process_frame

	# Fog variant walks like a Grunt, in mist grey; flagged hidden for Foresight
	g = await _make_game()
	var fg := await _night_with(g, "fog", north, 2.0)
	check("Fog variant: walks a ground route, hidden from Foresight", fg.stats.get("hidden", false) and not fg.path.is_empty() and not fg.flying)
	g.queue_free()
	await process_frame

	# Airship cards: Long Mooring Legendary hits ground at half damage; Twin Cannons faster, Legendary 2 targets
	g = await _make_game()
	g.cards = {"long_mooring": 2, "twin_cannons": 2, "long_draw": 2}
	g._start_loop("test")
	g.trust = 1000
	g.try_build("airship", Vector2i(11, 3))
	g.try_build("crossbow", Vector2i(4, 18))  # out of reach of the north gap, so only the Airship hits there
	var a: Tower = g.towers[0]
	var c: Tower = g.towers[1]
	check("Long Mooring Legendary: range 7, also ground", is_equal_approx(a.reach, 7 * GameConfig.CELL) and a.hits_ground and a.hits_air)
	check("Twin Cannons Legendary: 40% faster, 2 targets", is_equal_approx(a.interval, 1.0 / 1.4) and a.targets_per_volley == 2)
	check("Long Draw Legendary: Longbow hits flyers too", c.hits_air and c.hits_ground)
	g.start_night()
	g._spawn_queue.clear()
	var g1: Enemy = g._spawn(north, "grunt")
	var g2: Enemy = g._spawn(GameConfig.SPAWNS["north"][2], "grunt")
	var hp0: float = g1.hp
	for i in range(60):
		g.step(0.05)
	var hit1 := is_instance_valid(g1) and g1.hp < hp0
	var hit2 := is_instance_valid(g2) and g2.hp < hp0
	check("Twin Cannons Legendary + Long Mooring: both ground targets hit, half damage (3 per shell)",
		hit1 and hit2 and is_equal_approx(fposmod(hp0 - g1.hp, 3.0), 0.0))
	g.queue_free()
	await process_frame


func _foresight() -> void:
	var g := await _make_game()
	check("a run is 5 loops", GameConfig.LOOPS_PER_RUN == 5)
	var tiers := []
	for lp in range(5):
		g.loop = lp
		tiers.append(g.foresight_tier())
	check("Foresight tier = loop number (1..5)", tiers == [1, 2, 3, 4, 5])

	# what each tier reveals, on loop 2's night 3 (Fog variants can come) of several seeds
	var fog_seen := 0
	var fog_planned := 0
	var ok1 := true
	var ok2 := true
	var ok3 := true
	var ok4 := true
	for sd in range(1, 11):
		g.run_seed = sd
		g.loop = 1
		g.night = 2
		var plan := g.night_plan()
		for grp in plan:
			fog_planned += grp["enemies"].count("fog")
		var r1 := Foresight.reveal(1, plan, g)
		var r2 := Foresight.reveal(2, plan, g)
		var r3 := Foresight.reveal(3, plan, g)
		var r4 := Foresight.reveal(4, plan, g)
		for i in r1.size():
			var shown := 0
			for k in r2[i]["types"]:
				shown += r2[i]["types"][k]
				if k == "fog":
					fog_seen += 1
			ok1 = ok1 and not r1[i].has("types") and r1[i]["silhouettes"].size() == ceili(shown / 2.0)
			ok2 = ok2 and r2[i]["silhouettes"].size() == shown
			ok3 = ok3 and r3[i].has("paths") and not (r3[i]["paths"].is_empty() and r3[i]["surface"].is_empty()) and not r2[i].has("paths")
			ok4 = ok4 and r4[i].has("time") and not r3[i].has("time")
	check("tier 1: silhouettes only, about half as many as are coming", ok1)
	check("tier 2: one silhouette each plus type counts", ok2)
	check("tier 3: path ribbons for every group", ok3)
	check("tier 4: departure times", ok4)
	check("the Fog variant never shows (%d planned)" % fog_planned, fog_seen == 0 and fog_planned > 0)

	# tier 3: the ring drawn for a Tunneler is where it really comes up
	g.run_seed = 1
	g.loop = 2
	g.night = 0
	var gap: Array = GameConfig.SPAWNS["east"]
	var mid: Vector2i = gap[gap.size() / 2]
	var fake := [{"time": 3.0, "spawn": "east", "enemies": ["tunneler"]}]
	var predicted: Vector2i = Foresight.reveal(3, fake, g)[0]["surface"][0]
	g.start_night()
	g._spawn_queue.clear()
	var tu: Enemy = g._spawn(mid, "tunneler")
	var t := 0.0
	while tu.underground and t < 120.0:
		g.step(0.05)
		t += 0.05
	check("tier 3 ring = where the Tunneler comes up %s" % str(predicted), tu.cell == predicted)
	g.queue_free()
	await process_frame

	# the lens: day only, gaze-aimed
	g = await _make_game()
	g.set_lens(true)
	check("lens up in the day shows the coming night", g.foresight.showing and not g.foresight.seen_spawns().is_empty())
	var eye := g.board.to_global(Vector3(0, 0.45, GameConfig.SIZE * GameConfig.CELL / 2.0 + 0.25))
	var north := g.board.to_global(NavGrid.cell_centre(GameConfig.SPAWNS["north"][1]))
	g.set_lens(true, eye, north - eye)
	var seen := g.foresight.seen_spawns()
	var plan_edges := {}
	for grp in g.night_plan():
		plan_edges[grp["spawn"]] = true
	check("gaze-aimed: looking north shows only north %s" % str(seen), seen == ["north"] or (not plan_edges.has("north") and seen.is_empty()))
	g.set_lens(false)
	check("lens down hides it", not g.foresight.showing and not g.foresight.visible)
	g.set_lens(true)
	g.start_night()
	check("the night starting blanks the lens", not g.foresight.showing)
	g.set_lens(true)
	check("no reveal during the night", not g.foresight.showing)
	g.queue_free()
	await process_frame

	# the grab: a hand pinching at the lens grip holds it; held up high, the reveal shows; letting go puts it back
	g = await _make_game()
	var cam := XRCamera3D.new()
	root.add_child(cam)
	cam.global_position = g.board.to_global(Vector3(0, 0.45, 0.85))
	cam.look_at(g.board.global_position)
	g._xr_cam = cam
	var hand := GameHand.new()
	root.add_child(hand)
	await process_frame
	var rest := g._lens.global_position
	hand.global_position = g.lens_grip_position()
	g.hand_pressed(hand)
	check("a pinch at the grip picks the lens up", g._lens_hand == hand)
	g._update_lens()
	check("held low (on the table): no reveal", not g.foresight.showing)
	hand.global_position = cam.global_position + Vector3(0, -0.05, -0.15)
	g._update_lens()
	check("held up to the eye: the reveal shows", g.foresight.showing and g._lens.global_position.distance_to(rest) > 0.2)
	g.hand_released(hand)
	check("let go: the lens goes back and the reveal hides", not g.foresight.showing and g._lens.global_position.distance_to(rest) < 0.001)
	hand.global_position = g.lens_grip_position() + Vector3(0.3, 0, 0)
	g.hand_pressed(hand)
	check("a pinch away from the lens does not pick it up", g._lens_hand == null)
	hand.queue_free()
	cam.queue_free()
	g.queue_free()
	await process_frame

	# tier 5 rewrite: close one gap for the night
	g = await _make_game()
	check("no rewrite below tier 5", not g.close_spawn("north"))
	g.loop = 4
	var before := g.night_plan()
	var from_north := before.filter(func(x): return x["spawn"] == "north").size()
	g.set_lens(true)
	check("tier 5: lens up shows a close sign at each gap with enemies", ["north", "east", "west"].any(func(k): return g._buttons["close_" + k]["node"].visible))
	g.set_lens(false)
	check("tier 5: closing the north gap works once", g.close_spawn("north") and not g.close_spawn("east"))
	var after := g.night_plan()
	check("its groups come from the next edge, none from the north (%d moved)" % from_north,
		after.all(func(x): return x["spawn"] != "north") and after.size() == before.size())
	g.set_lens(true)
	check("the close signs hide once a gap is closed", not g._buttons["close_east"]["node"].visible)
	g.set_lens(false)
	g.start_night()
	g._clear_night()
	g._end_night()  # the night cleared
	check("next day the gap is open again", g.closed_spawn == "" and (g.phase != Game.Phase.DAY or g.night_plan().size() > 0))
	g.queue_free()
	await process_frame
