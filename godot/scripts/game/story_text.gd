class_name StoryText
extends RefCounted
## The words: villager thoughts, dawn prayers, Skotos (the Warden) lines and kindness-task lines.
## All text lives in godot/data/thoughts.json (written from docs/STORY.md); this only reads it. Loops and days are
## 0-based here (the game's own counters) and 1-based in the file; out-of-range values are clamped, so a call never
## returns an empty string while the file is intact.

const PATH := "res://data/thoughts.json"
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data


static func ids() -> Array:
	return data().get("villagers", {}).keys()


static func villager_name(id: String) -> String:
	return str(data().get("villagers", {}).get(id, {}).get("name", id.capitalize()))


static func villager_role(id: String) -> String:
	return str(data().get("villagers", {}).get(id, {}).get("role", ""))


static func thought(id: String, loop: int, idx: int) -> String:
	## The idx-th line (cycling) of villager `id` in loop `loop` (0-based).
	var lines: Array = data().get("villagers", {}).get(id, {}).get("loops", {}).get(str(clampi(loop, 0, 4) + 1), [])
	if lines.is_empty():
		return ""
	return str(lines[posmod(idx, lines.size())])


static func prayer(loop: int, day: int) -> String:
	## Maren's dawn prayer for a loop and day (both 0-based).
	var lines: Array = data().get("dawn_prayers", {}).get(str(clampi(loop, 0, 4) + 1), [])
	if lines.is_empty():
		return ""
	return str(lines[posmod(day, lines.size())])


static func warden(kind: String, loop: int) -> String:
	## kind = "dusk_day1" or "night5".
	return str(data().get("warden", {}).get(kind, {}).get(str(clampi(loop, 0, 4) + 1), ""))


static func task(id: String, which: String) -> String:
	## which = "before" or "after".
	return str(data().get("tasks", {}).get(id, {}).get(which, ""))
