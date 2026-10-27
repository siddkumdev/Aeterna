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
	await _sell()
	await _requests()
	await _spells()
	await _mouse_hand_rules()
	await _warden()
	await _crews()
	await _guards()
	await _decor()
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
		gs.try_build("guard", Vector2i(3, 9))
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
	var order := ["fire", "crossbow", "guard", "airship"]
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
	g.cards = {"quick_fuse": 2, "shield_wall": 1, "long_draw": 0, "sturdy_homes": 1, "deep_pockets": 0}
	g._start_loop("test")
	check("Deep Pockets: +30 starting trust", g.trust == GameConfig.START_TRUST + 30)
	check("Sturdy Homes Rare: houses 60 -> 90 HP", is_equal_approx(g.houses[0].max_hp, 90.0) and is_equal_approx(g.houses[0].hp, 90.0))
	g.trust = 1000
	g.try_build("fire", Vector2i(11, 11))
	g.try_build("guard", Vector2i(11, 4))
	g.try_build("crossbow", Vector2i(5, 11))
	var f: Tower = g.towers[0]
	var b: Tower = g.towers[1]
	var c: Tower = g.towers[2]
	check("Quick Fuse Legendary: 40% faster and every 5th shot", is_equal_approx(f.interval, 1.5 / 1.4) and f.every_nth == 5)
	check("Shield Wall Rare: Guards 45 HP, cannot hit flyers", is_equal_approx(b.guard_hp, 45.0) and not b.guards_air)
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

	# Airship: shoots the Wisp down, ignores ground enemies; no limit on how many (Siddharth 2026-10-23)
	g = await _make_game()
	g.trust = 1000
	check("Airship builds", g.try_build("airship", Vector2i(11, 3)))
	check("second Airship builds", g.try_build("airship", Vector2i(4, 4)))
	check("a third Airship builds too (no cap)", g.try_build("airship", Vector2i(17, 4)) and not g.at_max("airship"))
	g._press_button("airship")
	check("the Airship sign still picks one up with 3 out", g.selected == "airship" and g._buttons["airship"]["label"].text.contains("35 trust"))
	g._press_button("airship")
	g._press_button("fire")
	check("other towers build with Airships out", g.selected == "fire" and g.try_build("fire", Vector2i(17, 7)))
	g._press_button("fire")
	g.trust = 10
	g._press_button("guard")
	check("a sign you cannot afford does not pick up a tower", g.selected == "")
	g.trust = 1000
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
	g.try_build("guard", Vector2i(11, 2))  # right where it leaves the forest
	g.start_night()
	g._spawn_queue.clear()
	var tu: Enemy = g._spawn(north, "tunneler")
	var full: float = tu.hp
	var was_under := true
	for i in range(200):  # 10 s, still underground, the Guard Tower on top of it
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
	check("Foresight: 3 tiers over loops 1-2 / 3-4 / 5", tiers == [1, 1, 2, 2, 3])

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
		for i in r1.size():
			var shown := 0
			for k in r2[i]["types"]:
				shown += r2[i]["types"][k]
				if k == "fog":
					fog_seen += 1
			ok1 = ok1 and not r1[i].has("types") and r1[i]["silhouettes"].size() == ceili(shown / 2.0)
			ok2 = ok2 and r2[i]["silhouettes"].size() == shown
			ok4 = ok4 and not r2[i].has("time") and not r3[i].has("time")
			ok3 = ok3 and r3[i].has("paths") and not (r3[i]["paths"].is_empty() and r3[i]["surface"].is_empty()) and not r2[i].has("paths")
	check("tier 1: silhouettes only, about half as many as are coming", ok1)
	check("tier 2: one silhouette each plus type counts", ok2)
	check("no tier shows departure times", ok4)
	check("tier 3: path ribbons for every group", ok3)
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

	# tier 3 rewrite: close one gap for the night
	g = await _make_game()
	check("no rewrite below tier 3", not g.close_spawn("north"))
	g.loop = 3
	check("no rewrite at tier 2 (loop 4)", not g.close_spawn("north"))
	g.loop = 4
	var before := g.night_plan()
	var from_north := before.filter(func(x): return x["spawn"] == "north").size()
	g.set_lens(true)
	check("tier 3: lens up shows a close sign at each gap with enemies", ["north", "east", "west"].any(func(k): return g._buttons["close_" + k]["node"].visible))
	g.set_lens(false)
	check("tier 3: closing the north gap works once", g.close_spawn("north") and not g.close_spawn("east"))
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


