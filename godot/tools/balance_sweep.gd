extends SceneTree
## Balance sweep: tests whole 3-loop runs across multiple seeds and reports per-loop survival, win rate,
## and card rarity offers with active quests + spells. Run:
##   <godot console> --headless --xr-mode off --path godot -s res://tools/balance_sweep.gd

const PLAN := [["fire", Vector2i(11, 4)], ["fire", Vector2i(4, 11)], ["fire", Vector2i(18, 11)], ["airship", Vector2i(16, 11)],
	["crossbow", Vector2i(8, 4)], ["crossbow", Vector2i(4, 14)], ["crossbow", Vector2i(18, 8)],
	["guard", Vector2i(14, 6)], ["guard", Vector2i(6, 10)], ["airship", Vector2i(11, 18)],
	["fire", Vector2i(14, 4)], ["fire", Vector2i(4, 8)], ["fire", Vector2i(18, 14)],
	["crossbow", Vector2i(8, 18)], ["fire", Vector2i(14, 18)], ["guard", Vector2i(6, 15)], ["guard", Vector2i(17, 15)]]


func _initialize() -> void:
	await process_frame
	var variants := [["balanced_active (now)", 1.0, true], ["balanced_passive (no quests/spells)", 1.0, false], ["income x1.2", 1.2, true]]
	for v in variants:
		var wins := 0
		var res := []
		for sd in range(1, 6):
			var out: Dictionary = await _run(sd, v[1], v[2])
			res.append(out["text"])
			if out["won"]:
				wins += 1
		print("%-34s (%d/5 wins) | %s" % [v[0], wins, " | ".join(res)])
	quit()


func _run(sd: int, faith_mult: float, active_play: bool) -> Dictionary:
	var g: Game = load("res://scripts/game/game.gd").new()
	g.with_rig = false
	g.run_seed = sd
	root.add_child(g)
	await process_frame
	g.new_run(sd)
	var log := []
	var won := false
	while g.phase != Game.Phase.DONE:
		if g.phase == Game.Phase.CARDS:
			if g.ending_choice:
				won = true
			g.choose_card(0)
			continue
		if active_play:
			g.post_all_quests()
			for r in g.requests:
				if not r.done:
					r.done = true
					g._pay_quest(r)
		for item in PLAN:
			if g.towers.any(func(t): return t.cell == item[1]):
				continue
			if not g.try_build(item[0], item[1]):
				if g.at_max(item[0]):
					continue
				break
		var n := g.night
		var lp := g.loop
		g.start_night()
		var t := 0.0
		while g.phase == Game.Phase.NIGHT and t < 600.0:
			if active_play:
				_cast_spells(g)
			g.step(0.05)
			t += 0.05
			if int(t / 0.05) % 40 == 0:
				await process_frame
		if g.phase == Game.Phase.DAY and g.loop == lp and faith_mult != 1.0:
			var base_inc := g.standing_houses().size() * GameConfig.DAWN_FAITH_PER_HOUSE + GameConfig.NIGHT_CLEAR_FAITH_PER_NIGHT * (n + 1)
			g.faith += roundi(base_inc * (faith_mult - 1.0) * (1.0 + GameConfig.LOOP_FAITH_STEP * lp))
		if not (g.phase == Game.Phase.DAY and g.loop == lp):
			if g.ending_choice:  # loops are endless now: the sweep ends at the first ending offer (dawn of loop 3)
				won = true
				log.append("L%d WON" % (lp + 1))
			else:
				log.append("L%d n%d" % [lp + 1, n + 1])
	g.queue_free()
	await process_frame
	return {"won": won, "text": "s%d:%s" % [sd, " ".join(log)]}


func _cast_spells(g: Game) -> void:
	for e in g.enemies:
		if is_instance_valid(e) and e.alive and not e.underground and not e.shielded:
			for sp in ["storm", "boulder", "fire_orb"]:
				if g.spells.is_ready(sp):
					g.cast_spell(sp, e.position)
			break

