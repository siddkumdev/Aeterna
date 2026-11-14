extends SceneTree
## The immersive opening (desktop window): --xr-mode off --path godot -s res://tools/opening_shot.gd -- OUT_PREFIX
## Plays it at 6x speed and writes OUT_PREFIX_c1a.png .. _c5b.png (early and late in each chapter).

const SHOTS := [[[9.0, "a"], [29.0, "b"]], [[7.0, "a"], [21.0, "b"]], [[11.0, "a"], [27.0, "b"]],
	[[1.85, "s1"], [2.5, "s2"], [3.4, "s3"], [7.0, "a"], [20.0, "b"]], [[6.0, "a"], [22.0, "b"], [25.5, "c"], [39.5, "d"]]]


func _initialize() -> void:
	var prefix := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "opening"
	var l: Launcher = load("res://scripts/ui/launcher.gd").new()
	root.add_child(l)
	for i in 30:
		await process_frame
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 62
	cam.global_position = Vector3(0, 1.0, 0)
	cam.look_at(Vector3(0, 1.0, -1), Vector3.UP)
	l.game._camera = null
	l._auto_at = -1.0
	l._press_plaque("wake")
	Engine.time_scale = 6.0
	var got := {}
	var guard := 0
	while l._state == "narrating" and guard < 9000:
		guard += 1
		await process_frame
		var st: OpeningStage = l.game.get_node_or_null("OpeningStage")
		if st == null:
			continue
		if st._chapter < 0:
			continue
		for pair in SHOTS[st._chapter]:
			var key := "c%d%s" % [st._chapter + 1, pair[1]]
			if st._t >= pair[0] and not got.has(key):
				got[key] = true
				root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [prefix, key])
	print("OPENINGSHOT shots ", got.keys(), " state ", l._state)
	Engine.time_scale = 1.0
	quit()