func _sell() -> void:
	var g := await _make_game()
	g.try_build("fire", Vector2i(11, 4))
	var t: Tower = g.towers[0]
	var before := g.trust
	check("the tower under any of its 4 cells is found", g.tower_at(Vector2i(12, 5)) == t and g.tower_at(Vector2i(13, 5)) == null)
	check("selling on the day it was built refunds the full cost", g.sell(t) and g.trust == before + 60 and g.towers.is_empty())
	check("its cells open up again (can build there)", g.can_build("fire", Vector2i(11, 4)))
	g.try_build("fire", Vector2i(11, 4))
	g.try_build("guard", Vector2i(4, 11))
	g.select("sell")
	check("Sell sign selects sell mode", g.selected == "sell")
	g.start_night()
	check("no selling during the night", not g.sell(g.towers[0]) and g.towers.size() == 2)
	g._clear_night()
	g._end_night()
	before = g.trust
	check("after a night: half back (Fire 30)", g.sell(g.towers[0]) and g.trust == before + 30)
	before = g.trust
	check("after a night: half back (Guard Tower 35)", g.sell(g.towers[0]) and g.trust == before + 35)
	g.queue_free()
	await process_frame


func _requests() -> void:
	var g := await _make_game()
	var kinds := {}
	var where := {}
	for r in g.requests:
		kinds[r.kind] = true
		where[r.house] = true
	check("day 1: 4 requests, one of each kind, on 4 different houses", g.requests.size() == 4 and kinds.size() == 4 and where.size() == 4)
	var by := {}
	for r in g.requests:
		by[r.kind] = r
	var C := GameConfig.CELL
	var t0 := g.trust

	var ch: HelpRequest = by["chimney"]
	var home: Vector3 = ch.prop.position
	g.grab_request(ch)
	ch.move_to(home + Vector3(0, 0.5 * C, 0))
	check("chimney: a small tug does nothing, the rubble goes back", not g.release_request() and ch.prop.position == home and not ch.done)
	g.grab_request(ch)
	ch.move_to(home + Vector3(0, 2.0 * C, 0))
	check("chimney: pulled out -> done, +15 trust", g.release_request() and ch.done and g.trust == t0 + 15)

	var bd: HelpRequest = by["bird"]
	g.grab_request(bd)
	bd.move_to(bd.prop.position + Vector3(2.5 * C, 0, 0))
	check("bird: moved off the chimney -> done, +10", g.release_request() and bd.done and g.trust == t0 + 25)

	var ln: HelpRequest = by["lantern"]
	g.grab_request(ln)
	ln.move_to(ln._goal + Vector3(4.0 * C, 0.02, 0))
	check("lantern: dropped away from its house stays on the grass", not g.release_request() and not ln.done and ln.prop.position.y == 0.0)
	g.grab_request(ln)
	ln.move_to(ln._goal + Vector3(0.5 * C, 0.02, 0))
	check("lantern: carried to its house -> done, +20", g.release_request() and ln.done and ln.prop.position == ln._goal and g.trust == t0 + 45)

	var ct: HelpRequest = by["cart"]
	var cart_home: Vector3 = ct.prop.position
	g.grab_request(ct)
	ct.move_to(cart_home + Vector3(1.0 * C, 0.03, 0))
	check("cart: stays on the ground while pushed", ct.prop.position.y == 0.0)
	check("cart: a short push does nothing", not g.release_request() and ct.prop.position == cart_home)
	g.grab_request(ct)
	ct.move_to(cart_home + Vector3(0, 0, 2.5 * C))
	check("cart: pushed clear -> done, +25", g.release_request() and ct.done and g.trust == t0 + 70)
	check("a finished request cannot be grabbed again", not g.grab_request(ch))

	# a tower built on or beside a loose lantern or cart carries it to open ground (it used to hide it)
	g.queue_free()
	await process_frame
	g = await _make_game()
	g.trust = 1000
	for kind in ["lantern", "cart"]:
		var rq: HelpRequest = g.requests.filter(func(x): return x.kind == kind)[0]
		var cc := NavGrid.local_to_cell(rq.prop.position)
		check("%s starts on open ground" % kind, g._open_at(cc) or kind == "cart")
		var built := g.try_build("fire", cc - Vector2i(0, 2)) or g.try_build("fire", cc + Vector2i(0, 1))  # a tower right beside it
		check("%s: the tower beside it was built" % kind, built)
		var after := NavGrid.local_to_cell(rq.prop.position)
		var hidden := false
		for t in g.towers:
			for f in NavGrid.footprint(t.cell, GameConfig.TOWER_SIZE):
				if absi(f.x - after.x) <= 1 and absi(f.y - after.y) <= 1:
					hidden = true
		check("%s is not on or beside a tower after building next to it" % kind, not hidden and not g.nav.kind.has(after))
	g.queue_free()
	await process_frame
	g = await _make_game()

	# night: requests go away and cannot be grabbed; a new set comes with the next day
	g.start_night()
	check("requests vanish at night", g.requests.is_empty())
	g._clear_night()
	g._end_night()
	check("the next day brings 4 new requests", g.requests.size() == 4 and g.requests.all(func(r): return not r.done))
	g.queue_free()
	await process_frame

	# VR hand: pinch at the prop, move the hand, let go
	g = await _make_game()
	var hand := GameHand.new()
	root.add_child(hand)
	await process_frame
	var bird: HelpRequest = g.requests.filter(func(r): return r.kind == "bird")[0]
	hand.global_position = bird.grab_point()
	g.hand_pressed(hand)
	check("a pinch at a request prop grabs it", g._held_req == bird)
	hand.global_position += Vector3(0.0, 0.05, 0.12)
	g._update_held()
	check("the prop follows the hand", bird.prop.global_position.distance_to(hand.global_position) < 0.001)
	var before := g.trust
	g.hand_released(hand)
	check("letting go far enough finishes it", bird.done and g.trust == before + 10)
	hand.global_position = g.board.global_position + Vector3(0, 0.3, 0)
	g.hand_pressed(hand)
	check("a pinch away from every prop grabs nothing", g._held_req == null)
	hand.queue_free()
	g.queue_free()
	await process_frame

	# dawn repair: damage carries over, +10 HP a dawn; a shuttered house opens again with 10 HP
	g = await _make_game()
	g.start_night()
	g._spawn_queue.clear()
	g.houses[0].damage(30.0)
	g.houses[1].damage(100.0)
	g._clear_night()
	g._end_night()
	check("dawn: a hurt house heals only 10 (60 - 30 + 10 = 40)", is_equal_approx(g.houses[0].hp, 40.0))
	check("dawn: a shuttered house opens again with 10 HP", not g.houses[1].is_shuttered and is_equal_approx(g.houses[1].hp, 10.0))
	g.queue_free()
	await process_frame


