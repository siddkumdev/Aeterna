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
	await _grove()
	await _elites()
	await _doom()
	await _endings()
	await _loops()
	await _review_fixes()
	await _day_clock()
	await _quests()
	await _new_quests()
	await _quest_guidance()
	await _ledger()
	await _rim()
	await _tray_rules()
	await _perf_fixes()
	await _visual_rendering_fixes()
	await _seated_experience()
	await _interactive_tutorial()
	await _crews()
	await _guards()
	await _decor()
	await _grass()
	await _vfx()
	await _village_life()
	await _audio()
	await _juice()
	await load("res://tests/input_selftest.gd").run(self)  # replay driver, god-hand fallback, pinch debounce, palm direction
	await _fake_bloom()
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
	for lp in range(2, 5):  # loops are endless; spot-check the first few
		var gl := WavePlan.groups_for(3, 1, lp)
		check("loop %d: %d groups (3 + %d extra)" % [lp + 1, gl.size(), lp], gl.size() == 3 + lp)
	# flyers never more than a third of a night; Tunnelers and the Fog variant only in loop 2, from their night
	var air_bad := 0
	var loop1_bad := 0
	var seen := {}
	for sd in range(1, 41):
		for lp in range(2):
			for n in range(GameConfig.LOOP_NIGHTS_MAX):
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
	check("loop 2: the unlocks follow the loop too, so Tunnelers and Fog are in from night 1 (a short loop still fields them)", seen.get("tunneler L1", 0) == 1 and seen.get("fog L1", 0) == 1)
	var short_types := {}
	for x in WavePlan.groups_for(0, 3, 3):
		for k in x["enemies"]:
			short_types[k] = true
	check("a 1-night loop 4 fields later enemy types, not only Grunts", short_types.size() > 1)
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
	g.settle_ms = 0
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
	check("a full run ends in an ending, taken when the statue offers it", run["phase"] == Game.Phase.DONE and run.get("ending", false))
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
	while g.phase != Game.Phase.DONE and g.loop < 8:  # endless loops: the bot also stops after 8 loops
		if g.phase == Game.Phase.CARDS:
			if not whole_run:
				break
			if g.ending_choice:  # loops are endless: the bot takes the first ending offered (loop 3 on)
				out["log"].append("ending offered at loop %d" % (g.loop + 1))
				out["ending"] = true
				g.choose_card(0)
				continue
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

	# Night 5 on a doomed loop earns a full 3-card Rare/Legendary draft; loop 2+ scales rarity odds & faith income
	var non_common := 0
	var non_common_l2 := 0
	var draft_three := true
	var dg := await _make_game()
	for sd_i in range(1, 31):
		dg.run_seed = sd_i
		dg.loop = sd_i % 2
		dg.loop_nights = 5
		dg.night = 4  # the fall night of a 5-night loop
		dg._end_loop(false)
		draft_three = draft_three and dg.offers.size() == 3
		for o in dg.offers:
			if o["rarity"] > 0:
				non_common += 1
				if dg.loop == 1:
					non_common_l2 += 1
	dg.loop = 0
	dg.night = 2
	dg.phase = Game.Phase.DAY
	dg.start_night()
	dg._spawn_queue.clear()
	var wb: Enemy = dg._spawn(Vector2i(12, 3), "boss", _at(12, 3))
	dg.warden = Warden.new(dg, wb)
	dg.warden.phase = 2
	dg._end_loop(false)
	var boss_p2_draft: bool = dg.offers.size() == 3
	check("reaching Night 5 or Warden P2+ on a doomed loop grants a 3-card draft with Rare/Legendary rolls (%d non-Common, %d L2)" % [non_common, non_common_l2],
		draft_three and boss_p2_draft and non_common > 0 and non_common_l2 > 0)
	dg.loop = 1
	dg.night = 0
	dg.phase = Game.Phase.DAY
	dg.faith = 0
	var f0 := dg.faith
	dg.force_quests(["prayer"])
	var ledger_reward: int = dg.requests[0].info()["reward"]
	dg.requests[0].done = true
	dg._pay_quest(dg.requests[0])
	var quest_l2 := dg.faith - f0
	dg.faith = 0
	dg._end_night()
	check("loop 2 faith income and ledger reward scale +20%% (quest 10->%d, ledger %d, dawn+clear 40->%d)" % [quest_l2, ledger_reward, dg.faith],
		quest_l2 == 12 and ledger_reward == 12 and dg.faith == 48)
	dg.queue_free()
	await process_frame

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
	var above_face := c1.to_global(Vector3(Card3D.W * 0.45, 0.0, 0.06))
	check("overlapping card reach is measured from each card face", c1.touch_distance(above_face) < c1.global_position.distance_to(above_face)
		and tray.card_near(above_face, GameConfig.XR_CARD_REACH) == c1)
	tray.queue_free()
	var bx := Transform3D(Basis.IDENTITY, Vector3(0, 0.75, -0.85))
	var ts := Game.tray_start_transform(bx, Vector3(0, 1.2, 0.3))
	check("tray start pose: on the headset side, TRAY_OUT past the edge, TRAY_SIDE to the right, above the board top, turned to the player, tipped up",
		is_equal_approx(ts.origin.z, -0.85 + Game.HALF + GameConfig.TRAY_OUT) and is_equal_approx(ts.origin.x, GameConfig.TRAY_SIDE) 		and ts.origin.y > 0.75 and ts.basis.z.dot(Vector3(0, 0, 1)) > 0.6 and ts.basis.y.y < 1.0 and ts.basis.y.z > 0.0)  # 2026-11-18: beside the near edge on the player's right, above the board top, turned to the eyes
	var left := Game.tray_start_transform(bx, Vector3(-2, 1.2, -0.85))
	check("tray start pose: the edge nearest the headset is chosen, not a fixed side", is_equal_approx(left.origin.x, -(Game.HALF + GameConfig.TRAY_OUT)))
	var turned_board := Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis.from_scale(Vector3(1.5, 1.5, 1.5)), Vector3(0, 0.75, -0.85))
	var tb := Game.tray_start_transform(turned_board, Vector3(0, 1.2, 0.5))
	check("tray start pose follows the board's size when it is placed (never overlapping the island)", is_equal_approx(tb.origin.z, -0.85 + Game.HALF * 1.5 + GameConfig.TRAY_OUT) or is_equal_approx(absf(tb.origin.x), 0.0))
	var held := Game.tray_held_transform(ts, Vector3(0.5, 0.8, 0.0), Vector3(0, -0.02, 0.01), Vector3(0.5, 1.3, 1.0))
	check("a held tray follows the hand, keeps its tilt and faces the headset", held.origin.is_equal_approx(Vector3(0.5, 0.78, 0.01)) and absf(held.basis.y.y - ts.basis.y.y) < 0.001 and held.basis.z.dot(Vector3(0, 0, 1)) > 0.95)
	var hand := GameHand.new()
	root.add_child(hand)
	await process_frame
	var poke_a := Node3D.new()
	poke_a.add_to_group(GameHand.POKE_GROUP)
	root.add_child(poke_a)
	check("hand poke targets are cached after their first group lookup",
		hand._poke_cache_dirty and hand._poke_candidates().has(poke_a) and not hand._poke_cache_dirty)
	var poke_b := Node3D.new()
	poke_b.add_to_group(GameHand.POKE_GROUP)
	root.add_child(poke_b)
	check("adding a pokable invalidates and refreshes the hand target cache",
		hand._poke_cache_dirty and hand._poke_candidates().has(poke_a) and hand._poke_candidates().has(poke_b))
	poke_a.queue_free()
	await process_frame
	check("removing a pokable invalidates and refreshes the hand target cache",
		hand._poke_cache_dirty and hand._poke_candidates().all(func(n): return is_instance_valid(n))
		and hand._poke_candidates().has(poke_b))
	poke_b.queue_free()
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
	check("tracked hand: direct target selection follows the visible pinch", hand.target_point().is_equal_approx(mid))
	# The hand interaction profile and joint distance both report one physical pinch. The joint source replaces the
	# duplicate runtime trigger so opening the fingers always produces one release.
	var logical_presses := [0]
	var logical_releases := [0]
	hand.pressed.connect(func(_h): logical_presses[0] += 1)
	hand.released.connect(func(_h): logical_releases[0] += 1)
	hand._down.clear()
	hand._pinching = false
	hand._press_key("trigger_click")
	v.pinch_strength = GameHand.PINCH_PRESS
	hand._update_pinch()
	check("joint pinch replaces the duplicate runtime trigger without pressing twice", logical_presses[0] == 1
		and hand._down.size() == 1 and hand._down.has("pinch"))
	v.pinch_strength = GameHand.PINCH_RELEASE
	hand._update_pinch()
	check("opening a joint pinch releases once without waiting for runtime trigger", logical_releases[0] == 1 and not hand.is_pressing())
	# a headset pinch must be held PRESS_HOLD before it counts, and a fist (grip_click) never presses (the user, 2026-11-18)
	hand._xr_live = true
	hand._down.clear()
	hand._pinching = false
	hand._arm_t = -1.0
	var presses_a: int = logical_presses[0]
	v.pinch_strength = 1.0
	hand._update_pinch(0.1)
	hand._update_pinch(0.05)
	check("a pinch closed for 0.15 s has not pressed yet", logical_presses[0] == presses_a and not hand.is_pressing())
	v.pinch_strength = 0.2
	hand._update_pinch(0.05)
	v.pinch_strength = 1.0
	hand._update_pinch(0.1)
	check("a pinch that opens before the hold starts over and does not press", logical_presses[0] == presses_a)
	hand._update_pinch(0.25)
	check("a pinch held past PRESS_HOLD presses once", logical_presses[0] == presses_a + 1 and hand.is_pressing())
	v.pinch_strength = GameHand.PINCH_RELEASE
	hand._update_pinch(0.05)
	hand._release_wait = -1.0
	hand._down.clear()
	var visual_was := hand.visual.ever_live
	hand.visual.ever_live = true
	hand.button_pressed.emit("grip_click")
	check("a fist (grip_click) on a bare tracked hand never presses", not hand.is_pressing())
	hand.visual.ever_live = visual_was
	hand._xr_live = false
	# tracking lost: the hand keeps its pose only through the blink grace, then is hidden and takes part in nothing
	v.controller = hand
	v.apply_tracking(true, 0.016)
	check("tracked hand: visible, counts as live", v.tracked and v.ever_live and v.visible and v._bones.visible and not hand.is_lost())
	v.apply_tracking(false, GodHandVisual.LOST_GRACE * 0.5)
	check("tracking blink within the grace: the last pose stays drawn", v.tracked and v.visible)
	v.apply_tracking(false, GodHandVisual.LOST_GRACE * 0.6)
	check("tracking lost beyond the grace: mesh, glows and orb hidden", not v.tracked and not v.visible and not v._bones.visible and not v._balls.visible and not v._orb.visible)
	check("a lost hand is_lost and takes no press", hand.is_lost())
	hand._press_key("trigger_click")
	check("a lost hand cannot press", not hand.is_pressing())
	v.apply_tracking(true, 0.016)
	check("tracking returns: visible again at once, no longer lost", v.tracked and v.visible and v._bones.visible and not hand.is_lost())
	check("frozen joints past the grace with no aim pose count as stale", GodHandVisual.is_stale(GodHandVisual.LOST_GRACE + 0.1, true))
	check("frozen joints with a live aim pose (simulator) are not stale", not GodHandVisual.is_stale(5.0, false) and not GodHandVisual.is_stale(0.1, true))
	v.apply_tracking(false, 1.0)
	# frozen joints: identical past the grace with no aim pose is lost; changing joints or an aim pose is not
	var j0 := GodHandVisual.demo_joints(0.2, 0.0)
	v.set_pose_from(j0)
	var same_o: Array = []
	var moved_o: Array = []
	for t in j0:
		same_o.append((t as Transform3D).origin)
		moved_o.append((t as Transform3D).origin + Vector3(0, 0.001, 0))
	var st := 0.0
	for i in 5:
		st = v.still_time(same_o, st, GodHandVisual.LOST_GRACE * 0.3)
	check("identical joints for longer than the grace: stale without an aim pose", GodHandVisual.is_stale(st, true))
	check("identical joints but the aim pose exists: not stale", not GodHandVisual.is_stale(st, false))
	check("joints that change reset the still timer", v.still_time(moved_o, st, 0.1) == 0.0 and not GodHandVisual.is_stale(v.still_time(moved_o, st, 0.1), true))
	# a hold is cancelled once when the hand is lost, and a late release leaves nothing stuck
	v.apply_tracking(true, 0.016)
	v.apply_tracking(false, 1.0)
	var cancels := [0]
	var releases := [0]
	hand.cancelled.connect(func(_h): cancels[0] += 1)
	hand.released.connect(func(_h): releases[0] += 1)
	hand._down = {"trigger_click": true, "pinch": true}
	hand._pinching = true
	hand._update_pinch()
	hand._update_pinch()
	check("hold in progress when the hand is lost: cancelled exactly once, never released", cancels[0] == 1 and releases[0] == 0 and not hand.is_pressing())
	hand._release_key("trigger_click")
	check("a release arriving after the loss leaves nothing stuck and emits nothing", not hand.is_pressing() and cancels[0] == 1 and releases[0] == 0)
	hand._poking[12345] = true
	hand._update_poke()
	check("poke state is clear while the hand is not tracked", hand._poking.is_empty())
	# orb: a real controller always shows it (also after hands), hands hide it again
	var ov := GodHandVisual.new()
	ov.ever_live = true
	check("hands used earlier, then a controller with a pose: orb shows", ov.orb_wanted(true, true))
	check("lost hand (no controller): no orb", not ov.orb_wanted(true, false) and not ov.orb_wanted(false, true))
	ov.tracked = true
	check("back on hands: orb hidden", not ov.orb_wanted(true, true))
	ov.tracked = false
	ov.ever_live = false
	check("a never-tracked hand with a pose (simulator) keeps its orb", ov.orb_wanted(true, false))
	ov.free()
	var orb_hand := GodHandVisual.new()  # never tracked (controllers only): no hidden hand, nothing lost
	root.add_child(orb_hand)
	await process_frame
	var cvis := GameHand.new()
	root.add_child(cvis)
	cvis.visual = orb_hand
	check("a hand never tracked is not 'lost' (controllers behave as before)", not cvis.is_lost())
	cvis.visual = null
	cvis.queue_free()
	orb_hand.queue_free()
	hand.visual = null
	v.queue_free()
	hand.queue_free()
	g.queue_free()
	await process_frame

	# A4: each tracked hand can hold and cast a different physical spell card independently.
	var rig_game: Game = load("res://scripts/game/game.gd").new()
	rig_game.with_rig = true
	root.add_child(rig_game)
	for i in 3:
		await process_frame
	_night_start(rig_game)
	var fire_card: Card3D = rig_game._tray.cards.filter(func(c): return c.data.get("id", "") == "fire_orb")[0]
	var boulder_card: Card3D = rig_game._tray.cards.filter(func(c): return c.data.get("id", "") == "boulder")[0]
	var spell_hand_a := GameHand.new()
	var spell_hand_b := GameHand.new()
	root.add_child(spell_hand_a)
	root.add_child(spell_hand_b)
	await process_frame
	spell_hand_a.global_position = fire_card.global_position
	rig_game.hand_pressed(spell_hand_a)
	spell_hand_b.global_position = boulder_card.global_position
	rig_game.hand_pressed(spell_hand_b)
	check("one spell card can be held in each hand at the same time",
		rig_game._held_spell_cards.size() == 2 and rig_game._held_spell_cards.get(spell_hand_a) == fire_card \
		and rig_game._held_spell_cards.get(spell_hand_b) == boulder_card and fire_card.lifted and boulder_card.lifted)
	var faith_before := rig_game.faith
	spell_hand_a.global_position = rig_game.board.to_global(Vector3(-0.05, 0.15, 0.0))
	spell_hand_b.global_position = rig_game.board.to_global(Vector3(0.05, 0.15, 0.0))
	rig_game._update_held()
	rig_game.hand_released(spell_hand_a)
	check("releasing one spell casts only it and leaves the other hand holding",
		is_equal_approx(rig_game.spells.cooldown["fire_orb"], GameConfig.SPELLS["fire_orb"]["cooldown"]) \
		and rig_game.spells.is_ready("boulder") and not rig_game._held_spell_cards.has(spell_hand_a) \
		and rig_game._held_spell_cards.get(spell_hand_b) == boulder_card and boulder_card.lifted)
	rig_game.hand_released(spell_hand_b)
	check("the second spell keeps its own existing cooldown and neither spell costs faith",
		is_equal_approx(rig_game.spells.cooldown["fire_orb"], GameConfig.SPELLS["fire_orb"]["cooldown"]) \
		and is_equal_approx(rig_game.spells.cooldown["boulder"], GameConfig.SPELLS["boulder"]["cooldown"]) \
		and rig_game.faith == faith_before and rig_game._held_spell_cards.is_empty())
	spell_hand_a.queue_free()
	spell_hand_b.queue_free()
	rig_game.queue_free()
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

	# Airship: shoots flyers first, shells ground enemies at half damage when no flyer is in range; capped at max 2
	g = await _make_game()
	g.faith = 1000
	check("Airship builds", g.try_build("airship", Vector2i(11, 3)))
	check("second Airship builds", g.try_build("airship", Vector2i(4, 4)))
	check("a third Airship is blocked at max 2", not g.try_build("airship", Vector2i(17, 4)) and g.at_max("airship"))
	g._press_button("airship")
	check("the Airship sign cannot pick one up at max 2", g.selected == "")
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
	var gr := await _night_with(g, "grunt", north, 6.0)
	check("Airship shells ground enemies at half damage (4 per shell) when no flyers are in range",
		is_instance_valid(gr) and gr.hp < gr.stats["hp"] and is_equal_approx(fposmod(gr.stats["hp"] - gr.hp, 4.0), 0.0))
	g.queue_free()
	await process_frame

	# Airship prioritizes flyers over closer ground enemies; Wizard Tower splashes nearby ground enemies
	g = await _make_game()
	g.faith = 1000
	g.try_build("airship", Vector2i(10, 4))
	g.try_build("fire", Vector2i(4, 10))
	_night_start(g)
	var gr_close := _still(g, "grunt", _at(10, 6))
	var wi_far := _still(g, "wisp", _at(10, 7, 0.5, 0.0))
	wi_far.hp = 16.0  # survives 1 shot (8 dmg) so both volleys in 1.5 s must prioritize the flyer
	var wiz_a := _still(g, "grunt", _at(4, 13))
	var wiz_b := _still(g, "grunt", _at(4, 13, 0.4, 0.0))
	wiz_a.hp = 100.0
	wiz_b.hp = 100.0
	_run(g, 1.5)
	check("Airship prioritizes flyers over closer ground enemies",
		(not is_instance_valid(wi_far) or not wi_far.alive) and is_instance_valid(gr_close) and is_equal_approx(gr_close.hp, gr_close.stats["hp"]))
	check("Wizard Tower fireball deals 50%% splash to nearby ground enemies (14 primary / 7 splash)",
		is_instance_valid(wiz_a) and is_instance_valid(wiz_b) and wiz_a.hp < 100.0 and wiz_b.hp < 100.0 and not is_equal_approx(wiz_a.hp, wiz_b.hp))
	g.queue_free()
	await process_frame

	g = await _make_game()
	g.faith = 1000
	g.try_build("fire", Vector2i(4, 10))
	_night_start(g)
	var wiz_sp := _still(g, "splitter", _at(4, 12))
	wiz_sp.hp = 1.0
	_run(g, 0.5)
	var splitlings := g.enemies.filter(func(x): return is_instance_valid(x) and x.kind == "splitling")
	check("killing a Splitter with Wizard splash does not splash its newly spawned Splitlings",
		(not is_instance_valid(wiz_sp) or not wiz_sp.alive) and not splitlings.is_empty() and splitlings.all(func(x): return is_equal_approx(x.hp, x.stats["hp"])))
	g.queue_free()
	await process_frame

	# Tunneler: cannot be hit underground, pops up ~2 cells outside its target house, then walks in to hit it
	g = await _make_game()
	g.faith = 1000
	g.try_build("guard", Vector2i(11, 2))  # right where it leaves the forest
	g.start_night()
	g._spawn_queue.clear()
	var tu_guard: Enemy = g._spawn(north, "tunneler")
	var full: float = tu_guard.hp
	var was_under := true
	for i in range(200):  # 10 s, still underground, the Guard Tower on top of it
		g.step(0.05)
		was_under = was_under and tu_guard.underground
	check("a Tunneler starts underground and cannot be hit", was_under and is_equal_approx(tu_guard.hp, full))
	g.queue_free()
	await process_frame

	g = await _make_game()
	g.start_night()
	g._spawn_queue.clear()
	var tu: Enemy = g._spawn(north, "tunneler")
	var t := 0.0
	while tu.underground and t < 120.0:
		g.step(0.05)
		t += 0.05
	var d_surf := Vector2(tu.position.x - g.house_point(tu.target_house).x, tu.position.z - g.house_point(tu.target_house).z).length() / GameConfig.CELL
	check("it pops up ~2 cells outside a house (%.1f s, %.2f cells)" % [t, d_surf],
		not tu.underground and d_surf >= 1.8 and not g.nav.goals_of(tu.target_house).has(tu.cell))
	for i in range(120):
		g.step(0.05)
	check("then it walks in and hits that house", tu.attacking and g.houses[tu.target_house].hp < g.houses[tu.target_house].max_hp)
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
	check("Twin Cannons Legendary + Long Mooring: both ground targets hit, full damage (8 per shell)",
		hit1 and hit2 and is_equal_approx(fposmod(hp0 - g1.hp, 8.0), 0.0))
	g.queue_free()
	await process_frame


