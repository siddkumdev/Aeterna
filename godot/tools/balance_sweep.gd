extends SceneTree
## Balance sweep: a bot with a sensible build order plays whole 5-loop runs (3 seeds) under different trust
## settings and prints how far each run gets. For M3 tuning:
##   <godot console> --headless --xr-mode off --path godot -s res://tools/balance_sweep.gd
## Extra trust is added by hand on top of the current rules, so GameConfig stays untouched.

# a sensible player's build order: one Fire Tower on each approach, an Airship in the village centre (it reaches
# every house), then Longbows and more fire on the approaches, Braziers by the houses, a second Airship
const PLAN := [["fire", Vector2i(11, 4)], ["fire", Vector2i(4, 11)], ["fire", Vector2i(18, 11)], ["airship", Vector2i(11, 11)],
	["crossbow", Vector2i(8, 4)], ["crossbow", Vector2i(4, 14)], ["crossbow", Vector2i(18, 8)],
	["brazier", Vector2i(14, 6)], ["brazier", Vector2i(6, 10)], ["brazier", Vector2i(16, 11)],
	["fire", Vector2i(14, 4)], ["fire", Vector2i(4, 8)], ["fire", Vector2i(18, 14)], ["airship", Vector2i(11, 18)],
	["crossbow", Vector2i(8, 18)], ["fire", Vector2i(14, 18)], ["brazier", Vector2i(6, 15)], ["brazier", Vector2i(17, 15)]]


func _initialize() -> void:
	await process_frame
	# [label, start trust, dawn per standing house, clear reward per night number]
	var variants := [["now", 200, 5, 10], ["start 300", 300, 5, 10], ["income x2", 200, 10, 20],
		["start 300 + income x2", 300, 10, 20], ["start 300 + income x3", 300, 15, 30], ["start 400 + income x3", 400, 15, 30]]
	for v in variants:
		var res := []
		for sd in [1, 2, 3]:
			res.append(await _run(sd, v[1], v[2], v[3]))
		print("%-24s %s" % [v[0], " | ".join(res)])
	quit()


func _run(sd: int, start: int, dawn: int, clear: int) -> String:
	var g: Game = load("res://scripts/game/game.gd").new()
	g.with_rig = false
	g.run_seed = sd
	root.add_child(g)
	await process_frame
	g.new_run(sd)
	var log := []
	var last_loop := -1
	while g.phase != Game.Phase.DONE:
		if g.phase == Game.Phase.CARDS:
			g.choose_card(0)
			continue
		if g.loop != last_loop:
			last_loop = g.loop
			g.trust += start - GameConfig.START_TRUST
		for item in PLAN:  # in order: waits to afford the next one rather than skipping it
			if g.towers.any(func(t): return t.cell == item[1]):
				continue
			if not g.try_build(item[0], item[1]):
				break
		var n := g.night
		var lp := g.loop
		g.start_night()
		var t := 0.0
		while g.phase == Game.Phase.NIGHT and t < 900.0:
			g.step(0.05)
			t += 0.05
			if int(t / 0.05) % 40 == 0:
				await process_frame
		if g.phase == Game.Phase.DAY and g.loop == lp:
			g.trust += g.standing_houses().size() * (dawn - GameConfig.DAWN_TRUST_PER_HOUSE) + (clear - GameConfig.NIGHT_CLEAR_TRUST_PER_NIGHT) * (n + 1)
		elif g.loop_won or (g.phase == Game.Phase.CARDS and g.loop_won):
			log.append("L%d WON" % (lp + 1))
		else:
			log.append("L%d n%d" % [lp + 1, n + 1])
	g.queue_free()
	await process_frame
	return "seed %d: %s" % [sd, " ".join(log)]