func _at(cx: int, cy: int, dx_cells := 0.0, dz_cells := 0.0) -> Vector3:
	return NavGrid.cell_centre(Vector2i(cx, cy)) + Vector3(dx_cells, 0, dz_cells) * GameConfig.CELL


func _still(g: Game, kind: String, at: Vector3) -> Enemy:
	## An enemy that stays where it is put (frozen with a very long slow), so spell numbers can be measured.
	var e: Enemy = g._spawn(NavGrid.local_to_cell(at), kind, at)
	e.offset = Vector3.ZERO
	e.slow(0.0001, 100000.0)
	if kind == "boss":
		e.hp = 200.0  # the spell tests use the boss as a damage sponge (it had 200 HP before the Warden's phases)
	return e


func _night_start(g: Game) -> void:
	g.start_night()
	g._spawn_queue.clear()
	_still(g, "boss", _at(20, 20))  # keeps the night from ending while a test runs


func _run(g: Game, seconds: float) -> void:
	var t := 0.0
	while t < seconds and g.phase == Game.Phase.NIGHT:
		g.step(0.05)
		t += 0.05


func _spells() -> void:
	var C := GameConfig.CELL
	var g := await _make_game()
	check("no spells in the day", not g.cast_spell("fire_orb", _at(5, 5)))
	_night_start(g)
	check("night: the spell signs show and the tower signs hide",
		g._buttons["spell_fire_orb"]["node"].visible and not g._buttons["fire"]["node"].visible and g.spells.tokens["rage"].visible)

	# Fire Orb: 12 damage in a 1-cell radius, ground and air; a tunneler underground is safe
	var a := _still(g, "boss", _at(5, 5))
	var b := _still(g, "boss", _at(5, 5, 0.6, 0.0))
	var far := _still(g, "boss", _at(5, 5, 3.0, 0.0))
	var wisp := _still(g, "wisp", _at(5, 5, 0.0, 0.5))
	var mole := _still(g, "tunneler", _at(5, 5, -0.4, 0.0))
	check("Fire Orb casts", g.cast_spell("fire_orb", _at(5, 5)))
	_run(g, 0.3)
	check("the orb is still in the air before 0.5 s", is_equal_approx(a.hp, 200.0))
	_run(g, 0.4)
	check("Fire Orb: 12 damage inside 1 cell (ground)", is_equal_approx(a.hp, 188.0) and is_equal_approx(b.hp, 188.0))
	check("Fire Orb: none outside the radius", is_equal_approx(far.hp, 200.0))
	check("Fire Orb hits flyers (a Wisp, 8 HP, dies)", not is_instance_valid(wisp) or not wisp.alive)
	check("a Tunneler underground cannot be hit", is_equal_approx(mole.hp, mole.stats["hp"]) and mole.underground)
	check("Fire Orb cools down 8 s, then is ready", not g.cast_spell("fire_orb", _at(5, 5)) and g.spells.cooldown["fire_orb"] > 7.0)
	_run(g, 8.0)
	check("ready again after 8 s", g.spells.is_ready("fire_orb"))

	# Boulder Drop: height scales damage (1 + h/8) and radius (1 + 0.5 h/8), fall time sqrt(2h/(0.25 g))
	var lo := _still(g, "boss", _at(12, 5))
	var near_lo := _still(g, "boss", _at(12, 5, 1.3, 0.0))
	var edge := _still(g, "boss", _at(12, 5, 1.8, 0.0))
	check("Boulder casts from 1 cell up", g.cast_spell("boulder", _at(12, 5), 1.0))
	_run(g, 0.3)
	check("h=1: 15 x 1.125 damage at the centre, inside r=1.59 cells", is_equal_approx(lo.hp, 200.0 - 15.0 * 1.125) and near_lo.hp < 200.0)
	check("h=1: a target 1.8 cells out is missed", is_equal_approx(edge.hp, 200.0))
	_run(g, 15.0)
	var hi := _still(g, "boss", _at(12, 12))
	var near_hi := _still(g, "boss", _at(12, 12, 1.8, 0.0))
	g.cast_spell("boulder", _at(12, 12), 8.0)
	_run(g, 0.4)
	check("h=8: still falling at 0.4 s (0.57 s fall)", is_equal_approx(hi.hp, 200.0))
	_run(g, 0.3)
	check("h=8: 15 x 2 = 30 damage, and the wider radius (2.25) reaches 1.8 cells", is_equal_approx(hi.hp, 170.0) and near_hi.hp < 200.0)
	_run(g, 15.0)

	# Storm Cloud: strikes every 1.5 s for 6 s, each strike chains to 2 more within 2 cells, air included
	var s1 := _still(g, "boss", _at(5, 12))
	var sw := _still(g, "wisp", _at(5, 12, 1.5, 0.0))
	var s2 := _still(g, "boss", _at(5, 12, 3.0, 0.0))
	var s3 := _still(g, "boss", _at(5, 12, 4.5, 0.0))
	check("Storm Cloud casts", g.cast_spell("storm", _at(5, 12)))
	_run(g, 0.4)
	check("no strike before 0.5 s", is_equal_approx(s1.hp, 200.0))
	_run(g, 0.3)
	check("first strike: 8 damage on the first target, the Wisp (air) and the next boss; not the 4th in line",
		is_equal_approx(s1.hp, 192.0) and (not is_instance_valid(sw) or not sw.alive) and is_equal_approx(s2.hp, 192.0) and is_equal_approx(s3.hp, 200.0))
	_run(g, 6.5)
	check("4 strikes in 6 s (0.5, 2.0, 3.5, 5.0): 32 damage, then the cloud is gone",
		is_equal_approx(s1.hp, 168.0) and g.spells._fx.filter(func(f): return f["kind"] == "storm").is_empty())
	_run(g, 6.0)

	# Rage: towers inside the ring shoot faster for 8 s; outside they do not
	g.queue_free()
	await process_frame
	var shots := []
	for rage in [false, true]:
		g = await _make_game()
		g.trust = 1000
		g.try_build("fire", Vector2i(11, 4))
		_night_start(g)
		_still(g, "boss", _at(11, 8))
		if rage:
			check("Rage casts over the tower", g.cast_spell("rage", g.towers[0].position))
			check("haste inside 1.5, outside 1.0",
				is_equal_approx(g.spells.haste_at(g.towers[0].position), 1.5) and is_equal_approx(g.spells.haste_at(_at(11, 4, 5.0, 0.0)), 1.0))
		_run(g, 8.0)
		shots.append(g.towers[0].shots_fired)
		if rage:
			_run(g, 0.2)
			check("Rage ends after 8 s", is_equal_approx(g.spells.haste_at(g.towers[0].position), 1.0))
		g.queue_free()
		await process_frame
	check("Rage: about 1.5x the shots in 8 s (%d vs %d)" % [shots[1], shots[0]], shots[1] >= shots[0] + 2 and float(shots[1]) / shots[0] < 1.8)

	# Root Ward: a potion over a house soaks 40 damage for 8 s
	g = await _make_game()
	_night_start(g)
	check("Root Ward over open ground is refused and costs no cooldown", not g.cast_spell("roots", _at(2, 2)) and g.spells.is_ready("roots"))
	check("Root Ward over a house", g.cast_spell("roots", g.house_point(0) + Vector3(C, 0, 0)) and is_equal_approx(g.houses[0].ward, 40.0))
	g.houses[0].damage(30.0)
	check("30 damage is soaked: HP unchanged, 10 left", is_equal_approx(g.houses[0].hp, g.houses[0].max_hp) and is_equal_approx(g.houses[0].ward, 10.0))
	g.houses[0].damage(30.0)
	check("then the rest gets through: 20 damage", is_equal_approx(g.houses[0].hp, g.houses[0].max_hp - 20.0) and g.houses[0].ward == 0.0)
	_run(g, 0.2)
	check("a used-up ward removes its roots", g.spells._fx.filter(func(f): return f["kind"] == "roots").is_empty())
	g.queue_free()
	await process_frame
	g = await _make_game()
	_night_start(g)
	g.cast_spell("roots", g.house_point(1))
	_run(g, 8.2)
	check("an unused ward fades after 8 s", g.houses[1].ward == 0.0)

	# Quick Hands card, night reset, the signs and the VR grab
	g.queue_free()
	await process_frame
	g = await _make_game()
	g.cards = {"quick_hands": 1}
	_night_start(g)
	g.cast_spell("fire_orb", _at(5, 5))
	check("Quick Hands Rare: cooldown 25% shorter (8 -> 6 s)", is_equal_approx(g.spells.cooldown["fire_orb"], 6.0))
	g._clear_night()
	g.phase = Game.Phase.DAY  # as if the night had ended
	g.start_night()
	check("a new night starts with every spell ready", g.spells.is_ready("fire_orb"))
	g.pick_spell("storm")
	check("a sign arms a spell", g.spell_sel == "storm")
	g.pick_spell("storm")
	check("the same sign puts it down again", g.spell_sel == "")
	var hand := GameHand.new()
	root.add_child(hand)
	await process_frame
	g._refresh_buttons()
	hand.global_position = g.spells.tokens["boulder"].global_position
	g.hand_pressed(hand)
	check("a pinch at the Boulder token picks it up", g._held_spell == "boulder")
	hand.global_position = g.board.to_global(Vector3(0.05, 0.4, 0.05))  # 8 cells above the board
	g._update_held()
	g.hand_released(hand)
	check("let go over the board casts it from the hand's height", not g.spells.is_ready("boulder") and g._held_spell == "")
	var fall := g.spells._fx.filter(func(f): return f["kind"] == "ball")
	check("the boulder falls for 0.57 s (8 cells, toy gravity)", fall.size() == 1 and absf(fall[0]["total"] - 0.571) < 0.01)
	hand.global_position = g.spells.tokens["rage"].global_position
	g.hand_pressed(hand)
	hand.global_position = g.board.to_global(Vector3(1.0, 0.1, 0.0))  # off the board
	g.hand_released(hand)
	check("let go off the board: nothing is cast", g.spells.is_ready("rage"))
	hand.queue_free()
	g.queue_free()
	await process_frame