func _foresight() -> void:
	var g := await _make_game()
	var tiers := []
	for lp in range(3):  # the 3 tiers; later loops stay on the top tier (loops are endless)
		g.loop = lp
		tiers.append(g.foresight_tier())
	check("Foresight: 3 tiers over loops 1 / 2 / 3", tiers == [1, 2, 3])
	g.loop = 9
	check("Foresight: loop 10 keeps the top tier", g.foresight_tier() == 3)

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
	g.loop = 1
	check("no rewrite at tier 2 (loop 2)", not g.close_spawn("north"))
	g.loop = 2
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
	check("4 forced quests of 4 kinds on 4 different houses", g.requests.size() == 4 and kinds.size() == 4 and where.size() == 4)
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
	check("the next day plans 3 new quests, none posted yet", g.quest_plan.size() == 3 and g.requests.is_empty())
	g.post_all_quests()
	check("posted, the day has 3 open quests", g.requests.size() == 3 and g.requests.all(func(r): return not r.done))
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
	check("Fire Orb cools down 11 s, then is ready", not g.cast_spell("fire_orb", _at(5, 5)) and g.spells.cooldown["fire_orb"] > 10.0)
	_run(g, 11.0)
	check("ready again after 11 s", g.spells.is_ready("fire_orb"))

	# Boulder Drop: height scales damage (1 + h/8) and radius (1 + 0.5 h/8), fall time sqrt(2h/(0.25 g))
	var lo := _still(g, "boss", _at(12, 5))
	var near_lo := _still(g, "boss", _at(12, 5, 1.3, 0.0))
	var edge := _still(g, "boss", _at(12, 5, 1.8, 0.0))
	check("Boulder casts from 1 cell up", g.cast_spell("boulder", _at(12, 5), 1.0))
	_run(g, 0.3)
	check("h=1: 15 x 1.125 damage at the centre, inside r=1.59 cells", is_equal_approx(lo.hp, 200.0 - 15.0 * 1.125) and near_lo.hp < 200.0)
	check("h=1: a target 1.8 cells out is missed", is_equal_approx(edge.hp, 200.0))
	_run(g, 18.0)
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
	g.log_sounds = true
	g.sound_log.clear()
	check("Storm Cloud casts", g.cast_spell("storm", _at(5, 12)))
	check("Storm Cloud: the rain starts with the cloud", g.sound_log.count("storm_rain:start") == 1 and g.sound_log.count("storm_rain:stop") == 0)
	_run(g, 0.4)
	check("no strike before 0.5 s", is_equal_approx(s1.hp, 200.0))
	_run(g, 0.3)
	check("first strike: 8 damage on the first target, the Wisp (air) and the next boss; not the 4th in line",
		is_equal_approx(s1.hp, 192.0) and (not is_instance_valid(sw) or not sw.alive) and is_equal_approx(s2.hp, 192.0) and is_equal_approx(s3.hp, 200.0))
	check("first strike = ONE full strike sound plus a snap for each of the 2 extra chain enemies, no far sound",
		g.sound_log.count("storm_strike") == 1 and g.sound_log.count("storm_snap") == 2 and g.sound_log.count("storm_far") == 0)
	check("rain keeps going while the cloud is up", g.sound_log.count("storm_rain:stop") == 0)
	_run(g, 5.0)
	check("rain is still on at 6 s of cloud life minus a moment", g.sound_log.count("storm_rain:stop") <= 1)
	_run(g, 1.5)
	check("4 strikes in 6 s (0.5, 2.0, 3.5, 5.0): 32 damage, then the cloud is gone",
		is_equal_approx(s1.hp, 168.0) and g.spells._fx.filter(func(f): return f["kind"] == "storm").is_empty())
	check("4 strikes = 4 strike sounds and 2 snaps (only the first strike chains to 3: the Wisp dies, the next boss is then out of chain reach); the rain stopped exactly once when the cloud ended",
		g.sound_log.count("storm_strike") == 4 and g.sound_log.count("storm_snap") == 2 and g.sound_log.count("storm_rain:stop") == 1)
	_run(g, 6.0)
	g.spells.cooldown.clear()
	g.sound_log.clear()
	check("Storm Cloud over an empty spot casts", g.cast_spell("storm", _at(20, 2)))
	_run(g, 0.7)
	check("an empty strike makes the quieter far sound, not a strike or a snap",
		g.sound_log.count("storm_far") == 1 and g.sound_log.count("storm_strike") == 0 and g.sound_log.count("storm_snap") == 0)
	g.spells.clear_effects()
	check("a reset stops the rain (once) and leaves no cloud", g.sound_log.count("storm_rain:stop") == 1 and g.spells._fx.is_empty())
	g.spells.clear_effects()
	check("clearing again does not stop the rain twice", g.sound_log.count("storm_rain:stop") == 1)
	g.log_sounds = false

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
			_run(g, 2.2)
			check("Rage ends after 10 s", is_equal_approx(g.spells.haste_at(g.towers[0].position), 1.0))
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
	_run(g, 10.2)
	check("an unused ward fades after 10 s", g.houses[1].ward == 0.0)

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
	check("Quick Hands Rare: cooldown 25% shorter (11 -> 8.25 s)", is_equal_approx(g.spells.cooldown["fire_orb"], 8.25))
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
	g.loop = 3  # the fall night in any loop (Siddharth 2026-11-17: the Warden is never killable)
	g.loop_nights = 5
	g.night = 4
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
	var kd := Vector2(c0.position.x - boss.position.x, c0.position.z - boss.position.z).length()
	check("Warden phase 2: knots stand on open ground outside his mantle (%.2f m away, 0.2 to 0.36, toward the board centre)" % kd, kd > 0.2 and kd < 0.36 and g.warden.crystals.all(func(c): return (Vector2(-boss.position.x, -boss.position.z).normalized().dot(Vector2(c.position.x - boss.position.x, c.position.z - boss.position.z).normalized()) > 0.1))
		and g.warden.crystals.all(func(c): return g.houses.all(func(h): return Vector2(c.position.x - h.position.x, c.position.z - h.position.z).length() > 0.03)))
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
	check("Warden: empty phase-4 HP does not kill it (never killable on a fall night)", boss.alive and boss.hp > 0.0 and g.warden != null)
	g.queue_free()


func _grove_game(loop_index: int, tower_cells: Array) -> Game:
	## A night with a Warden already in its final stand (phase 4), towers on the given cells, the Grove's own timers held back.
	var g := await _make_game()
	g.loop = loop_index
	g.loop_nights = 5
	g.night = 1
	g.faith = 5000
	for c in tower_cells:
		g.try_build("fire", c)
	g.start_night()
	g._spawn_queue.clear()
	var boss: Enemy = g._spawn(Vector2i(12, 3), "boss", _at(12, 3))
	boss.offset = Vector3.ZERO
	boss.slow(0.0001, 100000.0)
	g.warden = Warden.new(g, boss)
	g.warden._final_stand()
	if g.warden.grove != null:
		g.warden.grove._seed_t = -100000.0
		g.warden.grove._lash_t = -100000.0
	return g


func _grove() -> void:
	## Skotos phase 4 "The Grove Awakens" (loop 2+): seeds, saplings, stranglers that disable a tower, the branch lash, cleanup.
	var g0 := await _grove_game(0, [Vector2i(16, 11)])
	check("Grove: loop 1 phase 4 has no Grove (unchanged)", g0.warden.phase == 4 and g0.warden.grove == null)
	_run(g0, 14.0)
	check("Grove: loop 1 plants nothing", g0.enemies.filter(func(e): return e.kind == "crystal").size() <= Warden.WARDEN_VINES)
	g0.queue_free()
	var g := await _grove_game(1, [Vector2i(16, 11)])
	var gr: Grove = g.warden.grove
	var tw: Tower = g.towers[0]
	check("Grove: loop 2 phase 4 starts the Grove", gr != null and g.towers.size() == 1)
	gr._seed_t = GameConfig.GROVE_SEED_EVERY - GameConfig.GROVE_SEED_FIRST  # the real first-planting timing
	_run(g, GameConfig.GROVE_SEED_FIRST - 0.3)
	check("Grove: nothing planted before the first %d s" % int(GameConfig.GROVE_SEED_FIRST), gr.seeds_planted == 0)
	_run(g, 0.5)
	var ok := gr.saplings.size() == GameConfig.GROVE_SEEDS and gr.saplings.all(func(d): return d["e"].hp == GameConfig.GROVE_SAPLING_HP and g.enemies.has(d["e"]))
	check("Grove: %d saplings of %d HP planted, targetable enemies" % [GameConfig.GROVE_SEEDS, int(GameConfig.GROVE_SAPLING_HP)], ok)
	var near := gr.saplings.all(func(d): var dv: Vector3 = d["e"].position - tw.position; return Vector2(dv.x, dv.z).length() < GameConfig.CELL * 3.6)
	check("Grove: seeds land near the tower", near)
	gr._seed_t = -100000.0  # no more plantings
	var s0: Enemy = gr.saplings[0]["e"]
	s0.take_damage(GameConfig.GROVE_SAPLING_HP)
	_run(g, 0.1)
	check("Grove: a sapling dies to %d damage and leaves the list" % int(GameConfig.GROVE_SAPLING_HP), not s0.alive and gr.saplings.size() == GameConfig.GROVE_SEEDS - 1)
	check("Grove: a growing sapling does not disable the tower", not tw.is_inactive())
	tw.stun_left = 1000.0  # (the tower would shoot the saplings dead; this test is about the ones that survive)
	_run(g, GameConfig.GROVE_SAPLING_GROW + 0.2)
	tw.stun_left = 0.0
	var st := gr.saplings.filter(func(d): return d["strangler"])
	check("Grove: surviving saplings become %d HP stranglers that disable the nearest tower" % int(GameConfig.GROVE_STRANGLER_HP),
		st.size() == GameConfig.GROVE_SEEDS - 1 and st.all(func(d): return d["e"].hp == GameConfig.GROVE_STRANGLER_HP and d["tower"] == tw) and tw.strangled and tw.is_inactive())
	var grunt := _still(g, "grunt", tw.position + Vector3(GameConfig.CELL * 3.0, 0, 0))
	var shots0 := tw.shots_fired
	_run(g, 1.5)
	check("Grove: a strangled tower does not fire", tw.shots_fired == shots0)
	var kill_a: Enemy = st[0]["e"]
	kill_a.take_damage(999.0)
	_run(g, 0.1)
	check("Grove: still strangled while another strangler holds it", tw.strangled)
	var kill_b: Enemy = st[1]["e"]
	kill_b.take_damage(999.0)
	_run(g, 0.1)
	check("Grove: destroying the stranglers re-enables the tower", not tw.strangled and not tw.is_inactive())
	grunt.hp = 9999.0
	_run(g, 2.0)
	check("Grove: the freed tower fires again", tw.shots_fired > shots0)
	g.queue_free()
	# branch lash: one tower on the line, one off it
	var g2 := await _grove_game(1, [Vector2i(16, 11), Vector2i(5, 11)])
	var gr2: Grove = g2.warden.grove
	var on_line: Tower = g2.towers[0]
	var off_line: Tower = g2.towers[1]
	var boss2: Enemy = g2.warden.boss
	var dir2 := (on_line.position - boss2.position).normalized()
	gr2._lash_line = {"a": boss2.position, "b": boss2.position + dir2 * 1.4, "t": 0.0, "mi": null, "struck": false}
	check("Grove: the lash geometry crosses only the tower on its line", gr2.lash_crosses(on_line, gr2._lash_line["a"], gr2._lash_line["b"]) and not gr2.lash_crosses(off_line, gr2._lash_line["a"], gr2._lash_line["b"]))
	_run(g2, GameConfig.GROVE_LASH_WARN - 0.2)
	check("Grove: nothing is stunned during the %.1f s warning" % GameConfig.GROVE_LASH_WARN, on_line.stun_left == 0.0)
	_run(g2, 0.4)
	check("Grove: the lash stuns the tower it crosses for %d s, not the other" % int(GameConfig.GROVE_LASH_STUN), on_line.stun_left > GameConfig.GROVE_LASH_STUN - 0.3 and on_line.is_inactive() and off_line.stun_left == 0.0)
	_run(g2, GameConfig.GROVE_LASH_STUN + 0.1)
	check("Grove: the stun wears off", not on_line.is_inactive())
	g2.queue_free()
	# the real schedule: with one tower, the lash comes every GROVE_LASH_EVERY s and always aims at it
	var g3 := await _grove_game(1, [Vector2i(16, 11)])
	var gr3: Grove = g3.warden.grove
	gr3._lash_t = 0.0
	_run(g3, GameConfig.GROVE_LASH_EVERY + 0.3)
	check("Grove: a lash lands every %d s" % int(GameConfig.GROVE_LASH_EVERY), g3.towers[0].stun_left > 0.0)
	# cleanup when the boss dies
	gr3._seed_t = GameConfig.GROVE_SEED_EVERY
	g3.warden.step(0.05)
	_run(g3, GameConfig.GROVE_SAPLING_GROW + 0.5)
	var seeds: Array = gr3.saplings.map(func(d): return d["e"])
	g3.towers[0].stun_left = 2.0
	g3.warden.crystals.clear()  # (the old vine cleanup is not the Grove's)
	g3.log_sounds = true
	g3.sound_log.clear()
	g3.warden.boss.alive = false
	g3.step(0.05)
	check("Grove: cleanup is silent (no enemy_death sounds)", not g3.sound_log.has("enemy_death"))
	check("Grove: boss death clears saplings, stranglers, stuns and the warden", g3.warden == null and not seeds.is_empty()
		and seeds.all(func(e): return not is_instance_valid(e) or not e.alive) and not g3.towers[0].is_inactive())
	g3.queue_free()
	# the lash period is exactly GROVE_LASH_EVERY (strike to strike)
	var g4 := await _grove_game(1, [Vector2i(16, 11)])
	var gr4: Grove = g4.warden.grove
	var t4: Tower = g4.towers[0]
	gr4._lash_t = 0.0
	_run(g4, GameConfig.GROVE_LASH_EVERY + 0.1)
	var first := t4.stun_left > 0.0
	t4.stun_left = 0.0
	_run(g4, GameConfig.GROVE_LASH_EVERY - 0.4)
	var early := t4.stun_left > 0.0
	_run(g4, 0.6)
	check("Grove: lash period is exactly %d s (strike at 12 and 24, not 12.3)" % int(GameConfig.GROVE_LASH_EVERY), first and not early and t4.stun_left > 0.0)
	# stun wobble reaches the model, and the cap on live saplings
	var model := Node3D.new()
	t4.add_child(model)
	t4._model = model
	t4.stun_left = 1.0
	t4.wobble = 0.05
	g4.step(0.05)
	check("Grove: a stunned tower still applies its wobble", is_equal_approx(model.rotation.z, 0.05))
	gr4._seed_t = -100000.0
	for i in 5:
		gr4.plant_seeds()
	check("Grove: at most %d live saplings and stranglers (planting skipped at the cap)" % GameConfig.GROVE_MAX_LIVE, gr4.saplings.size() == GameConfig.GROVE_MAX_LIVE and gr4.seeds_planted == GameConfig.GROVE_MAX_LIVE)
	g4.queue_free()


