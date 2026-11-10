extends SceneTree
## Pictures of the living village (desktop window needed, not --headless):
##   <godot console> --xr-mode off --resolution 1200x700 --path godot -s res://tools/village_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_day.png (the whole board by day), _close.png (close on the plaza), _strip.png (from nightfall: the sprint home,
## 0.4 s apart), _night.png (enemies on the board), _poses.png (every villager's job pose), _enemies.png (each enemy walking and attacking)
## and _walks.png (hopping against stepping legs).

var g: Game
var cam: Camera3D


func _shot() -> Image:
	return root.get_viewport().get_texture().get_image()


func _wait(seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < seconds * 1000.0:
		await process_frame


func _sheet(frames: Array, cols: int, path: String) -> void:
	var cw: int = frames[0].get_width() / 2
	var ch: int = frames[0].get_height() / 2
	var sheet := Image.create(cw * cols, ch * ((frames.size() + cols - 1) / cols), false, Image.FORMAT_RGBA8)
	for i in frames.size():
		var f: Image = frames[i]
		f.convert(Image.FORMAT_RGBA8)
		f.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(f, Rect2i(0, 0, cw, ch), Vector2i((i % cols) * cw, (i / cols) * ch))
	sheet.save_png(path)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := args[0] if args.size() > 0 else "village_shot"
	g = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 5:
		await process_frame
	g._hud.visible = false
	g._msg.visible = false
	cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 40
	var centre: Vector3 = g.board.global_position
	g.FAITH = 500
	g.cards = {}
	g.try_build("fire", Vector2i(5, 12))
	g.try_build("crossbow", Vector2i(18, 12))
	g.try_build("guard", Vector2i(12, 18))
	await _wait(5.0)
	cam.global_position = centre + Vector3(0, 0.75, 0.85)
	cam.look_at(centre, Vector3.UP)
	await _wait(0.3)
	_shot().save_png("%s_day.png" % prefix)
	cam.fov = 26
	cam.global_position = centre + Vector3(0.1, 0.32, 0.6)
	cam.look_at(centre + Vector3(0, 0.02, 0.0), Vector3.UP)
	await _wait(0.3)
	_shot().save_png("%s_close.png" % prefix)
	await _sheets(prefix)
	cam.fov = 34
	cam.global_position = centre + Vector3(0, 0.55, 0.62)
	cam.look_at(centre, Vector3.UP)
	await _wait(0.2)
	g.night = 2
	g.start_night()
	var strip: Array = []
	for i in 8:
		strip.append(_shot())
		await _wait(0.4)
	_sheet(strip, 4, "%s_strip.png" % prefix)
	await _wait(6.0)
	cam.fov = 40
	cam.global_position = centre + Vector3(0, 0.75, 0.85)
	cam.look_at(centre, Vector3.UP)
	await process_frame
	_shot().save_png("%s_night.png" % prefix)
	var inside := g.life.villagers.filter(func(v): return v.state == "inside").size()
	print("VILLAGESHOT inside at night: ", inside, " of ", g.life.villagers.size())
	print("VILLAGESHOT saved ", prefix)
	quit()


func _lone_rig(key: String, family: String, anim: String, gait: float) -> CharacterRig:
	## One model on a bare corner of the board, in close-up (the grass is hidden for these sheets only).
	var r := CharacterRig.new()
	g.board.add_child(r)
	r.setup(key, family)
	r.position = Vector3(-0.3, 0.0, 0.26)
	r.anim = anim
	r.gait = gait
	r.rotation.y = 0.5
	cam.fov = 26
	cam.global_position = r.global_position + Vector3(0.0, 0.05, 0.2)
	cam.look_at(r.global_position + Vector3(0, 0.03, 0), Vector3.UP)
	return r


func _sheets(prefix: String) -> void:
	g.grass.visible = false
	var poses: Array = []
	var jobs := {"elder_ram": "talk", "clerk_owl": "read", "farmer_horse": "fork", "builder_ant": "hammer", "dancer_butterfly": "dance", "baker_mouse": "roll",
		"tailor_spider": "sew", "kid_bunny": "cheer", "kid_sprout": "startle", "bee_kid": "water", "cat_girl": "sweep", "shroom_goblin": "tend"}
	for k in jobs:
		var r := _lone_rig(k, "char", jobs[k], 0.0)
		await _wait(0.75)
		poses.append(_shot())
		r.queue_free()
	_sheet(poses, 4, "%s_poses.png" % prefix)
	var foes: Array = []
	for f in [["blightbark", "bark"], ["veilrunner", "veil"], ["sporebloom", "spore"], ["lantern_spirit", "lantern"], ["mawdrill", "drill"]]:
		for a in ["walk", "attack"]:
			var r := _lone_rig(f[0], f[1], a, 0.4)
			await _wait(0.72 if a == "attack" else 0.5)
			foes.append(_shot())
			r.queue_free()
	_sheet(foes, 4, "%s_enemies.png" % prefix)
	var walks: Array = []  # hop on the top rows, stepping legs below: a legged villager and a gowned one, walking then sprinting
	for style in [false, true]:
		CharacterRig.step_legs = style
		for k in ["farmer_horse", "dancer_butterfly"]:
			for gait in [1.1, 6.0]:
				var r := _lone_rig(k, "char", "walk", gait)
				await _wait(0.33)
				walks.append(_shot())
				await _wait(0.07)
				walks.append(_shot())
				r.queue_free()
	CharacterRig.step_legs = false
	_sheet(walks, 4, "%s_walks.png" % prefix)
	g.grass.visible = true