func _mouse_hand_rules() -> void:
	var g := await _make_game()
	var hand := GameHand.new()
	root.add_child(hand)
	await process_frame
	var bird: HelpRequest = g.requests.filter(func(r): return r.kind == "bird")[0]
	var near := bird.grab_point() + Vector3(0.08, 0, 0)  # 8 cm away: out of the normal 5 cm reach, inside the easy 10 cm
	hand.global_position = near
	check("normal reach: 8 cm is too far to grab", not g.easy_reach and g.request_near(near) == null and not g.grabbable_near(near))
	g.easy_reach = true
	check("easy reach doubles the distances (5 cm -> 10 cm)", is_equal_approx(g.reach(0.05), 0.10))
	check("easy reach: the bubble would light up (something grabbable)", g.grabbable_near(near))
	g.select("fire")
	check("a tower armed: nothing counts as grabbable", g.placing() and not g.grabbable_near(near))
	g.hand_pressed(hand)
	check("a tower armed: a pinch near a prop does not grab it (it places instead)", g._held_req == null)
	g.select("")
	hand.global_position = near
	g.hand_pressed(hand)
	check("easy reach: the same pinch grabs it", g._held_req == bird)
	g.hand_released(hand)
	hand.queue_free()
	g.queue_free()
	await process_frame