func _elites() -> void:
	## 2026-11-11 (the user): the three scary bosses walk as elite enemies, one a night from the third night, never on the boss night.
	var g := await _make_game()
	var seen := {}
	g.loop_nights = 5
	for n in 5:
		g.night = n
		var elites := 0
		for grp in g.night_plan():
			for k in grp["enemies"]:
				if GameConfig.ELITES.has(k):
					elites += 1
					seen[k] = true
		check("night %d plans %d elite(s)" % [n + 1, elites], elites == (1 if n >= GameConfig.ELITE_FROM_NIGHT and n < g.fall_night() else 0))
	g.queue_free()
	await process_frame


func _doom() -> void:
	## Night 5 of loops 1-4 always falls: the Warden cannot die, and DOOM_AT seconds in the houses go dark.
	var g := await _make_game()
	g.loop_nights = 5
	g.night = g.fall_night()
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
	g.night_time = 12.0
	boss.take_damage(boss.hp + 1.0)
	_run(g, 0.1)
	check("doomed Warden keeps a sliver of life and fast-forwards near DOOM_AT",
		boss.alive and boss.hp > 0.0 and g.warden != null and g.night_time >= GameConfig.DOOM_AT - 1.5 and g.night_time < GameConfig.DOOM_AT)
	check("no horn before DOOM_AT", not g._doom_started)
	_run(g, 1.6)
	check("the horn sounds at DOOM_AT", g._doom_started)
	_run(g, GameConfig.DOOM_STEP * 4.0)
	check("the village falls and the loop is lost", g.phase != Game.Phase.NIGHT and not g.loop_won)
	g.queue_free()
	var f := await _make_game()
	f.loop = 7
	f.loop_nights = 4
	f.night = f.fall_night()
	check("a late loop's fall night is doomed too (no killable last loop)", f.is_doomed_night())
	f.queue_free()


func _endings() -> void:
	var g := await _make_game()
	g.loop = 2
	g.loop_nights = 4
	g.carried_total = GameConfig.ENDING_B_CARRIED
	g._offer_ending("Dawn.")
	check("from loop 3 the dawn offers both endings and keep looping", g.phase == Game.Phase.CARDS and g.ending_choice and g.offers.size() == 3)
	check("choosing an ending finishes the run with its words", g.choose_card(1) and g.phase == Game.Phase.DONE and g.last_message.contains("Skotos"))
	g.queue_free()


class NightEnder extends Enemy:
	## Test stand-in: its step ends the night (as the third house going dark would).
	var g: Game
	func step(_delta: float) -> void:
		g._end_loop(false)


class Watcher extends Enemy:
	var acted := false
	func step(_delta: float) -> void:
		acted = true


func _review_fixes() -> void:
	## Code review 2026-11-11 (findings 1, 2, 4, 8, 9).
	# 1: a hand losing tracking mid-pinch cancels instead of releasing
	var hand := GameHand.new()
	root.add_child(hand)
	await process_frame
	var got: Array[String] = []
	hand.released.connect(func(_h): got.append("released"))
	hand.cancelled.connect(func(_h): got.append("cancelled"))
	hand._press_key("pinch")
	hand._pinching = true
	hand._update_pinch()  # no tracked visual: the grace is over
	hand.press()
	hand.release()
	check("tracking lost mid-pinch emits cancelled; a real let-go still emits released", got.size() == 2 and got[0] == "cancelled" and got[1] == "released")
	var g := await _make_game()
	var spot := NavGrid.footprint_centre(Vector2i(16, 11), GameConfig.TOWER_SIZE)
	var cd := Card3D.new().setup({"kind": "tower", "id": "fire"})
	g.add_child(cd)
	var before := g.towers.size()
	var faith := g.faith
	g.select("fire")
	g._held_card = cd
	g._held_card_hand = hand
	hand.global_position = g.board.to_global(spot + Vector3(0, 0.07, 0))
	g.hand_released(hand, true)
	check("tracking lost holding a tower card: nothing built, no faith spent, card put back", g.towers.size() == before and g.faith == faith and g._held_card == null and not g.placing())
	g.select("fire")
	g._held_card = cd
	g._held_card_hand = hand
	g.hand_released(hand)
	check("the same card let go on purpose builds there", g.towers.size() == before + 1)
	var start := g.board.global_transform
	g._rim_hands.append(hand)
	g._rim_anchor()
	g.board.global_transform = start.translated(Vector3(0.1, 0, 0))
	g.hand_released(hand, true)
	check("tracking lost while moving the island: it stays where it was, no snap back", g._rim_hands.is_empty() and g.board.global_transform.is_equal_approx(start.translated(Vector3(0.1, 0, 0))))
	g.board.global_transform = start
	g.force_quests(["chimney"])
	var ch: HelpRequest = g.requests.filter(func(r): return r.kind == "chimney")[0]
	hand.global_position = ch.grab_point()
	g.hand_pressed(hand)
	var held := g._held_req == ch
	hand.global_position = ch.grab_point() + Vector3(0.0, 0.2, 0.0)
	g._update_held()
	g.hand_released(hand, true)
	check("tracking lost holding a request prop: it goes back unfinished", held and not ch.done and not ch.held and g._held_req == null and ch.prop.position.is_equal_approx(ch._home))
	# B1: both the legacy button path and the physical-card path use the correct indefinite article.
	g.faith = 0
	g._press_button("airship")
	check("an Airship: unaffordable tower button uses the correct article", g.last_message == "Not enough faith for an Airship.")
	var airship_card := Card3D.new().setup({"kind": "tower", "id": "airship"})
	g.add_child(airship_card)
	g._grab_card(airship_card, hand)
	check("an Airship: unaffordable physical card uses the correct article", g.last_message == "Not enough faith for an Airship.")
	_night_start(g)
	g._refresh_buttons()
	hand.global_position = g.spells.tokens["boulder"].global_position
	g.hand_pressed(hand)
	held = g._held_spell == "boulder"
	hand.global_position = g.board.to_global(Vector3(0.05, 0.4, 0.05))
	g._update_held()
	g.hand_released(hand, true)
	check("tracking lost holding a spell: not cast, still ready, token home", held and g._held_spell == "" and g.spells.is_ready("boulder") 		and g.spells.tokens["boulder"].position.is_equal_approx(g.spells.tokens["boulder"].get_meta("home")))
	g.queue_free()
	await process_frame
	# 2: a restart during the ending offer clears it
	g = await _make_game()
	g.loop = 2
	g.loop_nights = 5
	g.night = 4
	g._offer_ending("Dawn.")
	g.new_run(7)
	check("a new run clears the ending offer", not g.ending_choice)
	g._end_loop(false)
	check("the new run's first lost-night card is a card, not an ending", g.choose_card(0) and g.phase != Game.Phase.DONE and g.loop == 1)
	# 8: a rewind's hourglass animation and words do not outlive a new run
	g._hourglass = Node3D.new()
	g.board.add_child(g._hourglass)
	g._play_hourglass()
	var tw := g._rewind_tween
	var serial := g._rewind_serial
	g.new_run(8)
	check("a new run stops the rewind's hourglass and its pending words", tw != null and not tw.is_valid() and not g._hourglass.visible and g._rewind_serial != serial)
	g.queue_free()
	await process_frame
	# 4: once an enemy ends the night, no other enemy acts in that tick
	g = await _make_game()
	g.start_night()
	g._spawn_queue.clear()
	for e in g.enemies:
		e.queue_free()
	g.enemies.clear()
	var ender := NightEnder.new()
	ender.g = g
	var watcher := Watcher.new()
	g.enemies.append(ender)
	g.enemies.append(watcher)
	g.step(0.05)
	check("an enemy ending the night stops the rest acting that tick", g.phase != Game.Phase.NIGHT and not watcher.acted)
	g.queue_free()
	hand.queue_free()
	await process_frame
	# 9: the plaque touch pad is a world distance at any scale
	var p := Plaque.make("Wake")
	root.add_child(p)
	var pad := GameConfig.XR_PLAQUE_PAD
	var ok := true
	for s in [1.0, 1.7]:
		p.scale = Vector3.ONE * s
		var edge: float = Plaque.SIZE.x / 2.0 * s
		ok = ok and p.hit_point(Vector3(edge + pad - 0.001, 0, 0), pad) and not p.hit_point(Vector3(edge + pad + 0.001, 0, 0), pad)
	check("the plaque pad is the same world distance at scale 1.0 and 1.7", ok)
	p.queue_free()
	# B1: the source string had every glyph; scene geometry was depth-testing through individual letters.
	var bubble := Bubble.new()
	root.add_child(bubble)
	bubble.set_text("Biscuit's up there!")
	var bubble_surfaces_clear := bubble.label.no_depth_test and bubble.label.render_priority == 2
	for child in bubble.get_children():
		if child is MeshInstance3D:
			var material := child.material_override as StandardMaterial3D
			bubble_surfaces_clear = bubble_surfaces_clear and material != null and material.no_depth_test
	check("speech bubble text and parchment render above foreground geometry", bubble.text == "Biscuit's up there!" and bubble.label.text == bubble.text and bubble_surfaces_clear)
	bubble.queue_free()
	await process_frame


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
	check("the Warden wears the first of its four forms", boss._rig != null and boss._rig.key == "skotos_v02" and boss._rig.family == "skotos" and boss._vfx != null)
	for k in GameConfig.ELITES:
		var el: Enemy = g._spawn(Vector2i(12, 2), k)
		check("elite %s wears its model and is not the Warden" % k, el._rig != null and not el.is_boss and el.stats["elite"])
	for i in 4:
		boss.set_form(i)
		check("Warden form %d is its own body (%s)" % [i + 1, Enemy.BOSS_FORMS[i]], boss._rig.key == Enemy.form_key(i) and boss._rig.parts.has("head"))
	boss.set_form(0)
	check("Skotos: arms, head and fan are animated parts, the eyes and chest knot have glows",
		["arm_l", "arm_r", "head", "fan"].all(func(n): return boss._rig.parts.has(n)) and boss._vfx._eyes.size() == 2 and boss._vfx._bands.size() == 4 and boss._vfx._chest != null and boss._vfx._hands.size() == 2)
	check("Skotos stands about 2.3 cottages tall (BOSS_SCALE %.2f)" % Enemy.BOSS_SCALE, absf(ModelUtil.bounds(boss._rig.model).size.y * Enemy.BOSS_SCALE / 0.1376 - 2.25) < 0.5)
	var sw := Warden.new(g, boss)
	g.warden = sw
	boss.take_damage(boss.hp + 1.0)
	check("phase 2 with effects: three heartwood knots (rigged stand-in or model), veins grow", sw.phase == 2 and sw.crystals.size() == 3
		and sw.crystals.all(func(c): return c._knot_holder != null and c.stats["hp"] == 40.0) and is_instance_valid(sw.veins) and sw.veins.vein_count() == 3)
	await process_frame
	await process_frame
	sw.crystals[0].take_damage(99999.0)
	await process_frame
	await process_frame
	check("a broken knot snaps its vein", is_instance_valid(sw.veins) and sw.veins.vein_count() == 2)
	for c in sw.crystals.duplicate():
		if is_instance_valid(c) and c.alive:
			c.take_damage(99999.0)
	await process_frame
	await process_frame
	await process_frame
	check("no knots left: the veins are cleaned up and phase 3 begins", not is_instance_valid(sw.veins) and sw.phase == 3 and boss._rig.key == Enemy.form_key(2) and boss._rig.fury == 1.0)
	sw.crystals = [g._spawn(Vector2i(12, 2), "crystal", boss.position + Vector3(0.1, 0, 0))]
	sw._grow_veins()
	await process_frame
	check("veins reappear for a fresh knot", is_instance_valid(sw.veins) and sw.veins.vein_count() == 1)
	boss.alive = false  # the night ends / a new run starts: the boss is gone, so are the veins
	await process_frame
	await process_frame
	check("veins are cleaned up when the boss goes (night end / new run)", not is_instance_valid(sw.veins))
	g.warden = null
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
	check("Guards (5 damage a hit) kill a 20 HP Grunt", not e.alive)
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
	g.loop = 1
	g.try_build("guard", Vector2i(16, 5))
	var gt2: Tower = g.towers[1]
	check("loop 2 Guards scale +20% HP (36) and +15% dmg (5.75)",
		is_equal_approx(gt2.guard_hp, 36.0) and is_equal_approx(gt2.guard_damage, 5.75))
	g.loop = 0
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
	var follow := Node3D.new()
	root.add_child(follow)
	var v0 := a.voices
	var rain := a.loop_start("storm_rain", follow)
	check("audio: a spatial loop starts on a node and counts as a voice", rain != null and a.voices == v0 + 1 and a._loops.size() == 1)
	check("audio: a one-shot id is not a loop", a.loop_start("pinch", follow) == null)
	a.loop_stop(rain)
	a.loop_stop(rain)
	check("audio: stopping a loop frees its voice once", a._loops.is_empty() and a.voices == v0)
	a.loop_start("storm_rain", follow)
	follow.free()
	a._process(0.016)
	check("audio: a loop whose node is gone stops itself (no leak)", a._loops.is_empty() and a.voices == v0)
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
	check("the day hourglass runs at the decided 20x rate", GameConfig.DAY_FAST == 20.0)
	g._tick_day(0.75)
	check("a hurried day passes DAY_FAST times as fast", absf(g.day_left() - (30.0 - 0.75 * GameConfig.DAY_FAST)) < 0.01)
	g._tick_day(1.0)
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
	g.loop_nights = 6  # the day-cycle check below plays 3 nights without the fall
	check("day 1 plans 3 quests and posts none at once", g.quest_plan.size() == 3 and g.requests.is_empty())
	check("the very first quest is the prayer", g.quest_plan[0]["kind"] == "prayer")
	var day1: Array = g.quest_plan.map(func(q): return q["kind"])
	check("a day's quests are 3 different kinds", day1.size() == 3 and day1.all(func(k): return day1.count(k) == 1))
	check("posted by the day's clock: 1 early, 2 by 40%, 3 late", g.quests_posted_by(10.0) == 1 \
		and g.quests_posted_by(GameConfig.DAY_LENGTH * 0.4) == 2 and g.quests_posted_by(GameConfig.DAY_LENGTH * 0.9) == 3)
	var first := g.post_next_quest()
	check("post_next_quest posts one and leaves two planned", first != null and g.requests.size() == 1 and g.quest_plan.size() == 2)
	g.start_night()
	g._clear_night()
	g._end_night()
	var days: Array = day1 + g.quest_plan.map(func(q): return q["kind"])
	for d in 3:  # 16 kinds at 3 a day (since 2026-11-18): five days deal 15 different kinds
		g.start_night()
		g._clear_night()
		g._end_night()
		days.append_array(g.quest_plan.map(func(q): return q["kind"]))
	var seen := {}
	for k in days:
		seen[k] = true
	check("five days deal 15 different kinds, none twice", days.size() == 15 and seen.size() == 15 and GameConfig.REQUESTS.size() == 16)
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
	check("the book opens at its first spread", g.ledger.page == 0 and g.ledger.spread == 0)
	check("turning back from the first spread does nothing", not g.ledger.turn(-1) and g.ledger.spread == 0)
	check("tapping forward turns a leaf: the next spread", g.ledger.turn(1) and g.ledger.spread == 1 and g.ledger.page == 2)
	check("a leaf cannot be turned while another is turning", not g.ledger.turn(1))
	for i in 40:
		await process_frame
		await create_timer(0.02).timeout
	check("the leaf lands and can be turned on", g.ledger.turn(1) and g.ledger.spread == 2)
	for i in 40:
		await process_frame
		await create_timer(0.02).timeout
	check("the last spread cannot turn further", not g.ledger.turn(1) and LedgerPage.COUNT == 6)
	g.ledger.scale = Vector3.ONE
	var right: Vector3 = g.ledger._book.global_transform * Vector3(Ledger.PW / 2.0, 0, 0)
	var left: Vector3 = g.ledger._book.global_transform * Vector3(-Ledger.PW / 2.0, 0, 0)
	var away: Vector3 = g.ledger._book.global_basis.z.normalized()
	check("a fingertip on the right page finds it, on the left page finds it", g.ledger.page_hit_point(right, 0.05) == 1 and g.ledger.page_hit_point(left, 0.05) == -1)
	check("a ray at the left page finds it", g.ledger.page_hit_ray(left + away * 0.3, -away) == -1)
	check("a point off the book finds nothing", g.ledger.page_hit_point(right + Vector3(1, 0, 0), 0.05) == 0 and g.ledger.page_hit_point(right + away * 0.3, 0.05) == 0)
	var spine: Vector3 = g.ledger._book.global_transform * Vector3.ZERO
	check("a tap inside the ledger spine deadzone does not turn either page and still counts as on the book",
		g.ledger.page_hit_point(spine, 0.05) == 0 and g.ledger.near_open_book(spine, 0.05))
	g.ledger_from_palm(0.05, false, palm, Vector3.UP, eye)
	check("a brief tracking blink does not close the ledger", g.ledger.open)
	g.ledger_from_palm(GameConfig.PALM_CLOSE_HOLD + 0.05, false, palm, Vector3.UP, eye)
	check("sustained tracking loss closes the ledger after PALM_CLOSE_HOLD", not g.ledger.open)
	g.ledger.set_open(true)
	g.ledger.spread = 0
	g.ledger._land()
	check("page-turn cooldown blocks an immediate bounce turn right after a leaf lands", not g.ledger.turn(1) and g.ledger.spread == 0)
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


