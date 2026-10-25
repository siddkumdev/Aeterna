class_name Cards
extends RefCounted
## Ability cards (spec 15, revision 4). Kept through the time loop; each card is held at one rarity
## (0 Common, 1 Rare, 2 Legendary). Values are [Common, Rare, Legendary]. A Legendary also gets its bonus.
##   - after beating the boss night: 3 offers, each rolls its own rarity (70 / 25 / 5 %), keep 1;
##   - after losing a night: 1 offer, always Common, no choice;
##   - a card you hold is only offered again at a HIGHER rarity, and taking it upgrades your copy.
## Cards for systems not built yet (`requires`) are never offered; GameConfig.BUILT_SYSTEMS lists what exists.

const RARITY_NAMES: Array[String] = ["Common", "Rare", "Legendary"]
const RARITY_ODDS: Array[float] = [0.70, 0.25, 0.05]

const POOL := {
	"ember_shot": {"name": "Ember Shot", "applies": "Fire Tower", "values": [2, 3, 4],
		"text": "Fireballs set enemies burning: %s damage/s for 3 s",
		"legend": "An enemy that dies while burning passes its burn to the nearest enemy within 1 cell"},
	"quick_fuse": {"name": "Quick Fuse", "applies": "Fire Tower", "values": [15, 25, 40],
		"text": "Fires %s%% faster",
		"legend": "Every 5th fireball is double size and deals double damage"},
	"bellows": {"name": "Bellows", "applies": "Blast Brazier", "values": [15, 25, 40],
		"text": "Pulses %s%% faster",
		"legend": "Every 3rd pulse knocks ground enemies back 1 cell"},
	"hot_coals": {"name": "Hot Coals", "applies": "Blast Brazier", "values": [5, 6, 8],
		"text": "%s damage per pulse (base 4)",
		"legend": "Each pulse leaves a burning patch for 2 s (2 damage/s)"},
	"heavy_bolts": {"name": "Heavy Bolts", "applies": "Longbow Tower", "values": [5, 6, 8],
		"text": "%s damage per bolt (base 4)",
		"legend": "Bolts slow every enemy they pierce by 30% for 2 s"},
	"long_draw": {"name": "Long Draw", "applies": "Longbow Tower", "values": [7, 8, 9],
		"text": "Range %s cells (base 6)",
		"legend": "Bolts can also hit flyers"},
	"long_mooring": {"name": "Long Mooring", "applies": "Airship", "values": [5, 6, 7], "requires": "airship",
		"text": "Range %s cells (base 4)",
		"legend": "The Airship can also shoot ground enemies at half damage"},
	"twin_cannons": {"name": "Twin Cannons", "applies": "Airship", "values": [15, 25, 40], "requires": "airship",
		"text": "Fires %s%% faster",
		"legend": "Each volley fires at two different targets"},
	# Shield Wall, Sharp Stones and Friendly Faces (Guards, Slingers, Watch Hut) were cut with the troops
	# (Siddharth 2026-10-25); the pool is 11 cards.
	"quick_hands": {"name": "Quick Hands", "applies": "all spells", "values": [15, 25, 40], "requires": "spells",
		"text": "Spell cooldowns %s%% shorter",
		"legend": "Each cast has a 25% chance to come straight back off cooldown"},
	"sturdy_homes": {"name": "Sturdy Homes", "applies": "houses", "values": [25, 50, 100],
		"text": "Houses +%s%% HP",
		"legend": "Once per night, the first house that would be shuttered holds at 1 HP instead"},
	"deep_pockets": {"name": "Deep Pockets", "applies": "trust", "values": [30, 50, 80],
		"text": "+%s starting trust",
		"legend": "+5 trust after every night in which no house was shuttered"},
}


static func value(id: String, rarity: int) -> float:
	return float(POOL[id]["values"][rarity])


static func describe(id: String, rarity: int) -> String:
	var c: Dictionary = POOL[id]
	var t := "%s\n%s  |  %s\n%s" % [c["name"], RARITY_NAMES[rarity], c["applies"], c["text"] % str(c["values"][rarity])]
	if rarity == 2:
		t += "\nLegendary: " + c["legend"]
	return t


static func available(id: String) -> bool:
	var req: String = POOL[id].get("requires", "")
	return req == "" or req in GameConfig.BUILT_SYSTEMS


static func roll_rarity(rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	if r < RARITY_ODDS[2]:
		return 2
	if r < RARITY_ODDS[2] + RARITY_ODDS[1]:
		return 1
	return 0


static func offers(owned: Dictionary, count: int, rng: RandomNumberGenerator, common_only := false) -> Array[Dictionary]:
	## Up to `count` different cards as [{"id", "rarity"}]. `owned` maps id -> held rarity.
	var ids: Array = POOL.keys().filter(func(k): return available(k))
	for i in range(ids.size() - 1, 0, -1):  # seeded shuffle
		var j := rng.randi_range(0, i)
		var t = ids[i]
		ids[i] = ids[j]
		ids[j] = t
	var out: Array[Dictionary] = []
	for id in ids:
		if out.size() >= count:
			break
		var r := 0 if common_only else roll_rarity(rng)
		if owned.has(id) and r <= owned[id]:
			continue  # only offered again at a higher rarity than the copy you hold
		out.append({"id": id, "rarity": r})
	return out