func _warden() -> void:
	var g := await _make_game()
	g.night = GameConfig.BOSS_NIGHT
	g.start_night()
	g._spawn_queue.clear()
	var boss: Enemy = g._spawn(Vector2i(12, 3), "boss", _at(12, 3))
	boss.offset = Vector3.ZERO
	boss.slow(0.0001, 100000.0)
	g.warden = Warden.new(g, boss)
	var scale := boss.hp / GameConfig.ENEMIES["boss"]["hp"]
	var grunts0 := g.enemies.filter(func(e): return e.kind == "grunt").size()
	_run(g, GameConfig.WARDEN_SUMMON_EVERY + 0.2)
	var grunts1 := g.enemies.filter(func(e): return e.kind == "grunt").size()
	check("Warden phase 1: summons %d Grunts every %d s" % [GameConfig.WARDEN_SUMMON_COUNT, int(GameConfig.WARDEN_SUMMON_EVERY)],
		g.warden.phase == 1 and grunts1 - grunts0 == GameConfig.WARDEN_SUMMON_COUNT)
	boss.take_damage(boss.hp + 1.0)
	check("Warden: empty phase-1 HP starts phase 2, it lives, shielded, 3 crystals of 40 HP",
		boss.alive and g.warden.phase == 2 and boss.shielded and g.warden.crystals.size() == 3
		and g.warden.crystals.all(func(c): return c.hp == 40.0))
	var before := boss.hp
	boss.take_damage(500.0)
	boss.ignite(50.0, 2.0, false)
	_run(g, 0.5)
	check("Warden phase 2: no damage while a crystal stands", boss.alive and boss.hp == before)
	var c0: Enemy = g.warden.crystals[0]
	check("Warden phase 2: crystals ring it at %.0f cells" % GameConfig.WARDEN_CRYSTAL_RING,
		absf(Vector2(c0.position.x - boss.position.x, c0.position.z - boss.position.z).length() - GameConfig.WARDEN_CRYSTAL_RING * GameConfig.CELL) < 0.002)
	for c in g.warden.crystals.duplicate():
		c.take_damage(40.0)
		_run(g, 0.05)
		if g.warden.phase == 2:
			check("Warden phase 2: still shielded with %d crystal(s) left" % g.warden.crystals.size(), boss.shielded)
	check("Warden: all crystals broken starts phase 3, unshielded, %d HP x night/loop scale, enraged x%.1f" % [int(GameConfig.WARDEN_P3_HP), GameConfig.WARDEN_ENRAGE],
		g.warden.phase == 3 and not boss.shielded and absf(boss.hp - GameConfig.WARDEN_P3_HP * scale) < 0.01
		and absf(boss.stats["speed"] - GameConfig.ENEMIES["boss"]["speed"] * GameConfig.WARDEN_ENRAGE) < 0.0001
		and GameConfig.ENEMIES["boss"]["speed"] == 0.25)
	var wisps0 := g.enemies.filter(func(e): return e.kind == "wisp").size()
	_run(g, GameConfig.WARDEN_WISP_EVERY + 0.2)
	var wisps1 := g.enemies.filter(func(e): return e.kind == "wisp").size()
	check("Warden phase 3: %d Wisps rise every %d s" % [GameConfig.WARDEN_WISP_COUNT, int(GameConfig.WARDEN_WISP_EVERY)],
		wisps1 - wisps0 >= GameConfig.WARDEN_WISP_COUNT)
	boss.take_damage(boss.hp + 1.0)
	_run(g, 0.1)
	check("Warden: empty phase-3 HP kills it", not boss.alive and g.warden == null)
	g.queue_free()