func _tray_rules() -> void:
	## Siddharth 2026-11-12: the tray starts at the board's front edge, low; it is grabbed and moved on its own and
	## never follows the island.
	var g: Game = load("res://scripts/game/game.gd").new()
	g.settle_ms = 0
	g.with_rig = true
	root.add_child(g)
	for i in 4:
		await process_frame
	var tray: CardTray = g._tray
	var c := g.board.global_position
	var head := g._eye()
	var out := tray.global_position - c
	var to_head := head - c
	check("the tray starts on the headset side of the board", Vector2(out.x, out.z).dot(Vector2(to_head.x, to_head.z)) > 0.0)
	check("the tray starts TRAY_DROP above the board's top, below the eyes (2026-11-18: beside the near edge, higher)", is_equal_approx(tray.global_position.y, c.y + GameConfig.TRAY_DROP) and tray.global_position.y < head.y - 0.1)
	var l := g.board.to_local(tray.global_position)
	check("the tray does not overlap the island or its rim", maxf(absf(l.x), absf(l.z)) - 0.055 > Game.HALF + GameConfig.RIM_WIDTH)
	check("the tray is tipped up toward the player", tray.global_basis.y.y < 1.0 and tray.global_basis.y.z > 0.0)
	var at0 := tray.global_transform
	g.board.global_transform = Transform3D(Basis(Vector3.UP, 0.8) * Basis.from_scale(Vector3(1.6, 1.6, 1.6)), c + Vector3(0.3, 0.1, -0.2))
	for i in 3:
		await process_frame
	check("moving, turning and resizing the island leaves the tray where it is", tray.global_transform.is_equal_approx(at0))
	g.board.global_transform = Transform3D(Basis.IDENTITY, c)
	var hand := GameHand.new()
	root.add_child(hand)
	await process_frame
	hand.global_position = tray.global_transform * Vector3(0, 0, 0.05)  # the front lip, outside every card
	var cards_before := g._tray.cards.size()
	g.hand_pressed(hand)
	check("a pinch on the tray's wood grabs the tray, not a card", g._tray_hand == hand and g._held_card == null and cards_before > 0)
	var board_at := g.board.global_transform
	hand.global_position += Vector3(0.2, 0.05, 0.1)
	for i in 2:
		await process_frame
	check("the grabbed tray follows the hand", tray.global_position.distance_to(at0.origin + Vector3(0.2, 0.05, 0.1)) < 0.001)
	check("moving the tray never moves the island", g.board.global_transform.is_equal_approx(board_at))
	check("the grabbed tray keeps its tilt", absf(tray.global_basis.y.y - at0.basis.y.y) < 0.001)
	g.hand_released(hand)
	var dropped := tray.global_transform
	for i in 3:
		await process_frame
	check("a released tray stays where it was put", g._tray_hand == null and tray.global_transform.is_equal_approx(dropped))
	hand.global_position = tray.global_transform * Vector3(0, 0, 0.05)
	g.hand_pressed(hand)
	hand.global_position += Vector3(-0.3, 0, 0.2)
	await process_frame
	g.hand_released(hand, true)
	check("a hand lost mid-move leaves the tray where it was, no snap back", g._tray_hand == null and not tray.global_transform.is_equal_approx(dropped))
	dropped = tray.global_transform
	var zs := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.8), Vector3(0, 0.8, -0.8))
	var zin := Game.zoom_board_transform(zs, Vector3(0, 1.3, 0), 0.1, 0.4)
	var zout := Game.zoom_board_transform(zs, Vector3(0, 1.3, 0), 0.4, 0.1)
	check("two-hand spread brings the table closer at the same size; closing pushes it away", zin.origin.z > zs.origin.z and zout.origin.z < zs.origin.z and zin.basis.is_equal_approx(zs.basis) and is_equal_approx(zin.origin.y, zs.origin.y))
	check("a turned hand turns the held tray", absf(Game.tray_turned_transform(dropped, Vector3.ZERO, 0.5).basis.get_euler().y - wrapf(dropped.basis.get_euler().y + 0.5, -PI, PI)) < 0.01)
	var card: Card3D = tray.cards[0]
	hand.global_position = card.global_position
	g.hand_pressed(hand)
	check("a pinch on a card still picks the card", g._held_card == card and g._tray_hand == null)
	g.hand_released(hand, true)
	g.new_run(7)
	for i in 3:
		await process_frame
	check("a new run keeps the tray where it was put", g._tray.global_transform.is_equal_approx(dropped))
	var face := tray.cards[1].global_transform * Vector3(0, -0.042, 0)  # a card's lowest face, right over the wood
	hand.global_position = face
	check("the test point is over the wood and on a card face", tray.body_distance(face) <= GameConfig.TRAY_GRAB_PAD)
	g.hand_pressed(hand)
	check("a pinch on a card face over the wood picks the card, not the tray", g._held_card == tray.cards[1] and g._tray_hand == null)
	g.hand_released(hand, true)
	var bx := Transform3D(Basis.IDENTITY, Vector3(0, 0.75, -0.85))
	var low := Game.tray_clamp(Vector3(0, -2.0, 0.5), bx)
	var high := Game.tray_clamp(Vector3(0, 5.0, 0.5), bx)
	var far := Game.tray_clamp(Vector3(9.0, 0.8, 0.5), bx)
	var inside := Game.tray_clamp(Vector3(0.1, 0.75, -0.8), bx)
	var li := bx.affine_inverse() * inside
	check("the tray is clamped above the floor, below the ceiling, within reach of the board and out of the island",
		is_equal_approx(low.y, GameConfig.TRAY_MIN_Y) and is_equal_approx(high.y, GameConfig.TRAY_MAX_Y) 		and Vector2(far.x, far.z - bx.origin.z).length() <= GameConfig.TRAY_MAX_DIST + 0.001 and maxf(absf(li.x), absf(li.z)) >= Game.HALF + 0.05)
	var e := Game.tray_held_transform(dropped, Vector3(0, 0.8, 0), Vector3.ZERO, Vector3(2, 1.3, 0), 0.0, 0.3)
	check("a grabbed tray eases its yaw toward the headset instead of snapping", e.basis.get_euler().y > 0.1 and e.basis.get_euler().y < PI / 2.0 - 0.1)
	var g2: Game = load("res://scripts/game/game.gd").new()
	g2.with_rig = true
	root.add_child(g2)
	for i in 3:
		await process_frame
	var cam := XRCamera3D.new()
	root.add_child(cam)
	g2._xr = true
	g2._xr_cam = cam
	g2._tray_placed = false
	g2._tray.global_position = Vector3(7, 7, 7)
	await process_frame
	check("placement waits while the headset pose is invalid (head at the origin)", not g2._tray_placed and g2._tray.global_position.is_equal_approx(Vector3(7, 7, 7)))
	cam.global_position = Vector3(0, 1.2, 0.3)
	await process_frame
	check("the tray is placed once the headset pose is valid", g2._tray_placed and g2._tray.global_position.z > g2.board.global_position.z)
	check("the tray subtitle is centred and smart-wrapped within a compact view width",
		g._toast.width == Game.TRAY_SUBTITLE_WIDTH and g._toast.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART \
		and g._toast.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER \
		and g._toast.width * g._toast.pixel_size < 0.23)
	g.start_night()
	check("nightfall routes Skotos's long subtitle through the wrapped tray label",
		g.phase == Game.Phase.NIGHT and g._toast.text == g.last_message \
		and g._toast.text.begins_with("Skotos: ") and g._toast.text.length() > 50)
	check("toasts sit clearly above the tray cards with a slim 8px outline",
		g._toast.position.y >= 0.12 and g._toast.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM \
		and g._toast.outline_size == 8)
	g._show_toast("Dusk is coming.")
	g._show_toast("Night 1. They come from the forest.")
	var stack_clear := true
	for sl in g._toast_stack:
		if sl.text != "" or sl.visible or sl.outline_modulate.a > 0.01:
			stack_clear = false
	check("back-to-back status toasts replace in _toast instead of stacking ghost outlines",
		g._toast.text == "Night 1. They come from the forest." and g._toast.visible \
		and g._toast.modulate.a > 0.9 \
		and is_equal_approx(g._toast.outline_modulate.a, g._toast.modulate.a) \
		and stack_clear)
	g._refresh_hud()
	check("repeated HUD refresh with unchanged message keeps the single active toast clean",
		g._toast.text == "Night 1. They come from the forest.")
	g.last_message = "Can't build there."
	g._refresh_hud()
	g._show_toast("Hold to hurry the day")
	g.last_message = "Can't build there."
	g._refresh_hud()
	var stack_clear_after := true
	for sl in g._toast_stack:
		if sl.text != "" or sl.visible or sl.outline_modulate.a > 0.01:
			stack_clear_after = false
	check("repeating an explicit message after another toast still replaces cleanly",
		g._toast.text == "Can't build there." and stack_clear_after)
	g._tick_tray_bits(Game.TOAST_HOLD + 0.1)
	check("fading out clears toast text, visibility, outline alpha, and _toast_last",
		g._toast.modulate.a <= 0.01 and g._toast.outline_modulate.a <= 0.01 \
		and g._toast.text == "" and not g._toast.visible and g._toast_last == "")
	g2.queue_free()
	cam.queue_free()
	g.queue_free()
	hand.queue_free()
	await process_frame


