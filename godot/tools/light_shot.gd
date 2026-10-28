extends SceneTree
## Look-dev sheet of the board lighting (desktop window needed, not --headless):
##   <godot console> --xr-mode off --path godot -s res://tools/light_shot.gd -- OUT_PREFIX [seq]
## Builds a game with a few towers, then shoots the player's desktop view in each mood (dawn, day, dusk, night)
## into OUT_PREFIX_moods.png (2 x 2) plus one full frame per mood.
## seq: instead, a 12-frame strip (one frame a second, real time) of a night starting (day -> dusk -> night) and then
## a new day (night -> dawn -> day), as the game plays them: OUT_PREFIX_seq.png.

const MOODS := ["dawn", "day", "dusk", "night"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := args[0] if args.size() > 0 else "light_shot"
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 5:
		await process_frame
	g.trust = 2000
	g.cards = {}
	for t in [["fire", Vector2i(5, 12)], ["airship", Vector2i(15, 14)], ["guard", Vector2i(9, 16)], ["crossbow", Vector2i(16, 8)]]:
		g.try_build(t[0], t[1])
	g._hud.visible = false
	g._msg.visible = false
	g.set_process(false)
	if args.size() > 1 and args[1] == "seq":
		await _sequence(g, prefix)
		quit()
		return
	var shots: Array[Image] = []
	for mood in MOODS:
		g.lighting.set_mood(mood, 0.0)
		for i in 20:
			await process_frame
		var img := root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.save_png("%s_%s.png" % [prefix, mood])
		shots.append(img)
	var w := shots[0].get_width() / 2
	var h := shots[0].get_height() / 2
	var sheet := Image.create(w * 2, h * 2, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		shots[i].resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % 2) * w, (i / 2) * h))
	sheet.save_png("%s_moods.png" % prefix)
	print("LIGHTSHOT saved ", prefix, "_moods.png")
	quit()


func _sequence(g: Game, prefix: String) -> void:
	g.lighting.set_mood("day", 0.0)
	var frames: Array[Image] = []
	for step in [["dusk", "night", Lighting.DUSK_HOLD, 7], ["dawn", "day", Lighting.DAWN_HOLD, 5]]:
		g.lighting.play(step[0], step[1], step[2])
		for i in step[3]:
			var t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 1000:
				await process_frame
			var img := root.get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			frames.append(img)
	var w := frames[0].get_width() / 2
	var h := frames[0].get_height() / 2
	var sheet := Image.create(w * 4, h * 3, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		frames[i].resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(frames[i], Rect2i(0, 0, w, h), Vector2i((i % 4) * w, (i / 4) * h))
	sheet.save_png("%s_seq.png" % prefix)
	print("LIGHTSHOT saved ", prefix, "_seq.png (frames 1-7: night starting, 8-12: a new day)")