func _crews() -> void:
	var g := await _make_game()
	g.trust = 500
	g.try_build("fire", Vector2i(5, 12))  # (6,12) now holds village props
	g.try_build("crossbow", Vector2i(11, 12))
	g.try_build("airship", Vector2i(17, 12))  # (16,13) now holds a village prop
	var kinds := g.towers.map(func(t): return t.crew.kind if t.crew else "")
	check("every tower has its crew: wizard, archer, pilot", kinds == ["wizard", "archer", "pilot"])
	var wiz: Tower = g.towers[0]
	var anchor_ok := wiz.crew.position.distance_to(Vector3(0, 0.072, 0.0215)) < 0.003  # the model's crew_anchor (Godot axes)
	check("the Wizard Tower's wizard stands at the model's crew anchor", anchor_ok)
	check("the archer and the pilot stand at their models' crew anchors too",
		g.towers[1].crew.position.distance_to(Vector3(0.033, 0.056, 0.033)) < 0.003 and g.towers[2].crew.position.distance_to(Vector3(0.0, 0.121, -0.012)) < 0.003)
	g.start_night()
	g._spawn_queue.clear()
	var target := _still(g, "grunt", _at(7, 9))
	wiz.cooldown = 0.0
	g.step(0.05)
	check("firing starts the crew's shot animation", wiz.crew._act > 0.0)
	check("a wizard's fireball leaves from his staff tip", wiz.last_from.distance_to(wiz.crew.hand_point()) < 0.001 and not g.shots.is_empty() and target != null)
	g.queue_free()