func _perf_fixes() -> void:
	var vp := SubViewport.new()
	root.add_child(vp)
	Game.configure_xr_viewport(vp)
	check("XR viewport has foveation fully off (no VRS map)", vp.use_xr and vp.vrs_mode == Viewport.VRS_DISABLED)
	vp.queue_free()
	var g := Game.new()
	g.with_rig = false
	g.with_life = true
	root.add_child(g)
	for i in 3:
		await process_frame
	var buf: Array = []
	g.life.append_pushers(buf, 2)
	check("VillageLife.append_pushers respects limit without extra allocation", buf.size() <= 2)
	var prev_buf := g._grass_pushers
	g._feed_grass()
	g._feed_grass()
	check("Game._feed_grass reuses its pre-allocated buffer and caps pushers at MAX_PUSH",
		is_same(g._grass_pushers, prev_buf) and g._grass_pushers.size() <= GrassField.MAX_PUSH)
	g.grass.set_pushers([Vector4(0.1, 0.0, 0.1, 0.05)])
	check("GrassField.set_pushers fills pre-allocated buffer and zeroes unused slots",
		g.grass._push_buf.size() == GrassField.MAX_PUSH and g.grass._push_buf[0].is_equal_approx(Vector4(0.1, 0.0, 0.1, 0.05)) and g.grass._push_buf[1] == Vector4.ZERO)
	g._left_hand_tracker = XRHandTracker.new()
	var _t_lookup := g._get_left_hand_tracker()
	check("left tracker lookup returns cached instance while active", g._left_hand_tracker != null)
	XRServer.tracker_removed.emit(&"/user/hand_tracker/left", XRServer.TRACKER_HAND)
	check("XRServer.tracker_removed (2-arg signal) clears cached left hand tracker", g._left_hand_tracker == null)
	var tray := CardTray.new()
	root.add_child(tray)
	var card_list: Array[Dictionary] = [CardData.tower(GameConfig.TOWER_ORDER[0]), CardData.tower(GameConfig.TOWER_ORDER[1])]
	tray.set_cards(card_list)
	check("CardTray shares one compiled face shader across cards",
		tray._face_shader != null and tray.cards[0]._print_materials[0].shader == tray.cards[1]._print_materials[0].shader)
	var c0_vps := tray.cards[0].get_children().filter(func(x): return x is SubViewport)
	var c1_vps := tray.cards[1].get_children().filter(func(x): return x is SubViewport)
	var c0_quads_off := tray.cards[0].get_children().all(func(x): return not (x is MeshInstance3D) or x == tray.cards[0]._body or (x as MeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	check("Card3D shares card-back SubViewport across tray without retaining headless waiters",
		c0_vps.size() == 1 and c1_vps.size() == 1 and Card3D._back_waiters.is_empty() and c0_quads_off)
	var p_path: String = GameConfig.TOWERS[GameConfig.TOWER_ORDER[0]]["scene"]
	var dummy_img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	Card3D._portrait_cache[p_path] = ImageTexture.create_from_image(dummy_img)
	await tray.cards[0]._render_portrait()
	c0_vps = tray.cards[0].get_children().filter(func(x): return x is SubViewport)
	check("Card3D caches tower portraits without leaving an extra 3D SubViewport attached",
		tray.cards[0]._face.art == Card3D._portrait_cache[p_path] and c0_vps.size() <= 1)
	Card3D._portrait_cache.erase(p_path)
	check("Static board Forest, Paths, and Props are merged into minimal draw batches",
		g.board.get_node("Forest").get_child_count() <= 3
		and g.board.get_node("Dressing/Paths").get_child_count() <= 3
		and g.board.get_node("Dressing/Props").get_child_count() <= 3)
	var rig_chk := CharacterRig.new()
	root.add_child(rig_chk)
	rig_chk.setup("elder_ram")
	var sub_off := (not rig_chk.parts.has("arm_l")) or (rig_chk.parts["arm_l"] as MeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var main_on := (not rig_chk.parts.has("body")) or (rig_chk.parts["body"] as MeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	check("CharacterRig keeps body shadows on while disabling tiny sub-part shadow casters", sub_off and main_on)
	rig_chk.set_cast_shadows(false)
	var all_off := rig_chk._meshes.all(func(m): return m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	check("CharacterRig.set_cast_shadows(false) disables all mesh shadow casting", all_off)
	rig_chk.queue_free()
	var sw := StoryWorld.new()
	root.add_child(sw)
	check("StoryWorld splits Pines and FarPines into frustum-culled wedges (no flowers/bushes: game look, 2026-11-17)",
		sw.find_child("Pines0_*", false, false) != null
		and sw.find_child("FarPines0_*", false, false) != null
		and sw.find_child("Flowers_*", false, false) == null
		and sw.find_child("Bushes_*", false, false) == null)
	sw.apply_perf_tier(PerfTier.HIGH)
	check("StoryWorld.apply_perf_tier(HIGH) disables mobile bloom and sets orthogonal sun shadows",
		not sw.env.glow_enabled and not sw.env.adjustment_enabled
		and sw.env.reflected_light_source == Environment.REFLECTION_SOURCE_DISABLED
		and sw.env.ambient_light_source == Environment.AMBIENT_SOURCE_SKY
		and sw.sun.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL)
	sw.queue_free()
	var ep := ConfigFile.new()
	var ep_err := ep.load("res://export_presets.cfg")
	var excl := str(ep.get_value("preset.0", "exclude_filter", "")) if ep_err == OK else ""
	check("Quest export preset excludes tools/* and tests/* and silences XR log spam",
		ep_err == OK and excl.contains("tools/*") and excl.contains("tests/*") and not GameConfig.VERBOSE_XR_LOG)
	tray.queue_free()
	g.queue_free()
	await process_frame


func _visual_rendering_fixes() -> void:
	check("dusk and night bloom thresholds keep cream parchment below bloom",
		Lighting.PRESETS["dusk"]["thr"] >= 0.95 and Lighting.PRESETS["night"]["thr"] >= 0.95)
	var gv := GodHandVisual.new()
	root.add_child(gv)
	await process_frame
	gv.tracked = true
	gv.pinch_strength = 1.0
	gv.holding_card = true
	gv._update_glow()
	check("holding a card suppresses the additive pinch glow quad", not gv._pinch_glow.visible)
	gv.queue_free()
	var hd := HazeDome.new()
	root.add_child(hd)
	await process_frame
	check("HazeDome renders only on HazeDome.RENDER_LAYER", hd.layers == HazeDome.RENDER_LAYER)
	hd.queue_free()
	var lv := LensView.new()
	var dummy := Node3D.new()
	root.add_child(lv)
	root.add_child(dummy)
	lv.setup(dummy, Vector3.ZERO, Vector2(0.066, 0.098))
	check("LensView uses 672x960 MSAA_2X and excludes HazeDome from its cull mask",
		LensView.VIEW_SIZE == Vector2i(672, 960) and lv._vp.msaa_3d == Viewport.MSAA_2X and (lv._cam.cull_mask & HazeDome.RENDER_LAYER) == 0)
	lv.queue_free()
	dummy.queue_free()
	var g: Game = load("res://scripts/game/game.gd").new()
	g.with_rig = false
	g.with_life = true
	root.add_child(g)
	await process_frame
	check("resting Crystal Lens sits at 1.0x tabletop scale", g._lens.transform.basis.get_scale().is_equal_approx(Vector3.ONE))
	check("audio bus levels raise music and ambience for Quest speakers",
		AudioBank.BUS_DB["ambience"] == -10.0 and AudioBank.BUS_DB["music"] == -6.0)
	var md: Node = load("res://scripts/audio/music_director.gd").new()
	md.game = g
	check("music: day music alone by day, night bed alone at night, both silent-ish in between",
		md.targets(0.0).is_equal_approx(Vector2(1, 0)) and md.targets(1.0).is_equal_approx(Vector2(0, 1)) and md.targets(0.45).x < 1.0 and md.targets(0.45).y > 0.0)
	md.free()
	g._tick_clock()
	check("day clock and tutorial banner sit one above the other on the HUD root, which is not under the board",
		g.hud_root != null and g._clock.get_parent() == g.hud_root and not g.board.is_ancestor_of(g.hud_root) and g._clock.position.y - Launcher.TUTORIAL_HINT_POS.y >= 0.20)
	var hud_yaw := g.hud_root.global_transform.basis.get_euler().y
	var far0 := g.hud_root.global_position.distance_to(g.board.global_position)
	g.board.rotation.y += deg_to_rad(90.0)
	g.update_hud_root()
	var yaw_kept := is_equal_approx(g.hud_root.global_transform.basis.get_euler().y, hud_yaw)
	var dist_kept := g.hud_root.global_position.distance_to(g.board.global_position) >= Game.HALF * g.board.scale.x
	check("turning the table does not turn the day clock, which stays behind the table", yaw_kept and dist_kept)
	g.board.global_position += Vector3(0.3, 0, 0.1)
	g.board.scale = Vector3.ONE * 1.5
	g.update_hud_root()
	check("moving and resizing the table moves and scales the day clock with it",
		g.hud_root.global_position.distance_to(g.board.global_position) > far0 and is_equal_approx(g.hud_root.scale.x, 1.5))
	g.board.rotation.y = 0.0
	g.board.scale = Vector3.ONE
	g.board.global_position -= Vector3(0.3, 0, 0.1)
	g.update_hud_root()
	g.mouse_rim_begin(100.0)
	g.mouse_rim_drag(100.0)
	check("a plain click on a rim handle turns nothing", is_zero_approx(g.board.rotation.y))
	g.mouse_rim_drag(160.0)
	var y1 := g.board.rotation.y
	g.mouse_rim_drag(220.0)
	check("dragging the mouse on a rim handle turns the table smoothly, following the mouse",
		is_equal_approx(y1, 60.0 * Game.MOUSE_RIM_RAD_PER_PX) and is_equal_approx(g.board.rotation.y, 2.0 * y1))
	g.mouse_rim_drag(100.0)
	check("dragging back returns the table", is_zero_approx(g.board.rotation.y))
	g._mouse_rim = false
	g.force_quests(["chimney"])
	var kite: HelpRequest = g.requests[0]
	var kite_v: Villager = kite.asker()
	check("an open quest's asker acts the request out: it turns to the problem and pleads",
		kite_v != null and kite_v.ask_face == kite.problem_point() and kite.focus_point().is_equal_approx(g.board.to_global(kite.prop.position)))
	if kite_v != null and kite_v.rig != null:
		kite_v.wave_on(Vector3.INF)
		check("the asker plays the plead animation while the quest is untouched", kite_v.rig.anim == "plead")
		kite.grab()
		check("taking the quest up stops the act-out", kite_v.ask_face == Vector3.INF and kite_v.rig.anim != "plead")
	g._clear_requests()
	g.force_quests(["prayer"])
	var prayer_v: Villager = g.requests[0].asker()
	g.tap_villager(prayer_v)
	check("tapping a praying quest-giver villager counts toward Tap a villager",
		prayer_v.taps == 1 and g.requests[0].done)
	g.ledger = Ledger.new()
	g.ledger.game = g
	g.add_child(g.ledger)
	await process_frame
	var palm := Vector3(0.0, 1.0, 0.35)
	var eye := Vector3(0.0, 1.3, 0.55)
	g.ledger_from_palm(GameConfig.PALM_UP_HOLD + 0.05, true, palm, Vector3.UP, eye)
	var expected_dir := Vector3(g.board.global_position.x - palm.x, 0.0, g.board.global_position.z - palm.z).normalized()
	var actual_shift := Vector3(g.ledger.global_position.x - palm.x, 0.0, g.ledger.global_position.z - palm.z)
	check("ledger opens shifted inward toward the board center away from palm OS reticle",
		g.ledger.open and actual_shift.is_equal_approx(expected_dir * Game.LEDGER_INWARD_SHIFT))
	g.ledger.set_page(LedgerPage.COUNT - 1)
	g.ledger.scale = Vector3.ONE
	var quit_world: Vector3 = g.ledger._book.global_transform * Vector3(Ledger.PW * 0.5, -Ledger.PH / 2.0 + 0.025, 0.0)
	var hand := GameHand.new()
	root.add_child(hand)
	hand.global_position = quit_world
	g.hand_pressed(hand)
	check("tapping Quit Game on the last ledger spread requests exit", g.quit_requested)
	hand.queue_free()
	g.queue_free()
	await process_frame
	var g_rig: Game = load("res://scripts/game/game.gd").new()
	g_rig.with_rig = true
	g_rig.with_life = false
	root.add_child(g_rig)
	for i in 3:
		await process_frame
	g_rig.faith = 500
	g_rig.try_build("fire", Vector2i(16, 11))
	check("building the first tower shows the one-time sell-tower toast",
		g_rig._sell_hint_shown and g_rig._toast.text == Game.SELL_TOWER_HINT)
	g_rig._show_toast("Other toast")
	g_rig.try_build("fire", Vector2i(16, 13))
	check("building a second tower does not repeat the one-time sell-tower toast",
		g_rig._toast.text != Game.SELL_TOWER_HINT)
	g_rig.force_quests(["chimney"])
	var oq: HelpRequest = g_rig.requests[0]
	var outlined_before := oq.grab() and not oq._outlined.is_empty() and oq._outlined[0].material_overlay == HelpRequest._outline_mat
	var first_outlined: MeshInstance3D = oq._outlined[0] if not oq._outlined.is_empty() else null
	oq._finish()
	var outlined_off := oq._outlined.is_empty() and (first_outlined == null or first_outlined.material_overlay == null)
	check("quest item outline is on while an engaged quest is open and turns off when done", outlined_before and outlined_off)
	g_rig._clear_requests()
	g_rig.queue_free()
	await process_frame


func _seated_experience() -> void:
	## 2026-11-15: seated optimizations (visible rim handles, Lazy-Susan spin, 0.8x auto-center, tray-docked lens, one-hand compass, seated opening rotation).
	var sbt := Game.seated_board_transform(Vector3(0.2, 1.2, 0.3), Vector3(0.0, -0.3, -1.0))
	check("seated board centres ahead at eye_y - SEATED_BOARD_DROP and 0.8x scale",
		sbt.origin.is_equal_approx(Vector3(0.2, 1.2 - GameConfig.SEATED_BOARD_DROP, 0.3 - GameConfig.SEATED_BOARD_DIST))
		and is_equal_approx(sbt.basis.get_scale().x, GameConfig.SEATED_BOARD_SCALE))
	var head := Vector3(0.0, 1.2, 0.0)
	var too_far := Game.board_clamp(Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, -5.0)), head)
	var too_near := Game.board_clamp(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.1, -0.05)), head)
	check("board_clamp keeps the island within comfortable seated height and arm reach",
		too_far.origin.y <= head.y - 0.18 + 0.001
		and Vector2(too_far.origin.x - head.x, too_far.origin.z - head.z).length() <= GameConfig.BOARD_MAX_DIST + 0.001
		and is_equal_approx(too_near.origin.y, GameConfig.BOARD_MIN_Y)
		and Vector2(too_near.origin.x - head.x, too_near.origin.z - head.z).length() >= GameConfig.BOARD_MIN_DIST - 0.001)
	var center := Vector3(0.0, 0.78, -0.72)
	var p0 := center + Vector3(0.0, 0.0, 0.48)
	var p1 := center + Vector3(0.48, 0.0, 0.0)
	var spin_yaw := Game.rim_one_hand_yaw(center, p0, p1)
	var spun := Game.rim_transform(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.8), center), [p0] as Array[Vector3], [p1] as Array[Vector3], spin_yaw)
	check("one-hand tangential Lazy-Susan rim sweep turns the board around its centre",
		absf(spun.basis.get_euler().y - PI / 2.0) < 0.01 and spun.origin.distance_to(center) < 0.01)

	var g: Game = load("res://scripts/game/game.gd").new()
	g.settle_ms = 0
	g.with_rig = true
	g.with_life = false
	root.add_child(g)
	for i in 4:
		await process_frame
	check("four visible rim handles sit inside the instant-grab rim zone",
		GameConfig.RIM_HOLD == 0.0 and g._rim_handles.size() == 4 and g._rim_handles.all(func(r): return g.on_rim(r.global_position)))
	check("Crystal Lens and Board Compass dock on the CardTray wings",
		g._lens.get_parent() == g._tray and g._board_compass != null and g._board_compass.get_parent() == g._tray)

	var cam := XRCamera3D.new()
	root.add_child(cam)
	cam.global_position = Vector3(0.0, 1.2, 0.0)
	cam.look_at(Vector3(0.0, 1.2, -1.0), Vector3.UP)
	g._xr = true
	g.easy_reach = false
	g._xr_cam = cam
	g._board_placed = false
	g._tray_placed = false
	for i in 2:
		await process_frame
	check("XR start auto-centres board to seated pose (0.8x) and places tray in front",
		g._board_placed and is_equal_approx(g.board.scale.x, GameConfig.SEATED_BOARD_SCALE)
		and g._tray_placed and g._tray.global_position.z > g.board.global_position.z)

	var lens_before := g._lens.global_position
	var hand := GameHand.new()
	root.add_child(hand)
	await process_frame
	var start_pos := g.board.global_position
	var h0 := g._rim_handles[0].global_position
	hand.global_position = h0
	g.hand_pressed(hand)
	check("rim handle pinch grabs the board immediately with no hold delay",
		g._rim_hands.has(hand))
	var rel := h0 - start_pos
	hand.global_position = start_pos + Vector3(rel.z, rel.y, -rel.x)
	hand.rotation.y = PI / 2.0  # forearm follows the Lazy-Susan sweep without double-counting rotation
	g._tick_rim(0.05)
	check("one-hand tangential rim sweep turns smoothly without forearm double-rotation or off-pivot drift",
		absf(g.board.basis.get_euler().y - PI / 2.0) < 0.05 and g.board.global_position.distance_to(start_pos) < 0.02)
	g.recenter_seated_board()
	g._tick_rim(0.02)
	check("recenter clears active rim grip and resets board pose cleanly",
		g._rim_hands.is_empty() and is_equal_approx(g.board.basis.get_euler().y, 0.0))

	hand.rotation = Vector3.ZERO
	var glass_grab: Vector3 = g._fast_glass.global_position + Vector3(0, 0.03, 0)
	hand.global_position = glass_grab
	g.hand_pressed(hand)
	check("pinching the tray hourglass activates the hourglass without docked lens or card stealing it",
		g._fast_pending.has(hand) and g._lens_hand == null and g._held_card == null)
	g.hand_released(hand)
	g.easy_reach = true
	hand.global_position = glass_grab
	g.hand_pressed(hand)
	check("tray hourglass stays grabbable without docked lens steal even under easy_reach",
		g._fast_pending.has(hand) and g._lens_hand == null and g._held_card == null)
	g.hand_released(hand)
	g.easy_reach = false

	hand.global_position = g.lens_grip_position()
	g.hand_pressed(hand)
	check("pinching the docked Crystal Lens picks up the lens, not the tray or hourglass",
		g._lens_hand == hand and g._tray_hand == null and not g._fast_pending.has(hand))
	g.hand_released(hand)
	check("releasing the lens returns it cleanly to its tray dock",
		g._lens_hand == null and g._lens.global_position.distance_to(lens_before) < 0.002)

	hand.global_position = g._board_compass.global_position
	g.hand_pressed(hand)
	g.hand_released(hand)
	check("tapping the tray compass cycles board scale one-handedly (80% -> 100%)",
		is_equal_approx(g.board.scale.x, 1.0) and g._compass_label.text == "100%")
	g.hand_pressed(hand)
	g._tick_rim(GameConfig.COMPASS_RESET_HOLD + 0.05)
	g.hand_released(hand)
	check("holding the tray compass recenters the board back to 80% seated pose",
		is_equal_approx(g.board.scale.x, GameConfig.SEATED_BOARD_SCALE) and g._compass_label.text == "80%")

	var ch2_line: String = OpeningStage.CHAPTERS[1]["lines"][0][2]
	check("opening Chapter II adapts narration for seated play without behind-chair turn",
		OpeningStage.EYE < 1.35 and not ch2_line.to_lower().contains("turn around"))
	var st := OpeningStage.new()
	root.add_child(st)
	var st_cam := Camera3D.new()
	st.add_child(st_cam)
	st._cam = st_cam
	st.world = StoryWorld.new()
	st.add_child(st.world)
	st._build_overlay()
	st._start_chapter(1)
	check("opening Chapter II rotates StoryWorld into the seated front view",
		is_equal_approx(st.world.rotation.y, PI)
		and st.world.to_global(StoryWorld.VILLAGE).distance_to(StoryWorld.VILLAGE) > 10.0)
	st.queue_free()
	hand.queue_free()
	cam.queue_free()
	g.queue_free()
	await process_frame


