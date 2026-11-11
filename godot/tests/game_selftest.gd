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
	await _hand_reach()
	await _step2()
	await _foresight()
	await _sell()
	await _requests()
	await _spells()
	await _mouse_hand_rules()
	await _warden()
	await _elites()
	await _doom()
	await _endings()
	await _day_clock()
	await _quests()
	await _ledger()
	await _rim()
	await _crews()
	await _guards()
	await _decor()
	await _grass()
	await _vfx()
	await _village_life()
	await _audio()
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
	check("starts in day with the start faith", g.phase == Game.Phase.DAY and g.faith == GameConfig.START_FAITH)
	g.faith = 10
	check("unaffordable tower refused", not g.try_build("fire", Vector2i(1, 1)) and g.towers.is_empty())
	g.faith = GameConfig.START_FAITH
	await _play_night(g)
	var hurt := 0
	for h in g.houses:
		if h.hp < GameConfig.HOUSE_HP or h.is_shuttered:
			hurt += 1
	print("      no towers, night 1: phase %s, houses hit %d, standing %d" % [Game.Phase.keys()[g.phase], hurt, g.standing_houses().size()])
	check("undefended: Grunts reach and damage houses", hurt > 0 or g.phase != Game.Phase.NIGHT)
	check("losing loop 1 offers exactly 1 Common card", g.phase == Game.Phase.CARDS and g.offers.size() == 1 and g.offers[0]["rarity"] == 0)
	var offered: String = g.offers[0]["id"] if not g.offers.is_empty() else ""
	check("taking it rewinds to loop 2, day 1, faith and towers reset, card kept",
		g.choose_card(0) and g.loop == 1 and g.night == 0 and g.phase == Game.Phase.DAY and g.towers.is_empty() and g.cards.has(offered))
	g.queue_free()
	await process_frame

	# 2) A whole run (2 loops) by a bot that keeps building round the village and takes the first card offered.
	g = await _make_game()
	check("build costs faith", g.try_build("fire", Vector2i(16, 11)) and g.faith == GameConfig.START_FAITH - 60)
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
		gs.try_build("fire", Vector2i(16, 11))
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
	## 3 towers on day 1 near the village, then either nothing more or every day all faith spent on spots
	## round the village; takes the first card offered. Plays loop 1 only, or the whole run.
	## Returns {"lost_on": night lost in loop 1 (7 = beat the boss), "loops", "phase", "log"}.
	var g := await _make_game()
	var spots: Array[Vector2i] = [Vector2i(16, 11), Vector2i(11, 4), Vector2i(5, 11), Vector2i(17, 11), Vector2i(11, 18),
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
	check("Deep Pockets: +30 starting faith", g.faith == GameConfig.START_FAITH + 30)
	check("Sturdy Homes Rare: houses 60 -> 90 HP", is_equal_approx(g.houses[0].max_hp, 90.0) and is_equal_approx(g.houses[0].hp, 90.0))
	g.faith = 1000
	g.try_build("fire", Vector2i(16, 11))
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

	# Visual availability uses the same Card3D path for tower affordability and spell cooldowns.
	var visual := Card3D.new().setup(CardData.tower("fire"))
	root.add_child(visual)
	visual.set_glow(false)
	check("unavailable card greys its printed face", is_equal_approx(visual._print_materials[0].get_shader_parameter("unavailable"), 1.0))
	visual.set_glow(true)
	check("available card returns to its normal colour", is_equal_approx(visual._print_materials[0].get_shader_parameter("unavailable"), 0.0) \
		and (visual._body.material_override as StandardMaterial3D).albedo_color == Card3D.GOLD)
	visual.queue_free()
	await process_frame


func _hand_reach() -> void:
	## 2026-11-11 (Quest 3 test): the headset touch point is the drawn pinch, reach is wider there, nearest wins.
	check("headset card reach is wider than the old one (10 cm vs 6.4 cm)", is_equal_approx(GameConfig.XR_CARD_REACH, 0.10) 		and GameConfig.XR_CARD_REACH > GameConfig.TOUCH_REACH * 1.6 and GameConfig.XR_PLAQUE_PAD > 0.012)
	var g := await _make_game()
	g._xr = false
	g.easy_reach = true
	check("desktop card reach unchanged (6.4 cm x easy reach)", is_equal_approx(g.card_reach(), g.reach(GameConfig.TOUCH_REACH * 1.6)))
	g._xr = true
	g.easy_reach = false
	check("headset card reach is GameConfig.XR_CARD_REACH", is_equal_approx(g.card_reach(), GameConfig.XR_CARD_REACH))
	var tray := CardTray.new()
	root.add_child(tray)
	tray.set_cards([CardData.tower("fire"), CardData.tower("guard"), CardData.tower("crossbow")] as Array[Dictionary])
	await process_frame
	var c1: Card3D = tray.cards[1]
	var toward0 := (tray.cards[0].global_position - c1.global_position).normalized()
	var p := c1.global_position + toward0 * 0.025  # inside both cards' 10 cm reach, nearer the middle card
	check("wide reach: two cards in reach, the nearer one is picked", tray.cards[0].global_position.distance_to(p) <= 0.10 		and tray.card_near(p, GameConfig.XR_CARD_REACH) == c1)
	tray.queue_free()
	var at := Vector3(0, 1.2, 0.3)
	g._ui_follow = false
	check("UI rig ignores a small head move", g.ui_rig_step(at, at + Vector3(0.03, 0, 0), 0.016) == at)
	var moved := g.ui_rig_step(at, at + Vector3(0.2, 0, 0), 0.016)
	check("UI rig glides after a bigger head move", moved.x > at.x and moved.x < at.x + 0.2)
	check("UI rig snaps after a jump", g.ui_rig_step(at, at + Vector3(1, 0, 0), 0.016) == at + Vector3(1, 0, 0))
	var hand := GameHand.new()
	root.add_child(hand)
	await process_frame
	hand.global_position = Vector3(0.1, 1.0, 0.2)
	check("no tracked hand: touch point and ray origin are the node (controllers unchanged)", hand.touch_point() == hand.global_position 		and hand.ray_origin() == hand.global_position)
	var v := GodHandVisual.new()
	root.add_child(v)
	await process_frame
	v.set_pose_from(GodHandVisual.demo_joints(0.2, 1.0))
	hand.visual = v
	var mid := (v.thumb_tip_global() + v.index_tip_global()) * 0.5
	check("tracked hand: the touch point is the hand's own position unless DRAWN_PINCH_TOUCH is on", hand.touch_point().is_equal_approx(mid if GameConfig.DRAWN_PINCH_TOUCH else hand.global_position)
		and hand.ray_origin().is_equal_approx(hand.touch_point()))
	hand.visual = null
	v.queue_free()
	hand.queue_free()
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
	g.faith = 1000
	check("Airship builds", g.try_build("airship", Vector2i(11, 3)))
	check("second Airship builds", g.try_build("airship", Vector2i(4, 4)))
	check("a third Airship builds too (no cap)", g.try_build("airship", Vector2i(17, 4)) and not g.at_max("airship"))
	g._press_button("airship")
	check("the Airship sign still picks one up with 3 out", g.selected == "airship" and g._buttons["airship"]["label"].text.contains("35 faith"))
	g._press_button("airship")
	g._press_button("fire")
	check("other towers build with Airships out", g.selected == "fire" and g.try_build("fire", Vector2i(17, 7)))
	g._press_button("fire")
	g.faith = 10
	g._press_button("guard")
	check("a sign you cannot afford does not pick up a tower", g.selected == "")
	g.faith = 1000
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
	g.faith = 1000
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
	g.faith = 1000
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
	var before := g.faith
	check("the tower under any of its 4 cells is found", g.tower_at(Vector2i(12, 5)) == t and g.tower_at(Vector2i(13, 5)) == null)
	check("selling on the day it was built refunds the full cost", g.sell(t) and g.faith == before + 60 and g.towers.is_empty())
	check("its cells open up again (can build there)", g.can_build("fire", Vector2i(11, 4)))
	g.try_build("fire", Vector2i(11, 4))
	g.try_build("guard", Vector2i(4, 11))
	g.select("sell")
	check("Sell sign selects sell mode", g.selected == "sell")
	var sold: Tower = g.tower_at(Vector2i(12, 5))
	var meshes := ModelUtil.walk(sold).filter(func(n): return n is MeshInstance3D and n.mesh != null)
	var own: Array = meshes.map(func(n): return n.material_override)
	g._hover_board_cell = Vector2i(12, 5)
	g._update_ghost()
	check("the tower under the pointer turns solid red inside a ring", g._sell_mat != null and g._sell_mat.albedo_color.a == 1.0 and g._sell_ring.is_visible_in_tree() and not g._ghost_plate.visible and meshes.any(func(n): return n.material_override == g._sell_mat))
	check("the other tower does not", not ModelUtil.walk(g.towers[1]).any(func(n): return n is MeshInstance3D and n.material_override == g._sell_mat))
	g._hover_board_cell = Vector2i(0, 0)
	g._update_ghost()
	check("pointing away gives the tower its own look back", range(meshes.size()).all(func(i): return meshes[i].material_override == own[i]))
	g._hover_board_cell = Vector2i(12, 5)
	g._update_ghost()
	g.select("")
	check("leaving sell mode does too", range(meshes.size()).all(func(i): return meshes[i].material_override == own[i]))
	g.select("sell")
	g.start_night()
	check("no selling during the night", not g.sell(g.towers[0]) and g.towers.size() == 2)
	g._clear_night()
	g._end_night()
	before = g.faith
	check("after a night: half back (Fire 30)", g.sell(g.towers[0]) and g.faith == before + 30)
	before = g.faith
	check("after a night: half back (Guard Tower 35)", g.sell(g.towers[0]) and g.faith == before + 35)
	g.queue_free()
	await process_frame


func _requests() -> void:
	var g := await _make_game()
	g.force_quests(["cart", "lantern", "chimney", "bird"])
	var kinds := {}
	var where := {}
	for r in g.requests:
		kinds[r.kind] = true
		where[r.house] = true
	check("4 quests of 4 kinds on 4 different houses", g.requests.size() == 4 and kinds.size() == 4 and where.size() == 4)
	var by := {}
	for r in g.requests:
		by[r.kind] = r
	var C := GameConfig.CELL
	var t0 := g.faith

	var ch: HelpRequest = by["chimney"]
	var home: Vector3 = ch.prop.position
	g.grab_request(ch)
	ch.move_to(home + Vector3(0, 0.5 * C, 0))
	check("chimney: a small tug does nothing, the rubble goes back", not g.release_request() and ch.prop.position == home and not ch.done)
	g.grab_request(ch)
	ch.move_to(home + Vector3(0, 2.0 * C, 0))
	check("chimney: pulled out -> done, +15 faith", g.release_request() and ch.done and g.faith == t0 + 15)

	var bd: HelpRequest = by["bird"]
	g.grab_request(bd)
	bd.move_to(bd.prop.position + Vector3(2.5 * C, 0, 0))
	check("bird: moved off the chimney -> done, +10", g.release_request() and bd.done and g.faith == t0 + 25)

	var ln: HelpRequest = by["lantern"]
	g.grab_request(ln)
	ln.move_to(ln._goal + Vector3(4.0 * C, 0.02, 0))
	check("lantern: dropped away from its house stays on the grass", not g.release_request() and not ln.done and ln.prop.position.y == 0.0)
	g.grab_request(ln)
	ln.move_to(ln._goal + Vector3(0.5 * C, 0.02, 0))
	check("lantern: carried to its house -> done, +20", g.release_request() and ln.done and ln.prop.position == ln._goal and g.faith == t0 + 45)

	var ct: HelpRequest = by["cart"]
	var cart_home: Vector3 = ct.prop.position
	g.grab_request(ct)
	ct.move_to(cart_home + Vector3(1.0 * C, 0.03, 0))
	check("cart: stays on the ground while pushed", ct.prop.position.y == 0.0)
	check("cart: a short push does nothing", not g.release_request() and ct.prop.position == cart_home)
	g.grab_request(ct)
	ct.move_to(cart_home + Vector3(0, 0, 2.5 * C))
	check("cart: pushed clear -> done, +25", g.release_request() and ct.done and g.faith == t0 + 70)
	check("a finished request cannot be grabbed again", not g.grab_request(ch))

	# a tower built on or beside a loose lantern or cart carries it to open ground (it used to hide it)
	g.queue_free()
	await process_frame
	g = await _make_game()
	g.force_quests(["cart", "lantern", "chimney", "bird"])
	g.faith = 1000
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
	g.force_quests(["cart", "lantern", "chimney", "bird"])

	# night: requests go away and cannot be grabbed; a new set comes with the next day
	g.start_night()
	check("requests vanish at night", g.requests.is_empty())
	g._clear_night()
	g._end_night()
	check("the next day plans 4 new quests, none posted yet", g.quest_plan.size() == 4 and g.requests.is_empty())
	g.post_all_quests()
	check("posted, the day has 4 open quests", g.requests.size() == 4 and g.requests.all(func(r): return not r.done))
	g.queue_free()
	await process_frame

	# VR hand: pinch at the prop, move the hand, let go
	g = await _make_game()
	g.force_quests(["cart", "lantern", "chimney", "bird"])
	var hand := GameHand.new()
	root.add_child(hand)
	await process_frame
	var bird: HelpRequest = g.requests.filter(func(r): return r.kind == "chimney")[0]
	hand.global_position = bird.grab_point()
	g.hand_pressed(hand)
	check("a pinch at a request prop grabs it", g._held_req == bird)
	hand.global_position += Vector3(0.0, 0.05, 0.12)
	g._update_held()
	check("the prop follows the hand", bird.prop.global_position.distance_to(hand.global_position) < 0.001)
	var before := g.faith
	g.hand_released(hand)
	check("letting go far enough finishes it", bird.done and g.faith == before + GameConfig.REQUESTS["chimney"]["reward"])
	hand.global_position = g.board.global_position + Vector3(0, 0.3, 0)
	g.hand_pressed(hand)
	check("a pinch away from every prop grabs nothing", g._held_req == null)
	hand.queue_free()
	g.queue_free()
	await process_frame

	# dawn repair: damage carries over, +10 HP a dawn; a shuttered house opens again with 10 HP
	g = await _make_game()
	g.force_quests(["cart", "lantern", "chimney", "bird"])
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
		g.faith = 1000
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
	_run(g, 0.7)  # the roots take half a second to sink back
	check("a used-up ward removes its roots", g.spells._fx.filter(func(f): return f["kind"] == "roots").is_empty())
	g.queue_free()
	await process_frame
	g = await _make_game()
	_night_start(g)
	g.cast_spell("roots", g.house_point(1))
	_run(g, 8.2)
	check("an unused ward fades after 8 s", g.houses[1].ward == 0.0)

	# the critics' finds (2026-10-28): a second potion keeps its ward, a boulder's shadow never outlives it, Rage's ring is ticked
	g.queue_free()
	await process_frame
	g = await _make_game()
	_night_start(g)
	g.cast_spell("roots", g.house_point(0))
	_run(g, 1.0)
	g.spells.cooldown["roots"] = 0.0
	g.cast_spell("roots", g.house_point(0))
	_run(g, 1.0)
	check("a second Root Ward on the same house keeps its ward", is_equal_approx(g.houses[0].ward, 40.0) and g.spells._fx.filter(func(f): return f["kind"] == "roots").size() == 1)
	g.cast_spell("boulder", _at(5, 5), 8.0)
	g.spells.clear_effects()
	var shadows := 0
	for n in g.spells.get_children():
		if n is MeshInstance3D and n.mesh is CylinderMesh and not n.is_queued_for_deletion():
			shadows += 1
	check("a boulder's ground shadow is removed with the rest when effects clear (%d left)" % shadows, shadows == 0)
	g.cast_spell("rage", _at(8, 8))
	var rage_before: float = ((g.spells._fx.filter(func(f): return f["kind"] == "rage")[0]["flame"] as MeshInstance3D).material_override as ShaderMaterial).get_shader_parameter("progress")
	_run(g, 0.5)
	var rage_after: float = ((g.spells._fx.filter(func(f): return f["kind"] == "rage")[0]["flame"] as MeshInstance3D).material_override as ShaderMaterial).get_shader_parameter("progress")
	check("the Rage ring is ticked (its flame moves: %.2f -> %.2f)" % [rage_before, rage_after], not is_equal_approx(rage_before, rage_after))
	g.cast_spell("storm", _at(10, 10))
	var e := g._spawn(Vector2i(10, 10), "grunt", NavGrid.cell_centre(Vector2i(10, 10)))
	e.slow(0.0001, 1000.0)
	e.hp = 99999.0
	_run(g, 0.55)  # the first strike comes at 0.5 s and lasts 0.22 s
	var bolts := g.spells._fx.filter(func(f): return f["kind"] == "bolt")
	var bolt_ok := not bolts.is_empty()
	for bolt in bolts:
		bolt_ok = bolt_ok and (bolt["node"] as Node3D).get_child_count() > 0 and (bolt["node"].get_child(bolt["node"].get_child_count() - 1) as Node3D).global_position.distance_to(e.chest()) < 0.1
	check("storm bolts end on the enemy they hit (world space, not shifted by the board's position)", bolt_ok)
	var l: Lighting = g.lighting
	g._set_phase(Game.Phase.NIGHT, "")
	g._set_phase(Game.Phase.CARDS, "")
	_run(g, 0.0)
	await process_frame
	check("a night that ends inside the dusk leaves the day mood (no pending night)", l.current == "day" and (l._seq == null or not l._seq.is_valid()))

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
	g.force_quests(["cart", "lantern", "chimney", "bird"])
	var hand := GameHand.new()
	root.add_child(hand)
	await process_frame
	var bird: HelpRequest = g.requests.filter(func(r): return r.kind == "chimney")[0]
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
	g.loop = GameConfig.LOOPS_PER_RUN - 1  # the last loop: the Warden can die (loops 1-4 are the doomed fall, tested in _doom)
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
	check("Warden: empty phase-3 HP starts the final stand (phase 4): it lives, %d vines ring it" % Warden.WARDEN_VINES,
		boss.alive and g.warden.phase == 4 and g.warden.crystals.size() == Warden.WARDEN_VINES and absf(boss.hp - Warden.WARDEN_P4_HP * scale) < 0.01)
	boss.hp = 50.0
	_run(g, 1.0)
	check("Warden phase 4: it heals while a vine stands", boss.hp > 50.0)
	for c in g.warden.crystals.duplicate():
		c.take_damage(9999.0)
	_run(g, 0.1)
	var hp_no_vines := boss.hp
	_run(g, 1.0)
	check("Warden phase 4: no healing once the vines are down", is_equal_approx(boss.hp, hp_no_vines))
	boss.take_damage(boss.hp + 1.0)
	_run(g, 0.1)
	check("Warden: empty phase-4 HP kills it", not boss.alive and g.warden == null)
	g.queue_free()


func _elites() -> void:
	## 2026-11-11 (the user): the three scary bosses walk as elite enemies, one a night from the third night, never on the boss night.
	var g := await _make_game()
	var seen := {}
	for n in GameConfig.NIGHTS_PER_LOOP:
		g.night = n
		var elites := 0
		for grp in g.night_plan():
			for k in grp["enemies"]:
				if GameConfig.ELITES.has(k):
					elites += 1
					seen[k] = true
		check("night %d plans %d elite(s)" % [n + 1, elites], elites == (1 if n >= GameConfig.ELITE_FROM_NIGHT and n < GameConfig.BOSS_NIGHT else 0))
	g.queue_free()
	await process_frame


func _doom() -> void:
	## Night 5 of loops 1-4 always falls: the Warden cannot die, and DOOM_AT seconds in the houses go dark.
	var g := await _make_game()
	check("a loop is 5 nights and night 5 is the boss night", GameConfig.NIGHTS_PER_LOOP == 5 and GameConfig.BOSS_NIGHT == 4)
	g.night = GameConfig.BOSS_NIGHT
	g.start_night()
	g._spawn_queue.clear()
	var boss: Enemy = g._spawn(Vector2i(12, 3), "boss", _at(12, 3))
	boss.slow(0.0001, 100000.0)
	g.warden = Warden.new(g, boss)
	check("night 5 of loop 1 is doomed", g.is_doomed_night())
	boss.take_damage(boss.hp + 1.0)  # phase 1 ends
	g.warden.crystals.clear()
	g.warden.step(0.1)  # no crystals: enrage into phase 3
	boss.take_damage(boss.hp + 1.0)
	_run(g, 0.1)  # the final stand
	boss.take_damage(boss.hp + 1.0)
	_run(g, 0.1)
	check("doomed Warden keeps a sliver of life", boss.alive and boss.hp > 0.0 and g.warden != null)
	check("no horn before DOOM_AT", not g._doom_started)
	g.night_time = GameConfig.DOOM_AT - 0.2  # skip ahead: the test's own Wisps would otherwise wear the houses down first
	_run(g, 0.5)
	check("the horn sounds at DOOM_AT", g._doom_started)
	_run(g, GameConfig.DOOM_STEP * 4.0)
	check("the village falls and the loop is lost", g.phase != Game.Phase.NIGHT and not g.loop_won)
	g.queue_free()
	var f := await _make_game()
	f.loop = GameConfig.LOOPS_PER_RUN - 1
	f.night = GameConfig.BOSS_NIGHT
	check("the last loop is not doomed", not f.is_doomed_night())
	f.queue_free()


func _endings() -> void:
	var g := await _make_game()
	g.loop = GameConfig.LOOPS_PER_RUN - 1
	g.night = GameConfig.BOSS_NIGHT
	g._end_loop(true)
	check("beating the Warden in the last loop offers the two endings", g.phase == Game.Phase.CARDS and g.ending_choice and g.offers.size() == 2)
	check("choosing an ending finishes the run with its words", g.choose_card(1) and g.phase == Game.Phase.DONE and g.last_message.contains("Skotos"))
	g.queue_free()


func _village_life() -> void:
	var g: Game = load("res://scripts/game/game.gd").new()
	g.with_rig = false
	g.with_life = true
	root.add_child(g)
	await process_frame
	var life: VillageLife = g.life
	check("12 villagers, 2 to a house", life.villagers.size() == 12 and range(6).all(func(h): return life.villagers.filter(func(v): return v.home == h).size() == 2))
	check("they are all out on the first day", life.villagers.all(func(v): return v.visible))
	# the words (docs/STORY.md): every villager speaks, every loop has lines, nothing is empty
	check("12 distinct voices, one per villager", life.villagers.map(func(v): return v.voice).size() == 12 and life.villagers.map(func(v): return v.voice).filter(func(x): return x != "").size() == 12)
	var all_lines := true
	var banned := true
	var rx := RegEx.create_from_string("(?i)\\b(loop|time|rewind|reset)\\b")
	for vid in StoryText.ids():
		for lp in 5:
			for i in 4:
				var ln := StoryText.thought(vid, lp, i)
				all_lines = all_lines and ln != "" and ln.length() <= 110
				if lp < 3 and rx.search(ln) != null:
					banned = false
	check("every villager has 4 lines (max 110 chars) in each of the 5 loops", all_lines and StoryText.ids().size() == 12)
	check("no 'loop', 'time', 'rewind' or 'reset' in a villager's mouth before loop 4", banned)
	check("a dawn prayer for every loop and day", range(5).all(func(lp): return range(5).all(func(d): return StoryText.prayer(lp, d) != "")))
	check("Skotos has a dusk and a night-5 line in every loop", range(5).all(func(lp): return StoryText.warden("dusk_day1", lp) != "" and StoryText.warden("night5", lp) != ""))
	check("the first dawn prayer is Maren's first line", StoryText.prayer(0, 0).begins_with("Little god"))
	var tv: Villager = life.villagers[0]
	var t_line := g.tap_villager(tv)
	check("tapping a villager gives their first line for this loop", t_line == StoryText.thought(tv.voice, 0, 0) and tv.taps == 1)
	check("tapping again gives the next line", g.tap_villager(tv) == StoryText.thought(tv.voice, 0, 1))
	check("every model has a head, arms and legs", life.villagers.all(func(v): return v.rig.parts.has("head") and v.rig.parts.has("arm_l") and v.rig.parts.has("arm_r") and v.rig.parts.has("leg_l") and v.rig.parts.has("leg_r")))
	check("the forest's watchers wait by day", life.lurkers.size() >= 4)
	var trees_only := func(): return life.lurkers.all(func(l): return l["cell"].x in [1, GameConfig.SIZE - 2] or l["cell"].y in [1, GameConfig.SIZE - 2])
	var on_solid := false
	for i in 1200:  # a minute of the day
		life.tick(0.05)
		for v in life.villagers:
			if v.state == "go" and v._path.size() > 1:
				var c := NavGrid.local_to_cell(NavGrid.cell_centre(v._path[0]))
				on_solid = on_solid or (g.nav.kind.has(c) and g.nav.kind[c] != "spawn")
	check("a minute later the watchers are still by the tree line", trees_only.call())
	check("no one's route crosses a house, prop or the forest", not on_solid)
	var faith := g.faith
	var hp: float = g.houses[0].hp
	g.start_night()
	check("at nightfall the watchers go", life.lurkers.is_empty())
	check("at nightfall everyone runs", life.villagers.all(func(v): return v.state == "startle" or v.state == "inside"))
	for i in 200:  # 10 seconds is plenty at 6 cells a second
		life.tick(0.05)
	check("within 10 s all 12 are inside", life.villagers.all(func(v): return v.state == "inside" and not v.visible))
	check("running home changes no rule", g.faith == faith and g.houses[0].hp == hp)
	g.houses[0].damage(99999.0)
	g._end_night()
	check("after dawn the watchers are back", life.lurkers.size() >= 4)
	for i in 120:
		life.tick(0.05)
	check("at dawn all 12 come back out, a shuttered home too", life.villagers.all(func(v): return v.visible and v.state != "inside"))
	CharacterRig.step_legs = true
	var r: CharacterRig = life.villagers[2].rig
	r.anim = "walk"
	r.gait = 1.1
	var before: Transform3D = r.parts["leg_l"].transform
	r.tick(0.1)
	check("stepping legs move the leg parts", not r.parts["leg_l"].transform.is_equal_approx(before))
	CharacterRig.step_legs = false
	# someone halfway through a door when the day comes back still comes out
	g.start_night()
	var v: Villager = life.villagers[0]
	v.state = "enter"
	g.new_run(5)
	for i in 120:
		life.tick(0.05)
	check("whoever was at the door when day came back is out again", v.visible and v.state != "inside")
	g.queue_free()
	await process_frame
	await _real_models()


func _real_models() -> void:
	## With the rig on: enemies and crews wear Durva's models, die as bodies left behind, and the rules are the same.
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	await process_frame
	g.faith = 900
	g.cards = {}
	g.try_build("fire", Vector2i(5, 12))
	g.try_build("guard", Vector2i(18, 12))
	check("the wizard wears a model, with a staff tip for its flame", g.towers[0].crew._rig != null and g.towers[0].crew._tip != null)
	check("the Guards wear models", g.towers[1].guards.all(func(gd): return gd._crew._rig != null))
	var iw: IslandWorkers = g.island_workers
	check("3 of Durva's characters work under the island", iw.workers.size() == 3 and iw.workers.all(func(r): return r.is_inside_tree()))
	var pulses_before := iw.channels
	iw.channel_now(1)
	check("a channelling worker raises its tool", iw.workers[1].anim == "channel")
	var tool_raised := true
	for w in iw.workers:
		var keep: String = w.anim
		w.anim = "idle"
		w.tick(0.0)
		var low := iw._tool_tip(w).y
		w.anim = "channel"
		w.tick(0.0)
		tool_raised = tool_raised and iw._tool_tip(w).y > low + 0.005
		w.anim = keep
	iw.workers[1].anim = "channel"
	check("every worker's tool really goes up when it channels", tool_raised)
	for i in 40:
		iw.tick(0.05)
	check("the thread reaches the seed and the propulsion flares", iw.channels == pulses_before + 1 and iw._thrust._flare > 0.0)
	check("then the worker goes back to work", iw.workers[1].anim == "hammer" and not iw._thread.visible)
	g.start_night()
	g._spawn_queue.clear()
	var all_rigged := true
	for k in ["grunt", "scout", "splitter", "splitling", "wisp", "tunneler", "fog"]:
		var e: Enemy = g._spawn(Vector2i(12, 2), k)
		all_rigged = all_rigged and e._rig != null
		var hp0: float = GameConfig.ENEMIES[k]["hp"] * (1.0 + GameConfig.HP_RAMP_PER_NIGHT * g.night)
		check("%s: the model leaves its HP alone" % k, is_equal_approx(e.hp, hp0))
	check("every enemy kind wears its model", all_rigged)
	var boss: Enemy = g._spawn(Vector2i(12, 2), "boss")
	check("the Warden wears the first of its four forms", boss._rig != null and boss._rig.key == "eclipse_bloom_a")
	for k in GameConfig.ELITES:
		var el: Enemy = g._spawn(Vector2i(12, 2), k)
		check("elite %s wears its model and is not the Warden" % k, el._rig != null and not el.is_boss and el.stats["elite"])
	for i in 4:
		boss.set_form(i)
		check("Warden form %d is its own body (%s)" % [i + 1, Enemy.BOSS_FORMS[i]], boss._rig.key == Enemy.BOSS_FORMS[i] and boss._rig.parts.has("head"))
	var victim: Enemy = g.enemies[0]
	victim.take_damage(99999.0)
	check("a dead enemy leaves its toppling body behind", g._enemies_root.get_children().any(func(c): return c is CharacterRig))
	check("the body is not counted as an enemy", not g.enemies.has(victim))
	await process_frame
	g.queue_free()
	await process_frame


func _crews() -> void:
	var g := await _make_game()
	g.faith = 500
	g.try_build("fire", Vector2i(5, 12))  # (6,12) now holds village props
	g.try_build("crossbow", Vector2i(11, 4))  # the centre (11,11) is the shrine now
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
	check("a wizard's fireball leaves from the floating orb", wiz.last_from.distance_to(wiz._muzzle.global_position) < 0.001 and not g.shots.is_empty() and target != null)
	g.queue_free()


func _guards() -> void:
	var C := GameConfig.CELL
	var g := await _make_game()
	g.faith = 1000
	g.try_build("guard", Vector2i(16, 11))
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
	g.faith = 1000
	g._start_loop("test")
	g.try_build("guard", Vector2i(16, 11))
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
	g.faith = 1000
	g._start_loop("test")
	g.try_build("guard", Vector2i(16, 11))
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
	g.faith = 1000
	check("the village has prop cells", g.decor_cells.size() >= 10)
	var c: Vector2i = g.decor_cells[0]
	var top_left := c  # a 2 x 2 tower whose top-left cell is the prop cell
	check("a tower cannot be built on a village prop", not g.can_build("fire", top_left) and not g.try_build("fire", top_left))
	var shrine_cells := [Vector2i(11, 11), Vector2i(12, 11), Vector2i(11, 12), Vector2i(12, 12)]
	check("the shrine fills the four centre cells and no tower can stand there", shrine_cells.all(func(d): return g.decor_cells.has(d)) and not g.can_build("fire", Vector2i(11, 11)))
	check("props never sit in the centre block outside the shrine", g.decor_cells.all(func(d): return not VillageDresser.CENTRE_BLOCK.has_point(d) or shrine_cells.has(d)))
	check("the shrine stands on the plaza with its anchors", g.shrine != null and g.shrine.find_child("*__candle_anchor", true, false) != null and g.shrine.find_child("*__offering_anchor", true, false) != null)
	check("no cracks in loop 1, cracks from loop 2", not g._shrine_cracks.visible)
	g.loop = 1
	g._update_shrine()
	check("the shrine shows its cracks in loop 2", g._shrine_cracks.visible)
	g._helped = 3
	g._update_shrine()
	check("a honeycake for each kindness", g._cakes.size() == 3)
	check("the centre still takes a tower", g.can_build("fire", Vector2i(16, 11)))
	# enemies walk through props: the route does not treat a prop cell as solid
	check("props are not solid for the pathfinder", not g.nav.astar.is_point_solid(c))
	g._start_loop("again")
	check("the props still block towers after the time loop resets the grid", not g.can_build("fire", top_left))
	g.queue_free()
	await process_frame

func _grass() -> void:
	var g := await _make_game()
	g.faith = 1000
	var n: int = g.grass.tuft_count()
	check("the meadow has tufts, within the triangle budget (%d tufts, %d tris)" % [n, n * GrassField.TRIS_PER_TUFT], n > 1500 and n * GrassField.TRIS_PER_TUFT < 60000)
	g.grass.gust(Vector3.ZERO, Vector3(0.2, 0, 0))
	check("a Longbow gust is recorded, and a zero-length one is ignored", g.grass.gust_count() == 1 and (func(): g.grass.gust(Vector3.ZERO, Vector3.ZERO); return g.grass.gust_count() == 1).call())
	var fl: FlowerField = g.grass.flowers
	check("flowers and clover grow in the meadow (%d flowers, %d clover pads)" % [fl.flower_count(), fl.clover_count()], fl.flower_count() > 150 and fl.clover_count() > 150)
	var cell := Vector2i(5, 12)
	var under := 0
	for i in g.grass._cell.size():
		if g.grass._cell[i] in NavGrid.footprint(cell, GameConfig.TOWER_SIZE):
			under += 1
	# (headless Godot has no real MultiMesh buffer, so the check reads the field's own record of what it hid)
	g.try_build("fire", cell)
	var fp := NavGrid.footprint(cell, GameConfig.TOWER_SIZE)
	check("tufts under a tower are hidden (%d tufts sit on its 4 cells)" % under, under > 0 and fp.all(func(c): return g.grass._hidden.has(c)) and g.grass._hidden.size() == 4)
	g.sell(g.towers[0])
	check("and they come back when the tower is sold", g.grass._hidden.is_empty())
	g.try_build("crossbow", Vector2i(11, 4))  # the centre (11,11) is the shrine now
	g.start_night()
	g._spawn_queue.clear()
	_still(g, "grunt", _at(11, 9))
	g.towers[0].cooldown = 0.0
	g.step(0.05)
	check("a Longbow shot sends a gust through the grass", g.grass.gust_count() >= 1)
	g.queue_free()
	await process_frame

func _vfx() -> void:
	var g := await _make_game()
	g.faith = 500
	g.try_build("fire", Vector2i(5, 12))
	var wiz: Tower = g.towers[0]
	check("the Wizard Tower has its effects, with the orb at the model's orb anchor", wiz.fx != null and wiz.fx.orb != null and wiz.fx.orb.get_parent().name.ends_with("orb_anchor"))
	g.start_night()
	g._spawn_queue.clear()
	var foe := _still(g, "grunt", _at(7, 9))
	foe.hp = 99999.0
	wiz.cooldown = 0.5
	g.step(0.05)
	wiz.fx._process(0.016)
	check("while aiming, the orb charges up", wiz.fx.orb.charge > 0.0)
	wiz.cooldown = 0.0
	g.step(0.05)
	check("a shot sends a fireball with a glow and an ember trail", not g.shots.is_empty() and g.shots[0]._trail != null and g.shots[0]._glow != null)
	for i in 40:
		g.step(0.05)
	await process_frame
	check("the effects never change a rule: the grunt still took damage from the shot", foe.hp < 99999.0)
	g.queue_free()
	await process_frame
	var gr := await _make_game()
	gr.select("sell")
	gr.new_run(1)
	check("a new run clears sell mode and its ring", gr.selected == "" and not gr._sell_ring.is_visible_in_tree())
	gr.queue_free()
	await process_frame
	var g2 := await _make_game()
	g2.faith = 500
	g2.try_build("guard", Vector2i(5, 12))
	var gt: Tower = g2.towers[0]
	check("the Guard Tower has its effects (banner and gate leaves found)", gt.fx != null and gt.fx._banner != null and gt.fx._door_l != null and gt.fx._door_r != null)
	g2.start_night()
	g2._spawn_queue.clear()
	gt.fx._process(0.016)
	var closed: Basis = gt.fx._door_l.basis
	gt.guards[0].queue_free()
	gt.guards.remove_at(0)
	for i in 400:
		g2.step(0.05)
		gt.fx._process(0.05)
		if gt.fx._door_open > 0.5:
			break
	check("a Guard stepping out swings the gate leaves open", gt.fx._door_open > 0.5 and not gt.fx._door_l.basis.is_equal_approx(closed))
	g2.queue_free()
	await process_frame
	var g3 := await _make_game()
	g3.faith = 500
	g3.try_build("crossbow", Vector2i(5, 12))
	var bw: Tower = g3.towers[0]
	g3.start_night()
	g3._spawn_queue.clear()
	var foe3 := _still(g3, "grunt", _at(7, 9))
	foe3.hp = 99999.0
	bw.cooldown = 0.0
	g3.step(0.05)
	check("a Longbow shot rides a gust trail", not g3.shots.is_empty() and g3.shots[0]._trail != null)
	for i in 60:
		g3.step(0.05)
	await process_frame
	check("the wind never changes a rule: the grunt still took bolt damage", foe3.hp < 99999.0)
	g3.queue_free()
	await process_frame
	var g4 := await _make_game()
	g4.faith = 500
	g4.try_build("airship", Vector2i(5, 12))
	var sh: Tower = g4.towers[0]
	check("the Airship has its effects (burner and muzzle anchors found)", sh.fx != null and sh.fx._burner_at != null and sh.fx._muzzle_at != null)
	var home: Vector3 = sh.fx._ship.position
	g4.start_night()
	g4._spawn_queue.clear()
	var wisp := _still(g4, "wisp", _at(7, 9))
	wisp.hp = 99999.0
	sh.cooldown = 0.0
	g4.step(0.05)
	sh.fx._process(0.4)
	check("the balloon bobs (moves a little, under 3 mm)", sh.fx._ship.position.distance_to(home) > 0.0001 and sh.fx._ship.position.distance_to(home) < 0.003)
	check("an Airship shot is a flaming cannonball (painted head and tail)", not g4.shots.is_empty() and g4.shots[0]._glow != null and g4.shots[0]._trail != null)
	g4.queue_free()
	await process_frame
	g = await _make_game()
	var n := 0
	for i in 60:
		if VfxKit.burst(g.shots_root, Vector3.ZERO, Color.WHITE, Color.WHITE) != null:
			n += 1
	check("particle cap: at most %d bursts alive at once (%d started)" % [VfxKit.MAX_BURSTS, n], VfxKit.active_bursts() <= VfxKit.MAX_BURSTS)
	g.queue_free()
	await process_frame


func _audio() -> void:
	## The sound player: every sound the manifest lists has a file, unknown or missing ids stay silent, the cooldown
	## holds back a rapid repeat, and the game itself plays no sound without a rig.
	var g := await _make_game()
	check("audio: no player without the rig", g.audio == null)
	g.snd("place_thunk")  # must be a harmless no-op
	var a := AudioBank.new()
	root.add_child(a)
	a.setup()
	check("audio: manifest loaded (%d sounds)" % a.manifest.size(), a.manifest.size() >= 60)
	var missing := []
	for id in a.manifest:
		for f in a.manifest[id]["files"]:
			if not ResourceLoader.exists(AudioBank.DIR + f["file"]):
				missing.append(f["file"])
	check("audio: every listed file imported %s" % [missing], missing.is_empty())
	a.play("no_such_sound")
	check("audio: unknown id is silent", a.played == 0)
	a.play("pinch")
	check("audio: a known sound plays", a.played == 1)
	a.play("pinch")
	check("audio: the cooldown holds back a rapid repeat", a.played == 1)
	a.play("enemy_death", Vector3(0, 1, 0))
	check("audio: a spatial sound plays", a.played == 2)
	a.play("day_bed")
	check("audio: a loop is not a one-shot", a.played == 2)
	a.set_bed("day_bed")
	var s := a._stream("day_bed.wav", true)
	check("audio: a bed loops", s is AudioStreamWAV and (s as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD)
	check("audio: frequent sounds have several takes", a.manifest["pinch"]["files"].size() >= 4)
	var lims := 0
	var mb := AudioServer.get_bus_index("Master")
	for k in AudioServer.get_bus_effect_count(mb):
		if AudioServer.get_bus_effect(mb, k) is AudioEffectHardLimiter:
			lims += 1
	a._add_master_limiter()
	var lims2 := 0
	for k in AudioServer.get_bus_effect_count(mb):
		if AudioServer.get_bus_effect(mb, k) is AudioEffectHardLimiter:
			lims2 += 1
	check("audio: one limiter on Master, never added twice", lims == 1 and lims2 == 1)
	var amb := AudioServer.get_bus_index("ambience")
	a.play("village_bell")
	await create_timer(0.4).timeout
	check("audio: a story beat ducks the ambience", amb != -1 and AudioServer.get_bus_volume_db(amb) < AudioBank.BUS_DB["ambience"] - 3.0)
	# combo: quick kills climb the scale, a pause brings it back to the root
	await create_timer(1.3).timeout  # the spatial check above played enemy_death: let that combo run out first
	for i in range(3):
		a.play("enemy_death", Vector3(0, 1, 0))
		await create_timer(0.08).timeout
	check("audio: quick repeats of a combo sound climb the scale", a.combo_step("enemy_death") == 2)
	await create_timer(1.3).timeout
	a.play("enemy_death", Vector3(0, 1, 0))
	check("audio: after a pause the combo starts again", a.combo_step("enemy_death") == 0)
	# ambience one-shots: every pool id and every tower voice exists, and the scatter plays on its own
	var ids := []
	for e in Game.SCATTER_DAY + Game.SCATTER_NIGHT:
		ids.append(e["id"])
	for kind in GameConfig.TOWERS:
		var t := Tower.new()
		t.kind = kind
		t.cfg = GameConfig.TOWERS[kind]
		if t.voice() != "":
			ids.append("bark_%s_ready" % t.voice())
			ids.append("bark_%s_cheer" % t.voice())
		t.free()
	var absent := ids.filter(func(id): return not a.has(id))
	check("audio: every ambience one-shot and tower bark exists %s" % [absent], absent.is_empty() and ids.size() >= 14)
	var before := a.scattered
	a.set_scatter([{"id": "amb_bird", "where": "forest", "w": 1}], func(_w): return Vector3(0, 1, 0), Vector2(0.05, 0.1))
	await create_timer(2.4).timeout  # amb_bird's cooldown is 1 s: 2-3 really play, the rest are skipped
	var n_sc := a.scattered - before
	check("audio: the scatter plays ambience one-shots by itself, respecting the cooldown (%d)" % n_sc, n_sc >= 2 and n_sc <= 3)
	a.set_scatter([], Callable())
	a.queue_free()
	g.queue_free()
	# a kill is credited to the tower whose shot finished it (its crew cheers now and then)
	var gk := await _make_game()
	gk.try_build("fire", Vector2i(11, 3))
	var gr := await _night_with(gk, "grunt", GameConfig.SPAWNS["north"][1], 15.0)
	check("audio: a kill is credited to the tower that shot it", not gr.alive and gk.towers[0].kills == 1)
	var p := gk.ambience_point("forest")
	var lp: Vector3 = gk.board.to_local(p)
	var half := GameConfig.SIZE * GameConfig.CELL / 2.0
	check("audio: forest one-shots sit on the board's edge ring", absf(absf(lp.x) - half) < GameConfig.CELL or absf(absf(lp.z) - half) < GameConfig.CELL)
	gk.queue_free()


func _day_clock() -> void:
	## 2026-11-11 (the user): the day ends by itself, the hourglass hurries it, a held pinch sells a tower.
	var g := await _make_game()
	g.faith = 500
	g._tick_day(GameConfig.DAY_LENGTH - 30.0)
	check("the day runs but is not over before its length", g.phase == Game.Phase.DAY and absf(g.day_left() - 30.0) < 0.01)
	g.toggle_fast()
	check("the hourglass by day hurries the day (not the night speed)", g.day_fast and g.is_fast() and g.speed == 1.0)
	g._tick_day(1.5)
	check("a hurried day passes DAY_FAST times as fast", absf(g.day_left() - (30.0 - 1.5 * GameConfig.DAY_FAST)) < 0.01)
	g._tick_day(2.0)
	check("when the day runs out the night starts by itself", g.phase == Game.Phase.NIGHT and not g.day_fast)
	g.toggle_fast()
	check("the hourglass at night runs NIGHT_FAST (shown as 2x)", g.speed == GameConfig.NIGHT_FAST and g.is_fast())
	g._spawn_queue.clear()
	g.step(0.05)
	check("the next day starts from zero at normal speed", g.phase == Game.Phase.DAY and g.day_time == 0.0 and g.speed == 1.0)
	g.asleep = true
	g._tick_day(500.0)
	check("the day does not run while the island is asleep (title screen)", g.phase == Game.Phase.DAY and g.day_time == 0.0)
	g.asleep = false
	g.try_build("fire", Vector2i(16, 11))
	var t: Tower = g.towers[0]
	var before := g.faith
	check("a pinch on a built tower starts the crush", g.crush_start(t, null, Vector3.ZERO))
	g.crush_step(GameConfig.CRUSH_HOLD * 0.5)
	check("half a hold sells nothing and presses the tower down", g.towers.size() == 1 and t.scale.y < 1.0)
	g.crush_cancel()
	check("letting go early puts the tower back as it was", g.towers.size() == 1 and t.scale == Vector3.ONE and g._crush.is_empty())
	g.crush_start(t, null, Vector3.ZERO)
	g.crush_step(GameConfig.CRUSH_HOLD * 0.6)
	var sold := g.crush_step(GameConfig.CRUSH_HOLD * 0.6)
	check("a full hold sells the tower for its sell value", sold and g.towers.is_empty() and g.faith == before + GameConfig.TOWERS["fire"]["cost"])
	g.start_night()
	check("no crushing at night", not g.crush_start(null, null, Vector3.ZERO))
	g.queue_free()
	await process_frame


func _quests() -> void:
	## 2026-11-11 (the user): quests, at most 4 a day, posted one by one, cycling through every kind.
	var g := await _make_game()
	check("day 1 plans 4 quests and posts none at once", g.quest_plan.size() == 4 and g.requests.is_empty())
	check("the very first quest is the prayer", g.quest_plan[0]["kind"] == "prayer")
	var day1: Array = g.quest_plan.map(func(q): return q["kind"])
	check("a day's quests are 4 different kinds", day1.size() == 4 and day1.all(func(k): return day1.count(k) == 1))
	check("posted by the day's clock: 1 early, 2 by a quarter, 4 late", g.quests_posted_by(10.0) == 1 \
		and g.quests_posted_by(GameConfig.DAY_LENGTH * 0.3) == 2 and g.quests_posted_by(GameConfig.DAY_LENGTH * 0.9) == 4)
	var first := g.post_next_quest()
	check("post_next_quest posts one and leaves three planned", first != null and g.requests.size() == 1 and g.quest_plan.size() == 3)
	g.start_night()
	g._clear_night()
	g._end_night()
	var day2: Array = g.quest_plan.map(func(q): return q["kind"])
	var seen := {}
	for k in day1 + day2:
		seen[k] = true
	check("two days cycle through every kind once", seen.size() == GameConfig.REQUESTS.size())
	for k: String in GameConfig.REQUESTS:
		check("quest %s has its words and its how-to" % k, StoryText.task(HelpRequest.TASK_ID[k], "before") != "" and HelpRequest.HOW[k] != "")

	g.force_quests(["rain", "warm", "lights", "prayer"])
	var by := {}
	for r in g.requests:
		by[r.kind] = r
	var C := GameConfig.CELL
	var t0 := g.faith
	var rain: HelpRequest = by["rain"]
	g.grab_request(rain)
	rain.move_to(rain._goal + Vector3(5.0 * C, 0.08, 0))
	check("rain: the cloud let go away from the field goes back", not g.release_request() and not rain.done)
	g.grab_request(rain)
	rain.move_to(rain._goal + Vector3(0.5 * C, 0.08, 0))
	check("rain: the cloud let go over the field rains, +20", g.release_request() and rain.done and g.faith == t0 + 20)
	var warm: HelpRequest = by["warm"]
	var over: Vector3 = g.board.to_global(g.houses[warm.house].position + Vector3(0, 0.1, 0))
	check("warm: a hand over the house counts, far away does not", warm.hand_over_house(over) and not warm.hand_over_house(over + Vector3(0.4, 0, 0)))
	check("warm: half the hold is not enough", not warm.warm_step(HelpRequest.WARM_HOLD * 0.5, true) and not warm.done)
	warm.warm_step(1.0, false)
	check("warm: taking the hand away drains it", warm.progress < HelpRequest.WARM_HOLD * 0.5)
	check("warm: the full hold finishes it", warm.warm_step(HelpRequest.WARM_HOLD, true) and warm.done)
	var lights: HelpRequest = by["lights"]
	check("lights: three unlit lanterns stand by the door", lights._lamps.size() == 3 and not lights._lit.has(true))
	check("lights: two touched is not done", not lights.touch(lights._lamps[0].global_position, 0.03) and not lights.touch(lights._lamps[1].global_position, 0.03) and lights.progress == 2.0)
	check("lights: the third finishes it", lights.touch(lights._lamps[2].global_position, 0.03) and lights.done)
	var prayer: HelpRequest = by["prayer"]
	check("prayer: nothing to carry", not prayer.grabbable() and g.request_near(prayer.asker().global_position) == null)
	check("prayer: tapping someone else does not answer it", not prayer.answer(g))
	check("prayer: tapping the one who prays answers it", prayer.answer(prayer.asker()) and prayer.done)
	check("every quest has a gold mote, never a '!'", g.requests.all(func(r): return r._mote != null) and not FileAccess.get_file_as_string("res://scripts/game/help_request.gd").contains("HELP_MARKER_SCENE"))
	g.queue_free()
	await process_frame


func _ledger() -> void:
	## 2026-11-11 (the user): the stat screens, pulled up by turning the left palm up.
	var g := await _make_game()
	g.force_quests(["rain", "prayer"])
	var d := g.ledger_data()
	check("ledger data: day, loop, faith, homes, towers, spells, quests", d["night"] == 0 and d["loop"] == 0 and d["faith"] == g.faith \
		and d["houses"] == d["houses_total"] and d["towers"].size() == GameConfig.TOWER_ORDER.size() and d["spells"].size() == GameConfig.SPELL_ORDER.size() \
		and d["quests"].size() == 2 and d["quests"][0]["how"] != "" and d["quests"][0]["reward"] == 20)
	g.ledger = Ledger.new()
	g.ledger.game = g
	g.add_child(g.ledger)
	await process_frame
	var palm := Vector3(0, 1.0, -0.3)
	var eye := Vector3(0, 1.3, 0)  # the palm is 0.3 below and 0.42 away: inside PALM_REACH
	g.ledger_from_palm(0.1, true, palm, Vector3.UP, eye)
	check("a palm turned up for an instant does not open the ledger", not g.ledger.open)
	g.ledger_from_palm(GameConfig.PALM_UP_HOLD, true, palm, Vector3.UP, eye)
	check("held up for a moment, it opens above the palm", g.ledger.open and g.ledger.global_position.y > palm.y + 0.1)
	check("its face is toward the eye", g.ledger.global_basis.z.normalized().dot((eye - g.ledger.global_position).normalized()) > 0.9)
	g.ledger_from_palm(0.1, true, palm, Vector3(1, 0.4, 0).normalized(), eye)
	check("a tilted palm keeps it open", g.ledger.open)
	g.ledger_from_palm(0.1, true, palm, Vector3.DOWN, eye)
	check("palm turned away: it folds shut", not g.ledger.open)
	g.ledger_from_palm(1.0, false, palm, Vector3.UP, eye)
	check("no hand found: it stays shut", not g.ledger.open)
	g.asleep = true
	g.ledger_from_palm(1.0, true, palm, Vector3.UP, eye)
	check("it never opens on the title screen", not g.ledger.open)
	g.asleep = false
	g.ledger.set_open(true)
	check("the tabs turn the page and wrap", g.ledger.page == 0)
	g.ledger.turn(1)
	g.ledger.turn(-2)
	check("turning back from the first page reaches the last", g.ledger.page == LedgerPage.TABS.size() - 1)
	g.ledger.scale = Vector3.ONE
	var tab2 := LedgerPage.tab_rect(2)
	var local := Vector3((tab2.get_center().x / LedgerPage.SIZE.x - 0.5) * Ledger.W, (0.5 - tab2.get_center().y / LedgerPage.SIZE.y) * Ledger.H, 0)
	var world: Vector3 = g.ledger._quad.global_transform * local
	check("a fingertip on a tab finds that tab", g.ledger.tab_at_point(world, 0.03) == 2)
	check("a ray at a tab finds that tab", g.ledger.tab_at_ray(world + g.ledger.global_basis.z.normalized() * 0.3, -g.ledger.global_basis.z.normalized()) == 2)
	check("a point off the panel finds nothing", g.ledger.tab_at_point(world + Vector3(1, 0, 0), 0.03) == -1)
	g.queue_free()
	await process_frame


func _rim() -> void:
	## 2026-11-11 (the user): grab the table rim to move, turn and resize the island.
	var g := await _make_game()
	var edge: Vector3 = g.board.to_global(Vector3(Game.HALF + 0.04, 0, 0))
	check("the rim is just outside the island's edge, not on the grass or far away", g.on_rim(edge) 		and not g.on_rim(g.board.to_global(Vector3(0.2, 0, 0))) and not g.on_rim(g.board.to_global(Vector3(Game.HALF + 0.4, 0, 0))))
	var start: Transform3D = g.board.global_transform
	var one: Array[Vector3] = [edge]
	var moved: Array[Vector3] = [edge + Vector3(0.1, 0.05, -0.2)]
	var t := Game.rim_transform(start, one, moved)
	check("one hand drags the island with it", t.origin.is_equal_approx(start.origin + Vector3(0.1, 0.05, -0.2)) and t.basis.is_equal_approx(start.basis))
	t = Game.rim_transform(start, one, one, PI / 2.0)
	check("one hand turning turns it about the hand", absf(t.basis.get_euler().y - start.basis.get_euler().y - PI / 2.0) < 0.001 and (t * start.affine_inverse() * edge).is_equal_approx(edge))
	var two: Array[Vector3] = [edge, edge - Vector3(2.0 * (Game.HALF + 0.04), 0, 0)]
	var mid := (two[0] + two[1]) / 2.0
	var wide: Array[Vector3] = [mid + (two[0] - mid) * 1.5, mid + (two[1] - mid) * 1.5]
	t = Game.rim_transform(start, two, wide)
	check("two hands pulled apart make it bigger about their middle", is_equal_approx(t.basis.get_scale().x, 1.5) and (t * start.affine_inverse() * mid).is_equal_approx(mid))
	var huge: Array[Vector3] = [mid + (two[0] - mid) * 9.0, mid + (two[1] - mid) * 9.0]
	var tiny: Array[Vector3] = [mid + (two[0] - mid) * 0.1, mid + (two[1] - mid) * 0.1]
	check("the size stays within its limits", is_equal_approx(Game.rim_transform(start, two, huge).basis.get_scale().x, GameConfig.BOARD_SCALE.y) 		and is_equal_approx(Game.rim_transform(start, two, tiny).basis.get_scale().x, GameConfig.BOARD_SCALE.x))
	var turned: Array[Vector3] = [mid + (two[0] - mid).rotated(Vector3.UP, 0.5), mid + (two[1] - mid).rotated(Vector3.UP, 0.5)]
	t = Game.rim_transform(start, two, turned)
	check("two hands turning turn it, and it stays level", absf(t.basis.get_euler().y - start.basis.get_euler().y - 0.5) < 0.001 and absf(t.basis.y.normalized().dot(Vector3.UP) - 1.0) < 0.001)
	g.queue_free()
	await process_frame
