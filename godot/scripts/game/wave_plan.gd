class_name WavePlan
extends RefCounted
## Which enemies come on a night, from where and when (spec 6a, slice version: Grunts only).
## Deterministic from the run seed, so a night can be replayed.


static func groups_for(night: int, rng_seed: int) -> Array[Dictionary]:
	## night is 0-based. Returns [{"time": s, "spawn": "north"|..., "count": n}] in spawn order.
	var budget: int = GameConfig.NIGHT_BUDGETS[clampi(night, 0, GameConfig.NIGHT_BUDGETS.size() - 1)]
	var total := budget / GameConfig.GRUNT_THREAT
	# Group sizes grow through the night (2 : 3 : 4); the last group is never more than half the budget.
	var first := total * 2 / 9
	var second := total * 3 / 9
	var sizes: Array[int] = [first, second, total - first - second]
	var spawns: Array = GameConfig.SPAWNS.keys()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed + night * 7919
	for i in range(spawns.size() - 1, 0, -1):  # seeded shuffle: which edge each group comes from
		var j := rng.randi_range(0, i)
		var t = spawns[i]
		spawns[i] = spawns[j]
		spawns[j] = t
	var out: Array[Dictionary] = []
	for g in range(3):
		out.append({"time": GameConfig.FIRST_GROUP_DELAY + g * GameConfig.GROUP_INTERVAL, "spawn": spawns[g], "count": sizes[g]})
	return out