func _tut_next(l: Launcher) -> void:
	## One tutorial step the way the player does it: the action is noticed, the step waits MIN_STEP_S, then Continue is tapped.
	l._tutorial(0.05)
	l._step_time = Launcher.MIN_STEP_S + 1.0
	l._tutorial(0.05)
	l._advance()


func _interactive_tutorial() -> void:
	## Step-gated interactive tutorial: active spotlighting, card pickup/revert, daytime Live Fire shade, board spin, prayer, villager tap, lens, Night 1 spell finale.
	var l: Launcher = load("res://scripts/ui/launcher.gd").new()
	root.add_child(l)
	for _i in 6:
		await process_frame
	l._press_plaque("skip")
	await process_frame
	var g := l.game
	check("tutorial starts at step 0 highlighting tower cards",
		l._state == "playing" and l._step == 0 and g.tutorial_spotlight == "cards" \
		and l._hint_card != null and l._target_ring != null and l._target_ring.visible)
	g._press_button("fast")
	g.toggle_fast()
	check("hourglass and KEY_TAB stay locked during card-spotlight steps", not g.day_fast and g.phase == Game.Phase.DAY)

	g._held_card = g._tray.cards[0]
	l._tutorial(0.05)
	check("a finished step waits for Continue: it does not advance by itself, and Continue is hidden for the first seconds",
		l._step == 0 and l._step_done and (l._cont == null or not l._cont.visible))
	l._step_time = Launcher.MIN_STEP_S + 1.0
	l._tutorial(0.05)
	check("after the minimum time the Continue plaque shows", l._cont != null and l._cont.visible and l._step == 0)
	check("the day clock stands still during the tutorial", g.tutorial_hold and absf(g.day_time) < 0.001)
	g._tick_day(30.0)
	check("a tutorial day does not run down", absf(g.day_time) < 0.001)
	l._advance()
	check("picking up a tower card, then Continue, advances tutorial to step 1 (place on grass)",
		l._step == 1 and g.tutorial_spotlight == "cards" and not l._step_done and not l._cont.visible)

	g._held_card = null
	g.selected = ""
	l._tutorial(0.05)
	check("dropping the card without building reverts step 1 back to step 0",
		l._step == 0 and g.tutorial_spotlight == "cards")

	g.selected = "fire"
	_tut_next(l)
	check("selecting a tower kind advances to step 1", l._step == 1)
	var build_cell := l.tutorial_build_cell()
	var built := g.try_build("fire", build_cell)
	var faith_before_fire := g.faith
	_tut_next(l)
	check("building tower spawns harmless daytime Live Fire shade and advances to step 2",
		built and l._step == 2 and g.tutorial_spotlight == "rim" \
		and g.enemies.size() == 1 and g.phase == Game.Phase.DAY)
	var shade_clear := false
	if g.enemies.size() == 1:
		var sc: Vector2i = g.enemies[0].cell
		shade_clear = not g.nav.kind.has(sc) \
			and not [sc + Vector2i(1, 0), sc + Vector2i(-1, 0), sc + Vector2i(0, 1), sc + Vector2i(0, -1)].any(
				func(nb): return g.nav.kind.get(nb, "") in ["house", "tower", "decor"])
	check("Live Fire tutorial shade spawns clear of houses, towers, and decor", shade_clear)

	var t_fire := 0.0
	while not g.enemies.is_empty() and t_fire < 8.0:
		g.step(0.05)
		t_fire += 0.05
	check("Live Fire tutorial shade dies cleanly in daytime for +15 faith",
		g.enemies.is_empty() and g.phase == Game.Phase.DAY \
		and g.faith >= faith_before_fire + Game.TUTORIAL_SHADE_REWARD)

	l._tutorial(120.0)
	check("tutorial never silently skips after a long idle wait",
		l._step == 2 and l._hint_card != null and is_instance_valid(l._hint_card))

	g.board.rotation.y += deg_to_rad(25.0)
	_tut_next(l)
	check("spinning the island advances to step 3 and ensures prayer quest is posted",
		l._step == 3 and g.tutorial_spotlight == "board" and not g.requests.is_empty())
	check("the tutorial text hangs on the HUD root, not on the board",
		l._hint_root != null and l._hint_root.get_parent() == g.hud_root)
	var hint_yaw0 := l._hint_root.global_transform.basis.get_euler().y
	var hint_pos0 := l._hint_root.global_position
	g.board.rotation.y += deg_to_rad(90.0)
	g.board.global_position += Vector3(0.25, 0.0, 0.15)
	g.update_hud_root()
	check("turning and moving the table keeps tutorial text unrotated and moves it with the table",
		is_equal_approx(l._hint_root.global_transform.basis.get_euler().y, hint_yaw0) \
		and l._hint_root.global_position.distance_to(hint_pos0) > 0.2)
	g.board.rotation.y -= deg_to_rad(90.0)
	g.board.global_position -= Vector3(0.25, 0.0, 0.15)
	g.update_hud_root()

	var asker: Villager = null
	if not g.requests.is_empty():
		asker = g.requests[0].asker()
		g.tap_villager(asker)
	_tut_next(l)
	check("answering the first prayer increments _helped and advances to step 4",
		g._helped > 0 and l._step == 4 and g.tutorial_spotlight == "board")

	check("with no quest open, tutorial step 3 posts a fresh prayer rather than stalling",
		l._open_quest() == null and l._ensure_open_quest() != null and l._open_quest().kind == "prayer")
	g._clear_requests()
	# Tutorial step 3 with another quest already open: prayer must still be posted and completing only prayer finishes step 3
	g.force_quests(["chimney"])
	var kite_q: HelpRequest = g.requests[0]
	l._enter_step(3)
	l._tutorial(0.05)
	var step3_has_prayer := l._step3_quest != null and l._step3_quest.kind == "prayer" and g.requests.size() == 2
	kite_q._finish()
	g._pay_quest(kite_q)
	l._tutorial(0.05)
	var still_waiting_for_prayer := l._step == 3
	if step3_has_prayer:
		g.tap_villager(l._step3_quest.asker())
	_tut_next(l)
	check("tutorial step 3 posts prayer even with another quest open and completes on the prayer",
		step3_has_prayer and still_waiting_for_prayer and l._step == 4)
	g._clear_requests()
	# Tutorial step 3 when no VillageLife villager belongs to any house: stand-in asker spawns and can be tapped
	var saved_homes := []
	if g.life != null:
		for v in g.life.villagers:
			saved_homes.append([v, v.home])
			v.home = 99
	l._enter_step(3)
	l._tutorial(0.05)
	var standin: Node3D = l._step3_quest.asker() if l._step3_quest != null else null
	var standin_ok := standin != null and standin.is_visible_in_tree() and l._step3_quest.kind == "prayer"
	var found_standin := g._find_prayer_asker(standin.global_position + Vector3(0, 0.035, 0), Vector3.ZERO, 0.05) == standin if standin_ok else false
	if standin_ok:
		g.tap_villager(standin)
	_tut_next(l)
	check("tutorial step 3 falls back to a tappable stand-in villager when a house has no villager",
		standin_ok and found_standin and l._step == 4)
	for pair in saved_homes:
		pair[0].home = pair[1]
	g._clear_requests()
	if asker != null:
		g.tap_villager(asker)
	_tut_next(l)
	check("tapping a villager advances to step 5 (Crystal Lens foresight)",
		l._step == 5 and g.tutorial_spotlight == "lens")

	g.set_lens(true)
	_tut_next(l)
	check("peeking through Crystal Lens advances to step 6 (tray handles)",
		l._step == 6 and g.tutorial_spotlight == "tray")
	g._xr = true  # the hand steps only gate in XR; mouse play skips them
	g.toggle_fast()
	check("the hourglass stays locked during the tray step", not g.day_fast)
	l._tutorial(0.05)
	check("the tray step waits for a real grab", l._step == 6)
	g._tray_hand = g._mouse_hand
	_tut_next(l)
	g._tray_hand = null
	check("grabbing a tray handle advances to step 7 (zoom)", l._step == 7 and g.tutorial_spotlight == "zoom")
	g._zoom_hands = [g._mouse_hand, g._mouse_hand]
	g._zoom_d0 = 0.1
	g._zoom_d = 0.2
	_tut_next(l)
	g._zoom_hands = []
	check("a zoom advances to step 8 (ledger)", l._step == 8 and g.tutorial_spotlight == "ledger")
	g.ledger.set_open(true)
	_tut_next(l)
	g.ledger.set_open(false)
	g._xr = false
	check("opening the ledger advances to step 9 (sell a tower)", l._step == Launcher.SELL_STEP and g.tutorial_spotlight == "board" and not g.towers.is_empty())
	check("the sell step still holds the day clock", g.tutorial_hold)
	var tower_n := g.towers.size()
	l._tutorial(0.05)
	check("the sell step waits until a tower is sold", l._step == Launcher.SELL_STEP and not l._step_done)
	g.sell(g.towers[0])
	_tut_next(l)
	check("selling a tower advances to the rebuild step", tower_n > 0 and l._step == Launcher.REBUILD_STEP and g.tutorial_spotlight == "cards" and g.towers.is_empty())
	g.faith = maxi(g.faith, 200)
	g.try_build("fire", build_cell)
	_tut_next(l)
	check("building again advances to the hourglass step, and the day clock is free", l._step == Launcher.HOURGLASS_STEP and g.tutorial_spotlight == "hourglass" and not g.tutorial_hold)

	g.start_night()
	l._tutorial(0.05)
	check("starting Night 1 advances to the God Spell finale",
		l._step == Launcher.NIGHT_STEP and g.tutorial_spotlight == "spells" and g.phase == Game.Phase.NIGHT)

	var casted := g.cast_spell("fire_orb", NavGrid.footprint_centre(build_cell, GameConfig.TOWER_SIZE))
	l._tutorial(0.05)
	check("casting a Night 1 spell finishes tutorial and clears spotlight",
		casted and l._step == Launcher.HINTS.size() and g.tutorial_spotlight == "" \
		and l._hint_card == null and (l._target_ring == null or not l._target_ring.visible))

	g.new_run(7)
	l._tutorial(0.05)
	check("restarting a run via new_run() resets the tutorial back to step 0",
		l._step == 0 and g.tutorial_spotlight == "cards" and l._hint_card != null)

	g.selected = "guard"
	l._tutorial(0.05)
	var guard_cell := l.tutorial_build_cell()
	var built_guard := g.try_build("guard", guard_cell)
	l._tutorial(0.05)
	var t_guard := 0.0
	while not g.enemies.is_empty() and t_guard < 12.0:
		g.step(0.05)
		t_guard += 0.05
	for _i in 60:
		g.step(0.05)
	var guards_idle: bool = built_guard and not g.towers.is_empty() and g.towers[0].guards.all(func(gd): return gd.state == "idle")
	check("Guard Tower guards finish daytime Live Fire shade and return to idle post",
		built_guard and g.enemies.is_empty() and guards_idle and g.phase == Game.Phase.DAY)

	l.queue_free()
	await process_frame


func _juice() -> void:
	## Tower-to-enemy juice (2026-11-16): freeze, squash, push, kill spark, wind-up, hurt look. Looks only.
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	await process_frame
	g.faith = 900
	g.cards = {}
	g.start_night()
	g._spawn_queue.clear()
	var a := _still(g, "grunt", _at(8, 8))
	var b := _still(g, "grunt", _at(8, 12))
	a.take_damage(5.0)
	b.take_damage(5.0, true, "", 0.09, Vector3(1, 0, 0))
	check("juice: hit weight and direction change no damage", is_equal_approx(a.hp, b.hp) and a.hp < a.max_hp)
	var pa := a.position
	var pb := b.position
	a.step(0.05)
	b.step(0.05)
	check("juice: the gameplay position is untouched by the push (same move as an un-juiced hit)",
		(b.position - pb).is_equal_approx(a.position - pa) and b.stats["speed"] == a.stats["speed"])
	check("juice: the body squashes and is nudged", b._body.scale.y < 1.0 and b._body.scale.x > 1.0 and b._body.position.length() > 0.0)
	check("juice: a plain hit (spells) has no squash", a._body.scale == Vector3.ONE and a._body.position == Vector3.ZERO)
	for _i in 4:
		b.step(0.05)
	check("juice: the squash springs back", b._body.scale.is_equal_approx(Vector3.ONE) and b._body.position.length() < 0.0001)
	var e := _still(g, "grunt", _at(12, 6))
	for _i in 6:
		e.take_damage(1.0, true, "", 0.04, Vector3.RIGHT)
	check("juice: a fast tower gets one freeze per 0.25 s per enemy", e.freezes == 1)
	e._age += 0.3
	e.take_damage(1.0, true, "", 0.04, Vector3.RIGHT)
	check("juice: after the gap a new freeze starts", e.freezes == 2)
	var boss := _still(g, "boss", _at(12, 16))
	var grunt2 := _still(g, "grunt", _at(14, 16))
	boss.take_damage(1.0, true, "", 0.06, Vector3.RIGHT)
	grunt2.take_damage(1.0, true, "", 0.06, Vector3.RIGHT)
	boss.step(0.01)
	grunt2.step(0.01)
	check("juice: a boss squashes less than a grunt but still freezes", absf(1.0 - boss._body.scale.y) < absf(1.0 - grunt2._body.scale.y) and boss.freezes == 1)
	var hp_before := b.hp
	var faith_before := g.faith
	var rig := CharacterRig.new()
	root.add_child(rig)
	rig.setup("blightbark", "bark")
	rig.anim = "walk"
	rig.gait = 1.0
	for _i in 5:
		rig.tick(0.05)
	rig.freeze(0.09)
	var held := rig.model.rotation
	rig.tick(0.03)
	rig.tick(0.03)
	check("juice: the rig holds its pose during a freeze", rig.model.rotation.is_equal_approx(held))
	for _i in 4:
		rig.tick(0.05)
	check("juice: the rig moves again after the freeze", not rig.model.rotation.is_equal_approx(held))
	rig.set_hurt(true)
	check("juice: a hurt rig wears the crack overlay", rig._meshes.size() > 0 and rig._hurt_mat != null and rig._meshes[0].material_overlay == rig._hurt_mat)
	rig.hit()
	check("juice: the hit flash takes over the overlay", rig._meshes[0].material_overlay != rig._hurt_mat)
	rig.tick(0.1)
	check("juice: the hurt look returns after the flash", rig._meshes[0].material_overlay == rig._hurt_mat)
	var h := _still(g, "grunt", _at(16, 6))
	var spd = h.stats["speed"]
	h.hp = h.max_hp * 0.4
	h.step(0.05)
	check("juice: below half HP the enemy is hurt, speed unchanged", h._hurt and h._rig != null and h._rig._hurt_on and h.stats["speed"] == spd)
	h.hp = h.max_hp * 0.8
	h.step(0.05)
	check("juice: healed above half, the hurt look ends", not h._hurt)
	# the spark pool: never more than MAX at once, and the house glows on arrival
	var k: KillSparks = g.kill_sparks
	check("juice: the game owns a spark pool with the rig", k != null)
	var launched := 0
	for _i in 20:
		if k.spawn(_at(12, 12)):
			launched += 1
	check("juice: at most 8 sparks fly at once", launched == KillSparks.MAX and k.active == KillSparks.MAX)
	var target_house := k.nearest_house(_at(12, 12))
	k._process(KillSparks.FLIGHT * 0.5)
	check("juice: a flying spark moves", k._spark[0].visible and k.active == KillSparks.MAX)
	k._process(KillSparks.FLIGHT)
	check("juice: all sparks land and the pool empties", k.active == 0 and not k._spark[0].visible)
	check("juice: the house glows when a spark arrives", target_house._glow_t > 0.0)
	check("juice: sparks change no faith or hp", g.faith == faith_before and b.hp == hp_before)
	var victim := _still(g, "scout", _at(6, 6))
	var before := k.active
	victim.take_damage(1.0, true, "", 0.09, Vector3.RIGHT)
	victim.step(0.01)
	var squashed: bool = victim._body.scale.y < 1.0
	victim.take_damage(9999.0, true, "", 0.04, Vector3.RIGHT)
	check("juice: a kill during the squash hands the dying rig an unsquashed body", squashed and victim._body.scale == Vector3.ONE and victim._body.position == Vector3.ZERO)
	check("juice: a kill launches a spark", k.active == before + 1)
	rig.queue_free()
	g.queue_free()
	await process_frame
	await _wind_up()


