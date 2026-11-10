class_name CardData
extends RefCounted
## What a physical card shows. Built from GameConfig (towers, spells) and Cards (abilities), so the numbers on a card
## can never drift from the rules. Only the one-line flavour text is written here (story text, not a rule).
## A card is a Dictionary: {kind: "tower"|"spell"|"ability", id, title, seal, stats: [[label, value], x4],
## text, flavour, family}.

const TOWER_FLAVOUR := {
	"fire": "The old mage still lights her tower for the children.",
	"guard": "Three brave souls and one very big promise.",
	"crossbow": "A steady hand, a long road, and a wind that listens.",
	"airship": "Small, loud, and proud of it. Sees what the ground cannot.",
}
const SPELL_FLAVOUR := {
	"fire_orb": "A little sun, thrown with love.",
	"boulder": "The mountain remembers your name. Drop it from higher.",
	"storm": "Rain for the fields, thunder for the wicked.",
	"rage": "Courage is catching. Let them catch it.",
	"roots": "The wood has older friends than the Warden.",
}
const SPELL_TEXT := {
	"fire_orb": "Hurls a ball of fire that bursts where it lands.",
	"boulder": "Drop a boulder on the road. Release it higher for more damage and a wider crash.",
	"storm": "A storm cloud that strikes the nearest foe, then leaps to two more.",
	"rage": "Towers inside the ring shoot faster for a while.",
	"roots": "Roots rise and soak up damage meant for your people.",
}
const TOWER_TEXT := {
	"fire": "Hurls fireballs at one enemy at a time.",
	"guard": "Calls Guards who stand firm and fight what comes close.",
	"crossbow": "A long bolt that pierces every enemy in a line.",
	"airship": "Shoots only what flies.",
}


static func fmt(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, round(v)) else "%.1f" % v


static func cells(v: float) -> String:
	return "%s cell%s" % [fmt(v), "" if is_equal_approx(v, 1.0) else "s"]


static func tower(id: String) -> Dictionary:
	var t: Dictionary = GameConfig.TOWERS[id]
	var dmg: float = t["guard_damage"] if t.get("kind", "") == "spawner" else t["damage"]
	var rate: float = t["attack_interval"] if t.get("kind", "") == "spawner" else t["interval"]
	var area := cells(t["range"])
	return {
		"kind": "tower", "id": id, "title": t["name"], "family": "oak",
		"seal": str(int(t["cost"])),
		"stats": [["Damage", fmt(dmg)], ["Faith", str(int(t["cost"]))], ["Rate", "%ss" % fmt(rate)], ["Area", area]],
		"text": TOWER_TEXT.get(id, ""), "flavour": TOWER_FLAVOUR.get(id, ""),
	}


static func spell(id: String) -> Dictionary:
	var s: Dictionary = GameConfig.SPELLS[id]
	var dmg := "-"
	if s.has("damage"):
		dmg = fmt(s["damage"])
	elif s.has("absorb"):
		dmg = "Absorbs %s" % fmt(s["absorb"])
	elif s.has("haste"):
		dmg = "x%s speed" % fmt(s["haste"])
	var area := "-"
	for k in ["radius", "reach"]:
		if s.has(k):
			area = cells(s[k])
			break
	return {
		"kind": "spell", "id": id, "title": s["name"], "family": "ember",
		"seal": "Free",
		"stats": [["Damage", dmg], ["Faith", "Free"], ["Recharge", "%ss" % fmt(s["cooldown"])], ["Area", area]],
		"text": SPELL_TEXT.get(id, ""), "flavour": SPELL_FLAVOUR.get(id, ""),
	}


static func ending(id: String) -> Dictionary:
	## The two ways the story can end (docs/STORY.md section 8), as cards on the tray.
	var let_go := id == "let_go"
	return {
		"kind": "ending", "id": id, "title": "Let go" if let_go else "Remember them", "family": "ivory", "rarity": 0,
		"seal": "End",
		"stats": [["Ending", "Bittersweet" if let_go else "Hopeful"], ["", ""], ["", ""], ["", ""]],
		"text": "Spend all your godhood so the Veil holds forever. You fade." if let_go else "Show Skotos every prayer. Let them remember being loved.",
		"flavour": "Some days are worth having twice." if let_go else "Two small gods, one garden.",
	}


static func ability(id: String, rarity: int) -> Dictionary:
	var c: Dictionary = Cards.POOL[id]
	var text: String = c["text"] % str(c["values"][rarity])
	if rarity == 2:
		text += "  Legendary: " + c["legend"]
	return {
		"kind": "ability", "id": id, "title": c["name"], "family": "ivory", "rarity": rarity,
		"seal": ["I", "II", "III"][rarity],  # Common / Rare / Legendary (the Rarity box spells it out)
		"stats": [["Applies to", str(c["applies"]).capitalize()], ["Rarity", Cards.RARITY_NAMES[rarity]], ["", ""], ["", ""]],
		"text": text, "flavour": "",
	}