func _guards() -> void:
	var C := GameConfig.CELL
	var g := await _make_game()
	g.trust = 1000
	g.try_build("guard", Vector2i(11, 11))
	var gt: Tower = g.towers[0]
	check("a built Guard Tower has 3 Guards, each on its own free post touching the tower",
		gt.guards.size() == 3 and gt.guards.map(func(x): return x.index).size() == 3 and _distinct_posts(gt))
	var home := gt.guards[0].global_position
	g.cards = {}
	_night_start(g)
	for i in 100:
		g.step(0.05)
	check("with no enemy around, Guards stay at their posts (no wandering)", gt.guards[0].global_position.distance_to(home) < 0.001)
	# an enemy within sight: the Guard walks up, fights it, the enemy stops and fights back
	var post: Vector3 = gt.get_parent().to_local(gt.guards[0].post())  # board-local, like enemy positions
	var far := _still(g, "grunt", post + Vector3(3.5 * C, 0, 0))
	for i in 20:
		g.step(0.05)
	check("an enemy 3.5 cells from the post is out of sight and ignored", gt.guards[0].target == null)
	far.queue_free()
	g.enemies.erase(far)
	var e := _still(g, "grunt", post + Vector3(0, 0, 1.4 * C))
	e.hp = 20.0
	var hp0 := gt.guards[0].hp
	var met := false
	for i in 60:
		g.step(0.05)
		if e.alive and e.blocked_by != null:
			met = true
	check("an enemy within 2 cells: a Guard chases it and the enemy stops to fight it", met)
	for i in 400:
		g.step(0.05)
	check("Guards (4 damage a hit) kill a 20 HP Grunt", not e.alive)
	check("and the Grunt hurt the Guard that fought it", gt.guards.any(func(x): return x.hp < gt.guard_hp))
	for i in 400:
		g.step(0.05)
	check("then every Guard walks back to its post", gt.guards.all(func(x): return x.global_position.distance_to(x.post()) < 0.004 and x.state == "idle"))
	# an enemy that vanishes (freed) while a Guard chases it must not crash the Guard (seen by Siddharth 2026-10-26)
	var v := _still(g, "grunt", post + Vector3(0, 0, 1.4 * C))
	for i in 10:
		g.step(0.05)
	var chasing: bool = gt.guards.any(func(x): return x.state == "chase")
	g.enemies.erase(v)
	v.free()
	for i in 20:
		g.step(0.05)
	check("a chased enemy freed mid-chase: Guards drop the target and walk home, no crash", chasing and gt.guards.all(func(x): return x.target == null and x.state != "chase"))
	for i in 300:
		g.step(0.05)
	# ground only: a Wisp near the post is ignored; with Shield Wall Legendary it is hit
	var w := _still(g, "wisp", post + Vector3(0, 0, 1.0 * C))
	for i in 100:
		g.step(0.05)
	check("Guards cannot hit a flyer", w.alive and w.hp == w.stats["hp"] * (1.0 + GameConfig.HP_RAMP_PER_NIGHT * g.night) * (1.0 + GameConfig.LOOP_HP_STEP * g.loop))
	g.queue_free()
	await process_frame

	g = await _make_game()
	g.cards = {"shield_wall": 2}
	g.trust = 1000
	g._start_loop("test")
	g.try_build("guard", Vector2i(11, 11))
	gt = g.towers[0]
	check("Shield Wall Legendary: +100% HP and Guards can hit flyers", is_equal_approx(gt.guard_hp, 60.0) and gt.guards_air)
	_night_start(g)
	var w2 := _still(g, "wisp", gt.get_parent().to_local(gt.guards[0].post()) + Vector3(0, 0, 1.0 * C))
	for i in 400:
		g.step(0.05)
	check("and then they bring a Wisp down", not w2.alive)
	# a fallen Guard is replaced after `respawn` seconds
	var victim: Guard = gt.guards[0]
	victim.die()
	g.step(0.05)
	check("a dead Guard leaves a gap", gt.guards.size() == 2)
	for i in int(gt.respawn / 0.05) + 5:
		g.step(0.05)
	check("and is replaced after %.0f s, stepping out of the gate" % gt.respawn, gt.guards.size() == 3)
	# dawn: damaged Guards are healed
	gt.guards[0].hp = 5.0
	g._clear_night()
	g.phase = Game.Phase.NIGHT
	g.night = 0
	g._end_night()
	check("at dawn the Guards are back at full health", gt.guards.all(func(x): return is_equal_approx(x.hp, gt.guard_hp)))
	g.queue_free()
	await process_frame

	g = await _make_game()
	g.cards = {"friendly_faces": 1}
	g.trust = 1000
	g._start_loop("test")
	g.try_build("guard", Vector2i(11, 11))
	gt = g.towers[0]
	check("Friendly Faces Rare: 4 Guards, replacements 25% faster", gt.max_guards == 4 and gt.guards.size() == 4 and is_equal_approx(gt.respawn, 8.0 / 1.25))
	var gone := gt.guards[0]
	g.select("sell")
	g.sell(gt)
	await process_frame
	check("selling the tower takes its Guards with it", not is_instance_valid(gt) and not is_instance_valid(gone))
	g.queue_free()
	await process_frame


func _distinct_posts(t: Tower) -> bool:
	var seen := {}
	for g in t.guards:
		var c := NavGrid.local_to_cell(t.get_parent().to_local(g.post()))
		if seen.has(c) or t.game.nav.astar.is_point_solid(c):
			return false
		seen[c] = true
	return true


func _decor() -> void:
	var g := await _make_game()
	g.trust = 1000
	check("the village has prop cells", g.decor_cells.size() >= 10)
	var c: Vector2i = g.decor_cells[0]
	var top_left := c  # a 2 x 2 tower whose top-left cell is the prop cell
	check("a tower cannot be built on a village prop", not g.can_build("fire", top_left) and not g.try_build("fire", top_left))
	check("props never sit in the open centre block", g.decor_cells.all(func(d): return not VillageDresser.CENTRE_BLOCK.has_point(d)))
	check("the centre still takes a tower", g.can_build("fire", Vector2i(11, 11)))
	# enemies walk through props: the route does not treat a prop cell as solid
	check("props are not solid for the pathfinder", not g.nav.astar.is_point_solid(c))
	g._start_loop("again")
	check("the props still block towers after the time loop resets the grid", not g.can_build("fire", top_left))
	g.queue_free()
	await process_frame