func _wind_up() -> void:
	## The wind-up never moves a shot: the shot count follows the cooldown rule exactly.
	var g := await _make_game()
	g.faith = 500
	g.cards = {}
	g.try_build("crossbow", Vector2i(11, 4))
	var t: Tower = g.towers[0]
	g.start_night()
	g._spawn_queue.clear()
	_still(g, "boss", _at(12, 8))
	var cd := 0.0
	var expect := 0
	var crouched := false
	var kicked := false
	for _i in 120:
		t.step(0.05)
		cd = maxf(0.0, cd - 0.05)
		if cd <= 0.0:
			cd = t.interval
			expect += 1
			kicked = kicked or t._recoil > 0.0
		if t._model.scale.y < 0.999:
			crouched = true
	check("wind-up: shots fire exactly on the cooldown rule", t.shots_fired == expect and expect > 3)
	check("wind-up: the tower model crouches and kicks (visual only)", crouched and kicked)
	t.cooldown = 0.05
	t.step(0.01)
	var mid: bool = t._model.scale.y < 1.0
	t.reset_kick()
	check("wind-up: reset_kick puts the model back exactly as authored", mid and t._model.scale == t._model_scale and t._model.position == t._model_pos and t._recoil == 0.0)
	t.cooldown = 0.05
	t.step(0.01)
	g._clear_night()
	check("wind-up: the end of the night rests every tower", t._model.scale == t._model_scale and t._model.position == t._model_pos)
	g.queue_free()
	await process_frame


func _new_quests() -> void:
	## 2026-11-16: the eight pinch-and-carry kinds (laundry, well, apples, cat, weeds, bell, firewood, letter).
	var C := GameConfig.CELL
	var g := await _make_game()
	g.force_quests(["laundry", "well", "apples", "cat"])
	var by := {}
	for r in g.requests:
		by[r.kind] = r
	var t0 := g.faith

	var ln: HelpRequest = by["laundry"]
	check("laundry: three garments on the grass and a clothesline of two posts and a line", ln._items.size() == 3 and ln._extras.size() == 3 and ln._line_a.distance_to(ln._line_b) > 2.0 * C)
	check("laundry: nothing is on the line yet and every garment is out of reach of it", ln._items.all(func(n): return HelpRequest._seg_dist(n.position, ln._line_a, ln._line_b) > 0.8 * C))
	g.grab_request(ln)
	ln.move_to(ln._goal + Vector3(4.0 * C, 0.02, 0))
	check("laundry: dropped away from the line stays on the grass and can be pinched again", not g.release_request() and not ln.done and ln.progress == 0.0 and ln.prop.position.y == 0.0 and ln.grabbable())
	var hung := 0
	for i in 3:
		g.grab_request(ln)
		var it := ln.prop
		ln.move_to(ln._line_a.lerp(ln._line_b, 0.5) + Vector3(0, 0.0, 0.5 * C))
		var fin := g.release_request()
		hung += 1 if it.position.is_equal_approx(it.get_meta("hang")) else 0
		check("laundry: garment %d hangs, the request finishes only with the third" % (i + 1), fin == (i == 2) and ln.done == (i == 2))
	check("laundry: all three hang on the line, +20 faith", hung == 3 and g.faith == t0 + 20 and not ln.grabbable())

	var wl: HelpRequest = by["well"]
	check("well: the bucket lies at least 2 cells from the well", HelpRequest._flat(wl.prop.position, wl._goal) >= 2.0 * C - 0.001)
	g.grab_request(wl)
	wl.move_to(wl._goal + Vector3(3.0 * C, 0.02, 0))
	check("well: dropped away from the well stays on the grass, not done", not g.release_request() and not wl.done and wl.prop.position.y == 0.0)
	g.grab_request(wl)
	wl.move_to(wl._goal + Vector3(1.0 * C, 0.02, 0))
	check("well: released within 1.5 cells of the well -> done, +15", g.release_request() and wl.done and g.faith == t0 + 35)

	var ap: HelpRequest = by["apples"]
	check("apples: just the tree to start", ap._items.size() == 1 and ap.prop == ap._tree and not ap._shaken)
	var base: Vector3 = ap._tree.position
	g.grab_request(ap)
	ap.move_to(base + Vector3(0.4 * C, 0.02, 0))
	ap.move_to(base + Vector3(0, 0.02, 0))
	check("apples: a small wiggle drops nothing and the tree stays rooted", not ap._shaken and ap._tree.position == base)
	ap.move_to(base + Vector3(0.5 * C, 0.02, 0))
	check("apples: about a cell of wiggling drops 3 apples", ap._shaken and ap._items.size() == 3 and not ap.done)
	check("apples: letting go of the tree finishes nothing", not g.release_request() and not ap.done)
	for i in 3:
		g.grab_request(ap)
		var a := ap.prop
		ap.move_to(ap._goal + Vector3(3.0 * C, 0.02, 0))
		if i == 0:
			check("apples: dropped away from the basket lies on the grass, not done", not g.release_request() and a.position.y == 0.0 and not ap.done)
			g.grab_request(ap)
		ap.move_to(ap._goal + Vector3(0.4 * C, 0.02, 0))
		var fin := g.release_request()
		check("apples: apple %d in the basket, the request finishes only with the third" % (i + 1), fin == (i == 2) and ap.done == (i == 2))
	check("apples: +20 faith", g.faith == t0 + 55)

	var cat: HelpRequest = by["cat"]
	var roof := cat.prop.position
	check("cat: she sits on the roof, high up, with her tail and head as parts", roof.y > 0.04 and ModelUtil.parts(cat.prop).has("tail") and ModelUtil.parts(cat.prop).has("head"))
	g.grab_request(cat)
	cat.move_to(cat._goal + Vector3(0.5 * C, 0.1, 0))
	check("cat: let go in the air she goes back on the roof", not g.release_request() and not cat.done and cat.prop.position == roof)
	g.grab_request(cat)
	cat.move_to(cat._goal + Vector3(4.0 * C, 0.0, 0))
	check("cat: let go on the ground far from the door she goes back on the roof", not g.release_request() and cat.prop.position == roof)
	g.grab_request(cat)
	cat.move_to(cat._goal + Vector3(1.5 * C, 0.01, 0))
	check("cat: set down on the ground within 2 cells of the door -> done, +15", g.release_request() and cat.done and cat.prop.position.y == 0.0 and g.faith == t0 + 70)
	g.queue_free()
	await process_frame

	g = await _make_game()
	g.force_quests(["weeds", "bell", "firewood", "letter"])
	by = {}
	for r in g.requests:
		by[r.kind] = r
	t0 = g.faith
	g.log_sounds = true

	var wd: HelpRequest = by["weeds"]
	check("weeds: four weeds in the garden bed", wd._items.size() == 4 and wd._extras.size() == 1)
	g.grab_request(wd)
	var wh := wd.prop.position
	wd.move_to(wh + Vector3(0, 0.5 * C, 0))
	check("weeds: a short tug leaves it rooted", not g.release_request() and wd.prop.position == wh and wd.progress == 0.0)
	for i in 4:
		g.grab_request(wd)
		wd.move_to(wd.prop.position + Vector3(0, 1.5 * C, 0))
		var fin := g.release_request()
		check("weeds: pull %d, the request finishes only with the fourth" % (i + 1), fin == (i == 3) and wd.progress == float(i + 1))
	check("weeds: +20 faith", wd.done and g.faith == t0 + 20)

	var bl: HelpRequest = by["bell"]
	g.grab_request(bl)
	var rope_y: float = g.board.to_local(bl.grab_point()).y
	check("bell: the rope is what is pinched", bl.held and bl._rope != null)
	bl.move_to(Vector3(0, rope_y - 0.4 * C, 0))
	check("bell: a short pull does not ring, the rope comes back", not g.release_request() and bl.progress == 0.0 and bl._rope.position == bl._rope_home and not g.sound_log.has("village_bell"))
	for i in 3:
		g.grab_request(bl)
		bl.move_to(Vector3(0, rope_y - 1.2 * C, 0))
		var fin := g.release_request()
		check("bell: ring %d, the request finishes only with the third" % (i + 1), fin == (i == 2) and bl.progress == float(i + 1))
	check("bell: three rings sounded the village bell, +10 faith", g.sound_log.count("village_bell") == 3 and bl.done and g.faith == t0 + 30)

	var fw: HelpRequest = by["firewood"]
	check("firewood: three logs lie more than 1.5 cells from the door", fw._items.size() == 3 and fw._items.all(func(n): return HelpRequest._flat(n.position, fw._goal) > 1.5 * C))
	g.grab_request(fw)
	fw.move_to(fw._goal + Vector3(3.0 * C, 0.02, 0))
	check("firewood: dropped away from the door lies on the grass, not done", not g.release_request() and fw.prop.position.y == 0.0 and fw.progress == 0.0)
	for i in 3:
		g.grab_request(fw)
		fw.move_to(fw._goal + Vector3(1.0 * C, 0.02, 0))
		var fin := g.release_request()
		check("firewood: log %d at the door, the request finishes only with the third" % (i + 1), fin == (i == 2) and fw.done == (i == 2))
	check("firewood: +20 faith", g.faith == t0 + 50)

	var lt: HelpRequest = by["letter"]
	var far := 0.0
	for k in 40:
		far = maxf(far, HelpRequest._flat(lt._flutter_pos(k * TAU / 40.0), lt._flutter_c))
	check("letter: it drifts in a small loop, under a cell across, low in the air", far <= C and lt._flutter_pos(0.0) != lt._flutter_pos(1.5) and lt._flutter_pos(2.0).y < 0.035 and lt._flutter_pos(2.0).y > 0.015)
	check("letter: it starts more than a cell from the postbox", HelpRequest._flat(lt.prop.position, lt._goal) > C)
	g.grab_request(lt)
	lt.move_to(lt._goal + Vector3(3.0 * C, 0.02, 0))
	check("letter: dropped away from the postbox lies on the grass, not done", not g.release_request() and lt.prop.position.y == 0.0 and not lt.done)
	g.grab_request(lt)
	lt.move_to(lt._goal + Vector3(0.5 * C, 0.02, 0))
	check("letter: released within a cell of the postbox -> done, +15", g.release_request() and lt.done and g.faith == t0 + 65)
	g.queue_free()
	await process_frame

	# a tower built beside a loose item of the new kinds carries it (and its home) to open ground; a new run clears the deck
	g = await _make_game()
	g.force_quests(["well", "firewood", "letter", "laundry"])
	g.faith = 1000
	var bk: HelpRequest = g.requests[0]
	var bcell := NavGrid.local_to_cell(bk.prop.position)
	var before := bk.prop.position
	bk.dodge([bcell] as Array[Vector2i])  # a tower's cell right on it
	var ncell := NavGrid.local_to_cell(bk.prop.position)
	check("well: a tower built on the bucket carries it to open ground, home included", bk.prop.position != before and (absi(ncell.x - bcell.x) > 1 or absi(ncell.y - bcell.y) > 1) and bk._home.is_equal_approx(bk._homes[0]) and bk._home.is_equal_approx(bk.prop.position))
	g._quest_deck = ["x"]
	g.new_run(7)
	check("a new run starts with a fresh quest deck", not g._quest_deck.has("x"))
	g.queue_free()
	await process_frame

	# the well's own hanging bucket: hidden while the loose bucket is the quest, hauled back up when it is lowered
	g = await _make_game()
	g.force_quests(["well"])
	var wq: HelpRequest = g.requests[0]
	var hang: Node3D = wq._well_bucket
	check("well: the hanging bucket is a part of the well and hidden at setup, the loose one shows", hang != null and not hang.visible and wq.prop.visible)
	g.grab_request(wq)
	wq.move_to(wq._goal + Vector3(0.5 * C, 0.02, 0))
	g.release_request()
	var two := false
	var t_start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_start < 1500:
		await process_frame
		var shown := 0
		for b in [wq.prop, hang]:
			if b.visible and b.scale.x > 0.1:
				shown += 1
		two = two or shown > 1
	check("well: after it is lowered the well's bucket is back and there are never two buckets in view", hang.visible and hang.scale.x > 0.9 and not wq.prop.visible and not two)
	g._clear_requests()
	await process_frame
	check("well: no hidden bucket is left behind after the requests are cleared", not is_instance_valid(hang))
	g.queue_free()
	await process_frame

	# the words: every kind has 4 asking lines and 3 thank-yous, never the same one twice in a row
	for k: String in GameConfig.REQUESTS:
		var id: String = HelpRequest.TASK_ID[k]
		check("%s: 4 asking lines, 3 thank-yous, and a how-to" % k, StoryText.task_lines(id, "before").size() == 4 and StoryText.task_lines(id, "after").size() == 3 and HelpRequest.HOW[k] != "")
		var repeat := false
		var prev := ""
		for n in 12:
			var line := StoryText.task(id, "before")
			repeat = repeat or line == prev or line == ""
			prev = line
		check("%s: the asking line never repeats the one before" % k, not repeat)

	# with the rig: the outline covers every item still to do and drops each one when it is in place
	var gr: Game = load("res://scripts/game/game.gd").new()
	gr.with_rig = true
	gr.with_life = false
	root.add_child(gr)
	for i in 3:
		await process_frame
	gr.force_quests(["laundry"])
	var rq: HelpRequest = gr.requests[0]
	var covered := rq._items.all(func(n): return ModelUtil.walk(n).any(func(m): return m is MeshInstance3D and m.material_overlay is ShaderMaterial))
	gr.grab_request(rq)
	var first := rq.prop
	rq.move_to(rq._line_a.lerp(rq._line_b, 0.5) + Vector3(0, 0, 0.3 * C))
	gr.release_request()
	var dropped := ModelUtil.walk(first).all(func(m): return not (m is MeshInstance3D) or m.material_overlay == null)
	var others := rq._items.filter(func(n): return n != first).all(func(n): return ModelUtil.walk(n).any(func(m): return m is MeshInstance3D and m.material_overlay is ShaderMaterial))
	check("laundry: the outline covers every garment, and a hung one loses it", covered and dropped and others)
	gr._clear_requests()
	gr.queue_free()
	await process_frame


