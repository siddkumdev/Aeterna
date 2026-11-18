extends SceneTree
## Plays the game headless-free for a few seconds and prints the music gains by day, at dusk and at night.
func _initialize() -> void:
	var g: Game = load("res://scripts/game/game.gd").new()
	g.with_rig = true
	root.add_child(g)
	for i in 10:
		await process_frame
	var m = g.music
	print("music node: ", m != null, " day player: ", m._day != null and m._day.stream != null, " night player: ", m._night != null and m._night.stream != null)
	for lv in [0.0, 0.5, 1.0, 0.0]:
		m.force_level = lv
		for i in 60 * 10:
			await process_frame
		print("level %.1f -> day %.2f (playing %s, %.0f dB)  night %.2f (playing %s, %.0f dB)" % [lv, m.day_gain, m._day.playing, m._day.volume_db, m.night_gain, m._night.playing, m._night.volume_db])
	quit()
