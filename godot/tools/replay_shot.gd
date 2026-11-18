extends SceneTree
## Replay a Quest recording into the game (GameConfig.FORCE_XR rig, no headset). Run with a window for shots:
##   <godot console> --xr-mode off --path godot -s res://tools/replay_shot.gd -- REC.bin.gz OUT_DIR [shots|hands|stats]
## shots (default): head-camera frames at the first tower placements of the recording -> OUT_DIR/replay_tower_N_{pre,at}.png
## hands:  the same head view with both hands up close (untracked/fallback and tracked) -> OUT_DIR/replay_hands_*.png
## stats:  (also runs --headless) replays whole stretches and prints how many presses/merged/spikes the hands saw, with the
##         debounce on and off: the count of spurious grab/drops before/after (fix B)
## The game state is NOT the recorded state (the replay only feeds hands and head), so the shots show where the player's
## head and hands were, in a game that is at its first day.

const InputReplay := preload("res://scripts/game/input_replay.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "res://../quest_data/recordings/2026-11-17_19-10-07.bin.gz"
	var out_dir: String = args[1] if args.size() > 1 else "res://../_work/replay_shots"
	var mode: String = args[2] if args.size() > 2 else "shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameConfig.FORCE_XR = true
	var rp: Node = InputReplay.new()
	if not rp.load_file(path):
		print("replay_shot: cannot load ", path)
		quit(1)
		return
	print("replay_shot: %d frames, %.1f s, %d events" % [rp.frame_count(), rp.duration, rp.events.size()])
	if mode == "tray":
		_tray_angles(rp)
		quit()
		return
	if mode == "stats":
		await _stats(rp)
		quit()
		return
	if mode == "templates":
		await _templates(out_dir)
		quit()
		return
	var l: Launcher = load("res://scripts/ui/launcher.gd").new()
	root.add_child(l)
	root.add_child(rp)
	rp.install(null)
	rp.apply(120.0)  # a head pose from the seated play, so the board lands where this player had it
	for i in 40:
		await process_frame
	l._press_plaque("skip")
	l._skip = true
	for i in 30:
		await process_frame
	var g: Game = l.game
	rp.head_node = g._xr_cam
	g._xr_cam.fov = 80.0
	g._xr_cam.current = true
	rp.apply(120.0)
	g._board_placed = false
	g._tray_placed = false
	g.place_seated_board()
	for i in 20:
		await process_frame
	rp.fixed_dt = 1.0 / 72.0
	if mode == "wake":
		rp.seek(120.0)
		for i in 30:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/replay_wake_tray.png" % out_dir)
		quit()
		return
	var towers: Array = rp.events_of("tower")
	if mode == "hands":
		# close-up camera on the right hand at four recorded moments: untracked open / pinch / fist (fallback hand) and a tracked hand
		var want := {"fallback_open": [false, 0.0, 0.2], "fallback_pinch": [false, 0.95, 0.0], "fallback_fist": [false, 0.0, 0.95], "tracked": [true, -1.0, -1.0]}
		var found := {}
		var tt := 330.0
		while tt < rp.duration and found.size() < want.size():
			var hs: Dictionary = rp.sample(tt)["hands"]["right"]
			for k in want:
				if found.has(k) or not hs["aim_ok"] or hs["tracked"] != want[k][0]:
					continue
				if not want[k][0] and ((k == "fallback_open" and hs["trigger"] < 0.05 and hs["grip_val"] < 0.25) or (k == "fallback_pinch" and hs["trigger"] > want[k][1]) or (k == "fallback_fist" and hs["grip_val"] > 0.85)):
					found[k] = tt
				elif want[k][0] and hs["tracked"]:
					found[k] = tt
			tt += 0.25
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.fov = 45.0
		for k in found:
			rp.seek(found[k])
			var wait_frames := 0
			while wait_frames < 400 and (wait_frames < 20 or (g._hands[1] as GameHand).visual.tracked != bool(want[k][0])):  # past the 0.6 s blink grace: the hand shown is the pose of this moment
				rp.speed = 0.0
				rp.step(1.0 / 72.0)
				await process_frame
				wait_frames += 1
			var rh: GameHand = g._hands[1]
			var at: Vector3 = rh.visual.to_global(rh.visual._joints[0].origin)  # the palm
			var eye: Vector3 = g._xr_cam.global_position
			cam.global_position = at + (eye - at).normalized() * 0.30 + Vector3(0, 0.05, 0)
			cam.look_at(at, Vector3.UP)
			cam.current = true
			await process_frame
			await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s/replay_hands_%s.png" % [out_dir, k])
			print("hands shot ", k, " at t=", found[k], " tracked=", rh.visual.tracked, " fallback=", rh.visual.fallback)
		g._xr_cam.current = true
	else:
		var n := 0
		for tw in towers:
			if n >= 6:
				break
			var t: float = tw["t"]
			rp.seek(t - 1.0)
			rp.playing = true
			for i in 50:  # 0.7 s of replay, then the shot just before the pinch lets go
				await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s/replay_tower_%d_pre.png" % [out_dir, n])
			for i in 22:
				await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s/replay_tower_%d_at.png" % [out_dir, n])
			rp.playing = false
			n += 1
	for side in ["left", "right"]:
		var h: GameHand = g.get_node_or_null("XROrigin3D/%s_hand" % side) as GameHand
		if h == null:
			for c in g._hands:
				if String(c.tracker).begins_with(side):
					h = c
		if h != null and h.visual != null:
			print("hand %s: tracked=%s fallback=%s" % [side, h.visual.tracked, h.visual.fallback])
	quit()


func _stats(rp: InputReplay) -> void:
	## Replays the whole recording through the headset hands twice (debounce off, then on) and counts what the hands
	## reported. Runs headless: no rendering is needed.
	for on in [false, true]:
		GameHand.debounce = on
		var g: Game = load("res://scripts/game/game.gd").new()
		root.add_child(g)
		root.add_child(rp)
		rp.install(null)
		await process_frame
		rp.head_node = g._xr_cam
		var stats := {"btn": 0, "pressed": 0, "released": 0, "cancelled": 0, "short_press": 0, "quick_repress": 0}
		var t_press := {}
		var t_rel := {}
		var delay: float = GameHand.RELEASE_DEBOUNCE if on else 0.0  # the debounced release is signalled this late: measure the physical release time
		for h in g._hands:
			var gh: GameHand = h
			gh.button_pressed.connect(func(_n: String): stats["btn"] += 1)
			gh.pressed.connect(func(hh: GameHand):
				stats["pressed"] += 1
				t_press[hh] = rp.time
				if t_rel.has(hh) and rp.time - t_rel[hh] < 0.12:
					stats["quick_repress"] += 1)
			gh.released.connect(func(hh: GameHand):
				stats["released"] += 1
				t_rel[hh] = rp.time - delay
				if t_press.has(hh) and rp.time - delay - t_press[hh] < 0.1:
					stats["short_press"] += 1)
			gh.cancelled.connect(func(hh: GameHand):
				stats["cancelled"] += 1
				t_rel[hh] = rp.time - delay
				if t_press.has(hh) and rp.time - delay - t_press[hh] < 0.1:
					stats["short_press"] += 1)
		rp.fixed_dt = 1.0 / 72.0
		rp.apply(0.0)
		rp.playing = true
		var frames := 0
		while rp.playing and frames < 90000:
			await process_frame
			frames += 1
		var merged := 0
		var spikes := 0
		for h in g._hands:
			merged += (h as GameHand).merged_presses
			spikes += (h as GameHand).spike_cancels
		print("STATS debounce=%s frames=%d %s merged=%d spike_cancels=%d" % [on, frames, str(stats), merged, spikes])
		rp.playing = false
		rp.uninstall()
		root.remove_child(rp)
		g.queue_free()
		await process_frame
	GameHand.debounce = true


func _templates(out_dir: String) -> void:
	## The recorded open / pinch / fist hand templates (grip-pose space), both hands, side by side, from two directions.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.18, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.9)
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(sun)
	var cases := [[0.0, 0.0], [1.0, 0.0], [0.0, 1.0], [0.6, 0.5]]
	var holder := Node3D.new()
	root.add_child(holder)
	for side_i in 2:
		var side := "left" if side_i == 0 else "right"
		for c in cases.size():
			var v := GodHandVisual.new()
			v.side = side
			holder.add_child(v)
			await process_frame
			v.fallback_joints(Transform3D(Basis.IDENTITY, Vector3(0.0, side_i * -0.3, c * -0.22)), cases[c][0], cases[c][1])
			v.set_pose_from(v._joints)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 40.0
	for view in [["front", Vector3(1.0, -0.15, -0.33)], ["side", Vector3(-1.0, -0.15, -0.33)], ["back", Vector3(0.0, -0.15, 1.0)]]:
		cam.global_position = view[1]
		cam.look_at(Vector3(0.0, -0.15, -0.33), Vector3.UP)
		cam.current = true
		for i in 4:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/replay_templates_%s.png" % [out_dir, view[0]])


func _tray_angles(rp: Node) -> void:
	## Card pick-up angle below the horizon at the recorded tower placements, for the tray's default spot: the board and tray
	## are placed from the head at wake (t = 120 s) with Game's own formulas, then each pick-up is the tray's middle (+5 cm,
	## where the cards stand) seen from the recorded head at the pick-up time (the real pick-up time = last press before the tower).
	var head0: Transform3D = rp.sample(120.0)["head"]
	var board := Game.seated_board_transform(head0.origin, -head0.basis.z)
	var tray := Game.tray_start_transform(board, head0.origin)
	var pick := tray.origin + Vector3(0, 0.05, 0)
	var angs := []
	var dists := []
	for e in rp.events_of("tower"):
		var tt: float = e["t"]
		var rel := -1.0
		var prs := -1.0
		for ev in rp.events:
			var k: String = ev.get("kind", "")
			if (k == "release" or k == "press") and ev.get("input", "") in ["trigger_click", "grip_click"]:
				if k == "release" and absf(ev["t"] - tt) < 0.35:
					rel = ev["t"]
					prs = -1.0
		var h: Vector3 = rp.sample(tt - 1.5)["head"].origin  # the head while reaching for the card
		var v := pick - h
		var hz := Vector2(v.x, v.z).length()
		angs.append(snappedf(rad_to_deg(atan2(-v.y, hz)), 0.1))
		dists.append(snappedf(v.length(), 0.01))
	angs.sort()
	print("TRAY board=", board.origin, " scale=", board.basis.get_scale().x, " tray=", tray.origin, " head0=", head0.origin)
	print("TRAY pickup angles below horizon (deg, sorted): ", angs, " median ", angs[angs.size() / 2])
	print("TRAY head-to-tray distances (m): ", dists)
	var ends := tray.basis.x * 0.165
	print("TRAY wing/lens ends from head0: ", (tray.origin + ends).distance_to(head0.origin), " / ", (tray.origin - ends).distance_to(head0.origin))
	for s in [0.8, 1.0]:
		var b := Transform3D(board.basis.orthonormalized() * Basis.from_scale(Vector3.ONE * s), board.origin)
		var tr := Game.tray_start_transform(b, head0.origin)
		var local := b.affine_inverse() * tr.origin
		var gap_edge: float = maxf(absf(local.x), absf(local.z)) - Game.HALF * s  # distance of the tray's middle beyond the island edge
		print("TRAY scale ", s, ": middle beyond edge ", snappedf(gap_edge, 0.001), " m, minus half tray depth 0.055 = ", snappedf(gap_edge - 0.055, 0.001), " (rim handles reach 0.065 outside the edge only at their own side)")
