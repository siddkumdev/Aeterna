extends SceneTree
## Stills of the god-hand from SYNTHETIC joint data (desktop window needed, not --headless):
##   <godot console> --xr-mode off --path godot -s res://tools/god_hand_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_open.png, _curl.png, _pinch.png, _pinch_close.png, _hot.png. The pose is GodHandVisual.demo_joints,
## a stand-in: real tracking is only on the headset.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := args[0] if args.size() > 0 else "god_hand_shot"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color8(0x2A, 0x20, 0x28)  # a dim warm room, like the haze behind the hand
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var hand := GodHandVisual.new()
	hand.side = "right"
	root.add_child(hand)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 38
	for i in 4:
		await process_frame
	var cases := [
		["open", 0.0, 0.0, false, Vector3(0.03, 0.2, 0.1), Vector3(0, -0.01, -0.09)],
		["curl", 0.55, 0.0, false, Vector3(0.03, 0.2, 0.1), Vector3(0, -0.02, -0.07)],
		["pinch", 0.35, 1.0, false, Vector3(0.05, 0.16, 0.1), Vector3(0.0, -0.03, -0.1)],
		["pinch_close", 0.35, 1.0, false, Vector3(0.0, 0.07, -0.07), Vector3(0.0, -0.035, -0.12)],
		["hot", 0.2, 0.55, true, Vector3(0.0, 0.07, -0.07), Vector3(0.0, -0.035, -0.12)],
	]
	for c in cases:
		hand.set_pose_from(GodHandVisual.demo_joints(c[1], c[2]))
		hand.set_hot(c[3])
		cam.global_position = c[4]
		cam.look_at(c[5], Vector3.UP)
		for i in 90:  # let the embers rise and the glow settle
			hand.set_pose_from(GodHandVisual.demo_joints(c[1], c[2]))
			await process_frame
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("%s_%s.png" % [prefix, c[0]])
		print("GODHAND saved ", c[0], " pinch_strength=", snappedf(hand.pinch_strength, 0.01))
	quit()
