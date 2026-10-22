class_name WavePlan
extends RefCounted
## Which enemies come on a night, from where and when (spec 6a). Deterministic from the run seed, so a night
## can be replayed.
##   - The budget is spent only on types unlocked by that night and loop (GameConfig.ENEMIES[..]["unlock"],
##     ["unlock_loop"]).
##   - Guard rail: on the night a type unlocks, it opens the night ALONE in a small group, so the player can
##     learn it. Two new types on one night (night 2: Scout and Wisp) get one lead group each.
##   - Guard rail: flyers never more than GameConfig.FLYER_SHARE of the night's threat.
##   - The rest is split into 3 groups growing 2 : 3 : 4 (so no spawn gets more than half the budget), one
##     group per spawn edge in a seeded order.
##   - Each loop after the first adds one more extra group per night (spec 16 for loop 2; loop 5 has 4), each
##     worth a third of the budget, from the edges in turn starting with the one that had the smallest group.
##     The new-type guard only applies in loop 1 (by loop 2 the player knows every type).
##   - The boss night (GameConfig.BOSS_NIGHT) is escort groups only; Game adds the boss itself.


static func groups_for(night: int, rng_seed: int, loop := 0) -> Array[Dictionary]:
	## night and loop are 0-based. Returns [{"time": s, "spawn": "north"|..., "enemies": Array[String]}] in
	## spawn order.
	var budget: int = GameConfig.NIGHT_BUDGETS[clampi(night, 0, GameConfig.NIGHT_BUDGETS.size() - 1)]
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed + night * 7919 + loop * 104729
	var unlocked: Array[String] = []
	var fresh: Array[String] = []  # types that unlock tonight, each opens the night alone (loop 1 only)
	for k in GameConfig.WAVE_TYPES:
		var u: int = GameConfig.ENEMIES[k]["unlock"]
		if u <= night + 1 and loop >= GameConfig.ENEMIES[k].get("unlock_loop", 0):
			unlocked.append(k)
			if u == night + 1 and u > 1 and loop == 0:
				fresh.append(k)
	var extra := budget / 3  # each extra group (loops 2+) is worth a third of the budget
	var n_extra := loop * GameConfig.EXTRA_GROUPS_PER_LOOP
	var air := {"left": int((budget + extra * n_extra) * GameConfig.FLYER_SHARE)}
	var shares := [2, 3, 4]
	var budgets: Array[int] = []
	var left := budget
	for i in range(3):
		var b: int = budget * shares[i] / 9 if i < 2 else left
		budgets.append(b)
		left -= b
	var groups: Array = [[], [], []]
	var carry := 0
	for i in range(3):
		var pool := unlocked
		var alone := i < fresh.size() and i < 2
		if alone:
			pool = [fresh[i]] as Array[String]  # tonight's new type comes first, alone
		groups[i] = _buy(budgets[i] + carry, pool, rng, alone, air)
		carry = budgets[i] + carry - threat_of(groups[i])  # what an only-new-type group could not spend
	var spawns: Array = GameConfig.SPAWNS.keys()
	for i in range(spawns.size() - 1, 0, -1):  # seeded shuffle: which edge each group comes from
		var j := rng.randi_range(0, i)
		var t = spawns[i]
		spawns[i] = spawns[j]
		spawns[j] = t
	var out: Array[Dictionary] = []
	for g in range(3):
		out.append({"time": GameConfig.FIRST_GROUP_DELAY + g * GameConfig.GROUP_INTERVAL, "spawn": spawns[g], "enemies": groups[g]})
	for x in range(n_extra):
		# worth a third of the night's budget each, starting from the edge whose group was smallest (the first)
		out.append({"time": GameConfig.FIRST_GROUP_DELAY + (3 + x) * GameConfig.GROUP_INTERVAL, "spawn": spawns[x % 3],
			"enemies": _buy(extra, unlocked, rng, false, air)})
	return out


static func _buy(budget: int, pool: Array[String], rng: RandomNumberGenerator, only_pool: bool, air: Dictionary) -> Array[String]:
	## Spend `budget` threat on types from the pool, picked by weight (Grunts most often). Grunts (threat 1)
	## fill any remainder, except in an only-new-type group, which leaves the remainder to the next group.
	## air["left"] is the flyer threat the night may still spend; it goes down as flyers are bought.
	var out: Array[String] = []
	var left := budget
	while left > 0:
		var options := pool.filter(func(k): return GameConfig.ENEMIES[k]["threat"] <= left \
			and (not GameConfig.ENEMIES[k].get("flying", false) or GameConfig.ENEMIES[k]["threat"] <= air["left"]))
		if options.is_empty():
			if only_pool:
				break
			options = ["grunt"]
		var total := 0
		for k in options:
			total += GameConfig.ENEMIES[k]["weight"]
		var r := rng.randi_range(1, total)
		var k: String = options[0]
		for o in options:
			r -= GameConfig.ENEMIES[o]["weight"]
			if r <= 0:
				k = o
				break
		out.append(k)
		left -= GameConfig.ENEMIES[k]["threat"]
		if GameConfig.ENEMIES[k].get("flying", false):
			air["left"] -= GameConfig.ENEMIES[k]["threat"]
	return out


static func threat_of(enemies: Array) -> int:
	var t := 0
	for k in enemies:
		t += GameConfig.ENEMIES[k]["threat"]
	return t
