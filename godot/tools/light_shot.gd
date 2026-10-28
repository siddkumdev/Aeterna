extends SceneTree
## Look-dev sheet of the board lighting (desktop window needed, not --headless):
##   <godot console> --xr-mode off --path godot -s res://tools/light_shot.gd -- OUT_PREFIX
## Builds a game with a few towers, then shoots the player's desktop view in each mood (dawn, day, dusk, night)
## into OUT_PREFIX_moods.png (2 x 2) plus one full frame per mood.

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