func _quest_guidance() -> void:
	## 2026-11-17: the pinned quest slip, point-the-way, the dotted trail, and the stuck-only ghost hand.
	var C := GameConfig.CELL
	var gr: Game = load("res://scripts/game/game.gd").new()
	gr.with_rig = true
	gr.with_life = false
	root.add_child(gr)
	for i in 4:
		await process_frame
	gr.update_slip()
	check("slip: hidden while no quest is open", gr._slip != null and not gr._slip.visible and gr.slip_data().is_empty())
	gr.force_quests(["laundry", "well", "weeds"])
	gr.update_slip()
	var ln: HelpRequest = gr.requests[0]
	var wl: HelpRequest = gr.requests[1]
	var wd: HelpRequest = gr.requests[2]
	var d := gr.slip_data()
	check("slip: shows the oldest open quest when none was touched, with its step, where and 0/3 ticks", gr.active_request() == ln and d["name"] == "Washing on the grass" and d["step"] == "Hang the next garment on the line." and d["ticks"] == 3 and d["ticks_done"] == 0 and d["others"] == 2 and (d["where"].begins_with("at the ") or d["where"] == "by the shrine"))
	check("slip: visible by day with an open quest and shows the data", gr._slip.visible and gr._slip.shown.get("name", "") == "Washing on the grass")
	check("slip: it hangs in front of the tray lip, not over the cards", gr._slip.position.z > 0.05 and gr._slip.get_parent() == gr._tray)
	gr.grab_request(wd)
	gr.release_request()
	check("slip: the quest the player last engaged becomes the active one", gr.active_request() == wd)
	gr.update_slip()
	check("slip: it now names the weeds, 4 ticks", gr._slip.shown.get("name", "") == "Weeds in the garden" and gr._slip.shown.get("ticks", 0) == 4)
	gr.grab_request(ln)
	ln.move_to(ln._line_a.lerp(ln._line_b, 0.5) + Vector3(0, 0, 0.3 * C))
	gr.release_request()
	gr.update_slip()
	check("slip: one garment hung -> 1/3, and laundry is active again", gr.active_request() == ln and gr._slip.shown.get("ticks_done", 0) == 1)
	check("ledger info carries the step, where and ticks", ln.info()["ticks_done"] == 1 and ln.info()["ticks"] == 3 and ln.info()["step"] != "" and ln.info()["where"] != "")
	check("where: the far edge is north, +X east, the middle is the shrine", HelpRequest.where_phrase(Vector3(0, 0, -0.4)) == "at the north house" and HelpRequest.where_phrase(Vector3(0.4, 0, 0)) == "at the east house" and HelpRequest.where_phrase(Vector3(0.3, 0, -0.3)) == "at the north-east house" and HelpRequest.where_phrase(Vector3(0.01, 0, 0.01)) == "by the shrine")
	check("ledger page: a poke on a quest row's seal column picks that row, the text column does not", LedgerPage.quest_row_at(Vector2(480, 124 + 146 + 40), [false, false, false]) == 1 and LedgerPage.quest_row_at(Vector2(200, 124 + 40), [false, false, false]) == -1 and LedgerPage.quest_row_at(Vector2(480, 124 + 146 * 3 + 40), [false, false, false]) == -1 and LedgerPage.quest_row_at(Vector2(480, 124 + 146 + 40), [false, true, false]) == -1)
	check("point: touching the slip makes the asker's house glow", gr.point_active_quest() and ln.point_left > 3.9 and not ln._point_saved.is_empty())
	var house_mesh: MeshInstance3D = ln._point_saved[0][0]
	check("point: the house meshes carry the glow overlay", house_mesh.material_overlay is ShaderMaterial)
	ln.tick(2.0, true)
	check("point: still glowing after 2 s", ln.point_left > 1.5 and house_mesh.material_overlay is ShaderMaterial)
	ln.tick(2.5, true)
	check("point: gone after the few seconds, the previous overlay restored", ln.point_left <= 0.0 and ln._point_saved.is_empty() and house_mesh.material_overlay != HelpRequest._point_mat)
	var wl_before := wl.point_left
	wl.point_the_way()
	check("point: the ledger can point at any quest", wl.point_left > wl_before)
	check("point: _point_request refuses a bad index", not gr._point_request(-1) and not gr._point_request(99))
	wl.tick(HelpRequest.POINT_HOLD + 0.1, false)
	check("trail: every open quest has dots from the moment it opens", [ln, wl, wd].all(func(r): return r.trail_dots() > 0))
	var dots0 := wl.trail_dots()
	gr.grab_request(wl)
	wl.move_to(wl._goal + Vector3(3.0 * C, 0.02, 0))
	wl.tick(0.1, true)
	var dots1 := wl.trail_dots()
	wl.move_to(wl._goal + Vector3(1.2 * C, 0.02, 0))
	wl.tick(0.1, true)
	check("trail: it follows the held item and shortens as the goal nears", dots1 > 0 and wl.trail_dots() < dots1 and dots0 >= dots1)
	var tr_mm: MultiMesh = wl._trail.multimesh
	check("trail: it runs from the item to the goal", wl._trail_from.distance_to(wl.prop.position) < 0.001 and wl._trail_to.distance_to(wl._goal) < 0.001)
	check("trail: one MultiMesh per quest (a single draw)", wl._trail is MultiMeshInstance3D and tr_mm.instance_count == HelpRequest.TRAIL_MAX)
	gr.release_request()
	check("trail: the well quest finishes -> the trail goes, and so does its goal ring", wl.done and wl.trail_dots() == 0 and not wl._goal_ring.visible)
	var before_pl := wl.point_left
	wl.point_the_way()
	check("point: a finished quest cannot be pointed at (ledger poke on a done row)", wl.point_left == before_pl and wl._point_saved.is_empty() and not gr._point_request(1))
	check("trail: the goal ring is a gold ring at the goal while the quest is open", ln._goal_ring != null and (ln._goal_ring.visible or ln.trail_ends()[1].y >= 0.05))
	var cards_ok := true
	gr._slip.visible = true
	for c in gr._tray.cards:
		var at: Vector3 = c.global_position
		cards_ok = cards_ok and gr._tray.card_near(at, gr.card_reach()) == c and not gr._slip_takes(at)
	check("slip: a pinch on a tray card still takes the card, never the slip", cards_ok and not gr._tray.cards.is_empty())
	check("slip: a fingertip on the slip's face (clear of the cards) takes it", gr._slip_takes(gr._slip._body.global_position))
	check("ghost: nothing plays when a quest opens", ln._ghost == null and wd._ghost == null and ln.ghost_plays == 0)
	ln.idle = 0.0
	ln.tick(HelpRequest.GHOST_IDLE - 1.0, true)
	check("ghost: not before the stuck delay", ln.ghost_plays == 0 and (ln._ghost == null or not is_instance_valid(ln._ghost)))
	ln.tick(1.2, true)
	check("ghost: after the delay of no progress it plays at the item", ln.ghost_plays == 1 and is_instance_valid(ln._ghost) and ln._ghost is GhostHand)
	gr.grab_request(ln)
	ln.tick(0.1, true)
	await process_frame
	check("ghost: grabbing the item stops it", ln._ghost == null)
	ln.tick(HelpRequest.GHOST_IDLE + 1.0, true)
	check("ghost: no replay while the item is held", ln.ghost_plays == 1 and ln._ghost == null)
	ln.move_to(ln._line_a.lerp(ln._line_b, 0.5) + Vector3(0, 0, 0.3 * C))
	gr.release_request()
	ln.tick(0.1, true)
	check("ghost: progress resets the stuck timer", ln.idle < 0.5 and ln.progress == 2.0)
	ln.tick(HelpRequest.GHOST_IDLE + 0.5, true)
	check("ghost: it can recur once the player is stuck again", ln.ghost_plays == 2)
	var inactive_plays := wd.ghost_plays
	wd.tick(HelpRequest.GHOST_IDLE + 5.0, false)
	check("ghost: a quest that is not the active one never replays", wd.ghost_plays == inactive_plays)
	gr.phase = Game.Phase.NIGHT
	gr.update_slip()
	check("slip: hidden during the night", not gr._slip.visible)
	gr.phase = Game.Phase.DAY
	gr._clear_requests()
	gr.update_slip()
	check("slip: hidden again when no quest is open", not gr._slip.visible)
	gr.queue_free()
	await process_frame


func _fall_and_rewind(g: Game) -> void:
	## Play one loop's end: the fall night is lost, the first card is taken, the rewind runs.
	g.night = g.fall_night()
	g._end_loop(false)
	if g.phase == Game.Phase.CARDS:
		g.choose_card(0)


func _loops() -> void:
	## 2026-11-17 (Siddharth): loop 1 = 3 nights, later loops 1-8 nights, endless; warning signs; Faith carry-over;
	## endings from loop 3 on; the first rewind cutscene.
	check("loop 1 is 3 nights, the fall is night 3", GameConfig.loop_nights(1, 0) == 3 and GameConfig.loop_nights(99, 0) == 3)
	var lens := {}
	var in_range := true
	var det := true
	for sd in range(1, 101):
		for lp in range(1, 9):
			var n := GameConfig.loop_nights(sd, lp)
			in_range = in_range and n >= 1 and n <= 8
			det = det and n == GameConfig.loop_nights(sd, lp)
			lens[n] = true
	check("later loops last 1..8 nights", in_range)
	check("a loop's length is deterministic per run seed", det)
	check("every length 1 to 8 occurs across seeds", lens.size() == 8)
	var hist := [0, 0, 0, 0, 0, 0, 0, 0, 0]
	for k in 10000:
		hist[GameConfig.loop_nights(k, 1 + k % 7)] += 1
	check("loop length is weighted: the middle (4-5) beats the extremes (1 and 8), 3 and 6 beat 2 and 7",
		hist[4] > hist[2] and hist[5] > hist[2] and hist[4] > hist[1] * 3 and hist[5] > hist[8] * 3 and hist[3] > hist[2] and hist[6] > hist[7] and hist[2] > hist[1] and hist[7] > hist[8])
	check("the weights add up to 100", GameConfig.LOOP_NIGHT_WEIGHTS.reduce(func(a, b): return a + b, 0) == 100)
	var g := await _make_game()
	g.new_run(11)
	check("a new run starts loop 1 with 3 nights and the fall on night 3", g.loop_nights == 3 and g.fall_night() == 2 and not g.is_doomed_night())
	g.night = 2
	check("loop 1 falls on night 3", g.is_doomed_night())
	var lengths_ok := true
	for i in 6:  # loops are endless: loops 1 to 6 all continue
		var before := g.loop
		_fall_and_rewind(g)
		lengths_ok = lengths_ok and g.loop == before + 1 and g.phase == Game.Phase.DAY and g.loop_nights == GameConfig.loop_nights(11, g.loop)
	check("loops are endless: six rewinds in a row, each loop's length rolled from the run seed", lengths_ok and g.loop == 6)
	check("the run never ends by a loop count", g.phase != Game.Phase.DONE)
	g.queue_free()

	# the first rewind cutscene: only after loop 1, and it ends in the rewind
	var c := await _make_game()
	c.new_run(5)
	check("no cutscene yet", c.cutscene_count == 0 and not c.is_cutscene())
	_fall_and_rewind(c)
	check("the cutscene plays after loop 1 and ends in the rewind", c.cutscene_count == 1 and c.loop == 1 and not c.is_cutscene())
	_fall_and_rewind(c)
	_fall_and_rewind(c)
	check("later loops do not play it again", c.cutscene_count == 1 and c.loop == 3)
	check("the cutscene lines are in thoughts.json (DRAFT)", StoryText.cutscene("skotos_1").contains("lovely") and StoryText.cutscene("skotos_2").contains("curse") and StoryText.cutscene("maren").contains("Keep them")
		and StoryText.cutscene_narration().size() == 3)
	c.queue_free()

	# warning signs: the Veil's crack grows each night and is largest on the fall night; the dusk horn is for the fall only
	var w := await _make_game()
	w.new_run(3)
	w.loop = 1
	w.loop_nights = 5
	var grows := true
	var prev := -1.0
	for n in 6:
		var a := w.veil_crack_amount(n)
		grows = grows and (a > prev or a == 0.75)
		prev = a
	check("the Veil crack grows a little every night of the loop", grows and w.veil_crack_amount(1) > w.veil_crack_amount(0))
	check("the crack never reaches its maximum", w.veil_crack_amount(30) < 1.0)
	w.loop_nights = 5
	var same := true
	for n in 5:
		var before := w.veil_crack_amount(n)
		w.loop_nights = 2 + n
		same = same and is_equal_approx(before, w.veil_crack_amount(n))
	check("the crack does not depend on the fall night, so it cannot give it away", same)
	w.log_sounds = true
	w.night = 1
	w.sound_log.clear()
	w.start_night()
	var horn_other := w.sound_log.count("boss_roar")
	w.loop_nights = 5
	w._clear_night()
	w.phase = Game.Phase.DAY
	w.night = 4
	w.sound_log.clear()
	w.start_night()
	check("the horn sounds at every dusk, fall night or not", horn_other == 1 and w.sound_log.count("boss_roar") == 1)
	w.queue_free()

	# Faith carries over at each rewind
	var f := await _make_game()
	f.new_run(8)
	f.faith = 400
	f._helped = 2
	var expect := roundi(400 * GameConfig.CARRY_FAITH_SHARE) + GameConfig.CARRY_PER_VILLAGER * f.villagers_alive() + GameConfig.CARRY_PER_KINDNESS * 2
	check("carry amount = 15% of Faith + 10 per villager + 5 per kindness", f.carry_amount() == expect)
	_fall_and_rewind(f)
	check("the next loop starts with the usual Faith plus the carry", f.faith == GameConfig.START_FAITH + expect and f.carried_total == expect)
	f.faith = 100
	f._helped = 0
	var second := f.carry_amount()
	_fall_and_rewind(f)
	check("the carried total accumulates across the run", f.carried_total == expect + second and f.last_carry == second)
	check("the ledger data carries the total", f.ledger_data().get("carried", -1) == f.carried_total)
	f.queue_free()

	# endings: only from loop 3 on; B only when the carried total reaches the stand-in
	var e := await _make_game()
	e.new_run(2)
	e.loop_nights = 4
	e.loop = 1
	e.night = 0
	e.phase = Game.Phase.NIGHT
	e._end_night()
	check("no ending offer at a dawn of loop 2", e.phase == Game.Phase.DAY and not e.ending_choice)
	e.loop = 2
	e.night = 0
	e.phase = Game.Phase.NIGHT
	e.carried_total = GameConfig.ENDING_B_CARRIED - 1
	e._end_night()
	check("loop 3's dawn offers the ending (A and keep looping, B is closed below the total)",
		e.phase == Game.Phase.CARDS and e.ending_choice and e.offers.map(func(o): return o["id"]) == ["let_go", "keep_looping"])
	check("keep looping goes on to the day", e.choose_card(1) and e.phase == Game.Phase.DAY and not e.ending_choice and e.night == 1)
	e.phase = Game.Phase.NIGHT
	e.carried_total = GameConfig.ENDING_B_CARRIED
	e._end_night()
	check("ending B opens at the carried total", e.offers.map(func(o): return o["id"]) == ["let_go", "remember", "keep_looping"])
	e.queue_free()

	# the cutscene's input lock, the roman numerals, the force-dark house
	check("roman numerals for any loop number", LedgerPage.roman(9) == "IX" and LedgerPage.roman(14) == "XIV" and LedgerPage.roman(1) == "I")
	var k := await _make_game()
	var hand := GameHand.new()
	root.add_child(hand)
	await process_frame
	k.hand_pressed(hand)
	var free_press := k._active_hand == hand
	k.hand_released(hand)
	k._active_hand = null
	k._cutscene = true
	k.hand_pressed(hand)
	check("during the cutscene a pinch is ignored (and a free pinch is not)", free_press and k._active_hand == null)
	var spare := Node3D.new()
	var spare_req := HelpRequest.new()
	check("during the cutscene nothing can be tapped, grabbed or chosen",
		k.tap_villager(spare) == "" and not k.grab_request(spare_req) and not k.choose_card(0))
	spare.free()
	spare_req.free()
	k._cutscene = false
	hand.queue_free()
	var hh: House = k.houses[0]
	hh.hold_check = func(_h): return true  # a card that holds the house at 1 HP
	hh.damage(hh.max_hp * 2.0)
	var held := not hh.is_shuttered
	hh.force_dark()
	check("force_dark shutters a house that a hold would keep lit", held and hh.is_shuttered)
	k.queue_free()

	# the cutscene with the whole rig, cut short by a new run: nothing of it may linger
	var rg: Game = load("res://scripts/game/game.gd").new()
	root.add_child(rg)
	for i in 20:
		await process_frame
	if rg.with_rig and rg.board != null:
		rg.new_run(4)
		rg.night = rg.fall_night()
		rg.phase = Game.Phase.NIGHT
		rg._end_loop(false)
		rg.choose_card(0)
		for i in 6:
			await process_frame
		check("rig: the cutscene is running and locks the input", rg.is_cutscene())
		rg._cutscene_show_skotos()
		rg._cutscene_dim_statue()
		await create_timer(1.2).timeout
		rg.new_run(9)
		for i in 3:
			await process_frame
		var lit := rg.houses.all(func(h): return not h.is_shuttered)
		var flame_ok: bool = rg._shrine_flame == null or rg._shrine_flame.scale.is_equal_approx(Vector3.ONE)
		check("rig: a new run mid-cutscene clears it (unlocked, flame back, houses lit, no display Skotos)",
			not rg.is_cutscene() and lit and flame_ok and not is_instance_valid(rg._cutscene_skotos))
	else:
		print("      (no rig in this run: the rig cutscene test was skipped)")
	rg.queue_free()


func _fake_bloom() -> void:
	## Quest tiers: cheap halos stand in for the bloom (scripts/vfx/fake_bloom.gd).
	var g := await _make_game()
	var old_tier := PerfTier.tier
	PerfTier.tier = PerfTier.HIGH
	var fb = load("res://scripts/vfx/fake_bloom.gd").attach(g)
	fb.force_level = 1.0
	for i in 4:
		await process_frame
	check("fake bloom: halos exist on a Quest tier at night (house windows)", fb.enabled and fb.sources.size() >= g.houses.size() and fb.visible_halos() >= g.houses.size())
	fb.force_level = 0.0
	await process_frame
	check("fake bloom: no halos by day", fb.visible_halos() == 0)
	fb.force_level = 1.0
	await process_frame
	var before: int = fb.visible_halos()
	var h: House = g.houses[0]
	var mine := 0
	for s in fb.sources:
		if s["house"] == h:
			mine += 1
	h.force_dark()
	await process_frame
	check("fake bloom: a dark house loses its halos, the others keep theirs", mine > 0 and fb.visible_halos() == before - mine)
	PerfTier.tier = PerfTier.DESKTOP
	await process_frame
	check("fake bloom: desktop draws none", fb.visible_halos() == 0)
	PerfTier.tier = old_tier
	g.queue_free()
