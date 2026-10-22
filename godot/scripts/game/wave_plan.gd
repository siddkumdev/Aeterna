class_name WavePlan
extends RefCounted
## Which enemies come on a night, from where and when (spec 6a). Deterministic from the run seed, so a night
## can be replayed.
##   - The budget is spent only on types unlocked by that night (GameConfig.ENEMIES[..]["unlock"]).
##   - Guard rail: on the night a type unlocks, the first group is that type ALONE and small, so the player
##     can learn it.
##   - The rest is split into 3 groups growing 2 : 3 : 4 (so no spawn gets more than half the budget), one
##     group per spawn edge in a seeded order.


static func groups_for(night: int, rng_seed: int) -> Array[Dictionary]:
	## night is 0-based. Returns [{"time": s, "spawn": "north"|..., "enemies": Array[String]}] in spawn order.
	var budget: int = GameConfig.NIGHT_BUDGETS[clampi(night, 0, GameConfig.NIGHT_BUDGETS.size() - 1)]
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed + night * 7919
	var unlocked: Array[String] = []
	var fresh := ""  # the type that unlocks tonight, if any
	for k in GameConfig.WAVE_TYPES:
		var u: int = GameConfig.ENEMIES[k]["unlock"]
		if u <= night + 1:
			unlocked.append(k)
		if u == night + 1 and u > 1:
			fresh = k
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
		if i == 0 and fresh != "":
			pool = [fresh] as Array[String]  # tonight's new type comes first, alone
		groups[i] = _buy(budgets[i] + carry, pool, rng, i == 0 and fresh != "")
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
	return out


static func _buy(budget: int, pool: Array[String], rng: RandomNumberGenerator, only_pool: bool) -> Array[String]:
	## Spend `budget` threat on types from the pool, picked by weight (Grunts most often). Grunts (threat 1)
	## fill any remainder, except in an only-new-type group, which leaves the remainder to the next group.
	var out: Array[String] = []
	var left := budget
	while left > 0:
		var options := pool.filter(func(k): return GameConfig.ENEMIES[k]["threat"] <= left)
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
	return out


static func threat_of(enemies: Array) -> int:
	var t := 0
	for k in enemies:
		t += GameConfig.ENEMIES[k]["threat"]
	return t
